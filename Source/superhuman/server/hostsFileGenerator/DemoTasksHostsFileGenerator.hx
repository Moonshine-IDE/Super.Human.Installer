package superhuman.server.hostsFileGenerator;

import superhuman.server.provisioners.roles.RolesUtil;
import superhuman.server.provisioners.DemoTasks;
import superhuman.server.provisioners.AbstractProvisioner;
import haxe.Template;
import haxe.io.Path;

class DemoTasksHostsFileGenerator extends AbstractHostsFileGenerator {
    static public function generateContent( sourceTemplate:String, provisioner:AbstractProvisioner ):String {

        var internalProvisioner:DemoTasks = cast(provisioner, DemoTasks);

        var output:String = null;
			
        var versionGreaterThan22:Bool = internalProvisioner.data.version > "0.1.22";
        
        var defaultProvisionerFieldValue:String = versionGreaterThan22 ? null : "";
        var defaultRoleFieldValue:Dynamic = versionGreaterThan22 ? false : "";
        
        var replace = _getDefaultTemplateValues(internalProvisioner, defaultProvisionerFieldValue, defaultRoleFieldValue);

        for ( r in internalProvisioner.server.roles.value ) {

			var roleValue = r.value;
			var replaceWith:String = "";
			var installerHash:String = r.files.installerHash == null ? defaultProvisionerFieldValue : "\"" + r.files.installerHash + "\"";
			var installerName:String = r.files.installerFileName == null ? defaultProvisionerFieldValue : r.files.installerFileName;
			var installerVersion:Dynamic = r.files.installerVersion;
			var hotfixVersion:Dynamic = r.files.installerHotFixVersion;
            var hotfixHash:Dynamic = r.files.installerHotFixHash;
			var fixpackVersion:Dynamic = r.files.installerFixpackVersion;
            var fixpackHash:Dynamic = r.files.installerFixpackHash;

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

                    if (fixpackHash != null)
                    {
                        replace.DOMINO_FP_HASH = fixpackHash;
                    }

                    if (hotfixHash != null)
                    {
                        replace.DOMINO_HF_HASH = hotfixHash;
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
                replaceWith = RolesUtil.getDominoRole(internalProvisioner.data.version, r.value, r.enabled);
 
                replace.LEAP_HASH = installerHash;
                replace.LEAP_INSTALLED_CHECK = r.enabled;
                replace.LEAP_INSTALLER = installerName;
                replace.LEAP_INSTALLER_VERSION = installerVersion == null ? "" : installerVersion.fullVersion;
                replace.ROLE_LEAP = replaceWith;
             }

            if ( r.value == "nomadweb" ) {
                
                //"- name: hcl_domino_nomadweb" : "- name: domino_nomadweb";
                replaceWith = RolesUtil.getDominoRole(internalProvisioner.data.version, r.value, r.enabled);
				
                replace.NOMADWEB_HASH = installerHash;
                replace.NOMADWEB_INSTALLER = installerName;
                replace.NOMADWEB_VERSION = installerVersion == null ? defaultProvisionerFieldValue : installerVersion.fullVersion;
                replace.ROLE_NOMADWEB = replaceWith;
            }

            if ( r.value == "traveler" ) {

                //"- name: hcl_domino_traveler" : "- name: domino_traveler"
                replaceWith = RolesUtil.getDominoRole(internalProvisioner.data.version, r.value, r.enabled);
            	    
                replace.TRAVELER_INSTALLER = installerName;
                replace.TRAVELER_INSTALLER_VERSION = installerVersion == null ? defaultProvisionerFieldValue : installerVersion.fullVersion;
                replace.ROLE_TRAVELER = replaceWith;
            }

            if ( r.value == "traveler_htmo" ) {

                //"- name: hcl_domino_traveler_htmo" : "- name: domino_traveler_htmo"
                replaceWith = RolesUtil.getDominoRole(internalProvisioner.data.version, "traveler_htmo", r.enabled);
                replace.ROLE_TRAVELER_HTMO = replaceWith;
            }

            if ( r.value == "verse" ) {

                //"- name: hcl_domino_verse" : "- name: domino_verse"
                replaceWith = RolesUtil.getDominoRole(internalProvisioner.data.version, r.value, r.enabled);
       
                replace.VERSE_INSTALLER = installerName;
                replace.VERSE_INSTALLER_VERSION = installerVersion == null ? defaultProvisionerFieldValue : installerVersion.fullVersion;
                replace.ROLE_VERSE = replaceWith;
            }

            if ( r.value == "appdevpack" ) {

                //"- name: hcl_domino_appdevpack" : "- name: domino_appdevpack"
                replaceWith = RolesUtil.getDominoRole(internalProvisioner.data.version, r.value, r.enabled);        
            		
                replace.APPDEVPACK_INSTALLER = installerName;
                replace.APPDEVPACK_INSTALLER_VERSION = installerVersion == null ? defaultProvisionerFieldValue : installerVersion.fullVersion;
                replace.ROLE_APPDEVPACK = replaceWith;
            }

            if ( r.value == "domino-rest-api" ) {

                //"- name: hcl_domino_rest_api" : "- name: domino_rest_api"
                replaceWith = RolesUtil.getDominoRole(internalProvisioner.data.version, "rest_api", r.enabled);

                replace.DOMINO_REST_API_INSTALLER = installerName;
                replace.DOMINO_REST_API_INSTALLER_VERSION = installerVersion == null ? defaultProvisionerFieldValue : installerVersion.fullVersion;
                replace.ROLE_RESTAPI = replaceWith;
                replace.ROLE_DOMINO_RESTAPI = replaceWith;
            }
        }

        replace.ROLE_JEDI = RolesUtil.getDominoRole(internalProvisioner.data.version, "jedi", true);
        //"- name: startcloud_quick_start";
        replace.ROLE_STARTCLOUD_QUICK_START = RolesUtil.getOtherRole(internalProvisioner.data.version, "quick_start");
         //"- name: startcloud_haproxy";
        replace.ROLE_STARTCLOUD_HAPROXY = RolesUtil.getOtherRole(internalProvisioner.data.version, "haproxy");
        //"- name: startcloud_vagrant_readme";
        replace.ROLE_STARTCLOUD_VAGRANT_README = RolesUtil.getOtherRole(internalProvisioner.data.version, "vagrant_readme");

        var template = new Template( sourceTemplate );
		output = template.execute( replace );

        if ( internalProvisioner.server.disableBridgeAdapter.value ) {

            // Remove the contents of networks yaml tag
            var r:EReg = ~/(?:networks:)((.|\n)*)(?:vbox:)/;
            
            if ( r.match( output ) ) {

                output = r.replace( output, "vbox:" );

            }

        }

        return output;

    }

    static function _getDefaultTemplateValues(internalProvisioner:DemoTasks, defaultProvisionerFieldValue:String = null, defaultRoleFieldValue:Dynamic = ""):Dynamic {
        return {
            USER_EMAIL: internalProvisioner.server.userEmail.value,
            
            //settings
         	SERVER_HOSTNAME: internalProvisioner.server.url.hostname,
         	SERVER_DOMAIN: internalProvisioner.server.url.domainName,
         	SERVER_ID: internalProvisioner.server.id,
            SHOW_CONSOLE: false,
            POST_PROVISION: true,
            BOX_URL: 'https://boxvault.startcloud.com',
            SYNC_METHOD: internalProvisioner.server.syncMethod,
            SYNCBACK_ID_FILES: true,
            DEBUG_ALL_ANSIBLE_TASKS: true,
         	RESOURCES_CPU: internalProvisioner.server.numCPUs.value,    
         	RESOURCES_RAM: Std.string( internalProvisioner.server.memory.value ) + "G",
         	
            USE_HTTP_PROXY: false,
            HTTP_PROXY_HOST: '255.255.255.255',
            HTTP_PROXY_PORT: 3128,

         	//vagrant_user
         	SERVER_DEFAULT_USER: "startcloud",
         	SERVER_DEFAULT_USER_PASS: "STARTcloud24@!",
         	
         	//network
         	NETWORK_ADDRESS: ( internalProvisioner.server.dhcp4.value ) ? "192.168.2.1" : internalProvisioner.server.networkAddress.value,
         	NETWORK_NETMASK: ( internalProvisioner.server.dhcp4.value ) ? "255.255.255.0" : internalProvisioner.server.networkNetmask.value,
         	NETWORK_GATEWAY: ( internalProvisioner.server.dhcp4.value ) ? "" : internalProvisioner.server.networkGateway.value,
            // Always true, never false
         	NETWORK_DHCP4: internalProvisioner.server.dhcp4.value,
         	NETWORK_BRIDGE: internalProvisioner.server.networkBridge.value,
         	
         	//dns
         	NETWORK_DNS_NAMESERVER_1: ( internalProvisioner.server.dhcp4.value ) ? "1.1.1.1" : internalProvisioner.server.nameServer1.value,
         	NETWORK_DNS_NAMESERVER_2: ( internalProvisioner.server.dhcp4.value ) ? "1.0.0.1" : internalProvisioner.server.nameServer2.value,
           
            //vars
            SERVER_ORGANIZATION: internalProvisioner.server.organization.value,
            USER_SAFE_ID: DemoTasks._SAFE_ID_FILE,
            DOMINO_ADMIN_PASSWORD: "password",
            DOMINO_SERVER_CLUSTERMATES: 0,
            CERT_SELFSIGNED: ( internalProvisioner.server.url.hostname + "." + internalProvisioner.server.url.domainName ).toLowerCase() != "demo.startcloud.com",
			
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
            NOMADWEB_HOTFIX_INSTALLER: defaultProvisionerFieldValue,
            NOMADWEB_VERSION_HOTFIX_INSTALL: defaultProvisionerFieldValue,
            NOMADWEB_HOTFIX_INSTALL: defaultProvisionerFieldValue,
            
            //Traveler Variables
            TRAVELER_INSTALLER: defaultProvisionerFieldValue,
            TRAVELER_INSTALLER_VERSION: defaultProvisionerFieldValue,
            TRAVELER_FP_INSTALL: defaultProvisionerFieldValue,
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
            ROLE_JEDI: defaultRoleFieldValue,
            ROLE_OIDC: true,

            ENV_OPEN_BROWSER: false,
            ENV_SETUP_WAIT: internalProvisioner.server.setupWait.value,
        };
    }
}