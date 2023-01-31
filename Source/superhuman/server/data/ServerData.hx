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

package superhuman.server.data;

import superhuman.server.data.RoleData;
import superhuman.server.provisioners.ProvisionerDefinition.ProvisionerData;

typedef ServerData = {
    
    type:String,
    
    user_email:String,
    ?user_safeid:Null<String>,

    ?server_organization:String,
    server_id:Int,
    server_hostname:String,

    ?dhcp4:Bool,
    ?dhcp6:Bool,
    ?network_bridge:String,
    network_dns_nameserver_1:String,
    network_dns_nameserver_2:String,
    network_address:String,
    network_netmask:String,
    network_gateway:String,

    env_open_browser:Bool,
    env_setup_wait:Int,

    resources_cpu:Int,
    resources_ram:Float,

    roles:Array<RoleData>,

    ?vagrant_up_successful:Bool,

    ?provisioner:ProvisionerData,

}