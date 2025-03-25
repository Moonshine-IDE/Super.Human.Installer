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

package superhuman.server;

import superhuman.server.provisioners.AbstractProvisioner;
import superhuman.server.provisioners.ProvisionerType;
import superhuman.application.ApplicationData;
import prominic.sys.io.Executor;
import genesis.application.managers.LanguageManager;
import haxe.Json;
import haxe.Timer;
import haxe.io.Path;
import lime.system.System;
import lime.ui.FileDialog;
import lime.ui.FileDialogType;
import champaign.core.primitives.Property;
import prominic.core.primitives.ValidatingProperty;
import champaign.core.logging.Logger;
import prominic.sys.applications.bin.Shell;
import prominic.sys.applications.hashicorp.Vagrant;
import prominic.sys.applications.oracle.VirtualBox;
import prominic.sys.applications.oracle.VirtualBoxMachine;
import prominic.sys.io.AbstractExecutor;
import prominic.sys.io.FileTools;
import prominic.sys.tools.StrTools;
import superhuman.config.SuperHumanGlobals;
import superhuman.interfaces.IConsole;
import superhuman.managers.ProvisionerManager;
import superhuman.managers.ServerManager;
import superhuman.server.CombinedVirtualMachine.CombinedVirtualMachineState;
import superhuman.server.data.ProvisionerData;
import superhuman.server.data.RoleData;
import superhuman.server.data.ServerData;
import superhuman.server.provisioners.StandaloneProvisioner;
import superhuman.server.provisioners.CustomProvisioner;
import sys.FileSystem;
import sys.io.File;
import yaml.util.ObjectMap;
import yaml.Yaml;

using champaign.core.tools.ObjectTools;

class Server {

    static final _CONFIG_FILE = "server.shi";

    static final _VK_CERTIFIER:EReg = ~/^(?!\W)([a-zA-Z0-9-]+)?([^\W])$/;
    static final _VK_DOMAIN:EReg = ~/^[a-zA-Z0-9]+\.[a-zA-Z0-9.-_]+$/;
    static final _VK_HOSTNAME:EReg = ~/^(?:[a-zA-Z0-9\-]+)((\.{1})([a-zA-Z0-9\-]+)(\.{1})([a-zA-Z0-9\-]{2,})){0,1}([^-\.])$/;
    static final _VK_HOSTNAME_FULL:EReg = ~/^(?!\W)(?:[a-zA-Z0-9\-]+)(?:\.{0,1})(?:[a-zA-Z0-9\-]+)((?:\.{0,1})(?:[a-zA-Z]+)){0,1}(?:[^\W])$/;
    public static final _VK_IP:EReg = ~/^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
    static final _VK_NAME:EReg = ~/^[a-zA-Z0-9 _\-.]*$/;
    static final _VK_NAME_ALPHANUMERIC:EReg = ~/^[a-zA-Z0-9]*$/;
    static final _VK_SERVER_NAME:EReg = ~/^[a-zA-Z0-9 _-]*$/;
    static final _VK_SUBDOMAIN:EReg = ~/^[a-zA-Z0-9][a-zA-Z0-9]*$/;
    #if hl
    static final _VK_EMAIL:EReg = ~/^\w+([-+.']\w+)*@\w+([-.]\w+)*\.\w+([-.]\w+)*$/;
    #else
    static final _VK_EMAIL:EReg = ~/^(([^<>()\[\]\\.,;:\s@"]+(\.[^<>()\[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/;
    #end

    static public var keepFailedServersRunning:Bool = false;

    static public function create( data:ServerData, rootDir:String ):Server {
        var sc = new Server();

        sc._id = data.server_id;
        
        // Determine the server directory based on provisioner type
        var provisionerTypeForPath = data.provisioner != null ? data.provisioner.type : ProvisionerType.StandaloneProvisioner;
        sc._serverDir = Path.normalize( rootDir + "/" + provisionerTypeForPath + "/" + sc._id );
        FileSystem.createDirectory( sc._serverDir );
        sc._path.value = sc._serverDir;

        var latestStandaloneProvisioner = ProvisionerManager.getBundledProvisioners()[ 0 ];

        if ( data.provisioner == null ) {
            // Default to StandaloneProvisioner for null provisioner
            sc._provisioner = new StandaloneProvisioner(ProvisionerType.StandaloneProvisioner, latestStandaloneProvisioner.root, sc._serverDir, sc );
        } else {
            var provisioner = ProvisionerManager.getProvisionerDefinition( data.provisioner.type, data.provisioner.version );

            if ( provisioner != null ) {
                // Create the appropriate provisioner based on type
                if (data.provisioner.type == ProvisionerType.StandaloneProvisioner || 
                    data.provisioner.type == ProvisionerType.AdditionalProvisioner) {
                    // Use StandaloneProvisioner for built-in provisioner types
                    sc._provisioner = new StandaloneProvisioner(data.provisioner.type, provisioner.root, sc._serverDir, sc );
                } else {
                    // For custom provisioner types, use CustomProvisioner
                    sc._provisioner = new CustomProvisioner(data.provisioner.type, provisioner.root, sc._serverDir, sc );
                    Logger.info('${sc}: Created custom provisioner of type ${data.provisioner.type}');
                }
            } else {
                // The server already exists BUT the provisioner version is not supported
                // so we create the provisioner with target path only
                if (data.provisioner.type == ProvisionerType.StandaloneProvisioner || 
                    data.provisioner.type == ProvisionerType.AdditionalProvisioner) {
                    // Use StandaloneProvisioner for built-in provisioner types
                    sc._provisioner = new StandaloneProvisioner(data.provisioner.type, null, sc._serverDir, sc );
                } else {
                    // For custom provisioner types, use CustomProvisioner
                    sc._provisioner = new CustomProvisioner(data.provisioner.type, null, sc._serverDir, sc );
                    Logger.info('${sc}: Created custom provisioner of type ${data.provisioner.type} with null root');
                }
            }
        }

        sc._hostname.value = data.server_hostname;
        sc._memory.value = data.resources_ram;
        sc._nameServer1.value = data.network_dns_nameserver_1;
        sc._nameServer2.value = data.network_dns_nameserver_2;
        sc._networkAddress.value = data.network_address;
        sc._networkBridge.value = data.network_bridge;
        sc._networkGateway.value = data.network_gateway;
        sc._networkNetmask.value = data.network_netmask;
        sc._numCPUs.value = data.resources_cpu;
        sc._openBrowser.value = data.env_open_browser;
        sc._organization.value = data.server_organization;
        sc._roles.value = data.roles;
        sc._setupWait.value = data.env_setup_wait;
        sc._userEmail.value = data.user_email;
        sc._userSafeId.value = data.user_safeid;
        sc._serverProvisionerId.value = data.server_provisioner_id;
        sc._syncMethod = data.syncMethod == null ? SyncMethod.Rsync : data.syncMethod;
        sc._type = ( data.type != null ) ? data.type : ServerType.Domino;
        sc._dhcp4.value = ( data.dhcp4 != null ) ? data.dhcp4 : false;
        sc._combinedVirtualMachine.value = { home: sc._serverDir, serverId: sc._id, vagrantMachine: { vagrantId: null, serverId: sc._id }, virtualBoxMachine: { virtualBoxId: null, serverId: sc._id } };
        sc._disableBridgeAdapter.value = ( data.disable_bridge_adapter != null ) ? data.disable_bridge_adapter : false;
        sc._hostname.locked = sc._organization.locked = ( sc._provisioner.provisioned == true );
        
        // Initialize customProperties from data if available
        if (data.customProperties != null) {
            sc._customProperties = data.customProperties;
        }
        
        sc._created = true;
        sc._setServerStatus();
        return sc;

    }

    static public function getComputedName( hostname:String, organization:String ):ServerURL {

        var result:ServerURL = { domainName: "", hostname: "", path: "" };

        var a = hostname.split( "." );

        if ( a.length == 1 && a[0].length > 0 ) {

            result.hostname = a[0];
            result.domainName = organization + ".com";

        } else if ( a.length == 3 ) {

            result.hostname = a[0];
            result.domainName = a[1] + "." + a[2];

        } else {

            /*
            result.hostname = a[0].toLowerCase();
            var s = "";
            for ( i in 1...a.length ) s += a[i].toLowerCase() + ".";
            result.domainName = s;
            */
            result.hostname = "configure";
            result.domainName = "host.name";

        }

        result.path = organization;

        return result;

    }

    var _action:Property<ServerAction>;
    var _busy:Property<Bool>;
    var _combinedVirtualMachine:Property<CombinedVirtualMachine>;
    var _console:IConsole;
    var _created:Bool = false;
    var _currentAction:ServerAction = ServerAction.None( false );
    var _dhcp4:Property<Bool>;
    var _disableBridgeAdapter:Property<Bool>;
    var _diskUsage:Property<Float>;
    var _forceVagrantProvisioning:Bool;
    var _hostname:ValidatingProperty;
    var _id:Int;
    var _memory:Property<Float>;
    var _nameServer1:ValidatingProperty;
    var _nameServer2:ValidatingProperty;
    var _networkAddress:ValidatingProperty;
    var _networkBridge:ValidatingProperty;
    var _networkGateway:ValidatingProperty;
    var _networkNetmask:ValidatingProperty;
    var _numCPUs:Property<Int>;
    var _onStatusUpdate:List<( Server, Bool ) -> Void>;
    var _onUpdate:List<( Server, Bool ) -> Void>;
    var _onVagrantUpElapsedTimerUpdate:List<()->Void>;
    var _openBrowser:Property<Bool>;
    var _organization:ValidatingProperty;
    var _path:Property<String>;
    var _provisionedBeforeStart:Bool;
    var _provisioner:StandaloneProvisioner;
    var _refreshingVirtualBoxVMInfo:Bool = false;
    var _roles:Property<Array<RoleData>>;
    var _serverDir:String;
    var _setupWait:Property<Int>;
    var _status:Property<ServerStatus>;
    var _type:String;
    var _userEmail:ValidatingProperty;
    var _userSafeId:Property<String>;
    var _serverProvisionerId:Property<String>;
    var _vagrantHaltExecutor:AbstractExecutor;
    var _vagrantSuspendExecutor:AbstractExecutor;
    var _vagrantUpElapsedTime:Float;
    var _vagrantUpExecutor:AbstractExecutor;
    var _vagrantUpExecutorElapsedTimer:Timer;
    var _vagrantUpExecutorStopTimer:Timer;
    var _syncMethod:SyncMethod = SyncMethod.Rsync;
    var _customProperties:Dynamic = {};

    public var busy( get, never ):Bool;
    function get_busy() return _busy.value;

    public var console( get, set ):IConsole;
    function get_console() return _console;
    function set_console( value:IConsole ):IConsole { _console = value; _provisioner.console = value; return _console; }

    public var combinedVirtualMachine( get, never ):Property<CombinedVirtualMachine>;
    function get_combinedVirtualMachine() return _combinedVirtualMachine;

    public var currentAction( get, never ):ServerAction;
    function get_currentAction() return _currentAction;

    public var dhcp4( get, never ):Property<Bool>;
    function get_dhcp4() return _dhcp4;

    public var disableBridgeAdapter( get, never ):Property<Bool>;
    function get_disableBridgeAdapter() return _disableBridgeAdapter;

    public var diskUsage( get, never ):Property<Float>;
    function get_diskUsage() return _diskUsage;

    public var fqdn( get, never ):String;
    function get_fqdn():String {

        return url.hostname + "." + url.domainName + "/" + url.path;

    }

    public var domainName( get, never ):String;
    function get_domainName():String {
        return url.hostname + "." + url.domainName;
    }

    public var hasExecutionErrors:Bool = false;

    public var hostname( get, never ):ValidatingProperty;
    function get_hostname() return _hostname;
    
    public var id( get, never ):Int;
    function get_id() return _id;
    
    public var memory( get, never ):Property<Float>;
    function get_memory() return _memory;
    
    public var nameServer1( get, never ):ValidatingProperty;
    function get_nameServer1() return _nameServer1;
    
    public var nameServer2( get, never ):ValidatingProperty;
    function get_nameServer2() return _nameServer2;
    
    public var networkBridge( get, never ):ValidatingProperty;
    function get_networkBridge() return _networkBridge;
    
    public var networkAddress( get, never ):ValidatingProperty;
    function get_networkAddress() return _networkAddress;
    
    public var networkNetmask( get, never ):ValidatingProperty;
    function get_networkNetmask() return _networkNetmask;
    
    public var networkGateway( get, never ):ValidatingProperty;
    function get_networkGateway() return _networkGateway;
    
    public var numCPUs( get, never ):Property<Int>;
    function get_numCPUs() return _numCPUs;

    public var onStatusUpdate( get, never ):List<( Server, Bool ) -> Void>;
    function get_onStatusUpdate() return _onStatusUpdate;
    
    public var onUpdate( get, never ):List<( Server, Bool ) -> Void>;
    function get_onUpdate() return _onUpdate;
    
    public var onVagrantUpElapsedTimerUpdate( get, never ):List<() -> Void>;
    function get_onVagrantUpElapsedTimerUpdate() return _onVagrantUpElapsedTimerUpdate;
    
    public var openBrowser( get, never ):Property<Bool>;
    function get_openBrowser() return _openBrowser;
    
    public var organization( get, never ):ValidatingProperty;
    function get_organization() return _organization;
    
    public var path( get, never ):Property<String>;
    function get_path() return _path;

    public var provisioned( get, never ):Bool;
    function get_provisioned() return _provisioner.provisioned;

    public var provisionedBeforeStart( get, never ):Bool;
    function get_provisionedBeforeStart() return _provisionedBeforeStart;

    public var provisioner( get, never ):AbstractProvisioner;
    function get_provisioner() return _provisioner;

    public var roles( get, never ):Property<Array<RoleData>>;
    function get_roles() return _roles;

    public var serverDir( get, never ):String;
    function get_serverDir() return _serverDir;
    
    public var setupWait( get, never ):Property<Int>;
    function get_setupWait() return _setupWait;
    
    public var status( get, never ):Property<ServerStatus>;
    function get_status() return _status;

    public var url( get, never ):ServerURL;
    function get_url() {
        return getComputedName( _hostname.value, _organization.value );
    }
    
    public var userEmail( get, never ):ValidatingProperty;
    function get_userEmail() return _userEmail;

    public var userSafeId( get, never ):Property<String>;
    function get_userSafeId() return _userSafeId;

    public var serverProvisionerId( get, never ):Property<String>;
    function get_serverProvisionerId() return _serverProvisionerId;

    public var vagrantUpElapsedTime( get, never ):Float;
    function get_vagrantUpElapsedTime() return _vagrantUpElapsedTime;

    public var virtualBoxId( get, never ):String;
    function get_virtualBoxId() {
        return '${Std.string( this._id )}--${this.domainName}';
    }

    public var webAddress( get, never ):String;
    function get_webAddress() return _getWebAddress();

    public var syncMethod(get, set):SyncMethod;
    function get_syncMethod() return _syncMethod;
    function set_syncMethod( value:SyncMethod ):SyncMethod { _syncMethod = value; return _syncMethod; }
    
    public var customProperties(get, set):Dynamic;
    function get_customProperties() return _customProperties;
    function set_customProperties(value:Dynamic):Dynamic { _customProperties = value; return _customProperties; }
    
    // Backwards compatibility accessor
    public var userData(get, set):Dynamic;
    function get_userData() return _customProperties;
    function set_userData(value:Dynamic):Dynamic { _customProperties = value; return _customProperties; }
    
    function new() {

        _id = Math.floor( Math.random() * 9000 ) + 1000;

        _action = new Property( null, true );
        _action.onChange.add( _actionChanged );

        _busy = new Property( false );
        _busy.onChange.add( _propertyChanged );

        _combinedVirtualMachine = new Property( { state: CombinedVirtualMachineState.Unknown } );
        _combinedVirtualMachine.onChange.add( _propertyChanged );

        _dhcp4 = new Property( true );
        _dhcp4.onChange.add( _propertyChanged );

        _disableBridgeAdapter = new Property( true );
        _disableBridgeAdapter.onChange.add( _propertyChanged );

        _diskUsage = new Property( 0.0 );
        _diskUsage.onChange.add( _propertyChanged );

        _memory = new Property( 1.0 );
        _memory.onChange.add( _propertyChanged );

        _hostname = new ValidatingProperty( "", _VK_HOSTNAME, 1 );
        _hostname.onChange.add( _propertyChanged );

        _nameServer1 = new ValidatingProperty( "", _VK_IP, true );
        _nameServer1.onChange.add( _propertyChanged );

        _nameServer2 = new ValidatingProperty( "", _VK_IP, true );
        _nameServer2.onChange.add( _propertyChanged );

        _networkBridge = new ValidatingProperty( "", true );
        _networkBridge.onChange.add( _propertyChanged );

        _networkAddress = new ValidatingProperty( "", _VK_IP, true );
        _networkAddress.onChange.add( _propertyChanged );

        _networkNetmask = new ValidatingProperty( "", _VK_IP, true );
        _networkNetmask.onChange.add( _propertyChanged );

        _networkGateway = new ValidatingProperty( "", _VK_IP, true );
        _networkGateway.onChange.add( _propertyChanged );

        _numCPUs = new Property( 1 );
        _numCPUs.onChange.add( _propertyChanged );

        _onStatusUpdate = new List();
        _onUpdate = new List();
        _onVagrantUpElapsedTimerUpdate = new List();

        _openBrowser = new Property( false );
        _openBrowser.onChange.add( _propertyChanged );

        _organization = new ValidatingProperty( "", _VK_CERTIFIER, 1 );
        _organization.onChange.add( _propertyChanged );

        _path = new Property( "" );
        _path.onChange.add( _propertyChanged );

        _roles = new Property( [] );
        _roles.onChange.add( _propertyChanged );

        _setupWait = new Property( 300 );
        _setupWait.onChange.add( _propertyChanged );

        _status = new Property( ServerStatus.Unconfigured );
        _status.onChange.add( _serverStatusChanged );

        _type = ServerType.Domino;

        _userEmail = new ValidatingProperty( "", _VK_EMAIL, true );
        _userEmail.onChange.add( _propertyChanged );

        _userSafeId = new Property();
        _userSafeId.onChange.add( _propertyChanged );

        _serverProvisionerId = new Property();
        _serverProvisionerId.onChange.add( _propertyChanged );
    }

    public function dispose() {

        if ( _onStatusUpdate != null ) _onStatusUpdate.clear();
        _onStatusUpdate = null;

        if ( _onUpdate != null ) _onUpdate.clear();
        _onUpdate = null;

        if ( _onVagrantUpElapsedTimerUpdate != null ) _onVagrantUpElapsedTimerUpdate.clear();
        _onVagrantUpElapsedTimerUpdate = null;

        if ( _provisioner != null ) _provisioner.dispose();
        _provisioner = null;
    }

    public function getData():ServerData {

        var data:ServerData = {

            server_hostname: this._hostname.value,
            server_id: this._id,
            resources_ram: this._memory.value,
            network_dns_nameserver_1: this._nameServer1.value,
            network_dns_nameserver_2: this._nameServer2.value,
            network_bridge: this._networkBridge.value,
            network_address: this._networkAddress.value,
            network_netmask: this._networkNetmask.value,
            network_gateway: this._networkGateway.value,
            resources_cpu: this._numCPUs.value,
            env_open_browser: this._openBrowser.value,
            server_organization: this._organization.value,
            env_setup_wait: this._setupWait.value,
            user_email: this._userEmail.value,
            user_safeid: ( this._userSafeId != null && this._userSafeId.value != null ) ? this._userSafeId.value : null,
            server_provisioner_id: ( this._serverProvisionerId != null && this._serverProvisionerId.value != null ) ? this._serverProvisionerId.value : null,
            roles: this._roles.value,
            type: this._type,
            dhcp4: this._dhcp4.value,
            provisioner: this._provisioner.data,
            disable_bridge_adapter: this._disableBridgeAdapter.value,
            syncMethod: this._syncMethod,
            existingServerName: "",
            existingServerIpAddress: "",
            customProperties: this._customProperties
        };

        return data;

    }

    public function initDirectory() {

        _provisioner.copyFiles();

    }

    public function isValid():Bool {

        var hasVagrant:Bool = Vagrant.getInstance().exists;
        var hasVirtualBox:Bool = VirtualBox.getInstance().exists;
        var isHostnameValid:Bool = _hostname.isValid();
        var isOrganizationValid:Bool = _organization.isValid();
        var isMemorySufficient:Bool = _memory.value >= 4;
        var isCPUCountSufficient:Bool = _numCPUs.value >= 1;
        
        var isNetworkValid:Bool = _dhcp4.value || (
            _networkBridge.isValid() &&
            _networkAddress.isValid() &&
            _networkGateway.isValid() &&
            _networkNetmask.isValid() &&
            _nameServer1.isValid() &&
            _nameServer2.isValid()
        );
        
        var hasSafeId:Bool = safeIdExists();
        var areRolesOK:Bool = areRolesValid();

        var isValid:Bool = 
            hasVagrant &&
            hasVirtualBox &&
            isHostnameValid &&
            isOrganizationValid &&
            isMemorySufficient &&
            isCPUCountSufficient &&
            isNetworkValid &&
            hasSafeId &&
            areRolesOK;
            
        return isValid;

    }

    public function locateNotesSafeId( ?callback:()->Void ) {

        var dir = ( SuperHumanInstaller.getInstance().config.user.lastuseddirectory != null ) ? SuperHumanInstaller.getInstance().config.user.lastuseddirectory : System.userDirectory;
        var fd = new FileDialog();
        var currentDir:String;

        fd.onSelect.add( path -> {

            currentDir = Path.directory( path );
            _userSafeId.value = path;

            if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.safeidselected', path ) );

            if ( currentDir != null ) SuperHumanInstaller.getInstance().config.user.lastuseddirectory = currentDir;
            if ( callback != null ) callback();

        } );

        fd.browse( FileDialogType.OPEN, null, dir + "/", "Locate your Notes Safe Id file with .ids extension" );

    }

    public function openVagrantSSH() {

        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.vagrantssh' ) );

        var currDir = Sys.getCwd();
        Sys.setCwd( this._serverDir );
        Vagrant.getInstance().ssh();
        Sys.setCwd( currDir );

    }

    public function openFtpClient(appData:ApplicationData) {
    		if ( console != null ) 
    		{
    			if (appData != null && appData.exists)
    			{
    				console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.openftp' ) );
    				Logger.info( '${this}: ' + LanguageManager.getInstance().getString( 'serverpage.server.console.openftp' ) );
			}
			else
			{
				console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.openftpFailed', appData.appId ) );
				Logger.info( '${this}: ' + LanguageManager.getInstance().getString( 'serverpage.server.console.openftpFailed', appData.appId ) );
				return;
			}
		}
    			
    		var hostsFileMap = Yaml.read(Path.addTrailingSlash( this.provisioner.targetPath ) + superhuman.server.provisioners.StandaloneProvisioner.HOSTS_FILE);
    		var hosts:TObjectMap<String, Dynamic> = hostsFileMap.get('hosts')[0];
    		var settings:TObjectMap<String, Dynamic> = hosts.get('settings');
    		var userName = settings.get('vagrant_user');
    		var pass = settings.get('vagrant_user_pass');
    		
    		var ftpAppCommand = 'sftp://${userName}:${pass}@${this.domainName}';
			var clientCommand = appData.executablePath;
    		#if windows
			clientCommand = 'start "" "${appData.executablePath}" ${ftpAppCommand}';
			Sys.command( clientCommand );
			Logger.info( '${this}: ' + '[Execute: ${clientCommand}]' );
    		#else
			var ftpExecutor = new Executor(clientCommand, [ftpAppCommand]);
    			ftpExecutor.execute();
		#end
    }
    
    public function saveData() {
        try {
            // Get the server data with customProperties included
            var data = getData();
            
            // Log what we're saving
            Logger.info('${this}: Saving server data to ${Path.addTrailingSlash(this._serverDir) + _CONFIG_FILE}');
            Logger.info('${this}: customProperties included in save: ${this._customProperties != null}');
            
            // Check if customProperties exists and has dynamic custom properties
            if (this._customProperties != null) {
                var hasCustomProps = Reflect.hasField(this._customProperties, "dynamicCustomProperties");
                var hasAdvancedProps = Reflect.hasField(this._customProperties, "dynamicAdvancedCustomProperties");
                Logger.info('${this}: customProperties has: dynamicCustomProperties=${hasCustomProps}, dynamicAdvancedCustomProperties=${hasAdvancedProps}');
            }
            
            var s = Json.stringify(data);
            File.saveContent(Path.addTrailingSlash(this._serverDir) + _CONFIG_FILE, s);
            Logger.info('${this}: Server data saved successfully');

        } catch (e) {
            Logger.error('${this}: Error saving server data: ${e}');
        };
    }

    public function start( provision:Bool = false ) {

        this._currentAction = ServerAction.Start( false );
        this._busy.value = true;

        // Clean up Vagrant's cache before starting to handle cases where the VM was deleted outside the application
        Vagrant.getInstance().pruneGlobalStatus();

        _forceVagrantProvisioning = provision;
        this.status.value = ServerStatus.Initializing;
        this.combinedVirtualMachine.value.virtualBoxMachine.virtualBoxId = this.virtualBoxId;

        if ( console != null ) {

            console.clear();
            console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.start' ) );

        }

        _prepareFiles();
    }

    public function updateProvisioner( data:ProvisionerData ):Bool {
        // Capture the original version string for preservation
        var versionStr = null;
        if (data != null && data.version != null) {
            versionStr = data.version.toString();
            Logger.info('${this}: Updating provisioner from version ${this._provisioner.version} to ${versionStr}');
        } else {
            Logger.warning('${this}: Updating provisioner with null or invalid version');
            return false;
        }

        // Force provisioner update even if the version appears the same
        var vcd = ProvisionerManager.getProvisionerDefinition(data.type, data.version);
        
        if (vcd != null) {
            Logger.info('${this}: Found matching provisioner definition: ${vcd.name}');
            var newRoot:String = vcd.root;
            this._provisioner.reinitialize(newRoot);
            
            // Store the version string directly in customProperties for better persistence
            if (this._customProperties == null) {
                this._customProperties = {};
            }
            
            // Store exact string version in serviceTypeData
            if (!Reflect.hasField(this._customProperties, "serviceTypeData")) {
                Reflect.setField(this._customProperties, "serviceTypeData", {});
            }
            var serviceTypeData = Reflect.field(this._customProperties, "serviceTypeData");
            
            if (!Reflect.hasField(serviceTypeData, "provisioner")) {
                Reflect.setField(serviceTypeData, "provisioner", {});
            }
            var stProvisioner = Reflect.field(serviceTypeData, "provisioner");
            
            if (!Reflect.hasField(stProvisioner, "data")) {
                Reflect.setField(stProvisioner, "data", {});
            }
            var provData = Reflect.field(stProvisioner, "data");
            
            // Store both string version and original VersionInfo
            Reflect.setField(provData, "version", versionStr);
            Reflect.setField(provData, "versionInfo", data.version);
            
            // Also update any stored provisionerDefinition if present
            if (Reflect.hasField(this._customProperties, "provisionerDefinition")) {
                var provDef = Reflect.field(this._customProperties, "provisionerDefinition");
                if (provDef != null && Reflect.hasField(provDef, "data")) {
                    // Store both string version and original VersionInfo
                    Reflect.setField(provDef.data, "version", versionStr);
                    Reflect.setField(provDef.data, "versionInfo", data.version);
                }
            }
            
            // Directly set the version in the provisioner object to ensure it's displayed correctly
            // This is necessary because ServerList directly accesses _server.provisioner.version
            // for display in the server overview
            if (Reflect.hasField(this._provisioner, "_version")) {
                try {
                    // Use reflection to directly update the _version field in the provisioner
                    Reflect.setField(this._provisioner, "_version", data.version);
                    Logger.info('${this}: Directly updated provisioner._version to ${data.version}');
                } catch (e) {
                    Logger.warning('${this}: Could not update provisioner._version directly: ${e}');
                }
            }
            
            // Trigger update notification
            _propertyChanged(this._provisioner);
            
            // Save the updated data immediately
            this.saveData();
            
            Logger.info('${this}: Successfully updated provisioner to version ${versionStr}');
            return true;
        } else {
            Logger.warning('${this}: Could not find provisioner definition for type ${data.type}, version ${versionStr}');
            return false;
        }
    }

    function _prepareFiles() {

        _provisioner.copyFiles(_prepareFilesComplete);

    }

    function _prepareFilesComplete() {

        Logger.info( '${this}: Configuration files copied to ${this._serverDir}' );
        Logger.info( '${this}: Copying installer files to ${this._serverDir}/installers' );

        var paths:Array<PathPair> = [];

        for ( r in _roles.value ) {

            if ( r.enabled ) {

                if ( r.files.installer != null ) {

                    var dest:String = Path.normalize( this._serverDir + "/installers/" + r.value + "/archives/" + Path.withoutDirectory( r.files.installer ) );
                    paths.push( { source: r.files.installer, destination: dest } );

                }

                if ( r.files.hotfixes != null ) {

                    for ( h in r.files.hotfixes ) {

                        var dest:String = Path.normalize( this._serverDir + "/installers/" + r.value + "/archives/" + Path.withoutDirectory( h ) );
                        paths.push( { source: h, destination: dest } );

                    }
                }

                if ( r.files.fixpacks != null ) {

                    for ( f in r.files.fixpacks ) {

                        var dest:String = Path.normalize( this._serverDir + "/installers/" + r.value + "/archives/" + Path.withoutDirectory( f ) );
                        paths.push( { source: f, destination: dest } );

                    }
                }

            }

        }

        Logger.info( '${this}: Installer and Fixpack path pairs: ${paths}' );

        _provisioner.copyInstallers( paths, _batchCopyComplete );

    }

    function _batchCopyComplete() {

        Logger.info( '${this}: Setting working directory to ${_serverDir}' );
        if (console != null) {
        		console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.setworkingdirectory', _serverDir ) );
		}
		
        _saveSafeId();

        if ( !_provisioner.hostFileExists ) _provisioner.saveHostsFile();

        if ( console != null ) {
            console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.hostsfilecontent', _provisioner.getFileContentFromTargetDirectory( superhuman.server.provisioners.StandaloneProvisioner.HOSTS_FILE ) ) );
            console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.virtualboxmachine', Std.string( this._combinedVirtualMachine.value.virtualBoxMachine ) ) );
        }

		_startVagrantUp();
    }

    function _saveSafeId() {

        var r = _provisioner.saveSafeId( _userSafeId.value );
        if ( !r ) this._busy.value = false;

    }

    public function saveHostsFile() {

        if ( isValid() ) 
        {
            cast(this.provisioner, StandaloneProvisioner).saveHostsFile();
        }
    }

    function _actionChanged( prop:Property<ServerAction> ) { }

    function _propertyChanged<T>( property:T ) {

        if ( !_created ) return;

        _setServerStatus();

        for ( f in _onUpdate ) f( this, true );

    }

    public function safeIdExists():Bool {

        if ( _userSafeId == null || _userSafeId.value == null || _userSafeId.value == "" ) return false;

        return FileSystem.exists( _userSafeId.value );

    }

    public function areRolesValid():Bool {
        // Check if this is a custom provisioner
        var isCustomProvisioner = (_provisioner != null && 
                                  _provisioner.data != null && 
                                  _provisioner.data.type != ProvisionerType.StandaloneProvisioner && 
                                  _provisioner.data.type != ProvisionerType.AdditionalProvisioner &&
                                  _provisioner.data.type != ProvisionerType.Default);
                                  
        // For custom provisioners, just make sure at least one role is enabled
        if (isCustomProvisioner) {
            var hasEnabledRole = false;
            
            for (r in this._roles.value) {
                if (r.enabled) {
                    // Check if this role has a showInstaller property set to false
                    var skipInstallerCheck = false;
                    if (Reflect.hasField(r, "showInstaller") && Reflect.field(r, "showInstaller") == false) {
                        skipInstallerCheck = true;
                    }
                    
                    hasEnabledRole = true;
                    
                    // Still check installer file if it's required for this role
                    if (!skipInstallerCheck && 
                        (r.files.installer == null || r.files.installer == "null" || !FileSystem.exists(r.files.installer))) {
                        Logger.info('Role ${r.value} is missing required installer file');
                        return false;
                    }
                }
            }
            
            return hasEnabledRole;
        }
        
        // Original logic for built-in provisioners
        var valid:Bool = false;
        
        for (r in this._roles.value) {
            if (r.enabled) {
                valid = true;
                if (r.files.installer == null || r.files.installer == "null" || !FileSystem.exists(r.files.installer)) {
                    return false;
                }
            }
        }
        
        return valid;
    }

    function _getVagrantName():String {

        return Std.string( this._id ) + "--" + this.url.hostname + "." + this.url.domainName;

    }

    function _getWebAddress():String {

        var s = _provisioner.webAddress;

        if ( s == null ) {

            Logger.info( '${this}: The web address file has invalid content or non-existent' );
            if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.webaddressinvalid' ) );

        } else {

            Logger.info( '${this}: Web address file content: ${s}' );
            if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.webaddressvalue', s ) );

        }

        return s;

    }

    //
    // Vagrant provision
    //

    public function provision() {

        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.provision' ) );

        this._busy.value = true;
        this._status.value = ServerStatus.Provisioning;

        _provisioner.deleteProvisioningProofFile();

        if ( !Lambda.has( Vagrant.getInstance().onProvision, _onVagrantProvision ) )
            Vagrant.getInstance().onProvision.add( _onVagrantProvision );

        Vagrant.getInstance().getProvision( this._combinedVirtualMachine.value.vagrantMachine )
            .onStdOut.add( _vagrantProvisionStandardOutputData )
            .onStdErr.add( _vagrantProvisionStandardErrorData )
            .execute( this._serverDir );

    }

    function _onVagrantProvision( machine:VagrantMachine ) {

        if ( machine.serverId != this._id ) return;

        Vagrant.getInstance().onProvision.remove( _onVagrantProvision );

        Logger.info( '${this}: _onVagrantProvision' );
        this._busy.value = false;
        this._status.value = ServerStatus.Running( false );

    }

    function _vagrantProvisionStandardOutputData( executor:AbstractExecutor, data:String ) {

        if ( console != null && !SuperHumanInstaller.getInstance().config.preferences.disablevagrantlogging ) console.appendText( data );
        Logger.info( '${this}: Vagrant provision: ${data}' );

    }

    function _vagrantProvisionStandardErrorData( executor:AbstractExecutor, data:String ) {

        if ( console != null ) console.appendText( data, true );
        Logger.error( '${this}: Vagrant provision error: ${data}' );
        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.provisionerror' ), true );

    }

    //
    // Vagrant rsync
    //

    public function rsync() {

        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.rsync' ) );

        this._busy.value = true;
        this._status.value = ServerStatus.RSyncing;

        if ( !Lambda.has( Vagrant.getInstance().onRSync, _onVagrantRSync ) )
            Vagrant.getInstance().onRSync.add( _onVagrantRSync );

        Vagrant.getInstance().getRSync( this._combinedVirtualMachine.value.vagrantMachine )
            .onStdOut.add( _vagrantRSyncStandardOutputData )
            .onStdErr.add( _vagrantRSyncStandardErrorData )
            .execute( this._serverDir );

    }

    function _onVagrantRSync( machine:VagrantMachine ) {

        if ( machine.serverId != this._id ) return;

        Vagrant.getInstance().onRSync.remove( _onVagrantRSync );

        Logger.info( '${this}: _onVagrantRSync' );
        this._busy.value = false;
        this._status.value = ServerStatus.Running( false );

    }

    function _vagrantRSyncStandardOutputData( executor:AbstractExecutor, data:String ) {

        if ( console != null && !SuperHumanInstaller.getInstance().config.preferences.disablevagrantlogging ) console.appendText( data );
        Logger.info( '${this}: Vagrant rsync: ${data}' );

    }

    function _vagrantRSyncStandardErrorData( executor:AbstractExecutor, data:String ) {

        if ( console != null ) console.appendText( data, true );
        Logger.error( '${this}: Vagrant rsync error: ${data}' );
        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.rsyncerror' ), true );

    }

    //
    // Vagrant stop
    //

    public function stop( forced:Bool = false ) {

        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.stop' ) );

        this._busy.value = true;
        this.status.value = ServerStatus.Stopping( forced );
        this._currentAction = ServerAction.Stop( false );

        if ( !Lambda.has( Vagrant.getInstance().onHalt, _onVagrantHalt ) )
            Vagrant.getInstance().onHalt.add( _onVagrantHalt );

        _vagrantHaltExecutor = Vagrant.getInstance()
            .getHalt( this._combinedVirtualMachine.value.vagrantMachine, forced )
            .onStdOut.add( _vagrantHaltStandardOutputData )
            .onStdErr.add( _vagrantHaltStandardErrorData )
            .execute( this._serverDir );

    }

    function _onVagrantHalt( machine:VagrantMachine ) {

        if ( machine.serverId != this._id ) return;

        Vagrant.getInstance().onHalt.remove( _onVagrantHalt );

        if ( _vagrantHaltExecutor.hasErrors || _vagrantHaltExecutor.exitCode > 0 ) {

            Logger.error( '${this}: Server cannot be stopped' );

        } else {

            Logger.info( '${this}: Server stopped' );

        }

        this._currentAction = ServerAction.Stop( _vagrantHaltExecutor.hasErrors || _vagrantHaltExecutor.exitCode > 0 );
        refreshVirtualBoxInfo();

    }

    function _vagrantHaltStandardOutputData( executor:AbstractExecutor, data:String ) {

        if ( console != null && !SuperHumanInstaller.getInstance().config.preferences.disablevagrantlogging ) console.appendText( data );
        Logger.info( '${this}: Vagrant halt: ${data}' );

    }

    function _vagrantHaltStandardErrorData( executor:AbstractExecutor, data:String ) {

        if ( console != null ) console.appendText( data, true );
        Logger.error( '${this}: Vagrant halt error: ${data}' );
        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.stopfailed' ), true );

    }

    //
    // Vagrant suspend
    //

    public function suspend() {

        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.suspend' ) );

        this._busy.value = true;
        this.status.value = ServerStatus.Suspending;
        this._currentAction = ServerAction.Suspend( false );

        if ( !Lambda.has( Vagrant.getInstance().onSuspend, _onVagrantSuspend ) )
            Vagrant.getInstance().onSuspend.add( _onVagrantSuspend );

        _vagrantSuspendExecutor = Vagrant.getInstance()
            .getSuspend( this._combinedVirtualMachine.value.vagrantMachine )
            //.onStdOut( _vagrantHaltStandardOutputData )
            //.onStdErr( _vagrantHaltStandardErrorData )
            .execute( this._serverDir );

    }

    function _onVagrantSuspend( machine:VagrantMachine ) {

        if ( machine.serverId != this._id ) return;

        Vagrant.getInstance().onSuspend.remove( _onVagrantSuspend );

        if ( _vagrantSuspendExecutor.hasErrors || _vagrantSuspendExecutor.exitCode > 0 ) {

            Logger.error( '${this}: Server cannot be suspended' );
            if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.suspendederror' ), true );

        } else {

            Logger.info( '${this}: Server suspended' );
            if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.suspended' ) );

        }

        this._currentAction = ServerAction.Suspend( _vagrantSuspendExecutor.hasErrors || _vagrantSuspendExecutor.exitCode > 0 );
        refreshVirtualBoxInfo();

    }

    //
    // Vagrant destroy
    //

    public function destroy() {

        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.destroy' ) );

        this._busy.value = true;
        this._status.value = ServerStatus.Destroying( this._status.value == ServerStatus.Aborted );

        _provisioner.deleteWebAddressFile();

        if ( !Lambda.has( Vagrant.getInstance().onDestroy, _onVagrantDestroy ) )
            Vagrant.getInstance().onDestroy.add( _onVagrantDestroy );

        Vagrant.getInstance().getDestroy( this._combinedVirtualMachine.value.vagrantMachine, true )
            .onStdOut.add( _vagrantDestroyStandardOutputData )
            .onStdErr.add( _vagrantDestroyStandardErrorData )
            .execute( this._serverDir );

    }

    function _vagrantDestroyStandardOutputData( executor:AbstractExecutor, data:String ) {

        if ( console != null && !SuperHumanInstaller.getInstance().config.preferences.disablevagrantlogging ) console.appendText( data );
        Logger.info( '${this}: Vagrant destroy: ${data}' );

    }

    function _vagrantDestroyStandardErrorData( executor:AbstractExecutor, data:String ) {

        if ( console != null ) console.appendText( data, true );
        Logger.error( '${this}: Vagrant destroy error: ${data}' );
        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.destroyerror' ), true );

    }

    function _onVagrantDestroy( machine:VagrantMachine ) {

        if ( machine.serverId != this._id ) return;

        Vagrant.getInstance().onDestroy.remove( _onVagrantDestroy );

        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.destroyed' ) );

        Logger.info( '${this}: destroyed' );

        this._provisioner.deleteProvisioningProofFile();

        if ( this.status.value.match( ServerStatus.Destroying( true ) ) )
            _unregisterVM()
        else
            refreshVirtualBoxInfo();

    }

    function _unregisterVM() {

        if ( !Lambda.has( VirtualBox.getInstance().onUnregisterVM, _vmUnregistered ) )
            VirtualBox.getInstance().onUnregisterVM.add( _vmUnregistered );

        final executor = VirtualBox.getInstance().getUnregisterVM( this._combinedVirtualMachine.value.virtualBoxMachine, true );
        executor.execute( this._serverDir );

    }

    function _vmUnregistered( machine:VirtualBoxMachine ) {

        if ( machine.virtualBoxId != this._combinedVirtualMachine.value.virtualBoxMachine.virtualBoxId ) return;

        Logger.info('${this}: unregistered VM Id ' + machine.virtualBoxId);
        VirtualBox.getInstance().onUnregisterVM.remove( _vmUnregistered );

        refreshVirtualBoxInfo();

    }

    //
    // Vagrant up
    //

    function _startVagrantUp() {

        _provisioner.calculateTotalNumberOfTasks();
        _provisioner.startFileWatcher();

        this._busy.value = true;

        _provisionedBeforeStart = this._provisioner.provisioned;
        this.status.value = ServerStatus.Start( this._provisioner.provisioned );
        //_provisioner.deleteWebAddressFile();
        _provisioner.onProvisioningFileChanged.add( _onStandaloneProvisionerProvisioningFileChanged );

        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.vagrantupstart', '(provision:${_forceVagrantProvisioning})' ) );

        // If this is the first time starting the server, install the vagrant-scp-sync plugin first
        if (!_provisionedBeforeStart) {
            _installVagrantPlugin();
        } else {
            _executeVagrantUp();
        }
    }
    
    /**
     * Install the vagrant-scp-sync plugin before running vagrant up for the first time
     */
    function _installVagrantPlugin() {
        if (console != null) console.appendText("Installing vagrant-scp-sync plugin...");
        Logger.info('${this}: Installing vagrant-scp-sync plugin');
        
        // Create a custom executor for the plugin installation command
        var pluginExecutor = new Executor(Vagrant.getInstance().path + Vagrant.getInstance().executable, ["plugin", "install", "vagrant-scp-sync"]);
        pluginExecutor.onStart.add(_pluginInstallStarted);
        pluginExecutor.onStop.add(_pluginInstallStopped);
        pluginExecutor.onStdOut.add(_pluginInstallStandardOutputData);
        pluginExecutor.onStdErr.add(_pluginInstallStandardErrorData);
        
        pluginExecutor.execute(_serverDir);
    }
    
    function _pluginInstallStarted(executor:AbstractExecutor) {
        Logger.info('${this}: Vagrant plugin installation started');
        if (console != null) console.appendText("Vagrant plugin installation started");
    }
    
    function _pluginInstallStopped(executor:AbstractExecutor) {
        Logger.info('${this}: Vagrant plugin installation completed with exit code: ${executor.exitCode}');
        if (console != null) {
            if (executor.exitCode == 0) {
                console.appendText("Vagrant plugin installation completed successfully");
            } else {
                console.appendText("Vagrant plugin installation failed with exit code: ${executor.exitCode}", true);
            }
        }
        
        // Now proceed with vagrant up, regardless of whether the plugin installation succeeded
        _executeVagrantUp();
    }
    
    function _pluginInstallStandardOutputData(executor:AbstractExecutor, data:String) {
        if (console != null) console.appendText(data);
        Logger.info('${this}: Vagrant plugin installation: ${data}');
    }
    
    function _pluginInstallStandardErrorData(executor:AbstractExecutor, data:String) {
        if (console != null) console.appendText(data, true);
        Logger.error('${this}: Vagrant plugin installation error: ${data}');
    }
    
    /**
     * Execute the vagrant up command
     */
    function _executeVagrantUp() {
        _vagrantUpExecutor = Vagrant.getInstance().getUp( this._combinedVirtualMachine.value.vagrantMachine, _forceVagrantProvisioning, [] )
            .onStart.add( _vagrantUpStarted )
            .onStop.add( _vagrantUpStopped )
            .onStdOut.add( _vagrantUpStandardOutputData )
            .onStdErr.add( _vagrantUpStandardErrorData );

        _vagrantUpExecutor.execute( _serverDir );
        _vagrantUpElapsedTime = 0;
        _startVagrantUpElapsedTimer();
    }

    function _vagrantUpStarted( executor:AbstractExecutor ) {

        Logger.info( '${this}: Vagrant up started' );
        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.vagrantupstarted' ) );

    }

    function _vagrantUpStopped( executor:AbstractExecutor ) {

        if ( executor.exitCode > 0 ) {
            Logger.error( '${this}: Vagrant up stopped with exitcode: ${executor.exitCode}' );
        } else {
            Logger.info( '${this}: Vagrant up stopped with exitcode: ${executor.exitCode}' );
        }

        var elapsed = StrTools.timeToFormattedString( _vagrantUpElapsedTime );
        Logger.info( '${this}: Vagrant up elapsed time: ${elapsed}' );

        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.vagrantupstopped', Std.string( executor.exitCode ), elapsed ), executor.exitCode > 0 );

        hasExecutionErrors = executor.hasErrors || executor.exitCode > 0;
        this._currentAction = ServerAction.Start( hasExecutionErrors );

        if ( hasExecutionErrors ) {

            // Vagrant up finished with either exitcode > 0, or an error happened during execution

            if ( keepFailedServersRunning ) {

                // Keeping the failed server running in its current state
                Logger.info( '${this}: Server start was unsuccessful, keeping the server in its current status' );

                // Refreshing VirtualBox info
                this._currentAction = ServerAction.GetStatus( true );
                refreshVirtualBoxInfo();

            } else {

                // Stop or destroy the server

                if ( _provisionedBeforeStart ) {

                    // The server was provisioned before, so 'vagrant halt' is needed
                    Logger.info( '${this}: Server start was unsuccessful, stopping server' );

                    if ( !Lambda.has( Vagrant.getInstance().onHalt, _onVagrantUpHalt ) )
                        Vagrant.getInstance().onHalt.add( _onVagrantUpHalt );
            
                    this._currentAction = ServerAction.Stop( true );
                    Vagrant.getInstance().getHalt( this._combinedVirtualMachine.value.vagrantMachine, false ).execute( this._serverDir );

                } else {

                    // The server wasn't provisioned before, so 'vagrant destroy' is needed
                    Logger.info( '${this}: First start was unsuccessful, destroying server' );
                    //_provisioner.deleteWebAddressFile();

                    if ( !Lambda.has( Vagrant.getInstance().onDestroy, _onVagrantUpDestroy ) )
                        Vagrant.getInstance().onDestroy.add( _onVagrantUpDestroy );

                    this._currentAction = ServerAction.Destroy( true );
                    Vagrant.getInstance().getDestroy( this._combinedVirtualMachine.value.vagrantMachine, true ).execute( this._serverDir );

                }

            }

        } else {

            // Vagrant up successfully finished without errors
            if ( this._openBrowser.value ) {

                if ( _provisioner != null ) _provisioner.openWelcomePage();

            }

            // Refreshing VirtualBox info
            this._currentAction = ServerAction.GetStatus( false );
            refreshVirtualBoxInfo();

        }

        executor.dispose();

    }

    function _vagrantUpStandardOutputData( executor:AbstractExecutor, data:String ) {
     
    		var vagrantLogging:Bool = SuperHumanInstaller.getInstance().config.preferences.disablevagrantlogging;
        if ( console != null && !vagrantLogging ) console.appendText( new String( data ) );
        Logger.info( '${this}: Vagrant up: ${data}' );
        _provisioner.updateTaskProgress( data );
        
    }

    function _vagrantUpStandardErrorData( executor:AbstractExecutor, data:String ) {
        
        if ( console != null ) console.appendText( data, true );
        Logger.error( '${this}: Vagrant up error: ${data}' );

    }

    function _onVagrantUpDestroy( machine:VagrantMachine ) {

        if ( machine.serverId != this._id ) return;

        Logger.info( '${this}: Vagrant destroy finished after server\'s first start was unsuccessful' );
        Vagrant.getInstance().onDestroy.remove( _onVagrantUpDestroy );

        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.destroyed' ), true );

        this._combinedVirtualMachine.value = { home: this._serverDir, serverId: this._id, state: CombinedVirtualMachineState.NotCreated, vagrantMachine: { vagrantId: null, serverId: this._id }, virtualBoxMachine: { virtualBoxId: null, serverId: this._id } };
        this._vagrantUpExecutor = null;
        this._provisioner.stopFileWatcher();
        this._provisioner.onProvisioningFileChanged.clear();
        this._provisioner.deleteProvisioningProofFile();
        this._stopVagrantUpElapsedTimer();

        this._currentAction = ServerAction.GetStatus( false );
        refreshVirtualBoxInfo();

    }

    function _onVagrantUpHalt( machine:VagrantMachine ) {

        if ( machine.serverId != this._id ) return;

        Logger.info( '${this}: Vagrant halt finished after server start was unsuccessful' );
        Vagrant.getInstance().onDestroy.remove( _onVagrantUpHalt );

        //if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.destroyed' ), true );

        this._vagrantUpExecutor = null;
        this._provisioner.stopFileWatcher();
        this._provisioner.onProvisioningFileChanged.clear();
        this._stopVagrantUpElapsedTimer();

        this._currentAction = ServerAction.GetStatus( false );
        refreshVirtualBoxInfo();

    }

    //
    // VirtualBox
    //

    public function refreshVirtualBoxInfo() {
        if ( _refreshingVirtualBoxVMInfo) return;

        Logger.info( '${this}: Refreshing combined VM ${this._combinedVirtualMachine.value.virtualBoxMachine} and execute at ${this._serverDir}' );

        VirtualBox.getInstance().onShowVMInfo.add( _onVirtualBoxShowVMInfo );
        
        var combinedVMExecutor:AbstractExecutor = VirtualBox.getInstance().getShowVMInfo( this._combinedVirtualMachine.value.virtualBoxMachine );
        		combinedVMExecutor.onStart.add( _virtualMachineStarted );
            combinedVMExecutor.onStop.add( _virtualMachineStopped );
            combinedVMExecutor.onStdOut.add( _virtualMachineStandardOutputData );
            combinedVMExecutor.onStdErr.add( _virtualMachineStandardErrorData );
            
        combinedVMExecutor.execute( this._serverDir );
        _refreshingVirtualBoxVMInfo = true;
    }

    function _virtualMachineStarted( executor:AbstractExecutor ) {

        Logger.info( '${this}: Refreshed Virtual Machine started ' + executor.id );
    }
    
    function _virtualMachineStopped( executor:AbstractExecutor ) {

        Logger.info( '${this}: Refreshed Virtual Machine stopped ' + executor.id );
    }
    
    function _virtualMachineStandardOutputData( executor:AbstractExecutor, data:String ) {

        Logger.info( '${this}: Refreshed Virtual Machine standard output: ${data}');
    }
    
    function _virtualMachineStandardErrorData( executor:AbstractExecutor, data:String ) {

    		Logger.info( '${this}: Refreshed Virtual Machine error: ${data}');
    }
    
    function _onVirtualBoxShowVMInfo( machine:VirtualBoxMachine ) {

        if ( machine.virtualBoxId != this._combinedVirtualMachine.value.virtualBoxMachine.virtualBoxId ) return;

        VirtualBox.getInstance().onShowVMInfo.remove( _onVirtualBoxShowVMInfo );
        _refreshingVirtualBoxVMInfo = false;

        Logger.info( '${this}: VirtualBox VM Info has been refreshed for id: ${id}' );

        var vbm = VirtualBox.getInstance().getVirtualMachineById( this._combinedVirtualMachine.value.virtualBoxMachine.virtualBoxId );

        if ( vbm != null ) {

            Logger.info( '${this}: VirtualBox VM: ${this._combinedVirtualMachine.value.virtualBoxMachine}' );
            setVirtualBoxMachine( vbm );
            // calculateDiskSpace();

        } else {

            // The virtual machine no longer exists
            Logger.warning( '${this}: VirtualBox VM no longer exists, resetting object' );
            setVirtualBoxMachine( {} );

        }

        _setServerStatus();

        this._busy.value = false;

    }

    //
    // Combined Virtual Machine
    //

    public function setVagrantMachine( machine:VagrantMachine ) {

        _combinedVirtualMachine.value.vagrantMachine = {};
        _combinedVirtualMachine.value.vagrantMachine.applyObject( machine );
        _combinedVirtualMachine.value.vagrantMachine.serverId = this._id;

    }

    public function setVirtualBoxMachine( machine:VirtualBoxMachine ) {

        _combinedVirtualMachine.value.virtualBoxMachine = {};
        _combinedVirtualMachine.value.virtualBoxMachine.applyObject( machine );
        _combinedVirtualMachine.value.virtualBoxMachine.virtualBoxId = this.virtualBoxId;
        _combinedVirtualMachine.value.virtualBoxMachine.serverId = this._id;

    }

    //
    // Server Status
    //

    function _setServerStatus( ignoreBusyState:Bool = false ) {

        // Do not change status if server is busy
        if ( !ignoreBusyState && this._busy.value ) return;

        this._status.value = ServerManager.getInstance().getRealStatus( this );
        this._currentAction = ServerAction.None( false );

        this._hostname.locked = this._organization.locked = this._userSafeId.locked = this._roles.locked = this._networkBridge.locked = 
        this._networkAddress.locked = this._networkGateway.locked = this._networkNetmask.locked = this._dhcp4.locked = this._userEmail.locked = this._disableBridgeAdapter.locked =
            ( this._provisioner != null && this._provisioner.provisioned == true );

    }

    function _serverStatusChanged( property:Property<ServerStatus> ) {

        for ( f in _onStatusUpdate ) f( this, false );

    }

    public function setServerStatus() {

        _setServerStatus();

    }

    //
    // Provisioning and Provisioning proof check
    //

    public function deleteProvisioningProof() {

        if ( this._provisioner != null ) this._provisioner.deleteProvisioningProofFile();
        _setServerStatus();

    }

    function _onStandaloneProvisionerProvisioningFileChanged() {

        if ( _vagrantUpExecutorStopTimer != null ) {

            // Stopping the timer if it alredy exists
            _vagrantUpExecutorStopTimer.stop();
            _vagrantUpExecutorStopTimer = null;

        }

        // Was the server provisioned?
        if ( this._provisioner.provisioned ) {

            // Is the vagrant up executor still running?
            if ( _vagrantUpExecutor != null ) {

                // Wait 5 seconds to make sure
                _vagrantUpExecutorStopTimer = Timer.delay( () -> {

                    if ( _vagrantUpExecutor != null ) _vagrantUpExecutor.simulateStop();

                }, SuperHumanGlobals.SIMULATE_VAGRANT_UP_EXIT_TIMEOUT );

            }

        }

    }

    //
    // Calculating elapsed time for vagrant up
    //

    function _startVagrantUpElapsedTimer() {

        _stopVagrantUpElapsedTimer();

        _vagrantUpExecutorElapsedTimer = new Timer( 1000 );
        _vagrantUpExecutorElapsedTimer.run = () -> {
            _vagrantUpElapsedTime = _vagrantUpExecutor.runtime;
            if ( _onVagrantUpElapsedTimerUpdate != null ) for ( f in _onVagrantUpElapsedTimerUpdate ) f();
        };

    }

    function _stopVagrantUpElapsedTimer() {

        if ( _vagrantUpExecutorElapsedTimer != null ) {

            _vagrantUpExecutorElapsedTimer.stop();
            _vagrantUpExecutorElapsedTimer = null;

        }

    }

    public function toString():String {

        return '[Server(${this._id})]';

    }

    //
    // Local filesystem functions
    //

    public function calculateDiskSpace() {

        #if mac
        var f = Shell.getInstance().du( this._serverDir );

        if ( this._combinedVirtualMachine.value != null && this._combinedVirtualMachine.value.virtualBoxMachine.root != null )
            f += Shell.getInstance().du( this._combinedVirtualMachine.value.virtualBoxMachine.root );

        _diskUsage.value = f;
        #end

    }

}
