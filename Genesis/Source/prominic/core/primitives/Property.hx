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

import haxe.Serializer;
import haxe.Unserializer;
import prominic.core.interfaces.IDisposable;
import prominic.core.interfaces.ISerializable;

/**
 * A typed property that holds a value.
 */
class Property<T> implements IDisposable implements ISerializable {

    //
    // Private vars
    //

    private var _alwaysCallOnChange:Bool = false;
    private var _disposed:Bool = false;
    private var _onChange:List<(Property<T>)->Void>;
    private var _value:T;

    //
    // Public vars
    //

    /**
     * If true, value cannot be changed
     */
    public var locked:Bool = false;

    /**
     * List of functions that will be called if the property changes.
     */
    public var onChange( get, null ):List<(Property<T>)->Void>;

    /**
     * The value of *this* property.
     */
    public var value( get, set ):T;

    //
    // Getters, Setters
    //

    private function get_onChange() return _onChange;
    private function get_value():T return _value;
    private function set_value( v:T ):T { if ( locked ) return value; if ( !_alwaysCallOnChange && _value == v ) return value; _value = v; for ( f in _onChange ) f( this ); return _value; }

    public function new( ?defaultValue:T, ?alwaysCallOnChange:Bool = false ) {

        _value = defaultValue;
        _alwaysCallOnChange = alwaysCallOnChange;
        _onChange = new List<(Property<T>)->Void>();
        
    }

    /**
     * Clone the Property
     */
    public function clone():Property<T> {

        var p = new Property<T>();
        p._value = this._value;
        return p;

    }

    /**
     * Dispose the Property
     */
    public function dispose() {

        if ( _disposed ) return;

        _onChange.clear();
        _onChange = null;

        _disposed = true;

    }

    /**
     * Returns the string representation of the Property in Haxe serialized format.
     * @param properties If null, all properties are returned
     * @return String
     */

    public function getState( properties:Array<String> = null ):String {

        var s:String = Serializer.run( this );
        return s;

    }

    @:noCompletion public function hxSerialize( s:Serializer ) {

        s.useCache = true;
        s.serialize( this.value );

    }

    @:noCompletion public function hxUnserialize( u:Unserializer ) {

        this._value = u.unserialize();
        _onChange = new List<(Property<T>)->Void>();

    }

    function toString():String {

        return 'Property: ' + Std.string( value );

    }

}