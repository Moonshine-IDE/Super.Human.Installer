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
 
 package cpp;

 @:buildXml('<include name="${HXCPP}/src/hx/libs/std/Build.xml"/>')
 extern class NativeProcess {
     @:native("_hx_std_process_run")
     static function process_run(cmd:String, vargs:Array<String>, inShow:Int = 0):Dynamic;
 
     @:native("_hx_std_process_run")
     static function process_run_with_show(cmd:String, vargs:Array<String>, inShow:Int):Dynamic;
 
     @:native("_hx_std_process_stdout_read")
     static function process_stdout_read(handle:Dynamic, buf:haxe.io.BytesData, pos:Int, len:Int):Int;
 
     @:native("_hx_std_process_stderr_read")
     static function process_stderr_read(handle:Dynamic, buf:haxe.io.BytesData, pos:Int, len:Int):Int;
 
     @:native("_hx_std_process_stdin_write")
     static function process_stdin_write(handle:Dynamic, buf:haxe.io.BytesData, pos:Int, len:Int):Int;
 
     @:native("_hx_std_process_stdin_close")
     static function process_stdin_close(handle:Dynamic):Void;
 
     @:native("_hx_std_process_exit")
     static function process_exit(handle:Dynamic):Int;
 
     @:native("_hx_std_process_pid")
     static function process_pid(handle:Dynamic):Int;
 
     @:native("_hx_std_process_kill")
     static function process_kill(handle:Dynamic):Void;
 
     @:native("_hx_std_process_close")
     static function process_close(handle:Dynamic):Void;
 }
 