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

package superhuman.server;

import genesis.application.managers.LanguageManager;
import haxe.Exception;
import haxe.io.Path;
import prominic.core.primitives.VersionInfo;
import prominic.logging.Logger;
import prominic.sys.io.FileTools;
import superhuman.interfaces.IConsole;
import sys.FileSystem;
import sys.io.File;

class DominoVagrant {

    static final _HOSTS_FILE:String = "Hosts.yml";
    static final _SAFE_ID_FILE:String = "safe.ids";
    static final _SAFE_ID_LOCATION:String = "safe-id-to-cross-certify";
    static final _VERSION_FILE:String = "version.rb";
    static final _VERSION_PATTERN:EReg = ~/(\d{1,3}\.\d{1,3}\.\d{1,3})/;

    static public var HOSTS_TEMPLATE_PATH:String;

    static public function getVersionFromFile( path:String ):VersionInfo {

        var v:VersionInfo = "0.0.0";

        try {

            var c = File.getContent( path );
            var m = _VERSION_PATTERN.match( c );
            if ( m )
                v = _VERSION_PATTERN.matched( 0 )
            else
                v = "0.0.0";

        } catch( e ) {

            v = "0.0.0";

        }

        return v;

    }

    var _exists:Bool = false;
    var _sourcePath:String;
    var _targetPath:String;
    var _version:VersionInfo;

    public var console:IConsole;

    public var exists( get, never ):Bool;
    function get_exists() return FileSystem.exists( Path.addTrailingSlash( _targetPath ) + _VERSION_FILE );

    public var hostFileExists( get, never ):Bool;
    function get_hostFileExists() return FileSystem.exists( Path.addTrailingSlash( _targetPath ) + _HOSTS_FILE );

    public var safeIdExists( get, never ):Bool;
    function get_safeIdExists() return FileSystem.exists( Path.addTrailingSlash( _targetPath ) + Path.addTrailingSlash( _SAFE_ID_LOCATION ) + _SAFE_ID_FILE );

    public var version( get, never ):VersionInfo;
    function get_version() return _version;
    
    public function new( sourcePath:String, targetPath:String ) {

        _sourcePath = sourcePath;
        _targetPath = targetPath;

        _version = DominoVagrant.getVersionFromFile( Path.addTrailingSlash( _targetPath ) + _VERSION_FILE );
        if ( _version == "0.0.0" ) _version = DominoVagrant.getVersionFromFile( Path.addTrailingSlash( _sourcePath ) + _VERSION_FILE );

    }

    public function clearTargetDirectory() {



    }

    public function copyFiles( ?callback:()->Void ) {

        if ( exists ) {

            if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.copyvagrantfiles', _targetPath, "(not required, skipping)" ) );
            if ( callback != null ) callback();
            return;

        }

        Logger.debug( 'Copying server configuration files to ${_targetPath}' );
        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.copyvagrantfiles', _targetPath, "" ) );
        FileTools.copyDirectory( _sourcePath, _targetPath, FileOverwriteRule.Always, callback );

    }

    public function copyInstallers( pathPairs:Array<PathPair>, callback:()->Void ) {

        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.copyinstallers', _targetPath ) );
        FileTools.batchCopy( pathPairs, FileOverwriteRule.IfSizeDifferent, callback, _fileCopied );

    }

    public function createTargetDirectory() {

        if ( !FileSystem.exists( _targetPath ) ) FileSystem.createDirectory( _targetPath );

    }

    public function getSourceHostsFileContent():String {

        var r:String = "";

        try {

            r = File.getContent( HOSTS_TEMPLATE_PATH );

        } catch ( e ) {}

        return r;

    }

    public function getTargetHostsFileContent():String {

        var r:String = null;

        try {

            r = File.getContent( Path.addTrailingSlash( _targetPath ) + _HOSTS_FILE );

        } catch ( e ) {}

        return r;

    }

    public function saveHostsFile( content:String ) {

        createTargetDirectory();

        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.hostsfilecontent', content ) );

        try {

            File.saveContent( Path.addTrailingSlash( _targetPath ) + _HOSTS_FILE, content );
            Logger.debug( 'Server configuration file created at ${Path.addTrailingSlash( _targetPath ) + _HOSTS_FILE}' );
            if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.savehostsfile', Path.addTrailingSlash( _targetPath ) + _HOSTS_FILE ) );

        } catch ( e:Exception ) {

            Logger.error( 'Server configuration file cannot be created at ${Path.addTrailingSlash( _targetPath ) + _HOSTS_FILE}. Details: ${e.details()} Message: ${e.message}' );
            if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.savehostsfileerror', Path.addTrailingSlash( _targetPath ) + _HOSTS_FILE, '${e.details()} Message: ${e.message}' ), true );
            return;

        }

    }

    public function saveSafeId( safeIdPath:String ):Bool {

        createTargetDirectory();

        if ( FileSystem.exists( safeIdPath ) ) {

            var safeIdDir = Path.addTrailingSlash( _targetPath ) + Path.addTrailingSlash( _SAFE_ID_LOCATION );
            FileSystem.createDirectory( safeIdDir );

            try {

                File.copy( safeIdPath, safeIdDir + _SAFE_ID_FILE );
                if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.copysafeid', safeIdPath, safeIdDir + _SAFE_ID_FILE ) );
                return true;

            } catch ( e:Exception ) {

                Logger.error( 'Notes Safe ID at ${safeIdPath} cannot be copied to ${safeIdDir + _SAFE_ID_FILE}. Details: ${e.details()} Message: ${e.message}' );
                if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.copysafeidfailed', '${e.details()} Message: ${e.message}' ), true );

            }

        } else {

            Logger.error( 'Notes Safe ID does not exist at ${safeIdPath}' );
            if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.safeidnonexistent', safeIdPath ), true );

        }

        return false;

    }

    function _fileCopied( pathPair:PathPair, canCopy:Bool ) {

        if ( console != null ) {

            if ( canCopy ) {

                console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.copyinstaller', pathPair.source, pathPair.destination ) );

            } else {

                console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.installerexists', Path.withoutDirectory( pathPair.source ) ) );

            }

        }

    }

}