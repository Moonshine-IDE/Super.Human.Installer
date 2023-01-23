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
import genesis.application.components.AdvancedAssetLoader;
import genesis.application.components.Page;
import genesis.application.components.ProgressIndicator;
import genesis.application.managers.LanguageManager;
import genesis.application.theme.GenesisApplicationTheme;
import superhuman.theme.SuperHumanInstallerTheme;

class LoadingPage extends Page {

    var _image:AdvancedAssetLoader;
    var _labelLoading:Label;
    var _labelPleaseWait:Label;
    var _progressIndicator:ProgressIndicator;
    
    public function new() {

        super();

    }

    override function initialize() {

        super.initialize();

        _image = new AdvancedAssetLoader( GenesisApplicationTheme.getAssetPath( SuperHumanInstallerTheme.IMAGE_LOGO ) );
        this.addChild( _image );

        _labelLoading = new Label( LanguageManager.getInstance().getString( 'loadingpage.title', SuperHumanInstaller.getInstance().title ) );
        _labelLoading.variant = GenesisApplicationTheme.LABEL_LARGE;
        this.addChild( _labelLoading );

        _labelPleaseWait = new Label( LanguageManager.getInstance().getString( 'loadingpage.text' ) );
        _labelPleaseWait.variant = GenesisApplicationTheme.LABEL_COPYRIGHT;
        this.addChild( _labelPleaseWait );

        _progressIndicator = new ProgressIndicator( 24, 16, 0xCCCCCC );
        _progressIndicator.start();
        this.addChild( _progressIndicator );

    }

    public function stopProgressIndicator() {

        if ( _progressIndicator != null ) _progressIndicator.stop();

    }

}