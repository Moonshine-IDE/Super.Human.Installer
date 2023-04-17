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
import feathers.events.TriggerEvent;
import genesis.application.components.AdvancedAssetLoader;
import genesis.application.events.GenesisApplicationEvent;
import genesis.application.managers.LanguageManager;
import genesis.application.theme.GenesisApplicationTheme;

class SupportPage extends Page {

    var _githubLabel:Label;
    var _image:AdvancedAssetLoader;
    var _infoLabel:Label;
    var _label:Label;
    var _openLogsButton:Button;
    var _visitGitHubButton:Button;
    
    public function new() {

        super();

    }

    override function initialize() {

        super.initialize();

        _image = new AdvancedAssetLoader( GenesisApplicationTheme.getAssetPath( GenesisApplicationTheme.IMAGE_SUPPORT ) );
        this.addChild( _image );

        _label = new Label( LanguageManager.getInstance().getString( 'supportpage.title' ) );
        _label.variant = GenesisApplicationTheme.LABEL_LARGE;
        this.addChild( _label );

        _infoLabel = new Label();
        _infoLabel.htmlText = LanguageManager.getInstance().getString( 'supportpage.text', GenesisApplication.getInstance().title, GenesisApplication.getInstance().company );
        _infoLabel.variant = GenesisApplicationTheme.LABEL_CENTERED;
        _infoLabel.wordWrap = true;
        _infoLabel.maxWidth = GenesisApplicationTheme.GRID * 80;
        this.addChild( _infoLabel );

        _openLogsButton = new Button( LanguageManager.getInstance().getString( 'supportpage.button' ) );
        _openLogsButton.addEventListener( TriggerEvent.TRIGGER, _openLogsButtonTriggered );
        this.addChild( _openLogsButton );

        _githubLabel = new Label( LanguageManager.getInstance().getString( 'supportpage.visitgithubtext' ) );
        _githubLabel.variant = GenesisApplicationTheme.LABEL_CENTERED;
        _githubLabel.wordWrap = true;
        _githubLabel.maxWidth = GenesisApplicationTheme.GRID * 80;
        this.addChild( _githubLabel );

        _visitGitHubButton = new Button( LanguageManager.getInstance().getString( 'supportpage.visitgithub' ) );
        _visitGitHubButton.icon = new AdvancedAssetLoader( GenesisApplicationTheme.getAssetPath( GenesisApplicationTheme.ICON_GITHUB ) );
        _visitGitHubButton.addEventListener( TriggerEvent.TRIGGER, _visitGitHubButtonTriggered );
        this.addChild( _visitGitHubButton );

    }

    function _openLogsButtonTriggered( e:TriggerEvent ) {

        this.dispatchEvent( new GenesisApplicationEvent( GenesisApplicationEvent.OPEN_LOGS_DIRECTORY ) );

    }

    function _visitGitHubButtonTriggered( e:TriggerEvent ) {

        this.dispatchEvent( new GenesisApplicationEvent( GenesisApplicationEvent.VISIT_SOURCE_CODE_ISSUES ) );

    }

}