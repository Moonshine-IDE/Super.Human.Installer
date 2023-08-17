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

import champaign.core.primitives.VersionInfo;
import feathers.controls.Button;
import feathers.controls.Label;
import feathers.controls.LayoutGroup;
import feathers.controls.TextInput;
import feathers.data.ArrayCollection;
import feathers.events.FlatCollectionEvent;
import feathers.events.TriggerEvent;
import feathers.layout.HorizontalAlign;
import feathers.layout.HorizontalLayout;
import feathers.layout.HorizontalLayoutData;
import feathers.layout.VerticalAlign;
import feathers.layout.VerticalLayout;
import feathers.layout.VerticalLayoutData;
import genesis.application.components.AdvancedAssetLoader;
import genesis.application.components.HLine;
import genesis.application.components.Page;
import genesis.application.managers.LanguageManager;
import genesis.application.theme.GenesisApplicationTheme;
import openfl.events.Event;
import prominic.sys.applications.hashicorp.Vagrant.VagrantMachine;
import prominic.sys.applications.oracle.VirtualBoxMachine;
import superhuman.config.SuperHumanGlobals;
import superhuman.events.SuperHumanApplicationEvent;
import superhuman.server.Server;
import superhuman.server.provisioners.ProvisionerType;
import superhuman.theme.SuperHumanInstallerTheme;

class ServerPage extends Page {

    var _createServerButton:Button;
    var _emptyGroup:LayoutGroup;
    var _emptyGroupLayout:VerticalLayout;
    var _emptyLabel1:Label;
    var _emptyLabel2:Label;
    var _headerButton:Button;
    var _headerGroup:LayoutGroup;
    var _headerGroupLayout:HorizontalLayout;
    var _headerInput:TextInput;
    var _headerLabel:Label;
    var _headerLine:HLine;
    var _image:AdvancedAssetLoader;
    var _localServers:ArrayCollection<Server>;
    var _maxServers:Int;
    var _serverList:ServerList;
    var _servers:ArrayCollection<Server>;
    var _spacer:LayoutGroup;
    var _systemInfoBox:SystemInfoBox;
    var _vagrantMachines:Array<VagrantMachine>;
    var _vagrantVersion:VersionInfo;
    var _virtualBoxMachines:Array<VirtualBoxMachine>;
    var _virtualBoxVersion:VersionInfo;
    var _warningBoxVagrant:WarningBox;
    var _warningBoxVirtualBox:WarningBox;

    public var vagrantInstalled( never, set ):Bool;
    var _vagrantInstalled:Bool = false;
    function set_vagrantInstalled( value:Bool ):Bool {
        if ( _vagrantInstalled == value ) return value;
        _vagrantInstalled = value;
        if ( _warningBoxVagrant != null ) _warningBoxVagrant.visible = _warningBoxVagrant.includeInLayout = !_vagrantInstalled;
        return value;
    }

    public var vagrantMachines( get, set ):Array<VagrantMachine>;
    function get_vagrantMachines() return _vagrantMachines;
    function set_vagrantMachines( value ) {
        _vagrantMachines = value;
        if ( _systemInfoBox != null ) _systemInfoBox.vagrantMachines = _vagrantMachines;
        return _vagrantMachines;
    }

    public var vagrantVersion( never, set ):VersionInfo;
    function set_vagrantVersion( value:VersionInfo ):VersionInfo {

        _vagrantVersion = value;
        if ( _warningBoxVagrant != null ) _warningBoxVagrant.visible = _warningBoxVagrant.includeInLayout = _vagrantVersion < SuperHumanGlobals.VAGRANT_MINIMUM_SUPPORTED_VERSION;
        return _vagrantVersion;

    }

    public var virtualBoxInstalled( never, set ):Bool;
    var _virtualBoxInstalled:Bool = false;
    function set_virtualBoxInstalled( value:Bool ):Bool {
        if ( _virtualBoxInstalled == value ) return value;
        _virtualBoxInstalled = value;
        if ( _warningBoxVirtualBox != null ) _warningBoxVirtualBox.visible = _warningBoxVirtualBox.includeInLayout = !_virtualBoxInstalled;
        return value;
    }

    public var virtualBoxMachines( get, set ):Array<VirtualBoxMachine>;
    function get_virtualBoxMachines() return _virtualBoxMachines;
    function set_virtualBoxMachines( value ) {
        _virtualBoxMachines = value;
        if ( _systemInfoBox != null ) _systemInfoBox.virtualBoxMachines = _virtualBoxMachines;
        return _virtualBoxMachines;
    }

    public function new( servers:ArrayCollection<Server>, maxServers:Int = 1 ) {

        super();

        _servers = servers;
        _localServers = new ArrayCollection();
        _localServers.addAll( servers );
        _servers.addEventListener( FlatCollectionEvent.ADD_ITEM, _serverListChanged );
        _servers.addEventListener( FlatCollectionEvent.REMOVE_ALL, _serverListChanged );
        _servers.addEventListener( FlatCollectionEvent.RESET, _serverListChanged );
        _servers.addEventListener( FlatCollectionEvent.REMOVE_ITEM, _serverListChanged );
        _localServers.filterFunction = _serverFilterFunction;

        _maxServers = maxServers;

    }

    override function initialize() {

        super.initialize();

        _emptyGroupLayout = new VerticalLayout();
        _emptyGroupLayout.horizontalAlign = HorizontalAlign.CENTER;
        _emptyGroupLayout.gap = GenesisApplicationTheme.GRID * 2;

        _emptyGroup = new LayoutGroup();
        _emptyGroup.layoutData = new VerticalLayoutData( 100 );
        _emptyGroup.layout = _emptyGroupLayout;
        _emptyGroup.visible = _emptyGroup.includeInLayout = _servers.length == 0 || !_vagrantInstalled || !_virtualBoxInstalled;
        this.addChild( _emptyGroup );

        _image = new AdvancedAssetLoader( GenesisApplicationTheme.getAssetPath( SuperHumanInstallerTheme.IMAGE_LOGO ) );
        _emptyGroup.addChild( _image );

        _emptyLabel1 = new Label( LanguageManager.getInstance().getString( 'serverpage.title', SuperHumanInstaller.getInstance().title ) );
        _emptyLabel1.variant = GenesisApplicationTheme.LABEL_HUGE;
        _emptyGroup.addChild( _emptyLabel1 );

        _emptyLabel2 = new Label( LanguageManager.getInstance().getString( 'serverpage.text' ) );
        _emptyLabel2.includeInLayout = _emptyLabel2.visible = _vagrantInstalled && _virtualBoxInstalled;
        _emptyGroup.addChild( _emptyLabel2 );

        _headerGroupLayout = new HorizontalLayout();
        _headerGroupLayout.paddingTop = GenesisApplicationTheme.GRID * 2;
        _headerGroupLayout.verticalAlign = VerticalAlign.MIDDLE;
        _headerGroupLayout.gap = GenesisApplicationTheme.GRID * 2;

        _headerGroup = new LayoutGroup();
        _headerGroup.layout = _headerGroupLayout;
        _headerGroup.layoutData = new VerticalLayoutData( 100 );
        this.addChild( _headerGroup );

        _headerLabel = new Label( LanguageManager.getInstance().getString( 'serverpage.header', Std.string( _servers.length ) ) );
        _headerLabel.variant = GenesisApplicationTheme.LABEL_LARGE;
        _headerGroup.addChild( _headerLabel );

        _headerInput = new TextInput( "", LanguageManager.getInstance().getString( 'serverpage.filter' ) );
        _headerInput.layoutData = new HorizontalLayoutData( 100 );
        _headerInput.addEventListener( Event.CHANGE, _headerInputChanged );
        _headerGroup.addChild( _headerInput );

        _headerButton = new Button( LanguageManager.getInstance().getString( 'serverpage.buttoncreatenew' ) );
        _headerButton.addEventListener( TriggerEvent.TRIGGER, _createServerButtonTriggered );
        _headerGroup.addChild( _headerButton );

        _headerLine = new HLine();
        _headerLine.layoutData = new VerticalLayoutData( 100 );
        this.addChild( _headerLine );

        _headerGroup.visible = _headerGroup.includeInLayout = _vagrantInstalled && _virtualBoxInstalled && _servers.length != 0 && _vagrantVersion >= SuperHumanGlobals.VAGRANT_MINIMUM_SUPPORTED_VERSION;
        _headerLine.visible = _headerLine.includeInLayout = _vagrantInstalled && _virtualBoxInstalled && _servers.length != 0 && _vagrantVersion >= SuperHumanGlobals.VAGRANT_MINIMUM_SUPPORTED_VERSION;

        _serverList = new ServerList( _localServers );
        _serverList.addEventListener( SuperHumanApplicationEvent.CLOSE_CONSOLE, _closeConsole );
        _serverList.addEventListener( SuperHumanApplicationEvent.COPY_TO_CLIPBOARD, _forwardEvent );
        _serverList.addEventListener( SuperHumanApplicationEvent.CONFIGURE_SERVER, _forwardEvent );
        _serverList.addEventListener( SuperHumanApplicationEvent.DELETE_SERVER, _forwardEvent );
        _serverList.addEventListener( SuperHumanApplicationEvent.DESTROY_SERVER, _forwardEvent );
        _serverList.addEventListener( SuperHumanApplicationEvent.OPEN_BROWSER_SERVER_ADDRESS, _forwardEvent );
        _serverList.addEventListener( SuperHumanApplicationEvent.OPEN_CONSOLE, _openConsole );
        _serverList.addEventListener( SuperHumanApplicationEvent.OPEN_VAGRANT_SSH, _forwardEvent );
        _serverList.addEventListener( SuperHumanApplicationEvent.PROVISION_SERVER, _forwardEvent );
        _serverList.addEventListener( SuperHumanApplicationEvent.START_SERVER, _forwardEvent );
        _serverList.addEventListener( SuperHumanApplicationEvent.STOP_SERVER, _forwardEvent );
        _serverList.addEventListener( SuperHumanApplicationEvent.SUSPEND_SERVER, _forwardEvent );
        _serverList.addEventListener( SuperHumanApplicationEvent.SYNC_SERVER, _forwardEvent );
        #if debug
        _serverList.addEventListener( SuperHumanApplicationEvent.OPEN_SERVER_DIRECTORY, _forwardEvent );
        _serverList.addEventListener( SuperHumanApplicationEvent.RESET_SERVER, _forwardEvent );
        #end
        _serverList.visible = _serverList.includeInLayout = _servers.length != 0 && _vagrantInstalled && _virtualBoxInstalled;
        this.addChild( _serverList );

        _createServerButton = new Button( LanguageManager.getInstance().getString( 'serverpage.buttoncreate' ) );
        _createServerButton.addEventListener( TriggerEvent.TRIGGER, _createServerButtonTriggered );
        _createServerButton.includeInLayout = _createServerButton.visible = _vagrantInstalled && _virtualBoxInstalled && _servers.length == 0 && _vagrantVersion >= SuperHumanGlobals.VAGRANT_MINIMUM_SUPPORTED_VERSION;
        this.addChild( _createServerButton );

        _spacer = new LayoutGroup();
        _spacer.height = GenesisApplicationTheme.GRID * 4;
        _spacer.includeInLayout = _spacer.visible = _vagrantInstalled && _virtualBoxInstalled && _servers.length == 0 && _vagrantVersion >= SuperHumanGlobals.VAGRANT_MINIMUM_SUPPORTED_VERSION;
        this.addChild( _spacer );

        _systemInfoBox = new SystemInfoBox();
        _systemInfoBox.addEventListener( SuperHumanApplicationEvent.OPEN_VIRTUALBOX_GUI, _forwardEvent );
        _systemInfoBox.addEventListener( SuperHumanApplicationEvent.REFRESH_SYSTEM_INFO, _forwardEvent );
        _systemInfoBox.visible = _systemInfoBox.includeInLayout = _vagrantInstalled && _virtualBoxInstalled && _vagrantVersion >= SuperHumanGlobals.VAGRANT_MINIMUM_SUPPORTED_VERSION;
        if ( _vagrantMachines != null ) _systemInfoBox.vagrantMachines = _vagrantMachines;
        if ( _virtualBoxMachines != null ) _systemInfoBox.virtualBoxMachines = _virtualBoxMachines;
        this.addChild( _systemInfoBox );

        _warningBoxVagrant = new WarningBox();
        _warningBoxVagrant.title = LanguageManager.getInstance().getString( 'serverpage.vagrant.title' );
        _warningBoxVagrant.action = LanguageManager.getInstance().getString( 'serverpage.vagrant.buttoninstall' );
        _warningBoxVagrant.text = LanguageManager.getInstance().getString( 'serverpage.vagrant.text' );
        _warningBoxVagrant.addEventListener( TriggerEvent.TRIGGER, _warningBoxTriggered );
        _warningBoxVagrant.visible = _warningBoxVagrant.includeInLayout = !_vagrantInstalled || _vagrantVersion < SuperHumanGlobals.VAGRANT_MINIMUM_SUPPORTED_VERSION;
        this.addChild( _warningBoxVagrant );

        _warningBoxVirtualBox = new WarningBox();
        _warningBoxVirtualBox.title = LanguageManager.getInstance().getString( 'serverpage.virtualbox.title' );
        _warningBoxVirtualBox.action = LanguageManager.getInstance().getString( 'serverpage.virtualbox.buttoninstall' );
        _warningBoxVirtualBox.text = LanguageManager.getInstance().getString( 'serverpage.virtualbox.text' );
        _warningBoxVirtualBox.addEventListener( TriggerEvent.TRIGGER, _warningBoxTriggered );
        _warningBoxVirtualBox.visible = _warningBoxVirtualBox.includeInLayout = !_virtualBoxInstalled;
        this.addChild( _warningBoxVirtualBox );

    }

	function _closeConsole( e:SuperHumanApplicationEvent ) {

		_overlay.visible = false;
        _overlay.removeChildren();

	}

    function _createServerButtonTriggered( e:TriggerEvent ) {
		
        /*var event = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.CREATE_SERVER );
        		event.provisionerType = ProvisionerType.DemoTasks;
        this.dispatchEvent( event );*/
		
        this.dispatchEvent(new SuperHumanApplicationEvent(SuperHumanApplicationEvent.START_CONFIGURE_SERVER));
    }

    function _headerInputChanged( e:Event ) {

        _localServers.refresh();

    }

	function _openConsole( e:SuperHumanApplicationEvent ) {
		
		_overlay.visible = true;
        _overlay.addChild( e.console );
		e.console.title = LanguageManager.getInstance().getString( 'console.title', '#${Std.string( e.server.id )} (${e.server.fqdn})' );

	}

    function _serverFilterFunction( server:Server ):Bool {

        if ( _headerInput == null ) return true;

        var t = StringTools.trim( _headerInput.text ).toLowerCase();
        if ( t.length == 0 ) return true;

        return (
                StringTools.contains( Std.string( server.id ), t ) ||
                /*StringTools.contains( server.fqdn.toLowerCase(), t ) ||*/
                StringTools.contains( server.domainName.toLowerCase(), t ) ||
                StringTools.contains( server.hostname.value.toLowerCase(), t )
            );

    }

    function _serverListChanged( e:FlatCollectionEvent ) {

        _localServers.removeAll();
        _localServers.addAll( _servers );

        _headerLabel.text = LanguageManager.getInstance().getString( 'serverpage.header', Std.string( _servers.length ) );
        _emptyGroup.visible = _emptyGroup.includeInLayout = _servers.length == 0;
        _serverList.visible = _serverList.includeInLayout = _servers.length != 0;
        _headerGroup.visible = _headerGroup.includeInLayout = _vagrantInstalled && _virtualBoxInstalled && _servers.length != 0;
        _headerLine.visible = _headerLine.includeInLayout = _vagrantInstalled && _virtualBoxInstalled && _servers.length != 0;
        _createServerButton.includeInLayout = _createServerButton.visible = _vagrantInstalled && _virtualBoxInstalled && _servers.length == 0;

    }

    function _warningBoxTriggered( e:TriggerEvent ) {

        var event = new SuperHumanApplicationEvent( ( e.target == _warningBoxVagrant ) ? SuperHumanApplicationEvent.DOWNLOAD_VAGRANT : SuperHumanApplicationEvent.DOWNLOAD_VIRTUALBOX );
        this.dispatchEvent( event );

    }

}