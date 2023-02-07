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

package prominic.sys.applications.hashicorp;

import prominic.core.ds.ChainedList;
import prominic.logging.Logger;
import prominic.sys.applications.bin.Shell;
import prominic.sys.io.AbstractExecutor;
import prominic.sys.io.Executor;
import prominic.sys.tools.SysTools;
import sys.io.File;
import sys.thread.Mutex;

@:allow( prominic.sys )
@:allow( prominic.sys.applications )
class Vagrant extends AbstractApp {

    //static final _machineReadPattern = ~/(\d+,\w*,(\w|-)+,(\w|-|\/|\\|\.)*,*(.)+)/gm;
    static final _machineReadPattern = ~/((\d+),(.*),(.+),(.+))/gm;
    static final _machineReadPatternForStatus = ~/(\d+,.*,(\w|-)+,(\w|-|\/|\\|\.)*,*(.)+)/gm;
    static final _versionPattern = ~/(\d+\.\d+\.\d+)/;
    static final _SSH_SCRIPT:String = "ssh.sh";

    static var _instance:Vagrant;

    static public function getInstance():Vagrant {
        
        if ( _instance == null ) _instance = new Vagrant();
        return _instance;

    }

    var _currentMachine:VagrantMachine;
    var _currentWorkingDir:String;
    var _destroyExecutors:Map<VagrantMachine, Executor>;
    var _globalStatusExecutor:Executor;
    var _haltExecutors:Map<VagrantMachine, Executor>;
    var _initExecutors:Map<String, Executor>;
    var _machines:Array<VagrantMachine>;
    var _metadata:VagrantMetadata;
    var _numExecutors:Int;
    var _onDestroy:ChainedList<(VagrantMachine)->Void, Vagrant>;
    var _onGlobalStatus:ChainedList<()->Void, Vagrant>;
    var _onHalt:ChainedList<(VagrantMachine)->Void, Vagrant>;
    var _onInitMachine:ChainedList<(String)->Void, Vagrant>;
    var _onProvision:ChainedList<(VagrantMachine)->Void, Vagrant>;
    var _onRSync:ChainedList<(VagrantMachine)->Void, Vagrant>;
    var _onStatus:ChainedList<(VagrantMachine)->Void, Vagrant>;
    var _onStopAll:ChainedList<()->Void, Vagrant>;
    var _onUp:ChainedList<(VagrantMachine, Float)->Void, Vagrant>;
    var _onVersion:ChainedList<()->Void, Vagrant>;
    var _provisionExecutors:Map<VagrantMachine, Executor>;
    var _rsyncExecutors:Map<VagrantMachine, Executor>;
    var _statusExecutors:Map<VagrantMachine, Executor>;
    var _stopAllFinished:Bool = false;
    var _tempGlobalStatusData:String;
    var _upExecutors:Map<VagrantMachine, Executor>;
    var _vagrantFilename:String;
    var _versionExecutor:Executor;

    var _mutexGlobalStatusStderr:Mutex;
    var _mutexGlobalStatusStdout:Mutex;
    var _mutexGlobalStatusStop:Mutex;

    public var currentWorkingDir( get, set ):String;
    function get_currentWorkingDir() return _currentWorkingDir;
    function set_currentWorkingDir( value:String ):String {
        if ( value == _currentWorkingDir ) return value;
        _currentWorkingDir = value;
        Sys.putEnv( 'VAGRANT_CWD', _currentWorkingDir );
        return _currentWorkingDir;
    }

    public var onDestroy( get, never ):ChainedList<(VagrantMachine)->Void, Vagrant>;
    function get_onDestroy() return _onDestroy;

    public var onGlobalStatus( get, never ):ChainedList<()->Void, Vagrant>;
    function get_onGlobalStatus() return _onGlobalStatus;

    public var onHalt( get, never ):ChainedList<(VagrantMachine)->Void, Vagrant>;
    function get_onHalt() return _onHalt;

    public var onInitMachine( get, never ):ChainedList<(String)->Void, Vagrant>;
    function get_onInitMachine() return _onInitMachine;

    public var onProvision( get, never ):ChainedList<(VagrantMachine)->Void, Vagrant>;
    function get_onProvision() return _onProvision;

    public var onRSync( get, never ):ChainedList<(VagrantMachine)->Void, Vagrant>;
    function get_onRSync() return _onRSync;

    public var onStatus( get, never ):ChainedList<(VagrantMachine)->Void, Vagrant>;
    function get_onStatus() return _onStatus;

    public var onStopAll( get, never ):ChainedList<()->Void, Vagrant>;
    function get_onStopAll() return _onStopAll;

    public var onUp( get, never ):ChainedList<(VagrantMachine, Float)->Void, Vagrant>;
    function get_onUp() return _onUp;

    public var onVersion( get, never ):ChainedList<()->Void, Vagrant>;
    function get_onVersion() return _onVersion;

    public var machines( get, never ):Array<VagrantMachine>;
    function get_machines() return _machines;

    public var metadata( get, never ):VagrantMetadata;
    function get_metadata() return _metadata;

    public var stopAllFinished( get, never ):Bool;
    function get_stopAllFinished() return _stopAllFinished;

    public var vagrantFilename( get, set ):String;
    function get_vagrantFilename() return _vagrantFilename;
    function set_vagrantFilename( value:String ):String {
        if ( value == _vagrantFilename ) return value;
        _vagrantFilename = value;
        Sys.putEnv( 'VAGRANT_VAGRANTFILE', _vagrantFilename );
        return _vagrantFilename;
    }

    function new() {

        super();

        #if windows
        _executable = "vagrant.exe";
        #else
        _executable = "vagrant";
        #end
        _name = "Vagrant";
        #if ( mac || linux )
        _pathAdditions.push( "/opt/vagrant/bin" );
        #end
        _currentMachine = null;

        _onDestroy = new ChainedList( this );
        _onGlobalStatus = new ChainedList( this );
        _onHalt = new ChainedList( this );
        _onInitMachine = new ChainedList( this );
        _onProvision = new ChainedList( this );
        _onRSync = new ChainedList( this );
        _onStatus = new ChainedList( this );
        _onStopAll = new ChainedList( this );
        _onUp = new ChainedList( this );
        _onVersion = new ChainedList( this );

        // Setting up executor maps
        _destroyExecutors = [];
        _haltExecutors = [];
        _initExecutors = [];
        _provisionExecutors = [];
        _rsyncExecutors = [];
        _statusExecutors = [];
        _upExecutors = [];

        _mutexGlobalStatusStderr = new Mutex();
        _mutexGlobalStatusStdout = new Mutex();
        _mutexGlobalStatusStop = new Mutex();

        _instance = this;

    }

    public function clone():Vagrant {

        var v = new Vagrant();
        v._currentMachine = _currentMachine;
        v._machines = _machines;
        v._metadata = _metadata;
        v._executable = _executable;
        v._initialized = _initialized;
        v._name = _name;
        v._path = _path;
        v._status = _status;
        v._version = _version;
        v._initializationComplete();
        return cast v;

    }

    override public function dispose() {

        _currentMachine = null;
        _machines = null;
        _metadata = null;

        super.dispose();

    }

    /**
     * Creates a 'vagrant destroy {machine_id}' executor.
     * Returns an already created executor if it exists to make sure 'vagrant destroy' is not being executed multiple times for the same machine
     * @param force True if the destroy is forced
     * @param machine The VagrantMachine
     * @return Executor
     */
    public function getDestroy( force:Bool = false, ?machine:VagrantMachine ):Executor {

        // Return the already running executor for the given machine if it exists
        if ( machine != null && _destroyExecutors.exists( machine ) ) return _destroyExecutors.get( machine );

        var args:Array<String> = [ "destroy" ];
        if ( machine != null && machine.vagrantId != null ) args.push( machine.vagrantId );
        args.push( "-f" );

        var extraArgs:Array<Dynamic> = [];
        if ( machine != null ) extraArgs.push( machine );

        var _destroyExecutor = new Executor( this._path + this._executable, args, extraArgs );
        if ( machine != null ) _destroyExecutors.set( machine, _destroyExecutor );
        _destroyExecutor.onStop( _destroyExecutorStopped );
        return _destroyExecutor;

    }

    /**
     * Creates a 'vagrant halt {machine_id}' executor.
     * Returns an already created executor if it exists to make sure 'vagrant halt' is not being executed multiple times for the same machine
     * @param machine The VagrantMachine
     * @return Executor
     */
    public function getHalt( ?machine:VagrantMachine ):Executor {

        // Return the already running executor for the given machine if it exists
        if ( machine != null && _haltExecutors.exists( machine ) ) return _haltExecutors.get( machine );

        var args:Array<String> = [ "halt" ];
        if ( machine != null && machine.vagrantId != null ) args.push( machine.vagrantId );

        var extraArgs:Array<Dynamic> = [];
        if ( machine != null ) extraArgs.push( machine );

        var _haltExecutor = new Executor( this._path + this._executable, args, extraArgs );
        if ( machine != null ) _haltExecutors.set( machine, _haltExecutor );
        _haltExecutor.onStop( _haltExecutorStopped );
        return _haltExecutor;

    }

    /**
     * Creates a 'vagrant init' executor.
     * @param path If defined, the Vagrant machine will be initialized in the given directory, otherwise it will be initialized in the current working directory.
     * @return Executor
     */
    public function getInitMachine( ?vagrantFileContent:String, ?path:String ):Executor {

        // Return the already running executor for the given machine if it exists
        var p:String = ( path != null ) ? path : Sys.getCwd();
        if ( _initExecutors.exists( p ) ) return _initExecutors.get( p );

        if ( path != null ) Sys.setCwd( path );
        if ( vagrantFileContent != null ) File.saveContent( 'Vagrantfile', vagrantFileContent );

        var args:Array<String> = [ "init" ];
        var extraArgs:Array<Dynamic> = [];
        extraArgs.push( p );
        
        var _initMachineExecutor = new Executor( this._path + this._executable, args, extraArgs );
        _initExecutors.set( p, _initMachineExecutor );
        _initMachineExecutor.onStop( _initMachineExecutorStopped );
        return _initMachineExecutor;

    }

    /**
     * Creates a 'vagrant global-status' executor.
     * Only 1 instance exists, as this is a global command.
     * @return Executor
     */
    public function getGlobalStatus( prune:Bool = false ):Executor {

        if ( _globalStatusExecutor != null ) return _globalStatusExecutor;

        _tempGlobalStatusData = "";

        var args:Array<String> = [ "global-status" ];
        args.push( "--machine-readable" );
        if ( prune ) args.push( "--prune" );

        _globalStatusExecutor = new Executor( this._path + this._executable, args );
        _globalStatusExecutor.onStop( _globalStatusExecutorStopped ).onStdOut( _globalStatusExecutorStandardOutput );
        return _globalStatusExecutor;

    }

    /**
     * Creates a 'vagrant rsync {machine_id}' executor.
     * Returns an already created executor if it exists to make sure 'vagrant rsync' is not being executed multiple times for the same machine
     * @param machine The VagrantMachine
     * @return Executor
     */
    public function getRSync( machine:VagrantMachine ):Executor {

        // Return the already running executor for the given machine if it exists
        if ( machine != null && _rsyncExecutors.exists( machine ) ) return _rsyncExecutors.get( machine );

        var args:Array<String> = [ "rsync" ];
        if ( machine != null && machine.vagrantId != null ) args.push( machine.vagrantId );

        var extraArgs:Array<Dynamic> = [];
        if ( machine != null ) extraArgs.push( machine );

        var _rsyncExecutor = new Executor( this._path + this._executable, args, extraArgs );
        if ( machine != null ) _rsyncExecutors.set( machine, _rsyncExecutor );
        _rsyncExecutor.onStop( _rsyncExecutorStopped );
        return _rsyncExecutor;

    }

    /**
     * Creates a 'vagrant provision {machine_id}' executor.
     * Returns an already created executor if it exists to make sure 'vagrant provision' is not being executed multiple times for the same machine
     * @param machine The VagrantMachine
     * @return Executor
     */
    public function getProvision( machine:VagrantMachine ):Executor {

        // Return the already running executor for the given machine if it exists
        if ( machine != null && _provisionExecutors.exists( machine ) ) return _provisionExecutors.get( machine );

        var args:Array<String> = [ "provision" ];
        if ( machine != null && machine.vagrantId != null ) args.push( machine.vagrantId );

        var extraArgs:Array<Dynamic> = [];
        if ( machine != null ) extraArgs.push( machine );

        var _provisionExecutor = new Executor( this._path + this._executable, args, extraArgs );
        if ( machine != null ) _provisionExecutors.set( machine, _provisionExecutor );
        _provisionExecutor.onStop( _provisionExecutorStopped );
        return _provisionExecutor;

    }

    /**
     * Creates a 'vagrant status {machine_id}' executor.
     * Returns an already created executor if it exists to make sure 'vagrant status' is not being executed multiple times for the same machine
     * @param machine The VagrantMachine
     * @return Executor
     */
    public function getStatus( machine:VagrantMachine ):Executor {

        // Return the already running executor for the given machine if it exists
        if ( machine != null && _statusExecutors.exists( machine ) ) return _statusExecutors.get( machine );

        var args:Array<String> = [ "status" ];
        if ( machine != null && machine.vagrantId != null ) args.push( machine.vagrantId );
        args.push( "--machine-readable" );

        var extraArgs:Array<Dynamic> = [];
        if ( machine != null ) extraArgs.push( machine );

        var _statusExecutor = new Executor( this._path + this._executable, args, extraArgs );
        if ( machine != null ) _statusExecutors.set( machine, _statusExecutor );
        _statusExecutor.onStop( _statusExecutorStopped ).onStdOut( _statusExecutorStandardOutput );
        return _statusExecutor;

    }

    /**
     * Creates a 'vagrant -v' executor.
     * @return Executor
     */
    public function getVersion():Executor {

        if ( this._version != null ) return null;
        if ( _versionExecutor != null ) return _versionExecutor;

        _versionExecutor = new Executor( this.path + this._executable, [ "-v" ] );
        _versionExecutor.onStop( _versionExecutorStopped ).onStdOut( _versionExecutorStandardOutput );
        return _versionExecutor;

    }

    public function getUp( ?machine:VagrantMachine, ?provision:Bool = false, ?args:Array<String> ):Executor {

        // Return the already running executor for the given machine if it exists
        if ( _upExecutors.exists( machine ) ) return _upExecutors.get( machine );

        var params:Array<String> = [ "up" ];
        if ( machine != null && machine.vagrantId != null ) params.push( machine.vagrantId );
        if ( provision ) params.push( "--provision" );

        var extraArgs:Array<Dynamic> = [];
        if ( machine != null ) extraArgs.push( machine );

        var _upExecutor:Executor = new Executor( this._path + this._executable, params.concat( args ), extraArgs );
        _upExecutor.onStop( _upExecutorStopped );
        if ( machine != null ) _upExecutors.set( machine, _upExecutor );
        return _upExecutor;

    }

    // TODO: Add Windows and Linux implementation
    public function ssh() {
        
        #if windows
        Logger.warning( 'Vagrant ssh is not implemented yet on this platform' );
        #elseif linux
        Logger.warning( 'Vagrant ssh is not implemented yet on this platform' );
        #else
        var terminalCommand:String = 'cd "${Sys.getCwd()}"; vagrant ssh;';
        File.saveContent( '${Sys.getCwd()}/${_SSH_SCRIPT}', terminalCommand );
        Sys.command( 'chmod +x ./${_SSH_SCRIPT}' );
        Shell.getInstance().openTerminal( './${_SSH_SCRIPT}' );
        #end

    }

    public function stopAll( forced:Bool = false ) {

        _numExecutors = 0;
        if ( _globalStatusExecutor != null ) _numExecutors++;
        _numExecutors += Lambda.count( _destroyExecutors );
        _numExecutors += Lambda.count( _haltExecutors );
        _numExecutors += Lambda.count( _initExecutors );
        _numExecutors += Lambda.count( _provisionExecutors );
        _numExecutors += Lambda.count( _rsyncExecutors );
        _numExecutors += Lambda.count( _statusExecutors );
        _numExecutors += Lambda.count( _upExecutors );

        if ( _numExecutors == 0 ) {

            _stopAllFinished = true;
            for ( f in _onStopAll ) f();

        } else {

            if ( _globalStatusExecutor != null ) _globalStatusExecutor.onStop( _stopAllStop ).stop( forced );
            for( e in _destroyExecutors ) e.onStop( _stopAllStop ).stop( forced );
            for( e in _haltExecutors ) e.onStop( _stopAllStop ).stop( forced );
            for( e in _initExecutors ) e.onStop( _stopAllStop ).stop( forced );
            for( e in _provisionExecutors ) e.onStop( _stopAllStop ).stop( forced );
            for( e in _rsyncExecutors ) e.onStop( _stopAllStop ).stop( forced );
            for( e in _statusExecutors ) e.onStop( _stopAllStop ).stop( forced );
            for( e in _upExecutors ) e.onStop( _stopAllStop ).stop( forced );
    
        }

    }

    public override function toString():String {

        return '[Vagrant]';

    }

    function _stopAllStop( e:AbstractExecutor ) {

        _numExecutors--;

        if ( _numExecutors <= 0 ) {

            _stopAllFinished = true;
            for ( f in _onStopAll ) f();

        }

    }

    function _getMachineById( id:String ):VagrantMachine {

        for ( m in _machines ) {

            if ( m.vagrantId == id ) return m;

        }

        return null;

    }

    function _globalStatusExecutorStandardOutput( executor:AbstractExecutor, data:String ) {

        _mutexGlobalStatusStdout.acquire();
        _tempGlobalStatusData += data;
        _mutexGlobalStatusStdout.release();

    }

    function _globalStatusExecutorStopped( executor:AbstractExecutor ) {

        Logger.verbose( '_globalStatusExecutorStopped(): ${executor.exitCode} ${_tempGlobalStatusData}' );

        if ( _metadata == null ) _metadata = { machineCount: 0 };
        if ( _machines == null ) _machines = [];

        _mutexGlobalStatusStop.acquire();

        if ( executor.exitCode != 0 ) return;

        var a = _tempGlobalStatusData.split( SysTools.lineEnd );

        for ( v in a ) {

            var s = StringTools.trim( v );

            try {

                if ( s != null && s.length > 0 && _machineReadPattern.match( s ) ) {

                    _processMachineReadable( s );

                }

            } catch ( e ) {

                Logger.error( 'RegExp processing failed with ${s}' );

            }

        }

        for ( f in _onGlobalStatus ) f();

        _mutexGlobalStatusStop.release();

        executor.dispose();
        _globalStatusExecutor = null;

    }

    override function _initializationComplete() {

        if ( !exists ) return;

    }

    function _processMachineReadable( input:String ) {

        var a = input.split( "," );

        if ( a.contains( "metadata" ) ) {

            if ( _metadata == null ) _metadata = { machineCount: 0 };
            if ( a.contains( "machine-count") ) _metadata.machineCount = Std.parseInt( a[ 4 ] );

        }

        if ( a.contains( "machine-id" ) ) {

            if ( _machines == null ) _machines = [];

            _currentMachine = _getMachineById( a[ 3 ] );

            if ( _currentMachine == null ) {

                _currentMachine = { vagrantId: a[ 3 ] };
                _machines.push( _currentMachine );

            }

        }

        if ( a.contains( "provider-name" ) ) {

            if ( _currentMachine != null ) _currentMachine.provider = a[ 3 ];

        }

        if ( a.contains( "machine-home" ) ) {

            if ( _currentMachine != null ) _currentMachine.home = a[ 3 ];

        }

        if ( a.contains( "state" ) && a.indexOf( "state" ) == 2 ) {

            if ( _currentMachine != null ) _currentMachine.vagrantState = cast a[ 3 ];

        }

    }

    function _versionExecutorStandardOutput( executor:AbstractExecutor, data:String ) {

        var a = data.split( SysTools.lineEnd );

        if ( data.length > 0 && a.length > 0 ) {

            if ( _versionPattern.match( a[ 0 ] ) ) {

                this._version = _versionPattern.matched( 0 );

            }

        }

    }

    function _versionExecutorStopped( _versionExecutor:AbstractExecutor ) {
        
        for ( f in _onVersion ) f();

    }

    function _upExecutorStopped( executor:AbstractExecutor ) {

        Logger.verbose( '${this}: upExecutor stopped with exitCode: ${executor.exitCode}' );

        if ( executor.extraParams != null ) _upExecutors.remove( executor.extraParams[ 0 ] );

        for ( f in _onUp ) f( executor.extraParams[ 0 ], executor.exitCode );

    }

    function _statusExecutorStopped( _statusExecutor:AbstractExecutor ) {
        
        Logger.verbose( '${this}: statusExecutor stopped with exitCode: ${_statusExecutor.exitCode}' );

        if ( _statusExecutor.extraParams != null ) _statusExecutors.remove( _statusExecutor.extraParams[ 0 ] );

        for ( f in _onStatus ) f( _statusExecutor.extraParams[ 0 ] );

    }

    function _statusExecutorStandardOutput( executor:AbstractExecutor, data:String ) {

        var a = data.split( SysTools.lineEnd );

        for ( v in a ) {

            var s = StringTools.trim( v );

            try {

                if ( s != null && s.length > 0 && _machineReadPatternForStatus.match( s ) ) {

                    _processMachineReadableForStatus( s, executor.extraParams[ 0 ] );

                }

            } catch ( e ) {

                Logger.error( 'RegExp processing failed with ${s}' );

            }

        }

    }

    function _rsyncExecutorStopped( executor:AbstractExecutor ) {

        Logger.verbose( '${this}: rsyncExecutor stopped with exitCode: ${executor.exitCode}' );

        if ( executor.extraParams != null ) _rsyncExecutors.remove( executor.extraParams[ 0 ] );

        for ( f in _onRSync ) f( executor.extraParams[ 0 ] );

        executor.dispose();

    }

    function _provisionExecutorStopped( executor:AbstractExecutor ) {

        Logger.verbose( '${this}: provisionExecutor stopped with exitCode: ${executor.exitCode}' );

        if ( executor.extraParams != null ) _provisionExecutors.remove( executor.extraParams[ 0 ] );

        for ( f in _onProvision ) f( executor.extraParams[ 0 ] );

        executor.dispose();

    }

    function _haltExecutorStopped( executor:AbstractExecutor ) {

        Logger.verbose( '${this}: haltExecutor stopped with exitCode: ${executor.exitCode}' );

        if ( executor.extraParams != null ) _haltExecutors.remove( executor.extraParams[ 0 ] );

        for ( f in _onHalt ) f( executor.extraParams[ 0 ] );

    }

    function _destroyExecutorStopped( executor:AbstractExecutor ) {

        Logger.verbose( '${this}: destroyExecutor stopped with exitCode: ${executor.exitCode}' );

        if ( executor.extraParams != null ) _destroyExecutors.remove( executor.extraParams[ 0 ] );

        for ( f in _onDestroy ) f( executor.extraParams[ 0 ] );

    }

    function _initMachineExecutorStopped( executor:AbstractExecutor ) {

        Logger.verbose( '${this}: initMachineExecutor stopped with exitCode: ${executor.exitCode}' );

        if ( executor.extraParams != null ) _initExecutors.remove( executor.extraParams[ 0 ] );

        for ( f in _onInitMachine ) f( executor.extraParams[ 0 ] );

    }

    function _processMachineReadableForStatus( input:String, machine:VagrantMachine ) {

        var a = input.split( "," );

        if ( a.contains( "state" ) ) {

            machine.vagrantState = cast a[ 3 ];

        }

    }

}

typedef VagrantMetadata = {

    machineCount:Int,

}

typedef VagrantMachine = {

    ?home:String,
    ?provider:String,
    ?serverId:Int,
    ?vagrantId:String,
    ?vagrantState:String,

}
