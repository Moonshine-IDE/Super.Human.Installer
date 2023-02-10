package prominic.core.primitives;

class Wrapped<T> {

    static public inline function wrap<T>( object:T ):Wrapped<T> {

        return new Wrapped( object );

    }

    var _value:T;

    public var value( get, never ):T;
    function get_value() return _value;

    public function new( value:T ) {

        this._value = value;

    }

}