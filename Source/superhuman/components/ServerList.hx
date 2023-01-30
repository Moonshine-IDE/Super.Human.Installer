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

package superhuman.components;

import feathers.controls.Label;
import feathers.controls.LayoutGroup;
import feathers.controls.ListView;
import feathers.controls.dataRenderers.LayoutGroupItemRenderer;
import feathers.data.IFlatCollection;
import feathers.data.ListViewItemState;
import feathers.events.TriggerEvent;
import feathers.layout.HorizontalLayout;
import feathers.layout.HorizontalLayoutData;
import feathers.layout.VerticalAlign;
import feathers.layout.VerticalLayoutData;
import feathers.utils.DisplayObjectRecycler;
import genesis.application.components.AdvancedAssetLoader;
import genesis.application.components.GenesisButton;
import genesis.application.components.ProgressIndicator;
import genesis.application.managers.LanguageManager;
import genesis.application.theme.GenesisApplicationTheme;
import openfl.events.Event;
import prominic.core.primitives.Property;
import prominic.sys.applications.hashicorp.Vagrant;
import prominic.sys.applications.oracle.VirtualBox;
import prominic.sys.tools.StrTools;
import superhuman.events.SuperHumanApplicationEvent;
import superhuman.server.Server;
import superhuman.server.ServerStatus;
import superhuman.theme.SuperHumanInstallerTheme;

@:styleContext
class ServerList extends ListView {

    public function new( ?dataProvider:IFlatCollection<Dynamic> ) {

        super( dataProvider );

        var recycler = DisplayObjectRecycler.withFunction( () -> {

            var item = new ServerItem();
            item.addEventListener( SuperHumanApplicationEvent.CLOSE_CONSOLE, _forwardEvent );
            item.addEventListener( SuperHumanApplicationEvent.CONFIGURE_SERVER, _forwardEvent );
            item.addEventListener( SuperHumanApplicationEvent.COPY_TO_CLIPBOARD, _forwardEvent );
            item.addEventListener( SuperHumanApplicationEvent.DELETE_SERVER, _forwardEvent );
            item.addEventListener( SuperHumanApplicationEvent.DESTROY_SERVER, _forwardEvent );
            item.addEventListener( SuperHumanApplicationEvent.OPEN_BROWSER, _forwardEvent );
            item.addEventListener( SuperHumanApplicationEvent.OPEN_CONSOLE, _forwardEvent );
            item.addEventListener( SuperHumanApplicationEvent.OPEN_VAGRANT_SSH, _forwardEvent );
            item.addEventListener( SuperHumanApplicationEvent.PROVISION_SERVER, _forwardEvent );
            item.addEventListener( SuperHumanApplicationEvent.START_SERVER, _forwardEvent );
            item.addEventListener( SuperHumanApplicationEvent.STOP_SERVER, _forwardEvent );
            item.addEventListener( SuperHumanApplicationEvent.SYNC_SERVER, _forwardEvent );
            #if debug
            item.addEventListener( SuperHumanApplicationEvent.OPEN_SERVER_DIRECTORY, _forwardEvent );
            item.addEventListener( SuperHumanApplicationEvent.RESET_SERVER, _forwardEvent );
            #end
            return item;

        } );

        recycler.update = ( item:ServerItem, state:ListViewItemState) -> {

            item.updateServer( state.data );

        };

        recycler.reset = ( item:ServerItem, state:ListViewItemState) -> {

            item.reset();

        };

        recycler.destroy = ( item:ServerItem ) -> {

            item.removeEventListener( SuperHumanApplicationEvent.CLOSE_CONSOLE, _forwardEvent );
            item.removeEventListener( SuperHumanApplicationEvent.CONFIGURE_SERVER, _forwardEvent );
            item.removeEventListener( SuperHumanApplicationEvent.COPY_TO_CLIPBOARD, _forwardEvent );
            item.removeEventListener( SuperHumanApplicationEvent.DELETE_SERVER, _forwardEvent );
            item.removeEventListener( SuperHumanApplicationEvent.DESTROY_SERVER, _forwardEvent );
            item.removeEventListener( SuperHumanApplicationEvent.OPEN_BROWSER, _forwardEvent );
            item.removeEventListener( SuperHumanApplicationEvent.OPEN_CONSOLE, _forwardEvent );
            item.removeEventListener( SuperHumanApplicationEvent.OPEN_VAGRANT_SSH, _forwardEvent );
            item.removeEventListener( SuperHumanApplicationEvent.PROVISION_SERVER, _forwardEvent );
            item.removeEventListener( SuperHumanApplicationEvent.START_SERVER, _forwardEvent );
            item.removeEventListener( SuperHumanApplicationEvent.STOP_SERVER, _forwardEvent );
            item.removeEventListener( SuperHumanApplicationEvent.SYNC_SERVER, _forwardEvent );
            #if debug
            item.removeEventListener( SuperHumanApplicationEvent.OPEN_SERVER_DIRECTORY, _forwardEvent );
            item.removeEventListener( SuperHumanApplicationEvent.RESET_SERVER, _forwardEvent );
            #end
            item.destroy();

        };

        this.itemRendererRecycler = recycler;

    }

    function _forwardEvent( e:SuperHumanApplicationEvent ) {

        this.dispatchEvent( e );

    }

}

@:styleContext
class ServerItem extends LayoutGroupItemRenderer {

    var _buttonConfigure:GenesisButton;
    var _buttonConsole:GenesisButton;
    var _buttonDelete:GenesisButton;
    var _buttonDestroy:GenesisButton;
    var _buttonGroup:LayoutGroup;
    var _buttonOpenBrowser:GenesisButton;
    var _buttonOpenDir:GenesisButton;
    var _buttonProvision:GenesisButton;
    var _buttonSSH:GenesisButton;
    var _buttonStart:GenesisButton;
    var _buttonStop:GenesisButton;
    var _buttonSync:GenesisButton;
    var _console:Console;
    var _develKeys:Property<Bool>;
    var _labelInfo:Label;
    var _labelRoles:Label;
    var _labelTitle:Label;
    var _progressIndicator:ProgressIndicator;
    var _server:Server;
    var _serverUpdated:Bool = false;
    var _spacer:LayoutGroup;
    var _statusLabel:Label;
    var _titleGroup:LayoutGroup;
    var _titleGroupLayout:HorizontalLayout;

    public function new() {

        super();

    }

    public function destroy() {

        if ( _server != null ) {

            if ( _server.onUpdate != null ) _server.onUpdate.clear();
            _server = null;

        }

    }

    override function initialize() {

        super.initialize();

        _titleGroupLayout = new HorizontalLayout();
        _titleGroupLayout.verticalAlign = VerticalAlign.MIDDLE;

        _titleGroup = new LayoutGroup();
        _titleGroup.layoutData = new VerticalLayoutData( 100 );
        _titleGroup.layout = _titleGroupLayout;
        this.addChild( _titleGroup );

        _labelTitle = new Label();
        _labelTitle.variant = GenesisApplicationTheme.LABEL_LARGE;
        _labelTitle.layoutData = new HorizontalLayoutData( 100 );
        _titleGroup.addChild( _labelTitle );

        _progressIndicator = new ProgressIndicator( 20, 16, 0xAAAAAA );
        _progressIndicator.visible = false;
        _titleGroup.addChild( _progressIndicator );

        _labelRoles = new Label();
        _labelRoles.variant = GenesisApplicationTheme.LABEL_COPYRIGHT;
        this.addChild( _labelRoles );

        _labelInfo = new Label();
        _labelInfo.variant = GenesisApplicationTheme.LABEL_COPYRIGHT;
        this.addChild( _labelInfo );

        _statusLabel = new Label( "Status:" );
        _statusLabel.variant = GenesisApplicationTheme.LABEL_COPYRIGHT;
        this.addChild( _statusLabel );

        _buttonGroup = new LayoutGroup();
        _buttonGroup.variant = SuperHumanInstallerTheme.LAYOUT_GROUP_SERVER_BUTTON_GROUP;
        this.addChild( _buttonGroup );

        _buttonStart = new GenesisButton();
        _buttonStart.icon = new AdvancedAssetLoader( GenesisApplicationTheme.getAssetPath( GenesisApplicationTheme.ICON_START ) );
        _buttonStart.enabled = true;
        _buttonStart.toolTip = "Start server";
        _buttonStart.addEventListener( TriggerEvent.TRIGGER, _buttonStartTriggered );
        _buttonGroup.addChild( _buttonStart );

        _buttonStop = new GenesisButton();
        _buttonStop.icon = new AdvancedAssetLoader( GenesisApplicationTheme.getAssetPath( GenesisApplicationTheme.ICON_STOP ) );
        _buttonStop.enabled = _buttonStop.visible = _buttonStop.includeInLayout = false;
        _buttonStop.toolTip = "Stop server";
        _buttonStop.addEventListener( TriggerEvent.TRIGGER, _buttonStopTriggered );
        _buttonGroup.addChild( _buttonStop );

        _buttonSync = new GenesisButton();
        _buttonSync.icon = new AdvancedAssetLoader( GenesisApplicationTheme.getAssetPath( GenesisApplicationTheme.ICON_UPLOAD ) );
        _buttonSync.enabled = false;
        _buttonSync.toolTip = "Re-sync configuration files";
        _buttonSync.addEventListener( TriggerEvent.TRIGGER, _buttonSyncTriggered );
        _buttonGroup.addChild( _buttonSync );

        _buttonProvision = new GenesisButton();
        _buttonProvision.icon = new AdvancedAssetLoader( GenesisApplicationTheme.getAssetPath( GenesisApplicationTheme.ICON_REFRESH ) );
        _buttonProvision.enabled = false;
        _buttonProvision.toolTip = "Run provisioning on server";
        _buttonProvision.addEventListener( TriggerEvent.TRIGGER, _buttonProvisionTriggered );
        _buttonGroup.addChild( _buttonProvision );

        _buttonDestroy = new GenesisButton();
        _buttonDestroy.enabled = false;
        _buttonDestroy.icon = new AdvancedAssetLoader( GenesisApplicationTheme.getAssetPath( GenesisApplicationTheme.ICON_DESTROY ) );
        _buttonDestroy.toolTip = "Destroy server";
        _buttonDestroy.addEventListener( TriggerEvent.TRIGGER, _buttonDestroyTriggered );
        _buttonGroup.addChild( _buttonDestroy );

        _buttonConsole = new GenesisButton();
        _buttonConsole.icon = new AdvancedAssetLoader( GenesisApplicationTheme.getAssetPath( GenesisApplicationTheme.ICON_OUTPUT ) );
        _buttonConsole.addEventListener( TriggerEvent.TRIGGER, _buttonConsoleTriggered );
        _buttonConsole.toolTip = "Display output";
        _buttonGroup.addChild( _buttonConsole );

        _buttonOpenBrowser = new GenesisButton();
        _buttonOpenBrowser.icon = new AdvancedAssetLoader( GenesisApplicationTheme.getAssetPath( GenesisApplicationTheme.ICON_WEB ) );
        _buttonOpenBrowser.enabled = false;
        _buttonOpenBrowser.toolTip = "Open Welcome page in browser";
        _buttonOpenBrowser.addEventListener( TriggerEvent.TRIGGER, _buttonOpenBrowserTriggered );
        _buttonGroup.addChild( _buttonOpenBrowser );

        _buttonSSH = new GenesisButton();
        _buttonSSH.enabled = false;
        _buttonSSH.icon = new AdvancedAssetLoader( GenesisApplicationTheme.getAssetPath( GenesisApplicationTheme.ICON_CONSOLE ) );
        _buttonSSH.toolTip = "Open Vagrant SSH in Terminal";
        _buttonSSH.addEventListener( TriggerEvent.TRIGGER, _buttonSSHTriggered );
        _buttonGroup.addChild( _buttonSSH );

        _buttonOpenDir = new GenesisButton();
        _buttonOpenDir.icon = new AdvancedAssetLoader( GenesisApplicationTheme.getAssetPath( GenesisApplicationTheme.ICON_FOLDER ) );
        _buttonOpenDir.toolTip = "Open server directory in default file manager, and in Terminal";
        _buttonOpenDir.addEventListener( TriggerEvent.TRIGGER, _buttonOpenDirTriggered );
        #if debug _buttonGroup.addChild( _buttonOpenDir ); #end

        _buttonDelete = new GenesisButton();
        _buttonDelete.icon = new AdvancedAssetLoader( GenesisApplicationTheme.getAssetPath( GenesisApplicationTheme.ICON_DELETE ) );
        _buttonDelete.toolTip = "Delete server";
        _buttonDelete.addEventListener( TriggerEvent.TRIGGER, _buttonDeleteTriggered );
        #if debug _buttonGroup.addChild( _buttonDelete ); #end

        _spacer = new LayoutGroup();
        _spacer.layoutData = new HorizontalLayoutData( 100 );
        _buttonGroup.addChild( _spacer );

        _buttonConfigure = new GenesisButton();
        _buttonConfigure.icon = new AdvancedAssetLoader( GenesisApplicationTheme.getAssetPath( GenesisApplicationTheme.ICON_SETTINGS ) );
        _buttonConfigure.addEventListener( TriggerEvent.TRIGGER, _buttonConfigureTriggered );
        _buttonConfigure.toolTip = "Configure server";
        _buttonGroup.addChild( _buttonConfigure );

        _console = new Console( LanguageManager.getInstance().getString( 'serverpage.server.console.serverloaded' ) );
        _console.addEventListener( Event.CHANGE, _consoleChanged );
        _console.addEventListener( SuperHumanApplicationEvent.CLOSE_CONSOLE, _closeConsole );
        _console.addEventListener( SuperHumanApplicationEvent.COPY_TO_CLIPBOARD, _copyToClipboard );

        if ( _server != null ) {

            _server.console = _console;
            _console.propertyId = Std.string( _server.id );
            _updateServer( _server, false );

        }

    }

    public function reset() {

        if ( _server != null ) {

            if ( _server.onUpdate != null ) _server.onUpdate.clear();

        }

    }

    public function updateServer( server:Server ) {

        if ( _serverUpdated ) return;

        if ( _server != null ) {

            #if neko
            // List.remove( func ) is not working on Neko,
            // so the entire List must be cleared
            _server.onUpdate.clear();
            #else
            _server.onUpdate.remove( _updateServer );
            #end

        }

        _server = server;
        #if neko
        // Putting back the main class' function on Neko
        _server.onUpdate.add( SuperHumanInstaller.getInstance().onServerPropertyChanged );
        #end
        _server.onUpdate.add( _updateServer );

        if ( _labelTitle != null ) {

            _server.console = _console;
            _console.propertyId = Std.string( _server.id );
            _updateServer( _server, false );
    
        }

        _serverUpdated = true;

    }

    function _buttonConfigureTriggered( e:TriggerEvent ) {

        var event = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.CONFIGURE_SERVER );
        event.server = _server;
        this.dispatchEvent( event );

    }

    function _buttonConsoleTriggered( e:TriggerEvent ) {

        var event = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.OPEN_CONSOLE );
        event.server = _server;
        event.console = _console;
        this.dispatchEvent( event );

    }

    function _buttonDeleteTriggered( e:TriggerEvent ) {

        var event = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.DELETE_SERVER );
        event.server = _server;
        this.dispatchEvent( event );

    }

    function _buttonDestroyTriggered( e:TriggerEvent ) {

        var event = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.DESTROY_SERVER );
        event.server = _server;
        this.dispatchEvent( event );

    }

    function _buttonOpenBrowserTriggered( e:TriggerEvent ) {

        var event = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.OPEN_BROWSER );
        event.server = _server;
        this.dispatchEvent( event );

    }

    function _buttonOpenDirTriggered( e:TriggerEvent ) {

        #if debug

        var event = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.OPEN_SERVER_DIRECTORY );
        event.server = _server;
        this.dispatchEvent( event );

        #end

    }

    function _buttonProvisionTriggered( e:TriggerEvent ) {

        var event = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.PROVISION_SERVER );
        event.server = _server;
        this.dispatchEvent( event );

    }

    function _buttonResetTriggered( e:TriggerEvent ) {

        #if debug

        var event = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.RESET_SERVER );
        event.server = _server;
        this.dispatchEvent( event );

        #end

    }

    function _buttonSSHTriggered( e:TriggerEvent ) {

        var event = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.OPEN_VAGRANT_SSH );
        event.server = _server;
        this.dispatchEvent( event );

    }

    function _buttonStartTriggered( e:TriggerEvent ) {

        var event = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.START_SERVER );
        event.server = _server;
        this.dispatchEvent( event );

    }

    function _buttonStopTriggered( e:TriggerEvent ) {

        var event = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.STOP_SERVER );
        event.server = _server;
        this.dispatchEvent( event );

    }

    function _buttonSyncTriggered( e:TriggerEvent ) {

        var event = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.SYNC_SERVER );
        event.server = _server;
        this.dispatchEvent( event );

    }

    function _copyToClipboard( e:SuperHumanApplicationEvent ) {

        this.dispatchEvent( e );

    }

    function _closeConsole( e:SuperHumanApplicationEvent ) {

        this.dispatchEvent( e );

    }

    function _consoleChanged( e:Event ) {

        if ( _console.hasNewMessage ) {

            if ( _console.hasError ) {

                _buttonConsole.icon = new AdvancedAssetLoader( GenesisApplicationTheme.ICON_OUTPUT_ERROR );

            } else {

                _buttonConsole.icon = new AdvancedAssetLoader( GenesisApplicationTheme.ICON_OUTPUT_NEW );

            }

        } else {

            _buttonConsole.icon = new AdvancedAssetLoader( GenesisApplicationTheme.ICON_OUTPUT );

        }

    }

    function _getServerRoleNames():String {

        var s:String = "";
        var a:Array<String> = [];

        for ( role in SuperHumanInstaller.getInstance().serverRolesCollection ) {

            for ( subrole in _server.roles.value ) {

                if ( subrole.value == role.role.value && subrole.enabled ) a.push( role.name );

            }

        }

        s = ( a.length > 0 ) ? a.join( ", " ) : "None";
        return s;

    }

    function _updateServer( server:Server, requiresSave:Bool ) {

        _labelTitle.text = '#${_server.id}: ${_server.fqdn}';
        _labelRoles.text = 'Roles: ${_getServerRoleNames()}';
        var cpu:String = ( _server.numCPUs.value == 1 ) ? "CPU" : "CPUs";
        _labelInfo.text = 'Provisioner: demo-tasks v${_server.vagrantProvisioner.version}  •  System: ${_server.numCPUs.value} ${cpu}, ${_server.memory.value}GB RAM';
        if ( _server.diskUsage.value != 0 ) _labelInfo.text += '  •  Est. disk usage: ${ StrTools.autoFormatBytes( _server.diskUsage.value )}';

        _buttonConfigure.enabled = _buttonConfigure.includeInLayout = _buttonConfigure.visible = false;
        _buttonConfigure.icon = new AdvancedAssetLoader( GenesisApplicationTheme.getAssetPath( GenesisApplicationTheme.ICON_SETTINGS ) );
        _buttonDelete.enabled = _buttonDelete.includeInLayout = _buttonDelete.visible = false;
        _buttonDestroy.enabled = _buttonDestroy.includeInLayout = _buttonDestroy.visible = false;
        _buttonOpenBrowser.enabled = _buttonOpenBrowser.includeInLayout = _buttonOpenBrowser.visible = false;
        _buttonProvision.enabled = _buttonProvision.includeInLayout = _buttonProvision.visible = false;
        _buttonSSH.enabled = _buttonSSH.includeInLayout = _buttonSSH.visible = false;
        _buttonStart.enabled = _buttonStart.includeInLayout = _buttonStart.visible = false;
        _buttonStop.includeInLayout = _buttonStop.visible = _buttonStop.enabled = false;
        _buttonSync.enabled = _buttonSync.includeInLayout = _buttonSync.visible = false;
        _statusLabel.text = "Status: Unavailable";

        _progressIndicator.visible = _server.busy;
        if ( _server.busy ) _progressIndicator.start() else _progressIndicator.stop();

        if ( !Vagrant.getInstance().exists || !VirtualBox.getInstance().exists ) return;

        switch ( _server.status.value ) {

            case ServerStatus.Stopped:
                _buttonConfigure.enabled = _buttonConfigure.includeInLayout = _buttonConfigure.visible = true;
                _buttonDestroy.enabled = _buttonDestroy.includeInLayout = _buttonDestroy.visible = true;
                _buttonStart.visible = _buttonStart.includeInLayout = _buttonStart.enabled = true;
                _statusLabel.text = "Status: Stopped";

            case ServerStatus.Stopping:
                _statusLabel.text = "Status: Stopping, please wait...";

            case ServerStatus.FirstStart:
                _statusLabel.text = "Status: Starting for the first time. This might take a while, please be patient";

            case ServerStatus.Start:
                _statusLabel.text = "Status: Starting, please wait";

            case ServerStatus.Initializing:
                _statusLabel.text = "Status: Initializing";

            case ServerStatus.Running:
                _buttonOpenBrowser.enabled = _buttonOpenBrowser.includeInLayout = _buttonOpenBrowser.visible = true;
                _buttonSSH.enabled = _buttonSSH.includeInLayout = _buttonSSH.visible = true;
                _buttonStop.includeInLayout = _buttonStop.visible = _buttonStop.enabled = true;
                _statusLabel.text = "Status: Running";

            case ServerStatus.Unconfigured:
                _buttonConfigure.enabled = _buttonConfigure.includeInLayout = _buttonConfigure.visible = true;
                _buttonConfigure.icon = new AdvancedAssetLoader( GenesisApplicationTheme.getAssetPath( GenesisApplicationTheme.ICON_SETTINGS_WARNING ) );
                _buttonDelete.enabled = _buttonDelete.includeInLayout = _buttonDelete.visible = true;
                _statusLabel.text = "Status: Not configured. Please configure your server";

            case ServerStatus.Ready:
                _buttonConfigure.enabled = _buttonConfigure.includeInLayout = _buttonConfigure.visible = true;
                _buttonDelete.enabled = _buttonDelete.includeInLayout = _buttonDelete.visible = true;
                _buttonStart.enabled = _buttonStart.includeInLayout = _buttonStart.visible = true;
                _statusLabel.text = "Status: Ready to start";

            case ServerStatus.Provisioning:
                _statusLabel.text = "Status: Provisioning, please wait...";

            case ServerStatus.RSyncing:
                _statusLabel.text = "Status: Synchronizing, please wait...";

            case ServerStatus.GetStatus:
                _statusLabel.text = "Status: Retrieving status, please wait...";

            case ServerStatus.Destroying:
                _statusLabel.text = "Status: Destroying, please wait...";

            case ServerStatus.Error:
                _buttonConfigure.enabled = _buttonConfigure.includeInLayout = _buttonConfigure.visible = true;
                _buttonDelete.enabled = _buttonDelete.includeInLayout = _buttonDelete.visible = true;
                _buttonStart.enabled = _buttonStart.visible = _buttonStart.includeInLayout = true;
                _statusLabel.text = "Status: Error. Please check the server's output, review your server configuration, and try again";

            default:
                _buttonConfigure.enabled = _buttonConfigure.includeInLayout = _buttonConfigure.visible = false;
                _buttonDelete.enabled = _buttonDelete.includeInLayout = _buttonDelete.visible = true;
                _buttonDestroy.enabled = _buttonDestroy.includeInLayout = _buttonDestroy.visible = false;
                _buttonOpenBrowser.enabled = _buttonOpenBrowser.includeInLayout = _buttonOpenBrowser.visible = false;
                _buttonProvision.enabled = _buttonProvision.includeInLayout = _buttonProvision.visible = false;
                _buttonSSH.enabled = _buttonSSH.includeInLayout = _buttonSSH.visible = false;
                _buttonStart.enabled = _buttonStart.includeInLayout = _buttonStart.visible = false;
                _buttonStop.includeInLayout = _buttonStop.visible = _buttonStop.enabled = false;
                _buttonSync.enabled = _buttonSync.includeInLayout = _buttonSync.visible = false;
                _statusLabel.text = "Status: Stopped";

        }

    }

}