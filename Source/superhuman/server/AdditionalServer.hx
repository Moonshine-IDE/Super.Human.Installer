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
import superhuman.server.provisioners.AdditionalProvisioner;
import lime.system.System;

class AdditionalServer extends Server {

    public static final _HOSTNAME:EReg = ~/^[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?)*$/;
    public static final _HOSTNAME_WITH_PATH:EReg = ~/^[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]*[a-zA-Z0-9])?)*(\/.+)?$/;

    override function get_url():ServerURL {
        return getHostNameServerUrl(hostname.value);
    }

    var _existingServerName:ValidatingProperty;

    public var existingServerName( get, never ):ValidatingProperty;
    function get_existingServerName() return _existingServerName;

    var _existingServerIpAddress:ValidatingProperty;

    public var existingServerIpAddress( get, never ):ValidatingProperty;
    function get_existingServerIpAddress() return _existingServerIpAddress;

    function new() {
        super();

        _hostname.onChange.remove(_propertyChanged);
        _hostname = new ValidatingProperty( "", _HOSTNAME, true, 1 );
        _hostname.onChange.add( _propertyChanged );

        _existingServerName = new ValidatingProperty( "", _HOSTNAME_WITH_PATH, true, 1 );
        _existingServerName.onChange.add( _propertyChanged );

        _existingServerIpAddress = new ValidatingProperty( "", Server._VK_IP, true );
        _existingServerIpAddress.onChange.add( _propertyChanged );
    }

    static public function create( data:ServerData, rootDir:String ):AdditionalServer {
         var sc = new AdditionalServer();

        sc._id = data.server_id;
        sc._serverDir = Path.normalize( rootDir + "/additional-provisioner/" + sc._id );
        FileSystem.createDirectory( sc._serverDir );
        sc._path.value = sc._serverDir;

        var latestDemoTasks = ProvisionerManager.getBundledProvisioners(ProvisionerType.AdditionalProvisioner)[ 0 ];

        if ( data.provisioner == null ) {

            sc._provisioner = new AdditionalProvisioner(ProvisionerType.AdditionalProvisioner, latestDemoTasks.root, sc._serverDir, sc );

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

    override public function saveHostsFile() {

        if ( isValid() ) 
        {
            cast(this.provisioner, AdditionalProvisioner).saveHostsFile();
        }
    }

	override function _saveSafeId() {

        var r = this._provisioner.saveSafeId( _serverProvisionerId.value );
        if ( !r ) this._busy.value = false;

    }

    override public function safeIdExists():Bool {

        if ( _serverProvisionerId == null || _serverProvisionerId.value == null || _serverProvisionerId.value == "" ) return false;

        return FileSystem.exists( _serverProvisionerId.value );

    }

    override public function getData():ServerData {
        var sd:ServerData = super.getData();
            sd.existingServerName = _existingServerName.value;
            sd.existingServerIpAddress = _existingServerIpAddress.value;
        return sd;
    }

    public function locateServerProvisionerId( ?callback:()->Void ) {

        var dir = ( SuperHumanInstaller.getInstance().config.user.lastuseddirectory != null ) ? SuperHumanInstaller.getInstance().config.user.lastuseddirectory : System.userDirectory;
        var fd = new FileDialog();
        var currentDir:String;

        fd.onSelect.add( path -> {

            currentDir = Path.directory( path );
            _serverProvisionerId.value = path;

            if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.provisionerserveridselected', path ) );

            if ( currentDir != null ) SuperHumanInstaller.getInstance().config.user.lastuseddirectory = currentDir;
            if ( callback != null ) callback();

        } );

        fd.browse( FileDialogType.OPEN, null, dir + "/", "Locate your Server Id file with .ids extension" );

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