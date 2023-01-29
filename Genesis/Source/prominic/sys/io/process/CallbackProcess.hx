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

import sys.thread.EventLoop.EventHandler;
import sys.thread.Mutex;
import sys.thread.Thread;

class CallbackProcess extends BufferedProcess {
    
    final _callbackMutex:Mutex = new Mutex();
    final _enterFrameMutex:Mutex = new Mutex();
    final _fps:Int = 30;
    
    var _eventHandler:EventHandler;
    var _onStdErr:(?AbstractProcess)->Void;
    var _onStdOut:(?AbstractProcess)->Void;
    var _onStop:(?AbstractProcess)->Void;

    public var onStdErr( get, set ):(?AbstractProcess)->Void;
    function get_onStdErr() return _onStdOut;
    function set_onStdErr( value ) { _onStdErr = value; return _onStdErr; }
    
    public var onStdOut( get, set ):(?AbstractProcess)->Void;
    function get_onStdOut() return _onStdOut;
    function set_onStdOut( value ) { _onStdOut = value; return _onStdOut; }
    
    public var onStop( get, set ):(?AbstractProcess)->Void;
    function get_onStop() return _onStop;
    function set_onStop( value ) { _onStop = value; return _onStop; }

    public function new( cmd:String, ?args:Array<String>, ?workingDirectory:String, ?performanceSettings:ProcessPerformanceSettings ) {

        super( cmd, args, workingDirectory, performanceSettings );

    }

    override function start() {

        super.start();

        _eventHandler = Thread.current().events.repeat( _frameLoop, Std.int( ( 1 / _fps ) * 1000 ) );

    }

    function _frameLoop() {

        if ( _onStdOut != null && this._stdoutBuffer.length > 0 ) {

            _onStdOut( this );

        }

        if ( _onStdErr != null && this._stderrBuffer.length > 0 ) {

            _onStdErr( this );

        }

        if ( _exited ) {

            Thread.current().events.cancel( _eventHandler );

            if ( _onStop != null ) _onStop( this );

        }

    }

}