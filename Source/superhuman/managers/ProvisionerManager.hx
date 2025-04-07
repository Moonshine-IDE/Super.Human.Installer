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
import superhuman.server.provisioners.StandaloneProvisioner;
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
 * Structure for provisioner role definition
 */
typedef ProvisionerRole = {
    var name:String;
    var label:String;
    var description:String;
    @:optional var defaultEnabled:Bool;
    @:optional var required:Bool;
    @:optional var installers:{
        @:optional var installer:Bool;
        @:optional var fixpack:Bool;
        @:optional var hotfix:Bool;
    };
}

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
    @:optional var roles:Array<ProvisionerRole>;
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
    @:optional var hidden:Bool; // Whether to hide this field in the UI
    @:optional var validationKey:String; // Reference to validation key in Server class
    @:optional var options:Array<{value:String, label:String}>; // For dropdown fields
    @:optional var min:Float; // For number fields
    @:optional var max:Float; // For number fields
    @:optional var tooltip:String;
    @:optional var placeholder:String;
    @:optional var restrict:String; // For text fields, restricts input to specified characters
}

class ProvisionerManager {
    // Static cache of all provisioner definitions
    static private var _cachedProvisioners:Map<String, Array<ProvisionerDefinition>> = null;

    // Paths for bundled provisioners (included in the binary)
    static final PROVISIONER_STANDALONE_LOCAL_PATH:String = "assets/provisioners/hcl_domino_standalone_provisioner/";
    static final PROVISIONER_ADDITIONAL_LOCAL_PATH:String = "assets/provisioners/hcl_domino_additional_provisioner/";
    
    // Filenames for provisioner metadata
    static final PROVISIONER_METADATA_FILENAME:String = "provisioner-collection.yml";
    static final VERSION_METADATA_FILENAME:String = "provisioner.yml";
    
    /**
     * Get the path to the common provisioners directory
     * @return String The full path to the provisioners directory
     */
    static public function getProvisionersDirectory():String {
        return Path.addTrailingSlash(System.applicationStorageDirectory) + SuperHumanGlobals.PROVISIONERS_DIRECTORY;
    }
    
    /**
     * Initialize the provisioner cache
     * This should be called at application startup
     */
    static public function initializeCache():Void {
        if (_cachedProvisioners != null) {
            Logger.info('Provisioner cache already initialized with ${Lambda.count(_cachedProvisioners)} types');
            return; // Already initialized
        }
        
        Logger.info('Initializing provisioner cache...');
        _cachedProvisioners = new Map<String, Array<ProvisionerDefinition>>();
        
        // Scan provisioners directory
        var provisionersDir = getProvisionersDirectory();
        if (!FileSystem.exists(provisionersDir)) {
            FileSystem.createDirectory(provisionersDir);
            Logger.info('Created provisioners directory at ${provisionersDir}');
        }
        
        // Read all provisioner types
        try {
            var provisionerDirs = FileSystem.readDirectory(provisionersDir);
            Logger.info('Found ${provisionerDirs.length} potential provisioner directories');
            
            // Log each provisioner directory before processing
            Logger.info('Found provisioner directories:');
            for (dir in provisionerDirs) {
                var fullPath = Path.addTrailingSlash(provisionersDir) + dir;
                var isDir = FileSystem.isDirectory(fullPath);
                Logger.info('  - ${dir} (isDirectory: ${isDir})');
                
                // If it's a directory, check for metadata files
                if (isDir) {
                    var metadataPath = Path.addTrailingSlash(fullPath) + PROVISIONER_METADATA_FILENAME;
                    var legacyPath = Path.addTrailingSlash(fullPath) + "provisioner.yml";
                    var hasMetadata = FileSystem.exists(metadataPath);
                    var hasLegacy = FileSystem.exists(legacyPath);
                    Logger.info('    Has provisioner-collection.yml: ${hasMetadata}');
                    Logger.info('    Has provisioner.yml in root: ${hasLegacy}');
                    
                    // Check version directories
                    try {
                        var versionDirs = FileSystem.readDirectory(fullPath);
                        var versionSubdirs = versionDirs.filter(item -> 
                            FileSystem.isDirectory(Path.addTrailingSlash(fullPath) + item) && 
                            item != PROVISIONER_METADATA_FILENAME
                        );
                        
                        Logger.info('    Version directories: ${versionSubdirs.length}');
                        
                        // Check each version directory for provisioner.yml
                        for (versionDir in versionSubdirs) {
                            var versionPath = Path.addTrailingSlash(fullPath) + versionDir;
                            var versionMetadataPath = Path.addTrailingSlash(versionPath) + VERSION_METADATA_FILENAME;
                            var hasVersionMetadata = FileSystem.exists(versionMetadataPath);
                            var hasScriptsDir = FileSystem.exists(Path.addTrailingSlash(versionPath) + "scripts") && 
                                               FileSystem.isDirectory(Path.addTrailingSlash(versionPath) + "scripts");
                            
                            Logger.info('      - Version ${versionDir}:');
                            Logger.info('        Has provisioner.yml: ${hasVersionMetadata}');
                            Logger.info('        Has scripts directory: ${hasScriptsDir}');
                            
                            // Check content of version metadata file if it exists
                            if (hasVersionMetadata) {
                                try {
                                    var content = File.getContent(versionMetadataPath);
                                    Logger.info('        provisioner.yml content:');
                                    var lines = content.split("\n");
                                    var previewLines = lines.length > 5 ? lines.slice(0, 5) : lines;
                                    for (line in previewLines) {
                                        Logger.info('          ${line}');
                                    }
                                    if (lines.length > 5) {
                                        Logger.info('          ...(${lines.length - 5} more lines)');
                                    }
                                } catch (e) {
                                    Logger.error('        Error reading provisioner.yml: ${e}');
                                }
                            }
                        }
                    } catch (e) {
                        Logger.error('    Error reading version directories: ${e}');
                    }
                }
            }
            
            for (provisionerDir in provisionerDirs) {
                var provisionerPath = Path.addTrailingSlash(provisionersDir) + provisionerDir;
                
                // Skip if not a directory
                if (!FileSystem.isDirectory(provisionerPath)) {
                    Logger.verbose('Skipping non-directory: ${provisionerPath}');
                    continue;
                }
                
                // Read provisioner metadata
                var metadata = readProvisionerMetadata(provisionerPath);
                if (metadata == null) {
                    Logger.verbose('Skipping directory without valid metadata: ${provisionerPath}');
                    continue;
                }
                
                Logger.info('Found provisioner type: ${metadata.type} (${metadata.name})');
                
                // Create array for this type if it doesn't exist
                if (!_cachedProvisioners.exists(metadata.type)) {
                    _cachedProvisioners.set(metadata.type, []);
                }
                
                // Add all versions of this provisioner
                _addProvisionerVersionsToCache(provisionerPath, metadata);
            }
            
            // Log summary of cached provisioners
            var totalProvisioners = 0;
            for (type in _cachedProvisioners.keys()) {
                var count = _cachedProvisioners.get(type).length;
                totalProvisioners += count;
                Logger.info('Cached ${count} provisioners of type ${type}');
            }
            Logger.info('Provisioner cache initialized with ${totalProvisioners} total provisioners');
            
        } catch (e) {
            Logger.error('Error initializing provisioner cache: ${e}');
        }
    }
    
    /**
     * Add all versions of a provisioner to the cache
     * @param provisionerPath Path to the provisioner directory
     * @param metadata The provisioner metadata
     */
    static private function _addProvisionerVersionsToCache(provisionerPath:String, metadata:ProvisionerMetadata):Void {
        try {
            var versionDirs = FileSystem.readDirectory(provisionerPath);
            var validVersionCount = 0;
            
            // Log metadata being processed
            Logger.info('Processing provisioner: ${metadata.name} (${metadata.type})');
            Logger.info('Looking for valid versions in: ${provisionerPath}');
            
            for (versionDir in versionDirs) {
                var versionPath = Path.addTrailingSlash(provisionerPath) + versionDir;
                
                // Skip if not a directory or if it's a metadata file
                if (!FileSystem.isDirectory(versionPath) || 
                    versionDir == PROVISIONER_METADATA_FILENAME || 
                    versionDir == "provisioner.yml") {
                    continue;
                }
                
                // Check if this is a valid version directory (has scripts subdirectory)
                var scriptsPath = Path.addTrailingSlash(versionPath) + "scripts";
                if (!FileSystem.exists(scriptsPath) || !FileSystem.isDirectory(scriptsPath)) {
                    Logger.warning('Skipping invalid version directory (no scripts folder): ${versionPath}');
                    continue;
                }
                
                // Check for version-specific metadata file - MUST EXIST
                var versionMetadataPath = Path.addTrailingSlash(versionPath) + VERSION_METADATA_FILENAME;
                
                if (!FileSystem.exists(versionMetadataPath)) {
                    Logger.warning('Skipping version directory with missing provisioner.yml: ${versionPath}');
                    continue;
                }
                
                // Use our dedicated function to read version-specific metadata
                var versionMetadata = readProvisionerVersionMetadata(versionPath);
                
                if (versionMetadata == null) {
                    Logger.warning('Failed to read version-specific metadata from ${versionMetadataPath}');
                    continue;
                }
                
                // Add detailed logging to examine the fields
                if (versionMetadata.configuration != null) {
                    var basicCount = (versionMetadata.configuration.basicFields != null) ? 
                        versionMetadata.configuration.basicFields.length : 0;
                    var advancedCount = (versionMetadata.configuration.advancedFields != null) ? 
                        versionMetadata.configuration.advancedFields.length : 0;
                    
                    Logger.info('Version metadata has ${basicCount} basic fields and ${advancedCount} advanced fields');
                }
                
                // Override version field with the directory name to ensure consistency
                versionMetadata.version = versionDir;
                
                // Fall back to collection metadata for fields that might be missing in version metadata
                if (versionMetadata.name == null) versionMetadata.name = metadata.name;
                if (versionMetadata.type == null) versionMetadata.type = metadata.type;
                if (versionMetadata.description == null) versionMetadata.description = metadata.description;
                if (versionMetadata.author == null) versionMetadata.author = metadata.author;
                
                // If configuration is missing from version metadata, inherit from collection
                if (versionMetadata.configuration == null && metadata.configuration != null) {
                    Logger.info('No configuration found in version-specific metadata, inheriting from collection metadata');
                    versionMetadata.configuration = metadata.configuration;
                }
                
                // If roles are missing from version metadata, inherit from collection
                if (versionMetadata.roles == null && metadata.roles != null) {
                    Logger.info('No roles found in version-specific metadata, inheriting from collection metadata');
                    versionMetadata.roles = metadata.roles;
                }
                
                Logger.info('Successfully prepared metadata for ${versionMetadataPath}');
                
                if (versionMetadata != null) {
                    // Create provisioner definition
                    var versionInfo = VersionInfo.fromString(versionDir);
                    var provDef:ProvisionerDefinition = {
                        name: '${metadata.name} v${versionDir}',
                        data: { type: metadata.type, version: versionInfo },
                        root: versionPath,
                        metadata: versionMetadata
                    };
                    
                    // Add to cache - create the array if it doesn't exist
                    if (!_cachedProvisioners.exists(metadata.type)) {
                        Logger.info('Creating new cache entry for provisioner type: ${metadata.type}');
                        _cachedProvisioners.set(metadata.type, []);
                    }
                    
                    // Now we can safely push to the array
                    _cachedProvisioners.get(metadata.type).push(provDef);
                    Logger.info('Added provisioner to cache: ${provDef.name}, type: ${metadata.type}, version: ${versionDir}');
                    validVersionCount++;
                }
            }
            
            // If there are no valid versions but we have a provisioner-collection.yml
            // Add a disabled placeholder entry so the provisioner shows up in the UI but is greyed out
            if (validVersionCount == 0) {
                Logger.warning('No valid versions found for provisioner: ${metadata.name} (${metadata.type})');
                
                // Create a disabled entry using the metadata from the collection file
                var placeholderVersionInfo = VersionInfo.fromString("0.0.0");
                var provDef:ProvisionerDefinition = {
                    name: '${metadata.name} (Invalid)',
                    data: { 
                        type: metadata.type, 
                        version: placeholderVersionInfo 
                    },
                    root: provisionerPath,
                    metadata: metadata
                };
                
                // Add to cache with disabled flag
                if (!_cachedProvisioners.exists(metadata.type)) {
                    _cachedProvisioners.set(metadata.type, []);
                }
                
                _cachedProvisioners.get(metadata.type).push(provDef);
                Logger.info('Added disabled provisioner to cache: ${provDef.name}, type: ${metadata.type}');
                
                // In UI, this provisioner will be shown but disabled using the isEnabled flag in ServiceTypeData
            }
            
            // Sort the provisioners by version, newest first
            if (_cachedProvisioners.exists(metadata.type) && _cachedProvisioners.get(metadata.type).length > 0) {
                _cachedProvisioners.get(metadata.type).sort((a, b) -> {
                    var versionA = a.data.version;
                    var versionB = b.data.version;
                    
                    // Special case for the disabled entry (0.0.0)
                    if (versionA == "0.0.0") return 1; // Put disabled entries at the end
                    if (versionB == "0.0.0") return -1;
                    
                    return versionB > versionA ? 1 : (versionB < versionA ? -1 : 0);
                });
            }
            
        } catch (e) {
            Logger.error('Error adding provisioner versions to cache: ${e}');
        }
    }
    
    /**
     * Read and parse provisioner metadata from provisioner-collection.yml file
     * @param path Path to the provisioner directory
     * @return ProvisionerMetadata|null Metadata if file exists and is valid, null otherwise
     */
    static public function readProvisionerMetadata(path:String):ProvisionerMetadata {
        var metadataPath = Path.addTrailingSlash(path) + PROVISIONER_METADATA_FILENAME;
        
        // Add detailed logging
        Logger.info('Attempting to read provisioner collection metadata from: ${metadataPath}');
        
        // Only look for provisioner-collection.yml in the root directory
        if (!FileSystem.exists(metadataPath)) {
            Logger.error('No collection metadata file found at ${metadataPath}');
            return null;
        }
        
        Logger.info('Found ${PROVISIONER_METADATA_FILENAME} file at ${metadataPath}');
        
        try {
            // Read the file content directly
            var content = File.getContent(metadataPath);
            var previewLength:Int = cast Math.min(100, content.length);
            Logger.info('File content preview: ${content.substr(0, previewLength)}...');
            
            // Try to parse the YAML content
            var metadata:Dynamic = null;
            
            try {
                metadata = Yaml.read(metadataPath);
                
                // Debug the YAML parsing result
                Logger.info('YAML parsing result type: ${Type.typeof(metadata)}');
                if (metadata != null) {
                    // Check for ObjectMap type (common YAML parser output)
                    if (Std.isOfType(metadata, ObjectMap)) {
                        var objMap:ObjectMap<String, Dynamic> = cast metadata;
                        var keys = [for (k in objMap.keys()) k];
                        Logger.info('YAML parsed as ObjectMap with keys: ${keys.join(", ")}');
                        
                        // Create a standard object from ObjectMap for easier handling
                        var stdObj:Dynamic = {};
                        for (key in keys) {
                            Reflect.setField(stdObj, key, objMap.get(key));
                        }
                        metadata = stdObj;
                    } else {
                        Logger.info('YAML parsed as standard object');
                    }
                }
            } catch (yamlError) {
                Logger.error('YAML parsing error: ${yamlError}');
                
                // Try a manual parsing as fallback
                Logger.info('Attempting manual parsing of the YAML file');
                var lines = content.split("\n");
                var manualMetadata:Dynamic = {};
                
                for (line in lines) {
                    // Skip comments and empty lines
                    var trimmed = StringTools.ltrim(line);
                    if (StringTools.startsWith(trimmed, "#") || StringTools.trim(line) == "") continue;
                    
                    // Find key-value pairs
                    var colonPos = line.indexOf(":");
                    if (colonPos > 0) {
                        var key = StringTools.trim(line.substr(0, colonPos));
                        var value = StringTools.trim(line.substr(colonPos + 1));
                        
                        // Remove quotes if present
                        if (StringTools.startsWith(value, '"') && value.length > 0 && value.charAt(value.length - 1) == '"') {
                            value = value.substr(1, value.length - 2);
                        }
                        
                        Reflect.setField(manualMetadata, key, value);
                        Logger.info('Manually parsed field: ${key} = ${value}');
                    }
                }
                
                metadata = manualMetadata;
            }
            
            // Validate required fields with more detailed logging
            var hasName = Reflect.hasField(metadata, "name");
            var hasType = Reflect.hasField(metadata, "type");
            var hasDescription = Reflect.hasField(metadata, "description");
            
            Logger.info('Field validation - hasName: ${hasName}, hasType: ${hasType}, hasDescription: ${hasDescription}');
            
            if (!hasName || !hasType || !hasDescription) {
                Logger.warning('Invalid provisioner-collection.yml at ${metadataPath}: missing required fields');
                
                // For collection files, we'll try to recreate metadata from the path
                if (metadataPath.indexOf(PROVISIONER_METADATA_FILENAME) >= 0) {
                    Logger.info('Attempting to create metadata from provisioner path');
                    
                    // Extract type from directory name
                    var dirName = Path.withoutDirectory(Path.removeTrailingSlashes(path));
                    
                    // Create a default metadata based on path
                    var defaultMetadata = createDefaultMetadata(dirName, "");
                    Logger.info('Created default metadata from path: ${defaultMetadata.name}, ${defaultMetadata.type}');
                    
                    return defaultMetadata;
                }
                return null;
            }
            
            // Get basic fields
            var name:String = Reflect.field(metadata, "name");
            var type:String = Reflect.field(metadata, "type");
            var description:String = Reflect.field(metadata, "description");
            var author:Null<String> = Reflect.hasField(metadata, "author") ? Reflect.field(metadata, "author") : null;
            var version:Null<String> = Reflect.hasField(metadata, "version") ? Reflect.field(metadata, "version") : null;
            
                    // Parse configuration if it exists
                    var configuration:ProvisionerConfiguration = null;
                    if (Reflect.hasField(metadata, "configuration")) {
                        var configData:Dynamic = Reflect.field(metadata, "configuration");
                        Logger.info('Configuration data type: ${Type.typeof(configData)}');
                        
                        var basicFields = null;
                        var advancedFields = null;
                        
                        // Handle ObjectMap case
                        if (Std.isOfType(configData, ObjectMap)) {
                            var objMap:ObjectMap<String, Dynamic> = cast configData;
                            if (objMap.exists("basicFields")) {
                                basicFields = objMap.get("basicFields");
                                Logger.info('Found basicFields in ObjectMap, count: ${basicFields != null ? basicFields.length : 0}');
                            }
                            if (objMap.exists("advancedFields")) {
                                advancedFields = objMap.get("advancedFields");
                                Logger.info('Found advancedFields in ObjectMap, count: ${advancedFields != null ? advancedFields.length : 0}');
                            }
                        } 
                        // Handle standard object case
                        else if (Reflect.hasField(configData, "basicFields")) {
                            basicFields = Reflect.field(configData, "basicFields");
                            Logger.info('Found basicFields in standard object, count: ${basicFields != null ? basicFields.length : 0}');
                        
                            if (Reflect.hasField(configData, "advancedFields")) {
                                advancedFields = Reflect.field(configData, "advancedFields");
                                Logger.info('Found advancedFields in standard object, count: ${advancedFields != null ? advancedFields.length : 0}');
                            }
                        }
                        
                        configuration = {
                            basicFields: _parseFieldsArray(basicFields),
                            advancedFields: _parseFieldsArray(advancedFields)
                        };
                        
                        // Log the results to confirm
                        var basicParsedCount = configuration.basicFields != null ? configuration.basicFields.length : 0;
                        var advancedParsedCount = configuration.advancedFields != null ? configuration.advancedFields.length : 0;
                        Logger.info('Parsed configuration: basicFields=${basicParsedCount}, advancedFields=${advancedParsedCount}');
                    }
            
            // Parse roles if they exist
            var roles:Array<ProvisionerRole> = null;
            if (Reflect.hasField(metadata, "roles")) {
                var rolesData:Array<Dynamic> = Reflect.field(metadata, "roles");
                roles = _parseRolesArray(rolesData);
            }
            
            Logger.info('Successfully parsed collection metadata for ${name} (${type})');
            
            return {
                name: name,
                type: type,
                description: description,
                author: author,
                version: version,
                configuration: configuration,
                roles: roles
            };
        } catch (e) {
            Logger.error('Error reading provisioner-collection.yml at ${metadataPath}: ${e}');
            return null;
        }
    }
    
    /**
     * Read and parse version-specific provisioner metadata from provisioner.yml file inside a version directory
     * @param versionPath Path to the version directory (e.g. "/path/to/provisioner/0.1.23/")
     * @return ProvisionerMetadata|null Metadata if file exists and is valid, null otherwise
     */
    static public function readProvisionerVersionMetadata(versionPath:String):ProvisionerMetadata {
        var metadataPath = Path.addTrailingSlash(versionPath) + VERSION_METADATA_FILENAME;
        
        if (!FileSystem.exists(metadataPath)) {
            Logger.error('No version metadata file found at ${metadataPath}');
            return null;
        }
        
        try {
            var content = File.getContent(metadataPath);
            var previewLength:Int = cast Math.min(100, content.length);
            
            // Parse the YAML content
            var metadata:Dynamic = null;
            
            try {
                metadata = Yaml.read(metadataPath);
                
                if (metadata != null) {
                    // Check for ObjectMap type (common YAML parser output)
                    if (Std.isOfType(metadata, ObjectMap)) {
                        var objMap:ObjectMap<String, Dynamic> = cast metadata;
                        var keys = [for (k in objMap.keys()) k];
                        
                        // Create a standard object from ObjectMap for easier handling
                        var stdObj:Dynamic = {};
                        for (key in keys) {
                            Reflect.setField(stdObj, key, objMap.get(key));
                        }
                        metadata = stdObj;
                    }
                }
            } catch (yamlError) {
                Logger.error('YAML parsing error in version metadata: ${yamlError}');
                
                // Try a manual parsing as fallback
                var lines = content.split("\n");
                var manualMetadata:Dynamic = {};
                
                for (line in lines) {
                    // Skip comments and empty lines
                    var trimmed = StringTools.ltrim(line);
                    if (StringTools.startsWith(trimmed, "#") || StringTools.trim(line) == "") continue;
                    
                    // Find key-value pairs
                    var colonPos = line.indexOf(":");
                    if (colonPos > 0) {
                        var key = StringTools.trim(line.substr(0, colonPos));
                        var value = StringTools.trim(line.substr(colonPos + 1));
                        
                        // Remove quotes if present
                        if (StringTools.startsWith(value, '"') && value.length > 0 && value.charAt(value.length - 1) == '"') {
                            value = value.substr(1, value.length - 2);
                        }
                        
                        Reflect.setField(manualMetadata, key, value);
                    }
                }
                
                metadata = manualMetadata;
            }
            
            // Validate required fields
            var hasName = Reflect.hasField(metadata, "name");
            var hasType = Reflect.hasField(metadata, "type");
            var hasDescription = Reflect.hasField(metadata, "description");
            
            if (!hasName || !hasType || !hasDescription) {
                Logger.warning('Invalid provisioner.yml at ${metadataPath}: missing required fields');
                return null;
            }
            
            // Get basic fields
            var name:String = Reflect.field(metadata, "name");
            var type:String = Reflect.field(metadata, "type");
            var description:String = Reflect.field(metadata, "description");
            var author:Null<String> = Reflect.hasField(metadata, "author") ? Reflect.field(metadata, "author") : null;
            var version:Null<String> = Reflect.hasField(metadata, "version") ? Reflect.field(metadata, "version") : null;
            
            // Parse configuration if it exists with more detailed handling
            var configuration:ProvisionerConfiguration = null;
            if (Reflect.hasField(metadata, "configuration")) {
                var configData:Dynamic = Reflect.field(metadata, "configuration");
                
                var basicFields = null;
                var advancedFields = null;
                
                // Handle ObjectMap case
                if (Std.isOfType(configData, ObjectMap)) {
                    var objMap:ObjectMap<String, Dynamic> = cast configData;
                    if (objMap.exists("basicFields")) {
                        basicFields = objMap.get("basicFields");
                    }
                    if (objMap.exists("advancedFields")) {
                        advancedFields = objMap.get("advancedFields");
                    }
                } 
                // Handle standard object case
                else if (Reflect.hasField(configData, "basicFields")) {
                    basicFields = Reflect.field(configData, "basicFields");
                
                    if (Reflect.hasField(configData, "advancedFields")) {
                        advancedFields = Reflect.field(configData, "advancedFields");
                    }
                }
                
                // Parse fields arrays and create configuration
                configuration = {
                    basicFields: _parseFieldsArray(basicFields),
                    advancedFields: _parseFieldsArray(advancedFields)
                };
                
                // Log the results to confirm
                var basicParsedCount = configuration.basicFields != null ? configuration.basicFields.length : 0;
                var advancedParsedCount = configuration.advancedFields != null ? configuration.advancedFields.length : 0;
            }
            
            // Parse roles if they exist
            var roles:Array<ProvisionerRole> = null;
            if (Reflect.hasField(metadata, "roles")) {
                var rolesData:Array<Dynamic> = Reflect.field(metadata, "roles");
                roles = _parseRolesArray(rolesData);
            }
            
            return {
                name: name,
                type: type,
                description: description,
                author: author,
                version: version,
                configuration: configuration,
                roles: roles
            };
        } catch (e) {
            Logger.error('Error reading provisioner.yml at ${metadataPath}: ${e}');
            return null;
        }
    }
        
    /**
     * Parse an array of role definitions from the provisioner.yml file
     * @param rolesData The array of role data from the YAML file
     * @return Array<ProvisionerRole> The parsed role definitions
     */
    static private function _parseRolesArray(rolesData:Array<Dynamic>):Array<ProvisionerRole> {
        if (rolesData == null) {
            return [];
        }
        
        var result:Array<ProvisionerRole> = [];
        
        for (roleData in rolesData) {
            try {
                if (roleData == null) {
                    Logger.warning('Skipping null role data');
                    continue;
                }
                
                // Check if roleData is an ObjectMap
                if (Std.isOfType(roleData, ObjectMap)) {
                    var objMap:ObjectMap<String, Dynamic> = cast roleData;
                    
                    // Check for required fields
                    if (!objMap.exists("name") || !objMap.exists("label") || !objMap.exists("description")) {
                        Logger.warning('Skipping role with missing required properties: ${roleData}');
                        continue;
                    }
                    
                    var role:ProvisionerRole = {
                        name: objMap.get("name"),
                        label: objMap.get("label"),
                        description: objMap.get("description")
                    };
                    
                    // Add optional properties if they exist
                    if (objMap.exists("defaultEnabled")) {
                        role.defaultEnabled = objMap.get("defaultEnabled");
                    }
                    
                    // Add required property if it exists
                    if (objMap.exists("required")) {
                        role.required = objMap.get("required");
                    }
                    
                    // Add installers property if it exists
                    if (objMap.exists("installers")) {
                        var installersObj:ObjectMap<String, Dynamic> = objMap.get("installers");
                        role.installers = {
                            installer: installersObj.exists("installer") ? installersObj.get("installer") : false,
                            fixpack: installersObj.exists("fixpack") ? installersObj.get("fixpack") : false,
                            hotfix: installersObj.exists("hotfix") ? installersObj.get("hotfix") : false
                        };
                    }
                    
                    result.push(role);
                } 
                // Check for standard object with fields
                else if (!Reflect.hasField(roleData, "name") || !Reflect.hasField(roleData, "label") || !Reflect.hasField(roleData, "description")) {
                    Logger.warning('Skipping role with missing required properties: ${roleData}');
                    continue;
                } else {
                    var role:ProvisionerRole = {
                        name: Reflect.field(roleData, "name"),
                        label: Reflect.field(roleData, "label"),
                        description: Reflect.field(roleData, "description")
                    };
                    
                    // Add optional properties if they exist
                    if (Reflect.hasField(roleData, "defaultEnabled")) {
                        role.defaultEnabled = Reflect.field(roleData, "defaultEnabled");
                    }
                    
                    result.push(role);
                }
            } catch (e) {
                Logger.error('Error parsing role: ${e}');
            }
        }
        
        return result;
    }
    
    /**
     * Parse an array of field definitions from the provisioner.yml file
     * @param fieldsData The array of field data from the YAML file
     * @return Array<ProvisionerField> The parsed field definitions
     */
    static private function _parseFieldsArray(fieldsData:Array<Dynamic>):Array<ProvisionerField> {
        if (fieldsData == null) {
            return [];
        }
        
        var result:Array<ProvisionerField> = [];
        
        for (fieldData in fieldsData) {
            try {
                if (fieldData == null) {
                    Logger.warning('Skipping null field data');
                    continue;
                }
                
                // Check if the field has a name property
                var fieldName = null;
                var fieldType = "text"; // Default type
                var fieldLabel = null;
                
                // Try to get field properties using different methods
                try {
                    // First, check if fieldData is an ObjectMap
                    if (Std.isOfType(fieldData, ObjectMap)) {
                        var objMap:ObjectMap<String, Dynamic> = cast fieldData;
                        if (objMap.exists("name")) fieldName = objMap.get("name");
                        if (objMap.exists("type")) {
                            var typeValue = objMap.get("type");
                            fieldType = (typeValue != null && Std.string(typeValue).length > 0) ? Std.string(typeValue) : "text";
                        }
                        if (objMap.exists("label")) fieldLabel = objMap.get("label");
                        
                    }
                    // Check if fieldData has get method (ObjectMap interface)
                    else if (Reflect.hasField(fieldData, "get")) {
                        // Try to directly call the get method
                        try {
                            var getName = Reflect.field(fieldData, "get");
                            if (Reflect.isFunction(getName)) {
                                fieldName = Reflect.callMethod(fieldData, getName, ["name"]);
                                var typeValue = Reflect.callMethod(fieldData, getName, ["type"]);
                                fieldType = (typeValue != null && Std.string(typeValue).length > 0) ? Std.string(typeValue) : "text";
                                fieldLabel = Reflect.callMethod(fieldData, getName, ["label"]);
                                
                            }
                        } catch (e) {
                            Logger.error('Error calling get method: ${e}');
                        }
                    } else if (Reflect.hasField(fieldData, "name")) {
                        // It's an object with fields
                        fieldName = Reflect.field(fieldData, "name");
                        if (Reflect.hasField(fieldData, "type")) {
                            var typeValue = Reflect.field(fieldData, "type");
                            fieldType = (typeValue != null && Std.string(typeValue).length > 0) ? Std.string(typeValue) : "text";
                        }
                        if (Reflect.hasField(fieldData, "label")) fieldLabel = Reflect.field(fieldData, "label");
                        
                    } else if (Std.isOfType(fieldData, Dynamic) && fieldData.name != null) {
                        // It's a dynamic object with properties
                        fieldName = fieldData.name;
                        if (fieldData.type != null) {
                            var typeValue = fieldData.type;
                            fieldType = (typeValue != null && Std.string(typeValue).length > 0) ? Std.string(typeValue) : "text";
                        }
                        if (fieldData.label != null) fieldLabel = fieldData.label;
                        
                    }
                    
                } catch (e) {
                    Logger.error('Error extracting field properties: ${e}');
                }
                
                // Skip if no name found
                if (fieldName == null) {
                    Logger.warning('Skipping field with missing name property: ${fieldData}');
                    continue;
                }
                
                // Use name as label if label is missing
                if (fieldLabel == null) fieldLabel = fieldName;
                
                var field:ProvisionerField = {
                    name: fieldName,
                    type: fieldType,
                    label: fieldLabel
                };
                
                // Add optional properties if they exist
                // Try different ways to access properties
                function getProperty(obj:Dynamic, propName:String):Dynamic {
                    try {
                        // First, check if obj is an ObjectMap
                        if (Std.isOfType(obj, ObjectMap)) {
                            var objMap:ObjectMap<String, Dynamic> = cast obj;
                            if (objMap.exists(propName)) {
                                var value = objMap.get(propName);
                                return value;
                            }
                        }
                        // Check if obj has get method (ObjectMap interface)
                        else if (Reflect.hasField(obj, "get")) {
                            // Try to directly call the get method
                            try {
                                var getName = Reflect.field(obj, "get");
                                if (Reflect.isFunction(getName)) {
                                    var value = Reflect.callMethod(obj, getName, [propName]);
                                    return value;
                                }
                            } catch (e) {
                                Logger.error('Error calling get method for property ${propName}: ${e}');
                            }
                        } else if (Reflect.hasField(obj, propName)) {
                            var value = Reflect.field(obj, propName);
                            return value;
                        } else if (Std.isOfType(obj, Dynamic) && Reflect.getProperty(obj, propName) != null) {
                            var value = Reflect.getProperty(obj, propName);
                            return value;
                        }
                    } catch (e) {
                        Logger.error('Error getting property ${propName}: ${e}');
                    }
                    return null;
                }
                
                var defaultValue = getProperty(fieldData, "defaultValue");
                if (defaultValue != null) field.defaultValue = defaultValue;
                
                var required = getProperty(fieldData, "required");
                if (required != null) field.required = required;
                
                var validationKey = getProperty(fieldData, "validationKey");
                if (validationKey != null) field.validationKey = validationKey;
                
                var tooltip = getProperty(fieldData, "tooltip");
                if (tooltip != null) field.tooltip = tooltip;
                
                var placeholder = getProperty(fieldData, "placeholder");
                if (placeholder != null) field.placeholder = placeholder;
                
                var restrict = getProperty(fieldData, "restrict");
                if (restrict != null) field.restrict = restrict;
                
                // Process hidden property explicitly
                var hidden = getProperty(fieldData, "hidden");
                if (hidden != null) field.hidden = hidden;
                
                // Parse options for dropdown fields
                var optionsData = getProperty(fieldData, "options");
                if (optionsData != null && Std.isOfType(optionsData, Array)) {
                    field.options = [];
                    var optionsArray:Array<Dynamic> = cast optionsData;
                    
                    for (optionData in optionsArray) {
                        var optionValue = null;
                        var optionLabel = null;
                        
                        // Check if optionData is an ObjectMap
                        if (Std.isOfType(optionData, ObjectMap)) {
                            var objMap:ObjectMap<String, Dynamic> = cast optionData;
                            if (objMap.exists("value") && objMap.exists("label")) {
                                optionValue = objMap.get("value");
                                optionLabel = objMap.get("label");
                            }
                        } 
                        // Check if it's a standard object
                        else if (optionData != null && Reflect.hasField(optionData, "value") && Reflect.hasField(optionData, "label")) {
                            optionValue = Reflect.field(optionData, "value");
                            optionLabel = Reflect.field(optionData, "label");
                        }
                        
                        if (optionValue != null && optionLabel != null) {
                            field.options.push({
                                value: Std.string(optionValue),
                                label: Std.string(optionLabel)
                            });
                        } else {
                            Logger.warning('Skipping invalid option: ${optionData}');
                        }
                    }
                }
                
                // Parse min/max for number fields
                var minValue = getProperty(fieldData, "min");
                if (minValue != null) {
                    field.min = Std.parseFloat(Std.string(minValue));
                }
                
                var maxValue = getProperty(fieldData, "max");
                if (maxValue != null) {
                    field.max = Std.parseFloat(Std.string(maxValue));
                }
                
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
        if (type == ProvisionerType.StandaloneProvisioner) {
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
     * Get available provisioners from the cache
     * @param type Optional provisioner type filter
     * @return Array<ProvisionerDefinition> Array of available provisioners
     */
    static public function getBundledProvisioners(type:ProvisionerType = null):Array<ProvisionerDefinition> {
        // Initialize cache if needed
        if (_cachedProvisioners == null) {
            initializeCache();
        }
        
        // If no type specified, return all provisioners
        if (type == null) {
            var allProvisioners:Array<ProvisionerDefinition> = [];
            for (typeProvisioners in _cachedProvisioners) {
                for (provisioner in typeProvisioners) {
                    allProvisioners.push(provisioner);
                }
            }
            
            // Sort by version, newest first
            allProvisioners.sort((a, b) -> {
                var versionA = a.data.version;
                var versionB = b.data.version;
                return versionB > versionA ? 1 : (versionB < versionA ? -1 : 0);
            });
            
            return allProvisioners;
        }
        
        // Return provisioners of the specified type
        if (_cachedProvisioners.exists(type)) {
            // Return a copy to prevent modification of the cache
            return _cachedProvisioners.get(type).copy();
        }
        
        // No provisioners of this type found
        Logger.warning('No provisioners found for type ${type}');
        return [];
    }
    

    static public function getBundledProvisionerCollection( ?type:ProvisionerType ):ArrayCollection<ProvisionerDefinition> {

        var a = getBundledProvisioners(type);

        if ( type == null ) return new ArrayCollection( a );

        var c = new ArrayCollection<ProvisionerDefinition>();
        // Use string comparison for type checking to handle both enum and string values
        for ( p in a ) if ( Std.string(p.data.type) == Std.string(type) ) c.add( p );
        
        // If no matches found using direct type comparison, try case-insensitive comparison
        if (c.length == 0) {
            Logger.warning('No provisioners found for type ${type} using string comparison, trying case-insensitive comparison');
            
            var typeStr = Std.string(type).toLowerCase();
            for ( p in a ) {
                var pTypeStr = Std.string(p.data.type).toLowerCase();
                if (pTypeStr == typeStr) {
                    c.add(p);
                }
            }
        }
        
        // If still no matches AND this is a custom provisioner type, get ALL custom provisioners
        // This fixes cases where a custom provisioner type string isn't matching any available types
        if (c.length == 0) {
            var isStandardType = (Std.string(type) == Std.string(ProvisionerType.StandaloneProvisioner) || 
                                  Std.string(type) == Std.string(ProvisionerType.AdditionalProvisioner) ||
                                  Std.string(type) == Std.string(ProvisionerType.Default));
            
            if (!isStandardType) {
                Logger.warning('No matches for custom provisioner type ${type}, adding all custom provisioners as fallback');
                
                // Get all provisioners
                var allProvs = getBundledProvisioners();
                
                // Filter out standard provisioners
                for (p in allProvs) {
                    var pType = Std.string(p.data.type);
                    var isStandard = (pType == Std.string(ProvisionerType.StandaloneProvisioner) || 
                                     pType == Std.string(ProvisionerType.AdditionalProvisioner) ||
                                     pType == Std.string(ProvisionerType.Default));
                    
                    if (!isStandard) {
                        c.add(p);
                    }
                }
            }
        }
        
        // Log a detailed warning if still no matches found
        if (c.length == 0) {
            Logger.warning('No provisioners found for type ${type} after trying all matching methods');
            // Log all available provisioner types for debugging
            var availableTypes = [];
            for (p in a) availableTypes.push(Std.string(p.data.type));
            Logger.warning('Available provisioner types: ${availableTypes.join(", ")}');
        }
        
        return c;
    }

    static public function getProvisionerDefinition( type:ProvisionerType, version:VersionInfo ):Null<ProvisionerDefinition> {
        // First, try the most precise search - exact string match on type
        
        // Get all provisioners
        var allProvisioners = getBundledProvisioners();
        
        // First try: exact string match
        var typeProvisioners = allProvisioners.filter(p -> Std.string(p.data.type) == Std.string(type));
        
        // If no exact matches, try case-insensitive match
        if (typeProvisioners.length == 0) {
            var typeStr = Std.string(type).toLowerCase();
            typeProvisioners = allProvisioners.filter(p -> Std.string(p.data.type).toLowerCase() == typeStr);
        }
        
        // If we found provisioners of the requested type
        if (typeProvisioners.length > 0) {
            
            // Check for "empty" version by string representation to avoid null checks
            var versionStr = version.toString();
            if (versionStr == "0.0.0" || versionStr == "") {
                var result = typeProvisioners[0]; // Already sorted newest first
                
                // Make sure version-specific metadata is fully loaded
                if (result != null && result.root != null) {
                    var versionMetadata = readProvisionerVersionMetadata(result.root);
                    if (versionMetadata != null) {
                        // Update metadata to ensure configuration fields are available
                        result.metadata = versionMetadata;
                    }
                }
                
                return result;
            }
            
            // Otherwise, try to find the requested version
            for (provisioner in typeProvisioners) {
                if (provisioner.data.version.toString() == versionStr) {
                    
                    // Make sure version-specific metadata is fully loaded
                    if (provisioner != null && provisioner.root != null) {
                        var versionMetadata = readProvisionerVersionMetadata(provisioner.root);
                        if (versionMetadata != null) {
                            // Update metadata to ensure configuration fields are available
                            provisioner.metadata = versionMetadata;
                        }
                    }
                    
                    return provisioner;
                }
            }
            
            // If requested version not found, return the newest version
            var result = typeProvisioners[0];
            
            // Make sure version-specific metadata is fully loaded
            if (result != null && result.root != null) {
                var versionMetadata = readProvisionerVersionMetadata(result.root);
                if (versionMetadata != null) {
                    // Update metadata to ensure configuration fields are available
                    result.metadata = versionMetadata;
                }
            }
            
            return result;
        }
        
        // Log if we couldn't find any provisioners
        Logger.warning('No provisioners found for type ${type}');
        
        // Log all available types for debugging
        var availableTypes = [];
        for (p in allProvisioners) {
            availableTypes.push(Std.string(p.data.type));
        }
        Logger.warning('Available provisioner types: ${availableTypes.join(", ")}');
        
        // Return null with explicit Null<> return type to make it clear this can be null
        return null;
    }
    
    /**
     * Import a provisioner from a source directory to the common provisioners directory
     * This implementation zips the entire provisioner directory to handle deeply nested folder structures
     * @param sourcePath Path to the source provisioner directory
     * @return Bool True if import was successful, false otherwise
     */
    static public function importProvisioner(sourcePath:String):Bool {
        
        // Validate that the source directory contains a valid provisioner
        var metadata = readProvisionerMetadata(sourcePath);
        if (metadata == null) {
            Logger.error('Invalid provisioner at ${sourcePath}: missing or invalid provisioner-collection.yml');
            return false;
        }
        
        
        // Create the destination directory
        var destPath = Path.addTrailingSlash(getProvisionersDirectory()) + metadata.type;
        try {
            // Check if destination already exists
            var destDirExists = FileSystem.exists(destPath);
            
            // If destination exists, check if it has valid versions
            var hasValidVersions = false;
            if (destDirExists) {
                // Validate version directories in source
                var sourceVersionDirs = _getValidVersionDirectories(sourcePath);
                if (sourceVersionDirs.length == 0) {
                    Logger.warning('No valid version directories found in ${sourcePath}');
                    return false;
                }
                
                // Check if all versions already exist in destination
                var allVersionsExist = true;
                for (versionDir in sourceVersionDirs) {
                    var versionDestPath = Path.addTrailingSlash(destPath) + versionDir;
                    if (!FileSystem.exists(versionDestPath)) {
                        allVersionsExist = false;
                        break;
                    }
                }
                
                if (allVersionsExist) {
                    return true;
                }
            } else {
                // Create the destination directory if it doesn't exist
                FileSystem.createDirectory(destPath);
            }
            
            // Copy provisioner-collection.yml to the destination directory
            var sourceMetadataPath = Path.addTrailingSlash(sourcePath) + PROVISIONER_METADATA_FILENAME;
            var destMetadataPath = Path.addTrailingSlash(destPath) + PROVISIONER_METADATA_FILENAME;
            
            if (!FileSystem.exists(sourceMetadataPath)) {
                Logger.error('Provisioner metadata file not found at ${sourceMetadataPath}');
                return false;
            }
            
            File.copy(sourceMetadataPath, destMetadataPath);
            
            // Process and import version directories
            var sourceVersionDirs = _getValidVersionDirectories(sourcePath);
            if (sourceVersionDirs.length == 0) {
                Logger.warning('No valid version directories found in ${sourcePath}');
                return false;
            }
            
            var importedCount = 0;
            var skippedCount = 0;
            
            // Import each version directory using zip to handle deep nesting
            for (versionDir in sourceVersionDirs) {
                var versionSourcePath = Path.addTrailingSlash(sourcePath) + versionDir;
                var versionDestPath = Path.addTrailingSlash(destPath) + versionDir;
                
                // Skip if version already exists
                if (FileSystem.exists(versionDestPath)) {
                    skippedCount++;
                    continue;
                }
                
                try {
                    // Create the destination version directory
                    FileSystem.createDirectory(versionDestPath);
                    
                    // Zip the entire version directory
                    var zipBytes = _zipDirectory(versionSourcePath);
                    
                    // Unzip to the destination
                    _unzipToDirectory(zipBytes, versionDestPath);
                    
                    importedCount++;
                    Logger.info('Successfully imported version: ${versionDir}');
                } catch (e) {
                    Logger.error('Error importing version ${versionDir}: ${e}');
                    // Continue with other versions even if one fails
                }
            }
            
            Logger.info('Import summary: ${importedCount} versions imported, ${skippedCount} versions skipped');
            
            // Refresh the cache to include newly imported provisioners
            if (importedCount > 0) {
                _addProvisionerVersionsToCache(destPath, metadata);
                return true;
            } else if (skippedCount > 0) {
                // All versions already existed
                return true;
            } else {
                // No versions were imported
                return false;
            }
            
        } catch (e) {
            Logger.error('Error importing provisioner: ${e}');
            return false;
        }
    }
    
    /**
     * Get valid version directories from a provisioner directory
     * Valid versions must contain a scripts subdirectory
     * @param provisionerPath Path to the provisioner directory
     * @return Array<String> Array of valid version directory names
     */
    static private function _getValidVersionDirectories(provisionerPath:String):Array<String> {
        var validVersions = [];
        
        try {
            var items = FileSystem.readDirectory(provisionerPath);
            
            for (item in items) {
                // Skip if not a directory or if it's one of the metadata files
                if (!FileSystem.isDirectory(Path.addTrailingSlash(provisionerPath) + item) || 
                    item == PROVISIONER_METADATA_FILENAME ||
                    item == VERSION_METADATA_FILENAME) {
                    continue;
                }
                
                // Check if this is a valid version directory (has scripts subdirectory)
                var scriptsPath = Path.addTrailingSlash(provisionerPath) + Path.addTrailingSlash(item) + "scripts";
                if (FileSystem.exists(scriptsPath) && FileSystem.isDirectory(scriptsPath)) {
                    validVersions.push(item);
                } else {
                    Logger.warning('Invalid version directory (no scripts folder): ${item}');
                }
            }
        } catch (e) {
            Logger.error('Error reading directory ${provisionerPath}: ${e}');
        }
        
        return validVersions;
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
     * Uses no compression to avoid ZLib errors with deeply nested paths
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
                // Add file entry without compression
                try {
                    var data = File.getBytes(itemPath);
                    var entry:Entry = {
                        fileName: zipPath,
                        fileSize: data.length,
                        fileTime: FileSystem.stat(itemPath).mtime,
                        compressed: false, // No compression
                        dataSize: data.length,
                        data: data,
                        crc32: haxe.crypto.Crc32.make(data)
                    };
                    // Skip compression completely
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
