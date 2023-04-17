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

package genesis.application.components;

import feathers.controls.Button;
import feathers.controls.Label;
import feathers.controls.LayoutGroup;
import feathers.events.TriggerEvent;
import feathers.layout.HorizontalLayout;
import genesis.application.events.GenesisApplicationEvent;
import genesis.application.managers.LanguageManager;
import genesis.application.theme.GenesisApplicationTheme;
import genesis.application.updater.GenesisApplicationUpdaterEvent;

class UpdatePage extends Page {

    var _buttonGroup:LayoutGroup;
    var _buttonGroupLayout:HorizontalLayout;
    var _cancelButton:Button;
    var _description:Label;
    var _downloadButton:Button;
    var _launchButton:Button;
    var _progressBar:ProgressBar;
    var _title:Label;
    
    public function new() {
        
        super();

    }

    override function initialize() {

        super.initialize();

        _title = new Label( LanguageManager.getInstance().getString( 'updatepage.title', GenesisApplication.getInstance().title ) );
        _title.variant = GenesisApplicationTheme.LABEL_LARGE;
        this.addChild( _title );

        _description = new Label( LanguageManager.getInstance().getString( 'updatepage.text', GenesisApplication.getInstance().updater.updaterInfoEntry.version ) );
        _description.wordWrap = true;
        _description.width = GenesisApplicationTheme.GRID * 80;
        _description.variant = GenesisApplicationTheme.LABEL_CENTERED;
        this.addChild( _description );

        _progressBar = new ProgressBar();
        _progressBar.width = GenesisApplicationTheme.GRID * 80;
        this.addChild( _progressBar );

        _buttonGroupLayout = new HorizontalLayout();
        _buttonGroupLayout.gap = GenesisApplicationTheme.GRID * 2;

        _buttonGroup = new LayoutGroup();
        _buttonGroup.layout = _buttonGroupLayout;
        this.addChild( _buttonGroup );

        _downloadButton = new Button( LanguageManager.getInstance().getString( 'updatepage.buttondownload' ) );
        _downloadButton.addEventListener( TriggerEvent.TRIGGER, _downloadButtonTriggered );
        _buttonGroup.addChild( _downloadButton );

        _cancelButton = new Button( LanguageManager.getInstance().getString( 'updatepage.buttoncancel' ) );
        _cancelButton.addEventListener( TriggerEvent.TRIGGER, _cancelButtonTriggered );
        _buttonGroup.addChild( _cancelButton );

        GenesisApplication.getInstance().updater.addEventListener( GenesisApplicationUpdaterEvent.DOWNLOAD_CANCELLED, _downloadCancelled );
        GenesisApplication.getInstance().updater.addEventListener( GenesisApplicationUpdaterEvent.DOWNLOAD_COMPLETE, _downloadCompleted );
        GenesisApplication.getInstance().updater.addEventListener( GenesisApplicationUpdaterEvent.DOWNLOAD_FAILED, _downloadFailed );
        GenesisApplication.getInstance().updater.addEventListener( GenesisApplicationUpdaterEvent.DOWNLOAD_PROGRESS, _downloadProgress );
        GenesisApplication.getInstance().updater.addEventListener( GenesisApplicationUpdaterEvent.DOWNLOAD_START, _downloadStarted );

    }

    function _cancelButtonTriggered( e:TriggerEvent ) {

        if ( GenesisApplication.getInstance().updater.isDownloading ) {

            GenesisApplication.getInstance().updater.cancelDownload();

        } else {

            this.dispatchEvent( new GenesisApplicationEvent( GenesisApplicationEvent.CANCEL_UPDATE_PAGE ) );

        }

    }

    function _downloadButtonTriggered( e:TriggerEvent ) {
        
        GenesisApplication.getInstance().updater.downloadUpdate();

    }

    function _downloadCancelled( e:GenesisApplicationUpdaterEvent ) {

        _progressBar.percentage = 0;
        _downloadButton.enabled = true;
        this.dispatchEvent( new GenesisApplicationEvent( GenesisApplicationEvent.CANCEL_UPDATE_PAGE ) );

    }

    function _downloadCompleted( e:GenesisApplicationUpdaterEvent ) {

        _progressBar.percentage = 100;
        _downloadButton.enabled = true;
        GenesisApplication.getInstance().updater.launchInstaller( true );

    }

    function _downloadFailed( e:GenesisApplicationUpdaterEvent ) {

        _progressBar.percentage = 0;

    }

    function _downloadProgress( e:GenesisApplicationUpdaterEvent ) {

        _progressBar.percentage = e.downloadPercentage;

    }

    function _downloadStarted( e:GenesisApplicationUpdaterEvent ) {
        
        _downloadButton.enabled = false;

    }

}