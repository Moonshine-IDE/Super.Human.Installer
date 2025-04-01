package superhuman.server;

import lime.ui.FileDialogType;
import lime.ui.FileDialog;
import genesis.application.managers.LanguageManager;
import prominic.sys.applications.oracle.VirtualBox;
import prominic.sys.applications.hashicorp.Vagrant;
import prominic.core.primitives.ValidatingProperty;
import superhuman.server.provisioners.ProvisionerType;
import sys.FileSystem;
import haxe.io.Path;
import superhuman.managers.ProvisionerManager;
import superhuman.server.data.ServerData;
import superhuman.server.data.ProvisionerData;
import superhuman.server.provisioners.AdditionalProvisioner;
import lime.system.System;
import champaign.core.logging.Logger;

class AdditionalServer extends Server {

    public static final _HOSTNAME:EReg = ~/^[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?)*$/;
    public static final _HOSTNAME_WITH_PATH:EReg = ~/^[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?)*$/;
    public static final _SERVER_ORGANIZATION:EReg = ~/(?:\/)?([^\/]+)$/;
    override function get_url():ServerURL {
        return getHostNameServerUrl(hostname.value);
    }

    var _existingServerName:ValidatingProperty;

    public var existingServerName( get, never ):ValidatingProperty;
    function get_existingServerName() return _existingServerName;

    var _existingServerIpAddress:ValidatingProperty;

    public var existingServerIpAddress( get, never ):ValidatingProperty;
    function get_existingServerIpAddress() return _existingServerIpAddress;

    override function get_fqdn():String {
        return url.hostname + "." + url.domainName + "/" + organization.value;
    }

    function new() {
        super();

        _hostname.onChange.remove(_propertyChanged);
        _hostname = new ValidatingProperty( "", _HOSTNAME, true, 1 );
        _hostname.onChange.add( _propertyChanged );

        _existingServerName = new ValidatingProperty( "", _HOSTNAME_WITH_PATH, true, 1 );
        _existingServerName.onChange.add( _propertyChanged );

        _organization = new ValidatingProperty( "", _SERVER_ORGANIZATION, 1 );
        _organization.onChange.add( _propertyChanged );

        _existingServerIpAddress = new ValidatingProperty( "", Server._VK_IP, true );
        _existingServerIpAddress.onChange.add( _propertyChanged );
    }

    static public function create( data:ServerData, rootDir:String ):AdditionalServer {
         var sc = new AdditionalServer();

        sc._id = data.server_id;
        sc._serverDir = Path.normalize( rootDir + "/hcl_domino_additional_provisioner/" + sc._id );
        FileSystem.createDirectory( sc._serverDir );
        sc._path.value = sc._serverDir;

        var latestStandaloneProvisioner = ProvisionerManager.getBundledProvisioners(ProvisionerType.AdditionalProvisioner)[ 0 ];

        if ( data.provisioner == null ) {

            sc._provisioner = new AdditionalProvisioner(ProvisionerType.AdditionalProvisioner, latestStandaloneProvisioner.root, sc._serverDir, sc );

        } else {

            var provisioner = ProvisionerManager.getProvisionerDefinition( data.provisioner.type, data.provisioner.version );

            if ( provisioner != null ) {

                sc._provisioner = new AdditionalProvisioner(ProvisionerType.AdditionalProvisioner, provisioner.root, sc._serverDir, sc );

            } else {

                // The server already exists BUT the provisioner version is not supported
                // so we create the provisioner with target path only
                sc._provisioner = new AdditionalProvisioner( ProvisionerType.AdditionalProvisioner, null, sc._serverDir, sc );

            }

        }

        sc._existingServerName.value = data.existingServerName;
        sc._existingServerIpAddress.value = data.existingServerIpAddress;
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
        sc._created = true;
        sc._setServerStatus();
        return sc;
    }

    override public function isValid():Bool {

        var hasVagrant:Bool = Vagrant.getInstance().exists;
        var hasVirtualBox:Bool = VirtualBox.getInstance().exists;
        var hasValidHostname:Bool = _hostname.isValid();
        var hasValidExistingDominoServer:Bool = _existingServerName.isValid();
        var hasEnoughMemory:Bool = _memory.value >= 4;
        var hasEnoughCPUs:Bool = _numCPUs.value >= 1;
        var isDHCPEnabled:Bool = _dhcp4.value;
        
        var hasValidNetworkConfig:Bool = _networkBridge.isValid() &&
            _networkAddress.isValid() &&
            _networkGateway.isValid() &&
            _networkNetmask.isValid() &&
            _nameServer1.isValid() &&
            _nameServer2.isValid();
            
        var hasValidRoles:Bool = areRolesValid();
        
        var isValid:Bool = hasVagrant &&
            hasVirtualBox &&
            hasValidHostname &&
            hasValidExistingDominoServer &&
            hasEnoughMemory &&
            hasEnoughCPUs &&
            (isDHCPEnabled || hasValidNetworkConfig) &&
            hasValidRoles;

        return isValid;

    }

    public function getExistingServerUrl():ServerURL
    {
        return getHostNameServerUrl(_existingServerName.value);
    }

    public function getOrganization():String
    {
        if (_organization.isValid()) {
            return _SERVER_ORGANIZATION.matched(1);
        }
        return null;
    }
    
    override public function saveHostsFile() {

        if ( isValid() ) 
        {
            cast(this.provisioner, AdditionalProvisioner).saveHostsFile();
        }
    }

	override function _saveSafeId() {
        // AdditionalServer uses serverProvisionerId for the server.id file
        // This is set by locateServerProvisionerId()
        
        // CRITICAL FIX: Make sure we never use the provisioner version as a file path
        if (_serverProvisionerId == null || _serverProvisionerId.value == null || _serverProvisionerId.value == "") {
            Logger.error('${this}: No server ID file path selected');
            if (console != null) console.appendText("Error: No server ID file has been selected. Please use the 'Locate' button to select a server ID file.", true);
            this._busy.value = false;
            return;
        }
        
        // Get the actual server ID file path - it should NEVER be the version number
        var serverIdPath = _serverProvisionerId.value;
        
        // Double-check the serverIdPath is not the provisioner version (critical bug)
        if (serverIdPath == this._provisioner.version) {
            Logger.error('${this}: BUG DETECTED - Server ID path is the same as the provisioner version (${serverIdPath})');
            if (console != null) console.appendText("BUG: Server ID path is using the version number instead of a file path. Please report this issue.", true);
            this._busy.value = false;
            return;
        }
        
        // Make sure the file exists at the path
        if (!FileSystem.exists(serverIdPath)) {
            Logger.error('${this}: Server ID file does not exist at path: ${serverIdPath}');
            if (console != null) console.appendText("Error: The selected server ID file cannot be found at: " + serverIdPath, true);
            this._busy.value = false;
            return;
        }
        
        // Now call the provisioner with the correct path
        var result = this._provisioner.saveSafeId(serverIdPath);
        if (!result) {
            this._busy.value = false;
        }
    }

    override public function safeIdExists():Bool {
        // For AdditionalServer, we need to check the server ID file
        if ( _serverProvisionerId == null || _serverProvisionerId.value == null || _serverProvisionerId.value == "" ) return false;

        return FileSystem.exists( _serverProvisionerId.value );
    }

    override public function getData():ServerData {
        var sd:ServerData = super.getData();
            sd.existingServerName = _existingServerName.value;
            sd.existingServerIpAddress = _existingServerIpAddress.value;
            // Make sure server_provisioner_id is explicitly included 
            sd.server_provisioner_id = _serverProvisionerId.value;
        return sd;
    }

    // Override updateProvisioner to ensure we don't mess with the serverProvisionerId
    override public function updateProvisioner(data:ProvisionerData):Bool {
        // Call super implementation
        var result = super.updateProvisioner(data);
        
        // CRITICAL FIX: Make sure we never set serverProvisionerId to the version
        // The super.updateProvisioner might have set _serverProvisionerId.value to version
        if (_serverProvisionerId != null && _serverProvisionerId.value == this._provisioner.version) {
            Logger.error('${this}: updateProvisioner set serverProvisionerId to version - restoring previous value');
            // We don't have a previous value to restore, but we can at least clear it to force user selection
            _serverProvisionerId.value = null;
        }
        
        return result;
    }

    public function locateServerProvisionerId( ?callback:()->Void ) {

        if ( _fd != null ) return;
        
        var dir = ( SuperHumanInstaller.getInstance().config.user.lastuseddirectory != null ) ? SuperHumanInstaller.getInstance().config.user.lastuseddirectory : System.userDirectory;
        _fd = new FileDialog();
        var currentDir:String;
        
        // Default directory to start in
        var dir = (SuperHumanInstaller.getInstance().config.user.lastuseddirectory != null) ? 
            SuperHumanInstaller.getInstance().config.user.lastuseddirectory : System.userDirectory;

        _fd.onSelect.add(path -> {
            currentDir = Path.directory(path);
            
            // Verify the file exists
            if (FileSystem.exists(path)) {
                // Store the selected path for the server ID file
                _serverProvisionerId.value = path;
                Logger.info('${this}: Set serverProvisionerId to ${path}');
                
                // Immediately save the data to persist this change
                this.saveData();
                Logger.info('${this}: Saved server data after setting serverProvisionerId');
                
                if (console != null) {
                    console.appendText(LanguageManager.getInstance().getString('serverpage.server.console.provisionerserveridselected', path));
                }
                
                if (currentDir != null) {
                    SuperHumanInstaller.getInstance().config.user.lastuseddirectory = currentDir;
                }
                
                if (callback != null) {
                    callback();
                }
            } else {
                if (console != null) {
                    console.appendText('Error: Selected file does not exist: ${path}', true);
                }
            }
        });

        _fd.onCancel.add( () -> {
            _fd.onCancel.removeAll();
            _fd.onSelect.removeAll();
            _fd = null;
        } );

        _fd.browse(FileDialogType.OPEN, null, dir + "/", "Locate your Server Id file with .ids extension");
    }

    public static function getHostNameServerUrl(hostname:String):ServerURL
    {
        var result:ServerURL = { domainName: "", hostname: "", path: "" };
        
        // Split the URL by "/" to separate path
        var urlParts = hostname.split("/");
        var hostPart = urlParts[0];
        if (urlParts.length > 1) {
            result.path = urlParts[1];
        }

        // Split the host part by dots
        var a = hostPart.split(".");

        if (a.length == 3) {
            result.hostname = a[0];
            result.domainName = a[1] + "." + a[2];
        } else {
            result.hostname = "configure";
            result.domainName = "host.name";
        }
        return result;
    }
}
