/*
 *  Copyright (C) 2016-present Prominic.NET, Inc.
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the Server Side Public License, version 1,
 *  as published by MongoDB, Inc.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 *  Server Side Public License for more details.
 *
 *  You should have received a copy of the Server Side Public License
 *  along with this program. If not, see
 *
 *  http://www.mongodb.com/licensing/server-side-public-license
 *
 *  As a special exception, the copyright holders give permission to link the
 *  code of portions of this program with the OpenSSL library under certain
 *  conditions as described in each individual source file and distribute
 *  linked combinations including the program with the OpenSSL library. You
 *  must comply with the Server Side Public License in all respects for
 *  all of the code used other than as permitted herein. If you modify file(s)
 *  with this exception, you may extend this exception to your version of the
 *  file(s), but you are not obligated to do so. If you do not wish to do so,
 *  delete this exception statement from your version. If you delete this
 *  exception statement from all source files in the program, then also delete
 *  it in the license file.
 */

package;

import feathers.controls.Alert;
import feathers.controls.LayoutGroup;
import feathers.data.ArrayCollection;
import feathers.style.Theme;
import genesis.application.GenesisApplication;
import genesis.application.managers.LanguageManager;
import genesis.application.managers.ToastManager;
import genesis.application.theme.GenesisApplicationTheme;
import haxe.Json;
import lime.system.System;
import openfl.Lib;
import openfl.events.Event;
import openfl.events.UncaughtErrorEvent;
import openfl.system.Capabilities;
import prominic.logging.Logger;
import prominic.sys.applications.AbstractApp;
import prominic.sys.applications.bin.Shell;
import prominic.sys.applications.hashicorp.Vagrant;
import prominic.sys.applications.oracle.VirtualBox;
import prominic.sys.io.AbstractExecutor;
import prominic.sys.io.FileTools;
import prominic.sys.io.ParallelExecutor;
import prominic.sys.tools.StrTools;
import prominic.sys.tools.SysTools.CPUArchitecture;
import superhuman.components.AdvancedConfigPage;
import superhuman.components.ConfigPage;
import superhuman.components.HelpPage;
import superhuman.components.LoadingPage;
import superhuman.components.RolePage;
import superhuman.components.ServerPage;
import superhuman.components.SettingsPage;
import superhuman.config.SuperHumanConfig;
import superhuman.config.SuperHumanGlobals;
import superhuman.events.SuperHumanApplicationEvent;
import superhuman.managers.ProvisionerManager;
import superhuman.managers.ServerManager;
import superhuman.server.Server;
import superhuman.server.ServerStatus;
import superhuman.server.data.RoleData;
import superhuman.server.data.ServerData;
import superhuman.server.roles.ServerRoleImpl;
import superhuman.theme.SuperHumanInstallerTheme;
import sys.FileSystem;
import sys.io.File;

using prominic.tools.ObjectTools;

class SuperHumanInstaller extends GenesisApplication {

	static final _CONFIG_FILE:String = ".shi-config";
	static final _DOMINO_VAGRANT_VERSION_FILE:String = "version.rb";

	static public final PAGE_CONFIG = "page-config";
	static public final PAGE_CONFIG_ADVANCED = "page-config-advanced";
	static public final PAGE_HELP = "page-help";
	static public final PAGE_LOADING = "page-loading";
	static public final PAGE_ROLES = "page-roles";
	static public final PAGE_SERVER = "page-server";
	static public final PAGE_SETTINGS = "page-settings";

	static public final DEMO_TASKS_PATH:String = "assets/vagrant/demo-tasks/";

	static var _instance:SuperHumanInstaller;

	public static function getInstance():SuperHumanInstaller {

		return _instance;

	}

	final _validHashes:Map<String, Map<String, Array<String>>> = [
		
		"domino" => [ "installers" => [ "4153dfbb571b1284ac424824aa0e25e4" ], "hotfixes" => [], "fixpacks" => [] ],
		"appdevpack" => [ "installers" => [ "b84248ae22a57efe19dac360bd2aafc2" ] ],
		"leap" => [ "installers" => [ "080235c0f0cce7cc3446e01ffccf0046" ] ],
		"nomadweb" => [ "installers" => [ "044c7a71598f41cd3ddb88c5b4c9b403", "8f3e42f4f5105467c99cfd56b8b4a755" ] ],
		"traveler" => [ "installers" => [ "4a195e3282536de175a2979def40527d", "4118ee30d590289070f2d29ecf1b34cb" ] ],
		"verse" => [ "installers" => [ "dfad6854171e964427550454c5f006ee" ] ],
		"domino-rest-api" => [ "installers" => [ "fa990f9bac800726f917cd0ca857f220" ] ],

	];

	var _advancedConfigPage:AdvancedConfigPage;
	var _appCheckerOverlay:LayoutGroup;
	var _config:SuperHumanConfig;
	var _configPage:ConfigPage;
	var _defaultRoles:Map<String, RoleData>;
	var _defaultServerConfigData:ServerData;
	var _helpPage:HelpPage;
	var _loadingPage:LoadingPage;
	var _processId:Null<Int>;
	var _rolePage:RolePage;
	var _serverPage:ServerPage;
	var _serverRolesCollection:Array<ServerRoleImpl>;
	var _servers:ArrayCollection<Server>;
	var _settingsPage:SettingsPage;
	var _vagrantFile:String;

	public var config( get, never ):SuperHumanConfig;
	function get_config() return _config;

	public var defaultRoles( get, never ):Map<String, RoleData>;
	function get_defaultRoles() return _defaultRoles;

	public var serverRolesCollection( get, never ):Array<ServerRoleImpl>;
	function get_serverRolesCollection() return _serverRolesCollection;

	public var validHashes( get, never ):Map<String, Map<String, Array<String>>>;
	function get_validHashes() return _validHashes;

	public function new() {

		super( #if showlogin true #end );

		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener( UncaughtErrorEvent.UNCAUGHT_ERROR, _uncaughtError );

		_instance = this;

		Logger.info( 'Bundled Provisioners: ${ProvisionerManager.getBundledProvisioners()}' );

		ServerManager.serverRootDirectory = System.applicationStorageDirectory + "servers/";

		_defaultRoles = superhuman.server.provisioners.DemoTasks.getDefaultProvisionerRoles();

		_serverRolesCollection = [

			new ServerRoleImpl( "Domino", LanguageManager.getInstance().getString( 'rolepage.roles.domino.desc' ), _defaultRoles.get( "domino" ), _validHashes.get( "domino" ).get( "installers" ), _validHashes.get( "domino" ).get( "hotfixes" ), _validHashes.get( "domino" ).get( "fixpacks" ), "(Domino_12.0.2_Linux_English.tar)" ),
			new ServerRoleImpl( "NomadWeb", LanguageManager.getInstance().getString( 'rolepage.roles.nomadweb.desc' ), _defaultRoles.get( "nomadweb" ), _validHashes.get( "nomadweb" ).get( "installers" ), "(nomad-server-1.0.6-for-domino-1202-linux.tgz)" ),
			new ServerRoleImpl( "Leap (formerly Volt)", LanguageManager.getInstance().getString( 'rolepage.roles.leap.desc' ), _defaultRoles.get( "leap" ), _validHashes.get( "leap" ).get( "installers" ), "(Leap-1.0.5.zip)" ),
			new ServerRoleImpl( "Traveler", LanguageManager.getInstance().getString( 'rolepage.roles.traveler.desc' ), _defaultRoles.get( "traveler" ), _validHashes.get( "traveler" ).get( "installers" ), "(Traveler_12.0.2_Linux_ML.tar.gz)" ),
			new ServerRoleImpl( "Verse", LanguageManager.getInstance().getString( 'rolepage.roles.verse.desc' ), _defaultRoles.get( "verse" ), _validHashes.get( "verse" ).get( "installers" ), "(HCL_Verse_3.0.0.zip)" ),
			new ServerRoleImpl( "AppDev Pack for Node.js", LanguageManager.getInstance().getString( 'rolepage.roles.appdevpack.desc' ), _defaultRoles.get( "appdevpack" ), _validHashes.get( "appdevpack" ).get( "installers" ), "(domino-appdev-pack-1.0.15.tgz)" ),
			new ServerRoleImpl( "Domino REST API", LanguageManager.getInstance().getString( 'rolepage.roles.domino-rest-api.desc' ), _defaultRoles.get( "domino-rest-api" ), _validHashes.get( "domino-rest-api" ).get( "installers" ), "(Domino_REST_API_V1_Installer.tar.gz)" ),

		];

		if ( FileSystem.exists( '${System.applicationStorageDirectory}${_CONFIG_FILE}' ) ) {

			try {

				var content = File.getContent( '${System.applicationStorageDirectory}${_CONFIG_FILE}' );
				_config = Json.parse( content );

			} catch ( e ) {

				_config = {

					servers : [],
					user: {},
					preferences: { keepserversrunning: true, savewindowposition: false, provisionserversonstart:true },
	
				}

			}

			if ( _config.user == null ) _config.user = {};

			if ( _config.preferences == null ) _config.preferences = { keepserversrunning: true, savewindowposition: false, provisionserversonstart:true };
			if ( _config.preferences.keepserversrunning == null ) _config.preferences.keepserversrunning = true;
			if ( _config.preferences.savewindowposition == null ) _config.preferences.savewindowposition = false;
			if ( _config.preferences.provisionserversonstart == null ) _config.preferences.provisionserversonstart = true;

			var a:Array<String> = [];
			for ( r in _defaultRoles ) a.push( r.value );

			var b:Array<String> = [];
			for ( s in _config.servers ) {

				b = [];
				for( r in s.roles ) b.push( r.value );
				
				for ( v in a ) if ( !b.contains( v ) ) s.roles.push( _defaultRoles.get( v ) );

			}

		} else {

			_config = {

				servers : [],
				user: {},
				preferences: { keepserversrunning: true, savewindowposition: false, provisionserversonstart:true },

			}

			File.saveContent( '${System.applicationStorageDirectory}${_CONFIG_FILE}', Json.stringify( _config ) );

		}

		_servers = new ArrayCollection();

		for ( s in _config.servers ) {

			var server = Server.create( s, ServerManager.serverRootDirectory );
			server.onUpdate.add( onServerPropertyChanged );
			_servers.add( server );

		}

		if ( _config.preferences.savewindowposition ) {

			if ( _config.preferences.windowx != null ) this._window.x = _config.preferences.windowx;
			if ( _config.preferences.windowy != null ) this._window.y = _config.preferences.windowy;
			if ( _config.preferences.windowwidth != null ) this._window.width = _config.preferences.windowwidth;
			if ( _config.preferences.windowheight != null ) this._window.height = _config.preferences.windowheight;

			if ( this._window.x < 0 ) this._window.x = 0;
			if ( this._window.y < 0 ) this._window.y = 0;

		}

		Shell.getInstance().findProcessId( 'SuperHumanInstaller', null, _processIdFound );

	}

	function _processIdFound( result:Array<ProcessInfo> ) {

		if ( result != null && result.length > 0 ) {

			_processId = result[ 0 ].pid;
			Logger.verbose( 'SuperHumanInstaller process id found: ${_processId}' );

		}

	}

	override function _processArgs() {

		super._processArgs();

		var args = Sys.args();

        for( arg in args ) {

            if ( arg == "--prune" ) SuperHumanGlobals.PRUNE_VAGRANT_MACHINES = true;

		}

	}

	function _uncaughtError( e:UncaughtErrorEvent ) {

		Logger.fatal( '${e}' );

	}

	override function initialize() {

		super.initialize();

		Theme.setTheme( new SuperHumanInstallerTheme( #if lighttheme ThemeMode.Light #end ) );

		this._header.logo = GenesisApplicationTheme.getAssetPath( SuperHumanInstallerTheme.IMAGE_ICON );

		_loadingPage = new LoadingPage();
		this.addPage( _loadingPage, 0, PAGE_LOADING );

		_serverPage = new ServerPage( _servers, SuperHumanGlobals.MAXIMUM_ALLOWED_SERVERS );
		_serverPage.addEventListener( SuperHumanApplicationEvent.CONFIGURE_SERVER, _configureServer );
		_serverPage.addEventListener( SuperHumanApplicationEvent.COPY_TO_CLIPBOARD, _copyToClipboard );
		_serverPage.addEventListener( SuperHumanApplicationEvent.CREATE_SERVER, _createServer );
		_serverPage.addEventListener( SuperHumanApplicationEvent.DELETE_SERVER, _deleteServer );
		_serverPage.addEventListener( SuperHumanApplicationEvent.DESTROY_SERVER, _destroyServer );
		_serverPage.addEventListener( SuperHumanApplicationEvent.DOWNLOAD_VAGRANT, _downloadVagrant );
		_serverPage.addEventListener( SuperHumanApplicationEvent.DOWNLOAD_VIRTUALBOX, _downloadVirtualBox );
		_serverPage.addEventListener( SuperHumanApplicationEvent.OPEN_BROWSER, _openBrowser );
		_serverPage.addEventListener( SuperHumanApplicationEvent.OPEN_SERVER_DIRECTORY, _openServerDir );
		_serverPage.addEventListener( SuperHumanApplicationEvent.OPEN_VAGRANT_SSH, _openVagrantSSH );
		_serverPage.addEventListener( SuperHumanApplicationEvent.OPEN_VIRTUALBOX_GUI, _openVirtualBoxGUI );
		_serverPage.addEventListener( SuperHumanApplicationEvent.PROVISION_SERVER, _provisionServer );
		_serverPage.addEventListener( SuperHumanApplicationEvent.REFRESH_SYSTEM_INFO, _refreshSystemInfo );
		_serverPage.addEventListener( SuperHumanApplicationEvent.START_SERVER, _startServer );
		_serverPage.addEventListener( SuperHumanApplicationEvent.STOP_SERVER, _stopServer );
		_serverPage.addEventListener( SuperHumanApplicationEvent.SYNC_SERVER, _syncServer );
		this.addPage( _serverPage, PAGE_SERVER );

		_helpPage = new HelpPage();
		this.addPage( _helpPage, PAGE_HELP );

		_configPage = new ConfigPage();
		_configPage.addEventListener( SuperHumanApplicationEvent.ADVANCED_CONFIGURE_SERVER, _advancedConfigureServer );
		_configPage.addEventListener( SuperHumanApplicationEvent.CANCEL_PAGE, _cancelConfigureServer );
		_configPage.addEventListener( SuperHumanApplicationEvent.CONFIGURE_ROLES, _configureRoles );
		_configPage.addEventListener( SuperHumanApplicationEvent.SAVE_SERVER_CONFIGURATION, _saveServerConfiguration );
		this.addPage( _configPage, PAGE_CONFIG );

		_advancedConfigPage = new AdvancedConfigPage();
		_advancedConfigPage.addEventListener( SuperHumanApplicationEvent.CANCEL_PAGE, _cancelAdvancedConfigureServer );
		_advancedConfigPage.addEventListener( SuperHumanApplicationEvent.SAVE_ADVANCED_SERVER_CONFIGURATION, _saveAdvancedServerConfiguration );
		this.addPage( _advancedConfigPage, PAGE_CONFIG_ADVANCED );

		_settingsPage = new SettingsPage();
		_settingsPage.addEventListener( SuperHumanApplicationEvent.CANCEL_PAGE, _cancelSettings );
		_settingsPage.addEventListener( SuperHumanApplicationEvent.SAVE_APP_CONFIGURATION, _saveAppConfiguration );
		this.addPage( _settingsPage, PAGE_SETTINGS );

		_rolePage = new RolePage();
		_rolePage.addEventListener( SuperHumanApplicationEvent.CLOSE_ROLES, _closeRolePage );
		this.addPage( _rolePage, PAGE_ROLES );

		_navigator.validateNow();
		this.selectedPageId = PAGE_LOADING;

		_appCheckerOverlay = new LayoutGroup();
		_appCheckerOverlay.variant = SuperHumanInstallerTheme.LAYOUT_GROUP_APP_CHECKER_OVERLAY;
		this.addChild( _appCheckerOverlay );

		_header.addMenuItem( LanguageManager.getInstance().getString( 'mainmenu.servers' ), PAGE_SERVER, 0 );
		_header.addMenuItem( LanguageManager.getInstance().getString( 'mainmenu.help' ), PAGE_HELP, 1 );
		_header.addMenuItem( LanguageManager.getInstance().getString( 'mainmenu.settings' ), PAGE_SETTINGS );

		Vagrant.getInstance().onInit.add( _vagrantInitialized );
		Vagrant.getInstance().onDestroy.add( _vagrantDestroyed );
		Vagrant.getInstance().onUp.add( _vagrantUped );
		VirtualBox.getInstance().onInit.add( _virtualBoxInitialized );
		ParallelExecutor.create().add( Right([ Vagrant.getInstance().getInit(), VirtualBox.getInstance().getInit() ]) ).onStop( _checkAppsInitialized ).execute();

	}

	function _checkAppsInitialized( executor:AbstractExecutor ) {

		if( Vagrant.getInstance().initialized && VirtualBox.getInstance().initialized ) {

			if ( VirtualBox.getInstance().exists && Vagrant.getInstance().exists ) {

				Vagrant.getInstance().onGlobalStatus.add( _vagrantGlobalStatusFinished ).onVersion.add( _vagrantVersionUpdated );
				VirtualBox.getInstance().onVersion.add( _virtualBoxVersionUpdated ).onListVMs.add( _virtualBoxListVMsUpdated );

				ParallelExecutor.create().add( Right( [
					Vagrant.getInstance().getVersion(), Vagrant.getInstance().getGlobalStatus( SuperHumanGlobals.PRUNE_VAGRANT_MACHINES ),
					VirtualBox.getInstance().getBridgedInterfaces(), VirtualBox.getInstance().getHostInfo(), VirtualBox.getInstance().getVersion(), VirtualBox.getInstance().getListVMs()
				] ) ).onStop( _checkPrerequisitesFinished ).execute();

			} else {

				_checkPrerequisitesFinished();

			}

		}

	}

	function _vagrantInitialized( a:AbstractApp ) {

		_serverPage.vagrantInstalled = Vagrant.getInstance().exists;

		if ( Vagrant.getInstance().exists ) {

			Logger.debug( 'Vagrant is installed at ${Vagrant.getInstance().path}' );

		} else {

			Logger.warning( 'Vagrant is not installed' );

		}

	}

	function _vagrantGlobalStatusFinished() {

		Vagrant.getInstance().onGlobalStatus.remove( _vagrantGlobalStatusFinished );

		for ( i in Vagrant.getInstance().machines ) {

			for ( s in _servers ) {

				if ( s.path.value == i.home ) {

					s.vagrantMachine.value = i;
					s.vagrantMachine.value.serverId = s.id;

				}

			}

		}

		if ( _serverPage != null ) _serverPage.vagrantMachines = Vagrant.getInstance().machines;

	}

	function _vagrantVersionUpdated() {

		Logger.info( 'Vagrant version: ${Vagrant.getInstance().version}' );
		_serverPage.vagrantVersion = Vagrant.getInstance().version;

	}

	function _virtualBoxInitialized( a:AbstractApp ) {

		_serverPage.virtualBoxInstalled = VirtualBox.getInstance().exists;

		if ( VirtualBox.getInstance().exists ) {

			Logger.debug( 'VirtualBox is installed at ${VirtualBox.getInstance().path}' );

		} else {

			Logger.warning( 'VirtualBox is not installed' );

		}

	}

	function _virtualBoxVersionUpdated() {

		Logger.info( 'VirtualBox version: ${VirtualBox.getInstance().version}' );

	}

	function _virtualBoxListVMsUpdated() {

		VirtualBox.getInstance().onListVMs.remove( _virtualBoxListVMsUpdated );

		for ( i in VirtualBox.getInstance().virtualMachines ) {

			for ( s in _servers ) {

				if ( s.virtualBoxId == i.name ) s.virtualMachine.value = i;

			}

		}

		if ( _serverPage != null ) _serverPage.virtualBoxMachines = VirtualBox.getInstance().virtualMachines;

	}

	function _advancedConfigureServer( e:SuperHumanApplicationEvent ) {
		
		_advancedConfigPage.setServer( e.server );
		_advancedConfigPage.updateContent();
		this.selectedPageId = PAGE_CONFIG_ADVANCED;

	}

	function _configureServer( e:SuperHumanApplicationEvent ) {

		_showConfigureServer( e.server );

	}

	function _showConfigureServer( server:Server ) {

		_configPage.setServer( server );
		_configPage.updateContent( true );
		this.selectedPageId = PAGE_CONFIG;

	}

	function _cancelConfigureServer( e:SuperHumanApplicationEvent ) {

		this.selectedPageId = PAGE_SERVER;

	}

	function _cancelAdvancedConfigureServer( e:SuperHumanApplicationEvent ) {

		this.selectedPageId = PAGE_CONFIG;

	}

	function _cancelSettings( e:SuperHumanApplicationEvent ) {

		this.selectedPageId = this.previousPageId;

	}

	function _saveAppConfiguration( e:SuperHumanApplicationEvent ) {

		_saveConfig();
		this.selectedPageId = this.previousPageId;
		ToastManager.getInstance().showToast( LanguageManager.getInstance().getString( 'toast.settingssaved' ) );

	}

	function _downloadVagrant( e:SuperHumanApplicationEvent ) {

		Shell.getInstance().open( [ SuperHumanGlobals.VAGRANT_DOWNLOAD_URL ] );

	}

	function _downloadVirtualBox( e:SuperHumanApplicationEvent ) {

		Shell.getInstance().open( [ SuperHumanGlobals.VIRTUALBOX_DOWNLOAD_URL ] );
		
	}

	override function _onExit( exitCode:Int ) {

		super._onExit( exitCode );

		_config.preferences.windowx = this._window.x;
		_config.preferences.windowy = this._window.y;
		_config.preferences.windowwidth = this._window.width;
		_config.preferences.windowheight = this._window.height;

		_saveConfig();

		_canExit = false;

		if ( !_config.preferences.keepserversrunning && VirtualBox.getInstance().exists && Vagrant.getInstance().exists ) {

			Logger.debug( 'Shutting down server...' );

			// Stop all possibly running executors
			var vms:Array<VagrantMachine> = [];
			for ( s in _servers ) vms.push( s.vagrantMachine.value );
			Vagrant.getInstance().stopAll( false, vms );

			while( !_canExit ) {

				for ( server in _servers ) {

					// Shutting down VirtualBox machine
					var vboxArgs:Array<String> = [ 'controlvm' ];
					vboxArgs.push( server.virtualBoxId );
					vboxArgs.push( 'poweroff' );
					Sys.command( VirtualBox.getInstance().path + VirtualBox.getInstance().executable, vboxArgs );

					// Shutting down Vagrant machine
					var vagrantArgs:Array<String> = [ 'halt' ];
					if ( server.vagrantMachine.value != null && server.vagrantMachine.value.id != null ) {
						vagrantArgs.push( server.vagrantMachine.value.id );
					} else {
						Sys.setCwd( server.path.value );
					}
					Sys.command( Vagrant.getInstance().path + Vagrant.getInstance().executable, vagrantArgs );

				}

				// Wait 1s before exit
				Sys.sleep( 1 );
				_canExit = true;

			}

		}

	}

	override function _onWindowFocusIn() {

		super._onWindowFocusIn();

		if ( !SuperHumanGlobals.CHECK_VAGRANT_STATUS_ON_FOCUS ) return;

		if ( !Vagrant.getInstance().exists ) return;

		for ( server in _servers ) server.refreshVagrantStatus();

	}

	override function _onWindowFocusOut() {

		super._onWindowFocusOut();

	}

	override function _onWindowResize( w:Int, h:Int ) {

		super._onWindowResize( w, h );

		if ( w < SuperHumanInstallerTheme.APPLICATION_MIN_WIDTH ) _window.width = SuperHumanInstallerTheme.APPLICATION_MIN_WIDTH;
		if ( h < SuperHumanInstallerTheme.APPLICATION_MIN_HEIGHT ) _window.height = SuperHumanInstallerTheme.APPLICATION_MIN_HEIGHT;

	}

	function _openVagrantSSH( e:SuperHumanApplicationEvent ) {

		e.server.openVagrantSSH();

	}

	function _openBrowser( e:SuperHumanApplicationEvent ) {

		var a = e.server.webAddress;

		if ( a == null || a.length == 0 ) {

			if ( e.server.console != null ) e.server.console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.webaddressinvalid', '[${a}]' ), true );
			return;

		}

		Shell.getInstance().open( [ '${a}' ] );

	}

	function _saveConfig() {

		_config.servers = [];

		for ( server in _servers ) {

			_config.servers.push( server.getData() );

		}

		File.saveContent( '${System.applicationStorageDirectory}${_CONFIG_FILE}', Json.stringify( _config, ( SuperHumanGlobals.PRETTY_PRINT ) ? "\t" : null ) );
		Logger.debug( 'Configuration saved to: ${System.applicationStorageDirectory}${_CONFIG_FILE}' );

	}

	function _saveServerConfiguration( e:SuperHumanApplicationEvent ) {

		e.server.saveHostsFile();
		_saveConfig();
		
		ToastManager.getInstance().showToast( LanguageManager.getInstance().getString( 'toast.serverconfigsaved' ) );
		this.selectedPageId = PAGE_SERVER;

	}

	function _configureRoles( e:SuperHumanApplicationEvent ) {

		_rolePage.setServer( e.server );
		_rolePage.updateContent();
		this.selectedPageId = PAGE_ROLES;

	}

	function _closeRolePage( e:SuperHumanApplicationEvent ) {

		this.selectedPageId = this.previousPageId;
		_configPage.updateContent();

	}

	function _saveAdvancedServerConfiguration( e:SuperHumanApplicationEvent ) {

		e.server.saveHostsFile();
		_saveConfig();

		ToastManager.getInstance().showToast( LanguageManager.getInstance().getString( 'toast.advancedserverconfigsaved' ) );
		this.selectedPageId = PAGE_CONFIG;

	}

	function _startServer( e:SuperHumanApplicationEvent ) {

		if ( _cpuArchitecture == CPUArchitecture.Arm64 ) {

			Logger.info( 'CPU Architecture ${_cpuArchitecture} is not supported' );
			_showCPUArchitectureNotSupportedWarning();
			return;

		}

		Logger.info( 'Starting server: ${e.server.id}' );
		Logger.info( 'Server configuration: ${e.server.getData()}' );
		Logger.info( 'VirtualBox VM: ${e.server.virtualMachine.value}' );
		Logger.verbose( '\n----- Hosts.yml START -----\n${e.server.generateHostsFileContent()}\n----- Hosts.yml END -----' );

		// TODO: Decide how to handle provisioning if required
		// e.server.start( _config.preferences.provisionserversonstart );
		e.server.start();

	}

	function _stopServer( e:SuperHumanApplicationEvent ) {

		e.server.stop();

	}

	function _checkPrerequisitesFinished( ?executor:AbstractExecutor ) {

		if ( executor != null ) executor.dispose();

		if ( this.selectedPageId != PAGE_LOADING ) return;

		if( Vagrant.getInstance().initialized && VirtualBox.getInstance().initialized ) {

			if ( !Vagrant.getInstance().exists || !VirtualBox.getInstance().exists ) {

				_loadingPage.stopProgressIndicator();
				this.selectedPageId = PAGE_SERVER;
				_header.menuEnabled = true;
				return;

			}

			if ( Vagrant.getInstance().exists && Vagrant.getInstance().version != null && Vagrant.getInstance().metadata != null && VirtualBox.getInstance().exists && VirtualBox.getInstance().hostInfo != null && VirtualBox.getInstance().bridgedInterfaces != null ) {

				_header.menuEnabled = true;

				var build:String = #if neko "Neko" #elseif cpp "Native" #else "Unsupported" #end;
				var isDebug:String = #if debug "Debug | " #else "" #end;
				var ram:Float = StrTools.toPrecision( VirtualBox.getInstance().hostInfo.memorysize, 2, false );
				_footer.sysInfo = '${build} | ${isDebug}${Capabilities.os} | ${_cpuArchitecture} | Cores:${VirtualBox.getInstance().hostInfo.processorcorecount} | RAM: ${ram}GB | Vagrant: ${Vagrant.getInstance().version} | VirtualBox:${VirtualBox.getInstance().version}';

				Logger.debug( 'Vagrant machines: ${Vagrant.getInstance().machines}' );
				Logger.debug( 'VirtualBox hostinfo: ${VirtualBox.getInstance().hostInfo}' );
				Logger.debug( 'VirtualBox bridgedInterfaces: ${VirtualBox.getInstance().bridgedInterfaces}' );
				Logger.debug( 'VirtualBox vms: ${VirtualBox.getInstance().virtualMachines}' );

				_loadingPage.stopProgressIndicator();

				for ( server in _servers ) {

					if ( server.vagrantMachine.value.id == null ) server.refresh();
					if ( server.virtualBoxId != null ) server.refreshVirtualBoxInfo();
					
				}

				this.selectedPageId = PAGE_SERVER;

			}

		}
		
	}

	public function onServerPropertyChanged( server:Server, ?saveRequired:Bool ) {

		if( saveRequired ) _saveConfig();

		switch ( server.status.value ) {

			case ServerStatus.Stopping | ServerStatus.Initializing | ServerStatus.FirstStart | ServerStatus.Running:
				_header.updateButtonEnabled = false;

			default:
				_header.updateButtonEnabled = true;

		}

	}

	override function _updateFound(e:Event) {

		super._updateFound( e );

	}

	function _openServerDir( e:SuperHumanApplicationEvent ) {

		Shell.getInstance().open( [ e.server.path.value ] );
		Shell.getInstance().openTerminal( e.server.path.value );

	}

	function _syncServer( e:SuperHumanApplicationEvent ) {

		e.server.rsync();

	}

	function _provisionServer( e:SuperHumanApplicationEvent ) {

		e.server.provision();

	}

	function _destroyServer( e:SuperHumanApplicationEvent ) {

		Alert.show(

			LanguageManager.getInstance().getString( 'alert.destroyserver.text' ),
			LanguageManager.getInstance().getString( 'alert.destroyserver.title' ),
			[ LanguageManager.getInstance().getString( 'alert.destroyserver.buttonok' ), LanguageManager.getInstance().getString( 'alert.destroyserver.buttoncancel' ) ],
			( state ) -> {

			switch ( state.index ) {

				case 0:
					e.server.destroy();

				default:

			}

		} );
		
	}

	function _vagrantDestroyed( machine:VagrantMachine ) {

		ToastManager.getInstance().showToast( LanguageManager.getInstance().getString( 'toast.serverdestroyed' ) );
		_saveConfig();

	}

	function _vagrantUped( machine:VagrantMachine, exitCode:Float ) {

		if ( exitCode == 0 ) {

			ToastManager.getInstance().showToast( LanguageManager.getInstance().getString( 'toast.serverstarted' ) );

		} else {

			ToastManager.getInstance().showToast( LanguageManager.getInstance().getString( 'toast.servererror' ) );

		}

	}

	override function _pageChanged() {

		super._pageChanged();

		if ( _selectedPageId == PAGE_SETTINGS ) _settingsPage.updateData();

	}

	function _deleteServer( e:SuperHumanApplicationEvent ) {

		Alert.show(
			LanguageManager.getInstance().getString( 'alert.deleteserver.text' ),
			LanguageManager.getInstance().getString( 'alert.deleteserver.title' ),
			[
				LanguageManager.getInstance().getString( 'alert.deleteserver.buttondelete' ),
				LanguageManager.getInstance().getString( 'alert.deleteserver.buttondeletefiles' ),
				LanguageManager.getInstance().getString( 'alert.deleteserver.buttoncancel' )
			],
			( state ) -> {

				switch state.index {

					case 0:
						_deleteServerInstance( e.server );

					case 1:
						_deleteServerInstance( e.server, true );

					default:

				}

			}
		);

	}

	function _deleteServerInstance( server:Server, deleteFiles:Bool = false ) {

		Logger.debug( 'Deleting server ${server.id} deleteFiles:${deleteFiles}' );

		server.dispose();
		_servers.remove( server );
		
		if ( deleteFiles ) {

			FileTools.deleteDirectory( server.path.value );

		}

		ToastManager.getInstance().showToast( LanguageManager.getInstance().getString( 'toast.serverdeleted' ) );

		_saveConfig();

	}

	function _createServer( e:SuperHumanApplicationEvent ) {

		var newServerData:ServerData = ServerManager.getDefaultServerData( e.provisionerType );

		var server = Server.create( newServerData, ServerManager.serverRootDirectory );
		server.onUpdate.add( onServerPropertyChanged );
		_servers.add( server );

		ToastManager.getInstance().showToast( LanguageManager.getInstance().getString( 'toast.servercreated', 'with id ${server.id}' ) );

		_saveConfig();

		_showConfigureServer( server );

	}

	function _copyToClipboard( e:SuperHumanApplicationEvent ) {

		if ( e.data != null ) {

			openfl.system.System.setClipboard( e.data );
			ToastManager.getInstance().showToast( LanguageManager.getInstance().getString( 'toast.copiedtoclipboard' ) );

		}

	}

	function _showCPUArchitectureNotSupportedWarning() {

		Alert.show(
			LanguageManager.getInstance().getString( 'alert.notsupportedcpu.text', Std.string( _cpuArchitecture ) ),
			LanguageManager.getInstance().getString( 'alert.notsupportedcpu.title' ),
			[ LanguageManager.getInstance().getString( 'alert.notsupportedcpu.buttonok' ) ]
		);

	}

	override function _visitSourceCode(?e:Dynamic) {

		super._visitSourceCode(e);

		System.openURL( SuperHumanGlobals.SOURCE_CODE_URL );

	}

	function _openVirtualBoxGUI( e:SuperHumanApplicationEvent ) {

		VirtualBox.getInstance().openGUI();

	}

	function _refreshSystemInfo( e:SuperHumanApplicationEvent ) {

		Logger.verbose( 'Refreshing System Info...' );

		ParallelExecutor.create().add( Right( [
			Vagrant.getInstance().getGlobalStatus(),
			VirtualBox.getInstance().getListVMs()
		] ) ).onStop( _refreshSystemInfoStopped ).execute();

	}

	function _refreshSystemInfoStopped( executor:AbstractExecutor ) {

		Logger.verbose( 'System Info refreshed' );
		Logger.verbose( 'Vagrant machines: ${Vagrant.getInstance().machines}' );
		Logger.verbose( 'VirtualBox machines: ${VirtualBox.getInstance().virtualMachines}' );

		for ( i in VirtualBox.getInstance().virtualMachines ) {

			for ( s in _servers ) {

				if ( s.virtualBoxId == i.name ) s.virtualMachine.value = i;

			}

		}

		for ( i in Vagrant.getInstance().machines ) {

			for ( s in _servers ) {

				if ( s.path.value == i.home ) {

					s.updateVagrantMachine( i );

				}

			}

		}

		if ( _serverPage != null ) {

			_serverPage.vagrantMachines = Vagrant.getInstance().machines;
			_serverPage.virtualBoxMachines = VirtualBox.getInstance().virtualMachines;

		}

	}

}
