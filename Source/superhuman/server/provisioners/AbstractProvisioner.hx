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
import champaign.core.primitives.VersionInfo;
import genesis.application.managers.LanguageManager;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.io.BytesOutput;
import haxe.io.Path;
import haxe.zip.Entry;
import haxe.zip.Reader;
import haxe.zip.Tools;
import haxe.zip.Writer;
import lime.system.FileWatcher;
import prominic.sys.io.FileTools;
import superhuman.interfaces.IConsole;
import superhuman.server.data.ProvisionerData;
import superhuman.server.provisioners.ProvisionerType;
import sys.FileSystem;
import sys.io.File;

class AbstractProvisioner {

    static final _SCRIPTS_ROOT:String = "";
    static final _TEMPLATES_ROOT:String = "templates/";
    static final _CORE_ROOT:String = "core/";
    
    /**
     * Convert a path to the platform-specific format with long path support for Windows
     * @param path The original path 
     * @return The platform-appropriate path
     */
    #if windows
    private function _getWindowsLongPath(path:String):String {
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
    private function _getPlatformPath(path:String):String {
        #if windows
        return _getWindowsLongPath(path);
        #else
        return path;
        #end
    }
    
    var _exists:Bool = false;
    var _fileWatcher:FileWatcher;
    var _onFileAdded:List<(String)->Void>;
    var _onFileDeleted:List<(String)->Void>;
    var _server:Server;
    var _sourcePath:String;
    var _targetPath:String;
    var _type:ProvisionerType;
    var _version:VersionInfo;
    var _versionFile:String = "version.txt";

    public var console:IConsole;

    public var data( get, never ):ProvisionerData;
    function get_data():ProvisionerData return { type: _type, version: _version };

    public var exists( get, never ):Bool;
    function get_exists() return FileSystem.exists( Path.addTrailingSlash( _targetPath ) + _versionFile );

    public var onFileAdded( get, never ):List<(String)->Void>;
    function get_onFileAdded() return _onFileAdded;

    public var onFileDeleted( get, never ):List<(String)->Void>;
    function get_onFileDeleted() return _onFileDeleted;

    public var targetPath( get, never ):String;
    function get_targetPath() return Path.addTrailingSlash( _targetPath );

    public var type( get, never ):ProvisionerType;
    function get_type() return _type;

    public var version( get, never ):VersionInfo;
    function get_version() return _version;

    function new( type:ProvisionerType, sourcePath:String, targetPath:String, server:Server ) {

        _type = type;
        _sourcePath = sourcePath;
        _targetPath = targetPath;
        _server = server;

        _onFileAdded = new List();
        _onFileDeleted = new List();

    }

    public function clearTargetDirectory() {

        Logger.info('${this}: Deleting target directory: ${_targetPath}');
        FileTools.deleteDirectory( _targetPath );
        FileSystem.createDirectory( _targetPath );

    }

    public function copyFiles( ?callback:()->Void ) {

        if ( exists ) {
            if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.copyvagrantfiles', _targetPath, "(not required, skipping)" ) );
            if ( callback != null ) callback();
            return;
        }

        // Create target directory if it doesn't exist
        createTargetDirectory();

        Logger.info( '${this}: Copying server configuration files to ${_targetPath} using zip/unzip method' );
        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.copyvagrantfiles', _targetPath, "" ) );
        
        try {
            // First zip the provisioners directory
            var zipBytes = _zipDirectory( Path.addTrailingSlash( _sourcePath ) + _SCRIPTS_ROOT );
            
            // Then unzip to the target directory
            _unzipToDirectory( zipBytes, _targetPath );
            
            Logger.info( '${this}: Successfully copied files using zip/unzip method' );
            if ( callback != null ) callback();
            
        } catch ( e ) {
            Logger.error( '${this}: Error copying files using zip/unzip: ${e}' );
            if ( console != null ) console.appendText( 'Error copying provisioner files: ${e}', true );
            
            // Fall back to direct copy if zip/unzip fails
            Logger.info( '${this}: Falling back to direct copy method' );
            if ( console != null ) console.appendText( 'Falling back to direct copy method', true );
            
            try {
                FileTools.copyDirectory( Path.addTrailingSlash( _sourcePath ) + _SCRIPTS_ROOT, _targetPath, FileOverwriteRule.Always, callback );
            } catch ( e ) {
                Logger.error( '${this}: Error during fallback direct copy: ${e}' );
                if ( console != null ) console.appendText( 'Error during fallback direct copy: ${e}', true );
            }
        }
    }
    
    /**
     * Zip a directory and return the zipped bytes
     * @param directory The directory to zip
     * @return Bytes The zipped content
     */
    private function _zipDirectory( directory:String ):Bytes {
        Logger.info( '${this}: Zipping directory: ${directory}' );
        var entries:List<Entry> = new List<Entry>();
        _addDirectoryToZip( directory, "", entries );
        
        var out = new BytesOutput();
        var writer = new Writer( out );
        writer.write( entries );
        
        return out.getBytes();
    }
    
    /**
     * Helper function to recursively add files to a zip archive
     * Uses no compression to avoid ZLib errors with deeply nested paths
     * @param directory The base directory
     * @param path The current path within the zip
     * @param entries The list of zip entries
     */
    private function _addDirectoryToZip( directory:String, path:String, entries:List<Entry> ):Void {
        try {
            // Use platform-specific path for directory operations
            var platformDirectory = _getPlatformPath(directory);
            var items = FileSystem.readDirectory(platformDirectory);
            
            for ( item in items ) {
                var itemPath = Path.addTrailingSlash(directory) + item;
                var platformItemPath = _getPlatformPath(itemPath);
                var zipPath = path.length > 0 ? path + "/" + item : item;
                
                if ( FileSystem.isDirectory(platformItemPath) ) {
                    // Add directory entry
                    var entry:Entry = {
                        fileName: zipPath + "/",
                        fileSize: 0,
                        fileTime: Date.now(),
                        compressed: false,
                        dataSize: 0,
                        data: Bytes.alloc( 0 ),
                        crc32: 0
                    };
                    entries.add( entry );
                    
                    // Recursively add directory contents
                    _addDirectoryToZip( itemPath, zipPath, entries );
                } else {
                    // Add file entry without compression
                    try {
                        var data = File.getBytes(platformItemPath);
                        var entry:Entry = {
                            fileName: zipPath,
                            fileSize: data.length,
                            fileTime: FileSystem.stat(platformItemPath).mtime,
                            compressed: false, // No compression
                            dataSize: data.length,
                            data: data,
                            crc32: haxe.crypto.Crc32.make( data )
                        };
                        entries.add( entry );
                    } catch ( e ) {
                        Logger.warning( '${this}: Could not add file to zip: ${itemPath} - ${e}' );
                    }
                }
            }
        } catch ( e ) {
            Logger.error( '${this}: Error reading directory: ${directory} - ${e}' );
            throw e;
        }
    }
    
    /**
     * Unzip bytes to a directory
     * @param zipBytes The zipped content
     * @param directory The directory to unzip to
     */
    private function _unzipToDirectory( zipBytes:Bytes, directory:String ):Void {
        Logger.info( '${this}: Unzipping to directory: ${directory}' );
        var entries = Reader.readZip( new BytesInput( zipBytes ) );
        
        for ( entry in entries ) {
            var fileName = entry.fileName;
            
            // Skip directory entries
            if ( fileName.length > 0 && fileName.charAt( fileName.length - 1 ) == "/" ) {
                var dirPath = Path.addTrailingSlash( directory ) + fileName;
                _createDirectoryRecursive( dirPath );
                continue;
            }
            
            // Create parent directories if needed
            var filePath = Path.addTrailingSlash( directory ) + fileName;
            var parentDir = Path.directory( filePath );
            _createDirectoryRecursive( parentDir );
            
            // Extract file
            try {
                var data = entry.data;
                if ( entry.compressed ) {
                    Tools.uncompress( entry );
                }
                var platformFilePath = _getPlatformPath(filePath);
                File.saveBytes( platformFilePath, entry.data );
            } catch ( e ) {
                Logger.warning( '${this}: Could not extract file from zip: ${fileName} - ${e}' );
            }
        }
        Logger.info( '${this}: Unzip completed' );
    }
    
    /**
     * Create a directory and all parent directories if they don't exist
     * @param directory The directory path to create
     */
    private function _createDirectoryRecursive( directory:String ):Void {
        if ( directory == null || directory == "" ) {
            return;
        }
        
        var platformDir = _getPlatformPath(directory);
        if ( FileSystem.exists(platformDir) ) {
            return;
        }
        
        _createDirectoryRecursive( Path.directory( directory ) );
        FileSystem.createDirectory( platformDir );
    }

    public function createTargetDirectory() {

        if ( !FileSystem.exists( _getPlatformPath(_targetPath) ) ) {
            FileSystem.createDirectory( _getPlatformPath(_targetPath) );
        }

    }

    public function deleteFileInTargetDirectory( path:String ):Bool {

        try {
            var fullPath = Path.addTrailingSlash( _targetPath ) + path;
            FileSystem.deleteFile( _getPlatformPath(fullPath) );
            return true;

        } catch( e ) {}

        return false;

    }

    public function dispose() {
        
        stopFileWatcher();

        if ( _onFileAdded != null ) _onFileAdded.clear();
        _onFileAdded = null;
        if ( _onFileDeleted != null ) _onFileDeleted.clear();
        _onFileDeleted = null;

    }

    public function fileExists( path:String ):Bool {

        var fullPath = Path.addTrailingSlash( _targetPath ) + path;
        return FileSystem.exists( _getPlatformPath(fullPath) );

    }

    public function getFileContentFromSourceScriptsDirectory( path:String ):String {
    // This supports both traditional directory structures and GitHub nested directory structures
        var fullPath = Path.addTrailingSlash( _sourcePath ) + path;
        
        // First try the direct path (for root-level files)
        if ( FileSystem.exists( _getPlatformPath(fullPath) ) ) {
            try {
                return File.getContent( _getPlatformPath(fullPath) );
            } catch( e ) {
                Logger.error('Error reading file at ${fullPath}: ${e}');
            }
        }
        
        return null;
    }

    public function getFileContentFromSourceTemplateDirectory( path:String ):String {

    		var srcPath:String = Path.addTrailingSlash( _sourcePath );
    		var tmplRoot:String = _TEMPLATES_ROOT;
    		var p:String = path;
    		
    		var fullPath = srcPath + _TEMPLATES_ROOT + path;
    		var platformPath = _getPlatformPath(fullPath);
    		
    		try {
			if ( !FileSystem.exists( platformPath ) ) {
				return null;
			}
    		}
       	catch( e ) {
       		return null;
       	}
        
        try {
            return File.getContent( platformPath );
        } catch( e ) {}

        return null;

    }

    public function getFileContentFromTargetDirectory( path:String ):String {

        var fullPath = Path.addTrailingSlash( _targetPath ) + path;
        if ( !FileSystem.exists( _getPlatformPath(fullPath) ) ) return null;
        
        try {
            return File.getContent( _getPlatformPath(fullPath) );
        } catch( e ) {}

        return null;

    }

    public function reinitialize( sourcePath:String ) {

        // Only clear the target directory if the source path actually changed
        // This preserves user customizations when just navigating between pages
        if (_sourcePath != sourcePath) {
            Logger.info('${this}: Source path changed from ${_sourcePath} to ${sourcePath}, clearing target directory');
            clearTargetDirectory();
            _sourcePath = sourcePath;
        } else {
            Logger.info('${this}: Source path unchanged (${sourcePath}), preserving existing files');
        }

    }

    public function saveContentToFileInTargetDirectory( path:String, content:String ):Bool {

        try {
            var fullPath = Path.addTrailingSlash( _targetPath ) + path;
            File.saveContent( _getPlatformPath(fullPath), content );
            return true;
        } catch( e ) {}

        return false;

    }

    public function startFileWatcher() {

        if ( _fileWatcher == null ) {

            _fileWatcher = new FileWatcher();
            _fileWatcher.onAdd.add( _onFileWatcherFileAdded );
            _fileWatcher.onDelete.add( _onFileWatcherFileDeleted );
            _fileWatcher.addDirectory( this._targetPath, true );
            Logger.verbose( '${this}: FileWatcher started at: ${_targetPath}' );
    
        }

    }

    public function stopFileWatcher() {

        if ( _fileWatcher != null ) {

            _fileWatcher.onAdd.removeAll();
            _fileWatcher.onDelete.removeAll();
            _fileWatcher.removeDirectory( this._targetPath );
            _fileWatcher = null;
            Logger.verbose( '${this}: FileWatcher stopped at: ${_targetPath}' );

        }

    }

    public function generateHostsFileContent():String {
        return "";
    }

    public function toString():String {

        return '[AbstractProvisioner(v${this.version})]';

    }

    function _onFileWatcherFileAdded( path:String ) {

        Logger.verbose( '${this}: FileWatcher file added at: ${path}' );
        for ( f in _onFileAdded ) f( path );

    }

    function _onFileWatcherFileDeleted( path:String ) {

        Logger.verbose( '${this}: FileWatcher file deleted at: ${path}' );
        for ( f in _onFileDeleted ) f( path );

    }

}
