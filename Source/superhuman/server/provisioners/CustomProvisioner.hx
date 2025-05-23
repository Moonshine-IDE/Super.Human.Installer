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
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import haxe.io.Path;
import haxe.zip.Entry;
import haxe.zip.Writer;
import prominic.sys.io.FileTools;
import superhuman.managers.ProvisionerManager;
import superhuman.server.data.ProvisionerData;
import superhuman.server.data.RoleData;
import superhuman.server.data.ServerData;
import superhuman.server.definitions.ProvisionerDefinition;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
import StringTools;
import haxe.Template;
import haxe.Json;

/**
 * CustomProvisioner is a provisioner implementation for custom provisioner types.
 * It extends StandaloneProvisioner and overrides specific methods to handle custom provisioner functionality.
 */
class CustomProvisioner extends StandaloneProvisioner {

    /**
     * Override copyFiles to ensure we use the correct source path for custom provisioners
     * Always using the zip/unzip method for consistent file transfer and long path handling
     */
    /**
     * Create a single zip file from a directory, handling Windows long path issues
     * This creates a structured zip with proper directory entries and paths for reliable extraction
     * @param directory Path to the directory to zip
     * @return Bytes The complete zip file as bytes
     */
    private function _zipWholeDirectory(directory:String):Bytes {
        Logger.info('${this}: Creating structured zip from directory: ${directory}');
        
        // Create a new empty zip archive with improved handling for deep structures
        var entries = new List<Entry>();
        var platformDir = _getPlatformPath(directory);
        
        try {
            // Add a directory entry for the root directory
            var rootEntry:Entry = {
                fileName: "./",
                fileSize: 0,
                fileTime: Date.now(),
                compressed: false,
                dataSize: 0,
                data: Bytes.alloc(0),
                crc32: 0
            };
            entries.add(rootEntry);
            
            // Keep track of directories we've added to prevent duplicates
            var addedDirs = new Map<String, Bool>();
            addedDirs.set("./", true);
            
            // Get the source directory structure using platform-specific paths
            var filesToProcess = _collectAllFiles(platformDir);
            Logger.info('${this}: Found ${filesToProcess.length} files to process for zip creation');
            
            // First, make sure all parent directories exist in the zip
            for (filePath in filesToProcess) {
                try {
                    // Create relative path for the zip entry
                    var relPath = filePath.substr(platformDir.length + 1);
                    relPath = StringTools.replace(relPath, "\\", "/");
                    
                    // Add directory entries for all parent directories
                    var dirParts = relPath.split("/");
                    var currentPath = "";
                    
                    // Skip the last part (which is the file)
                    for (i in 0...dirParts.length - 1) {
                        currentPath += dirParts[i] + "/";
                        
                        // Skip if we already added this directory
                        if (addedDirs.exists(currentPath)) {
                            continue;
                        }
                        
                        // Add directory entry
                        var dirEntry:Entry = {
                            fileName: currentPath,
                            fileSize: 0,
                            fileTime: Date.now(),
                            compressed: false,
                            dataSize: 0,
                            data: Bytes.alloc(0),
                            crc32: 0
                        };
                        
                        entries.add(dirEntry);
                        addedDirs.set(currentPath, true);
                        Logger.verbose('${this}: Added directory entry to zip: ${currentPath}');
                    }
                } catch (e) {
                    Logger.warning('${this}: Error processing directories for file: ${filePath} - ${e}');
                }
            }
            
            // Now add all files
            for (filePath in filesToProcess) {
                // Create relative path for the zip entry
                var relPath = filePath.substr(platformDir.length + 1);
                relPath = StringTools.replace(relPath, "\\", "/");
                
                try {
                    // Get the platform path for the file
                    var platformFilePath = _getPlatformPath(filePath);
                    
                    // Get the file data with platform-specific path handling
                    var data = File.getBytes(platformFilePath);
                    
                    // Create an uncompressed entry
                    var entry:Entry = {
                        fileName: relPath,
                        fileSize: data.length,
                        fileTime: FileSystem.stat(platformFilePath).mtime,
                        compressed: false,
                        dataSize: data.length,
                        data: data,
                        crc32: haxe.crypto.Crc32.make(data)
                    };
                    
                    entries.add(entry);
                    Logger.verbose('${this}: Added file to zip: ${relPath}');
                } catch (e) {
                    Logger.warning('${this}: Could not add file to zip: ${relPath} - ${e}');
                }
            }
            
            // Write all entries to a zip file
            var out = new BytesOutput();
            var writer = new Writer(out);
            writer.write(entries);
            
            return out.getBytes();
        } catch (e) {
            Logger.error('${this}: Error creating zip from directory: ${e}');
            throw e;
        }
    }
    
    /**
     * Recursively collect all files from a directory and its subdirectories
     * Enhanced to handle very deep Windows paths reliably
     * @param directory The directory to collect files from
     * @return Array<String> All file paths found
     */
    private function _collectAllFiles(directory:String):Array<String> {
        var result:Array<String> = [];
        
        try {
            // Ensure we're using platform-specific path handling
            var platformDir = _getPlatformPath(directory);
            
            if (!FileSystem.exists(platformDir)) {
                Logger.error('${this}: Directory does not exist: ${directory}');
                return result;
            }
            
            if (!FileSystem.isDirectory(platformDir)) {
                Logger.error('${this}: Path is not a directory: ${directory}');
                return result;
            }
            
            try {
                var items = FileSystem.readDirectory(platformDir);
                Logger.verbose('${this}: Found ${items.length} items in directory: ${directory}');
                
                for (item in items) {
                    // Construct paths correctly with proper trailing slashes
                    var fullPath = Path.addTrailingSlash(directory) + item;
                    var platformPath = _getPlatformPath(fullPath);
                    
                    try {
                        if (FileSystem.isDirectory(platformPath)) {
                            // Add all files from subdirectories
                            var subFiles = _collectAllFiles(fullPath);
                            if (subFiles.length > 0) {
                                Logger.verbose('${this}: Adding ${subFiles.length} files from subdirectory: ${item}');
                                result = result.concat(subFiles);
                            } else {
                                Logger.verbose('${this}: No files found in subdirectory: ${item}');
                            }
                        } else {
                            // Add this file to the result
                            result.push(fullPath);
                        }
                    } catch (fileErr) {
                        // Log but continue processing other files
                        Logger.warning('${this}: Error processing item ${item} in directory ${directory}: ${fileErr}');
                    }
                }
            } catch (readErr) {
                Logger.error('${this}: Could not read directory ${directory}: ${readErr}');
                
                #if windows
                // Add specific info for Windows to help with debugging
                var dirLength = directory.length;
                Logger.error('${this}: Path length: ${dirLength}, possibly exceeding Windows limits even with long path support');
                Logger.error('${this}: Platform path used: ${platformDir}');
                #end
            }
        } catch (e) {
            Logger.error('${this}: Error collecting files from directory ${directory}: ${e}');
        }
        
        return result;
    }

    /**
 * Use robocopy on Windows to copy deep directory structures
 * Robocopy is a Windows-specific tool that handles long paths correctly
 * @param sourcePath The source directory path
 * @param targetPath The target directory path
 * @return Bool success status
 */
private function _copyWithRobocopy(sourcePath:String, targetPath:String):Bool {
    Logger.info('${this}: Using robocopy to copy from ${sourcePath} to ${targetPath}');
    
    // Format paths for robocopy - ensure trailing backslashes for directories
    var sourceFormatted = StringTools.replace(Path.addTrailingSlash(sourcePath), "/", "\\");
    var targetFormatted = StringTools.replace(Path.addTrailingSlash(targetPath), "/", "\\");
    
    try {
        // Build robocopy command with options for handling long paths
        // /E - Copy subdirectories including empty ones
        // /COPY:DAT - Copy Data, Attributes, and Timestamps
        // /R:1 - Retry 1 time (to minimize waiting if there's an issue)
        // /W:1 - Wait 1 second between retries
        // /NFL - Don't log file names (reduces log verbosity)
        // /NDL - Don't log directory names (reduces log verbosity)
        // /MT - Multi-threaded copying
        // /NP - No progress (avoid console flooding)
        // Normalize paths to Windows format - all backslashes
        var sourceDir = StringTools.replace(sourcePath, "/", "\\");
        var targetDir = StringTools.replace(targetPath, "/", "\\");
        
        // Remove trailing slashes/backslashes
        if (StringTools.endsWith(sourceDir, "\\")) {
            sourceDir = sourceDir.substr(0, sourceDir.length - 1);
        }
        if (StringTools.endsWith(targetDir, "\\")) {
            targetDir = targetDir.substr(0, targetDir.length - 1);
        }
        
        // Create a properly formatted robocopy command
        // Note: We separate each argument properly with spaces outside the quotes
        var command = 'robocopy "' + sourceDir + '" "' + targetDir + '" *.* /E /COPY:DAT /R:1 /W:1 /NFL /NDL /MT:8 /NP';
        Logger.info('${this}: Executing command: ${command}');
        
        if (console != null) {
            console.appendText('Executing robocopy for deep path handling: ${command}');
        }
        
        // Run robocopy process
        var process = new Process(command);
        var exitCode = process.exitCode();
        
        // Get output and error streams
        var output = process.stdout.readAll().toString();
        var error = process.stderr.readAll().toString();
        
        // Close the process to free resources
        process.close();
        
        // Log results
        if (output.length > 0) {
            Logger.info('${this}: Robocopy output: ${output}');
        }
        
        if (error.length > 0) {
            Logger.error('${this}: Robocopy error: ${error}');
        }
        
        // Robocopy returns specific exit codes:
        // 0 - No files copied (files already exist and are up to date)
        // 1 - Files copied successfully
        // 2 - Extra files/directories detected (not an error)
        // 3 = 1+2 (Some files copied, some extra files/directories detected)
        // Values 0-7 indicate success with various conditions
        
        if (exitCode >= 0 && exitCode <= 7) {
            Logger.info('${this}: Robocopy completed successfully with exit code ${exitCode}');
            
            // Verify some key files were copied correctly
            try {
                var targetHostsFilePath = Path.addTrailingSlash(_targetPath) + "templates";
                if (FileSystem.exists(_getPlatformPath(targetHostsFilePath))) {
                    Logger.info('${this}: Successfully verified templates directory exists in target');
                    return true;
                } else {
                    Logger.warning('${this}: Templates directory not found after robocopy operation');
                }
            } catch (verifyErr) {
                Logger.warning('${this}: Error verifying copied files: ${verifyErr}');
            }
            
            return true;
        } else {
            Logger.error('${this}: Robocopy failed with exit code ${exitCode}');
            if (console != null) {
                console.appendText('Robocopy failed with exit code ${exitCode}', true);
            }
            return false;
        }
    } catch (e) {
        Logger.error('${this}: Error executing robocopy: ${e}');
        if (console != null) {
            console.appendText('Error executing robocopy: ${e}', true);
        }
        return false;
    }
}

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

        #if windows
        // On Windows, use robocopy which handles long paths better
        Logger.info('${this}: On Windows platform, using robocopy for deep path copying');
        if (console != null) console.appendText(LanguageManager.getInstance().getString('serverpage.server.console.copyvagrantfiles', _targetPath, " (using robocopy)"));
        
        // Log path lengths for debugging
        Logger.info('${this}: Source path length: ${sourcePath.length}, Target path length: ${_targetPath.length}');
        
        // Use robocopy to handle long paths on Windows
        var success = _copyWithRobocopy(sourcePath, _targetPath);
        
        if (success) {
            Logger.info('${this}: Successfully copied files using robocopy');
        } else {
            Logger.error('${this}: Failed to copy files using robocopy');
            if (console != null) console.appendText('Error copying provisioner files with robocopy', true);
        }
        
        if (callback != null) callback();
        
        #else
        // On non-Windows platforms, use the original zip/unzip method
        Logger.info('${this}: Copying custom provisioner files to ${_targetPath} using enhanced zip/unzip method');
        if (console != null) console.appendText(LanguageManager.getInstance().getString('serverpage.server.console.copyvagrantfiles', _targetPath, ""));
        
        try {
            // Use our enhanced directory zipping method to better handle long paths
            Logger.info('${this}: Zipping source directory: ${sourcePath}');
            var zipBytes = _zipWholeDirectory(sourcePath);
            
            // Then unzip to the target directory
            Logger.info('${this}: Unzipping to target directory: ${_targetPath}');
            _unzipToDirectory(zipBytes, _targetPath);
            
            Logger.info('${this}: Successfully copied files using enhanced zip/unzip method');
            
            // Verify some key files were copied correctly
            try {
                var targetHostsFilePath = Path.addTrailingSlash(_targetPath) + "templates";
                if (FileSystem.exists(_getPlatformPath(targetHostsFilePath))) {
                    Logger.info('${this}: Successfully verified templates directory exists in target');
                } else {
                    Logger.warning('${this}: Templates directory may not have been copied correctly');
                }
            } catch (verifyErr) {
                Logger.warning('${this}: Error verifying copied files: ${verifyErr}');
            }
            
            if (callback != null) callback();
            
        } catch (e) {
            // No fallback - just report the error and continue
            Logger.error('${this}: Error copying files using zip/unzip: ${e}');
            if (console != null) console.appendText('Error copying provisioner files: ${e}', true);
            
            // Call the callback even if we failed
            if (callback != null) callback();
        }
        #end
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
        
        // Copy from userData to customProperties to ensure consistency
        Reflect.setField(_server.customProperties, "provisionerDefinition", provisionerDefinition);
    } else if (Reflect.hasField(_server.customProperties, "provisionerDefinition")) {
        provisionerDefinition = Reflect.field(_server.customProperties, "provisionerDefinition");
    }
    
    // Create dynamicCustomProperties if it doesn't exist
    if (!Reflect.hasField(_server.customProperties, "dynamicCustomProperties")) {
        Reflect.setField(_server.customProperties, "dynamicCustomProperties", {});
    }
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
                    
                    // Preserve the original type to ensure consistency
                    return {
                        type: originalType,
                        version: versionInfo
                    };
                }
            }
        }
    }
    
    // Fallback to the base version while preserving the original type
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
    
    _hostsTemplate = getFileContentFromSourceTemplateDirectory(StandaloneProvisioner.HOSTS_TEMPLATE_FILE);
    
    if (_hostsTemplate == null || _hostsTemplate.length == 0) {
        Logger.warning('${this}:generateHostsFileContent: Template not found using standard method, will try alternative location'); 
        var standaloneProvisioners = ProvisionerManager.getBundledProvisioners(ProvisionerType.StandaloneProvisioner);
        if (standaloneProvisioners != null && standaloneProvisioners.length > 0) {
            var latestStandaloneProvisioner = standaloneProvisioners[0];
            var standalonePath = Path.addTrailingSlash(latestStandaloneProvisioner.root) + "templates/" + StandaloneProvisioner.HOSTS_TEMPLATE_FILE;
            if (FileSystem.exists(standalonePath)) {
                try { _hostsTemplate = File.getContent(standalonePath); } catch (e) {
                    Logger.error('${this}:generateHostsFileContent: Error reading fallback template at ${standalonePath}: ${e}');
                }
            }
        }
    }
    
    if (_hostsTemplate == null || _hostsTemplate.length == 0) {
        Logger.error('${this}:generateHostsFileContent: Could not find any valid template for Hosts.yml');
        if (console != null) {
            console.appendText(LanguageManager.getInstance().getString('serverpage.server.console.error', 'Could not find template for Hosts.yml'), true);
        }
        return "hosts:\n  - name: \"::SERVER_HOSTNAME::.::SERVER_ORGANIZATION::.com\"\n    settings:\n      description: \"Custom provisioner host\"\n      ram: ::SERVER_MEMORY::\n      cpus: ::SERVER_CPUS::\n      dhcp4: ::SERVER_DHCP::\n";
    }

    var replacementMap = new Map<String, String>();
    var contextObject:Dynamic = {}; // Use a Dynamic object for haxe.Template

    // Helper for adding to map, ensuring value is not null and key is uppercase for template
    function addToContext(key:String, value:Dynamic) {
        Reflect.setField(contextObject, key.toUpperCase(), value == null ? "" : Std.string(value));
    }
    function addBoolToContext(key:String, value:Bool) {
        Reflect.setField(contextObject, key.toUpperCase(), value ? "true" : "false");
    }

    // Populate General Server Settings
    var fullHostname = _server.hostname.value;
    var hostnameOnly = fullHostname;
    var dotIndex = fullHostname.indexOf(".");
    if (dotIndex > 0) {
        hostnameOnly = fullHostname.substring(0, dotIndex);
    }
    addToContext("SERVER_HOSTNAME", hostnameOnly);
    addToContext("SERVER_DOMAIN", _server.url.domainName);
    addToContext("SERVER_ORGANIZATION", _server.organization.value);
    addToContext("SERVER_ID", _server.id);
    addToContext("RESOURCES_RAM", Std.string(_server.memory.value) + "G");
    addToContext("SERVER_MEMORY", _server.memory.value); // For older template compatibility
    addToContext("RESOURCES_CPU", _server.numCPUs.value);
    addToContext("SERVER_CPUS", _server.numCPUs.value); // For older template compatibility
    
    addBoolToContext("NETWORK_DHCP4", _server.dhcp4.value);
    addBoolToContext("SERVER_DHCP", _server.dhcp4.value); // For older template compatibility

    if (!_server.dhcp4.value) {
        addToContext("NETWORK_ADDRESS", _server.networkAddress.value);
        addToContext("NETWORK_GATEWAY", _server.networkGateway.value);
        addToContext("NETWORK_DNS_NAMESERVER_1", _server.nameServer1.value);
        addToContext("NETWORK_DNS1", _server.nameServer1.value); // For older template compatibility
        addToContext("NETWORK_DNS_NAMESERVER_2", _server.nameServer2.value);
        addToContext("NETWORK_DNS2", _server.nameServer2.value); // For older template compatibility
        addToContext("NETWORK_NETMASK", _server.networkNetmask.value);
    } else {
        addToContext("NETWORK_ADDRESS", "192.168.2.1");
        addToContext("NETWORK_NETMASK", "255.255.255.0");
        addToContext("NETWORK_GATEWAY", "");
        addToContext("NETWORK_DNS_NAMESERVER_1", "1.1.1.1");
        addToContext("NETWORK_DNS1", "1.1.1.1");
        addToContext("NETWORK_DNS_NAMESERVER_2", "1.0.0.1");
        addToContext("NETWORK_DNS2", "1.0.0.1");
    }
    addToContext("NETWORK_BRIDGE", _server.getEffectiveNetworkInterface());
    addBoolToContext("DISABLE_BRIDGE_ADAPTER", _server.disableBridgeAdapter.value);
    addToContext("USER_EMAIL", _server.userEmail.value);
    addToContext("SERVER_DEFAULT_USER", "startcloud");
    addToContext("SERVER_DEFAULT_USER_PASS", "STARTcloud24@!");
    addToContext("BOX_URL", "https://boxvault.startcloud.com");
    addBoolToContext("SHOW_CONSOLE", false);
    addBoolToContext("POST_PROVISION", true);
    addToContext("ENV_SETUP_WAIT", _server.setupWait.value);
    addToContext("SYNC_METHOD", Std.string(_server.syncMethod));

    // Populate Role-Specific Data
    if (_server.customProperties != null && Reflect.hasField(_server.customProperties, "provisionerDefinition")) {
        var provDef = Reflect.field(_server.customProperties, "provisionerDefinition");
        if (provDef != null && Reflect.hasField(provDef, "metadata") && Reflect.hasField(provDef.metadata, "roles")) {
            var metadataRolesArray:Array<Dynamic> = cast(Reflect.field(provDef.metadata, "roles"), Array<Dynamic>);
            var selectedRolesMap = new Map<String, RoleData>();
            for (sr in _server.roles.value) {
                selectedRolesMap.set(sr.value, sr);
            }

            for (metadataRoleInfo in metadataRolesArray) {
                if (metadataRoleInfo == null || !Reflect.hasField(metadataRoleInfo, "name")) continue;
                
                var roleName = Std.string(Reflect.field(metadataRoleInfo, "name"));
                var roleUpper = StringTools.replace(roleName.toUpperCase(), "-", "_");

                // Default initialization for this role's sub-variables
                // Note: Main role enablement (e.g., ::domino::) is handled separately below.
                addToContext(roleUpper + "_INSTALLER", "");
                addToContext(roleUpper + "_HASH", "");
                addToContext(roleUpper + "_INSTALLER_VERSION", "");
                addToContext(roleUpper + "_INSTALLER_MAJOR_VERSION", "");
                addToContext(roleUpper + "_INSTALLER_MINOR_VERSION", "");
                addToContext(roleUpper + "_INSTALLER_PATCH_VERSION", "");
                addBoolToContext(roleUpper + "_FP_INSTALL", false);
                addToContext(roleUpper + "_FP_INSTALLER", "");
                addToContext(roleUpper + "_FP_INSTALLER_VERSION", "");
                addToContext(roleUpper + "_FP_HASH", "");
                addBoolToContext(roleUpper + "_HF_INSTALL", false);
                addToContext(roleUpper + "_HF_INSTALLER", "");
                addToContext(roleUpper + "_HF_INSTALLER_VERSION", "");
                addToContext(roleUpper + "_HF_HASH", "");

                var selectedRoleData:RoleData = selectedRolesMap.get(roleName);
                var isRoleEnabled = (selectedRoleData != null && selectedRoleData.enabled);
                
                // Set main role enablement variable (e.g. ::domino:: or ::DOMINO::)
                // The template might use lowercase ::rolename:: or uppercase ::ROLENAME::
                // We set both to be safe, Haxe template will pick the one that exists.
                addBoolToContext(roleName.toLowerCase(), isRoleEnabled);
                addBoolToContext(roleUpper, isRoleEnabled);

                if (isRoleEnabled && selectedRoleData != null && selectedRoleData.files != null) {
                    var files = selectedRoleData.files;
                    if (files.installer != null && files.installerFileName != null) {
                        addToContext(roleUpper + "_INSTALLER", files.installerFileName);
                        addToContext(roleUpper + "_HASH", files.installerHash);
                        if (files.installerVersion != null) {
                            var v = files.installerVersion;
                            if (Reflect.hasField(v, "fullVersion")) addToContext(roleUpper + "_INSTALLER_VERSION", Reflect.field(v, "fullVersion"));
                            
                            // General handling for installer version parts
                            if (Reflect.hasField(v, "majorVersion")) {
                                addToContext(roleUpper + "_INSTALLER_MAJOR_VERSION", Reflect.field(v, "majorVersion"));
                            }
                            if (Reflect.hasField(v, "minorVersion")) {
                                addToContext(roleUpper + "_INSTALLER_MINOR_VERSION", Reflect.field(v, "minorVersion"));
                            }
                            if (Reflect.hasField(v, "patchVersion")) {
                                addToContext(roleUpper + "_INSTALLER_PATCH_VERSION", Reflect.field(v, "patchVersion"));
                            }
                        }
                    }
                    if (files.hotfixes != null && files.hotfixes.length > 0) {
                        var hotfixPath = new Path(files.hotfixes[0]);
                        addBoolToContext(roleUpper + "_HF_INSTALL", true);
                        addToContext(roleUpper + "_HF_INSTALLER", hotfixPath.file + "." + hotfixPath.ext);
                        addToContext(roleUpper + "_HF_HASH", files.installerHotFixHash);
                        if (files.installerHotFixVersion != null && Reflect.hasField(files.installerHotFixVersion, "fullVersion")) {
                            addToContext(roleUpper + "_HF_INSTALLER_VERSION", Reflect.field(files.installerHotFixVersion, "fullVersion"));
                        }
                    }
                    if (files.fixpacks != null && files.fixpacks.length > 0) {
                        var fixpackPath = new Path(files.fixpacks[0]);
                        addBoolToContext(roleUpper + "_FP_INSTALL", true);
                        addToContext(roleUpper + "_FP_INSTALLER", fixpackPath.file + "." + fixpackPath.ext);
                        addToContext(roleUpper + "_FP_HASH", files.installerFixpackHash);
                        if (files.installerFixpackVersion != null && Reflect.hasField(files.installerFixpackVersion, "fullVersion")) {
                            addToContext(roleUpper + "_FP_INSTALLER_VERSION", Reflect.field(files.installerFixpackVersion, "fullVersion"));
                        }
                    }
                }
            }
        }
    }

    // Populate with Custom Properties (allowing overrides)
    // These keys in the template are expected to be UPPERCASE by convention (e.g., ::MY_CUSTOM_FIELD::)
    if (_server.customProperties != null) {
        function safeToString(value:Dynamic):String { // Local helper
            if (value == null) return "";
            return switch(Type.typeof(value)) {
                case TBool: value ? "true" : "false";
                case TFloat: Std.string(value);
                case TInt: Std.string(value);
                case TClass(String): value;
                case _: try { Std.string(value); } catch(e) { ""; }
            }
        }
        
        // Process fields from provisioner.yml metadata.configuration
        if (Reflect.hasField(_server.customProperties, "provisionerDefinition")) {
            var provDef = Reflect.field(_server.customProperties, "provisionerDefinition");
            if (provDef != null && Reflect.hasField(provDef, "metadata") && Reflect.hasField(provDef.metadata, "configuration")) {
                var config = provDef.metadata.configuration;
                if (Reflect.hasField(config, "basicFields")) {
                    var fields:Array<Dynamic> = cast Reflect.field(config, "basicFields");
                    if (fields != null) for (field in fields) if (field != null && Reflect.hasField(field, "name")) {
                        var fieldName = Std.string(Reflect.field(field, "name"));
                        var defaultValue = (Reflect.hasField(field, "defaultValue") && Reflect.field(field, "defaultValue") != null) ? safeToString(Reflect.field(field, "defaultValue")) : "";
                        addToContext(fieldName, defaultValue); // Key will be uppercased by addToContext
                    }
                }
                if (Reflect.hasField(config, "advancedFields")) {
                     var fields:Array<Dynamic> = cast Reflect.field(config, "advancedFields");
                    if (fields != null) for (field in fields) if (field != null && Reflect.hasField(field, "name")) {
                        var fieldName = Std.string(Reflect.field(field, "name"));
                        var defaultValue = (Reflect.hasField(field, "defaultValue") && Reflect.field(field, "defaultValue") != null) ? safeToString(Reflect.field(field, "defaultValue")) : "";
                        addToContext(fieldName, defaultValue); // Key will be uppercased by addToContext
                    }
                }
            }
        }
        // Override with dynamicCustomProperties
        if (Reflect.hasField(_server.customProperties, "dynamicCustomProperties")) {
            var props = Reflect.field(_server.customProperties, "dynamicCustomProperties");
            if (props != null) for (field in Reflect.fields(props)) {
                if (field == "provisionerDefinition" || field == "serviceTypeData") continue;
                var value = Reflect.field(props, field);
                if (value != null) addToContext(field, safeToString(value)); // Key will be uppercased
            }
        }
        if (Reflect.hasField(_server.customProperties, "dynamicAdvancedCustomProperties")) {
            var props = Reflect.field(_server.customProperties, "dynamicAdvancedCustomProperties");
            if (props != null) for (field in Reflect.fields(props)) {
                if (field == "provisionerDefinition" || field == "serviceTypeData") continue;
                var value = Reflect.field(props, field);
                if (value != null) addToContext(field, safeToString(value)); // Key will be uppercased
            }
        }
    }
    
    var template = new haxe.Template(_hostsTemplate);
    var finalContent:String;
    try {
        finalContent = template.execute(contextObject);
    } catch (e:Dynamic) {
        Logger.error('${this}:generateHostsFileContent: Error executing Haxe template: ${e}');
        finalContent = "Error generating content from template: " + Std.string(e); 
    }
    
    return finalContent;
}
    
/**
 * Clear the target directory using robocopy on Windows for long paths
 * Use standard API on other platforms
 */
override public function clearTargetDirectory() {
    #if windows
    // On Windows, attempt to use robocopy to clear the directory first
    try {
        // Get platform-specific path
        var platformTargetPath = _getPlatformPath(_targetPath);
        
        // Check if directory exists first
        if (FileSystem.exists(platformTargetPath)) {
            Logger.info('${this}: Clearing target directory: ${_targetPath}');
            
            if (!FileSystem.isDirectory(platformTargetPath)) {
                Logger.error('${this}: Target path exists but is not a directory: ${_targetPath}');
                return;
            }
            
            // First try to use rd /s /q for directory removal (more reliable for long paths than FileSystem.deleteDirectory)
            try {
                var command = 'rd /s /q "' + StringTools.replace(platformTargetPath, "/", "\\") + '"';
                Logger.info('${this}: Executing command: ${command}');
                
                var process = new Process(command);
                var exitCode = process.exitCode();
                var error = process.stderr.readAll().toString();
                process.close();
                
                if (exitCode == 0) {
                    Logger.info('${this}: Successfully deleted target directory using rd command');
                } else {
                    Logger.warning('${this}: rd command returned non-zero exit code: ${exitCode}');
                    if (error.length > 0) {
                        Logger.warning('${this}: rd error output: ${error}');
                    }
                    
                    // Fall back to FileTools.deleteDirectory if rd fails
                    FileTools.deleteDirectory(platformTargetPath);
                    Logger.info('${this}: Successfully deleted target directory using FileTools');
                }
            } catch (deleteErr) {
                Logger.error('${this}: Error deleting target directory: ${deleteErr}');
                Logger.error('${this}: Path length: ${_targetPath.length}, Platform path: ${platformTargetPath}');
                // Rethrow to maintain existing behavior
                throw deleteErr;
            }
        }
        
        // Create the target directory with platform-specific handling
        try {
            FileSystem.createDirectory(platformTargetPath);
            Logger.info('${this}: Successfully created target directory');
        } catch (createErr) {
            Logger.error('${this}: Error creating target directory with standard API: ${createErr}');
            
            // Try using mkdir as a fallback
            try {
                var command = 'mkdir "' + StringTools.replace(platformTargetPath, "/", "\\") + '"';
                Logger.info('${this}: Attempting directory creation with command: ${command}');
                
                var process = new Process(command);
                var exitCode = process.exitCode();
                process.close();
                
                if (exitCode == 0) {
                    Logger.info('${this}: Successfully created directory using mkdir command');
                } else {
                    Logger.error('${this}: Failed to create directory with mkdir, exit code: ${exitCode}');
                    throw createErr; // Re-throw the original error
                }
            } catch (cmdErr) {
                Logger.error('${this}: Failed to create directory using mkdir command: ${cmdErr}');
                throw createErr; // Re-throw the original error
            }
        }
    } catch (e) {
        Logger.error('${this}: Error clearing target directory: ${e}');
        throw e;
    }
    #else
    // On non-Windows platforms, use the original implementation
    try {
        // Get platform-specific path
        var platformTargetPath = _getPlatformPath(_targetPath);
        
        // Check if directory exists first
        if (FileSystem.exists(platformTargetPath)) {
            Logger.info('${this}: Clearing target directory: ${_targetPath}');
            
            if (!FileSystem.isDirectory(platformTargetPath)) {
                Logger.error('${this}: Target path exists but is not a directory: ${_targetPath}');
                return;
            }
            
            // Attempt to delete the directory and its contents
            try {
                FileTools.deleteDirectory(platformTargetPath);
                Logger.info('${this}: Successfully deleted target directory');
            } catch (deleteErr) {
                Logger.error('${this}: Error deleting target directory: ${deleteErr}');
                throw deleteErr;
            }
        }
        
        // Create the target directory
        try {
            FileSystem.createDirectory(platformTargetPath);
            Logger.info('${this}: Successfully created target directory');
        } catch (createErr) {
            Logger.error('${this}: Error creating target directory: ${createErr}');
            throw createErr;
        }
    } catch (e) {
        Logger.error('${this}: Error clearing target directory: ${e}');
        throw e;
    }
    #end
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
     * Get the string representation of the provisioner
     * @return The string representation
     */
    override public function toString():String {
        return '[CustomProvisioner(${this._type} v${this.version})]';
    }
}
