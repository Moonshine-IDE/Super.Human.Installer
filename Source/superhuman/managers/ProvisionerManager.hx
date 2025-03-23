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
import haxe.io.Path;
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
        
        if (!FileSystem.exists(metadataPath)) {
            return null;
        }
        
        try {
            var content = File.getContent(metadataPath);
            var metadata:ObjectMap<String, Dynamic> = Yaml.read(metadataPath);
            
            // Validate required fields
            if (!metadata.exists("name") || !metadata.exists("type") || !metadata.exists("description")) {
                Logger.warning('Invalid provisioner.yml at ${metadataPath}: missing required fields');
                return null;
            }
            
            return {
                name: metadata.get("name"),
                type: metadata.get("type"),
                description: metadata.get("description"),
                author: metadata.exists("author") ? metadata.get("author") : null,
                version: metadata.exists("version") ? metadata.get("version") : null
            };
        } catch (e) {
            Logger.error('Error reading provisioner.yml at ${metadataPath}: ${e}');
            return null;
        }
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
                            
                            result.push({
                                name: '${metadata.name} v${versionDir}',
                                data: { type: metadata.type, version: versionInfo },
                                root: versionPath
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
    
    /**
     * Get fallback provisioners from the application bundle
     * @param type Optional provisioner type filter
     * @return Array<ProvisionerDefinition> Array of bundled provisioners
     * @deprecated This method is no longer used as provisioners are now loaded from the common directory
     */
    static private function _getFallbackProvisioners(type:ProvisionerType = null):Array<ProvisionerDefinition> {
        Logger.warning('_getFallbackProvisioners is deprecated and should not be used');
        return []; // Always return empty array
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
                
                // Create the destination version directory
                var versionDestPath = Path.addTrailingSlash(destPath) + versionDir;
                if (FileSystem.exists(versionDestPath)) {
                    Logger.warning('Version ${versionDir} already exists at ${versionDestPath}, skipping');
                    continue;
                }
                
                // Copy the version directory
                _copyDirectory(versionSourcePath, versionDestPath);
                Logger.info('Imported version ${versionDir} to ${versionDestPath}');
                versionsImported++;
            }
            
            if (versionsImported == 0) {
                Logger.warning('No valid version directories found in ${sourcePath}');
                return false;
            }
            
            Logger.info('Successfully imported ${versionsImported} versions of provisioner ${metadata.type}');
            return true;
            
        } catch (e) {
            Logger.error('Error importing provisioner: ${e}');
            return false;
        }
    }
    
    /**
     * Helper method to recursively copy a directory
     * @param source Source directory path
     * @param destination Destination directory path
     */
    static private function _copyDirectory(source:String, destination:String):Void {
        // Create the destination directory if it doesn't exist
        if (!FileSystem.exists(destination)) {
            FileSystem.createDirectory(destination);
        }
        
        // Copy all files and subdirectories
        var items = FileSystem.readDirectory(source);
        for (item in items) {
            var sourcePath = Path.addTrailingSlash(source) + item;
            var destPath = Path.addTrailingSlash(destination) + item;
            
            if (FileSystem.isDirectory(sourcePath)) {
                // Recursively copy subdirectory
                _copyDirectory(sourcePath, destPath);
            } else {
                // Copy file
                File.copy(sourcePath, destPath);
            }
        }
    }

}
