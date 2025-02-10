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

import superhuman.server.provisioners.AdditionalProvisioner;
import superhuman.server.provisioners.DemoTasks;
import feathers.controls.BitmapImage;
import openfl.Assets;
import champaign.core.logging.Logger;
import champaign.core.primitives.Property;
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
import genesis.application.components.GenesisButton;
import genesis.application.components.ProgressIndicator;
import genesis.application.managers.LanguageManager;
import genesis.application.theme.GenesisApplicationTheme;
import openfl.events.Event;
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
            item.addEventListener( SuperHumanApplicationEvent.OPEN_BROWSER_SERVER_ADDRESS, _forwardEvent );
            item.addEventListener( SuperHumanApplicationEvent.OPEN_CONSOLE, _forwardEvent );
            item.addEventListener( SuperHumanApplicationEvent.OPEN_VAGRANT_SSH, _forwardEvent );
            item.addEventListener( SuperHumanApplicationEvent.PROVISION_SERVER, _forwardEvent );
            item.addEventListener( SuperHumanApplicationEvent.START_SERVER, _forwardEvent );
            item.addEventListener( SuperHumanApplicationEvent.STOP_SERVER, _forwardEvent );
            item.addEventListener( SuperHumanApplicationEvent.SUSPEND_SERVER, _forwardEvent );
            item.addEventListener( SuperHumanApplicationEvent.SYNC_SERVER, _forwardEvent );
            item.addEventListener( SuperHumanApplicationEvent.OPEN_SERVER_DIRECTORY, _forwardEvent );
            item.addEventListener( SuperHumanApplicationEvent.OPEN_FTP_CLIENT, _forwardEvent );
            #if debug
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
            item.removeEventListener( SuperHumanApplicationEvent.OPEN_BROWSER_SERVER_ADDRESS, _forwardEvent );
            item.removeEventListener( SuperHumanApplicationEvent.OPEN_CONSOLE, _forwardEvent );
            item.removeEventListener( SuperHumanApplicationEvent.OPEN_VAGRANT_SSH, _forwardEvent );
            item.removeEventListener( SuperHumanApplicationEvent.PROVISION_SERVER, _forwardEvent );
            item.removeEventListener( SuperHumanApplicationEvent.START_SERVER, _forwardEvent );
            item.removeEventListener( SuperHumanApplicationEvent.STOP_SERVER, _forwardEvent );
            item.removeEventListener( SuperHumanApplicationEvent.SYNC_SERVER, _forwardEvent );
            item.removeEventListener( SuperHumanApplicationEvent.OPEN_SERVER_DIRECTORY, _forwardEvent );
            item.removeEventListener( SuperHumanApplicationEvent.OPEN_FTP_CLIENT, _forwardEvent);
            
            #if debug
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
    
    private static final CONTROL_BUTTON_WIDTH:Float = 50;
    private static final CONTROL_BUTTON_HEIGHT:Float = 30;

    var _labelTitle:Label;
    var _progressIndicator:ProgressIndicator;  
    var _labelRoles:Label;
    var _labelInfo:Label;   
    var _statusLabel:Label;
    var _elapsedTimeLabel:Label;
         
    var _buttonStart:GenesisButton;  
    var _buttonStop:GenesisButton;
    var _buttonSuspend:GenesisButton;
    var _buttonSync:GenesisButton;
    var _buttonProvision:GenesisButton;
    var _buttonDestroy:GenesisButton;
    var _buttonConsole:GenesisButton;
    var _buttonOpenBrowser:GenesisButton;
    var _buttonSSH:GenesisButton;
    var _buttonOpenDir:GenesisButton;      
    var _buttonDelete:GenesisButton;  
    var _buttonFtp:GenesisButton;    
           
    var _buttonConfigure:GenesisButton;

    var _console:Console;
    
    var _develKeys:Property<Bool>;
    var _server:Server;
    var _serverUpdated:Bool = false;

    public function new() {

        super();

    }

    public function destroy() {
        this._clearServerUpdates();
    }

    override function initialize() {

        super.initialize();

        var titleGroupLayout = new HorizontalLayout();
        		titleGroupLayout.verticalAlign = VerticalAlign.MIDDLE;

        var titleGroup = new LayoutGroup();
        		titleGroup.layoutData = new VerticalLayoutData( 100 );
        		titleGroup.layout = titleGroupLayout;
        this.addChild( titleGroup );

        _labelTitle = new Label();
        _labelTitle.variant = GenesisApplicationTheme.LABEL_LARGE;
        _labelTitle.layoutData = new HorizontalLayoutData( 100 );
        titleGroup.addChild( _labelTitle );

        _progressIndicator = new ProgressIndicator( 20, 16, 0xAAAAAA );
        _progressIndicator.visible = false;
        titleGroup.addChild( _progressIndicator );

        _labelRoles = new Label();
        _labelRoles.variant = GenesisApplicationTheme.LABEL_COPYRIGHT;
        this.addChild( _labelRoles );

        _labelInfo = new Label();
        _labelInfo.variant = GenesisApplicationTheme.LABEL_COPYRIGHT;
        this.addChild( _labelInfo );

        var statusLabelGroupLayout = new HorizontalLayout();
        		statusLabelGroupLayout.gap = GenesisApplicationTheme.GRID;

        var statusLabelGroup = new LayoutGroup();
        		statusLabelGroup.layout = statusLabelGroupLayout;
        this.addChild( statusLabelGroup );

        _statusLabel = new Label( '' );
        _statusLabel.variant = GenesisApplicationTheme.LABEL_COPYRIGHT;
        statusLabelGroup.addChild( _statusLabel );

        _elapsedTimeLabel = new Label( '' );
        _elapsedTimeLabel.variant = GenesisApplicationTheme.LABEL_COPYRIGHT;
        _elapsedTimeLabel.includeInLayout = _elapsedTimeLabel.visible = false;
        statusLabelGroup.addChild( _elapsedTimeLabel );

        var buttonGroup = new LayoutGroup();
        	    buttonGroup.variant = SuperHumanInstallerTheme.LAYOUT_GROUP_SERVER_BUTTON_GROUP;
        this.addChild( buttonGroup );

        _buttonStart = new GenesisButton();
        _buttonStart.icon = GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_START );
        _buttonStart.width = CONTROL_BUTTON_WIDTH;
        _buttonStart.height = CONTROL_BUTTON_HEIGHT;
        _buttonStart.enabled = true;
        _buttonStart.toolTip = LanguageManager.getInstance().getString( 'serverpage.server.start' );
        _buttonStart.addEventListener( TriggerEvent.TRIGGER, _buttonStartTriggered );
        buttonGroup.addChild( _buttonStart );

        _buttonStop = new GenesisButton();
        _buttonStop.icon = GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_STOP );
        _buttonStop.width = CONTROL_BUTTON_WIDTH;
        _buttonStop.height = CONTROL_BUTTON_HEIGHT;
        _buttonStop.enabled = _buttonStop.visible = _buttonStop.includeInLayout = false;
        _buttonStop.toolTip = LanguageManager.getInstance().getString( 'serverpage.server.stop' );
        _buttonStop.addEventListener( TriggerEvent.TRIGGER, _buttonStopTriggered );
        buttonGroup.addChild( _buttonStop );

        _buttonSuspend = new GenesisButton();
        _buttonSuspend.icon = GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_SUSPEND );
        _buttonSuspend.width = CONTROL_BUTTON_WIDTH;
        _buttonSuspend.height = CONTROL_BUTTON_HEIGHT;
        _buttonSuspend.enabled = _buttonSuspend.visible = _buttonSuspend.includeInLayout = false;
        _buttonSuspend.toolTip = LanguageManager.getInstance().getString( 'serverpage.server.suspend' );
        _buttonSuspend.addEventListener( TriggerEvent.TRIGGER, _buttonSuspendTriggered );
        buttonGroup.addChild( _buttonSuspend );

        _buttonSync = new GenesisButton();
        _buttonSync.icon = GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_UPLOAD );
        _buttonSync.width = CONTROL_BUTTON_WIDTH;
        _buttonSync.height = CONTROL_BUTTON_HEIGHT;
        _buttonSync.enabled = false;
        _buttonSync.toolTip = LanguageManager.getInstance().getString( 'serverpage.server.resync' );
        _buttonSync.addEventListener( TriggerEvent.TRIGGER, _buttonSyncTriggered );
        buttonGroup.addChild( _buttonSync );

        _buttonProvision = new GenesisButton();
        _buttonProvision.icon = GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_REFRESH );
        _buttonProvision.width = CONTROL_BUTTON_WIDTH;
        _buttonProvision.height = CONTROL_BUTTON_HEIGHT;
        _buttonProvision.enabled = false;
        _buttonProvision.toolTip = LanguageManager.getInstance().getString( 'serverpage.server.provision' );
        _buttonProvision.addEventListener( TriggerEvent.TRIGGER, _buttonProvisionTriggered );
        buttonGroup.addChild( _buttonProvision );

        _buttonDestroy = new GenesisButton();
        _buttonDestroy.icon = GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_DESTROY );
        _buttonDestroy.width = CONTROL_BUTTON_WIDTH;
        _buttonDestroy.height = CONTROL_BUTTON_HEIGHT;
        _buttonDestroy.enabled = false;
        _buttonDestroy.toolTip = LanguageManager.getInstance().getString( 'serverpage.server.destroy' );
        _buttonDestroy.addEventListener( TriggerEvent.TRIGGER, _buttonDestroyTriggered );
        buttonGroup.addChild( _buttonDestroy );

        _buttonConsole = new GenesisButton();
        _buttonConsole.icon = GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_OUTPUT );
        _buttonConsole.width = CONTROL_BUTTON_WIDTH;
        _buttonConsole.height = CONTROL_BUTTON_HEIGHT;
        _buttonConsole.addEventListener( TriggerEvent.TRIGGER, _buttonConsoleTriggered );
        _buttonConsole.toolTip = LanguageManager.getInstance().getString( 'serverpage.server.output' );
        buttonGroup.addChild( _buttonConsole );

        _buttonOpenBrowser = new GenesisButton();
        _buttonOpenBrowser.icon = GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_WEB );
        _buttonOpenBrowser.width = CONTROL_BUTTON_WIDTH;
        _buttonOpenBrowser.height = CONTROL_BUTTON_HEIGHT;
        _buttonOpenBrowser.enabled = false;
        _buttonOpenBrowser.toolTip = LanguageManager.getInstance().getString( 'serverpage.server.welcomepage' );
        _buttonOpenBrowser.addEventListener( TriggerEvent.TRIGGER, _buttonOpenBrowserTriggered );
        buttonGroup.addChild( _buttonOpenBrowser );

        _buttonSSH = new GenesisButton();
        _buttonSSH.icon = GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_CONSOLE );
        _buttonSSH.width = CONTROL_BUTTON_WIDTH;
        _buttonSSH.height = CONTROL_BUTTON_HEIGHT;
        _buttonSSH.enabled = false;
        _buttonSSH.toolTip = LanguageManager.getInstance().getString( 'serverpage.server.vagrantssh' );
        _buttonSSH.addEventListener( TriggerEvent.TRIGGER, _buttonSSHTriggered );
        buttonGroup.addChild( _buttonSSH );

        _buttonOpenDir = new GenesisButton();
        _buttonOpenDir.icon = GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_FOLDER );
        _buttonOpenDir.width = CONTROL_BUTTON_WIDTH;
        _buttonOpenDir.height = CONTROL_BUTTON_HEIGHT;
        _buttonOpenDir.toolTip = LanguageManager.getInstance().getString( 'serverpage.server.directory' );
        _buttonOpenDir.addEventListener( TriggerEvent.TRIGGER, _buttonOpenDirTriggered );
        buttonGroup.addChild( _buttonOpenDir );

        _buttonDelete = new GenesisButton();
        _buttonDelete.icon = GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_DELETE );
        _buttonDelete.width = CONTROL_BUTTON_WIDTH;
        _buttonDelete.height = CONTROL_BUTTON_HEIGHT;
        _buttonDelete.toolTip = LanguageManager.getInstance().getString( 'serverpage.server.delete' );
        _buttonDelete.addEventListener( TriggerEvent.TRIGGER, _buttonDeleteTriggered );
        buttonGroup.addChild( _buttonDelete );

        _buttonFtp = new GenesisButton();
        _buttonFtp.icon = GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_FILEZILLA );
        _buttonFtp.width = CONTROL_BUTTON_WIDTH;
        _buttonFtp.height = CONTROL_BUTTON_HEIGHT;
        _buttonFtp.toolTip = LanguageManager.getInstance().getString( 'serverpage.server.ftp' );
        _buttonFtp.addEventListener( TriggerEvent.TRIGGER, _buttonFtpTriggered );
        buttonGroup.addChild( _buttonFtp );
        
        var spacer = new LayoutGroup();
        		spacer.layoutData = new HorizontalLayoutData( 100 );
        buttonGroup.addChild( spacer );

        _buttonConfigure = new GenesisButton();
        _buttonConfigure.icon = GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_SETTINGS );
        _buttonConfigure.width = CONTROL_BUTTON_WIDTH;
        _buttonConfigure.height = CONTROL_BUTTON_HEIGHT;
        _buttonConfigure.addEventListener( TriggerEvent.TRIGGER, _buttonConfigureTriggered );
        _buttonConfigure.toolTip = LanguageManager.getInstance().getString( 'serverpage.server.configure' );
        buttonGroup.addChild( _buttonConfigure );

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
        this._clearServerUpdates();
    }

    public function updateServer( server:Server ) {

        if ( _serverUpdated ) return;

        this._clearServerUpdates();

        _server = server;
        this._addServerUpdates();

        if ( _labelTitle != null ) {

            _server.console = _console;
            _console.propertyId = Std.string( _server.id );
            _updateServer( _server, false );
    
        }

        _serverUpdated = true;

    }

    function _buttonConfigureTriggered( e:TriggerEvent ) {

        var event = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.CONFIGURE_SERVER );
        event.provisionerType = _server.provisioner.type;
        event.server = _server;
        this.dispatchEvent( event );

    }

    function _buttonConsoleTriggered( e:TriggerEvent ) {

        var event = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.OPEN_CONSOLE );
        event.provisionerType = _server.provisioner.type;
        event.server = _server;
        event.console = _console;
        this.dispatchEvent( event );

    }

    function _buttonDeleteTriggered( e:TriggerEvent ) {

        var event = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.DELETE_SERVER );
        event.provisionerType = _server.provisioner.type;
        event.server = _server;
        this.dispatchEvent( event );

    }
    
    function _buttonFtpTriggered( e:TriggerEvent ) {
        var event = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.OPEN_FTP_CLIENT );
        event.provisionerType = _server.provisioner.type;
        event.server = _server;
        this.dispatchEvent( event );
       // _server.openFtpClient('/Applications/FileZilla.app/Contents/MacOS/filezilla');
    }

    function _buttonDestroyTriggered( e:TriggerEvent ) {

        var event = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.DESTROY_SERVER );
        event.provisionerType = _server.provisioner.type;
        event.server = _server;
        this.dispatchEvent( event );

    }

    function _buttonOpenBrowserTriggered( e:TriggerEvent ) {

        var event = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.OPEN_BROWSER_SERVER_ADDRESS );
        event.server = _server;
        this.dispatchEvent( event );

    }

    function _buttonOpenDirTriggered( e:TriggerEvent ) {
    	
        var event = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.OPEN_SERVER_DIRECTORY );
        event.provisionerType = _server.provisioner.type;
        event.server = _server;
        this.dispatchEvent( event );
        
    }

    function _buttonProvisionTriggered( e:TriggerEvent ) {

        var event = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.PROVISION_SERVER );
        event.provisionerType = _server.provisioner.type;
        event.server = _server;
        this.dispatchEvent( event );

    }

    function _buttonResetTriggered( e:TriggerEvent ) {

        #if debug

        var event = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.RESET_SERVER );
        event.provisionerType = _server.provisioner.type;
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
        event.provisionerType = _server.provisioner.type;
        event.server = _server;
        this.dispatchEvent( event );

    }

    function _buttonStopTriggered( e:TriggerEvent ) {

        var event = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.STOP_SERVER );
        event.provisionerType = _server.provisioner.type;
        event.server = _server;
        event.forced = e.shiftKey;
        this.dispatchEvent( event );

    }

    function _buttonSuspendTriggered( e:TriggerEvent ) {

        var event = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.SUSPEND_SERVER );
        event.provisionerType = _server.provisioner.type;
        event.server = _server;
        this.dispatchEvent( event );

    }

    function _buttonSyncTriggered( e:TriggerEvent ) {

        var event = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.SYNC_SERVER );
        event.provisionerType = _server.provisioner.type;    
        event.server = _server;
        this.dispatchEvent( event );

    }

    function _copyToClipboard( e:SuperHumanApplicationEvent ) {

        e.provisionerType = _server.provisioner.type;
        this.dispatchEvent( e );

    }

    function _closeConsole( e:SuperHumanApplicationEvent ) {

        e.provisionerType = _server.provisioner.type;
        this.dispatchEvent( e );

    }

    function _consoleChanged( e:Event ) {

        if ( _console.hasNewMessage ) {

            if ( _console.hasError ) {

                _buttonConsole.icon = GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_OUTPUT_ERROR );

            } else {

                _buttonConsole.icon = GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_OUTPUT_NEW );

            }

        } else {

            _buttonConsole.icon = GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_OUTPUT );

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
        _buttonConfigure.icon = GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_SETTINGS );
        _buttonConsole.enabled = _buttonConsole.includeInLayout = _buttonConsole.visible = true;
        _buttonDelete.enabled = _buttonDelete.includeInLayout = _buttonDelete.visible = false;
        _buttonDestroy.enabled = _buttonDestroy.includeInLayout = _buttonDestroy.visible = false;
        _buttonOpenBrowser.enabled = _buttonOpenBrowser.includeInLayout = _buttonOpenBrowser.visible = false;
        _buttonOpenDir.enabled = _buttonOpenDir.includeInLayout = _buttonOpenDir.visible = false;
        _buttonFtp.enabled = _buttonFtp.includeInLayout = _buttonFtp.visible = false;
        _buttonProvision.enabled = _buttonProvision.includeInLayout = _buttonProvision.visible = false;
        _buttonSSH.enabled = _buttonSSH.includeInLayout = _buttonSSH.visible = false;
        _buttonStart.enabled = _buttonStart.includeInLayout = _buttonStart.visible = false;
        _buttonStop.includeInLayout = _buttonStop.visible = _buttonStop.enabled = false;
        _buttonSuspend.includeInLayout = _buttonSuspend.visible = _buttonSuspend.enabled = false;
        _buttonSync.enabled = _buttonSync.includeInLayout = _buttonSync.visible = false;
        _statusLabel.text = LanguageManager.getInstance().getString( 'serverpage.server.status.unavailable' );
        _elapsedTimeLabel.visible = _elapsedTimeLabel.includeInLayout = false;

        _progressIndicator.visible = _server.busy;
        if ( _server.busy ) _progressIndicator.start() else _progressIndicator.stop();

        if ( !Vagrant.getInstance().exists || !VirtualBox.getInstance().exists ) return;

        Logger.info('${this}: _updateServer Server status: ${_server.status.value}');
        Logger.info('${this}: _updateServer Server provisioned: ${_server.provisioned}');
        switch ( _server.status.value ) {

            case ServerStatus.Stopped( hasError ):
                _buttonConfigure.enabled = _buttonConfigure.includeInLayout = _buttonConfigure.visible = true;
                _buttonDestroy.enabled = _buttonDestroy.includeInLayout = _buttonDestroy.visible = _server.provisioned;
                _buttonDelete.enabled = _buttonDelete.includeInLayout = _buttonDelete.visible = !_server.provisioned;
                _buttonStart.visible = _buttonStart.includeInLayout = _buttonStart.enabled = true;
                _buttonOpenDir.enabled = _buttonOpenDir.includeInLayout = _buttonOpenDir.visible = true;
                _statusLabel.text = ( hasError ) ? LanguageManager.getInstance().getString( 'serverpage.server.status.stoppedwitherrors' ) : LanguageManager.getInstance().getString( 'serverpage.server.status.stopped', ( _server.provisioned ) ? '(${LanguageManager.getInstance().getString( 'serverpage.server.status.provisioned' )})' : '' );

            case ServerStatus.Stopping( forced ):
                _statusLabel.text = ( forced ) ?  LanguageManager.getInstance().getString( 'serverpage.server.status.stoppingforced' ) : LanguageManager.getInstance().getString( 'serverpage.server.status.stopping' );

            case ServerStatus.Start( provisionedBefore ):
            		_buttonOpenDir.enabled = _buttonOpenDir.includeInLayout = _buttonOpenDir.visible = true;
                if ( provisionedBefore ) {

                    _statusLabel.text = LanguageManager.getInstance().getString( 'serverpage.server.status.start' );
                    _elapsedTimeLabel.visible = _elapsedTimeLabel.includeInLayout = true;
                    _elapsedTimeLabel.text = LanguageManager.getInstance().getString( 'serverpage.server.status.elapsedtime', "00:00:00" );

                } else {

                    _statusLabel.text = LanguageManager.getInstance().getString( 'serverpage.server.status.firststart' );
                    _elapsedTimeLabel.visible = _elapsedTimeLabel.includeInLayout = true;
                    _elapsedTimeLabel.text = LanguageManager.getInstance().getString( 'serverpage.server.status.elapsedtime', "00:00:00" );

                } 

            case ServerStatus.Initializing:
                _statusLabel.text = LanguageManager.getInstance().getString( 'serverpage.server.status.initializing' );

            case ServerStatus.Running( hasError ):
            	    _buttonOpenDir.enabled = _buttonOpenDir.includeInLayout = _buttonOpenDir.visible = true;
            	    _buttonFtp.enabled = _buttonFtp.includeInLayout = _buttonFtp.visible = true;
                _buttonOpenBrowser.enabled = _buttonOpenBrowser.includeInLayout = _buttonOpenBrowser.visible = true;
                _buttonSSH.enabled = _buttonSSH.includeInLayout = _buttonSSH.visible = true;
                _buttonStop.includeInLayout = _buttonStop.visible = _buttonStop.enabled = true;
                _buttonSuspend.includeInLayout = _buttonSuspend.visible = _buttonSuspend.enabled = true;

                var ipAddress:String = "";
                switch (_server.provisioner.type)
                {
                    case AdditionalProvisioner:
                        {
                            ipAddress = cast(_server.provisioner, DemoTasks).ipAddress;

                        }
                        default:
                        {
                            ipAddress = cast(_server.provisioner, AdditionalProvisioner).ipAddress;
                        }
                }
                _statusLabel.text = ( hasError ) ? LanguageManager.getInstance().getString( 'serverpage.server.status.runningwitherrors', ( _server.provisioned ) ? '(IP: ${ipAddress})' : '' ) : LanguageManager.getInstance().getString( 'serverpage.server.status.running', ( _server.provisioned ) ? '(IP: ${ipAddress})' : '' );
                

            case ServerStatus.Unconfigured:
                _buttonConfigure.enabled = _buttonConfigure.includeInLayout = _buttonConfigure.visible = true;
                _buttonDelete.enabled = _buttonDelete.includeInLayout = _buttonDelete.visible = true;
                _buttonStart.enabled = _buttonStart.includeInLayout = _buttonStart.visible = true;
                _buttonOpenDir.enabled = _buttonOpenDir.includeInLayout = _buttonOpenDir.visible = true;
                _statusLabel.text = LanguageManager.getInstance().getString( 'serverpage.server.status.unconfigured' );

            case ServerStatus.Ready:
                _buttonConfigure.enabled = _buttonConfigure.includeInLayout = _buttonConfigure.visible = true;
                _buttonOpenDir.enabled = _buttonOpenDir.includeInLayout = _buttonOpenDir.visible = true;
                _buttonDelete.enabled = _buttonDelete.includeInLayout = _buttonDelete.visible = true;
                _buttonStart.enabled = _buttonStart.includeInLayout = _buttonStart.visible = true;
                _statusLabel.text = LanguageManager.getInstance().getString( 'serverpage.server.status.ready' );

            case ServerStatus.Provisioning:
                _statusLabel.text = LanguageManager.getInstance().getString( 'serverpage.server.status.provisioning' );

            case ServerStatus.RSyncing:
                _statusLabel.text = LanguageManager.getInstance().getString( 'serverpage.server.status.rsyncing' );

            case ServerStatus.GetStatus:
                _statusLabel.text = LanguageManager.getInstance().getString( 'serverpage.server.status.getstatus' );

            case ServerStatus.Destroying( unregisterVM ):
                _statusLabel.text = LanguageManager.getInstance().getString( 'serverpage.server.status.destroying' );

            case ServerStatus.Aborted:
                _buttonDestroy.enabled = _buttonDestroy.includeInLayout = _buttonDestroy.visible = true;
                _statusLabel.text = LanguageManager.getInstance().getString( 'serverpage.server.status.aborted' );

            case ServerStatus.Suspended:
                _buttonDestroy.enabled = _buttonDestroy.includeInLayout = _buttonDestroy.visible = true;
                _buttonStart.visible = _buttonStart.includeInLayout = _buttonStart.enabled = true;
                _statusLabel.text = LanguageManager.getInstance().getString( 'serverpage.server.status.suspended' );

            case ServerStatus.Suspending:
                _statusLabel.text = LanguageManager.getInstance().getString( 'serverpage.server.status.suspending' );

            default:
                _buttonDelete.enabled = _buttonDelete.includeInLayout = _buttonDelete.visible = true;
                _statusLabel.text = LanguageManager.getInstance().getString( 'serverpage.server.status.unknown' );

        }

    }

    function _updateVagrantUpElapsedTimer() {

        if ( _server != null && _elapsedTimeLabel != null && _elapsedTimeLabel.visible == true ) {

            var elapsed = StrTools.timeToFormattedString( _server.vagrantUpElapsedTime );
            
            var numberOfStartedTasks:Int = 0;
            var numberOfTasks:Int = 0;

            switch (_server.provisioner.type)
            {
                case AdditionalProvisioner:
                    {
                        numberOfStartedTasks = cast(_server.provisioner, DemoTasks).numberOfStartedTasks;
                        numberOfTasks = cast(_server.provisioner, DemoTasks).numberOfTasks;
                    }
                    default:
                    {
                        numberOfStartedTasks = cast(_server.provisioner, AdditionalProvisioner).numberOfStartedTasks;
                        numberOfTasks = cast(_server.provisioner, AdditionalProvisioner).numberOfTasks;  
                    }
            }
            //var percentage = StrTools.calculatePercentage( _server.provisioner.numberOfStartedTasks, _server.provisioner.numberOfTasks );
            if ( _server.provisionedBeforeStart )
                _elapsedTimeLabel.text = LanguageManager.getInstance().getString( 'serverpage.server.status.elapsedtime', '${elapsed}' )
            else
                _elapsedTimeLabel.text = LanguageManager.getInstance().getString( 'serverpage.server.status.elapsedtimewithtasks', '${elapsed}', '${numberOfStartedTasks+1}/${numberOfTasks+1}' );

        }

    }
    
    function _clearServerUpdates() {
    		 if ( _server != null ) {
            // List.remove( func ) is not working on Neko,
            // so the entire List must be cleared
            if (_server.onUpdate != null)
            {
            		#if neko
            		_server.onUpdate.clear();
            		#else
            		_server.onUpdate.remove( _updateServer );
            		#end
        		}
        		
        		if (_server.onStatusUpdate != null)
        		{
        			#if neko
            		_server.onStatusUpdate.clear();
            		#else
            		_server.onStatusUpdate.remove( _updateServer );
            		#end
        		}
        		
        		if (_server.onVagrantUpElapsedTimerUpdate != null)
        		{
        			#if neko
	    			_server.onVagrantUpElapsedTimerUpdate.clear();
            		#else
            		_server.onVagrantUpElapsedTimerUpdate.remove( _updateVagrantUpElapsedTimer );
            		#end
        		}
        }
    }
    
    function _addServerUpdates() {
    		if ( _server != null ) {
            // List.remove( func ) is not working on Neko,
            // so the entire List must be cleared
            if (_server.onUpdate != null)
            {
            		 _server.onUpdate.add( _updateServer );
        		}
        		
        		if (_server.onStatusUpdate != null)
        		{
        			_server.onStatusUpdate.add( _updateServer );
        		}
        		
        		if (_server.onVagrantUpElapsedTimerUpdate != null)
        		{
        			 _server.onVagrantUpElapsedTimerUpdate.add( _updateVagrantUpElapsedTimer );
        		}
        }
    }

}