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

package superhuman.events;

import genesis.application.events.GenesisApplicationEvent;
import superhuman.components.Console;
import superhuman.server.Server;
import superhuman.server.provisioners.ProvisionerType;

class SuperHumanApplicationEvent extends GenesisApplicationEvent {

    public static final ADVANCED_CONFIGURE_SERVER:String = "advancedConfigureServer";
    public static final CANCEL_ADVANCED_CONFIGURE_SERVER:String = "cancelAdvancedConfigureServer";
    public static final CANCEL_CONFIGURE_SERVER:String = "cancelConfigureServer";
    public static final CANCEL_PAGE:String = "cancelPage";
    public static final CLOSE_CONSOLE:String = "closeConsole";
    public static final CLOSE_ROLES:String = "closeRoles";
    public static final CONFIGURE_ROLES:String = "configureRoles";
    public static final CONFIGURE_SERVER:String = "configureServer";
    public static final COPY_TO_CLIPBOARD:String = "copyToClipboard";
    public static final CREATE_SERVER:String = "createServer";
    public static final DELETE_SERVER:String = "deleteServer";
    public static final DESTROY_SERVER:String = "destroyServer";
    public static final DOWNLOAD_VAGRANT:String = "downloadVagrant";
    public static final DOWNLOAD_VIRTUALBOX:String = "downloadVirtualBox";
    public static final OPEN_BROWSER:String = "openBrowser";
    public static final OPEN_CONSOLE:String = "openConsole";
    public static final OPEN_SERVER_DIRECTORY:String = "openServerDirectory";
    public static final OPEN_VAGRANT_SSH:String = "openVagrantSSH";
    public static final PROVISION_SERVER:String = "provisionServer";
    public static final RESET_SERVER:String = "resetServer";
    public static final SAVE_ADVANCED_SERVER_CONFIGURATION:String = "saveAdvancedServerConfiguration";
    public static final SAVE_APP_CONFIGURATION:String = "saveAppConfiguration";
    public static final SAVE_SERVER_CONFIGURATION:String = "saveServerConfiguration";
    public static final START_SERVER:String = "startServer";
    public static final STOP_SERVER:String = "stopServer";
    public static final SYNC_SERVER:String = "syncServer";

    public var console:Console;
    public var data:String;
    public var server:Server;
    public var provisionerType:ProvisionerType;
    
    public function new( type:String ) {

        super( type );

    }

}