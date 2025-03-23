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
    var _buttonSafeId:GenesisFormButton;
    var _buttonSave:GenesisFormButton;
    var _dropdownCoreComponentVersion:GenesisFormPupUpListView;
    var _form:GenesisForm;
    var _label:Label;
    var _labelMandatory:Label;
    var _server:Server;
    var _titleGroup:LayoutGroup;
    var _provisionerDefinition:ProvisionerDefinition;
    
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

        _form = new GenesisForm();
        this.addChild(_form);

        // Core component version dropdown
        var rowCoreComponentVersion = new GenesisFormRow();
        rowCoreComponentVersion.text = LanguageManager.getInstance().getString('serverconfigpage.form.provisioner.text');
        _dropdownCoreComponentVersion = new GenesisFormPupUpListView(ProvisionerManager.getBundledProvisionerCollection(_server?.provisioner?.type));
        _dropdownCoreComponentVersion.itemToText = (item:ProvisionerDefinition) -> {
            return item.name;
        };
        _dropdownCoreComponentVersion.selectedIndex = 0;
        rowCoreComponentVersion.content.addChild(_dropdownCoreComponentVersion);
        _form.addChild(rowCoreComponentVersion);

        // SafeID button
        var rowSafeId = new GenesisFormRow();
        rowSafeId.text = LanguageManager.getInstance().getString('serverconfigpage.form.safeid.text');
        _buttonSafeId = new GenesisFormButton();
        _buttonSafeId.toolTip = LanguageManager.getInstance().getString('serverconfigpage.form.safeid.tooltip');
        _buttonSafeId.addEventListener(TriggerEvent.TRIGGER, _buttonSafeIdTriggered);
        rowSafeId.content.addChild(_buttonSafeId);
        _form.addChild(rowSafeId);

        // Roles button
        var rowRoles = new GenesisFormRow();
        rowRoles.text = LanguageManager.getInstance().getString('serverconfigpage.form.roles.text');
        _buttonRoles = new GenesisFormButton(LanguageManager.getInstance().getString('serverconfigpage.form.roles.button'));
        _buttonRoles.addEventListener(TriggerEvent.TRIGGER, _buttonRolesTriggered);
        rowRoles.content.addChild(_buttonRoles);
        _form.addChild(rowRoles);

        var line = new HLine();
        line.width = _w;
        this.addChild(line);

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
        
        // Update the provisioner dropdown
        if (_dropdownCoreComponentVersion != null) {
            _dropdownCoreComponentVersion.dataProvider = ProvisionerManager.getBundledProvisionerCollection(_server.provisioner.type);
            
            // Select the current provisioner version
            for (i in 0..._dropdownCoreComponentVersion.dataProvider.length) {
                var d:ProvisionerDefinition = _dropdownCoreComponentVersion.dataProvider.get(i);
                if (d.data.version == _server.provisioner.version) {
                    _dropdownCoreComponentVersion.selectedIndex = i;
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
            _provisionerDefinition.metadata.configuration.basicFields != null) {
            
            // Add each field from the configuration
            for (field in _provisionerDefinition.metadata.configuration.basicFields) {
                _addDynamicField(field);
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
                                    var value = option.value;
                                    var label = option.label;
                                    
                                    if (value != null && label != null) {
                                        options.push([value, label]);
                                    } else {
                                        Logger.warning('Invalid dropdown option in field ${field.name}: value=${value}, label=${label}');
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
        
        // Add the row to the form
        _form.addChild(row);
        
        // Store the row in the dynamic rows map
        _dynamicRows.set(field.name, row);
    }

    override function updateContent(forced:Bool = false) {
        super.updateContent();

        if (_form != null) {
            _label.text = LanguageManager.getInstance().getString('serverconfigpage.title', Std.string(_server.id));
            
            // Update SafeID button
            _buttonSafeId.icon = (_server.safeIdExists()) ? GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_OK) : GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_WARNING);
            _buttonSafeId.text = (_server.safeIdExists()) ? LanguageManager.getInstance().getString('serverconfigpage.form.safeid.buttonlocateagain') : LanguageManager.getInstance().getString('serverconfigpage.form.safeid.buttonlocate');
            _buttonSafeId.enabled = !_server.userSafeId.locked;
            
            // Update Roles button
            _buttonRoles.icon = (_server.areRolesValid()) ? GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_OK) : GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_WARNING);
            _buttonRoles.enabled = !_server.roles.locked;
            
            // Update Save button
            _buttonSave.enabled = !_server.hostname.locked;
            
            // Update provisioner dropdown
            if (_dropdownCoreComponentVersion.selectedIndex == -1 || forced) {
                for (i in 0..._dropdownCoreComponentVersion.dataProvider.length) {
                    var d:ProvisionerDefinition = _dropdownCoreComponentVersion.dataProvider.get(i);
                    if (d.data.version == _server.provisioner.version) {
                        _dropdownCoreComponentVersion.selectedIndex = i;
                        break;
                    }
                }
            }
            _dropdownCoreComponentVersion.enabled = !_server.hostname.locked;
            
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

    function _advancedLinkTriggered(e:MouseEvent) {
        var evt = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.ADVANCED_CONFIGURE_SERVER);
        evt.server = _server;
        this.dispatchEvent(evt);
    }

    function _buttonSafeIdTriggered(e:TriggerEvent) {
        _server.locateNotesSafeId(_safeIdLocated);
    }

    function _safeIdLocated() {
        _buttonSafeId.setValidity(true);
        _buttonSafeId.icon = (_buttonSafeId.isValid()) ? GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_OK) : GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_WARNING);
        _buttonSafeId.text = (_buttonSafeId.isValid()) ? LanguageManager.getInstance().getString('serverconfigpage.form.safeid.buttonlocateagain') : LanguageManager.getInstance().getString('serverconfigpage.form.safeid.buttonlocate');
    }

    function _buttonRolesTriggered(e:TriggerEvent) {
        var evt = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.CONFIGURE_ROLES);
        evt.server = this._server;
        this.dispatchEvent(evt);
    }

    function _saveButtonTriggered(e:TriggerEvent) {
        _buttonSafeId.setValidity(_server.safeIdExists());
        _buttonRoles.setValidity(_server.areRolesValid());

        if (!_form.isValid() || !_server.safeIdExists() || !_server.areRolesValid()) {
            return;
        }

        // Making sure the event is fired
        var a = _server.roles.value.copy();
        _server.roles.value = a;
        _server.syncMethod = SuperHumanInstaller.getInstance().config.preferences.syncmethod;
        
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
                var value = selectedItem != null && selectedItem.length > 0 ? selectedItem[0] : null;
                
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
        
        // Update the provisioner
        var dvv:ProvisionerDefinition = cast _dropdownCoreComponentVersion.selectedItem;
        _server.updateProvisioner(dvv.data);

        SuperHumanInstaller.getInstance().config.user.lastusedsafeid = _server.userSafeId.value;
        
        var evt = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.SAVE_SERVER_CONFIGURATION);
        evt.server = _server;
        this.dispatchEvent(evt);
    }
}
