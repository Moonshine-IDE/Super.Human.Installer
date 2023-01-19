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

package genesis.application.updater;

import openfl.events.Event;

class GenesisApplicationUpdaterEvent extends Event {

    static public final DOWNLOAD_CANCELLED:String = "download-cancelled";
    static public final DOWNLOAD_COMPLETE:String = "download-complete";
    static public final DOWNLOAD_FAILED:String = "download-failed";
    static public final DOWNLOAD_PROGRESS:String = "download-progress";
    static public final DOWNLOAD_START:String = "download-start";
    static public final EXIT_APP:String = "exit-app";
    static public final UPDATE_FOUND:String = "update-found";
    static public final UPDATE_NOT_FOUND:String = "update-not-found";

    public var bytesLoaded:Null<Float>;
    public var bytesTotal:Null<Float>;

    public var downloadPercentage( get, never ):Float;
    function get_downloadPercentage():Float {
        if ( bytesLoaded == null || bytesTotal == null ) return 0;
        var f:Float = bytesLoaded / bytesTotal * 100.0;
        return f;
    }

    public function new( type:String ) {

        super( type );

    }
    
}