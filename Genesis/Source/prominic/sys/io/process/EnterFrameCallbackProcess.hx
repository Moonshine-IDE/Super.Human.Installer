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

/**
 * A CallbackProcess implementation that calls callback functions
 * on specific events of the spawned process. For stream output and event handling,
 * either an internal loop will be created and attached to the current thread,
 * or an openfl.display.DisplayObject's EnterFrame event will be used
 */
class EnterFrameCallbackProcess extends CallbackProcess {

    var _enterFrameEventDispatcher:EventDispatcher;

    /**
     * A CallbackProcess implementation that calls callback functions
     * on specific events of the spawned process. For stream output and event handling,
     * either an internal loop will be created and attached to the current thread,
     * or an openfl.display.DisplayObject's EnterFrame event will be used. If the current
     * thread does not have an event loop, callbacks will not be called.
     * @param cmd The command to execute, the process will be spawned with this command
     * @param args Optional command line arguments for the given process
     * @param workingDirectory The optional working directory of the process
     * @param performanceSettings See ProcessPerformanceSettings.hx for details
     * @param enterFrameEventDispatcher If defined, this DisplayObject's EnterFrame event
     * will be used to process stream data and fire appropriate events
     */
    public function new( cmd:String, ?args:Array<String>, ?workingDirectory:String, ?performanceSettings:ProcessPerformanceSettings, ?enterFrameEventDispatcher:DisplayObject ) {

        super( cmd, args, workingDirectory, performanceSettings );

        _enterFrameEventDispatcher = enterFrameEventDispatcher;

    }

    /**
     * Starts the process and sets up the relevant threads or event listeners for stream processing.
     */
    override function start() {

        if ( _enterFrameEventDispatcher != null ) {

            _enterFrameEventDispatcher.addEventListener( Event.ENTER_FRAME, _eventLoop );
            _cancelEventLoop = true;

        }

        super.start();

    }

    function _eventLoop( ?e:Dynamic ) {

        _frameLoop();

    }

    override function _frameLoop() {

        super._frameLoop();

        if ( _exited ) {

            if ( _enterFrameEventDispatcher != null ) {

                _enterFrameMutex.acquire();
                _enterFrameEventDispatcher.removeEventListener( Event.ENTER_FRAME, _eventLoop );
                _enterFrameMutex.release();

            }

        }

    }
    
}