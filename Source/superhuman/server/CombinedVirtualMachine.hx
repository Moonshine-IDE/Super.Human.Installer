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

typedef CombinedVirtualMachine = {

    ?CfgFile:String,
    ?LogFldr:String,
    ?SnapFldr:String,
    ?VMState:String,
    ?apic:String,
    ?chipset:String,
    ?cpuexecutioncap:Int,
    ?cpuprofile:String,
    ?cpus:Int,
    ?description:String,
    ?encryption:Bool,
    ?firmware:String,
    ?hardwareuuid:String,
    ?home:String,
    ?hpet:String,
    ?id:Int,
    ?longmode:String,
    ?memory:Int,
    ?name:String,
    ?nestedhwvirt:String,
    ?ostype:String,
    ?pae:String,
    ?pagefusion:String,
    ?provider:String,
    ?root:String,
    ?serverId:Int,
    ?state:CombinedVirtualMachineState,
    ?triplefaultreset:String,
    ?vagrantId:String,
    ?virtualBoxId:String,
    ?vram:Int,
    ?x2apic:String,

}

enum abstract CombinedVirtualMachineState( String ) to String {

    var Aborted = "aborted";
    var NotCreated = "not_created";
    var PowerOff = "poweroff";
    var Running = "running";
    var Unknown = "unknown";

}