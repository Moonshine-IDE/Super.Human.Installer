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

package prominic.sys.io.process;

class ProcessTools {
    
    static public function kill( pid:Int, signal:KillSignal = KillSignal.Kill ) {

        #if sys

        if ( _isMac() || _isLinux() ) {

            Sys.command( 'kill -s ${signal} ${pid}' );

        } else if ( _isWindows() ) {

            Sys.command( 'taskkill /PID ${pid} /T /F' );

        }

        #end

    }

    static function _isLinux():Bool {

        return Sys.systemName().toLowerCase().indexOf( 'linux') == 0;

    }

    static function _isMac():Bool {

        return Sys.systemName().toLowerCase().indexOf( 'mac') == 0;

    }

    static function _isWindows():Bool {

        return Sys.systemName().toLowerCase().indexOf( 'windows') == 0;

    }

}

enum abstract KillSignal( Int ) to Int {

    var Abort = 6;
    var Alarm = 14;
    var HangUp = 1;
    var Interrupt = 2;
    var Kill = 9;
    var Quit = 3;
    var Terminate = 15;

}