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

package prominic.logging;

import haxe.Json;
import haxe.Log;
import haxe.PosInfos;
import haxe.ds.BalancedTree;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

class Logger {

    static final _FILE_NAME_PATTERN:EReg = ~/^(?:log){1}(?:-){1}(?:[a-zA-Z0-9-]+)(?:.)(?:txt)$/;

    static var _baseFileName:String = "log";
    static var _currentLogFilePath:String;
    static var _logLevel:LogLevel = LogLevel.Info;
    static var _machineReadableOutput:Bool = false;
    static var _numLogFiles:Int;
    static var _pathToLogFile:String;
    static var _printTime:Bool = false;
    static var _useColoredOutput:Bool = true;

    public static function init( ?logLevel:LogLevel = LogLevel.Info, ?printTime:Bool = false, pathToLogFile:String, ?numLogFiles:Int = 9, ?useColoredOutput:Bool = true, ?machineReadable:Bool = false ):String {
        
        _logLevel = logLevel;
        _printTime = printTime;
        _pathToLogFile = Path.addTrailingSlash( Path.normalize( pathToLogFile ) );
        _useColoredOutput = useColoredOutput;
        _machineReadableOutput = machineReadable;
        _numLogFiles = numLogFiles;

        //var _fileName:String = StringTools.replace( StringTools.replace( "log-" + Date.now().toString() + ".txt", ":", "-" ), " ", "-" );
        var _fileName:String = "current.txt";
        _currentLogFilePath = _pathToLogFile + _fileName;

        #if sys

        // Directory maintenance

        try {

            // Creating log directory
            FileSystem.createDirectory( pathToLogFile );

            // If current.txt already exists, rename it
            if ( FileSystem.exists( _currentLogFilePath ) ) {

                var f = FileSystem.stat( _currentLogFilePath );
                var nn = StringTools.replace( StringTools.replace( "log-" + f.mtime.toString() + ".txt", ":", "-" ), " ", "-" );
                File.copy( _currentLogFilePath, _pathToLogFile + nn );
                FileSystem.deleteFile( _currentLogFilePath );

            }

            // Getting file list
            var a = FileSystem.readDirectory( _pathToLogFile );
            var b:Array<String> = [];
            for ( f in a ) if ( _FILE_NAME_PATTERN.match( f ) ) b.push( f );

            // Sorting files by modification date
            var m:BalancedTree<String, String> = new BalancedTree();
            for ( f in b ) m.set( Std.string( FileSystem.stat( _pathToLogFile + f ).mtime.getTime() ), f );

            var c:Array<String> = [];
            for ( d in m.keys() ) c.push( m.get( d ) );

            // Deleting files
            if ( c.length > _numLogFiles ) {

                for ( i in 0...c.length-_numLogFiles ) FileSystem.deleteFile( _pathToLogFile + c[ i ] );
                c.reverse();
                c.resize( _numLogFiles );
                c.reverse();

            }

            // Copying latest entry to last.txt
            File.copy( _pathToLogFile + c[ c.length-1 ], _pathToLogFile + "last.txt" );

        } catch ( e ) {}

        if ( _currentLogFilePath != null ) {

            try {

                File.saveContent( _currentLogFilePath, "" );

            } catch ( e ) {}

        }
        #end

        Log.trace = loggerFunction;

        return _currentLogFilePath;

    }

    public static function debug( v:Dynamic, ?pos:PosInfos ) {

        log( v, LogLevel.Debug, pos );

    }

    public static function error( v:Dynamic, ?pos:PosInfos ) {

        log( v, LogLevel.Error, pos );

    }

    public static function fatal( v:Dynamic, ?pos:PosInfos ) {

        log( v, LogLevel.Fatal, pos );

    }

    public static function info( v:Dynamic, ?pos:PosInfos ) {

        log( v, LogLevel.Info, pos );

    }

    public static function verbose( v:Dynamic, ?pos:PosInfos ) {

        log( v, LogLevel.Verbose, pos );

    }

    public static function warning( v:Dynamic, ?pos:PosInfos ) {

        log( v, LogLevel.Warning, pos );

    }

    static function log( v:Dynamic, ?level:LogLevel = LogLevel.Info, ?pos:PosInfos ) {
        
        if ( level > _logLevel || level == LogLevel.None ) return;

        trace( v, level, pos );

    }
    
    static function loggerFunction( v:Dynamic, ?pos:PosInfos ) {

        if ( _logLevel == LogLevel.None ) return;

        #if sys

        if ( _machineReadableOutput ) {

            var formattedMessage:FormattedMessage = {

                level: LogLevel.Info,
                message: Std.string( v ),
                time: Sys.time(),

            }

            if ( pos != null ) {

                if ( pos.customParams != null ) {

                    if ( Std.isOfType( pos.customParams[ 0 ], Int ) )
                        formattedMessage.level = cast( pos.customParams[ 0 ], Int );
        
                    for ( i in pos.customParams ) {
        
                        #if debug
                        if ( Reflect.hasField( i, "fileName" ) ) {
        
                            formattedMessage.source = '${i.fileName}:${i.lineNumber}';
        
                        }
                        #end
        
                    }
        
                } else {

                    #if debug   
                    formattedMessage.source = '${pos.fileName}:${pos.lineNumber}';
                    #end

                }

            }

            var finalMessage:String = Json.stringify( formattedMessage );

            if ( formattedMessage.level == LogLevel.Fatal || formattedMessage.level == LogLevel.Error ) {

                Sys.stderr().writeString( finalMessage + "\r\n" );

            }

            Sys.println( finalMessage );

            if ( _currentLogFilePath != null ) {

                try {

                    var o = File.append( _currentLogFilePath );
                    o.writeString( finalMessage + "\r\n" );
                    o.flush();
                    o.close();

                } catch ( e ) {}

            }

        } else {

            var s:String = Std.string( v );
            var c:String = '';
            var t:String = '';
            var l:String = '';
            var f:String = '';

            if ( _printTime ) t = '[${Date.now().toString()}]';

            var logLevel:LogLevel = LogLevel.Info;

            if ( pos != null ) {

                if ( pos.customParams != null ) {

                    if ( Std.isOfType( pos.customParams[ 0 ], Int ) )
                        logLevel = cast( pos.customParams[ 0 ], Int );
        
                    for ( i in pos.customParams ) {
        
                        #if debug
                        if ( Reflect.hasField( i, "fileName" ) ) {
        
                            f += '[${i.fileName}:${i.lineNumber}]';
        
                        }
                        #end
        
                    }
        
                } else {

                    #if debug   
                    f += '[${pos.fileName}:${pos.lineNumber}]';
                    #end

                }

            }

            switch ( logLevel ) {

                case LogLevel.Fatal:
                    c = Std.string( Colors.On_IRed ) + Std.string( Colors.BIWhite );
                    l += "[FATAL]";

                case LogLevel.Error:
                    c = Colors.BRed;
                    l += "[ERROR]";

                case LogLevel.Warning:
                    c = Colors.Yellow;
                    l += "[WARNING]";

                case LogLevel.Debug:
                    c = Colors.Cyan;
                    l += "[DEBUG]";

                case LogLevel.Verbose:
                    c = Colors.Purple;
                    l += "[VERBOSE]";

                default:
                    c = Colors.Color_Off;
                    l += "[INFO]";

            }

            if ( logLevel == LogLevel.Fatal || logLevel == LogLevel.Error ) {

                Sys.stderr().writeString( t + l + f + " " + s + "\r\n" );

            }

            if ( _useColoredOutput )
                Sys.println( c + t + l + f + " " + s + Std.string( Colors.Color_Off ) )
            
            else
                Sys.println( t + l + f + " " + s );

            if ( _currentLogFilePath != null ) {

                try {

                    var o = File.append( _currentLogFilePath );
                    o.writeString( t + l + f + " " + s + "\r\n" );
                    o.flush();
                    o.close();

                } catch ( e ) {}

            }

        }

        #end

    }

}

typedef FormattedMessage = {

    level:LogLevel,
    message:String,
    time:Float,
    ?source:String,

}

/*
enum abstract LogContext( String ) to String {

    var Server;

}
*/

enum abstract LogLevel( Int ) from Int to Int {

    var None = 0;
    var Fatal = 1;
    var Error = 2;
    var Warning = 3;
    var Info = 4;
    var Debug = 5;
    var Verbose = 6;

    @:op(A > B) private static inline function gt(a:LogLevel, b:LogLevel):Bool {
        return (a : Int) > (b : Int);
    }

    @:op(A >= B) private static inline function gte(a:LogLevel, b:LogLevel):Bool {

        return (a : Int) >= (b : Int);

    }

    @:op(A < B) private static inline function lt(a:LogLevel, b:LogLevel):Bool {

        return (a : Int) < (b : Int);

    }

    @:op(A <= B) private static inline function lte(a:LogLevel, b:LogLevel):Bool {

        return (a : Int) <= (b : Int);

    }

}

enum abstract Colors( String ) to String {

    // Reset
    var Color_Off='\033[0m';

    // Regular
    var Black='\033[0;30m';
    var Red='\033[0;31m';
    var Green='\033[0;32m';
    var Yellow='\033[0;33m';
    var Blue='\033[0;34m';
    var Purple='\033[0;35m';
    var Cyan='\033[0;36m';
    var White='\033[0;37m';

    // Bold
    var BBlack='\033[1;30m';
    var BRed='\033[1;31m';
    var BGreen='\033[1;32m';
    var BYellow='\033[1;33m';
    var BBlue='\033[1;34m';
    var BPurple='\033[1;35m';
    var BCyan='\033[1;36m';
    var BWhite='\033[1;37m';

    // Underline
    var UBlack='\033[4;30m';
    var URed='\033[4;31m';
    var UGreen='\033[4;32m';
    var UYellow='\033[4;33m';
    var UBlue='\033[4;34m';
    var UPurple='\033[4;35m';
    var UCyan='\033[4;36m';
    var UWhite='\033[4;37m';

    // Background
    var On_Black='\033[40m';
    var On_Red='\033[41m';
    var On_Green='\033[42m';
    var On_Yellow='\033[43m';
    var On_Blue='\033[44m';
    var On_Purple='\033[45m';
    var On_Cyan='\033[46m';
    var On_White='\033[47m';

    // High Intensity
    var IBlack='\033[0;90m';
    var IRed='\033[0;91m';
    var IGreen='\033[0;92m';
    var IYellow='\033[0;93m';
    var IBlue='\033[0;94m';
    var IPurple='\033[0;95m';
    var ICyan='\033[0;96m';
    var IWhite='\033[0;97m';

    // Bold High Intensity
    var BIBlack='\033[1;90m';
    var BIRed='\033[1;91m';
    var BIGreen='\033[1;92m';
    var BIYellow='\033[1;93m';
    var BIBlue='\033[1;94m';
    var BIPurple='\033[1;95m';
    var BICyan='\033[1;96m';
    var BIWhite='\033[1;97m';

    // High Intensity backgrounds
    var On_IBlack='\033[0;100m';
    var On_IRed='\033[0;101m';
    var On_IGreen='\033[0;102m';
    var On_IYellow='\033[0;103m';
    var On_IBlue='\033[0;104m';
    var On_IPurple='\033[0;105m';
    var On_ICyan='\033[0;106m';
    var On_IWhite='\033[0;107m';

}