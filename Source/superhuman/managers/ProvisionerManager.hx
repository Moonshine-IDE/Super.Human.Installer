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
            var previewLength = content.length > 200 ? 200 : content.length;
            Logger.info('Provisioner metadata content: ${content.substr(0, previewLength)}...');
            
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
            Logger.info('No roles to parse');
            return [];
        }
        
        Logger.info('Parsing ${rolesData.length} roles');
        var result:Array<ProvisionerRole> = [];
        
        for (roleData in rolesData) {
            try {
                if (roleData == null) {
                    Logger.warning('Skipping null role data');
                    continue;
                }
                
                Logger.info('Parsing role: ${roleData}');
                
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
                    
                    Logger.info('Role parsed: name=${role.name}, label=${role.label}');
                    
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
                    
                    Logger.info('Role parsed: name=${role.name}, label=${role.label}');
                    
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
            Logger.info('No fields to parse');
            return [];
        }
        
        Logger.info('Parsing ${fieldsData.length} fields');
        var result:Array<ProvisionerField> = [];
        
        for (fieldData in fieldsData) {
            try {
                if (fieldData == null) {
                    Logger.warning('Skipping null field data');
                    continue;
                }
                
                Logger.info('Parsing field: ${fieldData}');
                
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
                        
                        Logger.info('Got field properties using ObjectMap: name=${fieldName}, type=${fieldType}, label=${fieldLabel}');
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
                                
                                Logger.info('Got field properties using get method: name=${fieldName}, type=${fieldType}, label=${fieldLabel}');
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
                        
                        Logger.info('Got field properties using Reflect: name=${fieldName}, type=${fieldType}, label=${fieldLabel}');
                    } else if (Std.isOfType(fieldData, Dynamic) && fieldData.name != null) {
                        // It's a dynamic object with properties
                        fieldName = fieldData.name;
                        if (fieldData.type != null) {
                            var typeValue = fieldData.type;
                            fieldType = (typeValue != null && Std.string(typeValue).length > 0) ? Std.string(typeValue) : "text";
                        }
                        if (fieldData.label != null) fieldLabel = fieldData.label;
                        
                        Logger.info('Got field properties using dynamic access: name=${fieldName}, type=${fieldType}, label=${fieldLabel}');
                    }
                    
                    // Log the field data
                    Logger.info('Field data: ${fieldData}, extracted name: ${fieldName}, type: ${fieldType}, label: ${fieldLabel}');
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
                
                Logger.info('Field parsed: name=${field.name}, type=${field.type}, label=${field.label}');
                
                // Add optional properties if they exist
                // Try different ways to access properties
                function getProperty(obj:Dynamic, propName:String):Dynamic {
                    try {
                        // First, check if obj is an ObjectMap
                        if (Std.isOfType(obj, ObjectMap)) {
                            var objMap:ObjectMap<String, Dynamic> = cast obj;
                            if (objMap.exists(propName)) {
                                var value = objMap.get(propName);
                                Logger.info('Got property ${propName} using ObjectMap: ${value}');
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
                                    Logger.info('Got property ${propName} using get method: ${value}');
                                    return value;
                                }
                            } catch (e) {
                                Logger.error('Error calling get method for property ${propName}: ${e}');
                            }
                        } else if (Reflect.hasField(obj, propName)) {
                            var value = Reflect.field(obj, propName);
                            Logger.info('Got property ${propName} using Reflect: ${value}');
                            return value;
                        } else if (Std.isOfType(obj, Dynamic) && Reflect.getProperty(obj, propName) != null) {
                            var value = Reflect.getProperty(obj, propName);
                            Logger.info('Got property ${propName} using dynamic access: ${value}');
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
                    
                    // Filter out non-directories and the provisioner.yml file
                    var validVersionDirs = versionDirs.filter(dir -> 
                        FileSystem.isDirectory(Path.addTrailingSlash(provisionerPath) + dir) && 
                        dir != PROVISIONER_METADATA_FILENAME
                    );
                    
                    Logger.info('Found ${validVersionDirs.length} version directories for ${metadata.type}');
                    
                    for (versionDir in validVersionDirs) {
                        var versionPath = Path.addTrailingSlash(provisionerPath) + versionDir;
                        
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
