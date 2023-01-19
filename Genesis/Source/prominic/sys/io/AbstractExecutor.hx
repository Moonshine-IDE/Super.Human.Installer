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

import prominic.sys.tools.StrTools;

abstract class AbstractExecutor {

    var _exitCode:Float;
    var _extraParams:Array<Dynamic>;
    var _id:String;
    var _onStart:List<( AbstractExecutor ) -> Void>;
    var _onStdErr:List<( AbstractExecutor, String ) -> Void>;
    var _onStdOut:List<( AbstractExecutor, String ) -> Void>;
    var _onStop:List<( AbstractExecutor ) -> Void>;
    var _running:Bool = false;

    public var exitCode( get, never ):Float;
    function get_exitCode() return _exitCode;

    public var extraParams( get, never ):Array<Dynamic>;
    function get_extraParams() return _extraParams;

    public var id( get, never ):String;
    function get_id() return _id;

    public var running( get, never ):Bool;
    function get_running() return _running;

    function new( ?extraParams:Array<Dynamic> ) {

        _id = StrTools.randomString( StrTools.ALPHANUMERIC, 16 );
        _exitCode = -1;
        _extraParams = extraParams;
        _onStart = new List();
        _onStdErr = new List();
        _onStdOut = new List();
        _onStop = new List();

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

    public function onStart( callback:( AbstractExecutor ) -> Void ):AbstractExecutor {

        _onStart.add( callback );
        return this;

    }

    public function onStdErr( callback:( AbstractExecutor, String ) -> Void ):AbstractExecutor {

        _onStdErr.add( callback );
        return this;

    }

    public function onStdOut( callback:( AbstractExecutor, String ) -> Void ):AbstractExecutor {

        _onStdOut.add( callback );
        return this;

    }

    public function onStop( callback:( AbstractExecutor ) -> Void ):AbstractExecutor {

        _onStop.add( callback );
        return this;

    }

    abstract public function execute( ?extraArgs:Array<String> ):AbstractExecutor;
    abstract public function stop( ?forced:Bool ):Void;

}