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

package genesis.application.updater;

import haxe.crypto.Md5;
import haxe.io.Path;
import haxe.xml.Access;
import lime.system.System;
import openfl.Lib;
import openfl.events.Event;
import openfl.events.EventDispatcher;
import openfl.events.IOErrorEvent;
import openfl.events.ProgressEvent;
import openfl.filesystem.File;
import openfl.filesystem.FileMode;
import openfl.filesystem.FileStream;
import openfl.net.URLLoader;
import openfl.net.URLLoaderDataFormat;
import openfl.net.URLRequest;
import openfl.utils.ByteArray;
import prominic.core.primitives.VersionInfo;
import prominic.logging.Logger;
import prominic.sys.applications.bin.Shell;
import sys.FileSystem;

class GenesisApplicationUpdater extends EventDispatcher {

    var _downloadLoader:URLLoader;
    var _installerFile:File;
    var _installerFileStream:FileStream;
    var _installerPath:String;
    var _installerTotalSize:Float;
    var _isDownloading:Bool = false;
    var _updaterInfo:GenesisApplicationUpdaterInfo;
    var _versionInfoLoader:URLLoader;
    var _versionInfoURL:String;

    public var isDownloading( get, never ):Bool;
    function get_isDownloading() return _isDownloading;

    public var updaterInfo( get, never ):GenesisApplicationUpdaterInfo;
    function get_updaterInfo() return _updaterInfo;
    
    public function new() {

        super();

    }

    public function cancelDownload() {

        if ( !_isDownloading || _downloadLoader == null ) return;

        Logger.info( 'Download cancelled' );

        _downloadLoader.removeEventListener( Event.COMPLETE, _downloadLoaderComplete );
        _downloadLoader.removeEventListener( ProgressEvent.PROGRESS, _downloadLoaderProgress );
        _downloadLoader.removeEventListener( IOErrorEvent.IO_ERROR, _downloadLoaderError );
        _downloadLoader.close();
        _downloadLoader = null;

        if ( FileSystem.exists( _installerPath ) ) FileSystem.deleteFile( _installerPath );

        _isDownloading = false;

        this.dispatchEvent( new GenesisApplicationUpdaterEvent( GenesisApplicationUpdaterEvent.DOWNLOAD_CANCELLED ) );

    }

    public function checkUpdates( versionInfoURL:String ) {

        _versionInfoURL = versionInfoURL;
        var request:URLRequest = new URLRequest( _versionInfoURL );
        _versionInfoLoader = new URLLoader();
        _versionInfoLoader.addEventListener( Event.COMPLETE, _versionInfoLoaderComplete );
        _versionInfoLoader.addEventListener( IOErrorEvent.IO_ERROR, _versionInfoLoaderError );
        _versionInfoLoader.load( request );

    }

    public function downloadUpdate() {

        if ( _updaterInfo == null ) {

            Logger.warning( 'VersionInfo not found, stopping updater' );
            return;

        }

        _installerPath = Path.addTrailingSlash( System.applicationStorageDirectory ) + "downloads";
        FileSystem.createDirectory( _installerPath );
        _installerPath += "/" + Path.withoutDirectory( _updaterInfo.url.split( 'https://' )[ 1 ] );
        if ( FileSystem.exists( _installerPath ) ) FileSystem.deleteFile( _installerPath );

        Logger.info( 'Downloading update from ${_updaterInfo.url} to ${_installerPath}' );

        var request = new URLRequest( _updaterInfo.url );

        _downloadLoader = new URLLoader();
        _downloadLoader.addEventListener( Event.COMPLETE, _downloadLoaderComplete );
        _downloadLoader.addEventListener( ProgressEvent.PROGRESS, _downloadLoaderProgress );
        _downloadLoader.addEventListener( IOErrorEvent.IO_ERROR, _downloadLoaderError );
        _downloadLoader.dataFormat = URLLoaderDataFormat.BINARY;
        _downloadLoader.load( request );

        _isDownloading = true;
        this.dispatchEvent( new GenesisApplicationUpdaterEvent( GenesisApplicationUpdaterEvent.DOWNLOAD_START ) );

    }

    public function launchInstaller( exitApp:Bool = false ) {

        Shell.getInstance().open( [ _installerPath ] );

        if ( exitApp ) this.dispatchEvent( new GenesisApplicationUpdaterEvent( GenesisApplicationUpdaterEvent.EXIT_APP ) );

    }

    function _downloadLoaderComplete( e:Event ) {

        Logger.info( 'Downloading update completed' );

        _downloadLoader.removeEventListener( Event.COMPLETE, _downloadLoaderComplete );
        _downloadLoader.removeEventListener( ProgressEvent.PROGRESS, _downloadLoaderProgress );
        _downloadLoader.removeEventListener( IOErrorEvent.IO_ERROR, _downloadLoaderError );

        _updateLocalFile( cast _downloadLoader.data );

        _isDownloading = false;

        var evt = new GenesisApplicationUpdaterEvent( GenesisApplicationUpdaterEvent.DOWNLOAD_COMPLETE );
        this.dispatchEvent( evt );

    }

    function _downloadLoaderError( e:IOErrorEvent ) {

        _downloadLoader.removeEventListener( Event.COMPLETE, _downloadLoaderComplete );
        _downloadLoader.removeEventListener( ProgressEvent.PROGRESS, _downloadLoaderProgress );
        _downloadLoader.removeEventListener( IOErrorEvent.IO_ERROR, _downloadLoaderError );

        Logger.error( 'VersionInfo download error at ${_versionInfoURL}. Error: ${e.errorID} ${e.text} ${e.type}' );

        _isDownloading = false;

        var evt = new GenesisApplicationUpdaterEvent( GenesisApplicationUpdaterEvent.DOWNLOAD_FAILED );
        this.dispatchEvent( evt );

    }

    function _downloadLoaderProgress( e:ProgressEvent ) {

        if ( e.bytesTotal != 0 ) _installerTotalSize = e.bytesTotal;

        var evt = new GenesisApplicationUpdaterEvent( GenesisApplicationUpdaterEvent.DOWNLOAD_PROGRESS );
        evt.bytesLoaded = e.bytesLoaded;
        evt.bytesTotal = e.bytesTotal;
        this.dispatchEvent( evt );

    }

    function _versionInfoLoaderComplete( e:Event ) {

        _versionInfoLoader.removeEventListener( Event.COMPLETE, _versionInfoLoaderComplete );
        _versionInfoLoader.removeEventListener( IOErrorEvent.IO_ERROR, _versionInfoLoaderError );
        _processVersionInfoData( _versionInfoLoader.data );

        var evt:GenesisApplicationUpdaterEvent = new GenesisApplicationUpdaterEvent( GenesisApplicationUpdaterEvent.UPDATE_NOT_FOUND );
        
        if ( this._updaterInfo.version != null && this._updaterInfo.url != null ) {

            var currentVersion:VersionInfo = Lib.application.meta.get( "version" );

            if ( this._updaterInfo.version > currentVersion )
                evt = new GenesisApplicationUpdaterEvent( GenesisApplicationUpdaterEvent.UPDATE_FOUND );

        }

        this.dispatchEvent( evt );

    }

    function _versionInfoLoaderError( e:IOErrorEvent ) {

        _versionInfoLoader.removeEventListener( Event.COMPLETE, _versionInfoLoaderComplete );
        _versionInfoLoader.removeEventListener( IOErrorEvent.IO_ERROR, _versionInfoLoaderError );

        Logger.error( 'VersionInfo download error at ${_versionInfoURL}. Error: ${e.errorID} ${e.text} ${e.type}' );
        this.dispatchEvent( new GenesisApplicationUpdaterEvent( GenesisApplicationUpdaterEvent.UPDATE_NOT_FOUND ) );

    }

    function _processVersionInfoData( data:String ) {

        var xml:Access = new Access( Xml.parse( data ) );

        try {

            #if windows
            var root = xml.node.update.node.exe;
            var version:VersionInfo = root.node.version.innerData;
            var url:String = root.node.url.innerData;
            var description:String = StringTools.trim( root.node.description.innerData );
            _updaterInfo = { version: version, url: url, description: description };
            #end

            #if mac
            var root = xml.node.update.node.pkg;
            var version:VersionInfo = root.node.version.innerData;
            var url:String = root.node.url.innerData;
            var description:String = StringTools.trim( root.node.description.innerData );
            _updaterInfo = { version: version, url: url, description: description };
            #end

            #if linux
            var version:VersionInfo = "0.0.0";
            _updaterInfo = { version: version, url: "", description: "" };
            #end

        } catch ( e ) {}

    }

    function _updateLocalFile( data:ByteArray ) {

        try {

            var m = Md5.make( data );
            Logger.verbose( 'Downloaded installer MD5: ${m.toHex()}' );

            _installerFile = new File( _installerPath );
            _installerFileStream = new FileStream();
            _installerFileStream.open( _installerFile, FileMode.WRITE );
            _installerFileStream.writeBytes( data );
            _installerFileStream.close();

        } catch ( e ) {

            Logger.error( 'Downloaded data cannot be written to ${_installerPath}' );

        }

    }

}