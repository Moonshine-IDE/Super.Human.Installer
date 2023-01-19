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

package genesis.application.components;

import feathers.controls.Button;
import feathers.controls.LayoutGroup;
import feathers.events.TriggerEvent;
import genesis.application.events.GenesisApplicationEvent;

class LoginControl extends LayoutGroup {

    var _loginButton:Button;
    var _showLoginButton:Bool;
    var _userButton:Button;

    var _loggedIn:Bool = false;
    public var loggedIn( get, set ):Bool;
    function get_loggedIn():Bool return _loggedIn;
    function set_loggedIn( value:Bool ):Bool {
        if ( value == _loggedIn ) return value;
        _loggedIn = value;
        _setLoggedInState();
        return value;
    }

    var _username:String;
    public var username( get, set ):String;
    function get_username():String return _username;
    function set_username( value:String ):String {
        if ( value == _username ) return value;
        _username = value;
        _setLoggedInState();
        return value;
    }

    public function new( showLoginButton:Bool = true ) {

        super();

        _showLoginButton = showLoginButton;

        _loginButton = new Button();
        _loginButton.text = "Sign In";
        _loginButton.addEventListener( TriggerEvent.TRIGGER, _loginButtonTriggered );

        _userButton = new Button();
        _userButton.addEventListener( TriggerEvent.TRIGGER, _userButtonTriggered );

        _setLoggedInState();

    }

    function _loginButtonTriggered( e:TriggerEvent ) {

        this.dispatchEvent( new GenesisApplicationEvent( GenesisApplicationEvent.LOGIN ) );

    }

    function _setLoggedInState() {

        if ( _loggedIn ) {

            this.removeChildren();
            _userButton.text = _username;
            this.addChild( _userButton );

        } else {

            this.removeChildren();
            if ( _showLoginButton ) this.addChild( _loginButton );

        }

    }

    function _userButtonTriggered( e:TriggerEvent ) {

        

    }

}