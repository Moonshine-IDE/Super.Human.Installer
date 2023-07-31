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

import genesis.application.events.GenesisApplicationEvent;
import cpp.NativeSys;
import haxe.io.Path;
import superhuman.components.browsers.SetupBrowserPage;
import superhuman.browser.Browsers;
import superhuman.components.browsers.BrowsersPage;
import superhuman.config.SuperHumanHashes;
import champaign.core.logging.Logger;
import feathers.controls.Alert;
import feathers.controls.LayoutGroup;
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
import prominic.sys.applications.AbstractApp;
import prominic.sys.applications.bin.Shell;
import prominic.sys.applications.hashicorp.Vagrant;
import prominic.sys.applications.oracle.VirtualBox;
import prominic.sys.io.AbstractExecutor;
import prominic.sys.io.ExecutorManager;
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
import superhuman.server.CombinedVirtualMachine;
import superhuman.server.Server;
import superhuman.server.ServerStatus;
import superhuman.server.data.RoleData;
import superhuman.browser.BrowserData;
import superhuman.server.data.ServerData;
import superhuman.server.roles.ServerRoleImpl;
import superhuman.theme.SuperHumanInstallerTheme;
import sys.FileSystem;
import sys.io.File;

using champaign.core.tools.ObjectTools;

class SuperHumanInstaller extends GenesisApplication {

	static final _CONFIG_FILE:String = ".shi-config";
	static final _DOMINO_VAGRANT_VERSION_FILE:String = "version.rb";

	static final _TEXT_LINK_DEVOPS:String = "DevOps";
	static final _TEXT_LINK_DOMINO:String = "Domino";
	static final _TEXT_LINK_GENESIS_DIRECTORY:String = "GenesisDirectory";
	static final _TEXT_LINK_VAGRANT:String = "Vagrant";
	static final _TEXT_LINK_VIRTUALBOX:String = "VirtualBox";
	static final _TEXT_LINK_YAML:String = "YAML";

	static public final PAGE_CONFIG = "page-config";
	static public final PAGE_CONFIG_ADVANCED = "page-config-advanced";
	static public final PAGE_HELP = "page-help";
	static public final PAGE_LOADING = "page-loading";
	static public final PAGE_ROLES = "page-roles";
	static public final PAGE_SERVER = "page-server";
	static public final PAGE_SETTINGS = "page-settings";
	static public final PAGE_BROWSERS = "page-browsers";
	static public final PAGE_SETUP_BROWSERS = "page-setup-browsers";

	static public final DEMO_TASKS_PATH:String = "assets/vagrant/demo-tasks/";

	static var _instance:SuperHumanInstaller;

	public static function getInstance():SuperHumanInstaller {

		return _instance;

	}
	
	final _defaultConfig:SuperHumanConfig = {
		
		servers : [],
		user: {},
		preferences: { keepserversrunning: true, savewindowposition: false, provisionserversonstart:false, disablevagrantlogging: false, keepfailedserversrunning: false },
		browsers: Browsers.DEFAULT_BROWSERS_LIST
	}

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
	var _settingsPage:SettingsPage;
	var _vagrantFile:String;
	var _browsersPage:BrowsersPage;
	var _setupBrowserPage:SetupBrowserPage;
	var _browsersCollection:Array<BrowserData>;

	public var config( get, never ):SuperHumanConfig;
	function get_config() return _config;

	public var defaultRoles( get, never ):Map<String, RoleData>;
	function get_defaultRoles() return _defaultRoles;

	public var serverRolesCollection( get, never ):Array<ServerRoleImpl>;
	function get_serverRolesCollection() return _serverRolesCollection;

	public function new() {

		super( #if showlogin true #end );

		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener( UncaughtErrorEvent.UNCAUGHT_ERROR, _uncaughtError );

		_instance = this;
		_updaterAddress = SuperHumanGlobals.UPDATER_ADDRESS;

		Logger.info( '${this}: Bundled Provisioners: ${ProvisionerManager.getBundledProvisioners()}' );

		ServerManager.getInstance().serverRootDirectory = System.applicationStorageDirectory + "servers/";

		_defaultRoles = superhuman.server.provisioners.DemoTasks.getDefaultProvisionerRoles();

		var dominoHashes:Array<String> = SuperHumanHashes.getInstallersHashes("domino");
		var dominoHotFixHashes:Array<String> = SuperHumanHashes.getHotFixesHashes("domino");
		var dominoFixPacksHashes:Array<String> = SuperHumanHashes.getFixPacksHashes("domino");
		var nomadWebHashes:Array<String> = SuperHumanHashes.getInstallersHashes("nomadweb");
		var leapHashes:Array<String> = SuperHumanHashes.getInstallersHashes("leap");
		var travelerHashes:Array<String> = SuperHumanHashes.getInstallersHashes("traveler");
		var verseHashes:Array<String> = SuperHumanHashes.getInstallersHashes("verse");
		var appdevpackHashes:Array<String> = SuperHumanHashes.getInstallersHashes("appdevpack");
		var restApiHashes:Array<String> = SuperHumanHashes.getInstallersHashes("domino-rest-api");
		
		_serverRolesCollection = [

			new ServerRoleImpl( "Domino", LanguageManager.getInstance().getString( 'rolepage.roles.domino.desc' ), _defaultRoles.get( "domino" ), dominoHashes, dominoHotFixHashes, dominoFixPacksHashes, "(Domino_12.0.2_Linux_English.tar)" ),
						new ServerRoleImpl( "NomadWeb", LanguageManager.getInstance().getString( 'rolepage.roles.nomadweb.desc' ), _defaultRoles.get( "nomadweb" ), nomadWebHashes, "(nomad-server-1.0.8-for-domino-1202-linux.tgz)" ),
			new ServerRoleImpl( "Leap (formerly Volt)", LanguageManager.getInstance().getString( 'rolepage.roles.leap.desc' ), _defaultRoles.get( "leap" ), leapHashes, "(Leap-1.0.5.zip)" ),
			new ServerRoleImpl( "Traveler", LanguageManager.getInstance().getString( 'rolepage.roles.traveler.desc' ), _defaultRoles.get( "traveler" ), travelerHashes, "(Traveler_12.0.2FP1_Linux_ML.tar.gz)" ),
			new ServerRoleImpl( "Verse", LanguageManager.getInstance().getString( 'rolepage.roles.verse.desc' ), _defaultRoles.get( "verse" ), verseHashes, "(HCL_Verse_3.0.0.zip)" ),
			new ServerRoleImpl( "AppDev Pack for Node.js", LanguageManager.getInstance().getString( 'rolepage.roles.appdevpack.desc' ), _defaultRoles.get( "appdevpack" ), appdevpackHashes, "(domino-appdev-pack-1.0.15.tgz)" ),
			new ServerRoleImpl( "Domino REST API", LanguageManager.getInstance().getString( 'rolepage.roles.domino-rest-api.desc' ), _defaultRoles.get( "domino-rest-api" ), restApiHashes, "(Domino_REST_API_V1_Installer.tar.gz)" ),

		];

		if ( FileSystem.exists( '${System.applicationStorageDirectory}${_CONFIG_FILE}' ) ) {

			try {

				var content = File.getContent( '${System.applicationStorageDirectory}${_CONFIG_FILE}' );
				_config = Json.parse( content );

			} catch ( e ) {

				_config = _defaultConfig;

			}

			if ( _config.user == null ) _config.user = {};
			if ( _config.preferences == null ) _config.preferences = { keepserversrunning: true, savewindowposition: false, provisionserversonstart:false };
			if ( _config.preferences.keepserversrunning == null ) _config.preferences.keepserversrunning = true;
			if ( _config.preferences.savewindowposition == null ) _config.preferences.savewindowposition = false;
			if ( _config.preferences.provisionserversonstart == null ) _config.preferences.provisionserversonstart = false;
			if ( _config.preferences.disablevagrantlogging == null ) _config.preferences.disablevagrantlogging = false;
			if ( _config.preferences.keepfailedserversrunning == null ) _config.preferences.keepfailedserversrunning = false;

			var a:Array<String> = [];
			for ( r in _defaultRoles ) a.push( r.value );

			var b:Array<String> = [];
			for ( s in _config.servers ) {

				b = [];
				for( r in s.roles ) b.push( r.value );
				
				for ( v in a ) if ( !b.contains( v ) ) s.roles.push( _defaultRoles.get( v ) );

			}
			
			if (_config.browsers == null) {
				_config.browsers = _defaultConfig.browsers;
			}
			
		} else {

			_config = _defaultConfig;
			File.saveContent( '${System.applicationStorageDirectory}${_CONFIG_FILE}', Json.stringify( _config ) );

		}

		for ( s in _config.servers ) {

			var server = ServerManager.getInstance().createServer( s );
			server.onUpdate.add( onServerPropertyChanged );

		}

		if ( _config.preferences.savewindowposition ) {

			if ( _config.preferences.windowx != null ) this._window.x = _config.preferences.windowx;
			if ( _config.preferences.windowy != null ) this._window.y = _config.preferences.windowy;
			if ( _config.preferences.windowwidth != null ) this._window.width = _config.preferences.windowwidth;
			if ( _config.preferences.windowheight != null ) this._window.height = _config.preferences.windowheight;

			if ( this._window.x < 0 ) this._window.x = 0;
			if ( this._window.y < 0 ) this._window.y = 0;

		}

		Server.keepFailedServersRunning = _config.preferences.keepfailedserversrunning;
		Shell.getInstance().findProcessId( 'SuperHumanInstaller', null, _processIdFound );

	}

	function _processIdFound( result:Array<ProcessInfo> ) {

		if ( result != null && result.length > 0 ) {

			_processId = result[ 0 ].pid;
			Logger.debug( '${this}: SuperHumanInstaller process id found: ${_processId}' );

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

		Logger.fatal( '${this}: Fatal error: ${e}' );

	}

	override function initialize() {

		super.initialize();

		Theme.setTheme( new SuperHumanInstallerTheme( #if lighttheme ThemeMode.Light #end ) );

		this._header.logo = GenesisApplicationTheme.getAssetPath( SuperHumanInstallerTheme.IMAGE_ICON );

		ExecutorManager.getInstance().onExecutorListChanged.add( _onExecutorListChanged );

		_loadingPage = new LoadingPage();
		this.addPage( _loadingPage, 0, PAGE_LOADING );

		_serverPage = new ServerPage( ServerManager.getInstance().servers, SuperHumanGlobals.MAXIMUM_ALLOWED_SERVERS );
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
		_serverPage.addEventListener( SuperHumanApplicationEvent.SUSPEND_SERVER, _suspendServer );
		_serverPage.addEventListener( SuperHumanApplicationEvent.SYNC_SERVER, _syncServer );
		this.addPage( _serverPage, PAGE_SERVER );

		_helpPage = new HelpPage();
		_helpPage.addEventListener( SuperHumanApplicationEvent.TEXT_LINK, _helpPageTextLink );
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
		_settingsPage.addEventListener( SuperHumanApplicationEvent.OPEN_BROWSERS_SETUP, _openBrowsersSetup );
		_settingsPage.addEventListener( SuperHumanApplicationEvent.CANCEL_PAGE, _cancelSettings );
		_settingsPage.addEventListener( SuperHumanApplicationEvent.SAVE_APP_CONFIGURATION, _saveAppConfiguration );
		this.addPage( _settingsPage, PAGE_SETTINGS );

		_rolePage = new RolePage();
		_rolePage.addEventListener( SuperHumanApplicationEvent.CLOSE_ROLES, _closeRolePage );
		this.addPage( _rolePage, PAGE_ROLES );

		_browsersPage = new BrowsersPage();
		_browsersPage.addEventListener(SuperHumanApplicationEvent.SETUP_BROWSER, _setBrowserPage);
		_browsersPage.addEventListener( SuperHumanApplicationEvent.CLOSE_BROWSERS, _closeBrowsersPage );
		_browsersPage.addEventListener( SuperHumanApplicationEvent.REFRESH_DEFAULT_BROWSER, _refreshDefaultBrowser);
		_browsersPage.addEventListener( SuperHumanApplicationEvent.REFRESH_BROWSERS_PAGE, _refreshBrowsersPage);
		this.addPage( _browsersPage, PAGE_BROWSERS );
		
		_setupBrowserPage = new SetupBrowserPage();
		_setupBrowserPage.addEventListener( SuperHumanApplicationEvent.REFRESH_DEFAULT_BROWSER, _refreshDefaultBrowser);
		_setupBrowserPage.addEventListener( SuperHumanApplicationEvent.REFRESH_BROWSERS_PAGE, _refreshBrowsersPage);
		_setupBrowserPage.addEventListener( SuperHumanApplicationEvent.CLOSE_BROWSERS_SETUP, _closeSetupBrowserPage );
		this.addPage( _setupBrowserPage, PAGE_SETUP_BROWSERS );
		
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
		ParallelExecutor.create().add( Vagrant.getInstance().getInit(), VirtualBox.getInstance().getInit() ).onStop.add( _checkAppsInitialized ).execute();

	}

	function _checkAppsInitialized( executor:AbstractExecutor ) {

		if( Vagrant.getInstance().initialized && VirtualBox.getInstance().initialized ) {

			if ( VirtualBox.getInstance().exists && Vagrant.getInstance().exists ) {

				Vagrant.getInstance().onGlobalStatus.add( _vagrantGlobalStatusFinished ).onVersion.add( _vagrantVersionUpdated );
				VirtualBox.getInstance().onVersion.add( _virtualBoxVersionUpdated ).onListVMs.add( _virtualBoxListVMsUpdated );

				var pe = ParallelExecutor.create();
				pe.add( 
					Vagrant.getInstance().getVersion(),
					VirtualBox.getInstance().getBridgedInterfaces(),
					VirtualBox.getInstance().getHostInfo(),
					VirtualBox.getInstance().getVersion(),
					VirtualBox.getInstance().getListVMs( true )
				 );
				if ( !SuperHumanGlobals.IGNORE_VAGRANT_STATUS ) pe.add( Vagrant.getInstance().getGlobalStatus( SuperHumanGlobals.PRUNE_VAGRANT_MACHINES ) );
				pe.onStop.add( _checkPrerequisitesFinished ).execute();

			} else {

				_checkPrerequisitesFinished();

			}

		}

	}

	function _vagrantInitialized( a:AbstractApp ) {

		_serverPage.vagrantInstalled = Vagrant.getInstance().exists;

		if ( Vagrant.getInstance().exists ) {

			Logger.debug( '${this}: Vagrant is installed at ${Vagrant.getInstance().path}' );

		} else {

			Logger.warning( '${this}: Vagrant is not installed' );

		}

	}

	function _vagrantGlobalStatusFinished() {

		Vagrant.getInstance().onGlobalStatus.remove( _vagrantGlobalStatusFinished );

		for ( i in Vagrant.getInstance().machines ) {

			for ( s in ServerManager.getInstance().servers ) {

				if ( s.path.value == i.home ) s.setVagrantMachine( i );

			}

		}

		if ( _serverPage != null ) _serverPage.vagrantMachines = Vagrant.getInstance().machines;

	}

	function _vagrantVersionUpdated() {

		Logger.info( '${this}: Vagrant version: ${Vagrant.getInstance().version}' );
		_serverPage.vagrantVersion = Vagrant.getInstance().version;

	}

	function _virtualBoxInitialized( a:AbstractApp ) {

		_serverPage.virtualBoxInstalled = VirtualBox.getInstance().exists;

		if ( VirtualBox.getInstance().exists ) {

			Logger.debug( '${this}: VirtualBox is installed at ${VirtualBox.getInstance().path}' );

		} else {

			Logger.warning( '${this}: VirtualBox is not installed' );

		}

	}

	function _virtualBoxVersionUpdated() {

		Logger.info( '${this}: VirtualBox version: ${VirtualBox.getInstance().version}' );

	}

	function _virtualBoxListVMsUpdated() {

		VirtualBox.getInstance().onListVMs.remove( _virtualBoxListVMsUpdated );

		Logger.debug( '${this}: VirtualBox machines: ${VirtualBox.getInstance().virtualBoxMachines}' );

		for ( s in ServerManager.getInstance().servers ) {

			s.combinedVirtualMachine.value.virtualBoxMachine = {};

		}

		for ( i in VirtualBox.getInstance().virtualBoxMachines ) {

			for ( s in ServerManager.getInstance().servers ) {

				if ( s.virtualBoxId == i.name ) s.setVirtualBoxMachine( i );

			}

		}

		for ( s in ServerManager.getInstance().servers ) {

			// Deleting provisioning proof file if VirtualBox machine does not exist for this server
			if ( s.combinedVirtualMachine.value.virtualBoxMachine.name == null ) s.deleteProvisioningProof();

		}

		if ( _serverPage != null ) _serverPage.virtualBoxMachines = VirtualBox.getInstance().virtualBoxMachines;

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

	function _openBrowsersSetup(e:SuperHumanApplicationEvent) {
		this.selectedPageId = PAGE_BROWSERS;
	}
	
	function _cancelSettings( e:SuperHumanApplicationEvent ) {
		if (this.previousPageId != PAGE_BROWSERS) {
			this.selectedPageId = this.previousPageId;
		} else {
			this.selectedPageId = PAGE_SERVER;
		}
	}

	function _saveAppConfiguration( e:SuperHumanApplicationEvent ) {

		_saveConfig();
		if (this.previousPageId != PAGE_BROWSERS) {
			this.selectedPageId = this.previousPageId;
		} else {
			this.selectedPageId = PAGE_SERVER;
		}
		ToastManager.getInstance().showToast( LanguageManager.getInstance().getString( 'toast.settingssaved' ) );

	}
	
	function _downloadVagrant( e:SuperHumanApplicationEvent ) {

		Shell.getInstance().open( [ SuperHumanGlobals.VAGRANT_DOWNLOAD_URL ] );

	}

	function _downloadVirtualBox( e:SuperHumanApplicationEvent ) {

		Shell.getInstance().open( [ SuperHumanGlobals.VIRTUALBOX_DOWNLOAD_URL ] );
		
	}

	override function _onExit( exitCode:Int ) {

		_config.preferences.windowx = this._window.x;
		_config.preferences.windowy = this._window.y;
		_config.preferences.windowwidth = this._window.width;
		_config.preferences.windowheight = this._window.height;

		_saveConfig();

		_canExit = false;

		if ( !_config.preferences.keepserversrunning && VirtualBox.getInstance().exists && Vagrant.getInstance().exists ) {

			Logger.debug( '${this}: Shutting down server...' );

			// Stop all possibly running executors
			var vms:Array<CombinedVirtualMachine> = [];
			for ( s in ServerManager.getInstance().servers ) vms.push( s.combinedVirtualMachine.value );
			Vagrant.getInstance().stopAll( false );

			while( !_canExit ) {

				for ( server in ServerManager.getInstance().servers ) {

					// Shutting down VirtualBox machine
					var vboxArgs:Array<String> = [ 'controlvm' ];
					vboxArgs.push( server.virtualBoxId );
					vboxArgs.push( 'poweroff' );
					Sys.command( VirtualBox.getInstance().path + VirtualBox.getInstance().executable, vboxArgs );

					// Shutting down Vagrant machine
					var vagrantArgs:Array<String> = [ 'halt' ];
					if ( server.combinedVirtualMachine.value != null && server.combinedVirtualMachine.value.vagrantMachine.vagrantId != null ) {
						vagrantArgs.push( server.combinedVirtualMachine.value.vagrantMachine.vagrantId );
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

		super._onExit( exitCode );

	}

	override function _onWindowFocusIn() {

		super._onWindowFocusIn();

		if ( !SuperHumanGlobals.CHECK_VAGRANT_STATUS_ON_FOCUS ) return;

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

		var defaultBrowser = Browsers.getDefaultBrowser();
		var a = [e.server.webAddress];
		#if mac
		a = ["-a" + defaultBrowser.executablePath, e.server.webAddress];
		#elseif windows
		a = ["start", '""', '"${defaultBrowser.executablePath}"', '"${e.server.webAddress}"'];
		#end
		
		if ( e.server.webAddress == null || e.server.webAddress.length == 0 ) {

			if ( e.server.console != null ) e.server.console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.webaddressinvalid', '[${e.server.webAddress}]' ), true );
			Logger.error( '${this}: Web address is invalid: \"${e.server.webAddress}\"' );
			return;

		}
		
		#if windows
		var trim = StringTools.trim( a.join( " " ));
		NativeSys.sys_command(trim);
		#else
		Shell.getInstance().open( a );
		#end
	}

	function _saveConfig() {

		Server.keepFailedServersRunning = _config.preferences.keepfailedserversrunning;

		_config.servers = [];

		for ( server in ServerManager.getInstance().servers ) {

			_config.servers.push( server.getData() );
			server.saveData();

		}

		if (_config.browsers == null) 
		{
			_config.browsers = _defaultConfig.browsers;	
		} 
		else if (_browsersCollection != null) 
		{
			_config.browsers = _browsersCollection;
		}
		_browsersCollection = null;
		
		try {

			var conf = Json.stringify( _config, ( SuperHumanGlobals.PRETTY_PRINT ) ? "\t" : null );
			File.saveContent( '${System.applicationStorageDirectory}${_CONFIG_FILE}', Json.stringify( _config, ( SuperHumanGlobals.PRETTY_PRINT ) ? "\t" : null ) );
			Logger.debug( '${this}: Configuration saved to: ${System.applicationStorageDirectory}${_CONFIG_FILE}' );

		} catch ( e ) {

			Logger.error( '${this}: Configuration cannot be saved to: ${System.applicationStorageDirectory}${_CONFIG_FILE}' );

		}

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

	function _setBrowserPage(e:SuperHumanApplicationEvent) {
		this.selectedPageId = PAGE_SETUP_BROWSERS;	
		_setupBrowserPage.setBrowserData(e.browserData);
	}
	
	function _refreshDefaultBrowser(e:SuperHumanApplicationEvent) {
		for (b in _browsersCollection) {
			if (b != e.browserData) {
				b.isDefault = false;
			}
		}
		
		_updateDefaultBrowserSettingsPage();
	}	
	
	function _refreshBrowsersPage(e:SuperHumanApplicationEvent) {

		//this.selectedPageId = PAGE_BROWSERS;
		_browsersPage.refreshBrowsers();
		_updateDefaultBrowserSettingsPage();
	}

	function _closeSetupBrowserPage(e:SuperHumanApplicationEvent) {
		this.selectedPageId = this.previousPageId;	
	}
	
	function _closeBrowsersPage(e:SuperHumanApplicationEvent) {
		this.selectedPageId = PAGE_SETTINGS;
	}
	
	function _initializeBrowsersCollection() {
		if (this.previousPageId != PAGE_BROWSERS && this.previousPageId != PAGE_SETUP_BROWSERS) {
			_browsersCollection = new Array<BrowserData>();
			for (index => element in _config.browsers) 
			{
				var bd:Dynamic = _config.browsers[index];
				var newBd = new BrowserData(bd.browserType, bd.isDefault, bd.browserName, bd.executablePath);
				_browsersCollection.push(newBd);
			}	
			
			_updateDefaultBrowserSettingsPage();
		}
	}
	
	function _updateDefaultBrowserSettingsPage() {
		if (_settingsPage != null) {
			var defaultBrowser = _browsersCollection.filter(b -> b.isDefault);
			if (defaultBrowser.length > 0) {
				_settingsPage.updateDefaultBrowser(defaultBrowser[0]);
			}
		}
	}
	
	function _saveAdvancedServerConfiguration( e:SuperHumanApplicationEvent ) {

		e.server.saveHostsFile();
		_saveConfig();

		ToastManager.getInstance().showToast( LanguageManager.getInstance().getString( 'toast.advancedserverconfigsaved' ) );
		this.selectedPageId = PAGE_CONFIG;

	}

	function _startServer( e:SuperHumanApplicationEvent ) {

		if ( _cpuArchitecture == CPUArchitecture.Arm64 ) {

			Logger.warning( '${this}: CPU Architecture ${_cpuArchitecture} is not supported' );
			_showCPUArchitectureNotSupportedWarning();
			return;

		}

		Logger.info( '${this}: Starting server: ${e.server.id}' );
		Logger.info( '${this}: Server configuration: ${e.server.getData()}' );
		Logger.debug( '${this}: Virtual Machine: ${e.server.combinedVirtualMachine.value}' );
		Logger.debug( '\n----- Hosts.yml START -----\n${e.server.provisioner.generateHostsFileContent()}\n----- Hosts.yml END -----' );

		// TODO: Decide how to handle provisioning if required
		// e.server.start( _config.preferences.provisionserversonstart );
		e.server.start();

	}

	function _stopServer( e:SuperHumanApplicationEvent ) {

		e.server.stop( e.forced );

	}

	function _suspendServer( e:SuperHumanApplicationEvent ) {

		e.server.suspend();

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

				Logger.debug( '${this}: Vagrant machines: ${Vagrant.getInstance().machines}' );
				Logger.debug( '${this}: VirtualBox hostinfo: ${VirtualBox.getInstance().hostInfo}' );
				Logger.debug( '${this}: VirtualBox bridgedInterfaces: ${VirtualBox.getInstance().bridgedInterfaces}' );
				Logger.debug( '${this}: VirtualBox vms: ${VirtualBox.getInstance().virtualBoxMachines}' );

				for ( s in ServerManager.getInstance().servers ) s.setServerStatus();

				_loadingPage.stopProgressIndicator();
				this.selectedPageId = PAGE_SERVER;

			}

		}
		
	}

	public function onServerPropertyChanged( server:Server, ?saveRequired:Bool ) {

		if( saveRequired ) _saveConfig();

		switch ( server.status.value ) {

			case ServerStatus.Stopping( true ) | ServerStatus.Stopping( false ) | ServerStatus.Initializing | ServerStatus.Running( true ) | ServerStatus.Running( false ):
				_header.updateButtonEnabled = false;

			default:
				_header.updateButtonEnabled = true;

		}

	}

	override function _updateFound(e:Event) {

		super._updateFound( e );

	}

	function _openServerDir( e:SuperHumanApplicationEvent ) {

		Logger.info('${this}: _openServerDir path: ${e.server.path.value}');
		Shell.getInstance().open( [ e.server.path.value ] );
		Shell.getInstance().openTerminal( e.server.path.value, false );

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

		if ( _selectedPageId == PAGE_SETTINGS ) 
		{
			_initializeBrowsersCollection();
			_browsersPage.setBrowsers(_browsersCollection);
			_settingsPage.updateData();
		}
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

		Logger.info( '${this}: Deleting ${server} deleteFiles:${deleteFiles}' );

		server.dispose();
		ServerManager.getInstance().servers.remove( server );
		
		if ( deleteFiles ) {

			FileTools.deleteDirectory( server.path.value );

		}

		ToastManager.getInstance().showToast( LanguageManager.getInstance().getString( 'toast.serverdeleted' ) );

		_saveConfig();

	}

	function _createServer( e:SuperHumanApplicationEvent ) {

		Logger.info( '${this}: Creating new server...' );

		var newServerData:ServerData = ServerManager.getInstance().getDefaultServerData( e.provisionerType );
		var server = ServerManager.getInstance().createServer( newServerData );
		server.onUpdate.add( onServerPropertyChanged );

		Logger.info( '${this}: New ${server} created' );

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

		#if linux
		Shell.getInstance().open( [ SuperHumanGlobals.SOURCE_CODE_URL ] );
		#else
		System.openURL( SuperHumanGlobals.SOURCE_CODE_URL );
		#end

	}

	override function _visitSourceCodeIssues(?e:Dynamic) {

		super._visitSourceCodeIssues(e);
		#if linux
		Shell.getInstance().open( [ SuperHumanGlobals.SOURCE_CODE_ISSUE_NEW_URL ] );
		#else
		System.openURL( SuperHumanGlobals.SOURCE_CODE_ISSUE_NEW_URL );
		#end

	}

	override function _visitSourceCodeNewIssue(?e:Dynamic) {

		super._visitSourceCodeNewIssue(e);
		#if linux
		Shell.getInstance().open( [ SuperHumanGlobals.SOURCE_CODE_ISSUE_NEW_URL ] );
		#else
		System.openURL( SuperHumanGlobals.SOURCE_CODE_ISSUE_NEW_URL );
		#end

	}

	function _openVirtualBoxGUI( e:SuperHumanApplicationEvent ) {

		VirtualBox.getInstance().openGUI();

	}

	function _refreshSystemInfo( e:SuperHumanApplicationEvent ) {

		ServerManager.getInstance().onVMInfoRefreshed.add( _onVMInfoRefreshed );
		ServerManager.getInstance().refreshVMInfo( true, true );

	}

	function _onVMInfoRefreshed() {

		ServerManager.getInstance().onVMInfoRefreshed.remove( _onVMInfoRefreshed );

		if ( _serverPage != null ) {

			_serverPage.vagrantMachines = Vagrant.getInstance().machines;
			_serverPage.virtualBoxMachines = VirtualBox.getInstance().virtualBoxMachines;

		}

	}

	public override function toString():String {

		return '[Super.Human.Installer]';

	}

	function _onExecutorListChanged() {

		Logger.verbose( '${this}: Number of executors: ${ExecutorManager.getInstance().count()}' );
		_header.updateButtonEnabled = ExecutorManager.getInstance().count() == 0;

	}

	function _helpPageTextLink( e:SuperHumanApplicationEvent ) {

		switch e.text {

			case _TEXT_LINK_DEVOPS:
				Shell.getInstance().open( [ SuperHumanGlobals.DEVOPS_WIKI_URL ] );

			case _TEXT_LINK_DOMINO:
				Shell.getInstance().open( [ SuperHumanGlobals.DOMINO_WIKI_URL ] );

			case _TEXT_LINK_GENESIS_DIRECTORY:
				Shell.getInstance().open( [ SuperHumanGlobals.GENESIS_DIRECTORY_URL ] );

			case _TEXT_LINK_VAGRANT:
				Shell.getInstance().open( [ SuperHumanGlobals.VAGRANT_URL ] );

			case _TEXT_LINK_VIRTUALBOX:
				Shell.getInstance().open( [ SuperHumanGlobals.VIRTUALBOX_URL ] );

			case _TEXT_LINK_YAML:
				Shell.getInstance().open( [ SuperHumanGlobals.YAML_WIKI_URL ] );

			default:

		}

	}

	override function _showCrashAlert() {

		super._showCrashAlert();

		Alert.show(

			LanguageManager.getInstance().getString( 'alert.crash.text' ),
			LanguageManager.getInstance().getString( 'alert.crash.title' ),
			[ LanguageManager.getInstance().getString( 'alert.crash.buttonopen' ), LanguageManager.getInstance().getString( 'alert.crash.buttongithub' ), LanguageManager.getInstance().getString( 'alert.crash.buttonclose' ) ],
			( state ) -> {

				switch ( state.index ) {

					case 0:
						_openCrashLog();
						
					case 1:
						_visitSourceCodeNewIssue();

					default:

				}

			}

		);

	}

}
