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

import prominic.core.ds.ChainedList;
import prominic.sys.io.process.ProcessTools.KillSignal;
import prominic.sys.tools.StrTools;

abstract class AbstractExecutor {

    var _exitCode:Float;
    var _extraParams:Array<Dynamic>;
    var _hasErrors:Bool = false;
    var _id:String;
    var _onStart:ChainedList<( AbstractExecutor ) -> Void, AbstractExecutor>;
    var _onStdErr:ChainedList<( AbstractExecutor, String ) -> Void, AbstractExecutor>;
    var _onStdOut:ChainedList<( AbstractExecutor, String ) -> Void, AbstractExecutor>;
    var _onStop:ChainedList<( AbstractExecutor ) -> Void, AbstractExecutor>;
    var _running:Bool = false;
    var _startTime:Null<Float>;
    var _stopTime:Null<Float>;

    public var exitCode( get, never ):Float;
    function get_exitCode() return _exitCode;

    public var extraParams( get, never ):Array<Dynamic>;
    function get_extraParams() return _extraParams;

    public var hasErrors( get, never ):Bool;
    function get_hasErrors() return _hasErrors;

    public var id( get, never ):String;
    function get_id() return _id;

    public var onStart( get, never ):ChainedList<( AbstractExecutor ) -> Void, AbstractExecutor>;
    function get_onStart() return _onStart;

    public var onStdErr( get, never ):ChainedList<( AbstractExecutor, String ) -> Void, AbstractExecutor>;
    function get_onStdErr() return _onStdErr;

    public var onStdOut( get, never ):ChainedList<( AbstractExecutor, String ) -> Void, AbstractExecutor>;
    function get_onStdOut() return _onStdOut;

    public var onStop( get, never ):ChainedList<( AbstractExecutor ) -> Void, AbstractExecutor>;
    function get_onStop() return _onStop;

    public var running( get, never ):Bool;
    function get_running() return _running;

    public var runtime( get, never ):Null<Float>;
    function get_runtime() {
        var result:Null<Float> = null;
        if ( _startTime != null ) {
            if ( _stopTime != null ) {
                result = _stopTime - _startTime;
            } else {
                result = Sys.time() - _startTime;
            }
        }
        return result;
    }

    function new( ?extraParams:Array<Dynamic> ) {

        _id = StrTools.randomString( StrTools.ALPHANUMERIC, 16 );
        _exitCode = -1;
        _extraParams = extraParams;
        _onStart = new ChainedList( this );
        _onStdErr = new ChainedList( this );
        _onStdOut = new ChainedList( this );
        _onStop = new ChainedList( this );

    }

    public function dispose() {

        if ( _onStart != null ) _onStart.clear();
        _onStart = null;

        if ( _onStdErr != null ) _onStdErr.clear();
        _onStdErr = null;

        if ( _onStdOut != null ) _onStdOut.clear();
        _onStdOut = null;

        if ( _onStop != null ) _onStop.clear();
        _onStop = null;

    }

    public function toString():String {

        return '[AbstractExecutor:${_id}]';

    }

    abstract public function execute( ?extraArgs:Array<String>, ?workingDirectory:String ):AbstractExecutor;
    abstract public function kill( signal:KillSignal ):Void;
    abstract public function simulateStop():Void;
    abstract public function stop( ?forced:Bool ):Void;

}