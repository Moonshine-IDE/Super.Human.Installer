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

import feathers.controls.AssetLoader;
import feathers.controls.Button;
import feathers.controls.Label;
import feathers.controls.LayoutGroup;
import feathers.controls.TextArea;
import feathers.events.ScrollEvent;
import feathers.events.TriggerEvent;
import feathers.layout.HorizontalLayout;
import feathers.layout.HorizontalLayoutData;
import feathers.layout.VerticalAlign;
import feathers.layout.VerticalLayoutData;
import genesis.application.components.HLine;
import genesis.application.managers.LanguageManager;
import genesis.application.theme.GenesisApplicationTheme;
import openfl.events.Event;
import openfl.text.TextField;
import superhuman.events.SuperHumanApplicationEvent;
import superhuman.interfaces.IConsole;
import superhuman.theme.SuperHumanInstallerTheme;

@:styleContext
class Console extends LayoutGroup implements IConsole {

    var _clearButton:Button;
    var _closeButton:Button;
    var _copyButton:Button;
    var _hasError:Bool;
    var _hasNewMessage:Bool;
    var _i:Int = 0;
    var _textArea:ConsoleTextArea;
    var _titleLabel:Label;
    var _topGroup:LayoutGroup;

    public var hasError( get, never ):Bool;
    function get_hasError() return _hasError;

    public var hasNewMessage( get, never ):Bool;
    function get_hasNewMessage() return _hasNewMessage;

    var _title:String;
    public var title( get, set ):String;
    function get_title() return _title;
    function set_title( value:String ):String {
        if ( _title == value ) return value;
        _title = value;
        if ( _titleLabel != null ) _titleLabel.text = _title;
        return value;
    }
    
    public function new( ?text:String ) {

        super();

        _textArea = new ConsoleTextArea( text );
        _textArea.editable = false;
        
    }

    override function initialize() {

        super.initialize();

        _topGroup = new LayoutGroup();
        var l = new HorizontalLayout();
        l.verticalAlign = VerticalAlign.MIDDLE;
        l.setPadding( GenesisApplicationTheme.GRID );
        l.gap = GenesisApplicationTheme.GRID * 2;
        _topGroup.layout = l;
        _topGroup.layoutData = new VerticalLayoutData( 100 );
        this.addChild( _topGroup );

        _titleLabel = new Label( ( _title != null ) ? _title : "" );
        _titleLabel.variant = GenesisApplicationTheme.LABEL_LARGE;
        _titleLabel.layoutData = new HorizontalLayoutData( 100 );
        _topGroup.addChild( _titleLabel );

        _clearButton = new Button( LanguageManager.getInstance().getString( 'console.buttonclear' ) );
        _clearButton.icon = new AssetLoader( GenesisApplicationTheme.ICON_CLEAR );
        _clearButton.addEventListener( TriggerEvent.TRIGGER, _clearButtonTriggered );
        _topGroup.addChild( _clearButton );

        _copyButton = new Button( LanguageManager.getInstance().getString( 'console.buttoncopy' ) );
        _copyButton.icon = new AssetLoader( GenesisApplicationTheme.ICON_COPY );
        _copyButton.addEventListener( TriggerEvent.TRIGGER, _copyButtonTriggered );
        _topGroup.addChild( _copyButton );

        _closeButton = new Button( LanguageManager.getInstance().getString( 'console.buttonclose' ) );
        _closeButton.icon = new AssetLoader( GenesisApplicationTheme.ICON_CLOSE );
        _closeButton.addEventListener( TriggerEvent.TRIGGER, _closeButtonTriggered );
        _topGroup.addChild( _closeButton );

        var hl = new HLine();
        hl.layoutData = new VerticalLayoutData( 100 );
        this.addChild( hl );

        this.addChild( _textArea );

    }

    function _clearButtonTriggered( e:TriggerEvent ) {
        
        this.clear();

    }

    function _copyButtonTriggered( e:TriggerEvent ) {
        
        var evt = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.COPY_TO_CLIPBOARD );
        evt.data = _textArea.text;
        this.dispatchEvent( evt );

    }

    function _closeButtonTriggered( e:TriggerEvent ) {

        _hasError = _hasNewMessage = false;

        var evt = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.CLOSE_CONSOLE );
        evt.console = this;
        this.dispatchEvent( evt );

        this.dispatchEvent( new Event( Event.CHANGE ) );

    }

    public function appendText( text:String, isError:Bool = false ) {

        _hasNewMessage = true;
        if ( !_hasError ) _hasError = isError;

        _textArea.appendText( text, isError );
        this.dispatchEvent( new Event( Event.CHANGE ) );

    }

    public function clear() {

        _textArea.clear();

    }

}

@:styleContext
class ConsoleTextArea extends TextArea {

    var _errorColorHex:String;
    var _normalColorHex:String;
    var _scrollToBottom:Bool = true;

    public function new( ?text:String ) {

        super();

        if ( text != null ) this.text = text;

        this.addEventListener( ScrollEvent.SCROLL, _onScroll );

    }

    override function initialize() {

        super.initialize();

        this.autoHideScrollBars = false;
        _errorColorHex = StringTools.hex( SuperHumanInstallerTheme.getInstance().consoleTextErrorFormat.color, 6 );
        _normalColorHex = StringTools.hex( SuperHumanInstallerTheme.getInstance().consoleTextFormat.color, 6 );

    }

    public function appendText( text:String, isError:Bool = false ) {

        if ( isError ) {

            //this.textFieldViewPort.textField.htmlText += '<font color="#${_errorColorHex}">${text}</font>';
            this.text += text;

        } else {

            //this.textFieldViewPort.textField.htmlText += '<font color="#${_normalColorHex}">${text}</font>';
            this.text += text;

        }

    }

    override function update() {

        super.update();
        if ( _scrollToBottom ) this.scrollY = this.maxScrollY;

    }

    override function baseScrollContainer_addedToStageHandler(event:Event) {

        super.baseScrollContainer_addedToStageHandler(event);

        if ( _scrollToBottom ) this.scrollY = this.maxScrollY;

    }

    public function clear() {

        this.text = "";

    }

    function _onScroll( e:ScrollEvent ) {

        _scrollToBottom = this.scrollY == this.maxScrollY;

    }

}

typedef BufferedText = {

    isError:Bool,
    text:String,

}