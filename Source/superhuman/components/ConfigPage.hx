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
import genesis.application.components.GenesisFormRow;
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
import genesis.application.components.GenesisFormPupUpListView;
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
import superhuman.server.Server;
import superhuman.server.definitions.ProvisionerDefinition;
import superhuman.server.provisioners.ProvisionerType;
import sys.FileSystem;

class ConfigPage extends Page {

    final _w:Float = GenesisApplicationTheme.GRID * 100;

    var _advancedLink:Label;
    var _buttonCancel:GenesisFormButton;
    var _buttonGroup:LayoutGroup;
    var _buttonGroupLayout:HorizontalLayout;
    var _buttonRoles:GenesisFormButton;
    var _buttonSafeId:GenesisFormButton;
    var _buttonSave:GenesisFormButton;
    var _dropdownCoreComponentVersion:GenesisFormPupUpListView;
    var _syncMethodCheck:Check;

    var _form:GenesisForm;
    var _inputHostname:GenesisFormTextInput;
    var _inputOrganization:GenesisFormTextInput;
    var _label:Label;
    var _labelComputedName:Label;
    var _labelMandatory:Label;
    var _labelPreviousSafeId:Label;
    var _rowComputedName:GenesisFormRow;
    var _rowCoreComponentVersion:GenesisFormRow;
    var _rowHostname:GenesisFormRow;
    var _rowOrganization:GenesisFormRow;
    var _rowPreviousSafeId:GenesisFormRow;
    var _rowSafeId:GenesisFormRow;
    var _rowRoles:GenesisFormRow;
    
    // Common variables fields
    var _commonVariables:Map<String, GenesisFormTextInput> = new Map();
    var _commonVariableRows:Map<String, GenesisFormRow> = new Map();

    var _server:Server;
    var _titleGroup:LayoutGroup;

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
        this.addChild( _titleGroup );

        _label = new Label();
        _label.text = LanguageManager.getInstance().getString( 'serverconfigpage.title', _server != null ? Std.string( _server.id ) : "" );
        _label.variant = GenesisApplicationTheme.LABEL_LARGE;
        _label.layoutData = new HorizontalLayoutData( 100 );
        _titleGroup.addChild( _label );

        _advancedLink = new Label( LanguageManager.getInstance().getString( 'serverconfigpage.advancedlink' ) );
        _advancedLink.variant = GenesisApplicationTheme.LABEL_LINK;
        _advancedLink.addEventListener( MouseEvent.CLICK, _advancedLinkTriggered );
        _titleGroup.addChild( _advancedLink );

        var line = new HLine();
        line.width = _w;
        this.addChild( line );

        _form = new GenesisForm();
        this.addChild( _form );

        _rowCoreComponentVersion = new GenesisFormRow();
        _rowCoreComponentVersion.text = LanguageManager.getInstance().getString( 'serverconfigpage.form.provisioner.text' );
        _dropdownCoreComponentVersion = new GenesisFormPupUpListView( ProvisionerManager.getBundledProvisionerCollection(ProvisionerType.StandaloneProvisioner) );
        _dropdownCoreComponentVersion.itemToText = ( item:ProvisionerDefinition ) -> {
            return item.name;
        };
        _dropdownCoreComponentVersion.selectedIndex = 0;
        for ( i in 0...ProvisionerManager.getBundledProvisionerCollection( ProvisionerType.StandaloneProvisioner ).length ) {
            var d:ProvisionerDefinition = ProvisionerManager.getBundledProvisionerCollection( ProvisionerType.StandaloneProvisioner ).get( i );
            if ( d.data.version == _server.provisioner.version ) {
                _dropdownCoreComponentVersion.selectedIndex = i;
                break;
            }
        }
        //Temporary selection of older provisioner on windows, due to bugs in newest one. It's going to be changes with next prov release
        #if windows
	        _dropdownCoreComponentVersion.selectedIndex = 1;
        #end
        _dropdownCoreComponentVersion.enabled = !_server.hostname.locked;
        _rowCoreComponentVersion.content.addChild( _dropdownCoreComponentVersion );
        _form.addChild( _rowCoreComponentVersion );

        _rowHostname = new GenesisFormRow();
        _rowHostname.text = LanguageManager.getInstance().getString( 'serverconfigpage.form.hostname.text' );
        _inputHostname = new GenesisFormTextInput( _server.hostname.value, LanguageManager.getInstance().getString( 'serverconfigpage.form.hostname.prompt' ), _server.hostname.validationKey );
        _inputHostname.minLength = 1;
        _inputHostname.restrict = "a-zA-Z0-9.-";
        _inputHostname.toolTip = LanguageManager.getInstance().getString( 'serverconfigpage.form.hostname.tooltip' );
        _inputHostname.addEventListener( Event.CHANGE, _inputHostnameChanged );
        _inputHostname.enabled = !_server.hostname.locked;
        _rowHostname.content.addChild( _inputHostname );
        _form.addChild( _rowHostname );

        _rowOrganization = new GenesisFormRow();
        _rowOrganization.text = LanguageManager.getInstance().getString( 'serverconfigpage.form.orgcert.text' );
        _inputOrganization = new GenesisFormTextInput( _server.organization.value, LanguageManager.getInstance().getString( 'serverconfigpage.form.orgcert.prompt' ), _server.organization.validationKey );
        _inputOrganization.minLength = 1;
        _inputOrganization.restrict = "a-zA-Z0-9-";
        _inputOrganization.toolTip = LanguageManager.getInstance().getString( 'serverconfigpage.form.orgcert.tooltip' );
        _inputOrganization.addEventListener( Event.CHANGE, _inputHostnameChanged );
        _inputOrganization.enabled = !_server.organization.locked;
        _rowOrganization.content.addChild( _inputOrganization );
        _form.addChild( _rowOrganization );

        _rowComputedName = new GenesisFormRow();
        _rowComputedName.text = LanguageManager.getInstance().getString( 'serverconfigpage.form.computedname.text' );
        _labelComputedName = new Label();
        _labelComputedName.wordWrap = true;
        _rowComputedName.content.addChild( _labelComputedName );
        _form.addChild( _rowComputedName );

        _rowSafeId = new GenesisFormRow();
        _rowSafeId.text = LanguageManager.getInstance().getString( 'serverconfigpage.form.safeid.text' );
        _buttonSafeId = new GenesisFormButton();
        _buttonSafeId.toolTip = LanguageManager.getInstance().getString( 'serverconfigpage.form.safeid.tooltip' );
        _buttonSafeId.addEventListener( TriggerEvent.TRIGGER, _buttonSafeIdTriggered );
        _buttonSafeId.icon = ( _server.safeIdExists() ) ? GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_OK ) : GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_WARNING ) ;
        _buttonSafeId.text = ( _server.safeIdExists() ) ? LanguageManager.getInstance().getString( 'serverconfigpage.form.safeid.buttonlocateagain' ) : LanguageManager.getInstance().getString( 'serverconfigpage.form.safeid.buttonlocate' );
        _buttonSafeId.enabled = !_server.userSafeId.locked;
        _rowSafeId.content.addChild( _buttonSafeId );
        _form.addChild( _rowSafeId );

        _rowPreviousSafeId = new GenesisFormRow();
        _labelPreviousSafeId = new Label();
        _labelPreviousSafeId.variant = GenesisApplicationTheme.LABEL_LINK;
        _labelPreviousSafeId.buttonMode = _labelPreviousSafeId.useHandCursor = true;
        _labelPreviousSafeId.addEventListener( MouseEvent.CLICK, _labelPreviousSafeIdTriggered );
        _rowPreviousSafeId.content.addChild( _labelPreviousSafeId );
        _form.addChild( _rowPreviousSafeId );

        if ( !_server.safeIdExists() && SuperHumanInstaller.getInstance().config.user.lastusedsafeid != null ) {

            _rowPreviousSafeId.visible = _rowPreviousSafeId.includeInLayout = true;
            var p = Path.withoutDirectory( SuperHumanInstaller.getInstance().config.user.lastusedsafeid );
            _labelPreviousSafeId.text = LanguageManager.getInstance().getString( 'serverconfigpage.form.safeid.useprevious', p );
            _labelPreviousSafeId.toolTip = SuperHumanInstaller.getInstance().config.user.lastusedsafeid;

        } else {

            _rowPreviousSafeId.visible = _rowPreviousSafeId.includeInLayout = false;

        }

        _rowRoles = new GenesisFormRow();
        _rowRoles.text = LanguageManager.getInstance().getString( 'serverconfigpage.form.roles.text' );
        _buttonRoles = new GenesisFormButton( LanguageManager.getInstance().getString( 'serverconfigpage.form.roles.button' ) );
        _buttonRoles.addEventListener( TriggerEvent.TRIGGER, _buttonRolesTriggered );
        _buttonRoles.icon = ( _server.areRolesValid() ) ? GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_OK ) : GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_WARNING  );
        _buttonRoles.enabled = !_server.roles.locked;
        _rowRoles.content.addChild( _buttonRoles );
        _form.addChild( _rowRoles );

        var line = new HLine();
        line.width = _w;
        this.addChild( line );

        _buttonGroup = new LayoutGroup();
        _buttonGroupLayout = new HorizontalLayout();
        _buttonGroupLayout.gap = GenesisApplicationTheme.GRID * 2;
        _buttonGroupLayout.horizontalAlign = HorizontalAlign.CENTER;
        _buttonGroup.layout = _buttonGroupLayout;
        _buttonSave = new GenesisFormButton( LanguageManager.getInstance().getString( 'serverconfigpage.form.buttons.save' ) );
        _buttonSave.addEventListener( TriggerEvent.TRIGGER, _saveButtonTriggered );
        _buttonSave.width = GenesisApplicationTheme.GRID * 20;
        _buttonCancel = new GenesisFormButton( LanguageManager.getInstance().getString( 'serverconfigpage.form.buttons.cancel' ) );
        _buttonCancel.addEventListener( TriggerEvent.TRIGGER, _buttonCancelTriggered );
        _buttonCancel.width = GenesisApplicationTheme.GRID * 20;
        _buttonGroup.addChild( _buttonSave );
        _buttonGroup.addChild( _buttonCancel );
        _buttonSave.enabled = !_server.hostname.locked;
        this.addChild( _buttonGroup );

        _labelMandatory = new Label( LanguageManager.getInstance().getString( 'serverconfigpage.form.info' ) );
        _labelMandatory.variant = GenesisApplicationTheme.LABEL_COPYRIGHT_CENTER;
        this.addChild( _labelMandatory );

        _inputHostnameChanged( null );

    }

    public function setServer( server:Server ) {
        _server = server;
        
        // Initialize common variables from server's customProperties
        _initializeCommonVariables();
    }
    
    /**
     * Initialize common variables from the server's customProperties
     */
    private function _initializeCommonVariables() {
        // Clear existing common variables
        _commonVariables = new Map();
        _commonVariableRows = new Map();
        
        // Remove existing common variable rows from the form
        if (_form != null) {
            for (row in _commonVariableRows) {
                if (row != null && row.parent == _form) {
                    _form.removeChild(row);
                }
            }
        }
        
        // Check if server has customProperties
        if (_server != null && _server.customProperties != null) {
            // Check if this is a custom provisioner
            var isCustomProvisioner = (_server.provisioner.type != ProvisionerType.StandaloneProvisioner && 
                                     _server.provisioner.type != ProvisionerType.AdditionalProvisioner &&
                                     _server.provisioner.type != ProvisionerType.Default);
                                     
            // Get common variables from appropriate source
            var commonVars = new Map<String, String>();
            
            if (isCustomProvisioner) {
                // For custom provisioners, primarily check dynamicCustomProperties
                if (Reflect.hasField(_server.customProperties, "dynamicCustomProperties")) {
                    var dynamicProps = Reflect.field(_server.customProperties, "dynamicCustomProperties");
                    if (dynamicProps != null) {
                        for (field in Reflect.fields(dynamicProps)) {
                            var value = Reflect.field(dynamicProps, field);
                            if (value != null && Std.isOfType(value, String)) {
                                commonVars.set(field, value);
                            }
                        }
                    }
                }
            } else {
                // For standard provisioners, look at root customProperties
                for (field in Reflect.fields(_server.customProperties)) {
                    // Skip dynamicCustomProperties, dynamicAdvancedCustomProperties, and rolesProcessed
                    if (field != "dynamicCustomProperties" && 
                        field != "dynamicAdvancedCustomProperties" &&
                        field != "provisionerDefinition" &&
                        field != "serviceTypeData" &&
                        field != "rolesProcessed") {
                        
                        var value = Reflect.field(_server.customProperties, field);
                        if (value != null && Std.isOfType(value, String)) {
                            commonVars.set(field, value);
                        }
                    }
                }
            }
            
            // Add common variable fields to the form
            if (_form != null) {
                for (field => value in commonVars) {
                    _addCommonVariableField(field, value);
                }
            }
        }
    }
    
    /**
     * Add a common variable field to the form
     * @param name The variable name
     * @param value The variable value
     */
    private function _addCommonVariableField(name:String, value:String) {
        if (_form == null) return;
        
        // Create a new row for the field
        var row = new GenesisFormRow();
        row.text = name; // Use the variable name as the label
        
        // Create a text input for the value
        var input = new GenesisFormTextInput(value);
        
        // Add the input to the row
        row.content.addChild(input);
        
        // Add the row to the form after the roles row
        var roleIndex = _form.getChildIndex(_rowRoles);
        _form.addChildAt(row, roleIndex + 1);
        
        // Store the input and row in the maps
        _commonVariables.set(name, input);
        _commonVariableRows.set(name, row);
    }

    override function updateContent( forced:Bool = false ) {

        super.updateContent();

        if ( _form != null ) {

            _label.text = LanguageManager.getInstance().getString( 'serverconfigpage.title', Std.string( _server.id ) );
            if ( forced || ( _inputHostname.text == null || _inputHostname.text == "" ) ) _inputHostname.text = _server.hostname.value;
            _inputHostname.variant = null;
            _inputHostname.enabled = !_server.hostname.locked;
            if (  forced || ( _inputOrganization.text == null || _inputOrganization.text == "" ) ) _inputOrganization.text = _server.organization.value;
            _inputOrganization.variant = null;
            _inputOrganization.enabled = !_server.organization.locked;

            _buttonSafeId.variant = null;
            _buttonRoles.variant = null;
            _buttonRoles.icon = ( _server.areRolesValid() ) ? GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_OK ) : GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_WARNING  );
            _buttonRoles.update();
            _buttonSafeId.icon = ( _server.safeIdExists() ) ? GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_OK ) : GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_WARNING  );
            _buttonSafeId.text = ( _server.safeIdExists() ) ? LanguageManager.getInstance().getString( 'serverconfigpage.form.safeid.buttonlocateagain' ) : LanguageManager.getInstance().getString( 'serverconfigpage.form.safeid.buttonlocate' );

            if ( !_server.safeIdExists() && SuperHumanInstaller.getInstance().config.user.lastusedsafeid != null ) {

                _rowPreviousSafeId.visible = _rowPreviousSafeId.includeInLayout = true;
                var p = Path.withoutDirectory( SuperHumanInstaller.getInstance().config.user.lastusedsafeid );
                _labelPreviousSafeId.text = LanguageManager.getInstance().getString( 'serverconfigpage.form.safeid.useprevious', p );

            } else {

                _rowPreviousSafeId.visible = _rowPreviousSafeId.includeInLayout = false;

            }

            _buttonSafeId.enabled = !_server.userSafeId.locked;
            _buttonRoles.enabled = !_server.roles.locked;
            _buttonSave.enabled = !_server.hostname.locked;

            if ( _dropdownCoreComponentVersion.selectedIndex == -1 || forced ) {

                for ( i in 0..._dropdownCoreComponentVersion.dataProvider.length ) {

                    var d:ProvisionerDefinition = _dropdownCoreComponentVersion.dataProvider.get( i );

                    if ( d.data.version == _server.provisioner.version ) {

                        _dropdownCoreComponentVersion.selectedIndex = i;
                        break;

                    }

                }

            }

            _dropdownCoreComponentVersion.enabled = !_server.hostname.locked;
            
            // If forced update, reinitialize common variables
            if (forced) {
                _initializeCommonVariables();
            }
        }

    }

    function _advancedLinkTriggered( e:MouseEvent ) {
        // Check if server is still valid - it might have been removed if it was provisional
        if (_server == null) {
            return;
        }
        
        var evt = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.ADVANCED_CONFIGURE_SERVER );
        evt.server = _server;
        this.dispatchEvent( evt );
    }

    function _buttonSafeIdTriggered( e:TriggerEvent ) {

        _server.locateNotesSafeId( _safeIdLocated );

    }

    function _buttonRolesTriggered( e:TriggerEvent ) {

        var evt = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.CONFIGURE_ROLES );
        evt.server = this._server;
        this.dispatchEvent( evt );

    }

    function _inputHostnameChanged( e:Event ) {

        var a = Server.getComputedName( _inputHostname.text, _inputOrganization.text );
        _labelComputedName.text = a.hostname + "." + a.domainName + "/" + a.path;

    }

    function _safeIdLocated() {

        _buttonSafeId.setValidity( true );
        _buttonSafeId.icon = ( _buttonSafeId.isValid() ) ? GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_OK ) : GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_WARNING );
        _buttonSafeId.text = ( _buttonSafeId.isValid() ) ? LanguageManager.getInstance().getString( 'serverconfigpage.form.safeid.buttonlocateagain' ) : LanguageManager.getInstance().getString( 'serverconfigpage.form.safeid.buttonlocate' );

        if ( !_server.safeIdExists() && SuperHumanInstaller.getInstance().config.user.lastusedsafeid != null ) {

            _rowPreviousSafeId.visible = _rowPreviousSafeId.includeInLayout = true;
            var p = Path.withoutDirectory( SuperHumanInstaller.getInstance().config.user.lastusedsafeid );
            _labelPreviousSafeId.text = LanguageManager.getInstance().getString( 'serverconfigpage.form.safeid.useprevious', p );

        } else {
            _rowPreviousSafeId.visible = _rowPreviousSafeId.includeInLayout = false;
        }

    }

    function _saveButtonTriggered( e:TriggerEvent ) {

        _buttonSafeId.setValidity( _server.safeIdExists() );
        _buttonRoles.setValidity( _server.areRolesValid() );

        if ( !_form.isValid() || !_server.safeIdExists() || !_server.areRolesValid() ) {

            return;

        }

        // Making sure the event is fired
        var a = _server.roles.value.copy();
        _server.roles.value = a;
        _server.syncMethod = SuperHumanInstaller.getInstance().config.preferences.syncmethod;
        _server.hostname.value = StringTools.trim( _inputHostname.text );
        _server.organization.value = StringTools.trim( _inputOrganization.text );
        var dvv:ProvisionerDefinition = cast _dropdownCoreComponentVersion.selectedItem;
        _server.updateProvisioner( dvv.data );

        // Save common variables to server's customProperties
        _saveCommonVariables();
        
        // EXPLICIT: Force the provisioner to copy files regardless of exists check
        _server.provisioner.copyFiles();
        
        // Initialize server files - creates directory and initial configuration
        if (_server.provisional) {
            _server.initializeServerFiles();
        }

        SuperHumanInstaller.getInstance().config.user.lastusedsafeid = _server.userSafeId.value;
        
        var evt = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.SAVE_SERVER_CONFIGURATION );
        evt.server = _server;
        this.dispatchEvent( evt );

    }

    function _labelPreviousSafeIdTriggered( e:MouseEvent ) {

        if ( !FileSystem.exists( SuperHumanInstaller.getInstance().config.user.lastusedsafeid ) ) {

            SuperHumanInstaller.getInstance().config.user.lastusedsafeid = null;

        }

        _server.userSafeId.value = SuperHumanInstaller.getInstance().config.user.lastusedsafeid;
        _safeIdLocated();

    }
    
    function _buttonCancelTriggered( e:TriggerEvent ) {
        // Only remove the server if the server directory doesn't exist
        // This ensures we only remove truly new servers that have never been saved
        if (_server != null && !sys.FileSystem.exists(_server.serverDir)) {
            // This is a truly new server that has never been saved - safe to remove
            superhuman.managers.ServerManager.getInstance().removeProvisionalServer(_server);
        }
        // Dispatch the CANCEL_PAGE event to match what SuperHumanInstaller is listening for
        this.dispatchEvent(new SuperHumanApplicationEvent(SuperHumanApplicationEvent.CANCEL_PAGE));
    }
    
    /**
     * Save common variables to the server's customProperties
     */
    private function _saveCommonVariables() {
        if (_server == null || _commonVariables.keys().hasNext() == false) {
            return;
        }
        
        // Check if this is a custom provisioner
        var isCustomProvisioner = (_server.provisioner.type != ProvisionerType.StandaloneProvisioner && 
                                  _server.provisioner.type != ProvisionerType.AdditionalProvisioner &&
                                  _server.provisioner.type != ProvisionerType.Default);
        
        // Initialize customProperties if needed
        if (_server.customProperties == null) {
            _server.customProperties = {};
        }
        
        if (isCustomProvisioner) {
            // For custom provisioners, use the dynamicCustomProperties field
            
            // Initialize dynamicCustomProperties if needed
            if (!Reflect.hasField(_server.customProperties, "dynamicCustomProperties")) {
                Reflect.setField(_server.customProperties, "dynamicCustomProperties", {});
            }
            
            // Get reference to dynamicCustomProperties
            var dynamicProps = Reflect.field(_server.customProperties, "dynamicCustomProperties");
            
            // Save each common variable to dynamicCustomProperties
            for (name => input in _commonVariables) {
                var value = StringTools.trim(input.text);
                // Save to dynamicCustomProperties
                Reflect.setField(dynamicProps, name, value);
            }
        } else {
            // For standard provisioners, save directly to customProperties root
            
            // Save each common variable
            for (name => input in _commonVariables) {
                var value = StringTools.trim(input.text);
                // Save to root customProperties
                Reflect.setField(_server.customProperties, name, value);
            }
        }
        
        // Force an immediate save to persist changes
        _server.saveData();
    }
}
