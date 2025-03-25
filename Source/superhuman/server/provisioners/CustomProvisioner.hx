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
import superhuman.server.data.ServerData;
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
     * Get default server data for a custom provisioner
     * @param id The server ID
     * @return The default server data
     */
    static public function getDefaultServerData(id:Int):ServerData {
        // Get the available provisioners of type Custom
        var customProvisioners = ProvisionerManager.getBundledProvisioners(ProvisionerType.Custom);
        
        // Default roles array
        var roles:Array<RoleData> = [];
        
        // Check if we have any custom provisioners available
        if (customProvisioners != null && customProvisioners.length > 0) {
            var firstProvisioner = customProvisioners[0];
            
            // Get roles from the provisioner metadata if available
            if (firstProvisioner.metadata != null && 
                firstProvisioner.metadata.roles != null && 
                firstProvisioner.metadata.roles.length > 0) {
                
                Logger.info('${CustomProvisioner}: Using roles from custom provisioner metadata');
                
                // Create role data from custom provisioner roles
                for (roleInfo in firstProvisioner.metadata.roles) {
                    // Get default enabled state or default to false
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
                    
                    roles.push(roleData);
                }
            } else {
                // Fall back to default StandaloneProvisioner roles if no custom roles defined
                Logger.warning('${CustomProvisioner}: No custom roles found, falling back to default roles');
                roles = [for (r in StandaloneProvisioner.getDefaultProvisionerRoles().keyValueIterator()) r.value];
            }
            
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
            Logger.warning('${CustomProvisioner}: No custom provisioners found, using default provisioner');
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
