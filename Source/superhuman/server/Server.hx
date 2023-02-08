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

import genesis.application.managers.LanguageManager;
import haxe.Json;
import haxe.Timer;
import haxe.io.Path;
import lime.system.System;
import lime.ui.FileDialog;
import lime.ui.FileDialogType;
import prominic.core.primitives.Property;
import prominic.core.primitives.ValidatingProperty;
import prominic.logging.Logger;
import prominic.sys.applications.bin.Shell;
import prominic.sys.applications.hashicorp.Vagrant;
import prominic.sys.applications.oracle.VirtualBox;
import prominic.sys.applications.oracle.VirtualBoxMachine;
import prominic.sys.io.AbstractExecutor;
import prominic.sys.io.FileTools;
import superhuman.config.SuperHumanGlobals;
import superhuman.interfaces.IConsole;
import superhuman.managers.ProvisionerManager;
import superhuman.server.CombinedVirtualMachine.CombinedVirtualMachineState;
import superhuman.server.data.ProvisionerData;
import superhuman.server.data.RoleData;
import superhuman.server.data.ServerData;
import superhuman.server.provisioners.DemoTasks;
import sys.FileSystem;
import sys.io.File;

class Server {

    static final _CONFIG_FILE = "server.shi";

    static final _VK_CERTIFIER:EReg = ~/^(?!\W)([a-zA-Z0-9-]+)?([^\W])$/;
    static final _VK_DOMAIN:EReg = ~/^[a-zA-Z0-9]+\.[a-zA-Z0-9.-_]+$/;
    static final _VK_HOSTNAME:EReg = ~/^(?:[a-zA-Z0-9\-]+)((\.{1})([a-zA-Z0-9\-]+)(\.{1})([a-zA-Z0-9\-]{2,})){0,1}([^-\.])$/;
    static final _VK_HOSTNAME_FULL:EReg = ~/^(?!\W)(?:[a-zA-Z0-9\-]+)(?:\.{0,1})(?:[a-zA-Z0-9\-]+)((?:\.{0,1})(?:[a-zA-Z]+)){0,1}(?:[^\W])$/;
    static final _VK_IP:EReg = ~/^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
    static final _VK_NAME:EReg = ~/^[a-zA-Z0-9 _\-.]*$/;
    static final _VK_NAME_ALPHANUMERIC:EReg = ~/^[a-zA-Z0-9]*$/;
    static final _VK_SERVER_NAME:EReg = ~/^[a-zA-Z0-9 _-]*$/;
    static final _VK_SUBDOMAIN:EReg = ~/^[a-zA-Z0-9][a-zA-Z0-9]*$/;
    #if hl
    static final _VK_EMAIL:EReg = ~/^\w+([-+.']\w+)*@\w+([-.]\w+)*\.\w+([-.]\w+)*$/;
    #else
    static final _VK_EMAIL:EReg = ~/^(([^<>()\[\]\\.,;:\s@"]+(\.[^<>()\[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/;
    #end

    static public function create( data:ServerData, rootDir:String ):Server {

        var sc = new Server();

        sc._id = data.server_id;
        sc._serverDir = Path.normalize( rootDir + "/demo-tasks/" + sc._id );
        FileSystem.createDirectory( sc._serverDir );
        sc._path.value = sc._serverDir;

        var latestDemoTasks = ProvisionerManager.getBundledProvisioners()[ 0 ];

        if ( data.provisioner == null ) {

            sc._provisioner = new DemoTasks( latestDemoTasks.root, sc._serverDir, sc );

        } else {

            var provisioner = ProvisionerManager.getProvisionerDefinition( data.provisioner.type, data.provisioner.version );

            if ( provisioner != null ) {

                sc._provisioner = new DemoTasks( provisioner.root, sc._serverDir, sc );

            } else {

                // The server already exists BUT the provisioner version is not supported
                // so we create the provisioner with target path only
                sc._provisioner = new DemoTasks( null, sc._serverDir, sc );

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
        sc._type = ( data.type != null ) ? data.type : ServerType.Domino;
        sc._dhcp4.value = ( data.dhcp4 != null ) ? data.dhcp4 : false;
        sc._combinedVirtualMachine.value = { home: sc._serverDir, vagrantId: null, virtualBoxId: null, state: CombinedVirtualMachineState.Unknown, serverId: sc._id };
        sc._disableBridgeAdapter.value = ( data.disable_bridge_adapter != null ) ? data.disable_bridge_adapter : false;
        sc._hostname.locked = sc._organization.locked = ( sc._provisioner.provisioned == true );
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
            result.hostname = "invalid";
            result.domainName = "domain.name";

        }

        result.path = organization;

        return result;

    }

    var _action:Property<ServerAction>;
    var _busy:Property<Bool>;
    var _combinedVirtualMachine:Property<CombinedVirtualMachine>;
    var _console:IConsole;
    var _created:Bool = false;
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
    var _provisioner:DemoTasks;
    var _refreshingVirtualBoxVMInfo:Bool = false;
    var _roles:Property<Array<RoleData>>;
    var _serverDir:String;
    var _setupWait:Property<Int>;
    var _status:Property<ServerStatus>;
    var _type:String;
    var _userEmail:ValidatingProperty;
    var _userSafeId:Property<String>;
    var _vagrantMachine:VagrantMachine;
    var _vagrantUpElapsedTime:Float;
    var _vagrantUpExecutor:AbstractExecutor;
    var _vagrantUpExecutorElapsedTimer:Timer;
    var _vagrantUpExecutorStopTimer:Timer;
    var _virtualBoxMachine:VirtualBoxMachine;
    
    public var busy( get, never ):Bool;
    function get_busy() return _busy.value;

    public var console( get, set ):IConsole;
    function get_console() return _console;
    function set_console( value:IConsole ):IConsole { _console = value; _provisioner.console = value; return _console; }

    public var combinedVirtualMachine( get, never ):Property<CombinedVirtualMachine>;
    function get_combinedVirtualMachine() return _combinedVirtualMachine;

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

    public var provisioner( get, never ):DemoTasks;
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

    public var vagrantUpElapsedTime( get, never ):Float;
    function get_vagrantUpElapsedTime() return _vagrantUpElapsedTime;

    public var virtualBoxId( get, never ):String;
    function get_virtualBoxId() {
        return '${Std.string( this._id )}--${this.domainName}';
    }

    public var webAddress( get, never ):String;
    function get_webAddress() return _getWebAddress();

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
            roles: this._roles.value,
            type: this._type,
            dhcp4: this._dhcp4.value,
            provisioner: this._provisioner.data,
            disable_bridge_adapter: this._disableBridgeAdapter.value,

        };

        return data;

    }

    public function initDirectory() {

        _provisioner.copyFiles();

    }

    public function isValid():Bool {

        var isValid:Bool = false;

        isValid = 

            Vagrant.getInstance().exists &&
            VirtualBox.getInstance().exists &&
            _hostname.isValid() &&
            _organization.isValid() &&
            _memory.value >= 4 &&
            _numCPUs.value >= 1 &&

            ( _dhcp4.value || (

                _networkBridge.isValid() &&
                _networkAddress.isValid() &&
                _networkGateway.isValid() &&
                _networkNetmask.isValid() &&
                _nameServer1.isValid() &&
                _nameServer2.isValid()
    
            ) ) &&

            safeIdExists() &&
            areRolesValid()

        ;

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

    public function saveData() {

        try {

            var s = Json.stringify( getData() );
            File.saveContent( Path.addTrailingSlash( this._serverDir ) + _CONFIG_FILE, s );

        } catch ( e ) {};

    }

    public function start( provision:Bool = false ) {

        this._busy.value = true;

        _forceVagrantProvisioning = provision;
        this.status.value = ServerStatus.Initializing;

        if ( console != null ) {

            console.clear();
            console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.start' ) );

        }

        _prepareFiles();

    }

    public function updateProvisioner( data:ProvisionerData ):Bool {

        if ( this._provisioner.version == data.version ) return false;

        var vcd = ProvisionerManager.getProvisionerDefinition( data.type, data.version );
        var newRoot:String = vcd.root;
        this._provisioner.reinitialize( newRoot );
        _propertyChanged( this._provisioner );

        return true;

    }

    function _prepareFiles() {

        _provisioner.copyFiles( _prepareFilesComplete );

    }

    function _prepareFilesComplete() {

        Logger.debug( '${this}: Configuration files copied to ${this._serverDir}' );
        Logger.debug( '${this}: Copying installer files to ${this._serverDir}/installers' );

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

        Logger.verbose( '${this}: Installer and Fixpack path pairs: ${paths}' );

        _provisioner.copyInstallers( paths, _batchCopyComplete );

    }

    function _batchCopyComplete() {

        Logger.debug( '${this}: Setting working directory to ${_serverDir}' );
        console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.setworkingdirectory', _serverDir ) );

        _saveSafeId();

        //if ( !_provisioner.hostFileExists ) _provisioner.saveContentToFileInTargetDirectory( DemoTasks.HOSTS_FILE, generateHostsFileContent() );
        if ( !_provisioner.hostFileExists ) _provisioner.saveHostsFile();

        if ( console != null ) {
            console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.hostsfilecontent', _provisioner.getFileContentFromTargetDirectory( DemoTasks.HOSTS_FILE ) ) );
            console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.virtualboxmachine', Std.string( _virtualBoxMachine ) ) );
        }

		_startVagrantUp();

    }

    function _saveSafeId() {

        var r = _provisioner.saveSafeId( _userSafeId.value );
        if ( !r ) this._busy.value = false;

    }

    public function saveHostsFile() {

        if ( isValid() ) this.provisioner.saveHostsFile();

    }

    function _actionChanged( prop:Property<ServerAction> ) { }

    function _propertyChanged<T>( property:T ) {

        if ( !_created ) return;

        _setServerStatus();

        for ( f in _onUpdate ) f( this, true );

    }

    public function safeIdCopied():Bool {

        return _provisioner.safeIdExists;

    }

    public function safeIdExists():Bool {

        if ( _userSafeId == null || _userSafeId.value == null || _userSafeId.value == "" ) return false;

        return FileSystem.exists( _userSafeId.value );

    }

    public function areRolesValid():Bool {

        var valid:Bool = true;

        for ( r in this._roles.value ) {

            if ( r.enabled ) {

                if ( r.files.installer == null || r.files.installer == "null" || !FileSystem.exists( r.files.installer ) ) valid = false;

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

            Logger.verbose( '${this}: The web address file has invalid content or non-existent' );
            if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.webaddressinvalid' ) );

        } else {

            Logger.verbose( '${this}: Web address file content: ${s}' );
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

        _provisioner.deleteWebAddressFile();

        if ( !Lambda.has( Vagrant.getInstance().onProvision, _onVagrantProvision ) )
            Vagrant.getInstance().onProvision.add( _onVagrantProvision );

        Vagrant.getInstance().getProvision( this._vagrantMachine )
            .onStdOut( _vagrantProvisionStandardOutputData )
            .onStdErr( _vagrantProvisionStandardErrorData )
            .execute( this._serverDir );

    }

    function _onVagrantProvision( machine:VagrantMachine ) {

        Vagrant.getInstance().onProvision.remove( _onVagrantProvision );

        Logger.verbose( '${this}: _onVagrantProvision ${machine}' );
        this._busy.value = false;
        this._status.value = ServerStatus.Running;

    }

    function _vagrantProvisionStandardOutputData( executor:AbstractExecutor, data:String ) {

        if ( console != null && !SuperHumanInstaller.getInstance().config.preferences.disablevagrantlogging ) console.appendText( data );
        Logger.debug( '${this}: Vagrant provision: ${data}' );

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

        Vagrant.getInstance().getRSync( this._vagrantMachine )
            .onStdOut( _vagrantRSyncStandardOutputData )
            .onStdErr( _vagrantRSyncStandardErrorData )
            .execute( this._serverDir );

    }

    function _onVagrantRSync( machine:VagrantMachine ) {

        Vagrant.getInstance().onRSync.remove( _onVagrantRSync );

        Logger.verbose( '${this}: _onVagrantRSync ${machine}' );
        this._busy.value = false;
        this._status.value = ServerStatus.Running;

    }

    function _vagrantRSyncStandardOutputData( executor:AbstractExecutor, data:String ) {

        if ( console != null && !SuperHumanInstaller.getInstance().config.preferences.disablevagrantlogging ) console.appendText( data );
        Logger.debug( '${this}: Vagrant rsync: ${data}' );

    }

    function _vagrantRSyncStandardErrorData( executor:AbstractExecutor, data:String ) {

        if ( console != null ) console.appendText( data, true );
        Logger.error( '${this}: Vagrant rsync error: ${data}' );
        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.rsyncerror' ), true );

    }

    //
    // Vagrant stop
    //

    public function stop() {

        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.stop' ) );

        this._busy.value = true;
        this.status.value = ServerStatus.Stopping;

        if ( !Lambda.has( Vagrant.getInstance().onHalt, _onVagrantHalt ) )
            Vagrant.getInstance().onHalt.add( _onVagrantHalt );

        Vagrant.getInstance().getHalt( this._vagrantMachine )
            .onStdOut( _vagrantHaltStandardOutputData )
            .onStdErr( _vagrantHaltStandardErrorData )
            .execute( this._serverDir );

    }

    function _onVagrantHalt( machine:VagrantMachine ) {

        Vagrant.getInstance().onHalt.remove( _onVagrantHalt );

        Logger.verbose( '${this}: _onVagrantHalt ${machine}' );
        this._busy.value = false;
        this._status.value = ServerStatus.Stopped;

    }

    function _vagrantHaltStandardOutputData( executor:AbstractExecutor, data:String ) {

        if ( console != null && !SuperHumanInstaller.getInstance().config.preferences.disablevagrantlogging ) console.appendText( data );
        Logger.debug( '${this}: Vagrant halt: ${data}' );

    }

    function _vagrantHaltStandardErrorData( executor:AbstractExecutor, data:String ) {

        if ( console != null ) console.appendText( data, true );
        Logger.error( '${this}: Vagrant halt error: ${data}' );
        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.stopfailed' ), true );

    }

    //
    // Vagrant destroy
    //

    public function destroy() {

        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.destroy' ) );

        this._busy.value = true;
        this._status.value = ServerStatus.Destroying;

        _provisioner.deleteWebAddressFile();

        if ( !Lambda.has( Vagrant.getInstance().onDestroy, _onVagrantDestroy ) )
            Vagrant.getInstance().onDestroy.add( _onVagrantDestroy );

        Vagrant.getInstance().getDestroy( true, this._vagrantMachine )
            .onStdOut( _vagrantDestroyStandardOutputData )
            .onStdErr( _vagrantDestroyStandardErrorData )
            .execute( this._serverDir );

    }

    function _vagrantDestroyStandardOutputData( executor:AbstractExecutor, data:String ) {

        if ( console != null && !SuperHumanInstaller.getInstance().config.preferences.disablevagrantlogging ) console.appendText( data );
        Logger.debug( '${this}: Vagrant destroy: ${data}' );

    }

    function _vagrantDestroyStandardErrorData( executor:AbstractExecutor, data:String ) {

        if ( console != null ) console.appendText( data, true );
        Logger.error( '${this}: Vagrant destroy error: ${data}' );
        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.destroyerror' ), true );

    }

    function _onVagrantDestroy( machine:VagrantMachine ) {

        Vagrant.getInstance().onDestroy.remove( _onVagrantDestroy );

        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.destroyed' ) );

        Logger.verbose( '${this}: _onVagrantDestroy ${machine}' );
        this._busy.value = false;
        this._status.value = ServerStatus.Ready;
        this._provisioner.deleteWebAddressFile();
        this._combinedVirtualMachine.value.vagrantId = null;
        this._combinedVirtualMachine.value.state = CombinedVirtualMachineState.NotCreated;

    }

    //
    // Vagrant up
    //

    function _startVagrantUp() {

        _provisioner.calculateTotalNumberOfTasks();
        _provisioner.startFileWatcher();

        this._busy.value = true;

        _provisionedBeforeStart = this._provisioner.provisioned;

        if ( this._provisioner.provisioned ) {

            this.status.value = ServerStatus.Start;

        } else {

            this.status.value = ServerStatus.FirstStart;

        }

        _provisioner.deleteWebAddressFile();
        _provisioner.onProvisioningFileChanged.add( _onDemoTasksProvisioningFileChanged );

        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.vagrantupstart', '(provision:${_forceVagrantProvisioning})' ) );

        _vagrantUpExecutor = Vagrant.getInstance().getUp( null, _forceVagrantProvisioning, [] )
            .onStart( _vagrantUpStarted )
            .onStop( _vagrantUpStopped )
            .onStdOut( _vagrantUpStandardOutputData )
            .onStdErr( _vagrantUpStandardErrorData );

        _vagrantUpExecutor.execute( _serverDir );
        _vagrantUpElapsedTime = 0;
        _startVagrantUpElapsedTimer();

    }

    function _vagrantUpStarted( executor:AbstractExecutor ) {

        Logger.debug( '${this}: Vagrant up started' );
        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.vagrantupstarted' ) );

    }

    function _vagrantUpStopped( executor:AbstractExecutor ) {

        Logger.debug( '${this}: Vagrant up stopped with exitcode: ${executor.exitCode}' );
        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.vagrantupstopped', Std.string( executor.exitCode ) ) );

        this._busy.value = false;

        if ( executor.exitCode == -1 ) {

            this.status.value = ServerStatus.Ready;
            this._combinedVirtualMachine.value.state = CombinedVirtualMachineState.PowerOff;

        } else if ( executor.exitCode == 0 ) {

            this.status.value = ServerStatus.Running;
            this._combinedVirtualMachine.value.state = CombinedVirtualMachineState.Running;

            if ( this._provisioner.provisioned && this._openBrowser.value ) this._provisioner.openWelcomePage();

        } else {

            this.status.value = ServerStatus.Error;

        }

        this._hostname.locked = this._organization.locked = ( this._provisioner.provisioned == true );

        executor.dispose();
        _vagrantUpExecutor = null;
        _provisioner.onProvisioningFileChanged.clear();
        _provisioner.stopFileWatcher();
        _stopVagrantUpElapsedTimer();

    }

    function _vagrantUpStandardOutputData( executor:AbstractExecutor, data:String ) {
     
        if ( console != null && !SuperHumanInstaller.getInstance().config.preferences.disablevagrantlogging ) console.appendText( new String( data ) );
        Logger.debug( '${this}: Vagrant up: ${data}' );
        _provisioner.updateTaskProgress( data );
        
    }

    function _vagrantUpStandardErrorData( executor:AbstractExecutor, data:String ) {
        
        if ( console != null ) console.appendText( data, true );
        Logger.error( '${this}: Vagrant up error: ${data}' );

    }

    //
    // VirtualBox
    //

    public function refreshVirtualBoxInfo() {

        if ( _refreshingVirtualBoxVMInfo ) return;
        if ( this._virtualBoxMachine == null || this._virtualBoxMachine.virtualBoxId == null ) return;

        VirtualBox.getInstance().onShowVMInfo.add( _onVirtualBoxShowVMInfo );
        VirtualBox.getInstance().getShowVMInfo( this._virtualBoxMachine.virtualBoxId ).execute();
        _refreshingVirtualBoxVMInfo = true;

    }

    function _onVirtualBoxShowVMInfo( id:String ) {

        if ( id == this.virtualBoxId || id == this._virtualBoxMachine.virtualBoxId || id == this._virtualBoxMachine.name ) {

            _refreshingVirtualBoxVMInfo = false;
            VirtualBox.getInstance().onShowVMInfo.remove( _onVirtualBoxShowVMInfo );
            Logger.verbose( '${this}: VirtualBox VM: ${this._virtualBoxMachine}' );
            // calculateDiskSpace();

        }

    }

    //
    // Combined Virtual Machine
    //

    function _getCombinedVirtualMachine():CombinedVirtualMachine {

        return _combinedVirtualMachine.value;

    }

    public function setVagrantMachine( machine:VagrantMachine ) {

        this._vagrantMachine = machine;
        this._vagrantMachine.serverId = this._id;

        var cvm:CombinedVirtualMachine = _combinedVirtualMachine.value;

        for( i in Reflect.fields( machine ) ) {

            Reflect.setField( cvm, i, Reflect.field( machine, i ) );

        }

        _combinedVirtualMachine.value = cvm;

    }

    public function setVirtualBoxMachine( machine:VirtualBoxMachine ) {

        this._virtualBoxMachine = machine;
        this._virtualBoxMachine.serverId = this._id;

        var cvm:CombinedVirtualMachine = _combinedVirtualMachine.value;

        for( i in Reflect.fields( machine ) ) {

            Reflect.setField( cvm, i, Reflect.field( machine, i ) );

        }

        _combinedVirtualMachine.value = cvm;

        _setServerStatus();

    }

    //
    // Server Status
    //

    function _setServerStatus( ignoreBusyState:Bool = false ) {

        // Do not change status if server is busy
        if ( !ignoreBusyState && this._busy.value ) return;

        this._status.value = ServerStatusManager.getRealStatus( this );

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
    // Provisioning status check
    //

    function _onDemoTasksProvisioningFileChanged() {

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

        return '[Server:${this._id}]';

    }

    //
    // Local filesystem functions
    //

    public function calculateDiskSpace() {

        #if mac
        var f = Shell.getInstance().du( this._serverDir );

        if ( this._combinedVirtualMachine.value != null && this._combinedVirtualMachine.value.root != null )
            f += Shell.getInstance().du( this._combinedVirtualMachine.value.root );

        _diskUsage.value = f;
        #end

    }

}