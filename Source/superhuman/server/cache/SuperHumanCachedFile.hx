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

package superhuman.server.cache;

/**
 * Represents a file in the cache system
 */
typedef SuperHumanCachedFile = {
    /**
     * Path to the file in the cache directory
     */
    path: String,
    
    /**
     * Original filename
     */
    originalFilename: String,
    
    /**
     * MD5 hash of the file -- to be removed soon, we don't want backwards compatability
     */
    hash: String,
    
    /**
     * SHA256 hash of the file (more secure)
     */
    ?sha256: String,
    
    /**
     * Whether the file exists in the cache directory
     */
    exists: Bool,
    
    /**
     * Version information
     */
    ?version: {
        ?majorVersion: String,
        ?minorVersion: String,
        ?patchVersion: String,
        ?fixPackVersion: String,
        ?fullVersion: String
    },
    
    /**
     * Type of file (installer, hotfix, fixpack)
     */
    type: String,
    
    /**
     * Role/product the file applies to (domino, noamd, etc.)
     */
    role: String
}
