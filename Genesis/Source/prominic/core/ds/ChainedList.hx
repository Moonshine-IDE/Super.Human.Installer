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

package prominic.core.ds;

class ChainedList<T, V> {

    var _list:List<T>;
    var _ret:V;

    public var length( get, never ):Int;
    function get_length() return _list.length;
    
    public function new( result:V ) {

        _list = new List();
        _ret = result;

    }

    public function add( item:T ):V {

        _list.add( item );
        return _ret;

    }

    public function clear():V {

        _list.clear();
        return _ret;

    }

    public function filter( f:T -> Bool ) {

        var cl = new ChainedList( _ret );
        cl._list = _list.filter( f );
        return cl;

    }

    public function first() {

        return _list.first();

    }

    public function isEmpty() {

        return _list.isEmpty();

    }

    public function iterator() {

        return _list.iterator();

    }

    public function join( sep:String ) {

        return _list.join( sep );

    }

    inline public function keyValueIterator() {

        return _list.keyValueIterator();

    }

    public function last() {

        return _list.last();

    }

    public function map<X>( f:T -> X ) {

        var cl = new ChainedList( _ret );
        cl._list = _list.map( f );
        return cl;

    }

    public function pop():V {

        _list.pop();
        return _ret;

    }

    public function push( item:T ):V {

        _list.push( item );
        return _ret;

    }

    public function remove( item:T ):V {

        _list.remove( item );
        return _ret;

    }

    public function toString() {

        return _list.toString();

    }

}

