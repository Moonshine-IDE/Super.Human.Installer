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

package prominic.core.primitives;

import champaign.core.primitives.Property;

class ValidatingProperty extends Property<String> {

    var _isEmptyValid:Bool;
    var _minLength:Int;
    var _validationKey:EReg;

    public var validationKey( get, never ):EReg;
    function get_validationKey() return _validationKey;
    
    public function new( ?defaultValue:String, ?validationKey:EReg, ?isEmptyValid:Bool, ?minLength:Int = 0 ) {

        super( defaultValue );

        _validationKey = validationKey;
        _isEmptyValid = isEmptyValid;
        _minLength = minLength;

    }

    override function clone():ValidatingProperty {

        var p:ValidatingProperty = cast super.clone();
        p._isEmptyValid = this._isEmptyValid;
        p._minLength = this._minLength;
        p._validationKey = this._validationKey;
        return p;

    }

    public function isValid():Bool {

        if ( _isEmptyValid && ( this.value == null || this.value == "" ) ) return true;
        if ( !_isEmptyValid && ( this.value == null || this.value == "" ) ) return false;

        var v = this.value.length >= _minLength;
        if ( _validationKey != null ) v = v && _validationKey.match( this.value );

        return v;

    }

}