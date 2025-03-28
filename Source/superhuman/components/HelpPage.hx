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
import feathers.layout.VerticalLayoutData;
import genesis.application.GenesisApplication;
import genesis.application.components.AdvancedAssetLoader;
import genesis.application.components.Page;
import genesis.application.managers.LanguageManager;
import genesis.application.theme.GenesisApplicationTheme;
import openfl.events.TextEvent;
import superhuman.events.SuperHumanApplicationEvent;

class HelpPage extends Page {

    final _w:Float = GenesisApplicationTheme.GRID * 100;

    var _disclaimerLabel:Label;
    var _image:AdvancedAssetLoader;
    var _infoLabel:Label;
    var _titleLabel:Label;

    public function new() {

        super();

    }

    override function initialize() {

        super.initialize();

        _content.width = _w;

        _image = GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.IMAGE_HELP ) ;
        this.addChild( _image );

        _titleLabel = new Label( LanguageManager.getInstance().getString( 'helppage.title', GenesisApplication.getInstance().title ) );
        _titleLabel.variant = GenesisApplicationTheme.LABEL_LARGE;
        this.addChild( _titleLabel );

        _infoLabel = new Label();
        _infoLabel.htmlText = LanguageManager.getInstance().getString( 'helppage.text', GenesisApplication.getInstance().title );
        _infoLabel.wordWrap = true;
        _infoLabel.layoutData = new VerticalLayoutData( 100 );
        _infoLabel.addEventListener( TextEvent.LINK, _infoLabelLink );
        this.addChild( _infoLabel );

        _disclaimerLabel = new Label( LanguageManager.getInstance().getString( 'helppage.disclaimer' ) );
        _disclaimerLabel.variant = GenesisApplicationTheme.LABEL_COPYRIGHT;
        _disclaimerLabel.paddingTop = GenesisApplicationTheme.GRID * 2;
        this.addChild( _disclaimerLabel );

    }

    function _infoLabelLink( e:TextEvent ) {

        var evt = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.TEXT_LINK );
        evt.text = e.text;
        this.dispatchEvent( evt );

    }

}