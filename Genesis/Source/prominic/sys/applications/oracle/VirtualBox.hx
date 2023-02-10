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
import prominic.logging.Logger;
import prominic.sys.applications.bin.Shell;
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
    static final _patternListVMs = ~/^(?:")(.+)(?:").(?:{)(\S+)(?:})$/gm;
    static final _patternListVMsLong = ~/^Name:(?s:.+?)(?=Name:)/gms;
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

    static final _patternName2 = ~/^(?:Name:)(?:\s+)(.+)$/gm;
    static final _patternVMEncryption2 = ~/^(?:Encryption:)(?:\s+)(\S+)$/gm;
    static final _patternVMMemory2 = ~/^(?:Memory size:)(?:\s)*(\d+)(?:..)$/gm;
    static final _patternVMVRam2 = ~/^(?:VRAM size:)(?:\s*)(\d+)(?:..)$/gm;
    static final _patternCPUExecutionCap2 = ~/^(?:CPU exec cap:)(?:\s)*(\d+)(?:%)$/gm;
    static final _patternCPUs2 = ~/^(?:Number of CPUs:)(?:\s)*(\d+)$/gm;
    static final _patternVMState2 = ~/^(?:State:)(?:\s)*(.+)(?:.\(since.)(.+)(?:\))$/gm;
    static final _patternCFGFile2 = ~/^(?:Config file:)(?:\s+)(.+)$/gm;
    static final _patternSnapFldr2 = ~/^(?:Snapshot folder:)(?:\s+)(.+)$/gm;
    static final _patternLogFldr2 = ~/^(?:Log folder:)(?:\s+)(.+)$/gm;
    static final _patternHardwareUUID2 = ~/^(?:Hardware UUID:)(?:\s+)(.+)$/gm;
    static final _patternOSType2 = ~/^(?:Guest OS:)(?:\s+)(.+)$/gm;
    static final _patternPageFusion2 = ~/^(?:Page Fusion:)(?:\s+)(.+)$/gm;
    static final _patternHPET2 = ~/^(?:HPET:)(?:\s+)(.+)$/gm;
    static final _patternCPUProfile2 = ~/^(?:CPUProfile:)(?:\s+)(.+)$/gm;
    static final _patternChipset2 = ~/^(?:Chipset:)(?:\s+)(.+)$/gm;
    static final _patternFirmware2 = ~/^(?:Firmware:)(?:\s+)(.+)$/gm;
    static final _patternPAE2 = ~/^(?:PAE:)(?:\s+)(.+)$/gm;
    static final _patternLongmode2 = ~/^(?:Long Mode:)(?:\s+)(.+)$/gm;
    static final _patternTripleFaultReset2 = ~/^(?:Triple Fault Reset:)(?:\s+)(.+)$/gm;
    static final _patternAPIC2 = ~/^(?:APIC:)(?:\s+)(.+)$/gm;
    static final _patternX2APIC2 = ~/^(?:X2APIC:)(?:\s+)(.+)$/gm;
    static final _patternnestedHWVirt2 = ~/^(?:Nested VT-x\/AMD-V:)(?:\s+)(.+)$/gm;

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
    var _virtualBoxMachines:Array<VirtualBoxMachine>;

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

    public var virtualBoxMachines( get, never ):Array<VirtualBoxMachine>;
    function get_virtualBoxMachines() return _virtualBoxMachines;

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

        _virtualBoxMachines = [];
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

    public function getListVMs( longFormat:Bool = false ):Executor {

        _tempListVMsData = "";
        _virtualBoxMachines = [];
        var args:Array<String> = [ "list", "vms" ];
        if ( longFormat ) args.push( "--long" );
        var _listVMsExecutor = new Executor( this.path + this._executable, args, null, null, null, [ longFormat ] );
        _listVMsExecutor.onStdOut( _listVMsExecutorStandardOutput ).onStop( _listVMsExecutorStopped );
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

    public function getShowVMInfo( id:String, ?machineReadable:Bool ):Executor {

        //if ( _showVMInfoExecutors.exists( id ) ) return _showVMInfoExecutors.get( id );

        _tempShowVMInfoData = "";

        var args:Array<String> = [ "showvminfo" ];
        args.push( id );
        if ( machineReadable ) args.push( "--machinereadable" );

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

    public function getVirtualMachineById( id:String ):VirtualBoxMachine {

        for ( m in _virtualBoxMachines ) if ( m.virtualBoxId == id ) return m;
        return null;

    }

    public function openGUI() {

        Logger.verbose( '${this}: Opening GUI' );

        #if mac
        Shell.getInstance().open( [ "-a", "VirtualBox" ] );
        #elseif windows
        Shell.getInstance().open( [ "VirtualBox" ] );
        #elseif linux
        Shell.getInstance().exec( '${this._path}VirtualBox' );
        #end

    }

    public override function toString():String {

        return '[VirtualBox]';

    }

    function _bridgedInterfaceExecutorStandardOutput( executor:AbstractExecutor, data:String ) {

        _tempBridgedInterfaceData += data;

    }

    function _bridgedInterfaceExecutorStop( executor:AbstractExecutor ) {

        Logger.verbose( '${this}: bridgedInterfaceExecutor stopped with exit code: ${executor.exitCode}, data:${_tempBridgedInterfaceData}' );

        if ( executor.exitCode == 0 )
            _processBridgedInterfacesData();

    }

    function _hostInfoExecutorExecutorStandardOutput( executor:AbstractExecutor, data:String ) {

        _tempHostInfoData += data;

    }

    function _hostInfoExecutorExecutorStop( executor:AbstractExecutor ) {

        Logger.verbose( '${this}: hostInfoExecutor stopped with exit code: ${executor.exitCode}, data: ${_tempHostInfoData}' );

        if ( executor.exitCode == 0 )
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

                try {

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

                } catch ( e ) {

                    Logger.error( 'RegExp processing failed with ${b}' );

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

                try {

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

                } catch ( e ) {

                    Logger.error( 'RegExp processing failed with ${l}' );

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

        Logger.verbose( '${this}: showVMInfoExecutor stopped with exit code: ${executor.exitCode}' );
        
        if ( executor.exitCode == 0 )
            _processShowVMInfoLongFormatData( executor.extraParams[ 0 ] );

        _showVMInfoExecutors.remove( executor.extraParams[ 0 ] );

        for ( f in _onShowVMInfo ) f( executor.extraParams[ 0 ] );

    }

    function _listVMsExecutorStandardOutput( executor:AbstractExecutor, data:String ) {

        _tempListVMsData += data;

    }

    function _listVMsExecutorStopped( executor:AbstractExecutor ) {

        Logger.verbose( '${this}: listVMsExecutor stopped with exit code: ${executor.exitCode}' );

        if ( executor.exitCode == 0 ) {

            _virtualBoxMachines = [];

            if ( ( executor.extraParams[ 0 ] != null && executor.extraParams[ 0 ] == true ) ) {

                _processListVMsLongFormatData();

            } else {

                _processListVMsData();

            }

        }

        for ( f in _onListVMs ) f();

    }

    function _processListVMsData() {

        var a = _tempListVMsData.split( SysTools.lineEnd );

        if ( a != null && a.length > 0 ) {

            for ( l in a ) {

                try {

                    if ( _patternListVMs.match( l ) ) {

                        var vm:VirtualBoxMachine = {};
                        vm.name = _patternListVMs.matched( 1 );
                        vm.virtualBoxId = _patternListVMs.matched( 2 );
                        _virtualBoxMachines.push( vm );

                    }

                } catch ( e ) {

                    Logger.error( 'RegExp processing failed with ${l}' );

                }

            }

        }

    }

    function _processListVMsLongFormatData() {

        var machineBlocks = _tempListVMsData.split( SysTools.lineEnd + SysTools.lineEnd );

        if ( machineBlocks != null && machineBlocks.length > 0 ) {

            for ( block in machineBlocks ) {

                if ( block.length > 0 ) {

                    var currentMachine:VirtualBoxMachine = {};

                    var lines = block.split( SysTools.lineEnd );

                    if ( lines != null && lines.length > 0 ) {

                        for ( l in lines ) {

                            try {

                                if ( _patternName2.match( l ) )
                                    currentMachine.name = _patternName2.matched( 1 );
            
                                if ( _patternVMEncryption2.match( l ) )
                                    currentMachine.encryption = _patternVMEncryption2.matched( 1 ).toLowerCase() == "enabled";
            
                                if ( _patternVMMemory2.match( l ) )
                                    currentMachine.memory = Std.parseInt( _patternVMMemory2.matched( 1 ) );
            
                                if ( _patternVMVRam2.match( l ) )
                                    currentMachine.vram = Std.parseInt( _patternVMVRam2.matched( 1 ) );
            
                                if ( _patternCPUExecutionCap2.match( l ) )
                                    currentMachine.cpuexecutioncap = Std.parseInt( _patternCPUExecutionCap2.matched( 1 ) );
            
                                if ( _patternCPUs2.match( l ) )
                                    currentMachine.cpus = Std.parseInt( _patternCPUs2.matched( 1 ) );
            
                                if ( _patternVMState2.match( l ) )
                                    currentMachine.virtualBoxState = _patternVMState2.matched( 1 );
            
                                if ( _patternCFGFile2.match( l ) ) {
                                    currentMachine.CfgFile = Path.normalize( _patternCFGFile2.matched( 1 ) );
                                    currentMachine.root = Path.directory( currentMachine.CfgFile );
                                }
            
                                if ( _patternSnapFldr2.match( l ) )
                                    currentMachine.SnapFldr = Path.normalize( _patternSnapFldr2.matched( 1 ) );
            
                                if ( _patternLogFldr2.match( l ) )
                                    currentMachine.LogFldr = Path.normalize( _patternLogFldr2.matched( 1 ) );
            
                                if ( _patternHardwareUUID2.match( l ) )
                                    currentMachine.hardwareuuid = _patternHardwareUUID2.matched( 1 );
            
                                if ( _patternOSType2.match( l ) )
                                    currentMachine.ostype = _patternOSType2.matched( 1 );
            
                                if ( _patternPageFusion2.match( l ) )
                                    currentMachine.pagefusion = _patternPageFusion2.matched( 1 );
            
                                if ( _patternHPET2.match( l ) )
                                    currentMachine.hpet = _patternHPET2.matched( 1 );
            
                                if ( _patternCPUProfile2.match( l ) )
                                    currentMachine.cpuprofile = _patternCPUProfile2.matched( 1 );
            
                                if ( _patternChipset2.match( l ) )
                                    currentMachine.chipset = _patternChipset2.matched( 1 );
            
                                if ( _patternFirmware2.match( l ) )
                                    currentMachine.firmware = _patternFirmware2.matched( 1 );
            
                                if ( _patternPAE2.match( l ) )
                                    currentMachine.pae = _patternPAE2.matched( 1 );
            
                                if ( _patternLongmode2.match( l ) )
                                    currentMachine.longmode = _patternLongmode2.matched( 1 );
            
                                if ( _patternTripleFaultReset2.match( l ) )
                                    currentMachine.triplefaultreset = _patternTripleFaultReset2.matched( 1 );
            
                                if ( _patternAPIC2.match( l ) )
                                    currentMachine.apic = _patternAPIC2.matched( 1 );
            
                                if ( _patternX2APIC2.match( l ) )
                                    currentMachine.x2apic = _patternX2APIC2.matched( 1 );
            
                                if ( _patternnestedHWVirt2.match( l ) )
                                    currentMachine.nestedhwvirt = _patternnestedHWVirt2.matched( 1 );
            
                            } catch( e ) {
            
                                Logger.error( 'RegExp processing failed with ${l}' );
            
                            }

                        }

                        _virtualBoxMachines.push( currentMachine );

                    }

                }
                
            }

        }

    }

    function _processShowVMInfoData( id:String ) {

        var currentMachine:VirtualBoxMachine = null;
        for ( m in _virtualBoxMachines ) if ( m.name == id || m.virtualBoxId == id ) currentMachine = m;

        var a = _tempShowVMInfoData.split( SysTools.lineEnd );

        if ( currentMachine != null && a != null && a.length > 0 ) {

            for ( l in a ) {

                try {

                    if ( _patternName.match( l ) )
                        currentMachine.name = currentMachine.virtualBoxId = _patternName.matched( 1 );

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
                        currentMachine.virtualBoxState = _patternVMState.matched( 1 );

                    if ( _patternCFGFile.match( l ) ) {
                        currentMachine.CfgFile = Path.normalize( _patternCFGFile.matched( 1 ) );
                        currentMachine.root = Path.directory( currentMachine.CfgFile );
                    }

                    if ( _patternSnapFldr.match( l ) )
                        currentMachine.SnapFldr = Path.normalize( _patternSnapFldr.matched( 1 ) );

                    if ( _patternLogFldr.match( l ) )
                        currentMachine.LogFldr = Path.normalize( _patternLogFldr.matched( 1 ) );

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

                } catch( e ) {

                    Logger.error( 'RegExp processing failed with ${l}' );

                }

            }

        }

    }

    function _processShowVMInfoLongFormatData( id:String ) {

        final currentMachine:VirtualBoxMachine = {};

        if ( currentMachine != null && _tempShowVMInfoData.length > 0 ) {

            var lines = _tempShowVMInfoData.split( SysTools.lineEnd );

            if ( lines != null && lines.length > 0 ) {

                for ( l in lines ) {

                    try {

                        if ( _patternName2.match( l ) )
                            currentMachine.name = currentMachine.virtualBoxId = _patternName2.matched( 1 );
    
                        if ( _patternVMEncryption2.match( l ) )
                            currentMachine.encryption = _patternVMEncryption2.matched( 1 ).toLowerCase() == "enabled";
    
                        if ( _patternVMMemory2.match( l ) )
                            currentMachine.memory = Std.parseInt( _patternVMMemory2.matched( 1 ) );
    
                        if ( _patternVMVRam2.match( l ) )
                            currentMachine.vram = Std.parseInt( _patternVMVRam2.matched( 1 ) );
    
                        if ( _patternCPUExecutionCap2.match( l ) )
                            currentMachine.cpuexecutioncap = Std.parseInt( _patternCPUExecutionCap2.matched( 1 ) );
    
                        if ( _patternCPUs2.match( l ) )
                            currentMachine.cpus = Std.parseInt( _patternCPUs2.matched( 1 ) );
    
                        if ( _patternVMState2.match( l ) )
                            currentMachine.virtualBoxState = _patternVMState2.matched( 1 );
    
                        if ( _patternCFGFile2.match( l ) ) {
                            currentMachine.CfgFile = Path.normalize( _patternCFGFile2.matched( 1 ) );
                            currentMachine.root = Path.directory( currentMachine.CfgFile );
                        }
    
                        if ( _patternSnapFldr2.match( l ) )
                            currentMachine.SnapFldr = Path.normalize( _patternSnapFldr2.matched( 1 ) );
    
                        if ( _patternLogFldr2.match( l ) )
                            currentMachine.LogFldr = Path.normalize( _patternLogFldr2.matched( 1 ) );
    
                        if ( _patternHardwareUUID2.match( l ) )
                            currentMachine.hardwareuuid = _patternHardwareUUID2.matched( 1 );
    
                        if ( _patternOSType2.match( l ) )
                            currentMachine.ostype = _patternOSType2.matched( 1 );
    
                        if ( _patternPageFusion2.match( l ) )
                            currentMachine.pagefusion = _patternPageFusion2.matched( 1 );
    
                        if ( _patternHPET2.match( l ) )
                            currentMachine.hpet = _patternHPET2.matched( 1 );
    
                        if ( _patternCPUProfile2.match( l ) )
                            currentMachine.cpuprofile = _patternCPUProfile2.matched( 1 );
    
                        if ( _patternChipset2.match( l ) )
                            currentMachine.chipset = _patternChipset2.matched( 1 );
    
                        if ( _patternFirmware2.match( l ) )
                            currentMachine.firmware = _patternFirmware2.matched( 1 );
    
                        if ( _patternPAE2.match( l ) )
                            currentMachine.pae = _patternPAE2.matched( 1 );
    
                        if ( _patternLongmode2.match( l ) )
                            currentMachine.longmode = _patternLongmode2.matched( 1 );
    
                        if ( _patternTripleFaultReset2.match( l ) )
                            currentMachine.triplefaultreset = _patternTripleFaultReset2.matched( 1 );
    
                        if ( _patternAPIC2.match( l ) )
                            currentMachine.apic = _patternAPIC2.matched( 1 );
    
                        if ( _patternX2APIC2.match( l ) )
                            currentMachine.x2apic = _patternX2APIC2.matched( 1 );
    
                        if ( _patternnestedHWVirt2.match( l ) )
                            currentMachine.nestedhwvirt = _patternnestedHWVirt2.matched( 1 );
    
                    } catch( e ) {
    
                        Logger.error( 'RegExp processing failed with ${l}' );
    
                    }

                }

            }

        }

        for ( m in _virtualBoxMachines ) {

            if ( m.name == id || m.virtualBoxId == id ) {
                
                _virtualBoxMachines.remove( m );
                break;

            }

        }

        _virtualBoxMachines.push( currentMachine );

    }

}