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

import feathers.controls.Button;
import feathers.controls.Label;
import feathers.controls.LayoutGroup;
import feathers.data.ArrayCollection;
import feathers.events.FlatCollectionEvent;
import feathers.events.TriggerEvent;
import feathers.layout.HorizontalAlign;
import feathers.layout.VerticalLayout;
import feathers.layout.VerticalLayoutData;
import genesis.application.components.AdvancedAssetLoader;
import genesis.application.components.Page;
import genesis.application.managers.LanguageManager;
import genesis.application.theme.GenesisApplicationTheme;
import prominic.core.primitives.VersionInfo;
import superhuman.config.SuperHumanGlobals;
import superhuman.events.SuperHumanApplicationEvent;
import superhuman.server.Server;
import superhuman.theme.SuperHumanInstallerTheme;

class ServerPage extends Page {

    var _createServerButton:Button;
    var _emptyGroup:LayoutGroup;
    var _emptyGroupLayout:VerticalLayout;
    var _emptyLabel1:Label;
    var _emptyLabel2:Label;
    var _image:AdvancedAssetLoader;
    var _maxServers:Int;
    var _serverList:ServerList;
    var _servers:ArrayCollection<Server>;
    var _vagrantVersion:VersionInfo;
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

    public var virtualBoxInstalled( never, set ):Bool;
    var _virtualBoxInstalled:Bool = false;
    function set_virtualBoxInstalled( value:Bool ):Bool {
        if ( _virtualBoxInstalled == value ) return value;
        _virtualBoxInstalled = value;
        if ( _warningBoxVirtualBox != null ) _warningBoxVirtualBox.visible = _warningBoxVirtualBox.includeInLayout = !_virtualBoxInstalled;
        return value;
    }

    public var vagrantVersion( never, set ):VersionInfo;
    function set_vagrantVersion( value:VersionInfo ):VersionInfo {

        _vagrantVersion = value;
        if ( _warningBoxVagrant != null ) _warningBoxVagrant.visible = _warningBoxVagrant.includeInLayout = _vagrantVersion < SuperHumanGlobals.VAGRANT_MINIMUM_SUPPORTED_VERSION;
        return _vagrantVersion;

    }

    public function new( servers:ArrayCollection<Server>, maxServers:Int = 1 ) {

        super();

        _servers = servers;
        _servers.addEventListener( FlatCollectionEvent.ADD_ITEM, _serverListChanged );
        _servers.addEventListener( FlatCollectionEvent.REMOVE_ALL, _serverListChanged );
        _servers.addEventListener( FlatCollectionEvent.RESET, _serverListChanged );
        _servers.addEventListener( FlatCollectionEvent.REMOVE_ITEM, _serverListChanged );

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

        _serverList = new ServerList( _servers );
        _serverList.addEventListener( SuperHumanApplicationEvent.CLOSE_CONSOLE, _closeConsole );
        _serverList.addEventListener( SuperHumanApplicationEvent.COPY_TO_CLIPBOARD, _forwardEvent );
        _serverList.addEventListener( SuperHumanApplicationEvent.CONFIGURE_SERVER, _forwardEvent );
        _serverList.addEventListener( SuperHumanApplicationEvent.DELETE_SERVER, _forwardEvent );
        _serverList.addEventListener( SuperHumanApplicationEvent.DESTROY_SERVER, _forwardEvent );
        _serverList.addEventListener( SuperHumanApplicationEvent.OPEN_BROWSER, _forwardEvent );
        _serverList.addEventListener( SuperHumanApplicationEvent.OPEN_CONSOLE, _openConsole );
        _serverList.addEventListener( SuperHumanApplicationEvent.OPEN_VAGRANT_SSH, _forwardEvent );
        _serverList.addEventListener( SuperHumanApplicationEvent.PROVISION_SERVER, _forwardEvent );
        _serverList.addEventListener( SuperHumanApplicationEvent.START_SERVER, _forwardEvent );
        _serverList.addEventListener( SuperHumanApplicationEvent.STOP_SERVER, _forwardEvent );
        _serverList.addEventListener( SuperHumanApplicationEvent.SYNC_SERVER, _forwardEvent );
        #if debug
        _serverList.addEventListener( SuperHumanApplicationEvent.OPEN_SERVER_DIRECTORY, _forwardEvent );
        _serverList.addEventListener( SuperHumanApplicationEvent.RESET_SERVER, _forwardEvent );
        #end
        _serverList.visible = _serverList.includeInLayout = _servers.length != 0 && _vagrantInstalled && _virtualBoxInstalled;
        this.addChild( _serverList );

        _createServerButton = new Button( LanguageManager.getInstance().getString( 'serverpage.buttoncreate' ) );
        _createServerButton.addEventListener( TriggerEvent.TRIGGER, _createServerButtonTriggered );
        _createServerButton.includeInLayout = _createServerButton.visible = _vagrantInstalled && _virtualBoxInstalled && ( _maxServers == 0 || _servers.length < _maxServers ) && _vagrantVersion >= SuperHumanGlobals.VAGRANT_MINIMUM_SUPPORTED_VERSION;
        this.addChild( _createServerButton );

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

        var event = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.CREATE_SERVER );
        this.dispatchEvent( event );

    }

	function _openConsole( e:SuperHumanApplicationEvent ) {
		
		_overlay.visible = true;
        _overlay.addChild( e.console );
		e.console.title = LanguageManager.getInstance().getString( 'console.title', '#${Std.string( e.server.id )} (${e.server.fqdn})' );

	}

    function _serverListChanged( e:FlatCollectionEvent ) {

        _emptyGroup.visible = _emptyGroup.includeInLayout = _servers.length == 0;
        _serverList.visible = _serverList.includeInLayout = _servers.length != 0;
        _createServerButton.includeInLayout = _createServerButton.visible = _vagrantInstalled && _virtualBoxInstalled && ( _maxServers == 0 || _servers.length < _maxServers );

        if ( _servers.length == 0 ) {

        } else {

        }

    }

    function _warningBoxTriggered( e:TriggerEvent ) {

        var event = new SuperHumanApplicationEvent( ( e.target == _warningBoxVagrant ) ? SuperHumanApplicationEvent.DOWNLOAD_VAGRANT : SuperHumanApplicationEvent.DOWNLOAD_VIRTUALBOX );
        this.dispatchEvent( event );

    }

}