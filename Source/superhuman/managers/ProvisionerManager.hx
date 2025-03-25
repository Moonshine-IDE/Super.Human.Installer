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
            
            for (versionDir in versionDirs) {
                var versionPath = Path.addTrailingSlash(provisionerPath) + versionDir;
                
                // Skip if not a directory or if it's the provisioner.yml file
                if (!FileSystem.isDirectory(versionPath) || versionDir == "provisioner.yml") {
                    continue;
                }
                
                // Check if this is a valid version directory (has scripts subdirectory)
                var scriptsPath = Path.addTrailingSlash(versionPath) + "scripts";
                if (!FileSystem.exists(scriptsPath) || !FileSystem.isDirectory(scriptsPath)) {
                    Logger.verbose('Skipping invalid version directory (no scripts folder): ${versionPath}');
                    continue;
                }
                
                // Create a version-specific metadata copy
                var versionMetadata = Reflect.copy(metadata);
                versionMetadata.version = versionDir;
                
                // Create provisioner definition
                var versionInfo = VersionInfo.fromString(versionDir);
                var provDef:ProvisionerDefinition = {
                    name: '${metadata.name} v${versionDir}',
                    data: { type: metadata.type, version: versionInfo },
                    root: versionPath,
                    metadata: versionMetadata
                };
                
                // Add to cache
                _cachedProvisioners.get(metadata.type).push(provDef);
                Logger.info('Added provisioner to cache: ${provDef.name}, type: ${metadata.type}, version: ${versionDir}');
            }
            
            // Sort the provisioners by version, newest first
            if (_cachedProvisioners.exists(metadata.type)) {
                _cachedProvisioners.get(metadata.type).sort((a, b) -> {
                    var versionA = a.data.version;
                    var versionB = b.data.version;
                    return versionB > versionA ? 1 : (versionB < versionA ? -1 : 0);
                });
            }
            
        } catch (e) {
            Logger.error('Error adding provisioner versions to cache: ${e}');
        }
    }
    
    /**
     * Read and parse provisioner metadata from provisioner.yml file
     * @param path Path to the provisioner directory
     * @return ProvisionerMetadata|null Metadata if file exists and is valid, null otherwise
     */
    static public function readProvisionerMetadata(path:String):ProvisionerMetadata {
        var metadataPath = Path.addTrailingSlash(path) + PROVISIONER_METADATA_FILENAME;
        
        if (!FileSystem.exists(metadataPath)) {
            Logger.warning('Provisioner metadata file not found at ${metadataPath}');
            return null;
        }
        
        try {
            var content = File.getContent(metadataPath);
            var previewLength = content.length > 200 ? 200 : content.length;
            
            var metadata:ObjectMap<String, Dynamic> = Yaml.read(metadataPath);
            
            // Validate required fields
            if (!metadata.exists("name") || !metadata.exists("type") || !metadata.exists("description")) {
                Logger.warning('Invalid provisioner.yml at ${metadataPath}: missing required fields');
                return null;
            }
            
            // Parse configuration if it exists
            var configuration:ProvisionerConfiguration = null;
            if (metadata.exists("configuration")) {
                var configData:ObjectMap<String, Dynamic> = metadata.get("configuration");
                configuration = {
                    basicFields: _parseFieldsArray(configData.exists("basicFields") ? configData.get("basicFields") : null),
                    advancedFields: _parseFieldsArray(configData.exists("advancedFields") ? configData.get("advancedFields") : null)
                };
            }
            
            // Parse roles if they exist
            var roles:Array<ProvisionerRole> = null;
            if (metadata.exists("roles")) {
                var rolesData:Array<Dynamic> = metadata.get("roles");
                roles = _parseRolesArray(rolesData);
            }
            
            return {
                name: metadata.get("name"),
                type: metadata.get("type"),
                description: metadata.get("description"),
                author: metadata.exists("author") ? metadata.get("author") : null,
                version: metadata.exists("version") ? metadata.get("version") : null,
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
            }
            
            // Copy provisioner.yml to the destination directory
            var sourceMetadataPath = Path.addTrailingSlash(sourcePath) + PROVISIONER_METADATA_FILENAME;
            var destMetadataPath = Path.addTrailingSlash(destPath) + PROVISIONER_METADATA_FILENAME;
            
            if (!FileSystem.exists(sourceMetadataPath)) {
                Logger.error('Provisioner metadata file not found at ${sourceMetadataPath}');
                return false;
            }
            
            File.copy(sourceMetadataPath, destMetadataPath);

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
                return true; // Return success if all versions already exist
            }

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
