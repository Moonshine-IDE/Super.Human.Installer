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

package prominic.sys.tools;

class StrTools {

    public static final ALPHANUMERIC:String = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
    
    static public function randomString( charset:String, length:Int ):String {

        var s:String = "";

        for ( i in 0...length ) {

            var c = charset.charAt( Std.int( Math.random() * charset.length ) );
            s += c;

        }

        return s;

    }

    static public function toPrecision( f:Float, precision:UInt = 2, useSI:Bool = true ):Float {
        
        var m = Math.pow( 10, precision );
        var d = ( useSI ) ? 1000 : 1024;
        return Std.int( f * m / d ) / m;

    }

    static public function autoFormatBytes( bytes:Float ):String {

        var r = "";

        if ( bytes >= 1000000000 ) {

            var f = toPrecision( bytes / 1000000, 2 );
            r = Std.string( f ) + " GB";

        } else if ( bytes >= 1000000 ) {

            var f = toPrecision( bytes / 1000, 2 );
            r = Std.string( f ) + " MB";

        } else if ( bytes >= 1000 ) {

            var f = toPrecision( bytes, 2 );
            r = Std.string( f ) + " KB";

        } else {

            r = Std.string( bytes ) + " B";

        }

        return r;

    }

    static public function timeToFormattedString( timeInSeconds:Float, fractions:Bool = false ):String {

        var result = "";

        final totalFractions = Std.int( ( timeInSeconds * 1000 ) % 1000 );
        var totalFractionsS = Std.string( totalFractions );
        if ( totalFractionsS.length == 0 ) totalFractionsS = "000"
        else if ( totalFractionsS.length == 1 ) totalFractionsS = "00" + totalFractionsS
        else if ( totalFractionsS.length == 2 ) totalFractionsS = "0" + totalFractionsS;

        final totalSeconds = Std.int( timeInSeconds );
        
        final remainingSeconds = totalSeconds % 60;
        final remainingSecondsS = ( remainingSeconds < 10 ) ? '0${remainingSeconds}' : '${remainingSeconds}';

        final totalMinutes = Std.int( totalSeconds / 60 ) % 60;
        final totalMinutesS = ( totalMinutes < 10 ) ? '0${totalMinutes}' : '${totalMinutes}';

        final totalHours = Std.int( totalSeconds / 3600 );
        final totalHoursS:String = ( totalHours < 10 ) ? '0${totalHours}' : '${totalHours}';

        result = '${totalHoursS}:${totalMinutesS}:${remainingSecondsS}';
        if ( fractions ) result += '.${totalFractionsS}';
        return result;

    }

    static public function calculatePercentage( value:Int, total:Int ):Int {

        if ( total <= 0 ) return 0;
        return Std.int( ( value / total ) * 100 );

    }

}