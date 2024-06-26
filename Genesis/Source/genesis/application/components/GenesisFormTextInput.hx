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

import feathers.controls.TextInput;
import genesis.application.interfaces.IGenesisFormValidatedItem;
import genesis.application.theme.GenesisApplicationTheme;
import openfl.events.Event;

@:styleContext
class GenesisFormTextInput extends TextInput implements IGenesisFormValidatedItem {

    var _isEmptyValid:Bool;

    public var minLength:Int = 0;
    public var validationKey:EReg;

    public function new( text:String = "", ?prompt:String, ?validationKey:EReg, ?isEmptyValid:Bool ) {

        super( text, prompt, textField_changeHandler);

        this.validationKey = validationKey;
        this._isEmptyValid = isEmptyValid;

    }

    public function isValid():Bool {

        var t = StringTools.trim( this.text );

        if ( _isEmptyValid && ( t == null || t == "" ) ) return true;
        if ( !_isEmptyValid && ( t == null && t == "" ) ) return false;

        if ( validationKey == null && t.length >= minLength ) return true;
        var v = ( validationKey != null && validationKey.match( t ) && t.length >= minLength );
        this.variant = ( v ) ? null : GenesisApplicationTheme.INVALID;
        return v;

    }

    public function textField_changeHandler(event:Event) {

        if ( this.variant != null ) this.variant = null;

    }

}