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

package prominic.sys.io.process;

import haxe.Json;
import haxe.io.Eof;
import prominic.sys.io.process.Events.EventCommand;
import prominic.sys.io.process.Events.EventData;
import prominic.sys.io.process.Events.EventOwner;
import sys.io.Process;
import sys.thread.Mutex;
import sys.thread.Thread;

class ThreadedProcess implements IProcess {
    
    static final _inputBufferLength = 32768;
    static final _inputDelay = 0.1;
    static final _inputInterval = 0.2;
    static final _waitExitInterval = 0.5;

    var _args:Array<String>;
    var _cmd:String;
    var _done:Bool = false;
    var _exitCode:Int = -1;
    var _exited:Bool = false;
    var _mutex:Mutex;
    var _onStdErr:(String)->Void;
    var _onStdOut:(String)->Void;
    var _onStop:()->Void;
    var _pid:Int;
    var _process:Process;
    var _receiverThread:Thread;
    var _running:Bool = false;
    var _stderrFinished:Bool = false;
    var _stdoutFinished:Bool = false;

    public var exitCode( get, never ):Int;
    function get_exitCode() return _exitCode;

    public var onStop( get, set ):()->Void;
    function get_onStop() return _onStop;
    function set_onStop( value:()->Void ) { _onStop = value; return _onStop; }

    public var onStdErr( get, set ):(String)->Void;
    function get_onStdErr() return _onStdOut;
    function set_onStdErr( value:(String)->Void ) { _onStdErr = value; return _onStdErr; }
    
    public var onStdOut( get, set ):(String)->Void;
    function get_onStdOut() return _onStdOut;
    function set_onStdOut( value:(String)->Void ) { _onStdOut = value; return _onStdOut; }
    
    public var pid( get, never ):Int;
    function get_pid() return _pid;

    public var running( get, never ):Bool;
    function get_running() return _running;

    public function new( cmd:String, ?args:Array<String> ) {

        _cmd = cmd;
        _args = args;

    }

    public function start() {

        _mutex = new Mutex();
        _receiverThread = Thread.create( _waitForThreadMessages );

        _process = new Process( _cmd, _args );
        _pid = _process.getPid();
        _running = true;

        Thread.create( _readStdOut );
        Thread.create( _readStdErr );
        Thread.create( _waitForExit );

    }

    public function stop( forced:Bool = false ) {}

    function _readStdOut() {

        while( true ) {

            try {

                var data = StreamTools.readInput( _process.stdout, _inputBufferLength );

                var eventData:EventData = {};

                if ( data != null && data.length > 0 ) {

                    eventData = { command: EventCommand.Data, owner: EventOwner.StandardOutput, data: data };

                } else {

                    eventData = { command: EventCommand.Close, owner: EventOwner.StandardOutput };

                }

                _receiverThread.sendMessage( Json.stringify( eventData ) );

                if ( eventData.command == EventCommand.Close ) break;

            } catch ( e:Eof ) {

                trace( 'EOF' );

                var eventData:EventData = { command: EventCommand.Close, owner: EventOwner.StandardOutput };
                _receiverThread.sendMessage( Json.stringify( eventData ) );

                break;

            } catch ( e:Dynamic ) {}

            Sys.sleep( _inputInterval );

        }

    }

    function _readStdErr() {

        while( true ) {

            try {

                var data = StreamTools.readInput( _process.stderr, _inputBufferLength );

                var eventData:EventData = {};

                if ( data != null && data.length > 0 ) {

                    eventData = { command: EventCommand.Data, owner: EventOwner.StandardError, data: data };

                } else {

                    eventData = { command: EventCommand.Close, owner: EventOwner.StandardError };

                }

                _receiverThread.sendMessage( Json.stringify( eventData ) );

                if ( eventData.command == EventCommand.Close ) break;

            } catch ( e:Eof ) {

                var eventData:EventData = { command: EventCommand.Close, owner: EventOwner.StandardError };
                _receiverThread.sendMessage( Json.stringify( eventData ) );

                break;

            } catch ( e:Dynamic ) {}

            Sys.sleep( _inputInterval );

        }

    }

    function _waitForExit() {

        Sys.sleep( _waitExitInterval );

        var e = _process.exitCode();

        var eventData:EventData = { command: EventCommand.Exit, owner: EventOwner.Process, value: e };
        _receiverThread.sendMessage( Json.stringify( eventData ) );

    }

    function _waitForThreadMessages() {

        while ( !_done ) {

            var eventDataValue:String = Thread.readMessage( true );

            if ( eventDataValue != null ) {

                var eventData:EventData = Json.parse( eventDataValue );

                switch ( eventData.owner ) {

                    case EventOwner.Process:

                        switch ( eventData.command ) {
        
                            case EventCommand.Exit:
                                _mutex.acquire();
                                _exited = true;
                                _exitCode = eventData.value;
                                _running = false;
                                _mutex.release();
        
                            default:
        
                        }
        
                    case EventOwner.StandardOutput:
        
                        switch ( eventData.command ) {
        
                            case EventCommand.Data:
                                _mutex.acquire();
                                if ( _onStdOut != null && _onStdOut != null && eventData.data != null && eventData.data.length > 0 ) _onStdOut( eventData.data );
                                _mutex.release();
        
                            case EventCommand.Close:
                                _mutex.acquire();
                                _stdoutFinished = true;
                                _mutex.release();
        
                            default:
        
                        }
        
                    case EventOwner.StandardError:
        
                        switch ( eventData.command ) {
        
                            case EventCommand.Data:
                                _mutex.acquire();
                                if ( _onStdErr != null && _onStdErr != null && eventData.data != null && eventData.data.length > 0 ) _onStdErr( eventData.data );
                                _mutex.release();
        
                            case EventCommand.Close:
                                _mutex.acquire();
                                _stderrFinished = true;
                                _mutex.release();
        
                            default:
        
                        }
        
                    default:
        
                }

                if ( _exited && _stdoutFinished && _stderrFinished ) {

                    _mutex.acquire();
                    _process.close();
                    if ( _onStop != null && _onStop != null ) _onStop();
                    _done = true;
                    _mutex.release();
        
                }

            }

        }

    }

}