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
import prominic.core.interfaces.IDisposable;
import sys.io.Process;
import sys.thread.EventLoop.EventHandler;
import sys.thread.Mutex;
import sys.thread.Thread;

class AdvancedProcess implements IDisposable {

    static final _INPUT_BUFFER_SIZE:Int = 32768;
    static final _THREAD_LOOP_INTERVAL:Int = 33;
    static final _THREAD_SLEEP_INTERVAL:Float = .1;

    public var exitCode( get, null ):Null<Int>;
    var _exitCode:Null<Int>;
    function get_exitCode() return _exitCode;

    public var onStart( get, set ):()->Void;
    var _onStart:()->Void;
    function get_onStart() return _onStart;
    function set_onStart( value:()->Void ):()->Void { _onStart = value; return _onStart; }

    public var onStdErr( get, set ):( String )->Void;
    var _onStdErr:( String )->Void;
    function get_onStdErr() return _onStdErr;
    function set_onStdErr( value:( String )->Void ):( String )->Void { _onStdErr = value; return _onStdOut; }

    public var onStdOut( get, set ):( String )->Void;
    var _onStdOut:( String )->Void;
    function get_onStdOut() return _onStdOut;
    function set_onStdOut( value:( String )->Void ):( String )->Void { _onStdOut = value; return _onStdOut; }

    public var onStop( get, set ):()->Void;
    var _onStop:()->Void;
    function get_onStop() return _onStop;
    function set_onStop( value:()->Void ):()->Void { _onStop = value; return _onStop; }

    public var pid( get, null ):Null<Int>;
    var _pid:Null<Int>;
    function get_pid() return _pid;

    public var running( get, null ):Bool;
    var _running:Bool = false;
    function get_running() return _running;

    var _arguments:Array<String>;
    var _command:String;
    var _disposed:Bool = false;
    var _eventHandler:EventHandler;
    var _exited:Bool = false;
    var _mutexChecker:Mutex;
    var _mutexEventHandler:Mutex;
    var _mutexReadStdErr:Mutex;
    var _mutexReadStdOut:Mutex;
    var _mutexWaitForExit:Mutex;
    var _pendingStdErr:String;
    var _pendingStdOut:String;
    var _process:Process;
    var _stdErrFinished:Bool = false;
    var _stdOutFinished:Bool = false;
    var _mutexWriteStdOut:Mutex;

    public function new( command:String, ?arguments:Array<String> ) {

        _command = command;
        _arguments = arguments;

        _mutexChecker = new Mutex();
        _mutexEventHandler = new Mutex();
        _mutexReadStdErr = new Mutex();
        _mutexReadStdOut = new Mutex();
        _mutexWaitForExit = new Mutex();
        _mutexWriteStdOut = new Mutex();

        _pendingStdErr = "";
        _pendingStdOut = "";

    }

    public function dispose() {

        _onStart = null;
        _onStdErr = null;
        _onStdOut = null;
        _onStop = null;
        _mutexChecker = null;
        _mutexEventHandler = null;
        _mutexReadStdErr = null;
        _mutexReadStdOut = null;
        _mutexWaitForExit = null;
        _eventHandler = null;
        _process = null;
        _exitCode = null;
        _pid = null;
        _disposed = true;

    }

    public function start() {

        _process = new Process( _command, _arguments );
        _running = true;
        _pid = _process.getPid();

        Thread.create( _readStdOut );
        Thread.create( _readStdErr );
        Thread.create( _waitForExit );
        Thread.runWithEventLoop( _checker );

    }

    public function stop( forced:Bool = false ) {

        if ( _exited || _process == null ) return;

        if ( forced )
            _process.kill()
        else
            _process.close();

        _process = null;

    }

    function _checker() {

        var thread = Thread.current();

        //_mutexEventHandler.acquire();

        _eventHandler = thread.events.repeat( () -> {

            _mutexChecker.acquire();
            
            if ( _pendingStdOut.length > 0 ) {

                _mutexWriteStdOut.acquire();
                if ( _onStdOut != null ) _onStdOut( new String( _pendingStdOut ) );
                _pendingStdOut = "";
                _mutexWriteStdOut.release();

            }

            if ( _pendingStdErr.length > 0 ) {

                if ( _onStdErr != null ) _onStdErr( _pendingStdErr );
                _pendingStdErr = "";

            }

            if ( _exited && _stdOutFinished && _stdErrFinished ) {

                _running = false;
                _process.close();
                if ( _onStop != null ) _onStop();
                thread.events.cancel( _eventHandler );
                _mutexEventHandler.release();
                _mutexChecker.release();
                trace( 'thread.events.cancel()' );

            }

            _mutexChecker.release();
            trace( '_mutexChecker.release()' );

        }, _THREAD_LOOP_INTERVAL );

        //_mutexEventHandler.release();
        //trace( '_mutexEventHandler.release()' );

    }

    function _readStdErr() {

        trace( '#' );

        while( true ) {

            _mutexReadStdErr.acquire();

            try {

                var b = Bytes.alloc( _INPUT_BUFFER_SIZE );
                var d = _process.stderr.readBytes( b, 0, b.length );
                _pendingStdErr += b.toString();

            } catch( e ) {

                _stdErrFinished = true;
                _mutexReadStdErr.release();
                break;

            }

            Sys.sleep( _THREAD_SLEEP_INTERVAL );
            
            _mutexReadStdErr.release();

        }

        _mutexReadStdErr.release();

        _mutexReadStdErr.acquire();
        _stdErrFinished = true;
        _mutexReadStdErr.release();

    }

    function _readStdOut() {

        trace( '@' );

        while( true ) {

            _mutexReadStdOut.acquire();

            try {

                var b = Bytes.alloc( _INPUT_BUFFER_SIZE );
                var d = _process.stdout.readBytes( b, 0, b.length );
                _pendingStdOut += b.toString();
                //trace( '@ ${_pendingStdOut}');

            } catch( e ) {

                _stdOutFinished = true;
                break;

            }

            Sys.sleep( _THREAD_SLEEP_INTERVAL );
            
            _mutexReadStdOut.release();

        }

        _mutexReadStdOut.release();

        _mutexReadStdOut.acquire();
        _stdOutFinished = true;
        _mutexReadStdOut.release();

    }

    function _waitForExit() {

        _mutexWaitForExit.acquire();

        _exitCode = _process.exitCode();
        _running = false;
        _exited = true;

        _mutexWaitForExit.release();

    }

}