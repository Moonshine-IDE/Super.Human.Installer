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

import prominic.core.interfaces.IDisposable;
import prominic.logging.Logger;

class Executor extends AbstractExecutor implements IDisposable {

    static var _lineEnd:String = "\n";

    var _advancedProcess:AdvancedProcess;
    var _args:Array<String>;
    var _command:String;
    var _currentExecutionNumber:Int;
    var _disposed:Bool = false;
    var _env:Map<String, String>;
    var _numTries:Int;
    var _pid:Int;
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

        if ( Sys.systemName() == "Windows" ) _lineEnd = "\r\n";

    }

    public function execute( ?extraArgs:Array<String> ):Executor {

        if ( _running ) return this;

        if ( _workingDirectory != null ) Sys.setCwd( _workingDirectory );
        if ( _env != null ) for ( k in _env.keys() ) Sys.putEnv( k, _env.get( k ) );

        _validExitCodes = null;
        _numTries = 0;
        _currentExecutionNumber = 1;

        _advancedProcess = new AdvancedProcess( _command, ( extraArgs != null ) ? _args.concat( extraArgs ) : _args );
        _advancedProcess.onStdErr = _advancedProcessOnStdErr;
        _advancedProcess.onStdOut = _advancedProcessOnStdOut;
        _advancedProcess.onStop = _advancedProcessOnStop;
        _advancedProcess.start();
        this._pid = _advancedProcess.pid;
        _running = true;

        for ( f in _onStart ) f( this );

        Logger.verbose( '${this} execute' );
        return this;

    }

    function _advancedProcessOnStdErr( data:String ) {

        Logger.error( '${this} stderr: ${data}' );
        for ( f in _onStdErr ) f( this, data );

    }

    function _advancedProcessOnStdOut( data:String ) {

        for ( f in _onStdOut ) f( this, data );

    }

    function _advancedProcessOnStop() {

        _running = false;
        _exitCode = _advancedProcess.exitCode;
        for ( f in _onStop ) f( this );

    }

    public function stop( ?forced:Bool ) {

        if ( _advancedProcess != null ) {

            Logger.verbose( '${this} stop( forced:${forced} )' );
            _advancedProcess.stop( forced );

        }

    }

    //TODO: Implement Windows and Linux Kill
    public function kill( signal:KillSignal ) {
        
        #if windows
        // Not implemented yet
        _advancedProcess.stop( true );
        #elseif mac
        var e = Sys.command( "kill", [ "-" + Std.string( Std.int( signal ) ), Std.string( this._pid ) ] );
        Logger.verbose( '${this} kill(${Std.string( Std.int( signal ) )}) exitCode: ${e}' );
        #elseif linux
        // Not implemented yet
        _advancedProcess.stop( true );
        #end

    }

    override public function dispose() {

        //if ( _advancedProcess != null ) _advancedProcess.dispose();
        //_advancedProcess = null;
        _command = null;
        _args = null;
        _workingDirectory = null;
        _extraParams = null;
        _disposed = true;

        super.dispose();

    }

    public function toString():String {

        if ( _advancedProcess != null ) {

            return 'Executor: ${_command} ${_args} PID: ${this._pid}';

        }

        return 'Executor: ${_command} ${_args} PID: null';

    }

}

enum abstract KillSignal( Int ) from Int to Int  {
    
    var HangUp = 1;
    var Interrupt = 2;
    var Quit = 3;
    var Abort = 6;
    var Kill = 9;
    var Alarm = 14;
    var Terminate = 15;

}