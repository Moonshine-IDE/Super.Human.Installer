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

import superhuman.server.cache.SuperHumanFileCache;
import superhuman.server.cache.SuperHumanCachedFile;
import superhuman.server.definitions.ProvisionerDefinition;
import superhuman.config.SuperHumanHashes;
import champaign.core.logging.Logger;
import feathers.controls.Alert;
import feathers.controls.Button;
import feathers.controls.Label;
import feathers.controls.LayoutGroup;
import feathers.controls.PopUpListView;
import feathers.controls.ScrollContainer;
import feathers.data.ArrayCollection;
import feathers.events.TriggerEvent;
import feathers.layout.HorizontalAlign;
import feathers.layout.HorizontalLayout;
import feathers.layout.HorizontalLayoutData;
import feathers.layout.VerticalAlign;
import feathers.layout.VerticalLayout;
import feathers.layout.VerticalLayoutData;
import feathers.skins.RectangleSkin;
import genesis.application.components.GenesisFormPupUpListView;
import genesis.application.components.AdvancedAssetLoader;
import genesis.application.components.AdvancedCheckBox;
import genesis.application.components.HLine;
import genesis.application.components.Page;
import genesis.application.managers.LanguageManager;
import genesis.application.theme.GenesisApplicationTheme;
import haxe.io.Path;
import lime.system.System;
import lime.ui.FileDialog;
import lime.ui.FileDialogType;
import openfl.events.Event;
import prominic.sys.io.FileTools;
import superhuman.events.SuperHumanApplicationEvent;
import superhuman.managers.ProvisionerManager;
import superhuman.server.Server;
import superhuman.server.data.RoleData;
import superhuman.server.provisioners.ProvisionerType;
import superhuman.server.roles.ServerRoleImpl;
import superhuman.theme.SuperHumanInstallerTheme;

class RolePage extends Page {

    final _w:Float = GenesisApplicationTheme.GRID * 100;

    var _buttonGroup:LayoutGroup;
    var _buttonGroupLayout:HorizontalLayout;
    var _buttonClose:Button;
    var _listGroup:LayoutGroup;
    var _listGroupLayout:VerticalLayout;
    var _server:Server;
    // Fields to store provisioner info from custom provisioners
    public var _provisionerDefinition:ProvisionerDefinition;
    public var _lastDefinitionName:String;
    var _fd:FileDialog;
    
    public function new() {

        super();

    }

    override function initialize() {

        super.initialize();

        _content.width = _w;

        // Create a scroll container for the list content
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
        
        // Create the list group and add it to the scroll container
        _listGroup = new LayoutGroup();
        _listGroup.layoutData = new VerticalLayoutData(100);
        _listGroupLayout = new VerticalLayout();
        _listGroupLayout.gap = GenesisApplicationTheme.GRID;
        _listGroup.layout = _listGroupLayout;
        scrollContainer.addChild(_listGroup);

        _buttonGroup = new LayoutGroup();
        _buttonGroupLayout = new HorizontalLayout();
        _buttonGroupLayout.gap = GenesisApplicationTheme.GRID * 2;
        _buttonGroupLayout.horizontalAlign = HorizontalAlign.CENTER;
        _buttonGroup.layout = _buttonGroupLayout;
        this.addChild( _buttonGroup );

        _buttonClose = new Button( LanguageManager.getInstance().getString( 'rolepage.buttons.close' ) );
        _buttonClose.addEventListener( TriggerEvent.TRIGGER, _buttonCloseTriggered );
        _buttonGroup.addChild( _buttonClose );

        updateContent();

    }

    public function setServer( server:Server ) {

        _server = server;

    }

    override function updateContent( forced:Bool = false ) {

        super.updateContent();

        if ( _listGroup != null) {

            _listGroup.removeChildren();
            
            // Check if this is a custom provisioner
            Logger.info('RolePage: Server provisioner type: ${_server.provisioner.type}');
            
            // Dump the server's roles for debugging
            Logger.info('RolePage: Current server roles:');
            for (role in _server.roles.value) {
                Logger.info('  - Role: ${role.value}, enabled: ${role.enabled}');
            }
            
            // Get the actual class name of the provisioner to determine its type
            var provisionerClassName = Type.getClassName(Type.getClass(_server.provisioner));
            Logger.info('RolePage: Provisioner class name: ${provisionerClassName}');
            
            // Check by class name first (most reliable)
            var isStandardProvisioner = (provisionerClassName == "superhuman.server.provisioners.StandaloneProvisioner" || 
                                       provisionerClassName == "superhuman.server.provisioners.AdditionalProvisioner");
            
            // If not determined by class name, check by type
            if (!isStandardProvisioner) {
                isStandardProvisioner = (_server.provisioner.type == ProvisionerType.StandaloneProvisioner || 
                                       _server.provisioner.type == ProvisionerType.AdditionalProvisioner ||
                                       _server.provisioner.type == ProvisionerType.Default);
            }
            
            // If it's a standard provisioner, it should NEVER use custom roles
            var isCustomProvisioner = !isStandardProvisioner;
            
            Logger.info('RolePage: Final determination - Standard provisioner: ${isStandardProvisioner}, Custom provisioner: ${isCustomProvisioner}');
            
            // Use custom roles only for custom provisioners
            if (isCustomProvisioner) {
                // First try to get the provisioner definition from the event data
                var provisionerDefinition = null;
                
                // Try multiple methods to get the provisioner definition, in order of preference
                
                // Method 1: Check if we have the provisioner definition stored as an instance variable
                if (Reflect.hasField(this, "_provisionerDefinition") && 
                    Reflect.field(this, "_provisionerDefinition") != null) {
                    provisionerDefinition = Reflect.field(this, "_provisionerDefinition");
                    Logger.info('RolePage: Using provisioner definition from instance variable: ${provisionerDefinition.name}');
                }
                
                // Method 2: Check if there's a stored definition name in class fields
                else if (Reflect.hasField(this, "_lastDefinitionName") && 
                         Reflect.field(this, "_lastDefinitionName") != null) {
                    var definitionName = Reflect.field(this, "_lastDefinitionName");
                    Logger.info('RolePage: Using stored definition name: ${definitionName}');
                    
                    // Look up the provisioner by name
                    var allProvisioners = ProvisionerManager.getBundledProvisioners(_server.provisioner.type);
                    for (p in allProvisioners) {
                        if (p.name == definitionName) {
                            provisionerDefinition = p;
                            Logger.info('RolePage: Found matching provisioner definition: ${p.name}');
                            break;
                        }
                    }
                }
                
                // Method 3: Check if the server has a currentProvisionerDefinitionName in customProperties
                else if (provisionerDefinition == null && _server.customProperties != null && 
                         Reflect.hasField(_server.customProperties, "currentProvisionerDefinitionName")) {
                    var definitionName = Reflect.field(_server.customProperties, "currentProvisionerDefinitionName");
                    Logger.info('RolePage: Found provisioner name in server.customProperties: ${definitionName}');
                    
                    // Look up the provisioner by name
                    var allProvisioners = ProvisionerManager.getBundledProvisioners(_server.provisioner.type);
                    for (p in allProvisioners) {
                        if (p.name == definitionName) {
                            provisionerDefinition = p;
                            Logger.info('RolePage: Found matching provisioner definition: ${p.name}');
                            break;
                        }
                    }
                }
                
                // Method 4: Check if the server has a provisionerDefinition in customProperties
                else if (provisionerDefinition == null && _server.customProperties != null && 
                         Reflect.hasField(_server.customProperties, "provisionerDefinition")) {
                    provisionerDefinition = Reflect.field(_server.customProperties, "provisionerDefinition");
                    Logger.info('RolePage: Using provisioner definition from server.customProperties');
                }
                
                // Method 5: Get from the ProvisionerManager by type and version
                else if (provisionerDefinition == null) {
                    Logger.info('RolePage: Getting provisioner definition for type: ${_server.provisioner.type}, version: ${_server.provisioner.version}');
                    provisionerDefinition = ProvisionerManager.getProvisionerDefinition(_server.provisioner.type, _server.provisioner.version);
                    Logger.info('RolePage: Provisioner definition found: ${provisionerDefinition != null}');
                }
                
                // Method 6: Try to load directly from user directory
                if (provisionerDefinition == null) {
                    // Check in the user's application storage directory
                    var provisionersDir = ProvisionerManager.getProvisionersDirectory();
                    var typePath = Path.addTrailingSlash(provisionersDir) + Std.string(_server.provisioner.type);
                    var provisionerYmlPath = Path.addTrailingSlash(typePath) + "provisioner.yml";
                    
                    if (sys.FileSystem.exists(provisionerYmlPath)) {
                        Logger.info('RolePage: Found provisioner.yml at ${provisionerYmlPath}');
                        var metadata = ProvisionerManager.readProvisionerMetadata(typePath);
                        
                        if (metadata != null) {
                            Logger.info('RolePage: Successfully loaded metadata from ${provisionerYmlPath}');
                            
                            // Create a provisioner definition with this metadata
                            provisionerDefinition = {
                                name: metadata.name,
                                data: { 
                                    type: metadata.type, 
                                    version: champaign.core.primitives.VersionInfo.fromString("0.0.0")
                                },
                                root: typePath,
                                metadata: metadata
                            };
                        }
                    }
                }
                
                // Method 7: Try to find it in Assets/provisioners directory
                if (provisionerDefinition == null) {
                    Logger.info('RolePage: Trying to find provisioner definition in Assets/provisioners directory');
                    
                    // Check standard locations for provisioner.yml
                    var provisionerPaths = [
                        'Assets/provisioners/${_server.provisioner.type}/provisioner.yml',
                        'Assets/provisioners/${_server.provisioner.type}/${_server.provisioner.version}/provisioner.yml'
                    ];
                    
                    for (path in provisionerPaths) {
                        if (sys.FileSystem.exists(path)) {
                            Logger.info('RolePage: Found provisioner.yml at ${path}');
                            var metadata = ProvisionerManager.readProvisionerMetadata(Path.directory(path));
                            
                            if (metadata != null) {
                                // Create a provisioner definition with this metadata
                                provisionerDefinition = {
                                    name: metadata.name,
                                    data: { 
                                        type: metadata.type, 
                                        version: champaign.core.primitives.VersionInfo.fromString("0.0.0")
                                    },
                                    root: Path.directory(path),
                                    metadata: metadata
                                };
                                
                                break;
                            }
                        }
                    }
                }
                
                // Use standard server roles if no custom roles found
                var rolesList:Array<ServerRoleImpl> = [];
                
                // First check if we have roles in the provisioner definition
                if (provisionerDefinition != null && 
                    provisionerDefinition.metadata != null) {
                    
                    // Report provisioner metadata status
                    Logger.info('RolePage: Provisioner metadata found: ${provisionerDefinition.metadata != null}');
                    if (provisionerDefinition.metadata != null) {
                        var hasRoles = provisionerDefinition.metadata.roles != null && provisionerDefinition.metadata.roles.length > 0;
                        Logger.info('RolePage: Roles defined in metadata: ${hasRoles}');
                        if (hasRoles) {
                            Logger.info('RolePage: Found ${provisionerDefinition.metadata.roles.length} roles in provisioner metadata');
                        }
                    }
                    
                    // Process roles from provisioner.yml if available
                    if (provisionerDefinition.metadata.roles != null && 
                        provisionerDefinition.metadata.roles.length > 0) {
                        
                        // Create ServerRoleImpl objects from the provisioner.yml roles
                        var roles:Array<Dynamic> = cast provisionerDefinition.metadata.roles;
                        for (roleData in roles) {
                            try {
                                // Extract role properties
                                var roleName = Reflect.field(roleData, "name");
                                var roleLabel = Reflect.field(roleData, "label");
                                var roleDescription = Reflect.field(roleData, "description");
                                var roleDefaultEnabled = Reflect.field(roleData, "defaultEnabled");
                                
                                Logger.info('RolePage: Processing role: ${roleName} (${roleLabel})');
                                
                                // Check if this role already exists in the server's roles
                                var existingRole:RoleData = null;
                                for (r in _server.roles.value) {
                                    if (r.value == roleName) {
                                        existingRole = r;
                                        Logger.info('RolePage: Found existing role in server: ${roleName}');
                                        break;
                                    }
                                }
                                
                                // If the role doesn't exist in the server's roles, create a new one
                                if (existingRole == null) {
                                    Logger.info('RolePage: Creating new role for server: ${roleName}');
                                    existingRole = {
                                        value: roleName,
                                        enabled: roleDefaultEnabled == true,
                                        files: {
                                            installer: null,
                                            installerFileName: null,
                                            installerHash: null,
                                            installerVersion: null,
                                            hotfixes: [],
                                            installerHotFixHash: null,
                                            installerHotFixVersion: null,
                                            fixpacks: [],
                                            installerFixpackHash: null,
                                            installerFixpackVersion: null
                                        }
                                    };
                                    
                                    // Add the new role to the server's roles
                                    _server.roles.value.push(existingRole);
                                }
                                
                                // Get required and installers settings, if available
                                var roleRequired = Reflect.field(roleData, "required") == true;
                                var roleInstallers = Reflect.field(roleData, "installers");
                                
                                // Set required flag on the role data (which will make the checkbox disabled)
                                existingRole.isdefault = roleRequired;
                                
                                // Store installer settings in the role data for later use
                                if (roleInstallers != null) {
                                    Reflect.setField(existingRole, "showInstaller", Reflect.field(roleInstallers, "installer") == true);
                                    Reflect.setField(existingRole, "showFixpack", Reflect.field(roleInstallers, "fixpack") == true);
                                    Reflect.setField(existingRole, "showHotfix", Reflect.field(roleInstallers, "hotfix") == true);
                                } else {
                                    // Default values - don't show any installers for custom roles unless specified
                                    Reflect.setField(existingRole, "showInstaller", false);
                                    Reflect.setField(existingRole, "showFixpack", false);
                                    Reflect.setField(existingRole, "showHotfix", false);
                                }
                                
                                // Create the ServerRoleImpl with the role description
                                var roleImpl = new ServerRoleImpl(
                                    roleLabel,
                                    roleDescription,  // Use the description from provisioner.yml
                                    existingRole,
                                    [], // No hashes for custom roles
                                    [], // No hotfix hashes
                                    [], // No fixpack hashes
                                    "" // No file hint
                                );
                                
                                rolesList.push(roleImpl);
                                Logger.info('RolePage: Added custom role: ${roleLabel} with description: ${roleDescription}');
                            } catch (e) {
                                Logger.error('RolePage: Error processing role: ${e}');
                            }
                        }
                    } 
                    // If no roles defined in metadata, but server has basic domino roles, create those
                    else if (_server.roles.value.length > 0) {
                        Logger.info('RolePage: No custom roles found in metadata, using server\'s existing roles');
                        
                        // Create ServerRoleImpl objects for existing server roles
                        for (r in _server.roles.value) {
                            // Skip empty or invalid roles
                            if (r == null || r.value == null || r.value == "") continue;
                            
                            // Try to find a description for this role
                            var roleName = r.value;
                            var roleLabel = roleName; // Just use the role name directly
                            var roleDescription = 'Custom role: ${roleName}';
                            
                            var roleImpl = new ServerRoleImpl(
                                roleLabel,
                                roleDescription,
                                r,
                                [], // No hashes for custom roles
                                [], // No hotfix hashes 
                                [], // No fixpack hashes
                                "" // No file hint
                            );
                            
                            rolesList.push(roleImpl);
                            Logger.info('RolePage: Added existing server role: ${roleName}');
                        }
                    }
                }
                
                // If we have roles, display them
                if (rolesList.length > 0) {
                    // Add the custom roles to the list
                    for (i in rolesList) {
                        var item = new RolePickerItem(i, _server);
                        _listGroup.addChild(item);
                        
                        var line = new HLine();
                        line.layoutData = new VerticalLayoutData(100);
                        line.alpha = .5;
                        _listGroup.addChild(line);
                    }
                    
                    return; // Skip the default roles
                } else {
                    Logger.warning('RolePage: No roles found for custom provisioner, falling back to default roles');
                }
            }
            
            // Default behavior for built-in provisioners
            var coll = SuperHumanInstaller.getInstance().serverRolesCollection.copy();

            for (impl in coll) {
                for (r in _server.roles.value) {
                    if (r.value == impl.role.value) {
                        impl.role = r;
                    }
                }
            }

            for (i in coll) {
                var item = new RolePickerItem(i, _server);
                _listGroup.addChild(item);

                var line = new HLine();
                line.layoutData = new VerticalLayoutData(100);
                line.alpha = .5;
                _listGroup.addChild(line);
            }
        }
    }

    function _buttonCloseTriggered( e:TriggerEvent ) {
        // Set a flag indicating the user has completed role configuration
        if (_server != null) {
            if (_server.customProperties == null) {
                _server.customProperties = {};
            }
            
            // Mark roles as processed - set for all provisioner types
            // This flag is important for validation and should not be shown ANYWHERE
            Reflect.setField(_server.customProperties, "rolesProcessed", true);
            Logger.info('${this}: Marked roles as processed for server ID: ${_server.id}');
        }

        var event = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.CLOSE_ROLES );
        event.provisionerType = _server.provisioner.type;
        this.dispatchEvent( event );
    }

}

class RolePickerItem extends LayoutGroup {

    var _check:AdvancedCheckBox;
    var _descriptionLabel:Label;
    var _fixpackButton:Button;
    var _fixpackGroup:LayoutGroup;
    var _fixpackDropdown:PopUpListView;
    var _helpImage:AdvancedAssetLoader;
    var _hotfixButton:Button;
    var _hotfixGroup:LayoutGroup;
    var _hotfixDropdown:PopUpListView;
    var _installerButton:Button;
    var _installerDropdown:PopUpListView;
    var _installerDropdownGroup:LayoutGroup;
    var _installerGroup:LayoutGroup;
    var _installerGroupLayout:VerticalLayout;
    var _labelGroup:LayoutGroup;
    var _labelGroupLayout:HorizontalLayout;
    var _layout:VerticalLayout;
    var _roleImpl:ServerRoleImpl;
    var _selectInstallerLabel:Label;
    var _server:Server;
    var _fd:FileDialog;
    var _cachedFiles:Array<SuperHumanCachedFile>;
    var _allFilesGroup:LayoutGroup;

    public var role( get, never ):RoleData;
    function get_role() return _roleImpl.role;

    public function new( roleImpl:ServerRoleImpl, server:Server ) {

        super();

        _roleImpl = roleImpl;
        _server = server;

    }

    override function initialize() {

        super.initialize();

        this.minHeight = 50;
        this.layoutData = new VerticalLayoutData( 100 );

        _layout = new VerticalLayout();
        _layout.gap = GenesisApplicationTheme.GRID * 2;
        this.layout = _layout;

        _labelGroup = new LayoutGroup();
        _labelGroup.layoutData = new VerticalLayoutData( 100 );
        _labelGroupLayout = new HorizontalLayout();
        _labelGroupLayout.verticalAlign = VerticalAlign.MIDDLE;
        _labelGroupLayout.paddingRight = GenesisApplicationTheme.GRID * 2; // Add right padding for rightmost button
        _labelGroup.layout = _labelGroupLayout;
        _labelGroupLayout.gap = GenesisApplicationTheme.GRID;
        this.addChild( _labelGroup );

        _check = new AdvancedCheckBox( _roleImpl.name, _roleImpl.role.enabled );
        _check.enabled = !_roleImpl.role.isdefault;
        _check.addEventListener( Event.CHANGE, _checkSelected );
        _check.variant = GenesisApplicationTheme.CHECK_MEDIUM;
        _labelGroup.addChild( _check );

        _helpImage = GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_HELP );
        _helpImage.alpha = .33;
        _helpImage.toolTip = _roleImpl.description;
        _labelGroup.addChild( _helpImage );

        var spacer = new LayoutGroup();
        spacer.layoutData = new HorizontalLayoutData( 100 );
        _labelGroup.addChild( spacer );

        // Create a container for all dropdowns and browse buttons
        _allFilesGroup = new LayoutGroup();
        var allFilesLayout = new VerticalLayout();
        allFilesLayout.gap = GenesisApplicationTheme.GRID;
        _allFilesGroup.layout = allFilesLayout;
        _allFilesGroup.layoutData = new HorizontalLayoutData();
        _labelGroup.addChild(_allFilesGroup);
        
        // === INSTALLER ROW ===
        // Create installer dropdown group
        _installerDropdownGroup = new LayoutGroup();
        var dropdownLayout = new HorizontalLayout();
        dropdownLayout.gap = GenesisApplicationTheme.GRID;
        dropdownLayout.verticalAlign = VerticalAlign.MIDDLE;
        _installerDropdownGroup.layout = dropdownLayout;
        
        // Create installer dropdown
        _installerDropdown = new PopUpListView();
        _installerDropdown.prompt = "Select installer...";
        _installerDropdown.addEventListener(Event.CHANGE, _installerDropdownChanged);
        _installerDropdown.width = GenesisApplicationTheme.GRID * 30;
        _installerDropdown.layoutData = new HorizontalLayoutData(100); // Make dropdown take full width
        _installerDropdownGroup.addChild(_installerDropdown);
        
        // Add browse button next to dropdown
        _installerButton = new Button("Browse...");
        _installerButton.addEventListener(TriggerEvent.TRIGGER, _installerButtonTriggered);
        _installerButton.variant = GenesisApplicationTheme.BUTTON_SELECT_FILE;
        _installerDropdownGroup.addChild(_installerButton);
        
        // Add the installer group to the files container
        _allFilesGroup.addChild(_installerDropdownGroup);
        
        // === FIXPACK ROW ===
        // Create fixpack dropdown group
        _fixpackGroup = new LayoutGroup();
        _fixpackGroup.layout = new HorizontalLayout();
        cast(_fixpackGroup.layout, HorizontalLayout).gap = GenesisApplicationTheme.GRID;
        cast(_fixpackGroup.layout, HorizontalLayout).verticalAlign = VerticalAlign.MIDDLE;
        
        // Create fixpack dropdown
        _fixpackDropdown = new PopUpListView();
        _fixpackDropdown.prompt = "Select fixpack...";
        _fixpackDropdown.addEventListener(Event.CHANGE, _fixpackDropdownChanged);
        _fixpackDropdown.width = GenesisApplicationTheme.GRID * 30;
        _fixpackDropdown.layoutData = new HorizontalLayoutData(100);
        _fixpackGroup.addChild(_fixpackDropdown);
        
        // Add fixpack browse button
        _fixpackButton = new Button("Browse...");
        _fixpackButton.addEventListener(TriggerEvent.TRIGGER, _fixpackButtonTriggered);
        _fixpackButton.variant = GenesisApplicationTheme.BUTTON_SELECT_FILE;
        _fixpackGroup.addChild(_fixpackButton);
        
        // Add fixpack group to files container
        _allFilesGroup.addChild(_fixpackGroup);
        
        // === HOTFIX ROW ===
        // Create hotfix dropdown group
        _hotfixGroup = new LayoutGroup();
        _hotfixGroup.layout = new HorizontalLayout();
        cast(_hotfixGroup.layout, HorizontalLayout).gap = GenesisApplicationTheme.GRID;
        cast(_hotfixGroup.layout, HorizontalLayout).verticalAlign = VerticalAlign.MIDDLE;
        
        // Create hotfix dropdown
        _hotfixDropdown = new PopUpListView();
        _hotfixDropdown.prompt = "Select hotfix...";
        _hotfixDropdown.addEventListener(Event.CHANGE, _hotfixDropdownChanged);
        _hotfixDropdown.width = GenesisApplicationTheme.GRID * 30;
        _hotfixDropdown.layoutData = new HorizontalLayoutData(100);
        _hotfixGroup.addChild(_hotfixDropdown);
        
        // Add hotfix browse button
        _hotfixButton = new Button("Browse...");
        _hotfixButton.addEventListener(TriggerEvent.TRIGGER, _hotfixButtonTriggered);
        _hotfixButton.variant = GenesisApplicationTheme.BUTTON_SELECT_FILE;
        _hotfixGroup.addChild(_hotfixButton);
        
        // Add hotfix group to files container
        _allFilesGroup.addChild(_hotfixGroup);

        _selectInstallerLabel = new Label( LanguageManager.getInstance().getString( 'rolepage.role.noinstaller', _roleImpl.fileHint ) );
        _selectInstallerLabel.includeInLayout = _selectInstallerLabel.visible = false;
        _selectInstallerLabel.variant = GenesisApplicationTheme.LABEL_COPYRIGHT;
        this.addChild( _selectInstallerLabel );

        _installerGroupLayout = new VerticalLayout();
        _installerGroupLayout.gap = 2;

        _installerGroup = new LayoutGroup();
        _installerGroup.layoutData = new VerticalLayoutData( 100 );
        _installerGroup.layout = _installerGroupLayout;
        _installerGroup.visible = _installerGroup.includeInLayout = false;
        this.addChild( _installerGroup );

        updateData();

    }

    override function layoutGroup_removedFromStageHandler(event:Event) {

        _check.removeEventListener( Event.SELECT, _checkSelected );

        super.layoutGroup_removedFromStageHandler(event);

    }

    function _checkSelected( e:Event ) {

        _roleImpl.role.enabled = _check.selected;
        updateData();

    }

    public function updateData() {
        _installerGroup.removeChildren();
        _installerGroup.visible = _installerGroup.includeInLayout = false;
        
        // Populate all dropdowns with cached files
        _populateInstallerDropdown();
        _populateFixpackDropdown();
        _populateHotfixDropdown();
        
        // Check if this is a custom role with installer settings
        var showInstaller = true;
        var showFixpack = true;
        var showHotfix = true;
        
        // Check for custom installer settings
        if (Reflect.hasField(_roleImpl.role, "showInstaller")) {
            // Get installer settings from role configuration
            showInstaller = Reflect.field(_roleImpl.role, "showInstaller");
            showFixpack = Reflect.field(_roleImpl.role, "showFixpack");
            showHotfix = Reflect.field(_roleImpl.role, "showHotfix");
            
            // Log the settings for debugging
            Logger.info('${this}: Role ${_roleImpl.role.value} settings: installer=${showInstaller}, fixpack=${showFixpack}, hotfix=${showHotfix}');
        }
        
        // Show/hide all file selection groups based on role being enabled
        _allFilesGroup.includeInLayout = _allFilesGroup.visible = _roleImpl.role.enabled;
        
        // Show/hide each row based on settings
        _installerDropdownGroup.includeInLayout = _installerDropdownGroup.visible = showInstaller; 
        _fixpackGroup.includeInLayout = _fixpackGroup.visible = showFixpack;
        _hotfixGroup.includeInLayout = _hotfixGroup.visible = showHotfix;
        
        // All buttons should be enabled if the role is enabled (redundant but explicit)
        _installerButton.enabled = _roleImpl.role.enabled;
        _fixpackButton.enabled = _roleImpl.role.enabled;
        _hotfixButton.enabled = _roleImpl.role.enabled;
        
        // Show installer file if one is selected
        if (_roleImpl.role.files.installer != null) {
            var item = new RolePickerFileItem(_roleImpl.role.files.installer);
            item.addEventListener(TriggerEvent.TRIGGER, _fileItemTriggered);
            _installerGroup.addChild(item);
            _installerButton.enabled = false;
            _installerGroup.visible = _installerGroup.includeInLayout = true;
            _selectInstallerLabel.visible = _selectInstallerLabel.includeInLayout = false;
        } else if (showInstaller) {
            _selectInstallerLabel.visible = _selectInstallerLabel.includeInLayout = true;
        } else {
            // For custom roles where showInstaller is false, still show the description
            // Check if this is a custom role with a description
            var isCustomRole = !Reflect.hasField(_roleImpl.role, "isdefault") || 
                              (Reflect.hasField(_roleImpl.role, "showInstaller") && !Reflect.field(_roleImpl.role, "showInstaller"));
            
            if (isCustomRole && _roleImpl.description != null && _roleImpl.description.length > 0) {
                // Update the label to show the description instead of installer text
                _selectInstallerLabel.text = _roleImpl.description;
                _selectInstallerLabel.visible = _selectInstallerLabel.includeInLayout = true;
            } else {
                _selectInstallerLabel.visible = _selectInstallerLabel.includeInLayout = false;
            }
        }
        
        // Show hotfix files if any are selected
        if (_roleImpl.role.files.hotfixes != null && _roleImpl.role.files.hotfixes.length > 0) {
            for (hf in _roleImpl.role.files.hotfixes) {
                var item = new RolePickerFileItem(hf, RolePickerFileType.Hotfix);
                item.addEventListener(TriggerEvent.TRIGGER, _fileItemTriggered);
                _installerGroup.addChild(item);
                _installerGroup.visible = _installerGroup.includeInLayout = true;
            }
        }
        
        // Show fixpack files if any are selected
        if (_roleImpl.role.files.fixpacks != null && _roleImpl.role.files.fixpacks.length > 0) {
            for (hf in _roleImpl.role.files.fixpacks) {
                var item = new RolePickerFileItem(hf, RolePickerFileType.Fixpack);
                item.addEventListener(TriggerEvent.TRIGGER, _fileItemTriggered);
                _installerGroup.addChild(item);
                _installerGroup.visible = _installerGroup.includeInLayout = true;
            }
        }
    }

    function _fileItemTriggered( e:TriggerEvent ) {

        var item:RolePickerFileItem = cast e.target;
        item.removeEventListener( TriggerEvent.TRIGGER, _fileItemTriggered );
        item.parent.removeChild( item );

        switch ( item.type ) {

            case RolePickerFileType.Hotfix:
                _roleImpl.role.files.hotfixes.remove( item.path );

            case RolePickerFileType.Fixpack:
                _roleImpl.role.files.fixpacks.remove( item.path );

            default:
                _roleImpl.role.files.installer = null;

        }

        updateData();

    }

    // Single dialog flag to manage all file dialogs
    private var _isFileDialogOpen:Bool = false;
    
    /**
     * Populate the installer dropdown with cached files
     */
    private function _populateInstallerDropdown() {
        // Temporarily remove event listener to prevent change events during initialization
        _installerDropdown.removeEventListener(Event.CHANGE, _installerDropdownChanged);
        
        // Create a new collection for the dropdown
        var dropdownItems = new ArrayCollection<Dynamic>();
        
        // Get cached files for this role type
        _cachedFiles = SuperHumanFileCache.getInstance().getFilesByRoleAndType(_roleImpl.role.value, "installers");
        
        // Filter to only include files that actually exist
        var validCachedFiles = _cachedFiles.filter(function(file) return file.exists);
        
        // Add a placeholder prompt item if there are no valid cached files
        if (validCachedFiles.length == 0) {
            dropdownItems.add({
                label: "No valid cached files available",
                file: null,
                isPlaceholder: true
            });
            
            // Log info about filtered files
            if (_cachedFiles.length > 0) {
                Logger.info('${this}: Filtered out ${_cachedFiles.length - validCachedFiles.length} missing files from dropdown');
            }
        }
        
        // Add each valid cached file to the dropdown with improved formatting
        for (cachedFile in validCachedFiles) {
            var displayName = '';
            
            // Format the filename more clearly
            if (cachedFile.originalFilename != null && cachedFile.originalFilename != "") {
                displayName = '${cachedFile.originalFilename}';
            } else {
                // Fallback in case original filename is missing
                displayName = Path.withoutDirectory(cachedFile.path);
            }
            
            // Add version in a clear format if available
            if (cachedFile.version != null && cachedFile.version.fullVersion != null) {
                displayName += ' - v${cachedFile.version.fullVersion}';
            }
            
            dropdownItems.add({
                label: displayName,
                file: cachedFile
            });
        }
        
        // Set the dropdown data provider
        _installerDropdown.dataProvider = dropdownItems;
        _installerDropdown.itemToText = (item) -> item.label;
        
        // Save the intended selection index for later
        var indexToSelect = -1;
        
        // If a file is already selected, try to select it in the dropdown
        if (_roleImpl.role.files.installer != null && _roleImpl.role.files.installerHash != null) {
            // Find the cached file with matching hash
            for (i in 0...dropdownItems.length) {
                var item = dropdownItems.get(i);
                if (item.file != null && item.file.hash == _roleImpl.role.files.installerHash) {
                    indexToSelect = i;
                    break;
                }
            }
        }
        
        // Apply selection without triggering change events
        _installerDropdown.selectedIndex = indexToSelect;
        
        // Restore the event listener after setting the selection
        _installerDropdown.addEventListener(Event.CHANGE, _installerDropdownChanged);
    }
    
    /**
     * Handle installer dropdown selection change
     */
    private function _installerDropdownChanged(e:Event) {
        // Guard against invalid selection
        if (_installerDropdown.selectedItem == null) return;
        if (_installerDropdown.selectedIndex == -1) return;
        
        // Guard against selection events while a dialog is open
        if (_isFileDialogOpen) {
            Logger.info('${this}: Ignoring dropdown change event while dialog is open');
            return;
        }
        
        var selectedItem = _installerDropdown.selectedItem;
        
        // Skip placeholder items
        if (Reflect.hasField(selectedItem, "isPlaceholder") && selectedItem.isPlaceholder) {
            return;
        }
        
        var selectedFile = selectedItem.file;
        if (selectedFile == null) return;
        
        if (!selectedFile.exists) {
            // File exists in registry but not in cache
            _isFileDialogOpen = true; // Set flag before showing dialog
            Alert.show(
                "This file is registered but missing from the cache. Would you like to locate it?",
                "Missing File",
                ["Locate File", "Cancel"],
                (state) -> {
                    if (state.index == 0) {
                        // User wants to locate the file - dialog flag managed by _showFileDialog
                        _showFileDialog("installers", selectedFile.hash);
                    } else {
                        // Reset dialog flag and revert selection
                        _isFileDialogOpen = false;
                        _populateInstallerDropdown();
                    }
                }
            );
            return;
        }
        
        // File exists in cache, use it
        _roleImpl.role.files.installer = selectedFile.path;
        _roleImpl.role.files.installerFileName = selectedFile.originalFilename;
        _roleImpl.role.files.installerHash = selectedFile.hash;
        _roleImpl.role.files.installerVersion = selectedFile.version;
        
        updateData();
    }
    
    /**
     * Populate the fixpack dropdown with cached files
     */
    private function _populateFixpackDropdown() {
        // Temporarily remove event listener to prevent change events during initialization
        _fixpackDropdown.removeEventListener(Event.CHANGE, _fixpackDropdownChanged);
        
        // Create a new collection for the dropdown
        var dropdownItems = new ArrayCollection<Dynamic>();
        
        // Get cached files for this role type
        var cachedFixpacks = SuperHumanFileCache.getInstance().getFilesByRoleAndType(_roleImpl.role.value, "fixpacks");
        
        // Filter to only include files that actually exist
        var validCachedFiles = cachedFixpacks.filter(function(file) return file.exists);
        
        // Add a placeholder prompt item if there are no valid cached files
        if (validCachedFiles.length == 0) {
            dropdownItems.add({
                label: "No valid cached fixpacks available",
                file: null,
                isPlaceholder: true
            });
            
            // Log info about filtered files
            if (cachedFixpacks.length > 0) {
                Logger.info('${this}: Filtered out ${cachedFixpacks.length - validCachedFiles.length} missing fixpack files from dropdown');
            }
        }
        
        // Add each valid cached file to the dropdown with improved formatting
        for (cachedFile in validCachedFiles) {
            var displayName = '';
            
            // Format the filename more clearly
            if (cachedFile.originalFilename != null && cachedFile.originalFilename != "") {
                displayName = '${cachedFile.originalFilename}';
            } else {
                // Fallback in case original filename is missing
                displayName = Path.withoutDirectory(cachedFile.path);
            }
            
            // Add version in a clear format if available
            if (cachedFile.version != null && cachedFile.version.fullVersion != null) {
                displayName += ' - v${cachedFile.version.fullVersion}';
            }
            
            dropdownItems.add({
                label: displayName,
                file: cachedFile
            });
        }
        
        // Set the dropdown data provider
        _fixpackDropdown.dataProvider = dropdownItems;
        _fixpackDropdown.itemToText = (item) -> item.label;
        
        // Restore the event listener after setting the selection
        _fixpackDropdown.addEventListener(Event.CHANGE, _fixpackDropdownChanged);
    }
    
    /**
     * Handle fixpack dropdown selection change
     */
    private function _fixpackDropdownChanged(e:Event) {
        // Guard against invalid selection
        if (_fixpackDropdown.selectedItem == null) return;
        if (_fixpackDropdown.selectedIndex == -1) return;
        
        // Guard against selection events while a dialog is open
        if (_isFileDialogOpen) {
            Logger.info('${this}: Ignoring fixpack dropdown change event while dialog is open');
            return;
        }
        
        var selectedItem = _fixpackDropdown.selectedItem;
        
        // Skip placeholder items
        if (Reflect.hasField(selectedItem, "isPlaceholder") && selectedItem.isPlaceholder) {
            return;
        }
        
        var selectedFile = selectedItem.file;
        if (selectedFile == null) return;
        
        if (!selectedFile.exists) {
            // File exists in registry but not in cache
            _isFileDialogOpen = true; // Set flag before showing dialog
            Alert.show(
                "This fixpack file is registered but missing from the cache. Would you like to locate it?",
                "Missing Fixpack File",
                ["Locate File", "Cancel"],
                (state) -> {
                    if (state.index == 0) {
                        // User wants to locate the file - dialog flag managed by _showFileDialog
                        _showFileDialog("fixpacks", selectedFile.hash);
                    } else {
                        // Reset dialog flag and revert selection
                        _isFileDialogOpen = false;
                        _populateFixpackDropdown();
                    }
                }
            );
            return;
        }
        
        // Add the fixpack to the role's fixpacks list
        if (!_roleImpl.role.files.fixpacks.contains(selectedFile.path)) {
            _roleImpl.role.files.fixpacks.push(selectedFile.path);
            _roleImpl.role.files.installerFixpackHash = selectedFile.hash;
            _roleImpl.role.files.installerFixpackVersion = selectedFile.version;
            
            updateData();
        }
    }
    
    /**
     * Populate the hotfix dropdown with cached files
     */
    private function _populateHotfixDropdown() {
        // Temporarily remove event listener to prevent change events during initialization
        _hotfixDropdown.removeEventListener(Event.CHANGE, _hotfixDropdownChanged);
        
        // Create a new collection for the dropdown
        var dropdownItems = new ArrayCollection<Dynamic>();
        
        // Get cached files for this role type
        var cachedHotfixes = SuperHumanFileCache.getInstance().getFilesByRoleAndType(_roleImpl.role.value, "hotfixes");
        
        // Filter to only include files that actually exist
        var validCachedFiles = cachedHotfixes.filter(function(file) return file.exists);
        
        // Add a placeholder prompt item if there are no valid cached files
        if (validCachedFiles.length == 0) {
            dropdownItems.add({
                label: "No valid cached hotfixes available",
                file: null,
                isPlaceholder: true
            });
            
            // Log info about filtered files
            if (cachedHotfixes.length > 0) {
                Logger.info('${this}: Filtered out ${cachedHotfixes.length - validCachedFiles.length} missing hotfix files from dropdown');
            }
        }
        
        // Add each valid cached file to the dropdown with improved formatting
        for (cachedFile in validCachedFiles) {
            var displayName = '';
            
            // Format the filename more clearly
            if (cachedFile.originalFilename != null && cachedFile.originalFilename != "") {
                displayName = '${cachedFile.originalFilename}';
            } else {
                // Fallback in case original filename is missing
                displayName = Path.withoutDirectory(cachedFile.path);
            }
            
            // Add version in a clear format if available
            if (cachedFile.version != null && cachedFile.version.fullVersion != null) {
                displayName += ' - v${cachedFile.version.fullVersion}';
            }
            
            dropdownItems.add({
                label: displayName,
                file: cachedFile
            });
        }
        
        // Set the dropdown data provider
        _hotfixDropdown.dataProvider = dropdownItems;
        _hotfixDropdown.itemToText = (item) -> item.label;
        
        // Restore the event listener after setting the selection
        _hotfixDropdown.addEventListener(Event.CHANGE, _hotfixDropdownChanged);
    }
    
    /**
     * Handle hotfix dropdown selection change
     */
    private function _hotfixDropdownChanged(e:Event) {
        // Guard against invalid selection
        if (_hotfixDropdown.selectedItem == null) return;
        if (_hotfixDropdown.selectedIndex == -1) return;
        
        // Guard against selection events while a dialog is open
        if (_isFileDialogOpen) {
            Logger.info('${this}: Ignoring hotfix dropdown change event while dialog is open');
            return;
        }
        
        var selectedItem = _hotfixDropdown.selectedItem;
        
        // Skip placeholder items
        if (Reflect.hasField(selectedItem, "isPlaceholder") && selectedItem.isPlaceholder) {
            return;
        }
        
        var selectedFile = selectedItem.file;
        if (selectedFile == null) return;
        
        if (!selectedFile.exists) {
            // File exists in registry but not in cache
            _isFileDialogOpen = true; // Set flag before showing dialog
            Alert.show(
                "This hotfix file is registered but missing from the cache. Would you like to locate it?",
                "Missing Hotfix File",
                ["Locate File", "Cancel"],
                (state) -> {
                    if (state.index == 0) {
                        // User wants to locate the file - dialog flag managed by _showFileDialog
                        _showFileDialog("hotfixes", selectedFile.hash);
                    } else {
                        // Reset dialog flag and revert selection
                        _isFileDialogOpen = false;
                        _populateHotfixDropdown();
                    }
                }
            );
            return;
        }
        
        // Add the hotfix to the role's hotfixes list
        if (!_roleImpl.role.files.hotfixes.contains(selectedFile.path)) {
            _roleImpl.role.files.hotfixes.push(selectedFile.path);
            _roleImpl.role.files.installerHotFixHash = selectedFile.hash;
            _roleImpl.role.files.installerHotFixVersion = selectedFile.version;
            
            updateData();
        }
    }
    
    /**
     * Handle browse button click - open the file dialog
     */
    function _installerButtonTriggered(e:TriggerEvent) {
        _showFileDialog("installers");
    }

    /**
     * Unified file dialog handler for selecting a file
     * @param fileType The type of file (installers, hotfixes, fixpacks)
     * @param expectedHash Optional hash to verify when locating a missing file
     * @return True if dialog was opened, false if already open
     */
    private function _showFileDialog(fileType:String, ?expectedHash:String):Bool {
        // Guard against multiple dialogs with centralized flag
        if (_fd != null || _isFileDialogOpen) {
            Logger.warning('${this}: Attempted to open file dialog while another dialog is active');
            return false;
        }
        
        // Set flag to indicate dialog is open
        _isFileDialogOpen = true;
        Logger.info('${this}: Opening file dialog for ${fileType}');
        
        var dir = (SuperHumanInstaller.getInstance().config.user.lastuseddirectory != null) ? 
            SuperHumanInstaller.getInstance().config.user.lastuseddirectory : System.userDirectory;
        
        _fd = new FileDialog();
        var currentDir:String;
        
        _fd.onSelect.add(path -> {
            try {
                var currentPath = new Path(path);
                var fullFileName = currentPath.file + "." + currentPath.ext;
                
                currentDir = Path.directory(path);
                if (currentDir != null) SuperHumanInstaller.getInstance().config.user.lastuseddirectory = currentDir;
                
                // Calculate hash
                var fileHash = SuperHumanHashes.calculateMD5(path);
                
                if (expectedHash != null && fileHash != expectedHash) {
                    // Hash doesn't match expected value for missing file
                    Alert.show(
                        "The selected file doesn't match the expected hash. Would you like to use it anyway?",
                        "Hash Mismatch",
                        ["Use Anyway", "Cancel"],
                        (state) -> {
                            if (state.index == 0) {
                                // Use the file anyway and add to cache
                                _processSelectedFile(path, fullFileName, fileHash, fileType);
                            }
                            // Reset dialog flag regardless of choice
                            _isFileDialogOpen = false;
                        }
                    );
                } else {
                    // Process the selected file
                    _processSelectedFile(path, fullFileName, fileHash, fileType);
                    // Reset dialog flag after processing
                    _isFileDialogOpen = false;
                }
            } catch (e) {
                Logger.error('Error processing selected file: ${e}');
                _isFileDialogOpen = false; // Always reset flag
            }
            
            // Clean up dialog resources
            _fd.onSelect.removeAll();
            _fd.onCancel.removeAll();
            _fd = null;
        });
        
        _fd.onCancel.add(() -> {
            Logger.info('${this}: File dialog cancelled');
            _fd.onCancel.removeAll();
            _fd.onSelect.removeAll();
            _fd = null;
            // Reset dialog flag on cancel
            _isFileDialogOpen = false;
        });
        
        var dialogTitle = "Select File";
        switch (fileType) {
            case "installers":
                dialogTitle = LanguageManager.getInstance().getString('rolepage.role.locateinstaller', _roleImpl.name);
            case "hotfixes":
                dialogTitle = LanguageManager.getInstance().getString('rolepage.role.locatehotfix', _roleImpl.name);
            case "fixpacks":
                dialogTitle = LanguageManager.getInstance().getString('rolepage.role.locatefixpack', _roleImpl.name);
        }
        
        _fd.browse(FileDialogType.OPEN, null, dir + "/", dialogTitle);
        return true;
    }
    
    /**
     * Process a selected file and handle caching
     * @param path Path to the file
     * @param fullFileName Filename with extension
     * @param fileHash Calculated hash of the file
     * @param fileType Type of file (installers, hotfixes, fixpacks)
     */
    private function _processSelectedFile(path:String, fullFileName:String, fileHash:String, fileType:String) {
        // Check if this is a custom role - if yes, skip hash checking
        var isCustomRole = false;
        var hashes:Array<String> = [];
        var validHash = false;
        var version = null;
        
        try {
            // If the role doesn't exist in SuperHumanHashes, this will be null
            switch (fileType) {
                case "installers":
                    hashes = SuperHumanHashes.getInstallersHashes(_roleImpl.role.value);
                    if (fileHash != null && hashes != null && hashes.indexOf(fileHash) >= 0) {
                        version = SuperHumanHashes.getInstallerVersion(_roleImpl.role.value, fileHash);
                        validHash = true;
                    }
                case "hotfixes":
                    hashes = SuperHumanHashes.getHotFixesHashes(_roleImpl.role.value);
                    if (fileHash != null && hashes != null && hashes.indexOf(fileHash) >= 0) {
                        version = SuperHumanHashes.getHotfixesVersion(_roleImpl.role.value, fileHash);
                        validHash = true;
                    }
                case "fixpacks":
                    hashes = SuperHumanHashes.getFixPacksHashes(_roleImpl.role.value);
                    if (fileHash != null && hashes != null && hashes.indexOf(fileHash) >= 0) {
                        version = SuperHumanHashes.getFixpacksVersion(_roleImpl.role.value, fileHash);
                        validHash = true;
                    }
            }
            isCustomRole = (hashes == null || hashes.length == 0);
            
            Logger.info('${this}: Processing file (${fileType}): ${Path.withoutDirectory(path)}, hash: ${fileHash}, valid hash: ${validHash}, custom role: ${isCustomRole}');
        } catch (e) {
            Logger.error('${this}: Error checking hash validity: ${e}');
            isCustomRole = true;
        }
        
        // Check if file exists in cache registry
        var cachedFile = SuperHumanFileCache.getInstance().getFileByHash(fileHash);
        
        // If file exists in registry AND physically exists, use it directly
        if (cachedFile != null && cachedFile.exists) {
            Logger.info('${this}: Using existing cached file: ${cachedFile.path}');
            _useFileBasedOnType(cachedFile.path, fullFileName, cachedFile.hash, cachedFile.version, fileType);
            return;
        }
        
        // If file exists in registry but doesn't physically exist, offer to add it to cache
        if (cachedFile != null && !cachedFile.exists) {
            Logger.info('${this}: File registered in cache but missing from disk: ${cachedFile.path}');
            Alert.show(
                "This file has a valid hash but is missing from the cache directory. Would you like to add it to the cache?",
                "Add to Cache",
                ["Add to Cache", "Use Without Caching"],
                (state) -> {
                    if (state.index == 0) {
                        // Add to cache
                        var result = SuperHumanFileCache.getInstance().addFile(
                            path, 
                            _roleImpl.role.value, 
                            fileType, 
                            version
                        );
                        
                        if (result != null) {
                            _useFileBasedOnType(result.path, fullFileName, result.hash, result.version, fileType);
                        } else {
                            // Failed to add to cache, use directly
                            _useFileBasedOnType(path, fullFileName, fileHash, version, fileType);
                        }
                    } else {
                        // Use without caching
                        _useFileBasedOnType(path, fullFileName, fileHash, version, fileType);
                    }
                }
            );
            return;
        }
        
        if (isCustomRole) {
            Logger.info('${this}: Handling file for custom role (no hash checking required)');
            // For custom roles, just add the file without hash checking
            // But first ask if the user wants to add it to the cache
            Alert.show(
                "Would you like to add this file to the cache for future use?",
                "Add to Cache",
                ["Add to Cache", "Use Without Caching"],
                (state) -> {
                    if (state.index == 0) {
                        // Add to cache
                        var version = {};
                        var result = SuperHumanFileCache.getInstance().addFile(
                            path, 
                            _roleImpl.role.value, 
                            fileType, 
                            version
                        );
                        
                        if (result != null) {
                            _useFileBasedOnType(result.path, fullFileName, result.hash, result.version, fileType);
                        } else {
                            // Failed to add to cache, use directly
                            _useFileBasedOnType(path, fullFileName, fileHash, null, fileType);
                        }
                    } else {
                        // Use without caching
                        _useFileBasedOnType(path, fullFileName, fileHash, null, fileType);
                    }
                }
            );
        } else if (validHash) {
            // Standard role with valid hash but not in cache - offer to add
            Logger.info('${this}: Standard role with valid hash but not in cache: ${Path.withoutDirectory(path)}');
            Alert.show(
                "This file has a valid hash. Would you like to add it to the cache for future use?",
                "Add to Cache",
                ["Add to Cache", "Use Without Caching"],
                (state) -> {
                    if (state.index == 0) {
                        // Add to cache
                        var result = SuperHumanFileCache.getInstance().addFile(
                            path, 
                            _roleImpl.role.value, 
                            fileType, 
                            version
                        );
                        
                        if (result != null) {
                            _useFileBasedOnType(result.path, fullFileName, result.hash, result.version, fileType);
                        } else {
                            // Failed to add to cache, use directly
                            _useFileBasedOnType(path, fullFileName, fileHash, version, fileType);
                        }
                    } else {
                        // Use without caching
                        _useFileBasedOnType(path, fullFileName, fileHash, version, fileType);
                    }
                }
            );
        } else {
            // Standard role with invalid hash - warn user
            Logger.info('${this}: Standard role with invalid hash: ${Path.withoutDirectory(path)}');
            
            var alertText = "";
            switch (fileType) {
                case "installers":
                    alertText = LanguageManager.getInstance().getString('alert.installerhash.text', _roleImpl.name);
                case "hotfixes":
                    alertText = LanguageManager.getInstance().getString('alert.hotfixhash.text', _roleImpl.name);
                case "fixpacks":
                    alertText = LanguageManager.getInstance().getString('alert.fixpackhash.text', _roleImpl.name);
            }
            
            var alertTitle = "";
            switch (fileType) {
                case "installers":
                    alertTitle = LanguageManager.getInstance().getString('alert.installerhash.title');
                case "hotfixes":
                    alertTitle = LanguageManager.getInstance().getString('alert.hotfixhash.title');
                case "fixpacks":
                    alertTitle = LanguageManager.getInstance().getString('alert.fixpackhash.title');
            }
            
            Alert.show(
                alertText,
                alertTitle,
                ["Add to Cache Anyway", "Use Without Caching", "Cancel"],
                (state) -> {
                    switch (state.index) {
                        case 0:
                            // Add to cache anyway
                            var result = SuperHumanFileCache.getInstance().addFile(
                                path, 
                                _roleImpl.role.value, 
                                fileType, 
                                {}
                            );
                            
                            if (result != null) {
                                _useFileBasedOnType(result.path, fullFileName, result.hash, result.version, fileType);
                            } else {
                                // Failed to add to cache, use directly
                                _useFileBasedOnType(path, fullFileName, fileHash, null, fileType);
                            }
                        
                        case 1:
                            // Use without caching
                            _useFileBasedOnType(path, fullFileName, fileHash, null, fileType);
                            
                        default:
                            // Cancel - do nothing
                    }
                }
            );
        }
    }
    
    /**
     * Apply the selected file to the role based on file type
     */
    private function _useFileBasedOnType(path:String, filename:String, hash:String, version:Dynamic, fileType:String) {
        switch (fileType) {
            case "installers":
                _roleImpl.role.files.installer = path;
                _roleImpl.role.files.installerFileName = filename;
                _roleImpl.role.files.installerHash = hash;
                _roleImpl.role.files.installerVersion = version;
                
            case "hotfixes":
                if (!_roleImpl.role.files.hotfixes.contains(path)) {
                    _roleImpl.role.files.hotfixes.push(path);
                    _roleImpl.role.files.installerHotFixHash = hash;
                    _roleImpl.role.files.installerHotFixVersion = version;
                }
                
            case "fixpacks":
                if (!_roleImpl.role.files.fixpacks.contains(path)) {
                    _roleImpl.role.files.fixpacks.push(path);
                    _roleImpl.role.files.installerFixpackHash = hash;
                    _roleImpl.role.files.installerFixpackVersion = version;
                }
        }
        
        updateData();
    }

    /**
     * Handler for hotfix button - uses the unified file dialog
     */
    function _hotfixButtonTriggered(e:TriggerEvent) {
        _showFileDialog("hotfixes");
    }

    /**
     * Handler for fixpack button - uses the unified file dialog
     */
    function _fixpackButtonTriggered(e:TriggerEvent) {
        _showFileDialog("fixpacks");
    }

}

class RolePickerFileItem extends LayoutGroup {

    var _deleteButton:Button;
    var _isHotfix:Bool;
    var _isFixpack:Bool;
    var _label:Label;
    var _layout:HorizontalLayout;
    var _path:String;
    var _type:RolePickerFileType;

    public var path( get, never ):String;
    function get_path() return _path;

    public var type( get, never ):RolePickerFileType;
    function get_type() return _type;

    public function new( path:String, type:RolePickerFileType = RolePickerFileType.Installer ) {

        super();

        _path = path;
        _type = type;

    }

    override function initialize() {

        super.initialize();

        var r = new RectangleSkin( FillStyle.SolidColor( 0x191919 ) );
        r.cornerRadius = 12;
        this.backgroundSkin = r;

        _layout = new HorizontalLayout();
        _layout.gap = GenesisApplicationTheme.GRID;
        _layout.setPadding( GenesisApplicationTheme.GRID / 2 );
        _layout.paddingLeft = _layout.paddingRight = GenesisApplicationTheme.GRID;
        _layout.verticalAlign = VerticalAlign.MIDDLE;
        this.layout = _layout;

        _deleteButton = new Button();
        _deleteButton.variant = GenesisApplicationTheme.BUTTON_SMALL;
        _deleteButton.icon = GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_DESTROY_SMALL );
        _deleteButton.layoutData = new HorizontalLayoutData();
        _deleteButton.toolTip = LanguageManager.getInstance().getString( 'rolepage.role.removefile' );
        _deleteButton.addEventListener( TriggerEvent.TRIGGER, _deleteButtonTriggered );
        this.addChild( _deleteButton );

        _label = new Label();

        switch ( _type ) {

            case RolePickerFileType.Fixpack:
                _label.text = LanguageManager.getInstance().getString( 'rolepage.role.fixpackfile', Path.withoutDirectory( _path ) );

            case RolePickerFileType.Hotfix:
                _label.text = LanguageManager.getInstance().getString( 'rolepage.role.hotfixfile', Path.withoutDirectory( _path ) );

            default:
                _label.text = LanguageManager.getInstance().getString( 'rolepage.role.installerfile', Path.withoutDirectory( _path ) );

        }

        _label.variant = GenesisApplicationTheme.LABEL_COPYRIGHT;
        _label.layoutData = new HorizontalLayoutData( 100 );
        this.addChild( _label );

    }

    override function feathersControl_removedFromStageHandler(event:Event) {

        super.feathersControl_removedFromStageHandler(event);

        if ( _deleteButton != null ) _deleteButton.removeEventListener( TriggerEvent.TRIGGER, _deleteButtonTriggered );

    }

    function _deleteButtonTriggered( e:TriggerEvent ) {

        this.dispatchEvent( e );

    }

}

enum RolePickerFileType {

    Fixpack;
    Hotfix;
    Installer;

}
