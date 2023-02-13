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

package prominic.sys.applications.bin;

import haxe.io.Path;
import prominic.logging.Logger;
import prominic.sys.io.AbstractExecutor;
import prominic.sys.io.Executor;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
#if windows
import lime.system.System;
#end
#if ( windows || linux )
import haxe.exceptions.NotImplementedException;
#end

@:allow( prominic.sys )
@:allow( prominic.sys.applications )
class Shell extends AbstractApp {

    static var _instance:Shell;

    static public function getInstance():Shell {

        if ( _instance == null ) _instance = new Shell();
        return _instance;

    }

    var _stdouts:Map<String, String>;

    function new() {

        super();

        _path = "";
        #if windows
        _executable = "cmd";
        #else
        _executable = "";
        #end
        _name = "Shell";

        _stdouts = [];

        _instance = this;

    }

    /**
     * Alias of ls()
     * @param path 
     * @param callback 
     */
    public function dir( path:String, ?callback:(Array<String>) -> Void ) {

        ls( path, callback );

    }

    /**
     * Lists contents of the given path.
     * @param path The path to list the contents of
     * @param callback Optional callback function, that receives an Array<String> value with the list of files and directories
     */
    public function ls( path:String, ?callback:(Array<String>) -> Void ) {

        #if windows
        var lsExecutor:Executor = new Executor( this._executable, [ "/c", "dir", "/b", path ], null, null, [ callback ] );
        #else
        var lsExecutor:Executor = new Executor( "ls", [ path ], null, null, [ callback ] );
        #end
        _stdouts.set( lsExecutor.id, "" );
        lsExecutor.onStdOut.add( _lsExecutorOutput ).onStop.add( _lsExecutorStopped ).execute();

    }

    @:noDoc @:noCompletion
    function _lsExecutorOutput( lsExecutor:AbstractExecutor, data:String ) {

        if ( !_stdouts.exists( lsExecutor.id ) ) {

            _stdouts.set( lsExecutor.id, data );

        } else {

            var s = _stdouts.get( lsExecutor.id ) + data;
            _stdouts.set( lsExecutor.id, s );

        }

    }

    @:noDoc @:noCompletion
    function _lsExecutorStopped( lsExecutor:AbstractExecutor ) {

        if ( lsExecutor.extraParams != null && lsExecutor.extraParams.length > 0 && lsExecutor.extraParams[ 0 ] != null ) {

            var s = _stdouts.get( lsExecutor.id );

            if ( s != null ) {

                var a:Array<String> = ( s.length > 0 ) ? s.split( '\n' ) : [];
                lsExecutor.extraParams[ 0 ]( a );

            }

        }

        _stdouts.remove( lsExecutor.id );
        lsExecutor.dispose();
        lsExecutor = null;

    }

    /**
     * Creates a soft link (symlink, symbolic link). Warning! On Windows, administrator privileges are required to create symlinks!
     * @param sourcePath The original file or directory
     * @param destinationPath The link target
     * @param callback This function will be called when the operations finished. Optional.
     */
    public function ln( sourcePath:String, destinationPath:String, ?callback:(Bool)->Void ) {

        #if windows
        var symlinkExecutor:Executor = new Executor( this._executable, [ "/c", "mklink", destinationPath, sourcePath ], [ callback ] );
        #else
        var symlinkExecutor:Executor = new Executor( "ln", [ "-s", "-F", sourcePath, destinationPath ], [ callback ] );
        #end
        symlinkExecutor.onStop.add( _symlinkExecutorStopped ).execute();

    }

    /**
     * Alias for ln()
     * @param sourcePath 
     * @param destinationPath 
     * @param callback 
     */
    public function mklink( sourcePath:String, destinationPath:String, ?callback:(Bool)->Void ) {

        ln( sourcePath, destinationPath, callback );

    }

    @:noDoc @:noCompletion
    function _symlinkExecutorStopped( symlinkExecutor:AbstractExecutor ) {

        if ( symlinkExecutor.extraParams != null && symlinkExecutor.extraParams.length > 0 && symlinkExecutor.extraParams[ 0 ] != null ) {

            symlinkExecutor.extraParams[ 0 ]( symlinkExecutor.exitCode == 0 );

        }

        symlinkExecutor.dispose();
        symlinkExecutor = null;

    }

    public function kill( processId:Int, ?callback:() -> Void ) {

        #if windows
        //var killExecutor:Executor = new Executor( this._executable, [ "/c", "dir", "/b", path ], null, null, [ callback ] );
        #else
        var killExecutor:Executor = new Executor( "kill", [ Std.string( processId ) ], null, null, [ callback ] );
        killExecutor.onStop.add( _killExecutorStopped ).execute();
        #end

    }

    @:noDoc @:noCompletion
    function _killExecutorStopped( killExecutor:AbstractExecutor ) {

        if ( killExecutor.extraParams != null && killExecutor.extraParams.length > 0 && killExecutor.extraParams[ 0 ] != null ) {

            killExecutor.extraParams[ 0 ]();

        }

        killExecutor.dispose();
        killExecutor = null;

    }

    public function arch( ?callback:(String) -> Void):Executor {

        #if mac
        var archExecutor:Executor = new Executor( "arch", null, [ callback ] );
        archExecutor.onStdOut.add( ( executor:AbstractExecutor, data:String ) -> {

            if ( executor.extraParams != null && executor.extraParams.length > 0 && executor.extraParams[ 0 ] != null ) {

                executor.extraParams[ 0 ]( data );
    
            }

        } ).execute();
        return archExecutor;
        #end

        return null;

    }

    public function checkArm64():Bool {

        #if mac
        var p = new Process( "arch", [ "-arm64", "echo", "true" ] );
        var e = p.exitCode();
        return ( e == 0 );
        #end

        return false;

    }

    //TODO: Implement Windows and Linux open
    public function opene( args:Array<String> ) {

        #if mac
        Sys.command( 'open', args );
        #end

    }

    public function uname():String {

        #if windows
        return null;
        #else
        Logger.verbose( '${this}: uname' );
        var p = new Process( "uname", [ "-m" ] );
        var b = p.stdout.readAll();
        var e = p.exitCode();
        return StringTools.trim( b.toString() );
        #end
    }

    /**
     * Opens/Launches the given path or URL by the operating system's relevant command
     * @param args The arguments to attach to the open command
     */
    public function open( args:Array<String> ) {

        Logger.verbose( '${this}: Open:${args}' );

        #if linux
        Sys.command( "/usr/bin/xdg-open", args );
        #elseif mac
        Sys.command( "/usr/bin/open", args );
        #else
        System.openFile( StringTools.trim( args.join( " " ) ) );
        #end

    }

    public function exec( path:String ) {

        Logger.verbose( '${this}: Exec:${path}' );
        Sys.command( 'exec ${path} &' );

    }

    /**
     * Runs a system command to calculate MD5 hash of the given file
     * @param path Must point to an existing file
     * @return The MD5 hash read from stdout. Returs null if the file does not exist
     */
    public function md5( path:String ):String {

        if ( !FileSystem.exists( path ) ) return null;

        Logger.verbose( '${this}: Checking MD5 at:${path}' );

        #if mac
        var p = new Process( "md5", [ "-q", path ] );
        var b = p.stdout.readAll();
        var e = p.exitCode();
        return StringTools.trim( b.toString() );
        #end

        #if linux
        var r:EReg = ~/([a-z0-9]{32})/gmi;
        var p = new Process( "md5sum", [ "-z", path ] );
        var b = p.stdout.readAll();
        var e = p.exitCode();
        var a = b.toString();
        if ( r.match( a ) ) {
            return r.matched( 1 );
        }
        return null;
        #end

        #if windows
        var r:EReg = ~/([a-z0-9]{32})/gmi;
        var p = new Process( "certutil", [ "-hashfile", path, "MD5" ] );
        var b = p.stdout.readAll();
        var e = p.exitCode();
        var a = b.toString();
        if ( r.match( a ) ) {
            return r.matched( 1 );
        }
        return null;
        #end

    }

    public function openTerminal( ?path:String, launchFileAtPath:Bool = true ) {

        Logger.verbose( '${this}: Opening Terminal at:${path}' );

        #if mac
        Sys.command( "open", [ "-a", "Terminal", path ] );
        #end

        #if windows
        var cwd = Sys.getCwd();
        Sys.setCwd( path );
        if ( launchFileAtPath )
            System.openFile( path )
        else
            System.openFile( "cmd.exe" );
        Sys.setCwd( cwd );
        #end

    }

    public function runShellScript( path:String, ?content:String ) {

        Logger.verbose( '${this}: Running shell script at:${path} content:${content}' );
        var cwd = Sys.getCwd();
        if ( content != null ) File.saveContent( path, content );
        var dir = Path.directory( path );
        var file = Path.withoutDirectory( path );
        Sys.setCwd( dir );
        Sys.command( 'sh', [ file ] );
        Sys.setCwd( cwd );

    }

    // TODO: Implement Windows
    public function findProcessId( ?filter:String, ?pattern:EReg, ?parentPid:Int, ?callback:( Array<ProcessInfo> ) -> Void ) {

        #if windows

        // Not implemented

        #else

        var cmd:String = 'ps';

        var args:Array<String> = [];
        args.push( '-ax' );
        args.push( '-o' );
        args.push( 'pid,ppid,command' );

        var executor:Executor = new Executor( cmd, args, null, null, null, [ filter, pattern, parentPid, callback ] );
        executor.onStdOut.add( _findProcessIdStdOut ).onStop.add( _findProcessIdStop ).execute();

        #end

    }

    function _findProcessIdStdOut( executor:AbstractExecutor, data:String ) {

        if ( !_stdouts.exists( executor.id ) ) {

            _stdouts.set( executor.id, data );

        } else {

            var s = _stdouts.get( executor.id ) + data;
            _stdouts.set( executor.id, s );

        }

    }

    function _findProcessIdStop( executor:AbstractExecutor ) {

        //var regex:EReg = ~/^(\d+)\s(?:.+)\s(?:\d+:\d+\.\d+\s)(.+)$/gm;
        var regex:EReg = ~/^(\d+)\s+(\d+)\s+(.+)$/gm;
        var filter:String = executor.extraParams[ 0 ];
        var pattern:EReg = executor.extraParams[ 1 ];
        var parentPid:Null<Int> = executor.extraParams[ 2 ];
        var callback:( Array<ProcessInfo> ) -> Void = executor.extraParams[ 3 ];
        var result:Array<ProcessInfo> = [];

        var s = _stdouts.get( executor.id );

        if ( s != null ) {

            var a:Array<String> = ( s.length > 0 ) ? s.split( '\n' ) : [];
                
            for ( i in a ) {

                if ( filter != null ) {

                    if ( i.toLowerCase().indexOf( filter.toLowerCase() ) >= 0 ) {

                        if ( regex.match( i ) ) {

                            result.push( { pid: Std.parseInt( regex.matched( 1 ) ), parentPid: Std.parseInt( regex.matched( 2 ) ), command: regex.matched( 3 ) } );

                        }

                    }

                } else if ( pattern != null ) {

                    if ( pattern.match( i ) ) {

                        if ( regex.match( i ) ) {

                            result.push( { pid: Std.parseInt( regex.matched( 1 ) ), parentPid: Std.parseInt( regex.matched( 2 ) ), command: regex.matched( 3 ) } );

                        }

                    }

                }

            }

        }

        if ( parentPid != null ) {

            var finalResult:Array<ProcessInfo> = [];
            for ( i in result ) if ( i.parentPid == parentPid ) finalResult.push( i );
            result = finalResult;

        }

        if ( callback != null ) callback( result );

        _stdouts.remove( executor.id );
        executor.dispose();
        executor = null;
        
    }

    // TODO: Implement Windows
    public function killProcesses( processIds:Array<Int>, signal:KillSignal ) {

        for ( pid in processIds ) {

            #if windows

            // Not implemented

            #else

            var args:Array<String> = [];
            args.push( "-" + Std.string( Std.int( signal ) ) );
            args.push( Std.string( pid ) );
            var e = Sys.command( "kill", args );

            #end

        }

    }

    /**
     * Calculates the size of the given directory or file
     * @param path 
     * @return The size in bytes. Returns 0 if the path doesn't exist
     */
    public function du( path:String ) {

        #if mac
            var r:EReg = ~/^(\d+)\s(?:.)*$/gm;            
            var p = new Process( "du", [ "-Aks", path ] );
            var b = p.stdout.readAll().toString();
            var e = p.exitCode();

            if ( e == 0 ) {

                if ( r.match( b ) ) {

                    var f = Std.parseFloat( r.matched( 1 ) );
                    f *= 1000;
                    return f;

                } else {

                    return 0;

                }

            }
            
            return 0;
        #else
            throw new NotImplementedException( "Shell.du() is not implemented on this platform" );
        #end

    }

    public override function toString():String {

        return '[Shell]';

    }

}

typedef ProcessInfo = {

    pid:Int,
    parentPid:Int,
    command:String,

}

enum abstract KillSignal( Int ) from Int to Int  {
    
    var HangUp = 1;
    var Interrupt = 2;
    var Quit = 3;
    var Abort = 6;
    var Kill = 9;
    var Alarm = 14;
    var Terminate = 15;

}