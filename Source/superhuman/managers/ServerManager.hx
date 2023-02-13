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

package superhuman.managers;

import feathers.data.ArrayCollection;
import prominic.logging.Logger;
import prominic.sys.applications.hashicorp.Vagrant;
import prominic.sys.applications.oracle.VirtualBox;
import prominic.sys.io.AbstractExecutor;
import prominic.sys.io.ExecutorManager;
import prominic.sys.io.ParallelExecutor;
import superhuman.server.Server;
import superhuman.server.ServerStatus;
import superhuman.server.data.ServerData;
import superhuman.server.provisioners.ProvisionerType;
import sys.FileSystem;

class ServerManager {

    static var _instance:ServerManager;

    static public function getInstance():ServerManager {

        if ( _instance == null ) _instance = new ServerManager();
        return _instance;

    }

    var _onVMInfoRefreshed:List<()->Void>;
    var _serverRootDirectory:String;
    var _servers:ArrayCollection<Server>;

    public var onVMInfoRefreshed( get, never ):List<()->Void>;
    function get_onVMInfoRefreshed() return _onVMInfoRefreshed;

    public var serverRootDirectory( get, set ):String;
    function get_serverRootDirectory() return _serverRootDirectory;
    function set_serverRootDirectory( value ) {
        if ( value == _serverRootDirectory ) return _serverRootDirectory;
        _serverRootDirectory = value;
        if ( !FileSystem.exists( _serverRootDirectory ) ) FileSystem.createDirectory( _serverRootDirectory );
        return _serverRootDirectory;
    }

    public var servers( get, never ):ArrayCollection<Server>;
    function get_servers() return _servers;
    
    function new() {

        _onVMInfoRefreshed = new List();
        _servers = new ArrayCollection();

    }

    public function createServer( serverData:ServerData ):Server {

        var server = Server.create( serverData, serverRootDirectory );
        _servers.add( server );
        return server;

    }

    public function getDefaultServerData( type:ProvisionerType ):ServerData {
        
        if ( type == ProvisionerType.DemoTasks ) return superhuman.server.provisioners.DemoTasks.getDefaultServerData( superhuman.server.provisioners.DemoTasks.getRandomServerId( _serverRootDirectory ) );

        return null;

    }

    public function getRealStatus( server:Server ):ServerStatus {

        var result = ServerStatus.Unknown;

        Logger.debug( '${server}.combinedVirtualMachine: ${server.combinedVirtualMachine.value}' );

        final hasError = ( server.currentAction != null ) ? server.currentAction.getParameters()[ 0 ] : false;

        switch server.combinedVirtualMachine.value.vagrantMachine.vagrantState {
            
            case "aborted":
                result = ServerStatus.Aborted;

            case "poweroff":
                result = ServerStatus.Stopped( false );

            case "running":
                result = ServerStatus.Running( false );

            case "saved":
                result = ServerStatus.Suspended;

            default:

        }

        switch server.combinedVirtualMachine.value.virtualBoxMachine.virtualBoxState {
            
            case "aborted":
                result = ServerStatus.Aborted;

            case "powered off":
                result = ServerStatus.Stopped( false );

            case "running":
                result = ServerStatus.Running( hasError );

            case "saved":
                result = ServerStatus.Suspended;

            case "starting":
                result = ServerStatus.Running( false );

            case "stopping":
                result = ServerStatus.Running( false );

            default:
                result = ServerStatus.Unknown;

        }

        if ( result == ServerStatus.Unknown ) {

            if ( server.isValid() )
                result = ServerStatus.Ready
            else
                result = ServerStatus.Unconfigured;

        }

        if ( !server.isValid() ) result = ServerStatus.Unconfigured;

        Logger.debug( '${server}: Assumed status: ${result}' );

        return result;

    }

    public function getServerDirectory( type:ProvisionerType, id:Int ):String {

        return '${_serverRootDirectory}${type}/${id}';

    }

    public function refreshVMInfo( refreshVagrant:Bool, refreshVirtualBox:Bool ) {

        if ( ExecutorManager.getInstance().exists( ServerManagerExecutorContext.RefreshVMInfo ) ) return;

		Logger.debug( '${this}: Refreshing System Info...' );

		var pe = ParallelExecutor.create();
		if ( refreshVagrant ) pe.add( Vagrant.getInstance().getGlobalStatus() );
		if ( refreshVirtualBox ) pe.add( VirtualBox.getInstance().getListVMs( true ) );
		pe.onStop.add( _refreshVMInfoStopped );
		ExecutorManager.getInstance().set( ServerManagerExecutorContext.RefreshVMInfo, pe );
		pe.execute();

    }

    public function toString():String {

        return '[ServerManager]';

    }

    function _refreshVMInfoStopped( executor:AbstractExecutor ) {

        ExecutorManager.getInstance().remove( ServerManagerExecutorContext.RefreshVMInfo );

		Logger.debug( '${this}: VM Info refreshed' );
		Logger.debug( '${this}: Vagrant machines: ${Vagrant.getInstance().machines}' );
		Logger.debug( '${this}: VirtualBox machines: ${VirtualBox.getInstance().virtualBoxMachines}' );

		for ( s in _servers ) {

			s.combinedVirtualMachine.value.virtualBoxMachine = {};
			s.combinedVirtualMachine.value.vagrantMachine = {};

		}

		for ( i in Vagrant.getInstance().machines ) {

			for ( s in _servers ) {

				if ( s.path.value == i.home ) s.setVagrantMachine( i );

			}

		}

		for ( i in VirtualBox.getInstance().virtualBoxMachines ) {

			for ( s in _servers ) {

				if ( s.virtualBoxId == i.name ) {
					
					s.setVirtualBoxMachine( i );
					s.setServerStatus();

				}

			}

		}

		for ( s in _servers ) {

			// Deleting provisioning proof file if VirtualBox machine does not exist for this server
			if ( s.combinedVirtualMachine.value.virtualBoxMachine.name == null ) s.deleteProvisioningProof();

		}

		executor.dispose();

    }

}

enum abstract ServerManagerExecutorContext( String ) to String {

    var RefreshVMInfo = "ServerManager_RefreshVMInfo";

}