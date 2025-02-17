package superhuman.server.provisioners;

import sys.io.File;
import genesis.application.managers.LanguageManager;
import sys.FileSystem;
import superhuman.server.data.ServerData;
import superhuman.managers.ProvisionerManager;
import superhuman.server.hostsFileGenerator.AdditionalProvisionerHostsFileGenerator;
import haxe.Exception;
import haxe.io.Path;
import champaign.core.logging.Logger;

@:allow( superhuman.server.hostsFileGenerator.AdditionalProvisionerHostsFileGenerator )
class AdditionalProvisioner extends DemoTasks {
    
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
			roles: [ for ( r in DemoTasks.getDefaultProvisionerRoles().keyValueIterator() ) r.value ],
			server_hostname: "",
			server_id: id,
			server_organization: "",
			type: ServerType.Domino,
			user_email: "",
            provisioner: ProvisionerManager.getBundledProvisioners(ProvisionerType.AdditionalProvisioner)[ 0 ].data,
            syncMethod: SyncMethod.Rsync,
			existingServerName: "",
			existingServerIpAddress: ""
		};

    }

    static public function getRandomServerId( serverDirectory:String ):Int {

		// Range: 1025 - 9999
		var r = Math.floor( Math.random() * 8974 ) + 1025;

		if ( FileSystem.exists( '${serverDirectory}${ProvisionerType.AdditionalProvisioner}/${r}' ) ) return getRandomServerId( serverDirectory );

		return r;

	}

    public override function generateHostsFileContent():String {
        _hostsTemplate = getFileContentFromSourceTemplateDirectory( DemoTasks.HOSTS_TEMPLATE_FILE );

        return AdditionalProvisionerHostsFileGenerator.generateContent( _hostsTemplate, this );
    }

	override public function saveSafeId( serverIdPath:String ):Bool {

        createTargetDirectory();

        if ( FileSystem.exists( serverIdPath ) ) {

            var safeIdDir = Path.addTrailingSlash( _targetPath ) + Path.addTrailingSlash( _getSafeIdLocation() );
            FileSystem.createDirectory( safeIdDir );

            try {

                File.copy( serverIdPath, safeIdDir + "server.id" );
                if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.copyserverid', serverIdPath, safeIdDir + "server.id" ) );
                return true;

            } catch ( e:Exception ) {

                Logger.error( '${this}: Server ID at ${serverIdPath} cannot be copied to ${safeIdDir + "server.id"}. Details: ${e.details()} Message: ${e.message}' );
                if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.copyserveridfailed', '${e.details()} Message: ${e.message}' ), true );

            }

        } else {

            Logger.error( '${this}: Server ID does not exist at ${serverIdPath}' );
            if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.provisionerserveridnonexistent', serverIdPath ), true );

        }

        return false;

    }

    override function _getSafeIdLocation():String {
        return "id-files/server-ids";
    }

    public override function toString():String {
        return '[AdditionalProvisioner(v${this.version})]';
    }
}