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

    // DevOps Wikipedia page url
    static public final DEVOPS_WIKI_URL:String = "https://en.wikipedia.org/wiki/DevOps";

    // HCL Domino Wikipedia page url
    static public final DOMINO_WIKI_URL:String = "https://en.wikipedia.org/wiki/HCL_Domino";

    // Genesis.Directory url
    static public final GENESIS_DIRECTORY_URL:String = "https://genesis.directory/";

    // Use of 'vagrant global-status'
    static public final IGNORE_VAGRANT_STATUS:Bool = false;

    // Maximum number of allowed servers. Set to 0 for unlimited
    static public final MAXIMUM_ALLOWED_SERVERS:UInt = 0;

    // Pretty-print JSON files
    static public final PRETTY_PRINT:Bool = true;

    // Execute vagrant global-status with --prune switch
    static public var PRUNE_VAGRANT_MACHINES:Bool = false;

    // The time to wait after the provisioning proof file created, in milliseconds
    static public final SIMULATE_VAGRANT_UP_EXIT_TIMEOUT:Int = 5000;

    // Source code url
    static public final SOURCE_CODE_URL:String = "https://github.com/Moonshine-IDE/Super.Human.Installer";

    // Source code url
    static public final SOURCE_CODE_ISSUES_URL:String = "https://github.com/Moonshine-IDE/Super.Human.Installer/issues";

    // Updater versioninfo file address
    static public final UPDATER_ADDRESS:String = "https://moonshine-ide.github.io/Super.Human.Installer/versioninfo.json";

    // Vagrant url
    static public final VAGRANT_URL:String = "https://www.vagrantup.com/";

    // Vagrant download url
    static public final VAGRANT_DOWNLOAD_URL:String = "https://developer.hashicorp.com/vagrant/downloads";

    // Vagrant minimum supported version
    static public final VAGRANT_MINIMUM_SUPPORTED_VERSION:VersionInfo = "2.3.4";

    // VirtualBox url
    static public final VIRTUALBOX_URL:String = "https://www.virtualbox.org/";

    // VirtualBox download url
    static public final VIRTUALBOX_DOWNLOAD_URL:String = "https://www.virtualbox.org/wiki/Downloads";

    // YAML Wikipedia page url
    static public final YAML_WIKI_URL:String = "https://en.wikipedia.org/wiki/YAML";

}