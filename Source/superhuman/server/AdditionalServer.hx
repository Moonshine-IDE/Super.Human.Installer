package superhuman.server;

import superhuman.server.provisioners.ProvisionerType;
import sys.FileSystem;
import haxe.io.Path;
import superhuman.managers.ProvisionerManager;
import superhuman.server.data.ServerData;
import superhuman.server.provisioners.AdditionalProvisioner;

class AdditionalServer extends Server {

    static public function create( data:ServerData, rootDir:String ):Server {
         var sc = new Server();

        sc._id = data.server_id;
        sc._serverDir = Path.normalize( rootDir + "/additional-provisioner/" + sc._id );
        FileSystem.createDirectory( sc._serverDir );
        sc._path.value = sc._serverDir;

        var latestDemoTasks = ProvisionerManager.getBundledProvisioners(ProvisionerType.AdditionalProvisioner)[ 0 ];

        if ( data.provisioner == null ) {

            sc._provisioner = new AdditionalProvisioner( latestDemoTasks.root, sc._serverDir, sc );

        } else {

            var provisioner = ProvisionerManager.getProvisionerDefinition( data.provisioner.type, data.provisioner.version );

            if ( provisioner != null ) {

                sc._provisioner = new AdditionalProvisioner( provisioner.root, sc._serverDir, sc );

            } else {

                // The server already exists BUT the provisioner version is not supported
                // so we create the provisioner with target path only
                sc._provisioner = new AdditionalProvisioner( null, sc._serverDir, sc );

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
}