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

import openfl.events.NativeProcessExitEvent;
import openfl.events.ProgressEvent;
import prominic.core.interfaces.IDisposable;
import prominic.logging.Logger;
import prominic.sys.io.AdvancedNativeProcess;

class Executor extends AbstractExecutor implements IDisposable {

    static var _lineEnd:String = "\n";

    var _args:Array<String>;
    var _command:String;
    var _currentExecutionNumber:Int;
    var _disposed:Bool = false;
    var _env:Map<String, String>;
    var _nativeProcess:AdvancedNativeProcess;
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

        _nativeProcess = new AdvancedNativeProcess();
        _addListeners();
        _nativeProcess.startCommand2( _command, ( extraArgs != null ) ? _args.concat( extraArgs ) : _args, _workingDirectory );
        _running = true;
        this._pid = _nativeProcess.pid;
        for ( f in _onStart ) f( this );
        Logger.verbose( '${this} execute' );
        return this;

    }

    public function executeUntil( validExitCodes:Array<Float>, numTries:Int = 0, ?extraArgs:Array<String> ):Executor {

        if ( _running ) return this;

        _validExitCodes = validExitCodes;
        _numTries = numTries;

        if ( _workingDirectory != null ) Sys.setCwd( _workingDirectory );
        if ( _env != null ) for ( k in _env.keys() ) Sys.putEnv( k, _env.get( k ) );

        _nativeProcess = new AdvancedNativeProcess();
        _addListeners();
        _nativeProcess.startCommand( _command, ( extraArgs != null ) ? _args.concat( extraArgs ) : _args, _workingDirectory );
        _running = true;
        this._pid = _nativeProcess.pid;
        for ( f in _onStart ) f( this );
        Logger.verbose( '${this} execute' );
        return this;

    }

    function _addListeners() {

        if ( _nativeProcess != null ) {

            //_nativeProcess.addEventListener( ProgressEvent.STANDARD_OUTPUT_DATA, _nativeProcessStandardOutput );
            _nativeProcess.addEventListener( ProgressEvent.STANDARD_ERROR_DATA, _nativeProcessStandardError );
            _nativeProcess.addEventListener( NativeProcessExitEvent.EXIT, _nativeProcessExit );
            _nativeProcess.stdoutCallback = _nativeProcessStandardOutput2;

        }

    }

    function _deleteListeners() {
        
        if ( _nativeProcess != null ) {

            //_nativeProcess.removeEventListener( ProgressEvent.STANDARD_OUTPUT_DATA, _nativeProcessStandardOutput );
            _nativeProcess.removeEventListener( ProgressEvent.STANDARD_ERROR_DATA, _nativeProcessStandardError );
            _nativeProcess.removeEventListener( NativeProcessExitEvent.EXIT, _nativeProcessExit );
            _nativeProcess.stdoutCallback = null;

        }

    }

    function _nativeProcessStandardOutput( e:ProgressEvent ) {

        if ( _nativeProcess.running ) {

            var a = _nativeProcess.standardOutput.readUTFBytes( Std.int( e.bytesLoaded ) );
            for ( f in _onStdOut ) f( this, a );

        }

    }

    function _nativeProcessStandardOutput2( data:String ) {

        for ( f in _onStdOut ) f( this, data );

    }

    function _nativeProcessStandardError( e:ProgressEvent ) {
        
        var a = _nativeProcess.standardError.readUTFBytes( _nativeProcess.standardError.bytesAvailable );
        Logger.verbose( '${this} stderr: ${a}' );

        for ( f in _onStdErr ) f( this, a );

    }

    function _nativeProcessExit( e:NativeProcessExitEvent ) {

        Logger.verbose( '${this} _nativeProcessExit:${e.exitCode}' );
        _running = false;
        _exitCode = e.exitCode;
        var _canExit = false;

        if ( _numTries == 0 ) {

            if ( _validExitCodes != null ) {

                for ( ec in _validExitCodes ) {

                    if ( _exitCode == ec ) {

                        _canExit = true;

                    }

                }

            } else {

                _canExit = true;

            }

        } else {

            _canExit = _currentExecutionNumber > _numTries;

        }

        _deleteListeners();

        if ( _canExit ) {

            if ( _onStop != null ) for ( f in _onStop ) f( this );

        } else {

            _currentExecutionNumber++;
            _nativeProcess = new AdvancedNativeProcess();
            _addListeners();
            _nativeProcess.startCommand( _command, _args, _workingDirectory );
            _running = true;
            this._pid = _nativeProcess.pid;
            Logger.verbose( '${this} execute _currentExecutionNumber:${_currentExecutionNumber} _numTries:${_numTries}' );

        }

    }

    public function send( data:String ) {

        if ( _nativeProcess != null ) {

            try {

                _nativeProcess.standardInput.writeUTF( data );

            } catch ( e ) { }

        }

    }

    public function stop( ?forced:Bool ) {

        if ( _nativeProcess != null ) {

            Logger.verbose( '${this} stop( forced:${forced} )' );
            _nativeProcess.exit( forced );

        }

    }

    //TODO: Implement Windows and Linux Kill
    public function kill( signal:KillSignal ) {
        
        #if windows
        // Not implemented yet
        _nativeProcess.exit( true );
        #elseif mac
        var e = Sys.command( "kill", [ "-" + Std.string( Std.int( signal ) ), Std.string( this._pid ) ] );
        Logger.verbose( '${this} kill(${Std.string( Std.int( signal ) )}) exitCode: ${e}' );
        #elseif linux
        // Not implemented yet
        _nativeProcess.exit( true );
        #end

    }

    override public function dispose() {

        //_deleteListeners();
        //_nativeProcess = null;

        /*
        _command = null;
        _args = null;
        _workingDirectory = null;
        _extraParams = null;
        _disposed = true;

        super.dispose();
        */

    }

    public function toString():String {

        if ( _nativeProcess != null ) {

            return 'Executor: ${_command} ${_args} PID: ${_nativeProcess.pid}';

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