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

package prominic.sys.applications;

import prominic.sys.io.Executor;
import prominic.sys.io.process.ProcessTools.KillSignal;

class ExecutorManager {

    static var _instance:ExecutorManager;

    static public function getInstance():ExecutorManager {

        if ( _instance == null ) _instance = new ExecutorManager();
        return _instance;

    }

    var _executors:Map<String, Executor>;

    function new() {

        _executors = [];

    }

    public function clear() {

        _executors.clear();

    }

    public function exists( key:String ):Bool {

        return _executors.exists( key );

    }

    public function get( key:String ):Executor {

        return _executors.get( key );

    }

    public function killAll() {

        for ( e in _executors ) e.kill( KillSignal.Kill );

    }

    public function remove( key:String ):Bool {

        return _executors.remove( key );

    }

    public function set( key:String, value:Executor ) {

        _executors.set( key, value );

    }

    public function stopAll( ?forced:Bool ) {

        for ( e in _executors ) e.stop( forced );

    }

}