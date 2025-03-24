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
        
        // Initialize with empty collection - we'll set it properly in setServer
        _dropdownCoreComponentVersion = new GenesisFormPupUpListView(new feathers.data.ArrayCollection<ProvisionerDefinition>([]));
        _dropdownCoreComponentVersion.itemToText = (item:ProvisionerDefinition) -> {
            return item.name;
        };
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
        
        // Mark the form as initialized
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
            _label.text = LanguageManager.getInstance().getString('serverconfigpage.title', Std.string(_server.id));
        }
        
        // Load any custom properties from server.customProperties
        if (_server.customProperties != null && Reflect.hasField(_server.customProperties, "dynamicCustomProperties")) {
            var customPropsObj = Reflect.field(_server.customProperties, "dynamicCustomProperties");
            if (customPropsObj != null) {
                Logger.info('${this}: Loading custom properties from server customProperties: ${customPropsObj}');
                
                // Iterate over fields in the object
                var fields = Reflect.fields(customPropsObj);
                Logger.info('${this}: Found ${fields.length} custom properties to load');
                
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
                            
                            Logger.info('${this}: Created custom property from customProperties: ${field}');
                        }
                    } else {
                        // Update existing property
                        var prop = _customProperties.get(field);
                        if (prop != null && Reflect.hasField(prop, "value")) {
                            Reflect.setField(prop, "value", value);
                            Logger.info('${this}: Updated existing custom property from customProperties: ${field} to ${value}');
                        }
                    }
                }
                
                // Force an update of the UI once properties are loaded
                _pendingUpdateContent = true;
            }
        } else {
            Logger.info('${this}: No dynamicCustomProperties found in server customProperties');
        }
        
        Logger.info('${this}: Server set: ${server.id}, provisioner type: ${server.provisioner.type}');
        
        // We'll update the dropdown in updateContent() to ensure it's initialized
    }
    
    /**
     * Update the provisioner dropdown with versions of the same type
     */
    private function _updateProvisionerDropdown() {
        if (_dropdownCoreComponentVersion == null) {
            Logger.warning('${this}: Dropdown is null, cannot update provisioner versions');
            return;
        }
        
        Logger.info('${this}: Setting up provisioner dropdown for server with type: ${_server.provisioner.type}, version: ${_server.provisioner.version}');
        
        // Check if we already have a provisioner definition from the service type data
        var serviceTypeProvisioner = null;
        if (_server != null && _server.customProperties != null) {
            var customProperties = _server.customProperties;
            if (Reflect.hasField(customProperties, "serviceTypeData")) {
                var serviceTypeData = Reflect.field(customProperties, "serviceTypeData");
                if (serviceTypeData != null && Reflect.hasField(serviceTypeData, "provisioner")) {
                    serviceTypeProvisioner = Reflect.field(serviceTypeData, "provisioner");
                    Logger.info('${this}: Found provisioner in service type data: ${serviceTypeProvisioner.name}');
                }
            }
        }
        
        // Get the provisioners directory path
        var provisionersDir = ProvisionerManager.getProvisionersDirectory();
        Logger.info('${this}: Provisioners directory: ${provisionersDir}');
        
        // Get the actual provisioner type from the server
        var provisionerType = _server.provisioner.type;
        Logger.info('${this}: Getting provisioners for type: ${provisionerType}');
        
        // Create a collection for the dropdown
        var provisionerCollection = new feathers.data.ArrayCollection<ProvisionerDefinition>();
        
        // First try to get provisioners directly from the directory
        if (sys.FileSystem.exists(provisionersDir)) {
            try {
                // Check if the specific provisioner directory exists
                var provisionerPath = haxe.io.Path.addTrailingSlash(provisionersDir) + provisionerType;
                if (sys.FileSystem.exists(provisionerPath) && sys.FileSystem.isDirectory(provisionerPath)) {
                    Logger.info('${this}: Found provisioner directory at ${provisionerPath}');
                    
                    // Read the metadata
                    var metadata = ProvisionerManager.readProvisionerMetadata(provisionerPath);
                    if (metadata != null) {
                        Logger.info('${this}: Read metadata: name=${metadata.name}, type=${metadata.type}');
                        
                        // Scan for version directories
                        var versionDirs = sys.FileSystem.readDirectory(provisionerPath);
                        
                        for (versionDir in versionDirs) {
                            var versionPath = haxe.io.Path.addTrailingSlash(provisionerPath) + versionDir;
                            
                            // Skip if not a directory or if it's the provisioner.yml file
                            if (!sys.FileSystem.isDirectory(versionPath) || versionDir == "provisioner.yml") {
                                continue;
                            }
                            
                            // Check if this is a valid version directory (has scripts subdirectory)
                            var scriptsPath = haxe.io.Path.addTrailingSlash(versionPath) + "scripts";
                            if (sys.FileSystem.exists(scriptsPath) && sys.FileSystem.isDirectory(scriptsPath)) {
                                // Create a version-specific metadata copy
                                var versionMetadata = Reflect.copy(metadata);
                                versionMetadata.version = versionDir;
                                
                                // Create a provisioner definition
                                var versionInfo = champaign.core.primitives.VersionInfo.fromString(versionDir);
                                var provDef:ProvisionerDefinition = {
                                    name: '${metadata.name} v${versionDir}',
                                    data: { type: metadata.type, version: versionInfo },
                                    root: versionPath,
                                    metadata: versionMetadata
                                };
                                
                                // Add to collection
                                provisionerCollection.add(provDef);
                                Logger.info('${this}: Manually added provisioner version: ${versionDir}');
                            }
                        }
                    }
                }
            } catch (e) {
                Logger.error('${this}: Error scanning for custom provisioners: ${e}');
            }
        }
        
        // If we didn't find any versions directly, try using the API
        if (provisionerCollection.length == 0) {
            // Get all provisioners of the same type
            var allProvisioners = ProvisionerManager.getBundledProvisioners(provisionerType);
            
            // Log detailed information about each provisioner
            Logger.info('${this}: Found ${allProvisioners.length} provisioners of type ${provisionerType}');
            for (i in 0...allProvisioners.length) {
                var p = allProvisioners[i];
                Logger.info('${this}: Provisioner ${i}: name=${p.name}, type=${p.data.type}, version=${p.data.version}, root=${p.root}');
                
                if (p.metadata != null) {
                    Logger.info('${this}: Metadata: name=${p.metadata.name}, type=${p.metadata.type}, version=${p.metadata.version}');
                } else {
                    Logger.warning('${this}: No metadata for provisioner ${p.name}');
                }
                
                // Add to collection
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
                        Logger.info('${this}: Added filtered provisioner: ${p.name}');
                    }
                }
                
                Logger.info('${this}: Found ${provisionerCollection.length} filtered provisioners for type ${provisionerType}');
            }
        }
        
        // No replacement needed - removing duplicate code
        
        // Set the dropdown data provider
        _dropdownCoreComponentVersion.dataProvider = provisionerCollection;
        Logger.info('${this}: Set dropdown data provider with ${provisionerCollection.length} items');
        
        // First try to select the provisioner from service type data if available
        var selectedIndex = -1;
        if (serviceTypeProvisioner != null) {
            for (i in 0...provisionerCollection.length) {
                var d:ProvisionerDefinition = provisionerCollection.get(i);
                if (d.name == serviceTypeProvisioner.name && d.data.version == serviceTypeProvisioner.data.version) {
                    selectedIndex = i;
                    Logger.info('${this}: Found matching service type provisioner at index ${i}');
                    break;
                }
            }
        }
        
        // If no match from service type data, try to match by server's provisioner version
        if (selectedIndex < 0) {
            for (i in 0...provisionerCollection.length) {
                var d:ProvisionerDefinition = provisionerCollection.get(i);
                Logger.info('${this}: Checking provisioner at index ${i}: ${d.name}, version=${d.data.version} against server version=${_server.provisioner.version}');
                
                if (d.data.version == _server.provisioner.version) {
                    selectedIndex = i;
                    Logger.info('${this}: Found matching version at index ${i}');
                    break;
                }
            }
        }
        
        // If we found a match, select it
        if (selectedIndex >= 0) {
            Logger.info('${this}: Setting selected index to ${selectedIndex}');
            _dropdownCoreComponentVersion.selectedIndex = selectedIndex;
        } else if (provisionerCollection.length > 0) {
            // Otherwise select the first one
            Logger.info('${this}: No matching version found, setting selected index to 0');
            _dropdownCoreComponentVersion.selectedIndex = 0;
        } else {
            Logger.warning('${this}: No provisioners in collection, cannot set selected index');
        }
        
        // Get the provisioner definition for the current version
        var provisionerDefinition = null;
        if (selectedIndex >= 0) {
            provisionerDefinition = provisionerCollection.get(selectedIndex);
            Logger.info('${this}: Using provisioner definition at index ${selectedIndex}: ${provisionerDefinition.name}');
        } else if (provisionerCollection.length > 0) {
            provisionerDefinition = provisionerCollection.get(0);
            Logger.info('${this}: Using first provisioner definition: ${provisionerDefinition.name}');
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
            Logger.info('${this}: Form not initialized yet, storing provisioner definition for later');
            _pendingProvisionerDefinition = definition;
            return;
        }
        
        _provisionerDefinition = definition;
        
        // Log the provisioner definition to help with debugging
        Logger.info('${this}: Setting provisioner definition: ${definition.name}, type: ${definition.data.type}, version: ${definition.data.version}');
        
        // Initialize server properties for all fields in the provisioner definition
        if (_server != null && definition.metadata != null && 
            definition.metadata.configuration != null && 
            definition.metadata.configuration.basicFields != null) {
            
            Logger.info('${this}: Initializing server properties for basic fields');
            
            // Create properties for each field in the basic configuration
            for (field in definition.metadata.configuration.basicFields) {
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
            
            if (definition.metadata.roles != null) {
                Logger.info('Roles defined: ${definition.metadata.roles.length}');
            } else {
                Logger.warning('No roles found in provisioner metadata');
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
            _provisionerDefinition.metadata.configuration.basicFields != null) {
            
            // Add each field from the configuration
            for (field in _provisionerDefinition.metadata.configuration.basicFields) {
                Logger.info('Adding field to form: ${field.name}, type: ${field.type}, label: ${field.label}');
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
            Logger.info('${this}: Form not initialized yet, storing updateContent request for later');
            _pendingUpdateContent = true;
            return;
        }
        
        Logger.info('${this}: Updating content (forced=${forced})');
        
        if (_form != null && _server != null) {
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
            
            // Update provisioner dropdown - this is now handled by _updateProvisionerDropdown
            if (forced || _dropdownCoreComponentVersion.dataProvider.length == 0) {
                Logger.info('${this}: Updating provisioner dropdown (forced=${forced}, current items=${_dropdownCoreComponentVersion.dataProvider.length})');
                
                // Use a small delay to ensure the UI is ready
                haxe.Timer.delay(function() {
                    _updateProvisionerDropdown();
                }, 100);
            } else {
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
            }
            _dropdownCoreComponentVersion.enabled = !_server.hostname.locked;
            
            // Log information about available dynamic fields
            Logger.info('${this}: Updating ${Lambda.count(_dynamicFields)} dynamic fields with server or custom property values');
            
            // Look for dynamic custom properties in server.customProperties if they exist
            var customPropValues = new Map<String, Dynamic>();
            if (_server.customProperties != null && Reflect.hasField(_server.customProperties, "dynamicCustomProperties")) {
                var customPropsObj = Reflect.field(_server.customProperties, "dynamicCustomProperties");
                if (customPropsObj != null) {
                    var fields = Reflect.fields(customPropsObj);
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
                            Logger.info('${this}: Using value from server property _${fieldName}: ${valueField}');
                            valueSource = "serverPropertyUnderscore";
                        } catch (e2) {
                            // Property doesn't exist on server
                            Logger.warning('${this}: Could not get property value for ${fieldName}: ${e2}');
                        }
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
            Logger.info('${this}: Sending provisioner definition in event: ${_provisionerDefinition.name}');
        }
        
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

    /**
     * Handler for property changes to propagate to the server
     * @param property The property that changed
     */
    private function _propertyChangedHandler<T>(property:T):Void {
        if (_server != null) {
            _server.setServerStatus();
        }
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
        
        Logger.info('${this}: Saving form data for ${Lambda.count(_dynamicFields)} fields');
        
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
                // Handle special cases for standard server properties
                // Important: Map known custom provisioner fields to server standard fields
                if (fieldName == "hostname") {
                    // Set the server hostname via Property object
                    _server.hostname.value = value;
                    Logger.info('${this}: Set server hostname to ${value}');
                } else if (fieldName == "organization") {
                    // Set the server organization via Property object
                    _server.organization.value = value;
                    Logger.info('${this}: Set server organization to ${value}');
                } else if (fieldName == "userEmail") {
                    // Set user email via Property object
                    _server.userEmail.value = value;
                    Logger.info('${this}: Set user email to ${value}');
                } else if (fieldName == "openBrowser") {
                    // Set open browser flag via Property object
                    var boolValue = value.toLowerCase() == "true";
                    _server.openBrowser.value = boolValue;
                    Logger.info('${this}: Set open browser to ${value}');
                } else if (fieldName == "numCPUs") {
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
                        Logger.info('${this}: Updated custom property ${fieldName} value to ${value}');
                        
                        // Also update the server field directly if it exists
                        try {
                            var propName = 'server_${fieldName}';
                            Reflect.setField(_server, propName, value);
                        } catch (e) {
                            // Just continue if the field doesn't exist
                        }
                    }
                } else {
                    // Try to update server property
                    try {
                        var prop = Reflect.getProperty(_server, fieldName);
                        if (prop != null && Reflect.hasField(prop, "value")) {
                            Reflect.setField(prop, "value", value);
                            Logger.info('${this}: Updated server property ${fieldName} value to ${value}');
                        }
                    } catch (e) {
                        Logger.warning('${this}: Could not update property ${fieldName}: ${e}');
                    }
                }
            }
        }
        
        // Store custom properties in server's customProperties if available
        if (_server != null && _customProperties.keys().hasNext()) {
            // Make sure customProperties is initialized
            if (_server.customProperties == null) {
                _server.customProperties = {};
            }
            
            // Create or update the dynamicCustomProperties field to hold our custom properties
            var customProperties:Dynamic = _server.customProperties;
            if (!Reflect.hasField(customProperties, "dynamicCustomProperties")) {
                Reflect.setField(customProperties, "dynamicCustomProperties", {});
            }
            
            var customPropsObj = Reflect.field(customProperties, "dynamicCustomProperties");
            for (key => prop in _customProperties) {
                if (Reflect.hasField(prop, "value")) {
                    Reflect.setField(customPropsObj, key, Reflect.field(prop, "value"));
                }
            }
            
            // Force an immediate save of server data to avoid race conditions
            _server.saveData();
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
