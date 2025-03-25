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

// Note to AI, NEVER EVER EVER US PREFIXES when constructing variable names for custom provisioner variables and roles

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
import openfl.events.MouseEvent;
import superhuman.events.SuperHumanApplicationEvent;
import superhuman.managers.ProvisionerManager;
import superhuman.managers.ProvisionerManager.ProvisionerField;
import superhuman.server.Server;
import superhuman.server.definitions.ProvisionerDefinition;
import sys.FileSystem;

/**
 * A dynamic configuration page for custom provisioners
 * This page reads the configuration fields from the provisioner.yml file
 * and dynamically creates the form fields
 */
class DynamicConfigPage extends Page {

    final _w:Float = GenesisApplicationTheme.GRID * 100;

    var _advancedLink:Label;
    var _buttonCancel:GenesisFormButton;
    var _buttonGroup:LayoutGroup;
    var _buttonGroupLayout:HorizontalLayout;
    var _buttonRoles:GenesisFormButton;
    var _buttonSave:GenesisFormButton;
    public var _dropdownCoreComponentVersion:GenesisFormPupUpListView;
    var _form:GenesisForm;
    var _label:Label;
    var _labelMandatory:Label;
    var _server:Server;
    var _titleGroup:LayoutGroup;
    var _provisionerDefinition:ProvisionerDefinition;
    var _pendingProvisionerDefinition:ProvisionerDefinition;
    var _formInitialized:Bool = false;
    var _pendingUpdateContent:Bool = false;
    
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
        _label.variant = GenesisApplicationTheme.LABEL_LARGE;
        _label.layoutData = new HorizontalLayoutData(100);
        _titleGroup.addChild(_label);

        _advancedLink = new Label(LanguageManager.getInstance().getString('serverconfigpage.advancedlink'));
        _advancedLink.variant = GenesisApplicationTheme.LABEL_LINK;
        _advancedLink.addEventListener(MouseEvent.CLICK, _advancedLinkTriggered);
        _titleGroup.addChild(_advancedLink);

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
        scrollContainer.layout = scrollLayout;
        
        // Add the scroll container to the page
        this.addChild(scrollContainer);

        // Create the form and add it to the scroll container
        _form = new GenesisForm();
        scrollContainer.addChild(_form);

        // Core component version dropdown
        var rowCoreComponentVersion = new GenesisFormRow();
        rowCoreComponentVersion.text = LanguageManager.getInstance().getString('serverconfigpage.form.provisioner.text');
        
        // Initialize with empty collection - we'll set it properly in setServer
        _dropdownCoreComponentVersion = new GenesisFormPupUpListView(new feathers.data.ArrayCollection<ProvisionerDefinition>([]));
        _dropdownCoreComponentVersion.itemToText = (item:ProvisionerDefinition) -> {
            return item.name;
        };
        // Add change event listener to update roles button when selection changes
        _dropdownCoreComponentVersion.addEventListener(Event.CHANGE, _versionDropdownChanged);
        rowCoreComponentVersion.content.addChild(_dropdownCoreComponentVersion);
        _form.addChild(rowCoreComponentVersion);

        // Roles button
        var rowRoles = new GenesisFormRow();
        rowRoles.text = LanguageManager.getInstance().getString('serverconfigpage.form.roles.text');
        _buttonRoles = new GenesisFormButton(LanguageManager.getInstance().getString('serverconfigpage.form.roles.button'));
        _buttonRoles.addEventListener(TriggerEvent.TRIGGER, _buttonRolesTriggered);
        rowRoles.content.addChild(_buttonRoles);
        _form.addChild(rowRoles);

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
        _buttonSave = new GenesisFormButton(LanguageManager.getInstance().getString('serverconfigpage.form.buttons.save'));
        _buttonSave.addEventListener(TriggerEvent.TRIGGER, _saveButtonTriggered);
        _buttonSave.width = GenesisApplicationTheme.GRID * 20;
        _buttonCancel = new GenesisFormButton(LanguageManager.getInstance().getString('serverconfigpage.form.buttons.cancel'));
        _buttonCancel.addEventListener(TriggerEvent.TRIGGER, _cancel);
        _buttonCancel.width = GenesisApplicationTheme.GRID * 20;
        _buttonGroup.addChild(_buttonSave);
        _buttonGroup.addChild(_buttonCancel);
        this.addChild(_buttonGroup);

        _labelMandatory = new Label(LanguageManager.getInstance().getString('serverconfigpage.form.info'));
        _labelMandatory.variant = GenesisApplicationTheme.LABEL_COPYRIGHT_CENTER;
        this.addChild(_labelMandatory);
        
        // Mark the form as initialized
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
            _label.text = LanguageManager.getInstance().getString('serverconfigpage.title', Std.string(_server.id));
        }
        
        // First get the provisioner definition to know what fields we need
        var provisionerDefinition = null;
        if (_server.customProperties != null && Reflect.hasField(_server.customProperties, "provisionerDefinition")) {
            provisionerDefinition = Reflect.field(_server.customProperties, "provisionerDefinition");
        }
        
        // Initialize all fields from the provisioner definition
        if (provisionerDefinition != null && provisionerDefinition.metadata != null && 
            provisionerDefinition.metadata.configuration != null && 
            provisionerDefinition.metadata.configuration.basicFields != null) {
            
            // Create properties for each field in the basic configuration
            var basicFields:Array<Dynamic> = cast provisionerDefinition.metadata.configuration.basicFields;
            for (field in basicFields) {
                _initializeServerProperty(field);
            }
        }
        
        // Then load any saved values from dynamicCustomProperties
        if (_server.customProperties != null && Reflect.hasField(_server.customProperties, "dynamicCustomProperties")) {
            var customPropsObj = Reflect.field(_server.customProperties, "dynamicCustomProperties");
            if (customPropsObj != null) {
                Logger.info('${this}: Loading custom properties from server customProperties');
                
                // Get fields as an array we can iterate over
                var fieldNames = Reflect.fields(customPropsObj);
                Logger.info('${this}: Found ${fieldNames.length} custom properties to load');
                
                for (field in fieldNames) {
                    var value = Reflect.field(customPropsObj, field);
                    Logger.info('${this}: Found custom property in customProperties: ${field} = ${value}');
                    
                    // Update existing property or create new one
                    var prop = _customProperties.exists(field) ? _customProperties.get(field) : null;
                    
                    if (prop == null) {
                        prop = new champaign.core.primitives.Property<String>(Std.string(value));
                        _customProperties.set(field, prop);
                        
                        // Add property change listener
                        var onChange = Reflect.field(prop, "onChange");
                        if (onChange != null && Reflect.hasField(onChange, "add")) {
                            var self = this;
                            Reflect.callMethod(onChange, Reflect.field(onChange, "add"), [function(p) { self._propertyChangedHandler(p); }]);
                        }
                    } else if (Reflect.hasField(prop, "value")) {
                        Reflect.setField(prop, "value", Std.string(value));
                    }
                }
            }
        }
        
        // Also check root customProperties for any values
        if (_server.customProperties != null) {
            for (field in _customProperties.keys()) {
                if (Reflect.hasField(_server.customProperties, field)) {
                    var value = Reflect.field(_server.customProperties, field);
                    var prop = _customProperties.get(field);
                    if (prop != null && Reflect.hasField(prop, "value")) {
                        Reflect.setField(prop, "value", Std.string(value));
                    }
                }
            }
        }
        
        // Update provisioner dropdown and definition first
        if (_formInitialized && _form != null) {
            _updateProvisionerDropdown();
        }
        
        // Then update the UI to show the values
        if (_formInitialized && _form != null) {
            updateContent(true);
        } else {
            _pendingUpdateContent = true;
        }
    }

    private function _updateProvisionerDropdown() {
        if (_dropdownCoreComponentVersion == null) {
            return;
        }
        
        if (_server == null) {
            return;
        }
        
        // Check if we already have a provisioner definition from the service type data
        var serviceTypeProvisioner = null;
        if (_server.customProperties != null) {
            var customProperties = _server.customProperties;
            if (Reflect.hasField(customProperties, "serviceTypeData")) {
                var serviceTypeData = Reflect.field(customProperties, "serviceTypeData");
                if (serviceTypeData != null && Reflect.hasField(serviceTypeData, "provisioner")) {
                    serviceTypeProvisioner = Reflect.field(serviceTypeData, "provisioner");
                }
            }
        }
        
        // Get the actual provisioner type from the server
        var provisionerType = _server.provisioner.type;
        
        // Get provisioners of the same type from the cache
        var allProvisioners = ProvisionerManager.getBundledProvisioners(provisionerType);
        
        // Create a collection for the dropdown
        var provisionerCollection = new feathers.data.ArrayCollection<ProvisionerDefinition>();
        
        // Add each provisioner to the collection
        for (i in 0...allProvisioners.length) {
            var p = allProvisioners[i];
            provisionerCollection.add(p);
        }
        
        // If no provisioners found, try getting all provisioners
        if (provisionerCollection.length == 0) {
            Logger.warning('${this}: No provisioners found for type ${provisionerType}, getting all provisioners');
            allProvisioners = ProvisionerManager.getBundledProvisioners();
            
            // Filter to only include provisioners of the correct type
            for (p in allProvisioners) {
                if (p.data.type == provisionerType) {
                    provisionerCollection.add(p);
                }
            }
        }
        
        // Set the dropdown data provider
        _dropdownCoreComponentVersion.dataProvider = provisionerCollection;
        
        // Try to find the right provisioner to select in this priority order:
        // 1. First check serverProvisionerId (single source of truth)
        // 2. Then check service type data
        // 3. Then check server.provisioner.version
        var selectedIndex = -1;
        
        // PRIORITY 1: Check serverProvisionerId first as the authoritative source
        if (_server.serverProvisionerId != null && 
            _server.serverProvisionerId.value != null && 
            _server.serverProvisionerId.value != "" &&
            _server.serverProvisionerId.value != "0.0.0") {
            
            var serverProvisionerIdStr = _server.serverProvisionerId.value;
            var serverProvisionerId = champaign.core.primitives.VersionInfo.fromString(serverProvisionerIdStr);
            
            Logger.info('${this}: Looking for provisioner matching serverProvisionerId: ${serverProvisionerIdStr}');
            
            for (i in 0...provisionerCollection.length) {
                var d:ProvisionerDefinition = provisionerCollection.get(i);
                if (d.data.version == serverProvisionerId) {
                    selectedIndex = i;
                    Logger.info('${this}: Found provisioner matching serverProvisionerId: ${d.name}');
                    break;
                }
            }
        }
        
        // PRIORITY 2: If no match by serverProvisionerId, try service type data
        if (selectedIndex < 0 && serviceTypeProvisioner != null) {
            Logger.info('${this}: Looking for provisioner matching service type data');
            
            for (i in 0...provisionerCollection.length) {
                var d:ProvisionerDefinition = provisionerCollection.get(i);
                if (d.name == serviceTypeProvisioner.name && d.data.version == serviceTypeProvisioner.data.version) {
                    selectedIndex = i;
                    Logger.info('${this}: Found provisioner matching service type data: ${d.name}');
                    break;
                }
            }
        }
        
        // PRIORITY 3: If still no match, try by server's provisioner version
        if (selectedIndex < 0) {
            Logger.info('${this}: Looking for provisioner matching server provisioner version: ${_server.provisioner.version}');
            
            for (i in 0...provisionerCollection.length) {
                var d:ProvisionerDefinition = provisionerCollection.get(i);
                if (d.data.version == _server.provisioner.version) {
                    selectedIndex = i;
                    Logger.info('${this}: Found provisioner matching server version: ${d.name}');
                    break;
                }
            }
        }
        
        // Set the selected index based on what we found
        if (selectedIndex >= 0) {
            _dropdownCoreComponentVersion.selectedIndex = selectedIndex;
        } else if (provisionerCollection.length > 0) {
            // Default to first (newest) provisioner if no match found
            _dropdownCoreComponentVersion.selectedIndex = 0;
            Logger.info('${this}: No matching provisioner found, defaulting to newest: ${provisionerCollection.get(0).name}');
        } else {
            Logger.warning('${this}: No provisioners in collection, cannot set selected index');
        }
        
        // Get the provisioner definition for the selected version
        var provisionerDefinition = null;
        if (selectedIndex >= 0) {
            provisionerDefinition = provisionerCollection.get(selectedIndex);
        } else if (provisionerCollection.length > 0) {
            provisionerDefinition = provisionerCollection.get(0);
        } else {
            Logger.warning('${this}: No provisioner definition available');
        }
        
        // Set the provisioner definition to generate the form fields
        if (provisionerDefinition != null) {
            setProvisionerDefinition(provisionerDefinition);
        } else {
            Logger.warning('${this}: Cannot set provisioner definition, it is null');
        }
    }
    
    /**
     * Set the provisioner definition for this configuration page
     * @param definition The provisioner definition
     */
    public function setProvisionerDefinition(definition:ProvisionerDefinition) {
        // If the form is not initialized yet, store the definition for later
        if (!_formInitialized || _form == null) {
            _pendingProvisionerDefinition = definition;
            return;
        }
        
        _provisionerDefinition = definition;
        
        // Initialize server properties for all fields in the provisioner definition
        if (_server != null && definition.metadata != null && 
            definition.metadata.configuration != null && 
            definition.metadata.configuration.basicFields != null) {
            
            // Create properties for each field in the basic configuration
            var basicFields:Array<Dynamic> = cast definition.metadata.configuration.basicFields;
            for (field in basicFields) {
                _initializeServerProperty(field);
            }
        }
        
        if (definition.metadata != null) {
            if (definition.metadata.configuration != null) {
                var basicFieldCount = definition.metadata.configuration.basicFields != null ? 
                    definition.metadata.configuration.basicFields.length : 0;
                var advancedFieldCount = definition.metadata.configuration.advancedFields != null ? 
                    definition.metadata.configuration.advancedFields.length : 0;
                
                Logger.info('${this}: Provisioner has ${basicFieldCount} basic fields and ${advancedFieldCount} advanced fields');
            } else {
                Logger.warning('No configuration found in provisioner metadata');
            }
        } else {
            Logger.warning('No metadata found in provisioner definition');
        }
        
        // Remove existing dynamic form rows from the form
        for (fieldName => row in _dynamicRows) {
            if (row != null && row.parent == _form) {
                Logger.info('${this}: Removing existing form row for field ${fieldName}');
                _form.removeChild(row);
            }
        }
        
        // Clear existing dynamic fields maps
        _dynamicFields = new Map();
        _dynamicRows = new Map();
        
        // Create dynamic fields based on the provisioner configuration
        if (_provisionerDefinition != null && _provisionerDefinition.metadata != null && 
            _provisionerDefinition.metadata.configuration != null && 
            _provisionerDefinition.metadata.configuration.basicFields != null) {
            
            // Add each field from the configuration
            var basicFields:Array<Dynamic> = cast _provisionerDefinition.metadata.configuration.basicFields;
            Logger.info('${this}: Adding ${basicFields.length} dynamic fields to form');
            
            for (field in basicFields) {
                _addDynamicField(field);
            }
        } else {
            Logger.warning('Unable to add dynamic fields - missing configuration or basicFields');
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
                    
                    // Initialize in server's customProperties if needed
                    if (_server.customProperties == null) {
                        _server.customProperties = {};
                    }
                    
                    // Save in original case
                    Reflect.setField(_server.customProperties, fieldName, defaultValue);
                    
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
                
                var stepper = new GenesisFormNumericStepper(defaultValue, minValue, maxValue);
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

    override function updateContent(forced:Bool = false) {
        super.updateContent();

        // If the form is not initialized yet, store the update request for later
        if (!_formInitialized || _form == null || _server == null) {
            _pendingUpdateContent = true;
            return;
        }
        
        Logger.info('${this}: Updating content (forced=${forced})');
        
        if (_form != null && _server != null) {
            _label.text = LanguageManager.getInstance().getString('serverconfigpage.title', Std.string(_server.id));
            
            // Update Roles button
            _buttonRoles.icon = (_server.areRolesValid()) ? GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_OK) : GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_WARNING);
            _buttonRoles.enabled = !_server.roles.locked;
            
            // Update Save button
            _buttonSave.enabled = !_server.hostname.locked;
            
            // Update provisioner dropdown - this is now handled by _updateProvisionerDropdown
//            if (forced || _dropdownCoreComponentVersion.dataProvider.length == 0) {
//                // Use a small delay to ensure the UI is ready
//                haxe.Timer.delay(function() {
//                    _updateProvisionerDropdown();
//                }, 100);
//            } else {
                // Just update the selected index if needed
                if (_dropdownCoreComponentVersion.selectedIndex == -1) {
                    for (i in 0..._dropdownCoreComponentVersion.dataProvider.length) {
                        var d:ProvisionerDefinition = _dropdownCoreComponentVersion.dataProvider.get(i);
                        if (d.data.version == _server.provisioner.version) {
                            _dropdownCoreComponentVersion.selectedIndex = i;
                            break;
                        }
                    }
                }
//            }
            _dropdownCoreComponentVersion.enabled = !_server.hostname.locked;
            
            // Look for dynamic custom properties in server.customProperties if they exist
            var customPropValues = new Map<String, Dynamic>();
            if (_server.customProperties != null && Reflect.hasField(_server.customProperties, "dynamicCustomProperties")) {
                var customPropsObj = Reflect.field(_server.customProperties, "dynamicCustomProperties");
                if (customPropsObj != null) {
                    var fields = Reflect.fields(customPropsObj);
                    Logger.info('${this}: Found ${fields.length} fields in dynamicCustomProperties');
                    
                    for (field in fields) {
                        var value = Reflect.field(customPropsObj, field);
                        customPropValues.set(field, value);
                        Logger.info('${this}: Found field in customProperties: ${field} = ${value}');
                    }
                }
            }
            
                // Update dynamic fields with server or custom property values
                for (fieldName => field in _dynamicFields) {
                    var value = null;
                    var valueField = null;
                    var valueSource = "none";
                    
                    Logger.info('${this}: Processing field ${fieldName}');
                    
                    // Special handling for standard fields like hostname
                    if (fieldName == "hostname") {
                        // Get hostname directly from server.hostname.value
                        valueField = _server.hostname.value;
                        valueSource = "standardServerProperty";
                    }
    // First check if it's in customProperties directly
    else if (Reflect.hasField(_server.customProperties, fieldName)) {
        valueField = Reflect.field(_server.customProperties, fieldName);
        Logger.info('${this}: Using value from direct customProperties for ${fieldName}: ${valueField}, type: ${Type.typeof(valueField)}');
        
        // If the value is empty, try other sources
        if (valueField == null || valueField == "") {
            Logger.info('${this}: Value from direct customProperties is empty, trying other sources');
            
            // Try customPropValues (from dynamicCustomProperties)
            if (customPropValues.exists(fieldName)) {
                valueField = customPropValues.get(fieldName);
                valueSource = "customProperties";
                Logger.info('${this}: Using value from customPropValues for ${fieldName}: ${valueField}');
            }
            // Try _customProperties
            else if (_customProperties.exists(fieldName)) {
                value = _customProperties.get(fieldName);
                if (value != null && Reflect.hasField(value, "value")) {
                    valueField = Reflect.field(value, "value");
                }
                Logger.info('${this}: Using value from _customProperties for ${fieldName}: ${valueField}');
                valueSource = "customPropertiesMap";
            }
        } else {
            valueSource = "directCustomProperty";
        }
    }
                    // Then check if it's in the customPropValues map (from dynamicCustomProperties)
                    else if (customPropValues.exists(fieldName)) {
                        valueField = customPropValues.get(fieldName);
                        valueSource = "customProperties";
                    }
                    // Then check if it's a custom property in our local map
                    else if (_customProperties.exists(fieldName)) {
                        value = _customProperties.get(fieldName);
                        if (value != null && Reflect.hasField(value, "value")) {
                            valueField = Reflect.field(value, "value");
                        }
                        Logger.info('${this}: Using value from _customProperties for ${fieldName}: ${valueField}');
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
                            Logger.info('${this}: Using value from server property for ${fieldName}: ${valueField}');
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
                                Logger.info('${this}: Using value from server property with underscore for ${fieldName}: ${valueField}');
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
                        Logger.info('${this}: Found direct property in customProperties: ${fieldName} = ${valueField}');
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
                        Logger.info('${this}: Set text input ${fieldName} to "${displayValue}" (source: ${valueSource})');
                        
                    } else if (Std.isOfType(field, GenesisFormNumericStepper)) {
                        var stepper:GenesisFormNumericStepper = cast field;
                        var numValue:Float = 0;
                        
                        if (valueField != null) {
                            numValue = Std.parseFloat(Std.string(valueField));
                        } else if (value != null) {
                            numValue = Std.parseFloat(Std.string(value));
                        }
                        
                        stepper.value = numValue;
                        Logger.info('${this}: Set numeric stepper ${fieldName} to ${numValue} (source: ${valueSource})');
                        
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
                            boolValue = Std.string(value).toLowerCase() == "true";
                        }
                        
                        checkbox.selected = boolValue;
                        Logger.info('${this}: Set checkbox ${fieldName} to ${boolValue} (source: ${valueSource})');
                        
                    } else if (Std.isOfType(field, GenesisFormPupUpListView)) {
                        var dropdown:GenesisFormPupUpListView = cast field;
                        if (dropdown.dataProvider != null && dropdown.dataProvider.length > 0) {
                            var selectedValue = valueField != null ? valueField : value;
                            var foundMatch = false;
                            
                            Logger.info('${this}: Looking for dropdown match for ${fieldName} with value ${selectedValue}');
                            
                            for (i in 0...dropdown.dataProvider.length) {
                                var option = dropdown.dataProvider.get(i);
                                if (option != null && option.length > 0) {
                                    Logger.info('${this}: Checking dropdown option ${i}: ${option[0]} == ${selectedValue}');
                                    
                                    if (option[0] == selectedValue) {
                                        dropdown.selectedIndex = i;
                                        foundMatch = true;
                                        Logger.info('${this}: Set dropdown ${fieldName} to index ${i} (${option[1]}) (source: ${valueSource})');
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

    function _advancedLinkTriggered(e:MouseEvent) {
        var evt = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.ADVANCED_CONFIGURE_SERVER);
        evt.server = _server;
        
        // Explicitly set the provisioner type to ensure it's handled as a custom provisioner
        // This is important because the _advancedConfigureServer method checks server.provisioner.type
        // to determine whether to use DynamicAdvancedConfigPage or AdvancedConfigPage
        evt.provisionerType = _server.provisioner.type;
        
        // Store the provisioner definition in the event if available
        if (_provisionerDefinition != null) {
            evt.data = _provisionerDefinition.name;
        }
        
        this.dispatchEvent(evt);
    }

    function _buttonRolesTriggered(e:TriggerEvent) {
        var evt = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.CONFIGURE_ROLES);
        evt.server = this._server;
        
        // Pass the provisioner type and the current provisioner definition
        evt.provisionerType = _server.provisioner.type;
        
        // Include the provisioner definition in the event data
        if (_provisionerDefinition != null) {
            // Pass the provisioner definition name directly
            evt.data = _provisionerDefinition.name;
            
            // Also include the definition in the server's customProperties for later retrieval
            if (_server.customProperties == null) {
                _server.customProperties = {};
            }
            Reflect.setField(_server.customProperties, "currentProvisionerDefinitionName", _provisionerDefinition.name);
            
            // Store the definition name in RolePage.lastDefinitionName if it exists
            try {
                // Get a reference to the RolePage instance - we need to check if it exists first
                var rolesPage = SuperHumanInstaller.getInstance().getRolesPage();
                if (rolesPage != null) {
                    Logger.info('${this}: Setting lastDefinitionName on RolePage: ${_provisionerDefinition.name}');
                    Reflect.setField(rolesPage, "_lastDefinitionName", _provisionerDefinition.name);
                }
            } catch (e) {
                Logger.warning('${this}: Could not set lastDefinitionName on RolePage: ${e}');
            }
            
            Logger.info('${this}: Passing provisioner definition to roles page: ${_provisionerDefinition.name}');
        } else {
            Logger.warning('${this}: No provisioner definition available to pass to roles page');
            evt.data = null;
        }
        
        this.dispatchEvent(evt);
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
    
    /**
     * Update the roles button icon when the version dropdown selection changes
     * @param e The change event
     */
    function _versionDropdownChanged(e:Event) {
        // Only update if we have a valid server
        if (_server != null) {
            // Update the button icon based on the current validation state
            _buttonRoles.icon = (_server.areRolesValid()) ? 
                GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_OK) : 
                GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_WARNING);
        }
    }
    
    function _saveButtonTriggered(e:TriggerEvent) {
        _buttonRoles.setValidity(_server.areRolesValid());

        // Making sure the event is fired
        var a = _server.roles.value.copy();
        _server.roles.value = a;
        _server.syncMethod = SuperHumanInstaller.getInstance().config.preferences.syncmethod;
        
        // Update server properties from dynamic fields
        for (fieldName => field in _dynamicFields) {
            var value:String = null;
            
            if (Std.isOfType(field, GenesisFormTextInput)) {
                var input:GenesisFormTextInput = cast field;
                value = StringTools.trim(input.text);
                Logger.info('${this}: Getting value from text input ${fieldName}: ${value}');
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
                // Handle special cases for standard server properties
                // Important: Map known custom provisioner fields to server standard fields
                if (fieldName == "hostname") {
                    // Set the server hostname via Property object
                    _server.hostname.value = value;
                } else if (fieldName == "organization") {
                    // Set the server organization via Property object
                    _server.organization.value = value;
                } else if (fieldName == "userEmail") {
                    // Set user email via Property object
                    _server.userEmail.value = value;
                } else if (fieldName == "openBrowser") {
                    // Set open browser flag via Property object
                    var boolValue = value.toLowerCase() == "true";
                    _server.openBrowser.value = boolValue;
                } else if (fieldName == "numCPUs") {
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
                } else if (_customProperties.exists(fieldName)) {
                    // Update custom property
                    var prop = _customProperties.get(fieldName);
                    if (prop != null && Reflect.hasField(prop, "value")) {
                        // Update the Property object
                        Reflect.setField(prop, "value", value);
                        
                        // Initialize customProperties if needed
                        if (_server.customProperties == null) {
                            _server.customProperties = {};
                        }
                        
                        // Initialize dynamicCustomProperties if needed
                        if (!Reflect.hasField(_server.customProperties, "dynamicCustomProperties")) {
                            Reflect.setField(_server.customProperties, "dynamicCustomProperties", {});
                        }
                        
                        // Get reference to dynamicCustomProperties
                        var customPropsObj = Reflect.field(_server.customProperties, "dynamicCustomProperties");
                        
                        // Save in both locations to ensure compatibility
                        Reflect.setField(customPropsObj, fieldName, value);
                        Reflect.setField(_server.customProperties, fieldName, value);
                        
                        // Log the save operation
                        Logger.info('${this}: Saved custom property ${fieldName} with value ${value} in both locations');
                        
                        // Force an immediate save to persist changes
                        _server.saveData();
                        
                        // Double check the save
                        var savedValue = Reflect.field(customPropsObj, fieldName);
                        Logger.info('${this}: Verified saved value for ${fieldName}: ${savedValue}');
                    }
                } else {
                    // Store the value directly in customProperties to preserve exact case
                    if (_server.customProperties == null) {
                        _server.customProperties = {};
                    }
                    Reflect.setField(_server.customProperties, fieldName, value);
                    Logger.info('${this}: Stored custom property ${fieldName} with exact case: ${value}');
                }
            }
        }
        
        // Store custom properties in server's customProperties if available
        if (_server != null && _customProperties.keys().hasNext()) {
            // Make sure customProperties is initialized
            if (_server.customProperties == null) {
                _server.customProperties = {};
            }
            
            // Initialize or update dynamicCustomProperties
            if (!Reflect.hasField(_server.customProperties, "dynamicCustomProperties")) {
                Reflect.setField(_server.customProperties, "dynamicCustomProperties", {});
            }
            
            // Get reference to dynamicCustomProperties
            var customPropsObj = Reflect.field(_server.customProperties, "dynamicCustomProperties");
            
            // Save all custom properties - only save to dynamicCustomProperties
            // to avoid duplication in the server's customProperties
            for (fieldName => field in _dynamicFields) {
                var value:String = null;
                
                if (Std.isOfType(field, GenesisFormTextInput)) {
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
                    // Only save to dynamicCustomProperties to avoid duplication
                    Reflect.setField(customPropsObj, fieldName, value);
                    Logger.info('${this}: Saved field ${fieldName} with value ${value} in dynamicCustomProperties');
                }
            }
            
            // Force an immediate save of server data to avoid race conditions
            _server.saveData();
            
            // Force an update of the UI to show the new values
            updateContent(true);
        }
        
    // Update the provisioner with the selected version
    var dvv:ProvisionerDefinition = cast _dropdownCoreComponentVersion.selectedItem;
    if (dvv != null) {
        var versionStr = dvv.data.version.toString();
        Logger.info('${this}: Updating provisioner to version ${versionStr}');
        
        // Create a copy of the provisioner data for update
        var updatedData = {
            type: dvv.data.type,
            version: dvv.data.version
        };
        
        // Set the serverProvisionerId as the single source of truth for version
        if (_server.serverProvisionerId != null) {
            _server.serverProvisionerId.value = versionStr;
            Logger.info('${this}: Updated serverProvisionerId to ${versionStr}');
        }
        
        // For backwards compatibility, store minimal version info in customProperties
        if (_server.customProperties == null) {
            _server.customProperties = {};
        }
        
        // Store the basic provisioner definition reference
        Reflect.setField(_server.customProperties, "provisionerDefinition", dvv);
        
        // Update the server's provisioner with the server.updateProvisioner method
        var success = _server.updateProvisioner(updatedData);
        if (success) {
            Logger.info('${this}: Successfully updated provisioner to version ${versionStr}');
            // Update the roles button icon after changing provisioner
            _buttonRoles.icon = (_server.areRolesValid()) ? 
                GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_OK) : 
                GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_WARNING);
        } else {
            Logger.warning('${this}: Failed to update provisioner to version ${versionStr}');
        }
        
        // Force an immediate save of the server data
        _server.saveData();
        
        Logger.info('${this}: Provisioner version updated and saved');
    } else {
        Logger.warning('${this}: No provisioner selected in dropdown, cannot update version');
    }

        // Save the server data one final time to ensure everything is persisted
        _server.saveData();
        
        // Force an update of the UI to show the saved values
        updateContent(true);
        
        // Update the last used safe ID
        SuperHumanInstaller.getInstance().config.user.lastusedsafeid = _server.userSafeId.value;
        
        // Small delay to ensure all saves are complete before navigating away
        haxe.Timer.delay(function() {
            var evt = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.SAVE_SERVER_CONFIGURATION);
            evt.server = _server;
            this.dispatchEvent(evt);
        }, 100);
    }
}
