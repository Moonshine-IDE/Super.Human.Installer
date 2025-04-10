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

import champaign.core.logging.Logger;
import feathers.controls.Check;
import feathers.controls.Label;
import feathers.controls.LayoutGroup;
import feathers.controls.ScrollContainer;
import feathers.layout.VerticalLayout;
import feathers.layout.VerticalLayoutData;
import feathers.events.TriggerEvent;
import feathers.layout.HorizontalAlign;
import feathers.layout.HorizontalLayout;
import feathers.layout.HorizontalLayoutData;
import feathers.layout.VerticalAlign;
import genesis.application.components.GenesisForm;
import genesis.application.components.GenesisFormButton;
import genesis.application.components.GenesisFormCheckBox;
import genesis.application.components.GenesisFormNumericStepper;
import genesis.application.components.GenesisFormPupUpListView;
import genesis.application.components.GenesisFormRow;
import genesis.application.components.GenesisFormTextInput;
import genesis.application.components.HLine;
import genesis.application.components.Page;
import genesis.application.managers.LanguageManager;
import genesis.application.theme.GenesisApplicationTheme;
import haxe.io.Path;
import openfl.events.Event;
import prominic.sys.applications.oracle.BridgedInterface;
import prominic.sys.applications.oracle.VirtualBox;
import sys.FileSystem;
import superhuman.events.SuperHumanApplicationEvent;
import superhuman.managers.ProvisionerManager;
import superhuman.managers.ProvisionerManager.ProvisionerField;
import superhuman.server.Server;
import superhuman.server.definitions.ProvisionerDefinition;
import superhuman.theme.SuperHumanInstallerTheme;

/**
 * A dynamic advanced configuration page for custom provisioners
 * This page reads the advanced configuration fields from the provisioner.yml file
 * and dynamically creates the form fields
 */
class DynamicAdvancedConfigPage extends Page {

    final _w:Float = GenesisApplicationTheme.GRID * 100;

    var _buttonCancel:GenesisFormButton;
    var _buttonGroup:LayoutGroup;
    var _buttonGroupLayout:HorizontalLayout;
    var _buttonSave:GenesisFormButton;
    var _form:GenesisForm;
    var _label:Label;
    var _labelMandatory:Label;
    var _server:Server;
    var _titleGroup:LayoutGroup;
    var _provisionerDefinition:ProvisionerDefinition;
    var _pendingProvisionerDefinition:ProvisionerDefinition;
    var _formInitialized:Bool = false;
    var _pendingUpdateContent:Bool = false;
    
    // Standard form fields
    var _dropdownNetworkInterface:GenesisFormPupUpListView;
    var _rowNetworkInterface:GenesisFormRow;
    
    // Dynamic form fields
    var _dynamicFields:Map<String, Dynamic> = new Map();
    var _dynamicRows:Map<String, GenesisFormRow> = new Map();
    // Local storage for custom properties not already in the server
    var _customProperties:Map<String, Dynamic> = new Map();

    public function new() {
        super();
    }

    override function initialize() {
        super.initialize();
        
        // Add event listener for when the component is added to stage
        this.addEventListener(openfl.events.Event.ADDED_TO_STAGE, _onAddedToStage);

        // Create a vertical layout for the page
        var pageLayout = new VerticalLayout();
        pageLayout.horizontalAlign = HorizontalAlign.CENTER;
        pageLayout.gap = GenesisApplicationTheme.GRID;
        this.layout = pageLayout;

        // Create the title group at the top (outside scroll container)
        _titleGroup = new LayoutGroup();
        var _titleGroupLayout = new HorizontalLayout();
        _titleGroupLayout.horizontalAlign = HorizontalAlign.LEFT;
        _titleGroupLayout.verticalAlign = VerticalAlign.MIDDLE;
        _titleGroup.layout = _titleGroupLayout;
        _titleGroup.width = _w;
        this.addChild(_titleGroup);

        _label = new Label();
        _label.text = LanguageManager.getInstance().getString('serveradvancedconfigpage.title', "");
        _label.variant = GenesisApplicationTheme.LABEL_LARGE;
        _label.layoutData = new HorizontalLayoutData(100);
        _titleGroup.addChild(_label);

        var line = new HLine();
        line.width = _w;
        this.addChild(line);

        // Create a scroll container for the form content
        var scrollContainer = new ScrollContainer();
        scrollContainer.variant = SuperHumanInstallerTheme.SCROLL_CONTAINER_DARK;
        scrollContainer.layoutData = new VerticalLayoutData(100, 100);
        
        // Set up vertical layout for the scroll container
        var scrollLayout = new VerticalLayout();
        scrollLayout.horizontalAlign = HorizontalAlign.CENTER;
        scrollLayout.gap = GenesisApplicationTheme.GRID;
        scrollLayout.paddingTop = GenesisApplicationTheme.GRID * 2;
        scrollLayout.paddingBottom = GenesisApplicationTheme.GRID * 2;
        scrollContainer.layout = scrollLayout;
        
        // Add the scroll container to the page
        this.addChild(scrollContainer);

        // Create the form and add it to the scroll container
        _form = new GenesisForm();
        scrollContainer.addChild(_form);

        // Initialize network interface dropdown but don't add to form yet
        // We'll only add it if the provisioner.yml has a corresponding field
        _rowNetworkInterface = new GenesisFormRow();
        _rowNetworkInterface.text = LanguageManager.getInstance().getString('serveradvancedconfigpage.form.networkinterface.text');
        // Create a custom collection with Default and None options at the beginning
        var originalCollection = VirtualBox.getInstance().bridgedInterfacesCollection;
        var interfaceCollection = new feathers.data.ArrayCollection<BridgedInterface>();
        
        // Get the default network interface from global preferences
        var defaultNic = SuperHumanInstaller.getInstance().config.preferences.defaultNetworkInterface;
        
        // Add Default option (empty string)
        interfaceCollection.add({ name: "" });
        
        // Add None option (special "none" value)
        interfaceCollection.add({ name: "none" });
        
        // Create a deduplicated collection by excluding empty names, "none", and the default interface
        var addedNames = new Map<String, Bool>();
        addedNames.set("", true);  // Already added empty string (Default)
        addedNames.set("none", true); // Already added "none"
        
        if (defaultNic != null && defaultNic != "" && defaultNic != "none") {
            addedNames.set(defaultNic, true); // Mark default as added to avoid duplicates
        }
        
        // Add all original interfaces, excluding duplicates and the default
        for (i in 0...originalCollection.length) {
            var interfaceItem = originalCollection.get(i);
            if (interfaceItem.name != "" && interfaceItem.name != "none" && !addedNames.exists(interfaceItem.name)) {
                interfaceCollection.add(interfaceItem);
                addedNames.set(interfaceItem.name, true);
            }
        }
        
        _dropdownNetworkInterface = new GenesisFormPupUpListView(interfaceCollection);
        _dropdownNetworkInterface.itemToText = (item:BridgedInterface) -> {
            if (item.name == "") {
                // Get the default network interface from global preferences
                var defaultNic = SuperHumanInstaller.getInstance().config.preferences.defaultNetworkInterface;
                if (defaultNic != null && defaultNic != "" && defaultNic != "none") {
                    return 'Default (' + defaultNic + ')';
                }
                return 'Default (none selected)';
            }
            if (item.name == "none") return "None";
            return item.name;
        };
        // Don't set selectedIndex here, wait until we have data
        _dropdownNetworkInterface.prompt = LanguageManager.getInstance().getString('serveradvancedconfigpage.form.networkinterface.prompt');
        _rowNetworkInterface.content.addChild(_dropdownNetworkInterface);
        // We'll add this to the form only if needed based on provisioner

        // Add a line after the scroll container
        var bottomLine = new HLine();
        bottomLine.width = _w;
        this.addChild(bottomLine);

        // Create button group at the bottom (outside scroll container)
        _buttonGroup = new LayoutGroup();
        _buttonGroupLayout = new HorizontalLayout();
        _buttonGroupLayout.gap = GenesisApplicationTheme.GRID * 2;
        _buttonGroupLayout.horizontalAlign = HorizontalAlign.CENTER;
        _buttonGroup.layout = _buttonGroupLayout;
        _buttonSave = new GenesisFormButton(LanguageManager.getInstance().getString('serveradvancedconfigpage.form.buttons.save'));
        _buttonSave.addEventListener(TriggerEvent.TRIGGER, _saveButtonTriggered);
        _buttonSave.width = GenesisApplicationTheme.GRID * 20;
        _buttonCancel = new GenesisFormButton(LanguageManager.getInstance().getString('serveradvancedconfigpage.form.buttons.cancel'));
        _buttonCancel.addEventListener(TriggerEvent.TRIGGER, _cancel);
        _buttonCancel.width = GenesisApplicationTheme.GRID * 20;
        _buttonGroup.addChild(_buttonSave);
        _buttonGroup.addChild(_buttonCancel);
        this.addChild(_buttonGroup);

        _labelMandatory = new Label(LanguageManager.getInstance().getString('serveradvancedconfigpage.form.info'));
        _labelMandatory.variant = GenesisApplicationTheme.LABEL_COPYRIGHT_CENTER;
        this.addChild(_labelMandatory);
        
        _formInitialized = true;
        
        // If we have a pending provisioner definition, apply it now
        if (_pendingProvisionerDefinition != null) {
            setProvisionerDefinition(_pendingProvisionerDefinition);
            _pendingProvisionerDefinition = null;
        }
        
        // If we have a pending updateContent call, process it now
        if (_pendingUpdateContent) {
            _pendingUpdateContent = false;
            updateContent(true);
        }
    }
    
    /**
     * Handler for when the component is added to the stage
     * This ensures all UI components are fully initialized
     */
    private function _onAddedToStage(e:openfl.events.Event):Void {
        // Remove the listener as we only need it once
        this.removeEventListener(openfl.events.Event.ADDED_TO_STAGE, _onAddedToStage);
        
        // Process immediately when added to stage
        // If we have a pending provisioner definition, apply it now
        if (_pendingProvisionerDefinition != null) {
            setProvisionerDefinition(_pendingProvisionerDefinition);
            _pendingProvisionerDefinition = null;
        }
        
        // If we have a pending updateContent call, process it now
        if (_pendingUpdateContent) {
            _pendingUpdateContent = false;
            updateContent(true);
        }
    }

    /**
     * Set the server for this configuration page
     * @param server The server to configure
     */
    public function setServer(server:Server) {
        _server = server;
        
        // Update the label with the server ID
        if (_label != null) {
            _label.text = LanguageManager.getInstance().getString('serveradvancedconfigpage.title', Std.string(_server.id));
        }
        
        // Update the network interface dropdown
        if (_dropdownNetworkInterface != null) {
            // Reset the selected index
            _dropdownNetworkInterface.selectedIndex = 0;
            
            // Find the matching network interface
            for (i in 0..._dropdownNetworkInterface.dataProvider.length) {
                var d = _dropdownNetworkInterface.dataProvider.get(i);
                // Use getEffectiveNetworkInterface to get the actual interface value
                if (d != null && d.name == _server.getEffectiveNetworkInterface()) {
                    _dropdownNetworkInterface.selectedIndex = i;
                    break;
                }
            }
            
            // Update the enabled state - always enable in custom provisioners
            // When using custom provisioners, we need to allow changing the network bridge
            // regardless of disableBridgeAdapter value
            _dropdownNetworkInterface.enabled = !_server.networkBridge.locked;
        }
        
        // Store the server reference first, then load custom properties
        // This ensures we have the server reference before trying to load properties
        
        // Force an update of the UI after server is set
        // This will ensure fields are populated after they're created
        _pendingUpdateContent = true;
    }
    
    /**
     * Set the provisioner definition for this configuration page
     * @param definition The provisioner definition
     */
    public function setProvisionerDefinition(definition:ProvisionerDefinition) {
        // If the component is not initialized yet, store the definition for later
        if (!_formInitialized || _form == null) {
            _pendingProvisionerDefinition = definition;
            return;
        }
        
        _provisionerDefinition = definition;
        
        // Initialize server properties for all fields in the provisioner definition
        if (_server != null && definition.metadata != null && 
            definition.metadata.configuration != null && 
            definition.metadata.configuration.advancedFields != null) {
            
            
            // Create properties for each field in the advanced configuration
            for (field in definition.metadata.configuration.advancedFields) {
                _initializeServerProperty(field);
            }
        }
        
        if (definition.metadata != null) {
            if (definition.metadata.configuration != null) {
                var basicFieldCount = definition.metadata.configuration.basicFields != null ? 
                    definition.metadata.configuration.basicFields.length : 0;
                var advancedFieldCount = definition.metadata.configuration.advancedFields != null ? 
                    definition.metadata.configuration.advancedFields.length : 0;
            } else {
                Logger.warning('No configuration found in provisioner metadata');
            }
        } else {
            Logger.warning('No metadata found in provisioner definition');
        }
        
        // Clear existing dynamic fields
        for (row in _dynamicRows) {
            if (_form != null && _form.contains(row)) {
                _form.removeChild(row);
            }
        }
        _dynamicFields = new Map();
        _dynamicRows = new Map();
        
        // Also remove the network interface row if it was previously added
        if (_form != null && _form.contains(_rowNetworkInterface)) {
            _form.removeChild(_rowNetworkInterface);
        }
        
        // Check if we need to add the network interface field
        var needsNetworkInterface = false;
        
        // First check if there's a networkBridge or networkInterface field in the advanced config
        if (_provisionerDefinition != null && _provisionerDefinition.metadata != null && 
            _provisionerDefinition.metadata.configuration != null && 
            _provisionerDefinition.metadata.configuration.advancedFields != null) {
            
            for (field in _provisionerDefinition.metadata.configuration.advancedFields) {
                if (field.name == "networkBridge" || field.name == "networkInterface") {
                    needsNetworkInterface = true;
                    break;
                }
            }
        }
        
        // Add the network interface field if needed
        if (needsNetworkInterface && _form != null && _rowNetworkInterface != null) {
            _form.addChild(_rowNetworkInterface);
        }
        
        // Create dynamic fields based on the provisioner configuration
        var configFound = false;
        var advancedFields:Array<Dynamic> = null;
        
        // ONLY use version-specific metadata from the provisioner definition
        if (_provisionerDefinition != null && _provisionerDefinition.metadata != null) {
            if (_provisionerDefinition.metadata.configuration != null && 
                _provisionerDefinition.metadata.configuration.advancedFields != null) {
                advancedFields = cast _provisionerDefinition.metadata.configuration.advancedFields;
                configFound = true;
            } else {
                Logger.warning('${this}: No configuration or advancedFields found in provisioner version metadata');
                
                // If this is a version directory provisioner, try to load from version provisioner.yml
                if (_provisionerDefinition.root != null) {
                    var versionPath = _provisionerDefinition.root;
                    var versionMetadataPath = Path.addTrailingSlash(versionPath) + "provisioner.yml";
                    if (FileSystem.exists(versionMetadataPath)) {
                        try {
                            // Use the specific function for version metadata
                            var versionMetadata = ProvisionerManager.readProvisionerVersionMetadata(versionPath);
                            
                            if (versionMetadata != null && versionMetadata.configuration != null && 
                                versionMetadata.configuration.advancedFields != null) {
                                
                                advancedFields = cast versionMetadata.configuration.advancedFields;
                                configFound = true;
                                
                                // Store this metadata for future use
                                if (_server.customProperties == null) {
                                    _server.customProperties = {};
                                }
                                Reflect.setField(_server.customProperties, "versionMetadata", versionMetadata);
                                
                                // Also update the provisioner definition's metadata with this version-specific metadata
                                _provisionerDefinition.metadata = versionMetadata;
                            } else {
                                Logger.warning('${this}: Version-specific metadata has no valid configuration or advancedFields');
                            }
                        } catch (e) {
                            Logger.error('${this}: Error reading version metadata: ${e}');
                        }
                    } else {
                        Logger.warning('${this}: No provisioner.yml found at ${versionMetadataPath}');
                    }
                } else {
                    Logger.warning('${this}: Provisioner definition has no root path');
                }
            }
        } else {
            Logger.warning('${this}: No provisioner definition or metadata available');
        }
        
        // For advanced config, always ensure network interface is handled
        // Add network interface handling based on what was found
        var needsNetworkInterface = false;
        
        // Check if networkBridge or networkInterface was found in the config
        if (configFound && advancedFields != null) {
            for (field in advancedFields) {
                if (field.name == "networkBridge" || field.name == "networkInterface") {
                    needsNetworkInterface = true;
                    break;
                }
            }
        }
        
        // If network interface isn't in the fields or no fields were found, 
        // make sure we add minimal network config
        if (!needsNetworkInterface || advancedFields == null || advancedFields.length == 0) {
            // Create minimal network config if we don't have it already
            if (advancedFields == null) {
                advancedFields = [];
            }
            
            // Add networkBridge field
            advancedFields.push({ 
                name: "networkBridge", 
                type: "text", 
                label: LanguageManager.getInstance().getString('serveradvancedconfigpage.form.networkbridge.text')
            });
            
            configFound = true;
            needsNetworkInterface = true;
        }
        
        // Add the network interface field if needed
        if (needsNetworkInterface && _form != null && _rowNetworkInterface != null) {
            _form.addChild(_rowNetworkInterface);
        }
        
        // If config was found, add the fields
        if (configFound && advancedFields != null) {
            // Add each field from the configuration
            for (field in advancedFields) {
                // Skip networkBridge/networkInterface since we handle it separately
                if (field.name == "networkBridge" || field.name == "networkInterface") {
                    continue;
                }
                
                _addDynamicField(field);
            }
        } else {
            Logger.warning('${this}: No advanced fields found in provisioner.yml - form will be minimal');
        }
    }
    
    /**
     * Initialize a server property based on the field definition
     * @param field The field definition from the provisioner.yml
     */
    private function _initializeServerProperty(field:ProvisionerField) {
        if (field == null || field.name == null || _server == null) {
            Logger.warning('${this}: Cannot initialize server property: field=${field != null}, name=${field != null ? field.name != null : false}, server=${_server != null}');
            return;
        }
        
        var fieldName = field.name;
        
        // Special handling for CONSOLE_PORT field - set default to server ID
        var isConsolePortField = (fieldName == "CONSOLE_PORT");
        if (isConsolePortField) {
            field.defaultValue = _server.id;
        }
        
        // Check if the property already exists on the server - checking multiple ways
        var directExists = Reflect.hasField(_server, fieldName);
        var underscoreExists = Reflect.hasField(_server, "_" + fieldName);
        var getterExists = Reflect.hasField(_server, "get_" + fieldName);
        var propertyExists = directExists || underscoreExists || getterExists;
        
        if (!propertyExists) {
            
            // Create the property based on the field type
            switch (field.type) {
                case "text":
                    // Create a string property
                    var defaultValue = field.defaultValue != null ? Std.string(field.defaultValue) : "";
                    var prop = new champaign.core.primitives.Property<String>(defaultValue);
                    _customProperties.set(fieldName, prop);
                    
                case "number":
                    // Create a numeric property
                    var defaultValue = "0.0";
                    if (field.defaultValue != null) {
                        try {
                            var floatVal = Std.parseFloat(Std.string(field.defaultValue));
                            if (Math.isNaN(floatVal)) defaultValue = "0.0";
                            else defaultValue = Std.string(floatVal);
                        } catch (e) {
                            Logger.warning('${this}: Error parsing default value for ${fieldName}: ${e}');
                            defaultValue = "0.0";
                        }
                    }
                    var prop = new champaign.core.primitives.Property<String>(defaultValue);
                    _customProperties.set(fieldName, prop);
                    
                case "checkbox":
                    // Create a boolean property
                    var defaultValue = "false";
                    if (field.defaultValue != null) {
                        defaultValue = Std.string(field.defaultValue).toLowerCase() == "true" ? "true" : "false";
                    }
                    var prop = new champaign.core.primitives.Property<String>(defaultValue);
                    _customProperties.set(fieldName, prop);
                    
                case "dropdown":
                    // Create a string property for dropdown
                    var defaultValue = field.defaultValue != null ? Std.string(field.defaultValue) : "";
                    var prop = new champaign.core.primitives.Property<String>(defaultValue);
                    _customProperties.set(fieldName, prop);
                    
                default:
                    Logger.warning('${this}: Unknown field type for property initialization: ${field.type}');
            }
            
            // Add property change listener to custom properties
            var prop = _customProperties.get(fieldName);
            if (prop != null && Reflect.hasField(prop, "onChange")) {
                var onChange = Reflect.field(prop, "onChange");
                if (onChange != null && Reflect.hasField(onChange, "add")) {
                    var self = this;
                    Reflect.callMethod(onChange, Reflect.field(onChange, "add"), [function(p) { self._propertyChangedHandler(p); }]);
                }
            }
        } else {
            
            // Add property change listener to existing server properties
            var prop = Reflect.getProperty(_server, fieldName);
            if (prop != null && Reflect.hasField(prop, "onChange")) {
                var onChange = Reflect.field(prop, "onChange");
                if (onChange != null && Reflect.hasField(onChange, "add")) {
                    var self = this;
                    Reflect.callMethod(onChange, Reflect.field(onChange, "add"), [function(p) { self._propertyChangedHandler(p); }]);
                }
            }
        }
    }
    
    /**
     * Add a dynamic field to the form based on the field definition
     * @param field The field definition from the provisioner.yml
     */
    private function _addDynamicField(field:ProvisionerField) {
        if (field == null) {
            Logger.warning("Attempted to add a null field to the form");
            return;
        }
        
        // Skip UI creation for hidden fields but still store them in dynamicFields
        // First check if the field has a hidden property that's true
        var isHidden = false;
        if (Reflect.hasField(field, "hidden")) {
            var hiddenValue = Reflect.field(field, "hidden");
            isHidden = (hiddenValue == true || Std.string(hiddenValue).toLowerCase() == "true");
        } else {
            Logger.info('${this}: Field ${field.name} has no hidden property defined');
        }
        
        if (isHidden) {
            // For hidden fields, store a reference to the default value directly
            var defaultValue = null;
            if (field.defaultValue != null) {
                defaultValue = field.defaultValue;
            }
            _dynamicFields.set(field.name, {
                hidden: true,
                value: defaultValue
            });
            return;
        }
        
        // Create a new row for the field
        var row = new GenesisFormRow();
        row.text = field.label != null ? field.label : "Unnamed Field";
        
        // Create the appropriate form control based on the field type
        switch (field.type != null ? field.type : "") {
            case "text":
                var input = new GenesisFormTextInput();
                input.prompt = field.placeholder != null ? field.placeholder : "";
                input.toolTip = field.tooltip != null ? field.tooltip : "";
                
                // Set validation key if provided
                if (field.validationKey != null) {
                    input.validationKey = new EReg(field.validationKey, "");
                }
                
                // Set default value if provided
                if (field.defaultValue != null) {
                    input.text = Std.string(field.defaultValue);
                }
                
                // Set minimum length if required
                if (field.required == true) {
                    input.minLength = 1;
                }
                
                // Set restrict if provided
                if (field.restrict != null) {
                    input.restrict = field.restrict;
                }
                
                // Add the input to the row
                row.content.addChild(input);
                
                // Store the input in the dynamic fields map
                _dynamicFields.set(field.name, input);
                
                case "number":
                    // Get default values
                    var defaultValue = field.defaultValue != null ? Std.parseFloat(Std.string(field.defaultValue)) : 0;
                    var minValue = field.min != null ? field.min : 0;
                    var maxValue = field.max != null ? field.max : 100;
                    
                    // For common integer fields, make sure we're using integer step values
                    var isIntegerField = (field.name == "numCPUs" || field.name == "setupWait" || field.name == "CONSOLE_PORT");
                    
                    // Memory field should increment by whole numbers but allow decimal values
                    var usesWholeNumberStep = isIntegerField || field.name == "memory";
                    
                    // Force default value to be an integer for integer fields
                    if (isIntegerField && !Math.isNaN(defaultValue)) {
                        defaultValue = Math.round(defaultValue);
                    }
                    
                    var stepper = new GenesisFormNumericStepper(defaultValue, minValue, maxValue);
                    
                    // For integer fields like numCPUs and setupWait, set the step to 1.0 
                    // Also set step to 1.0 for memory field to increment by whole numbers
                    if (isIntegerField || field.name == "memory") {
                        // Set step property directly on the NumericStepper instance
                        stepper.step = 1.0;
                    }
                    
                    stepper.toolTip = field.tooltip != null ? field.tooltip : "";
                
                    // Add the stepper to the row
                    row.content.addChild(stepper);
                
                    // Store the stepper in the dynamic fields map
                    _dynamicFields.set(field.name, stepper);
                
            case "checkbox":
                // Create checkbox with default value of false
                var isSelected = false;
                if (field.defaultValue != null) {
                    isSelected = Std.string(field.defaultValue).toLowerCase() == "true";
                }
                var checkbox = new GenesisFormCheckBox(field.label, isSelected);
                checkbox.toolTip = field.tooltip != null ? field.tooltip : "";
                
                // Add the checkbox to the row
                row.content.addChild(checkbox);
                
                // Store the checkbox in the dynamic fields map
                _dynamicFields.set(field.name, checkbox);
                
            case "dropdown":
                var dropdown = new GenesisFormPupUpListView();
                dropdown.toolTip = field.tooltip != null ? field.tooltip : "";
                
                // Add options if provided
                if (field.options != null) {
                    try {
                        var options = [];
                        
                        // Check if options is a nested array (sometimes YAML can parse it this way)
                        if (Std.isOfType(field.options, Array) && field.options.length > 0) {
                            // Handle nested array case
                            var nestedOptions:Array<Dynamic> = cast field.options;
                            for (option in nestedOptions) {
                                if (option != null) {
                                    var value = null;
                                    var label = null;
                                    
                                    if (Reflect.hasField(option, "value")) {
                                        value = Reflect.field(option, "value");
                                    }
                                    
                                    if (Reflect.hasField(option, "label")) {
                                        label = Reflect.field(option, "label");
                                    }
                                    
                                    if (value != null && label != null) {
                                        options.push([value, label]);
                                    } else {
                                        Logger.warning('Invalid dropdown option in field ${field.name}: ${option}');
                                    }
                                }
                            }
                        } else {
                            // Handle normal array case
                            for (option in field.options) {
                                if (option != null) {
                                    var value = null;
                                    var label = null;
                                    
                                    if (option != null) {
                                        if (Reflect.hasField(option, "value")) {
                                            value = Reflect.field(option, "value");
                                        }
                                        
                                        if (Reflect.hasField(option, "label")) {
                                            label = Reflect.field(option, "label");
                                        }
                                        
                                        if (value != null && label != null) {
                                            options.push([value, label]);
                                        } else {
                                            Logger.warning('Invalid dropdown option in field ${field.name}: value=${value}, label=${label}');
                                        }
                                    }
                                }
                            }
                        }
                        
                        if (options.length > 0) {
                            dropdown.dataProvider = new feathers.data.ArrayCollection(options);
                            dropdown.itemToText = (item) -> item != null && item.length > 1 ? item[1] : "Unknown";
                            
                            // Set default value if provided
                            if (field.defaultValue != null) {
                                for (i in 0...options.length) {
                                    if (options[i][0] == field.defaultValue) {
                                        dropdown.selectedIndex = i;
                                        break;
                                    }
                                }
                            }
                        } else {
                            Logger.warning('No valid options found for dropdown field ${field.name}');
                        }
                    } catch (e) {
                        Logger.error('Error parsing dropdown options for field ${field.name}: ${e}');
                    }
                }
                
                // Add the dropdown to the row
                row.content.addChild(dropdown);
                
                // Store the dropdown in the dynamic fields map
                _dynamicFields.set(field.name, dropdown);
                
            default:
                Logger.warning('Unknown field type: ${field.type} for field ${field.name}');
        }
        
        // Add the row to the form if both row and form are not null
        if (row != null && _form != null) {
            _form.addChild(row);
            
            // Store the row in the dynamic rows map
            if (field.name != null) {
                _dynamicRows.set(field.name, row);
            }
        } else {
            Logger.warning('Could not add row to form: row=${row != null}, form=${_form != null}, field.name=${field.name != null}');
        }
    }

    override public function updateContent(forced:Bool = false) {
        super.updateContent();

        // If the form is not initialized yet, store the update request for later
        if (!_formInitialized || _form == null || _server == null) {
            _pendingUpdateContent = true;
            return;
        }
        
        if (_form != null && _server != null && _dropdownNetworkInterface != null) {
            _label.text = LanguageManager.getInstance().getString('serveradvancedconfigpage.title', Std.string(_server.id));
            
            // Update network interface dropdown
            _dropdownNetworkInterface.selectedIndex = 0;
            for (i in 0..._dropdownNetworkInterface.dataProvider.length) {
                var d = _dropdownNetworkInterface.dataProvider.get(i);
                if (d != null && d.name == _server.networkBridge.value) {
                    _dropdownNetworkInterface.selectedIndex = i;
                    break;
                }
            }
            // Update the enabled state - always enable in custom provisioners, regardless of disableBridgeAdapter
            _dropdownNetworkInterface.enabled = !_server.networkBridge.locked;
            
            // Load custom properties from server.customProperties if they haven't been loaded yet
            if (_server.customProperties != null && Lambda.count(_customProperties) == 0) {
                // Check for dynamicAdvancedCustomProperties
                if (Reflect.hasField(_server.customProperties, "dynamicAdvancedCustomProperties")) {
                    var customPropsObj = Reflect.field(_server.customProperties, "dynamicAdvancedCustomProperties");
                    if (customPropsObj != null) {
                        var fields = Reflect.fields(customPropsObj);
                        for (field in fields) {
                            var value = Reflect.field(customPropsObj, field);
                            // Create a property based on the value type if it doesn't already exist
                            if (!_customProperties.exists(field)) {
                                var prop = null;
                                
                                if (Std.isOfType(value, String)) {
                                    prop = new champaign.core.primitives.Property<String>(value);
                                } else if (Std.isOfType(value, Float) || Std.isOfType(value, Int)) {
                                    prop = new champaign.core.primitives.Property<String>(Std.string(value));
                                } else if (Std.isOfType(value, Bool)) {
                                    // Convert Boolean to String for consistency
                                    var boolValue:Bool = cast value;
                                    var boolStr = boolValue ? "true" : "false";
                                    prop = new champaign.core.primitives.Property<String>(boolStr);
                                } else {
                                    // Handle other types by converting to string
                                    prop = new champaign.core.primitives.Property<String>(Std.string(value));
                                }
                                
                                if (prop != null) {
                                    _customProperties.set(field, prop);
                                    
                                    // Add property change listener
                                    var onChange = Reflect.field(prop, "onChange");
                                    if (onChange != null && Reflect.hasField(onChange, "add")) {
                                        var self = this;
                                        Reflect.callMethod(onChange, Reflect.field(onChange, "add"), [function(p) { self._propertyChangedHandler(p); }]);
                                    }
                                }
                            } else {
                                // Update existing property
                                var prop = _customProperties.get(field);
                                if (prop != null && Reflect.hasField(prop, "value")) {
                                    Reflect.setField(prop, "value", value);
                                }
                            }
                        }
                    }
                }
            }
            
            // Look for dynamic custom properties in server.customProperties if they exist
            var customPropValues = new Map<String, Dynamic>();
            if (_server.customProperties != null) {
                // Check for dynamicAdvancedCustomProperties
                if (Reflect.hasField(_server.customProperties, "dynamicAdvancedCustomProperties")) {
                    var customPropsObj = Reflect.field(_server.customProperties, "dynamicAdvancedCustomProperties");
                    if (customPropsObj != null) {
                        var fields = Reflect.fields(customPropsObj);
                        for (field in fields) {
                            var value = Reflect.field(customPropsObj, field);
                            customPropValues.set(field, value);
                        }
                    } else {
                        Logger.warning('${this}: dynamicAdvancedCustomProperties object is null');
                    }
                }
            } else {
                Logger.info('${this}: Server customProperties is null');
            }
            
            // Update dynamic fields with server or custom property values
            for (fieldName => field in _dynamicFields) {
                var value = null;
                var valueField = null;
                var valueSource = "none";
                
                // First check if it's in the customPropValues map (direct from customProperties)
                if (customPropValues.exists(fieldName)) {
                    valueField = customPropValues.get(fieldName);
                    valueSource = "customProperties";
                }
                // Then check if it's a custom property in our local map
                else if (_customProperties.exists(fieldName)) {
                    value = _customProperties.get(fieldName);
                    if (value != null && Reflect.hasField(value, "value")) {
                        valueField = Reflect.field(value, "value");
                    }
                    valueSource = "customPropertiesMap";
                } 
                // If not, try to get it from the server
                else {
                    try {
                        value = Reflect.getProperty(_server, fieldName);
                        if (value != null && Reflect.hasField(value, "value")) {
                            valueField = Reflect.field(value, "value");
                        } else {
                            valueField = value;
                        }
                        valueSource = "serverProperty";
                    } catch (e) {
                        // Try with underscore prefix
                        try {
                            value = Reflect.getProperty(_server, "_" + fieldName);
                            if (value != null && Reflect.hasField(value, "value")) {
                                valueField = Reflect.field(value, "value");
                            } else {
                                valueField = value;
                            }
                            valueSource = "serverPropertyUnderscore";
                        } catch (e2) {
                            // Property doesn't exist on server
                            Logger.warning('${this}: Could not get property value for ${fieldName}: ${e2}');
                        }
                    }
                }
                
                // If we still don't have a value, check if there's a direct property in customProperties
                if ((valueField == null && value == null) && _server.customProperties != null) {
                    if (Reflect.hasField(_server.customProperties, fieldName)) {
                        valueField = Reflect.field(_server.customProperties, fieldName);
                        valueSource = "directCustomProperty";
                    }
                }
                
                // Apply the value to the field
                if (valueField != null || value != null) {
                    if (Std.isOfType(field, GenesisFormTextInput)) {
                        var input:GenesisFormTextInput = cast field;
                        var displayValue = "";
                        
                        if (valueField != null) {
                            // Use the valueField directly
                            displayValue = Std.string(valueField);
                        } else if (value != null) {
                            // Remove "Property: " prefix if present
                            var valueStr = Std.string(value);
                            if (valueStr.indexOf("Property: ") == 0) {
                                valueStr = valueStr.substr(10); // Remove "Property: " prefix
                            }
                            displayValue = valueStr;
                        }
                        
                        input.text = displayValue;
                        
                    } else if (Std.isOfType(field, GenesisFormNumericStepper)) {
                        var stepper:GenesisFormNumericStepper = cast field;
                        var numValue:Float = 0;
                        
                        // Get the default value from the provisioner definition for fallback
                        var defaultValue:Float = 0;
                        var hasDefaultValue = false;
                        
                        if (_provisionerDefinition != null && 
                            _provisionerDefinition.metadata != null && 
                            _provisionerDefinition.metadata.configuration != null && 
                            _provisionerDefinition.metadata.configuration.advancedFields != null) {
                            
                            // Find the field in the definition to get its default value
                            for (defField in _provisionerDefinition.metadata.configuration.advancedFields) {
                                if (defField.name == fieldName && defField.defaultValue != null) {
                                    try {
                                        defaultValue = Std.parseFloat(Std.string(defField.defaultValue));
                                        if (!Math.isNaN(defaultValue)) {
                                            hasDefaultValue = true;
                                        }
                                    } catch (e) {
                                        Logger.warning('${this}: Error parsing default value for ${fieldName}: ${e}');
                                    }
                                    break;
                                }
                            }
                        }
                        
                        if (valueField != null) {
                            try {
                                numValue = Std.parseFloat(Std.string(valueField));
                                if (Math.isNaN(numValue) && hasDefaultValue) {
                                    numValue = defaultValue;
                                }
                            } catch (e) {
                                Logger.warning('${this}: Error parsing value for ${fieldName}: ${e}, using default: ${hasDefaultValue ? defaultValue : 0}');
                                numValue = hasDefaultValue ? defaultValue : 0;
                            }
                        } else if (value != null) {
                            try {
                                numValue = Std.parseFloat(Std.string(value));
                                if (Math.isNaN(numValue) && hasDefaultValue) {
                                    numValue = defaultValue;
                                }
                            } catch (e) {
                                Logger.warning('${this}: Error parsing value for ${fieldName}: ${e}, using default: ${hasDefaultValue ? defaultValue : 0}');
                                numValue = hasDefaultValue ? defaultValue : 0;
                            }
                        } else if (hasDefaultValue) {
                            // No value found, use the default from provisioner definition
                            numValue = defaultValue;
                        }
                        
                        // Special handling for integer fields to ensure they're whole numbers
                        if (fieldName == "numCPUs" || fieldName == "setupWait" || fieldName == "CONSOLE_PORT") {
                            numValue = Math.round(numValue);
                        }
                        
                        // Ensure the value is within bounds
                        // Use Reflect to safely check if properties exist and have values
                        if (Reflect.hasField(stepper, "minimum")) {
                            var min = Reflect.field(stepper, "minimum");
                            if (min != null && Std.isOfType(min, Float) && numValue < min) {
                                numValue = min;
                            }
                        }
                        
                        if (Reflect.hasField(stepper, "maximum")) {
                            var max = Reflect.field(stepper, "maximum");
                            if (max != null && Std.isOfType(max, Float) && numValue > max) {
                                numValue = max;
                            }
                        }
                        
                        stepper.value = numValue;
                        
                    } else if (Std.isOfType(field, GenesisFormCheckBox)) {
                        var checkbox:GenesisFormCheckBox = cast field;
                        var boolValue:Bool = false;
                        
                        if (valueField != null) {
                            if (Std.isOfType(valueField, Bool)) {
                                boolValue = cast valueField;
                            } else if (Std.isOfType(valueField, String)) {
                                boolValue = Std.string(valueField).toLowerCase() == "true";
                            } else {
                                boolValue = valueField != null; // Convert to boolean
                            }
                        } else if (value != null) {
                            if (Std.isOfType(value, Bool)) {
                                boolValue = cast value;
                            } else if (Std.isOfType(value, String)) {
                                boolValue = Std.string(value).toLowerCase() == "true";
                            } else {
                                boolValue = value != null; // Convert to boolean
                            }
                        }
                        
                        checkbox.selected = boolValue;
                        
                    } else if (Std.isOfType(field, GenesisFormPupUpListView)) {
                        var dropdown:GenesisFormPupUpListView = cast field;
                        if (dropdown.dataProvider != null && dropdown.dataProvider.length > 0) {
                            var selectedValue = valueField != null ? valueField : value;
                            var foundMatch = false;
                            
                            
                            for (i in 0...dropdown.dataProvider.length) {
                                var option = dropdown.dataProvider.get(i);
                                if (option != null && option.length > 0) {
                                    
                                    if (option[0] == selectedValue) {
                                        dropdown.selectedIndex = i;
                                        foundMatch = true;
                                        break;
                                    }
                                }
                            }
                            
                            if (!foundMatch) {
                                Logger.warning('${this}: Could not find matching option for dropdown ${fieldName} with value ${selectedValue}');
                            }
                        }
                    }
                } else {
                    Logger.info('${this}: No value found for field ${fieldName}');
                }
            }
        }
    }

    /**
     * Handler for property changes to propagate to the server
     * @param property The property that changed
     */
    private function _propertyChangedHandler<T>(property:T):Void {
        if (_server != null) {
            _server.setServerStatus();
        }
    }
    
    override function _cancel(?e:Dynamic) {
        // For advanced config, we don't remove provisional servers on cancel
        // Instead, we just return to the basic config page with no changes
        
        // Use CANCEL_PAGE to return to the basic config page
        var evt = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.CANCEL_PAGE);
        if (_server != null) {
            evt.server = _server;
            // Check that provisioner exists before accessing type to avoid null reference
            if (_server.provisioner != null) {
                evt.provisionerType = _server.provisioner.type;
            } else {
                Logger.warning('${this}: Server has no provisioner, cannot determine type');
            }
        } else {
            Logger.warning('${this}: No server object available for cancel event');
        }
        
        // The SuperHumanInstaller.hx _cancelAdvancedConfigureServer method will handle navigation
        // back to the appropriate basic configuration page
        this.dispatchEvent(evt);
    }
    
    function _saveButtonTriggered(e:TriggerEvent) {
        // Verify form validation before saving
        if (!_form.isValid()) {
            Logger.warning('${this}: Form validation failed, cannot save configuration');
            
            // Log which fields might be invalid
            for (fieldName => field in _dynamicFields) {
                if (Std.isOfType(field, GenesisFormTextInput)) {
                    var input:GenesisFormTextInput = cast field;
                    // GenesisFormTextInput doesn't have an errorText property or isValid property
                    // Just log that the field might be invalid
                    Logger.warning('${this}: Field ${fieldName} may be invalid - please check requirements');
                }
            }
            return;
        }
        
        if (_server == null) {
            Logger.warning('${this}: Server object is null, cannot save');
            return;
        }

        // Update standard fields
        if (_dropdownNetworkInterface.selectedItem != null) {
            // Get the selected network interface
            var selectedInterface = _dropdownNetworkInterface.selectedItem.name;
            
            // Handle "Default" (empty string) case
            if (selectedInterface == "") {
                // Use the default from preferences
                var defaultNic = SuperHumanInstaller.getInstance().config.preferences.defaultNetworkInterface;
                if (defaultNic != null && defaultNic != "" && defaultNic != "none") {
                    selectedInterface = defaultNic;
                }
            }
            
            // Set the value in the server object
            _server.networkBridge.value = selectedInterface;
        }
        
        // Update server properties from dynamic fields
        for (fieldName => field in _dynamicFields) {
                var value:String = null;
            
            // Special handling for hidden fields stored as objects with {hidden: true, value: defaultValue}
            if (Reflect.hasField(field, "hidden") && Reflect.field(field, "hidden") == true) {
                // For hidden fields, use the defaultValue directly
                if (Reflect.hasField(field, "value")) {
                    value = Std.string(Reflect.field(field, "value"));
                }
            } else if (Std.isOfType(field, GenesisFormTextInput)) {
                var input:GenesisFormTextInput = cast field;
                value = StringTools.trim(input.text);
            } else if (Std.isOfType(field, GenesisFormNumericStepper)) {
                var stepper:GenesisFormNumericStepper = cast field;
                value = Std.string(stepper.value);
            } else if (Std.isOfType(field, GenesisFormCheckBox)) {
                var checkbox:GenesisFormCheckBox = cast field;
                value = checkbox.selected ? "true" : "false";
            } else if (Std.isOfType(field, GenesisFormPupUpListView)) {
                var dropdown:GenesisFormPupUpListView = cast field;
                var selectedItem = dropdown.selectedItem;
                value = selectedItem != null && selectedItem.length > 0 ? Std.string(selectedItem[0]) : null;
            }
            
            if (value != null) {
                // Handle special cases for standard server properties by field name
                if (fieldName == "numCPUs") {
                    // Set CPU count via Property object
                    _server.numCPUs.value = Std.parseInt(value);
                } else if (fieldName == "memory") {
                    // Set memory via Property object
                    _server.memory.value = Std.parseFloat(value);
                } else if (fieldName == "networkAddress") {
                    // Set network address via Property object
                    _server.networkAddress.value = value;
                } else if (fieldName == "networkNetmask") {
                    // Set network netmask via Property object
                    _server.networkNetmask.value = value;
                } else if (fieldName == "networkGateway") {
                    // Set network gateway via Property object
                    _server.networkGateway.value = value;
                } else if (fieldName == "nameServer1") {
                    // Set DNS server 1 via Property object
                    _server.nameServer1.value = value;
                } else if (fieldName == "nameServer2") {
                    // Set DNS server 2 via Property object
                    _server.nameServer2.value = value;
                } else if (fieldName == "networkBridge") {
                    // Set network bridge via Property object
                    _server.networkBridge.value = value;
                } else if (fieldName == "dhcp4") {
                    // Set DHCP flag via Property object
                    var boolValue = value.toLowerCase() == "true";
                    _server.dhcp4.value = boolValue;
                } else if (fieldName == "disableBridgeAdapter") {
                    // Set disable bridge adapter flag via Property object
                    var boolValue = value.toLowerCase() == "true";
                    _server.disableBridgeAdapter.value = boolValue;
                } else if (fieldName == "setupWait") {
                    // Set setup wait time via Property object
                    _server.setupWait.value = Std.parseInt(value);
                } else if (fieldName == "CONSOLE_PORT") {
                    // Ensure CONSOLE_PORT is always stored as an integer
                    var intValue = Std.parseInt(value);
                    value = Std.string(intValue); // Ensure it's a valid integer string
                } else if (_customProperties.exists(fieldName)) {
                    // Update custom property
                    var prop = _customProperties.get(fieldName);
                    if (prop != null && Reflect.hasField(prop, "value")) {
                        Reflect.setField(prop, "value", value);
                        
                        // Also update the server field directly if it exists
                        try {
                            var propName = fieldName;
                            // Convert camelCase to snake_case for server property names
                            if (propName.indexOf("_") < 0) {
                                var snakeCase = "";
                                for (i in 0...propName.length) {
                                    var char = propName.charAt(i);
                                    if (i > 0 && char >= "A" && char <= "Z") {
                                        snakeCase += "_" + char.toLowerCase();
                                    } else {
                                        snakeCase += char.toLowerCase();
                                    }
                                }
                                propName = snakeCase;
                            }
                            Reflect.setField(_server, propName, value);
                        } catch (e) {
                            // Just continue if the field doesn't exist
                        }
                    }
                } else {
                    // Initialize customProperties if needed
                    if (_server.customProperties == null) {
                        _server.customProperties = {};
                    }
                    
                    // Initialize dynamicAdvancedCustomProperties if needed
                    if (!Reflect.hasField(_server.customProperties, "dynamicAdvancedCustomProperties")) {
                        Reflect.setField(_server.customProperties, "dynamicAdvancedCustomProperties", {});
                    }
                    
                    // Get reference to dynamicAdvancedCustomProperties
                    var customPropsObj = Reflect.field(_server.customProperties, "dynamicAdvancedCustomProperties");
                    
                    // Only store in dynamicAdvancedCustomProperties to avoid duplication
                    Reflect.setField(customPropsObj, fieldName, value);
                    
                    // Also create a custom property for change tracking
                    var prop = new champaign.core.primitives.Property<String>(value);
                    if (prop != null) {
                        _customProperties.set(fieldName, prop);
                        
                        // Add property change listener
                        var onChange = Reflect.field(prop, "onChange");
                        if (onChange != null && Reflect.hasField(onChange, "add")) {
                            var self = this;
                            Reflect.callMethod(onChange, Reflect.field(onChange, "add"), [function(p) { self._propertyChangedHandler(p); }]);
                        }
                    }
                }
            }
        }
        
        // Store custom properties in server's customProperties if available
        if (_server != null) {
            // Make sure customProperties is initialized
            if (_server.customProperties == null) {
                _server.customProperties = {};
            }
            
            // Create or update the dynamicAdvancedCustomProperties field to hold our custom properties
            var customProperties:Dynamic = _server.customProperties;
            if (!Reflect.hasField(customProperties, "dynamicAdvancedCustomProperties")) {
                Reflect.setField(customProperties, "dynamicAdvancedCustomProperties", {});
            }
            
            var customPropsObj = Reflect.field(customProperties, "dynamicAdvancedCustomProperties");
            
            // Save all dynamic field values to customProperties
            for (fieldName => field in _dynamicFields) {
                var value:Dynamic = null;
                
                if (Std.isOfType(field, GenesisFormTextInput)) {
                    var input:GenesisFormTextInput = cast field;
                    value = StringTools.trim(input.text);
                } else if (Std.isOfType(field, GenesisFormNumericStepper)) {
                    var stepper:GenesisFormNumericStepper = cast field;
                    value = stepper.value;
                } else if (Std.isOfType(field, GenesisFormCheckBox)) {
                    var checkbox:GenesisFormCheckBox = cast field;
                    value = checkbox.selected;
                } else if (Std.isOfType(field, GenesisFormPupUpListView)) {
                    var dropdown:GenesisFormPupUpListView = cast field;
                    var selectedItem = dropdown.selectedItem;
                    value = selectedItem != null && selectedItem.length > 0 ? selectedItem[0] : null;
                }
                
                if (value != null) {
                    Reflect.setField(customPropsObj, fieldName, value);
                }
            }
            
            // Also save custom properties from our local map
            for (key => prop in _customProperties) {
                if (Reflect.hasField(prop, "value")) {
                    Reflect.setField(customPropsObj, key, Reflect.field(prop, "value"));
                }
            }
            
            // Force an immediate save of server data to avoid race conditions
            _server.saveData();
        }

        // Explicitly save hosts file to ensure it's created for custom provisioners
        _server.saveHostsFile();
        
        // Initialize server files if this is a provisional server
        if (_server.provisional) {
            _server.initializeServerFiles();
        }
        
        var evt = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.SAVE_ADVANCED_SERVER_CONFIGURATION);
        evt.server = _server;
        this.dispatchEvent(evt);
    }
}
