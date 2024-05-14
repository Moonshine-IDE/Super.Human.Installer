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

package superhuman.managers;

import champaign.core.primitives.VersionInfo;
import feathers.data.ArrayCollection;
import haxe.io.Path;
import lime.system.System;
import superhuman.server.definitions.ProvisionerDefinition;
import superhuman.server.provisioners.ProvisionerType;

class ProvisionerManager {

    static final PROVISIONER_DEMO_TASKS_LOCAL_PATH:String = "assets/provisioners/demo-tasks/";
    
    static public function getBundledProvisioners():Array<ProvisionerDefinition> {
        
        // Generate array of available provisioners, newest always at the top
        return [
            // Demo-tasks v0.1.18 has been disabled because of current bugs on Windows
            /*
            {
                name: "Demo-tasks v0.1.18",
                data: { type: ProvisionerType.DemoTasks, version: VersionInfo.fromString( "0.1.18" ) },
                root: Path.addTrailingSlash( System.applicationDirectory ) + PROVISIONER_DEMO_TASKS_LOCAL_PATH + "0.1.18"
            },
            */
            {
                name: "Demo-tasks v0.1.22",
                data: { type: ProvisionerType.DemoTasks, version: VersionInfo.fromString( "0.1.22" ) },
                root: Path.addTrailingSlash( System.applicationDirectory ) + PROVISIONER_DEMO_TASKS_LOCAL_PATH + "0.1.22"
            },
            {
                name: "Demo-tasks v0.1.20",
                data: { type: ProvisionerType.DemoTasks, version: VersionInfo.fromString( "0.1.20" ) },
                root: Path.addTrailingSlash( System.applicationDirectory ) + PROVISIONER_DEMO_TASKS_LOCAL_PATH + "0.1.20"
            }
        ];

    }

    static public function getBundledProvisionerCollection( ?type:ProvisionerType ):ArrayCollection<ProvisionerDefinition> {

        var a = getBundledProvisioners();

        if ( type == null ) return new ArrayCollection( a );

        var c = new ArrayCollection<ProvisionerDefinition>();
        for ( p in a ) if ( p.data.type == type ) c.add( p );
        return c;

    }

    static public function getProvisionerDefinition( type:ProvisionerType, version:VersionInfo ):ProvisionerDefinition {

        for ( provisioner in getBundledProvisionerCollection() ) {

			if ( provisioner.data.type == type && provisioner.data.version == version ) return provisioner;

		}

		return null;

    }

}