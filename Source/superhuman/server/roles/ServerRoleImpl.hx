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

package superhuman.server.roles;

import superhuman.server.data.ProvisionerRoleData;

class ServerRoleImpl {

    var _description:String;
    var _fileHint:String;
    var _fixpackHashes:Array<String>;
    var _hotfixHashes:Array<String>;
    var _installerHashes:Array<String>;
    var _name:String;
    var _role:ProvisionerRoleData;

    public var description( get, never ):String;
    function get_description() return _description;

    public var fileHint( get, never ):String;
    function get_fileHint() return _fileHint;
    
    public var name( get, never ):String;
    function get_name() return _name;
    
    public var role( get, set ):ProvisionerRoleData;
    function get_role() return _role;
    function set_role( value:ProvisionerRoleData ):ProvisionerRoleData {
        _role = value;
        return value;
    }
    
    public function new( name:String, description:String, role:ProvisionerRoleData, ?installerHashes:Array<String>, ?hotfixHashes:Array<String>, ?fixpackHashes:Array<String>, ?fileHint:String ) {

        _name = name;
        _description = description;
        _role = role;

        _installerHashes = installerHashes;
        _hotfixHashes = hotfixHashes;
        _fixpackHashes = fixpackHashes;
        _fileHint = fileHint;

    }

}