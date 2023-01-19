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

import prominic.core.primitives.VersionInfo;
import sys.FileSystem;

class MacTools {

    static public function createInstaller( options:MacInstallerOptions ):Bool {

        Sys.println( 'Creating macOS installer v${options.versionInfo}' );

        FileSystem.createDirectory( options.outputPath );
        var args:Array<String> = [];
        args.push( "--version" );
        args.push( options.versionInfo.toString() );
        args.push( "--product" );
        args.push( options.pkgprojTemplatePath );
        args.push( "--identifier" );
        args.push( options.appId );
        args.push( "--component" );
        args.push( options.appPath );
        args.push( "/Applications" );
        args.push( './${options.outputPath}/${options.appName}.pkg' );
        var i = Sys.command( 'productbuild', args );
        
        if ( i == 0 ) {

            Sys.println( 'macOS installer created at ${options.outputPath}/${options.appName}.pkg' );

        } else {

            Sys.println( 'macOS installer creation failed' );

        }

        return i == 0;

    }
    
}

typedef MacInstallerOptions = {

    appId:String,
    appName:String,
    appPath:String,
    outputPath:String,
    pkgprojTemplatePath:String,
    versionInfo:VersionInfo,

}