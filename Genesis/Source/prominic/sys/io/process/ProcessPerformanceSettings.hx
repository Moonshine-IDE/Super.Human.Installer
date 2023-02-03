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

typedef ProcessPerformanceSettings = {

    /**
     * Disables the thread that's listening to stderr.
     */
    ?disableStderrThread:Bool,

    /**
     * Disables the thread that's listening to stdout.
     */

    ?disableStdoutThread:Bool,

    /**
     * Disables the WaitForExit thread, and captures exit code
     * after stdout and stderr are closed. Setting it to true may
     * conserve memory and CPU resources by limiting the number
     * of new threads
     */
    ?disableWaitForExitThread:Bool,

    /**
     * The number of times the looped thread is being executed per second.
     * Applies only to implementations that have their internal loop defined and
     * enabled. The default value is defined in AbstractProcess
     */
    ?eventsPerSecond:UInt,

    /**
     * Size of the input buffer to read into, in bytes. The default value
     * in ProcessImpl is 32768
     */
    ?inputBufferSize:Int,

    /**
     * The delay, in seconds, between input read loop cycles (Sys.sleep(n)).
     * To conserver CPU usage, sometimes it's a good idea to delay the
     * input read loop cycles by a number between 0.1 and 0.5
     */
    ?inputReadRepeatDelay:Float,

    /**
     * The delay, in seconds, between input thread message read loop cycles.
     * To conserver CPU usage, sometimes it's a good idea to delay the
     * thread message read loop cycles by a number between 0.05 and 0.1
     */
    ?messageReceiverRepeatDelay:Float,

    /**
     * The delay, in seconds, before and after process.exitCode() function.
     * It's usually helpful to add some delay not to receive exitCode
     * immediately after start(). Used only if disableWaitForExitThread is
     * false
     */
    ?waitForExitDelay:Float,

}