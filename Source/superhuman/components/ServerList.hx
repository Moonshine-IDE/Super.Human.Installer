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
    var _elapsedTimeLabel:Label;
    var _labelInfo:Label;
    var _labelRoles:Label;
    var _labelTitle:Label;
    var _progressIndicator:ProgressIndicator;
    var _server:Server;
    var _serverUpdated:Bool = false;
    var _spacer:LayoutGroup;
    var _statusLabel:Label;
    var _statusLabelGroup:LayoutGroup;
    var _statusLabelGroupLayout:HorizontalLayout;
    var _titleGroup:LayoutGroup;
    var _titleGroupLayout:HorizontalLayout;

    public function new() {

        super();

    }

    public function destroy() {

        if ( _server != null ) {

            if ( _server.onStatusUpdate != null ) _server.onStatusUpdate.clear();
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

        _statusLabelGroupLayout = new HorizontalLayout();
        _statusLabelGroupLayout.gap = GenesisApplicationTheme.GRID;

        _statusLabelGroup = new LayoutGroup();
        _statusLabelGroup.layout = _statusLabelGroupLayout;
        this.addChild( _statusLabelGroup );

        _statusLabel = new Label( '' );
        _statusLabel.variant = GenesisApplicationTheme.LABEL_COPYRIGHT;
        _statusLabelGroup.addChild( _statusLabel );

        _elapsedTimeLabel = new Label( '' );
        _elapsedTimeLabel.variant = GenesisApplicationTheme.LABEL_COPYRIGHT;
        _elapsedTimeLabel.includeInLayout = _elapsedTimeLabel.visible = false;
        _statusLabelGroup.addChild( _elapsedTimeLabel );

        _buttonGroup = new LayoutGroup();
        _buttonGroup.variant = SuperHumanInstallerTheme.LAYOUT_GROUP_SERVER_BUTTON_GROUP;
        this.addChild( _buttonGroup );

        _buttonStart = new GenesisButton();
        _buttonStart.icon = new AdvancedAssetLoader( GenesisApplicationTheme.getAssetPath( GenesisApplicationTheme.ICON_START ) );
        _buttonStart.enabled = true;
        _buttonStart.toolTip = LanguageManager.getInstance().getString( 'serverpage.server.start' );
        _buttonStart.addEventListener( TriggerEvent.TRIGGER, _buttonStartTriggered );
        _buttonGroup.addChild( _buttonStart );

        _buttonStop = new GenesisButton();
        _buttonStop.icon = new AdvancedAssetLoader( GenesisApplicationTheme.getAssetPath( GenesisApplicationTheme.ICON_STOP ) );
        _buttonStop.enabled = _buttonStop.visible = _buttonStop.includeInLayout = false;
        _buttonStop.toolTip = LanguageManager.getInstance().getString( 'serverpage.server.stop' );
        _buttonStop.addEventListener( TriggerEvent.TRIGGER, _buttonStopTriggered );
        _buttonGroup.addChild( _buttonStop );

        _buttonSync = new GenesisButton();
        _buttonSync.icon = new AdvancedAssetLoader( GenesisApplicationTheme.getAssetPath( GenesisApplicationTheme.ICON_UPLOAD ) );
        _buttonSync.enabled = false;
        _buttonSync.toolTip = LanguageManager.getInstance().getString( 'serverpage.server.resync' );
        _buttonSync.addEventListener( TriggerEvent.TRIGGER, _buttonSyncTriggered );
        _buttonGroup.addChild( _buttonSync );

        _buttonProvision = new GenesisButton();
        _buttonProvision.icon = new AdvancedAssetLoader( GenesisApplicationTheme.getAssetPath( GenesisApplicationTheme.ICON_REFRESH ) );
        _buttonProvision.enabled = false;
        _buttonProvision.toolTip = LanguageManager.getInstance().getString( 'serverpage.server.provision' );
        _buttonProvision.addEventListener( TriggerEvent.TRIGGER, _buttonProvisionTriggered );
        _buttonGroup.addChild( _buttonProvision );

        _buttonDestroy = new GenesisButton();
        _buttonDestroy.enabled = false;
        _buttonDestroy.icon = new AdvancedAssetLoader( GenesisApplicationTheme.getAssetPath( GenesisApplicationTheme.ICON_DESTROY ) );
        _buttonDestroy.toolTip = LanguageManager.getInstance().getString( 'serverpage.server.destroy' );
        _buttonDestroy.addEventListener( TriggerEvent.TRIGGER, _buttonDestroyTriggered );
        _buttonGroup.addChild( _buttonDestroy );

        _buttonConsole = new GenesisButton();
        _buttonConsole.icon = new AdvancedAssetLoader( GenesisApplicationTheme.getAssetPath( GenesisApplicationTheme.ICON_OUTPUT ) );
        _buttonConsole.addEventListener( TriggerEvent.TRIGGER, _buttonConsoleTriggered );
        _buttonConsole.toolTip = LanguageManager.getInstance().getString( 'serverpage.server.output' );
        _buttonGroup.addChild( _buttonConsole );

        _buttonOpenBrowser = new GenesisButton();
        _buttonOpenBrowser.icon = new AdvancedAssetLoader( GenesisApplicationTheme.getAssetPath( GenesisApplicationTheme.ICON_WEB ) );
        _buttonOpenBrowser.enabled = false;
        _buttonOpenBrowser.toolTip = LanguageManager.getInstance().getString( 'serverpage.server.welcomepage' );
        _buttonOpenBrowser.addEventListener( TriggerEvent.TRIGGER, _buttonOpenBrowserTriggered );
        _buttonGroup.addChild( _buttonOpenBrowser );

        _buttonSSH = new GenesisButton();
        _buttonSSH.enabled = false;
        _buttonSSH.icon = new AdvancedAssetLoader( GenesisApplicationTheme.getAssetPath( GenesisApplicationTheme.ICON_CONSOLE ) );
        _buttonSSH.toolTip = LanguageManager.getInstance().getString( 'serverpage.server.vagrantssh' );
        _buttonSSH.addEventListener( TriggerEvent.TRIGGER, _buttonSSHTriggered );
        _buttonGroup.addChild( _buttonSSH );

        _buttonOpenDir = new GenesisButton();
        _buttonOpenDir.icon = new AdvancedAssetLoader( GenesisApplicationTheme.getAssetPath( GenesisApplicationTheme.ICON_FOLDER ) );
        _buttonOpenDir.toolTip = LanguageManager.getInstance().getString( 'serverpage.server.directory' );
        _buttonOpenDir.addEventListener( TriggerEvent.TRIGGER, _buttonOpenDirTriggered );
        #if debug _buttonGroup.addChild( _buttonOpenDir ); #end

        _buttonDelete = new GenesisButton();
        _buttonDelete.icon = new AdvancedAssetLoader( GenesisApplicationTheme.getAssetPath( GenesisApplicationTheme.ICON_DELETE ) );
        _buttonDelete.toolTip = LanguageManager.getInstance().getString( 'serverpage.server.delete' );
        _buttonDelete.addEventListener( TriggerEvent.TRIGGER, _buttonDeleteTriggered );
        #if debug _buttonGroup.addChild( _buttonDelete ); #end

        _spacer = new LayoutGroup();
        _spacer.layoutData = new HorizontalLayoutData( 100 );
        _buttonGroup.addChild( _spacer );

        _buttonConfigure = new GenesisButton();
        _buttonConfigure.icon = new AdvancedAssetLoader( GenesisApplicationTheme.getAssetPath( GenesisApplicationTheme.ICON_SETTINGS ) );
        _buttonConfigure.addEventListener( TriggerEvent.TRIGGER, _buttonConfigureTriggered );
        _buttonConfigure.toolTip = LanguageManager.getInstance().getString( 'serverpage.server.configure' );
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
            if ( _server.onStatusUpdate != null ) _server.onStatusUpdate.clear();
            if ( _server.onVagrantUpElapsedTimerUpdate != null ) _server.onVagrantUpElapsedTimerUpdate.clear();

        }

    }

    public function updateServer( server:Server ) {

        if ( _serverUpdated ) return;

        if ( _server != null ) {

            #if neko
            // List.remove( func ) is not working on Neko,
            // so the entire List must be cleared
            _server.onUpdate.clear();
            _server.onStatusUpdate.clear();
            _server.onVagrantUpElapsedTimerUpdate.clear();
            #else
            _server.onUpdate.remove( _updateServer );
            _server.onStatusUpdate.remove( _updateServer );
            _server.onVagrantUpElapsedTimerUpdate.remove( _updateVagrantUpElapsedTimer );
            #end

        }

        _server = server;
        #if neko
        // Putting back the main class' function on Neko
        _server.onUpdate.add( SuperHumanInstaller.getInstance().onServerPropertyChanged );
        _server.onStatusUpdate.add( _updateServer );
        _server.onVagrantUpElapsedTimerUpdate.add( _updateVagrantUpElapsedTimer );
        #end
        _server.onUpdate.add( _updateServer );
        _server.onStatusUpdate.add( _updateServer );
        _server.onVagrantUpElapsedTimerUpdate.add( _updateVagrantUpElapsedTimer );

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
        _labelRoles.text = LanguageManager.getInstance().getString( 'serverpage.server.roles', _getServerRoleNames() );
        var cpu:String = ( _server.numCPUs.value == 1 ) ? "CPU" : "CPUs";
        var prov:String = '${_server.provisioner.type} v${_server.provisioner.version}';
        _labelInfo.text = LanguageManager.getInstance().getString( 'serverpage.server.sysinfo', prov, Std.string( _server.numCPUs.value ), cpu, Std.string( _server.memory.value ) );
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
        _statusLabel.text = LanguageManager.getInstance().getString( 'serverpage.server.status.unavailable' );
        _elapsedTimeLabel.visible = _elapsedTimeLabel.includeInLayout = false;

        _progressIndicator.visible = _server.busy;
        if ( _server.busy ) _progressIndicator.start() else _progressIndicator.stop();

        if ( !Vagrant.getInstance().exists || !VirtualBox.getInstance().exists ) return;

        switch ( _server.status.value ) {

            case ServerStatus.Stopped:
                _buttonConfigure.enabled = _buttonConfigure.includeInLayout = _buttonConfigure.visible = true;
                _buttonDestroy.enabled = _buttonDestroy.includeInLayout = _buttonDestroy.visible = true;
                _buttonStart.visible = _buttonStart.includeInLayout = _buttonStart.enabled = true;
                _statusLabel.text = LanguageManager.getInstance().getString( 'serverpage.server.status.stopped' );

            case ServerStatus.Stopping:
                _statusLabel.text = LanguageManager.getInstance().getString( 'serverpage.server.status.stopping' );

            case ServerStatus.FirstStart:
                _statusLabel.text = LanguageManager.getInstance().getString( 'serverpage.server.status.firststart' );
                _elapsedTimeLabel.visible = _elapsedTimeLabel.includeInLayout = true;
                _elapsedTimeLabel.text = LanguageManager.getInstance().getString( 'serverpage.server.status.elapsedtime', "" );

            case ServerStatus.Start:
                _statusLabel.text = LanguageManager.getInstance().getString( 'serverpage.server.status.start' );
                _elapsedTimeLabel.visible = _elapsedTimeLabel.includeInLayout = true;
                _elapsedTimeLabel.text = LanguageManager.getInstance().getString( 'serverpage.server.status.elapsedtime', "" );

            case ServerStatus.Initializing:
                _statusLabel.text = LanguageManager.getInstance().getString( 'serverpage.server.status.initializing' );

            case ServerStatus.Running:
                _buttonOpenBrowser.enabled = _buttonOpenBrowser.includeInLayout = _buttonOpenBrowser.visible = true;
                _buttonSSH.enabled = _buttonSSH.includeInLayout = _buttonSSH.visible = true;
                _buttonStop.includeInLayout = _buttonStop.visible = _buttonStop.enabled = true;
                _statusLabel.text = ( _server.provisioned ) ? LanguageManager.getInstance().getString( 'serverpage.server.status.running', '(IP: ${_server.provisioner.ipAddress})' ) : LanguageManager.getInstance().getString( 'serverpage.server.status.running', '' );

            case ServerStatus.Unconfigured:
                _buttonConfigure.enabled = _buttonConfigure.includeInLayout = _buttonConfigure.visible = true;
                _buttonConfigure.icon = new AdvancedAssetLoader( GenesisApplicationTheme.getAssetPath( GenesisApplicationTheme.ICON_SETTINGS_WARNING ) );
                _buttonDelete.enabled = _buttonDelete.includeInLayout = _buttonDelete.visible = true;
                _statusLabel.text = LanguageManager.getInstance().getString( 'serverpage.server.status.unconfigured' );

            case ServerStatus.Ready:
                _buttonConfigure.enabled = _buttonConfigure.includeInLayout = _buttonConfigure.visible = true;
                _buttonDelete.enabled = _buttonDelete.includeInLayout = _buttonDelete.visible = true;
                _buttonStart.enabled = _buttonStart.includeInLayout = _buttonStart.visible = true;
                _statusLabel.text = ( _server.provisioned ) ? LanguageManager.getInstance().getString( 'serverpage.server.status.readyprovisioned' ) : LanguageManager.getInstance().getString( 'serverpage.server.status.ready' );

            case ServerStatus.Provisioning:
                _statusLabel.text = LanguageManager.getInstance().getString( 'serverpage.server.status.provisioning' );

            case ServerStatus.RSyncing:
                _statusLabel.text = LanguageManager.getInstance().getString( 'serverpage.server.status.rsyncing' );

            case ServerStatus.GetStatus:
                _statusLabel.text = LanguageManager.getInstance().getString( 'serverpage.server.status.getstatus' );

            case ServerStatus.Destroying:
                _statusLabel.text = LanguageManager.getInstance().getString( 'serverpage.server.status.destroying' );

            case ServerStatus.Error:
                _buttonConfigure.enabled = _buttonConfigure.includeInLayout = _buttonConfigure.visible = true;
                _buttonDelete.enabled = _buttonDelete.includeInLayout = _buttonDelete.visible = true;
                _buttonStart.enabled = _buttonStart.visible = _buttonStart.includeInLayout = true;
                _statusLabel.text = LanguageManager.getInstance().getString( 'serverpage.server.status.error' );

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
                _statusLabel.text = LanguageManager.getInstance().getString( 'serverpage.server.status.stopped' );

        }

    }

    function _updateVagrantUpElapsedTimer() {

        if ( _server != null && _elapsedTimeLabel != null && _elapsedTimeLabel.visible == true ) {

            var elapsed = StrTools.timeToFormattedString( _server.vagrantUpElapsedTime );
            var percentage = StrTools.calculatePercentage( _server.provisioner.numberOfStartedTasks, _server.provisioner.numberOfTasks );
            if ( _server.provisioner.provisioned )
                _elapsedTimeLabel.text = LanguageManager.getInstance().getString( 'serverpage.server.status.elapsedtime', '${elapsed}' )
            else
                _elapsedTimeLabel.text = LanguageManager.getInstance().getString( 'serverpage.server.status.elapsedtimewithtasks', '${elapsed}', '${_server.provisioner.numberOfStartedTasks+1}/${_server.provisioner.numberOfTasks+1}' );

        }

    }

}