package superhuman.server.hostsFileGenerator;

import superhuman.server.provisioners.AdditionalProvisioner;
import superhuman.server.provisioners.roles.RolesUtil;
import superhuman.server.provisioners.AbstractProvisioner;
import haxe.Template;
import haxe.io.Path;
import superhuman.server.AdditionalServer;
import superhuman.server.ServerURL;

class AdditionalProvisionerHostsFileGenerator extends StandaloneProvisionerHostsFileGenerator {
    static public function generateContent( sourceTemplate:String, provisioner:AbstractProvisioner ):String {

        var output:String = null;
        var internalProvisioner:AdditionalProvisioner = cast(provisioner, AdditionalProvisioner);
        var internalServer:AdditionalServer = cast(internalProvisioner.server, AdditionalServer);
        
        var defaultProvisionerFieldValue:String = null;
        var defaultRoleFieldValue:Dynamic = false;

        var existingServerUrl:ServerURL = internalServer.getExistingServerUrl();
        var existingDominoOriginHostname:String = existingServerUrl != null ? existingServerUrl.hostname : defaultProvisionerFieldValue;
        var existingDominoOriginDomain:String = existingServerUrl != null ? existingServerUrl.domainName : defaultProvisionerFieldValue;
        var existingDominoOriginServerIp:String = internalServer.existingServerIpAddress != null ? 
                                                  internalServer.existingServerIpAddress.value :
                                                  defaultProvisionerFieldValue;

        var existingDominoServerId:String = defaultProvisionerFieldValue;
            if (internalServer.serverProvisionerId != null) {
                var serverProvisionerName = new Path(internalServer.serverProvisionerId.value);
                existingDominoServerId = serverProvisionerName.file + "." + serverProvisionerName.ext;
            }
                                          
        //additional server

        var replace = StandaloneProvisionerHostsFileGenerator._getDefaultTemplateValues(internalProvisioner, defaultProvisionerFieldValue, defaultRoleFieldValue);
            replace.DOMINO_IS_ADDITIONAL_INSTANCE = true;
            replace.DOMINO_ORIGIN_HOSTNAME = existingDominoOriginHostname;
            replace.DOMINO_ORIGIN_DOMAIN = existingDominoOriginDomain;
            replace.DOMINO_SERVER_ID = existingDominoServerId;
            replace.DOMINO_ORIGIN_SERVER_IP = existingDominoOriginServerIp;
            replace.SERVER_ORGANIZATION = internalServer.getOrganization();

        for ( r in internalProvisioner.server.roles.value ) {

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

                if (r.files.hotfixes != null && r.files.hotfixes.length > 0)
                {
                    var hotfixesPath = new Path(r.files.hotfixes[0]);
                    
                    replace.NOMADWEB_HOTFIX_INSTALL = true;
                    replace.NOMADWEB_HOTFIX_INSTALLER = hotfixesPath.file + "." + hotfixesPath.ext;
                    replace.NOMADWEB_VERSION_HOTFIX_INSTALL = hotfixVersion == null ? defaultProvisionerFieldValue : hotfixVersion.fullVersion;
                }

                replace.ROLE_NOMADWEB = replaceWith;
            }

            if ( r.value == "traveler" ) {

                //"- name: hcl_domino_traveler" : "- name: domino_traveler"
                replaceWith = RolesUtil.getDominoRole(internalProvisioner.data.version, r.value, r.enabled);
            	    
                replace.TRAVELER_INSTALLER = installerName;
                replace.TRAVELER_INSTALLER_VERSION = installerVersion == null ? defaultProvisionerFieldValue : installerVersion.fullVersion;

                if (r.files.fixpacks != null && r.files.fixpacks.length > 0)
                {
                    var fixPacksPath = new Path(r.files.fixpacks[0]);
                    
                    replace.TRAVELER_FP_INSTALL = true;
                    replace.TRAVELER_FP_INSTALLER = fixPacksPath.file + "." + fixPacksPath.ext;
                    replace.TRAVELER_FP_INSTALLER_VERSION = fixpackVersion == null ? defaultProvisionerFieldValue : fixpackVersion.fullVersion;
                }

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
}
