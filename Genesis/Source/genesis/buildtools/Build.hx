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

class Build {

    static final PROJECT_FILE:String = 'project.xml';
    
    public static function main() {

        Sys.println( 'Super.Human.Installer - Clean and Build App (Native/C++)' );
        Sys.println( '' );

        Sys.setCwd( '..' );

        var _platform = '';

        #if bump

        var _projectFile = ProjectFile.read( PROJECT_FILE );

        if ( _projectFile != null ) {

            var v = _projectFile.version;
            _projectFile.bumpVersion();
            Sys.println( 'Bumping version: ${v} -> ${_projectFile.version}' );
            _projectFile.save( PROJECT_FILE );

        }
        
        #end

        switch Sys.systemName().toLowerCase() {

            case "mac":
                _platform = "mac";

            case "windows":
                _platform = "windows";

            case "linux":
                _platform = "linux";

            default:

        }

        #if debug
        var _debug = '-debug -Dlogverbose -Dlogcolor -Denableupdater';
        #else
        var _debug = '-Denableupdater';
        #end

        Sys.command( 'haxelib run openfl build ${PROJECT_FILE} ${_platform} -clean ${_debug}' );

    }

}