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
import openfl.events.Event;
import prominic.sys.applications.oracle.BridgedInterface;
import prominic.sys.applications.oracle.VirtualBox;
import superhuman.events.SuperHumanApplicationEvent;
import superhuman.managers.ProvisionerManager;
import superhuman.managers.ProvisionerManager.ProvisionerField;
import superhuman.server.Server;
import superhuman.server.definitions.ProvisionerDefinition;

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

        _form = new GenesisForm();
        this.addChild(_form);

        // Initialize network interface dropdown but don't add to form yet
        // We'll only add it if the provisioner.yml has a corresponding field
        _rowNetworkInterface = new GenesisFormRow();
        _rowNetworkInterface.text = LanguageManager.getInstance().getString('serveradvancedconfigpage.form.networkinterface.text');
        _dropdownNetworkInterface = new GenesisFormPupUpListView(VirtualBox.getInstance().bridgedInterfacesCollection);
        _dropdownNetworkInterface.itemToText = (item:BridgedInterface) -> {
            if (item.name == "") return LanguageManager.getInstance().getString('serveradvancedconfigpage.form.networkinterface.default');
            return item.name;
        };
        // Don't set selectedIndex here, wait until we have data
        _dropdownNetworkInterface.prompt = LanguageManager.getInstance().getString('serveradvancedconfigpage.form.networkinterface.prompt');
        _rowNetworkInterface.content.addChild(_dropdownNetworkInterface);
        // We'll add this to the form only if needed based on provisioner

        var line = new HLine();
        line.width = _w;
        this.addChild(line);

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
            Logger.info('${this}: Applying pending provisioner definition after initialization');
            setProvisionerDefinition(_pendingProvisionerDefinition);
            _pendingProvisionerDefinition = null;
        }
        
        // If we have a pending updateContent call, process it now
        if (_pendingUpdateContent) {
            Logger.info('${this}: Processing pending updateContent call');
            _pendingUpdateContent = false;
            updateContent(true);
        }
    }
    
    /**
     * Handler for when the component is added to the stage
     * This ensures all UI components are fully initialized
     */
    private function _onAddedToStage(e:openfl.events.Event):Void {
        Logger.info('${this}: Added to stage, ensuring UI is ready');
        
        // Remove the listener as we only need it once
        this.removeEventListener(openfl.events.Event.ADDED_TO_STAGE, _onAddedToStage);
        
        // Process immediately when added to stage
        // If we have a pending provisioner definition, apply it now
        if (_pendingProvisionerDefinition != null) {
            Logger.info('${this}: Applying pending provisioner definition after added to stage');
            setProvisionerDefinition(_pendingProvisionerDefinition);
            _pendingProvisionerDefinition = null;
        }
        
        // If we have a pending updateContent call, process it now
        if (_pendingUpdateContent) {
            Logger.info('${this}: Processing pending updateContent call after added to stage');
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
                if (d != null && d.name == _server.networkBridge.value) {
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
        Logger.info('${this}: Set server for advanced config page, server ID: ${_server.id}');
        
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
            Logger.info('${this}: Component not initialized yet, storing provisioner definition for later');
            return;
        }
        
        _provisionerDefinition = definition;
        
        // Log the provisioner definition to help with debugging
        Logger.info('${this}: Setting provisioner definition for advanced config: ${definition.name}, type: ${definition.data.type}, version: ${definition.data.version}');
        
        // Initialize server properties for all fields in the provisioner definition
        if (_server != null && definition.metadata != null && 
            definition.metadata.configuration != null && 
            definition.metadata.configuration.advancedFields != null) {
            
            Logger.info('${this}: Initializing server properties for advanced fields');
            
            // Create properties for each field in the advanced configuration
            for (field in definition.metadata.configuration.advancedFields) {
                _initializeServerProperty(field);
            }
        }
        
        if (definition.metadata != null) {
            Logger.info('Provisioner metadata: name=${definition.metadata.name}, type=${definition.metadata.type}');
            
            if (definition.metadata.configuration != null) {
                var basicFieldCount = definition.metadata.configuration.basicFields != null ? 
                    definition.metadata.configuration.basicFields.length : 0;
                var advancedFieldCount = definition.metadata.configuration.advancedFields != null ? 
                    definition.metadata.configuration.advancedFields.length : 0;
                
                Logger.info('Configuration fields: basic=${basicFieldCount}, advanced=${advancedFieldCount}');
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
                    Logger.info('${this}: Found network interface field in provisioner: ${field.name}');
                    break;
                }
            }
        }
        
        // Add the network interface field if needed
        if (needsNetworkInterface && _form != null && _rowNetworkInterface != null) {
            _form.addChild(_rowNetworkInterface);
            Logger.info('${this}: Added network interface dropdown to form');
        } else {
            Logger.info('${this}: Network interface field not needed for this provisioner');
        }
        
        // Create dynamic fields based on the provisioner configuration
        if (_provisionerDefinition != null && _provisionerDefinition.metadata != null && 
            _provisionerDefinition.metadata.configuration != null && 
            _provisionerDefinition.metadata.configuration.advancedFields != null) {
            
            // Add each field from the configuration
            for (field in _provisionerDefinition.metadata.configuration.advancedFields) {
                // Skip networkBridge/networkInterface since we handle it separately
                if (field.name == "networkBridge" || field.name == "networkInterface") {
                    continue;
                }
                
                Logger.info('Adding advanced field to form: ${field.name}, type: ${field.type}, label: ${field.label}');
                _addDynamicField(field);
            }
        } else {
            Logger.warning('Unable to add dynamic advanced fields - missing configuration or advancedFields');
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
        Logger.info('${this}: Initializing server property: ${fieldName}, type: ${field.type}');
        
        // Check if the property already exists on the server - checking multiple ways
        var directExists = Reflect.hasField(_server, fieldName);
        var underscoreExists = Reflect.hasField(_server, "_" + fieldName);
        var getterExists = Reflect.hasField(_server, "get_" + fieldName);
        var propertyExists = directExists || underscoreExists || getterExists;
        
        if (!propertyExists) {
            Logger.info('${this}: Creating custom property: ${fieldName}');
            
            // Create the property based on the field type
            switch (field.type) {
                case "text":
                    // Create a string property
                    var defaultValue = field.defaultValue != null ? Std.string(field.defaultValue) : "";
                    var prop = new champaign.core.primitives.Property<String>(defaultValue);
                    _customProperties.set(fieldName, prop);
                    Logger.info('${this}: Created custom property ${fieldName} in local storage');
                    
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
                    Logger.info('${this}: Created custom property ${fieldName} in local storage');
                    
                case "checkbox":
                    // Create a boolean property
                    var defaultValue = "false";
                    if (field.defaultValue != null) {
                        defaultValue = Std.string(field.defaultValue).toLowerCase() == "true" ? "true" : "false";
                    }
                    var prop = new champaign.core.primitives.Property<String>(defaultValue);
                    _customProperties.set(fieldName, prop);
                    Logger.info('${this}: Created custom property ${fieldName} in local storage');
                    
                case "dropdown":
                    // Create a string property for dropdown
                    var defaultValue = field.defaultValue != null ? Std.string(field.defaultValue) : "";
                    var prop = new champaign.core.primitives.Property<String>(defaultValue);
                    _customProperties.set(fieldName, prop);
                    Logger.info('${this}: Created custom property ${fieldName} in local storage');
                    
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
            Logger.info('${this}: Property already exists on server: ${fieldName}');
            
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
                    var isIntegerField = (field.name == "numCPUs" || field.name == "setupWait");
                    
                    // Force default value to be an integer for integer fields
                    if (isIntegerField && !Math.isNaN(defaultValue)) {
                        defaultValue = Math.round(defaultValue);
                    }
                    
                    var stepper = new GenesisFormNumericStepper(defaultValue, minValue, maxValue);
                    
                    // For integer fields like numCPUs and setupWait, set the step to 1.0 
                    // This makes the stepper increment in whole numbers only
                    if (isIntegerField) {
                        // Set step property directly on the NumericStepper instance
                        stepper.step = 1.0;
                        Logger.info('${this}: Set step size to 1.0 for integer field ${field.name}');
                    }
                    
                    stepper.toolTip = field.tooltip != null ? field.tooltip : "";
                
                    // Add the stepper to the row
                    row.content.addChild(stepper);
                
                    // Store the stepper in the dynamic fields map
                    _dynamicFields.set(field.name, stepper);
                    
                    // Log the created field
                    Logger.info('${this}: Created numeric field ${field.name} with default=${defaultValue}, min=${minValue}, max=${maxValue}, isInteger=${isIntegerField}');
                
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
            Logger.info('${this}: Form not initialized yet, storing updateContent request for later');
            _pendingUpdateContent = true;
            return;
        }
        
        Logger.info('${this}: Updating content (forced=${forced})');
        
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
                Logger.info('${this}: Loading custom properties from server customProperties');
                
                // Check for dynamicAdvancedCustomProperties
                if (Reflect.hasField(_server.customProperties, "dynamicAdvancedCustomProperties")) {
                    var customPropsObj = Reflect.field(_server.customProperties, "dynamicAdvancedCustomProperties");
                    if (customPropsObj != null) {
                        var fields = Reflect.fields(customPropsObj);
                        Logger.info('${this}: Found ${fields.length} custom properties to load from dynamicAdvancedCustomProperties');
                        
                        for (field in fields) {
                            var value = Reflect.field(customPropsObj, field);
                            Logger.info('${this}: Found custom property in customProperties: ${field} = ${value}');
                            
                            // Create a property based on the value type if it doesn't already exist
                            if (!_customProperties.exists(field)) {
                                var prop = null;
                                
                                if (Std.isOfType(value, String)) {
                                    prop = new champaign.core.primitives.Property<String>(value);
                                    Logger.info('${this}: Created String property for ${field} with value ${value}');
                                } else if (Std.isOfType(value, Float) || Std.isOfType(value, Int)) {
                                    prop = new champaign.core.primitives.Property<String>(Std.string(value));
                                    Logger.info('${this}: Created numeric property for ${field} with value ${value}');
                                } else if (Std.isOfType(value, Bool)) {
                                    // Convert Boolean to String for consistency
                                    var boolValue:Bool = cast value;
                                    var boolStr = boolValue ? "true" : "false";
                                    prop = new champaign.core.primitives.Property<String>(boolStr);
                                    Logger.info('${this}: Created Boolean property for ${field} with value ${boolValue} (${boolStr})');
                                } else {
                                    // Handle other types by converting to string
                                    prop = new champaign.core.primitives.Property<String>(Std.string(value));
                                    Logger.info('${this}: Created String property for unknown type ${field} with value ${value}');
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
            
            // Log information about available dynamic fields
            Logger.info('${this}: Updating ${Lambda.count(_dynamicFields)} dynamic fields with server or custom property values');
            
            // Look for dynamic custom properties in server.customProperties if they exist
            var customPropValues = new Map<String, Dynamic>();
            if (_server.customProperties != null) {
                Logger.info('${this}: Server has customProperties object');
                
                // Check for dynamicAdvancedCustomProperties
                if (Reflect.hasField(_server.customProperties, "dynamicAdvancedCustomProperties")) {
                    var customPropsObj = Reflect.field(_server.customProperties, "dynamicAdvancedCustomProperties");
                    if (customPropsObj != null) {
                        var fields = Reflect.fields(customPropsObj);
                        Logger.info('${this}: Found ${fields.length} fields in dynamicAdvancedCustomProperties');
                        
                        for (field in fields) {
                            var value = Reflect.field(customPropsObj, field);
                            customPropValues.set(field, value);
                            Logger.info('${this}: Found custom property in dynamicAdvancedCustomProperties: ${field} = ${value}');
                        }
                    } else {
                        Logger.warning('${this}: dynamicAdvancedCustomProperties object is null');
                    }
                } else {
                    Logger.info('${this}: No dynamicAdvancedCustomProperties found in server.customProperties');
                    
                    // As a fallback, check if there are any properties in dynamicCustomProperties that match our field names
                    if (Reflect.hasField(_server.customProperties, "dynamicCustomProperties")) {
                        var basicPropsObj = Reflect.field(_server.customProperties, "dynamicCustomProperties");
                        if (basicPropsObj != null) {
                            var fields = Reflect.fields(basicPropsObj);
                            Logger.info('${this}: Checking ${fields.length} fields in dynamicCustomProperties as fallback');
                            
                            // Only check for fields that we have in our dynamic fields
                            for (fieldName in _dynamicFields.keys()) {
                                if (Reflect.hasField(basicPropsObj, fieldName)) {
                                    var value = Reflect.field(basicPropsObj, fieldName);
                                    customPropValues.set(fieldName, value);
                                    Logger.info('${this}: Found matching field in dynamicCustomProperties as fallback: ${fieldName} = ${value}');
                                }
                            }
                        }
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
                
                Logger.info('${this}: Processing field ${fieldName}');
                
                // First check if it's in the customPropValues map (direct from customProperties)
                if (customPropValues.exists(fieldName)) {
                    valueField = customPropValues.get(fieldName);
                    Logger.info('${this}: Using value from customProperties for ${fieldName}: ${valueField}');
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
                                            Logger.info('${this}: Found default value for ${fieldName}: ${defaultValue}');
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
                                    Logger.info('${this}: Using default value ${defaultValue} for ${fieldName} since value is NaN');
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
                                    Logger.info('${this}: Using default value ${defaultValue} for ${fieldName} since value is NaN');
                                }
                            } catch (e) {
                                Logger.warning('${this}: Error parsing value for ${fieldName}: ${e}, using default: ${hasDefaultValue ? defaultValue : 0}');
                                numValue = hasDefaultValue ? defaultValue : 0;
                            }
                        } else if (hasDefaultValue) {
                            // No value found, use the default from provisioner definition
                            numValue = defaultValue;
                            Logger.info('${this}: No value found for ${fieldName}, using default: ${defaultValue}');
                        }
                        
                        // Special handling for integer fields to ensure they're whole numbers
                        if (fieldName == "numCPUs" || fieldName == "setupWait") {
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
                            if (Std.isOfType(value, Bool)) {
                                boolValue = cast value;
                            } else if (Std.isOfType(value, String)) {
                                boolValue = Std.string(value).toLowerCase() == "true";
                            } else {
                                boolValue = value != null; // Convert to boolean
                            }
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
        var evt = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.CANCEL_PAGE);
        if (_server != null) {
            evt.server = _server;
            // Also set the provisioner type to ensure proper page navigation
            evt.provisionerType = _server.provisioner.type;
        }
        this.dispatchEvent(evt);
    }
    
    function _saveButtonTriggered(e:TriggerEvent) {
        Logger.info('${this}: Save button triggered, form valid: ${_form.isValid()}, server: ${_server != null}');
        
        if (!_form.isValid() || _server == null) {
            Logger.warning('${this}: Form validation failed, cannot save');
            return;
        }

        // Update standard fields
        if (_dropdownNetworkInterface.selectedItem != null) {
            _server.networkBridge.value = _dropdownNetworkInterface.selectedItem.name;
        }
        
        // Update server properties from dynamic fields
        for (fieldName => field in _dynamicFields) {
                var value:String = null;
            
            if (Std.isOfType(field, GenesisFormTextInput)) {
                var input:GenesisFormTextInput = cast field;
                value = StringTools.trim(input.text);
                Logger.info('${this}: Saving text field ${fieldName} with value: ${value}');
            } else if (Std.isOfType(field, GenesisFormNumericStepper)) {
                var stepper:GenesisFormNumericStepper = cast field;
                value = Std.string(stepper.value);
                Logger.info('${this}: Saving numeric field ${fieldName} with value: ${value}');
            } else if (Std.isOfType(field, GenesisFormCheckBox)) {
                var checkbox:GenesisFormCheckBox = cast field;
                value = checkbox.selected ? "true" : "false";
                Logger.info('${this}: Saving checkbox field ${fieldName} with value: ${value}');
            } else if (Std.isOfType(field, GenesisFormPupUpListView)) {
                var dropdown:GenesisFormPupUpListView = cast field;
                var selectedItem = dropdown.selectedItem;
                value = selectedItem != null && selectedItem.length > 0 ? Std.string(selectedItem[0]) : null;
                Logger.info('${this}: Saving dropdown field ${fieldName} with value: ${value}');
            }
            
            if (value != null) {
                // Handle special cases for standard server properties by field name
                if (fieldName == "numCPUs") {
                    // Set CPU count via Property object
                    _server.numCPUs.value = Std.parseInt(value);
                    Logger.info('${this}: Set resources CPU to ${value}');
                } else if (fieldName == "memory") {
                    // Set memory via Property object
                    _server.memory.value = Std.parseFloat(value);
                    Logger.info('${this}: Set resources RAM to ${value}');
                } else if (fieldName == "networkAddress") {
                    // Set network address via Property object
                    _server.networkAddress.value = value;
                    Logger.info('${this}: Set network address to ${value}');
                } else if (fieldName == "networkNetmask") {
                    // Set network netmask via Property object
                    _server.networkNetmask.value = value;
                    Logger.info('${this}: Set network netmask to ${value}');
                } else if (fieldName == "networkGateway") {
                    // Set network gateway via Property object
                    _server.networkGateway.value = value;
                    Logger.info('${this}: Set network gateway to ${value}');
                } else if (fieldName == "nameServer1") {
                    // Set DNS server 1 via Property object
                    _server.nameServer1.value = value;
                    Logger.info('${this}: Set DNS server 1 to ${value}');
                } else if (fieldName == "nameServer2") {
                    // Set DNS server 2 via Property object
                    _server.nameServer2.value = value;
                    Logger.info('${this}: Set DNS server 2 to ${value}');
                } else if (fieldName == "networkBridge") {
                    // Set network bridge via Property object
                    _server.networkBridge.value = value;
                    Logger.info('${this}: Set network bridge to ${value}');
                } else if (fieldName == "dhcp4") {
                    // Set DHCP flag via Property object
                    var boolValue = value.toLowerCase() == "true";
                    _server.dhcp4.value = boolValue;
                    Logger.info('${this}: Set DHCP flag to ${value}');
                } else if (fieldName == "disableBridgeAdapter") {
                    // Set disable bridge adapter flag via Property object
                    var boolValue = value.toLowerCase() == "true";
                    _server.disableBridgeAdapter.value = boolValue;
                    Logger.info('${this}: Set disable bridge adapter to ${value}');
                } else if (fieldName == "setupWait") {
                    // Set setup wait time via Property object
                    _server.setupWait.value = Std.parseInt(value);
                    Logger.info('${this}: Set setup wait to ${value}');
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
                } else if (Reflect.hasField(_server, fieldName)) {
                    // Update server property
                    var prop = Reflect.getProperty(_server, fieldName);
                    if (prop != null && Reflect.hasField(prop, "value")) {
                        // It's a property with a value field
                        Reflect.setField(prop, "value", value);
                    } else {
                        // It's a direct property
                        Reflect.setProperty(_server, fieldName, value);
                    }
                } else {
                    // Create a custom property if it doesn't exist in any form
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
                    Logger.info('${this}: Saved field ${fieldName} with value: ${value} to customProperties');
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
            Logger.info('${this}: Saved all custom properties to server data');
        }

        _server.saveHostsFile();
        
        var evt = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.SAVE_ADVANCED_SERVER_CONFIGURATION);
        evt.server = _server;
        this.dispatchEvent(evt);
    }
}
