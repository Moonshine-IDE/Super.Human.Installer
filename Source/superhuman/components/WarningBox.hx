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

package superhuman.components;

import feathers.controls.Button;
import feathers.controls.Label;
import feathers.controls.LayoutGroup;
import feathers.events.TriggerEvent;
import feathers.layout.HorizontalLayoutData;
import feathers.layout.VerticalLayout;
import genesis.application.theme.GenesisApplicationTheme;

@:styleContext
class WarningBox extends LayoutGroup {

    var _button:Button;
    var _contentGroup:LayoutGroup;
    var _labelText:Label;
    var _labelTitle:Label;

    public var title( get, set ):String;
    var _title:String;
    function get_title() return _title;
    function set_title( value:String ):String {
        if ( _title == value ) return value;
        _title = value;
        if ( _labelTitle != null ) _labelTitle.text = _title;
        return value;
    }
    
    public var text( get, set ):String;
    var _text:String;
    function get_text() return _text;
    function set_text( value:String ):String {
        if ( _text == value ) return value;
        _text = value;
        if ( _labelText != null ) _labelText.text = _text;
        return value;
    }
    
    public var action( get, set ):String;
    var _action:String;
    function get_action() return _action;
    function set_action( value:String ):String {
        if ( _action == value ) return value;
        _action = value;
        if ( _button != null ) _button.text = _action;
        return value;
    }
    
    public function new() {

        super();

    }

    override function initialize() {

        super.initialize();

        _contentGroup = new LayoutGroup();
        _contentGroup.layoutData = new HorizontalLayoutData( 100 );
        _contentGroup.layout = new VerticalLayout();
        this.addChild( _contentGroup );

        _labelTitle = new Label();
        if ( _title != null ) _labelTitle.text = _title;
        _contentGroup.addChild( _labelTitle );

        _labelText = new Label();
        _labelText.variant = GenesisApplicationTheme.LABEL_COPYRIGHT;
        if ( _text != null ) _labelText.text = _text;
        _contentGroup.addChild( _labelText );

        _button = new Button();
        _button.variant = GenesisApplicationTheme.BUTTON_WARNING;
        _button.layoutData = new HorizontalLayoutData();
        if ( _action != null ) _button.text = _action;
        _button.addEventListener( TriggerEvent.TRIGGER, _buttonTriggered );
        this.addChild( _button );

    }

    function _buttonTriggered( e:TriggerEvent ) {

        this.dispatchEvent( e );

    }

}