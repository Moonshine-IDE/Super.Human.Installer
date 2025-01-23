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

import feathers.controls.Label;
import genesis.application.components.Page;
import genesis.application.events.GenesisApplicationEvent;
import genesis.application.managers.LanguageManager;
import genesis.application.theme.GenesisApplicationTheme;
import openfl.events.MouseEvent;

class AboutPage extends Page {

    var _buildInfoLabel:Label;
    var _genesisInfoLabel:Label;
    var _genesisLinkLabel:Label;
    var _image:AdvancedAssetLoader;
    var _label:Label;
    var _openSourceDescriptionLabel:Label;
    var _openSourceLabel:Label;
    var _openSourceLinkLabel:Label;
    
    public function new() {

        super();

    }

    override function initialize() {

        super.initialize();

        _image =  GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.IMAGE_GENESIS_DIRECTORY);
        this.addChild( _image );

        _label = new Label( LanguageManager.getInstance().getString( 'aboutpage.title', GenesisApplication.getInstance().title ) );
        _label.variant = GenesisApplicationTheme.LABEL_LARGE;
        this.addChild( _label );

        _genesisInfoLabel = new Label( LanguageManager.getInstance().getString( 'aboutpage.about', GenesisApplication.getInstance().title ) );
        _genesisInfoLabel.maxWidth = GenesisApplicationTheme.GRID * 80;
        _genesisInfoLabel.wordWrap = true;
        _genesisInfoLabel.variant = GenesisApplicationTheme.LABEL_CENTERED;
        this.addChild( _genesisInfoLabel );

        _genesisLinkLabel = new Label( LanguageManager.getInstance().getString( 'aboutpage.genesislink' ) );
        _genesisLinkLabel.variant = GenesisApplicationTheme.LABEL_LINK;
        _genesisLinkLabel.useHandCursor = _genesisLinkLabel.buttonMode = true;
        _genesisLinkLabel.addEventListener( MouseEvent.CLICK, _genesisLinkLabelTriggered );
        this.addChild( _genesisLinkLabel );

        _openSourceLabel = new Label( LanguageManager.getInstance().getString( 'aboutpage.opensource' ) );
        _openSourceLabel.variant = GenesisApplicationTheme.LABEL_LARGE;
        this.addChild( _openSourceLabel );

        _openSourceDescriptionLabel = new Label( LanguageManager.getInstance().getString( 'aboutpage.aboutopensource', GenesisApplication.getInstance().title ) );
        _openSourceDescriptionLabel.maxWidth = GenesisApplicationTheme.GRID * 80;
        _openSourceDescriptionLabel.wordWrap = true;
        _openSourceDescriptionLabel.variant = GenesisApplicationTheme.LABEL_CENTERED;
        this.addChild( _openSourceDescriptionLabel );

        _openSourceLinkLabel = new Label( LanguageManager.getInstance().getString( 'aboutpage.sourcelink' ) );
        _openSourceLinkLabel.variant = GenesisApplicationTheme.LABEL_LINK;
        _openSourceLinkLabel.useHandCursor = _openSourceLinkLabel.buttonMode = true;
        _openSourceLinkLabel.addEventListener( MouseEvent.CLICK, _openSourceLinkLabelTriggered );
        this.addChild( _openSourceLinkLabel );

        #if buildmacros
        _buildInfoLabel = new Label( 'BRANCH BUILD\nBranch: ${GenesisApplication.GIT_BRANCH}\nCommit: ${GenesisApplication.GIT_COMMIT}' );
        _buildInfoLabel.variant = GenesisApplicationTheme.LABEL_SMALL_CENTERED;
        _buildInfoLabel.wordWrap = true;
        this.addChild( _buildInfoLabel );
        #end

    }

    function _genesisLinkLabelTriggered( e:MouseEvent ) {

        this.dispatchEvent( new GenesisApplicationEvent( GenesisApplicationEvent.VISIT_GENESIS_DIRECTORY ) );

    }

    function _openSourceLinkLabelTriggered( e:MouseEvent ) {

        this.dispatchEvent( new GenesisApplicationEvent( GenesisApplicationEvent.VISIT_SOURCE_CODE ) );

    }

}