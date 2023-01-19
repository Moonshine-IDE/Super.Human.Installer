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
import sys.io.Process;
import sys.thread.EventLoop.EventHandler;
import sys.thread.Mutex;
import sys.thread.Thread;

class AdvancedProcess implements IDisposable {

    public var exitCode( get, null ):Null<Int>;
    var _exitCode:Null<Int>;
    function get_exitCode() return _exitCode;

    public var onStart( get, null ):List<()->Void>;
    var _onStart:List<()->Void>;
    function get_onStart() return _onStart;

    public var onStdErr( get, null ):List<( String )->Void>;
    var _onStdErr:List<( String )->Void>;
    function get_onStdErr() return _onStdErr;

    public var onStdOut( get, null ):List<( String )->Void>;
    var _onStdOut:List<( String )->Void>;
    function get_onStdOut() return _onStdOut;

    public var onStop( get, null ):List<()->Void>;
    var _onStop:List<()->Void>;
    function get_onStop() return _onStop;

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
    var _exited:Null<Bool>;
    var _mutexChecker:Mutex;
    var _mutexEventHandler:Mutex;
    var _mutexReadStdErr:Mutex;
    var _mutexReadStdOut:Mutex;
    var _mutexWaitForExit:Mutex;
    var _pendingStdErr:String;
    var _pendingStdOut:String;
    var _process:Process;

    public function new( command:String, ?arguments:Array<String> ) {

        _command = command;
        _arguments = arguments;
        _onStart = new List();
        _onStdErr = new List();
        _onStdOut = new List();
        _onStop = new List();

        _mutexChecker = new Mutex();
        _mutexEventHandler = new Mutex();
        _mutexReadStdErr = new Mutex();
        _mutexReadStdOut = new Mutex();
        _mutexWaitForExit = new Mutex();

        _pendingStdErr = "";
        _pendingStdOut = "";

    }

    public function dispose() {

        _onStart.clear();
        _onStart = null;
        _onStdErr.clear();
        _onStdErr = null;
        _onStdOut.clear();
        _onStdOut = null;
        _onStop.clear();
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

        if ( _exited != null || _process == null ) return;

        if ( forced )
            _process.kill()
        else
            _process.close();

        _process = null;

    }

    function _checker() {

        var thread = Thread.current();

        _mutexEventHandler.acquire();

        _eventHandler = thread.events.repeat( () -> {

            _mutexChecker.acquire();
            
            if ( _pendingStdOut.length > 0 ) {

                for ( f in _onStdOut ) f( _pendingStdOut );
                _pendingStdOut = "";

            }

            if ( _pendingStdErr.length > 0 ) {

                for ( f in _onStdErr ) f( _pendingStdErr );
                _pendingStdErr = "";

            }

            if ( _exited != null ) {

                _running = false;
                _process.close();
                for ( f in _onStop ) f();
                thread.events.cancel( _eventHandler );

            }

            _mutexChecker.release();

        }, 33 );

        _mutexEventHandler.release();

    }

    function _readStdErr() {

        _mutexReadStdErr.acquire();

        var s = _process.stderr.readAll().toString();
        _pendingStdErr += s;

        _mutexReadStdErr.release();

    }

    function _readStdOut() {

        _mutexReadStdOut.acquire();

        var s = _process.stdout.readAll().toString();
        _pendingStdOut += s;

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