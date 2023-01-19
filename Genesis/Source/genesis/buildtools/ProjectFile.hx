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

package genesis.buildtools;

import haxe.xml.Access;
import prominic.core.primitives.VersionInfo;
import sys.FileSystem;
import sys.io.File;

class ProjectFile {

    static var _content:String;

    static public function read( path:String ):ProjectFile {

        if ( !FileSystem.exists( path ) ) return null;

        var _pf = new ProjectFile();
        _pf._path = path;

        _content = File.getContent( _pf._path );
        _pf._xml = Xml.parse( _content );
        if ( _pf._xml == null ) return null;

        _pf._access = new Access( _pf._xml );
        _pf._getVersion();

        return _pf;

    }

    var _access:Access;
    var _path:String;
    var _version:VersionInfo;
    var _xml:Xml;

    public var version( get, never ):VersionInfo;
    function get_version() return _version;
    
    function new() { }

    public function bumpVersion():Bool {

        if ( _version == null ) return false;

        _version++;

        var _metas = _access.node.project.nodes.meta;
        
        for ( m in _metas ) {

            if ( m.has.version ) m.att.version = _version.toString();

        }

        return true;

    }

    public function save( path:String ) {

        var s = _access.get_x().toString();
        s = StringTools.replace( s, "&#039;", "'" );
        File.saveContent( path, s );

    }

    function _getVersion() {

        var _metas = _access.node.project.nodes.meta;

        for ( m in _metas ) {

            if ( m.has.version ) _version = m.att.version;

        }

    }

}