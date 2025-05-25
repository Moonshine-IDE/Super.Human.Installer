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

package prominic.sys.applications.utm;

import champaign.core.ds.ChainedList;
import champaign.core.logging.Logger;
import prominic.helpers.PListUtil;
import prominic.sys.applications.AbstractApp;
import prominic.sys.applications.bin.Shell;
import prominic.sys.io.AbstractExecutor;
import prominic.sys.io.Executor;
import prominic.sys.io.ExecutorManager;
import prominic.sys.tools.SysTools;

using Lambda;

@:allow( prominic.sys )
@:allow( prominic.sys.applications )
class UTM extends AbstractApp {

    static final _patternListVMs = ~/^(\S+)\s+\((.+)\)$/gm;
    static final _versionPattern = ~/(\d+\.\d+\.\d+)/;

    static var _instance:UTM;

    static public function getInstance():UTM {
        
        if ( _instance == null ) _instance = new UTM();
        return _instance;

    }

    var _onListVMs:ChainedList<()->Void, UTM>;
    var _onPowerOffVM:ChainedList<(UTMMachine)->Void, UTM>;
    var _onVersion:ChainedList<()->Void, UTM>;
    var _tempListVMsData:String;
    var _utmMachines:Array<UTMMachine>;

    public var onListVMs( get, never ):ChainedList<()->Void, UTM>;
    function get_onListVMs() return _onListVMs;

    public var onPowerOffVM( get, never ):ChainedList<(UTMMachine)->Void, UTM>;
    function get_onPowerOffVM() return _onPowerOffVM;

    public var onVersion( get, never ):ChainedList<()->Void, UTM>;
    function get_onVersion() return _onVersion;

    public var utmMachines( get, never ):Array<UTMMachine>;
    function get_utmMachines() return _utmMachines;

    function new() {

        super();

        _executable = "utmctl";
        _name = "UTM";
        _instance = this;

        _onListVMs = new ChainedList( this );
        _onPowerOffVM = new ChainedList( this );
        _onVersion = new ChainedList( this );

        _utmMachines = [];
        
        // Add path for UTM command-line tool
        _pathAdditions.push( "/Applications/UTM.app/Contents/MacOS" );
        _pathAdditions.push( "/usr/local/bin" );
    }

    public function clone():UTM {

        var v = new UTM();
        v._executable = _executable;
        v._initialized = _initialized;
        v._name = _name;
        v._path = _path;
        v._status = _status;
        v._version = _version;
        return cast v;

    }

    override public function dispose() {

        _utmMachines = null;
        super.dispose();

    }

    public function getListVMs():AbstractExecutor {

        // Return the already running executor if it exists
        if ( ExecutorManager.getInstance().exists( UTMExecutorContext.ListVMs ) )
            return ExecutorManager.getInstance().get( UTMExecutorContext.ListVMs );

        _tempListVMsData = "";
        _utmMachines = [];
        var args:Array<String> = [ "list" ];

        final executor = new Executor( this.path + this._executable, args );
        executor.onStdOut.add( _listVMsExecutorStandardOutput ).onStop.add( _listVMsExecutorStopped );
        ExecutorManager.getInstance().set( UTMExecutorContext.ListVMs, executor );
        return executor;

    }

    public function getPowerOffVM( machine:UTMMachine, force:Bool = false ):AbstractExecutor {

        // Return the already running executor if it exists
        if ( ExecutorManager.getInstance().exists( '${UTMExecutorContext.PowerOffVM}${machine.name}' ) )
            return ExecutorManager.getInstance().get( '${UTMExecutorContext.PowerOffVM}${machine.name}' );

        var args:Array<String> = [ "stop" ];
        if (machine.name != null) {
            args.push( machine.name );
        }
        
        if (force) {
            args.push( "--force" );
        }

        var extraArgs:Array<Dynamic> = [];
        extraArgs.push( machine );

        final executor = new Executor( this.path + this._executable, args, extraArgs );
        executor.onStop.add( _powerOffVMExecutorStopped );
        ExecutorManager.getInstance().set( '${UTMExecutorContext.PowerOffVM}${machine.name}', executor );
        return executor;

    }

    public function startVM( machine:UTMMachine ):AbstractExecutor {

        // Return the already running executor if it exists
        if ( ExecutorManager.getInstance().exists( '${UTMExecutorContext.StartVM}${machine.name}' ) )
            return ExecutorManager.getInstance().get( '${UTMExecutorContext.StartVM}${machine.name}' );

        var args:Array<String> = [ "start" ];
        if (machine.name != null) {
            args.push( machine.name );
        }

        var extraArgs:Array<Dynamic> = [];
        extraArgs.push( machine );

        final executor = new Executor( this.path + this._executable, args, extraArgs );
        executor.onStop.add( _startVMExecutorStopped );
        ExecutorManager.getInstance().set( '${UTMExecutorContext.StartVM}${machine.name}', executor );
        return executor;

    }

    public function getVersion():AbstractExecutor {

        // Return the already running executor if it exists
        if ( ExecutorManager.getInstance().exists( UTMExecutorContext.Version ) )
            return ExecutorManager.getInstance().get( UTMExecutorContext.Version );

        // Create a minimal executor that will just trigger the version event
        final executor = new Executor( this.path + this._executable, [ "list" ] );
        executor.onStop.add( _versionExecutorStopped );
        ExecutorManager.getInstance().set( UTMExecutorContext.Version, executor );
        
        // Read the UTM version directly from the Info.plist file
        try {
            var plistPath = "/Applications/UTM.app/Contents/Info.plist";
            Logger.info('${this}: Attempting to read plist from ${plistPath}');
            
            var plist = PListUtil.readFromFile(plistPath);
            if (plist != null) {
                Logger.info('${this}: Successfully read plist file');
                
                // Try different approaches to get the version
                // 1. Using the typed PListEntryId
                var versionEntry = plist.get(PListEntryId.CFBundleShortVersionString);
                if (versionEntry != null) {
                    this._version = versionEntry.value;
                    Logger.info('${this}: Found UTM version from plist using PListEntryId: ${this._version}');
                } else {
                    // 2. Try using string directly as fallback
                    try {
                        var stringKeyEntry = plist.get("CFBundleShortVersionString");
                        if (stringKeyEntry != null) {
                            this._version = stringKeyEntry.value;
                            Logger.info('${this}: Found UTM version from plist using string key: ${this._version}');
                        } else {
                            Logger.warning('${this}: CFBundleShortVersionString not found in plist');
                        }
                    } catch (e) {
                        Logger.error('${this}: Error getting version with string key: ${e}');
                    }
                }
                
                // Additional debug output
                try {
                    // Log all keys for debugging
                    Logger.info('${this}: Plist contents: ${plist}');
                } catch (e) {
                    Logger.error('${this}: Error logging plist: ${e}');
                }
            } else {
                Logger.error('${this}: Plist file could not be read from ${plistPath}');
            }
        } catch (e) {
            Logger.error('${this}: Error reading UTM version from plist: ${e}');
        }
        
        return executor;
    }

    public function getVirtualMachineByName( name:String ):UTMMachine {

        for ( m in _utmMachines ) if ( m.name == name ) return m;
        return null;

    }

    public function openGUI() {

        Logger.info( '${this}: Opening GUI' );
        Shell.getInstance().open( [ "-a", "UTM" ] );

    }

    public override function toString():String {

        return '[UTM]';

    }


    function _versionExecutorStopped( executor:AbstractExecutor ) {
        
        Logger.info( '${this}: _versionExecutorStopped(): ${executor.exitCode}' );

        for ( f in _onVersion ) f();

        ExecutorManager.getInstance().remove( UTMExecutorContext.Version );

        executor.dispose();

    }

    function _powerOffVMExecutorStopped( executor:AbstractExecutor ) {

        Logger.info( '${this}: powerOffVMExecutor stopped with exitCode: ${executor.exitCode}' );

        for ( f in _onPowerOffVM ) f( executor.extraParams[ 0 ] );

        ExecutorManager.getInstance().remove( '${UTMExecutorContext.PowerOffVM}${executor.extraParams[ 0 ].name}' );

        executor.dispose();

    }

    function _startVMExecutorStopped( executor:AbstractExecutor ) {

        Logger.info( '${this}: startVMExecutor stopped with exitCode: ${executor.exitCode}' );

        // Refresh VM list after starting a VM
        getListVMs().execute();

        ExecutorManager.getInstance().remove( '${UTMExecutorContext.StartVM}${executor.extraParams[ 0 ].name}' );

        executor.dispose();

    }

    function _listVMsExecutorStandardOutput( executor:AbstractExecutor, data:String ) {

        _tempListVMsData += data;

    }

    function _listVMsExecutorStopped( executor:AbstractExecutor ) {

        Logger.info( '${this}: listVMsExecutor stopped with exit code: ${executor.exitCode}' );

        if ( executor.exitCode == 0 ) {

            _utmMachines = [];
            _processListVMsData();

        }

        for ( f in _onListVMs ) f();

        ExecutorManager.getInstance().remove( UTMExecutorContext.ListVMs );

        executor.dispose();

    }

    function _processListVMsData() {

        var lines = _tempListVMsData.split(SysTools.lineEnd);

        for (line in lines) {
            line = StringTools.trim(line);
            if (line.length == 0) continue;

            // Parse VM name and status
            // Example format: "VM Name (running)" or "VM Name (stopped)"
            var parts = line.split(" (");
            if (parts.length >= 2) {
                var name = parts[0];
                var status = parts[1].substring(0, parts[1].length - 1); // Remove trailing ")"

                var vm:UTMMachine = {
                    name: name,
                    status: status
                };
                _utmMachines.push(vm);
            }
        }
    }
}

enum abstract UTMExecutorContext( String ) to String {

    var ListVMs = "UTM_ListVMs";
    var PowerOffVM = "UTM_PowerOffVM_";
    var StartVM = "UTM_StartVM_";
    var Version = "UTM_Version";

}
