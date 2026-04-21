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

package superhuman.utils;

import champaign.core.logging.Logger;
import sys.FileSystem;
import sys.io.File;

/**
 * Writes a file via temp-file + rename so a crash mid-write cannot leave a
 * truncated or empty target. Optionally keeps the last good content in a
 * `.bak` file for recovery.
 */
class SafeFileSaver {

    /**
     * Atomically saves `content` to `path`. Writes to `${path}.tmp` first,
     * then renames over the target. If `keepBackup` is true, the previous
     * content of `path` is copied to `${path}.bak` before the rename.
     * @return true on success, false if the write failed (target left untouched when possible)
     */
    public static function save( path:String, content:String, keepBackup:Bool = true ):Bool {

        var tmpPath = path + ".tmp";
        var bakPath = path + ".bak";

        try {
            File.saveContent( tmpPath, content );
        } catch ( e ) {
            Logger.error( 'SafeFileSaver: Failed to write temp file ${tmpPath}: ${e}' );
            _tryDelete( tmpPath );
            return false;
        }

        if ( keepBackup && FileSystem.exists( path ) ) {
            try {
                File.copy( path, bakPath );
            } catch ( e ) {
                Logger.warning( 'SafeFileSaver: Failed to create backup ${bakPath}: ${e}' );
            }
        }

        try {
            if ( FileSystem.exists( path ) ) FileSystem.deleteFile( path );
            FileSystem.rename( tmpPath, path );
        } catch ( e ) {
            Logger.error( 'SafeFileSaver: Failed to rename ${tmpPath} to ${path}: ${e}' );
            _tryDelete( tmpPath );
            return false;
        }

        return true;

    }

    /**
     * Restores `path` from `${path}.bak` if the target is missing or empty
     * and a non-empty backup exists. Call this at startup before reading
     * critical configuration files.
     * @return true if a restore happened
     */
    public static function restoreFromBackupIfNeeded( path:String ):Bool {

        var bakPath = path + ".bak";

        if ( !FileSystem.exists( bakPath ) ) return false;

        var targetMissingOrEmpty = !FileSystem.exists( path ) || FileSystem.stat( path ).size == 0;
        if ( !targetMissingOrEmpty ) return false;

        if ( FileSystem.stat( bakPath ).size == 0 ) return false;

        try {
            File.copy( bakPath, path );
            Logger.warning( 'SafeFileSaver: Restored ${path} from backup (${bakPath})' );
            return true;
        } catch ( e ) {
            Logger.error( 'SafeFileSaver: Failed to restore ${path} from ${bakPath}: ${e}' );
            return false;
        }

    }

    static function _tryDelete( path:String ) {
        try { if ( FileSystem.exists( path ) ) FileSystem.deleteFile( path ); } catch ( _ ) {}
    }

}
