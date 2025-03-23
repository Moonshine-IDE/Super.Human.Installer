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
        _dropdownNetworkInterface.selectedIndex = 0;
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
            for (i in 0..._dropdownNetworkInterface.dataProvider.length) {
                var d = _dropdownNetworkInterface.dataProvider.get(i);
                if (d.name == _server.networkBridge.value) {
                    _dropdownNetworkInterface.selectedIndex = i;
                    break;
                }
            }
        }
    }
    
    /**
     * Set the provisioner definition for this configuration page
     * @param definition The provisioner definition
     */
    public function setProvisionerDefinition(definition:ProvisionerDefinition) {
        _provisionerDefinition = definition;
        
        // Clear existing dynamic fields
        for (row in _dynamicRows) {
            if (_form.contains(row)) {
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
                _addDynamicField(field);
            }
        }
    }
    
    /**
     * Add a dynamic field to the form based on the field definition
     * @param field The field definition from the provisioner.yml
     */
    private function _addDynamicField(field:ProvisionerManager.ProvisionerField) {
        // Create a new row for the field
        var row = new GenesisFormRow();
        row.text = field.label;
        
        // Create the appropriate form control based on the field type
        switch (field.type) {
            case "text":
                var input = new GenesisFormTextInput();
                input.prompt = field.placeholder != null ? field.placeholder : "";
                input.toolTip = field.tooltip != null ? field.tooltip : "";
                
                // Set validation key if provided
                if (field.validationKey != null) {
                    input.validationKey = field.validationKey;
                }
                
                // Set default value if provided
                if (field.defaultValue != null) {
                    input.text = Std.string(field.defaultValue);
                }
                
                // Set minimum length if required
                if (field.required == true) {
                    input.minLength = 1;
                }
                
                // Add the input to the row
                row.content.addChild(input);
                
                // Store the input in the dynamic fields map
                _dynamicFields.set(field.name, input);
                
            case "number":
                var stepper = new GenesisFormNumericStepper();
                stepper.toolTip = field.tooltip != null ? field.tooltip : "";
                
                // Set min/max values if provided
                if (field.min != null) stepper.minimum = field.min;
                if (field.max != null) stepper.maximum = field.max;
                
                // Set default value if provided
                if (field.defaultValue != null) {
                    stepper.value = Std.parseFloat(Std.string(field.defaultValue));
                }
                
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
                    var options = [];
                    for (option in field.options) {
                        options.push({value: option.value, label: option.label});
                    }
                    dropdown.dataProvider = new feathers.data.ArrayCollection(options);
                    dropdown.itemToText = (item) -> item.label;
                    
                    // Set default value if provided
                    if (field.defaultValue != null) {
                        for (i in 0...options.length) {
                            if (options[i].value == field.defaultValue) {
                                dropdown.selectedIndex = i;
                                break;
                            }
                        }
                    }
                }
                
                // Add the dropdown to the row
                row.content.addChild(dropdown);
                
                // Store the dropdown in the dynamic fields map
                _dynamicFields.set(field.name, dropdown);
                
            default:
                Logger.warning('Unknown field type: ${field.type} for field ${field.name}');
        }
        
        // Add the row to the form
        _form.addChild(row);
        
        // Store the row in the dynamic rows map
        _dynamicRows.set(field.name, row);
    }

    override function updateContent(forced:Bool = false) {
        super.updateContent();

        if (_form != null && _server != null) {
            _label.text = LanguageManager.getInstance().getString('serveradvancedconfigpage.title', Std.string(_server.id));
            
            // Update network interface dropdown
            _dropdownNetworkInterface.selectedIndex = 0;
            for (i in 0..._dropdownNetworkInterface.dataProvider.length) {
                var d = _dropdownNetworkInterface.dataProvider.get(i);
                if (d.name == _server.networkBridge.value) {
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
                            input.text = Reflect.field(value, "value");
                        } else {
                            input.text = Std.string(value);
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
                        var selectedValue = Reflect.hasField(value, "value") ? Reflect.field(value, "value") : value;
                        for (i in 0...dropdown.dataProvider.length) {
                            var option = dropdown.dataProvider.get(i);
                            if (option.value == selectedValue) {
                                dropdown.selectedIndex = i;
                                break;
                            }
                        }
                    }
                }
            }
        }
    }

    override function _cancel(?e:Dynamic) {
        var evt = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.CANCEL_PAGE);
        evt.server = _server;
        this.dispatchEvent(evt);
    }
    
    function _saveButtonTriggered(e:TriggerEvent) {
        if (!_form.isValid()) return;

        // Update standard fields
        _server.networkBridge.value = _dropdownNetworkInterface.selectedItem.name;
        
        // Update server properties from dynamic fields
        for (fieldName => field in _dynamicFields) {
            if (Std.isOfType(field, GenesisFormTextInput)) {
                var input:GenesisFormTextInput = cast field;
                var value = StringTools.trim(input.text);
                
                // Check if the server has this property
                if (Reflect.hasField(_server, fieldName)) {
                    var prop = Reflect.getProperty(_server, fieldName);
                    if (Reflect.hasField(prop, "value")) {
                        // It's a property with a value field
                        Reflect.setField(prop, "value", value);
                    } else {
                        // It's a direct property
                        Reflect.setProperty(_server, fieldName, value);
                    }
                }
            } else if (Std.isOfType(field, GenesisFormNumericStepper)) {
                var stepper:GenesisFormNumericStepper = cast field;
                var value = stepper.value;
                
                // Check if the server has this property
                if (Reflect.hasField(_server, fieldName)) {
                    var prop = Reflect.getProperty(_server, fieldName);
                    if (Reflect.hasField(prop, "value")) {
                        // It's a property with a value field
                        Reflect.setField(prop, "value", value);
                    } else {
                        // It's a direct property
                        Reflect.setProperty(_server, fieldName, value);
                    }
                }
            } else if (Std.isOfType(field, GenesisFormCheckBox)) {
                var checkbox:GenesisFormCheckBox = cast field;
                var value = checkbox.selected;
                
                // Check if the server has this property
                if (Reflect.hasField(_server, fieldName)) {
                    var prop = Reflect.getProperty(_server, fieldName);
                    if (Reflect.hasField(prop, "value")) {
                        // It's a property with a value field
                        Reflect.setField(prop, "value", value);
                    } else {
                        // It's a direct property
                        Reflect.setProperty(_server, fieldName, value);
                    }
                }
            } else if (Std.isOfType(field, GenesisFormPupUpListView)) {
                var dropdown:GenesisFormPupUpListView = cast field;
                var selectedItem = dropdown.selectedItem;
                var value = selectedItem != null ? selectedItem.value : null;
                
                // Check if the server has this property
                if (Reflect.hasField(_server, fieldName)) {
                    var prop = Reflect.getProperty(_server, fieldName);
                    if (Reflect.hasField(prop, "value")) {
                        // It's a property with a value field
                        Reflect.setField(prop, "value", value);
                    } else {
                        // It's a direct property
                        Reflect.setProperty(_server, fieldName, value);
                    }
                }
            }
        }

        _server.saveHostsFile();
        
        var evt = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.SAVE_ADVANCED_SERVER_CONFIGURATION);
        evt.server = _server;
        this.dispatchEvent(evt);
    }
}
