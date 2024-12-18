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

import openfl.display.DisplayObject;
import feathers.controls.Label;
import feathers.controls.LayoutGroup;
import feathers.core.FeathersControl;
import feathers.layout.HorizontalLayoutData;
import prominic.core.interfaces.IValidator;

@:styleContext
class GenesisForm extends LayoutGroup implements IValidator {

    public function new() {
        
        super();

    }

    public function isValid():Bool {

        var isValid = true;

        for ( i in 0...this.numChildren ) {

            var c = this.getChildAt( i );

            if ( c != null && Std.isOfType( c, IValidator ) ) {

                if ( !cast( c, IValidator ).isValid() ) isValid = false;

            }

        }

        return isValid;

    }

}

@:styleContext
class GenesisFormRow extends LayoutGroup implements IValidator {

    var _label:Label;

    var _text:String;
    public var text( get, set ):String;
    function get_text() return _text;
    function set_text( value:String ):String {
        if ( _text == value ) return value;
        _text = value;
        if ( _label != null ) _label.text = _text;
        return value;
    }

    var _content:GenesisFormRowContent;
    public var content( get, set ):GenesisFormRowContent;
    function get_content() return _content;
    function set_content( value:GenesisFormRowContent ):GenesisFormRowContent {
        if ( _content == value ) return value;
        _content = value;
        return value;
    }

    public function new() {
        
        super();

        _label = new Label();
        _label.layoutData = new HorizontalLayoutData( 40 );
        this.addChild( _label );

        _content = new GenesisFormRowContent();
        _content.layoutData = new HorizontalLayoutData( 60 );
        this.addChild( _content );

    }

    public function isValid():Bool {

        var v = true;

        for ( i in 0..._content.numChildren ) {

            var c = _content.getChildAt( i );
            if ( c != null && Std.isOfType( c, IValidator ) && !cast( c, IValidator ).isValid() ) v = false;

        }

        return v;

    }

}

@:styleContext
class GenesisFormRowContent extends LayoutGroup {

    public function new() {

        super();

    }

    override function addChildAt( child:DisplayObject, index:Int ):DisplayObject {

        var fc = cast( child, FeathersControl );

        if ( fc != null ) {

            fc.layoutData = new HorizontalLayoutData( 100 );

        }

        return super.addChildAt( child, index );

    }

}