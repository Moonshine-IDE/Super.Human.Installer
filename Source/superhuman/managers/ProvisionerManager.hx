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
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import openfl.events.ProgressEvent;
import openfl.net.URLLoader;
import openfl.net.URLLoaderDataFormat;
import openfl.net.URLRequest;
import openfl.net.URLRequestHeader;
import openfl.utils.ByteArray;
import haxe.io.Path;
import haxe.zip.Entry;
import haxe.zip.Reader;
import haxe.zip.Tools;
import haxe.zip.Writer;
import lime.system.System;
import openfl.filesystem.File;
import superhuman.server.definitions.ProvisionerDefinition;
import superhuman.server.provisioners.ProvisionerType;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
import yaml.Yaml;
import yaml.util.ObjectMap;
import genesis.application.managers.ToastManager;

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
                
                // For future provisioners, scripts files will be in the main directory
                // For backwards compatibility, we'll check for scripts directory but not require it
                var scriptsPath = Path.addTrailingSlash(versionPath) + "scripts";
                var hasScriptsDir = FileSystem.exists(scriptsPath) && FileSystem.isDirectory(scriptsPath);
                Logger.info('Version directory ${versionDir}: ${hasScriptsDir ? "has" : "does not have"} scripts folder');
                
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
                    
                    // Check if this version already exists in the cache
                    var versionExists = false;
                    var cachedVersions = _cachedProvisioners.get(metadata.type);
                    
                    for (existingDef in cachedVersions) {
                        if (existingDef.data.version.toString() == versionInfo.toString()) {
                            Logger.info('Version ${versionDir} of ${metadata.type} already exists in cache, updating definition');
                            // Update the existing definition with the new path and metadata
                            existingDef.root = versionPath;
                            existingDef.metadata = versionMetadata;
                            versionExists = true;
                            break;
                        }
                    }
                    
                    // Only add to the cache if it doesn't already exist
                    if (!versionExists) {
                        _cachedProvisioners.get(metadata.type).push(provDef);
                        Logger.info('Added provisioner to cache: ${provDef.name}, type: ${metadata.type}, version: ${versionDir}');
                    }
                    
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
                    
                    // Copy the directory directly using Windows long path support
                    Logger.info('Copying version directory ${versionDir} using direct file copy');
                    _copyDirectoryRecursive(versionSourcePath, versionDestPath);
                    
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
     * Import a specific provisioner version into an existing or new collection
     * @param sourcePath Path to the version directory containing provisioner.yml and scripts
     * @return Bool Success or failure
     */
    static public function importProvisionerVersion(sourcePath:String):Bool {
        // First, validate that the source directory contains a valid provisioner version
        if (!FileSystem.exists(sourcePath) || !FileSystem.isDirectory(sourcePath)) {
            Logger.error('Invalid path: ${sourcePath} is not a directory');
            return false;
        }
        
        // Check for provisioner.yml file
        var versionMetadataPath = Path.addTrailingSlash(sourcePath) + VERSION_METADATA_FILENAME;
        if (!FileSystem.exists(versionMetadataPath)) {
            Logger.error('Version directory is missing provisioner.yml at ${versionMetadataPath}');
            return false;
        }
        
        // For backward compatibility, check for scripts directory but don't require it
        var scriptsDir = Path.addTrailingSlash(sourcePath) + "scripts";
        var hasScriptsDir = FileSystem.exists(scriptsDir) && FileSystem.isDirectory(scriptsDir);
        Logger.info('Version directory ${hasScriptsDir ? "has" : "does not have"} scripts folder: ${scriptsDir}');
        
        // Read the version metadata
        var versionMetadata = readProvisionerVersionMetadata(sourcePath);
        if (versionMetadata == null) {
            Logger.error('Failed to read version metadata from ${versionMetadataPath}');
            return false;
        }
        
        // Extract the provisioner type from the version metadata
        if (versionMetadata.type == null) {
            Logger.error('Version metadata is missing required "type" field');
            return false;
        }
        
        // Check if a version identifier is available - prioritize the metadata version field
        var versionId:String = null;
        
        // First check for the version field in the metadata (even if it's a number, convert to string)
        if (versionMetadata.version != null) {
            // Ensure version is treated as a string (in case it was parsed as a number from YAML)
            versionId = Std.string(versionMetadata.version);
            Logger.info('Using version from provisioner.yml metadata: ${versionId}');
        } else {
            // Fallback to directory name if it looks like a version number
            var dirName = Path.withoutDirectory(Path.removeTrailingSlashes(sourcePath));
            var versionRegex = ~/^\d+(\.\d+)*$/;
            
            if (versionRegex.match(dirName)) {
                versionId = dirName;
                Logger.info('No version field in metadata, using directory name as version: ${versionId}');
            } else {
                // No version identifier found
                Logger.error('Cannot determine version ID for import. Directory name is not a version number and metadata has no version field.');
                return false;
            }
        }
        
        // Now that we have the type and version, we need to find or create the collection
        var provisionersDir = getProvisionersDirectory();
        var collectionPath = Path.addTrailingSlash(provisionersDir) + versionMetadata.type;
        var collectionMetadataPath = Path.addTrailingSlash(collectionPath) + PROVISIONER_METADATA_FILENAME;
        var collectionExists = FileSystem.exists(collectionPath) && FileSystem.isDirectory(collectionPath);
        var collectionMetadataExists = FileSystem.exists(collectionMetadataPath);
        
        // Check if the destination version directory already exists
        var versionDestPath = Path.addTrailingSlash(collectionPath) + versionId;
        if (FileSystem.exists(versionDestPath)) {
            // Version already exists, show a toast notification
            ToastManager.getInstance().showToast('Version ${versionId} already exists in the ${versionMetadata.type} collection');
            return false;
        }
        
        // Create or update the collection
        if (!collectionExists) {
            // Create the collection directory
            try {
                FileSystem.createDirectory(collectionPath);
                Logger.info('Created new collection directory at ${collectionPath}');
            } catch (e) {
                Logger.error('Failed to create collection directory: ${e}');
                return false;
            }
            
            // Create a collection metadata file based on the version metadata
            var collectionMetadata:ProvisionerMetadata = {
                name: versionMetadata.name,
                type: versionMetadata.type,
                description: versionMetadata.description,
                author: versionMetadata.author
            };
            
            try {
                _writeYamlFile(collectionMetadataPath, collectionMetadata);
                Logger.info('Created collection metadata at ${collectionMetadataPath}');
            } catch (e) {
                Logger.error('Failed to create collection metadata: ${e}');
                return false;
            }
        } else if (!collectionMetadataExists) {
            // Collection directory exists but no metadata file, create one
            var collectionMetadata:ProvisionerMetadata = {
                name: versionMetadata.name,
                type: versionMetadata.type,
                description: versionMetadata.description,
                author: versionMetadata.author
            };
            
            try {
                _writeYamlFile(collectionMetadataPath, collectionMetadata);
                Logger.info('Created missing collection metadata at ${collectionMetadataPath}');
            } catch (e) {
                Logger.error('Failed to create missing collection metadata: ${e}');
                return false;
            }
        }
        
        // Now import the version into the collection
        try {
            // Create the destination version directory
            FileSystem.createDirectory(versionDestPath);
            
            // Use direct file copying with Windows long path support
            Logger.info('Copying version directory using direct file copy');
            _copyDirectoryRecursive(sourcePath, versionDestPath);
            
            Logger.info('Successfully imported version ${versionId} into collection ${versionMetadata.type}');
            
            // If we have a collection metadata, refresh the cache
            var collectionMetadata = readProvisionerMetadata(collectionPath);
            if (collectionMetadata != null) {
                _addProvisionerVersionsToCache(collectionPath, collectionMetadata);
            }
            
            return true;
        } catch (e) {
            Logger.error('Error importing version: ${e}');
            return false;
        }
    }
    
    /**
     * Write a YAML file with the given content
     * @param filePath Path to the file to write
     * @param content Content to write in YAML format
     */
    static private function _writeYamlFile(filePath:String, content:Dynamic):Void {
        // Create a YAML string manually since the Yaml library doesn't have a good writer
        var yamlStr = "# Provisioner Collection Metadata\n";
        
        for (field in Reflect.fields(content)) {
            var value = Reflect.field(content, field);
            if (value != null) {
                yamlStr += '${field}: ${value}\n';
            }
        }
        
        File.saveContent(filePath, yamlStr);
    }
    
    /**
     * Import a provisioner from GitHub
     * @param organization GitHub organization or username
     * @param repository Repository name
     * @param branch Branch name (defaults to "main")
     * @param useGit Whether to use git clone instead of HTTP download
     * @param tokenName Name of GitHub token to use from secrets (optional)
     * @return Bool Success or failure
     */
    static public function importProvisionerFromGitHub(
        organization:String, 
        repository:String, 
        branch:String = "main", 
        useGit:Bool = false,
        tokenName:String = null
    ):Bool {
        Logger.info('Importing provisioner from GitHub: ${organization}/${repository} branch ${branch}');
        
        var success = false;
        var shortTempDirPath = null; // For Windows, this will be C:/Users/Username/repo/
        var repoDir = null; // Directory where we'll find the repository contents
        
        try {
            // Find GitHub token if specified
            var token:String = null;
            if (tokenName != null && tokenName != "") {
                var secrets = SuperHumanInstaller.getInstance().config.secrets;
                if (secrets != null && secrets.git_api_keys != null) {
                    for (gitToken in secrets.git_api_keys) {
                        if (gitToken.name == tokenName) {
                            token = gitToken.key;
                            break;
                        }
                    }
                }
                
                if (token == null) {
                    Logger.warning('Specified GitHub token "${tokenName}" not found in secrets');
                }
            }
            
            // Set up temporary paths for cloning
            if (Sys.systemName() == "Windows") {
                var username = Sys.getEnv("USERNAME");
                if (username != null && username != "") {
                    // Always use C:/Users/Username/repo on Windows
                    shortTempDirPath = 'C:/Users/${username}/repo/';
                    
                    // Make sure it exists
                    if (!FileSystem.exists(shortTempDirPath)) {
                        try {
                            FileSystem.createDirectory(shortTempDirPath);
                        } catch (e) {
                            Logger.error('Failed to create repo directory at ${shortTempDirPath}: ${e}');
                            return false;
                        }
                    }
                } else {
                    Logger.error('Could not determine Windows username for repo path');
                    return false;
                }
            } else {
                // For non-Windows, create a temporary directory in the system temp
                var timestamp = Date.now().getTime();
                shortTempDirPath = Path.addTrailingSlash(System.applicationStorageDirectory) + 
                                   "temp_" + repository + "_" + timestamp + "/";
                try {
                    if (!FileSystem.exists(shortTempDirPath)) {
                        FileSystem.createDirectory(shortTempDirPath);
                    }
                } catch (e) {
                    Logger.error('Failed to create temporary directory: ${e}');
                    return false;
                }
            }
            
            // Download the repository directly to the temporary directory
            if (useGit) {
                Logger.info('Using git clone with recursive submodules and longpaths support');
                var gitResult = _downloadWithGit(organization, repository, branch, shortTempDirPath, token);
                success = gitResult.success;
                
                // For Git clone, the repo is directly in the shortTempDirPath
                repoDir = shortTempDirPath;
            } else {
                // Create an extracted subdirectory for HTTP download
                var extractDir = Path.addTrailingSlash(shortTempDirPath) + "extracted";
                if (!FileSystem.exists(extractDir)) {
                    FileSystem.createDirectory(extractDir);
                }
                
                success = _downloadWithHttp(organization, repository, branch, shortTempDirPath, token);
                repoDir = Path.addTrailingSlash(shortTempDirPath) + "extracted"; // With HTTP, the repo is in the extracted subdirectory
            }
            
            if (!success) {
                Logger.error('Failed to download GitHub repository');
                if (shortTempDirPath != null && FileSystem.exists(shortTempDirPath)) {
                    Logger.info('Cleaning up temporary directory: ${shortTempDirPath}');
                    _safeDeleteDirectory(shortTempDirPath);
                }
                return false;
            }
            
            Logger.info('Repository downloaded, searching for provisioner in: ${repoDir}');
            
            // Check the repository structure using the actual repository name for better matching
                // List directory contents for debugging
            try {
                var items = FileSystem.readDirectory(repoDir);
                Logger.info('Repository directory contents:');
                for (item in items) {
                    var isDir = FileSystem.isDirectory(Path.addTrailingSlash(repoDir) + item);
                    Logger.info('  - ${item} (isDirectory: ${isDir})');
                }
            } catch (e) {
                Logger.error('Error listing repository contents: ${e}');
            }
            
            Logger.info('Searching for provisioner root structure in cloned repository...');
            var provisionerPath = _findProvisionerRoot(repoDir, repository);
            if (provisionerPath == null) {
                Logger.error('Could not find valid provisioner structure in the repository');
                if (shortTempDirPath != null && FileSystem.exists(shortTempDirPath)) {
                    Logger.info('Cleaning up temporary directory: ${shortTempDirPath}');
                    _safeDeleteDirectory(shortTempDirPath);
                }
                return false;
            }
            
            Logger.info('Found provisioner structure at: ${provisionerPath}');
            
            // Determine if this is a collection or a single version
            var isCollection = FileSystem.exists(Path.addTrailingSlash(provisionerPath) + PROVISIONER_METADATA_FILENAME);
            
            if (isCollection) {
                // Import as a collection
                Logger.info('Importing GitHub repository as a provisioner collection');
                success = importProvisioner(provisionerPath);
            } else {
                // Import as a version
                Logger.info('Importing GitHub repository as a provisioner version');
                success = importProvisionerVersion(provisionerPath);
            }
            
            // Clean up temporary files - ensure this happens regardless of the import success
            Logger.info('Cleaning up temporary directories after import');
            if (shortTempDirPath != null) {
                try {
                    if (FileSystem.exists(shortTempDirPath)) {
                        Logger.info('Cleaning up temporary directory: ${shortTempDirPath}');
                        
                        // On Windows, the repo directory is specifically at C:/Users/Username/repo
                        // We need to take special care with cleanup in this case
                        if (Sys.systemName() == "Windows") {
                            // Force cleanup of Windows repo directory - this is important!
                            _forceCleanupWindowsRepoDir(shortTempDirPath);
                        } else {
                            // For non-Windows, use the standard cleanup
                            _safeDeleteDirectory(shortTempDirPath);
                            
                            // Also clean up any nested repo directory
                            var shortTempRepoDir = Path.addTrailingSlash(shortTempDirPath) + "repo";
                            if (FileSystem.exists(shortTempRepoDir)) {
                                Logger.info('Cleaning up short temp repo directory: ${shortTempRepoDir}');
                                _deleteDirectory(shortTempRepoDir);
                            }
                        }
                    } else {
                        Logger.info('Temporary directory does not exist, no cleanup needed: ${shortTempDirPath}');
                    }
                } catch (e) {
                    Logger.warning('Failed to clean up temporary directories: ${e}');
                }
            }
            
            return success;
        } catch (e) {
            Logger.error('Error importing from GitHub: ${e}');
            if (shortTempDirPath != null && FileSystem.exists(shortTempDirPath)) {
                Logger.info('Cleaning up temporary directory: ${shortTempDirPath}');
                _safeDeleteDirectory(shortTempDirPath);
            }
            return false;
        }
    }
    
    /**
     * Download a GitHub repository using HTTP (ZIP download)
     * Uses OpenFL's URLLoader with a synchronous wait
     */
    static private function _downloadWithHttp(
        organization:String, 
        repository:String, 
        branch:String, 
        destinationDir:String,
        token:String = null
    ):Bool {
        // Create URL for the ZIP download
        var url = 'https://github.com/${organization}/${repository}/archive/refs/heads/${branch}.zip';
        Logger.info('Downloading GitHub repository via HTTP: ${organization}/${repository} branch ${branch}');
        Logger.info('Download URL: ${url}');
        
        var zipPath = Path.addTrailingSlash(destinationDir) + "repo.zip";
        var extractDir = Path.addTrailingSlash(destinationDir) + "extracted";
        if (!FileSystem.exists(extractDir)) {
            FileSystem.createDirectory(extractDir);
        }
        
        // Status flags
        var success = false;
        var done = false;
        var downloadError = null;
        
        try {
            // Create URL request with optional auth header
            var request = new URLRequest(url);
            if (token != null && token.length > 0) {
                Logger.info('Using GitHub token for authentication');
                request.requestHeaders = [
                    new URLRequestHeader("Authorization", 'token ${token}')
                ];
            }
            
            // Set up loader and event handlers
            var loader = new URLLoader();
            loader.dataFormat = URLLoaderDataFormat.BINARY;
            
            loader.addEventListener(Event.COMPLETE, function(e:Event) {
                try {
                    Logger.info('Download complete, saving to ${zipPath}');
                    var data:ByteArray = cast(loader.data, ByteArray);
                    var bytes = Bytes.ofData(data);
                    File.saveBytes(zipPath, bytes);
                    success = true;
                } catch (e) {
                    Logger.error('Error saving downloaded file: ${e}');
                    success = false;
                }
                done = true;
            });
            
            loader.addEventListener(IOErrorEvent.IO_ERROR, function(e:IOErrorEvent) {
                Logger.error('Error downloading file: ${e.text}');
                downloadError = e.text;
                success = false;
                done = true;
            });
            
            loader.addEventListener(ProgressEvent.PROGRESS, function(e:ProgressEvent) {
                if (e.bytesTotal > 0) {
                    var percent = Math.round((e.bytesLoaded / e.bytesTotal) * 100);
                    Logger.info('Download progress: ${percent}% (${e.bytesLoaded}/${e.bytesTotal} bytes)');
                }
            });
            
            // Start the download
            Logger.info('Starting download from ${url}');
            loader.load(request);
            
            // Wait for download to complete with timeout
            var startTime = Date.now().getTime();
            var timeout = 10 * 60 * 1000; // 10 minutes
            
            // Simple blocking wait
            while (!done) {
                Sys.sleep(0.2); // Sleep for 200ms
                
                var currentTime = Date.now().getTime();
                if (currentTime - startTime > timeout) {
                    Logger.error('Download timed out after ${timeout/1000} seconds');
                    return false;
                }
            }
            
            // Check if download completed successfully
            if (!success) {
                Logger.error('Download failed: ${downloadError != null ? downloadError : "Unknown error"}');
                return false;
            }
            
            // Extract zip file
            if (!FileSystem.exists(zipPath)) {
                Logger.error('ZIP file not found after download: ${zipPath}');
                return false;
            }
            
            // Read and extract the ZIP file
            Logger.info('Extracting ZIP file to ${extractDir}');
            try {
                var zipBytes = File.getBytes(zipPath);
                var zipEntries = Reader.readZip(new BytesInput(zipBytes));
                
                Logger.info('ZIP file contains ${zipEntries.length} entries');
                
                // Extract all files
                var extractedCount = 0;
                for (entry in zipEntries) {
                    // Skip directories
                    if (StringTools.endsWith(entry.fileName, "/")) {
                        var dirPath = Path.addTrailingSlash(extractDir) + entry.fileName;
                        _createDirectoryRecursive(dirPath);
                        continue;
                    }
                    
                    // Create parent directories if needed
                    var filePath = Path.addTrailingSlash(extractDir) + entry.fileName;
                    var parentDir = Path.directory(filePath);
                    _createDirectoryRecursive(parentDir);
                    
                    // Extract the file
                    try {
                        if (entry.compressed) {
                            haxe.zip.Tools.uncompress(entry);
                        }
                        File.saveBytes(filePath, entry.data);
                        extractedCount++;
                    } catch (e) {
                        Logger.warning('Failed to extract file ${entry.fileName}: ${e}');
                    }
                }
                
                Logger.info('Successfully extracted ${extractedCount} files');
                
                // Verify the extraction was successful
                if (extractedCount > 0) {
                    // Try to find the extracted repository directory - usually in {repository}-{branch} format
                    try {
                        var files = FileSystem.readDirectory(extractDir);
                        var repoFound = false;
                        
                        for (file in files) {
                            var filePath = Path.addTrailingSlash(extractDir) + file;
                            if (FileSystem.isDirectory(filePath) && file.indexOf(repository) >= 0) {
                                Logger.info('Found extracted repository directory: ${file}');
                                repoFound = true;
                                break;
                            }
                        }
                        
                        if (!repoFound) {
                            Logger.warning('Could not find repository directory in extracted files - proceeding anyway');
                        }
                    } catch (e) {
                        Logger.warning('Error checking extracted directory: ${e} - proceeding anyway');
                    }
                    
                    return true;
                } else {
                    Logger.error('No files were extracted from the ZIP');
                    return false;
                }
            } catch (e) {
                Logger.error('Error extracting ZIP file: ${e}');
                return false;
            }
        } catch (e) {
            Logger.error('Error during HTTP download: ${e}');
            return false;
        }
    }
    
    /**
     * Download a GitHub repository using git clone with support for recursive submodules
     * and a shorter path to handle Windows path length limitations
     * @return {success:Bool, shortTempPath:String} Returns both success status and the short temp path used
     */
    static private function _downloadWithGit(
        organization:String, 
        repository:String, 
        branch:String, 
        destinationDir:String,
        token:String = null
    ):{success:Bool, shortTempPath:String} {
        Logger.info('Downloading GitHub repository via git clone: ${organization}/${repository} branch ${branch}');
        
        // Define variables for temporary paths
        var shortTempDir = null;
        var shortTempRepoDir = null;
        
        // CRITICAL: On Windows, we ONLY use C:/Users/Username/repo - no other paths, no subdirectories, no fallbacks
        // This is mandatory to handle Windows path length limitations - DO NOT MODIFY THIS BEHAVIOR
        if (Sys.systemName() == "Windows") {
            // Get username from environment
            var username = Sys.getEnv("USERNAME");
            if (username != null && username != "") {
                // Create ONLY C:/Users/Username/repo - exactly this path and nothing else, this is  critical to ONLY use this path, we CANNOT use ANYTHING ELSE EVER!!!
                shortTempDir = 'C:/Users/${username}/repo/';
                
                // Create repo directory if it doesn't exist
                try {
                    if (!FileSystem.exists(shortTempDir)) {
                        FileSystem.createDirectory(shortTempDir);
                    }
                } catch(e) {
                    Logger.error('Failed to create directory at ${shortTempDir}: ${e}');
                    return {success: false, shortTempPath: null};
                }
            } else {
                Logger.error('Could not determine Windows username');
                return {success: false, shortTempPath: null};
            }
        } else {
            // For Mac/Linux, use application storage directory
            var timestamp = Date.now().getTime();
            shortTempDir = Path.addTrailingSlash(System.applicationStorageDirectory) + repository + "_" + timestamp + "/";
            
            try {
                if (!FileSystem.exists(shortTempDir)) {
                    FileSystem.createDirectory(shortTempDir);
                    Logger.info('Created temporary directory: ${shortTempDir}');
                }
            } catch(e) {
                Logger.error('Failed to create directory at ${shortTempDir}: ${e}');
                return {success: false, shortTempPath: null};
            }
        }
        
        try {
            // Build the clone URL
            var cloneUrl = "";
            if (token != null) {
                // Use HTTPS with token for authentication
                cloneUrl = 'https://${token}@github.com/${organization}/${repository}.git';
            } else {
                // Use plain HTTPS for public repos
                cloneUrl = 'https://github.com/${organization}/${repository}.git';
            }
            
            // Enable long paths in git for Windows to avoid path length limitations
            Logger.info('Configuring git for long paths');
            Sys.command('git config --global core.longpaths true');
            
            // Single command for cloning with recursive submodules and longpaths enabled
            Logger.info('Performing git clone with recursive submodules to shorter path');
            
            // For Windows, use a single command approach with better error handling
            if (Sys.systemName() == "Windows") {
                // On Windows: Ensure the path is properly formatted with backslashes and no trailing slash
                var windowsSafePath = StringTools.replace(shortTempDir, "/", "\\");
                windowsSafePath = StringTools.trim(windowsSafePath); // Remove any trailing whitespace
                if (StringTools.endsWith(windowsSafePath, "\\")) {
                    windowsSafePath = windowsSafePath.substr(0, windowsSafePath.length - 1); // Remove trailing backslash
                }
                
                var cloneCmd = 'git -c core.longpaths=true clone --depth 1 --recursive --branch ${branch} ${cloneUrl} "${windowsSafePath}"';
                Logger.info('Executing single git clone command for Windows: ${cloneCmd}');
                
                // Use Process instead of Sys.command to capture output
                var process = new sys.io.Process(cloneCmd);
                var exitCode = process.exitCode();
                
                // Capture and log stdout
                var output = process.stdout.readAll().toString();
                if (output != null && output.length > 0) {
                    var lines = output.split("\n");
                    for (line in lines) {
                        if (StringTools.trim(line).length > 0) {
                            Logger.info('Git output: ${line}');
                        }
                    }
                }
                
                // Capture and log stderr
                var error = process.stderr.readAll().toString();
                if (error != null && error.length > 0) {
                    var lines = error.split("\n");
                    for (line in lines) {
                        if (StringTools.trim(line).length > 0) {
                            Logger.info('Git: ${line}');
                        }
                    }
                }
                
                // Close the process
                process.close();
                
                if (exitCode != 0) {
                    Logger.error('Failed to clone GitHub repository, exit code: ${exitCode}');
                    
                    // For Windows, we just try to clean up and call again - no fancy uniqueName handling since we always use C:/Users/Username/repo
                    if (error != null && error.indexOf("destination path") >= 0 && error.indexOf("already exists") >= 0) {
                        Logger.warning('Detected "destination path already exists" error. Directory appears to exist to Git but may not be visible to standard APIs.');
                        
                        // Clean up the repo directory if possible before retrying
                        try {
                            _deleteDirectory(shortTempDir);
                            Logger.info('Cleared repo directory, retrying the git clone operation');
                        } catch (e) {
                            Logger.warning('Could not clean up repo directory: ${e}');
                        }
                        
                        // Try again with the same directory - it should be clean now
                        return _downloadWithGit(organization, repository, branch, destinationDir, token);
                    }
                    
                    return {success: false, shortTempPath: shortTempDir};
                }
            } else {
                // For macOS/Linux, a single command approach with output logging
                var cloneCmd = 'git clone --depth 1 --recursive --branch ${branch} ${cloneUrl} ${shortTempDir}/repo';
                Logger.info('Executing git clone command: ${cloneCmd}');
                
                // Use Process instead of Sys.command to capture output
                var process = new sys.io.Process(cloneCmd);
                var exitCode = process.exitCode();
                
                // Capture and log stdout
                var output = process.stdout.readAll().toString();
                if (output != null && output.length > 0) {
                    var lines = output.split("\n");
                    for (line in lines) {
                        if (StringTools.trim(line).length > 0) {
                            Logger.info('Git output: ${line}');
                        }
                    }
                }
                
                // Capture and log stderr
                var error = process.stderr.readAll().toString();
                if (error != null && error.length > 0) {
                    var lines = error.split("\n");
                    for (line in lines) {
                            if (StringTools.trim(line).length > 0) {
                                Logger.warning('Git error: ${line}');
                        }
                    }
                }
                
                // Close the process
                process.close();
                
                if (exitCode != 0) {
                    Logger.error('Failed to clone GitHub repository, exit code: ${exitCode}');
                    
                    // Clean up the temporary directory
                    try {
                        _deleteDirectory(shortTempDir);
                    } catch (e) {
                        Logger.warning('Failed to clean up temporary directory: ${e}');
                    }
                    
                    return {success: false, shortTempPath: shortTempDir};
                }
            }
            
            // The repo has been successfully cloned to the shortTempDir, 
            // no need to move it again since it will be processed by importProvisioner/importProvisionerVersion
            Logger.info('Clone successful. Repository is available at ${shortTempDir}');
            
            // We don't need to zip/unzip here as that will be handled 
            // during the actual import operation if needed
            return {success: true, shortTempPath: shortTempDir};
        } catch (e) {
            Logger.error('Error during git clone: ${e}');
            return {success: false, shortTempPath: null};
        }
    }
    
    /**
     * Check if a directory is writable by attempting to create a test file
     * @param directory Directory to check
     * @return Bool true if directory is writable
     */
    static private function _canWriteToDirectory(directory:String):Bool {
        if (!FileSystem.exists(directory)) {
            return false;
        }
        
        var testFile = Path.addTrailingSlash(directory) + ".write_test_" + Date.now().getTime();
        try {
            File.saveContent(testFile, "test");
            FileSystem.deleteFile(testFile);
            return true;
        } catch (e) {
            return false;
        }
    }
    
    /**
     * Copy a directory and all its contents with Windows long path support
     * This uses OpenFL's File.copyTo to copy entire directory trees at once
     * @param source Source directory path
     * @param destination Destination directory path
     */
    static private function _copyDirectoryRecursive(source:String, destination:String):Void {
        // Source validation
        if (!FileSystem.exists(source)) {
            Logger.error('Source directory does not exist: ${source}');
            throw new haxe.Exception('Source directory does not exist: ${source}');
        }
        
        if (!FileSystem.isDirectory(source)) {
            Logger.error('Source path is not a directory: ${source}');
            throw new haxe.Exception('Source path is not a directory: ${source}');
        }
        
        // Ensure destination parent directory exists
        var destParent = Path.directory(destination);
        if (!FileSystem.exists(destParent)) {
            try {
                // Use platform path for directory creation
                var platformDestParent = _getPlatformPath(destParent);
                Logger.info('Creating destination parent directory: ${destParent}');
                _createDirectoryRecursiveWithPlatformPath(platformDestParent);
            } catch (e) {
                Logger.error('Failed to create destination parent directory: ${destParent} - ${e}');
                throw e;
            }
        }
        
        // Copy the entire directory at once using OpenFL's File.copyTo method
        try {
            Logger.info('Copying directory ${source} to ${destination} using OpenFL File.copyTo');
            
            // Create OpenFL File objects for source and destination
            var sourceDir = new openfl.filesystem.File(source);
            var destDir = new openfl.filesystem.File(destination);
            
            // Copy the entire directory tree in one operation
            sourceDir.copyTo(destDir, true); // true to overwrite if destination exists
            
            Logger.info('Directory copy completed successfully');
        } catch (e) {
            Logger.error('Error during directory copy operation: ${e}');
            throw e;
        }
    }
    
    /**
     * Copy a directory and all its contents using direct file copy with Windows long path support
     * This method is kept for backward compatibility, but now uses direct file copying instead of zip/unzip
     * @param source Source directory path
     * @param destination Destination directory path
     */
    static private function _copyDirectoryViaZip(source:String, destination:String):Void {
        Logger.info('Copying directory ${source} to ${destination} (using direct file copy)');
        _copyDirectoryRecursive(source, destination);
    }
    
    /**
     * Find the root directory of a provisioner in the repository
     * @param repositoryPath Path to the repository
     * @param actualRepositoryName Optional name of the repository for better matching
     * @return String|null Path to the provisioner root, or null if not found
     */
    static private function _findProvisionerRoot(repositoryPath:String, actualRepositoryName:String = null):String {
        Logger.info('Searching for provisioner root in: ${repositoryPath}');
        
        // First, check if the repo root itself is a provisioner
        if (_isProvisionerDirectory(repositoryPath)) {
            Logger.info('Repository root is a valid provisioner');
            return repositoryPath;
        }
        
        try {
            // Use the actual repository name if provided, otherwise get it from the path
            var repoName = actualRepositoryName != null ? actualRepositoryName : Path.withoutDirectory(Path.removeTrailingSlashes(repositoryPath));
            Logger.info('Using repository name: ${repoName}');
            
            // Read first level directories
            var items = FileSystem.readDirectory(repositoryPath);
            Logger.info('Found ${items.length} items in repository root');
            
            // Create a function to recursively check directories up to a certain depth
            function checkDirectory(dirPath:String, relativePath:String, depth:Int = 0, maxDepth:Int = 3):String {
                if (depth > maxDepth) return null;
                
                // Check if this directory is a provisioner
                if (_isProvisionerDirectory(dirPath)) {
                    Logger.info('Found valid provisioner at depth ${depth}: ${relativePath}');
                    return dirPath;
                }
                
                // Don't go deeper if we're already at max depth
                if (depth == maxDepth) return null;
                
                try {
                    var subItems = FileSystem.readDirectory(dirPath);
                    Logger.verbose('Checking ${subItems.length} items at depth ${depth}: ${relativePath}');
                    
                    // First check any directories with the same name as the repository (common pattern)
                    for (subItem in subItems) {
                        var subItemPath = Path.addTrailingSlash(dirPath) + subItem;
                        var newRelativePath = relativePath.length > 0 ? relativePath + "/" + subItem : subItem;
                        
                        if (FileSystem.isDirectory(subItemPath) && subItem == repoName) {
                            Logger.info('Found subdirectory with same name as repository at depth ${depth}: ${newRelativePath}');
                            
                            // Check if this matches the expected structure
                            var result = checkDirectory(subItemPath, newRelativePath, depth + 1, maxDepth);
                            if (result != null) return result;
                        }
                    }
                    
                    // Then check all other directories
                    for (subItem in subItems) {
                        var subItemPath = Path.addTrailingSlash(dirPath) + subItem;
                        var newRelativePath = relativePath.length > 0 ? relativePath + "/" + subItem : subItem;
                        
                        if (FileSystem.isDirectory(subItemPath) && subItem != repoName) {
                            var result = checkDirectory(subItemPath, newRelativePath, depth + 1, maxDepth);
                            if (result != null) return result;
                        }
                    }
                } catch (e) {
                    Logger.warning('Error checking subdirectories of ${dirPath}: ${e}');
                }
                
                return null;
            }
            
            // Start recursive search from the repository root
            var provisioner = checkDirectory(repositoryPath, "", 0);
            if (provisioner != null) return provisioner;
            
            // First priority: Look for a subdirectory with the same name as the repository
            for (item in items) {
                var itemPath = Path.addTrailingSlash(repositoryPath) + item;
                if (FileSystem.isDirectory(itemPath) && item == repoName) {
                    Logger.info('Found subdirectory with same name as repository: ${item}');
                    
                    // Check if this directory is a provisioner
                    if (_isProvisionerDirectory(itemPath)) {
                        Logger.info('Directory ${item} is a valid provisioner');
                        return itemPath;
                    }
                    
                    var versionMetadataPath = Path.addTrailingSlash(itemPath) + VERSION_METADATA_FILENAME;
                    if (FileSystem.exists(versionMetadataPath)) {
                        Logger.info('Found provisioner.yml in ${item}');
                        return itemPath;
                    }
                }
            }
            
            // Second priority: Look for a directory specifically named "provisioner"
            for (item in items) {
                var itemPath = Path.addTrailingSlash(repositoryPath) + item;
                if (FileSystem.isDirectory(itemPath) && item == "provisioner") {
                    Logger.info('Found "provisioner" directory');
                    if (_isProvisionerDirectory(itemPath)) {
                        Logger.info('Directory "provisioner" is a valid provisioner');
                        return itemPath;
                    }
                }
            }
            
            // Third priority: Check all first-level subdirectories
            for (item in items) {
                var itemPath = Path.addTrailingSlash(repositoryPath) + item;
                if (FileSystem.isDirectory(itemPath)) {
                    // Check if this directory is a provisioner
                    if (_isProvisionerDirectory(itemPath)) {
                        Logger.info('First-level directory ${item} is a valid provisioner');
                        return itemPath;
                    }
                    
                    // Check second level 
                    try {
                        var subItems = FileSystem.readDirectory(itemPath);
                        for (subItem in subItems) {
                            var subItemPath = Path.addTrailingSlash(itemPath) + subItem;
                            if (FileSystem.isDirectory(subItemPath)) {
                                if (_isProvisionerDirectory(subItemPath)) {
                                    Logger.info('Second-level directory ${item}/${subItem} is a valid provisioner');
                                    return subItemPath;
                                }
                                
                                // Check third level for deeper nesting
                                try {
                                    var subSubItems = FileSystem.readDirectory(subItemPath);
                                    for (subSubItem in subSubItems) {
                                        var subSubItemPath = Path.addTrailingSlash(subItemPath) + subSubItem;
                                        if (FileSystem.isDirectory(subSubItemPath) && _isProvisionerDirectory(subSubItemPath)) {
                                            Logger.info('Third-level directory ${item}/${subItem}/${subSubItem} is a valid provisioner');
                                            return subSubItemPath;
                                        }
                                    }
                                } catch (e) {
                                    // Ignore errors at this level
                                }
                            }
                        }
                    } catch (e) {
                        Logger.warning('Error checking subdirectories of ${itemPath}: ${e}');
                    }
                }
            }
        } catch (e) {
            Logger.error('Error searching for provisioner root: ${e}');
        }
        
        Logger.warning('No valid provisioner structure found in repository');
        return null;
    }
    
    /**
     * Check if a directory contains a valid provisioner structure
     * @param directoryPath Path to check
     * @return Bool True if the directory looks like a provisioner
     */
    static private function _isProvisionerDirectory(directoryPath:String):Bool {
        // Check for collection structure (has provisioner-collection.yml)
        if (FileSystem.exists(Path.addTrailingSlash(directoryPath) + PROVISIONER_METADATA_FILENAME)) {
            return true;
        }
        
        // Check for version structure - just need provisioner.yml 
        // Future provisioners will have scripts moved up to main directory
        var hasVersionMetadata = FileSystem.exists(Path.addTrailingSlash(directoryPath) + VERSION_METADATA_FILENAME);
        
        // If we have the metadata file, consider it a valid provisioner directory
        if (hasVersionMetadata) {
            Logger.info('Found provisioner.yml in directory: ${directoryPath}');
            return true;
        }
        
        return false;
    }
    
    /**
     * Clean up a temporary directory
     * @param tempDir Path to the temporary directory
     */
    static private function _cleanupTempDir(tempDir:String):Void {
        if (FileSystem.exists(tempDir)) {
            try {
                _deleteDirectory(tempDir);
            } catch (e) {
                Logger.warning('Failed to clean up temporary directory ${tempDir}: ${e}');
            }
        }
    }
    
    /**
     * Recursively delete a directory and all its contents
     * @param dirPath Path to the directory to delete
     */
    static private function _deleteDirectory(dirPath:String):Void {
        if (!FileSystem.exists(dirPath) || !FileSystem.isDirectory(dirPath)) {
            return;
        }
        
        var items = FileSystem.readDirectory(dirPath);
        for (item in items) {
            var itemPath = Path.addTrailingSlash(dirPath) + item;
            if (FileSystem.isDirectory(itemPath)) {
                _deleteDirectory(itemPath);
            } else {
                FileSystem.deleteFile(itemPath);
            }
        }
        
        FileSystem.deleteDirectory(dirPath);
    }

    /**
     * Safely delete a directory by checking if it's a valid temporary directory first
     * This helps prevent accidental deletion of important system directories
     * @param dirPath Path to the directory to delete
     */
    static private function _safeDeleteDirectory(dirPath:String):Void {
        // Safety checks to prevent deleting important directories
        if (dirPath == null || dirPath == "" || dirPath.length < 10) {
            Logger.error('Refusing to delete potentially important directory: ${dirPath}');
            return;
        }
        
        // Only delete directories with our expected patterns - on Windows, we only use the repo directory
        var isValidTemp = false;
        
        if (Sys.systemName() == "Windows") {
            // On Windows, we ONLY use the C:/Users/Username/repo path
            if (dirPath.indexOf("/repo") >= 0 || dirPath.indexOf("\\repo") >= 0) {
                isValidTemp = true;
            }
        } else {
            // On non-Windows, we use paths in the application storage directory
            if (dirPath.indexOf(System.applicationStorageDirectory) >= 0) {
                isValidTemp = true;
            }
        }
        
        if (!isValidTemp) {
            Logger.error('Refusing to delete directory that does not match expected patterns: ${dirPath}');
            return;
        }
        
        // Safe to delete
        try {
            _deleteDirectory(dirPath);
            Logger.info('Successfully deleted temporary directory: ${dirPath}');
        } catch (e) {
            Logger.warning('Error deleting directory ${dirPath}: ${e}');
        }
    }
    
    /**
     * Force cleanup of Windows repo directory specifically
     * This is a special case for the C:/Users/Username/repo path which is used for cloning
     * @param dirPath The repo directory path to clean up
     */
    static private function _forceCleanupWindowsRepoDir(dirPath:String):Void {
        Logger.info('Performing forced cleanup of Windows repo directory: ${dirPath}');
        
        // Verify this is actually the repo directory to be extra safe
        if (dirPath == null || dirPath.toLowerCase().indexOf("\\repo") < 0 && dirPath.toLowerCase().indexOf("/repo") < 0) {
            Logger.error('Not a Windows repo directory, refusing to force clean: ${dirPath}');
            return;
        }
        
        try {
            // First try standard directory deletion
            _deleteDirectory(dirPath);
            Logger.info('Successfully deleted repo directory using standard method');
        } catch (e) {
            Logger.warning('Standard directory deletion failed: ${e}, trying command-line deletion');
            
            // Try using rd /s /q command which can sometimes work when the API fails
            try {
                var dirPathBackslash = StringTools.replace(dirPath, "/", "\\");
                var command = 'rd /s /q "${dirPathBackslash}"';
                Logger.info('Executing command: ${command}');
                
                var process = new Process(command);
                var exitCode = process.exitCode();
                var error = process.stderr.readAll().toString();
                process.close();
                
                if (exitCode == 0) {
                    Logger.info('Successfully deleted repo directory using rd command');
                } else {
                    // If rd fails, try to use robocopy trick (create empty dir and mirror it)
                    Logger.warning('rd command failed with exit code ${exitCode}: ${error}, trying robocopy purge');
                    
                    // Create a temporary empty directory
                    var tempEmptyDir = Path.addTrailingSlash(dirPath) + "..\\empty_temp_dir_" + Date.now().getTime();
                    try {
                        FileSystem.createDirectory(tempEmptyDir);
                        
                        // Use robocopy with /MIR to "mirror" the empty directory, effectively purging everything
                        var robocopyCmd = 'robocopy "${tempEmptyDir}" "${dirPathBackslash}" /MIR /NFL /NDL /NJH /NJS /NC /NS';
                        Logger.info('Executing robocopy purge: ${robocopyCmd}');
                        
                        var roboProcess = new Process(robocopyCmd);
                        roboProcess.close();
                        
                        // Delete the temp empty directory
                        FileSystem.deleteDirectory(tempEmptyDir);
                        
                        // Now try to remove the directory again
                        if (FileSystem.exists(dirPath)) {
                            FileSystem.deleteDirectory(dirPath);
                            Logger.info('Successfully removed repo directory after robocopy purge');
                        }
                    } catch (tempDirErr) {
                        Logger.error('Robocopy purge method failed: ${tempDirErr}');
                        
                        // As a last resort, report to the user that they may need to clean up manually
                        Logger.warning('Failed to automatically clean up ${dirPath}. This directory may need to be manually removed.');
                        ToastManager.getInstance().showToast('Note: The temporary repository at ${dirPath} could not be automatically cleaned up and may need manual removal.');
                    }
                }
            } catch (cmdErr) {
                Logger.warning('Command-line deletion failed: ${cmdErr}');
                
                // Report to the user that they may need to clean up manually
                Logger.warning('Failed to automatically clean up ${dirPath}. This directory may need to be manually removed.');
                ToastManager.getInstance().showToast('Note: The temporary repository at ${dirPath} could not be automatically cleaned up and may need manual removal.');
            }
        }
    }
    
    /**
     * Get valid version directories from a provisioner directory
     * Valid versions must contain a provisioner.yml file
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
                
                // Check if this is a valid version directory (has provisioner.yml)
                var versionMetadataPath = Path.addTrailingSlash(provisionerPath) + Path.addTrailingSlash(item) + VERSION_METADATA_FILENAME;
                if (FileSystem.exists(versionMetadataPath)) {
                    validVersions.push(item);
                    
                    // Log whether it has a scripts folder (for backward compatibility info)
                    var scriptsPath = Path.addTrailingSlash(provisionerPath) + Path.addTrailingSlash(item) + "scripts";
                    var hasScriptsDir = FileSystem.exists(scriptsPath) && FileSystem.isDirectory(scriptsPath);
                    Logger.info('Valid version directory: ${item} (has scripts folder: ${hasScriptsDir})');
                } else {
                    Logger.warning('Invalid version directory (no provisioner.yml file): ${item}');
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
    /**
     * Convert a path to the platform-specific format with long path support for Windows
     * @param path The original path 
     * @return The platform-appropriate path
     */
    #if windows
    static private function _getWindowsLongPath(path:String):String {
        // Only apply the prefix if the path is long and doesn't already have it
        if (path.length > 240 && !StringTools.startsWith(path, "\\\\?\\")) {
            // Make sure path is absolute and uses backslashes
            var normalizedPath = StringTools.replace(Path.normalize(path), "/", "\\");
            
            // Check if it's a UNC path (network share)
            if (StringTools.startsWith(normalizedPath, "\\\\")) {
                return "\\\\?\\UNC\\" + normalizedPath.substr(2);
            } else if (Path.isAbsolute(normalizedPath)) {
                return "\\\\?\\" + normalizedPath;
            }
        }
        return path;
    }
    #end

    /**
     * Convert a path to the platform-specific format
     * @param path The original path
     * @return The platform-appropriate path
     */
    static private function _getPlatformPath(path:String):String {
        // Basic path validation
        if (path == null || path == "") {
            Logger.error('Cannot convert null or empty path');
            return path;
        }
        
        #if windows
        // For Windows, add special handling
        try {
            // Normalize path separators before conversion - make all forward slashes into backslashes
            var normalizedPath = StringTools.replace(path, "/", "\\");
            
            // Log the conversion for debugging
            var result = _getWindowsLongPath(normalizedPath);
            
            // Log the conversion to help diagnose path issues
            if (path != result) {
                Logger.info('Windows path conversion: "' + path + '" -> "' + result + '"');
            }
            
            // Return the converted path
            return result;
        } catch (e) {
            Logger.error('Error in Windows path conversion for "' + path + '": ' + e);
            return path; // Return original path as fallback
        }
        #else
        // On non-Windows platforms, simply return the original path
        return path;
        #end
    }
    
    static private function _zipDirectory(directory:String):Bytes {
        Logger.info('Zipping directory: ${directory}');
        
        // Add validation before proceeding
        if (directory == null || directory == "") {
            Logger.error('Cannot zip null or empty directory path');
            throw new haxe.Exception('Invalid directory path: null or empty');
        }
        
        // Log the existence of the directory
        var directoryExists = FileSystem.exists(directory);
        var isDirectory = directoryExists && FileSystem.isDirectory(directory);
        Logger.info('Directory exists: ${directoryExists}, Is directory: ${isDirectory}');
        
        if (!directoryExists) {
            Logger.error('Cannot zip non-existent directory: ${directory}');
            throw new haxe.Exception('Invalid directory path: directory does not exist');
        }
        
        if (!isDirectory) {
            Logger.error('Cannot zip non-directory path: ${directory}');
            throw new haxe.Exception('Invalid directory path: not a directory');
        }
        
        // Try to list contents for diagnostic purposes
        try {
            var items = FileSystem.readDirectory(directory);
            Logger.info('Directory contains ${items.length} items at top level');
        } catch (e) {
            Logger.error('Error listing directory contents: ${e}');
            // Continue anyway, as the deeper function will handle this error
        }
        
        var entries:List<Entry> = new List<Entry>();
        
        try {
            _addDirectoryToZip(directory, "", entries);
            
            var out = new BytesOutput();
            var writer = new Writer(out);
            writer.write(entries);
            
            return out.getBytes();
        } catch (e) {
            Logger.error('Error during directory zipping: ${e}');
            throw e; // Re-throw to be handled by caller
        }
    }
    
    /**
     * Helper function to recursively add files to a zip archive
     * Uses no compression to avoid ZLib errors with deeply nested paths
     * @param directory The base directory
     * @param path The current path within the zip
     * @param entries The list of zip entries
     */
    static private function _addDirectoryToZip(directory:String, path:String, entries:List<Entry>):Void {
        // Enhanced validation of input directory parameter
        if (directory == null || directory == "") {
            var errorMsg = "Cannot process null or empty directory";
            Logger.error(errorMsg);
            throw new haxe.Exception(errorMsg);
        }

        // Check if directory exists and is actually a directory
        var directoryExists = FileSystem.exists(directory);
        if (!directoryExists) {
            var errorMsg = 'Directory does not exist: ${directory}';
            Logger.error(errorMsg);
            throw new haxe.Exception(errorMsg);
        }

        var isDirectory = FileSystem.isDirectory(directory);
        if (!isDirectory) {
            var errorMsg = 'Path exists but is not a directory: ${directory}';
            Logger.error(errorMsg);
            throw new haxe.Exception(errorMsg);
        }

        Logger.info('_addDirectoryToZip processing directory: ${directory} (path within zip: ${path})');
        
        try {
            // Use platform-specific path for directory operations
            var platformDirectory = _getPlatformPath(directory);
            Logger.info('Using platform directory: ${platformDirectory}');
            
            // Check if platform directory exists (in case conversion changed something)
            var platformDirExists = FileSystem.exists(platformDirectory);
            if (!platformDirExists) {
                var errorMsg = 'Platform-specific directory path does not exist: ${platformDirectory}';
                Logger.error(errorMsg);
                throw new haxe.Exception(errorMsg);
            }
            
            // Read directory contents with detailed logging and more robust error handling
            var items = [];
            try {
                // Try to read the directory with the platform path first
                items = FileSystem.readDirectory(platformDirectory);
                Logger.info('Directory contains ${items.length} items');
            } catch (e) {
                // Handle the specific "Invalid directory" error
                var errorMsg = Std.string(e);
                if (errorMsg.indexOf("Invalid directory") >= 0) {
                    Logger.error('Directory exists but cannot be read with long path (Invalid directory error): ${platformDirectory}');
                    Logger.error('This may be due to permission issues or path encoding problems');
                    
                    // Additional diagnostics for Windows
                    if (Sys.systemName() == "Windows") {
                        Logger.error('Windows path details:');
                        Logger.error('  Original path: ${directory}');
                        Logger.error('  Platform path: ${platformDirectory}');
                    }
                    
                    // Try with the original directory as fallback
                    try {
                        items = FileSystem.readDirectory(directory);
                        Logger.info('Successfully read directory using original path: ${items.length} items');
                    } catch (e2) {
                        Logger.error('Failed to read directory using original path: ${e2}');
                        throw new haxe.Exception('Cannot read directory content: ${e2.message}');
                    }
                } else {
                    Logger.error('Error reading directory contents: ${e}');
                    throw e;
                }
            }
            
            // Process the directory contents
            for (item in items) {
                var itemPath = Path.addTrailingSlash(directory) + item;
                var platformItemPath = _getPlatformPath(itemPath);
                var zipPath = path.length > 0 ? path + "/" + item : item;
                
                // Verify the item exists using the appropriate path
                var itemPathToUse = platformItemPath;
                var itemExists = FileSystem.exists(platformItemPath);
                
                if (!itemExists) {
                    Logger.warning('Item does not exist with platform path: ${platformItemPath}, trying original path');
                    itemExists = FileSystem.exists(itemPath);
                    if (itemExists) {
                        itemPathToUse = itemPath;
                        Logger.info('Item exists with original path: ${itemPath}');
                    } else {
                        Logger.warning('Item does not exist at all, skipping: ${item}');
                        continue;
                    }
                }
                
                var isItemDirectory = false;
                // Try to determine if it's a directory
                try {
                    isItemDirectory = FileSystem.isDirectory(itemPathToUse);
                } catch (e) {
                    Logger.warning('Error checking if item is directory: ${e}, skipping: ${item}');
                    continue;
                }
                
                Logger.verbose('Processing ${isItemDirectory ? "directory" : "file"}: ${item}');
                
                if (isItemDirectory) {
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
                    try {
                        _addDirectoryToZip(itemPath, zipPath, entries);
                    } catch (e) {
                        Logger.warning('Error adding subdirectory ${itemPath} to zip: ${e}, continuing with other items');
                    }
                } else {
                    // Add file entry without compression
                    try {
                        var data = File.getBytes(itemPathToUse);
                        var entry:Entry = {
                            fileName: zipPath,
                            fileSize: data.length,
                            fileTime: Date.now(), // Use current time if stat fails
                            compressed: false, // No compression
                            dataSize: data.length,
                            data: data,
                            crc32: haxe.crypto.Crc32.make(data)
                        };
                        
                        // Try to get the actual file time using stat
                        try {
                            entry.fileTime = FileSystem.stat(itemPathToUse).mtime;
                        } catch (statErr) {
                            Logger.verbose('Could not get file time for ${itemPath}, using current time');
                        }
                        
                        // Skip compression completely
                        entries.add(entry);
                        Logger.verbose('Added file to zip: ${zipPath} (${data.length} bytes)');
                    } catch (e) {
                        Logger.warning('Could not add file to zip: ${itemPath} - ${e}');
                    }
                }
            }
        } catch (e) {
            Logger.error('Error processing directory for zip: ${directory} - ${e}');
            throw e;
        }
    }
    
    /**
     * Create a directory using a platform path that has already been processed for long path support
     * This version takes an already formatted platform path and handles creating parent directories
     * @param platformDir A directory path that has already been processed with _getPlatformPath
     */
    static private function _createDirectoryRecursiveWithPlatformPath(platformDir:String):Void {
        if (platformDir == null || platformDir == "") {
            return;
        }
        
        if (FileSystem.exists(platformDir)) {
            return;
        }
        
        // Get the parent directory - we need to convert back from platform path to get the directory
        var standardPath = #if windows 
            StringTools.startsWith(platformDir, "\\\\?\\") ? 
                (StringTools.startsWith(platformDir, "\\\\?\\UNC\\") ? 
                    "\\\\" + platformDir.substr(8) : // Convert back from UNC
                    platformDir.substr(4)) : // Convert back from local drive
                platformDir
        #else 
            platformDir 
        #end;
        
        var parentDir = Path.directory(standardPath);
        var platformParentDir = _getPlatformPath(parentDir);
        
        // Recursively create parent directories first
        _createDirectoryRecursiveWithPlatformPath(platformParentDir);
        
        try {
            // Create this directory with the platform path
            FileSystem.createDirectory(platformDir);
        } catch (e) {
            Logger.error('Failed to create directory with platform path: ${platformDir} - ${e}');
            throw e;
        }
    }

    /**
     * Unzip bytes to a directory with enhanced Windows long path handling
     * @param zipBytes The zipped content
     * @param directory The directory to unzip to
     */
    static private function _unzipToDirectory(zipBytes:Bytes, directory:String):Void {
        Logger.info('Unzipping to directory: ${directory}');
        var entries = Reader.readZip(new BytesInput(zipBytes));
        
        // Ensure the root extraction directory exists using platform path
        var platformDirectory = _getPlatformPath(directory);
        if (!FileSystem.exists(platformDirectory)) {
            try {
                Logger.info('Creating root extraction directory: ${platformDirectory}');
                _createDirectoryRecursiveWithPlatformPath(platformDirectory);
            } catch (e) {
                Logger.error('Failed to create root extraction directory: ${directory} - ${e}');
                throw new haxe.Exception('Could not create extraction directory: ${e.message}');
            }
        }
        
        // Process all entries with enhanced Windows path handling
        for (entry in entries) {
            var fileName = entry.fileName;
            
            // Skip invalid entries
            if (fileName == null || fileName == "") {
                Logger.warning('Skipping entry with empty filename');
                continue;
            }
            
            // Normalize path separators to avoid issues
            fileName = StringTools.replace(fileName, "\\", "/");
            
            // Process directory entries
            if (fileName.length > 0 && fileName.charAt(fileName.length - 1) == "/") {
                try {
                    // Create full platform path for directory
                    var fullDirPath = Path.addTrailingSlash(directory) + fileName;
                    var platformDirPath = _getPlatformPath(fullDirPath);
                    
                    // Log the path for debugging
                    Logger.verbose('Creating directory: ${platformDirPath}');
                    
                    // Use platform-specific method for directory creation
                    _createDirectoryRecursiveWithPlatformPath(platformDirPath);
                } catch (e) {
                    Logger.warning('Could not create directory: ${fileName} - ${e}');
                }
                continue;
            }
            
            // Process file entries with enhanced path handling
            try {
                // Create absolute paths for file and its parent directory
                var fullFilePath = Path.addTrailingSlash(directory) + fileName;
                var platformFilePath = _getPlatformPath(fullFilePath);
                
                // Get parent directory and create it with platform path handling
                var parentDir = Path.directory(fullFilePath);
                var platformParentDir = _getPlatformPath(parentDir);
                
                try {
                    // Create parent directories first
                    _createDirectoryRecursiveWithPlatformPath(platformParentDir);
                } catch (e) {
                    Logger.warning('Could not create parent directory ${platformParentDir}: ${e}');
                    continue; // Skip this file if we can't create its parent directory
                }
                
                // Uncompress the file if needed
                if (entry.compressed) {
                    Tools.uncompress(entry);
                }
                
                // Log the file path for debugging
                Logger.verbose('Saving file: ${platformFilePath}');
                
                // Save the file using platform path handling for Windows long paths
                try {
                    File.saveBytes(platformFilePath, entry.data);
                } catch (e) {
                    Logger.warning('Could not save file ${platformFilePath}: ${e}');
                }
            } catch (e) {
                Logger.warning('Could not extract file from zip: ${fileName} - ${e}');
            }
        }
        Logger.info('Unzip completed');
    }
    
    /**
     * Create a directory and all parent directories if they don't exist
     * Legacy method kept for backwards compatibility, now uses _createDirectoryRecursiveWithPlatformPath
     * @param directory The directory path to create
     */
    static private function _createDirectoryRecursive(directory:String):Void {
        if (directory == null || directory == "") {
            return;
        }
        
        var platformDir = _getPlatformPath(directory);
        if (FileSystem.exists(platformDir)) {
            return;
        }
        
        // Get parent directory and create it first
        var parentDir = Path.directory(directory);
        var platformParentDir = _getPlatformPath(parentDir);
        _createDirectoryRecursiveWithPlatformPath(platformParentDir);
        
        try {
            // Create this directory
            FileSystem.createDirectory(platformDir);
        } catch (e) {
            Logger.error('Failed to create directory: ${directory} - ${e}');
            throw e;
        }
    }

}
