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

package prominic.sys.io;

import champaign.core.interfaces.IDisposable;
import champaign.core.logging.Logger;
import champaign.sys.io.process.AbstractProcess;
import champaign.sys.io.process.CallbackProcess;
import champaign.sys.io.process.ProcessTools.KillSignal;
import prominic.sys.tools.StrTools;
import sys.thread.Mutex;

class Executor extends AbstractExecutor implements IDisposable {

    static var _lineEnd:String = "\n";

    var _args:Array<String>;
    var _command:String;
    var _currentExecutionNumber:Int;
    var _disposed:Bool = false;
    var _env:Map<String, String>;
    var _mutexStderr:Mutex;
    var _mutexStdout:Mutex;
    var _mutexStop:Mutex;
    var _numTries:Int;
    var _pid:Int;
    var _process:CallbackProcess;
    var _timeout:Float = 0;
    var _validExitCodes:Array<Float>;
    var _workingDirectory:String;

    public var args( get, never ):Array<String>;
    function get_args() return _args;

    public var environment( get, never ):Map<String, String>;
    function get_environment() return _env;

    public var pid( get, never ):Int;
    function get_pid() return _pid;

    public var workingDirectory( get, never ):String;
    function get_workingDirectory() return _workingDirectory;

    public function new( command:String, ?args:Array<String>, ?workingDirectory:String, ?environment:Map<String, String>, ?timeout:Float, ?extraParams:Array<Dynamic> ) {

        super( extraParams );
        
        _command = command;
        _args = args;
        _workingDirectory = workingDirectory;
        _env = environment;
        _timeout = ( timeout != null ) ? timeout : 0;

        _mutexStderr = new Mutex();
        _mutexStdout = new Mutex();
        _mutexStop = new Mutex();

        if ( Sys.systemName() == "Windows" ) _lineEnd = "\r\n";

    }

    public function execute( ?extraArgs:Array<String>, ?workingDirectory:String ):Executor {

        if ( _running ) return this;

        _startTime = Sys.time();

        _hasErrors = false;

        var currentWorkingDirectory = Sys.getCwd();
        if ( _workingDirectory != null ) 
        {
        		Sys.setCwd( _workingDirectory );
    		}
    		
        if ( workingDirectory != null ) 
        {
        		Sys.setCwd( workingDirectory );
    		}
    		
        if ( _env != null ) 
        {
        		for ( k in _env.keys() ) 
        		{
        			Sys.putEnv( k, _env.get( k ) );
    			}
    		}

        _validExitCodes = null;
        _numTries = 0;
        _currentExecutionNumber = 1;

        var finalArgs = extraArgs != null ? _args.concat( extraArgs ) : _args;
        _process = new CallbackProcess(_command,  finalArgs);
        _process.onStdErr = _processOnStdErr;
        _process.onStdOut = _processOnStdOut;
        _process.onStop = _processOnStop;
        _process.start();
        this._pid = _process.pid;
        _running = true;
        for ( f in _onStart ) f( this );

        Logger.info( '${this}: execute() in ${Sys.getCwd()}' );

        Sys.setCwd( currentWorkingDirectory );

        return this;

    }

    function _processOnStdErr( ?process:AbstractProcess ) {

        if ( _exitCode >= 0 ) return;

        _mutexStderr.acquire();
        var s = process.stderrBuffer.getAll();
        Logger.error( '${this} stderr: ${s}' );
        _hasErrors = true;
        for ( f in _onStdErr ) f( this, s );
        _mutexStderr.release();

    }

    function _processOnStdOut( ?process:AbstractProcess ) {

        if ( _exitCode >= 0 ) return;

        _mutexStdout.acquire();
        var s = process.stdoutBuffer.getAll();
        for ( f in _onStdOut ) f( this, s );
        _mutexStdout.release();

    }

    function _processOnStop( ?process:AbstractProcess ) {

        if ( _exitCode >= 0 ) return;

        _stopTime = Sys.time();
        var t = _stopTime - _startTime;
        Logger.info( '${this}: stopped with exit code ${_process.exitCode}. Execution time:${StrTools.timeToFormattedString(t, true)}' );

        _mutexStop.acquire();
        _running = false;
        _exitCode = _process.exitCode;
        for ( f in _onStop ) f( this );
        _mutexStop.release();

    }

    /**
     * This function is implemented because in specific circumstances the spawned process
     * never exits, so the exit code cannot be received, and the callbacks cannot be called.
     */
    public function simulateStop() {

        if ( _exitCode >= 0 ) return;

        _stopTime = Sys.time();
        _mutexStop.acquire();
        _running = false;
        _exitCode = 0;
        for ( f in _onStop ) f( this );
        _mutexStop.release();

    }

    public function stop( ?forced:Bool ) {

        if ( _process != null ) {

            Logger.info( '${this}: stop( forced:${forced} )' );
            _process.stop( forced );

        }

    }

    //TODO: Implement Windows and Linux Kill
    public function kill( signal:KillSignal ) {
        
        #if windows
        // Not implemented yet
        _process.stop( true );
        #elseif mac
        var e = Sys.command( "kill", [ "-" + Std.string( Std.int( signal ) ), Std.string( this._pid ) ] );
        Logger.warning( '${this} kill(${Std.string( Std.int( signal ) )}) exitCode: ${e}' );
        #elseif linux
        // Not implemented yet
        _process.stop( true );
        #end

    }

    override public function dispose() {

        if ( _disposed ) return;

        Logger.debug( '${this}: Disposing...' );

        _command = null;
        _args = null;
        _workingDirectory = null;
        _extraParams = null;
        _disposed = true;

        super.dispose();

    }

    public override function toString():String {

        if ( _process != null ) {

            return '[Executor(${this._id}: ${_command} ${_args}, PID: ${this._pid})]';

        }

        return '[Executor(${this._id}: ${_command} ${_args} PID: null)]';
    }

}
