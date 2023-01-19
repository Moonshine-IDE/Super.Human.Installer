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

package genesis.remote;

import genesis.remote.events.AuthEvent;
import haxe.Json;
import haxe.io.Path;
import lime.system.System;
import openfl.events.EventDispatcher;
#if sys
import sys.io.File;
#end
#if web
import js.Browser;
#end

class GenesisRemote extends EventDispatcher {

    final _filename:String = ".genesis";

    var _saveCredentials:Bool = false;

    public var context( get, never ):AuthContext;
    var _context:AuthContext;
    function get_context():AuthContext return _context;

    public var loggedIn( get, never ):Bool;
    var _loggedIn:Bool = false;
    function get_loggedIn():Bool return _loggedIn;

    public var user( get, never ):AuthUser;
    var _user:AuthUser = {};
    function get_user():AuthUser return _user;

    public function new() {

        super();

    }

    public function authenticate( username:String, password:String, ?saveCredentials:Bool = false, ?context:AuthContext = AuthContext.Local ) {

        _user.username = username;
        _saveCredentials = saveCredentials;
        _context = context;
        #if web
        _context = AuthContext.Local;
        #end
        _authComplete();

    }

    function _authComplete() {

        _loggedIn = true;
        _user.token = "1234567890";

        if ( _saveCredentials ) _saveAuthInfo();
        
        var e = new AuthEvent( AuthEvent.COMPLETE );
        e.success = true;
        this.dispatchEvent( e );

    }

    function _saveAuthInfo() {

        var s = Json.stringify( _user );
        var d = System.applicationStorageDirectory;

        switch( _context ) {

            case AuthContext.Global:
                var p = new Path( d );
                var a = d.split( ( p.backslash ) ? "\\" : "/" );
                a.pop();
                a.pop();
                a.push("");
                d = a.join( ( p.backslash ) ? "\\" : "/" );
                #if sys
                File.saveContent( d + _filename, s );
                #elseif web
                Browser.getLocalStorage().setItem( _filename, s );
                #end

            case AuthContext.Local:
                #if sys
                File.saveContent( d + _filename, s );
                #elseif web
                Browser.getLocalStorage().setItem( _filename, s );
                #end

            default:

        }

    }

}