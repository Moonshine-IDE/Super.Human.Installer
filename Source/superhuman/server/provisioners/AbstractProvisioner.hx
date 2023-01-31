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

import genesis.application.managers.LanguageManager;
import haxe.io.Path;
import prominic.core.primitives.VersionInfo;
import prominic.logging.Logger;
import prominic.sys.io.FileTools;
import superhuman.interfaces.IConsole;
import superhuman.server.data.ProvisionerData;
import superhuman.server.provisioners.ProvisionerType;
import sys.FileSystem;
import sys.io.File;

class AbstractProvisioner {

    static final _SCRIPTS_ROOT:String = "scripts/";
    static final _TEMPLATES_ROOT:String = "templates/";
    
    var _exists:Bool = false;
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

    public var version( get, never ):VersionInfo;
    function get_version() return _version;

    function new( type:ProvisionerType, sourcePath:String, targetPath:String ) {

        _type = type;
        _sourcePath = sourcePath;
        _targetPath = targetPath;

    }

    public function clearTargetDirectory() {

        FileTools.deleteDirectory( _targetPath );
        FileSystem.createDirectory( _targetPath );

    }

    public function copyFiles( ?callback:()->Void ) {

        if ( exists ) {

            if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.copyvagrantfiles', _targetPath, "(not required, skipping)" ) );
            if ( callback != null ) callback();
            return;

        }

        Logger.debug( 'Copying server configuration files to ${_targetPath}' );
        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.copyvagrantfiles', _targetPath, "" ) );
        FileTools.copyDirectory( Path.addTrailingSlash( _sourcePath ) + _SCRIPTS_ROOT, _targetPath, FileOverwriteRule.Always, callback );

    }

    public function createTargetDirectory() {

        if ( !FileSystem.exists( _targetPath ) ) FileSystem.createDirectory( _targetPath );

    }

    public function deleteFileInTargetDirectory( path:String ):Bool {

        try {
            
            FileSystem.deleteFile( Path.addTrailingSlash( _targetPath ) + path );
            return true;

        } catch( e ) {}

        return false;

    }

    public function fileExists( path:String ):Bool {

        return FileSystem.exists( Path.addTrailingSlash( _targetPath ) + path );

    }

    public function getFileContentFromSourceScriptsDirectory( path:String ):String {

        if ( !FileSystem.exists( Path.addTrailingSlash( _sourcePath ) + _SCRIPTS_ROOT + path ) ) return null;
        
        try {

            return File.getContent( Path.addTrailingSlash( _sourcePath ) + _SCRIPTS_ROOT + path );

        } catch( e ) {}

        return null;

    }

    public function getFileContentFromSourceTemplateDirectory( path:String ):String {

        if ( !FileSystem.exists( Path.addTrailingSlash( _sourcePath ) + _TEMPLATES_ROOT + path ) ) return null;
        
        try {

            return File.getContent( Path.addTrailingSlash( _sourcePath ) + _TEMPLATES_ROOT + path );

        } catch( e ) {}

        return null;

    }

    public function getFileContentFromTargetDirectory( path:String ):String {

        if ( !FileSystem.exists( Path.addTrailingSlash( _targetPath ) + path ) ) return null;
        
        try {

            return File.getContent( Path.addTrailingSlash( _targetPath ) + path );

        } catch( e ) {}

        return null;

    }

    public function reinitialize( sourcePath:String ) {

        clearTargetDirectory();
        _sourcePath = sourcePath;

    }

    public function saveContentToFileInTargetDirectory( path:String, content:String ):Bool {

        try {

            File.saveContent( Path.addTrailingSlash( _targetPath ) + path, content );
            return true;

        } catch( e ) {}

        return false;

    }

}