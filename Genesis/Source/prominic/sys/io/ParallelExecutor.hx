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

import prominic.logging.Logger;
import prominic.sys.io.process.ProcessTools.KillSignal;

class ParallelExecutor extends AbstractExecutor {

    static public function create( dispatchProgressEvents:Bool = false ) {

        var e = new ParallelExecutor();
        e._dispatchProgressEvents = dispatchProgressEvents;
        return e;

    }

    var _dispatchProgressEvents:Bool;
    var _executors:Array<AbstractExecutor>;
    var _hasError:Bool;

    public var hasError( get, never ):Bool;
    function get_hasError() return _hasError;

    function new() {

        super();

        _executors = [];

    }

    public function add( ...executors:AbstractExecutor ):ParallelExecutor {

        for ( e in executors ) _executors.push( e );
        return this;

    }

    override public function dispose() {

        Logger.debug( '${this}: Disposing...' );
        
        super.dispose();

    }

    public function execute( ?extraArgs:Array<String>, ?workingDirectory:String ) {

        var a:Array<String> = [];
        for ( e in _executors ) a.push( e.id );
        Logger.debug( '${this}: execute() executors:${a} extraArgs:${extraArgs} workingDirectory:${workingDirectory}' );

        if ( _executors.length == 0 ) {

            for ( f in _onStop ) f( this );

        } else {

            for ( executor in _executors ) {

                executor.onStop.add( _executorStopped );
                executor.execute( extraArgs );

            }

        }

        return this;

    }

    public function kill( signal:KillSignal ) {}

    function _executorStopped( executor:AbstractExecutor ) {

        if ( executor.exitCode != 0 ) this._hasError = true;

        _executors.remove( executor );

        if ( _executors.length == 0 ) {

            Logger.debug( '${this}: All executors stopped. Errors: ${this._hasError}' );
            for ( f in _onStop ) f( this );

        }

    }

    @:keep
    public function stop( ?forced:Bool ) { }

    @:keep
    public function simulateStop() {}

    public override function toString():String {

        return '[ParallelExecutor(${this._id})]';

    }
    
}
