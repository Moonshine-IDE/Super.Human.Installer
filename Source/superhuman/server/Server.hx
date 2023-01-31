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
import haxe.Template;
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
import prominic.sys.applications.oracle.VirtualMachine;
import prominic.sys.io.AbstractExecutor;
import prominic.sys.io.FileTools;
import superhuman.interfaces.IConsole;
import superhuman.managers.ProvisionerManager;
import superhuman.server.data.ProvisionerData;
import superhuman.server.data.RoleData;
import superhuman.server.data.ServerData;
import superhuman.server.provisioners.DemoTasks;
import sys.FileSystem;

class Server {

    static final _SAFE_ID_FILENAME:String = "safe.ids";
    static final _VAGRANTFILE:String = "Vagrantfile";

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

            sc._provisioner = new DemoTasks( latestDemoTasks.root, sc._serverDir );

        } else {

            var provisioner = ProvisionerManager.getProvisionerDefinition( data.provisioner.type, data.provisioner.version );

            if ( provisioner != null ) {

                sc._provisioner = new DemoTasks( provisioner.root, sc._serverDir );

            } else {

                // The server already exists BUT the provisioner version is not supported
                // so we create the provisioner with target path only
                sc._provisioner = new DemoTasks( null, sc._serverDir );

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

        sc._vagrantMachine.value = { home: sc._serverDir, id: null, state: VagrantMachineState.Unknown, serverId: sc._id };

        sc._hostname.locked = sc._organization.locked = ( sc._provisioner.provisioned == true );
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
    var _console:IConsole;
    var _dhcp4:Property<Bool>;
    var _diskUsage:Property<Float>;
    var _hostname:ValidatingProperty;
    var _hostsTemplate:String;
    var _id:Int;
    var _memory:Property<Float>;
    var _nameServer1:ValidatingProperty;
    var _nameServer2:ValidatingProperty;
    var _networkAddress:ValidatingProperty;
    var _networkBridge:ValidatingProperty;
    var _networkGateway:ValidatingProperty;
    var _networkNetmask:ValidatingProperty;
    var _numCPUs:Property<Int>;
    var _onUpdate:List<( Server, Bool ) -> Void>;
    var _openBrowser:Property<Bool>;
    var _organization:ValidatingProperty;
    var _path:Property<String>;
    var _provision:Bool;
    var _provisioner:DemoTasks;
    var _refreshingVirtualBoxVMInfo:Bool = false;
    var _roles:Property<Array<RoleData>>;
    var _serverDir:String;
    var _setupWait:Property<Int>;
    var _status:Property<ServerStatus>;
    var _type:String;
    var _userEmail:ValidatingProperty;
    var _userSafeId:Property<String>;
    var _vagrantMachine:Property<VagrantMachine>;
    var _virtualMachine:Property<VirtualMachine>;
    
    public var busy( get, never ):Bool;
    function get_busy() return _busy.value;

    public var console( get, set ):IConsole;
    function get_console() return _console;
    function set_console( value:IConsole ):IConsole { _console = value; _provisioner.console = value; return _console; }

    public var dhcp4( get, never ):Property<Bool>;
    function get_dhcp4() return _dhcp4;

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

    public var onUpdate( get, never ):List<( Server, Bool ) -> Void>;
    function get_onUpdate() return _onUpdate;
    
    public var openBrowser( get, never ):Property<Bool>;
    function get_openBrowser() return _openBrowser;
    
    public var organization( get, never ):ValidatingProperty;
    function get_organization() return _organization;
    
    public var path( get, never ):Property<String>;
    function get_path() return _path;

    public var provisioned( get, never ):Bool;
    function get_provisioned() return _provisioner.provisioned;

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

    public var vagrantMachine( get, never ):Property<VagrantMachine>;
    function get_vagrantMachine() return _vagrantMachine;

    public var virtualBoxId( get, never ):String;
    function get_virtualBoxId() {
        return '${Std.string( this._id )}--${this.domainName}';
    }

    public var virtualMachine( get, never ):Property<VirtualMachine>;
    function get_virtualMachine() return _virtualMachine;

    public var webAddress( get, never ):String;
    function get_webAddress() return _getWebAddress();

    function new() {

        _id = Math.floor( Math.random() * 9000 ) + 1000;

        _action = new Property( null, true );
        _action.onChange.add( _actionChanged );

        _busy = new Property( false );
        _busy.onChange.add( _propertyChanged );

        _dhcp4 = new Property( true );
        _dhcp4.onChange.add( _propertyChanged );

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

        _onUpdate = new List();

        _openBrowser = new Property( false );
        _openBrowser.onChange.add( _propertyChanged );

        _organization = new ValidatingProperty( "", _VK_CERTIFIER, 1 );
        _organization.onChange.add( _propertyChanged );

        _path = new Property( "" );
        _path.onChange.add( _propertyChanged );

        _setupWait = new Property( 300 );
        _setupWait.onChange.add( _propertyChanged );

        _status = new Property( ServerStatus.Unconfigured );
        _status.onChange.add( _propertyChanged );

        _userEmail = new ValidatingProperty( "", _VK_EMAIL, true );
        _userEmail.onChange.add( _propertyChanged );

        _userSafeId = new Property();
        _userSafeId.onChange.add( _propertyChanged );

        _roles = new Property( [] );
        _roles.onChange.add( _propertyChanged );

        _type = ServerType.Domino;

        _vagrantMachine = new Property( { id:null, state:VagrantMachineState.Unknown } );
        _vagrantMachine.onChange.add( _propertyChanged );

        _virtualMachine = new Property( {} );
        _virtualMachine.onChange.add( _propertyChanged );

        Vagrant.getInstance().onDestroy.add( _onVagrantDestroy );
        Vagrant.getInstance().onHalt.add( _onVagrantHalt );
        Vagrant.getInstance().onProvision.add( _onVagrantProvision );
        Vagrant.getInstance().onRSync.add( _onVagrantRSync );
        Vagrant.getInstance().onStatus.add( _onVagrantStatus );

    }

    public function dispose() {

        if ( _onUpdate != null ) _onUpdate.clear();
        _onUpdate = null;

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

    public function provision() {

        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.provision' ) );

        this._busy.value = true;

        this._status.value = ServerStatus.Provisioning;

        Vagrant.getInstance().getProvision( this._vagrantMachine.value )
            .onStdOut( _vagrantProvisionStandardOutputData )
            .onStdErr( _vagrantProvisionStandardErrorData )
            .execute();

    }

    public function start( provision:Bool = false ) {

        this._busy.value = true;

        _provision = provision;
        this.status.value = ServerStatus.Initializing;

        if ( console != null ) {

            console.clear();
            console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.start' ) );

        }

        _provisioner.deleteWebAddressFile();

        _prepareFiles();

    }

    public function stop() {

        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.stop' ) );

        this.status.value = ServerStatus.Stopping;

        if ( _provisioner.provisioned == true ) {

            this._busy.value = true;

            Vagrant.getInstance().getHalt( this._vagrantMachine.value )
                .onStdOut( _vagrantHaltStandardOutputData )
                .onStdErr( _vagrantHaltStandardErrorData )
                .execute( this._serverDir );

        } else {

            this._busy.value = true;

            Vagrant.getInstance().getHalt( this._vagrantMachine.value )
                .onStdOut( _vagrantHaltStandardOutputData )
                .onStdErr( _vagrantHaltStandardErrorData )
                .execute( this._serverDir );

        }

    }

    public function refresh() {

        // TODO: Set provisioned to false if virtualmachine doesn't exist!
        //if ( this._vagrantMachine == null || this._vagrantMachine.value == null || this._vagrantMachine.value.id == null )
            _provisioner.deleteWebAddressFile();

        _propertyChanged( null );
        refreshVagrantStatus();

    }

    public function updateProvisioner( data:ProvisionerData ):Bool {

        if ( this._provisioner.version == data.version ) return false;

        var vcd = ProvisionerManager.getProvisionerDefinition( data.type, data.version );
        var newRoot:String = vcd.root;
        this._provisioner.reinitialize( newRoot );
        _propertyChanged( this._provisioner );

        return true;

    }

    function _checkStatus() {

        this._hostname.locked = this._organization.locked = this._userSafeId.locked = this._roles.locked = this._networkBridge.locked = 
        this._networkAddress.locked = this._networkGateway.locked = this._networkNetmask.locked = this._dhcp4.locked = this._userEmail.locked = 
            ( this._provisioner != null && this._provisioner.provisioned == true );

        if ( !isValid() ) {

            this._status.value = ServerStatus.Unconfigured;
            return;

        }

        if ( this._status.value == ServerStatus.Provisioning ) return;
        if ( this._status.value == ServerStatus.RSyncing ) return;
        if ( this._status.value == ServerStatus.GetStatus ) return;
        if ( this._status.value == ServerStatus.Stopping ) return;
        if ( this._status.value == ServerStatus.Stopped ) return;
        if ( this._status.value == ServerStatus.Start ) return;
        if ( this._status.value == ServerStatus.Running ) return;
        if ( this._status.value == ServerStatus.Destroying ) return;
        if ( this._status.value == ServerStatus.Ready ) return;

        if ( _provisioner.provisioned == true ) {

            if ( this._vagrantMachine.value != null ) {

                switch ( this._vagrantMachine.value.state ) {

                    case VagrantMachineState.Running:
                        this._status.value = ServerStatus.Running;

                    case VagrantMachineState.PowerOff:
                        this._status.value = ServerStatus.Stopped;

                    case VagrantMachineState.Aborted:
                        this._status.value = ServerStatus.Unconfigured;
                        _provisioner.deleteWebAddressFile();

                    default:

                }

            } else {

            }

        } else {

            if ( this._status.value == ServerStatus.Unconfigured ) this._status.value = ServerStatus.Ready;

        }

    }

    function _prepareFiles() {

        _provisioner.copyFiles( _prepareFilesComplete );

    }

    function _prepareFilesComplete() {

        Logger.debug( 'Configuration files copied to ${this._serverDir}' );
        Logger.debug( 'Copying installer files to ${this._serverDir}/installers' );

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

        Logger.verbose( 'Installer and Fixpack path pairs: ${paths}' );

        _provisioner.copyInstallers( paths, _batchCopyComplete );

    }

    function _batchCopyComplete() {

        Logger.debug( 'Setting working directory to ${_serverDir}' );
        console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.setworkingdirectory', _serverDir ) );
		Sys.setCwd( _serverDir );

        _saveSafeId();

        if ( !_provisioner.hostFileExists ) _provisioner.saveContentToFileInTargetDirectory( DemoTasks.HOSTS_FILE, generateHostsFileContent() );

        if ( console != null ) {
            console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.hostsfilecontent', _provisioner.getFileContentFromTargetDirectory( DemoTasks.HOSTS_FILE ) ) );
            console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.virtualboxmachine', Std.string( _virtualMachine.value ) ) );
        }

		_startVagrantUp();

    }

    function _saveSafeId() {

        var r = _provisioner.saveSafeId( _userSafeId.value );
        if ( !r ) this._busy.value = false;

    }

    public function saveHostsFile() {

        if ( isValid() ) this._saveHostsFile();

    }

    public function generateHostsFileContent():String {

        _hostsTemplate = _provisioner.getFileContentFromSourceTemplateDirectory( DemoTasks.HOSTS_TEMPLATE_FILE );

        var replace = {

            USER_EMAIL: _userEmail.value,
            USER_SAFE_ID: _SAFE_ID_FILENAME,

            SERVER_ID: _id,
            SERVER_HOSTNAME: url.hostname,
            SERVER_DOMAIN: url.domainName,
            SERVER_ORGANIZATION: _organization.value,

            NETWORK_BRIDGE: _networkBridge.value,

            // Always true, never false
            NETWORK_DHCP4: true,
            NETWORK_DNS_NAMESERVER_1: ( _dhcp4.value ) ? "1.1.1.1" : _nameServer1.value,
            NETWORK_DNS_NAMESERVER_2: ( _dhcp4.value ) ? "1.0.0.1" : _nameServer2.value,
            NETWORK_ADDRESS: ( _dhcp4.value ) ? "192.168.2.1" : _networkAddress.value,
            NETWORK_NETMASK: ( _dhcp4.value ) ? "255.255.255.0" : _networkNetmask.value,
            NETWORK_GATEWAY: ( _dhcp4.value ) ? "" : _networkGateway.value,

            ENV_OPEN_BROWSER: _openBrowser.value,
            ENV_SETUP_WAIT: _setupWait.value,

            RESOURCES_CPU: _numCPUs.value,
            RESOURCES_RAM: Std.string( _memory.value ) + "G",

            ROLE_LEAP: "",
            ROLE_NOMADWEB: "",
            ROLE_TRAVELER: "",
            ROLE_TRAVELER_HTMO: "",
            ROLE_VERSE: "",
            ROLE_APPDEVPACK: "",
            ROLE_STARTCLOUD_QUICK_START: "",
            ROLE_STARTCLOUD_HAPROXY: "",
            ROLE_STARTCLOUD_VAGRANT_README: "",
            ROLE_RESTAPI: "",

            CERT_SELFSIGNED: ( url.hostname + "." + url.domainName ).toLowerCase() != "demo.startcloud.com",

        };

        var travelerEnabled:Bool = false;
        var verseEnabled:Bool = false;

        for ( r in _roles.value ) {

            if ( r.value == "leap" )
                replace.ROLE_LEAP = ( r.enabled ) ? "- name: domino-leap" : "#- name: domino-leap";

            if ( r.value == "nomadweb" )
                replace.ROLE_NOMADWEB = ( r.enabled ) ? "- name: domino-nomadweb" : "#- name: domino-nomadweb";

            if ( r.value == "traveler" ) {
                travelerEnabled = r.enabled;
                replace.ROLE_TRAVELER = ( r.enabled ) ? "- name: domino-traveler" : "#- name: domino-traveler";
                replace.ROLE_TRAVELER_HTMO = ( r.enabled ) ? "- name: domino-traveler-htmo" : "# - name: domino-traveler-htmo";
            }

            if ( r.value == "verse" ) {
                verseEnabled = r.enabled;
                replace.ROLE_VERSE = ( r.enabled ) ? "- name: domino-verse" : "#- name: domino-verse";
            }

            if ( r.value == "appdevpack" )
                replace.ROLE_APPDEVPACK = ( r.enabled ) ? "- name: domino-appdevpack" : "#- name: domino-appdevpack";

            if ( r.value == "domino-rest-api" )
                replace.ROLE_RESTAPI = ( r.enabled ) ? "- name: domino-rest-api" : "#- name: domino-rest-api";

            replace.ROLE_STARTCLOUD_QUICK_START = "- name: startcloud-quick-start";
            replace.ROLE_STARTCLOUD_HAPROXY = "- name: startcloud-haproxy";
            replace.ROLE_STARTCLOUD_VAGRANT_README = "- name: startcloud-vagrant-readme";

        }

        var template = new Template( _hostsTemplate );
		var output = template.execute( replace );

        return output;

    }

    function _saveHostsFile() {

        Sys.setCwd( System.applicationDirectory );

		var output = generateHostsFileContent();

        _provisioner.saveContentToFileInTargetDirectory( DemoTasks.HOSTS_FILE, output );

    }

    function _actionChanged( prop:Property<ServerAction> ) {

        if ( _action.value == null ) return;

        this._status.value = ServerStatusManager.getStatus( _action.value, this._vagrantMachine.value, isValid(), this._provisioner.provisioned );

    }

    function _propertyChanged<T>( property:T ) {

        //TODO
        //var save:Bool = property == cast _vagrantUpSuccessful;

        //for ( f in _onUpdate ) f( this, save );
        for ( f in _onUpdate ) f( this, false );

        _checkStatus();

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

            Logger.verbose( 'detectedpublicaddress.txt has invalid content or non-existent' );
            if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.webaddressinvalid' ) );

        } else {

            Logger.verbose( 'detectedpublicaddress.txt content: ${s}' );
            if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.webaddressvalue', s ) );

        }

        return s;

    }

    public function rsync() {

        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.rsync' ) );

        this._busy.value = true;
        this._status.value = ServerStatus.RSyncing;

        Vagrant.getInstance().getRSync( this._vagrantMachine.value )
            .onStdOut( _vagrantRSyncStandardOutputData )
            .onStdErr( _vagrantRSyncStandardErrorData )
            .execute();

    }

    function _vagrantRSyncStandardOutputData( executor:AbstractExecutor, data:String ) {

        if ( console != null ) console.appendText( data );
        Logger.debug( 'Vagrant rsync: ${data}' );

    }

    function _vagrantRSyncStandardErrorData( executor:AbstractExecutor, data:String ) {

        if ( console != null ) console.appendText( data, true );
        Logger.error( 'Vagrant rsync error: ${data}' );
        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.rsyncerror' ), true );

    }

    function _onVagrantRSync( machine:VagrantMachine ) {

        if ( machine.serverId != this._id ) return;

        Logger.verbose( '_onVagrantRSync ${machine}' );
        this._busy.value = false;
        this._status.value = ServerStatus.Running;

    }

    function _onVagrantHalt( machine:VagrantMachine ) {

        if ( machine.serverId != this._id ) return;

        Logger.verbose( '_onVagrantHalt ${machine}' );
        this._busy.value = false;
        this._status.value = ServerStatus.Stopped;

    }

    function _onVagrantProvision( machine:VagrantMachine ) {

        if ( machine.serverId != this._id ) return;

        Logger.verbose( '_onVagrantProvision ${machine}' );
        this._busy.value = false;
        this._status.value = ServerStatus.Running;

    }

    function _vagrantHaltStandardOutputData( executor:AbstractExecutor, data:String ) {

        if ( console != null ) console.appendText( data );
        Logger.debug( 'Vagrant halt: ${data}' );

    }

    function _vagrantHaltStandardErrorData( executor:AbstractExecutor, data:String ) {

        if ( console != null ) console.appendText( data, true );
        Logger.error( 'Vagrant halt error: ${data}' );
        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.stopfailed' ), true );

    }

    function _vagrantProvisionStandardOutputData( executor:AbstractExecutor, data:String ) {

        if ( console != null ) console.appendText( data );
        Logger.debug( 'Vagrant provision: ${data}' );

    }

    function _vagrantProvisionStandardErrorData( executor:AbstractExecutor, data:String ) {

        if ( console != null ) console.appendText( data, true );
        Logger.error( 'Vagrant provision error: ${data}' );
        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.provisionerror' ), true );

    }

    public function destroy() {

        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.destroy' ) );

        this._busy.value = true;
        this._status.value = ServerStatus.Destroying;

        _provisioner.deleteWebAddressFile();

        Vagrant.getInstance().getDestroy( true, this._vagrantMachine.value )
            .onStdOut( _vagrantDestroyStandardOutputData )
            .onStdErr( _vagrantDestroyStandardErrorData )
            .execute();

    }

    function _vagrantDestroyStandardOutputData( executor:AbstractExecutor, data:String ) {

        if ( console != null ) console.appendText( data );
        Logger.debug( 'Vagrant destroy: ${data}' );

    }

    function _vagrantDestroyStandardErrorData( executor:AbstractExecutor, data:String ) {

        if ( console != null ) console.appendText( data, true );
        Logger.error( 'Vagrant destroy error: ${data}' );
        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.destroyerror' ), true );

    }

    function _onVagrantDestroy( machine:VagrantMachine ) {

        if ( machine.serverId != this._id ) return;

        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.destroyed' ) );

        Logger.verbose( '_onVagrantDestroy ${machine}' );
        this._busy.value = false;
        this._status.value = ServerStatus.Ready;
        this._provisioner.deleteWebAddressFile();
        this._vagrantMachine.value.id = null;
        this._vagrantMachine.value.state = VagrantMachineState.NotCreated;

    }

    /**
     * Local filesystem functions
     */

    public function calculateDiskSpace() {

        #if mac
        var f = Shell.getInstance().du( this._serverDir );

        if ( this._virtualMachine.value != null && this._virtualMachine.value.root != null )
            f += Shell.getInstance().du( this._virtualMachine.value.root );

        _diskUsage.value = f;
        #end

    }

    /**
     * Vagrant up
     */

    function _startVagrantUp() {

        this._busy.value = true;

        if ( this._provisioner.provisioned ) {

            this.status.value = ServerStatus.Start;

        } else {

            this.status.value = ServerStatus.FirstStart;

        }

        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.vagrantupstart', '(provision:${_provision})' ) );

        Vagrant.getInstance().getUp( this._vagrantMachine.value, _provision, [] )
            .onStart( _vagrantUpStarted )
            .onStop( _vagrantUpStopped )
            .onStdOut( _vagrantUpStandardOutputData )
            .onStdErr( _vagrantUpStandardErrorData )
            .execute( _serverDir );

    }

    function _vagrantUpStarted( executor:AbstractExecutor ) {

        Logger.debug( '${this._id}: Vagrant up started' );
        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.vagrantupstarted' ) );

    }

    function _vagrantUpStopped( executor:AbstractExecutor ) {

        Logger.debug( '${this._id}: Vagrant up stopped with exitcode: ${executor.exitCode}' );
        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.vagrantupstopped', Std.string( executor.exitCode ) ) );

        this._busy.value = false;

        if ( executor.exitCode == -1 ) {

            this.status.value = ServerStatus.Ready;
            this._vagrantMachine.value.state = VagrantMachineState.PowerOff;

        } else if ( executor.exitCode == 0 ) {

            this.status.value = ServerStatus.Running;
            this._vagrantMachine.value.state = VagrantMachineState.Running;

        } else {

            this.status.value = ServerStatus.Error;

        }

        this._hostname.locked = this._organization.locked = ( this._provisioner.provisioned == true );

        executor.dispose();

    }

    function _vagrantUpStandardOutputData( executor:AbstractExecutor, data:String ) {
     
        if ( console != null ) console.appendText( new String( data ) );
        Logger.debug( '${this._id}: Vagrant up: ${data}' );
        
    }

    function _vagrantUpStandardErrorData( executor:AbstractExecutor, data:String ) {
        
        if ( console != null ) console.appendText( data, true );
        Logger.error( '${this._id}: Vagrant up error: ${data}' );

    }

    /**
     * Vagrant status
     */

    public function refreshVagrantStatus() {

        if ( busy ) return;
        if ( this._status.value == ServerStatus.Error || this._status.value == ServerStatus.Unconfigured || this._status.value == ServerStatus.Ready ) return;

        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.refreshvagrantstatus' ) );

        this._busy.value = true;
        this._status.value = ServerStatus.GetStatus;

        Vagrant.getInstance().getStatus( this._vagrantMachine.value ).execute( this._serverDir );

    }

    function _onVagrantStatus( machine:VagrantMachine ) {

        if ( machine.serverId != this._id ) return;

        this._busy.value = false;

        Logger.verbose( '_onVagrantStatus ${machine}' );
        if( machine.id == this._vagrantMachine.value.id ) this._vagrantMachine.value = machine;
        Logger.verbose( '_onVagrantStatus ${this._vagrantMachine.value}' );

        switch ( machine.state ) {

            case VagrantMachineState.NotCreated | VagrantMachineState.Unknown | VagrantMachineState.Aborted:
                this._provisioner.deleteWebAddressFile();
                this._status.value = ServerStatus.Ready;

            case VagrantMachineState.Running:
                this._status.value = ServerStatus.Running;

            case VagrantMachineState.PowerOff:
                this._status.value = ServerStatus.Stopped;

            default:

        }

    }

    /**
     * VitualBox
     */

    public function refreshVirtualBoxInfo() {

        if ( _refreshingVirtualBoxVMInfo ) return;
        if ( this._virtualMachine.value == null || this._virtualMachine.value.id == null ) return;

        VirtualBox.getInstance().onShowVMInfo.add( _onVirtualBoxShowVMInfo );
        VirtualBox.getInstance().getShowVMInfo( this._virtualMachine.value.id ).execute();
        _refreshingVirtualBoxVMInfo = true;

    }

    function _onVirtualBoxShowVMInfo( id:String ) {

        if ( id == this.virtualBoxId || id == this._virtualMachine.value.id || id == this._virtualMachine.value.name ) {

            _refreshingVirtualBoxVMInfo = false;
            VirtualBox.getInstance().onShowVMInfo.remove( _onVirtualBoxShowVMInfo );
            Logger.verbose( 'VirtualBox VM: ${this._virtualMachine.value}' );
            // calculateDiskSpace();

        }

    }

}