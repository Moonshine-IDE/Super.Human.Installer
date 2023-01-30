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

import haxe.io.Eof;
import prominic.sys.io.process.data.Message;
import prominic.sys.io.process.data.StringBuffer;
import sys.io.Process;
import sys.thread.Mutex;
import sys.thread.Thread;

abstract class AbstractProcess {

    static final _defaultPerformaceSettings:ProcessPerformanceSettings = {

        disableWaitForExitThread: true,
        inputBufferSize: 32768,
        inputReadRepeatDelay: .0,
        messageReceiverRepeatDelay: .0,
        waitForExitDelay: .0,

    };

    final _mutex:Mutex = new Mutex();

    var _args:Array<String>;
    var _bufferMutex:Mutex;
    var _className:String;
    var _cmd:String;
    var _done:Bool = false;
    var _exitCode:Int = -1;
    var _exited:Bool = false;
    var _performanceSettings:ProcessPerformanceSettings;
    var _pid:Int;
    var _process:Process;
    var _receiverThread:Thread;
    var _running:Bool = false;
    var _stderrBuffer:StringBuffer;
    var _stderrFinished:Bool = false;
    var _stdoutBuffer:StringBuffer;
    var _stdoutFinished:Bool = false;
    var _workingDirectory:String;

    public var exitCode( get, never ):Int;
    function get_exitCode() return _exitCode;

    public var pid( get, never ):Int;
    function get_pid() return _pid;

    public var running( get, never ):Bool;
    function get_running() return _running;

    public var stderrBuffer( get, never ):StringBuffer;
    function get_stderrBuffer() return _stderrBuffer;

    public var stdoutBuffer( get, never ):StringBuffer;
    function get_stdoutBuffer() return _stdoutBuffer;

    public var workingDirectory( get, never ):String;
    function get_workingDirectory() return _workingDirectory;
    
    function new( cmd:String, ?args:Array<String>, ?workingDirectory:String, ?performanceSettings:ProcessPerformanceSettings ) {

        _cmd = cmd;
        _args = args;
        _workingDirectory = workingDirectory;
        
        _performanceSettings = ( performanceSettings != null ) ? performanceSettings : _defaultPerformaceSettings;
        if ( _performanceSettings.disableWaitForExitThread == null ) _performanceSettings.disableWaitForExitThread = _defaultPerformaceSettings.disableWaitForExitThread;
        if ( _performanceSettings.inputBufferSize == null ) _performanceSettings.inputBufferSize = _defaultPerformaceSettings.inputBufferSize;
        if ( _performanceSettings.inputReadRepeatDelay == null ) _performanceSettings.inputReadRepeatDelay = _defaultPerformaceSettings.inputReadRepeatDelay;
        if ( _performanceSettings.messageReceiverRepeatDelay == null ) _performanceSettings.inputReadRepeatDelay = _defaultPerformaceSettings.messageReceiverRepeatDelay;
        if ( _performanceSettings.waitForExitDelay == null ) _performanceSettings.waitForExitDelay = _defaultPerformaceSettings.waitForExitDelay;

        var a = Type.getClassName( Type.getClass( this ) ).split( '.' );
        _className = a[ a.length - 1 ];

        _bufferMutex = new Mutex();
        _stderrBuffer = new StringBuffer();
        _stdoutBuffer = new StringBuffer();

    }

    public function clearBuffers() {

        _stderrBuffer.clear();
        _stdoutBuffer.clear();

    }

    public function kill() {
        
        ProcessTools.kill( this._pid );

    }

    public function start() {

        // The process is either running or already exited
        if ( _process != null || _running || _exited ) return;

        #if verbose_process_logs trace( '[${_className}] start()' ); #end

        _mutex.acquire();
        final cwd:String = Sys.getCwd();
        if ( _workingDirectory != null ) Sys.setCwd( _workingDirectory );
        _process = new Process( _cmd, _args );
        _pid = _process.getPid();
        _running = true;
        if ( _workingDirectory != null ) Sys.setCwd( cwd );
        _mutex.release();
        #if verbose_process_logs trace( '[${_className}][Process:${_pid}:${_cmd}:${_args}] Started' ); #end

        #if verbose_process_logs trace( '[${_className}] Initializing Thread:MessageReceiver' ); #end
        _receiverThread = Thread.create( _waitForThreadMessages );

        #if verbose_process_logs trace( '[${_className}:${_pid}] Initializing Thread:StdOut' ); #end
        Thread.create( _readStdOut );
        #if verbose_process_logs trace( '[${_className}:${_pid}] Initializing Thread:StdErr' ); #end
        Thread.create( _readStdErr );

        if ( !_performanceSettings.disableWaitForExitThread ) {

            #if verbose_process_logs trace( '[${_className}:${_pid}] Initializing Thread:WaitForExit' ); #end
            Thread.create( _waitForExit );

        } else {

            #if verbose_process_logs trace( '[${_className}:${_pid}] Disabled Thread:WaitForExit' ); #end

        }

    }

    public function stop( forced:Bool = false ) {

        if ( !_running || _exited ) return;

        #if verbose_process_logs trace( '[${_className}] stop( forced:${forced} )' ); #end

        if ( forced ) {

            if ( _process != null ) _process.kill();

        } else {

            if ( _process != null ) _process.close();

        }

    }

    function _getExitCode() {

        if ( _exitCode != -1 || _exited ) return;

        #if verbose_process_logs trace( '[${_className}:${_pid}][ProcessExit] Started' ); #end
        _mutex.acquire();
        _exitCode = _process.exitCode();
        _process.close();
        _exited = true;
        _running = false;
        _mutex.release();
        #if verbose_process_logs trace( '[${_className}:${_pid}][ProcessExit] Exit code received: ${_exitCode}' ); #end
        #if verbose_process_logs trace( '[${_className}:${_pid}][ProcessExit] Finished' ); #end

    }

    function _readStdOut() {

        final _threadName:String = "StdOut";

        #if verbose_process_logs trace( '[${_className}:${_pid}][Thread:${_threadName}] Started' ); #end

        while( true ) {

            try {

                #if verbose_process_logs trace( '[${_className}:${_pid}][Thread:${_threadName}] Trying to read' ); #end
                final data = StreamTools.readInput( _process.stdout, _performanceSettings.inputBufferSize );

                final object:MessageObject = { sender: MessageSender.StandardOutput };

                if ( data != null && data.length > 0 ) {

                    #if verbose_process_logs trace( '[${_className}:${_pid}][Thread:${_threadName}] Data received' ); #end
                    object.command = MessageCommand.Data;
                    object.data = data;

                } else {

                    #if verbose_process_logs trace( '[${_className}:${_pid}][Thread:${_threadName}] Null received, closing Input' ); #end
                    object.command = MessageCommand.Close;

                }

                _receiverThread.sendMessage( Message.fromMessageObject( object ) );

                if ( object.command == MessageCommand.Close ) {
                 
                    break;

                }

            } catch ( e:Eof ) {

                #if verbose_process_logs trace( '[${_className}:${_pid}][Thread:${_threadName}] EOF received, closing Input' ); #end
                final object:MessageObject = { command: MessageCommand.Close, sender: MessageSender.StandardOutput };
                _receiverThread.sendMessage( Message.fromMessageObject( object ) );

                break;

            } catch ( e:Dynamic ) {}

            if ( _performanceSettings.inputReadRepeatDelay > 0 ) Sys.sleep( _performanceSettings.inputReadRepeatDelay );

        }

        #if verbose_process_logs trace( '[${_className}:${_pid}][Thread:${_threadName}] Finished' ); #end

    }

    function _readStdErr() {

        final _threadName:String = "StdErr";

        #if verbose_process_logs trace( '[${_className}:${_pid}][Thread:${_threadName}] Started' ); #end

        while( true ) {

            try {

                #if verbose_process_logs trace( '[${_className}:${_pid}][Thread:${_threadName}] Trying to read' ); #end
                final data = StreamTools.readInput( _process.stderr, _performanceSettings.inputBufferSize );

                final object:MessageObject = { sender: MessageSender.StandardError };

                if ( data != null && data.length > 0 ) {

                    #if verbose_process_logs trace( '[${_className}:${_pid}][Thread:${_threadName}] Data received' ); #end
                    object.command = MessageCommand.Data;
                    object.data = data;

                } else {

                    #if verbose_process_logs trace( '[${_className}:${_pid}][Thread:${_threadName}] Null received, closing Input' ); #end
                    object.command = MessageCommand.Close;

                }

                _receiverThread.sendMessage( Message.fromMessageObject( object ) );

                if ( object.command == MessageCommand.Close ) {
                    
                    break;

                }

            } catch ( e:Eof ) {

                #if verbose_process_logs trace( '[${_className}:${_pid}][Thread:${_threadName}] EOF received, closing Input' ); #end
                final object:MessageObject = { command: MessageCommand.Close, sender: MessageSender.StandardError };
                _receiverThread.sendMessage( Message.fromMessageObject( object ) );

                break;

            } catch ( e:Dynamic ) {}

            if ( _performanceSettings.inputReadRepeatDelay > 0 ) Sys.sleep( _performanceSettings.inputReadRepeatDelay );

        }

        #if verbose_process_logs trace( '[${_className}:${_pid}][Thread:${_threadName}] Finished' ); #end

    }

    function _waitForExit() {

        final _threadName:String = "WaitForExit";

        #if verbose_process_logs trace( '[${_className}:${_pid}][Thread:${_threadName}] Started' ); #end

        if ( _performanceSettings.waitForExitDelay > 0 ) Sys.sleep( _performanceSettings.waitForExitDelay );

        final e = _process.exitCode();

        #if verbose_process_logs trace( '[${_className}:${_pid}][Thread:${_threadName}] Exit code received: ${e}' ); #end

        if ( _performanceSettings.waitForExitDelay > 0 ) Sys.sleep( _performanceSettings.waitForExitDelay );

        final object:MessageObject = { command: MessageCommand.Exit, sender: MessageSender.Process, value: e };
        _receiverThread.sendMessage( Message.fromMessageObject( object ) );

        #if verbose_process_logs trace( '[${_className}:${_pid}][Thread:${_threadName}] Finished' ); #end

    }

    function _waitForThreadMessages() {

        final _threadName:String = "MessageReceiver";

        #if verbose_process_logs trace( '[${_className}:${_pid}][Thread:${_threadName}] Started' ); #end

        while ( !_done ) {

            #if verbose_process_logs trace( '[${_className}:${_pid}][Thread:${_threadName}] Waiting for messages' ); #end
            final message:Message = Thread.readMessage( true );

            if ( message != null ) {

                #if verbose_process_logs trace( '[${_className}:${_pid}][Thread:${_threadName}] Message received' ); #end
                var object:MessageObject = message.toMessageObject();
                object.pid = this._pid;

                switch ( object.sender ) {

                    case MessageSender.Process:

                        switch ( object.command ) {
        
                            case MessageCommand.Exit:
                                _mutex.acquire();
                                _exited = true;
                                _exitCode = object.value;
                                _running = false;
                                _mutex.release();
        
                            default:
        
                        }
        
                    case MessageSender.StandardOutput:
        
                        switch ( object.command ) {
        
                            case MessageCommand.Data:
                                _mutex.acquire();
                                if ( object.data != null && object.data.length > 0 ) _stdoutBuffer.add( object.data );
                                _mutex.release();
        
                            case MessageCommand.Close:
                                _mutex.acquire();
                                _stdoutFinished = true;
                                _mutex.release();
        
                            default:
        
                        }
        
                    case MessageSender.StandardError:
        
                        switch ( object.command ) {
        
                            case MessageCommand.Data:
                                _mutex.acquire();
                                if ( object.data != null && object.data.length > 0 ) _stderrBuffer.add( object.data );
                                _mutex.release();
        
                            case MessageCommand.Close:
                                _mutex.acquire();
                                _stderrFinished = true;
                                _mutex.release();
        
                            default:
        
                        }
        
                    default:
        
                }

                object = null;

                #if verbose_process_logs 
                if ( _performanceSettings.disableWaitForExitThread )
                    trace( '[${_className}:${_pid}][Thread:${_threadName}] StdOut.finished:${_stdoutFinished}, StdErr.finished:${_stderrFinished}' )
                else
                    trace( '[${_className}:${_pid}][Thread:${_threadName}] StdOut.finished:${_stdoutFinished}, StdErr.finished:${_stderrFinished}, WaitForExit.finished:${_exited}' );
                #end

                if ( _stdoutFinished && _stderrFinished ) {

                    if ( _performanceSettings.disableWaitForExitThread ) {

                        #if verbose_process_logs trace( '[${_className}:${_pid}][Thread:${_threadName}] All 2 threads are finished' ); #end

                        _mutex.acquire();
                        /* */
                        _done = true;
                        _mutex.release();

                    } else {

                        if ( _exited ) {

                            #if verbose_process_logs trace( '[${_className}:${_pid}][Thread:${_threadName}] All 3 threads are finished' ); #end

                            _mutex.acquire();
                            /* */
                            _done = true;
                            _mutex.release();

                        }

                    }
        
                }

            }

            if ( _performanceSettings.messageReceiverRepeatDelay > 0 ) Sys.sleep( _performanceSettings.messageReceiverRepeatDelay );

        }

        #if verbose_process_logs trace( '[${_className}:${_pid}][Thread:${_threadName}] Cleaning up' ); #end

        #if verbose_process_logs trace( '[${_className}:${_pid}][Thread:${_threadName}] Finished' ); #end

        _getExitCode();

        _mutex.acquire();
        _args = null;
        _receiverThread = null;
        _mutex.release();

        #if verbose_process_logs trace( '[${_className}:${_pid}] <<<<< Finished with Exit Code: ${_exitCode} >>>>>' ); #end

    }

}