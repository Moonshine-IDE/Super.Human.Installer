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
                return _getFallbackProvisioners(type);
            }
        }
        
        try {
            // List all directories in the common directory
            var provisionerDirs = FileSystem.readDirectory(commonDir);
            
            for (provisionerDir in provisionerDirs) {
                var provisionerPath = Path.addTrailingSlash(commonDir) + provisionerDir;
                
                // Skip if not a directory
                if (!FileSystem.isDirectory(provisionerPath)) {
                    continue;
                }
                
                // Read provisioner metadata
                var metadata = readProvisionerMetadata(provisionerPath);
                
                // Skip if no metadata or if filtering by type and type doesn't match
                if (metadata == null || (type != null && metadata.type != type)) {
                    continue;
                }
                
                // List all version directories
                try {
                    var versionDirs = FileSystem.readDirectory(provisionerPath);
                    
                    for (versionDir in versionDirs) {
                        var versionPath = Path.addTrailingSlash(provisionerPath) + versionDir;
                        
                        // Skip if not a directory
                        if (!FileSystem.isDirectory(versionPath)) {
                            continue;
                        }
                        
                        // Check if this is a valid version directory (has scripts and templates subdirectories)
                        var scriptsPath = Path.addTrailingSlash(versionPath) + "scripts";
                        var templatesPath = Path.addTrailingSlash(versionPath) + "templates";
                        
                        if (FileSystem.exists(scriptsPath) && FileSystem.isDirectory(scriptsPath)) {
                            // Create provisioner definition
                            var versionInfo = VersionInfo.fromString(versionDir);
                            
                            result.push({
                                name: '${metadata.name} v${versionDir}',
                                data: { type: metadata.type, version: versionInfo },
                                root: versionPath
                            });
                        }
                    }
                } catch (e) {
                    Logger.error('Error reading version directories for provisioner ${provisionerDir}: ${e}');
                }
            }
        } catch (e) {
            Logger.error('Error reading provisioners directory: ${e}');
            return _getFallbackProvisioners(type);
        }
        
        // If no provisioners found in common directory, fall back to bundled ones
        if (result.length == 0) {
            return _getFallbackProvisioners(type);
        }
        
        // Sort by version, newest first
        result.sort((a, b) -> {
            var versionA = a.data.version;
            var versionB = b.data.version;
            return versionB > versionA ? 1 : (versionB < versionA ? -1 : 0);
        });
        
        return result;
    }
    
    /**
     * Get fallback provisioners from the application bundle
     * @param type Optional provisioner type filter
     * @return Array<ProvisionerDefinition> Array of bundled provisioners
     */
    static private function _getFallbackProvisioners(type:ProvisionerType = null):Array<ProvisionerDefinition> {
        Logger.warning('No provisioners found in common directory, falling back to bundled provisioners');
        
        if (type == ProvisionerType.AdditionalProvisioner) {
            return [
                {
                    name: "HCL Additional Provisioner v0.1.23",
                    data: { type: ProvisionerType.AdditionalProvisioner, version: VersionInfo.fromString("0.1.23") },
                    root: Path.addTrailingSlash(System.applicationDirectory) + PROVISIONER_ADDITIONAL_LOCAL_PATH + "0.1.23"
                },
            ];
        } else if (type == ProvisionerType.DemoTasks || type == null) {
            return [
                {
                    name: "HCL Standalone Provisioner v0.1.23",
                    data: { type: ProvisionerType.DemoTasks, version: VersionInfo.fromString("0.1.23") },
                    root: Path.addTrailingSlash(System.applicationDirectory) + PROVISIONER_STANDALONE_LOCAL_PATH + "0.1.23"
                },
                {
                    name: "HCL Standalone Provisioner v0.1.22",
                    data: { type: ProvisionerType.DemoTasks, version: VersionInfo.fromString("0.1.22") },
                    root: Path.addTrailingSlash(System.applicationDirectory) + PROVISIONER_STANDALONE_LOCAL_PATH + "0.1.22"
                },
                {
                    name: "HCL Standalone Provisioner v0.1.20",
                    data: { type: ProvisionerType.DemoTasks, version: VersionInfo.fromString("0.1.20") },
                    root: Path.addTrailingSlash(System.applicationDirectory) + PROVISIONER_STANDALONE_LOCAL_PATH + "0.1.20"
                }
            ];
        }
        
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

}
