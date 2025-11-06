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
import feathers.controls.TextCallout;
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
import openfl.events.MouseEvent;
import openfl.net.URLRequest;
import openfl.Lib;
import prominic.sys.io.FileTools;
import superhuman.events.SuperHumanApplicationEvent;
import superhuman.managers.ProvisionerManager;
import superhuman.server.Server;
import superhuman.server.data.RoleData;
import superhuman.server.provisioners.ProvisionerType;
import superhuman.server.roles.ServerRoleImpl;
import superhuman.theme.SuperHumanInstallerTheme;

class RolePage extends Page {

    final _w:Float = GenesisApplicationTheme.GRID * 140;
    
    // Role dependency definitions
    private static final ROLES_DEPEND_ON_DOMINO:Array<String> = ["verse", "leap"];
    private static final ROLES_VERSION_DEPENDENT:Array<String> = ["nomadweb", "traveler", "domino-rest-api"];
    
    // Domino selection tracking
    private var _dominoInstallerSelected:Bool = false;
    private var _dominoInstallerVersion:Dynamic = null;
    private var _dominoRole:RoleData = null;
    private var _roleFixpacks:Map<String, Array<String>> = new Map();

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
    
    // Header elements
    var _titleGroup:LayoutGroup;
    var _titleLabel:Label;
    var _descriptionLabel:Label;
    var _licenseLink:Label;
    
    public function new() {

        super();

    }

    override function initialize() {

        super.initialize();

        _content.width = _w;
        _content.maxWidth = GenesisApplicationTheme.GRID * 150;
        
        // Create header section
        _titleGroup = new LayoutGroup();
        var titleGroupLayout = new VerticalLayout();
        titleGroupLayout.horizontalAlign = HorizontalAlign.CENTER;
        titleGroupLayout.gap = GenesisApplicationTheme.GRID;
        _titleGroup.layout = titleGroupLayout;
        _titleGroup.width = _w;
        _titleGroup.layoutData = new VerticalLayoutData(100);
        this.addChild(_titleGroup);
        
        // Add title label
        _titleLabel = new Label();
        _titleLabel.text = "ROLES";
        _titleLabel.variant = GenesisApplicationTheme.LABEL_LARGE;
        _titleGroup.addChild(_titleLabel);
        
        // Add description about what roles are for
        _descriptionLabel = new Label();
        _descriptionLabel.text = "Select the roles you want to enable for your server. Each role provides specific functionality and may require installation files.";
        _descriptionLabel.wordWrap = true;
        _descriptionLabel.width = _w;
        _titleGroup.addChild(_descriptionLabel);
        
        // Add horizontal line separator
        var line = new HLine();
        line.width = _w;
        this.addChild(line);

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
        
        // Check if Domino installer is selected and update dependency info
        checkDominoInstaller();

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
                // Create RolePickerItem with dependency info
                var isDependentRole = ROLES_DEPEND_ON_DOMINO.indexOf(i.role.value.toLowerCase()) >= 0;
                var isVersionDependentRole = ROLES_VERSION_DEPENDENT.indexOf(i.role.value.toLowerCase()) >= 0;
                
                // Add extra logging for dependency information
                Logger.info('RolePage: Creating custom role item for ${i.role.value}, isDependentRole=${isDependentRole}, isVersionDependentRole=${isVersionDependentRole}, dominoSelected=${_dominoInstallerSelected}');
                
                // Add extra logging for dependency information
                Logger.info('RolePage: Creating standard role item for ${i.role.value}, isDependentRole=${isDependentRole}, isVersionDependentRole=${isVersionDependentRole}, dominoSelected=${_dominoInstallerSelected}');
                
                var item = new RolePickerItem(
                    i, 
                    _server, 
                    isDependentRole,
                    isVersionDependentRole,
                    _dominoInstallerSelected,
                    _dominoInstallerVersion,
                    _roleFixpacks
                );
                
                // Listen for installer changes to update dependencies
                item.addEventListener(Event.CHANGE, onRoleItemChanged);
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
                        
                        // Find and store the Domino role for dependency checking
                        if (r.value.toLowerCase() == "domino") {
                            _dominoRole = r;
                        }
                    }
                }
            }

            for (i in coll) {
                // Create RolePickerItem with dependency info
                var isDependentRole = ROLES_DEPEND_ON_DOMINO.indexOf(i.role.value.toLowerCase()) >= 0;
                var isVersionDependentRole = ROLES_VERSION_DEPENDENT.indexOf(i.role.value.toLowerCase()) >= 0;
                
                var item = new RolePickerItem(
                    i, 
                    _server, 
                    isDependentRole,
                    isVersionDependentRole,
                    _dominoInstallerSelected,
                    _dominoInstallerVersion,
                    _roleFixpacks
                );
                
                // Listen for installer changes to update dependencies
                item.addEventListener(Event.CHANGE, onRoleItemChanged);
                _listGroup.addChild(item);

                var line = new HLine();
                line.layoutData = new VerticalLayoutData(100);
                line.alpha = .5;
                _listGroup.addChild(line);
            }
        }
    }

    /**
     * Handle clicks on the license link to open the purchase website
     */
    function _licenseLinkTriggered(e:MouseEvent) {
        // Open the prominic.shop HCL Domino license page in the default browser
        Lib.navigateToURL(new URLRequest("https://www.prominic.shop/category/hcl-domino"));
        
        // Show a confirmation callout
        TextCallout.show("Opening HCL Domino license page in your browser", _licenseLink);
    }
    
    /**
     * Check if Domino installer is selected and update dependency info
     * This is made public so it can be called from child components
     */
    public function checkDominoInstaller():Void {
        _dominoInstallerSelected = false;
        _dominoInstallerVersion = null;
        
        // Find the Domino role
        Logger.info('RolePage: checkDominoInstaller - _dominoRole is ${_dominoRole != null ? "found" : "null"}');
        
        if (_dominoRole != null) {
            // Check if an installer file is selected
            var hasInstaller = _dominoRole.files.installer != null;
            var hasInstallerVersion = _dominoRole.files.installerVersion != null;
            
            Logger.info('RolePage: checkDominoInstaller - hasInstaller: ${hasInstaller}, hasInstallerVersion: ${hasInstallerVersion}');
            
            if (hasInstaller && hasInstallerVersion) {
                _dominoInstallerSelected = true;
                _dominoInstallerVersion = _dominoRole.files.installerVersion;
                Logger.info('RolePage: Domino installer selected with version: ${_dominoInstallerVersion.fullVersion}');
                Logger.info('RolePage: Setting _dominoInstallerSelected = true');
            } else {
                Logger.info('RolePage: No Domino installer selected, _dominoInstallerSelected = false');
            }
        }
        
        // Update fixpack tracking
        updateRoleFixpacks();
    }
    
    /**
     * Update tracking of selected fixpacks for all roles
     */
    private function updateRoleFixpacks():Void {
        _roleFixpacks = new Map();
        
        // Loop through all roles to collect selected fixpacks
        if (_server != null && _server.roles != null && _server.roles.value != null) {
            for (roleData in _server.roles.value) {
                if (roleData.files.fixpacks != null && roleData.files.fixpacks.length > 0) {
                    // Extract fixpack versions from the file paths or metadata
                    var fixpackVersions = new Array<String>();
                    
                    // If there's a fixpack version in the role data
                    if (roleData.files.installerFixpackVersion != null) {
                        var version = roleData.files.installerFixpackVersion;
                        if (Reflect.hasField(version, "fixPackVersion")) {
                            fixpackVersions.push(Reflect.field(version, "fixPackVersion"));
                        }
                    }
                    
                    if (fixpackVersions.length > 0) {
                        _roleFixpacks.set(roleData.value, fixpackVersions);
                        Logger.info('RolePage: Role ${roleData.value} has fixpacks: ${fixpackVersions.join(", ")}');
                    }
                }
            }
        }
    }
    
    /**
     * Handle changes to role items - particularly Domino selection
     */
    private function onRoleItemChanged(e:Event):Void {
        var item:RolePickerItem = cast e.currentTarget;
        
        // If this is the Domino role, update dependencies
        if (item.role.value.toLowerCase() == "domino") {
            Logger.info('RolePage: Domino role selection changed, updating dependencies');
            
            // Find and store the Domino role directly from server's role collection
            _dominoRole = null;
            for (r in _server.roles.value) {
                if (r.value.toLowerCase() == "domino") {
                    _dominoRole = r;
                    Logger.info('RolePage: Found Domino role: installer=${r.files.installer != null}, version=${r.files.installerVersion != null}');
                    
                    // If version is available, log it
                    if (r.files.installerVersion != null) {
                        try {
                            var versionInfo = r.files.installerVersion;
                            var fullVersionStr = "unknown";
                            var majorVersionStr = "unknown";
                            var minorVersionStr = "unknown";
                            var patchStr = "N/A";
                            
                            // Safely access version properties using Reflect
                            if (Reflect.hasField(versionInfo, "fullVersion")) {
                                fullVersionStr = Std.string(Reflect.field(versionInfo, "fullVersion"));
                            }
                            
                            if (Reflect.hasField(versionInfo, "majorVersion")) {
                                majorVersionStr = Std.string(Reflect.field(versionInfo, "majorVersion"));
                            }
                            
                            if (Reflect.hasField(versionInfo, "minorVersion")) {
                                minorVersionStr = Std.string(Reflect.field(versionInfo, "minorVersion"));
                            }
                            
                            if (Reflect.hasField(versionInfo, "patch")) {
                                patchStr = Std.string(Reflect.field(versionInfo, "patch"));
                            }
                            
                            Logger.info('RolePage: Domino version: ' + 
                                'fullVersion=${fullVersionStr}, ' + 
                                'majorVersion=${majorVersionStr}, ' + 
                                'minorVersion=${minorVersionStr}, ' + 
                                'patch=${patchStr}');
                        } catch (e) {
                            Logger.error('RolePage: Error accessing version info: ${e}');
                        }
                    }
                    
                    break;
                }
            }
            
            // Update Domino installer selection status
            checkDominoInstaller();
            
            Logger.info('RolePage: After checkDominoInstaller, _dominoInstallerSelected=${_dominoInstallerSelected}, version=${_dominoInstallerVersion != null ? _dominoInstallerVersion.fullVersion : "null"}');
            
            // Force refresh all roles to apply dependency rules
            Logger.info('RolePage: Updating all role items to reflect new Domino installer status');
            updateContent(true);
        } else if (item.role.value.toLowerCase() == "nomadweb" || 
                  item.role.value.toLowerCase() == "traveler" || 
                  item.role.value.toLowerCase() == "domino-rest-api") {
            // Also refresh content if any version-dependent role changes
            Logger.info('RolePage: Version-dependent role ${item.role.value} changed, updating content');
            updateContent(true);
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
    
    // Installer selection buttons (replacing dropdown + browse button)
    var _installerSelectButton:Button;
    var _fixpackSelectButton:Button;
    var _hotfixSelectButton:Button;
    
    // Dependency tracking
    private var _isDependentRole:Bool = false;
    private var _isVersionDependentRole:Bool = false;
    private var _dominoInstallerSelected:Bool = false;
    private var _dominoInstallerVersion:Dynamic = null;
    private var _roleFixpacks:Map<String, Array<String>> = null;
    private var _dependencyWarning:Label;

    public var role( get, never ):RoleData;
    function get_role() return _roleImpl.role;

    public function new(
        roleImpl:ServerRoleImpl, 
        server:Server, 
        isDependentRole:Bool = false,
        isVersionDependentRole:Bool = false,
        dominoInstallerSelected:Bool = false,
        dominoInstallerVersion:Dynamic = null,
        roleFixpacks:Map<String, Array<String>> = null
    ) {
        super();

        _roleImpl = roleImpl;
        _server = server;
        _isDependentRole = isDependentRole;
        _isVersionDependentRole = isVersionDependentRole;
        _dominoInstallerSelected = dominoInstallerSelected;
        _dominoInstallerVersion = dominoInstallerVersion;
        _roleFixpacks = roleFixpacks;
    }

    override function initialize() {

        super.initialize();

        this.minHeight = 50;
        this.layoutData = new VerticalLayoutData( 100 );

        _layout = new VerticalLayout();
        _layout.gap = GenesisApplicationTheme.GRID * 2;
        this.layout = _layout;
        
        // Check if this is the Domino role to add license link
        var isDominoRole = (_roleImpl.role.value != null && _roleImpl.role.value.toLowerCase() == "domino");
        
        // Add HCL Domino license link if this is the Domino role
        if (isDominoRole) {
            // Create license text container with horizontal layout
            var licenseContainer = new LayoutGroup();
            var licenseLayout = new HorizontalLayout();
            licenseLayout.gap = 0;
            licenseLayout.horizontalAlign = HorizontalAlign.LEFT;
            licenseLayout.verticalAlign = VerticalAlign.MIDDLE;
            licenseContainer.layout = licenseLayout;
            licenseContainer.layoutData = new VerticalLayoutData(100);
            
            // Add regular text label
            var licenseText = new Label();
            licenseText.text = "Need a HCL Domino License? Get one now at ";
            licenseContainer.addChild(licenseText);
            
            // Add clickable link for Prominic.shop
            var licenseLink = new Label();
            licenseLink.text = "Prominic.shop!";
            licenseLink.variant = GenesisApplicationTheme.LABEL_LINK;
            licenseLink.buttonMode = licenseLink.useHandCursor = true;
            licenseLink.addEventListener(MouseEvent.CLICK, function(e:MouseEvent) {
                // Open the prominic.shop HCL Domino license page in the default browser
                Lib.navigateToURL(new URLRequest("https://www.prominic.shop/category/hcl-domino"));
                
                // Show a confirmation callout
                TextCallout.show("Opening HCL Domino license page in your browser", licenseLink);
            });
            licenseContainer.addChild(licenseLink);
            
            this.addChild(licenseContainer);
        }

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
        
        // Create dependency warning label (initially hidden)
        _dependencyWarning = new Label();
        _dependencyWarning.variant = GenesisApplicationTheme.LABEL_SMALL_CENTERED;
        _dependencyWarning.wordWrap = true;
        _dependencyWarning.includeInLayout = _dependencyWarning.visible = false;
        this.addChild(_dependencyWarning);

        var spacer = new LayoutGroup();
        spacer.layoutData = new HorizontalLayoutData( 100 );
        _labelGroup.addChild( spacer );

        // Create a container for file selection buttons
        _allFilesGroup = new LayoutGroup();
        var allFilesLayout = new HorizontalLayout(); // Changed to horizontal layout
        allFilesLayout.gap = GenesisApplicationTheme.GRID * 2; // Increased spacing between buttons
        allFilesLayout.verticalAlign = VerticalAlign.MIDDLE;
        _allFilesGroup.layout = allFilesLayout;
        _allFilesGroup.layoutData = new HorizontalLayoutData();
        _labelGroup.addChild(_allFilesGroup);
        
        // Create installer selection button with plus icon
        _installerSelectButton = new Button("+ Installer"); // Added plus to indicate add action
        _installerSelectButton.addEventListener(TriggerEvent.TRIGGER, _showInstallerDialog);
        _installerSelectButton.variant = GenesisApplicationTheme.BUTTON_SELECT_FILE;
        _allFilesGroup.addChild(_installerSelectButton);
        
        // Create fixpack selection button with plus icon
        _fixpackSelectButton = new Button("+ Fixpack"); // Added plus to indicate add action
        _fixpackSelectButton.addEventListener(TriggerEvent.TRIGGER, _showFixpackDialog);
        _fixpackSelectButton.variant = GenesisApplicationTheme.BUTTON_SELECT_FILE;
        _allFilesGroup.addChild(_fixpackSelectButton);
        
        // Create hotfix selection button with plus icon
        _hotfixSelectButton = new Button("+ Hotfix"); // Added plus to indicate add action
        _hotfixSelectButton.addEventListener(TriggerEvent.TRIGGER, _showHotfixDialog);
        _hotfixSelectButton.variant = GenesisApplicationTheme.BUTTON_SELECT_FILE;
        _allFilesGroup.addChild(_hotfixSelectButton);
        
        // Create the dropdowns for use in the dialogs - they won't be added to the display directly
        _installerDropdown = new PopUpListView();
        _installerDropdown.prompt = "Select installer...";
        _installerDropdown.addEventListener(Event.CHANGE, _installerDropdownChanged);
        _installerDropdown.width = GenesisApplicationTheme.GRID * 30;
        
        _fixpackDropdown = new PopUpListView();
        _fixpackDropdown.prompt = "Select fixpack...";
        _fixpackDropdown.addEventListener(Event.CHANGE, _fixpackDropdownChanged);
        _fixpackDropdown.width = GenesisApplicationTheme.GRID * 30;
        
        _hotfixDropdown = new PopUpListView();
        _hotfixDropdown.prompt = "Select hotfix...";
        _hotfixDropdown.addEventListener(Event.CHANGE, _hotfixDropdownChanged);
        _hotfixDropdown.width = GenesisApplicationTheme.GRID * 30;
        
        // Create the browse buttons for use in the dialogs
        _installerButton = new Button("Browse...");
        _installerButton.addEventListener(TriggerEvent.TRIGGER, _installerButtonTriggered);
        _installerButton.variant = GenesisApplicationTheme.BUTTON_SELECT_FILE;
        
        _fixpackButton = new Button("Browse...");
        _fixpackButton.addEventListener(TriggerEvent.TRIGGER, _fixpackButtonTriggered);
        _fixpackButton.variant = GenesisApplicationTheme.BUTTON_SELECT_FILE;
        
        _hotfixButton = new Button("Browse...");
        _hotfixButton.addEventListener(TriggerEvent.TRIGGER, _hotfixButtonTriggered);
        _hotfixButton.variant = GenesisApplicationTheme.BUTTON_SELECT_FILE;

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
        
        // Check dependency status
        var isDisabledByDependency = checkDependencyStatus();
        
        // Populate all dropdowns with cached files
        _populateInstallerDropdown();
        _populateFixpackDropdown();
        _populateHotfixDropdown();
        
        // Determine which buttons to show based on role type
        var showInstaller = true; // Default to showing installer
        var showFixpack = false;  // Default to hiding fixpack
        var showHotfix = false;   // Default to hiding hotfix
        
        // Check if this is a custom role with explicit installer settings
        if (Reflect.hasField(_roleImpl.role, "showInstaller")) {
            // Get installer settings from role configuration (custom provisioners)
            showInstaller = Reflect.field(_roleImpl.role, "showInstaller");
            showFixpack = Reflect.field(_roleImpl.role, "showFixpack");
            showHotfix = Reflect.field(_roleImpl.role, "showHotfix");
            
            Logger.info('${this}: Custom role ${_roleImpl.role.value} settings: installer=${showInstaller}, fixpack=${showFixpack}, hotfix=${showHotfix}');
        } else {
            // For built-in roles, use Reflect to check for hashes since the fields are private
            // Always show installer button for built-in roles
            
            // Use Reflect to access the private _fixpackHashes field
            var fixpackHashes = Reflect.field(_roleImpl, "_fixpackHashes");
            // Only check if the array exists, not whether it has elements
            // This allows roles with empty arrays (like Traveler) to show the button
            showFixpack = fixpackHashes != null && Std.isOfType(fixpackHashes, Array);
            
            // Use Reflect to access the private _hotfixHashes field
            var hotfixHashes = Reflect.field(_roleImpl, "_hotfixHashes");
            // Only check if the array exists, not whether it has elements
            showHotfix = hotfixHashes != null && Std.isOfType(hotfixHashes, Array);
            
            Logger.info('${this}: Built-in role ${_roleImpl.role.value} settings: installer=true, fixpack=${showFixpack}, hotfix=${showHotfix}');
        }
        
        // Show/hide all file selection buttons based on role being enabled
        _allFilesGroup.includeInLayout = _allFilesGroup.visible = _roleImpl.role.enabled;
        
        // Check if an installer is selected for this role
        var installerSelected = _roleImpl.role.files.installer != null;
        
        // Show/hide each selection button based on settings and installer selection
        _installerSelectButton.includeInLayout = _installerSelectButton.visible = showInstaller;
        // Only show fixpack and hotfix buttons if an installer is selected for this role
        _fixpackSelectButton.includeInLayout = _fixpackSelectButton.visible = showFixpack && installerSelected;
        _hotfixSelectButton.includeInLayout = _hotfixSelectButton.visible = showHotfix && installerSelected;
        
        // All buttons should be enabled if the role is enabled and not disabled by dependency
        var buttonsEnabled = _roleImpl.role.enabled && !isDisabledByDependency;
        _installerSelectButton.enabled = buttonsEnabled;
        _fixpackSelectButton.enabled = buttonsEnabled;
        _hotfixSelectButton.enabled = buttonsEnabled;
        
        // Set alpha for visual indication of disabled status
        var alphaValue = buttonsEnabled ? 1.0 : 0.5;
        _allFilesGroup.alpha = alphaValue;
        
        // Also enable the browse buttons used in dialogs
        _installerButton.enabled = buttonsEnabled;
        _fixpackButton.enabled = buttonsEnabled;
        _hotfixButton.enabled = buttonsEnabled;
        
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
                // If this is the Domino role and the installer was removed, notify parent
                if (_roleImpl.role.value.toLowerCase() == "domino") {
                    Logger.info('${this}: Domino installer removed, notifying parent');
                    // Find the parent RolePage to force an immediate update
                    var parent = this.parent;
                    while (parent != null && !Std.isOfType(parent, RolePage)) {
                        parent = parent.parent;
                    }
                    
                    if (parent != null) {
                        var rolePage = cast(parent, RolePage);
                        Logger.info('${this}: Found RolePage parent, forcing content update after file selection');
                        rolePage.checkDominoInstaller();
                        rolePage.updateContent(true);
                    } else {
                        // As fallback, dispatch change event to notify the parent component
                        this.dispatchEvent(new Event(Event.CHANGE, true));
                    }
                }
        }

        updateData();
    }

    // Single dialog flag to manage all file dialogs
    private var _isFileDialogOpen:Bool = false;
    
    
    /**
     * Check dependency status for this role
     * @return True if the role should be disabled due to dependencies
     */
    private function checkDependencyStatus():Bool {
        // Reset dependency warning
        _dependencyWarning.includeInLayout = _dependencyWarning.visible = false;
        
        // Log current state for debugging
        Logger.info('${this}: Checking dependency for ${_roleImpl.role.value}: isDependentRole=${_isDependentRole}, dominoSelected=${_dominoInstallerSelected}');
        
        // If this is not a dependent role, no restrictions apply
        if (!_isDependentRole && !_isVersionDependentRole) {
            return false;
        }
        
        // Check if Domino installer is selected
        if (!_dominoInstallerSelected) {
            // For dependent roles, disable if Domino installer is not selected
            _check.enabled = false;
            _dependencyWarning.text = "Requires Domino installer to be selected";
            _dependencyWarning.includeInLayout = _dependencyWarning.visible = true;
            return true;
        }
        
        // For version-dependent roles, check version compatibility
        if (_isVersionDependentRole && _dominoInstallerVersion != null) {
            if (!isCompatibleWithSelectedDomino()) {
                _check.enabled = false;
                _dependencyWarning.text = 'Incompatible with selected Domino version ${_dominoInstallerVersion.fullVersion}';
                _dependencyWarning.includeInLayout = _dependencyWarning.visible = true;
                return true;
            }
        }
        
        // Role can be enabled
        _check.enabled = !_roleImpl.role.isdefault;
        return false;
    }
    
    /**
     * Check if this role is compatible with the selected Domino version
     */
    private function isCompatibleWithSelectedDomino():Bool {
        if (_dominoInstallerVersion == null) return false;
        
        var roleName = _roleImpl.role.value.toLowerCase();
        switch (roleName) {
            case "traveler":
                // Traveler versions should match Domino major.minor versions
                if (_dominoInstallerVersion.majorVersion != null && 
                    _dominoInstallerVersion.minorVersion != null) {
                    return true; // We'll filter specific files in the dropdown population
                }
                return false;
                
            case "nomadweb":
                // Nomad Web uses patch with _R<dominoMajor> suffix
                if (_dominoInstallerVersion.majorVersion != null) {
                    return true; // We'll filter specific files in the dropdown population
                }
                return false;
                
            case "domino-rest-api":
                // Domino REST API uses patch with _R<dominoMajor> suffix
                if (_dominoInstallerVersion.majorVersion != null) {
                    return true; // We'll filter specific files in the dropdown population
                }
                return false;
                
            default:
                return true; // Non-version-dependent roles are always compatible
        }
    }
    
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
        
        // For version-dependent roles, filter based on Domino compatibility
        if (_isVersionDependentRole && _dominoInstallerSelected && _dominoInstallerVersion != null) {
            validCachedFiles = filterCompatibleFiles(validCachedFiles);
            
            // If filtering removed all files, log this
            if (validCachedFiles.length == 0 && _cachedFiles.length > 0) {
                Logger.info('${this}: All cached files filtered out due to Domino version compatibility');
            }
        }
        
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
                
                // Add warning about required fixpack
                if (Reflect.hasField(cachedFile.version, "fixPackVersion")) {
                    var requiredFixpack = Reflect.field(cachedFile.version, "fixPackVersion");
                    var hasRequiredFixpack = false;
                    
                    // Check if we have the required fixpack
                    if (_roleFixpacks != null && _roleFixpacks.exists(_roleImpl.role.value)) {
                        var installedFixpacks = _roleFixpacks.get(_roleImpl.role.value);
                        hasRequiredFixpack = installedFixpacks.indexOf(requiredFixpack) >= 0;
                    }
                    
                    if (!hasRequiredFixpack) {
                        displayName += ' (Requires fixpack ${requiredFixpack})';
                    }
                }
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
                if (item.file != null && item.file.sha256 == _roleImpl.role.files.installerHash) {
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
                        _showFileDialog("installers", selectedFile.sha256);
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
        _roleImpl.role.files.installerHash = selectedFile.sha256;
        _roleImpl.role.files.installerVersion = selectedFile.version;
        
        updateData();
    }
    
    /**
    /**
     * Filter files based on compatibility with selected Domino version
     */
    private function filterCompatibleFiles(files:Array<SuperHumanCachedFile>):Array<SuperHumanCachedFile> {
        if (_dominoInstallerVersion == null) return files;
        
        var roleName = _roleImpl.role.value.toLowerCase();
        return files.filter(function(file) {
            if (file.version == null) return false;
            
            switch (roleName) {
                case "traveler":
                    // Match major and minor version with Domino
                    return Reflect.hasField(file.version, "majorVersion") && 
                           Reflect.hasField(file.version, "minorVersion") &&
                           Reflect.field(file.version, "majorVersion") == _dominoInstallerVersion.majorVersion &&
                           Reflect.field(file.version, "minorVersion") == _dominoInstallerVersion.minorVersion;
                    
                case "nomadweb":
                    // Check for _R<dominoMajor> suffix in patch or fullVersion
                    var dominoSuffix = '_R${_dominoInstallerVersion.majorVersion}';
                    
                    if (Reflect.hasField(file.version, "patch") && 
                        Reflect.field(file.version, "patch") != null &&
                        StringTools.contains(Reflect.field(file.version, "patch"), dominoSuffix)) {
                        return true;
                    }
                    
                    // Sometimes newer versions don't use the suffix
                    if (Reflect.hasField(file.version, "fullVersion") && 
                        !StringTools.contains(Reflect.field(file.version, "fullVersion"), "_R")) {
                        // If no _R suffix, it might be compatible with multiple versions
                        return true;
                    }
                    
                    return false;
                    
                case "domino-rest-api":
                    // Check for _R<dominoMajor> suffix in patch or fullVersion
                    var dominoSuffix = '_R${_dominoInstallerVersion.majorVersion}';
                    
                    if (Reflect.hasField(file.version, "patch") && 
                        Reflect.field(file.version, "patch") != null) {
                        return StringTools.contains(Reflect.field(file.version, "patch"), dominoSuffix);
                    }
                    
                    return false;
                    
                default:
                    return true; // Non-version-dependent roles are always compatible
            }
        });
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
        
        // For version-dependent roles, filter based on Domino compatibility
        if (_isVersionDependentRole && _dominoInstallerSelected && _dominoInstallerVersion != null) {
            validCachedFiles = filterCompatibleFiles(validCachedFiles);
        }
        
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
                        _showFileDialog("fixpacks", selectedFile.sha256);
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
            _roleImpl.role.files.installerFixpackHash = selectedFile.sha256;
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
        
        // For version-dependent roles, filter based on Domino compatibility
        if (_isVersionDependentRole && _dominoInstallerSelected && _dominoInstallerVersion != null) {
            validCachedFiles = filterCompatibleFiles(validCachedFiles);
        }
        
        // Handle hotfixes that require specific fixpacks
        validCachedFiles = validCachedFiles.filter(function(file) {
            // If this file doesn't specify a fixpack requirement, it's always compatible
            if (file.version == null || !Reflect.hasField(file.version, "fixPackVersion")) {
                return true;
            }
            
            // Get the required fixpack
            var requiredFixpack = Reflect.field(file.version, "fixPackVersion");
            Logger.info('${this}: Hotfix requires fixpack: ${requiredFixpack}');
            
            // If no fixpacks are installed for this role, user can make an informed choice
            // We'll just show a warning in the hotfix name or description
            if (_roleFixpacks == null || !_roleFixpacks.exists(_roleImpl.role.value)) {
                return true; // Include it but we'll mark it as requiring a fixpack
            }
            
            // Check if the specific fixpack is installed
            var installedFixpacks = _roleFixpacks.get(_roleImpl.role.value);
            return installedFixpacks.indexOf(requiredFixpack) >= 0;
        });
        
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
                        _showFileDialog("hotfixes", selectedFile.sha256);
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
            _roleImpl.role.files.installerHotFixHash = selectedFile.sha256;
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
                
                // Calculate SHA256 hash - wait until it's done, no timeout
                var fileHash:String = null;
                var hashCalculated = false;
                SuperHumanHashes.calculateSHA256Async(path, function(calculatedHash:String) {
                    fileHash = calculatedHash;
                    hashCalculated = true;
                });
                
                // Wait for hash calculation to complete - no arbitrary timeout
                while (!hashCalculated) {
                    Sys.sleep(0.1);
                }
                
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
            _useFileBasedOnType(cachedFile.path, fullFileName, cachedFile.sha256, cachedFile.version, fileType);
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
                            fileHash,
                            version
                        );
                        
                        if (result != null) {
                            _useFileBasedOnType(result.path, fullFileName, result.sha256, result.version, fileType);
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
                        var result = SuperHumanFileCache.getInstance().addFile(
                            path, 
                            _roleImpl.role.value, 
                            fileType, 
                            fileHash,
                            null
                        );
                        
                        if (result != null) {
                            _useFileBasedOnType(result.path, fullFileName, result.sha256, result.version, fileType);
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
                            fileHash,
                            version
                        );
                        
                        if (result != null) {
                            _useFileBasedOnType(result.path, fullFileName, result.sha256, result.version, fileType);
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
                                fileHash,
                                null
                            );
                            
                            if (result != null) {
                                _useFileBasedOnType(result.path, fullFileName, result.sha256, result.version, fileType);
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
                
                // If this is the Domino role and the installer was selected, notify parent
                if (_roleImpl.role.value.toLowerCase() == "domino") {
                    Logger.info('${this}: Domino installer selected, path=${path}, hash=${hash}');
                    if (version != null) {
                        try {
                            Logger.info('${this}: Domino version info: ' + 
                                'fullVersion=${version.fullVersion}, ' +
                                'majorVersion=${version.majorVersion}, ' +
                                'minorVersion=${version.minorVersion}' +
                                (Reflect.hasField(version, "patch") ? ', patch=' + Reflect.field(version, "patch") : ''));
                        } catch (e) {
                            Logger.error('${this}: Error logging version info: ${e}');
                        }
                    } else {
                        Logger.warning('${this}: No version info available for selected Domino installer');
                    }
                    
                    // Find the parent RolePage to force an immediate refresh
                    var parent = this.parent;
                    while (parent != null && !Std.isOfType(parent, RolePage)) {
                        parent = parent.parent;
                    }
                    
                    if (parent != null) {
                        var rolePage = cast(parent, RolePage);
                        Logger.info('${this}: Found RolePage parent, forcing refresh after file selection');
                        rolePage.checkDominoInstaller();
                        rolePage.updateContent(true);
                    } else {
                        // Fallback to event dispatch if parent not found
                        this.dispatchEvent(new Event(Event.CHANGE, true));
                    }
                }
                
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
                    
                    // If this is any role getting a fixpack, we need to update hotfix dependencies
                    Logger.info('${this}: Fixpack added to ${_roleImpl.role.value}, notifying parent');
                    // Dispatch change event to notify the parent component about fixpack change
                    this.dispatchEvent(new Event(Event.CHANGE, true));
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

    /**
     * Show the installer selection dialog
     */
    private function _showInstallerDialog(e:TriggerEvent) {
        // Guard against multiple dialogs
        if (_isFileDialogOpen) return;
        
        // Populate the dropdown with current data
        _populateInstallerDropdown();
        
        // Determine what options are available for the user
        var options = [];
        var hasValidCachedFiles = false;
        
        if (_installerDropdown.dataProvider != null && _installerDropdown.dataProvider.length > 0) {
            // Check if we have valid cached files (not just placeholder)
            for (i in 0..._installerDropdown.dataProvider.length) {
                var item = _installerDropdown.dataProvider.get(i);
                if (item.file != null && !Reflect.hasField(item, "isPlaceholder")) {
                    hasValidCachedFiles = true;
                    break;
                }
            }
        }
        
        // Add different option sets based on what's available
        if (hasValidCachedFiles) {
            options = [
                "Select from cached files",
                "Browse for file",
                "Cancel"
            ];
        } else {
            options = [
                "Browse for file",
                "Cancel"
            ];
        }
        
        // Show the alert with appropriate options
        Alert.show(
            "Choose how you want to select an installer file",
            "Select Installer",
            options,
            (state) -> {
                // Handle selection based on options presented
                if (hasValidCachedFiles) {
                    switch (state.index) {
                        case 0: // Select from cached files
                            _showInstallerDropdownSelection();
                        case 1: // Browse for file
                            _showFileDialog("installers");
                        default: // Cancel - do nothing
                    }
                } else {
                    switch (state.index) {
                        case 0: // Browse for file
                            _showFileDialog("installers");
                        default: // Cancel - do nothing
                    }
                }
            }
        );
    }
    
    /**
     * Show a dialog to select from cached installer files
     */
    private function _showInstallerDropdownSelection() {
        // Create an array of options for the alert from the dropdown items
        var options = [];
        var fileItems = [];
        
        if (_installerDropdown.dataProvider != null) {
            for (i in 0..._installerDropdown.dataProvider.length) {
                var item = _installerDropdown.dataProvider.get(i);
                // Only include valid files, not placeholders
                if (item.file != null && !Reflect.hasField(item, "isPlaceholder")) {
                    options.push(item.label);
                    fileItems.push(item);
                }
            }
        }
        
        // Add a cancel option
        options.push("Cancel");
        
        // Calculate cancel button index (last item)
        var cancelIndex = options.length - 1;
        
        // Show the vertical options alert with file options
        VerticalOptionsAlert.show(
            "", // Remove message since title is now descriptive enough
            "Select a Cached Installer",
            options,
            (state) -> {
                // If the user selected a file (not cancel)
                if (state.index < fileItems.length) {
                    var selectedItem = fileItems[state.index];
                    var selectedFile = selectedItem.file;
                    
                    if (selectedFile != null && selectedFile.exists) {
                        _roleImpl.role.files.installer = selectedFile.path;
                        _roleImpl.role.files.installerFileName = selectedFile.originalFilename;
                        _roleImpl.role.files.installerHash = selectedFile.sha256;
                        _roleImpl.role.files.installerVersion = selectedFile.version;
                        
                        // Handle Domino installer selection
                        if (_roleImpl.role.value.toLowerCase() == "domino") {
                            Logger.info('${this}: Domino installer selected from cached files dialog');
                            
                            // Notify role page of selection change
                            this.dispatchEvent(new Event(Event.CHANGE, true));
                            
                            // Navigate up to find RolePage parent
                            var parent = this.parent;
                            while (parent != null && !Std.isOfType(parent, RolePage)) {
                                parent = parent.parent;
                            }
                            
                            if (parent != null) {
                                var rolePage = cast(parent, RolePage);
                                Logger.info('${this}: Found RolePage parent, forcing content update');
                                rolePage.checkDominoInstaller();
                                rolePage.updateContent(true);
                            }
                        }
                        
                        updateData();
                    }
                }
                // No action needed for cancel
            },
            cast this,
            false,
            cancelIndex
        );
    }
    
    /**
     * Show the fixpack selection dialog
     */
    private function _showFixpackDialog(e:TriggerEvent) {
        // Guard against multiple dialogs
        if (_isFileDialogOpen) return;
        
        // Populate the dropdown with current data
        _populateFixpackDropdown();
        
        // Determine what options are available for the user
        var options = [];
        var hasValidCachedFiles = false;
        
        if (_fixpackDropdown.dataProvider != null && _fixpackDropdown.dataProvider.length > 0) {
            // Check if we have valid cached files (not just placeholder)
            for (i in 0..._fixpackDropdown.dataProvider.length) {
                var item = _fixpackDropdown.dataProvider.get(i);
                if (item.file != null && !Reflect.hasField(item, "isPlaceholder")) {
                    hasValidCachedFiles = true;
                    break;
                }
            }
        }
        
        // Add different option sets based on what's available
        if (hasValidCachedFiles) {
            options = [
                "Select from cached files",
                "Browse for file",
                "Cancel"
            ];
        } else {
            options = [
                "Browse for file",
                "Cancel"
            ];
        }
        
        // Show the alert with appropriate options
        Alert.show(
            "Choose how you want to select a fixpack file",
            "Select Fixpack",
            options,
            (state) -> {
                // Handle selection based on options presented
                if (hasValidCachedFiles) {
                    switch (state.index) {
                        case 0: // Select from cached files
                            _showFixpackDropdownSelection();
                        case 1: // Browse for file
                            _showFileDialog("fixpacks");
                        default: // Cancel - do nothing
                    }
                } else {
                    switch (state.index) {
                        case 0: // Browse for file
                            _showFileDialog("fixpacks");
                        default: // Cancel - do nothing
                    }
                }
            }
        );
    }
    
    /**
     * Show a dialog to select from cached fixpack files
     */
    private function _showFixpackDropdownSelection() {
        // Create an array of options for the alert from the dropdown items
        var options = [];
        var fileItems = [];
        
        if (_fixpackDropdown.dataProvider != null) {
            for (i in 0..._fixpackDropdown.dataProvider.length) {
                var item = _fixpackDropdown.dataProvider.get(i);
                // Only include valid files, not placeholders
                if (item.file != null && !Reflect.hasField(item, "isPlaceholder")) {
                    options.push(item.label);
                    fileItems.push(item);
                }
            }
        }
        
        // Add a cancel option
        options.push("Cancel");
        
        // Calculate cancel button index (last item)
        var cancelIndex = options.length - 1;
        
        // Show the vertical options alert with file options
        VerticalOptionsAlert.show(
            "", // Remove message since title is now descriptive enough
            "Select a Cached Fixpack",
            options,
            (state) -> {
                // If the user selected a file (not cancel)
                if (state.index < fileItems.length) {
                    var selectedItem = fileItems[state.index];
                    var selectedFile = selectedItem.file;
                    
                    if (selectedFile != null && selectedFile.exists && 
                        !_roleImpl.role.files.fixpacks.contains(selectedFile.path)) {
                        
                        _roleImpl.role.files.fixpacks.push(selectedFile.path);
                        _roleImpl.role.files.installerFixpackHash = selectedFile.sha256;
                        _roleImpl.role.files.installerFixpackVersion = selectedFile.version;
                        updateData();
                    }
                }
                // No action needed for cancel
            },
            cast this,
            false,
            cancelIndex
        );
    }
    
    /**
     * Show the hotfix selection dialog
     */
    private function _showHotfixDialog(e:TriggerEvent) {
        // Guard against multiple dialogs
        if (_isFileDialogOpen) return;
        
        // Populate the dropdown with current data
        _populateHotfixDropdown();
        
        // Determine what options are available for the user
        var options = [];
        var hasValidCachedFiles = false;
        
        if (_hotfixDropdown.dataProvider != null && _hotfixDropdown.dataProvider.length > 0) {
            // Check if we have valid cached files (not just placeholder)
            for (i in 0..._hotfixDropdown.dataProvider.length) {
                var item = _hotfixDropdown.dataProvider.get(i);
                if (item.file != null && !Reflect.hasField(item, "isPlaceholder")) {
                    hasValidCachedFiles = true;
                    break;
                }
            }
        }
        
        // Add different option sets based on what's available
        if (hasValidCachedFiles) {
            options = [
                "Select from cached files",
                "Browse for file",
                "Cancel"
            ];
        } else {
            options = [
                "Browse for file",
                "Cancel"
            ];
        }
        
        // Show the alert with appropriate options
        Alert.show(
            "Choose how you want to select a hotfix file",
            "Select Hotfix",
            options,
            (state) -> {
                // Handle selection based on options presented
                if (hasValidCachedFiles) {
                    switch (state.index) {
                        case 0: // Select from cached files
                            _showHotfixDropdownSelection();
                        case 1: // Browse for file
                            _showFileDialog("hotfixes");
                        default: // Cancel - do nothing
                    }
                } else {
                    switch (state.index) {
                        case 0: // Browse for file
                            _showFileDialog("hotfixes");
                        default: // Cancel - do nothing
                    }
                }
            }
        );
    }
    
    /**
     * Show a dialog to select from cached hotfix files
     */
    private function _showHotfixDropdownSelection() {
        // Create an array of options for the alert from the dropdown items
        var options = [];
        var fileItems = [];
        
        if (_hotfixDropdown.dataProvider != null) {
            for (i in 0..._hotfixDropdown.dataProvider.length) {
                var item = _hotfixDropdown.dataProvider.get(i);
                // Only include valid files, not placeholders
                if (item.file != null && !Reflect.hasField(item, "isPlaceholder")) {
                    options.push(item.label);
                    fileItems.push(item);
                }
            }
        }
        
        // Add a cancel option
        options.push("Cancel");
        
        // Calculate cancel button index (last item)
        var cancelIndex = options.length - 1;
        
        // Show the vertical options alert with file options
        VerticalOptionsAlert.show(
            "", // Remove message since title is now descriptive enough
            "Select a Cached Hotfix",
            options,
            (state) -> {
                // If the user selected a file (not cancel)
                if (state.index < fileItems.length) {
                    var selectedItem = fileItems[state.index];
                    var selectedFile = selectedItem.file;
                    
                    if (selectedFile != null && selectedFile.exists && 
                        !_roleImpl.role.files.hotfixes.contains(selectedFile.path)) {
                        
                        _roleImpl.role.files.hotfixes.push(selectedFile.path);
                        _roleImpl.role.files.installerHotFixHash = selectedFile.sha256;
                        _roleImpl.role.files.installerHotFixVersion = selectedFile.version;
                        updateData();
                    }
                }
                // No action needed for cancel
            },
            cast this,
            false,
            cancelIndex
        );
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
