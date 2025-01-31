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

import genesis.application.components.GenesisFormRow;
import superhuman.server.SyncMethod;
import superhuman.components.filesync.FileSyncSetting;
import superhuman.application.ApplicationData;
import superhuman.components.applications.ApplicationsList;
import feathers.data.ArrayCollection;
import superhuman.components.browsers.BrowsersList;
import superhuman.browser.BrowserData;
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
    var _cbSystemSleep:GenesisFormCheckBox;
    var _cbDisableVagrantLogging:GenesisFormCheckBox;
    var _cbKeepFailedServersRunning:GenesisFormCheckBox;
    var _cbKeepServersRunning:GenesisFormCheckBox;
    var _form:GenesisForm;
    var _label:Label;
    var _rowAdvanced:GenesisFormRow;
    var _rowApplicationWindow:GenesisFormRow;
    var _rowSystemSleep:GenesisFormRow;
    var _rowKeepFailedServersRunning:GenesisFormRow;
    var _rowKeepServersRunning:GenesisFormRow;
    var _rowProvision:GenesisFormRow;
    var _rowSyncMethod:GenesisFormRow;
    var _fileSyncSetting:FileSyncSetting;
    var _rowBrowsers:GenesisFormRow;
    var _rowApplications:GenesisFormRow;

    var _browsersList:BrowsersList;
    var _applicationsList:ApplicationsList;

    var _titleGroup:LayoutGroup;
    
    var _browsers:ArrayCollection<BrowserData>;
    var _applications:ArrayCollection<ApplicationData>;
    
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

        _rowSystemSleep = new GenesisFormRow();
        
        _cbSystemSleep = new GenesisFormCheckBox( LanguageManager.getInstance().getString( 'settingspage.interface.preventsystemfromsleep' ) );
        _rowSystemSleep.content.addChild( _cbSystemSleep );
        
        _form.addChild( _rowSystemSleep );
        
        var spacer = new LayoutGroup();
        spacer.height = GenesisApplicationTheme.SPACER;
        _form.addChild( spacer );

        _rowProvision = new GenesisFormRow();
        _rowProvision.text = LanguageManager.getInstance().getString( 'settingspage.servers.title' );
        _form.addChild( _rowProvision );
 
        _rowKeepServersRunning = new GenesisFormRow();
        _cbKeepServersRunning = new GenesisFormCheckBox( LanguageManager.getInstance().getString( 'settingspage.servers.keeprunning' ) );
        _rowProvision.content.addChild( _cbKeepServersRunning );
        _form.addChild( _rowKeepServersRunning );
       
        _rowSyncMethod = new GenesisFormRow();
        _rowSyncMethod.text = LanguageManager.getInstance().getString( 'settingspage.syncMethods' );

        _fileSyncSetting = new FileSyncSetting();
        _fileSyncSetting.width = _width;
        _rowSyncMethod.content.addChild(_fileSyncSetting);
        _form.addChild( _rowSyncMethod );
        
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
        spacer.height = GenesisApplicationTheme.SPACER;
        _form.addChild( spacer );

        _rowBrowsers = new GenesisFormRow();
        _rowBrowsers.text = LanguageManager.getInstance().getString( 'settingspage.browser.titlesetupbrowser' );
        _browsersList = new BrowsersList(_browsers);
        _browsersList.width = _width;
        _browsersList.addEventListener(SuperHumanApplicationEvent.CONFIGURE_BROWSER, _configureBrowser );
  		_browsersList.addEventListener(BrowserItem.BROWSER_ITEM_CHANGE, _browserItemChange);
        _rowBrowsers.content.addChild(_browsersList);
        _form.addChild(_rowBrowsers);

        spacer = new LayoutGroup();
        spacer.height = GenesisApplicationTheme.SPACER;
        _form.addChild( spacer );
        
        _rowApplications = new GenesisFormRow();
        _rowApplications.text = LanguageManager.getInstance().getString( 'settingspage.applications.titlesetupapplications' );
        _applicationsList = new ApplicationsList(_applications);
        _applicationsList.width = _width;
        _applicationsList.addEventListener(SuperHumanApplicationEvent.CONFIGURE_APPLICATION, _configureApplication );
        _rowApplications.content.addChild(_applicationsList);
        _form.addChild(_rowApplications);
        
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
            _cbSystemSleep.selected = SuperHumanInstaller.getInstance().config.preferences.preventsystemfromsleep;
       //     _cbProvision.selected = SuperHumanInstaller.getInstance().config.preferences.provisionserversonstart;
            _cbKeepServersRunning.selected = SuperHumanInstaller.getInstance().config.preferences.keepserversrunning;
            _cbDisableVagrantLogging.selected = SuperHumanInstaller.getInstance().config.preferences.disablevagrantlogging;
            _cbKeepFailedServersRunning.selected = SuperHumanInstaller.getInstance().config.preferences.keepfailedserversrunning;
        }

        if (_fileSyncSetting != null) {
       	 	_fileSyncSetting.selectedSyncMethod = SuperHumanInstaller.getInstance().config.preferences.syncmethod == SyncMethod.Rsync ? SyncMethod.Rsync : SyncMethod.SCP;
		}
     }

     public function setBrowsers(browsers:Array<BrowserData>) {
    		_browsers = new ArrayCollection(browsers);	
    		if (_browsersList != null) {
    			_browsersList.dataProvider = _browsers;
    		}
    }
    
    public function setApplications(apps:Array<ApplicationData>) {
    		_applications = new ArrayCollection(apps);	
    		if (_applicationsList != null) {
    			_applicationsList.dataProvider = _applications;
    		}
    }
    
    function _configureBrowser(e:SuperHumanApplicationEvent) {
    		this._forwardEvent(e);
    }
    
   function _configureApplication(e:SuperHumanApplicationEvent) {
    		this._forwardEvent(e);
    }
    
    function _browserItemChange(e:SuperHumanApplicationEvent) {
		//refresh state of default browser for the rest of items
		var refreshDefaultBrowserEvent = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.REFRESH_DEFAULT_BROWSER);
			refreshDefaultBrowserEvent.browserData = e.browserData;
		this.dispatchEvent(refreshDefaultBrowserEvent);
			
		this.refreshBrowsers();
    }
    
    public function refreshBrowsers() {
    		_browsersList.dataProvider.updateAll();
    }
    
    function _saveButtonTriggered( e:TriggerEvent ) {

        SuperHumanInstaller.getInstance().config.preferences.savewindowposition = _cbApplicationWindow.selected;
        SuperHumanInstaller.getInstance().config.preferences.preventsystemfromsleep = _cbSystemSleep.selected;
      //  SuperHumanInstaller.getInstance().config.preferences.provisionserversonstart = _cbProvision.selected;
        SuperHumanInstaller.getInstance().config.preferences.keepserversrunning = _cbKeepServersRunning.selected;
        SuperHumanInstaller.getInstance().config.preferences.disablevagrantlogging = _cbDisableVagrantLogging.selected;
        SuperHumanInstaller.getInstance().config.preferences.keepfailedserversrunning = _cbKeepFailedServersRunning.selected;
        SuperHumanInstaller.getInstance().config.preferences.syncmethod = _fileSyncSetting.selectedSyncMethod;

        this.dispatchEvent( new SuperHumanApplicationEvent( SuperHumanApplicationEvent.SAVE_APP_CONFIGURATION ) );

    }
}