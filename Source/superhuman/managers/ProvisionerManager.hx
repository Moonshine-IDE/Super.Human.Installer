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

package superhuman.managers;

import superhuman.config.SuperHumanGlobals;
import superhuman.server.provisioners.DemoTasks;
import champaign.core.logging.Logger;
import champaign.core.primitives.VersionInfo;
import feathers.data.ArrayCollection;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import haxe.io.Path;
import haxe.zip.Entry;
import haxe.zip.Reader;
import haxe.zip.Tools;
import haxe.zip.Writer;
import lime.system.System;
import superhuman.server.definitions.ProvisionerDefinition;
import superhuman.server.provisioners.ProvisionerType;
import sys.FileSystem;
import sys.io.File;
import yaml.Yaml;
import yaml.util.ObjectMap;

/**
 * Structure for provisioner.yml metadata
 */
typedef ProvisionerMetadata = {
    var name:String;
    var type:String;
    var description:String;
    @:optional var author:String;
    @:optional var version:String;
    @:optional var configuration:ProvisionerConfiguration;
    @:optional var serverType:String; // Determines which UI type to use (e.g., "domino" or "additional-domino")
}

/**
 * Structure for configuration fields in provisioner.yml
 */
typedef ProvisionerConfiguration = {
    @:optional var basicFields:Array<ProvisionerField>;
    @:optional var advancedFields:Array<ProvisionerField>;
}

/**
 * Structure for a single configuration field
 */
typedef ProvisionerField = {
    var name:String;
    var type:String; // text, number, checkbox, dropdown, button
    var label:String;
    @:optional var defaultValue:Dynamic;
    @:optional var required:Bool;
    @:optional var validationKey:String; // Reference to validation key in Server class
    @:optional var options:Array<{value:String, label:String}>; // For dropdown fields
    @:optional var min:Float; // For number fields
    @:optional var max:Float; // For number fields
    @:optional var tooltip:String;
    @:optional var placeholder:String;
    @:optional var restrict:String; // For text fields, restricts input to specified characters
}

class ProvisionerManager {

    // Paths for bundled provisioners (included in the binary)
    static final PROVISIONER_STANDALONE_LOCAL_PATH:String = "assets/provisioners/hcl_domino_standalone_provisioner/"; // Renamed from demo-tasks
    static final PROVISIONER_ADDITIONAL_LOCAL_PATH:String = "assets/provisioners/hcl_domino_additional_provisioner/"; // Renamed from additional-prov
    
    // Filename for provisioner metadata
    static final PROVISIONER_METADATA_FILENAME:String = "provisioner.yml";
    
    /**
     * Get the path to the common provisioners directory
     * @return String The full path to the provisioners directory
     */
    static public function getProvisionersDirectory():String {
        return Path.addTrailingSlash(System.applicationStorageDirectory) + SuperHumanGlobals.PROVISIONERS_DIRECTORY;
    }
    
    /**
     * Read and parse provisioner metadata from provisioner.yml file
     * @param path Path to the provisioner directory
     * @return ProvisionerMetadata|null Metadata if file exists and is valid, null otherwise
     */
    static public function readProvisionerMetadata(path:String):ProvisionerMetadata {
        var metadataPath = Path.addTrailingSlash(path) + PROVISIONER_METADATA_FILENAME;
        
        Logger.info('Reading provisioner metadata from ${metadataPath}');
        
        if (!FileSystem.exists(metadataPath)) {
            Logger.warning('Provisioner metadata file not found at ${metadataPath}');
            return null;
        }
        
        try {
            var content = File.getContent(metadataPath);
            Logger.info('Provisioner metadata content: ${content.substr(0, Math.min(Std.int(content.length), 200))}...');
            
            var metadata:ObjectMap<String, Dynamic> = Yaml.read(metadataPath);
            
            // Validate required fields
            if (!metadata.exists("name") || !metadata.exists("type") || !metadata.exists("description")) {
                Logger.warning('Invalid provisioner.yml at ${metadataPath}: missing required fields');
                return null;
            }
            
            Logger.info('Provisioner metadata parsed successfully: name=${metadata.get("name")}, type=${metadata.get("type")}');
            
            // Parse configuration if it exists
            var configuration:ProvisionerConfiguration = null;
            if (metadata.exists("configuration")) {
                var configData:ObjectMap<String, Dynamic> = metadata.get("configuration");
                configuration = {
                    basicFields: _parseFieldsArray(configData.exists("basicFields") ? configData.get("basicFields") : null),
                    advancedFields: _parseFieldsArray(configData.exists("advancedFields") ? configData.get("advancedFields") : null)
                };
            }
            
            return {
                name: metadata.get("name"),
                type: metadata.get("type"),
                description: metadata.get("description"),
                author: metadata.exists("author") ? metadata.get("author") : null,
                version: metadata.exists("version") ? metadata.get("version") : null,
                configuration: configuration,
                serverType: metadata.exists("serverType") ? metadata.get("serverType") : null
            };
        } catch (e) {
            Logger.error('Error reading provisioner.yml at ${metadataPath}: ${e}');
            return null;
        }
    }
    
    /**
     * Parse an array of field definitions from the YAML data
     * @param fieldsData The array of field data from the YAML
     * @return Array<ProvisionerField> The parsed field definitions
     */
    static private function _parseFieldsArray(fieldsData:Array<Dynamic>):Array<ProvisionerField> {
        if (fieldsData == null) {
            Logger.info('No fields data provided');
            return null;
        }
        
        Logger.info('Parsing ${fieldsData.length} fields');
        var result:Array<ProvisionerField> = [];
        
        for (fieldData in fieldsData) {
            try {
                Logger.info('Parsing field: ${fieldData}');
                
                var field:ProvisionerField = {
                    name: fieldData.get("name"),
                    type: fieldData.get("type"),
                    label: fieldData.get("label")
                };
                
                Logger.info('Field parsed: name=${field.name}, type=${field.type}, label=${field.label}');
            
                // Add optional properties if they exist
                if (fieldData.exists("defaultValue")) field.defaultValue = fieldData.get("defaultValue");
                if (fieldData.exists("required")) field.required = fieldData.get("required");
                if (fieldData.exists("validationKey")) field.validationKey = fieldData.get("validationKey");
                if (fieldData.exists("tooltip")) field.tooltip = fieldData.get("tooltip");
                if (fieldData.exists("placeholder")) field.placeholder = fieldData.get("placeholder");
                if (fieldData.exists("restrict")) field.restrict = fieldData.get("restrict");
                
                // Parse options for dropdown fields
                if (fieldData.exists("options")) {
                    var optionsData:Array<Dynamic> = fieldData.get("options");
                    field.options = [];
                    
                    for (optionData in optionsData) {
                        field.options.push({
                            value: optionData.get("value"),
                            label: optionData.get("label")
                        });
                    }
                }
                
                // Parse min/max for number fields
                if (fieldData.exists("min")) field.min = Std.parseFloat(fieldData.get("min"));
                if (fieldData.exists("max")) field.max = Std.parseFloat(fieldData.get("max"));
                
                result.push(field);
            } catch (e) {
                Logger.error('Error parsing field: ${e}');
            }
        }
        
        return result;
    }
    
    /**
     * Create default metadata for legacy provisioners
     * @param type Provisioner type
     * @param version Version string
     * @return ProvisionerMetadata Default metadata
     */
    static public function createDefaultMetadata(type:String, version:String):ProvisionerMetadata {
        if (type == ProvisionerType.DemoTasks) {
            return {
                name: "HCL Standalone Provisioner",
                type: type,
                description: "Default provisioner for standalone Domino servers",
                version: version
            };
        } else if (type == ProvisionerType.AdditionalProvisioner) {
            return {
                name: "HCL Additional Provisioner",
                type: type,
                description: "Provisioner for additional Domino servers",
                version: version
            };
        } else {
            return {
                name: "Custom Provisioner",
                type: type,
                description: "Custom provisioner",
                version: version
            };
        }
    }

    /**
     * Get available provisioners from the common directory
     * @param type Optional provisioner type filter
     * @return Array<ProvisionerDefinition> Array of available provisioners
     */
    static public function getBundledProvisioners(type:ProvisionerType = null):Array<ProvisionerDefinition> {
        var result:Array<ProvisionerDefinition> = [];
        
        // Check for provisioners in the common directory
        var commonDir = getProvisionersDirectory();
        if (!FileSystem.exists(commonDir)) {
            // Create the directory if it doesn't exist
            try {
                FileSystem.createDirectory(commonDir);
                Logger.info('Created provisioners directory at ${commonDir}');
            } catch (e) {
                Logger.error('Failed to create provisioners directory at ${commonDir}: ${e}');
                return []; // Return empty array instead of falling back
            }
        }
        
        try {
            // List all directories in the common directory
            var provisionerDirs = FileSystem.readDirectory(commonDir);
            Logger.info('Found ${provisionerDirs.length} provisioner directories in ${commonDir}');
            
            for (provisionerDir in provisionerDirs) {
                var provisionerPath = Path.addTrailingSlash(commonDir) + provisionerDir;
                
                // Skip if not a directory
                if (!FileSystem.isDirectory(provisionerPath)) {
                    continue;
                }
                
                // Read provisioner metadata
                var metadata = readProvisionerMetadata(provisionerPath);
                
                // Skip if no metadata or if filtering by type and type doesn't match
                if (metadata == null) {
                    Logger.warning('No valid metadata found for provisioner at ${provisionerPath}');
                    continue;
                }
                
                if (type != null && metadata.type != type) {
                    Logger.verbose('Skipping provisioner ${metadata.type} as it does not match requested type ${type}');
                    continue;
                }
                
                Logger.info('Processing provisioner ${metadata.name} (${metadata.type})');
                
                // List all version directories
                try {
                    var versionDirs = FileSystem.readDirectory(provisionerPath);
                    Logger.info('Found ${versionDirs.length} version directories for ${metadata.type}');
                    
                    for (versionDir in versionDirs) {
                        var versionPath = Path.addTrailingSlash(provisionerPath) + versionDir;
                        
                        // Skip if not a directory
                        if (!FileSystem.isDirectory(versionPath)) {
                            continue;
                        }
                        
                        // Check if this is a valid version directory (has scripts subdirectory)
                        var scriptsPath = Path.addTrailingSlash(versionPath) + "scripts";
                        
                        if (FileSystem.exists(scriptsPath) && FileSystem.isDirectory(scriptsPath)) {
                            // Create provisioner definition
                            var versionInfo = VersionInfo.fromString(versionDir);
                            Logger.info('Adding provisioner ${metadata.type} version ${versionDir}');
                            
                            // Create a copy of the metadata with the specific version
                            var versionMetadata = Reflect.copy(metadata);
                            versionMetadata.version = versionDir;
                            
                            result.push({
                                name: '${metadata.name} v${versionDir}',
                                data: { type: metadata.type, version: versionInfo },
                                root: versionPath,
                                metadata: versionMetadata
                            });
                        } else {
                            Logger.warning('Skipping version directory ${versionDir} as it does not have a scripts subdirectory');
                        }
                    }
                } catch (e) {
                    Logger.error('Error reading version directories for provisioner ${provisionerDir}: ${e}');
                }
            }
        } catch (e) {
            Logger.error('Error reading provisioners directory: ${e}');
            return []; // Return empty array instead of falling back
        }
        
        // Sort by version, newest first
        result.sort((a, b) -> {
            var versionA = a.data.version;
            var versionB = b.data.version;
            return versionB > versionA ? 1 : (versionB < versionA ? -1 : 0);
        });
        
        Logger.info('Returning ${result.length} provisioner definitions');
        return result;
    }
    

    static public function getBundledProvisionerCollection( ?type:ProvisionerType ):ArrayCollection<ProvisionerDefinition> {

        var a = getBundledProvisioners(type);

        if ( type == null ) return new ArrayCollection( a );

        var c = new ArrayCollection<ProvisionerDefinition>();
        for ( p in a ) if ( p.data.type == type ) c.add( p );
        return c;

    }

    static public function getProvisionerDefinition( type:ProvisionerType, version:VersionInfo ):ProvisionerDefinition {

        var bundledProvisionerCollection = getBundledProvisionerCollection(type);
        for ( provisioner in bundledProvisionerCollection ) {

			if ( provisioner.data.type == type && provisioner.data.version == version ) return provisioner;

		}

		return null;

    }
    
    /**
     * Import a provisioner from a source directory to the common provisioners directory
     * @param sourcePath Path to the source provisioner directory
     * @return Bool True if import was successful, false otherwise
     */
    static public function importProvisioner(sourcePath:String):Bool {
        // Validate that the source directory contains a valid provisioner
        var metadata = readProvisionerMetadata(sourcePath);
        if (metadata == null) {
            Logger.error('Invalid provisioner at ${sourcePath}: missing or invalid provisioner.yml');
            return false;
        }
        
        // Create the destination directory
        var destPath = Path.addTrailingSlash(getProvisionersDirectory()) + metadata.type;
        try {
            if (!FileSystem.exists(destPath)) {
                FileSystem.createDirectory(destPath);
                Logger.info('Created provisioner directory at ${destPath}');
            }
            
            // Copy provisioner.yml to the destination directory
            var sourceMetadataPath = Path.addTrailingSlash(sourcePath) + PROVISIONER_METADATA_FILENAME;
            var destMetadataPath = Path.addTrailingSlash(destPath) + PROVISIONER_METADATA_FILENAME;
            
            if (!FileSystem.exists(sourceMetadataPath)) {
                Logger.error('Provisioner metadata file not found at ${sourceMetadataPath}');
                return false;
            }
            
            File.copy(sourceMetadataPath, destMetadataPath);
            Logger.info('Copied provisioner metadata to ${destMetadataPath}');
            
            // Look for version directories in the source directory
            var versionDirs = FileSystem.readDirectory(sourcePath);
            var versionsImported = 0;
            var versionsAlreadyExist = 0;
            var validVersionsFound = 0;
            
            for (versionDir in versionDirs) {
                var versionSourcePath = Path.addTrailingSlash(sourcePath) + versionDir;
                
                // Skip if not a directory or if it's the provisioner.yml file
                if (!FileSystem.isDirectory(versionSourcePath) || versionDir == PROVISIONER_METADATA_FILENAME) {
                    continue;
                }
                
                // Check if this is a valid version directory (has scripts subdirectory)
                var scriptsSourcePath = Path.addTrailingSlash(versionSourcePath) + "scripts";
                if (!FileSystem.exists(scriptsSourcePath) || !FileSystem.isDirectory(scriptsSourcePath)) {
                    Logger.warning('Skipping version directory ${versionDir} as it does not have a scripts subdirectory');
                    continue;
                }
                
                // Count valid version directories
                validVersionsFound++;
                
                // Create the destination version directory
                var versionDestPath = Path.addTrailingSlash(destPath) + versionDir;
                if (FileSystem.exists(versionDestPath)) {
                    Logger.warning('Version ${versionDir} already exists at ${versionDestPath}, skipping');
                    versionsAlreadyExist++;
                    continue;
                }
                
                // Use zip/unzip to copy the version directory instead of direct file copying
                try {
                    // Create the destination directory
                    FileSystem.createDirectory(versionDestPath);
                    
                    // Zip the source directory
                    var zipBytes = _zipDirectory(versionSourcePath);
                    
                    // Unzip to the destination directory
                    _unzipToDirectory(zipBytes, versionDestPath);
                    
                    Logger.info('Imported version ${versionDir} to ${versionDestPath}');
                    versionsImported++;
                } catch (e) {
                    Logger.error('Error importing version ${versionDir}: ${e}');
                }
            }
            
            if (validVersionsFound == 0) {
                Logger.warning('No valid version directories found in ${sourcePath}');
                return false;
            }
            
            if (versionsImported == 0 && versionsAlreadyExist > 0) {
                Logger.info('All versions of provisioner ${metadata.type} already exist (${versionsAlreadyExist} versions)');
                return true; // Return success if all versions already exist
            }
            
            Logger.info('Successfully imported ${versionsImported} versions of provisioner ${metadata.type}' + 
                        (versionsAlreadyExist > 0 ? ' (${versionsAlreadyExist} versions already existed)' : ''));
            return true;
            
        } catch (e) {
            Logger.error('Error importing provisioner: ${e}');
            return false;
        }
    }
    
    /**
     * Zip a directory and return the zipped bytes
     * @param directory The directory to zip
     * @return Bytes The zipped content
     */
    static private function _zipDirectory(directory:String):Bytes {
        var entries:List<Entry> = new List<Entry>();
        _addDirectoryToZip(directory, "", entries);
        
        var out = new BytesOutput();
        var writer = new Writer(out);
        writer.write(entries);
        
        return out.getBytes();
    }
    
    /**
     * Helper function to recursively add files to a zip archive
     * @param directory The base directory
     * @param path The current path within the zip
     * @param entries The list of zip entries
     */
    static private function _addDirectoryToZip(directory:String, path:String, entries:List<Entry>):Void {
        var items = FileSystem.readDirectory(directory);
        
        for (item in items) {
            var itemPath = Path.addTrailingSlash(directory) + item;
            var zipPath = path.length > 0 ? path + "/" + item : item;
            
            if (FileSystem.isDirectory(itemPath)) {
                // Add directory entry
                var entry:Entry = {
                    fileName: zipPath + "/",
                    fileSize: 0,
                    fileTime: Date.now(),
                    compressed: false,
                    dataSize: 0,
                    data: Bytes.alloc(0),
                    crc32: 0
                };
                entries.add(entry);
                
                // Recursively add directory contents
                _addDirectoryToZip(itemPath, zipPath, entries);
            } else {
                // Add file entry
                try {
                    var data = File.getBytes(itemPath);
                    var entry:Entry = {
                        fileName: zipPath,
                        fileSize: data.length,
                        fileTime: FileSystem.stat(itemPath).mtime,
                        compressed: true,
                        dataSize: 0,
                        data: data,
                        crc32: haxe.crypto.Crc32.make(data)
                    };
                    Tools.compress(entry, 9);
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
    static private function _unzipToDirectory(zipBytes:Bytes, directory:String):Void {
        var entries = Reader.readZip(new BytesInput(zipBytes));
        
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
                    Tools.uncompress(entry);
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
    static private function _createDirectoryRecursive(directory:String):Void {
        if (directory == null || directory == "" || FileSystem.exists(directory)) {
            return;
        }
        
        _createDirectoryRecursive(Path.directory(directory));
        FileSystem.createDirectory(directory);
    }

}
