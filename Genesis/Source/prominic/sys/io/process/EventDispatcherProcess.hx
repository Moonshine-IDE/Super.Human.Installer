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

import openfl.display.DisplayObject;
import openfl.events.Event;
import openfl.events.EventDispatcher;
import openfl.events.EventType;
import openfl.events.IEventDispatcher;
import sys.thread.EventLoop.EventHandler;
import sys.thread.Mutex;
import sys.thread.Thread;

/**
 * A BufferedProcess implementation that dispatches ProcessEvents on specific events of
 * the spawned process. For stream output and event handling, either an internal
 * loop will be created and attached to the current thread, or an
 * openfl.display.DisplayObject's EnterFrame event will be used
 */
class EventDispatcherProcess extends BufferedProcess implements IEventDispatcher {

    final _fps:Int = 30;

    var _enterFrameEventDispatcher:EventDispatcher;
    var _eventDispatcherMutex:Mutex;
    var _eventHandler:EventHandler;
    var _internalEventDispatcher:EventDispatcher;

    /**
     * A BufferedProcess implementation that dispatches ProcessEvents on specific events of
     * the spawned process. For stream output and event handling, either an internal
     * loop will be created and attached to the current thread, or an
     * openfl.display.DisplayObject's EnterFrame event will be used
     * @param cmd The command to execute, the process will be spawned with this command
     * @param args Optional command line arguments for the given process
     * @param workingDirectory The optional working directory of the process
     * @param performanceSettings See ProcessPerformanceSettings.hx for details
     * @param enterFrameEventDispatcher If defined, this DisplayObject's EnterFrame event
     * will be used to process stream data and fire appropriate events
     */
    public function new( cmd:String, ?args:Array<String>, ?workingDirectory:String, ?performanceSettings:ProcessPerformanceSettings, ?enterFrameEventDispatcher:DisplayObject ) {

        super( cmd, args, workingDirectory, performanceSettings );

        _internalEventDispatcher = new EventDispatcher();
        _eventDispatcherMutex = new Mutex();
        _enterFrameEventDispatcher = enterFrameEventDispatcher;

    }

    /**
     * Starts the process and sets up the relevant threads or event listeners for stream processing.
     */
    override function start() {

        super.start();

        if ( _enterFrameEventDispatcher != null ) {

            _enterFrameEventDispatcher.addEventListener( Event.ENTER_FRAME, _eventLoop );

        } else {

            _eventHandler = Thread.current().events.repeat( _frameLoop, Std.int( ( 1 / _fps ) * 1000 ) );

        }

    }

    public function addEventListener<T>( type:EventType<T>, listener:T->Void, useCapture:Bool = false, priority:Int = 0, useWeakReference:Bool = false ) {

        return _internalEventDispatcher.addEventListener( type, listener, useCapture, priority, useWeakReference );

    }

    public function dispatchEvent( event:Event ):Bool {

        return _internalEventDispatcher.dispatchEvent( event );

    }

    public function hasEventListener( type:String ):Bool {

        return _internalEventDispatcher.hasEventListener( type );

    }

    public function removeEventListener<T>( type:EventType<T>, listener:T->Void, useCapture:Bool = false ) {

        return _internalEventDispatcher.removeEventListener( type, listener, useCapture );

    }

    public function willTrigger( type:String ):Bool {

        return _internalEventDispatcher.willTrigger( type );

    }

    function _eventLoop( ?e:Dynamic ) {

        _frameLoop();

    }

    inline function _frameLoop() {

        if ( this._stdoutBuffer.length > 0 ) {

            _eventDispatcherMutex.acquire();
            var evt = new ProcessEvent( ProcessEvent.STDOUT_DATA );
            evt.process = this;
            this.dispatchEvent( evt );
            _eventDispatcherMutex.release();

        }

        if ( this._stderrBuffer.length > 0 ) {

            _eventDispatcherMutex.acquire();
            var evt = new ProcessEvent( ProcessEvent.STDERR_DATA );
            evt.process = this;
            this.dispatchEvent( evt );
            _eventDispatcherMutex.release();

        }

        if ( _exited ) {

            _eventDispatcherMutex.acquire();

            if ( _enterFrameEventDispatcher != null ) {

                _enterFrameEventDispatcher.removeEventListener( Event.ENTER_FRAME, _eventLoop );
                _enterFrameEventDispatcher = null;

            } else {

                if ( _eventHandler != null ) Thread.current().events.cancel( _eventHandler );

            }

            var evt = new ProcessEvent( ProcessEvent.PROCESS_EXIT );
            evt.process = this;
            this.dispatchEvent( evt );
            _eventDispatcherMutex.release();

        }

    }

}

class ProcessEvent extends Event {

    static public final PROCESS_EXIT:String = 'process-exit';
    static public final STDERR_DATA:String = 'stderr-data';
    static public final STDOUT_DATA:String = 'stdout-data';

    public var process:EventDispatcherProcess;

    public function new( type:String, bubbles:Bool = false, cancelable:Bool = false ) {
        
        super( type, bubbles, cancelable );

    }

}