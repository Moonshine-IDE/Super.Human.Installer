package superhuman.config;

import champaign.core.logging.Logger;
import haxe.Json;
import openfl.Assets;
import sys.FileSystem;
import sys.io.File;

class SuperHumanHashes
{
	/**
	 * Map of valid hashes with the following structure:
	 * - Key is product role (domino, leap, nomadweb, etc.)
	 * - Value is a map where:
	 *   - Key is file type (installers, hotfixes, fixpacks)
	 *   - Value is an array of hash entries with the following fields:
	 *     - hash: MD5 hash (for backward compatibility)
	 *     - sha256: SHA256 hash (more secure)
	 *     - fileName: Expected file name
	 *     - version: Version information object
	 */
	public static var validHashes:Map<String, Map<String, Array<{}>>>;
	
	// Path to the registry JSON file in application storage directory
	private static final REGISTRY_FILE_PATH =  "assets/config/initial-registry.json";
	
	// Public initializer that should be called after Logger is set up
	public static function initialize() {
		loadHashRegistry();
	}
	
	/**
	 * Load hash registry from JSON file
	 * Will initialize the validHashes map
	 */
	private static function loadHashRegistry():Void {
		// Initialize map
		validHashes = new Map<String, Map<String, Array<{}>>>();
		
		Logger.info('===== REGISTRY LOADING PROCESS =====');
		Logger.info('Current working directory: ${Sys.getCwd()}');
		Logger.info('Absolute path to registry file: ${sys.FileSystem.absolutePath(REGISTRY_FILE_PATH)}');
		Logger.info('Does Assets directory exist? ${FileSystem.exists("Assets")}');
		Logger.info('Does Assets/config directory exist? ${FileSystem.exists("Assets/config")}');
		Logger.info('Application storage directory: ${lime.system.System.applicationStorageDirectory}');
		Logger.info('Attempting to load hash registry from application storage: ${REGISTRY_FILE_PATH}');
		
		try {
			// Read the JSON file
			Logger.info('Reading registry file content from: ${REGISTRY_FILE_PATH}');
			var jsonContent = File.getContent(REGISTRY_FILE_PATH);
			Logger.info('Registry file content length: ${jsonContent.length} bytes');
			
			// Parse the JSON
			Logger.info('Parsing registry JSON content');
			var data:Dynamic = Json.parse(jsonContent);
			
			var totalEntries = 0;
			var roleCount = 0;
			
			// Convert the parsed data to our map structure
			Logger.info('Processing registry data structure');
			for (roleName in Reflect.fields(data)) {
				roleCount++;
				var roleMap = new Map<String, Array<{}>>();
				var roleData:Dynamic = Reflect.field(data, roleName);
				var roleEntries = 0;
				
				for (typeName in Reflect.fields(roleData)) {
					var entries:Array<Dynamic> = Reflect.field(roleData, typeName);
					var hashEntries:Array<{}> = [];
					
					// Convert each entry to a dynamic object
					for (entry in entries) {
						hashEntries.push(entry);
						roleEntries++;
						totalEntries++;
					}
					
					roleMap.set(typeName, hashEntries);
				}
				
				Logger.info('Loaded ${roleEntries} entries for role: ${roleName}');
				validHashes.set(roleName, roleMap);
			}
			
			Logger.info('Successfully loaded hash registry from ${REGISTRY_FILE_PATH}');
			Logger.info('Registry contains ${roleCount} roles and ${totalEntries} total entries');
			Logger.info('===== REGISTRY LOADING COMPLETE =====');
		} catch (e:Dynamic) {
			Logger.error('Failed to load hash registry: ${e}');
			
			// Initialize an empty registry if loading fails
			validHashes = new Map<String, Map<String, Array<{}>>>();
		}
	}
	
	public static function getInstallersHashes(installerType:String):Array<String> 
	{
		var hashes:Array<String> = [];
		
		// Check if installerType exists in validHashes
		if (validHashes == null || !validHashes.exists(installerType)) {
			Logger.warning('No valid hashes found for installer type: ${installerType}');
			return hashes;
		}
		
		var roleMap = validHashes.get(installerType);
		
		// Check if "installers" exists in the role map
		if (roleMap == null || !roleMap.exists("installers")) {
			Logger.warning('No "installers" entry found for installer type: ${installerType}');
			return hashes;
		}
		
		var installersHashes:Array<Dynamic> = roleMap.get("installers");
		
		// Check if installersHashes is null
		if (installersHashes == null) {
			Logger.warning('Null installers array for installer type: ${installerType}');
			return hashes;
		}
		
		// Extract hash values
		hashes = installersHashes.map(function(item:Dynamic):String {
			if (item == null || !Reflect.hasField(item, "hash")) {
				return "unknown";
			}
			return item.hash;
		});
		
		return hashes;
	}
	
	public static function getHotFixesHashes(installerType:String):Array<String> 
	{
		var hashes:Array<String> = [];
		
		// Check if installerType exists in validHashes
		if (validHashes == null || !validHashes.exists(installerType)) {
			Logger.warning('No valid hashes found for installer type: ${installerType}');
			return hashes;
		}
		
		var roleMap = validHashes.get(installerType);
		
		// Check if "hotfixes" exists in the role map
		if (roleMap == null || !roleMap.exists("hotfixes")) {
			Logger.warning('No "hotfixes" entry found for installer type: ${installerType}');
			return hashes;
		}
		
		var installersHashes:Array<Dynamic> = roleMap.get("hotfixes");
		
		// Check if installersHashes is null
		if (installersHashes == null) {
			Logger.warning('Null hotfixes array for installer type: ${installerType}');
			return hashes;
		}
		
		// Extract hash values
		hashes = installersHashes.map(function(item:Dynamic):String {
			if (item == null || !Reflect.hasField(item, "hash")) {
				return "unknown";
			}
			return item.hash;
		});
		
		return hashes;
	}
	
	public static function getFixPacksHashes(installerType:String):Array<String> 
	{
		var hashes:Array<String> = [];
		
		// Check if installerType exists in validHashes
		if (validHashes == null || !validHashes.exists(installerType)) {
			Logger.warning('No valid hashes found for installer type: ${installerType}');
			return hashes;
		}
		
		var roleMap = validHashes.get(installerType);
		
		// Check if "fixpacks" exists in the role map
		if (roleMap == null || !roleMap.exists("fixpacks")) {
			Logger.warning('No "fixpacks" entry found for installer type: ${installerType}');
			return hashes;
		}
		
		var installersHashes:Array<Dynamic> = roleMap.get("fixpacks");
		
		// Check if installersHashes is null
		if (installersHashes == null) {
			Logger.warning('Null fixpacks array for installer type: ${installerType}');
			return hashes;
		}
		
		// Extract hash values
		hashes = installersHashes.map(function(item:Dynamic):String {
			if (item == null || !Reflect.hasField(item, "hash")) {
				return "unknown";
			}
			return item.hash;
		});
		
		return hashes;
	}
	
	public static function getInstallerVersion(installerType:String, hash:String):{}
	{
		// Check if installerType exists in validHashes
		if (validHashes == null || !validHashes.exists(installerType)) {
			Logger.warning('No valid hashes found for installer type: ${installerType}');
			return null;
		}
		
		var roleMap = validHashes.get(installerType);
		
		// Check if "installers" exists in the role map
		if (roleMap == null || !roleMap.exists("installers")) {
			Logger.warning('No "installers" entry found for installer type: ${installerType}');
			return null;
		}
		
		var installersHashes:Array<Dynamic> = roleMap.get("installers");
		
		// Check if installersHashes is null
		if (installersHashes == null) {
			Logger.warning('Null installers array for installer type: ${installerType}');
			return null;
		}
		
		var version:{} = getVersion(installersHashes, hash);
		return version;
	}
	
	public static function getHotfixesVersion(installerType:String, hash:String):{}
	{
		// Check if installerType exists in validHashes
		if (validHashes == null || !validHashes.exists(installerType)) {
			Logger.warning('No valid hashes found for installer type: ${installerType}');
			return null;
		}
		
		var roleMap = validHashes.get(installerType);
		
		// Check if "hotfixes" exists in the role map
		if (roleMap == null || !roleMap.exists("hotfixes")) {
			Logger.warning('No "hotfixes" entry found for installer type: ${installerType}');
			return null;
		}
		
		var installersHashes:Array<Dynamic> = roleMap.get("hotfixes");
		
		// Check if installersHashes is null
		if (installersHashes == null) {
			Logger.warning('Null hotfixes array for installer type: ${installerType}');
			return null;
		}
		
		var version:{} = getVersion(installersHashes, hash);
		return version;
	}
	
	public static function getFixpacksVersion(installerType:String, hash:String):{}
	{
		// Check if installerType exists in validHashes
		if (validHashes == null || !validHashes.exists(installerType)) {
			Logger.warning('No valid hashes found for installer type: ${installerType}');
			return null;
		}
		
		var roleMap = validHashes.get(installerType);
		
		// Check if "fixpacks" exists in the role map
		if (roleMap == null || !roleMap.exists("fixpacks")) {
			Logger.warning('No "fixpacks" entry found for installer type: ${installerType}');
			return null;
		}
		
		var installersHashes:Array<Dynamic> = roleMap.get("fixpacks");
		
		// Check if installersHashes is null
		if (installersHashes == null) {
			Logger.warning('Null fixpacks array for installer type: ${installerType}');
			return null;
		}
		
		var version:{} = getVersion(installersHashes, hash);
		return version;
	}
	
	public static function getHash(installerType:String, hashType:String, fullVersion:String):String
	{
		// Check if installerType exists in validHashes
		if (validHashes == null || !validHashes.exists(installerType)) {
			Logger.warning('No valid hashes found for installer type: ${installerType}');
			return "";
		}
		
		var roleMap = validHashes.get(installerType);
		
		// Check if hashType exists in the role map
		if (roleMap == null || !roleMap.exists(hashType)) {
			Logger.warning('No "${hashType}" entry found for installer type: ${installerType}');
			return "";
		}
		
		var installers:Array<Dynamic> = roleMap.get(hashType);
		
		// Check if installers is null
		if (installers == null) {
			Logger.warning('Null ${hashType} array for installer type: ${installerType}');
			return "";
		}
		
		var filteredHashes:Array<Dynamic> = installers.filter(function(item:Dynamic):Bool {
			return item != null && 
			       Reflect.hasField(item, "version") && 
			       Reflect.hasField(item.version, "fullVersion") && 
			       item.version.fullVersion == fullVersion;
		});
		
		if (filteredHashes != null && filteredHashes.length > 0) {
			var result = filteredHashes[0];
			if (result != null && Reflect.hasField(result, "hash")) {
				return result.hash;
			}
		}
		
		return "";
	}
	
	private static function getVersion(installerHashes:Array<Dynamic>, hash:String):{}
	{
		var version:{} = null;
		
		// Handle null/empty inputs
		if (installerHashes == null || hash == null || hash.length == 0) {
			Logger.warning('getVersion called with invalid parameters: installerHashes=${installerHashes != null}, hash=${hash}');
			return null;
		}
		
		// Safely filter, checking for null items and hash field existence
		var filteredHashes:Array<Dynamic> = installerHashes.filter(function(item:Dynamic):Bool {
			return item != null && Reflect.hasField(item, "hash") && item.hash == hash;
		});
		
		if (filteredHashes != null && filteredHashes.length > 0)
		{
			var firstItem = filteredHashes[0];
			// Check if the version field exists
			if (Reflect.hasField(firstItem, "version")) {
				version = firstItem.version;
			} else {
				Logger.warning('Found item with hash ${hash} but it has no version field');
			}
		}
		
		return version;
	}
	
	/**
	 * Find the matching entry in the hash registry
	 * @param hash MD5 or SHA256 hash to look up
	 * @param role Optional role to search in
	 * @param type Optional type to search in
	 * @return The matching entry if found, or null if not found
	 */
	public static function findHashEntry(hash:String, ?role:String, ?type:String):Dynamic {
		if (hash == null || hash.length == 0) return null;
		
		// If role and type are specified, search only in that role and type
		if (role != null && type != null) {
			if (validHashes.exists(role)) {
				var roleMap = validHashes.get(role);
				if (roleMap.exists(type)) {
					var entries:Array<Dynamic> = roleMap.get(type);
					for (entry in entries) {
						if ((entry.hash != null && entry.hash == hash) || 
							(Reflect.hasField(entry, "sha256") && Reflect.field(entry, "sha256") == hash)) {
							return entry;
						}
					}
				}
			}
		}
		// If only role is specified, search in all types for that role
		else if (role != null) {
			if (validHashes.exists(role)) {
				var roleMap = validHashes.get(role);
				for (type in roleMap.keys()) {
					var entries:Array<Dynamic> = roleMap.get(type);
					for (entry in entries) {
						if ((entry.hash != null && entry.hash == hash) || 
							(Reflect.hasField(entry, "sha256") && Reflect.field(entry, "sha256") == hash)) {
							return entry;
						}
					}
				}
			}
		}
		// If only type is specified, search in all roles for that type
		else if (type != null) {
			for (role in validHashes.keys()) {
				var roleMap = validHashes.get(role);
				if (roleMap.exists(type)) {
					var entries:Array<Dynamic> = roleMap.get(type);
					for (entry in entries) {
						if ((entry.hash != null && entry.hash == hash) || 
							(Reflect.hasField(entry, "sha256") && Reflect.field(entry, "sha256") == hash)) {
							return entry;
						}
					}
				}
			}
		}
		// If neither role nor type is specified, search in all roles and types
		else {
			for (role in validHashes.keys()) {
				var roleMap = validHashes.get(role);
				for (type in roleMap.keys()) {
					var entries:Array<Dynamic> = roleMap.get(type);
					for (entry in entries) {
						if ((entry.hash != null && entry.hash == hash) || 
							(Reflect.hasField(entry, "sha256") && Reflect.field(entry, "sha256") == hash)) {
							return entry;
						}
					}
				}
			}
		}
		
		return null;
	}
	
	/**
	 * Calculate MD5 hash for a file
	 * @param filePath Path to the file
	 * @return MD5 hash string or null if failed
	 */
	public static function calculateMD5(filePath:String):String {
		if (!sys.FileSystem.exists(filePath)) {
			return null;
		}
		
		try {
			// Log the command that will be used
			#if windows
			champaign.core.logging.Logger.info('[Shell]: Checking MD5 with command: certutil -hashfile "${filePath}" MD5');
			#elseif mac
			champaign.core.logging.Logger.info('[Shell]: Checking MD5 with command: md5 "${filePath}"');
			#else
			champaign.core.logging.Logger.info('[Shell]: Checking MD5 with command: md5sum "${filePath}"');
			#end
			
			// Use Shell.md5() directly instead of FileTools.checkMD5()
			// This avoids the issue where checkMD5 requires a matching hash in the array
			var hash = prominic.sys.applications.bin.Shell.getInstance().md5(filePath);
			if (hash != null) {
				champaign.core.logging.Logger.info('MD5 hash calculated successfully: ${hash}');
				return hash;
			}
			
			champaign.core.logging.Logger.error('MD5 calculation returned null');
			return null;
		} catch (e) {
			champaign.core.logging.Logger.error('Failed to calculate MD5 hash: ${e}');
			return null;
		}
	}
	
	/**
	 * Calculate SHA256 hash for a file asynchronously
	 * @param filePath Path to the file
	 * @param callback Function to call with the calculated hash (or null if failed)
	 */
	public static function calculateSHA256Async(filePath:String, callback:(hash:String) -> Void):Void {
		if (!sys.FileSystem.exists(filePath)) {
			callback(null);
			return;
		}
		
		try {
			var command:String;
			var args:Array<String>;
			
			// Prepare command based on platform
			#if windows
			command = "certutil.exe";
			args = ["-hashfile", filePath, "SHA256"];
			champaign.core.logging.Logger.info('[Shell]: Checking SHA256 with command: certutil -hashfile "${filePath}" SHA256');
			#elseif mac
			command = "shasum";
			args = ["-a", "256", filePath];
			champaign.core.logging.Logger.info('[Shell]: Checking SHA256 with command: shasum -a 256 "${filePath}"');
			#else
			command = "sha256sum";
			args = [filePath];
			champaign.core.logging.Logger.info('[Shell]: Checking SHA256 with command: sha256sum "${filePath}"');
			#end
			
			// Create executor for the appropriate command
			var executor = new prominic.sys.io.Executor(command, args);
			
			// Set up output buffer
			var outputBuffer = new StringBuf();
			
			// Set up event handlers
			executor.onStdOut.add(function(e, data) {
				if (data != null) {
					outputBuffer.add(data);
				}
			});
			
			executor.onStop.add(function(e) {
				// Parse output based on platform
				var hash:String = null;
				var output = outputBuffer.toString();
				
				if (output != null && output.length > 0) {
					#if windows
					// Parse Windows certutil output
					var lines = output.split("\n");
					if (lines.length >= 2) {
						hash = StringTools.trim(lines[1]).toLowerCase();
					}
					#else
					// Parse Mac/Linux output (both have similar formats)
					var parts = output.split(" ");
					if (parts.length > 0) {
						hash = StringTools.trim(parts[0]).toLowerCase();
					}
					#end
				}
				
				if (hash != null) {
					champaign.core.logging.Logger.info('SHA256 hash calculated successfully: ${hash}');
					callback(hash);
				} else {
					champaign.core.logging.Logger.error('SHA256 calculation returned null');
					callback(null);
				}
			});
			
			// Start the process
			executor.execute();
		} catch (e) {
			champaign.core.logging.Logger.error('Failed to calculate SHA256 hash: ${e}');
			callback(null);
		}
	}
	
	/**
	 * Get fileName for a given hash
	 * @param hash The hash to look up
	 * @param role Optional role to limit search
	 * @param type Optional type to limit search
	 * @return The fileName if found, null otherwise
	 */
	public static function getFileNameForHash(hash:String, ?role:String, ?type:String):String {
		// Search by both MD5 and SHA256 hashes
		
		// If role and type are specified, search only in that role and type
		if (role != null && type != null) {
			if (validHashes.exists(role)) {
				var roleMap = validHashes.get(role);
				if (roleMap.exists(type)) {
					var entries:Array<Dynamic> = roleMap.get(type);
					for (entry in entries) {
						if ((entry.hash != null && entry.hash == hash) || 
							(Reflect.hasField(entry, "sha256") && Reflect.field(entry, "sha256") == hash)) {
							return Reflect.hasField(entry, "fileName") ? Reflect.field(entry, "fileName") : null;
						}
					}
				}
			}
		}
		// If only role is specified, search in all types for that role
		else if (role != null) {
			if (validHashes.exists(role)) {
				var roleMap = validHashes.get(role);
				for (type in roleMap.keys()) {
					var entries:Array<Dynamic> = roleMap.get(type);
					for (entry in entries) {
						if ((entry.hash != null && entry.hash == hash) || 
							(Reflect.hasField(entry, "sha256") && Reflect.field(entry, "sha256") == hash)) {
							return Reflect.hasField(entry, "fileName") ? Reflect.field(entry, "fileName") : null;
						}
					}
				}
			}
		}
		// If only type is specified, search in all roles for that type
		else if (type != null) {
			for (role in validHashes.keys()) {
				var roleMap = validHashes.get(role);
				if (roleMap.exists(type)) {
					var entries:Array<Dynamic> = roleMap.get(type);
					for (entry in entries) {
						if ((entry.hash != null && entry.hash == hash) || 
							(Reflect.hasField(entry, "sha256") && Reflect.field(entry, "sha256") == hash)) {
							return Reflect.hasField(entry, "fileName") ? Reflect.field(entry, "fileName") : null;
						}
					}
				}
			}
		}
		// If neither role nor type is specified, search in all roles and types
		else {
			for (role in validHashes.keys()) {
				var roleMap = validHashes.get(role);
				for (type in roleMap.keys()) {
					var entries:Array<Dynamic> = roleMap.get(type);
					for (entry in entries) {
						if ((entry.hash != null && entry.hash == hash) || 
							(Reflect.hasField(entry, "sha256") && Reflect.field(entry, "sha256") == hash)) {
							return Reflect.hasField(entry, "fileName") ? Reflect.field(entry, "fileName") : null;
						}
					}
				}
			}
		}
		
		return null;
	}
	
	// Chunking method removed - we now only use the system commands via FileTools
}
