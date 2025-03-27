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

package superhuman.components.serviceType;

import lime.ui.FileDialog;
import lime.ui.FileDialogType;
import superhuman.managers.ProvisionerManager;
import genesis.application.managers.ToastManager;
import superhuman.server.data.ServerUIType;
import superhuman.server.ServerType;
import superhuman.server.provisioners.ProvisionerType;
import feathers.controls.GridViewColumn;
import genesis.application.theme.GenesisApplicationTheme;
import feathers.controls.Label;
import superhuman.server.data.ServiceTypeData;
import feathers.data.ArrayCollection;
import superhuman.events.SuperHumanApplicationEvent;
import genesis.application.components.GenesisFormButton;
import feathers.events.TriggerEvent;
import genesis.application.components.HLine;
import genesis.application.managers.LanguageManager;
import feathers.layout.HorizontalLayoutData;
import feathers.controls.LayoutGroup;
import feathers.layout.HorizontalLayout;
import feathers.layout.VerticalAlign;
import feathers.layout.HorizontalAlign;
import genesis.application.components.Page;

class ServiceTypePage extends Page {

    final _w:Float = GenesisApplicationTheme.GRID * 100;

    var _titleGroup:LayoutGroup;
	var _labelTitle:Label;
	
	var _serviceTypeGrid:ServiceTypeGrid;
	
	var _buttonGroup:LayoutGroup;
    var _buttonGroupLayout:HorizontalLayout;
    var _buttonSave:GenesisFormButton;
    var _buttonClose:GenesisFormButton;
    var _buttonImportProvisioner:GenesisFormButton;
    
    var _serviceTypesCollection:Array<ServiceTypeData>;
	
    public function new(serviceTypes:Array<ServiceTypeData>) {

        super();
        
        _serviceTypesCollection = serviceTypes;
    }

    override function initialize() {

        super.initialize();

        _content.width = _w;
        
        var titleGroupLayout = new HorizontalLayout();
        		titleGroupLayout.horizontalAlign = HorizontalAlign.RIGHT;
        		titleGroupLayout.verticalAlign = VerticalAlign.MIDDLE;
        		
        _titleGroup = new LayoutGroup();
        _titleGroup.layout = titleGroupLayout;
        _titleGroup.width = _w;
        this.addChild( _titleGroup );

        _labelTitle = new Label();
        _labelTitle.variant = GenesisApplicationTheme.LABEL_LARGE;
        _labelTitle.text = LanguageManager.getInstance().getString( 'servicetypepage.title' );
        _labelTitle.layoutData = new HorizontalLayoutData( 100 );
        _titleGroup.addChild( _labelTitle );
        
        var line = new HLine();
            line.width = _w;
    	    this.addChild( line );
    	    
    	    _serviceTypeGrid = new ServiceTypeGrid(new ArrayCollection(_serviceTypesCollection));
    	    _serviceTypeGrid.selectedIndex = 0;
    	    _serviceTypeGrid.width = _w;
    	    _serviceTypeGrid.columns = new ArrayCollection([
			new GridViewColumn("Service", (data) -> {
				// Strip version from display name
				var displayName = data.value;
				// Use a regular expression to find and remove the version
				var versionPattern = ~/\sv\d+(\.\d+)*$/;
				if (versionPattern.match(displayName)) {
					displayName = versionPattern.replace(displayName, "");
				}
				return displayName;
			}),
			new GridViewColumn("Description", (data) -> data.description),
		]);
		this.addChild(_serviceTypeGrid);
		
    	    var line = new HLine();
        		line.width = _w;
    		this.addChild( line );
    		
    		_buttonGroup = new LayoutGroup();
        _buttonGroupLayout = new HorizontalLayout();
        _buttonGroupLayout.gap = GenesisApplicationTheme.GRID * 2;
        _buttonGroupLayout.horizontalAlign = HorizontalAlign.CENTER;
        _buttonGroup.layout = _buttonGroupLayout;
        this.addChild( _buttonGroup );

        _buttonSave = new GenesisFormButton( LanguageManager.getInstance().getString( 'servicetypepage.continue' ) );
        _buttonSave.addEventListener( TriggerEvent.TRIGGER, _continueButtonTriggered );
        _buttonGroup.addChild(_buttonSave);
        
        _buttonClose = new GenesisFormButton( LanguageManager.getInstance().getString( 'settingspage.buttons.cancel' ) );
        _buttonClose.addEventListener( TriggerEvent.TRIGGER, _buttonCloseTriggered );
        _buttonGroup.addChild( _buttonClose );
        
        _buttonImportProvisioner = new GenesisFormButton("Import Provisioner");
        _buttonImportProvisioner.addEventListener(TriggerEvent.TRIGGER, _importProvisioner);
        _buttonGroup.addChild(_buttonImportProvisioner);
    }
    
    function _continueButtonTriggered(e:TriggerEvent) {
        var selectedServiceType = _serviceTypeGrid.selectedItem;
        
        // Create the appropriate event based on server type
        var event:SuperHumanApplicationEvent;
        
        // Log the selected service type for debugging
        champaign.core.logging.Logger.info('Selected service type: ${selectedServiceType.value}, type: ${selectedServiceType.provisionerType}, serverType: ${selectedServiceType.serverType}');
        
        // Store the original provisioner type for safe keeping
        var originalProvisionerType = selectedServiceType.provisionerType;
        
        // Validate the provisioner type based on the UI type selection
        // This ensures consistent provisioner types for the standard provisioner types
        if (Std.string(selectedServiceType.serverType) == Std.string(ServerUIType.AdditionalDomino)) {
            // For additional Domino servers - ALWAYS force the standard type
            event = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.CREATE_ADDITIONAL_DOMINO_SERVER);
            selectedServiceType.provisionerType = ProvisionerType.AdditionalProvisioner;
            champaign.core.logging.Logger.info('Forcing provisioner type to AdditionalProvisioner for additional server');
        } else if (originalProvisionerType == ProvisionerType.StandaloneProvisioner || 
                  selectedServiceType.value.indexOf("HCL Standalone Provisioner") >= 0) {
            // For standard Domino servers - ALWAYS force the standard type
            event = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.CREATE_SERVER);
            selectedServiceType.provisionerType = ProvisionerType.StandaloneProvisioner;
            champaign.core.logging.Logger.info('Forcing provisioner type to StandaloneProvisioner for standard server');
        } else {
            // For custom provisioners
            event = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.CREATE_CUSTOM_SERVER);
            champaign.core.logging.Logger.info('Using custom provisioner type: ${selectedServiceType.provisionerType}');
        }
        
        // Double check that the provisioner type is correct after our fixes
        champaign.core.logging.Logger.info('Final provisioner type after validation: ${selectedServiceType.provisionerType}');
        
        // Set the provisioner type and service type data on the event
        event.provisionerType = selectedServiceType.provisionerType;
        event.serviceTypeData = selectedServiceType;

        this.dispatchEvent(event);
	}
	
    /**
     * Check if a provisioner type is a custom provisioner
     * Use string comparison to handle both enum and string values consistently
     * @param provisionerType The provisioner type to check
     * @return Bool True if the provisioner type is a custom provisioner
     */
    private function _isCustomProvisioner(provisionerType:String):Bool {
        // Check if the provisioner type is not one of the built-in types
        // Use string comparison to handle both enum and string values
        return Std.string(provisionerType) != Std.string(ProvisionerType.StandaloneProvisioner) && 
               Std.string(provisionerType) != Std.string(ProvisionerType.AdditionalProvisioner) &&
               Std.string(provisionerType) != Std.string(ProvisionerType.Default);
    }
	
    function _buttonCloseTriggered( e:TriggerEvent ) {
        this.dispatchEvent( new SuperHumanApplicationEvent( SuperHumanApplicationEvent.CLOSE_SERVICE_TYPE_PAGE ) );
    }
    
    /**
     * Handle the import provisioner button click
     * @param e The trigger event
     */
    function _importProvisioner(e:TriggerEvent) {
        var fd = new FileDialog();
        fd.onSelect.add(path -> {
            // Import the provisioner
            var success = ProvisionerManager.importProvisioner(path);
            
            if (success) {
                ToastManager.getInstance().showToast("Provisioner imported successfully");
                
                // Dispatch event to notify the application that a provisioner was imported
                var event = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.IMPORT_PROVISIONER);
                this.dispatchEvent(event);
            } else {
                ToastManager.getInstance().showToast("Failed to import provisioner. Check that the directory contains a valid provisioner.yml file and at least one version directory with scripts.");
            }
        });
        
        fd.browse(FileDialogType.OPEN_DIRECTORY, null, null, "Select Provisioner Directory");
    }
    
    /**
     * Update the service types collection and refresh the grid
     * @param serviceTypes The new service types collection
     */
    public function updateServiceTypes(serviceTypes:Array<ServiceTypeData>) {
        // Update the internal collection
        _serviceTypesCollection = serviceTypes;
        
        // Sort the provisioners by type: Standalone first, Additional second, custom types last
        _serviceTypesCollection.sort((a, b) -> {
            // Standalone first
            if (a.provisionerType == ProvisionerType.StandaloneProvisioner && b.provisionerType != ProvisionerType.StandaloneProvisioner)
                return -1;
            if (a.provisionerType != ProvisionerType.StandaloneProvisioner && b.provisionerType == ProvisionerType.StandaloneProvisioner)
                return 1;
            
            // Additional second
            if (a.provisionerType == ProvisionerType.AdditionalProvisioner && b.provisionerType != ProvisionerType.AdditionalProvisioner)
                return -1;
            if (a.provisionerType != ProvisionerType.AdditionalProvisioner && b.provisionerType == ProvisionerType.AdditionalProvisioner)
                return 1;
            
            // Everything else (custom provisioners) is equal priority
            return 0;
        });
        
        // Update the grid's data provider
        if (_serviceTypeGrid != null) {
            _serviceTypeGrid.dataProvider = new ArrayCollection(_serviceTypesCollection);
            
            // Select the first item if available
            if (_serviceTypesCollection.length > 0) {
                _serviceTypeGrid.selectedIndex = 0;
            }
            
            // Force the grid to update by calling updateAll on the data provider
            _serviceTypeGrid.dataProvider.updateAll();
            
            // Validate the grid to ensure UI is updated
            _serviceTypeGrid.validateNow();
        }
    }
    
    /**
     * Force a refresh of the service types grid
     * Similar to how SettingsPage.refreshBrowsers() works
     */
    public function refreshServiceTypes() {
        if (_serviceTypeGrid != null && _serviceTypeGrid.dataProvider != null) {
            _serviceTypeGrid.dataProvider.updateAll();
            _serviceTypeGrid.validateNow();
        }
    }
}
