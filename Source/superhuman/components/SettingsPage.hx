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
import feathers.controls.ScrollContainer;
import feathers.layout.VerticalLayoutData;
import lime.ui.FileDialog;
import lime.ui.FileDialogType;
import superhuman.server.SyncMethod;
import superhuman.components.filesync.FileSyncSetting;
import superhuman.application.ApplicationData;
import superhuman.components.applications.ApplicationsList;
import feathers.data.ArrayCollection;
import superhuman.components.browsers.BrowsersList;
import superhuman.browser.BrowserData;
import superhuman.managers.ProvisionerManager;
import genesis.application.managers.ToastManager;
import champaign.core.logging.Logger;
import feathers.controls.Label;
import feathers.controls.LayoutGroup;
import feathers.events.TriggerEvent;
import feathers.layout.HorizontalAlign;
import feathers.layout.HorizontalLayout;
import feathers.layout.HorizontalLayoutData;
import feathers.layout.VerticalAlign;
import feathers.layout.VerticalLayout;
import genesis.application.components.GenesisForm;
import genesis.application.components.GenesisFormButton;
import genesis.application.components.GenesisFormCheckBox;
import genesis.application.components.GenesisFormPupUpListView;
import genesis.application.components.HLine;
import genesis.application.components.Page;
import genesis.application.managers.LanguageManager;
import genesis.application.theme.GenesisApplicationTheme;
import prominic.sys.applications.oracle.BridgedInterface;
import prominic.sys.applications.oracle.VirtualBox;
import superhuman.events.SuperHumanApplicationEvent;
import superhuman.server.cache.SuperHumanFileCache;
import superhuman.theme.SuperHumanInstallerTheme;

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
    var _rowProvisioners:GenesisFormRow;
    var _buttonImportProvisioner:GenesisFormButton;
    var _rowNetworkInterface:GenesisFormRow;
    var _dropdownNetworkInterface:GenesisFormPupUpListView;

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

        // Create a scroll container for the content
        var scrollContainer = new ScrollContainer();
        scrollContainer.variant = SuperHumanInstallerTheme.SCROLL_CONTAINER_DARK;
        scrollContainer.layoutData = new VerticalLayoutData(100, 100);
        scrollContainer.autoHideScrollBars = false;
        scrollContainer.fixedScrollBars = true;
        
        // Set up vertical layout for the scroll container
        var scrollLayout = new VerticalLayout();
        scrollLayout.horizontalAlign = HorizontalAlign.CENTER;
        scrollLayout.gap = GenesisApplicationTheme.GRID;
        scrollLayout.paddingTop = GenesisApplicationTheme.GRID * 2;
        scrollLayout.paddingBottom = GenesisApplicationTheme.GRID * 2;
        scrollLayout.paddingLeft = GenesisApplicationTheme.GRID * 2;
        scrollLayout.paddingRight = GenesisApplicationTheme.GRID * 3; // Extra padding on right side for scrollbar
        scrollContainer.layout = scrollLayout;
        
        // Add the scroll container to the page
        this.addChild(scrollContainer);

        _form = new GenesisForm();
        scrollContainer.addChild(_form);

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
        
        _rowNetworkInterface = new GenesisFormRow();
        _rowNetworkInterface.text = "Default Network Interface";
        
        // Create a custom collection with None option (empty string) first, followed by all interfaces
        var originalCollection = VirtualBox.getInstance().bridgedInterfacesCollection;
        var interfaceCollection = new feathers.data.ArrayCollection<BridgedInterface>();
        
        // Add None option (empty string)
        interfaceCollection.add({ name: "" });
        
        // Add all original interfaces, excluding any that might have empty name
        // This prevents duplicates of the "None" option
        for (i in 0...originalCollection.length) {
            var interfaceItem = originalCollection.get(i);
            if (interfaceItem.name != "") {
                interfaceCollection.add(interfaceItem);
            }
        }
        
        _dropdownNetworkInterface = new GenesisFormPupUpListView(interfaceCollection);
        _dropdownNetworkInterface.itemToText = (item:BridgedInterface) -> {
            if (item.name == "") return "None";
            return item.name;
        };
        _dropdownNetworkInterface.selectedIndex = 0;
        _dropdownNetworkInterface.prompt = LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.networkinterface.prompt' );
        _rowNetworkInterface.content.addChild( _dropdownNetworkInterface );
        _form.addChild( _rowNetworkInterface );

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
        
        spacer = new LayoutGroup();
        spacer.height = GenesisApplicationTheme.SPACER;
        _form.addChild( spacer );
        
        // Add provisioner management section
        _rowProvisioners = new GenesisFormRow();
        _rowProvisioners.text = "Provisioner Management";
        
        _buttonImportProvisioner = new GenesisFormButton("Import Provisioner");
        _buttonImportProvisioner.addEventListener(TriggerEvent.TRIGGER, _importProvisioner);
        _rowProvisioners.content.addChild(_buttonImportProvisioner);
        
        _form.addChild(_rowProvisioners);
        
        spacer = new LayoutGroup();
        spacer.height = GenesisApplicationTheme.SPACER;
        _form.addChild( spacer );
        
        // Add Global Secrets button
        var _rowSecrets = new GenesisFormRow();
        _rowSecrets.text = "Global Secrets";
        
        var _buttonGlobalSecrets = new GenesisFormButton("Manage Global Secrets");
        _buttonGlobalSecrets.addEventListener(TriggerEvent.TRIGGER, _openGlobalSecrets);
        _rowSecrets.content.addChild(_buttonGlobalSecrets);
        
        _form.addChild(_rowSecrets);
        
        spacer = new LayoutGroup();
        spacer.height = GenesisApplicationTheme.SPACER;
        _form.addChild( spacer );
        
        // Add File Cache Manager button
        var _rowFileCache = new GenesisFormRow();
        _rowFileCache.text = "Installer Files & Hashes";
        
        var _buttonHashManager = new GenesisFormButton("Manage Installer Files");
        _buttonHashManager.addEventListener(TriggerEvent.TRIGGER, _openHashManager);
        _rowFileCache.content.addChild(_buttonHashManager);
        
        _form.addChild(_rowFileCache);
        
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
            // Set the selected sync method
            _fileSyncSetting.selectedSyncMethod = SuperHumanInstaller.getInstance().config.preferences.syncmethod == SyncMethod.Rsync ? SyncMethod.Rsync : SyncMethod.SCP;
            
            // Set the disabled state based on the global flag
            _fileSyncSetting.syncDisabled = superhuman.config.SuperHumanGlobals.IS_SYNC_DISABLED;
        }
        
        if (_dropdownNetworkInterface != null) {
            _dropdownNetworkInterface.selectedIndex = 0; // Default to "None"
            
            // If there is a default network interface set in preferences, select it
            if (SuperHumanInstaller.getInstance().config.preferences.defaultNetworkInterface != null) {
                var defaultInterface = SuperHumanInstaller.getInstance().config.preferences.defaultNetworkInterface;
                for (i in 0..._dropdownNetworkInterface.dataProvider.length) {
                    var d = _dropdownNetworkInterface.dataProvider.get(i);
                    if (d.name == defaultInterface) {
                        _dropdownNetworkInterface.selectedIndex = i;
                        break;
                    }
                }
            }
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
        
        // Save the selected network interface
        if (_dropdownNetworkInterface.selectedItem != null) {
            SuperHumanInstaller.getInstance().config.preferences.defaultNetworkInterface = _dropdownNetworkInterface.selectedItem.name;
        } else {
            SuperHumanInstaller.getInstance().config.preferences.defaultNetworkInterface = "";
        }

        this.dispatchEvent( new SuperHumanApplicationEvent( SuperHumanApplicationEvent.SAVE_APP_CONFIGURATION ) );

    }
    
    /**
     * Navigate to the Global Secrets page
     * @param e The trigger event
     */
    function _openGlobalSecrets(e:TriggerEvent) {
        dispatchEvent(new SuperHumanApplicationEvent(SuperHumanApplicationEvent.OPEN_SECRETS_PAGE));
    }
    
    /**
     * Navigate to the provisioner import page when the Import Provisioner button is clicked
     * @param e The trigger event
     */
    function _importProvisioner(e:TriggerEvent) {
        // Dispatch event to open the provisioner import page
        var event = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.OPEN_PROVISIONER_IMPORT_PAGE);
        Logger.info('${this}: Requesting to open provisioner import page');
        this.dispatchEvent(event);
    }
    
    /**
     * Navigate to the hash manager page when the Manage Installer Files button is clicked
     * @param e The trigger event
     */
    function _openHashManager(e:TriggerEvent) {
        // Dispatch event to open the hash manager page
        var event = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.OPEN_HASH_MANAGER_PAGE);
        Logger.info('${this}: Requesting to open hash manager page');
        this.dispatchEvent(event);
    }
    
    /**
     * Handle cancel button click
     */
    override function _cancel(?e:Dynamic) {
        // Dispatch the cancel event which will be handled by SuperHumanInstaller
        this.dispatchEvent(new SuperHumanApplicationEvent(SuperHumanApplicationEvent.CANCEL_PAGE));
    }
}
