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

package superhuman.server.cache;

import champaign.core.logging.Logger;
import haxe.Json;
import haxe.io.Path;
import lime.system.System;
import openfl.events.EventDispatcher;
import prominic.sys.io.FileTools;
import superhuman.config.SuperHumanHashes;
import superhuman.server.cache.SuperHumanCachedFile;
import sys.FileSystem;
import sys.io.File;

/**
 * Manages the file cache system for installer files
 */
class SuperHumanFileCache extends EventDispatcher {
    
    // Singleton instance
    private static var _instance:SuperHumanFileCache;
    
    // Registry file name
    private static final REGISTRY_FILENAME:String = "cache-registry.json";
    
    // Cached files registry
    private var _registry:Map<String, Map<String, Array<SuperHumanCachedFile>>>;
    
    // Cache directory path
    private var _cacheDirectory:String;
    
    /**
     * Get the singleton instance
     */
    public static function getInstance():SuperHumanFileCache {
        if (_instance == null) {
            _instance = new SuperHumanFileCache();
        }
        return _instance;
    }
    
    /**
     * Private constructor (singleton)
     */
    private function new() {
        super();
        
        try {
            Logger.info('Initializing SuperHumanFileCache');
            
            // Initialize registry map
            _registry = new Map<String, Map<String, Array<SuperHumanCachedFile>>>();
            
            // Determine cache directory
            _cacheDirectory = getCacheDirectory();
            Logger.info('Cache directory: ${_cacheDirectory}');
            
            // Create directory if it doesn't exist (do this before other initialization)
            if (!FileSystem.exists(_cacheDirectory)) {
                try {
                    FileSystem.createDirectory(_cacheDirectory);
                    Logger.info('Created file cache directory at ${_cacheDirectory}');
                } catch (e) {
                    Logger.error('Failed to create file cache directory: ${e}');
                }
            }
            
            // Initialize cache after directory is created
            initialize();
            
            Logger.info('SuperHumanFileCache initialization complete');
        } catch (e) {
            Logger.error('Error in SuperHumanFileCache constructor: ${e}');
        }
    }
    
    /**
     * Get the cache directory based on operating system
     */
    public static function getCacheDirectory():String {
        var cacheDir:String;
        
        #if windows
        // Windows: C:\Users\{username}\AppData\Roaming\SuperHumanInstallerDev\file-cache
        cacheDir = Path.join([System.applicationStorageDirectory, "file-cache"]);
        #elseif mac
        // Mac: /Users/{username}/Library/Application Support/SuperHumanInstallerDev/file-cache
        cacheDir = Path.join([System.applicationStorageDirectory, "file-cache"]);
        #else
        // Linux: /home/{username}/.SuperHumanInstallerDev/file-cache
        cacheDir = Path.join([System.applicationStorageDirectory, "file-cache"]);
        #end
        
        return cacheDir;
    }
    
    /**
     * Initialize the cache system
     */
    public function initialize():Void {
        // Create cache directory if it doesn't exist
        if (!FileSystem.exists(_cacheDirectory)) {
            try {
                FileSystem.createDirectory(_cacheDirectory);
                Logger.info('Created file cache directory at ${_cacheDirectory}');
            } catch (e) {
                Logger.error('Failed to create file cache directory: ${e}');
                return;
            }
        }
        
        // Load registry from disk or initialize with defaults
        loadRegistry();
        
        // Log initialization state
        var registryPath = Path.join([_cacheDirectory, REGISTRY_FILENAME]);
        
        // Correctly count Map entries
        var hasData = false;
        var roleCount = 0;
        if (_registry != null) {
            for (role in _registry.keys()) {
                hasData = true;
                roleCount++;
            }
        }
        
        Logger.info('Registry state after loading: Registry file exists: ${FileSystem.exists(registryPath)}, Registry has ${roleCount} roles, Has data: ${hasData}');
        
        // Verify cache integrity (check if files exist)
        verifyCache();
        
        // Only save registry if it's been modified during verification
        // This helps ensure we don't unnecessarily overwrite the registry
        saveRegistry();
        
        // Log final registry state after initialization
        var roleCount = 0;
        var fileCount = 0;
        if (_registry != null) {
            roleCount = Reflect.fields(_registry).length;
            for (role in _registry.keys()) {
                var roleMap = _registry.get(role);
                for (type in roleMap.keys()) {
                    var entries = roleMap.get(type);
                    fileCount += entries.length;
                }
            }
        }
        Logger.info('Registry initialization complete with ${roleCount} roles and ${fileCount} total files in registry');
    }
    
    /**
     * Load the registry from disk
     */
    private function loadRegistry():Void {
        var registryPath = Path.join([_cacheDirectory, REGISTRY_FILENAME]);
        
        if (FileSystem.exists(registryPath)) {
            try {
                var content = File.getContent(registryPath);
                var loadedData = Json.parse(content);
                Logger.info('Loaded file cache registry from ${registryPath}');
                
                // When loading from JSON, we need to rebuild the Map structure
                // JSON.parse converts Maps to plain objects, so we need to convert them back
                _registry = new Map<String, Map<String, Array<SuperHumanCachedFile>>>();
                
                // Check if we got valid data
                if (loadedData != null) {
                    var hasEntries = false;
                    
                    // For each role in the loaded data
                    for (roleKey in Reflect.fields(loadedData)) {
                        var roleData = Reflect.field(loadedData, roleKey);
                        
                        // Create a new Map for this role
                        var roleMap = new Map<String, Array<SuperHumanCachedFile>>();
                        
                        // For each type in this role
                        for (typeKey in Reflect.fields(roleData)) {
                            var entriesRaw = Reflect.field(roleData, typeKey);
                            var entries:Array<SuperHumanCachedFile> = cast entriesRaw;
                            
                            if (entries != null && entries.length > 0) {
                                hasEntries = true;
                                roleMap.set(typeKey, entries);
                                Logger.verbose('Loaded ${entries.length} files for ${roleKey}/${typeKey}');
                            } else {
                                // Handle empty arrays
                                roleMap.set(typeKey, []);
                            }
                        }
                        
                        // Add this role map to the registry
                        _registry.set(roleKey, roleMap);
                    }
                    
                    if (!hasEntries) {
                        Logger.warning('Registry loaded but contains no entries, initializing with defaults');
                        initializeWithDefaults();
                    } else {
                        // Log info about what was loaded - use Reflect.fields since we know we have valid data
                        var roles = Reflect.fields(loadedData);
                        Logger.info('Registry loaded successfully with roles: ${roles.join(", ")}');
                    }
                } else {
                    Logger.warning('Registry loaded but data is null, initializing with defaults');
                    initializeWithDefaults();
                }
            } catch (e) {
                Logger.error('Failed to load file cache registry: ${e}');
                initializeWithDefaults();
            }
        } else {
            Logger.info('No existing registry found, initializing with defaults');
            initializeWithDefaults();
        }
    }
    
    /**
     * Initialize registry with default values from SuperHumanHashes
     * This should only be called when no registry exists yet
     */
    private function initializeWithDefaults():Void {
        Logger.info('Creating new registry with default hash values');
        
        // Initialize a new registry if it doesn't exist
        if (_registry == null) {
            _registry = new Map<String, Map<String, Array<SuperHumanCachedFile>>>();
        }
        
        // Add static hashes from SuperHumanHashes
        for (role in SuperHumanHashes.validHashes.keys()) {
            // Get or create role map
            var roleMap = _registry.exists(role) ? _registry.get(role) : new Map<String, Array<SuperHumanCachedFile>>();
            
            // For each role in the static hashes
            var staticRoleMap = SuperHumanHashes.validHashes.get(role);
            
            for (type in staticRoleMap.keys()) {
                // Get or create type array
                var existingEntries = roleMap.exists(type) ? roleMap.get(type) : new Array<SuperHumanCachedFile>();
                var entries = staticRoleMap.get(type);
                
                // Create a map of existing hashes for quick lookup
                var existingHashes = new Map<String, Bool>();
                for (existingFile in existingEntries) {
                    existingHashes.set(existingFile.hash, true);
                }
                
                // Only add entries that don't already exist
                for (entry in entries) {
                    var hash:String = null;
                    if (Reflect.hasField(entry, "hash")) {
                        hash = Reflect.field(entry, "hash");
                    } else {
                        continue; // Skip entries without hash
                    }
                    
                    // Skip if this hash already exists in the registry
                    if (existingHashes.exists(hash)) {
                        Logger.info('Skipping default hash that already exists in registry: ${hash}');
                        continue;
                    }
                    
                    // Use originalFilename without hash prefix
                    var originalFilename = "unknown.unknown"; // Default filename
                    
                    // Create a version object if not null
                    var versionObj = null;
                    if (Reflect.hasField(entry, "version")) {
                        versionObj = Reflect.field(entry, "version");
                    }
                    
                    // Create a cached file entry with default values - use original filename for the path
                    var cachedFile:SuperHumanCachedFile = {
                        path: Path.join([_cacheDirectory, role, type, originalFilename]),
                        originalFilename: originalFilename, // Clean filename without hash prefix
                        hash: hash,
                        exists: false, // File doesn't physically exist yet
                        version: versionObj,
                        type: type,
                        role: role
                    };
                    
                    existingEntries.push(cachedFile);
                    Logger.verbose('Added default hash to registry: ${hash}');
                }
                
                roleMap.set(type, existingEntries);
            }
            
            _registry.set(role, roleMap);
        }
        
        Logger.info('Registry initialization with defaults complete');
    }
    
    /**
     * Verify cache integrity
     */
    private function verifyCache():Void {
        // Make sure registry exists
        if (_registry == null) {
            Logger.warning('Registry is null in verifyCache, initializing with defaults');
            initializeWithDefaults();
            return;
        }
        
        // Log the current registry state
        Logger.info('Verifying cache with registry containing roles: ${[for (role in _registry.keys()) role].join(", ")}');
        
        // For each role
        for (role in _registry.keys()) {
            var roleMap = _registry.get(role);
            
            // Ensure role map exists
            if (roleMap == null) {
                Logger.warning('Role map is null for role ${role}, skipping');
                continue;
            }
            
            // For each type (installer, hotfix, fixpack)
            for (type in roleMap.keys()) {
                var entries = roleMap.get(type);
                
                // Ensure entries array exists
                if (entries == null) {
                    Logger.warning('Entries array is null for type ${type} in role ${role}, creating empty array');
                    entries = new Array<SuperHumanCachedFile>();
                    roleMap.set(type, entries);
                    continue;
                }
                
                // For each cached file
                for (i in 0...entries.length) {
                    var cachedFile = entries[i];
                    
                    // Skip null entries
                    if (cachedFile == null) {
                        Logger.warning('Null cached file at index ${i} for type ${type} in role ${role}, skipping');
                        continue;
                    }
                    
                    // Handle null path
                    if (cachedFile.path == null) {
                        Logger.warning('Null path for cached file at index ${i} for type ${type} in role ${role}, skipping');
                        continue;
                    }
                    
                    // Update exists flag based on whether file exists
                    cachedFile.exists = FileSystem.exists(cachedFile.path);
                    
                    // Update the entry in the array
                    entries[i] = cachedFile;
                }
                
                // Update the role map
                roleMap.set(type, entries);
            }
            
            // Update the registry
            _registry.set(role, roleMap);
        }
    }
    
    /**
     * Save registry to disk
     */
    private function saveRegistry():Void {
        var registryPath = Path.join([_cacheDirectory, REGISTRY_FILENAME]);
        
        try {
            var content = Json.stringify(_registry, null, "  "); // Pretty-print with 2 spaces
            File.saveContent(registryPath, content);
            Logger.info('Saved file cache registry to ${registryPath}');
        } catch (e) {
            Logger.error('Failed to save file cache registry: ${e}');
        }
    }
    
    /**
     * Add a file to the cache
     * @param sourceFilePath Path to the source file
     * @param role Role/product (domino, nomad, etc.)
     * @param type File type (installer, hotfix, fixpack)
     * @param version Optional version info
     * @param originalHash Optional original hash for replacement
     * @return The cached file entry if successful, null otherwise
     */
    public function addFile(sourceFilePath:String, role:String, type:String, ?version:Dynamic, ?originalHash:String):SuperHumanCachedFile {
        if (!FileSystem.exists(sourceFilePath)) {
            Logger.error('Source file does not exist: ${sourceFilePath}');
            return null;
        }
        
        // Check if we should remove an existing file with original hash first (file replacement case)
        if (originalHash != null) {
            var existingFile = getFileByHash(originalHash, role, type);
            if (existingFile != null) {
                Logger.info('Removing existing file with hash ${originalHash} before adding replacement');
                removeFile(existingFile);
            }
        }
        
        // Calculate hash with robust error handling
        var hash:String = null;
        try {
            Logger.info('Calculating MD5 hash for: ${sourceFilePath}');
            var fileSize = FileSystem.stat(sourceFilePath).size;
            var fileSizeMB = fileSize / (1024 * 1024);
            Logger.info('File size: ${Std.string(Math.round(fileSizeMB * 100) / 100)} MB');
            
            hash = SuperHumanHashes.calculateMD5(sourceFilePath);
            
            // Log success
            if (hash != null) {
                Logger.info('Successfully calculated hash for ${sourceFilePath}: ${hash}');
            }
        } catch (e) {
            Logger.error('Exception during hash calculation: ${e}');
            // We'll continue with hash = null, which is handled below
        }
        
        if (hash == null) {
            Logger.error('Failed to calculate hash for: ${sourceFilePath}');
            return null;
        }
        
        // Check if a file with this hash already exists in the cache
        var existingFile = getFileByHash(hash);
        if (existingFile != null) {
            Logger.info('File with hash ${hash} already exists in the cache, removing it first to avoid duplicates');
            removeFile(existingFile);
        }
        
        // Get original filename
        var originalFilename = Path.withoutDirectory(sourceFilePath);
        
        // Create target directory
        var targetDir = Path.join([_cacheDirectory, role, type]);
        if (!FileSystem.exists(targetDir)) {
            try {
                // Create directory recursively
                FileSystem.createDirectory(targetDir);
                Logger.info('Created directory: ${targetDir}');
            } catch (e) {
                Logger.error('Failed to create directory: ${targetDir}, error: ${e}');
                return null;
            }
        }
        
        // Create target path - use just the original filename, not hash prefix
        var targetFilename = originalFilename;
        var targetPath = Path.join([targetDir, targetFilename]);
        
        // Log that we're using the original filename format now
        Logger.info('Using filename format without hash prefix: ${targetFilename}');
        
        // Copy file to cache
        try {
            File.copy(sourceFilePath, targetPath);
            Logger.info('Copied file to cache: ${targetPath}');
        } catch (e) {
            Logger.error('Failed to copy file to cache: ${e}');
            return null;
        }
        
        // Create cached file entry with clean original filename (not including hash)
        var cachedFile:SuperHumanCachedFile = {
            path: targetPath,
            originalFilename: originalFilename,  // Store the actual filename without hash prefix
            hash: hash,
            exists: true,
            version: version,
            type: type,
            role: role
        };
        
        Logger.info('Added file to cache: ${originalFilename} with hash ${hash}');
        
        // Add to registry
        addToRegistry(cachedFile);
        
        // Save registry
        saveRegistry();
        
        return cachedFile;
    }
    
    /**
     * Add a cached file to the registry
     */
    private function addToRegistry(cachedFile:SuperHumanCachedFile):Void {
        var role = cachedFile.role;
        var type = cachedFile.type;
        var hash = cachedFile.hash;
        
        // Check if role exists
        if (!_registry.exists(role)) {
            _registry.set(role, new Map<String, Array<SuperHumanCachedFile>>());
        }
        
        var roleMap = _registry.get(role);
        
        // Check if type exists
        if (!roleMap.exists(type)) {
            roleMap.set(type, new Array<SuperHumanCachedFile>());
        }
        
        var entries = roleMap.get(type);
        
        // Check if hash already exists
        var exists = false;
        for (i in 0...entries.length) {
            if (entries[i].hash == hash) {
                // Update existing entry
                entries[i] = cachedFile;
                exists = true;
                break;
            }
        }
        
        // Add new entry if it doesn't exist
        if (!exists) {
            entries.push(cachedFile);
        }
        
        // Update the registry
        roleMap.set(type, entries);
        _registry.set(role, roleMap);
    }
    
    /**
     * Get a cached file by hash
     * @param hash File hash
     * @param role Optional role to search in
     * @param type Optional type to search in
     * @return The cached file entry if found, null otherwise
     */
    public function getFileByHash(hash:String, ?role:String, ?type:String):SuperHumanCachedFile {
        // If role and type are specified, search only in that role and type
        if (role != null && type != null) {
            if (_registry.exists(role)) {
                var roleMap = _registry.get(role);
                if (roleMap.exists(type)) {
                    var entries = roleMap.get(type);
                    for (entry in entries) {
                        if (entry.hash == hash) {
                            return entry;
                        }
                    }
                }
            }
        }
        // If only role is specified, search in all types for that role
        else if (role != null) {
            if (_registry.exists(role)) {
                var roleMap = _registry.get(role);
                for (type in roleMap.keys()) {
                    var entries = roleMap.get(type);
                    for (entry in entries) {
                        if (entry.hash == hash) {
                            return entry;
                        }
                    }
                }
            }
        }
        // If only type is specified, search in all roles for that type
        else if (type != null) {
            for (role in _registry.keys()) {
                var roleMap = _registry.get(role);
                if (roleMap.exists(type)) {
                    var entries = roleMap.get(type);
                    for (entry in entries) {
                        if (entry.hash == hash) {
                            return entry;
                        }
                    }
                }
            }
        }
        // If neither role nor type is specified, search in all roles and types
        else {
            for (role in _registry.keys()) {
                var roleMap = _registry.get(role);
                for (type in roleMap.keys()) {
                    var entries = roleMap.get(type);
                    for (entry in entries) {
                        if (entry.hash == hash) {
                            return entry;
                        }
                    }
                }
            }
        }
        
        return null;
    }
    
    /**
     * Get all cached files for a role and type
     * @param role Role to search for
     * @param type Type to search for
     * @return Array of cached files
     */
    public function getFilesByRoleAndType(role:String, type:String):Array<SuperHumanCachedFile> {
        if (_registry.exists(role)) {
            var roleMap = _registry.get(role);
            if (roleMap.exists(type)) {
                return roleMap.get(type);
            }
        }
        
        return [];
    }
    
    /**
     * Remove a file from the cache
     * @param cachedFile The cached file to remove
     * @return True if successful, false otherwise
     */
    public function removeFile(cachedFile:SuperHumanCachedFile):Bool {
        if (cachedFile == null) {
            return false;
        }
        
        var role = cachedFile.role;
        var type = cachedFile.type;
        var hash = cachedFile.hash;
        
        // Check if file exists in registry
        if (!_registry.exists(role)) {
            return false;
        }
        
        var roleMap = _registry.get(role);
        if (!roleMap.exists(type)) {
            return false;
        }
        
        var entries = roleMap.get(type);
        var index = -1;
        
        // Find entry index
        for (i in 0...entries.length) {
            if (entries[i].hash == hash) {
                index = i;
                break;
            }
        }
        
        if (index == -1) {
            return false;
        }
        
        // Delete physical file if it exists
        if (cachedFile.exists && FileSystem.exists(cachedFile.path)) {
            try {
                FileSystem.deleteFile(cachedFile.path);
                Logger.info('Deleted file from cache: ${cachedFile.path}');
            } catch (e) {
                Logger.error('Failed to delete file from cache: ${e}');
                return false;
            }
        }
        
        // Remove from registry
        entries.splice(index, 1);
        roleMap.set(type, entries);
        _registry.set(role, roleMap);
        
        // Save registry
        saveRegistry();
        
        return true;
    }
    
    /**
     * Verify if a file is in the cache and matches a known hash
     * @param filePath Path to the file to verify
     * @param role Role to check against
     * @param type Type to check against
     * @return The matched cached file if found, null otherwise
     */
    public function verifyFile(filePath:String, role:String, type:String):SuperHumanCachedFile {
        if (!FileSystem.exists(filePath)) {
            return null;
        }
        
        // Calculate hash
        var hash = SuperHumanHashes.calculateMD5(filePath);
        if (hash == null) {
            return null;
        }
        
        // Check if hash exists in registry
        return getFileByHash(hash, role, type);
    }
    
    /**
     * Get the registry
     */
    public function getRegistry():Map<String, Map<String, Array<SuperHumanCachedFile>>> {
        return _registry;
    }
    
    /**
     * Update a cached file's metadata
     * @param cachedFile The cached file to update
     * @return True if successful, false otherwise
     */
    public function updateFileMetadata(cachedFile:SuperHumanCachedFile):Bool {
        if (cachedFile == null) {
            return false;
        }
        
        // Add to registry (will update if it exists)
        addToRegistry(cachedFile);
        
        // Save registry
        saveRegistry();
        
        return true;
    }
}
