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

package superhuman.server.provisioners;

import champaign.core.logging.Logger;
import genesis.application.managers.LanguageManager;
import haxe.Exception;
import haxe.io.Path;
import prominic.sys.applications.hashicorp.Vagrant;
import prominic.sys.applications.oracle.VirtualBox;
import superhuman.managers.ProvisionerManager;
import superhuman.server.data.ProvisionerData;
import superhuman.server.data.RoleData;
import superhuman.server.data.ServerData;
import superhuman.server.definitions.ProvisionerDefinition;
import sys.FileSystem;
import sys.io.File;
import yaml.Yaml;
import yaml.util.ObjectMap;
import StringTools;

/**
 * CustomProvisioner is a provisioner implementation for custom provisioner types.
 * It extends StandaloneProvisioner and overrides specific methods to handle custom provisioner functionality.
 */
class CustomProvisioner extends StandaloneProvisioner {

    /**
     * Override copyFiles to ensure we use the correct source path for custom provisioners
     * Always using the zip/unzip method for consistent file transfer and long path handling
     */
    override public function copyFiles(?callback:()->Void) {
        if (exists) {
            if (console != null) console.appendText(LanguageManager.getInstance().getString('serverpage.server.console.copyvagrantfiles', _targetPath, "(not required, skipping)"));
            if (callback != null) callback();
            return;
        }

        // Get the correct source path for this custom provisioner
        var sourcePath = "";
        if (_server != null && _server.customProperties != null) {
            if (Reflect.hasField(_server.customProperties, "provisionerDefinition")) {
                var provDef = Reflect.field(_server.customProperties, "provisionerDefinition");
                if (provDef != null && Reflect.hasField(provDef, "root")) {
                    sourcePath = provDef.root;
                    Logger.info('${this}: Using source path from provisioner definition: ${sourcePath}');
                }
            }
        }

        // If we couldn't get the path from customProperties, use the _sourcePath
        if (sourcePath == "") {
            sourcePath = _sourcePath;
            Logger.info('${this}: Using default source path: ${sourcePath}');
        }

        // Create target directory if it doesn't exist
        createTargetDirectory();

        Logger.info('${this}: Copying custom provisioner files to ${_targetPath} using zip/unzip method');
        if (console != null) console.appendText(LanguageManager.getInstance().getString('serverpage.server.console.copyvagrantfiles', _targetPath, ""));
        
        try {
            // First zip the entire source directory to handle potential long paths
            Logger.info('${this}: Zipping source directory: ${sourcePath}');
            var zipBytes = _zipDirectory(sourcePath);
            
            // Then unzip to the target directory
            Logger.info('${this}: Unzipping to target directory: ${_targetPath}');
            _unzipToDirectory(zipBytes, _targetPath);
            
            Logger.info('${this}: Successfully copied files using zip/unzip method');
            if (callback != null) callback();
            
        } catch (e) {
            Logger.error('${this}: Error copying files using zip/unzip: ${e}');
            if (console != null) console.appendText('Error copying provisioner files: ${e}', true);
            
            // Fall back to parent implementation as a last resort
            Logger.info('${this}: Falling back to parent implementation');
            
            // Temporarily store the original _sourcePath
            var originalSource = _sourcePath;
            
            // Set the source path to the correct one
            _sourcePath = sourcePath;
            
            // Call the parent implementation
            super.copyFiles(callback);
            
            // Restore the original source path
            _sourcePath = originalSource;
        }
    }


    /**
     * Get default roles for a custom provisioner from its metadata
     * @return A map of role keys to RoleData objects
     */
    static public function getDefaultProvisionerRoles():Map<String, RoleData> {
        var allProvisioners = ProvisionerManager.getBundledProvisioners();
        
        // Filter to only include custom provisioners (not standard ones)
        var customProvisioners = allProvisioners.filter(p -> 
            p.data.type != ProvisionerType.StandaloneProvisioner &&
            p.data.type != ProvisionerType.AdditionalProvisioner &&
            p.data.type != ProvisionerType.Default
        );
        
        // Check if we found any custom provisioners
        if (customProvisioners == null || customProvisioners.length == 0) {
            Logger.warning('CustomProvisioner.getDefaultProvisionerRoles: No custom provisioners found, using default roles');
            // Fall back to default roles
            return StandaloneProvisioner.getDefaultProvisionerRoles();
        }
        
        // Get the first (newest) custom provisioner
        var provisionerDefinition:ProvisionerDefinition = customProvisioners[0];
        
        // Check if it has metadata with roles
        if (provisionerDefinition.metadata == null || 
            provisionerDefinition.metadata.roles == null ||
            provisionerDefinition.metadata.roles.length == 0) {
            Logger.warning('CustomProvisioner.getDefaultProvisionerRoles: Custom provisioner has no roles in metadata, using default roles');
            // Fall back to default roles
            return StandaloneProvisioner.getDefaultProvisionerRoles();
        }
        
        // Create a map of roles from the metadata
        var roles = new Map<String, RoleData>();
        Logger.info('CustomProvisioner.getDefaultProvisionerRoles: Found ${provisionerDefinition.metadata.roles.length} roles in metadata');
        
        for (roleInfo in provisionerDefinition.metadata.roles) {
            var defaultEnabled = roleInfo.defaultEnabled == true;
            
            // Create role data
            var roleData:RoleData = {
                value: roleInfo.name,
                enabled: defaultEnabled,
                files: {
                    installer: null,
                    installerFileName: null,
                    installerHash: null,
                    installerVersion: null,
                    hotfixes: [],
                    installerHotFixHash: null,
                    installerHotFixVersion: null,
                    fixpacks: [],
                    installerFixpackHash: null,
                    installerFixpackVersion: null
                }
            };
            
            roles.set(roleInfo.name, roleData);
            Logger.info('CustomProvisioner.getDefaultProvisionerRoles: Added role ${roleInfo.name}, enabled=${defaultEnabled}');
        }
        
        return roles;
    }
    
    /**
     * Get default server data for a custom provisioner
     * @param id The server ID
     * @return The default server data
     */
    static public function getDefaultServerData(id:Int):ServerData {
        
        // Get the available provisioners of type Custom
        var customProvisioners = ProvisionerManager.getBundledProvisioners(ProvisionerType.Custom);
        
        // Get roles from custom provisioner
        var roleMap = getDefaultProvisionerRoles();
        var roles:Array<RoleData> = [for (r in roleMap.keyValueIterator()) r.value];
        
        // Check if we have any custom provisioners available
        if (customProvisioners != null && customProvisioners.length > 0) {
            var firstProvisioner = customProvisioners[0];
            
            return {
                env_open_browser: true,
                env_setup_wait: 300,

                dhcp4: true,
                network_address: "",
                network_dns_nameserver_1: "1.1.1.1",
                network_dns_nameserver_2: "1.0.0.1",
                network_gateway: "",
                network_netmask: "",

                network_bridge: "",
                resources_cpu: 2,
                resources_ram: 8.0,
                roles: roles,
                server_hostname: "",
                server_id: id,
                server_organization: "",
                type: ServerType.Domino,
                user_email: "",
                provisioner: firstProvisioner.data,
                syncMethod: SyncMethod.Rsync,
                existingServerName: "",
                existingServerIpAddress: ""
            };
        } else {
            // Fall back to default behavior if no custom provisioners are available
            Logger.warning('CustomProvisioner.getDefaultServerData: No custom provisioners found, using default provisioner');
            return {
                env_open_browser: true,
                env_setup_wait: 300,

                dhcp4: true,
                network_address: "",
                network_dns_nameserver_1: "1.1.1.1",
                network_dns_nameserver_2: "1.0.0.1",
                network_gateway: "",
                network_netmask: "",

                network_bridge: "",
                resources_cpu: 2,
                resources_ram: 8.0,
                roles: [for (r in StandaloneProvisioner.getDefaultProvisionerRoles().keyValueIterator()) r.value],
                server_hostname: "",
                server_id: id,
                server_organization: "",
                type: ServerType.Domino,
                user_email: "",
                provisioner: ProvisionerManager.getBundledProvisioners(ProvisionerType.Custom)[0].data,
                syncMethod: SyncMethod.Rsync,
                existingServerName: "",
                existingServerIpAddress: ""
            };
        }
    }

    /**
     * Generate a random server ID
     * @param serverDirectory The server directory
     * @return A random server ID
     */
    static public function getRandomServerId(serverDirectory:String):Int {
        // Range: 1025 - 9999
        var r = Math.floor(Math.random() * 8974) + 1025;

        if (FileSystem.exists('${serverDirectory}${ProvisionerType.Custom}/${r}')) return getRandomServerId(serverDirectory);

        return r;
    }

/**
 * Initialize the server's custom properties with metadata from the provisioner
 * This ensures the dynamic pages can access the configuration
 */
private function _initializeServerMetadata() {
    if (_server == null || _server.customProperties == null) {
        return;
    }
    
    // Get the provisioner definition for this server
    var provisionerDefinition = null;
    
    // Check both userData and customProperties for the provisioner definition
    if (_server.userData != null && Reflect.hasField(_server.userData, "provisionerDefinition")) {
        provisionerDefinition = Reflect.field(_server.userData, "provisionerDefinition");
        Logger.info('${this}: Found provisioner definition in server userData');
        
        // Copy from userData to customProperties to ensure consistency
        Reflect.setField(_server.customProperties, "provisionerDefinition", provisionerDefinition);
    } else if (Reflect.hasField(_server.customProperties, "provisionerDefinition")) {
        provisionerDefinition = Reflect.field(_server.customProperties, "provisionerDefinition");
        Logger.info('${this}: Found provisioner definition in server customProperties');
    }
    
    // Create dynamicCustomProperties if it doesn't exist
    if (!Reflect.hasField(_server.customProperties, "dynamicCustomProperties")) {
        Reflect.setField(_server.customProperties, "dynamicCustomProperties", {});
        Logger.info('${this}: Created dynamicCustomProperties container');
    }
    
    // Ensure we don't add any duplicate metadata fields - they can be referenced directly
    // from the provisioner definition when needed
    Logger.info('${this}: Using provisionerDefinition as the single source of truth for metadata');
}

/**
 * Override data includes the correct version and type
 * Using serverProvisionerId as the single authoritative source for version information
 * Ensures consistent type handling by preserving the original type
 * @return ProvisionerData with the correct version
 */
override public function get_data():ProvisionerData {
    // Initialize server metadata if needed
    _initializeServerMetadata();
    
    // Create a baseline data object
    var baseData = super.get_data();
    Logger.info('${this}: Getting data with base type: ${baseData.type}');
    
    // Use consistent type comparison
    var isStandalone = (Std.string(baseData.type) == Std.string(ProvisionerType.StandaloneProvisioner));
    var isAdditional = (Std.string(baseData.type) == Std.string(ProvisionerType.AdditionalProvisioner));
    var isDefault = (Std.string(baseData.type) == Std.string(ProvisionerType.Default));
    
    // Keep track of original type to ensure it's preserved
    var originalType = baseData.type;
    
    // First priority: Use serverProvisionerId as the authoritative source for version
    if (_server != null && _server.serverProvisionerId != null && 
        _server.serverProvisionerId.value != null && 
        _server.serverProvisionerId.value != "" && 
        _server.serverProvisionerId.value != "0.0.0") {
        
        var versionStr = _server.serverProvisionerId.value;
        Logger.info('${this}: Using serverProvisionerId for version: ${versionStr}');

        return { 
            type: originalType,
            version: champaign.core.primitives.VersionInfo.fromString(versionStr)
        };
    }
    
    // Second priority: Check customProperties for stored provisionerDefinition
    if (_server != null && _server.customProperties != null) {
        if (Reflect.hasField(_server.customProperties, "provisionerDefinition")) {
            var provDef = Reflect.field(_server.customProperties, "provisionerDefinition");
            if (provDef != null && Reflect.hasField(provDef, "data")) {
                if (Reflect.hasField(provDef.data, "version")) {
                    var versionInfo = Reflect.field(provDef.data, "version");
                    Logger.info('${this}: Using provisionerDefinition for version: ${versionInfo}');
                    
                    // Preserve the original type to ensure consistency
                    return {
                        type: originalType,
                        version: versionInfo
                    };
                }
                
                if (Reflect.hasField(provDef.data, "type")) {
                    // Only log the type information for debugging
                    var typeInfo = Reflect.field(provDef.data, "type");
                    Logger.info('${this}: Found provisionerDefinition type: ${typeInfo}, using original type: ${originalType}');
                }
            }
        }
    }
    
    // Fallback to the base version while preserving the original type
    Logger.error('${this}: Using fallback with original type: ${originalType}');
    return {
        type: originalType,
        version: baseData.version
    };
}

/**
 * Generate the Hosts.yml file content
 * @return The generated Hosts.yml content
 */
override public function generateHostsFileContent():String {
        // Try to get the template content from several potential locations
        var templatePath = Path.addTrailingSlash(_sourcePath) + "templates/" + StandaloneProvisioner.HOSTS_TEMPLATE_FILE;
        
        // First try to get the template from the normal source template directory method
        _hostsTemplate = getFileContentFromSourceTemplateDirectory(StandaloneProvisioner.HOSTS_TEMPLATE_FILE);
        
        // Log template status
        if (_hostsTemplate == null || _hostsTemplate.length == 0) {
            Logger.warning('${this}: Template not found using standard method, will try alternative location');
            
            // Try to fall back to the standalone provisioner template
            if (_hostsTemplate == null || _hostsTemplate.length == 0) {
                // Get the latest standalone provisioner definition
                var standaloneProvisioners = ProvisionerManager.getBundledProvisioners(ProvisionerType.StandaloneProvisioner);
                if (standaloneProvisioners != null && standaloneProvisioners.length > 0) {
                    var latestStandaloneProvisioner = standaloneProvisioners[0];
                    var standalonePath = Path.addTrailingSlash(latestStandaloneProvisioner.root) + "templates/" + StandaloneProvisioner.HOSTS_TEMPLATE_FILE;
                    
                    if (FileSystem.exists(standalonePath)) {
                        try {
                            _hostsTemplate = File.getContent(standalonePath);
                        } catch (e) {
                            Logger.error('${this}: Error reading fallback template at ${standalonePath}: ${e}');
                        }
                    }
                }
            }
        }
        
        // Log the final template state
        if (_hostsTemplate == null || _hostsTemplate.length == 0) {
            Logger.error('${this}: Could not find any valid template for Hosts.yml');
            if (console != null) {
                console.appendText(LanguageManager.getInstance().getString('serverpage.server.console.error', 'Could not find template for Hosts.yml'), true);
            }
            
            // Return a basic template as last resort
            return "hosts:\n  - name: \"::SERVER_HOSTNAME::.::SERVER_ORGANIZATION::.com\"\n    settings:\n      description: \"Custom provisioner host\"\n      ram: ::SERVER_MEMORY::\n      cpus: ::SERVER_CPUS::\n      dhcp4: ::SERVER_DHCP::\n";
        }
        
        // Create a simple hosts file generator for custom provisioners
        // This is a simplified version that just does basic variable substitution
        var content = _hostsTemplate;
        
        // Initialize variables for ALL roles from the provisioner definition
        if (_server != null && _server.customProperties != null && 
            Reflect.hasField(_server.customProperties, "provisionerDefinition")) {
            
            var provDef = Reflect.field(_server.customProperties, "provisionerDefinition");
            if (provDef != null && Reflect.hasField(provDef, "metadata") && 
                Reflect.hasField(provDef.metadata, "roles")) {
                
                var rolesList:Dynamic = Reflect.field(provDef.metadata, "roles");
                if (rolesList != null) {
                    // Cast the dynamic rolesList to Array<Dynamic> or iterate using indices
                    var rolesArray:Array<Dynamic> = cast(rolesList, Array<Dynamic>);
                    Logger.info('${this}: Initializing variables for ${rolesArray.length} roles from provisioner metadata');
                    
                    for (i in 0...rolesArray.length) {
                        var roleInfo = rolesArray[i];
                        if (roleInfo != null && Reflect.hasField(roleInfo, "name")) {
                            var roleName = Reflect.field(roleInfo, "name");
                            var roleUpper = roleName.toUpperCase();
                            roleUpper = StringTools.replace(roleUpper, "-", "_");
                            
                            // Initialize all standard variables for this role
                            content = _initializeStandardVariables(content, roleUpper);
                            
                            // Set role enablement to false by default
                            content = _replaceVariable(content, roleName, "false");
                            
                            Logger.verbose('${this}: Initialized variables for role ${roleName}');
                        }
                    }
                }
            }
        }
     
        // Extract just the hostname part (before the first dot)
        var fullHostname = _server.hostname.value;
        var hostnameOnly = fullHostname;
        var dotIndex = fullHostname.indexOf(".");
        if (dotIndex > 0) {
            hostnameOnly = fullHostname.substring(0, dotIndex);
        }
        
        // Replace variables with server values
        content = _replaceVariable(content, "SERVER_HOSTNAME", hostnameOnly);
        content = _replaceVariable(content, "SERVER_DOMAIN", _server.url.domainName);
        content = _replaceVariable(content, "SERVER_ORGANIZATION", _server.organization.value);
        content = _replaceVariable(content, "SERVER_ID", Std.string(_server.id));
        content = _replaceVariable(content, "RESOURCES_RAM", Std.string(_server.memory.value) + "G");
        content = _replaceVariable(content, "SERVER_MEMORY", Std.string(_server.memory.value));
        content = _replaceVariable(content, "RESOURCES_CPU", Std.string(_server.numCPUs.value));
        content = _replaceVariable(content, "SERVER_CPUS", Std.string(_server.numCPUs.value));
        content = _replaceVariable(content, "NETWORK_DHCP4", _server.dhcp4.value ? "true" : "false");
        content = _replaceVariable(content, "SERVER_DHCP", _server.dhcp4.value ? "true" : "false");
        
        // Network settings
        if (!_server.dhcp4.value) {
            content = _replaceVariable(content, "NETWORK_ADDRESS", _server.networkAddress.value);
            content = _replaceVariable(content, "NETWORK_GATEWAY", _server.networkGateway.value);
            content = _replaceVariable(content, "NETWORK_DNS_NAMESERVER_1", _server.nameServer1.value);
            content = _replaceVariable(content, "NETWORK_DNS1", _server.nameServer1.value);
            content = _replaceVariable(content, "NETWORK_DNS_NAMESERVER_2", _server.nameServer2.value);
            content = _replaceVariable(content, "NETWORK_DNS2", _server.nameServer2.value);
        } else {
            // Provide default values for DHCP mode
            content = _replaceVariable(content, "NETWORK_ADDRESS", "192.168.2.1");
            content = _replaceVariable(content, "NETWORK_NETMASK", "255.255.255.0");
            content = _replaceVariable(content, "NETWORK_GATEWAY", "");
            content = _replaceVariable(content, "NETWORK_DNS_NAMESERVER_1", "1.1.1.1");
            content = _replaceVariable(content, "NETWORK_DNS1", "1.1.1.1");
            content = _replaceVariable(content, "NETWORK_DNS_NAMESERVER_2", "1.0.0.1");
            content = _replaceVariable(content, "NETWORK_DNS2", "1.0.0.1");
        }
        
        // Bridge adapter
        content = _replaceVariable(content, "NETWORK_BRIDGE", _server.networkBridge.value);
        content = _replaceVariable(content, "DISABLE_BRIDGE_ADAPTER", _server.disableBridgeAdapter.value ? "true" : "false");
        
        // User settings
        content = _replaceVariable(content, "USER_EMAIL", _server.userEmail.value);
        
        // Server default settings
        content = _replaceVariable(content, "SERVER_DEFAULT_USER", "startcloud");
        content = _replaceVariable(content, "SERVER_DEFAULT_USER_PASS", "STARTcloud24@!");
        content = _replaceVariable(content, "BOX_URL", "https://boxvault.startcloud.com");
        content = _replaceVariable(content, "SHOW_CONSOLE", "false");
        content = _replaceVariable(content, "POST_PROVISION", "true");
        content = _replaceVariable(content, "ENV_SETUP_WAIT", Std.string(_server.setupWait.value));
        content = _replaceVariable(content, "SYNC_METHOD", Std.string(_server.syncMethod));
        
        // Process all roles with their exact names - no prefixes
        for (role in _server.roles.value) {
            var roleValue = role.enabled ? "true" : "false";
            var roleName = role.value;
            
            // Set the basic role enablement variable
            content = _replaceVariable(content, roleName, roleValue);
            
            // Set standard variables for all roles
            var roleUpper = roleName.toUpperCase();
            
            // Handle role name that contains hyphens
            roleUpper = StringTools.replace(roleUpper, "-", "_");
            
            // Initialize all standard variables with default values
            content = _initializeStandardVariables(content, roleUpper);
            
            // Process installer file information for standard roles
            if (role.files != null) {
                // Main installer
                if (role.files.installer != null) {
                    var installerFileName = role.files.installerFileName;
                    var installerHash = role.files.installerHash;
                    var installerVersion = role.files.installerVersion;
                    
                    // Override with actual values if they exist
                    // Main installer
                    if (installerFileName != null) {
                        content = _replaceVariable(content, roleUpper + "_INSTALLER", installerFileName);
                    }
                    
                    if (installerHash != null) {
                        content = _replaceVariable(content, roleUpper + "_HASH", installerHash);
                    }
                    
                    if (installerVersion != null) {
                        var fullVersion = null;
                        if (Reflect.hasField(installerVersion, "fullVersion"))
                            fullVersion = Reflect.field(installerVersion, "fullVersion");
                        
                        if (fullVersion != null) {
                            content = _replaceVariable(content, roleUpper + "_INSTALLER_VERSION", fullVersion);
                            
                            // Special handling for domino version fields
                            if (roleName == "domino") {
                                var majorVersion = null;
                                var minorVersion = null;
                                var patchVersion = null;
                                
                                if (Reflect.hasField(installerVersion, "majorVersion"))
                                    majorVersion = Reflect.field(installerVersion, "majorVersion");
                                if (Reflect.hasField(installerVersion, "minorVersion"))
                                    minorVersion = Reflect.field(installerVersion, "minorVersion");
                                if (Reflect.hasField(installerVersion, "patchVersion"))
                                    patchVersion = Reflect.field(installerVersion, "patchVersion");
                                
                                if (majorVersion != null) {
                                    content = _replaceVariable(content, "DOMINO_INSTALLER_MAJOR_VERSION", majorVersion);
                                    content = _replaceVariable(content, "DOMINO_MAJOR_VERSION", majorVersion);
                                }
                                
                                if (minorVersion != null) {
                                    content = _replaceVariable(content, "DOMINO_INSTALLER_MINOR_VERSION", minorVersion);
                                    content = _replaceVariable(content, "DOMINO_MINOR_VERSION", minorVersion);
                                }
                                
                                if (patchVersion != null) {
                                    content = _replaceVariable(content, "DOMINO_INSTALLER_PATCH_VERSION", patchVersion);
                                    content = _replaceVariable(content, "DOMINO_PATCH_VERSION", patchVersion);
                                }
                            }
                        }
                    }
                }
                
                // Process hotfixes using standardized variables
                if (role.files.hotfixes != null && role.files.hotfixes.length > 0) {
                    var hotfixPath = new Path(role.files.hotfixes[0]);
                    var hotfixFileName = hotfixPath.file + "." + hotfixPath.ext;
                    var roleUpper = roleName.toUpperCase();
                    roleUpper = StringTools.replace(roleUpper, "-", "_");
                    
                    // Set standard hotfix variables
                    content = _replaceVariable(content, roleUpper + "_HF_INSTALL", "true");
                    content = _replaceVariable(content, roleUpper + "_HF_INSTALLER", hotfixFileName);
                    
                    if (role.files.installerHotFixVersion != null) {
                        var fullVersion = null;
                        if (Reflect.hasField(role.files.installerHotFixVersion, "fullVersion"))
                            fullVersion = Reflect.field(role.files.installerHotFixVersion, "fullVersion");
                        
                        if (fullVersion != null) {
                            content = _replaceVariable(content, roleUpper + "_HF_INSTALLER_VERSION", fullVersion);
                        }
                    }
                    
                    if (role.files.installerHotFixHash != null) {
                        content = _replaceVariable(content, roleUpper + "_HF_HASH", role.files.installerHotFixHash);
                    }
                }
                
                // Process fixpacks using standardized variables
                if (role.files.fixpacks != null && role.files.fixpacks.length > 0) {
                    var fixpackPath = new Path(role.files.fixpacks[0]);
                    var fixpackFileName = fixpackPath.file + "." + fixpackPath.ext;
                    var roleUpper = roleName.toUpperCase();
                    roleUpper = StringTools.replace(roleUpper, "-", "_");
                    
                    // Set standard fixpack variables
                    content = _replaceVariable(content, roleUpper + "_FP_INSTALL", "true");
                    content = _replaceVariable(content, roleUpper + "_FP_INSTALLER", fixpackFileName);
                    
                    if (role.files.installerFixpackVersion != null) {
                        var fullVersion = null;
                        if (Reflect.hasField(role.files.installerFixpackVersion, "fullVersion"))
                            fullVersion = Reflect.field(role.files.installerFixpackVersion, "fullVersion");
                        
                        if (fullVersion != null) {
                            content = _replaceVariable(content, roleUpper + "_FP_INSTALLER_VERSION", fullVersion);
                        }
                    }
                    
                    if (role.files.installerFixpackHash != null) {
                        content = _replaceVariable(content, roleUpper + "_FP_HASH", role.files.installerFixpackHash);
                    }
                    

                }
            }
        }

        // Add custom properties if available
        if (_server.customProperties != null) {
            // Helper function to convert a value to string safely
            function safeToString(value:Dynamic):String {
                if (value == null) return "";
                return switch(Type.typeof(value)) {
                    case TBool: value ? "true" : "false";
                    case TFloat: Std.string(value);
                    case TInt: Std.string(value);
                    case TClass(String): value;
                    case _: try { Std.string(value); } catch(e) { ""; }
                }
            }
            
            // Prepare a map of all custom properties for template variable substitution
            var allCustomProps = new Map<String, String>();

            
            // Get default field values from the provisioner definition if available
            if (Reflect.hasField(_server.customProperties, "provisionerDefinition")) {
                var provDef = Reflect.field(_server.customProperties, "provisionerDefinition");
                if (provDef != null && Reflect.hasField(provDef, "metadata") && 
                    Reflect.hasField(provDef.metadata, "configuration")) {
                    
                    var config = provDef.metadata.configuration;
                    
                    // Extract default values from basic fields
                    if (Reflect.hasField(config, "basicFields")) {
                        var fields = Reflect.field(config, "basicFields");
                        if (fields != null) {
                            for (i in 0...fields.length) {
                                var field = fields[i];
                                if (field != null && Reflect.hasField(field, "name")) {
                                    var fieldName = Reflect.field(field, "name");
                                    var defaultValue = "";
                                    if (Reflect.hasField(field, "defaultValue") && 
                                        Reflect.field(field, "defaultValue") != null) {
                                        defaultValue = safeToString(Reflect.field(field, "defaultValue"));
                                    }
                                    allCustomProps.set(fieldName, defaultValue);
                                }
                            }
                        }
                    }
                    
                    // Extract default values from advanced fields
                    if (Reflect.hasField(config, "advancedFields")) {
                        var fields = Reflect.field(config, "advancedFields");
                        if (fields != null) {
                            for (i in 0...fields.length) {
                                var field = fields[i];
                                if (field != null && Reflect.hasField(field, "name")) {
                                    var fieldName = Reflect.field(field, "name");
                                    var defaultValue = "";
                                    if (Reflect.hasField(field, "defaultValue") && 
                                        Reflect.field(field, "defaultValue") != null) {
                                        defaultValue = safeToString(Reflect.field(field, "defaultValue"));
                                    }
                                    allCustomProps.set(fieldName, defaultValue);
                                }
                            }
                        }
                    }
                }
            }
            
            // Now prioritize values from dynamicCustomProperties (highest priority)
            if (Reflect.hasField(_server.customProperties, "dynamicCustomProperties")) {
                var props = Reflect.field(_server.customProperties, "dynamicCustomProperties");
                if (props != null) {
                    
                    for (field in Reflect.fields(props)) {
                        // Skip internal fields
                        if (field == "provisionerDefinition" || field == "serviceTypeData") continue;
                        
                        var value = Reflect.field(props, field);
                        if (value != null) {
                            allCustomProps.set(field, safeToString(value));
                        }
                    }
                }
            }
            
            // Then check dynamicAdvancedCustomProperties (also high priority)
            if (Reflect.hasField(_server.customProperties, "dynamicAdvancedCustomProperties")) {
                var props = Reflect.field(_server.customProperties, "dynamicAdvancedCustomProperties");
                if (props != null) {
                    
                    for (field in Reflect.fields(props)) {
                        // Skip internal fields
                        if (field == "provisionerDefinition" || field == "serviceTypeData") continue;
                        
                        var value = Reflect.field(props, field);
                        if (value != null) {
                            allCustomProps.set(field, safeToString(value));
                        }
                    }
                }
            }
            
            // Replace all variables in the template
            for (field => value in allCustomProps) {
                content = _replaceVariable(content, field, value);
            }
        } else {
            Logger.warning('${this}: No customProperties available on server');
        }
        
        return content;
    }
    
/**
 * Override saveSafeId to prevent copying SafeID for custom provisioners
 * @param safeid The path to the SafeID file
 * @return Always returns true for custom provisioners
 */
override public function saveSafeId(safeid:String):Bool {
    return true;
}

/**
 * Override hostFileExists to ensure the initial check for host file existence works properly
 * This method is called in Server._batchCopyComplete() to determine if the file needs to be created
 */
override public function get_hostFileExists():Bool {
    var exists = this.fileExists(StandaloneProvisioner.HOSTS_FILE);
    return exists;
}

/**
 * Override the saveHostsFile method to ensure it gets called for custom provisioners
 * This method validates the server before saving and logs detailed validation results
 */
override public function saveHostsFile() {
    // Create target directory and ensure it exists regardless of validation
    createTargetDirectory();

    // Log the custom properties state to help with debugging
    if (_server != null && _server.customProperties != null) {
        
        if (Reflect.hasField(_server.customProperties, "dynamicCustomProperties")) {
            var basicFields = Reflect.field(_server.customProperties, "dynamicCustomProperties");
            if (basicFields == null) {
                Logger.warning('${this}: dynamicCustomProperties is null');
            }
        }
        
        if (Reflect.hasField(_server.customProperties, "dynamicAdvancedCustomProperties")) {
            var advancedFields = Reflect.field(_server.customProperties, "dynamicAdvancedCustomProperties");
            if (advancedFields == null) {
                Logger.warning('${this}: dynamicAdvancedCustomProperties is null');
            }
        }
    } else {
        Logger.warning('${this}: Server has no customProperties');
    }

    // Generate the content for Hosts.yml file
    var content = generateHostsFileContent();

    if (console != null) console.appendText(LanguageManager.getInstance().getString('serverpage.server.console.hostsfilecontent', content));

    try {
        // Save the content to the file
        var hostsFilePath = Path.addTrailingSlash(_targetPath) + StandaloneProvisioner.HOSTS_FILE;
        File.saveContent(hostsFilePath, content);
        
        if (console != null) console.appendText(LanguageManager.getInstance().getString('serverpage.server.console.savehostsfile', hostsFilePath));
        
        // Update server status after saving hosts file
        if (_server != null) {
            _server.setServerStatus();
            
            // Make sure to save the server data to persist any changes to customProperties
            _server.saveData();
        }
    } catch (e:Exception) {
        Logger.error('${this}: Custom provisioner could not create Hosts.yml file. Details: ${e.details()} Message: ${e.message}');
        if (console != null) console.appendText(LanguageManager.getInstance().getString('serverpage.server.console.savehostsfileerror', Path.addTrailingSlash(_targetPath) + StandaloneProvisioner.HOSTS_FILE, '${e.details()} Message: ${e.message}'), true);
    }
}

    /**
     * Initialize standard variables for a role using the standardized naming pattern
     * This ensures all roles have consistent default values for all potential variables
     * @param content The template content to operate on 
     * @param roleUpper The uppercase role name (with hyphens converted to underscores)
     * @return The content with variables initialized
     */
    private function _initializeStandardVariables(content:String, roleUpper:String):String {
        var result = content;
        
        // Main installer variables
        result = _replaceVariable(result, roleUpper + "_INSTALLER", "");
        result = _replaceVariable(result, roleUpper + "_HASH", "");
        result = _replaceVariable(result, roleUpper + "_INSTALLER_VERSION", "");
        
        // Fixpack variables
        result = _replaceVariable(result, roleUpper + "_FP_INSTALL", "false");
        result = _replaceVariable(result, roleUpper + "_FP_INSTALLER", "");
        result = _replaceVariable(result, roleUpper + "_FP_INSTALLER_VERSION", "");
        result = _replaceVariable(result, roleUpper + "_FP_HASH", "");
        
        // Hotfix variables
        result = _replaceVariable(result, roleUpper + "_HF_INSTALL", "false");
        result = _replaceVariable(result, roleUpper + "_HF_INSTALLER", "");
        result = _replaceVariable(result, roleUpper + "_HF_INSTALLER_VERSION", "");
        result = _replaceVariable(result, roleUpper + "_HF_HASH", "");
        
        
        return result;
    }

    /**
     * Helper method to replace variables in the template using the ::VARIABLENAME:: format
     * Also attempts common variations of the variable name for better compatibility
     * @param content The template content
     * @param name The variable name
     * @param value The replacement value
     * @return String The content with replaced variables
     */
    private function _replaceVariable(content:String, name:String, value:String):String {
        // Ensure value is never null - use empty string if null
        if (value == null) value = "";
        
        var originalName = name;
        var result = content;
        var replaced = false;
        
        // Create an array of case variations to try
        var variations = [
            name,               // Original case
            name.toUpperCase(), // Uppercase
            name.toLowerCase()  // Lowercase
        ];
        
        // Try each variation
        for (variation in variations) {
            var pattern = "::" + variation + "::";
            var before = result;
            
            // Use StringTools.replace to replace all occurrences
            result = StringTools.replace(result, pattern, value);
            
            // Check if any replacements were made
            if (before != result) {
                replaced = true;
            }
        }
        
        // Log if no replacements were made
        if (!replaced) {
            Logger.verbose('${this}: Variable ${name} not found in template with any case variation');
        }
        
        return result;
    }
    
    /**
     * Get the string representation of the provisioner
     * @return The string representation
     */
    override public function toString():String {
        return '[CustomProvisioner(${this._type} v${this.version})]';
    }
}
