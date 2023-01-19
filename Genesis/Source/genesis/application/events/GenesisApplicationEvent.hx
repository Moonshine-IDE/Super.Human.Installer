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

package genesis.application.events;

import openfl.events.Event;

class GenesisApplicationEvent extends Event {

    public static final CANCEL:String = "cancel";
    public static final CANCEL_UPDATE_PAGE:String = "cancelUpdatePage";
    public static final INIT_UPDATE:String = "initUpdate";
    public static final LOGIN:String = "login";
    public static final LOGOUT:String = "logout";
    public static final MENU_SELECTED:String = "menuSelected";
    public static final OPEN_LOGS_DIRECTORY:String = "openLogsDirectory";
    public static final SHOW_USER_MENU:String = "showUserMenu";
    public static final START_PROCESS:String = "startProcess";
    public static final VISIT_GENESIS_DIRECTORY:String = "visitGenesisDirectory";
    public static final VISIT_SOURCE_CODE:String = "visitSourceCode";

    public var pageId:String;
    public var password:String;
    public var username:String;

    public function new( type:String ) {

        super( type );

    }

}