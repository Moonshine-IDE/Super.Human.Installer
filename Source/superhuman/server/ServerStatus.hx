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

package superhuman.server;

enum ServerStatus {

    /**
     * Used internally for an initial status
     */
    Unknown;
    
    /**
     * The server is invalid
     */
    Invalid;

    /**
     * The server is not running
     */
    Stopped;

    /**
     * The server is stopping
     */
    Stopping;

    /**
     * The server has never been configured
     */
    Unconfigured;

    /**
     * The server is initializing, copying files to server directory
     */
    Initializing;

    /**
     * The server is starting for the first time, previously 'vagrant up' was unsuccessful
     */
    FirstStart;

    /**
     * The server is starting
     */
    Start;

    /**
     * The server is configured, ready for first launch
     */
    Ready;

    /**
     * The server is running
     */
    Running;

    /**
     * The server is finished with an error
     */
    Error;

    /**
     * The server is finished with an error but still running
     */
    RunningWithError;

    /**
     * The server is provisioning
     */
    Provisioning;
    
    /**
     * The server is RSyncing
     */
    RSyncing;

    /**
     * The server is retrieving status
     */
    GetStatus;

    /**
     * The server is about to be destroyed
     */
    Destroying;
    
}