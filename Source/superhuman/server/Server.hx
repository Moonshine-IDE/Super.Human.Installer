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

        // Log provisioner type without normalizing it
        if (data.provisioner != null) {
            // Log the incoming provisioner data for debugging
            Logger.info('Creating server with provisioner type: ${data.provisioner.type}, version: ${data.provisioner.version}');
            
            // We're no longer forcing normalization, as it breaks custom provisioners
            // Instead we'll use string comparison consistently throughout the codebase
        }
        
        // Get the effective provisioner type from data.provisioner
        // This is set by ServerManager before calling create()
        var effectiveProvisionerType = data.provisioner != null ? 
            data.provisioner.type : ProvisionerType.StandaloneProvisioner;
        Logger.info('Server.create: Using provisioner type for server creation: ${effectiveProvisionerType}');
        
        // Store server directory path but don't create it yet
        sc._serverDir = Path.normalize( rootDir + "/" + effectiveProvisionerType + "/" + sc._id );
        sc._path.value = sc._serverDir;
        
        // Set the provisional flag to indicate this server hasn't been confirmed yet
        sc.markAsProvisional();
        
        var latestStandaloneProvisioner = ProvisionerManager.getBundledProvisioners()[ 0 ];

        // Always force data.provisioner to match the type parameter for consistency
        if (data.provisioner != null) {
            // Override the provisioner type in the data object to match the type parameter
            if (Std.string(data.provisioner.type) != Std.string(effectiveProvisionerType)) {
                Logger.warning('Correcting provisioner type in data from ${data.provisioner.type} to ${effectiveProvisionerType}');
                data.provisioner.type = effectiveProvisionerType;
            }
        }

        if (data.provisioner == null) {
            // Default to StandaloneProvisioner for null provisioner
            sc._provisioner = new StandaloneProvisioner(ProvisionerType.StandaloneProvisioner, latestStandaloneProvisioner.root, sc._serverDir, sc);
        } else {
            // Look up the provisioner definition based on the effective type
            var provisioner = ProvisionerManager.getProvisionerDefinition(effectiveProvisionerType, data.provisioner.version);

            if (provisioner != null) {
                // Create the appropriate provisioner based on the effective type
                if (Std.string(effectiveProvisionerType) == Std.string(ProvisionerType.StandaloneProvisioner)) {
                    // Standalone provisioner
                    sc._provisioner = new StandaloneProvisioner(ProvisionerType.StandaloneProvisioner, provisioner.root, sc._serverDir, sc);
                } else if (Std.string(effectiveProvisionerType) == Std.string(ProvisionerType.AdditionalProvisioner)) {
                    // Additional provisioner - create the proper AdditionalProvisioner instance, not StandaloneProvisioner
                    sc._provisioner = new superhuman.server.provisioners.AdditionalProvisioner(ProvisionerType.AdditionalProvisioner, provisioner.root, sc._serverDir, sc);
                } else {
                    // Custom provisioner
                    sc._provisioner = new CustomProvisioner(effectiveProvisionerType, provisioner.root, sc._serverDir, sc);
                }
            } else {
                // Fallback - the server already exists BUT the provisioner version is not supported
                // so we create the provisioner with target path only
                if (Std.string(effectiveProvisionerType) == Std.string(ProvisionerType.StandaloneProvisioner)) {
                    // Standalone provisioner fallback
                    sc._provisioner = new StandaloneProvisioner(ProvisionerType.StandaloneProvisioner, null, sc._serverDir, sc);
                    Logger.error('${sc}: Created StandaloneProvisioner with null root (fallback)');
                } else if (Std.string(effectiveProvisionerType) == Std.string(ProvisionerType.AdditionalProvisioner)) {
                    // Additional provisioner fallback - create the proper AdditionalProvisioner instance, not StandaloneProvisioner
                    sc._provisioner = new superhuman.server.provisioners.AdditionalProvisioner(ProvisionerType.AdditionalProvisioner, null, sc._serverDir, sc);
                    Logger.error('${sc}: Created AdditionalProvisioner with null root (fallback)');
                } else {
                    // Custom provisioner fallback
                    sc._provisioner = new CustomProvisioner(effectiveProvisionerType, null, sc._serverDir, sc);
                    Logger.error('${sc}: Created CustomProvisioner of type ${effectiveProvisionerType} with null root (fallback)');
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

    static public function getComputedName( hostname:String, organization:String, ?customProperties:Dynamic = null, ?provisioner:AbstractProvisioner = null ):ServerURL {

        var result:ServerURL = { domainName: "", hostname: "", path: "" };
        
        // Check if this is a custom provisioner (not one of the standard types)
        var isCustomProvisioner = false;
        if (provisioner != null) {
            isCustomProvisioner = (
                Std.string(provisioner.type) != Std.string(ProvisionerType.StandaloneProvisioner) && 
                Std.string(provisioner.type) != Std.string(ProvisionerType.AdditionalProvisioner) &&
                Std.string(provisioner.type) != Std.string(ProvisionerType.Default)
            );
        }
        
        // Special handling for custom provisioners
        if (isCustomProvisioner && customProperties != null) {
            // For custom provisioners, ONLY look for DOMAIN field in dynamicCustomProperties
            var domain = null;
            
            // Check in dynamicCustomProperties - this is the ONLY place for custom provisioners
            if (Reflect.hasField(customProperties, "dynamicCustomProperties")) {
                var dynamicProps = Reflect.field(customProperties, "dynamicCustomProperties");
                if (dynamicProps != null && Reflect.hasField(dynamicProps, "DOMAIN")) {
                    domain = Reflect.field(dynamicProps, "DOMAIN");
                }
            }
            
            // Use the domain if found, otherwise set a default domain
            if (domain != null && domain != "") {
                // For custom provisioners, hostname is just the subdomain
                // and domain is directly from the DOMAIN field
                result.hostname = hostname;
                result.domainName = domain;
                result.path = ""; // No path for custom provisioners
                
                return result;
            }
        }
        
        // Original behavior for standard provisioners or if no domain was found for custom provisioner
        var a = hostname.split( "." );

        if ( a.length == 1 && a[0].length > 0 ) {
            result.hostname = a[0];
            
            // Even for custom provisioners, if we didn't find a DOMAIN field,
            // fall back to using organization + ".com" if organization is not empty
            if (organization != null && organization != "") {
                result.domainName = organization + ".com";
            } else {
                // For custom provisioners without a DOMAIN field or organization,
                // use a default domain to prevent the ".." issue
                result.domainName = "example.com";
            }
        } else if ( a.length == 3 ) {
            result.hostname = a[0];
            result.domainName = a[1] + "." + a[2];
        } else {
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
    var _provisional:Bool = false;
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
    var _fd:FileDialog;

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
    
    /**
     * Gets the effective network interface to use, checking for default value
     * If the server's network interface is empty/"" (default), this returns the global default
     * Otherwise returns the server's configured value
     * @return The effective network interface name to use
     */
    public function getEffectiveNetworkInterface():String {
        // If the server's network interface is empty (default), use the global preference
        if (_networkBridge != null && (_networkBridge.value == null || _networkBridge.value == "")) {
            // Get the global default from preferences
            var defaultInterface = SuperHumanInstaller.getInstance().config.preferences.defaultNetworkInterface;
            
            // Return the global default if it exists, otherwise empty string
            return (defaultInterface != null) ? defaultInterface : "";
        }
        
        // Otherwise return the server's configured network interface
        return _networkBridge.value;
    }
    
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
    function get_provisioned() {
        try {
            // Check if provisioning was explicitly canceled
            if (_provisioningCanceled) {
                return false;
            }
            
            // For a server to be considered properly provisioned, BOTH conditions must be true:
            // 1. The provisioner must report it as provisioned (provisioning.proof file exists)
            // 2. The VM must exist in VirtualBox
            //
            // This ensures servers stopped during provisioning are not reported as provisioned
            return _provisioner != null && _provisioner.provisioned && vmExistsInVirtualBox();
        } catch (e) {
            Logger.error('${this}: Error in provisioned getter: ${e}');
            return false; // Safer default is false
        }
    }
    
    /**
     * Checks if this server's VM exists in VirtualBox
     * @return True if the VM exists, false otherwise
     */
    public function vmExistsInVirtualBox():Bool {
        if (this.virtualBoxId == null) return false;
        
        for (vm in VirtualBox.getInstance().virtualBoxMachines) {
            if (vm.name == this.virtualBoxId) {
                return true;
            }
        }
        return false;
    }

    public var provisionedBeforeStart( get, never ):Bool;
    function get_provisionedBeforeStart() return _provisionedBeforeStart;

    public var provisioner( get, never ):AbstractProvisioner;
    function get_provisioner() return _provisioner;

    public var provisional( get, never ):Bool;
    function get_provisional() return _provisional;

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
        return getComputedName( _hostname.value, _organization.value, _customProperties, _provisioner );
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

        // Process the customProperties to minimize serviceTypeData before serialization
        var processedCustomProperties = this._customProperties;
        if (processedCustomProperties != null && Reflect.hasField(processedCustomProperties, "serviceTypeData")) {
            // Create a copy to avoid modifying the original
            processedCustomProperties = Reflect.copy(this._customProperties);
            
            // Get the original serviceTypeData
            var originalServiceTypeData = Reflect.field(processedCustomProperties, "serviceTypeData");
            
            // Minimize it to just the essential fields
            if (originalServiceTypeData != null) {
                var minimalServiceTypeData = {
                    isEnabled: Reflect.hasField(originalServiceTypeData, "isEnabled") ? 
                        Reflect.field(originalServiceTypeData, "isEnabled") : true,
                    provisionerType: Reflect.hasField(originalServiceTypeData, "provisionerType") ? 
                        Reflect.field(originalServiceTypeData, "provisionerType") : this._provisioner.type,
                    value: Reflect.hasField(originalServiceTypeData, "value") ? 
                        Reflect.field(originalServiceTypeData, "value") : "",
                    description: Reflect.hasField(originalServiceTypeData, "description") ? 
                        Reflect.field(originalServiceTypeData, "description") : "",
                    serverType: Reflect.hasField(originalServiceTypeData, "serverType") ? 
                        Reflect.field(originalServiceTypeData, "serverType") : ""
                };
                
                // Replace with the minimal version for serialization
                Reflect.setField(processedCustomProperties, "serviceTypeData", minimalServiceTypeData);
            }
        }

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
            customProperties: processedCustomProperties
        };

        return data;

    }

    public function initDirectory() {

        _provisioner.copyFiles();

    }
    
    /**
     * Initialize server files - creates directory and initial configuration files
     * This should be called when a user confirms server configuration
     */
    public function initializeServerFiles():Void {
        
        // Create the server directory if it doesn't exist
        if (!FileSystem.exists(_serverDir)) {
            try {
                FileSystem.createDirectory(_serverDir);
            } catch (e) {
                return;
            }
        }
        
        // Copy provisioner files to the server directory
        initDirectory();
        
        // Save the hosts file
        saveHostsFile();
        
        // Save the server data
        saveData();
        
        // Mark the server as no longer provisional
        _provisional = false;
    }

    public function isValid():Bool {
        // Check if this is a custom provisioner
        var isCustomProvisioner = (this.provisioner.type != ProvisionerType.StandaloneProvisioner && 
                                   this.provisioner.type != ProvisionerType.AdditionalProvisioner &&
                                   this.provisioner.type != ProvisionerType.Default);
        
        // Always required checks for any provisioner type
        var hasVagrant:Bool = Vagrant.getInstance().exists;
        var hasVirtualBox:Bool = VirtualBox.getInstance().exists;
        var isHostnameValid:Bool = _hostname.isValid();
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
        
        // Conditionally required checks based on provisioner type
        var isOrganizationValid:Bool = isCustomProvisioner ? true : _organization.isValid();
        var hasSafeId:Bool = isCustomProvisioner ? true : safeIdExists();
        
        // Roles are validated differently based on provisioner type, but always checked
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
        if ( _fd != null ) return;

        var dir = ( SuperHumanInstaller.getInstance().config.user.lastuseddirectory != null ) ? SuperHumanInstaller.getInstance().config.user.lastuseddirectory : System.userDirectory;
        _fd = new FileDialog();

        var currentDir:String;

        _fd.onSelect.add( (path) -> {

            currentDir = Path.directory( path );
            _userSafeId.value = path;

            if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.safeidselected', path ) );

            if ( currentDir != null ) SuperHumanInstaller.getInstance().config.user.lastuseddirectory = currentDir;
            if ( callback != null ) callback();
            
            _fd.onSelect.removeAll();
            _fd.onCancel.removeAll();
            _fd = null;            
        } );
        
        _fd.onCancel.add( () -> {
            _fd.onCancel.removeAll();
            _fd.onSelect.removeAll();
            _fd = null;
        } );
        
        _fd.browse( FileDialogType.OPEN, null, dir + "/", "Locate your Notes Safe Id file with .ids extension" );
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
			}
			else
			{
				console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.openftpFailed', appData.appId ) );
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
    		#else
			var ftpExecutor = new Executor(clientCommand, [ftpAppCommand]);
    			ftpExecutor.execute();
		#end
    }
    
    public function saveData() {
        try {
            // Check if this is a custom provisioner
            var isCustomProvisioner = (this.provisioner.type != ProvisionerType.StandaloneProvisioner && 
                                      this.provisioner.type != ProvisionerType.AdditionalProvisioner &&
                                      this.provisioner.type != ProvisionerType.Default);
            
            // For custom provisioners, we need to ensure there's no duplication of values
            if (isCustomProvisioner && this._customProperties != null) {
                
                // If dynamicCustomProperties exists, remove any duplicate properties at root level
                if (Reflect.hasField(this._customProperties, "dynamicCustomProperties")) {
                    var dynamicProps = Reflect.field(this._customProperties, "dynamicCustomProperties");
                    if (dynamicProps != null) {
                        // Get all fields in dynamicCustomProperties
                        var fieldNames = Reflect.fields(dynamicProps);
                        
                        // Check for each field if it also exists at the root level
                        for (fieldName in fieldNames) {
                            if (Reflect.hasField(this._customProperties, fieldName)) {
                                // Remove the duplicate field from root level
                                Reflect.deleteField(this._customProperties, fieldName);
                            }
                        }
                    }
                }
            }
            
            // Get the server data with customProperties included
            var data = getData();
            
            // Ensure type consistency between customProperties and provisioner type
            if (data.customProperties != null && 
                Reflect.hasField(data.customProperties, "provisionerDefinition") &&
                Reflect.hasField(Reflect.field(data.customProperties, "provisionerDefinition"), "data")) {
                
                var provDef = Reflect.field(data.customProperties, "provisionerDefinition");
                var provData = Reflect.field(provDef, "data");
                
                // Ensure the provisionerDefinition.data.type matches the top-level provisioner.type
                if (data.provisioner != null && provData != null) {
                    if (Std.string(Reflect.field(provData, "type")) != Std.string(data.provisioner.type)) {
                        Reflect.setField(provData, "type", data.provisioner.type);
                    }
                }
            }
            
            // Check if customProperties exists and has dynamic custom properties
            if (this._customProperties != null) {
                var hasCustomProps = Reflect.hasField(this._customProperties, "dynamicCustomProperties");
                var hasAdvancedProps = Reflect.hasField(this._customProperties, "dynamicAdvancedCustomProperties");
            }
            
            var s = Json.stringify(data);
            File.saveContent(Path.addTrailingSlash(this._serverDir) + _CONFIG_FILE, s);

        } catch (e) {
            Logger.error('${this}: Error saving server data: ${e}');
        };
    }

    public function start( provision:Bool = false ) {

        this._currentAction = ServerAction.Start( false );
        this._busy.value = true;

        // Clean up Vagrant's cache before starting to handle cases where the VM was deleted outside the application
        Vagrant.getInstance().pruneGlobalStatus();

        // This ensures we don't try to recreate the VM with an old/invalid ID
        this.combinedVirtualMachine.value.vagrantMachine.vagrantId = null;

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
        } else {
            Logger.warning('${this}: Updating provisioner with null or invalid version');
            return false;
        }

        // Force provisioner update even if the version appears the same
        var vcd = ProvisionerManager.getProvisionerDefinition(data.type, data.version);
        
        if (vcd != null) {
            var newRoot:String = vcd.root;
            this._provisioner.reinitialize(newRoot);
            
            // STEP 1: Update serverProvisionerId - this is the single source of truth for version
            if (this._serverProvisionerId != null) {
                this._serverProvisionerId.value = versionStr;
            }
            
            // STEP 2: Update the internal _version field which is used by the data getter
            if (Reflect.hasField(this._provisioner, "_version")) {
                try {
                    Reflect.setField(this._provisioner, "_version", data.version);
                } catch (e) {
                    Logger.warning('${this}: Could not update provisioner._version directly: ${e}');
                }
            }
            
            // STEP 3: Initialize custom properties if needed
            if (this._customProperties == null) {
                this._customProperties = {};
            }
            
            // STEP 4: Store the provisioner definition in customProperties
            Reflect.setField(this._customProperties, "provisionerDefinition", vcd);
            
            // STEP 5: For custom provisioners, ensure we update any related custom properties
            var isCustomProvisioner = (data.type != ProvisionerType.StandaloneProvisioner && 
                                      data.type != ProvisionerType.AdditionalProvisioner);
            
            if (isCustomProvisioner) {
                // Initialize dynamicCustomProperties if it doesn't exist
                if (!Reflect.hasField(this._customProperties, "dynamicCustomProperties")) {
                    Reflect.setField(this._customProperties, "dynamicCustomProperties", {});
                }
                
                // Store version information in dynamicCustomProperties for UI components to access
                var dynamicProps = Reflect.field(this._customProperties, "dynamicCustomProperties");
                Reflect.setField(dynamicProps, "provisionerVersion", versionStr);
            }
            
            // Trigger update notification
            _propertyChanged(this._provisioner);
            
            // Save the updated data immediately
            this.saveData();
            
            return true;
        } else {
            Logger.warning('${this}: Could not find provisioner definition for type ${data.type}, version ${versionStr}');
            return false;
        }
    }

    function _prepareFiles() {
        // The provisioner files were already copied during server initialization when Save was clicked
        // Skip directly to installer files preparation and continue the startup process
        
        // Just verify essential files exist and regenerate if missing
        if (!_provisioner.hostFileExists) {
            _provisioner.saveHostsFile();
        }
        
        // Proceed directly to the installer file preparation
        _prepareFilesComplete();
    }

    function _prepareFilesComplete() {

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

        _provisioner.copyInstallers( paths, _batchCopyComplete );

    }

    function _batchCopyComplete() {

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

    /**
     * Marks this server as provisional, meaning it's newly created and not yet saved/configured.
     * Provisional servers are removed from the system if the user cancels configuration.
     */
    public function markAsProvisional() {
        this._provisional = true;
    }
    
    public function saveHostsFile() {
        // Check if this is a custom provisioner
        var isCustomProvisioner = (this.provisioner.data.type != ProvisionerType.StandaloneProvisioner && 
                                  this.provisioner.data.type != ProvisionerType.AdditionalProvisioner);
                                  
        // Perform validation
        var isValid = this.isValid();
        if (!isValid) {
            Logger.warning('${this}: Server validation failed, cannot save Hosts.yml file');
            
            if (console != null) {
                console.appendText("Server validation failed. Please check the following:", true);
                
                // Log specific validation issues
                if (!Vagrant.getInstance().exists)
                    console.appendText("- Vagrant is not installed", true);
                    
                if (!VirtualBox.getInstance().exists)
                    console.appendText("- VirtualBox is not installed", true);
                    
                if (!this.hostname.isValid())
                    console.appendText("- Invalid hostname", true);
                    
                // Only show organization validation for standard provisioners
                if (!isCustomProvisioner && !this.organization.isValid())
                    console.appendText("- Invalid organization", true);
                    
                if (this.memory.value < 4)
                    console.appendText("- Memory allocation less than 4GB", true);
                    
                if (this.numCPUs.value < 1)
                    console.appendText("- CPU count insufficient", true);
                    
                var isNetworkValid = this.dhcp4.value || (
                    this.networkBridge.isValid() &&
                    this.networkAddress.isValid() &&
                    this.networkGateway.isValid() &&
                    this.networkNetmask.isValid() &&
                    this.nameServer1.isValid() &&
                    this.nameServer2.isValid()
                );
                
                if (!isNetworkValid)
                    console.appendText("- Network configuration invalid", true);
                    
                // Only show SafeID validation for standard provisioners
                if (!isCustomProvisioner && !this.safeIdExists())
                    console.appendText("- SafeID file not found", true);
                    
                if (!this.areRolesValid())
                    console.appendText("- Role configuration invalid", true);
            }
            
            return;
        }
        
        // If valid, save the hosts file
        if (isCustomProvisioner) {
            cast(this.provisioner, CustomProvisioner).saveHostsFile();
        } else {
            cast(this.provisioner, StandaloneProvisioner).saveHostsFile();
        }
    }

    function _actionChanged( prop:Property<ServerAction> ) { }

    function _propertyChanged<T>( property:T ) {
        try {
            // Early exit if server isn't created yet
            if (!_created) return;
            
            // Always handle status update safely
            try {
                _setServerStatus();
            } catch (e) {
                Logger.error('${this}: Error updating server status in property change: ${e}');
            }
            
            // Handle update callbacks safely
            if (_onUpdate != null) {
                for (f in _onUpdate) {
                    try {
                        f(this, true);
                    } catch (e) {
                        Logger.error('${this}: Error in update callback: ${e}');
                        // Continue with other callbacks despite errors
                    }
                }
            } else {
                Logger.warning('${this}: Cannot notify updates - _onUpdate is null');
            }
        } catch (e) {
            // Global error handler
            Logger.error('${this}: Unhandled exception in _propertyChanged: ${e}');
        }
    }

    public function safeIdExists():Bool {

        if ( _userSafeId == null || _userSafeId.value == null || _userSafeId.value == "" ) return false;

        return FileSystem.exists( _userSafeId.value );

    }

    public function areRolesValid():Bool {
        // Check if this is a custom provisioner by looking specifically at the provisioner type
        // This is the critical check to ensure we don't mix behavior between provisioner types
        var provisionerType = _provisioner != null && _provisioner.data != null ? _provisioner.data.type : null;
        var isCustomProvisioner = (provisionerType != null && 
                                  provisionerType != ProvisionerType.StandaloneProvisioner && 
                                  provisionerType != ProvisionerType.AdditionalProvisioner &&
                                  provisionerType != ProvisionerType.Default);
        
        Logger.verbose('${this}: Validating roles for server. Provisioner type: ${provisionerType}, Custom provisioner: ${isCustomProvisioner}');
        
        // For custom provisioners only, check if the roles have been processed
        if (isCustomProvisioner) {
            // Check for the flag set by RolePage.buttonCloseTriggered
            var rolesProcessed = false;
            
            if (_customProperties != null) {
                // Check for the rolesProcessed flag that's set when the user visits and closes the roles page
                if (Reflect.hasField(_customProperties, "rolesProcessed")) {
                    rolesProcessed = Reflect.field(_customProperties, "rolesProcessed") == true;
                }
            }
            
            // If the user hasn't visited and closed the roles page, return false to force them to visit
            if (!rolesProcessed) {
                return false;
            }
            
            // Even if the roles page was visited, we still need to validate that at least one role is enabled
            // This ensures users don't just visit the page without making necessary changes
            
            var hasEnabledRole = false;
            var validationMessages = new Array<String>();
            
            // Get custom role definitions from provisioner metadata if available
            var customRoleMap = new Map<String, Bool>();
            var hasMetadata = false;
            
            // Look for metadata in customProperties
            if (_customProperties != null && Reflect.hasField(_customProperties, "provisionerDefinition")) {
                var provDef = Reflect.field(_customProperties, "provisionerDefinition");
                if (provDef != null && Reflect.hasField(provDef, "metadata")) {
                    var metadata = Reflect.field(provDef, "metadata");
                    if (metadata != null && Reflect.hasField(metadata, "roles")) {
                        var roles = Reflect.field(metadata, "roles");
                        if (roles != null) {
                            hasMetadata = true;
                            // Cast roles to Array<Dynamic> to avoid "can't iterate on Dynamic" error
                            var rolesArray:Array<Dynamic> = cast roles;
                            
                            // Build a map of role names to installer requirements
                            for (role in rolesArray) {
                                if (role != null && Reflect.hasField(role, "name")) {
                                    var requiresInstaller = false;
                                    
                                    // Check if role requires installer
                                    if (Reflect.hasField(role, "installers")) {
                                        var installers = Reflect.field(role, "installers");
                                        if (installers != null && Reflect.hasField(installers, "installer")) {
                                            requiresInstaller = Reflect.field(installers, "installer");
                                        }
                                    }
                                    
                                    customRoleMap.set(Reflect.field(role, "name"), requiresInstaller);
                                }
                            }
                        }
                    }
                }
            }
            
            // If we have no metadata roles but this is a custom provisioner, 
            // assume all roles are valid with no installer requirements
            var noValidMetadataRoles = (customRoleMap.keys().hasNext() == false);

            // Now validate each role
            for (r in this._roles.value) {
                if (r.enabled) {
                    hasEnabledRole = true;
                    
                    // If we have no metadata or the role is in the metadata, it's valid
                    var isValidRole = noValidMetadataRoles || customRoleMap.exists(r.value);
                    
                    if (!isValidRole) {
                        Logger.warning('${this}: Role ${r.value} is not defined in provisioner metadata, skipping installer check');
                        continue;
                    }
                    
                    // Check if this is a custom role from the metadata that requires an installer
                    var requiresInstaller = !noValidMetadataRoles && customRoleMap.exists(r.value) ? 
                                           customRoleMap.get(r.value) : false;
                    
                    // If this role has showInstaller=false explicitly set, don't check installer regardless
                    if (Reflect.hasField(r, "showInstaller") && Reflect.field(r, "showInstaller") == false) {
                        requiresInstaller = false;
                    }
                    
                    // Only check installer file if it's required for this role
                    if (requiresInstaller) {
                        if (r.files == null || r.files.installer == null || r.files.installer == "null" || 
                            !FileSystem.exists(r.files.installer)) {
                            
                            var errorMsg = 'Role ${r.value} is missing required installer file';
                            Logger.warning('${this}: ${errorMsg}');
                            validationMessages.push(errorMsg);
                            
                            if (console != null && validationMessages.length > 0) {
                                console.appendText("Role validation failed:", true);
                                for (msg in validationMessages) {
                                    console.appendText("- " + msg, true);
                                }
                            }
                            
                            return false;
                        }
                    }
                }
            }
            
            // Ensure at least one role is enabled
            if (!hasEnabledRole) {
                var errorMsg = 'Custom provisioner requires at least one enabled role';
                Logger.warning('${this}: ${errorMsg}');
                validationMessages.push(errorMsg);
                
                if (console != null && validationMessages.length > 0) {
                    console.appendText("Role validation failed:", true);
                    for (msg in validationMessages) {
                        console.appendText("- " + msg, true);
                    }
                }
                
                return false;
            }
            
            // If we get here, validation passed
            return true;
            
            // Now proceed with standard custom provisioner role validation
            var hasEnabledRole = false;
            var validationMessages = new Array<String>();
            
            // Get custom role definitions from provisioner metadata if available
            var customRoleMap = new Map<String, Bool>();
            var hasMetadata = false;
            
            // Only check for metadata for custom provisioner types
            if (provisionerType != ProvisionerType.StandaloneProvisioner && 
                provisionerType != ProvisionerType.AdditionalProvisioner &&
                _customProperties != null && 
                Reflect.hasField(_customProperties, "provisionerDefinition")) {
                
                var provDef = Reflect.field(_customProperties, "provisionerDefinition");
                if (provDef != null && Reflect.hasField(provDef, "metadata")) {
                    var metadata = Reflect.field(provDef, "metadata");
                    if (metadata != null && Reflect.hasField(metadata, "roles")) {
                        var roles = Reflect.field(metadata, "roles");
                        if (roles != null) {
                            hasMetadata = true;
                            // Cast roles to Array<Dynamic> to avoid "can't iterate on Dynamic" error
                            var rolesArray:Array<Dynamic> = cast roles;
                            
                            // Build a map of role names to installer requirements
                            for (role in rolesArray) {
                                if (role != null && Reflect.hasField(role, "name")) {
                                    var requiresInstaller = false;
                                    
                                    // Check if role requires installer
                                    if (Reflect.hasField(role, "installers")) {
                                        var installers = Reflect.field(role, "installers");
                                        if (installers != null && Reflect.hasField(installers, "installer")) {
                                            requiresInstaller = Reflect.field(installers, "installer");
                                        }
                                    }
                                    
                                    customRoleMap.set(Reflect.field(role, "name"), requiresInstaller);
                                }
                            }
                        }
                    }
                }
            }
            
            // If we have no metadata roles but this is a custom provisioner, 
            // assume all roles are valid with no installer requirements
            var noValidMetadataRoles = (customRoleMap.keys().hasNext() == false);
            if (noValidMetadataRoles) {
                if (!hasMetadata) {
                    Logger.warning('${this}: Warning: No metadata found for custom provisioner');
                    if (console != null) {
                        console.appendText("Warning: No metadata found for custom provisioner. This may affect role validation.", true);
                    }
                }
            }
            
            // For custom provisioners with no enabled roles, we need at least one
            for (r in this._roles.value) {
                if (r.enabled) {
                    hasEnabledRole = true;
                    
                    // If we have no metadata or the role is in the metadata, it's valid
                    var isValidRole = noValidMetadataRoles || customRoleMap.exists(r.value);
                    
                    if (!isValidRole) {
                        Logger.warning('${this}: Role ${r.value} is not defined in provisioner metadata, skipping installer check');
                        validationMessages.push('Role ${r.value} is not defined in provisioner metadata');
                        continue;
                    }
                    
                    // Check if this is a custom role from the metadata that requires an installer
                    var requiresInstaller = !noValidMetadataRoles && customRoleMap.exists(r.value) ? 
                                           customRoleMap.get(r.value) : false;
                    
                    // If this role has showInstaller=false, don't check installer regardless
                    if (Reflect.hasField(r, "showInstaller") && Reflect.field(r, "showInstaller") == false) {
                        requiresInstaller = false;
                    }
                    
                    // Only check installer file if it's required for this role
                    if (requiresInstaller) {
                        if (r.files == null || r.files.installer == null || r.files.installer == "null" || 
                            !FileSystem.exists(r.files.installer)) {
                            
                            var errorMsg = 'Role ${r.value} is missing required installer file';
                            Logger.warning('${this}: ${errorMsg}');
                            validationMessages.push(errorMsg);
                            
                            if (console != null && validationMessages.length > 0) {
                                console.appendText("Role validation failed:", true);
                                for (msg in validationMessages) {
                                    console.appendText("- " + msg, true);
                                }
                            }
                            
                            return false;
                        }
                    }
                }
            }
            
            if (!hasEnabledRole) {
                var errorMsg = 'Custom provisioner requires at least one enabled role';
                Logger.warning('${this}: ${errorMsg}');
                validationMessages.push(errorMsg);
                
                if (console != null && validationMessages.length > 0) {
                    console.appendText("Role validation failed:", true);
                    for (msg in validationMessages) {
                        console.appendText("- " + msg, true);
                    }
                }
                
                return false;
            }
            
            return hasEnabledRole;
        }
        
        // Original logic for built-in provisioners
        var valid:Bool = false;
        var validationMessages = new Array<String>();
        
        for (r in this._roles.value) {
            if (r.enabled) {
                valid = true;
                if (r.files.installer == null || r.files.installer == "null" || !FileSystem.exists(r.files.installer)) {
                    var errorMsg = 'Standard role ${r.value} is missing required installer file';
                    Logger.warning('${this}: ${errorMsg}');
                    validationMessages.push(errorMsg);
                    
                    if (console != null && validationMessages.length > 0) {
                        console.appendText("Role validation failed:", true);
                        for (msg in validationMessages) {
                            console.appendText("- " + msg, true);
                        }
                    }
                    
                    return false;
                }
            }
        }
        
        if (!valid) {
            var errorMsg = 'No enabled roles found for standard provisioner';
            Logger.warning('${this}: ${errorMsg}');
            validationMessages.push(errorMsg);
            
            if (console != null && validationMessages.length > 0) {
                console.appendText("Role validation failed:", true);
                for (msg in validationMessages) {
                    console.appendText("- " + msg, true);
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
            if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.webaddressinvalid' ) );

        } else {
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

        this._busy.value = false;
        this._status.value = ServerStatus.Running( false );

    }

    function _vagrantProvisionStandardOutputData( executor:AbstractExecutor, data:String ) {

        if ( console != null && !SuperHumanInstaller.getInstance().config.preferences.disablevagrantlogging ) console.appendText( data );

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
        this._busy.value = false;
        this._status.value = ServerStatus.Running( false );
    }

    function _vagrantRSyncStandardOutputData( executor:AbstractExecutor, data:String ) {
        if ( console != null && !SuperHumanInstaller.getInstance().config.preferences.disablevagrantlogging ) console.appendText( data );
    }

    function _vagrantRSyncStandardErrorData( executor:AbstractExecutor, data:String ) {

        if ( console != null ) console.appendText( data, true );
        Logger.error( '${this}: Vagrant rsync error: ${data}' );
        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.rsyncerror' ), true );

    }

    //
    // Vagrant stop
    //

    // Flag to indicate if provisioning was canceled
    var _provisioningCanceled:Bool = false;
    
    public function stop( forced:Bool = false ) {

        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.stop' ) );

        // If we're in the middle of provisioning, use a different approach
        if (_vagrantUpExecutor != null && _vagrantUpExecutor.running) {
            if (console != null) console.appendText("Stopping provisioning process...", true);
            
            // Mark that we're canceling provisioning
            _provisioningCanceled = true;
            
            // Set current action and status
            this._busy.value = true;
            this.status.value = ServerStatus.Stopping(true); // true indicates forced
            this._currentAction = ServerAction.Stop(false);
            
            // Clean up timers now
            _stopVagrantUpElapsedTimer();
            
            // Try to forcefully stop the VM using VirtualBox directly
            if (this.virtualBoxId != null) {
                if (console != null) console.appendText("Using VirtualBox to forcefully power off the VM...", true);
                
                // Execute the VirtualBox poweroff command
                try {
                    // Register for the poweroff callback before executing
                    if (!Lambda.has(VirtualBox.getInstance().onPowerOffVM, _onProvisioningPowerOffVM)) {
                        VirtualBox.getInstance().onPowerOffVM.add(_onProvisioningPowerOffVM);
                    }
                    
                    var powerOffExecutor = VirtualBox.getInstance().getPowerOffVM(
                        this._combinedVirtualMachine.value.virtualBoxMachine
                    );
                    powerOffExecutor.execute(this._serverDir);
                    
                    if (console != null) console.appendText("VirtualBox poweroff command issued successfully", true);
                } catch (e:Dynamic) {
                    Logger.error('${this}: Error executing VirtualBox poweroff: ${e}');
                    if (console != null) console.appendText('Error executing VirtualBox poweroff: ${e}', true);
                    
                    // If poweroff failed, manually set to Stopped with error state
                    this._status.value = ServerStatus.Stopped(true);
                }
            } else {
                Logger.warning('${this}: Cannot power off VM - virtualBoxId is null');
                if (console != null) console.appendText("Cannot power off VM - machine ID is not available yet", true);
                
                // Even if VM ID is not available, set to Stopped with error state
                this._status.value = ServerStatus.Stopped(true);
            }
            
            // Also try to stop the Vagrant process directly
            try {
                _vagrantUpExecutor.stop(true);
            } catch (e:Dynamic) {
                Logger.error('${this}: Error stopping Vagrant process: ${e}');
            }
            
            return; // Skip the regular vagrant halt process
        }

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
            Logger.error( '${this}: Server cannot be stopped normally, will try VirtualBox direct method' );
            
            // Try to forcefully stop the VM using VirtualBox directly
            if (this.virtualBoxId != null) {
                if (console != null) console.appendText("Vagrant halt failed. Using VirtualBox to forcefully power off the VM...", true);
                
                // Execute the VirtualBox poweroff command
                try {
                    var powerOffExecutor = VirtualBox.getInstance().getPowerOffVM(
                        this._combinedVirtualMachine.value.virtualBoxMachine
                    );
                    powerOffExecutor.execute(this._serverDir);
                    
                    if (console != null) console.appendText("VirtualBox poweroff command issued successfully", true);
                } catch (e:Dynamic) {
                    Logger.error('${this}: Error executing VirtualBox poweroff: ${e}');
                    if (console != null) console.appendText('Error executing VirtualBox poweroff: ${e}', true);
                }
            } else {
                Logger.warning('${this}: Cannot power off VM - virtualBoxId is null');
                if (console != null) console.appendText("Cannot power off VM - machine ID is not available", true);
            }
        }

        this._currentAction = ServerAction.Stop( _vagrantHaltExecutor.hasErrors || _vagrantHaltExecutor.exitCode > 0 );
        refreshVirtualBoxInfo();
    }

    function _vagrantHaltStandardOutputData( executor:AbstractExecutor, data:String ) {
        if ( console != null && !SuperHumanInstaller.getInstance().config.preferences.disablevagrantlogging ) console.appendText( data );
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
        // Always set unregisterVM (second parameter) to true if:
        // 1. Current status is Aborted OR
        // 2. VM exists in VirtualBox
        this._status.value = ServerStatus.Destroying( this._status.value == ServerStatus.Aborted || this.vmExistsInVirtualBox() );

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
    }

    function _vagrantDestroyStandardErrorData( executor:AbstractExecutor, data:String ) {
        if ( console != null ) console.appendText( data, true );
        Logger.error( '${this}: Vagrant destroy error: ${data}' );
        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.destroyerror' ), true );
    }

    function _onVagrantDestroy( machine:VagrantMachine ) {
        try {
            // Log that we're starting the destroy handler with machine info
            var machineInfo = machine != null ? 
                (machine.serverId != null ? 'machine with serverId=${machine.serverId}' : 'machine with null serverId') : 
                'null machine';

            // Validate machine parameter first to avoid null reference
            if (machine == null) {
                Logger.warning('${this}: Vagrant destroy callback received null machine');
                
                // Handle this case by manually updating status and VM info
                try {
                    // Ensure the status is safe
                    this._status.value = ServerStatus.Unknown;
                    this._busy.value = false;
                    
                    // Try to refresh VirtualBox info to recover
                    if (this._combinedVirtualMachine != null && 
                        this._combinedVirtualMachine.value != null && 
                        this._combinedVirtualMachine.value.virtualBoxMachine != null) {
                        refreshVirtualBoxInfo();
                    }
                } catch (e) {
                    Logger.error('${this}: Failed to recover from null machine: ${e}');
                }
                return;
            }

            // Validate serverId match
            if (machine.serverId != this._id) {
                Logger.warning('${this}: Vagrant destroy callback for wrong server: ${machine.serverId} vs ${this._id}');
                return;
            }

            // First, safely remove the callback to prevent multiple triggers
            try {
                var vagrant = Vagrant.getInstance();
                if (vagrant != null && vagrant.onDestroy != null) {
                    vagrant.onDestroy.remove(_onVagrantDestroy);
                }
            } catch (e) {
                Logger.warning('${this}: Error removing destroy callback: ${e}');
            }

            // Safe console access
            if (console != null) {
                try {
                    console.appendText(LanguageManager.getInstance().getString('serverpage.server.console.destroyed'));
                } catch (e) {
                    Logger.error('${this}: Error accessing console: ${e}');
                }
            }

            // Safely delete provisioning proof file
            if (_provisioner != null) {
                try {
                    _provisioner.deleteProvisioningProofFile();
                } catch (e) {
                    Logger.error('${this}: Error deleting provisioning proof file: ${e}');
                }
            }

            // Update server state based on current status - with safe null checks
            try {
                var curStatus = this.status != null ? this.status.value : null;
                var isDestroying = curStatus != null && curStatus.match(ServerStatus.Destroying(true));
                
                if (isDestroying) {
                    try {
                        _unregisterVM();
                    } catch (e) {
                        Logger.error('${this}: Error unregistering VM: ${e}');
                        try {
                            // Force state update even if unregister fails
                            this._status.value = ServerStatus.Unknown;
                            this._busy.value = false;
                            refreshVirtualBoxInfo();
                        } catch (e2) {
                            Logger.error('${this}: Critical error during recovery: ${e2}');
                        }
                    }
                } else {
                    refreshVirtualBoxInfo();
                }
            } catch (e) {
                Logger.error('${this}: Error updating server state after destroy: ${e}');
                
                // Last resort recovery
                try {
                    this._status.value = ServerStatus.Unknown;
                    this._busy.value = false;
                } catch (e2) {
                    Logger.error('${this}: Critical failure in recovery: ${e2}');
                }
            }
        } catch (e) {
            // Global try/catch for the entire method
            Logger.error('${this}: Unhandled exception in _onVagrantDestroy: ${e}');
            try {
                // Force a final status update to prevent UI from hanging
                this._status.value = ServerStatus.Unknown;
                this._busy.value = false;
            } catch (e2) {
                // Nothing more we can do
                Logger.error('${this}: Fatal error in recovery: ${e2}');
            }
        }
    }

    function _unregisterVM() {

        if ( !Lambda.has( VirtualBox.getInstance().onUnregisterVM, _vmUnregistered ) )
            VirtualBox.getInstance().onUnregisterVM.add( _vmUnregistered );

        final executor = VirtualBox.getInstance().getUnregisterVM( this._combinedVirtualMachine.value.virtualBoxMachine, true );
        executor.execute( this._serverDir );

    }

    function _vmUnregistered( machine:VirtualBoxMachine ) {

        if ( machine.virtualBoxId != this._combinedVirtualMachine.value.virtualBoxMachine.virtualBoxId ) return;

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

        // Check for the plugin first, then proceed to vagrant up
        _checkAndInstallVagrantPlugin();
    }
    
    /**
     * Check if the vagrant-scp-sync plugin is installed, and install it if needed
     */
    function _checkAndInstallVagrantPlugin() {
        if (console != null) console.appendText("Checking for vagrant-scp-sync plugin...");
        
        try {
            // First check if the plugin is already installed
            var pluginOutput = "";
            var checkExecutor = new Executor(Vagrant.getInstance().path + Vagrant.getInstance().executable, ["plugin", "list"]);
            
            // Collect the output as it comes
            checkExecutor.onStdOut.add((executor:AbstractExecutor, data:String) -> {
                pluginOutput += data;
                if (console != null) console.appendText(data);
            });
            
            checkExecutor.onStop.add((executor:AbstractExecutor) -> {
                if (pluginOutput.indexOf("vagrant-scp-sync") >= 0) {
                    // Plugin is already installed, proceed directly to vagrant up
                    if (console != null) console.appendText("vagrant-scp-sync plugin already installed");
                    _executeVagrantUp();
                } else {
                    // Plugin not found, install it
                    _safeInstallVagrantPlugin();
                }
            });
            
            checkExecutor.execute();
        } catch (e:Dynamic) {
            // If anything goes wrong with the check, log it and continue with vagrant up
            Logger.error('${this}: Error checking vagrant plugin: ${e}');
            if (console != null) console.appendText('Error checking vagrant plugin: ${e}', true);
            // Continue with vagrant up anyway
            _executeVagrantUp();
        }
    }
    
    /**
     * Install the vagrant-scp-sync plugin before running vagrant up for the first time,
     * with additional error handling and fallback
     */
    function _safeInstallVagrantPlugin() {
        if (console != null) console.appendText("Installing vagrant-scp-sync plugin...");
        
        try {
            // Create a custom executor for the plugin installation command
            var pluginExecutor = new Executor(Vagrant.getInstance().path + Vagrant.getInstance().executable, ["plugin", "install", "vagrant-scp-sync"]);
            
            // Add event handlers with explicit null checks
            if (pluginExecutor != null) {
                if (pluginExecutor.onStart != null) 
                    pluginExecutor.onStart.add(_pluginInstallStarted);
                if (pluginExecutor.onStop != null) 
                    pluginExecutor.onStop.add(_pluginInstallStopped);
                if (pluginExecutor.onStdOut != null) 
                    pluginExecutor.onStdOut.add(_pluginInstallStandardOutputData);
                if (pluginExecutor.onStdErr != null) 
                    pluginExecutor.onStdErr.add(_pluginInstallStandardErrorData);
                
                // Execute only if the executor was properly initialized
                try {
                    pluginExecutor.execute();
                } catch (execError:Dynamic) {
                    Logger.error('${this}: Error executing plugin installation: ${execError}');
                    if (console != null) console.appendText('Error executing plugin installation: ${execError}', true);
                    _executeVagrantUp();
                }
            } else {
                Logger.error('${this}: Failed to create plugin installation executor');
                if (console != null) console.appendText('Failed to create plugin installation executor', true);
                _executeVagrantUp();
            }
        } catch (e:Dynamic) {
            // If there's any exception, log it and continue with vagrant up
            Logger.error('${this}: Exception during plugin installation setup: ${e}');
            if (console != null) console.appendText('Exception during plugin installation setup: ${e}', true);
            // Continue with vagrant up even if plugin installation fails
            _executeVagrantUp();
        }
    }
    
    function _pluginInstallStarted(executor:AbstractExecutor) {
        if (console != null) console.appendText("Vagrant plugin installation started");
    }
    
    function _pluginInstallStopped(executor:AbstractExecutor) {
        if (console != null) {
            if (executor.exitCode == 0) {
                console.appendText("Vagrant plugin installation completed successfully");
            } else {
                console.appendText("Vagrant plugin installation failed with exit code: ${executor.exitCode}", true);
                console.appendText("Continuing without the plugin - some features may be limited", true);
            }
        }
        
        // Now proceed with vagrant up, regardless of whether the plugin installation succeeded
        _executeVagrantUp();
    }
    
    function _pluginInstallStandardOutputData(executor:AbstractExecutor, data:String) {
        if (console != null) console.appendText(data);
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

        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.vagrantupstarted' ) );

    }

    function _vagrantUpStopped( executor:AbstractExecutor ) {
        
        // Record if this was stopped due to user cancellation
        var wasExplicitlyCanceled = _provisioningCanceled;
        
        // Always reset the cancellation flag
        _provisioningCanceled = false;

        if ( executor.exitCode > 0 || wasExplicitlyCanceled ) {
            Logger.error( '${this}: Vagrant up stopped with exitcode: ${executor.exitCode}${wasExplicitlyCanceled ? " (manually canceled by user)" : ""}' );
        }

        var elapsed = StrTools.timeToFormattedString( _vagrantUpElapsedTime );

        if ( console != null ) {
            if (wasExplicitlyCanceled) {
                console.appendText("Provisioning process was canceled by user.", true);
                console.appendText("You can now destroy the VM if needed.", true);
            }
            console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.vagrantupstopped', Std.string( executor.exitCode ), elapsed ), executor.exitCode > 0 );
        }

        // If it was explicitly canceled or had errors, mark as error state
        hasExecutionErrors = wasExplicitlyCanceled || executor.hasErrors || executor.exitCode > 0;
        this._currentAction = ServerAction.Start( hasExecutionErrors );

        // Clean up timers just to be sure
        _stopVagrantUpElapsedTimer();
        _provisioner.stopFileWatcher();

        if ( hasExecutionErrors ) {
            // Special handling for user cancellation
            if (wasExplicitlyCanceled) {
                
                // Force state to Stopped with errors to show destroy button
                this._status.value = ServerStatus.Stopped(true);
                this._busy.value = false;
                
                // Skip any auto-cleanup of the VM
                refreshVirtualBoxInfo();
            }
            // Normal handling for non-cancellation errors
            else if ( keepFailedServersRunning ) {

                // Refreshing VirtualBox info
                this._currentAction = ServerAction.GetStatus( true );
                refreshVirtualBoxInfo();
            } else {
                // Stop or destroy the server
                if ( _provisionedBeforeStart ) {

                    if ( !Lambda.has( Vagrant.getInstance().onHalt, _onVagrantUpHalt ) )
                        Vagrant.getInstance().onHalt.add( _onVagrantUpHalt );
            
                    this._currentAction = ServerAction.Stop( true );
                    Vagrant.getInstance().getHalt( this._combinedVirtualMachine.value.vagrantMachine, false ).execute( this._serverDir );
                } else {

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

        // Clean up the executor
        _vagrantUpExecutor = null;
        executor.dispose();
    }

    function _vagrantUpStandardOutputData( executor:AbstractExecutor, data:String ) {
     
    		var vagrantLogging:Bool = SuperHumanInstaller.getInstance().config.preferences.disablevagrantlogging;
        if ( console != null && !vagrantLogging ) console.appendText( new String( data ) );
        _provisioner.updateTaskProgress( data );
        
    }

    function _vagrantUpStandardErrorData( executor:AbstractExecutor, data:String ) {
        
        if ( console != null ) console.appendText( data, true );
        Logger.error( '${this}: Vagrant up error: ${data}' );

    }
    
    /**
     * Callback for when the VirtualBox poweroff command completes after canceling provisioning
     */
    function _onProvisioningPowerOffVM( machine:VirtualBoxMachine ) {
        // Make sure this is for our machine
        if (machine.virtualBoxId != this._combinedVirtualMachine.value.virtualBoxMachine.virtualBoxId) return;
        
        // Remove the callback
        VirtualBox.getInstance().onPowerOffVM.remove(_onProvisioningPowerOffVM);
        
        if (console != null) console.appendText("VM has been successfully powered off.", true);
        
        // Force delete the provisioning proof file to ensure it's marked as not provisioned
        if (_provisioner != null) {
            _provisioner.deleteProvisioningProofFile();
            if (console != null) console.appendText("Marking server as corrupt since provisioning was interrupted.", true);
        }
        
        // Keep the server in stopping state until cleanup is complete
        this._status.value = ServerStatus.Stopping(true); // Keep in stopping state
        this._busy.value = true; // Keep busy flag on to prevent state changes
        
        // Wait for 30 seconds to allow any Ruby provisioning processes to terminate
        if (console != null) console.appendText("Waiting 30 seconds for provisioning processes to clean up...", true);
        
        // Create a timer for the 30-second delay
        var cleanupTimer = new Timer(30000); // 30 seconds in milliseconds
        cleanupTimer.run = () -> {
            // Stop the timer after one execution
            cleanupTimer.stop();
            
            // Delete the provisioning proof file again to be absolutely sure
            if (_provisioner != null) {
                _provisioner.deleteProvisioningProofFile();
            }
            
            // Explicitly set state to Stopped with errors to make the destroy button appear
            if (console != null) console.appendText("Cleanup completed. Setting server to stopped with error state...", true);
            
            this._status.value = ServerStatus.Stopped(true);
            this._busy.value = false;
            
            // Wait a brief moment before refreshing the VirtualBox info to ensure UI state has updated
            Timer.delay(() -> {
                // Refresh VM info to update the UI
                refreshVirtualBoxInfo();
                
                if (console != null) console.appendText("Server is now in a stopped and corrupt state. You can destroy the VM if needed.", true);
            }, 500); // Small additional delay to ensure UI state updates first
        };
    }

    function _onVagrantUpDestroy( machine:VagrantMachine ) {

        if ( machine.serverId != this._id ) return;

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

        // Determine if this is a custom provisioner
        var isCustomProvisioner = (this._provisioner != null && 
                                   this._provisioner.type != null &&
                                   Std.string(this._provisioner.type) != Std.string(ProvisionerType.StandaloneProvisioner) && 
                                   Std.string(this._provisioner.type) != Std.string(ProvisionerType.AdditionalProvisioner) && 
                                   Std.string(this._provisioner.type) != Std.string(ProvisionerType.Default));
        
        Logger.verbose('${this}: Setting server status: isCustomProvisioner=${isCustomProvisioner}');
        
        // For custom provisioners, only lock hostname and networking fields
        // Organization and SafeID fields don't apply to custom provisioners
        if (isCustomProvisioner) {
            // Fields to lock for custom provisioners when provisioned
            this._hostname.locked = this._networkBridge.locked = 
            this._networkAddress.locked = this._networkGateway.locked = 
            this._networkNetmask.locked = this._dhcp4.locked = 
            this._disableBridgeAdapter.locked = (this._provisioner != null && this._provisioner.provisioned == true);
            
            // Organization and safeID fields should not be locked for custom provisioners
            this._organization.locked = false;
            this._userSafeId.locked = false;
            this._userEmail.locked = false;
            
            // Lock roles only if provisioned
            this._roles.locked = (this._provisioner != null && this._provisioner.provisioned == true);
        } else {
            // Standard locking behavior for built-in provisioners
            this._hostname.locked = this._organization.locked = this._userSafeId.locked = 
            this._roles.locked = this._networkBridge.locked = this._networkAddress.locked = 
            this._networkGateway.locked = this._networkNetmask.locked = this._dhcp4.locked = 
            this._userEmail.locked = this._disableBridgeAdapter.locked = 
                (this._provisioner != null && this._provisioner.provisioned == true);
        }
    }

    function _serverStatusChanged( property:Property<ServerStatus> ) {
        try {
            if (_onStatusUpdate == null) {
                Logger.warning('${this}: Cannot update status - _onStatusUpdate is null');
                return;
            }
            
            for ( f in _onStatusUpdate ) {
                try {
                    f( this, false );
                } catch (e) {
                    Logger.error('${this}: Error in status update callback: ${e}');
                    // Continue with other callbacks despite errors
                }
            }
        } catch (e) {
            Logger.error('${this}: Unhandled exception in _serverStatusChanged: ${e}');
        }
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
