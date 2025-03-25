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

import superhuman.config.SuperHumanHashes;
import champaign.core.logging.Logger;
import feathers.controls.Alert;
import feathers.controls.Button;
import feathers.controls.Label;
import feathers.controls.LayoutGroup;
import feathers.events.TriggerEvent;
import feathers.layout.HorizontalAlign;
import feathers.layout.HorizontalLayout;
import feathers.layout.HorizontalLayoutData;
import feathers.layout.VerticalAlign;
import feathers.layout.VerticalLayout;
import feathers.layout.VerticalLayoutData;
import feathers.skins.RectangleSkin;
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

class RolePage extends Page {

    final _w:Float = GenesisApplicationTheme.GRID * 100;

    var _buttonGroup:LayoutGroup;
    var _buttonGroupLayout:HorizontalLayout;
    var _buttonClose:Button;
    var _listGroup:LayoutGroup;
    var _listGroupLayout:VerticalLayout;
    var _server:Server;
    
    public function new() {

        super();

    }

    override function initialize() {

        super.initialize();

        _content.width = _w;

        _listGroup = new LayoutGroup();
        _listGroup.layoutData = new VerticalLayoutData( 100 );
        _listGroupLayout = new VerticalLayout();
        _listGroupLayout.gap = GenesisApplicationTheme.GRID;
        _listGroup.layout = _listGroupLayout;
        this.addChild( _listGroup );

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
            
            // Check if this is a custom provisioner (not StandaloneProvisioner or AdditionalProvisioner)
            var isCustomProvisioner = _server.provisioner.type != "standalone-provisioner" && 
                                     _server.provisioner.type != "additional-provisioner" &&
                                     _server.provisioner.type != "default";
            
            // Use custom roles only for custom provisioners
            if (isCustomProvisioner) {
                // Get the provisioner definition for the server
                var provisionerDefinition = ProvisionerManager.getProvisionerDefinition(_server.provisioner.type, _server.provisioner.version);
                
                if (provisionerDefinition != null && 
                    provisionerDefinition.metadata != null && 
                    provisionerDefinition.metadata.roles != null && 
                    provisionerDefinition.metadata.roles.length > 0) {
                    
                    var customRoles:Array<ServerRoleImpl> = [];
                    
                    // Create ServerRoleImpl objects from the provisioner.yml roles
                    var roles:Array<Dynamic> = cast provisionerDefinition.metadata.roles;
                    for (roleData in roles) {
                        // Check if this role already exists in the server's roles
                        var existingRole:RoleData = null;
                        var roleName = Reflect.field(roleData, "name");
                        var roleLabel = Reflect.field(roleData, "label");
                        var roleDescription = Reflect.field(roleData, "description");
                        var roleDefaultEnabled = Reflect.field(roleData, "defaultEnabled");
                        
                        for (r in _server.roles.value) {
                            if (r.value == roleName) {
                                existingRole = r;
                                break;
                            }
                        }
                        
                        // If the role doesn't exist in the server's roles, create a new one
                        if (existingRole == null) {
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
                        
                        // Create a ServerRoleImpl for the role
                        var roleImpl = new ServerRoleImpl(
                            roleLabel,
                            roleDescription,
                            existingRole,
                            [], // No hashes for custom roles
                            [], // No hotfix hashes
                            [], // No fixpack hashes
                            "" // No file hint
                        );
                        
                        customRoles.push(roleImpl);
                    }
                    
                    // Add the custom roles to the list
                    for (i in customRoles) {
                        var item = new RolePickerItem(i, _server);
                        _listGroup.addChild(item);
                        
                        var line = new HLine();
                        line.layoutData = new VerticalLayoutData(100);
                        line.alpha = .5;
                        _listGroup.addChild(line);
                    }
                    
                    return; // Skip the default roles
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

        var event = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.CLOSE_ROLES );
        event.provisionerType = _server.provisioner.type;
        this.dispatchEvent( event );

    }

}

class RolePickerItem extends LayoutGroup {

    var _check:AdvancedCheckBox;
    var _fixpackButton:Button;
    var _helpImage:AdvancedAssetLoader;
    var _hotfixButton:Button;
    var _installerButton:Button;
    var _installerGroup:LayoutGroup;
    var _installerGroupLayout:VerticalLayout;
    var _labelGroup:LayoutGroup;
    var _labelGroupLayout:HorizontalLayout;
    var _layout:VerticalLayout;
    var _roleImpl:ServerRoleImpl;
    var _selectInstallerLabel:Label;
    var _server:Server;

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
        _labelGroup.layout = _labelGroupLayout;
        _labelGroupLayout.gap = 4;
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

        _installerButton = new Button( LanguageManager.getInstance().getString( 'rolepage.role.buttoninstaller' ) );
        _installerButton.addEventListener( TriggerEvent.TRIGGER, _installerButtonTriggered );
        _installerButton.variant = GenesisApplicationTheme.BUTTON_SELECT_FILE;
        _labelGroup.addChild( _installerButton );

        _fixpackButton = new Button( LanguageManager.getInstance().getString( 'rolepage.role.buttonfixpack' ) );
        _fixpackButton.addEventListener( TriggerEvent.TRIGGER, _fixpackButtonTriggered );
        _fixpackButton.variant = GenesisApplicationTheme.BUTTON_SELECT_FILE;
        _labelGroup.addChild( _fixpackButton );
        
        _hotfixButton = new Button( LanguageManager.getInstance().getString( 'rolepage.role.buttonhotfix' ) );
        _hotfixButton.addEventListener( TriggerEvent.TRIGGER, _hotfixButtonTriggered );
        _hotfixButton.variant = GenesisApplicationTheme.BUTTON_SELECT_FILE;
        _labelGroup.addChild( _hotfixButton );

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
        _hotfixButton.includeInLayout = _hotfixButton.visible = false;
        _fixpackButton.includeInLayout = _fixpackButton.visible = false;

        _installerButton.enabled = _roleImpl.role.enabled;

        if ( _roleImpl.role.files.installer != null ) {

            var item = new RolePickerFileItem( _roleImpl.role.files.installer );
            item.addEventListener( TriggerEvent.TRIGGER, _fileItemTriggered );
            _installerGroup.addChild( item );
            _installerButton.enabled = false;
            _installerGroup.visible = _installerGroup.includeInLayout = true;
            _selectInstallerLabel.visible = _selectInstallerLabel.includeInLayout = false;

        } else {

            _selectInstallerLabel.visible = _selectInstallerLabel.includeInLayout = true;

        }

        if ( _roleImpl.role.files.hotfixes != null ) {

            _hotfixButton.includeInLayout = _hotfixButton.visible = true;

            for ( hf in _roleImpl.role.files.hotfixes ) {

                var item = new RolePickerFileItem( hf, RolePickerFileType.Hotfix );
                item.addEventListener( TriggerEvent.TRIGGER, _fileItemTriggered );
                _installerGroup.addChild( item );
                _installerGroup.visible = _installerGroup.includeInLayout = true;
    
            }

        }

        if ( _roleImpl.role.files.fixpacks != null ) {

            _fixpackButton.includeInLayout = _fixpackButton.visible = true;

            for ( hf in _roleImpl.role.files.fixpacks ) {

                var item = new RolePickerFileItem( hf, RolePickerFileType.Fixpack );
                item.addEventListener( TriggerEvent.TRIGGER, _fileItemTriggered );
                _installerGroup.addChild( item );
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

    function _installerButtonTriggered( e:TriggerEvent ) {

        var dir = ( SuperHumanInstaller.getInstance().config.user.lastuseddirectory != null ) ? SuperHumanInstaller.getInstance().config.user.lastuseddirectory : System.userDirectory;
        var fd = new FileDialog();
        var currentDir:String;

        fd.onSelect.add( path -> {
			
            var currentPath = new Path(path);
            var fullFileName = currentPath.file + "." + currentPath.ext;
            
            currentDir = Path.directory( path );
            
            if ( currentDir != null ) SuperHumanInstaller.getInstance().config.user.lastuseddirectory = currentDir;

            var hashes:Array<String> = SuperHumanHashes.getInstallersHashes(_roleImpl.role.value);
            var v = FileTools.checkMD5( path, hashes);

            if ( v != null) 
            	{

                _roleImpl.role.files.installer = path;
                _roleImpl.role.files.installerFileName = fullFileName;
                _roleImpl.role.files.installerHash = v;
                _roleImpl.role.files.installerVersion = SuperHumanHashes.getInstallerVersion(_roleImpl.role.value, v);
                
                updateData();
                
            } 
            	else 
            	{

                Alert.show(
                    LanguageManager.getInstance().getString( 'alert.installerhash.text', _roleImpl.name ),
                    LanguageManager.getInstance().getString( 'alert.installerhash.title' ),
                    [ LanguageManager.getInstance().getString( 'alert.installerhash.buttonyes' ), LanguageManager.getInstance().getString( 'alert.installerhash.buttonno' ) ],
                    ( state ) -> {

                    switch state.index {

                        case 0:
                            _roleImpl.role.files.installer = path;
                            _roleImpl.role.files.installerFileName = fullFileName;
                            
                            updateData();

                        default:

                    }

                } );

            }


        } );

        fd.browse( FileDialogType.OPEN, null, dir + "/", LanguageManager.getInstance().getString( 'rolepage.role.locateinstaller', _roleImpl.name ) );

    }

    function _hotfixButtonTriggered( e:TriggerEvent ) {
        
        var dir = ( SuperHumanInstaller.getInstance().config.user.lastuseddirectory != null ) ? SuperHumanInstaller.getInstance().config.user.lastuseddirectory : System.userDirectory;
        var fd = new FileDialog();
        var currentDir:String;

        fd.onSelect.add( path -> {

        		var currentPath = new Path(path);
            var fullFileName = currentPath.file + "." + currentPath.ext;
            
            currentDir = Path.directory( path );
            
            if ( currentDir != null ) SuperHumanInstaller.getInstance().config.user.lastuseddirectory = currentDir;

            var hashes:Array<String> = SuperHumanHashes.getHotFixesHashes(_roleImpl.role.value);
            var v = FileTools.checkMD5( path, hashes);

            if ( v != null ) 
            	{

                if ( !_roleImpl.role.files.hotfixes.contains( path ) ) 
                {	
                		//Only latest added hotfix will be taken into account 
    		            _roleImpl.role.files.installerHotFixVersion = SuperHumanHashes.getHotfixesVersion(_roleImpl.role.value, v);
                		_roleImpl.role.files.installerHotFixHash = v;
                		_roleImpl.role.files.hotfixes.push( path );
        			}
    
                updateData();

            } else {

                Alert.show(
                    LanguageManager.getInstance().getString( 'alert.hotfixhash.text', _roleImpl.name ),
                    LanguageManager.getInstance().getString( 'alert.hotfixhash.title' ),
                    [ LanguageManager.getInstance().getString( 'alert.hotfixhash.buttonyes' ), LanguageManager.getInstance().getString( 'alert.hotfixhash.buttonno' ) ],
                    ( state ) -> {

                    switch state.index {

                        case 0:
                            if ( !_roleImpl.role.files.hotfixes.contains( path ) ) 
                            {
                            		_roleImpl.role.files.hotfixes.push( path );
                        		}
                            updateData();

                        default:

                    }

                } );

            }

        } );

        fd.browse( FileDialogType.OPEN, null, dir + "/", LanguageManager.getInstance().getString( 'rolepage.role.locatehotfix', _roleImpl.name ) );

    }

    function _fixpackButtonTriggered( e:TriggerEvent ) {
        
        var dir = ( SuperHumanInstaller.getInstance().config.user.lastuseddirectory != null ) ? SuperHumanInstaller.getInstance().config.user.lastuseddirectory : System.userDirectory;
        var fd = new FileDialog();
        var currentDir:String;

        fd.onSelect.add( path -> {

            currentDir = Path.directory( path );
            if ( currentDir != null ) SuperHumanInstaller.getInstance().config.user.lastuseddirectory = currentDir;

            var hashes:Array<String> = SuperHumanHashes.getFixPacksHashes(_roleImpl.role.value);
            var v = FileTools.checkMD5( path, hashes);

            if ( v != null ) {

                if ( !_roleImpl.role.files.fixpacks.contains( path ) ) 
                {
                		_roleImpl.role.files.installerFixpackVersion = SuperHumanHashes.getFixpacksVersion(_roleImpl.role.value, v);
                        _roleImpl.role.files.installerFixpackHash = v;
                		_roleImpl.role.files.fixpacks.push( path );
            		}
                updateData();

            } else {

                Alert.show(
                    LanguageManager.getInstance().getString( 'alert.fixpackhash.text', _roleImpl.name ),
                    LanguageManager.getInstance().getString( 'alert.fixpackhash.title' ),
                    [ LanguageManager.getInstance().getString( 'alert.fixpackhash.buttonyes' ), LanguageManager.getInstance().getString( 'alert.fixpackhash.buttonno' ) ], ( state ) -> {

                    switch state.index {

                        case 0:
                            if ( !_roleImpl.role.files.fixpacks.contains( path ) ) _roleImpl.role.files.fixpacks.push( path );
                            updateData();

                        default:

                    }

                } );

            }

        } );

        fd.browse( FileDialogType.OPEN, null, dir + "/", LanguageManager.getInstance().getString( 'rolepage.role.locatefixpack', _roleImpl.name ) );

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
