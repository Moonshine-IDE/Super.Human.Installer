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

import superhuman.browser.Browsers;
import feathers.controls.Label;
import feathers.controls.LayoutGroup;
import feathers.events.TriggerEvent;
import feathers.layout.HorizontalAlign;
import feathers.layout.HorizontalLayout;
import feathers.layout.HorizontalLayoutData;
import feathers.layout.VerticalAlign;
import genesis.application.components.GenesisForm;
import genesis.application.components.GenesisFormButton;
import genesis.application.components.GenesisFormCheckBox;
import genesis.application.components.HLine;
import genesis.application.components.Page;
import genesis.application.managers.LanguageManager;
import genesis.application.theme.GenesisApplicationTheme;
import superhuman.events.SuperHumanApplicationEvent;

class SettingsPage extends Page {

    final _width:Float = GenesisApplicationTheme.GRID * 100;

    var _buttonCancel:GenesisFormButton;
    var _buttonGroup:LayoutGroup;
    var _buttonGroupLayout:HorizontalLayout;
    var _buttonSave:GenesisFormButton;
    var _cbApplicationWindow:GenesisFormCheckBox;
    var _cbDisableVagrantLogging:GenesisFormCheckBox;
    var _cbKeepFailedServersRunning:GenesisFormCheckBox;
    var _cbKeepServersRunning:GenesisFormCheckBox;
    var _cbProvision:GenesisFormCheckBox;
    var _form:GenesisForm;
    var _label:Label;
    var _rowAdvanced:GenesisFormRow;
    var _rowApplicationWindow:GenesisFormRow;
    var _rowKeepFailedServersRunning:GenesisFormRow;
    var _rowKeepServersRunning:GenesisFormRow;
    var _rowProvision:GenesisFormRow;
    var _rowBrowsers:GenesisFormRow;
    var _rowBrowsersDefault:GenesisFormRow;
    var _buttonDefaultBrowser:GenesisFormButton;
    var _labelDefaultBrowser:Label;
    var _titleGroup:LayoutGroup;
    
    public function new() {

        super();

    }

    override function initialize() {

        super.initialize();

        _titleGroup = new LayoutGroup();
        var _titleGroupLayout = new HorizontalLayout();
        _titleGroupLayout.horizontalAlign = HorizontalAlign.LEFT;
        _titleGroupLayout.verticalAlign = VerticalAlign.MIDDLE;
        _titleGroup.layout = _titleGroupLayout;
        _titleGroup.width = _width;
        this.addChild( _titleGroup );

        _label = new Label();
        _label.text = LanguageManager.getInstance().getString( 'settingspage.title' );
        _label.variant = GenesisApplicationTheme.LABEL_LARGE;
        _label.layoutData = new HorizontalLayoutData( 100 );
        _titleGroup.addChild( _label );

        var line = new HLine();
        line.width = _width;
        this.addChild( line );

        _form = new GenesisForm();
        this.addChild( _form );

        _rowApplicationWindow = new GenesisFormRow();
        _rowApplicationWindow.text = LanguageManager.getInstance().getString( 'settingspage.interface.title' );

        _cbApplicationWindow = new GenesisFormCheckBox( LanguageManager.getInstance().getString( 'settingspage.interface.rememberwindowposition' ) );
        _rowApplicationWindow.content.addChild( _cbApplicationWindow );

        _form.addChild( _rowApplicationWindow );

        var spacer = new LayoutGroup();
        spacer.height = GenesisApplicationTheme.GRID * 2;
        _form.addChild( spacer );

        _rowProvision = new GenesisFormRow();
        _rowProvision.text = LanguageManager.getInstance().getString( 'settingspage.servers.title' );
        _form.addChild( _rowProvision );

        _cbProvision = new GenesisFormCheckBox( LanguageManager.getInstance().getString( 'settingspage.servers.alwaysprovision' ) );
        // _rowProvision.content.addChild( _cbProvision );
         
        _rowKeepServersRunning = new GenesisFormRow();
        _cbKeepServersRunning = new GenesisFormCheckBox( LanguageManager.getInstance().getString( 'settingspage.servers.keeprunning' ) );
        _rowProvision.content.addChild( _cbKeepServersRunning );
        _form.addChild( _rowKeepServersRunning );

        _rowAdvanced = new GenesisFormRow();
        _rowAdvanced.text = LanguageManager.getInstance().getString( 'settingspage.advanced.title' );
        _cbDisableVagrantLogging = new GenesisFormCheckBox( LanguageManager.getInstance().getString( 'settingspage.advanced.disablevagrantlogging' ) );
        _rowAdvanced.content.addChild( _cbDisableVagrantLogging );
        _form.addChild( _rowAdvanced );

        _rowKeepFailedServersRunning = new GenesisFormRow();
        _cbKeepFailedServersRunning = new GenesisFormCheckBox( LanguageManager.getInstance().getString( 'settingspage.advanced.keepfailedserversrunning' ) );
        _rowKeepFailedServersRunning.content.addChild( _cbKeepFailedServersRunning );
        _form.addChild( _rowKeepFailedServersRunning );
        
        spacer = new LayoutGroup();
        spacer.height = GenesisApplicationTheme.GRID * 2;
        _form.addChild( spacer );
      
        _rowBrowsersDefault = new GenesisFormRow();
        _rowBrowsersDefault.text = LanguageManager.getInstance().getString( 'settingspage.browser.title' );
        _labelDefaultBrowser = new Label();
        _rowBrowsersDefault.content.addChild(_labelDefaultBrowser);
        _form.addChild(_rowBrowsersDefault);
        
        _rowBrowsers = new GenesisFormRow();
        _buttonDefaultBrowser = new GenesisFormButton( LanguageManager.getInstance().getString( 'settingspage.browser.defaultbrowser' ) );
        _buttonDefaultBrowser.addEventListener( TriggerEvent.TRIGGER, _setDefaultBrowserButtonTrigger );
        _rowBrowsers.content.addChild(_buttonDefaultBrowser);
        _form.addChild(_rowBrowsers);

        var line = new HLine();
        line.width = _width;
        this.addChild( line );

        _buttonGroup = new LayoutGroup();
        _buttonGroupLayout = new HorizontalLayout();
        _buttonGroupLayout.gap = GenesisApplicationTheme.GRID * 2;
        _buttonGroupLayout.horizontalAlign = HorizontalAlign.CENTER;
        _buttonGroup.layout = _buttonGroupLayout;
        _buttonSave = new GenesisFormButton( LanguageManager.getInstance().getString( 'settingspage.buttons.save' ) );
        _buttonSave.addEventListener( TriggerEvent.TRIGGER, _saveButtonTriggered );
        _buttonSave.width = GenesisApplicationTheme.GRID * 20;
        _buttonCancel = new GenesisFormButton( LanguageManager.getInstance().getString( 'settingspage.buttons.cancel' ) );
        _buttonCancel.addEventListener( TriggerEvent.TRIGGER, _cancel );
        _buttonCancel.width = GenesisApplicationTheme.GRID * 20;
        _buttonGroup.addChild( _buttonSave );
        _buttonGroup.addChild( _buttonCancel );
        this.addChild( _buttonGroup );

        updateData();

    }

    public function updateData() {

        if ( _cbApplicationWindow != null ) {

            _cbApplicationWindow.selected = SuperHumanInstaller.getInstance().config.preferences.savewindowposition;
            _cbProvision.selected = SuperHumanInstaller.getInstance().config.preferences.provisionserversonstart;
            _cbKeepServersRunning.selected = SuperHumanInstaller.getInstance().config.preferences.keepserversrunning;
            _cbDisableVagrantLogging.selected = SuperHumanInstaller.getInstance().config.preferences.disablevagrantlogging;
            _cbKeepFailedServersRunning.selected = SuperHumanInstaller.getInstance().config.preferences.keepfailedserversrunning;

        }
		
        if (_labelDefaultBrowser != null) {
        		var defaultBrowser = Browsers.getDefaultBrowser();
        		_labelDefaultBrowser.text = LanguageManager.getInstance().getString( 'settingspage.browser.currentdefaultbrowser', defaultBrowser.browserName);
    		}
    }

    function _saveButtonTriggered( e:TriggerEvent ) {

        SuperHumanInstaller.getInstance().config.preferences.savewindowposition = _cbApplicationWindow.selected;
        SuperHumanInstaller.getInstance().config.preferences.provisionserversonstart = _cbProvision.selected;
        SuperHumanInstaller.getInstance().config.preferences.keepserversrunning = _cbKeepServersRunning.selected;
        SuperHumanInstaller.getInstance().config.preferences.disablevagrantlogging = _cbDisableVagrantLogging.selected;
        SuperHumanInstaller.getInstance().config.preferences.keepfailedserversrunning = _cbKeepFailedServersRunning.selected;

        this.dispatchEvent( new SuperHumanApplicationEvent( SuperHumanApplicationEvent.SAVE_APP_CONFIGURATION ) );

    }
    
    function _setDefaultBrowserButtonTrigger(e:TriggerEvent) {
    		 this.dispatchEvent( new SuperHumanApplicationEvent( SuperHumanApplicationEvent.OPEN_BROWSERS_SETUP ) );
    }

}