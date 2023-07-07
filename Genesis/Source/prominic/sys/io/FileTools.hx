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

package prominic.sys.io;

import haxe.io.Bytes;
import haxe.io.Path;
import champaign.core.logging.Logger;
import prominic.sys.applications.bin.Shell;
import sys.FileSystem;
import sys.io.File;
import sys.thread.Mutex;
import sys.thread.Thread;

/**
 * Library of file system operations
 */
class FileTools {

    static var _batchCopyCallback:()->Void;
    static var _batchCopyPaths:Array<PathPair>;
    static var _batchCopyPerFileCallback:(PathPair, Bool)->Void;
    static var _batchOverwriteRule:FileOverwriteRule;
    static var _copyDirectoryCallback:()->Void;
    static var _copyDirectoryThreaded:Bool;
    static var _destinationPath:String;
    static var _mutex:Mutex = new Mutex();
    static var _overwriteRule:FileOverwriteRule;
    static var _sourcePath:String;

    /**
     * Copies one directory and its files (including subdirectories) to another directory.
     * @param sourcePath The path to the source directory
     * @param destinationPath The path to the destination directory. If it doesn't exist, it'll be created
     * @param overwriteRule Optionally define the rule of overwrite. @see OverwriteRule for mode details
     * @param callback This function will be called when the operations finished. Optional.
     */
    static public function copyDirectory( sourcePath:String, destinationPath:String, ?overwriteRule:FileOverwriteRule = FileOverwriteRule.IfNewer, ?callback:()->Void ) {

        if ( !FileSystem.isDirectory( sourcePath ) ) return;

        _copyDirectoryCallback = callback;
        _copyDirectoryThreaded = true;
        _destinationPath = destinationPath;
        _sourcePath = sourcePath;
        _overwriteRule = overwriteRule;

        if ( !FileSystem.exists( _destinationPath ) ) FileSystem.createDirectory( _destinationPath );

        if ( _copyDirectoryThreaded ) {

            Thread.runWithEventLoop( _copyDirectory );

        } else {

            _copyDirectory();

        }

    }

    @:noDoc @:noCompletion
    static function _copyDirectory() {

        if ( _copyDirectoryThreaded ) {

            _mutex = new Mutex();
            _mutex.acquire();

        }

        _copyDirectoryContents( _sourcePath, _destinationPath );

        if ( _copyDirectoryThreaded ) _mutex.release();

        if ( _copyDirectoryCallback != null ) _copyDirectoryCallback();

    }

    @:noDoc @:noCompletion
    static function _copyDirectoryContents( sourcePath:String, destinationPath:String ) {

        var fileList = FileSystem.readDirectory( sourcePath );

        for ( filename in fileList ) {

            var src = sourcePath + "/" + filename;
            var dest = destinationPath + "/" + filename;

            if ( FileSystem.isDirectory( src ) ) {

                if ( !FileSystem.exists( dest ) ) FileSystem.createDirectory( dest );
                _copyDirectoryContents( src, dest );

            } else {

                var canCopy:Bool = false;

                if ( _overwriteRule == FileOverwriteRule.Always ) canCopy = true;

                if ( _overwriteRule == FileOverwriteRule.IfNewer ) {

                    if ( FileSystem.exists( dest ) ) {

                        var ds = FileSystem.stat( dest );
                        var ss = FileSystem.stat( src );

                        if ( ss.mtime.getTime() > ds.mtime.getTime() ) {

                            canCopy = true;

                        }

                    } else {

                        canCopy = true;

                    }

                }

                if ( _overwriteRule == FileOverwriteRule.IfSizeDifferent ) {

                    if ( FileSystem.exists( dest ) ) {

                        var ds = FileSystem.stat( dest );
                        var ss = FileSystem.stat( src );

                        if ( ss.size != ds.size ) {

                            canCopy = true;

                        }

                    } else {

                        canCopy = true;

                    }

                }

                if ( canCopy ) {

                    try {

                        File.copy( src, dest );

                    } catch ( e ) {

                        Logger.error( 'Copying ${src} to ${dest} failed' );

                    }

                }

            }

        }

    }

    static public function batchCopy( paths:Array<PathPair>, ?overwriteRule:FileOverwriteRule = FileOverwriteRule.IfNewer, ?callback:()->Void, ?perFileCallback:( PathPair, Bool ) -> Void ) {

        _batchCopyPaths = paths;
        _batchOverwriteRule = overwriteRule;
        _batchCopyCallback = callback;
        _batchCopyPerFileCallback = perFileCallback;

        Thread.createWithEventLoop( _batchCopy );

    }

    static function _batchCopy() {

        _mutex.acquire();

        for ( p in _batchCopyPaths ) {

            var canCopy:Bool = true;

            FileSystem.createDirectory( Path.directory( p.destination ) );

            if ( FileSystem.exists( p.destination ) ) {

                var src = FileSystem.stat( p.source );
                var dest = FileSystem.stat( p.destination );

                switch ( _batchOverwriteRule ) {

                    case FileOverwriteRule.IfNewer:
                        canCopy = ( src.mtime.getTime() > dest.mtime.getTime() );

                    case FileOverwriteRule.IfSizeDifferent:
                        canCopy = src.size != dest.size;

                    case FileOverwriteRule.Never:
                        canCopy = false;

                    default:
                        canCopy = true;

                }
    
            }

            if ( _batchCopyPerFileCallback != null ) _batchCopyPerFileCallback( p, canCopy );

            if ( canCopy ) {

                Logger.debug( 'Copying ${p.source} to ${p.destination}' );
                _copyFileByChunks( p.source, p.destination );

            }

        }

        _mutex.release();

        if ( _batchCopyCallback != null ) _batchCopyCallback();

    }

    static function _copyFileByChunks( sourcePath:String, targetPath:String, ?callback:(Bool)->Void ) {

        if ( !FileSystem.exists( sourcePath ) ) {

            if ( callback != null ) callback( false );
            return;

        }

        var chunkSize:Int = 16000000;
        var readBytes:Int = 0;
        var size = FileSystem.stat( sourcePath ).size;
        var input = File.read( sourcePath );
        var output = File.write( targetPath );
        var buffer:Bytes = Bytes.alloc( chunkSize );
        var position:Int = 0;

        while( readBytes < size ) {

            buffer = Bytes.alloc( chunkSize );
            var length = input.readBytes( buffer, 0, chunkSize );
            output.writeBytes( buffer, 0, length );
            output.flush();
            position += length;
            readBytes += length;

        }

        if ( callback != null ) callback( true );

    }

    /**
     * Deletes the given directory recursively including files and subdirectories
     * @param path The path to the directory to be deleted
     */
    static public function deleteDirectory( path:String ) {

        if ( !FileSystem.exists( path ) || !FileSystem.isDirectory( path ) ) return;

        _deleteDirectory( path );

    }

    static function _deleteDirectory( path:String ) {

        var p = Path.addTrailingSlash( path );
        var a = FileSystem.readDirectory( p );

        for ( f in a ) {

            if ( FileSystem.isDirectory( p + "/" + f ) ) {

                _deleteDirectory( p + "/" + f );

            } else {

                try {

                    FileSystem.deleteFile( p + "/" + f );

                } catch( e ) {}

            }

        }

        try  {

            FileSystem.deleteDirectory( p );

        } catch( e ) {}

    }

    static public function checkMD5( path:String, md5s:Array<String> ):Bool {

        var valid:Bool = false;

        if ( !FileSystem.exists( path ) ) return valid;

        var s = Shell;

        #if neko
        var md5 = Shell.getInstance().md5( path );
        #elseif linux
        var md5 = Shell.getInstance().md5( path );
        #else
        var md5 = Shell.getInstance().md5( path );
        //var md5:String = Md5.make( File.getBytes( path ) ).toHex();
        #end

        if ( md5 == null || md5.length != 32 ) return valid;

        for ( m in md5s ) 
        	{

            if ( m.toLowerCase() == md5.toLowerCase() ) 
            {
            		valid = true;
        		}
        }

        return valid;

    }

    /**
     * Calculates the total size of the directory.
     * Does not work well with file size greather than 4GB (limitations of Int)
     * @param path The path to the directory
     * @return Float
     */
    static public function calculateDirectorySize( path:String ):Float {

        if ( !FileSystem.exists( path ) ) return 0;

        var size:Float = 0;

        var a = FileSystem.readDirectory( path );

        for ( f in a ) {

            var p = Path.addTrailingSlash( path ) + f;

            if ( FileSystem.isDirectory( p ) ) {

                size += calculateDirectorySize( p );

            } else {

                var stat = FileSystem.stat( p );
                size += stat.size;

            }

        }

        return size;

    }

}

enum FileOverwriteRule {

    Always;
    IfNewer;
    IfSizeDifferent;
    Never;

}

typedef PathPair = {

    source:String,
    destination:String,

}