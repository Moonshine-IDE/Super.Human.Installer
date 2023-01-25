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

package superhuman.config;

import prominic.core.primitives.VersionInfo;

class SuperHumanGlobals {
    
    // Check Vagrant status for servers if app receives focus
    static public final CHECK_VAGRANT_STATUS_ON_FOCUS:Bool = false;

    // Maximum number of allowed servers. Set to 0 for unlimited
    static public final MAXIMUM_ALLOWED_SERVERS:UInt = 0;

    // Pretty-print JSON files
    static public final PRETTY_PRINT:Bool = true;

    // Execute vagrant global-status with --prune switch
    static public var PRUNE_VAGRANT_MACHINES:Bool = true;

    // Source code url
    static public final SOURCE_CODE_URL:String = "https://github.com/Moonshine-IDE/Super.Human.Installer";

    // Vagrant download url
    static public final VAGRANT_DOWNLOAD_URL:String = "https://developer.hashicorp.com/vagrant/downloads";

    // Vagrant minimum supported version
    static public final VAGRANT_MINIMUM_SUPPORTED_VERSION:VersionInfo = "2.3.4";

    // VirtualBox download url
    static public final VIRTUALBOX_DOWNLOAD_URL:String = "https://www.virtualbox.org/wiki/Downloads";

}