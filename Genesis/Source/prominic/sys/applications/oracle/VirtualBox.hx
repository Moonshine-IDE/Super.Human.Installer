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

package prominic.sys.applications.oracle;

import feathers.data.ArrayCollection;
import haxe.io.Path;
import prominic.core.ds.ChainedList;
import prominic.sys.io.AbstractExecutor;
import prominic.sys.io.Executor;
import prominic.sys.tools.SysTools;

@:allow( prominic.sys )
@:allow( prominic.sys.applications )
class VirtualBox extends AbstractApp {

    static final _patternDHCP = new EReg( "(^DHCP:\\h+)", "" );
    static final _patternGUID = new EReg( "(^GUID:\\h+)", "" );
    static final _patternHardwareAddress = new EReg( "(^HardwareAddress:\\h+)", "" );
    static final _patternIPAddress = new EReg( "(^IPAddress:\\h+)", "" );
    static final _patternIPV6Address = new EReg( "(^IPV6Address:\\h+)", "" );
    static final _patternIPV6NetworkMaskPrefixLength = new EReg( "(^IPV6NetworkMaskPrefixLength:\\h+)", "" );
    static final _patternListVMs = ~/^(?:")(\S+)(?:").(?:{)(\S+)(?:})$/gm;
    static final _patternMByte = new EReg( "(\\hMByte)", "" );
    static final _patternMediumType = new EReg( "(^MediumType:\\h+)", "" );
    static final _patternMemoryAvailable = new EReg( "(^Memory available:\\h+)", "" );
    static final _patternMemorySize = new EReg( "(^Memory size:\\h+)", "" );
    static final _patternName = new EReg( "(^Name:\\h+)", "" );
    static final _patternNetworkMask = new EReg( "(^NetworkMask:\\h+)", "" );
    static final _patternProcessorCoreCount = new EReg( "(^Processor core count:\\h+)", "" );
    static final _patternProcessorCount = new EReg( "(^Processor count:\\h+)", "" );
    static final _patternProcessorSupportsHWVirtualization = new EReg( "(^Processor supports HW virtualization:\\h+)", "" );
    static final _patternStatus = new EReg( "(^Status:\\h+)", "" );
    static final _patternVBoxNetworkName = new EReg( "(^VBoxNetworkName:\\h+)", "" );
    static final _patternWireless = new EReg( "(^Wireless:\\h+)", "" );

    static final _patternVMEncryption = ~/^(?:Encryption:)(?:\s+)(\S+)$/gm;
    static final _patternVMMemory = ~/^(?:memory=)(\d+)$/gm;
    static final _patternVMVRam = ~/^(?:vram=)(\d+)$/gm;
    static final _patternCPUExecutionCap = ~/^(?:cpuexecutioncap=)(\d+)$/gm;
    static final _patternCPUs = ~/^(?:cpus=)(\d+)$/gm;
    static final _patternVMState = ~/^(?:VMState=")(.+)(?:")$/gm;
    static final _patternCFGFile = ~/^(?:CfgFile=")(.+)(?:")$/gm;
    static final _patternSnapFldr = ~/^(?:SnapFldr=")(.+)(?:")$/gm;
    static final _patternLogFldr = ~/^(?:LogFldr=")(.+)(?:")$/gm;
    static final _patternDescription = ~/^(?:description=")(.+)(?:")$/gm;
    static final _patternHardwareUUID = ~/^(?:hardwareuuid=")(.+)(?:")$/gm;
    static final _patternOSType = ~/^(?:ostype=")(.+)(?:")$/gm;
    static final _patternPageFusion = ~/^(?:pagefusion=")(.+)(?:")$/gm;
    static final _patternHPET = ~/^(?:hpet=")(.+)(?:")$/gm;
    static final _patternCPUProfile = ~/^(?:cpu-profile=")(.+)(?:")$/gm;
    static final _patternChipset = ~/^(?:chipset=")(.+)(?:")$/gm;
    static final _patternFirmware = ~/^(?:firmware=")(.+)(?:")$/gm;
    static final _patternPAE = ~/^(?:pae=")(.+)(?:")$/gm;
    static final _patternLongmode = ~/^(?:longmode=")(.+)(?:")$/gm;
    static final _patternTripleFaultReset = ~/^(?:triplefaultreset=")(.+)(?:")$/gm;
    static final _patternAPIC = ~/^(?:apic=")(.+)(?:")$/gm;
    static final _patternX2APIC = ~/^(?:x2apic=")(.+)(?:")$/gm;
    static final _patternnestedHWVirt = ~/^(?:nested-hw-virt=")(.+)(?:")$/gm;

    static final _versionPattern = ~/(\d+\.\d+\.\d+)/;

    static var _instance:VirtualBox;

    static public function getInstance():VirtualBox {
        
        if ( _instance == null ) _instance = new VirtualBox();
        return _instance;

    }

    var _bridgedInterfaces:Array<BridgedInterface>;
    var _bridgedInterfacesCollection:ArrayCollection<BridgedInterface>;
    var _hostInfo:HostInfo;
    var _onBridgedInterfaces:ChainedList<(Array<BridgedInterface>)->Void, VirtualBox>;
    var _onHostInfo:ChainedList<(HostInfo)->Void, VirtualBox>;
    var _onListVMs:ChainedList<()->Void, VirtualBox>;
    var _onPowerOffVM:ChainedList<(String)->Void, VirtualBox>;
    var _onShowVMInfo:ChainedList<(String)->Void, VirtualBox>;
    var _onVersion:ChainedList<()->Void, VirtualBox>;
    var _showVMInfoExecutors:Map<String, Executor>;
    var _tempBridgedInterfaceData:String;
    var _tempHostInfoData:String;
    var _tempListVMsData:String;
    var _tempShowVMInfoData:String;
    var _virtualMachines:Array<VirtualMachine>;

    public var hostInfo( get, never ):HostInfo;
    function get_hostInfo() return _hostInfo;

    public var bridgedInterfaces( get, never ):Array<BridgedInterface>;
    function get_bridgedInterfaces() return _bridgedInterfaces;

    public var bridgedInterfacesCollection( get, never ):ArrayCollection<BridgedInterface>;
    function get_bridgedInterfacesCollection() {
        if ( _bridgedInterfacesCollection == null ) _bridgedInterfacesCollection = new ArrayCollection<BridgedInterface>( _bridgedInterfaces );
        return _bridgedInterfacesCollection;
    }

    public var onBridgedInterfaces( get, never ):ChainedList<(Array<BridgedInterface>)->Void, VirtualBox>;
    function get_onBridgedInterfaces() return _onBridgedInterfaces;

    public var onHostInfo( get, never ):ChainedList<(HostInfo)->Void, VirtualBox>;
    function get_onHostInfo() return _onHostInfo;

    public var onListVMs( get, never ):ChainedList<()->Void, VirtualBox>;
    function get_onListVMs() return _onListVMs;

    public var onPowerOffVM( get, never ):ChainedList<(String)->Void, VirtualBox>;
    function get_onPowerOffVM() return _onPowerOffVM;

    public var onShowVMInfo( get, never ):ChainedList<(String)->Void, VirtualBox>;
    function get_onShowVMInfo() return _onShowVMInfo;

    public var onVersion( get, never ):ChainedList<()->Void, VirtualBox>;
    function get_onVersion() return _onVersion;

    public var virtualMachines( get, never ):Array<VirtualMachine>;
    function get_virtualMachines() return _virtualMachines;

    function new() {

        super();

        #if windows
        _executable = "VBoxManage.exe";
        #else
        _executable = "VBoxManage";
        #end
        _name = "VirtualBox";
        _instance = this;

        _onBridgedInterfaces = new ChainedList( this );
        _onHostInfo = new ChainedList( this );
        _onListVMs = new ChainedList( this );
        _onPowerOffVM = new ChainedList( this );
        _onShowVMInfo = new ChainedList( this );
        _onVersion = new ChainedList( this );

        _virtualMachines = [];
        _showVMInfoExecutors = [];
        
        #if windows
        var p = Sys.environment().get( "ProgramFiles");
        if ( p != null ) _pathAdditions.push( '${p}\\Oracle\\VirtualBox' );
        var p = Sys.environment().get( "ProgramFiles(x86)");
        if ( p != null ) _pathAdditions.push( '${p}\\Oracle\\VirtualBox' );
        #end

    }

    public function clone():VirtualBox {

        var v = new VirtualBox();
        v._bridgedInterfaces = _bridgedInterfaces;
        v._hostInfo = _hostInfo;
        v._executable = _executable;
        v._initialized = _initialized;
        v._name = _name;
        v._path = _path;
        v._status = _status;
        v._version = _version;
        return cast v;

    }

    override public function dispose() {

        _bridgedInterfaces = null;
        _bridgedInterfacesCollection = null;
        _hostInfo = null;

        super.dispose();

    }

    public function getBridgedInterfaces():Executor {

        _tempBridgedInterfaceData = "";
        var _bridgedInterfaceExecutor = new Executor( this.path + this._executable, [ "list", "bridgedifs" ]);
        _bridgedInterfaceExecutor.onStop( _bridgedInterfaceExecutorStop ).onStdOut( _bridgedInterfaceExecutorStandardOutput );
        return _bridgedInterfaceExecutor;

    }

    public function getHostInfo():Executor {

        _tempHostInfoData = "";
        var _hostInfoExecutor = new Executor( this.path + this._executable, [ "list", "hostinfo" ]);
        _hostInfoExecutor.onStdOut( _hostInfoExecutorExecutorStandardOutput ).onStop( _hostInfoExecutorExecutorStop );
        return _hostInfoExecutor;

    }

    public function getListVMs():Executor {

        _tempListVMsData = "";
        _virtualMachines = [];
        var _listVMsExecutor = new Executor( this.path + this._executable, [ "list", "vms" ]);
        _listVMsExecutor.onStdOut( _listVMsExecutorStandardOutput ).onStop( _listVMsExecutorStop );
        return _listVMsExecutor;

    }

    public function getPowerOffVM( id:String ):Executor {

        var args:Array<String> = [ "controlvm" ];
        args.push( id );
        args.push( "poweroff" );

        var extraArgs:Array<Dynamic> = [];
        extraArgs.push( id );

        var _powerOffExecutor = new Executor( this.path + this._executable, args, extraArgs );
        _powerOffExecutor.onStop( _powerOffVMExecutorStopped );
        return _powerOffExecutor;

    }

    public function getShowVMInfo( id:String ):Executor {

        //if ( _showVMInfoExecutors.exists( id ) ) return _showVMInfoExecutors.get( id );

        _tempShowVMInfoData = "";

        var args:Array<String> = [ "showvminfo" ];
        args.push( id );
        args.push( "--machinereadable" );

        var extraArgs:Array<Dynamic> = [];
        extraArgs.push( id );

        var _showVMInfoExecutor = new Executor( this.path + this._executable, args, extraArgs );
        _showVMInfoExecutor.onStdOut( _showVMInfoExecutorStandardOutput ).onStop( _showVMInfoExecutorStopped );
        _showVMInfoExecutors.set( id, _showVMInfoExecutor );
        return _showVMInfoExecutor;

    }

    public function getUnregisterVM( id:String, delete:Bool = false ):Executor {

        var args:Array<String> = [ "unregistervm" ];
        if ( delete ) args.push( "--delete" );
        args.push( id );
        var _unregisterExecutor = new Executor( this.path + this._executable, args );
        return _unregisterExecutor;

    }

    public function getVersion():Executor {

        var _versionExecutor = new Executor( this.path + this._executable, [ "-V" ] );
        _versionExecutor.onStop( _versionExecutorStopped ).onStdOut( _versionExecutorStandardOutput );
        return _versionExecutor;

    }

    function _bridgedInterfaceExecutorStandardOutput( executor:AbstractExecutor, data:String ) {

        _tempBridgedInterfaceData += data;

    }

    function _bridgedInterfaceExecutorStop( executor:AbstractExecutor ) {

        _processBridgedInterfacesData();

    }

    function _hostInfoExecutorExecutorStandardOutput( executor:AbstractExecutor, data:String ) {

        _tempHostInfoData += data;

    }

    function _hostInfoExecutorExecutorStop( executor:AbstractExecutor ) {

        _processHostInfoData();

    }

    function _processBridgedInterfacesData() {

        _bridgedInterfaces = [];

        // Adding "Default" interface to the list
        var bi:BridgedInterface = { name: "" };
        _bridgedInterfaces.push( bi );

        var a = _tempBridgedInterfaceData.split( SysTools.lineEnd + SysTools.lineEnd );

        if ( a != null && a.length > 0 ) {

            for ( i in a ) {

                var b = i.split( SysTools.lineEnd );

                var bridgedInterface:BridgedInterface = {};

                if ( b != null && b.length > 0 ) {

                    for ( l in b ) {

                        if ( _patternName.match( l ) ) bridgedInterface.name = _patternName.matchedRight();
                        if ( _patternGUID.match( l ) ) bridgedInterface.guid = _patternGUID.matchedRight();
                        if ( _patternIPAddress.match( l ) ) bridgedInterface.ipaddress = _patternIPAddress.matchedRight();
                        if ( _patternNetworkMask.match( l ) ) bridgedInterface.networkmask = _patternNetworkMask.matchedRight();
                        if ( _patternIPV6Address.match( l ) ) bridgedInterface.ipv6address = _patternIPV6Address.matchedRight();
                        if ( _patternHardwareAddress.match( l ) ) bridgedInterface.hardwareaddress = _patternHardwareAddress.matchedRight();
                        if ( _patternMediumType.match( l ) ) bridgedInterface.mediumtype = _patternMediumType.matchedRight();
                        if ( _patternStatus.match( l ) ) bridgedInterface.status = _patternStatus.matchedRight();
                        if ( _patternVBoxNetworkName.match( l ) ) bridgedInterface.vboxnetworkname = _patternVBoxNetworkName.matchedRight();
                        if ( _patternWireless.match( l ) ) bridgedInterface.wireless = ( _patternWireless.matchedRight() == "Yes" ) ? true : false;
                        if ( _patternIPV6NetworkMaskPrefixLength.match( l ) ) bridgedInterface.ipv6networkmaskprefixlength = Std.parseInt( _patternIPV6NetworkMaskPrefixLength.matchedRight() );
                        if ( _patternDHCP.match( l ) ) bridgedInterface.dhcp = cast _patternDHCP.matchedRight();

                    }

                }

                if ( bridgedInterface.name != null ) _bridgedInterfaces.push( bridgedInterface );

            }

            for ( f in _onBridgedInterfaces ) f( _bridgedInterfaces );

        }

    }

    function _processHostInfoData() {

        _hostInfo = {};

        var a = _tempHostInfoData.split( SysTools.lineEnd );

        if ( a != null && a.length > 0 ) {

            for ( l in a ) {

                if ( _patternProcessorCount.match( l ) ) _hostInfo.processorcount = Std.parseInt( _patternProcessorCount.matchedRight() );
                if ( _patternProcessorCoreCount.match( l ) ) _hostInfo.processorcorecount = Std.parseInt( _patternProcessorCoreCount.matchedRight() );
                if ( _patternProcessorSupportsHWVirtualization.match( l ) ) _hostInfo.supportshardwarevirtualization = ( _patternProcessorSupportsHWVirtualization.matchedRight().toLowerCase() == "yes" ) ? true : false;

                if ( _patternMemorySize.match( l ) ) {

                    if ( _patternMByte.match( _patternMemorySize.matchedRight() ) ) {

                        _hostInfo.memorysize = Std.parseFloat( _patternMByte.matchedLeft() );

                    }

                }

                if ( _patternMemoryAvailable.match( l ) ) {

                    if ( _patternMByte.match( _patternMemoryAvailable.matchedRight() ) ) {

                        _hostInfo.memoryavailable = Std.parseFloat( _patternMByte.matchedLeft() );

                    }

                }

            }

            for ( f in _onHostInfo ) f( _hostInfo );

        }

    }

    function _versionExecutorStandardOutput( executor:AbstractExecutor, data:String ) {

        var a = data.split( SysTools.lineEnd );

        if ( data.length > 0 && a.length > 0 ) {

            if ( _versionPattern.match( a[ 0 ] ) ) {

                this._version = _versionPattern.matched( 0 );

                for ( f in _onVersion ) f();

            }

        }

    }

    function _versionExecutorStopped( executor:AbstractExecutor ) {
        
        executor.dispose();

    }

    function _powerOffVMExecutorStopped( executor:AbstractExecutor ) {

        for ( f in _onPowerOffVM ) f( executor.extraParams[ 0 ] );

    }

    function _showVMInfoExecutorStandardOutput( executor:AbstractExecutor, data:String ) {

        _tempShowVMInfoData += data;

    }

    function _showVMInfoExecutorStopped( executor:AbstractExecutor ) {

        if ( executor.exitCode == 0 )
            _processShowVMInfoData( executor.extraParams[ 0 ] );

        _showVMInfoExecutors.remove( executor.extraParams[ 0 ] );

    }

    function _listVMsExecutorStandardOutput( executor:AbstractExecutor, data:String ) {

        _tempListVMsData += data;

    }

    function _listVMsExecutorStop( executor:AbstractExecutor ) {

        _processListVMsData();
        
    }

    function _processListVMsData() {

        var a = _tempListVMsData.split( SysTools.lineEnd );

        if ( a != null && a.length > 0 ) {

            for ( l in a ) {

                if ( _patternListVMs.match( l ) ) {

                    var vm:VirtualMachine = {};
                    vm.name = _patternListVMs.matched( 1 );
                    vm.id = _patternListVMs.matched( 2 );
                    _virtualMachines.push( vm );

                }

            for ( f in _onListVMs ) f();

            }

        }

    }

    function _processShowVMInfoData( id:String ) {

        var currentMachine:VirtualMachine = null;
        for ( m in _virtualMachines ) if ( m.name == id || m.id == id ) currentMachine = m;

        var a = _tempShowVMInfoData.split( SysTools.lineEnd );

        if ( currentMachine != null && a != null && a.length > 0 ) {

            for ( l in a ) {

                if ( _patternVMEncryption.match( l ) )
                    currentMachine.encryption = _patternVMEncryption.matched( 1 ).toLowerCase() == "enabled";

                if ( _patternVMMemory.match( l ) )
                    currentMachine.memory = Std.parseInt( _patternVMMemory.matched( 1 ) );

                if ( _patternVMVRam.match( l ) )
                    currentMachine.vram = Std.parseInt( _patternVMVRam.matched( 1 ) );

                if ( _patternCPUExecutionCap.match( l ) )
                    currentMachine.cpuexecutioncap = Std.parseInt( _patternCPUExecutionCap.matched( 1 ) );

                if ( _patternCPUs.match( l ) )
                    currentMachine.cpus = Std.parseInt( _patternCPUs.matched( 1 ) );

                if ( _patternVMState.match( l ) )
                    currentMachine.VMState = _patternVMState.matched( 1 );

                if ( _patternCFGFile.match( l ) ) {
                    currentMachine.CfgFile = _patternCFGFile.matched( 1 );
                    currentMachine.root = Path.directory( currentMachine.CfgFile );
                }

                if ( _patternSnapFldr.match( l ) )
                    currentMachine.SnapFldr = _patternSnapFldr.matched( 1 );

                if ( _patternLogFldr.match( l ) )
                    currentMachine.LogFldr = _patternLogFldr.matched( 1 );

                if ( _patternDescription.match( l ) )
                    currentMachine.description = _patternDescription.matched( 1 );

                if ( _patternHardwareUUID.match( l ) )
                    currentMachine.hardwareuuid = _patternHardwareUUID.matched( 1 );

                if ( _patternOSType.match( l ) )
                    currentMachine.ostype = _patternOSType.matched( 1 );

                if ( _patternPageFusion.match( l ) )
                    currentMachine.pagefusion = _patternPageFusion.matched( 1 );

                if ( _patternHPET.match( l ) )
                    currentMachine.hpet = _patternHPET.matched( 1 );

                if ( _patternCPUProfile.match( l ) )
                    currentMachine.cpuprofile = _patternCPUProfile.matched( 1 );

                if ( _patternChipset.match( l ) )
                    currentMachine.chipset = _patternChipset.matched( 1 );

                if ( _patternFirmware.match( l ) )
                    currentMachine.firmware = _patternFirmware.matched( 1 );

                if ( _patternPAE.match( l ) )
                    currentMachine.pae = _patternPAE.matched( 1 );

                if ( _patternLongmode.match( l ) )
                    currentMachine.longmode = _patternLongmode.matched( 1 );

                if ( _patternTripleFaultReset.match( l ) )
                    currentMachine.triplefaultreset = _patternTripleFaultReset.matched( 1 );

                if ( _patternAPIC.match( l ) )
                    currentMachine.apic = _patternAPIC.matched( 1 );

                if ( _patternX2APIC.match( l ) )
                    currentMachine.x2apic = _patternX2APIC.matched( 1 );

                if ( _patternnestedHWVirt.match( l ) )
                    currentMachine.nestedhwvirt = _patternnestedHWVirt.matched( 1 );

            }

        }

        for ( f in _onShowVMInfo ) f( id );

    }

}