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

import prominic.sys.applications.bin.Which;
import champaign.core.ds.ChainedList;
import champaign.core.logging.Logger;
import prominic.sys.applications.bin.Shell;
import prominic.sys.io.AbstractExecutor;
import prominic.sys.io.Executor;
import prominic.sys.io.ExecutorManager;
import prominic.sys.tools.SysTools;
import sys.io.File;
import sys.thread.Mutex;

using Lambda;

@:allow( prominic.sys )
@:allow( prominic.sys.applications )
class Vagrant extends AbstractApp {

    static final _machineReadPattern = ~/((\d+),(.*),(.+),(.+))/gm;
    static final _machineReadPatternForStatus = ~/(\d+,.*,(\w|-)+,(\w|-|\/|\\|\.)*,*(.)+)/gm;
    static final _versionPattern = ~/(\d+\.\d+\.\d+)/;
    static final _rsyncVersionPattern = ~/rsync\s+version\s+(\d+\.\d+\.\d+).*/;
    #if windows
    static final _SSH_SCRIPT:String = "ssh.bat";
    #else
    static final _SSH_SCRIPT:String = "ssh.sh";
    #end

    static var _instance:Vagrant;

    static public function getInstance():Vagrant {
        
        if ( _instance == null ) _instance = new Vagrant();
        return _instance;

    }

    var _currentMachine:VagrantMachine;
    var _currentWorkingDir:String;
    var _machines:Array<VagrantMachine>;
    var _metadata:VagrantMetadata;
    var _numExecutors:Int;
    var _onDestroy:ChainedList<(VagrantMachine)->Void, Vagrant>;
    var _onGlobalStatus:ChainedList<()->Void, Vagrant>;
    var _onHalt:ChainedList<(VagrantMachine)->Void, Vagrant>;
    var _onInitMachine:ChainedList<(VagrantMachine)->Void, Vagrant>;
    var _onProvision:ChainedList<(VagrantMachine)->Void, Vagrant>;
    var _onRSync:ChainedList<(VagrantMachine)->Void, Vagrant>;
    var _onStatus:ChainedList<(VagrantMachine)->Void, Vagrant>;
    var _onStopAll:ChainedList<()->Void, Vagrant>;
    var _onSuspend:ChainedList<(VagrantMachine)->Void, Vagrant>;
    var _onUp:ChainedList<(VagrantMachine, Float)->Void, Vagrant>;
    var _onVersion:ChainedList<()->Void, Vagrant>;
    var _onVersionRsync:ChainedList<()->Void, Vagrant>;
    var _stopAllFinished:Bool = false;
    var _tempGlobalStatusData:String;
    var _vagrantFilename:String;

    var _mutexGlobalStatusStderr:Mutex;
    var _mutexGlobalStatusStdout:Mutex;
    var _mutexGlobalStatusStop:Mutex;

    private static var _rsyncPath:String = null;
    private static final _rsyncLocations:Array<String> = [
        #if windows
        "C:\\Program Files\\cwRsync\\bin\\rsync.exe",
        "C:\\Program Files (x86)\\cwRsync\\bin\\rsync.exe",
        "C:\\msys64\\usr\\bin\\rsync.exe",
        "C:\\cygwin64\\bin\\rsync.exe",
        #else
        "/opt/local/bin/rsync",  // MacPorts
        "/usr/local/bin/rsync",  // Homebrew
        "/usr/bin/rsync"         // System default
        #end
    ];

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

    public var onInitMachine( get, never ):ChainedList<(VagrantMachine)->Void, Vagrant>;
    function get_onInitMachine() return _onInitMachine;

    public var onProvision( get, never ):ChainedList<(VagrantMachine)->Void, Vagrant>;
    function get_onProvision() return _onProvision;

    public var onRSync( get, never ):ChainedList<(VagrantMachine)->Void, Vagrant>;
    function get_onRSync() return _onRSync;

    public var onStatus( get, never ):ChainedList<(VagrantMachine)->Void, Vagrant>;
    function get_onStatus() return _onStatus;

    public var onStopAll( get, never ):ChainedList<()->Void, Vagrant>;
    function get_onStopAll() return _onStopAll;

    public var onSuspend( get, never ):ChainedList<(VagrantMachine)->Void, Vagrant>;
    function get_onSuspend() return _onSuspend;

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
        _pathAdditions.push("/opt/local/bin");
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
        _onSuspend = new ChainedList( this );
        _onUp = new ChainedList( this );
        _onVersion = new ChainedList( this );
        _onVersionRsync = new ChainedList( this );

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
    public function getDestroy( machine:VagrantMachine, force:Bool = false ):AbstractExecutor {

        // Return the already running executor for the given machine if it exists
        if ( ExecutorManager.getInstance().exists( '${VagrantExecutorContext.Destroy}${machine.serverId}' ) )
            return ExecutorManager.getInstance().get( '${VagrantExecutorContext.Destroy}${machine.serverId}' );

        var args:Array<String> = [ "destroy" ];
        if ( machine.vagrantId != null ) args.push( machine.vagrantId );
        args.push( "-f" );

        var extraArgs:Array<Dynamic> = [];
        extraArgs.push( machine );

        final executor = new Executor( this._path + this._executable, args, extraArgs );
        executor.onStop.add( _destroyExecutorStopped );
        ExecutorManager.getInstance().set( '${VagrantExecutorContext.Destroy}${machine.serverId}', executor );
        return executor;

    }

    /**
     * Creates a 'vagrant halt {machine_id}' executor.
     * Returns an already created executor if it exists to make sure 'vagrant halt' is not being executed multiple times for the same machine
     * @param machine The VagrantMachine
     * @return Executor
     */
    public function getHalt( machine:VagrantMachine, force:Bool = false ):AbstractExecutor {

        // Return the already running executor for the given machine if it exists
        if ( ExecutorManager.getInstance().exists( '${VagrantExecutorContext.Halt}${machine.serverId}' ) )
            return ExecutorManager.getInstance().get( '${VagrantExecutorContext.Halt}${machine.serverId}' );

        var args:Array<String> = [ "halt" ];
        if ( force ) args.push( '-f' );
        if ( machine.vagrantId != null ) args.push( machine.vagrantId );

        var extraArgs:Array<Dynamic> = [];
        extraArgs.push( machine );

        final executor = new Executor( this._path + this._executable, args, extraArgs );
        executor.onStop.add( _haltExecutorStopped );
        ExecutorManager.getInstance().set( '${VagrantExecutorContext.Halt}${machine.serverId}', executor );
        return executor;

    }

    /**
     * Creates a 'vagrant init' executor.
     * @param path If defined, the Vagrant machine will be initialized in the given directory, otherwise it will be initialized in the current working directory.
     * @return Executor
     */
    public function getInitMachine( machine:VagrantMachine, ?vagrantFileContent:String, ?path:String ):AbstractExecutor {

        // Return the already running executor for the given machine if it exists
        if ( ExecutorManager.getInstance().exists( '${VagrantExecutorContext.Init}${machine.serverId}' ) )
            return ExecutorManager.getInstance().get( '${VagrantExecutorContext.Init}${machine.serverId}' );

        if ( vagrantFileContent != null ) File.saveContent( 'Vagrantfile', vagrantFileContent );

        var args:Array<String> = [ "init" ];

        var extraArgs:Array<Dynamic> = [];
        extraArgs.push( machine );
        
        final executor = new Executor( this._path + this._executable, args, extraArgs );
        executor.onStop.add( _initMachineExecutorStopped );
        ExecutorManager.getInstance().set( '${VagrantExecutorContext.Init}${machine.serverId}', executor );
        return executor;

    }

    /**
     * Creates a 'vagrant global-status' executor.
     * Only 1 instance exists, as this is a global command.
     * @return Executor
     */
    public function getGlobalStatus( prune:Bool = false ):AbstractExecutor {

        // Return the already running executor if it exists
        if ( ExecutorManager.getInstance().exists( VagrantExecutorContext.GlobalStatus ) )
            return ExecutorManager.getInstance().get( VagrantExecutorContext.GlobalStatus );

        _tempGlobalStatusData = "";

        var args:Array<String> = [ "global-status" ];
        args.push( "--machine-readable" );
        if ( prune ) args.push( "--prune" );

        final executor = new Executor( this._path + this._executable, args );
        executor.onStop.add( _globalStatusExecutorStopped ).onStdOut.add( _globalStatusExecutorStandardOutput );
        ExecutorManager.getInstance().set( VagrantExecutorContext.GlobalStatus, executor );
        return executor;

    }

    /**
     * Creates a 'vagrant rsync {machine_id}' executor.
     * Returns an already created executor if it exists to make sure 'vagrant rsync' is not being executed multiple times for the same machine
     * @param machine The VagrantMachine
     * @return Executor
     */
    public function getRSync( machine:VagrantMachine ):AbstractExecutor {

        // Return the already running executor for the given machine if it exists
        if ( ExecutorManager.getInstance().exists( '${VagrantExecutorContext.RSync}${machine.serverId}' ) )
            return ExecutorManager.getInstance().get( '${VagrantExecutorContext.RSync}${machine.serverId}' );

        var args:Array<String> = [ findRsyncPath() ];
        if ( machine.vagrantId != null ) args.push( machine.vagrantId );

        var extraArgs:Array<Dynamic> = [];
        extraArgs.push( machine );

        final executor = new Executor( this._path + this._executable, args, extraArgs );
        executor.onStop.add( _rsyncExecutorStopped );
        ExecutorManager.getInstance().set( '${VagrantExecutorContext.RSync}${machine.serverId}', executor );
        return executor;

    }

    /**
     * Creates a 'vagrant provision {machine_id}' executor.
     * Returns an already created executor if it exists to make sure 'vagrant provision' is not being executed multiple times for the same machine
     * @param machine The VagrantMachine
     * @return Executor
     */
    public function getProvision( machine:VagrantMachine ):AbstractExecutor {

        // Return the already running executor for the given machine if it exists
        if ( ExecutorManager.getInstance().exists( '${VagrantExecutorContext.Provision}${machine.serverId}' ) )
            return ExecutorManager.getInstance().get( '${VagrantExecutorContext.Provision}${machine.serverId}' );

        var args:Array<String> = [ "provision" ];
        if ( machine.vagrantId != null ) args.push( machine.vagrantId );

        var extraArgs:Array<Dynamic> = [];
        extraArgs.push( machine );

        final executor = new Executor( this._path + this._executable, args, extraArgs );
        executor.onStop.add( _provisionExecutorStopped );
        ExecutorManager.getInstance().set( '${VagrantExecutorContext.Provision}${machine.serverId}', executor );
        return executor;

    }

    /**
     * Creates a 'vagrant status {machine_id}' executor.
     * Returns an already created executor if it exists to make sure 'vagrant status' is not being executed multiple times for the same machine
     * @param machine The VagrantMachine
     * @return Executor
     */
    public function getStatus( machine:VagrantMachine ):AbstractExecutor {

        // Return the already running executor for the given machine if it exists
        if ( ExecutorManager.getInstance().exists( '${VagrantExecutorContext.Status}${machine.serverId}' ) )
            return ExecutorManager.getInstance().get( '${VagrantExecutorContext.Status}${machine.serverId}' );

        var args:Array<String> = [ "status" ];
        if ( machine.vagrantId != null ) args.push( machine.vagrantId );
        args.push( "--machine-readable" );

        var extraArgs:Array<Dynamic> = [];
        extraArgs.push( machine );

        final executor = new Executor( this._path + this._executable, args, extraArgs );
        executor.onStop.add( _statusExecutorStopped ).onStdOut.add( _statusExecutorStandardOutput );
        ExecutorManager.getInstance().set( '${VagrantExecutorContext.Status}${machine.serverId}', executor );
        return executor;

    }

    public function getSuspend( machine:VagrantMachine ):AbstractExecutor {

        // Return the already running executor for the given machine if it exists
        if ( ExecutorManager.getInstance().exists( '${VagrantExecutorContext.Suspend}${machine.serverId}' ) )
            return ExecutorManager.getInstance().get( '${VagrantExecutorContext.Suspend}${machine.serverId}' );

        var args:Array<String> = [ "suspend" ];
        if ( machine.vagrantId != null ) args.push( machine.vagrantId );

        var extraArgs:Array<Dynamic> = [];
        extraArgs.push( machine );

        final executor = new Executor( this._path + this._executable, args, extraArgs );
        executor.onStop.add( _suspendExecutorStopped ).onStdOut.add( _suspendExecutorStandardOutput );
        ExecutorManager.getInstance().set( '${VagrantExecutorContext.Suspend}${machine.serverId}', executor );
        return executor;

    }

    /**
     * Creates a 'vagrant -v' executor.
     * @return Executor
     */
    public function getVersion():AbstractExecutor {

        // Return the already running executor if it exists
        if ( ExecutorManager.getInstance().exists( VagrantExecutorContext.Version ) )
            return ExecutorManager.getInstance().get( VagrantExecutorContext.Version );

        final executor = new Executor( this.path + this._executable, [ "-v" ] );
        executor.onStop.add( _versionExecutorStopped ).onStdOut.add( _versionExecutorStandardOutput );
        ExecutorManager.getInstance().set( VagrantExecutorContext.Version, executor );
        return executor;

    }

     /**
     * Creates a 'rsync -v' executor.
     * @return Executor
     */
     public function getRsyncVersion():AbstractExecutor {

        // Return the already running executor if it exists
        if ( ExecutorManager.getInstance().exists( VagrantExecutorContext.VersionRsync ) )
            return ExecutorManager.getInstance().get( VagrantExecutorContext.VersionRsync );

        var rsyncPath = findRsyncPath();
        if ( rsyncPath == null ) 
        {
            this._versionRsync = "";
            return null;
        }

        final executor = new Executor( rsyncPath, [ "--version" ] );
        executor.onStop.add(_versionRsyncExecutorStopped).onStdOut.add( _versionRsyncExecutorStandardOutput );
        ExecutorManager.getInstance().set( VagrantExecutorContext.VersionRsync, executor );
        return executor;

    }

    public function getUp( machine:VagrantMachine, ?provision:Bool = false, ?args:Array<String> ):AbstractExecutor {

        // Return the already running executor for the given machine if it exists
        if ( ExecutorManager.getInstance().exists( '${VagrantExecutorContext.Up}${machine.serverId}' ) )
            return ExecutorManager.getInstance().get( '${VagrantExecutorContext.Up}${machine.serverId}' );

        var params:Array<String> = [ "up" ];
        if ( machine.vagrantId != null ) params.push( machine.vagrantId );
        if ( provision ) params.push( "--provision" );

        var extraArgs:Array<Dynamic> = [];
        extraArgs.push( machine );

        final executor:Executor = new Executor( this._path + this._executable, params.concat( args ), extraArgs );
        executor.onStop.add( _upExecutorStopped );
        ExecutorManager.getInstance().set( '${VagrantExecutorContext.Up}${machine.serverId}', executor );
        return executor;

    }

    // TODO: Add Windows and Linux implementation
    public function ssh() {
        
        #if windows
        var terminalCommand:String = 'cd "${Sys.getCwd()}"\r\nvagrant ssh';
        File.saveContent( '${Sys.getCwd()}/${_SSH_SCRIPT}', terminalCommand );
        Shell.getInstance().openTerminal( '${Sys.getCwd()}/${_SSH_SCRIPT}' );
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

        /*
        _numExecutors = _globalExecutors.count();

        if ( _numExecutors == 0 ) {

            _stopAllFinished = true;
            for ( f in _onStopAll ) f();

        } else {

            _globalExecutors.iter( ( e ) -> { e.onStop( _stopAllStop ).stop( forced ); } );

        }
        */

    }

    public override function toString():String {

        return '[Vagrant]';

    }

    function _stopAllStop( e:AbstractExecutor ) {

        /*
        _numExecutors--;

        for ( k in _globalExecutors.keys() ) {

            if ( _globalExecutors.get( k ) == e ) {

                _globalExecutors.remove( k );
                break;

            }

        }

        if ( _numExecutors <= 0 ) {

            _stopAllFinished = true;
            for ( f in _onStopAll ) f();

        }
        */

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

        Logger.debug( '${this}: _globalStatusExecutorStopped(): ${executor.exitCode} ${_tempGlobalStatusData}' );

        _mutexGlobalStatusStop.acquire();

        if ( _metadata == null ) _metadata = { machineCount: 0 };
        if ( _machines == null ) _machines = [];

        if ( executor.exitCode == 0 ) {

            var a = _tempGlobalStatusData.split( SysTools.lineEnd );

            for ( v in a ) {

                var s = StringTools.trim( v );

                try {

                    if ( s != null && s.length > 0 && _machineReadPattern.match( s ) ) {

                        _processMachineReadable( s );

                    }

                } catch ( e ) {

                    Logger.error( '${this}: globalstatus Regex processing failed with ${s}' );

                }

            }

        }

        for ( f in _onGlobalStatus ) f();

        ExecutorManager.getInstance().remove( VagrantExecutorContext.GlobalStatus );

        _mutexGlobalStatusStop.release();

        executor.dispose();

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

    function _versionExecutorStopped( executor:AbstractExecutor ) {
        
        Logger.debug( '${this}: _versionExecutorStopped(): ${executor.exitCode}' );

        for ( f in _onVersion ) f();

        ExecutorManager.getInstance().remove( VagrantExecutorContext.Version );

        executor.dispose();

    }

    function _versionRsyncExecutorStandardOutput( executor:AbstractExecutor, data:String ) {

        var a = data.split( SysTools.lineEnd );

        if ( data.length > 0 && a.length > 0 ) {
            for (p in a) {
                if ( _rsyncVersionPattern.match(p) ) {

                    this._versionRsync = _rsyncVersionPattern.matched(1);
                    break;
                }
            }
        }

    }

    function _versionRsyncExecutorStopped( executor:AbstractExecutor ) {
        
        // Clear the cached path when checking version
        // This ensures we'll look for rsync again next time
        _rsyncPath = null;
        
        Logger.debug( '${this}: _versionRsyncExecutorStopped(): ${executor.exitCode}' );

        for ( f in _onVersionRsync ) f();

        ExecutorManager.getInstance().remove( VagrantExecutorContext.VersionRsync );

        executor.dispose();

    }

    private function findRsyncPath():String {
        if (_rsyncPath != null) return _rsyncPath;
        
        // First try which command to find rsync in PATH
        final whichExecutor = new Executor(Which.getInstance().path + Which.getInstance()._executable, ["rsync"]);
        var whichOutput:String = null;
        whichExecutor.onStdOut.add((executor, data) -> {
            whichOutput = data;
        });
        whichExecutor.onStop.add((executor) -> {
            if (executor.exitCode == 0 && whichOutput != null) {
                var output = StringTools.trim(whichOutput);
                if (output != "" && sys.FileSystem.exists(output)) {
                    _rsyncPath = output;
                }
            }
        });
        whichExecutor.execute();
        
        if (_rsyncPath != null) return _rsyncPath;

        // Then check common installation locations
        for (path in _rsyncLocations) {
            if (sys.FileSystem.exists(path)) {
                _rsyncPath = path;
                return _rsyncPath;
            }
        }

        #if windows
        // On Windows, if rsync is not found, throw a more descriptive error
        return null;
        #else
        // If nothing else found, fall back to "rsync" and let the system resolve it
        _rsyncPath = "rsync";
        return _rsyncPath;
        #end
    }

    function _upExecutorStopped( executor:AbstractExecutor ) {

        Logger.debug( '${this}: upExecutor stopped with exitCode: ${executor.exitCode}' );

        for ( f in _onUp ) f( executor.extraParams[ 0 ], executor.exitCode );

        ExecutorManager.getInstance().remove( '${VagrantExecutorContext.Up}${executor.extraParams[ 0 ].serverId}' );

        executor.dispose();

    }

    function _statusExecutorStopped( executor:AbstractExecutor ) {
        
        Logger.debug( '${this}: statusExecutor stopped with exitCode: ${executor.exitCode}' );

        for ( f in _onStatus ) f( executor.extraParams[ 0 ] );

        ExecutorManager.getInstance().remove( '${VagrantExecutorContext.Status}${executor.extraParams[ 0 ].serverId}' );

        executor.dispose();

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

        Logger.debug( '${this}: rsyncExecutor stopped with exitCode: ${executor.exitCode}' );

        for ( f in _onRSync ) f( executor.extraParams[ 0 ] );

        ExecutorManager.getInstance().remove( '${VagrantExecutorContext.RSync}${executor.extraParams[ 0 ].serverId}' );

        executor.dispose();

    }

    function _provisionExecutorStopped( executor:AbstractExecutor ) {

        Logger.debug( '${this}: provisionExecutor stopped with exitCode: ${executor.exitCode}' );

        for ( f in _onProvision ) f( executor.extraParams[ 0 ] );

        ExecutorManager.getInstance().remove( '${VagrantExecutorContext.Provision}${executor.extraParams[ 0 ].serverId}' );

        executor.dispose();

    }

    function _haltExecutorStopped( executor:AbstractExecutor ) {

        Logger.debug( '${this}: haltExecutor stopped with exitCode: ${executor.exitCode}' );

        for ( f in _onHalt ) f( executor.extraParams[ 0 ] );

        ExecutorManager.getInstance().remove( '${VagrantExecutorContext.Halt}${executor.extraParams[ 0 ].serverId}' );

        executor.dispose();

    }

    function _destroyExecutorStopped( executor:AbstractExecutor ) {

        Logger.debug( '${this}: destroyExecutor stopped with exitCode: ${executor.exitCode}' );

        for ( f in _onDestroy ) f( executor.extraParams[ 0 ] );

        ExecutorManager.getInstance().remove( '${VagrantExecutorContext.Destroy}${executor.extraParams[ 0 ].serverId}' );

        executor.dispose();

    }

    function _initMachineExecutorStopped( executor:AbstractExecutor ) {

        Logger.debug( '${this}: initMachineExecutor stopped with exitCode: ${executor.exitCode}' );

        for ( f in _onInitMachine ) f( executor.extraParams[ 0 ] );

        ExecutorManager.getInstance().remove( '${VagrantExecutorContext.Init}${executor.extraParams[ 0 ].serverId}' );

        executor.dispose();

    }

    function _processMachineReadableForStatus( input:String, machine:VagrantMachine ) {

        var a = input.split( "," );

        if ( a.contains( "state" ) ) {

            machine.vagrantState = cast a[ 3 ];

        }

    }

    function _suspendExecutorStandardOutput( executor:AbstractExecutor, data:String ) {



    }

    function _suspendExecutorStopped( executor:AbstractExecutor ) {

        Logger.debug( '${this}: suspendExecutor stopped with exitCode: ${executor.exitCode}' );

        for ( f in _onSuspend ) f( executor.extraParams[ 0 ] );

        ExecutorManager.getInstance().remove( '${VagrantExecutorContext.Suspend}${executor.extraParams[ 0 ].serverId}' );

        executor.dispose();

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

enum abstract VagrantExecutorContext( String ) to String {

    var Destroy = "Vagrant_Destroy_";
    var GlobalStatus = "Vagrant_GlobalStatus";
    var Halt = "Vagrant_Halt_";
    var Init = "Vagrant_Init_";
    var Provision = "Vagrant_Provision_";
    var RSync = "Vagrant_RSync_";
    var Status = "Vagrant_Status_";
    var Suspend = "Vagrant_Suspend_";
    var Up = "Vagrant_Up_";
    var Version = "Vagrant_Version";
    var VersionRsync = "Vagrant_VersionRsync";
}
