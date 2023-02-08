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

/**
 * An AbstractProcess implementation that calls callback functions
 * on specific events of the spawned process. For stream output and event handling,
 * an internal loop will be created and attached to the current thread
 */
class CallbackProcess extends BufferedProcess {
    
    final _callbackMutex:Mutex = new Mutex();
    final _enterFrameMutex:Mutex = new Mutex();
    
    var _cancelEventLoop:Bool = false;
    var _eventHandler:EventHandler;
    var _onStdErr:(?AbstractProcess)->Void;
    var _onStdOut:(?AbstractProcess)->Void;
    var _onStop:(?AbstractProcess)->Void;

    /**
     * Callback when there's data in stderr buffer
     */
    public var onStdErr( get, set ):(?AbstractProcess)->Void;
    function get_onStdErr() return _onStdOut;
    function set_onStdErr( value ) { _onStdErr = value; return _onStdErr; }
    
    /**
     * Callback when there's data in stdout buffer
     */
    public var onStdOut( get, set ):(?AbstractProcess)->Void;
    function get_onStdOut() return _onStdOut;
    function set_onStdOut( value ) { _onStdOut = value; return _onStdOut; }
    
    /**
     * Callback when the process exits
     */
    public var onStop( get, set ):(?AbstractProcess)->Void;
    function get_onStop() return _onStop;
    function set_onStop( value ) { _onStop = value; return _onStop; }

    /**
     * An AbstractProcess implementation that calls callback functions
     * on specific events of the spawned process. For stream output and event handling,
     * an internal loop will be created and attached to the current thread. If the current
     * thread does not have an event loop, callbacks will not be called.
     * @param cmd The command to execute, the process will be spawned with this command
     * @param args Optional command line arguments for the given process
     * @param workingDirectory The optional working directory of the process
     * @param performanceSettings See ProcessPerformanceSettings.hx for details
     */
    public function new( cmd:String, ?args:Array<String>, ?workingDirectory:String, ?performanceSettings:ProcessPerformanceSettings ) {

        super( cmd, args, workingDirectory, performanceSettings );

    }

    /**
     * Starts the process and sets up the relevant threads for stream processing.
     * @param inlineExecution If true, the process launches without additional output listener threads,
     * waiting for exit code in the current thread, therefore it's a thread blocking function. Stdout,
     * stderr data, pid, exit code, and callbacks are only available after the process finishes
     */
    override function start( ?inlineExecution:Bool ) {

        super.start( inlineExecution );

        if ( inlineExecution ) return;

        if ( !_cancelEventLoop && Thread.current().events != null ) _eventHandler = Thread.current().events.repeat( _frameLoop, Std.int( ( 1 / _performanceSettings.eventsPerSecond ) * 1000 ) );

    }

    override function _startInline() {

        super._startInline();

        if ( _onStdOut != null && this._stdoutBuffer.length > 0 ) _onStdOut( this );
        if ( _onStdErr != null && this._stderrBuffer.length > 0 ) _onStdErr( this );
        if ( _onStop != null ) _onStop( this );

    }

    function _frameLoop() {

        if ( _onStdOut != null && this._stdoutBuffer.length > 0 ) _onStdOut( this );

        if ( _onStdErr != null && this._stderrBuffer.length > 0 ) _onStdErr( this );

        if ( _exited ) {

            _cancelEventLoop = true;

            if ( _onStop != null ) _onStop( this );

        }

        if ( _cancelEventLoop && _eventHandler != null ) Thread.current().events.cancel( _eventHandler );

    }

}