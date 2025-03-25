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

        Logger.info('${this}: Copying server configuration files to ${_targetPath} from ${sourcePath}');
        if (console != null) console.appendText(LanguageManager.getInstance().getString('serverpage.server.console.copyvagrantfiles', _targetPath, ""));
        
        // Create target directory if it doesn't exist
        if (!FileSystem.exists(_targetPath)) {
            FileSystem.createDirectory(_targetPath);
        }

        try {
            // First zip the scripts directory
            var zipBytes = _zipDirectory(Path.addTrailingSlash(sourcePath) + "scripts/");
            
            // Then unzip to the target directory
            _unzipToDirectory(zipBytes, _targetPath);
            
            Logger.info('${this}: Successfully copied files using zip/unzip method');
            if (callback != null) callback();
            
        } catch (e) {
            Logger.error('${this}: Error copying files: ${e}');
            if (console != null) console.appendText('Error copying provisioner files: ${e}', true);
        }
    }

    /**
     * Zip a directory and return the zipped bytes
     * @param directory The directory to zip
     * @return Bytes The zipped content
     */
    private function _zipDirectory(directory:String):haxe.io.Bytes {
        var entries:List<haxe.zip.Entry> = new List<haxe.zip.Entry>();
        _addDirectoryToZip(directory, "", entries);
        
        // Compress all entries after they've been added
        for (entry in entries) {
            if (!StringTools.endsWith(entry.fileName, "/")) { // Don't compress directory entries
                haxe.zip.Tools.compress(entry, 9);
            }
        }
        
        var out = new haxe.io.BytesOutput();
        var writer = new haxe.zip.Writer(out);
        writer.write(entries);
        
        return out.getBytes();
    }
    
    /**
     * Helper function to recursively add files to a zip archive
     * @param directory The base directory
     * @param path The current path within the zip
     * @param entries The list of zip entries
     */
    private function _addDirectoryToZip(directory:String, path:String, entries:List<haxe.zip.Entry>):Void {
        var items = FileSystem.readDirectory(directory);
        
        for (item in items) {
            var itemPath = Path.addTrailingSlash(directory) + item;
            var zipPath = path.length > 0 ? path + "/" + item : item;
            
            if (FileSystem.isDirectory(itemPath)) {
                // Add directory entry
                var entry:haxe.zip.Entry = {
                    fileName: zipPath + "/",
                    fileSize: 0,
                    fileTime: Date.now(),
                    compressed: false,
                    dataSize: 0,
                    data: haxe.io.Bytes.alloc(0),
                    crc32: 0
                };
                entries.add(entry);
                
                // Recursively add directory contents
                _addDirectoryToZip(itemPath, zipPath, entries);
            } else {
                // Add file entry
                try {
                    var data = File.getBytes(itemPath);
                    var entry:haxe.zip.Entry = {
                        fileName: zipPath,
                        fileSize: data.length,
                        fileTime: FileSystem.stat(itemPath).mtime,
                        compressed: false,
                        dataSize: data.length,
                        data: data,
                        crc32: haxe.crypto.Crc32.make(data)
                    };
                    entries.add(entry);
                } catch (e) {
                    Logger.warning('Could not add file to zip: ${itemPath} - ${e}');
                }
            }
        }
    }
    
    /**
     * Unzip bytes to a directory
     * @param zipBytes The zipped content
     * @param directory The directory to unzip to
     */
    private function _unzipToDirectory(zipBytes:haxe.io.Bytes, directory:String):Void {
        var entries = haxe.zip.Reader.readZip(new haxe.io.BytesInput(zipBytes));
        
        for (entry in entries) {
            var fileName = entry.fileName;
            
            // Skip directory entries
            if (fileName.length > 0 && fileName.charAt(fileName.length - 1) == "/") {
                var dirPath = Path.addTrailingSlash(directory) + fileName;
                _createDirectoryRecursive(dirPath);
                continue;
            }
            
            // Create parent directories if needed
            var filePath = Path.addTrailingSlash(directory) + fileName;
            var parentDir = Path.directory(filePath);
            _createDirectoryRecursive(parentDir);
            
            // Extract file
            try {
                var data = entry.data;
                if (entry.compressed) {
                    haxe.zip.Tools.uncompress(entry);
                }
                File.saveBytes(filePath, entry.data);
            } catch (e) {
                Logger.warning('Could not extract file from zip: ${fileName} - ${e}');
            }
        }
    }
    
    /**
     * Create a directory and all parent directories if they don't exist
     * @param directory The directory path to create
     */
    private function _createDirectoryRecursive(directory:String):Void {
        if (directory == null || directory == "" || FileSystem.exists(directory)) {
            return;
        }
        
        _createDirectoryRecursive(Path.directory(directory));
        FileSystem.createDirectory(directory);
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
            return "hosts:\n  - name: \"::SERVER_HOSTNAME::.::SERVER_ORGANIZATION::.com\"\n    settings:\n      description: \"Custom provisioner host\"\n      ram: ::SERVER_MEMORY::\n      cpus: ::SERVER_CPUS::\n      dhcp4: ::SERVER_DHCP::\n";
        }
        
        // Create a simple hosts file generator for custom provisioners
        // This is a simplified version that just does basic variable substitution
        var content = _hostsTemplate;
     
        // Extract just the hostname part (before the first dot)
        var fullHostname = _server.hostname.value;
        var hostnameOnly = fullHostname;
        var dotIndex = fullHostname.indexOf(".");
        if (dotIndex > 0) {
            hostnameOnly = fullHostname.substring(0, dotIndex);
            Logger.info('${this}: Extracted hostname "${hostnameOnly}" from full hostname "${fullHostname}"');
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
        
        // Process all roles using exact names from provisioner.yml
        for (role in _server.roles.value) {
            var roleValue = role.enabled ? "true" : "false";
            content = _replaceVariable(content, role.value, roleValue);
            Logger.info('${this}: Setting role variable ${role.value} = ${roleValue}');
        }

        // Add custom properties if available
        if (_server.customProperties != null) {
            var customProps = _server.customProperties;
            
            // Log the current state of customProperties for debugging
            Logger.info('${this}: Processing customProperties with fields: ${Reflect.fields(customProps).join(", ")}');
            
            // Process all custom properties in a consistent way
            var allCustomProps = new Map<String, String>();
            
            // Helper function to safely get a field value
            function getFieldValue(obj:Dynamic, field:String):Dynamic {
                if (obj == null || !Reflect.hasField(obj, field)) return null;
                return Reflect.field(obj, field);
            }
            
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
            
            // For custom provisioners, we want to ONLY use dynamicCustomProperties
            // This ensures a clean separation between custom and standard provisioner properties
            var basicProps = getFieldValue(customProps, "dynamicCustomProperties");
            
            if (basicProps != null) {
                Logger.info('${this}: Processing dynamicCustomProperties with fields: ${Reflect.fields(basicProps).join(", ")}');
                
                // Get all fields from dynamicCustomProperties
                var fields = Reflect.fields(basicProps);
                for (field in fields) {
                    // Skip internal fields
                    if (field == "provisionerDefinition" || field == "serviceTypeData") continue;
                    
                    // Get and convert the value
                    var value = Reflect.field(basicProps, field);
                    if (value != null) {
                        var strValue = safeToString(value);
                        if (strValue != "") {
                            allCustomProps.set(field, strValue);
                            Logger.info('${this}: Added custom property ${field} = ${strValue}');
                        }
                    }
                }
            } else {
                Logger.info('${this}: No dynamicCustomProperties found in server');
            }
            
            // Add advanced properties (higher priority)
            var advancedProps = getFieldValue(customProps, "dynamicAdvancedCustomProperties");
            if (advancedProps != null) {
                Logger.info('${this}: Processing dynamicAdvancedCustomProperties with fields: ${Reflect.fields(advancedProps).join(", ")}');
                
                // Get all fields from dynamicAdvancedCustomProperties
                var fields = Reflect.fields(advancedProps);
                for (field in fields) {
                    // Skip internal fields
                    if (field == "provisionerDefinition" || field == "serviceTypeData") continue;
                    
                    // Get and convert the value
                    var value = Reflect.field(advancedProps, field);
                    if (value != null) {
                        var strValue = safeToString(value);
                        if (strValue != "") {
                            allCustomProps.set(field, strValue);
                            Logger.info('${this}: Added advanced custom property ${field} = ${strValue}');
                        }
                    }
                }
            }
            
            // Replace all variables in the template
            Logger.info('${this}: Replacing ${Lambda.count(allCustomProps)} custom properties in template');
            for (field => value in allCustomProps) {
                var before = content;
                content = _replaceVariable(content, field, value);
                var replaced = (before != content);
                Logger.info('${this}: Replaced property ${field} = ${value}, success=${replaced}');
            }
        } else {
            Logger.warning('${this}: No customProperties available on server');
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
    
    // Create target directory and ensure it exists regardless of validation
    createTargetDirectory();

    // Log the custom properties state to help with debugging
    if (_server != null && _server.customProperties != null) {
        Logger.info('${this}: Server has customProperties with fields: ${Reflect.fields(_server.customProperties).join(", ")}');
        
        if (Reflect.hasField(_server.customProperties, "dynamicCustomProperties")) {
            var basicFields = Reflect.field(_server.customProperties, "dynamicCustomProperties");
            if (basicFields != null) {
                Logger.info('${this}: dynamicCustomProperties has fields: ${Reflect.fields(basicFields).join(", ")}');
            } else {
                Logger.warning('${this}: dynamicCustomProperties is null');
            }
        } else {
            Logger.info('${this}: No dynamicCustomProperties found');
        }
        
        if (Reflect.hasField(_server.customProperties, "dynamicAdvancedCustomProperties")) {
            var advancedFields = Reflect.field(_server.customProperties, "dynamicAdvancedCustomProperties");
            if (advancedFields != null) {
                Logger.info('${this}: dynamicAdvancedCustomProperties has fields: ${Reflect.fields(advancedFields).join(", ")}');
            } else {
                Logger.warning('${this}: dynamicAdvancedCustomProperties is null');
            }
        } else {
            Logger.info('${this}: No dynamicAdvancedCustomProperties found');
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
        
        Logger.info('${this}: Custom provisioner created Hosts.yml at ${hostsFilePath}');
        if (console != null) console.appendText(LanguageManager.getInstance().getString('serverpage.server.console.savehostsfile', hostsFilePath));
        
        // Update server status after saving hosts file
        if (_server != null) {
            _server.setServerStatus();
            
            // Make sure to save the server data to persist any changes to customProperties
            _server.saveData();
            Logger.info('${this}: Saved server data to persist customProperties');
        }
    } catch (e:Exception) {
        Logger.error('${this}: Custom provisioner could not create Hosts.yml file. Details: ${e.details()} Message: ${e.message}');
        if (console != null) console.appendText(LanguageManager.getInstance().getString('serverpage.server.console.savehostsfileerror', Path.addTrailingSlash(_targetPath) + StandaloneProvisioner.HOSTS_FILE, '${e.details()} Message: ${e.message}'), true);
    }
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
                Logger.info('${this}: Replaced variable ${variation} with value "${value}"');
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
