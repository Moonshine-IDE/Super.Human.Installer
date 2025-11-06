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
class AdditionalProvisioner extends StandaloneProvisioner {
    
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
			roles: [ for ( r in StandaloneProvisioner.getDefaultProvisionerRoles().keyValueIterator() ) r.value ],
			server_hostname: "",
			server_id: id,
			server_organization: "",
			type: ServerType.Domino,
			user_email: "",
            provisioner: {
                type: ProvisionerType.AdditionalProvisioner,
                version: champaign.core.primitives.VersionInfo.fromString("0.1.23")
            },
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
        _hostsTemplate = getFileContentFromSourceTemplateDirectory( StandaloneProvisioner.HOSTS_TEMPLATE_FILE );

        return AdditionalProvisionerHostsFileGenerator.generateContent( _hostsTemplate, this );
    }

	override public function saveSafeId( serverIdPath:String ):Bool {
        // Very simple version - just copy the file and don't complicate things
        // When serverIdPath is just a version number, we detect and handle it
        
        // Print a direct error if serverIdPath equals the version number
        if (serverIdPath == this.version) {
            Logger.error('CRITICAL ERROR: serverIdPath is set to version number "${serverIdPath}" instead of a file path!');
            Logger.error('This is likely a bug in the code passing the version instead of the actual server ID file path');
            if ( console != null ) console.appendText('ERROR: The version number "${serverIdPath}" was used as a file path. This is a bug.', true);
            return false;
        }
        
        createTargetDirectory();

        if (FileSystem.exists(serverIdPath)) {
            var safeIdDir = Path.addTrailingSlash(_targetPath) + Path.addTrailingSlash(_getSafeIdLocation());
            FileSystem.createDirectory(safeIdDir);
            
            // Get the original filename instead of hardcoding "server.id"
            var originalFileName = Path.withoutDirectory(serverIdPath);
            var destPath = safeIdDir + originalFileName;
            
            Logger.info('${this}: Copying server ID file with original filename: ${originalFileName}');
            
            try {
                // Copy preserving the original filename
                File.copy(serverIdPath, destPath);
                if (console != null) console.appendText('Copied server ID from ${serverIdPath} to ${destPath}');
                return true;
            } catch (e:Exception) {
                Logger.error('Failed to copy server ID: ${e.message}');
                if (console != null) console.appendText('Failed to copy server ID: ${e.message}', true);
            }
        } else {
            Logger.error('Server ID file not found at path: ${serverIdPath}');
            if (console != null) console.appendText('Server ID file not found at: ${serverIdPath}', true);
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
