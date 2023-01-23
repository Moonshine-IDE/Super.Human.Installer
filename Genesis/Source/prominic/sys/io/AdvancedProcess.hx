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

import haxe.io.Bytes;
import haxe.io.Eof;
import haxe.io.Input;
import sys.io.Process;
import sys.thread.Deque;
import sys.thread.Mutex;
import sys.thread.Thread;

class AdvancedProcess {

    static final _eventCheckerInterval = .1;
    static final _inputBufferLength = 32768;
    static final _inputInterval = .05;

    static function readOutput( output:Input, bufferLength:Int ):String {

        var bytes = Bytes.alloc( bufferLength );
        var size = output.readBytes( bytes, 0, bytes.length );
        return bytes.getString( 0, size );

    }

    static function readOutputAll( output:Input ):String {

        var data = output.readAll();
        return data.toString();

    }

    static function readOutputUntil( output:Input, charCode:Int = 0 ):String {

        var result:String = "";

        while( true ) {
            try {
                var data = output.readByte();
                result += String.fromCharCode( data );
            } catch ( e ) {
                break;
            };
        }

        return result;

    }

    var _args:Array<String>;
    var _cmd:String;
    var _deque:Deque<EventData>;
    var _eventCheckerThread:Thread;
    var _exitCode:Int = -1;
    var _exited:Bool = false;
    var _mutexChecker:Mutex;
    var _mutexExit:Mutex;
    var _mutexStdErr:Mutex;
    var _mutexStdOut:Mutex;
    var _onStdErr:(String)->Void;
    var _onStdOut:(String)->Void;
    var _onStop:()->Void;
    var _pid:Int;
    var _process:Process;
    var _standardErrorFinished:Bool = false;
    var _standardOutputFinished:Bool = false;

    public var exitCode( get, never ):Int;
    function get_exitCode() return _exitCode;

    public var onStop( get, set ):()->Void;
    function get_onStop() return _onStop;
    function set_onStop( value:()->Void ) { _onStop = value; return _onStop; }

    public var onStdErr( get, set ):(String)->Void;
    function get_onStdErr() return _onStdErr;
    function set_onStdErr( value:(String)->Void ) { _onStdErr = value; return _onStdErr; }

    public var onStdOut( get, set ):(String)->Void;
    function get_onStdOut() return _onStdOut;
    function set_onStdOut( value:(String)->Void ) { _onStdOut = value; return _onStdOut; }

    public var pid( get, null ):Int;
    function get_pid() return _pid;

    public function new( cmd:String, ?args:Array<String> ) {

        _cmd = cmd;
        _args = args;

        _mutexChecker = new Mutex();
        _mutexExit = new Mutex();
        _mutexStdErr = new Mutex();
        _mutexStdOut = new Mutex();
        _deque = new Deque();

    }

    public function start( threaded:Bool = true ) {

        _process = new Process( _cmd, _args );
        _pid = _process.getPid();

        if ( threaded ) {

            _eventCheckerThread = Thread.create( _eventChecker );
            Thread.create( _readStdOut );
            Thread.create( _readStdErr );
            Thread.create( _waitForExit );

        } else {

            _exitCode = _process.exitCode();
            if ( _onStdErr != null ) _onStdErr( _process.stderr.readAll().toString() );
            if ( _onStdOut != null ) _onStdOut( _process.stdout.readAll().toString() );
            if ( _onStop != null ) _onStop();

        }

    }

    public function stop( forced:Bool = false ) {

        

    }

    function _eventChecker() {

        while ( true ) {

            //var eventData:EventData = Thread.readMessage( true );
            var eventData:EventData = _deque.pop( true );

            if ( eventData != null ) {

                switch ( eventData.owner ) {

                    case EventOwner.Process:

                        switch ( eventData.command ) {

                            case EventCommand.Exit:
                                _mutexChecker.acquire();
                                _exited = true;
                                _exitCode = eventData.value;
                                _process.close();
                                _mutexChecker.release();

                            default:

                        }

                    case EventOwner.StandardError:

                        switch ( eventData.command ) {

                            case EventCommand.Close:
                                _mutexChecker.acquire();
                                _standardErrorFinished = true;
                                _mutexChecker.release();

                            case EventCommand.Data:
                                if ( _onStdErr != null ) _onStdErr( eventData.data );

                            default:

                        }

                    case EventOwner.StandardOutput:

                        switch ( eventData.command ) {

                            case EventCommand.Close:
                                _mutexChecker.acquire();
                                _standardOutputFinished = true;
                                _mutexChecker.release();

                            case EventCommand.Data:
                                if ( _onStdOut != null ) _onStdOut( eventData.data );

                            default:

                        }

                    default:

                }

            }

            if ( _exited ) {

                //trace( '----------------------------' );
                if ( _onStop != null ) _onStop();
                break;

            }

            Sys.sleep( _eventCheckerInterval );

        }

    }

    function _readStdOut() {

        while( true ) {

            _mutexStdOut.acquire();
            if ( _exited ) break;

            try {

                _mutexStdOut.acquire();
                var data = AdvancedProcess.readOutput( _process.stdout, _inputBufferLength );
                var eventData:EventData = { command: EventCommand.Data, owner: EventOwner.StandardOutput, data: data };
                //_eventCheckerThread.sendMessage( eventData );
                _deque.push( eventData );
                _mutexStdOut.release();

            } catch ( e:Eof ) {

                break;

            } catch ( e:Dynamic ) {

                break;

            }

            _mutexStdOut.release();
            Sys.sleep( _inputInterval );

        }

        _mutexStdOut.tryAcquire();
        var eventData:EventData = { command: EventCommand.Close, owner: EventOwner.StandardOutput };
        //_eventCheckerThread.sendMessage( eventData );
        _deque.push( eventData );
        _mutexStdOut.release();

    }

    function _readStdErr() {

        while( true ) {

            if ( _exited ) break;

            try {

                _mutexStdErr.acquire();
                var data = AdvancedProcess.readOutput( _process.stderr, _inputBufferLength );
                var eventData:EventData = { command: EventCommand.Data, owner: EventOwner.StandardError, data: data };
                //_eventCheckerThread.sendMessage( eventData );
                _deque.push( eventData );
                _mutexStdErr.release();

            } catch ( e:Eof ) {

                break;

            } catch ( e:Dynamic ) {

                break;

            }

            Sys.sleep( _inputInterval );

        }

        _mutexStdErr.acquire();
        var eventData:EventData = { command: EventCommand.Close, owner: EventOwner.StandardError };
        //_eventCheckerThread.sendMessage( eventData );
        _deque.push( eventData );
        _mutexStdErr.release();

    }

    function _waitForExit() {

        Sys.sleep( 1 );

        var e = _process.exitCode();

        _mutexExit.acquire();
        var eventData:EventData = { command: EventCommand.Exit, owner: EventOwner.Process, value: e };
        //_eventCheckerThread.sendMessage( eventData );
        _deque.add( eventData );
        _mutexExit.release();

    }
    
}

typedef EventData = {

    command:EventCommand,
    owner:EventOwner,
    ?data:String,
    ?value:Int,

}

enum EventCommand {

    Close;
    Data;
    Exit;

}

enum EventOwner {

    Process;
    StandardError;
    StandardOutput;

}