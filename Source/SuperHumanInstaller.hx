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

import superhuman.server.AdditionalServer;
import openfl.Assets;
import champaign.core.primitives.VersionInfo;
import superhuman.server.SyncMethod;
import haxe.io.Path;
import superhuman.components.applications.SetupApplicationsPage;
import superhuman.components.additionals.AdditionalServerPage;
import superhuman.components.SecretsPage;
import openfl.desktop.ClipboardFormats;
import openfl.desktop.Clipboard;
import haxe.io.Bytes;
import superhuman.server.data.ServiceTypeData;
import superhuman.server.provisioners.ProvisionerType;
import superhuman.components.serviceType.ServiceTypePage;
import superhuman.components.browsers.SetupBrowserPage;
import superhuman.components.ProvisionerImportPage;
import superhuman.browser.Browsers;
import superhuman.config.SuperHumanHashes;
import champaign.core.logging.Logger;
import feathers.controls.Alert;
import feathers.controls.LayoutGroup;
import feathers.style.Theme;
import genesis.application.GenesisApplication;
import genesis.application.managers.LanguageManager; 
import genesis.application.managers.ToastManager;
import haxe.Json;
import lime.system.System;
import openfl.Lib;
import openfl.events.Event;
import openfl.events.UncaughtErrorEvent;
import openfl.system.Capabilities;
import prominic.sys.applications.AbstractApp;
import prominic.sys.applications.bin.Shell;
import prominic.sys.applications.git.Git;
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
import superhuman.components.DynamicAdvancedConfigPage;
import superhuman.components.DynamicConfigPage;
import superhuman.components.HelpPage;
import superhuman.components.LoadingPage;
import superhuman.components.RolePage;
import superhuman.components.ServerPage;
import superhuman.components.SettingsPage;
import superhuman.components.ProvisionerImportPage;
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
import superhuman.application.ApplicationData;
import superhuman.application.Applications;
import superhuman.server.data.ServerUIType;
import superhuman.server.definitions.ProvisionerDefinition;
import sys.io.Process;
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

	static public final PAGE_SERVICE_TYPE = "page-service-type";
	static public final PAGE_CONFIG = "page-config";
	static public final PAGE_CONFIG_ADVANCED = "page-config-advanced";
	static public final PAGE_ADDITIONAL_SERVER = "page-additional-server";
	static public final PAGE_HELP = "page-help";
	static public final PAGE_LOADING = "page-loading";
	static public final PAGE_ROLES = "page-roles";
	static public final PAGE_SERVER = "page-server";
	static public final PAGE_SETTINGS = "page-settings";
	static public final PAGE_SECRETS = "page-secrets";
	static public final PAGE_SETUP_BROWSERS = "page-setup-browsers";
	static public final PAGE_SETUP_APPLICATIONS = "page-setup-applications";
	static public final PAGE_PROVISIONER_IMPORT = "page-provisioner-import";
	
	static var _instance:SuperHumanInstaller;

	public static function getInstance():SuperHumanInstaller {

		return _instance;

	}
	
	final _defaultConfig:SuperHumanConfig = {
		
		servers : [],
		user: {},
		preferences: { keepserversrunning: true, savewindowposition: false, preventsystemfromsleep: false, provisionserversonstart:false, disablevagrantlogging: false, keepfailedserversrunning: false },
		browsers: Browsers.DEFAULT_BROWSERS_LIST,
		applications: Applications.DEFAULT_APPLICATIONS_LIST
	}

	var _advancedConfigPage:AdvancedConfigPage;
	var _appCheckerOverlay:LayoutGroup;
	var _serviceTypePage:ServiceTypePage;
	var _config:SuperHumanConfig;
	var _configPage:ConfigPage;
	var _defaultRoles:Map<String, RoleData>;
	var _defaultServerConfigData:ServerData;
	var _dynamicConfigPage:DynamicConfigPage;
	var _dynamicAdvancedConfigPage:DynamicAdvancedConfigPage;
	var _helpPage:HelpPage;
	var _loadingPage:LoadingPage;
	var _processId:Null<Int>;
	var _rolePage:RolePage;
	var _serverPage:ServerPage;
	var _serverRolesCollection:Array<ServerRoleImpl>;
	var _settingsPage:SettingsPage;
	var _vagrantFile:String;
	var _setupBrowserPage:SetupBrowserPage;
	var _setupApplicationsPage:SetupApplicationsPage;
	var _additionalServerPage:AdditionalServerPage;
	var _secretsPage:SecretsPage;
	var _provisionerImportPage:ProvisionerImportPage;
	var _browsersCollection:Array<BrowserData>;
	var _applicationsCollection:Array<ApplicationData>;
	var _serviceTypesCollection:Array<ServiceTypeData>;
	
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

		_defaultRoles = superhuman.server.provisioners.StandaloneProvisioner.getDefaultProvisionerRoles();

		var dominoHashes:Array<String> = SuperHumanHashes.getInstallersHashes("domino");
		var dominoHotFixHashes:Array<String> = SuperHumanHashes.getHotFixesHashes("domino");
		var dominoFixPacksHashes:Array<String> = SuperHumanHashes.getFixPacksHashes("domino");
		var nomadWebHashes:Array<String> = SuperHumanHashes.getInstallersHashes("nomadweb");
		var nomadWebHotFixHashes:Array<String> = SuperHumanHashes.getHotFixesHashes("nomadweb");
		var leapHashes:Array<String> = SuperHumanHashes.getInstallersHashes("leap");
		var travelerHashes:Array<String> = SuperHumanHashes.getInstallersHashes("traveler");
		var travelerFixPacksHashes:Array<String> = SuperHumanHashes.getFixPacksHashes("traveler");
		var verseHashes:Array<String> = SuperHumanHashes.getInstallersHashes("verse");
		var appdevpackHashes:Array<String> = SuperHumanHashes.getInstallersHashes("appdevpack");
		var restApiHashes:Array<String> = SuperHumanHashes.getInstallersHashes("domino-rest-api");
		
		_serverRolesCollection = [

			new ServerRoleImpl( "Domino", LanguageManager.getInstance().getString( 'rolepage.roles.domino.desc' ), _defaultRoles.get( "domino" ), dominoHashes, dominoHotFixHashes, dominoFixPacksHashes, "(Domino_14.0_Linux_English.tar)" ),
			new ServerRoleImpl( "NomadWeb", LanguageManager.getInstance().getString( 'rolepage.roles.nomadweb.desc' ), _defaultRoles.get( "nomadweb" ), nomadWebHashes, nomadWebHotFixHashes, "(nomad-server-1.0.15-linux.tar.gz)" ),
			new ServerRoleImpl( "Leap (formerly Volt)", LanguageManager.getInstance().getString( 'rolepage.roles.leap.desc' ), _defaultRoles.get( "leap" ), leapHashes, "(hcl.dleap-1.1.7.29.zip)" ),
			new ServerRoleImpl( "Traveler", LanguageManager.getInstance().getString( 'rolepage.roles.traveler.desc' ), _defaultRoles.get( "traveler" ), travelerHashes, null, travelerFixPacksHashes, "(Traveler_14.0.0FP2_Linux_ML.tar.gz)" ),
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
			if ( _config.preferences.syncmethod == null ) _config.preferences.syncmethod = SyncMethod.Rsync;

			var a:Array<String> = [];
			for ( r in _defaultRoles ) a.push( r.value );

			var b:Array<String> = [];
			for ( s in _config.servers ) {

				b = [];
				for( r in s.roles ) b.push( r.value );
				
				for ( v in a ) if ( !b.contains( v ) ) s.roles.push( _defaultRoles.get( v ) );

			}
			
		} else {

			_config = _defaultConfig;
			File.saveContent( '${System.applicationStorageDirectory}${_CONFIG_FILE}', Json.stringify( _config ) );

		}

		Browsers.normaliseConfigBrowsersWithDefaultBrowsers();
		Applications.normaliseConfigApplications();
		
		for ( s in _config.servers ) {

			var server = ServerManager.getInstance().createServer( s, s.provisioner.type );
			server.onUpdate.add( onServerPropertyChanged );
			
			// Mark servers loaded from config as non-provisional
			Reflect.setField(server, "_provisional", false);

		}

		if ( _config.preferences.savewindowposition ) {

			if ( _config.preferences.windowx != null ) this._window.x = _config.preferences.windowx;
			if ( _config.preferences.windowy != null ) this._window.y = _config.preferences.windowy;
			if ( _config.preferences.windowwidth != null ) this._window.width = _config.preferences.windowwidth;
			if ( _config.preferences.windowheight != null ) this._window.height = _config.preferences.windowheight;

			if ( this._window.x < 0 ) this._window.x = 0;
			if ( this._window.y < 0 ) this._window.y = 0;

		}
		
		System.allowScreenTimeout = _config.preferences.preventsystemfromsleep;
	
		// Initialize service types collection
	_serviceTypesCollection = [];
	
	// Get all available provisioners
	var allProvisioners:Array<ProvisionerDefinition> = ProvisionerManager.getBundledProvisioners();
	Logger.info('${this}: Available provisioners: ${allProvisioners.length}');
	
	// Group provisioners by type to avoid duplicates
	var provisionersByType = new Map<String, Array<ProvisionerDefinition>>();
	
	for (provisioner in allProvisioners) {
		var type:String = provisioner.data.type;
		if (!provisionersByType.exists(type)) {
			provisionersByType.set(type, []);
		}
		provisionersByType.get(type).push(provisioner);
	}
	
	// Create a service type entry for each unique provisioner type
	for (type in provisionersByType.keys()) {
		// Get the newest version of this provisioner type
		var provisioners = provisionersByType.get(type);
		
		if (provisioners.length > 0) {
			var provisioner = provisioners[0];
			
			// Check if this is a valid provisioner or a disabled placeholder
			// The placeholder will have version 0.0.0
			var isValidProvisioner = provisioner.data.version.toString() != "0.0.0";
			
			// Add detailed logging
			Logger.info('Creating service type entry for provisioner: ${provisioner.name}');
			Logger.info('  - Type: ${type}');
			Logger.info('  - Version: ${provisioner.data.version}');
			Logger.info('  - Valid: ${isValidProvisioner}');
			
			// Determine server UI type based on naming convention
			// Default to Domino for unknown types
			var serverType = type.indexOf("additional") >= 0 ? 
				ServerUIType.AdditionalDomino : ServerUIType.Domino;
			
			// Read the provisioner metadata to get the description
			var metadata = ProvisionerManager.readProvisionerMetadata(Path.directory(provisioner.root));
			var description = metadata != null ? metadata.description : provisioner.name;
			
			// If this is a disabled placeholder, mark it with "(INVALID)" suffix in the description
			if (!isValidProvisioner) {
				description += " (INVALID - missing provisioner.yml in version directories)";
				Logger.warning('Adding invalid provisioner to service types: ${provisioner.name}');
			}
			
			// Get the base name without version
			var baseName = provisioner.name;
			var versionIndex = baseName.lastIndexOf(" v");
			if (versionIndex > 0) {
				baseName = baseName.substring(0, versionIndex);
			}
			
	// Add to service types collection
	_serviceTypesCollection.push({
		value: provisioner.name,
		description: description,
		provisionerType: type,
		serverType: serverType,
		isEnabled: isValidProvisioner, // Only enable if it's a valid provisioner
		provisioner: provisioner // Store the actual provisioner definition
	});
	
	// Log the service type that was added
	Logger.info('Added service type: ${provisioner.name}, enabled: ${isValidProvisioner}');
		}
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

		this._header.logo = Assets.getPath( SuperHumanInstallerTheme.IMAGE_ICON );

		// Initialize provisioners directory and cache
		_initializeProvisionersDirectory();
		ProvisionerManager.initializeCache();

		ExecutorManager.getInstance().onExecutorListChanged.add( _onExecutorListChanged );

		_loadingPage = new LoadingPage();
		this.addPage( _loadingPage, 0, PAGE_LOADING );

		_serverPage = new ServerPage( ServerManager.getInstance().servers, SuperHumanGlobals.MAXIMUM_ALLOWED_SERVERS );
		_serverPage.addEventListener( SuperHumanApplicationEvent.OPEN_FTP_CLIENT, _openFtpServer );
		_serverPage.addEventListener( SuperHumanApplicationEvent.START_SERVER, _startServer );
		_serverPage.addEventListener( SuperHumanApplicationEvent.STOP_SERVER, _stopServer );
		_serverPage.addEventListener( SuperHumanApplicationEvent.SUSPEND_SERVER, _suspendServer );
		_serverPage.addEventListener( SuperHumanApplicationEvent.SYNC_SERVER, _syncServer );
		_serverPage.addEventListener( SuperHumanApplicationEvent.PROVISION_SERVER, _provisionServer );
		_serverPage.addEventListener( SuperHumanApplicationEvent.DESTROY_SERVER, _destroyServer );		
		_serverPage.addEventListener( SuperHumanApplicationEvent.OPEN_BROWSER_SERVER_ADDRESS, _openBrowserServerAddress );
		_serverPage.addEventListener( SuperHumanApplicationEvent.OPEN_VAGRANT_SSH, _openVagrantSSH );
		_serverPage.addEventListener( SuperHumanApplicationEvent.OPEN_SERVER_DIRECTORY, _openServerDir );
		_serverPage.addEventListener( SuperHumanApplicationEvent.OPEN_SERVER_TERMINAL, _openServerTerminal );
		_serverPage.addEventListener( SuperHumanApplicationEvent.DELETE_SERVER, _deleteServer );
						
		_serverPage.addEventListener( SuperHumanApplicationEvent.CONFIGURE_SERVER, _configureServer );
		_serverPage.addEventListener( SuperHumanApplicationEvent.COPY_TO_CLIPBOARD, _copyToClipboard );
		_serverPage.addEventListener( SuperHumanApplicationEvent.START_CONFIGURE_SERVER, _startConfigureServer);
		_serverPage.addEventListener( SuperHumanApplicationEvent.DOWNLOAD_VAGRANT, _downloadVagrant );
		_serverPage.addEventListener( SuperHumanApplicationEvent.DOWNLOAD_VIRTUALBOX, _downloadVirtualBox );
		_serverPage.addEventListener( SuperHumanApplicationEvent.OPEN_VIRTUALBOX_GUI, _openVirtualBoxGUI );
		_serverPage.addEventListener( SuperHumanApplicationEvent.REFRESH_SYSTEM_INFO, _refreshSystemInfo );

		this.addPage( _serverPage, PAGE_SERVER );

		_helpPage = new HelpPage();
		_helpPage.addEventListener( SuperHumanApplicationEvent.TEXT_LINK, _helpPageTextLink );
		this.addPage( _helpPage, PAGE_HELP );

		_serviceTypePage = new ServiceTypePage(_serviceTypesCollection);
		_serviceTypePage.addEventListener( SuperHumanApplicationEvent.CREATE_SERVER, _createServer);
		_serviceTypePage.addEventListener( SuperHumanApplicationEvent.CREATE_ADDITIONAL_DOMINO_SERVER, _createAdditionalDominoServer );
		_serviceTypePage.addEventListener( SuperHumanApplicationEvent.CREATE_CUSTOM_SERVER, _createCustomServer );
		_serviceTypePage.addEventListener( SuperHumanApplicationEvent.CLOSE_SERVICE_TYPE_PAGE, _cancelServiceType );
		_serviceTypePage.addEventListener( SuperHumanApplicationEvent.IMPORT_PROVISIONER, _provisionerImported );
		_serviceTypePage.addEventListener( SuperHumanApplicationEvent.OPEN_PROVISIONER_IMPORT_PAGE, _openProvisionerImportPage );
		this.addPage( _serviceTypePage, PAGE_SERVICE_TYPE );
		
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

		_additionalServerPage = new AdditionalServerPage();
		_additionalServerPage.addEventListener( SuperHumanApplicationEvent.ADVANCED_CONFIGURE_SERVER, _advancedConfigureServer );
		_additionalServerPage.addEventListener( SuperHumanApplicationEvent.CONFIGURE_ROLES, _configureRoles );
		_additionalServerPage.addEventListener( SuperHumanApplicationEvent.SAVE_SERVER_CONFIGURATION, _saveServerConfiguration );
		_additionalServerPage.addEventListener( SuperHumanApplicationEvent.CANCEL_PAGE, _cancelConfigureServer );
		this.addPage( _additionalServerPage, PAGE_ADDITIONAL_SERVER );

		_settingsPage = new SettingsPage();
        _settingsPage.addEventListener( SuperHumanApplicationEvent.CANCEL_PAGE, _cancelSettings );
        _settingsPage.addEventListener( SuperHumanApplicationEvent.SAVE_APP_CONFIGURATION, _saveAppConfiguration );
        _settingsPage.addEventListener(SuperHumanApplicationEvent.CONFIGURE_BROWSER, _configureBrowserPage);
        _settingsPage.addEventListener(SuperHumanApplicationEvent.CONFIGURE_APPLICATION, _configureApplicationPage);
        _settingsPage.addEventListener( SuperHumanApplicationEvent.REFRESH_DEFAULT_BROWSER, _refreshDefaultBrowser);
        _settingsPage.addEventListener( SuperHumanApplicationEvent.IMPORT_PROVISIONER, _provisionerImported);
        _settingsPage.addEventListener( SuperHumanApplicationEvent.OPEN_SECRETS_PAGE, _openSecretsPage);
        _settingsPage.addEventListener( SuperHumanApplicationEvent.OPEN_PROVISIONER_IMPORT_PAGE, _openProvisionerImportPage);
		
		this.addPage( _settingsPage, PAGE_SETTINGS );
		
        _secretsPage = new SecretsPage();
        _secretsPage.addEventListener( SuperHumanApplicationEvent.CANCEL_PAGE, _cancelSecrets );
        _secretsPage.addEventListener( SuperHumanApplicationEvent.SAVE_APP_CONFIGURATION, _saveAppConfiguration );
        _secretsPage.addEventListener( SuperHumanApplicationEvent.OPEN_EXTERNAL_URL, _openExternalUrl );
		this.addPage( _secretsPage, PAGE_SECRETS );

		_rolePage = new RolePage();
		_rolePage.addEventListener( SuperHumanApplicationEvent.CLOSE_ROLES, _closeRolePage );
		this.addPage( _rolePage, PAGE_ROLES );

		_setupBrowserPage = new SetupBrowserPage();
		_setupBrowserPage.addEventListener( SuperHumanApplicationEvent.REFRESH_DEFAULT_BROWSER, _refreshDefaultBrowser);
		_setupBrowserPage.addEventListener( SuperHumanApplicationEvent.REFRESH_BROWSERS_PAGE, _refreshBrowsersPage);
		_setupBrowserPage.addEventListener( SuperHumanApplicationEvent.OPEN_DOWNLOAD_BROWSER, _openDownloadBrowser);
		_setupBrowserPage.addEventListener( SuperHumanApplicationEvent.CLOSE_BROWSERS_SETUP, _closeSetupBrowserPage );
		this.addPage( _setupBrowserPage, PAGE_SETUP_BROWSERS );
		
		_setupApplicationsPage = new SetupApplicationsPage();
		_setupApplicationsPage.addEventListener( SuperHumanApplicationEvent.REFRESH_DEFAULT_BROWSER, _refreshDefaultBrowser);
		_setupApplicationsPage.addEventListener( SuperHumanApplicationEvent.REFRESH_BROWSERS_PAGE, _refreshBrowsersPage);
		_setupApplicationsPage.addEventListener( SuperHumanApplicationEvent.OPEN_DOWNLOAD_BROWSER, _openDownloadBrowser);
		_setupApplicationsPage.addEventListener( SuperHumanApplicationEvent.CLOSE_APPLICATION_SETUP, _closeSetupAppPage );
		this.addPage( _setupApplicationsPage, PAGE_SETUP_APPLICATIONS );
		
		_provisionerImportPage = new ProvisionerImportPage();
		_provisionerImportPage.addEventListener( SuperHumanApplicationEvent.IMPORT_PROVISIONER, _provisionerImported );
		_provisionerImportPage.addEventListener( SuperHumanApplicationEvent.CLOSE_PROVISIONER_IMPORT_PAGE, _closeProvisionerImportPage );
		this.addPage( _provisionerImportPage, PAGE_PROVISIONER_IMPORT );
		
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
		Git.getInstance().onInit.add( _gitInitialized );
		ParallelExecutor.create().add( Vagrant.getInstance().getInit(), VirtualBox.getInstance().getInit(), Git.getInstance().getInit() ).onStop.add( _checkAppsInitialized ).execute();

	}

	function _checkAppsInitialized( executor:AbstractExecutor ) {

		if( Vagrant.getInstance().initialized && VirtualBox.getInstance().initialized ) {

			if ( VirtualBox.getInstance().exists && Vagrant.getInstance().exists ) {

				Vagrant.getInstance().onGlobalStatus.add( _vagrantGlobalStatusFinished ).onVersion.add( _vagrantVersionUpdated );
				VirtualBox.getInstance().onVersion.add( _virtualBoxVersionUpdated ).onListVMs.add( _virtualBoxListVMsUpdated );

				Git.getInstance().onVersion.add( _gitVersionUpdated );
				
				var pe = ParallelExecutor.create();
				pe.add( 
					Vagrant.getInstance().getVersion(),
					VirtualBox.getInstance().getBridgedInterfaces(),
					VirtualBox.getInstance().getHostInfo(),
					VirtualBox.getInstance().getVersion(),
					VirtualBox.getInstance().getListVMs( true ),
					Git.getInstance().getVersion()
				 );

				var rsyncExecutor = Vagrant.getInstance().getRsyncVersion();
				if (rsyncExecutor != null)
				{
					pe.add(rsyncExecutor);
				}

				if ( !SuperHumanGlobals.IGNORE_VAGRANT_STATUS ) 
				{
					pe.add( Vagrant.getInstance().getGlobalStatus( SuperHumanGlobals.PRUNE_VAGRANT_MACHINES ) );
				}
				pe.onStop.add( _checkPrerequisitesFinished ).execute();

			} else {

				_checkPrerequisitesFinished();

			}

		}

	}

	function _vagrantInitialized( a:AbstractApp ) {

		_serverPage.vagrantInstalled = Vagrant.getInstance().exists;

		if ( Vagrant.getInstance().exists ) {

			Logger.info( '${this}: Vagrant is installed at ${Vagrant.getInstance().path}' );

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

			Logger.info( '${this}: VirtualBox is installed at ${VirtualBox.getInstance().path}' );

		} else {

			Logger.warning( '${this}: VirtualBox is not installed' );

		}

	}
	
	function _gitInitialized( a:AbstractApp ) {
		
		if ( Git.getInstance().exists ) {
			Logger.info( '${this}: Git is installed at ${Git.getInstance().path}' );
		} else {
			Logger.warning( '${this}: Git is not installed' );
		}
		
	}

	function _virtualBoxVersionUpdated() {

		Logger.info( '${this}: VirtualBox version: ${VirtualBox.getInstance().version}' );

	}
	
	function _gitVersionUpdated() {

		Logger.info( '${this}: Git version: ${Git.getInstance().version}' );

	}

	function _virtualBoxListVMsUpdated() {

		VirtualBox.getInstance().onListVMs.remove( _virtualBoxListVMsUpdated );

		Logger.info( '${this}: VirtualBox machines: ${VirtualBox.getInstance().virtualBoxMachines}' );

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
		// Store the server reference to ensure we're working with the same server
		var server = e.server;
		
		// First check if the server still exists
		if (server == null) {
			Logger.warning('${this}: Cannot configure advanced server settings - server is null');
			// Return to server overview page
			this.selectedPageId = PAGE_SERVER;
			return;
		}
		
		// Check if this is a custom provisioner
		// We can use either the event's provisionerType or the server's provisioner type
		var provisionerType = e.provisionerType != null ? e.provisionerType : 
		                      (server.provisioner != null ? server.provisioner.type : null);
		
		// Make sure we have a valid provisioner type before proceeding
		if (provisionerType == null) {
			Logger.warning('${this}: Cannot determine provisioner type - provisioner is null');
			// Return to server overview page
			this.selectedPageId = PAGE_SERVER;
			return;
		}
		
		var isCustomProvisioner = provisionerType != ProvisionerType.StandaloneProvisioner && 
								  provisionerType != ProvisionerType.AdditionalProvisioner &&
								  provisionerType != ProvisionerType.Default;
		
		Logger.info('${this}: Advanced configure server with provisioner type: ${provisionerType}, isCustom: ${isCustomProvisioner}');
		
		if (isCustomProvisioner) {
			// Initialize the dynamic advanced config page if it doesn't exist
			if (_dynamicAdvancedConfigPage == null) {
				_dynamicAdvancedConfigPage = new DynamicAdvancedConfigPage();
				_dynamicAdvancedConfigPage.addEventListener(SuperHumanApplicationEvent.CANCEL_PAGE, _cancelAdvancedConfigureServer);
				_dynamicAdvancedConfigPage.addEventListener(SuperHumanApplicationEvent.SAVE_ADVANCED_SERVER_CONFIGURATION, _saveAdvancedServerConfiguration);
				this.addPage(_dynamicAdvancedConfigPage, "page-dynamic-advanced-config");
			}
			
			// Get the provisioner definition for the custom provisioner
			var provisionerDefinition = null;
			
			// First check if we have a provisioner definition name in the event data
			if (e.data != null && e.data is String) {
				var provisionerName:String = e.data;
				Logger.info('${this}: Looking for provisioner definition by name: ${provisionerName}');
				
				// Try to find the provisioner definition by name
				var allProvisioners = ProvisionerManager.getBundledProvisioners(provisionerType);
				for (provisioner in allProvisioners) {
					if (provisioner.name == provisionerName) {
						provisionerDefinition = provisioner;
						Logger.info('${this}: Found provisioner definition by name: ${provisioner.name}');
						break;
					}
				}
			}
			
			// If we didn't find a provisioner definition by name, try to find it by version
			if (provisionerDefinition == null) {
				var allProvisioners = ProvisionerManager.getBundledProvisioners(provisionerType);
				if (allProvisioners.length > 0) {
					// Find the exact provisioner version that matches the server's provisioner
					for (provisioner in allProvisioners) {
						if (provisioner.data.version == server.provisioner.version) {
							provisionerDefinition = provisioner;
							Logger.info('${this}: Found provisioner definition by version: ${provisioner.data.version}');
							break;
						}
					}
					
					// If no exact match, use the first one
					if (provisionerDefinition == null && allProvisioners.length > 0) {
						provisionerDefinition = allProvisioners[0];
						Logger.info('${this}: Using first available provisioner definition: ${provisionerDefinition.name}');
					}
				}
			}
			
			// Set the server and provisioner definition for the dynamic advanced config page
			_dynamicAdvancedConfigPage.setServer(server);
			if (provisionerDefinition != null) {
				_dynamicAdvancedConfigPage.setProvisionerDefinition(provisionerDefinition);
				Logger.info('${this}: Using provisioner definition for advanced config: ${provisionerDefinition.name}');
			} else {
				Logger.warning('${this}: No provisioner definition found for advanced config');
			}
			_dynamicAdvancedConfigPage.updateContent();
			
			// Show the dynamic advanced config page
			this.selectedPageId = "page-dynamic-advanced-config";
		} else {
			// Use the standard advanced config page for built-in provisioners
			_advancedConfigPage.setServer(server);
			_advancedConfigPage.updateContent();
			this.selectedPageId = PAGE_CONFIG_ADVANCED;
		}
	}

	function _configureServer( e:SuperHumanApplicationEvent ) {
		// Get the provisioner type from the event or the server
		var provisionerType = e.provisionerType != null ? e.provisionerType : e.server.provisioner.type;
		
		// Get the actual class name of the provisioner to determine its type
		var provisionerClassName = Type.getClassName(Type.getClass(e.server.provisioner));
		Logger.info('${this}: Configure server with provisioner class: ${provisionerClassName}, type: ${provisionerType}');
		
		// Check if this is a standard provisioner by class name first (most reliable)
		var isStandardProvisioner = (provisionerClassName == "superhuman.server.provisioners.StandaloneProvisioner" || 
								   provisionerClassName == "superhuman.server.provisioners.AdditionalProvisioner");
		
		// Also check by type as a fallback
		if (!isStandardProvisioner) {
			isStandardProvisioner = (provisionerType == ProvisionerType.StandaloneProvisioner || 
								   provisionerType == ProvisionerType.AdditionalProvisioner ||
								   provisionerType == ProvisionerType.Default);
		}
		
		// If it's a standard provisioner, it should NEVER use the custom config page
		var isCustomProvisioner = !isStandardProvisioner;
		
		Logger.info('${this}: Configure server with provisioner type: ${provisionerType}, isStandard: ${isStandardProvisioner}, isCustom: ${isCustomProvisioner}');
		
		if (isCustomProvisioner) {
			// For custom provisioners, use the dynamic config page
			_showConfigureCustomServer(e.server);
		} else {
			// For built-in provisioner types, use the standard config pages
			switch (provisionerType) {
				case ProvisionerType.AdditionalProvisioner:
					_showConfigureAdditionalServer(cast(e.server, AdditionalServer));
				default:
					_showConfigureServer(e.server);
			}
		}
	}
	
	/**
	 * Show the dynamic configuration page for custom provisioners
	 * @param server The server to configure
	 */
	function _showConfigureCustomServer(server:Server) {
		// Initialize the dynamic config page if it doesn't exist
		if (_dynamicConfigPage == null) {
			_dynamicConfigPage = new DynamicConfigPage();
			_dynamicConfigPage.addEventListener(SuperHumanApplicationEvent.ADVANCED_CONFIGURE_SERVER, _advancedConfigureServer);
			_dynamicConfigPage.addEventListener(SuperHumanApplicationEvent.CANCEL_PAGE, _cancelConfigureServer);
			_dynamicConfigPage.addEventListener(SuperHumanApplicationEvent.CONFIGURE_ROLES, _configureRoles);
			_dynamicConfigPage.addEventListener(SuperHumanApplicationEvent.SAVE_SERVER_CONFIGURATION, _saveServerConfiguration);
			this.addPage(_dynamicConfigPage, "page-dynamic-config");
		}
		
		// Set the server for the dynamic config page
		_dynamicConfigPage.setServer(server);
		
		// Get the provisioner definition for the current server
		var provisionerDefinition = null;
		
		// Check if we have a stored provisioner definition in the server's userData
		if (server.userData != null && Reflect.hasField(server.userData, "provisionerDefinition")) {
			provisionerDefinition = Reflect.field(server.userData, "provisionerDefinition");
			Logger.info('${this}: Found provisioner definition in server userData: ${provisionerDefinition.name}');
		} else {
			// Try to find the provisioner definition by type and version
			var allProvisioners = ProvisionerManager.getBundledProvisioners(server.provisioner.type);
			if (allProvisioners.length > 0) {
				// Find the exact provisioner version that matches the server's provisioner
				for (provisioner in allProvisioners) {
					if (provisioner.data.version == server.provisioner.version) {
						provisionerDefinition = provisioner;
						Logger.info('${this}: Found provisioner definition by version: ${provisioner.data.version}');
						break;
					}
				}
				
				// If no exact match, use the first one
				if (provisionerDefinition == null && allProvisioners.length > 0) {
					provisionerDefinition = allProvisioners[0];
					Logger.info('${this}: Using first available provisioner definition: ${provisionerDefinition.name}');
				}
			}
		}
		
		// Force the updateContent call with a delay to ensure the UI is ready
		haxe.Timer.delay(function() {
			// Force the dropdown to be populated with all provisioners of this type
			if (_dynamicConfigPage._dropdownCoreComponentVersion != null) {
				var provisionerCollection = ProvisionerManager.getBundledProvisionerCollection(server.provisioner.type);
				Logger.info('${this}: Setting dropdown data provider with ${provisionerCollection.length} items');
				_dynamicConfigPage._dropdownCoreComponentVersion.dataProvider = provisionerCollection;
				
				// Select the current provisioner version if available
				if (provisionerDefinition != null) {
					for (i in 0...provisionerCollection.length) {
						var d = provisionerCollection.get(i);
						if (d.data.version == provisionerDefinition.data.version) {
							_dynamicConfigPage._dropdownCoreComponentVersion.selectedIndex = i;
							break;
						}
					}
				}
			}
			
			// Set the provisioner definition to generate form fields
			if (provisionerDefinition != null) {
				_dynamicConfigPage.setProvisionerDefinition(provisionerDefinition);
			}
			
			// Update the content with forced=true to ensure all fields are created
			_dynamicConfigPage.updateContent(true);
		}, 100);
		
		// Show the dynamic config page
		this.selectedPageId = "page-dynamic-config";
	}

	function _showConfigureServer( server:Server ) {

		_configPage.setServer( server );
		_configPage.updateContent( true );
		this.selectedPageId = PAGE_CONFIG;

	}

	function _showConfigureAdditionalServer( server:AdditionalServer ) {

		_additionalServerPage.setServer( server );
		_additionalServerPage.updateContent( true );
		this.selectedPageId = PAGE_ADDITIONAL_SERVER;

	}

	function _cancelServiceType( e:SuperHumanApplicationEvent ) {
		this.selectedPageId = PAGE_SERVER;
	}

	function _cancelConfigureServer( e:SuperHumanApplicationEvent ) {
		// If this server is provisional (has never been saved/confirmed),
		// remove it completely from the system
		if (e.server != null && e.server.provisional) {
			Logger.info('${this}: Removing provisional server ${e.server.id} - configuration was cancelled before saving');
			// Remove from server manager using the proper method
			ServerManager.getInstance().removeProvisionalServer(e.server);
			// Save config to ensure it's removed from the .shi-config file
			_saveConfig();
		}

		if (this.previousPageId != PAGE_SERVICE_TYPE)
		{
			this.selectedPageId = PAGE_SERVER;
		}
		else
		{
			this.selectedPageId = PAGE_SERVICE_TYPE;
		}
	}

	function _cancelAdvancedConfigureServer( e:SuperHumanApplicationEvent ) {
		// For advanced config, we don't remove provisional servers on cancel
		// We just return to the basic config page with no changes
		
		// Safely get provisioner type, with multiple fallbacks
		var provisionerType = null;
		
		// Try to get from event first (most reliable)
		if (e.provisionerType != null) {
			provisionerType = e.provisionerType;
			Logger.info('${this}: Got provisioner type from event: ${provisionerType}');
		} 
		// If not available, try to get from server if it exists
		else if (e.server != null && e.server.provisioner != null) {
			provisionerType = e.server.provisioner.type;
			Logger.info('${this}: Got provisioner type from server: ${provisionerType}');
		}
		
		// If we still don't have a type or server is null, default to the server page
		if (provisionerType == null || e.server == null) {
			Logger.warning('${this}: Cannot determine provisioner type or server is null, returning to server list');
			this.selectedPageId = PAGE_SERVER;
			return;
		}
		
		// Now determine which page to navigate to based on the provisioner type
		Logger.info('${this}: Navigating back to basic config for provisioner type: ${provisionerType}');
		
		// Instead of navigating based only on provisioner type, also check the previousPageId
		// This helps maintain proper navigation history
		switch (provisionerType) {
			case ProvisionerType.AdditionalProvisioner:
				// For additional provisioners, go to the additional server page
				if (_additionalServerPage != null && e.server != null) {
					// First set the server to ensure the page has the correct data
					_additionalServerPage.setServer(cast(e.server, AdditionalServer));
					// Force content update to refresh the UI
					_additionalServerPage.updateContent(true);
					// Then navigate to the page
					this.selectedPageId = PAGE_ADDITIONAL_SERVER;
					Logger.info('${this}: Navigating to AdditionalServerPage for server ${e.server.id}');
				} else {
					this.selectedPageId = PAGE_SERVER;
					Logger.warning('${this}: Could not navigate to AdditionalServerPage - missing page or server');
				}
				
			case ProvisionerType.StandaloneProvisioner, ProvisionerType.Default:
				// For built-in provisioner types, go to the standard config page
				if (_configPage != null && e.server != null) {
					// First set the server to ensure the page has the correct data
					_configPage.setServer(e.server);
					// Force content update to refresh the UI
					_configPage.updateContent(true);
					// Then navigate to the page
					this.selectedPageId = PAGE_CONFIG;
					Logger.info('${this}: Navigating to ConfigPage for server ${e.server.id}');
				} else {
					this.selectedPageId = PAGE_SERVER;
					Logger.warning('${this}: Could not navigate to ConfigPage - missing page or server');
				}
				
			default:
				// For custom provisioner types, go to the dynamic config page
				if (_dynamicConfigPage != null && e.server != null) {
					// First set the server to ensure the page has the correct data
					_dynamicConfigPage.setServer(e.server);
					// Force content update to refresh the UI
					_dynamicConfigPage.updateContent(true);
					// Then navigate to the page
					this.selectedPageId = "page-dynamic-config";
					Logger.info('${this}: Navigating to DynamicConfigPage for server ${e.server.id}');
				} else {
					this.selectedPageId = PAGE_SERVER;
					Logger.warning('${this}: Could not navigate to DynamicConfigPage - missing page or server');
				}
		}
	}

	function _cancelSettings( e:SuperHumanApplicationEvent ) {
		if (this.previousPageId != PAGE_SETUP_BROWSERS && this.previousPageId != PAGE_SETUP_APPLICATIONS && this.previousPageId != PAGE_SECRETS) {
			this.selectedPageId = this.previousPageId;
		} else {
			this.selectedPageId = PAGE_SERVER;
		}
	}
	
	function _cancelSecrets( e:SuperHumanApplicationEvent ) {
		this.selectedPageId = PAGE_SETTINGS;
	}
	
	function _openSecretsPage( e:SuperHumanApplicationEvent ) {
		this.selectedPageId = PAGE_SECRETS;
	}
	
	/**
	 * Navigate to the provisioner import page
	 * @param e The event
	 */
	function _openProvisionerImportPage( e:SuperHumanApplicationEvent ) {
		Logger.info('${this}: Opening provisioner import page');
		this.selectedPageId = PAGE_PROVISIONER_IMPORT;
	}

	function _saveAppConfiguration( e:SuperHumanApplicationEvent ) {

		_saveConfig();
		if (this.previousPageId != PAGE_SETUP_BROWSERS && this.previousPageId != PAGE_SETUP_APPLICATIONS) {
			this.selectedPageId = this.previousPageId;
		} else {
			this.selectedPageId = PAGE_SERVER;
		}
		ToastManager.getInstance().showToast( LanguageManager.getInstance().getString( 'toast.settingssaved' ) );

	}
	
	function _downloadVagrant( e:SuperHumanApplicationEvent ) {

		Browsers.openLink(SuperHumanGlobals.VAGRANT_DOWNLOAD_URL);

	}

	function _downloadVirtualBox( e:SuperHumanApplicationEvent ) {
		Browsers.openLink(SuperHumanGlobals.VIRTUALBOX_DOWNLOAD_URL);
	}

	override function _onExit( exitCode:Int ) {

		_config.preferences.windowx = this._window.x;
		_config.preferences.windowy = this._window.y;
		_config.preferences.windowwidth = this._window.width;
		_config.preferences.windowheight = this._window.height;

		_saveConfig();

		_canExit = false;

		if ( !_config.preferences.keepserversrunning && VirtualBox.getInstance().exists && Vagrant.getInstance().exists ) {

			Logger.warning( '${this}: Shutting down server...' );

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

	function _openBrowserServerAddress( e:SuperHumanApplicationEvent ) {
		if ( e.server.webAddress == null || e.server.webAddress.length == 0 ) 
		{
			if ( e.server.console != null ) 
			{
				e.server.console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.webaddressinvalid', '[${e.server.webAddress}]' ), true );
			}
		}
		Browsers.openLink(e.server.webAddress);
	}
	
	function _openExternalUrl( e:SuperHumanApplicationEvent ) {
		if (e.url != null && e.url.length > 0) {
			Logger.info('${this}: Opening external URL: ${e.url}');
			Browsers.openLink(e.url);
		} else {
			Logger.warning('${this}: Cannot open external URL - URL is null or empty');
		}
	}

	function _saveConfig() {

		Server.keepFailedServersRunning = _config.preferences.keepfailedserversrunning;
		System.allowScreenTimeout = _config.preferences.preventsystemfromsleep;
		
		_config.servers = [];

		// Only save non-provisional servers to config
		for ( server in ServerManager.getInstance().servers ) {
			// Skip servers that are still provisional (user hasn't saved them yet)
			if (server.provisional) {
				Logger.info('${this}: Skipping provisional server ${server.id} when saving config');
				continue;
			}

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
		
		if (_config.applications == null) 
		{
			_config.applications = _defaultConfig.applications;	
		} 
		else if (_applicationsCollection != null) 
		{
			_config.applications = _applicationsCollection;
		}
		
		_applicationsCollection = null;
		_browsersCollection = null;
		
		try {
			var conf = Json.stringify( _config, ( SuperHumanGlobals.PRETTY_PRINT ) ? "\t" : null );
			File.saveContent( '${System.applicationStorageDirectory}${_CONFIG_FILE}', Json.stringify( _config, ( SuperHumanGlobals.PRETTY_PRINT ) ? "\t" : null ) );
			Logger.info( '${this}: Configuration saved to: ${System.applicationStorageDirectory}${_CONFIG_FILE}' );
		} catch ( e ) {
			Logger.error( '${this}: Configuration cannot be saved to: ${System.applicationStorageDirectory}${_CONFIG_FILE}' );
		}

	}

    function _saveServerConfiguration( e:SuperHumanApplicationEvent ) {
        // Check if this is a custom provisioner 
        var isCustomProvisioner = (e.server.provisioner.type != ProvisionerType.StandaloneProvisioner && 
                                  e.server.provisioner.type != ProvisionerType.AdditionalProvisioner);
        
        Logger.info('${this}: Saving server configuration for server ${e.server.id}, custom provisioner: ${isCustomProvisioner}');
        
        // Try to save hosts file first, with detailed logging
        try {
            // Force update of any fields before saving
            e.server.saveData();
            
            // Explicitly save hosts file to ensure it's created
            e.server.saveHostsFile();
            
            // Set server status after saving hosts file to ensure it's in the correct state
            e.server.setServerStatus();
            
            Logger.info('${this}: Successfully saved hosts file for server ${e.server.id}');
        } catch(ex) {
            Logger.error('${this}: Error saving hosts file: ${ex}');
            
            if (e.server.console != null) {
                e.server.console.appendText('Error saving hosts file: ${ex}', true);
            }
        }
        
        // Save the global config
        _saveConfig();
        
        ToastManager.getInstance().showToast( LanguageManager.getInstance().getString( 'toast.serverconfigsaved' ) );
        this.selectedPageId = PAGE_SERVER;
    }

	function _configureRoles( e:SuperHumanApplicationEvent ) {
		// Set the server for the role page
		_rolePage.setServer( e.server );
		
		// Get the actual class name of the provisioner to determine its type
		var provisionerClassName = Type.getClassName(Type.getClass(e.server.provisioner));
		Logger.info('${this}: Configure roles with provisioner class: ${provisionerClassName}');
		
		// Check if this is a standard provisioner by class name first (most reliable)
		var isStandardProvisioner = (provisionerClassName == "superhuman.server.provisioners.StandaloneProvisioner" || 
								   provisionerClassName == "superhuman.server.provisioners.AdditionalProvisioner");
		
		// Also check by type as a fallback
		if (!isStandardProvisioner) {
			var provisionerType = e.provisionerType != null ? e.provisionerType : e.server.provisioner.type;
			isStandardProvisioner = (provisionerType == ProvisionerType.StandaloneProvisioner || 
								   provisionerType == ProvisionerType.AdditionalProvisioner ||
								   provisionerType == ProvisionerType.Default);
		}
		
		// If it's a standard provisioner, it should NEVER use custom roles
		var isCustomProvisioner = !isStandardProvisioner;
		
		Logger.info('${this}: Configure roles with isStandard: ${isStandardProvisioner}, isCustom: ${isCustomProvisioner}');
		
		// Log the provisioner type information
		Logger.info('${this}: Configure roles - isStandardProvisioner: ${isStandardProvisioner}');
		
		// Check if the event contains a provisioner definition name in data field
		if (isCustomProvisioner && e.data != null && Std.isOfType(e.data, String)) {
			var provisionerName:String = cast e.data;
			Logger.info('${this}: Got provisioner name from event: ${provisionerName}');
			
			// Look up the provisioner definition by name
			var provisionerType = e.provisionerType != null ? e.provisionerType : e.server.provisioner.type;
			var allProvisioners = ProvisionerManager.getBundledProvisioners(provisionerType);
			var foundProvisioner = null;
			
			// Find the provisioner that matches the name
			for (provisioner in allProvisioners) {
				if (provisioner.name == provisionerName) {
					foundProvisioner = provisioner;
					Logger.info('${this}: Found matching provisioner definition: ${provisioner.name}');
					break;
				}
			}
			
			// If we found a provisioner, set it on the role page
			if (foundProvisioner != null) {
				Reflect.setField(_rolePage, "_provisionerDefinition", foundProvisioner);
				Logger.info('${this}: Setting provisioner definition on RolePage: ${foundProvisioner.name}');
			} else {
				// Clear any existing provisioner definition if we couldn't find a match
				Reflect.setField(_rolePage, "_provisionerDefinition", null);
				Logger.warning('${this}: Could not find provisioner definition with name: ${provisionerName}');
			}
		} else if (isCustomProvisioner) {
			// For custom provisioners without a definition name, try to find by type and version
			var provisionerType = e.provisionerType != null ? e.provisionerType : e.server.provisioner.type;
			var allProvisioners = ProvisionerManager.getBundledProvisioners(provisionerType);
			
			if (allProvisioners.length > 0) {
				// Find the exact provisioner version that matches the server's provisioner
				var foundProvisioner = null;
				for (provisioner in allProvisioners) {
					if (provisioner.data.version == e.server.provisioner.version) {
						foundProvisioner = provisioner;
						Logger.info('${this}: Found provisioner definition by version: ${provisioner.data.version}');
						break;
					}
				}
				
				// If no exact match, use the first one
				if (foundProvisioner == null) {
					foundProvisioner = allProvisioners[0];
					Logger.info('${this}: Using first available provisioner definition: ${foundProvisioner.name}');
				}
				
				Reflect.setField(_rolePage, "_provisionerDefinition", foundProvisioner);
			} else {
				// Clear any existing provisioner definition
				Reflect.setField(_rolePage, "_provisionerDefinition", null);
				Logger.info('${this}: No provisioner definitions found for type: ${provisionerType}');
			}
		} else {
			// For standard provisioners, clear any existing provisioner definition
			Reflect.setField(_rolePage, "_provisionerDefinition", null);
			Logger.info('${this}: Standard provisioner, clearing provisioner definition');
		}
		
		// Update the role page content and navigate to it
		_rolePage.updateContent();
		this.selectedPageId = PAGE_ROLES;
	}

	function _closeRolePage( e:SuperHumanApplicationEvent ) {

		this.selectedPageId = this.previousPageId;

		switch ( e.provisionerType ) {
			case ProvisionerType.AdditionalProvisioner:
				_additionalServerPage.updateContent();
			default:
				_configPage.updateContent();
		}
	}

	function _configureBrowserPage(e:SuperHumanApplicationEvent) {
		this.selectedPageId = PAGE_SETUP_BROWSERS;	
		_setupBrowserPage.setBrowserData(e.browserData);
	}
	
	function _configureApplicationPage(e:SuperHumanApplicationEvent) {
		this.selectedPageId = PAGE_SETUP_APPLICATIONS;	
		_setupApplicationsPage.setAppData(e.appData);
	}
	
	function _refreshDefaultBrowser(e:SuperHumanApplicationEvent) {
		for (b in _browsersCollection) {
			if (b != e.browserData) {
				b.isDefault = false;
			}
		}
	}	
	
	function _refreshBrowsersPage(e:SuperHumanApplicationEvent) {
		_settingsPage.refreshBrowsers();
	}

	function _openDownloadBrowser(e:SuperHumanApplicationEvent) {
		Browsers.openLink(e.browserData.downloadUrl);	
	}
	
	function _closeSetupBrowserPage(e:SuperHumanApplicationEvent) {
		this.selectedPageId = this.previousPageId;	
	}
	
    function _closeSetupAppPage(e:SuperHumanApplicationEvent) {
        this.selectedPageId = this.previousPageId;
    }
    
    function _closeProvisionerImportPage(e:SuperHumanApplicationEvent) {
        // Return to the previous page or the settings page, depending on where we came from
        if (this.previousPageId != null && this.previousPageId != PAGE_PROVISIONER_IMPORT) {
            this.selectedPageId = this.previousPageId;
        } else {
            // Default to settings page if we can't determine the previous page
            this.selectedPageId = PAGE_SETTINGS;
        }
        
        Logger.info('${this}: Closing provisioner import page, returning to ${this.selectedPageId}');
    }
    
    /**
     * Handle the provisioner imported event
     * @param e The event
     */
    function _provisionerImported(e:SuperHumanApplicationEvent) {
        // Refresh the list of available provisioners
        var allProvisioners:Array<ProvisionerDefinition> = ProvisionerManager.getBundledProvisioners();
        Logger.info('${this}: Available provisioners after import: ${allProvisioners.length}');
        
        // Reinitialize service types collection
        _serviceTypesCollection = [];
        
        // Group provisioners by type to avoid duplicates
        var provisionersByType = new Map<String, Array<ProvisionerDefinition>>();
        
        for (provisioner in allProvisioners) {
            var type:String = provisioner.data.type;
            if (!provisionersByType.exists(type)) {
                provisionersByType.set(type, []);
            }
            provisionersByType.get(type).push(provisioner);
        }
        
        // Create a service type entry for each unique provisioner type
        for (type in provisionersByType.keys()) {
            // Get the newest version of this provisioner type
            var provisioners = provisionersByType.get(type);
            
            if (provisioners.length > 0) {
                var provisioner = provisioners[0];
                
                // Determine server UI type based on naming convention or content
                var serverType = ServerUIType.Domino; // Default to standard Domino
                
                // Check if this is an additional server provisioner
                if (type.indexOf("additional") >= 0) {
                    serverType = ServerUIType.AdditionalDomino;
                } else if (type != ProvisionerType.StandaloneProvisioner && type != ProvisionerType.AdditionalProvisioner) {
                    // This is a custom provisioner type
                    Logger.info('${this}: Detected custom provisioner type: ${type}');
                }
                
                // Read the provisioner metadata to get the description
                var metadata = ProvisionerManager.readProvisionerMetadata(Path.directory(provisioner.root));
                var description = metadata != null ? metadata.description : provisioner.name;
                
                // Get the base name without version
                var baseName = provisioner.name;
                var versionIndex = baseName.lastIndexOf(" v");
                if (versionIndex > 0) {
                    baseName = baseName.substring(0, versionIndex);
                }
                
	// Add to service types collection
	_serviceTypesCollection.push({
		value: provisioner.name, // Keep the full name with version in the value
		description: description,
		provisionerType: type,
		serverType: serverType,
		isEnabled: true,
		provisioner: provisioner // Store the actual provisioner definition
	});
                
                Logger.info('${this}: Added provisioner to service types: ${baseName}, type: ${type}, serverType: ${serverType}');
            }
        }
        
        // Always update the service types collection in the page
        if (_serviceTypePage != null) {
            // Log current page for debugging
            Logger.info('${this}: Current page: ${this.selectedPageId}, checking if on SERVICE_TYPE page: ${this.selectedPageId == PAGE_SERVICE_TYPE}');
            
            // Update with the latest collection
            _serviceTypePage.updateServiceTypes(_serviceTypesCollection);
            
            // If we're currently on the service type page, dispatch an event to refresh the UI
            if (this.selectedPageId == PAGE_SERVICE_TYPE) {
                Logger.info('${this}: On ServiceTypePage, dispatching refresh event');
                
                // Create a new event for provisioner data update
                var refreshEvent = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.PROVISIONER_DATA_UPDATED);
                
                // Dispatch to the service type page to trigger a refresh
                _serviceTypePage.dispatchEvent(refreshEvent);
            }
        }
        
        // Refresh the server page to show the new provisioner
        if (_serverPage != null) {
            // Force a refresh of the server page
            for (server in ServerManager.getInstance().servers) {
                server.setServerStatus();
            }
        }
        
        Logger.info('${this}: Provisioner imported successfully');
        
        // The ServiceTypePage already shows a toast notification, so we don't need one here
    }
	
	function _initializeApplicationsCollection() {
		if (this.previousPageId != PAGE_SETUP_APPLICATIONS) {
			_applicationsCollection = new Array<ApplicationData>();
			for (index => element in _config.applications) 
			{
				var aConfig:Dynamic = _config.applications[index];
				var appData:ApplicationData = new ApplicationData(aConfig.appId);
    					appData.appName = aConfig.appName;
    					appData.executablePath = aConfig.executablePath;
    					appData.displayPath = aConfig.displayPath;
    					appData.exists = aConfig.exists;
				_applicationsCollection.push(appData);
			}	
		}
	}
	
	function _initializeBrowsersCollection() {
		if (this.previousPageId != PAGE_SETUP_BROWSERS) {
			_browsersCollection = new Array<BrowserData>();
			for (index => element in _config.browsers) 
			{
				var bd:Dynamic = _config.browsers[index];
				var newBd = new BrowserData(bd.browserType, bd.isDefault, bd.browserName, bd.executablePath);
				_browsersCollection.push(newBd);
			}	
		}
	}

	function _saveAdvancedServerConfiguration( e:SuperHumanApplicationEvent ) {
		// Save changes to the server
		e.server.saveHostsFile();
		_saveConfig();

		// Show success message
		ToastManager.getInstance().showToast( LanguageManager.getInstance().getString( 'toast.advancedserverconfigsaved' ) );

		// Log the navigation event
		Logger.info('${this}: Advanced configuration saved, returning to basic config page');
		
		// Return to the appropriate basic configuration page based on provisioner type
		switch ( e.server.provisioner.type ) {
			case ProvisionerType.AdditionalProvisioner:
				// For additional provisioners, go to the additional server page
				if (_additionalServerPage != null) {
					_additionalServerPage.setServer(cast(e.server, AdditionalServer));
					_additionalServerPage.updateContent(true); // Force refresh the UI
					this.selectedPageId = PAGE_ADDITIONAL_SERVER;
					Logger.info('${this}: Returning to AdditionalServerPage for server ${e.server.id}');
				} else {
					// Fallback if page isn't available
					this.selectedPageId = PAGE_SERVER;
				}
				
			case ProvisionerType.StandaloneProvisioner, ProvisionerType.Default:
				// For built-in provisioner types, go to the standard config page
				if (_configPage != null) {
					_configPage.setServer(e.server);
					_configPage.updateContent(true); // Force refresh the UI
					this.selectedPageId = PAGE_CONFIG;
					Logger.info('${this}: Returning to ConfigPage for server ${e.server.id}');
				} else {
					// Fallback if page isn't available
					this.selectedPageId = PAGE_SERVER;
				}
				
			default:
				// For custom provisioner types, go back to the dynamic config page
				if (_dynamicConfigPage != null) {
					_dynamicConfigPage.setServer(e.server);
					_dynamicConfigPage.updateContent(true); // Force refresh the UI
					this.selectedPageId = "page-dynamic-config";
					Logger.info('${this}: Returning to DynamicConfigPage for server ${e.server.id}');
				} else {
					// Fallback to server page if dynamic config page is not available
					this.selectedPageId = PAGE_SERVER;
					Logger.error('${this}: No suitable config page found, returning to server list');
				}
		}
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

				var rsyncVersionInfo:VersionInfo = Vagrant.getInstance().versionRsync;
				
				// Check if running on Windows
				var isWindows:Bool = Capabilities.os.toLowerCase().indexOf("windows") >= 0;
				
				// Create base system info without rsync
				var sysInfoBase = '${build} | ${isDebug}${Capabilities.os} | ${_cpuArchitecture} | Cores:${VirtualBox.getInstance().hostInfo.processorcorecount} | RAM: ${ram}GB | Vagrant: ${Vagrant.getInstance().version} | VirtualBox:${VirtualBox.getInstance().version}';
				
				// Add Git information if available
				if (Git.getInstance().exists && Git.getInstance().version != null) {
					sysInfoBase += ' | Git: ${Git.getInstance().version}';
				}
				
				// Only add rsync info for non-Windows systems
				if (!isWindows) {
					var rsyncVersion:String = rsyncVersionInfo != "" && rsyncVersionInfo != "0.0.0" ? "| Rsync: " + rsyncVersionInfo : "Rsync: not installed";
					_footer.sysInfo = sysInfoBase + ' ' + rsyncVersion;
				} else {
					_footer.sysInfo = sysInfoBase;
				}
				
				// Determine if we're on a Mac system
				var isMac:Bool = Capabilities.os.toLowerCase().indexOf("mac") >= 0;
				
				// Define the rsync compatibility check once
				var rsyncIncompatibleVersion:Bool = rsyncVersionInfo > "0.0.0" && rsyncVersionInfo <= "2.6.9";
				
				// Determine if system has incompatible rsync (Mac-specific issue)
				var isRsyncIncompatible:Bool = isMac && rsyncIncompatibleVersion;
				
				// Set global flag for disabling the sync toggle
				SuperHumanGlobals.IS_SYNC_DISABLED = isRsyncIncompatible;
				
				// If on Mac with incompatible rsync, force SCP but remember user preference
				if (isRsyncIncompatible) {
					// Store original preference if not already saved
					if (_config.preferences.userPreferredSyncMethod == null) {
						_config.preferences.userPreferredSyncMethod = _config.preferences.syncmethod;
					}
					// Force SCP for Mac with incompatible rsync
					_config.preferences.syncmethod = SyncMethod.SCP;
				} else if (_config.preferences.userPreferredSyncMethod != null) {
					// Restore user preference if we're not on an incompatible system
					_config.preferences.syncmethod = _config.preferences.userPreferredSyncMethod;
					_config.preferences.userPreferredSyncMethod = null;
				}
				
				// Show warning for any non-Windows system with incompatible rsync
				if (!isWindows && rsyncIncompatibleVersion) {
					_footer.warning = LanguageManager.getInstance().getString( 'serverconfigpage.form.syncmethod.warning' );
				}

				Logger.info( '${this}: Vagrant machines: ${Vagrant.getInstance().machines}' );
				Logger.info( '${this}: VirtualBox hostinfo: ${VirtualBox.getInstance().hostInfo}' );
				Logger.info( '${this}: VirtualBox bridgedInterfaces: ${VirtualBox.getInstance().bridgedInterfaces}' );
				Logger.info( '${this}: VirtualBox vms: ${VirtualBox.getInstance().virtualBoxMachines}' );
				Logger.info( '${this}: Rsync version: ${Vagrant.getInstance().versionRsync}' );

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

	}
	
	function _openServerTerminal( e:SuperHumanApplicationEvent ) {

		Logger.info('${this}: _openServerTerminal path: ${e.server.path.value}');
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

	// Tracking for server deletion
	private var _pendingDeleteServer:Server = null;
	private var _pendingDeleteFiles:Bool = false;
	
	function _vagrantDestroyed( machine:VagrantMachine ) {
		// Check if we're waiting to delete a server
		if (_pendingDeleteServer != null) {
			Logger.info('${this}: VM destroyed, now proceeding with server deletion');
			
			// Cache the server and delete flag, then clear pending state
			var server = _pendingDeleteServer;
			var deleteFiles = _pendingDeleteFiles;
			
			// Reset pending state
			_pendingDeleteServer = null;
			_pendingDeleteFiles = false;
			
		// Now complete the server deletion
		server.dispose();
		ServerManager.getInstance().servers.remove(server);
		
		if (deleteFiles) {
			#if windows
			// On Windows, use rd /s /q command to handle long paths better
			try {
				var serverPath = server.path.value;
				
				// Convert path to Windows format with backslashes
				var windowsPath = StringTools.replace(serverPath, "/", "\\");
				var command = 'rd /s /q "' + windowsPath + '"';
				
				Logger.info('${this}: Using Windows rd command to delete directory: ${command}');
				
				// Execute the command
				var process = new Process(command);
				var exitCode = process.exitCode();
				var error = process.stderr.readAll().toString();
				process.close();
				
				if (exitCode == 0) {
					Logger.info('${this}: Successfully deleted server directory using rd command');
				} else {
					Logger.warning('${this}: rd command returned non-zero exit code: ${exitCode}');
					if (error.length > 0) {
						Logger.warning('${this}: rd error output: ${error}');
					}
					
					// Fall back to FileTools if rd fails
					try {
						FileTools.deleteDirectory(serverPath);
						Logger.info('${this}: Deleted server directory using FileTools fallback');
					} catch (ftError) {
						Logger.error('${this}: Error deleting server directory with FileTools: ${ftError}');
					}
				}
			} catch (e) {
				Logger.error('${this}: Error using rd command: ${e}');
				
				// Fall back to FileTools on error
				try {
					FileTools.deleteDirectory(server.path.value);
				} catch (ftError) {
					Logger.error('${this}: Error deleting server directory: ${ftError}');
				}
			}
			#else
			// Use standard FileTools on non-Windows platforms
			try {
				FileTools.deleteDirectory(server.path.value);
			} catch (e) {
				Logger.error('${this}: Error deleting server directory: ${e}');
			}
			#end
		}

			ToastManager.getInstance().showToast(LanguageManager.getInstance().getString('toast.serverdeleted'));
			_saveConfig();
		} else {
			// Normal destroy operation, not part of server deletion
			ToastManager.getInstance().showToast(LanguageManager.getInstance().getString('toast.serverdestroyed'));
			_saveConfig();
		}
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
			_settingsPage.setBrowsers(_browsersCollection);
			
			_initializeApplicationsCollection();
			_settingsPage.setApplications(_applicationsCollection);
			
			_settingsPage.updateData();
		}
		else if ( _selectedPageId == PAGE_SERVICE_TYPE )
		{
			// Make sure the service types list is always refreshed when navigating to this page
			if (_serviceTypePage != null) {
				_serviceTypePage.updateServiceTypes(_serviceTypesCollection);
			}
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
	
	function _openFtpServer(e:SuperHumanApplicationEvent) {
		var apps = _config.applications;
		var fileZilla:Array<Dynamic> = apps.filter(f -> f.appId == Applications.FILE_ZILLA);
		e.server.openFtpClient(fileZilla[0]);
	}

	function _deleteServerInstance( server:Server, deleteFiles:Bool = false ) {
		Logger.info( '${this}: Deleting ${server} deleteFiles:${deleteFiles}' );

		// Check if we need to destroy the VM first
		if (server.vmExistsInVirtualBox()) {
			Logger.info( '${this}: Server has a VM that needs to be destroyed first' );
			
			try {
				// Set pending delete to be handled in the _vagrantDestroyed callback
				// This ensures deletion only proceeds after VM destruction is complete
				_pendingDeleteServer = server;
				_pendingDeleteFiles = deleteFiles;
				
				// Start VM destruction and return - we'll finish the deletion
				// when the _vagrantDestroyed callback fires
				server.destroy();
				
				// Notify user that we're destroying the VM first
				ToastManager.getInstance().showToast( LanguageManager.getInstance().getString( 'toast.serverdestroying', 'VM will be destroyed before deletion' ) );
				
				// The rest of the deletion will be handled in the _vagrantDestroyed callback
				return;
			} catch (e) {
				// If VM destruction fails, log error and proceed with deletion anyway
				Logger.error('${this}: Failed to destroy VM before deletion: ${e}, proceeding with deletion anyway');
				if (server.console != null) {
					server.console.appendText('Failed to destroy VM before deletion: ${e}, proceeding with deletion anyway', true);
				}
				
				// Reset pending state since we're proceeding directly
				_pendingDeleteServer = null;
				_pendingDeleteFiles = false;
			}
		}

		// No VM to destroy, proceed with immediate deletion
		server.dispose();
		ServerManager.getInstance().servers.remove( server );
		
		if ( deleteFiles ) {
			try {
				FileTools.deleteDirectory( server.path.value );
			} catch (e) {
				Logger.error('${this}: Error deleting server directory: ${e}');
			}
		}

		ToastManager.getInstance().showToast( LanguageManager.getInstance().getString( 'toast.serverdeleted' ) );
		_saveConfig();
	}

	function _createServer( e:SuperHumanApplicationEvent ) {
		Logger.info( '${this}: Creating new server with provisioner type: ${e.provisionerType}' );

		// ALWAYS use the standard standalone provisioner type for this method
		// This way we maintain consistency regardless of what was passed
		var provisionerType = ProvisionerType.StandaloneProvisioner;
		
		// Log that we're forcing the type for clarity
		if (Std.string(e.provisionerType) != Std.string(ProvisionerType.StandaloneProvisioner)) {
			Logger.warning( '${this}: Forcing provisioner type to StandaloneProvisioner (was: ${e.provisionerType})' );
		} else {
			Logger.info( '${this}: Using StandaloneProvisioner type' );
		}

		var server:Server = _createServerAndSaveConfig( provisionerType );
		
		// Ensure the server was created with the correct type
		Logger.info( '${this}: Verifying server provisioner type: ${server.provisioner.type}' );
		if (Std.string(server.provisioner.type) != Std.string(ProvisionerType.StandaloneProvisioner)) {
			Logger.warning( '${this}: Server was created with incorrect type: ${server.provisioner.type}, should be ${ProvisionerType.StandaloneProvisioner}' );
		}

		_showConfigureServer( server );
	}

	function _createAdditionalDominoServer( e:SuperHumanApplicationEvent ) {
		Logger.info( '${this}: Creating Additional Domino server with provisioner type: ${e.provisionerType}' );

		// Make sure we're using the correct provisioner type string from the event
		var provisionerType = e.provisionerType;
		
		// Verify this is actually an additional provisioner
		if (Std.string(provisionerType) != Std.string(ProvisionerType.AdditionalProvisioner)) {
			Logger.warning( '${this}: Expected additional provisioner but got: ${provisionerType}, correcting to ${ProvisionerType.AdditionalProvisioner}' );
			provisionerType = ProvisionerType.AdditionalProvisioner;
		}

		var server:AdditionalServer = cast(_createServerAndSaveConfig( provisionerType ), AdditionalServer);

		_showConfigureAdditionalServer( server );
	}
	
	function _createCustomServer( e:SuperHumanApplicationEvent ) {
		Logger.info( '${this}: Creating custom server with provisioner type: ${e.provisionerType}' );
		
		// Get the provisioner definition for the custom provisioner
		var provisionerDefinition = null;
		var allProvisioners = ProvisionerManager.getBundledProvisioners(e.provisionerType);
		Logger.info('${this}: Found ${allProvisioners.length} provisioners of type ${e.provisionerType}');
		
		// Log all available provisioners for debugging
		for (i in 0...allProvisioners.length) {
			var p = allProvisioners[i];
			Logger.info('${this}: Provisioner ${i}: name=${p.name}, type=${p.data.type}, version=${p.data.version}, root=${p.root}');
			
			if (p.metadata != null) {
				Logger.info('${this}: Metadata: name=${p.metadata.name}, type=${p.metadata.type}, version=${p.metadata.version}');
			} else {
				Logger.warning('${this}: No metadata for provisioner ${p.name}');
			}
		}
		
		// If we have a specific service type data, use that to find the provisioner
		if (e.serviceTypeData != null) {
			Logger.info('${this}: Using service type data: ${e.serviceTypeData.value}, ${e.serviceTypeData.provisionerType}');
			
			// First check if the service type data has a provisioner field
			if (e.serviceTypeData.provisioner != null) {
				provisionerDefinition = e.serviceTypeData.provisioner;
				Logger.info('${this}: Using provisioner directly from service type data: ${provisionerDefinition.name}');
			} else {
				// Find the provisioner that matches the service type data
				for (provisioner in allProvisioners) {
					if (provisioner.name == e.serviceTypeData.value) {
						provisionerDefinition = provisioner;
						Logger.info('${this}: Found matching provisioner by name: ${provisioner.name}');
						break;
					}
				}
			}
		}
		
		// If we didn't find a specific provisioner, use the first one
		if (provisionerDefinition == null && allProvisioners.length > 0) {
			provisionerDefinition = allProvisioners[0];
			Logger.info('${this}: Using first available provisioner: ${provisionerDefinition.name}');
		}
		
		// Create a new server data with the correct provisioner type
		var newServerData = ServerManager.getInstance().getDefaultServerData(ProvisionerType.StandaloneProvisioner);
		
		// Override the provisioner type and version with the custom provisioner
		if (provisionerDefinition != null) {
			newServerData.provisioner = {
				type: e.provisionerType,
				version: provisionerDefinition.data.version
			};
			Logger.info('${this}: Set provisioner type to ${e.provisionerType} and version to ${provisionerDefinition.data.version}');
		} else {
			newServerData.provisioner = {
				type: e.provisionerType,
				version: null
			};
			Logger.info('${this}: Set provisioner type to ${e.provisionerType} but no version available');
		}
		
		// Create the server with the custom provisioner type
		var server = ServerManager.getInstance().createServer(newServerData, e.provisionerType);
		server.onUpdate.add(onServerPropertyChanged);
		
		Logger.info('${this}: New ${server} created with provisioner type ${e.provisionerType}');
		
		ToastManager.getInstance().showToast(LanguageManager.getInstance().getString('toast.servercreated', 'with id ${server.id}'));
		
		_saveConfig();
		
		// Store the service type data in the server's userData for later use
		if (e.serviceTypeData != null) {
			// Initialize userData if needed
			server.userData = server.userData != null ? server.userData : {};
			
			// Store the service type data
			Reflect.setField(server.userData, "serviceTypeData", e.serviceTypeData);
			Logger.info('${this}: Stored service type data in server userData: ${e.serviceTypeData.value}');
		}
		
		// Initialize the dynamic config page if it doesn't exist
		if (_dynamicConfigPage == null) {
			_dynamicConfigPage = new DynamicConfigPage();
			_dynamicConfigPage.addEventListener( SuperHumanApplicationEvent.ADVANCED_CONFIGURE_SERVER, _advancedConfigureServer );
			_dynamicConfigPage.addEventListener( SuperHumanApplicationEvent.CANCEL_PAGE, _cancelConfigureServer );
			_dynamicConfigPage.addEventListener( SuperHumanApplicationEvent.CONFIGURE_ROLES, _configureRoles );
			_dynamicConfigPage.addEventListener( SuperHumanApplicationEvent.SAVE_SERVER_CONFIGURATION, _saveServerConfiguration );
			this.addPage( _dynamicConfigPage, "page-dynamic-config" );
		}
		
		// Set the server for the dynamic config page
		_dynamicConfigPage.setServer(server);
		
		// Store the provisioner definition and type in the server's userData for later use
		if (provisionerDefinition != null) {
			// Initialize userData if needed
			server.userData = server.userData != null ? server.userData : {};
			
			// Store the provisioner definition
			Reflect.setField(server.userData, "provisionerDefinition", provisionerDefinition);
			Logger.info('${this}: Stored provisioner definition in server userData: ${provisionerDefinition.name}');
		}
		
		// Force the updateContent call with a delay to ensure the UI is ready
		haxe.Timer.delay(function() {
			// Force the dropdown to be populated with all provisioners of this type
			if (_dynamicConfigPage._dropdownCoreComponentVersion != null) {
				var provisionerCollection = ProvisionerManager.getBundledProvisionerCollection(e.provisionerType);
				Logger.info('${this}: Setting dropdown data provider with ${provisionerCollection.length} items');
				_dynamicConfigPage._dropdownCoreComponentVersion.dataProvider = provisionerCollection;
				
				// Select the current provisioner version if available
				if (provisionerDefinition != null) {
					for (i in 0...provisionerCollection.length) {
						var d = provisionerCollection.get(i);
						if (d.data.version == provisionerDefinition.data.version) {
							_dynamicConfigPage._dropdownCoreComponentVersion.selectedIndex = i;
							break;
						}
					}
				}
			}
			
			// Set the provisioner definition to generate form fields
			if (provisionerDefinition != null) {
				_dynamicConfigPage.setProvisionerDefinition(provisionerDefinition);
			}
			
			// Update the content with forced=true to ensure all fields are created
			_dynamicConfigPage.updateContent(true);
		}, 100); // Small delay to ensure UI is ready
		
		// Show the dynamic config page
		this.selectedPageId = "page-dynamic-config";
	}

	function _copyToClipboard( e:SuperHumanApplicationEvent ) {

		if ( e.data != null ) {

			var content = Bytes.ofString(e.data);
			Clipboard.generalClipboard.setData(ClipboardFormats.RICH_TEXT_FORMAT, content);
			ToastManager.getInstance().showToast( LanguageManager.getInstance().getString( 'toast.copiedtoclipboard' ) );

		}

	}
	
	function _startConfigureServer(e:SuperHumanApplicationEvent) {
		this.selectedPageId = PAGE_SERVICE_TYPE;	
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

		Browsers.openLink( SuperHumanGlobals.SOURCE_CODE_URL);
	}

	override function _visitSourceCodeIssues(?e:Dynamic) {

		super._visitSourceCodeIssues(e);

		Browsers.openLink( SuperHumanGlobals.SOURCE_CODE_ISSUE_NEW_URL );
	}

	override function _visitSourceCodeNewIssue(?e:Dynamic) {

		super._visitSourceCodeNewIssue(e);

		Browsers.openLink( SuperHumanGlobals.SOURCE_CODE_ISSUE_NEW_URL );
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

	/**
	 * Get the RolePage instance
	 * This allows other components to interact with the RolePage directly
	 * @return The RolePage instance
	 */
	public function getRolesPage():RolePage {
		return _rolePage;
	}

	public override function toString():String {

		return '[Super.Human.Installer]';

	}

	/**
	 * Initialize the provisioners directory
	 * This ensures the directory exists and is ready for use
	 */
	function _initializeProvisionersDirectory() {
		var provisionersDir = ProvisionerManager.getProvisionersDirectory();
		
		if (!FileSystem.exists(provisionersDir)) {
			try {
				FileSystem.createDirectory(provisionersDir);
				Logger.info('Created provisioners directory at ${provisionersDir}');
			} catch (e) {
				Logger.error('Failed to create provisioners directory at ${provisionersDir}: ${e}');
			}
		}
	}

	function _onExecutorListChanged() {

		Logger.verbose( '${this}: Number of executors: ${ExecutorManager.getInstance().count()}' );
		_header.updateButtonEnabled = ExecutorManager.getInstance().count() == 0;

	}

	function _helpPageTextLink( e:SuperHumanApplicationEvent ) {

		switch e.text {

			case _TEXT_LINK_DEVOPS:
				Browsers.openLink(SuperHumanGlobals.DEVOPS_WIKI_URL);

			case _TEXT_LINK_DOMINO:
				Browsers.openLink(SuperHumanGlobals.DOMINO_WIKI_URL);

			case _TEXT_LINK_GENESIS_DIRECTORY:
				Browsers.openLink(SuperHumanGlobals.GENESIS_DIRECTORY_URL);

			case _TEXT_LINK_VAGRANT:
				Browsers.openLink(SuperHumanGlobals.VAGRANT_URL);

			case _TEXT_LINK_VIRTUALBOX:
				Browsers.openLink(SuperHumanGlobals.VIRTUALBOX_URL);

			case _TEXT_LINK_YAML:
				Browsers.openLink(SuperHumanGlobals.YAML_WIKI_URL);

			default:

		}

	}

	function _createServerAndSaveConfig(provisionerType:ProvisionerType) {
		var newServerData:ServerData = ServerManager.getInstance().getDefaultServerData( provisionerType );
		var server = ServerManager.getInstance().createServer( newServerData, provisionerType );
		server.onUpdate.add( onServerPropertyChanged );

		Logger.info( '${this}: New ${server} created' );

		ToastManager.getInstance().showToast( LanguageManager.getInstance().getString( 'toast.servercreated', 'with id ${server.id}' ) );

		_saveConfig();

		return server;
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
