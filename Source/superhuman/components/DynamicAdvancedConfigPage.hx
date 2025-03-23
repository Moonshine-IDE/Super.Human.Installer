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

        // Network interface dropdown (standard field)
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
        _form.addChild(_rowNetworkInterface);

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
            haxe.Timer.delay(function() {
                updateContent(true);
            }, 100); // Small delay to ensure UI is ready
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
        
        // Delay the initialization slightly to ensure all UI components are ready
        haxe.Timer.delay(function() {
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
        }, 200); // Small delay to ensure UI is ready
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
            
            // Update the enabled state
            _dropdownNetworkInterface.enabled = !_server.networkBridge.locked && !_server.disableBridgeAdapter.value;
        }
        
        Logger.info('${this}: Set server for advanced config page, server ID: ${_server.id}');
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
        
        // Create dynamic fields based on the provisioner configuration
        if (_provisionerDefinition != null && _provisionerDefinition.metadata != null && 
            _provisionerDefinition.metadata.configuration != null && 
            _provisionerDefinition.metadata.configuration.advancedFields != null) {
            
            // Add each field from the configuration
            for (field in _provisionerDefinition.metadata.configuration.advancedFields) {
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
        
        // Check if the property already exists
        var propertyExists = Reflect.hasField(_server, fieldName);
        
        if (!propertyExists) {
            Logger.info('${this}: Creating new property on server: ${fieldName}');
            
            // Create the property based on the field type
            switch (field.type) {
                case "text":
                    // Create a string property
                    var defaultValue = field.defaultValue != null ? Std.string(field.defaultValue) : "";
                    var prop = new champaign.core.primitives.Property<String>(defaultValue);
                    Reflect.setField(_server, fieldName, prop);
                    
                case "number":
                    // Create a numeric property
                    var defaultValue = 0.0;
                    if (field.defaultValue != null) {
                        try {
                            defaultValue = Std.parseFloat(Std.string(field.defaultValue));
                            if (Math.isNaN(defaultValue)) defaultValue = 0.0;
                        } catch (e) {
                            Logger.warning('${this}: Error parsing default value for ${fieldName}: ${e}');
                            defaultValue = 0.0;
                        }
                    }
                    var prop = new champaign.core.primitives.Property<Float>(defaultValue);
                    Reflect.setField(_server, fieldName, prop);
                    
                case "checkbox":
                    // Create a boolean property
                    var defaultValue = false;
                    if (field.defaultValue != null) {
                        defaultValue = Std.string(field.defaultValue).toLowerCase() == "true";
                    }
                    var prop = new champaign.core.primitives.Property<Bool>(defaultValue);
                    Reflect.setField(_server, fieldName, prop);
                    
                case "dropdown":
                    // Create a string property for dropdown
                    var defaultValue = field.defaultValue != null ? Std.string(field.defaultValue) : "";
                    var prop = new champaign.core.primitives.Property<String>(defaultValue);
                    Reflect.setField(_server, fieldName, prop);
                    
                default:
                    Logger.warning('${this}: Unknown field type for property initialization: ${field.type}');
            }
            
            // Add property change listener
            var prop = Reflect.getProperty(_server, fieldName);
            if (prop != null && Reflect.hasField(prop, "onChange")) {
                var onChange = Reflect.field(prop, "onChange");
                if (onChange != null && Reflect.hasField(onChange, "add")) {
                    Reflect.callMethod(onChange, Reflect.field(onChange, "add"), [_server._propertyChanged]);
                }
            }
        } else {
            Logger.info('${this}: Property already exists on server: ${fieldName}');
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
                var checkbox = new GenesisFormCheckBox(field.label);
                checkbox.toolTip = field.tooltip != null ? field.tooltip : "";
                
                // Set default value if provided
                if (field.defaultValue != null) {
                    checkbox.selected = Std.string(field.defaultValue).toLowerCase() == "true";
                }
                
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
            _dropdownNetworkInterface.enabled = !_server.networkBridge.locked && !_server.disableBridgeAdapter.value;
            
            // Update dynamic fields with server values
            for (fieldName => field in _dynamicFields) {
                // Get the server property value if it exists
                var value = Reflect.getProperty(_server, fieldName);
                if (value != null) {
                    if (Std.isOfType(field, GenesisFormTextInput)) {
                        var input:GenesisFormTextInput = cast field;
                        if (Reflect.hasField(value, "value")) {
                            var fieldValue = Reflect.field(value, "value");
                            input.text = fieldValue != null ? Std.string(fieldValue) : "";
                        } else {
                            // Remove "Property: " prefix if present
                            var valueStr = Std.string(value);
                            if (valueStr.indexOf("Property: ") == 0) {
                                valueStr = valueStr.substr(10); // Remove "Property: " prefix
                            }
                            input.text = valueStr;
                        }
                    } else if (Std.isOfType(field, GenesisFormNumericStepper)) {
                        var stepper:GenesisFormNumericStepper = cast field;
                        if (Reflect.hasField(value, "value")) {
                            stepper.value = Std.parseFloat(Std.string(Reflect.field(value, "value")));
                        } else {
                            stepper.value = Std.parseFloat(Std.string(value));
                        }
                    } else if (Std.isOfType(field, GenesisFormCheckBox)) {
                        var checkbox:GenesisFormCheckBox = cast field;
                        if (Reflect.hasField(value, "value")) {
                            checkbox.selected = Reflect.field(value, "value");
                        } else {
                            checkbox.selected = value;
                        }
                    } else if (Std.isOfType(field, GenesisFormPupUpListView)) {
                        var dropdown:GenesisFormPupUpListView = cast field;
                        if (dropdown.dataProvider != null && dropdown.dataProvider.length > 0) {
                            var selectedValue = Reflect.hasField(value, "value") ? Reflect.field(value, "value") : value;
                            for (i in 0...dropdown.dataProvider.length) {
                                var option = dropdown.dataProvider.get(i);
                                if (option != null && option.length > 0 && option[0] == selectedValue) {
                                    dropdown.selectedIndex = i;
                                    break;
                                }
                            }
                        }
                    }
                }
            }
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
        _server.networkBridge.value = _dropdownNetworkInterface.selectedItem.name;
        Logger.info('${this}: Updated network bridge to: ${_server.networkBridge.value}');
        
        // Update server properties from dynamic fields
        for (fieldName => field in _dynamicFields) {
            if (Std.isOfType(field, GenesisFormTextInput)) {
                var input:GenesisFormTextInput = cast field;
                var value = StringTools.trim(input.text);
                
                Logger.info('${this}: Saving text field ${fieldName} with value: ${value}');
                
                // Ensure the property exists on the server
                if (!Reflect.hasField(_server, fieldName)) {
                    Logger.info('${this}: Creating missing property on server: ${fieldName}');
                    var prop = new champaign.core.primitives.Property<String>(value);
                    Reflect.setField(_server, fieldName, prop);
                    
                    // Add property change listener
                    var onChange = Reflect.field(prop, "onChange");
                    if (onChange != null && Reflect.hasField(onChange, "add")) {
                        Reflect.callMethod(onChange, Reflect.field(onChange, "add"), [_server._propertyChanged]);
                    }
                }
                
                // Set the property value
                var prop = Reflect.getProperty(_server, fieldName);
                if (prop != null) {
                    if (Reflect.hasField(prop, "value")) {
                        // It's a property with a value field
                        Reflect.setField(prop, "value", value);
                        Logger.info('${this}: Updated property ${fieldName}.value to: ${value}');
                    } else {
                        // It's a direct property
                        Reflect.setProperty(_server, fieldName, value);
                        Logger.info('${this}: Updated direct property ${fieldName} to: ${value}');
                    }
                } else {
                    Logger.warning('${this}: Failed to get property ${fieldName} from server');
                }
            } else if (Std.isOfType(field, GenesisFormNumericStepper)) {
                var stepper:GenesisFormNumericStepper = cast field;
                var value = stepper.value;
                
                Logger.info('${this}: Saving numeric field ${fieldName} with value: ${value}');
                
                // Ensure the property exists on the server
                if (!Reflect.hasField(_server, fieldName)) {
                    Logger.info('${this}: Creating missing property on server: ${fieldName}');
                    var prop = new champaign.core.primitives.Property<Float>(value);
                    Reflect.setField(_server, fieldName, prop);
                    
                    // Add property change listener
                    var onChange = Reflect.field(prop, "onChange");
                    if (onChange != null && Reflect.hasField(onChange, "add")) {
                        Reflect.callMethod(onChange, Reflect.field(onChange, "add"), [_server._propertyChanged]);
                    }
                }
                
                // Set the property value
                var prop = Reflect.getProperty(_server, fieldName);
                if (prop != null) {
                    if (Reflect.hasField(prop, "value")) {
                        // It's a property with a value field
                        Reflect.setField(prop, "value", value);
                        Logger.info('${this}: Updated property ${fieldName}.value to: ${value}');
                    } else {
                        // It's a direct property
                        Reflect.setProperty(_server, fieldName, value);
                        Logger.info('${this}: Updated direct property ${fieldName} to: ${value}');
                    }
                } else {
                    Logger.warning('${this}: Failed to get property ${fieldName} from server');
                }
            } else if (Std.isOfType(field, GenesisFormCheckBox)) {
                var checkbox:GenesisFormCheckBox = cast field;
                var value = checkbox.selected;
                
                Logger.info('${this}: Saving checkbox field ${fieldName} with value: ${value}');
                
                // Ensure the property exists on the server
                if (!Reflect.hasField(_server, fieldName)) {
                    Logger.info('${this}: Creating missing property on server: ${fieldName}');
                    var prop = new champaign.core.primitives.Property<Bool>(value);
                    Reflect.setField(_server, fieldName, prop);
                    
                    // Add property change listener
                    var onChange = Reflect.field(prop, "onChange");
                    if (onChange != null && Reflect.hasField(onChange, "add")) {
                        Reflect.callMethod(onChange, Reflect.field(onChange, "add"), [_server._propertyChanged]);
                    }
                }
                
                // Set the property value
                var prop = Reflect.getProperty(_server, fieldName);
                if (prop != null) {
                    if (Reflect.hasField(prop, "value")) {
                        // It's a property with a value field
                        Reflect.setField(prop, "value", value);
                        Logger.info('${this}: Updated property ${fieldName}.value to: ${value}');
                    } else {
                        // It's a direct property
                        Reflect.setProperty(_server, fieldName, value);
                        Logger.info('${this}: Updated direct property ${fieldName} to: ${value}');
                    }
                } else {
                    Logger.warning('${this}: Failed to get property ${fieldName} from server');
                }
            } else if (Std.isOfType(field, GenesisFormPupUpListView)) {
                var dropdown:GenesisFormPupUpListView = cast field;
                var selectedItem = dropdown.selectedItem;
                var value = selectedItem != null && selectedItem.length > 0 ? selectedItem[0] : null;
                
                Logger.info('${this}: Saving dropdown field ${fieldName} with value: ${value}');
                
                // Ensure the property exists on the server
                if (!Reflect.hasField(_server, fieldName)) {
                    Logger.info('${this}: Creating missing property on server: ${fieldName}');
                    var prop = new champaign.core.primitives.Property<String>(value);
                    Reflect.setField(_server, fieldName, prop);
                    
                    // Add property change listener
                    var onChange = Reflect.field(prop, "onChange");
                    if (onChange != null && Reflect.hasField(onChange, "add")) {
                        Reflect.callMethod(onChange, Reflect.field(onChange, "add"), [_server._propertyChanged]);
                    }
                }
                
                // Set the property value
                var prop = Reflect.getProperty(_server, fieldName);
                if (prop != null) {
                    if (Reflect.hasField(prop, "value")) {
                        // It's a property with a value field
                        Reflect.setField(prop, "value", value);
                        Logger.info('${this}: Updated property ${fieldName}.value to: ${value}');
                    } else {
                        // It's a direct property
                        Reflect.setProperty(_server, fieldName, value);
                        Logger.info('${this}: Updated direct property ${fieldName} to: ${value}');
                    }
                } else {
                    Logger.warning('${this}: Failed to get property ${fieldName} from server');
                }
            }
        }

        _server.saveHostsFile();
        
        var evt = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.SAVE_ADVANCED_SERVER_CONFIGURATION);
        evt.server = _server;
        this.dispatchEvent(evt);
    }
}
