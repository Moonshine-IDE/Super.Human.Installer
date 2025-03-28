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

import superhuman.server.AdditionalServer;
import feathers.data.ArrayCollection;
import champaign.core.logging.Logger;
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

    public function createServer( serverData:ServerData, type:ProvisionerType = ProvisionerType.StandaloneProvisioner ):Server {
        var server:Server;
        
        // Handle different provisioner types - using string comparison for consistency
        if (Std.string(type) == Std.string(ProvisionerType.StandaloneProvisioner) || 
            Std.string(type) == Std.string(ProvisionerType.Default) || 
            Std.string(type) == Std.string(ProvisionerType.Custom)) {
            // Use the standard Server class for standalone provisioners and custom types
            server = Server.create(serverData, serverRootDirectory);
            Logger.info('${this}: Created standard server with provisioner type: ${type}');
        } else if (Std.string(type) == Std.string(ProvisionerType.AdditionalProvisioner)) {
            // Use the AdditionalServer class for additional provisioners
            server = AdditionalServer.create(serverData, serverRootDirectory);
            Logger.info('${this}: Created additional server with provisioner type: ${type}');
        } else {
            // For any other custom type, default to standard Server
            // This is safer than defaulting to AdditionalServer which has more specific requirements
            Logger.info('${this}: Creating server with custom provisioner type: ${type}');
            server = Server.create(serverData, serverRootDirectory);
        }
        
        if (server != null) {
            // All new servers start as provisional until saved
            if (Reflect.hasField(server, "_provisional")) {
                Reflect.setField(server, "_provisional", true);
                Logger.info('${this}: Server ${server.id} marked as provisional');
            }
            
            // Add to server collection
            _servers.add(server);
        } else {
            Logger.error('${this}: Failed to create server with provisioner type: ${type}');
        }
        
        return server;
    }

    public function getDefaultServerData( type:ProvisionerType ):ServerData {
        
        if (Std.string(type) == Std.string(ProvisionerType.StandaloneProvisioner)) 
        {
            return superhuman.server.provisioners.StandaloneProvisioner.getDefaultServerData( superhuman.server.provisioners.StandaloneProvisioner.getRandomServerId( _serverRootDirectory ) );
        }
        else if (Std.string(type) == Std.string(ProvisionerType.AdditionalProvisioner)) 
        {
            return superhuman.server.provisioners.AdditionalProvisioner.getDefaultServerData( superhuman.server.provisioners.AdditionalProvisioner.getRandomServerId( _serverRootDirectory ) );
        }
        else
        {
            // For custom provisioner types, use the StandaloneProvisioner as a base
            // This ensures we have a valid ServerData object for any provisioner type
            var serverId = superhuman.server.provisioners.StandaloneProvisioner.getRandomServerId( _serverRootDirectory );
            var data = superhuman.server.provisioners.StandaloneProvisioner.getDefaultServerData( serverId );
            
            // Update the provisioner type to the custom type
            if (data != null && data.provisioner != null) {
                data.provisioner.type = type;
                
                // Try to find a valid version for this provisioner type
                var allProvisioners = ProvisionerManager.getBundledProvisioners(type);
                if (allProvisioners.length > 0) {
                    // Use the first (newest) version
                    data.provisioner.version = allProvisioners[0].data.version;
                    Logger.info('${this}: Using version ${data.provisioner.version} for custom provisioner type ${type}');
                } else {
                    Logger.warning('${this}: No versions found for custom provisioner type ${type}');
                    // Set to null to indicate no version is available
                    data.provisioner.version = null;
                }
            }
            
            return data;
        }
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
            {
                result = ServerStatus.Ready;
            }
            else
            {
                result = ServerStatus.Unconfigured;
            }

        }

        if ( !server.isValid() ) 
        {
            Logger.warning( '${server}: Unconfigured because server is not valid' );
            result = ServerStatus.Unconfigured;
        }

        Logger.info( '${server}: Assumed status: ${result}' );

        return result;

    }

    public function getServerDirectory( type:ProvisionerType, id:Int ):String {

        return '${_serverRootDirectory}${type}/${id}';

    }

    /**
     * Removes a server from the manager, but only if it's provisional.
     * This prevents accidental removal of configured servers.
     * @param server The server to remove
     * @return Bool True if the server was removed, false otherwise
     */
    public function removeProvisionalServer(server:Server):Bool {
        // Only remove if the server is provisional
        if (server != null && server.provisional) {
            // Remove the server from the collection
            _servers.remove(server);
            // Dispose of the server to clean up any resources
            server.dispose();
            Logger.info('${this}: Removed provisional server ${server.id}');
            return true;
        }
        Logger.warning('${this}: Cannot remove server ${server != null ? server.id : -1} as it is not provisional');
        return false;
    }

    public function refreshVMInfo( refreshVagrant:Bool, refreshVirtualBox:Bool ) {

        if ( ExecutorManager.getInstance().exists( ServerManagerExecutorContext.RefreshVMInfo ) ) return;

		Logger.info( '${this}: Refreshing System Info...' );

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
		Logger.info( '${this}: Vagrant machines: ${Vagrant.getInstance().machines}' );
		Logger.info( '${this}: VirtualBox machines: ${VirtualBox.getInstance().virtualBoxMachines}' );

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

        for ( f in _onVMInfoRefreshed ) f();

		executor.dispose();

    }

}

enum abstract ServerManagerExecutorContext( String ) to String {

    var RefreshVMInfo = "ServerManager_RefreshVMInfo";

}
