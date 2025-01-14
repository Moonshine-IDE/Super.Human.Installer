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

package superhuman.server.provisioners;

import superhuman.server.provisioners.roles.RolesUtil;
import superhuman.browser.Browsers;
import champaign.core.logging.Logger;
import champaign.core.primitives.VersionInfo;
import genesis.application.managers.LanguageManager;
import haxe.Exception;
import haxe.Template;
import haxe.io.Path;
import lime.system.System;
import prominic.sys.io.FileTools;
import superhuman.managers.ProvisionerManager;
import superhuman.server.data.RoleData;
import superhuman.server.data.ServerData;
import superhuman.server.provisioners.ProvisionerType;
import sys.FileSystem;
import sys.io.File;

using champaign.core.tools.ObjectTools;

@:allow( superhuman.server.provisioners.HostsFileGenerator )
class DemoTasks extends AbstractProvisioner {

    static final _CURRENT_TASK_IDENTIFIER_PATTERN:EReg = ~/(?:TASK \x{5b})(\S+)(?:.+)(?:\x{3a})(?:.*)/m;
    static final _IP_ADDRESS_PATTERN:EReg = ~/(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)/;
    static final _SAFE_ID_FILE:String = "safe.ids";
    static final _DEFAULT_SAFE_ID_LOCATION:String = "safe-id-to-cross-certify";
    static final _TASK_IDENTIFIER_PATTERN:EReg = ~/(?:\s{6})(?:- name: )(\S+)/;
    static final _VERSION_PATTERN:EReg = ~/(\d{1,3}\.\d{1,3}\.\d{1,3})/;
    static final _WEB_ADDRESS_PATTERN:EReg = ~/(?:https:\/\/)(.*)(?::\d{1,5}\/welcome.html)/;

    // Additional templates for version 0.1.18+
    static final _TEMPLATE_DOMINO_INSTALL:String = "domino_install.template.yml";
    static final _TEMPLATE_DOMINO_LEAP:String = "domino_leap.template.yml";
    static final _TEMPLATE_DOMINO_NOMADWEB:String = "domino_nomadweb.template.yml";
    static final _TEMPLATE_DOMINO_TRAVELER:String = "domino_traveler.template.yml";
    static final _TEMPLATE_DOMINO_VAGRANT_REST_API:String = "domino_vagrant_rest_api.template.yml";
    static final _TEMPLATE_DOMINO_VERSE:String = "domino_verse.template.yml";
    static final _TEMPLATE_STARTCLOUD_HAPROXY:String = "startcloud_haproxy.template.yml";
    static final _TEMPLATE_STARTCLOUD_QUICK_START:String = "startcloud_quick_start.template.yml";
    static final _TEMPLATE_STARTCLOUD_VAGRANT_README:String = "startcloud_vagrant_readme.template.yml";

    static public final HOSTS_FILE:String = "Hosts.yml";
    static public final HOSTS_TEMPLATE_FILE:String = "Hosts.template.yml";
    static public final PROVISIONER_TYPE:ProvisionerType = ProvisionerType.DemoTasks;
    static public final PROVISIONING_PROOF_FILE:String = ".vagrant/provisioned-briged-ip.txt";
    static public final WEB_ADDRESS_FILE:String = ".vagrant/done.txt";

    static public function getDefaultProvisionerRoles():Map<String, RoleData> {

        return [

            "domino" => { value: "domino", enabled: true, files: { hotfixes: [], fixpacks: [] }, isdefault: true },
            "appdevpack" => { value: "appdevpack", enabled: false, files: {} },
            "nomadweb" => { value: "nomadweb", enabled: false, files: {} },
            "leap" => { value: "leap", enabled: false, files: {} },
            "traveler" => { value: "traveler", enabled: false, files: {} },
            "verse" => { value: "verse", enabled: false, files: {} },
            "domino-rest-api" => { value: "domino-rest-api", enabled: false, files: {} },

        ];

    }

    static public function getDefaultServerData( id:Int ):ServerData {

        return {

			env_open_browser: true,
			env_setup_wait: 300,

			//network_address: "192.168.2.227",
			//network_dns_nameserver_1: "1.1.1.1",
			//network_dns_nameserver_2: "1.0.0.1",
			//network_gateway: "192.168.2.1",
			//network_netmask: "255.255.255.0",

			dhcp4: true,
			network_address: "",
			network_dns_nameserver_1: "1.1.1.1",
			network_dns_nameserver_2: "1.0.0.1",
			network_gateway: "",
			network_netmask: "",

			network_bridge: "",
			resources_cpu: 2,
			resources_ram: 8.0,
			roles: [ for ( r in getDefaultProvisionerRoles().keyValueIterator() ) r.value ],
			server_hostname: "",
			server_id: id,
			server_organization: "",
			type: ServerType.Domino,
			user_email: "",
            provisioner: ProvisionerManager.getBundledProvisioners()[ 0 ].data,
            syncMethod: SyncMethod.Rsync,
		};

    }

    static public function getRandomServerId( serverDirectory:String ):Int {

		// Range: 1025 - 9999
		var r = Math.floor( Math.random() * 8974 ) + 1025;

		if ( FileSystem.exists( '${serverDirectory}${PROVISIONER_TYPE}/${r}' ) ) return getRandomServerId( serverDirectory );

		return r;

	}

    static public function getVersionFromFile( path:String ):VersionInfo {

        var v:VersionInfo = "0.0.0";

        try {

            var c = File.getContent( path );
            var m = _VERSION_PATTERN.match( c );
            if ( m )
                v = _VERSION_PATTERN.matched( 0 )
            else
                v = "0.0.0";

        } catch( e ) {

            v = "0.0.0";

        }

        return v;

    }

    var _hostsTemplate:String;
    var _onProvisioningFileChanged:List<()->Void>;
    var _startedTasks:Array<String>;
    var _tasks:Array<String>;

    public var hostFileExists( get, never ):Bool;
    function get_hostFileExists() return this.fileExists( HOSTS_FILE );

    public var ipAddress( get, never ):String;
    function get_ipAddress() {
        var result:String = null;
        var wa = _getWebAddress();
        if ( wa == null ) return result;
        try {
            if ( _IP_ADDRESS_PATTERN.match( wa ) ) return _IP_ADDRESS_PATTERN.matched( 0 );
        } catch ( e ) {};
        return result;
    }

    public var numberOfStartedTasks( get, never ):Int;
    function get_numberOfStartedTasks() return _startedTasks.length;

    public var numberOfTasks( get, never ):Int;
    function get_numberOfTasks() return _tasks.length;

    public var onProvisioningFileChanged( get, never ):List<()->Void>;
    function get_onProvisioningFileChanged() return _onProvisioningFileChanged;

    public var provisioned( get, never ):Bool;
    function get_provisioned() return _provisioningProofFileExists();

    public var provisionSuccessful( get, never ):Bool;
    function get_provisionSuccessful() return _webAddressValid();

    public var safeIdExists( get, never ):Bool;
    function get_safeIdExists() return this.fileExists( Path.addTrailingSlash( _DEFAULT_SAFE_ID_LOCATION ) + _SAFE_ID_FILE );

    public var server( get, never ):Server;
    function get_server() return _server;

    public var webAddress( get, never ):String;
    function get_webAddress() return _getWebAddress();
    
    public function new( sourcePath:String, targetPath:String, server:Server ) {

        super( superhuman.server.provisioners.ProvisionerType.DemoTasks, sourcePath, targetPath, server );

        _versionFile = "version.rb";
        
        _setVersionFromFiles();
 
        _onProvisioningFileChanged = new List();
    }

    public function calculateTotalNumberOfTasks() {

        _tasks = [];
        _startedTasks = [];

        try {

            var c = File.getContent( Path.addTrailingSlash( _targetPath ) + HOSTS_FILE );

            while ( true ) {

                if ( _TASK_IDENTIFIER_PATTERN.match( c ) ) {

                    var s = _TASK_IDENTIFIER_PATTERN.matched( 1 );
                    _tasks.push( s );
                    c = _TASK_IDENTIFIER_PATTERN.replace( c, "" );

                } else {

                    break;

                }

            }

        } catch ( e ) {};

        Logger.debug( '[${this._type} v${this._version}]: Total number of tasks: ${_tasks.length}' );
        Logger.debug( '[${this._type} v${this._version}]: Total tasks: ${_tasks}' );

    }

    public function copyInstallers( pathPairs:Array<PathPair>, callback:()->Void ) {

        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.copyinstallers', _targetPath ) );
        FileTools.batchCopy( pathPairs, FileOverwriteRule.IfSizeDifferent, callback, _fileCopied );

    }

    public function deleteProvisioningProofFile() {

        this.deleteFileInTargetDirectory( PROVISIONING_PROOF_FILE );

    }

    public function deleteWebAddressFile() {

        this.deleteFileInTargetDirectory( WEB_ADDRESS_FILE );

    }

    override function dispose() {

        if ( _onProvisioningFileChanged != null ) _onProvisioningFileChanged.clear();
        _onProvisioningFileChanged = null;

        super.dispose();

    }

    public function generateHostsFileContent():String {

        _hostsTemplate = getFileContentFromSourceTemplateDirectory( HOSTS_TEMPLATE_FILE );

        //if ( _version >= "0.1.18" ) return HostsFileGenerator.generateContentForV18( _hostsTemplate, this );
        return HostsFileGenerator.generateContent( _hostsTemplate, this );

    }

    public function openWelcomePage() {
        Browsers.openLink(_getWebAddress());
    }

    public override function reinitialize( sourcePath:String ) {

        super.reinitialize( sourcePath );

        _setVersionFromFiles();

        Logger.debug( '${this}: Reinitialized' );
    }
	
    public function saveHostsFile() {

        if ( _server.isValid() ) this._saveHostsFile();

    }

    public function saveSafeId( safeIdPath:String ):Bool {

        createTargetDirectory();

        if ( FileSystem.exists( safeIdPath ) ) {

            var safeIdDir = Path.addTrailingSlash( _targetPath ) + Path.addTrailingSlash( _getSafeIdLocation() );
            FileSystem.createDirectory( safeIdDir );

            try {

                File.copy( safeIdPath, safeIdDir + _SAFE_ID_FILE );
                if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.copysafeid', safeIdPath, safeIdDir + _SAFE_ID_FILE ) );
                return true;

            } catch ( e:Exception ) {

                Logger.error( '${this}: Notes Safe ID at ${safeIdPath} cannot be copied to ${safeIdDir + _SAFE_ID_FILE}. Details: ${e.details()} Message: ${e.message}' );
                if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.copysafeidfailed', '${e.details()} Message: ${e.message}' ), true );

            }

        } else {

            Logger.error( '${this}: Notes Safe ID does not exist at ${safeIdPath}' );
            if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.safeidnonexistent', safeIdPath ), true );

        }

        return false;

    }

    public override function toString():String {

        return '[DemoTasks(v${this.version})]';

    }

    public function updateTaskProgress( input:String ) {

        try {

            while ( true ) {

                if ( _CURRENT_TASK_IDENTIFIER_PATTERN.match( input ) ) {

                    var s = _CURRENT_TASK_IDENTIFIER_PATTERN.matched( 1 );
                    if ( !_startedTasks.contains( s ) && _tasks.contains( s ) ) _startedTasks.push( s );
                    input = _CURRENT_TASK_IDENTIFIER_PATTERN.replace( input, "" );

                } else {

                    break;

                }

            }

        } catch ( e ) {};

    }

    function _setVersionFromFiles() {
    		var versions:Array<Dynamic> = [];
        	var ver:Dynamic;
        	
        	if (_targetPath != null)
        	{
        		ver = {path: Path.addTrailingSlash( _targetPath ) + _versionFile , 
        					   version: getVersionFromFile( Path.addTrailingSlash( _targetPath ) + _versionFile )};
        		versions.push(ver);
        	}
        	
        if (_sourcePath != null ) 
        {
        		ver = {path: Path.addTrailingSlash( _targetPath ) + _versionFile, 
        			   version: getVersionFromFile( Path.addTrailingSlash( _sourcePath ) + AbstractProvisioner._SCRIPTS_ROOT + _versionFile )};
        		versions.push(ver);
		}

        versions = versions.filter(v -> v.version != 0);
        
        if (versions.length > 0) 
        {
        		var fullVer:Dynamic = versions.shift();
        		_version = fullVer.version;
    		}
    		else
    		{
    			_version = "0.0.0";
    		}
    }
    
    function _fileCopied( pathPair:PathPair, canCopy:Bool ) {

        if ( console != null ) {

            if ( canCopy ) {

                console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.copyinstaller', pathPair.source, pathPair.destination ) );

            } else {

                console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.installerexists', Path.withoutDirectory( pathPair.source ) ) );

            }

        }

    }

    function _getWebAddress():String {

        var e = _webAddressFileExists();

        if ( !e ) {

            Logger.error( '${this}: File at ${Path.addTrailingSlash( _targetPath ) + WEB_ADDRESS_FILE} doesn\'t exist' );
            return null;

        }

        try {

            var c = File.getContent( Path.addTrailingSlash( _targetPath ) + WEB_ADDRESS_FILE );
            if ( c == null || c.length == 0 ) return null;

            if ( _WEB_ADDRESS_PATTERN.match( c ) ) return _WEB_ADDRESS_PATTERN.matched( 0 );

        } catch( e ) {}

        return null;

    }

    override function _onFileWatcherFileAdded( path:String ) {

        super._onFileWatcherFileAdded( path );

        if ( path.indexOf( WEB_ADDRESS_FILE ) >= 0 ) {

            if ( _onProvisioningFileChanged != null ) for ( f in _onProvisioningFileChanged ) f();

        }

    }

    override function _onFileWatcherFileDeleted( path:String ) {

        super._onFileWatcherFileDeleted( path );

        if ( path.indexOf( WEB_ADDRESS_FILE ) >= 0 ) {

            if ( _onProvisioningFileChanged != null ) for ( f in _onProvisioningFileChanged ) f();

        }

    }

    function _provisioningProofFileExists():Bool {

        return FileSystem.exists( Path.addTrailingSlash( _targetPath ) + PROVISIONING_PROOF_FILE );

    }

    function _saveHostsFile() {

        createTargetDirectory();

        var content = generateHostsFileContent();

        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.hostsfilecontent', content ) );

        try {

            File.saveContent( Path.addTrailingSlash( _targetPath ) + HOSTS_FILE, content );
            Logger.debug( '${this}: Server configuration file created at ${Path.addTrailingSlash( _targetPath ) + HOSTS_FILE}' );
            if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.savehostsfile', Path.addTrailingSlash( _targetPath ) + HOSTS_FILE ) );

        } catch ( e:Exception ) {

            Logger.error( '${this}: Server configuration file cannot be created at ${Path.addTrailingSlash( _targetPath ) + HOSTS_FILE}. Details: ${e.details()} Message: ${e.message}' );
            if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.savehostsfileerror', Path.addTrailingSlash( _targetPath ) + HOSTS_FILE, '${e.details()} Message: ${e.message}' ), true );
            return;

        }

    }

    function _webAddressFileExists():Bool {

        return FileSystem.exists( Path.addTrailingSlash( _targetPath ) + WEB_ADDRESS_FILE );

    }

    function _webAddressValid():Bool {

        if ( !_webAddressFileExists() ) return false;

        try {

            var c = File.getContent( Path.addTrailingSlash( _targetPath ) + WEB_ADDRESS_FILE );
            if ( c == null || c.length == 0 ) return false;

            if ( _WEB_ADDRESS_PATTERN.match( c ) ) return true;

        } catch( e ) {}

        return false;

    }
    
    function _getSafeIdLocation():String {
    		if (version < "0.1.23")
    		{
    			return _DEFAULT_SAFE_ID_LOCATION;
    		}

    		return "id-files/user-safe-ids";
    }

}

class HostsFileGenerator {

    static public function generateContent( sourceTemplate:String, provisioner:DemoTasks ):String {

        var output:String = null;
			
        var versionGreaterThan20:Bool = provisioner.data.version > "0.1.20";
        var versionGreaterThan22:Bool = provisioner.data.version > "0.1.22";
        
        var defaultProvisionerFieldValue:String = versionGreaterThan22 ? null : "";
        var defaultRoleFieldValue:Dynamic = versionGreaterThan22 ? false : "";

        var syncMethod = provisioner.server.syncMethod;

        var replace = {

            USER_EMAIL: provisioner.server.userEmail.value,
            
            //settings
         	SERVER_HOSTNAME: provisioner.server.url.hostname,
         	SERVER_DOMAIN: provisioner.server.url.domainName,
         	SERVER_ID: provisioner.server.id,
            SHOW_CONSOLE: false,
            POST_PROVISION: false,
            BOX_URL: 'https://boxvault.startcloud.com',
            SYNC_METHOD: syncMethod,
            SYNCBACK_ID_FILES: true,
            DEBUG_ALL_ANSIBLE_TASKS: true,
         	RESOURCES_CPU: provisioner.server.numCPUs.value,
         	RESOURCES_RAM: Std.string( provisioner.server.memory.value ) + "G",
         	
            USE_HTTP_PROXY: false,
            HTTP_PROXY_HOST: '255.255.255.255',
            HTTP_PROXY_PORT: 3128,

         	//vagrant_user
         	SERVER_DEFAULT_USER: "startcloud",
         	SERVER_DEFAULT_USER_PASS: "STARTcloud24@!",
         	
         	//network
         	NETWORK_ADDRESS: ( provisioner.server.dhcp4.value ) ? "192.168.2.1" : provisioner.server.networkAddress.value,
         	NETWORK_NETMASK: ( provisioner.server.dhcp4.value ) ? "255.255.255.0" : provisioner.server.networkNetmask.value,
         	NETWORK_GATEWAY: ( provisioner.server.dhcp4.value ) ? "" : provisioner.server.networkGateway.value,
            // Always true, never false
         	NETWORK_DHCP4: true,
         	NETWORK_BRIDGE: provisioner.server.networkBridge.value,
         	
         	//dns
         	NETWORK_DNS_NAMESERVER_1: ( provisioner.server.dhcp4.value ) ? "1.1.1.1" : provisioner.server.nameServer1.value,
         	NETWORK_DNS_NAMESERVER_2: ( provisioner.server.dhcp4.value ) ? "1.0.0.1" : provisioner.server.nameServer2.value,
           
            //vars
            SERVER_ORGANIZATION: provisioner.server.organization.value,
            USER_SAFE_ID: superhuman.server.provisioners.DemoTasks._SAFE_ID_FILE,
            DOMINO_ADMIN_PASSWORD: "password",
            DOMINO_SERVER_CLUSTERMATES: 0,
            CERT_SELFSIGNED: ( provisioner.server.url.hostname + "." + provisioner.server.url.domainName ).toLowerCase() != "demo.startcloud.com",
			
		    DOMINO_IS_ADDITIONAL_INSTANCE: false,
			
            //Domino Variables
            DOMINO_HASH: defaultProvisionerFieldValue,
            DOMINO_INSTALLER: defaultProvisionerFieldValue,
            DOMINO_INSTALLER_VERSION: defaultProvisionerFieldValue,
            DOMINO_INSTALLER_MAJOR_VERSION: defaultProvisionerFieldValue,
            DOMINO_INSTALLER_MINOR_VERSION: defaultProvisionerFieldValue,
            DOMINO_INSTALLER_PATCH_VERSION: defaultProvisionerFieldValue,
            
            DOMINO_MAJOR_VERSION: defaultProvisionerFieldValue,
            DOMINO_MINOR_VERSION: defaultProvisionerFieldValue,
            DOMINO_PATCH_VERSION: defaultProvisionerFieldValue,
            
            //Domino fixpack Variables
            DOMINO_FP_HASH: defaultProvisionerFieldValue,
            DOMINO_INSTALLER_FIXPACK_INSTALL: false,
            DOMINO_INSTALLER_FIXPACK_VERSION: defaultProvisionerFieldValue,
            DOMINO_INSTALLER_FIXPACK: defaultProvisionerFieldValue,
            
            //Domino Hotfix Variables
            DOMINO_HF_HASH: defaultProvisionerFieldValue,
            DOMINO_INSTALLER_HOTFIX_INSTALL: false,
            DOMINO_INSTALLER_HOTFIX_VERSION: defaultProvisionerFieldValue,
            DOMINO_INSTALLER_HOTFIX: defaultProvisionerFieldValue,
            
            //Leap Variables
            LEAP_HASH: defaultProvisionerFieldValue,
            LEAP_INSTALLED_CHECK: false,
            LEAP_INSTALLER: defaultProvisionerFieldValue,
            LEAP_INSTALLER_VERSION: defaultProvisionerFieldValue,
		    
            //Nomad Web Variables
            NOMADWEB_HASH: defaultProvisionerFieldValue,
            NOMADWEB_INSTALLER: defaultProvisionerFieldValue,
            NOMADWEB_VERSION: defaultProvisionerFieldValue,
            
            //Traveler Variables
            TRAVELER_INSTALLER: defaultProvisionerFieldValue,
            TRAVELER_INSTALLER_VERSION: defaultProvisionerFieldValue,
            TRAVELER_FP_INSTALLER: defaultProvisionerFieldValue,
            TRAVELER_FP_INSTALLER_VERSION: defaultProvisionerFieldValue,
            
            //Verse Variables
            VERSE_INSTALLER: defaultProvisionerFieldValue,
            VERSE_INSTALLER_VERSION: defaultProvisionerFieldValue,
      		
            //AppDev Web Pack Variables
            APPDEVPACK_INSTALLER: defaultProvisionerFieldValue,
            APPDEVPACK_INSTALLER_VERSION: defaultProvisionerFieldValue,
            
            //Domino Rest API Variables
            DOMINO_REST_API_INSTALLER_VERSION: defaultProvisionerFieldValue,
            DOMINO_REST_API_INSTALLER: defaultProvisionerFieldValue,
            
            //roles
            ROLE_LEAP: defaultRoleFieldValue,
            ROLE_NOMADWEB: defaultRoleFieldValue,
            ROLE_TRAVELER: defaultRoleFieldValue,
            ROLE_TRAVELER_HTMO: defaultRoleFieldValue,
            ROLE_VERSE: defaultRoleFieldValue,
            ROLE_APPDEVPACK: defaultRoleFieldValue,
            ROLE_RESTAPI: defaultRoleFieldValue,
            ROLE_DOMINO_RESTAPI: defaultRoleFieldValue,
            ROLE_VOLTMX: defaultRoleFieldValue,
            ROLE_VOLTMX_DOCKER: defaultRoleFieldValue,
            ROLE_STARTCLOUD_QUICK_START: defaultRoleFieldValue,
            ROLE_STARTCLOUD_HAPROXY: defaultRoleFieldValue,
            ROLE_STARTCLOUD_VAGRANT_README: defaultRoleFieldValue,
            ROLE_DOMINO_RESET: defaultRoleFieldValue,
            ROLE_MARIADB: defaultRoleFieldValue,
            ROLE_DOCKER: defaultRoleFieldValue,
            
            ENV_OPEN_BROWSER: false,
            ENV_SETUP_WAIT: provisioner.server.setupWait.value,
        };

        for ( r in provisioner.server.roles.value ) {

			var roleValue = r.value;
			var replaceWith:String = "";
			var installerHash:String = r.files.installerHash == null ? defaultProvisionerFieldValue : "\"" + r.files.installerHash + "\"";
			var installerName:String = r.files.installerFileName == null ? defaultProvisionerFieldValue : r.files.installerFileName;
			var installerVersion:Dynamic = r.files.installerVersion;
			var hotfixVersion:Dynamic = r.files.installerHotFixVersion;
			var fixpackVersion:Dynamic = r.files.installerFixpackVersion;
			var installerHash:Dynamic = r.files.installerHash;
			
			if (r.value == "domino")
			{
				replace.DOMINO_HASH = installerHash;
				replace.DOMINO_INSTALLER = installerName;
						
				if (installerVersion != null)
				{
					if (installerVersion.hash != null)
					{
						replace.DOMINO_HASH = installerHash;
					}
					
					if (installerVersion.fullVersion != null)
					{
						replace.DOMINO_INSTALLER_VERSION = installerVersion.fullVersion;
					}
					
					if (installerVersion.majorVersion != null)
					{
						replace.DOMINO_INSTALLER_MAJOR_VERSION = installerVersion.majorVersion;
						replace.DOMINO_MAJOR_VERSION = installerVersion.majorVersion;
					}
					
					if (installerVersion.minorVersion != null)
					{
						replace.DOMINO_INSTALLER_MINOR_VERSION = installerVersion.minorVersion;
						replace.DOMINO_MINOR_VERSION = installerVersion.minorVersion;
					}
					
					if (installerVersion.patchVersion != null)
					{
						replace.DOMINO_INSTALLER_PATCH_VERSION = installerVersion.patchVersion;
						replace.DOMINO_PATCH_VERSION = installerVersion.patchVersion;
					}
				}
				
				if (r.files.hotfixes != null && r.files.hotfixes.length > 0)
				{
					var hotfixesPath = new Path(r.files.hotfixes[0]);
					
					replace.DOMINO_INSTALLER_HOTFIX_INSTALL = true;
					replace.DOMINO_INSTALLER_HOTFIX = hotfixesPath.file + "." + hotfixesPath.ext;
					replace.DOMINO_INSTALLER_HOTFIX_VERSION = hotfixVersion == null ? defaultProvisionerFieldValue : hotfixVersion.fullVersion;
				}
					
				if (r.files.fixpacks != null && r.files.fixpacks.length > 0)
				{
					var fixPacksPath = new Path(r.files.fixpacks[0]);
					
					replace.DOMINO_INSTALLER_FIXPACK_INSTALL = true;
					replace.DOMINO_INSTALLER_FIXPACK = fixPacksPath.file + "." + fixPacksPath.ext;
					replace.DOMINO_INSTALLER_FIXPACK_VERSION = fixpackVersion == null ? defaultProvisionerFieldValue : fixpackVersion.fullVersion;
				}
			}
		  	
            if ( r.value == "leap" ) {

                //"- name: hcl_domino_leap" : "- name: domino_leap";
                replaceWith = RolesUtil.getDominoRole(provisioner.data.version, r.value, r.enabled);
 
                replace.LEAP_HASH = installerHash;
                replace.LEAP_INSTALLED_CHECK = r.enabled;
                replace.LEAP_INSTALLER = installerName;
                replace.LEAP_INSTALLER_VERSION = installerVersion == null ? "" : installerVersion.fullVersion;
                replace.ROLE_LEAP = replaceWith;
             }

            if ( r.value == "nomadweb" ) {
                
                //"- name: hcl_domino_nomadweb" : "- name: domino_nomadweb";
                replaceWith = RolesUtil.getDominoRole(provisioner.data.version, r.value, r.enabled);
				
                replace.NOMADWEB_HASH = installerHash;
                replace.NOMADWEB_INSTALLER = installerName;
                replace.NOMADWEB_VERSION = installerVersion == null ? defaultProvisionerFieldValue : installerVersion.fullVersion;
                replace.ROLE_NOMADWEB = replaceWith;
            }

            if ( r.value == "traveler" ) {

                //"- name: hcl_domino_traveler" : "- name: domino_traveler"
                replaceWith = RolesUtil.getDominoRole(provisioner.data.version, r.value, r.enabled);
            	    
                replace.TRAVELER_INSTALLER = installerName;
                replace.TRAVELER_INSTALLER_VERSION = installerVersion == null ? defaultProvisionerFieldValue : installerVersion.fullVersion;
                replace.ROLE_TRAVELER = replaceWith;
            }

            if ( r.value == "traveler" ) {

                //"- name: hcl_domino_traveler_htmo" : "- name: domino_traveler_htmo"
                replaceWith = RolesUtil.getDominoRole(provisioner.data.version, "traveler_htmo", r.enabled);
                replace.ROLE_TRAVELER_HTMO = replaceWith;
            }

            if ( r.value == "verse" ) {

                //"- name: hcl_domino_verse" : "- name: domino_verse"
                replaceWith = RolesUtil.getDominoRole(provisioner.data.version, r.value, r.enabled);
       
                replace.VERSE_INSTALLER = installerName;
                replace.VERSE_INSTALLER_VERSION = installerVersion == null ? defaultProvisionerFieldValue : installerVersion.fullVersion;
                replace.ROLE_VERSE = replaceWith;
            }

            if ( r.value == "appdevpack" ) {

                //"- name: hcl_domino_appdevpack" : "- name: domino_appdevpack"
                replaceWith = RolesUtil.getDominoRole(provisioner.data.version, r.value, r.enabled);
            		
                replace.APPDEVPACK_INSTALLER = installerName;
                replace.APPDEVPACK_INSTALLER_VERSION = installerVersion == null ? defaultProvisionerFieldValue : installerVersion.fullVersion;
                replace.ROLE_APPDEVPACK = replaceWith;
            }

            if ( r.value == "domino-rest-api" ) {

                //"- name: hcl_domino_rest_api" : "- name: domino_rest_api"
                replaceWith = RolesUtil.getDominoRole(provisioner.data.version, "rest_api", r.enabled);

                replace.DOMINO_REST_API_INSTALLER = installerName;
                replace.DOMINO_REST_API_INSTALLER_VERSION = installerVersion == null ? defaultProvisionerFieldValue : installerVersion.fullVersion;
                replace.ROLE_RESTAPI = replaceWith;
                replace.ROLE_DOMINO_RESTAPI = replaceWith;
            }
			
            //"- name: startcloud_quick_start";
            replace.ROLE_STARTCLOUD_QUICK_START = RolesUtil.getOtherRole(provisioner.data.version, "quick_start");
             //"- name: startcloud_haproxy";
            replace.ROLE_STARTCLOUD_HAPROXY = RolesUtil.getOtherRole(provisioner.data.version, "haproxy");
            //"- name: startcloud_vagrant_readme";
            replace.ROLE_STARTCLOUD_VAGRANT_README = RolesUtil.getOtherRole(provisioner.data.version, "vagrant_readme");
        }

        var template = new Template( sourceTemplate );
		output = template.execute( replace );

        if ( provisioner.server.disableBridgeAdapter.value ) {

            // Remove the contents of networks yaml tag
            var r:EReg = ~/(?:networks:)((.|\n)*)(?:vbox:)/;
            
            if ( r.match( output ) ) {

                output = r.replace( output, "vbox:" );

            }

        }

        return output;

    }
}