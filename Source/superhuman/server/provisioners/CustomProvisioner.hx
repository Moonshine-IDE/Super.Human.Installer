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
 * Ensure data includes the correct version
 * Using serverProvisionerId as the single authoritative source for version information
 * @return ProvisionerData with the correct version
 */
override public function get_data():ProvisionerData {
    // Create a baseline data object
    var baseData = super.get_data();
    
    // First priority: Use serverProvisionerId as the authoritative source
    if (_server != null && _server.serverProvisionerId != null && 
        _server.serverProvisionerId.value != null && 
        _server.serverProvisionerId.value != "" && 
        _server.serverProvisionerId.value != "0.0.0") {
        
        var versionStr = _server.serverProvisionerId.value;

        return { 
            type: baseData.type,
            version: champaign.core.primitives.VersionInfo.fromString(versionStr)
        };
    }
    
    // Second priority: Check customProperties for stored provisionerDefinition
    if (_server != null && _server.customProperties != null) {
        if (Reflect.hasField(_server.customProperties, "provisionerDefinition")) {
            var provDef = Reflect.field(_server.customProperties, "provisionerDefinition");
            if (provDef != null && Reflect.hasField(provDef, "data") && 
                Reflect.hasField(provDef.data, "version")) {
                
                var versionInfo = Reflect.field(provDef.data, "version");
                return {
                    type: baseData.type,
                    version: versionInfo
                };
            }
        }
    }
    
    // Fallback to the base version
    return baseData;
}

/**
 * Generate the Hosts.yml file content
 * @return The generated Hosts.yml content
 */
override public function generateHostsFileContent():String {
        // Try to get the template content from several potential locations
        var templatePath = Path.addTrailingSlash(_sourcePath) + "templates/" + StandaloneProvisioner.HOSTS_TEMPLATE_FILE;
        Logger.info('${this}: Looking for hosts template at: ${templatePath}');
        
        // First try to get the template from the normal source template directory method
        _hostsTemplate = getFileContentFromSourceTemplateDirectory(StandaloneProvisioner.HOSTS_TEMPLATE_FILE);
        
        // Log template status
        if (_hostsTemplate == null || _hostsTemplate.length == 0) {
            Logger.warning('${this}: Template not found using standard method, will try alternative locations');
            
            // Try to look in the scripts directory
            var scriptsTemplatePath = Path.addTrailingSlash(_sourcePath) + "scripts/templates/" + StandaloneProvisioner.HOSTS_TEMPLATE_FILE;
            Logger.info('${this}: Trying to find template at: ${scriptsTemplatePath}');
            
            if (FileSystem.exists(scriptsTemplatePath)) {
                try {
                    _hostsTemplate = File.getContent(scriptsTemplatePath);
                    Logger.info('${this}: Found template at: ${scriptsTemplatePath}');
                } catch (e) {
                    Logger.error('${this}: Error reading template at ${scriptsTemplatePath}: ${e}');
                }
            }
            
            // If still no template, try to fall back to the standalone provisioner template
            if (_hostsTemplate == null || _hostsTemplate.length == 0) {
                // Get the latest standalone provisioner definition
                var standaloneProvisioners = ProvisionerManager.getBundledProvisioners(ProvisionerType.StandaloneProvisioner);
                if (standaloneProvisioners != null && standaloneProvisioners.length > 0) {
                    var latestStandaloneProvisioner = standaloneProvisioners[0];
                    var standalonePath = Path.addTrailingSlash(latestStandaloneProvisioner.root) + "templates/" + StandaloneProvisioner.HOSTS_TEMPLATE_FILE;
                    Logger.info('${this}: Trying to use fallback template from standalone provisioner: ${standalonePath}');
                    
                    if (FileSystem.exists(standalonePath)) {
                        try {
                            _hostsTemplate = File.getContent(standalonePath);
                            Logger.info('${this}: Using fallback template from: ${standalonePath}');
                        } catch (e) {
                            Logger.error('${this}: Error reading fallback template at ${standalonePath}: ${e}');
                        }
                    }
                }
            }
        } else {
            Logger.info('${this}: Successfully loaded template with standard method');
        }
        
        // Log the final template state
        if (_hostsTemplate == null || _hostsTemplate.length == 0) {
            Logger.error('${this}: Could not find any valid template for Hosts.yml');
            if (console != null) {
                console.appendText(LanguageManager.getInstance().getString('serverpage.server.console.error', 'Could not find template for Hosts.yml'), true);
            }
            
            // Return a basic template as last resort
            return "hosts:\n  - name: \"{{SERVER_HOSTNAME}}.{{SERVER_ORGANIZATION}}.com\"\n    settings:\n      description: \"Custom provisioner host\"\n      ram: {{SERVER_MEMORY}}\n      cpus: {{SERVER_CPUS}}\n      dhcp4: {{SERVER_DHCP}}\n";
        }
        
        // Create a simple hosts file generator for custom provisioners
        // This is a simplified version that just does basic variable substitution
        var content = _hostsTemplate;
        
        // Replace variables with server values
        content = StringTools.replace(content, "{{SERVER_HOSTNAME}}", _server.hostname.value);
        content = StringTools.replace(content, "{{SERVER_ORGANIZATION}}", _server.organization.value);
        content = StringTools.replace(content, "{{SERVER_ID}}", Std.string(_server.id));
        content = StringTools.replace(content, "{{SERVER_MEMORY}}", Std.string(_server.memory.value));
        content = StringTools.replace(content, "{{SERVER_CPUS}}", Std.string(_server.numCPUs.value));
        content = StringTools.replace(content, "{{SERVER_DHCP}}", _server.dhcp4.value ? "true" : "false");
        
        // Network settings
        if (!_server.dhcp4.value) {
            content = StringTools.replace(content, "{{NETWORK_ADDRESS}}", _server.networkAddress.value);
            content = StringTools.replace(content, "{{NETWORK_NETMASK}}", _server.networkNetmask.value);
            content = StringTools.replace(content, "{{NETWORK_GATEWAY}}", _server.networkGateway.value);
            content = StringTools.replace(content, "{{NETWORK_DNS1}}", _server.nameServer1.value);
            content = StringTools.replace(content, "{{NETWORK_DNS2}}", _server.nameServer2.value);
        }
        
        // Bridge adapter
        content = StringTools.replace(content, "{{NETWORK_BRIDGE}}", _server.networkBridge.value);
        content = StringTools.replace(content, "{{DISABLE_BRIDGE_ADAPTER}}", _server.disableBridgeAdapter.value ? "true" : "false");
        
        // User settings
        content = StringTools.replace(content, "{{USER_EMAIL}}", _server.userEmail.value);
        
        // Add custom properties if available
        if (_server.customProperties != null) {
            var customProps = _server.customProperties;
            if (Reflect.hasField(customProps, "dynamicCustomProperties")) {
                var dynamicProps = Reflect.field(customProps, "dynamicCustomProperties");
                var fields = Reflect.fields(dynamicProps);
                for (field in fields) {
                    var value = Reflect.field(dynamicProps, field);
                    content = StringTools.replace(content, "{{" + field.toUpperCase() + "}}", Std.string(value));
                }
            }
            
            if (Reflect.hasField(customProps, "dynamicAdvancedCustomProperties")) {
                var advancedProps = Reflect.field(customProps, "dynamicAdvancedCustomProperties");
                var fields = Reflect.fields(advancedProps);
                for (field in fields) {
                    var value = Reflect.field(advancedProps, field);
                    content = StringTools.replace(content, "{{" + field.toUpperCase() + "}}", Std.string(value));
                }
            }
        }
        
        return content;
    }
    
/**
 * Override hostFileExists to ensure the initial check for host file existence works properly
 * This method is called in Server._batchCopyComplete() to determine if the file needs to be created
 */
override public function get_hostFileExists():Bool {
    var exists = this.fileExists(StandaloneProvisioner.HOSTS_FILE);
    Logger.info('${this}: Checking if Hosts.yml exists: ${exists} at path ${Path.addTrailingSlash(_targetPath) + StandaloneProvisioner.HOSTS_FILE}');
    return exists;
}

/**
 * Override the saveHostsFile method to ensure it gets called for custom provisioners
 * This method validates the server before saving and logs detailed validation results
 */
override public function saveHostsFile() {
    Logger.info('${this}: Saving Hosts.yml file for custom provisioner');
    
    // Check if the server is valid, but log details even if it's not
    var isValid = _server.isValid();
    Logger.info('${this}: Server validation result: ${isValid}');
    
    // Log detailed validation info for debugging
    var hasVagrant = Vagrant.getInstance().exists;
    var hasVirtualBox = VirtualBox.getInstance().exists;
    var isHostnameValid = _server.hostname.isValid();
    var isOrganizationValid = _server.organization.isValid();
    var isMemorySufficient = _server.memory.value >= 4;
    var isCPUCountSufficient = _server.numCPUs.value >= 1;
    
    var isNetworkValid = _server.dhcp4.value || (
        _server.networkBridge.isValid() &&
        _server.networkAddress.isValid() &&
        _server.networkGateway.isValid() &&
        _server.networkNetmask.isValid() &&
        _server.nameServer1.isValid() &&
        _server.nameServer2.isValid()
    );
    
    var hasSafeId = _server.safeIdExists();
    var areRolesOK = _server.areRolesValid();
    
    Logger.info('${this}: Validation details: hasVagrant=${hasVagrant}, hasVirtualBox=${hasVirtualBox}, ' +
                'isHostnameValid=${isHostnameValid}, isOrganizationValid=${isOrganizationValid}, ' +
                'isMemorySufficient=${isMemorySufficient}, isCPUCountSufficient=${isCPUCountSufficient}, ' +
                'isNetworkValid=${isNetworkValid}, hasSafeId=${hasSafeId}, areRolesOK=${areRolesOK}');
    
    // Report validation issues to console if server isn't valid but proceed anyway
    if (!isValid && console != null) {
        console.appendText(LanguageManager.getInstance().getString('serverpage.server.console.warning', 
            'Server validation detected issues that might cause problems:'), true);
        
        if (!hasVagrant) console.appendText("  - Vagrant not installed", true);
        if (!hasVirtualBox) console.appendText("  - VirtualBox not installed", true);
        if (!isHostnameValid) console.appendText("  - Invalid hostname", true);
        if (!isOrganizationValid) console.appendText("  - Invalid organization", true);
        if (!isMemorySufficient) console.appendText("  - Memory allocation less than 4GB", true);
        if (!isCPUCountSufficient) console.appendText("  - CPU count insufficient", true);
        if (!isNetworkValid) console.appendText("  - Network configuration invalid", true);
        if (!hasSafeId) console.appendText("  - SafeID file not found", true);
        if (!areRolesOK) console.appendText("  - Role configuration invalid", true);
    }
    
    // Create target directory and ensure it exists
    createTargetDirectory();

    // Generate the content for Hosts.yml file
    var content = generateHostsFileContent();

    if (console != null) console.appendText(LanguageManager.getInstance().getString('serverpage.server.console.hostsfilecontent', content));

    try {
        // Save the content to the file
        var hostsFilePath = Path.addTrailingSlash(_targetPath) + StandaloneProvisioner.HOSTS_FILE;
        File.saveContent(hostsFilePath, content);
        
        Logger.info('${this}: Custom provisioner created Hosts.yml at ${hostsFilePath}');
        if (console != null) console.appendText(LanguageManager.getInstance().getString('serverpage.server.console.savehostsfile', hostsFilePath));
        
        // Update server status after saving hosts file
        if (_server != null) {
            Logger.info('${this}: Updating server status after saving Hosts.yml');
            _server.setServerStatus();
        }
    } catch (e:Exception) {
        Logger.error('${this}: Custom provisioner could not create Hosts.yml file. Details: ${e.details()} Message: ${e.message}');
        if (console != null) console.appendText(LanguageManager.getInstance().getString('serverpage.server.console.savehostsfileerror', Path.addTrailingSlash(_targetPath) + StandaloneProvisioner.HOSTS_FILE, '${e.details()} Message: ${e.message}'), true);
    }
}

    /**
     * Get the string representation of the provisioner
     * @return The string representation
     */
    override public function toString():String {
        return '[CustomProvisioner(${this._type} v${this.version})]';
    }
}
