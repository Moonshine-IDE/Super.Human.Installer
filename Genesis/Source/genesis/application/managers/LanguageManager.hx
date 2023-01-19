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

package genesis.application.managers;

import haxe.Json;
import openfl.events.EventDispatcher;
import sys.FileSystem;
import sys.io.File;

class LanguageManager extends EventDispatcher {

    static var _instance:LanguageManager;
    
    static public function getInstance():LanguageManager {

        if ( _instance == null ) _instance = new LanguageManager();
        return _instance;

    }

    var _data:Dynamic;

    public function new() {

        super();
        
        _instance = this;

    }

    public function getString( id:String, ...replacement:String ):String {

        var result:String = null;

        var a = id.split( '.' );
        var r:Dynamic = {};
        var node:Dynamic = _data;

        for ( i in a ) {

            r = _getValue( node, i );
            node = r;

        }

        if ( r != null ) {

            result = cast r;

            var n:Int = 1;

            for ( i in replacement ) {

                result = StringTools.replace( result, '%${n}', i );
                n++;

            }

        }

        return result;

    }

    function _getValue( node:Dynamic, field:String ):Dynamic {

        if ( Reflect.hasField( node, field ) ) {

            return Reflect.field( node, field );

        }

        return null;

    }

    public function load( path:String ):Bool {

        if ( !FileSystem.exists( path ) ) return false;

        try {

            var content = File.getContent( path );
            _data = Json.parse( content );

        } catch ( e ) {

            return false;

        }
        
        return true;

    }

}