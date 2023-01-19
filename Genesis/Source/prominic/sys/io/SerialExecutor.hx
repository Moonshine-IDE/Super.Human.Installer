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

import haxe.ds.Either;

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

    public function add( executor:Either<AbstractExecutor, Array<AbstractExecutor>> ):SerialExecutor {

        switch ( executor ) {

            case Left( l ):
                if ( l != null ) _executors.push( l );

            case Right( r ):
                for ( e in r ) if ( e != null ) _executors.push( e );

            default:
                
        }
        
        return this;

    }

    override public function dispose() {

        for ( e in _executors ) {

            e.dispose();

        }

        _executors = null;
        _currentExecutor = null;

        super.dispose();

    }

    public function execute( ?extraArgs:Array<String> ) {

        for ( e in _executors ) {

            e.onStop( _executorStopped );

        }

        if ( _executors.length > 0 ) {

            _currentExecutor = _executors[ 0 ];
            _currentExecutor.execute( extraArgs );
            
        }

        return this;

    }

    function _executorStopped( executor:AbstractExecutor ) {

        _currentExitCode = executor.exitCode;
        _executors.remove( _currentExecutor );

        if ( executor.exitCode != 0 && _stopOnError ) {

            for ( f in _onStop ) f( this );
            return;

        }

        if ( _executors.length > 0 ) {

            _currentExecutor = _executors[ 0 ];
            _currentExecutor.execute();

        } else {

            for ( f in _onStop ) f( this );

        }

    }

    @:keep
    public function stop( ?forced:Bool ) { }

}
