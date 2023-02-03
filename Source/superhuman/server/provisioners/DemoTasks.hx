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

package superhuman.server.provisioners;

import genesis.application.managers.LanguageManager;
import haxe.Exception;
import haxe.io.Path;
import lime.system.System;
import prominic.core.primitives.VersionInfo;
import prominic.logging.Logger;
import prominic.sys.io.FileTools;
import superhuman.managers.ProvisionerManager;
import superhuman.server.data.RoleData;
import superhuman.server.data.ServerData;
import superhuman.server.provisioners.ProvisionerType;
import sys.FileSystem;
import sys.io.File;

using prominic.tools.ObjectTools;

class DemoTasks extends AbstractProvisioner {

    static final _IP_ADDRESS_PATTERN:EReg = ~/^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/;
    static final _SAFE_ID_FILE:String = "safe.ids";
    static final _SAFE_ID_LOCATION:String = "safe-id-to-cross-certify";
    static final _VERSION_PATTERN:EReg = ~/(\d{1,3}\.\d{1,3}\.\d{1,3})/;
    static final _WEB_ADDRESS_PATTERN:EReg = ~/^(?:https:\/\/)(.*)(?::\d{3})(?:\/.*)$/gm;

    static public final HOSTS_FILE:String = "Hosts.yml";
    static public final HOSTS_TEMPLATE_FILE:String = "Hosts.template.yml";
    static public final PROVISIONER_TYPE:ProvisionerType = ProvisionerType.DemoTasks;
    static public final WEB_ADDRESS_FILE:String = ".vagrant/done.txt";

    static public function getDefaultProvisionerRoles():Map<String, RoleData> {

        return [

            "domino" => { value: "domino", enabled: true, files: { hotfixes: [], fixpacks: [] }, isdefault: true },
            "appdevpack" => { value: "appdevpack", enabled: false, files: {} },
            "nomadweb" => { value: "nomadweb", enabled: false, files: {} },
            "leap" => { value: "leap", enabled: false, files: {} },
            "traveler" => { value: "traveler", enabled: false, files: {} },
            "verse" => { value: "verse", enabled: false, files: {} },
            "domino-rest-api" => { value: "domino-rest-api", enabled: false, files: {} },

        ];

    }

    static public function getDefaultServerData( id:Int ):ServerData {

        return {

			env_open_browser: true,
			env_setup_wait: 300,

			//network_address: "192.168.2.227",
			//network_dns_nameserver_1: "1.1.1.1",
			//network_dns_nameserver_2: "1.0.0.1",
			//network_gateway: "192.168.2.1",
			//network_netmask: "255.255.255.0",

			dhcp4: true,
			network_address: "",
			network_dns_nameserver_1: "1.1.1.1",
			network_dns_nameserver_2: "1.0.0.1",
			network_gateway: "",
			network_netmask: "",

			network_bridge: "",
			resources_cpu: 2,
			resources_ram: 4.0,
			roles: [ for ( r in getDefaultProvisionerRoles().keyValueIterator() ) r.value ],
			server_hostname: "",
			server_id: id,
			server_organization: "",
			type: ServerType.Domino,
			user_email: "",
            provisioner: ProvisionerManager.getBundledProvisioners()[ 0 ].data,

		};

    }

    static public function getRandomServerId( serverDirectory:String ):Int {

		// Range: 1025 - 9999
		var r = Math.floor( Math.random() * 8974 ) + 1025;

		if ( FileSystem.exists( '${serverDirectory}${PROVISIONER_TYPE}/${r}' ) ) return getRandomServerId( serverDirectory );

		return r;

	}

    static public function getVersionFromFile( path:String ):VersionInfo {

        var v:VersionInfo = "0.0.0";

        try {

            var c = File.getContent( path );
            var m = _VERSION_PATTERN.match( c );
            if ( m )
                v = _VERSION_PATTERN.matched( 0 )
            else
                v = "0.0.0";

        } catch( e ) {

            v = "0.0.0";

        }

        return v;

    }

    public var hostFileExists( get, never ):Bool;
    function get_hostFileExists() return this.fileExists( HOSTS_FILE );

    public var provisioned( get, never ):Bool;
    function get_provisioned() return _webAddressFileExists();

    public var safeIdExists( get, never ):Bool;
    function get_safeIdExists() return this.fileExists( Path.addTrailingSlash( _SAFE_ID_LOCATION ) + _SAFE_ID_FILE );

    public var webAddress( get, never ):String;
    function get_webAddress() return _getWebAddress();
    
    public function new( sourcePath:String, targetPath:String ) {

        super( superhuman.server.provisioners.ProvisionerType.DemoTasks, sourcePath, targetPath );

        _versionFile = "version.rb";
        _version = getVersionFromFile( Path.addTrailingSlash( _targetPath ) + _versionFile );

        if ( _version == "0.0.0" && _sourcePath != null ) _version = getVersionFromFile( Path.addTrailingSlash( _sourcePath ) + AbstractProvisioner._SCRIPTS_ROOT + _versionFile );

    }

    public function copyInstallers( pathPairs:Array<PathPair>, callback:()->Void ) {

        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.copyinstallers', _targetPath ) );
        FileTools.batchCopy( pathPairs, FileOverwriteRule.IfSizeDifferent, callback, _fileCopied );

    }

    public function deleteWebAddressFile() {

        this.deleteFileInTargetDirectory( WEB_ADDRESS_FILE );

    }

    public function openWelcomePage() {

        System.openURL( _getWebAddress() );

    }

    public override function reinitialize( sourcePath:String ) {

        super.reinitialize( sourcePath );

        _version = getVersionFromFile( Path.addTrailingSlash( _targetPath ) + _versionFile );
        if ( _version == "0.0.0" ) _version = getVersionFromFile( Path.addTrailingSlash( _sourcePath ) + AbstractProvisioner._SCRIPTS_ROOT + _versionFile );

    }

    public function saveSafeId( safeIdPath:String ):Bool {

        createTargetDirectory();

        if ( FileSystem.exists( safeIdPath ) ) {

            var safeIdDir = Path.addTrailingSlash( _targetPath ) + Path.addTrailingSlash( _SAFE_ID_LOCATION );
            FileSystem.createDirectory( safeIdDir );

            try {

                File.copy( safeIdPath, safeIdDir + _SAFE_ID_FILE );
                if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.copysafeid', safeIdPath, safeIdDir + _SAFE_ID_FILE ) );
                return true;

            } catch ( e:Exception ) {

                Logger.error( 'Notes Safe ID at ${safeIdPath} cannot be copied to ${safeIdDir + _SAFE_ID_FILE}. Details: ${e.details()} Message: ${e.message}' );
                if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.copysafeidfailed', '${e.details()} Message: ${e.message}' ), true );

            }

        } else {

            Logger.error( 'Notes Safe ID does not exist at ${safeIdPath}' );
            if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.safeidnonexistent', safeIdPath ), true );

        }

        return false;

    }

    function _fileCopied( pathPair:PathPair, canCopy:Bool ) {

        if ( console != null ) {

            if ( canCopy ) {

                console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.copyinstaller', pathPair.source, pathPair.destination ) );

            } else {

                console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.installerexists', Path.withoutDirectory( pathPair.source ) ) );

            }

        }

    }

    function _webAddressFileExists():Bool {

        var e = FileSystem.exists( Path.addTrailingSlash( _targetPath ) + WEB_ADDRESS_FILE );

        if ( !e ) {

            Logger.error( 'File at ${Path.addTrailingSlash( _targetPath ) + WEB_ADDRESS_FILE} doesn\'t exist' );
            return false;

        }

        return true;

    }

    function _getWebAddress():String {

        if ( !_webAddressFileExists() ) return null;

        try {

            var c = File.getContent( Path.addTrailingSlash( _targetPath ) + WEB_ADDRESS_FILE );
            if ( c == null || c.length == 0 ) return null;

            if ( _WEB_ADDRESS_PATTERN.match( c ) ) return _WEB_ADDRESS_PATTERN.matched( 0 );

        } catch( e ) {}

        return null;

    }

    function _saveHostsFile( content:String ) {

        createTargetDirectory();

        if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.hostsfilecontent', content ) );

        try {

            File.saveContent( Path.addTrailingSlash( _targetPath ) + HOSTS_FILE, content );
            Logger.debug( 'Server configuration file created at ${Path.addTrailingSlash( _targetPath ) + HOSTS_FILE}' );
            if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.savehostsfile', Path.addTrailingSlash( _targetPath ) + HOSTS_FILE ) );

        } catch ( e:Exception ) {

            Logger.error( 'Server configuration file cannot be created at ${Path.addTrailingSlash( _targetPath ) + HOSTS_FILE}. Details: ${e.details()} Message: ${e.message}' );
            if ( console != null ) console.appendText( LanguageManager.getInstance().getString( 'serverpage.server.console.savehostsfileerror', Path.addTrailingSlash( _targetPath ) + HOSTS_FILE, '${e.details()} Message: ${e.message}' ), true );
            return;

        }

    }

}