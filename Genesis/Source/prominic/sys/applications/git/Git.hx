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

package prominic.sys.applications.git;

import champaign.core.ds.ChainedList;
import champaign.core.logging.Logger;
import prominic.sys.applications.AbstractApp;
import prominic.sys.io.AbstractExecutor;
import prominic.sys.io.Executor;
import prominic.sys.io.ExecutorManager;
import prominic.sys.tools.SysTools;

@:allow( prominic.sys )
@:allow( prominic.sys.applications )
class Git extends AbstractApp {

    static final _versionPattern = ~/(\d+\.\d+\.\d+)/;

    static var _instance:Git;

    static public function getInstance():Git {
        
        if ( _instance == null ) _instance = new Git();
        return _instance;

    }

    var _onVersion:ChainedList<()->Void, Git>;

    public var onVersion( get, never ):ChainedList<()->Void, Git>;
    function get_onVersion() return _onVersion;

    function new() {

        super();

        #if windows
        _executable = "git.exe";
        #else
        _executable = "git";
        #end
        _name = "Git";

        _onVersion = new ChainedList( this );

        _instance = this;

    }

    public function clone():Git {

        var g = new Git();
        g._executable = _executable;
        g._initialized = _initialized;
        g._name = _name;
        g._path = _path;
        g._status = _status;
        g._version = _version;
        g._initializationComplete();
        return cast g;

    }

    override public function dispose() {

        super.dispose();

    }

    /**
     * Creates a 'git --version' executor.
     * @return Executor
     */
    public function getVersion():AbstractExecutor {

        // Return the already running executor if it exists
        if ( ExecutorManager.getInstance().exists( GitExecutorContext.Version ) )
            return ExecutorManager.getInstance().get( GitExecutorContext.Version );

        final executor = new Executor( this.path + this._executable, [ "--version" ] );
        executor.onStop.add( _versionExecutorStopped ).onStdOut.add( _versionExecutorStandardOutput );
        ExecutorManager.getInstance().set( GitExecutorContext.Version, executor );
        return executor;

    }

    /**
     * Returns the full path to the git executable.
     * Ensures the application is initialized first.
     * @return String The full path or null if not initialized/found.
     */
    public function getExecutablePath():String {
        if (!_initialized) {
            Logger.warning('${this}: Attempted to get executable path before initialization.');
            // Optionally trigger initialization here if desired
            // initialize(); 
            return null; 
        }
        if (_path == null || _executable == null) {
             Logger.warning('${this}: Path or executable name is null.');
             return null;
        }
        return this.path + this._executable;
    }

    public override function toString():String {

        return '[Git]';

    }

    function _versionExecutorStandardOutput( executor:AbstractExecutor, data:String ) {

        var a = data.split( SysTools.lineEnd );

        if ( data.length > 0 && a.length > 0 ) {

            if ( _versionPattern.match( a[ 0 ] ) ) {

                this._version = _versionPattern.matched( 0 );

            }

        }

    }

    function _versionExecutorStopped( executor:AbstractExecutor ) {
        
        Logger.info( '${this}: _versionExecutorStopped(): ${executor.exitCode}' );

        for ( f in _onVersion ) f();

        ExecutorManager.getInstance().remove( GitExecutorContext.Version );

        executor.dispose();

    }

}

enum abstract GitExecutorContext( String ) to String {

    var Version = "Git_Version";
    
}
