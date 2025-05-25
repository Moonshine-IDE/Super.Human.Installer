package prominic.helpers;

import haxe.ds.StringMap;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;

class PListUtil {

    static public function readFromFile( path:String ):PList {

        if ( !FileSystem.exists( path ) ) return null;

        var result:PList = null;

        try {

            var c = File.getContent( path );
            result = PListUtil.parse( c );

        } catch ( e ) {}

        if ( result == null ) {

            // Try to convert the file to XML format
            var p = new Process( 'plutil -convert xml1 ${path} -o -' );
            var e = p.exitCode();

            if ( e == 0 ) {

                try {

                    var c = p.stdout.readAll().toString();
                    result = PListUtil.parse( c );

                } catch ( e ) {}

            }

        }

        return result;

    }
    
    static public function parse( data:String ):PList {

        final plist = new PList();

        try {

            var xml = new XmlNodeAccess( Xml.parse( data ) );

            if ( xml.hasNode.plist && xml.node.plist.has.version ) {

                plist.version = xml.node.plist.att.version;

                var i = xml.node.plist.elements;

                while ( true ) {

                    var e = i.next();

                    if ( e != null ) {

                        if ( e.name.toLowerCase() == "dict" ) plist._dict = _parseDict( e );

                    }

                    if ( !i.hasNext() ) break;

                }

            }

        } catch ( e ) {

            return null;

        }

        return plist;

    }

    static function _parseArray( xml:XmlNodeAccess ):Array<PListEntry<Any>> {

        var a:Array<PListEntry<Any>> = [];
        var i = xml.elements;

        while ( true ) {

            var e = i.next();

            if ( e.name.toLowerCase() == "array" ) {

                var aa = _parseArray( e );
                a.push( new PListEntry( aa ) );

            }

            if ( e.name.toLowerCase() == "string" ) a.push( new PListEntry( e.innerData ) );

            if ( e.name.toLowerCase() == "dict" ) {

                var d = _parseDict( e );
                a.push( new PListEntry( d ) );

            }

            if ( !i.hasNext() ) break;

        }

        return a;

    }

    static function _parseDict( xml:XmlNodeAccess ):Dict {

        var dict = new Dict();
        var i = xml.elements;

        while ( true ) {

            var key = i.next();

            if ( key != null ) {

                var value = i.next();

                if ( value != null ) {

                    if ( value.name.toLowerCase() == "string" ) dict.set( key.innerData, new PListEntry( value.innerData ) );
                    if ( value.name.toLowerCase() == "true" ) dict.set( key.innerData, new PListEntry( true ) );
                    if ( value.name.toLowerCase() == "false" ) dict.set( key.innerData, new PListEntry( false ) );
                    if ( value.name.toLowerCase() == "dict" ) dict.set( key.innerData, new PListEntry( _parseDict( value ) ) );

                    if ( value.name.toLowerCase() == "array" ) {

                        var a = _parseArray( value );
                        dict.set( key.innerData, new PListEntry( a ) );

                    }

                }

            }

            if ( !i.hasNext() ) break;

        }

        return dict;

    }

}

@:allow( prominic.helpers.PListUtil )
class PList {

    var _dict:Dict;

    public var version:String;

    function new() {

        _dict = new Dict();

    }

    public function exist( entryId:PListEntryId ):Bool {

        return _dict.exists( entryId );

    }

    public function get( entryId:PListEntryId ):PListEntry<Any> {

        return _dict.get( cast entryId );

    }

    public function getValue<T>( entryId:PListEntryId ):T {

        return cast _dict.get( cast entryId ).value;

    }

    public function toString() {

        return Std.string( _dict );

    }

}

@:allow( prominic.helpers.PListUtil )
class PListEntry<T> {

    var _value:T;

    public var value( get, never ):T;
    function get_value() return _value;

    public function new( value:T ) {

        _value = value;

    }

    public function toString() {

        return Std.string( _value );

    }

}

enum abstract PListEntryId( String ) to String {

    var CFBundleExecutable;
    var CFBundleShortVersionString;

}

@:forward( exists, get, set )
abstract Dict( StringMap<PListEntry<Any>> ) {

    public inline function new() {

        this = new StringMap();

    }

}
