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
import openfl.Lib;
import openfl.desktop.NativeProcess;
import openfl.desktop.NativeProcessStartupInfo;
import openfl.errors.IOError;
import openfl.events.Event;
import openfl.events.IEventDispatcher;
import openfl.events.IOErrorEvent;
import openfl.events.NativeProcessExitEvent;
import openfl.events.ProgressEvent;
import openfl.utils.ByteArray;
import sys.io.Process;
import sys.thread.EventLoop.EventHandler;
import sys.thread.Mutex;
import sys.thread.Thread;

/**
 * @see More info: <https://api.openfl.org/openfl/desktop/NativeProcess.html>
 */
class AdvancedNativeProcess extends NativeProcess {

    var __pid:Int;
    public var pid( get, never ):Int;
    function get_pid() return __pid;

    var _stdoutCallback:(String)->Void;
    public var stdoutCallback( get, set ):(String)->Void;
    function get_stdoutCallback() return _stdoutCallback;
    function set_stdoutCallback( value:(String)->Void ):(String)->Void { _stdoutCallback = value; return _stdoutCallback; }

    var _stdoutBuffer:String;

    public function new() {

        super();

    }
    
    override function start( info:NativeProcessStartupInfo ) {

        super.start( info );

        __pid = __process.getPid();

    }

    public function startCommand( cmd:String, ?args:Array<String>, ?workingDirectory:String, ?loopInterval:Int = 100 ):Void {
        var cwdToRestore:String = null;
        if (workingDirectory != null)
        {
            cwdToRestore = Sys.getCwd();
            Sys.setCwd(workingDirectory);
        }
        __processKilled = false;
        __process = new Process(cmd, args, false);
        __pid = __process.getPid();
        var standardOutputMutex = new Mutex();
        __standardOutput.mutex = standardOutputMutex;
        __standardOutput.input = new ByteArray();
        var standardErrorMutex = new Mutex();
        __standardError.mutex = standardErrorMutex;
        __standardError.input = new ByteArray();
        __standardInput.output = __process.stdin;
        if (cwdToRestore != null)
        {
            Sys.setCwd(cwdToRestore);
        }

        var pendingStdoutBytes:Int = 0;
        var pendingStderrBytes:Int = 0;
        var pendingStdoutIOError:IOError = null;
        var pendingStderrIOError:IOError = null;
        var pendingExitCode:Null<Float> = null;
        var pendingExitCodeMutex = new Mutex();
        var eventHandler:EventHandler = null;
        var eventLoopMutex = new Mutex();

        function startLoop() {
            var t = Thread.current();
            eventHandler = t.events.repeat( () -> {

                eventLoopMutex.acquire();

                standardOutputMutex.acquire();
                if (pendingStdoutBytes > 0)
                {
                    dispatchEvent(new ProgressEvent(ProgressEvent.STANDARD_OUTPUT_DATA, false, false, pendingStdoutBytes));
                    pendingStdoutBytes = 0;
                }

                standardOutputMutex.release();

                standardErrorMutex.acquire();
                if (pendingStderrBytes > 0)
                {
                    dispatchEvent(new ProgressEvent(ProgressEvent.STANDARD_ERROR_DATA, false, false, pendingStderrBytes));
                    pendingStderrBytes = 0;
                }
                standardErrorMutex.release();

                standardOutputMutex.acquire();
                if (pendingStdoutIOError != null)
                {
                    var ioError = pendingStdoutIOError;
                    pendingStdoutIOError = null;
                    dispatchEvent(new IOErrorEvent(IOErrorEvent.STANDARD_OUTPUT_IO_ERROR, false, false, ioError.message, ioError.errorID));
                }
                standardOutputMutex.release();

                standardErrorMutex.acquire();
                if (pendingStderrIOError != null)
                {
                    var ioError = pendingStderrIOError;
                    pendingStderrIOError = null;
                    dispatchEvent(new IOErrorEvent(IOErrorEvent.STANDARD_ERROR_IO_ERROR, false, false, ioError.message, ioError.errorID));
                }
                standardErrorMutex.release();

                pendingExitCodeMutex.acquire();
                if (pendingExitCode != null)
                {
                    dispatchEvent(new NativeProcessExitEvent(NativeProcessExitEvent.EXIT, false, false, pendingExitCode));
                    t.events.cancel( eventHandler );
                }
                pendingExitCodeMutex.release();

                eventLoopMutex.release();

            }, loopInterval );

        }
        Thread.runWithEventLoop( startLoop );

        function stdoutProgress(bytes:Bytes, length:Int):Void {
            standardOutputMutex.acquire();
            var newStandardOutput = new ByteArray();
            newStandardOutput.writeBytes(__standardOutput.input, __standardOutput.input.position);
            newStandardOutput.writeBytes(bytes, 0, length);
            newStandardOutput.position = 0;
            __standardOutput.input = newStandardOutput;
            pendingStdoutBytes += length;
            standardOutputMutex.release();
        }

        function stderrProgress(bytes:Bytes, length:Int):Void {
            standardErrorMutex.acquire();
            var newStandardError = new ByteArray();
            newStandardError.writeBytes(__standardError.input, __standardError.input.position);
            newStandardError.writeBytes(bytes, 0, length);
            newStandardError.position = 0;
            __standardError.input = newStandardError;
            pendingStderrBytes += length;
            standardErrorMutex.release();
        }

        var stdoutDone = false;
        var stderrDone = false;
        function createStderrThread():Void
        {
            Thread.create(function():Void
            {
                while (true)
                {
                    if (__processKilled)
                    {
                        break;
                    }
                    try
                    {
                        var bytes = Bytes.alloc(32768);
                        var length = __process.stderr.readBytes(bytes, 0, bytes.length);
                        stderrProgress(bytes, length);
                    }
                    catch (e:Eof)
                    {
                        // this is normal when the process exits
                        break;
                    }
                    catch (e:Dynamic)
                    {
                        standardErrorMutex.acquire();
                        pendingStderrIOError = new IOError(Std.string(e));
                        standardErrorMutex.release();
                        break;
                    }
                    Sys.sleep(.5);
                }
                standardErrorMutex.acquire();
                stderrDone = true;
                standardErrorMutex.release();
            });
        }
        function createStdoutThread():Void
        {
            Thread.create(function():Void
            {
                while (true)
                {
                    if (__processKilled)
                    {
                        break;
                    }
                    try
                    {
                        var bytes = Bytes.alloc(32768);
                        var length = __process.stdout.readBytes(bytes, 0, bytes.length);
                        stdoutProgress(bytes, length);
                    }
                    catch (e:Eof)
                    {
                        // this is normal when the process exits
                        break;
                    }
                    catch (e:Dynamic)
                    {
                        standardOutputMutex.acquire();
                        pendingStdoutIOError = new IOError(Std.string(e));
                        standardOutputMutex.release();
                        break;
                    }
                    Sys.sleep(.5);
                }
                standardOutputMutex.acquire();
                stdoutDone = true;
                standardOutputMutex.release();
                #if hl
                createStderrThread();
                #end
            });
        }
        function createExitThread():Void
        {
            Thread.createWithEventLoop(function():Void
            {
                var done = false;
                while (!done)
                {
                    Sys.sleep(.5);
                    standardOutputMutex.acquire();
                    standardErrorMutex.acquire();
                    done = stdoutDone && stderrDone;
                    standardErrorMutex.release();
                    standardOutputMutex.release();
                }
                var result = Math.NaN;
                try
                {
                    result = __process.exitCode(true);
                }
                catch (e:Dynamic)
                {
                    // may throw "process killed by signal 9"
                }
                if ( __process != null && !__processKilled ) __process.close();

                standardOutputMutex.acquire();
                __standardOutput.input = null;
                standardOutputMutex.release();

                standardErrorMutex.acquire();
                __standardError.input = null;
                standardErrorMutex.release();

                __standardInput.output = null;
                __process = null;

                pendingExitCodeMutex.acquire();
                pendingExitCode = result;
                pendingExitCodeMutex.release();
            });
        }
        createStdoutThread();
        #if !hl
        // for some reason, reading both stdout and stderr on HashLink causes
        // a freeze. as a workaround, we'll wait until stdout throws EOF before
        // we try to read stderr.
        createStderrThread();
        #end
        createExitThread();
    }

	public function startCommand2(cmd:String, ?args:Array<String>, ?workingDirectory:String):Void {
		var cwdToRestore:String = null;
		if (workingDirectory != null) {
			cwdToRestore = Sys.getCwd();
			Sys.setCwd(workingDirectory);
		}
		__processKilled = false;
		__process = new Process(cmd, args, false);
        __pid = __process.getPid();
		var standardOutputMutex = new Mutex();
		__standardOutput.mutex = standardOutputMutex;
		__standardOutput.input = new ByteArray();
		var standardErrorMutex = new Mutex();
		__standardError.mutex = standardErrorMutex;
		__standardError.input = new ByteArray();
		__standardInput.output = __process.stdin;
		if (cwdToRestore != null) {
			Sys.setCwd(cwdToRestore);
		}

		var pendingStdoutBytes:Int = 0;
		var pendingStderrBytes:Int = 0;
		var pendingStdoutIOError:IOError = null;
		var pendingStderrIOError:IOError = null;
		var pendingExitCode:Null<Float> = null;
		var pendingExitCodeMutex = new Mutex();
		function onEnterFrame(event:Event):Void {
			standardOutputMutex.acquire();
			if (pendingStdoutBytes > 0) {
                if ( _stdoutCallback != null ) _stdoutCallback( __standardOutput.readUTFBytes( __standardOutput.bytesAvailable ) );
				dispatchEvent(new ProgressEvent(ProgressEvent.STANDARD_OUTPUT_DATA, false, false, pendingStdoutBytes));
				pendingStdoutBytes = 0;
			}
			standardOutputMutex.release();

			standardErrorMutex.acquire();
			if (pendingStderrBytes > 0) {
				dispatchEvent(new ProgressEvent(ProgressEvent.STANDARD_ERROR_DATA, false, false, pendingStderrBytes));
				pendingStderrBytes = 0;
			}
			standardErrorMutex.release();

			standardOutputMutex.acquire();
			if (pendingStdoutIOError != null) {
				var ioError = pendingStdoutIOError;
				pendingStdoutIOError = null;
				dispatchEvent(new IOErrorEvent(IOErrorEvent.STANDARD_OUTPUT_IO_ERROR, false, false, ioError.message, ioError.errorID));
			}
			standardOutputMutex.release();

			standardErrorMutex.acquire();
			if (pendingStderrIOError != null) {
				var ioError = pendingStderrIOError;
				pendingStderrIOError = null;
				dispatchEvent(new IOErrorEvent(IOErrorEvent.STANDARD_ERROR_IO_ERROR, false, false, ioError.message, ioError.errorID));
			}
			standardErrorMutex.release();

			pendingExitCodeMutex.acquire();
			if (pendingExitCode != null) {
				cast(event.currentTarget, IEventDispatcher).removeEventListener(Event.ENTER_FRAME, onEnterFrame);
				dispatchEvent(new NativeProcessExitEvent(NativeProcessExitEvent.EXIT, false, false, pendingExitCode));
			}
			pendingExitCodeMutex.release();
		}
		Lib.current.addEventListener(Event.ENTER_FRAME, onEnterFrame);

		function stdoutProgress(bytes:Bytes, length:Int):Void {
			standardOutputMutex.acquire();
			var newStandardOutput = new ByteArray();
			newStandardOutput.writeBytes(__standardOutput.input, __standardOutput.input.position);
			newStandardOutput.writeBytes(bytes, 0, length);
			newStandardOutput.position = 0;
			__standardOutput.input = newStandardOutput;
			pendingStdoutBytes += length;
			standardOutputMutex.release();
		}

		function stderrProgress(bytes:Bytes, length:Int):Void {
			standardErrorMutex.acquire();
			var newStandardError = new ByteArray();
			newStandardError.writeBytes(__standardError.input, __standardError.input.position);
			newStandardError.writeBytes(bytes, 0, length);
			newStandardError.position = 0;
			__standardError.input = newStandardError;
			pendingStderrBytes += length;
			standardErrorMutex.release();
		}

		var stdoutDone = false;
		var stderrDone = false;
		function createStderrThread():Void {
			Thread.create(function():Void {
				while (true) {
					if (__processKilled) {
						break;
					}
					try {
						var bytes = Bytes.alloc(32768);
						var length = __process.stderr.readBytes(bytes, 0, bytes.length);
						stderrProgress(bytes, length);
					} catch (e:Eof) {
						// this is normal when the process exits
						break;
					} catch (e:Dynamic) {
						standardErrorMutex.acquire();
						pendingStderrIOError = new IOError(Std.string(e));
						standardErrorMutex.release();
						break;
					}
					Sys.sleep(1);
				}
				standardErrorMutex.acquire();
				stderrDone = true;
				standardErrorMutex.release();
			});
		}
		function createStdoutThread():Void {
			Thread.create(function():Void {
				while (true) {
					if (__processKilled) {
						break;
					}
					try {
						var bytes = Bytes.alloc(32768);
						var length = __process.stdout.readBytes(bytes, 0, bytes.length);
						stdoutProgress(bytes, length);
					} catch (e:Eof) {
						// this is normal when the process exits
						break;
					} catch (e:Dynamic) {
						standardOutputMutex.acquire();
						pendingStdoutIOError = new IOError(Std.string(e));
						standardOutputMutex.release();
						break;
					}
					Sys.sleep(1);
				}
				standardOutputMutex.acquire();
				stdoutDone = true;
				standardOutputMutex.release();
				#if hl
				createStderrThread();
				#end
			});
		}
		function createExitThread():Void {
			Thread.create(function():Void {
				var done = false;
				while (!done) {
					//Sys.sleep(1);
					standardOutputMutex.acquire();
					standardErrorMutex.acquire();
					done = stdoutDone && stderrDone;
					standardErrorMutex.release();
					standardOutputMutex.release();
				}
				var result = Math.NaN;
				try {
					result = __process.exitCode(true);
				} catch (e:Dynamic) {
					// may throw "process killed by signal 9"
				}
				__process.close();

				standardOutputMutex.acquire();
				//__standardOutput.input = null;
				standardOutputMutex.release();

				standardErrorMutex.acquire();
				__standardError.input = null;
				standardErrorMutex.release();

				__standardInput.output = null;
				__process = null;

				pendingExitCodeMutex.acquire();
				pendingExitCode = result;
				pendingExitCodeMutex.release();
			});
		}
		createStdoutThread();
		#if !hl
		// for some reason, reading both stdout and stderr on HashLink causes
		// a freeze. as a workaround, we'll wait until stdout throws EOF before
		// we try to read stderr.
		createStderrThread();
		#end
		createExitThread();
	}

    override function exit( force:Bool = false ) {

        //super.exit( force );

        var ec = -1;
        
        if ( __process == null || __processKilled ) {
            // no error or anything. simply return.
            return;
        }

        __processKilled = true;

        if ( force ) {
            
            __process.kill();
            __process = null;

        } else {

            __process.close();
            __process = null;

        }

        this.dispatchEvent(new NativeProcessExitEvent( NativeProcessExitEvent.EXIT, false, false, ec ) );

    }

}