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

import genesis.buildtools.MacTools.MacInstallerOptions;
import haxe.Template;
import haxe.xml.Access;
import prominic.core.primitives.VersionInfo;
import sys.io.File;

class Distribution {

    static var _appId:String;
    static var _projectXml:Access;
    static var _versionInfo:VersionInfo;

    public static function main() {
        
        Sys.println( 'Super.Human.Installer Distribution' );
        Sys.println( '' );

        var s = File.getContent( '../project.xml' );
        _projectXml = new Access( Xml.parse( s ) );

        var _metas = _projectXml.node.project.nodes.meta;
        for ( m in _metas ) {
            if ( m.has.version ) _versionInfo = m.att.version;
        }
        
        switch Sys.systemName().toLowerCase() {

            case "mac":
                var o:MacInstallerOptions = {

                    #if debug
                    appId: "net.prominic.genesis.superhumaninstallerdev",
                    appPath: "../Export/Development/macos/bin/SuperHumanInstallerDev.app",
                    appName: "SuperHumanInstallerDev",
                    #else
                    appId: "net.prominic.genesis.superhumaninstaller",
                    appPath: "../Export/Production/macos/bin/SuperHumanInstaller.app",
                    appName: "SuperHumanInstaller",
                    #end
                    outputPath: "../Dist/macos",
                    pkgprojTemplatePath: "../Templates/installer/SuperHumanInstaller.template.plist",
                    versionInfo: _versionInfo,

                };

                if ( MacTools.createInstaller( o ) ) _updateXML();

            case "windows":

            case "linux":

            default:

        }

    }

    static function _updateXML() {

        #if debug
        var _xml:String = "updater-dev.xml";
        #else
        var _xml:String = "updater.xml";
        #end
        var _fn:String = "updater.template.xml";
        var _templateFilePath:String = '../Templates/updater/${_fn}';
        var _content = File.getContent( _templateFilePath );
        var _template = new Template( _content );

        var replace = {

            APP_VERSION: _versionInfo.toString(),
            #if debug
            MAC_INSTALLER_URL: 'https://static.moonshine-ide.com/downloads/superhumaninstaller/macos/SuperHumanInstallerDev.pkg',
            WIN_INSTALLER_URL: 'https://static.moonshine-ide.com/downloads/superhumaninstaller/windows/SuperHumanInstallerDev.exe',
            #else
            MAC_INSTALLER_URL: 'https://static.moonshine-ide.com/downloads/superhumaninstaller/macos/SuperHumanInstaller.pkg',
            WIN_INSTALLER_URL: 'https://static.moonshine-ide.com/downloads/superhumaninstaller/windows/SuperHumanInstaller.exe',
            #end

        }

        var result = _template.execute( replace );
        var _xmlFilePath:String = '../Dist/${_xml}';
        File.saveContent( _xmlFilePath, result );

        Sys.println( 'Xml saved at ${_xmlFilePath}' );

    }

}