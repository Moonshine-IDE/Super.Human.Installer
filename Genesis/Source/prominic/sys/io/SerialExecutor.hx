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

import champaign.core.logging.Logger;
import champaign.sys.io.process.ProcessTools.KillSignal;
import prominic.sys.tools.StrTools;

class SerialExecutor extends AbstractExecutor {

    static public function create( stopOnError:Bool = false, dispatchProgressEvents:Bool = false ):SerialExecutor {

        var e = new SerialExecutor();
        e._stopOnError = stopOnError;
        e._dispatchProgressEvents = dispatchProgressEvents;
        return e;

    }
    
    var _currentExecutor:AbstractExecutor;
    var _currentExitCode:Float;
    var _dispatchProgressEvents:Bool;
    var _executors:Array<AbstractExecutor>;
    var _stopOnError:Bool;

    public var currentExecutor( get, never ):AbstractExecutor;
    function get_currentExecutor() return _currentExecutor;

    public var currentExitCode( get, never ):Float;
    function get_currentExitCode() return _currentExitCode;

    function new() {

        super();

        _executors = [];

    }

    public function add( ...executors:AbstractExecutor ):SerialExecutor {

        for ( e in executors ) _executors.push( e );
        return this;

    }

    override public function dispose() {

        Logger.debug( '${this}: Disposing...' );
        
        for ( e in _executors ) {

            e.dispose();

        }

        _executors = null;
        _currentExecutor = null;

        super.dispose();

    }

    public function execute( ?extraArgs:Array<String>, ?workingDirectory:String ) {

        var a:Array<String> = [];
        for ( e in _executors ) a.push( e.id );
        Logger.info( '${this}: execute() executors:${a} extraArgs:${extraArgs} workingDirectory:${workingDirectory}' );

        _startTime = Sys.time();
        _running = true;

        if ( _executors.length == 0 ) {

            _running = false;
            _stopTime = Sys.time();
            for ( f in _onStop ) f( this );
            return this;

        } else {

            for ( e in _executors ) e.onStop.add( _executorStopped );

            _currentExecutor = _executors[ 0 ];
            _currentExecutor.execute( extraArgs );

        }

        return this;

    }

    public function kill( signal:KillSignal ) {}

    function _executorStopped( executor:AbstractExecutor ) {

        _currentExitCode = executor.exitCode;
        _executors.remove( _currentExecutor );

        if ( executor.exitCode != 0 && _stopOnError ) {

            _running = false;
            _stopTime = Sys.time();
            Logger.info( '${this}: Stopping sequence. ${executor} stopped with exit code ${executor.exitCode}. Execution time: ${StrTools.timeToFormattedString(this.runtime, true)}' );
            for ( f in _onStop ) f( this );
            return;

        }

        if ( _executors.length > 0 ) {

            _currentExecutor = _executors[ 0 ];
            _currentExecutor.execute();

        } else {

            _running = false;
            _stopTime = Sys.time();
            Logger.info( '${this}: All executors stopped. Execution time: ${StrTools.timeToFormattedString(this.runtime, true)}' );
            for ( f in _onStop ) f( this );

        }

    }

    @:keep
    public function stop( ?forced:Bool ) { }

    @:keep
    public function simulateStop() {}

    public override function toString():String {

        return '[SerialExecutor(${this._id})]';

    }

}
