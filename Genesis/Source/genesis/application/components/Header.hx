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

import feathers.controls.AssetLoader;
import feathers.controls.Button;
import feathers.controls.Label;
import feathers.controls.LayoutGroup;
import feathers.events.TriggerEvent;
import feathers.layout.HorizontalLayoutData;
import genesis.application.events.GenesisApplicationEvent;
import genesis.application.managers.LanguageManager;
import genesis.application.theme.GenesisApplicationTheme;

class Header extends LayoutGroup {

    var _label:Label;
    var _logoLoader:AdvancedAssetLoader;
    var _mainMenu:MainMenu;
    var _spacer:LayoutGroup;
    var _updateButton:Button;

    public var text( get, set ):String;
    var _text:String;
    function get_text():String return _text;
    function set_text( value:String ):String {
        _text = value;
        if ( _label != null ) _label.text = _text;
        return _text;
    }

    public var logo( get, set ):String;
    var _logo:String;
    function get_logo():String return _logo;
    function set_logo( value:String ):String {
        if ( value == _logo ) return value;
        _logo = value;
        if ( _logoLoader != null ) _logoLoader.source = _logo;
        return _logo;
    }

    public var menuEnabled( never, set ):Bool;
    function set_menuEnabled( value:Bool ):Bool {
        if ( _mainMenu != null ) {
            _mainMenu.enabled = value;
            _mainMenu.alpha = ( value ) ? 1 : .5;
            _updateButton.enabled = value;
            return _mainMenu.enabled;
        }
        return false;
    }

    public var updateButtonEnabled( never, set ):Bool;
    function set_updateButtonEnabled( value:Bool ):Bool {
        if ( _updateButton != null ) {
            _updateButton.enabled = value;
            return _updateButton.enabled;
        }
        return false;
    }

    public function new() {

        super();

        this.variant = GenesisApplicationTheme.LAYOUT_GROUP_HEADER;

        _logoLoader = new AdvancedAssetLoader( ( _logo != null ) ? _logo : null );
        _logoLoader.layoutData = HorizontalLayoutData.fillVertical();
        this.addChild( _logoLoader );

        _label = new Label();
        _label.variant = GenesisApplicationTheme.LABEL_TITLE;
        _label.text = ( _text != null ) ? _text : "";
        this.addChild( _label );

        _mainMenu = new MainMenu();
        _mainMenu.addEventListener( GenesisApplicationEvent.MENU_SELECTED, _menuSelected );
        this.addChild( _mainMenu );

        _spacer = new LayoutGroup();
        _spacer.layoutData = new HorizontalLayoutData( 100, 100 );
        this.addChild( _spacer );

        _updateButton = new Button( LanguageManager.getInstance().getString( 'mainmenu.updateavailable' ) );
        _updateButton.variant = GenesisApplicationTheme.BUTTON_HIGHLIGHT;
        _updateButton.includeInLayout = _updateButton.visible = false;
        _updateButton.addEventListener( TriggerEvent.TRIGGER, _updateButtonTriggered );
        this.addChild( _updateButton );

    }

    public function addMenuItem( label:String, pageId:String, ?index:Int ) {

        _mainMenu.addMenuItem( label, pageId, index );

    }

    public function updateFound() {

        _updateButton.includeInLayout = _updateButton.visible = true;

    }

    function _menuSelected( e:GenesisApplicationEvent ) {

        this.dispatchEvent( e );

    }

    function _updateButtonTriggered( e:TriggerEvent ) {

        this.dispatchEvent( new GenesisApplicationEvent( GenesisApplicationEvent.INIT_UPDATE ) );

    }

}