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

import prominic.sys.applications.bin.Shell;

class SysTools {

    static final _PATH_SEPARATOR:String = #if windows ";" #else ":" #end;
    static final _PATH_VARIABLE:String = #if windows "Path" #else "PATH" #end;

    static var _cpuArchitecture:CPUArchitecture;
    #if windows
    static var _lineEnd:String = "\r\n";
    #else
    static var _lineEnd:String = "\n";
    #end

    public static var lineEnd( get, never ):String;
    static function get_lineEnd() return _lineEnd;
    
    /**
     * Adds a new value to PATH environment variable if it doesn't already exist
     * @param value The new value to be added
     * @return Returns true if value has been added to path, false otherwise
     */

    public static function addToPath( value:String ):Bool {
        
        var _env = Sys.environment();
        var _systemPath = _env.get( _PATH_VARIABLE );
        var a = _systemPath.split( _PATH_SEPARATOR );

        if ( !a.contains( value ) ) {

            a.push( value );
            var np = a.join( _PATH_SEPARATOR );
            Sys.putEnv( _PATH_VARIABLE, np );
            return true;

        }

        return false;

    }

    static public function getCPUArchitecture():CPUArchitecture {

        #if mobile
        return CPUArchitecture.Unknown;
        #else

        if ( _cpuArchitecture != null ) return _cpuArchitecture;

        var s:String = "";

        #if windows
        s = Sys.environment().get( 'PROCESSOR_ARCHITECTURE' );
        if ( s == null ) s = "";
        #elseif mac
        _cpuArchitecture = ( Shell.getInstance().checkArm64() ) ? CPUArchitecture.Arm64 : CPUArchitecture.X86_64;
        return _cpuArchitecture;
        #else
        s = Shell.getInstance().uname();
        #end

        switch s.toLowerCase() {
            case "i386" | "i686" | "x86":
                _cpuArchitecture = CPUArchitecture.X86;
            case "x86_64" | "amd64":
                _cpuArchitecture = CPUArchitecture.X86_64;
            case "arm64":
                _cpuArchitecture = CPUArchitecture.Arm64;
            default:
                _cpuArchitecture = CPUArchitecture.Unknown;
        }

        return _cpuArchitecture;

        #end

    }

    public static function getWindowsUserName() {
    		var envs = Sys.environment();
		if (envs.exists("USERNAME")) {
			return envs["USERNAME"];
		}
		
		if (envs.exists("USER")) {
			return envs["USER"];
		}    
		return null;
    }
}

enum CPUArchitecture {

    Arm64;
    Unknown;
    X86;
    X86_64;

}