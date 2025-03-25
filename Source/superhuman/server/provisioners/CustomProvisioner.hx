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
        Logger.info('CustomProvisioner.getDefaultProvisionerRoles: Getting custom provisioner roles');
        
        // Find all provisioner definitions
        var allProvisioners = ProvisionerManager.getBundledProvisioners();
        
        // Filter to only include custom provisioners (not standard ones)
        var customProvisioners = allProvisioners.filter(p -> 
            p.data.type != ProvisionerType.StandaloneProvisioner &&
            p.data.type != ProvisionerType.AdditionalProvisioner &&
            p.data.type != ProvisionerType.Default
        );
        
        Logger.info('CustomProvisioner.getDefaultProvisionerRoles: Found ${customProvisioners.length} custom provisioners across all types');
        
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
        Logger.info('CustomProvisioner.getDefaultServerData: Starting with id ${id}');
        
        // Get the available provisioners of type Custom
        var customProvisioners = ProvisionerManager.getBundledProvisioners(ProvisionerType.Custom);
        Logger.info('CustomProvisioner.getDefaultServerData: Found ${customProvisioners != null ? customProvisioners.length : 0} custom provisioners');
        
        // Get roles from custom provisioner
        var roleMap = getDefaultProvisionerRoles();
        var roles:Array<RoleData> = [for (r in roleMap.keyValueIterator()) r.value];
        Logger.info('CustomProvisioner.getDefaultServerData: Using ${roles.length} roles from getDefaultProvisionerRoles()');
        
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
 * Ensure data includes the correct string version
 * This is needed for proper version persistence, especially after restarting the application
 * @return ProvisionerData with the correct version
 */
override public function get_data():ProvisionerData {
    // Create a baseline data object
    var baseData = super.get_data();
    
    // Check for version information in various places with priority order
    var foundVersion:String = null;
    var versionSource = "default";
    
    if (_server != null) {
        // 1. First check the server's serverProvisionerId property (highest priority)
        if (_server.serverProvisionerId != null && _server.serverProvisionerId.value != null && 
            _server.serverProvisionerId.value != "" && _server.serverProvisionerId.value != "0.0.0") {
            foundVersion = _server.serverProvisionerId.value;
            versionSource = "serverProvisionerId";
        }
        
        // 2. Then check top-level provisioner object if we haven't found a version yet
        else if (baseData.version != null && baseData.version.toString() != "0.0.0") {
            foundVersion = baseData.version.toString();
            versionSource = "baseData";
        }
        
        // 3. Check in the server's customProperties (multiple locations)
        else if (_server.customProperties != null) {
            // 3a. Check in serviceTypeData.provisioner.data
            if (Reflect.hasField(_server.customProperties, "serviceTypeData")) {
                var serviceTypeData = Reflect.field(_server.customProperties, "serviceTypeData");
                if (serviceTypeData != null && Reflect.hasField(serviceTypeData, "provisioner")) {
                    var stProvisioner = Reflect.field(serviceTypeData, "provisioner");
                    if (stProvisioner != null && Reflect.hasField(stProvisioner, "data")) {
                        var provData = Reflect.field(stProvisioner, "data");
                        if (Reflect.hasField(provData, "version")) {
                            var storedVersion = Reflect.field(provData, "version");
                            if (storedVersion != null && Std.string(storedVersion) != "0.0.0") {
                                foundVersion = Std.string(storedVersion);
                                versionSource = "serviceTypeData.provisioner.data";
                            }
                        }
                    }
                }
            }
            
            // 3b. Check in provisionerDefinition.data
            if (foundVersion == null && Reflect.hasField(_server.customProperties, "provisionerDefinition")) {
                var provDef = Reflect.field(_server.customProperties, "provisionerDefinition");
                if (provDef != null && Reflect.hasField(provDef, "data")) {
                    var provData = Reflect.field(provDef, "data");
                    if (Reflect.hasField(provData, "version")) {
                        var storedVersion = Reflect.field(provData, "version");
                        if (storedVersion != null && Std.string(storedVersion) != "0.0.0") {
                            foundVersion = Std.string(storedVersion);
                            versionSource = "provisionerDefinition.data";
                        }
                    }
                }
            }
        }
    }
    
    // If we found a version in any of the storage locations, use it
    if (foundVersion != null) {
        Logger.info('CustomProvisioner: Using stored version string ${foundVersion} from ${versionSource}');
        return { 
            type: baseData.type,
            version: champaign.core.primitives.VersionInfo.fromString(foundVersion)
        };
    }
    
    // Fallback to the base version (likely 0.0.0)
    return baseData;
}

/**
 * Generate the Hosts.yml file content
 * @return The generated Hosts.yml content
 */
override public function generateHostsFileContent():String {
        _hostsTemplate = getFileContentFromSourceTemplateDirectory(StandaloneProvisioner.HOSTS_TEMPLATE_FILE);
        
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
     * Get the string representation of the provisioner
     * @return The string representation
     */
    override public function toString():String {
        return '[CustomProvisioner(${this._type} v${this.version})]';
    }
}
