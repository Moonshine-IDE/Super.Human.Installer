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

package prominic.sys.applications;

import champaign.core.ds.ChainedList;
import champaign.core.logging.Logger;
import champaign.core.primitives.VersionInfo;
import haxe.io.Path;
import prominic.sys.applications.bin.Which;
import prominic.sys.io.AbstractExecutor;
import prominic.sys.io.Executor;
import prominic.sys.io.ExecutorManager;
import prominic.sys.tools.SysTools;
import sys.io.Process;

@:allow( prominic.sys )
@:allow( prominic.sys.applications )
@:forwardStatics
abstract class AbstractApp {

    static final _DEFAULT_PATH_ADDITIONS:Array<String> = #if windows [ ] #elseif linux [ ] #elseif mac [ "/usr/local/bin" ] #else [] #end;

    var _env:Map<String, String>;
    var _executable:String;
    var _initialized:Bool = false;
    var _name:String;
    var _onInit:ChainedList<(AbstractApp) -> Void, AbstractApp>;
    var _path:String;
    var _pathAdditions:Array<String> = _DEFAULT_PATH_ADDITIONS;
    var _status:AppStatus;
    var _version:Null<VersionInfo>;

    public var executable( get, never ):String;
    function get_executable() return _executable;

    public var exists( get, never ):Bool;
    function get_exists() return _path != null;

    public var initialized( get, never ):Bool;
    function get_initialized() return _initialized;

    public var onInit( get, never ):ChainedList<(AbstractApp) -> Void, AbstractApp>;
    function get_onInit() return _onInit;

    public var path( get, never ):String;
    function get_path() return _path;

    public var status( get, never ):AppStatus;
    function get_status() return _status;

    public var version( get, never ):Null<VersionInfo>;
    function get_version() return _version;

    public function new() {

        _name = "AbstractApp";
        _onInit = new ChainedList( this );

    }

    public function dispose() {

        _pathAdditions = null;
        _env = null;
        _onInit.clear();
        _onInit = null;

    }

    public function exit( forced:Bool = false ) { }

    public function getInit():AbstractExecutor {

        // Return the already running executor if it exists
        if ( ExecutorManager.getInstance().exists( '${_name}_${AbstractAppExecutorContext.Init}' ) )
            return ExecutorManager.getInstance().get( '${_name}_${AbstractAppExecutorContext.Init}' );

        //
        // Setting up system path
        //
        for ( p in _pathAdditions ) SysTools.addToPath( p );

        var executablePath = Which.getInstance().path + Which.getInstance().executable;
        final executor = new Executor( executablePath, [ this._executable ] );
        executor.onStdErr.add( _initStandardError ).onStdOut.add( _initStandardOutput ).onStop.add( _initStop );
        ExecutorManager.getInstance().set( '${_name}_${AbstractAppExecutorContext.Init}', executor );
        return executor;

    }

    public function inlineInit() {

        //
        // Setting up system path
        //
        for ( p in _pathAdditions ) SysTools.addToPath( p );

        var p = new Process( Which.getInstance().path + Which.getInstance().executable, [ this._executable ] );
        var ec = p.exitCode();
        var data = p.stdout.readAll();

        if ( ec == 0 ) {

            _initStandardOutput( null, data.toString() );

        }

        _initialized = true;
        _initializationComplete();
        
        for ( f in _onInit ) f( this );

    }

    public function toString():String {

        return '[AbstractApp]';

    }

    function _initStandardOutput( executor:AbstractExecutor, data:String ) {

        var a = data.split( SysTools.lineEnd );
        if ( data.length > 0 && a.length > 0 && StringTools.trim( a[ 0 ] ).length > 0 ) this._path = Path.addTrailingSlash( Path.directory( a[ 0 ] ) );

    }

    function _initStandardError( executor:AbstractExecutor, data:String ) {

        //Logger.verbose( '${this}: _initStandardError ${data}' );
        
    }

    function _initStop( executor:AbstractExecutor ) {

       // Logger.debug( '${this}: _initStop(): ${executor.exitCode}' );

        _initialized = true;

        for ( f in _onInit ) f( this );

        ExecutorManager.getInstance().remove( '${_name}_${AbstractAppExecutorContext.Init}' );

        executor.dispose();
        _initializationComplete();
        
    }

    function _initializationComplete():Void {}

}

enum abstract AbstractAppExecutorContext( String ) to String {

    var Init = "AbstractApp_Init";

}
