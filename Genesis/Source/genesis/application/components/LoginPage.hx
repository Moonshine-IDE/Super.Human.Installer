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
import feathers.controls.Check;
import feathers.controls.Label;
import feathers.controls.LayoutGroup;
import feathers.controls.TextInput;
import feathers.events.TriggerEvent;
import feathers.layout.HorizontalLayout;
import genesis.application.events.GenesisApplicationEvent;
import genesis.application.theme.GenesisApplicationTheme;
import openfl.events.Event;

class LoginPage extends Page {

    var _buttonCancel:Button;
    var _buttonGroup:LayoutGroup;
    var _buttonGroupLayout:HorizontalLayout;
    var _buttonSubmit:Button;
    var _cbSaveCredentials:Check;
    var _createAccountGroup:LayoutGroup;
    var _inputPassword:TextInput;
    var _inputUsername:TextInput;
    var _label:Label;
    var _labelAction:Label;
    var _labelInfo:Label;

    public function new() {

        super();

    }

    override function initialize() {

        super.initialize();

        this.variant = GenesisApplicationTheme.LAYOUT_GROUP_LOGIN;

        _label = new Label();
        _label.variant = GenesisApplicationTheme.LABEL_LARGE;
        _label.text = "Please Sign In";
        this.addChild( _label );

        var line = new HLine();
        line.width = 200;
        this.addChild( line );

        _inputUsername = new TextInput( "", "Username" );
        _inputUsername.width = 200;
        _inputUsername.addEventListener( Event.CHANGE, _inputChanged );
        this.addChild( _inputUsername );

        _inputPassword = new TextInput( "", "Password" );
        _inputPassword.displayAsPassword = true;
        _inputPassword.width = 200;
        _inputPassword.addEventListener( Event.CHANGE, _inputChanged );
        this.addChild( _inputPassword );

        _cbSaveCredentials = new Check( "Keep me logged in" );
        //this.addChild( _cbSaveCredentials );

        _buttonGroupLayout = new HorizontalLayout();
        _buttonGroupLayout.gap = 10;

        _buttonGroup = new LayoutGroup();
        _buttonGroup.layout = _buttonGroupLayout;
        this.addChild( _buttonGroup );

        _buttonSubmit = new Button( "Submit" );
        _buttonSubmit.enabled = false;
        _buttonSubmit.addEventListener( TriggerEvent.TRIGGER, _buttonSubmitTriggered );
        _buttonGroup.addChild( _buttonSubmit );

        _buttonCancel = new Button( "Cancel" );
        _buttonCancel.addEventListener( TriggerEvent.TRIGGER, _buttonCancelTriggered );
        _buttonGroup.addChild( _buttonCancel );

        _createAccountGroup = new LayoutGroup();
        _createAccountGroup.variant = GenesisApplicationTheme.LAYOUT_GROUP_CREATE_ACCOUNT;
        this.addChild( _createAccountGroup );

        _labelInfo = new Label( "Don't have an account yet?" );
        _createAccountGroup.addChild( _labelInfo );

        _labelAction = new Label( "Create one" );
        _labelAction.variant = GenesisApplicationTheme.LABEL_LINK;
        _createAccountGroup.addChild( _labelAction );

    }

    function _buttonCancelTriggered( e:TriggerEvent ) {

        this.dispatchEvent( new GenesisApplicationEvent( GenesisApplicationEvent.CANCEL ) );

    }

    function _buttonSubmitTriggered( e:TriggerEvent ) {

        var e = new GenesisApplicationEvent( GenesisApplicationEvent.LOGIN );
        e.username = _inputUsername.text;
        e.password = _inputPassword.text;
        this.dispatchEvent( e );

    }

    function _checkFields():Bool {

        return ( _inputUsername.text.length > 0 && _inputPassword.text.length > 0 );

    }

    function _inputChanged( e:Event ) {

        _buttonSubmit.enabled = _checkFields();

    }

}