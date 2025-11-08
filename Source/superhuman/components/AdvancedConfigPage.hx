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

import genesis.application.components.GenesisFormRow;
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
import genesis.application.components.GenesisFormTextInput;
import genesis.application.components.HLine;
import genesis.application.components.Page;
import genesis.application.managers.LanguageManager;
import genesis.application.theme.GenesisApplicationTheme;
import openfl.events.Event;
import prominic.sys.applications.oracle.BridgedInterface;
import prominic.sys.applications.oracle.VirtualBox;
import prominic.sys.tools.StrTools;
import superhuman.events.SuperHumanApplicationEvent;
import superhuman.server.Server;

class AdvancedConfigPage extends Page {

    final _w:Float = GenesisApplicationTheme.GRID * 100;

    var _buttonCancel:GenesisFormButton;
    var _buttonGroup:LayoutGroup;
    var _buttonGroupLayout:HorizontalLayout;
    var _buttonSave:GenesisFormButton;
    var _cbDHCP:GenesisFormCheckBox;
    var _cbDisableBridgeAdapter:GenesisFormCheckBox;
    var _cbOpenBrowser:GenesisFormCheckBox;
    var _buttonGeneratePassword:GenesisFormButton;
    var _buttonTogglePassword:GenesisFormButton;
    var _dropdownNetworkInterface:GenesisFormPupUpListView;
    var _passwordVisible:Bool = false;
    var _form:GenesisForm;
    var _inputAlertEmail:GenesisFormTextInput;
    var _inputGatewayIP:GenesisFormTextInput;
    var _inputNameServer2:GenesisFormTextInput;
    var _inputNameServer:GenesisFormTextInput;
    var _inputNetmaskIP:GenesisFormTextInput;
    var _inputNetworkIP:GenesisFormTextInput;
    var _inputVagrantPassword:GenesisFormTextInput;
    var _label:Label;
    var _labelMandatory:Label;
    var _rowAlertEmail:GenesisFormRow;
    var _rowCPUs:GenesisFormRow;
    var _rowDHCP:GenesisFormRow;
    var _rowDisableBridgeAdapter:GenesisFormRow;
    var _rowGatewayIP:GenesisFormRow;
    var _rowMisc:GenesisFormRow;
    var _rowNameServer2:GenesisFormRow;
    var _rowNameServer:GenesisFormRow;
    var _rowNetmaskIP:GenesisFormRow;
    var _rowNetworkIP:GenesisFormRow;
    var _rowNetworkInterface:GenesisFormRow;
    var _rowRAM:GenesisFormRow;
    var _rowVagrantPassword:GenesisFormRow;
    var _server:Server;
    var _stepperCPUs:GenesisFormNumericStepper;
    var _stepperRAM:GenesisFormNumericStepper;
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
        _label.text = LanguageManager.getInstance().getString( 'serveradvancedconfigpage.title', Std.string( _server.id ) );
        _label.variant = GenesisApplicationTheme.LABEL_LARGE;
        _label.layoutData = new HorizontalLayoutData( 100 );
        _titleGroup.addChild( _label );

        var line = new HLine();
        line.width = _w;
        this.addChild( line );

        _form = new GenesisForm();
        this.addChild( _form );

        _rowNetworkInterface = new GenesisFormRow();
        _rowNetworkInterface.text = LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.networkinterface.text' );
        _dropdownNetworkInterface = new GenesisFormPupUpListView( VirtualBox.getInstance().bridgedInterfacesCollection );
        // Create a custom collection with Default and None options at the beginning
        var originalCollection = VirtualBox.getInstance().bridgedInterfacesCollection;
        var interfaceCollection = new feathers.data.ArrayCollection<BridgedInterface>();
        
        // Get the default network interface from global preferences
        var defaultNic = SuperHumanInstaller.getInstance().config.preferences.defaultNetworkInterface;
        
        // Add Default option (empty string)
        interfaceCollection.add({ name: "" });
        
        // Add None option (special "none" value)
        interfaceCollection.add({ name: "none" });
        
        // Create a deduplicated collection by excluding empty names, "none", and the default interface
        var addedNames = new Map<String, Bool>();
        addedNames.set("", true);  // Already added empty string (Default)
        addedNames.set("none", true); // Already added "none"
        
        if (defaultNic != null && defaultNic != "" && defaultNic != "none") {
            addedNames.set(defaultNic, true); // Mark default as added to avoid duplicates
        }
        
        // Add all original interfaces, excluding duplicates and the default
        for (i in 0...originalCollection.length) {
            var interfaceItem = originalCollection.get(i);
            if (interfaceItem.name != "" && interfaceItem.name != "none" && !addedNames.exists(interfaceItem.name)) {
                interfaceCollection.add(interfaceItem);
                addedNames.set(interfaceItem.name, true);
            }
        }
        
        _dropdownNetworkInterface = new GenesisFormPupUpListView(interfaceCollection);
        _dropdownNetworkInterface.itemToText = (item:BridgedInterface) -> {
            if (item.name == "") {
                // Get the default network interface from global preferences
                var defaultNic = SuperHumanInstaller.getInstance().config.preferences.defaultNetworkInterface;
                if (defaultNic != null && defaultNic != "" && defaultNic != "none") {
                    return 'Default (' + defaultNic + ')';
                }
                return 'Default (none selected)';
            }
            if (item.name == "none") return "None";
            return item.name;
        };
        _dropdownNetworkInterface.selectedIndex = 0;
        for ( i in 0..._dropdownNetworkInterface.dataProvider.length ) {
            var d = _dropdownNetworkInterface.dataProvider.get( i );
            // Use getEffectiveNetworkInterface to get the actual interface value
            if ( d.name == _server.getEffectiveNetworkInterface() ) {
                _dropdownNetworkInterface.selectedIndex = i;
                break;
            }
        }
        _dropdownNetworkInterface.prompt = LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.networkinterface.prompt' );
        _dropdownNetworkInterface.enabled = !_server.networkBridge.locked && !_server.disableBridgeAdapter.value && _server.disableBridgeAdapter.locked;
        _rowNetworkInterface.content.addChild( _dropdownNetworkInterface );
        _form.addChild( _rowNetworkInterface );

        _rowDHCP = new GenesisFormRow();
        _rowDHCP.text = LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.dhcp.text' );
        _cbDHCP = new GenesisFormCheckBox( LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.dhcp.checkbox' ), _server.dhcp4.value );
        _cbDHCP.toolTip = LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.dhcp.tooltip' );
        _cbDHCP.addEventListener( Event.CHANGE, _cbDHCP_Or_cbDisableBridgeAdapterChanged );
        _rowDHCP.content.addChild( _cbDHCP );
        _form.addChild( _rowDHCP );

        _rowNetworkIP = new GenesisFormRow();
        _rowNetworkIP.text = LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.networkip.text' );
        _inputNetworkIP = new GenesisFormTextInput( _server.networkAddress.value, LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.networkip.prompt' ), _server.networkAddress.validationKey, true );
        _inputNetworkIP.restrict = "0-9.";
        _inputNetworkIP.minLength = 7;
        _inputNetworkIP.toolTip = LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.networkip.tooltip' );
        _inputNetworkIP.enabled = !_server.dhcp4.value;
        _rowNetworkIP.content.addChild( _inputNetworkIP );
        _form.addChild( _rowNetworkIP );
        
        _rowGatewayIP = new GenesisFormRow();
        _rowGatewayIP.text = LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.gatewayip.text' );
        _inputGatewayIP = new GenesisFormTextInput( _server.networkGateway.value, LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.gatewayip.prompt' ), _server.networkGateway.validationKey, true );
        _inputGatewayIP.restrict = "0-9.";
        _inputGatewayIP.minLength = 7;
        _inputGatewayIP.toolTip = LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.gatewayip.tooltip' );
        _inputGatewayIP.enabled = !_server.dhcp4.value;
        _rowGatewayIP.content.addChild( _inputGatewayIP );
        _form.addChild( _rowGatewayIP );

        _rowNetmaskIP = new GenesisFormRow();
        _rowNetmaskIP.text = LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.netmaskip.text' );
        _inputNetmaskIP = new GenesisFormTextInput( _server.networkNetmask.value, LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.netmaskip.prompt' ), _server.networkNetmask.validationKey, true );
        _inputNetmaskIP.restrict = "0-9.";
        _inputNetmaskIP.minLength = 7;
        _inputNetmaskIP.toolTip = LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.netmaskip.tooltip' );
        _inputNetmaskIP.enabled = !_server.dhcp4.value;
        _rowNetmaskIP.content.addChild( _inputNetmaskIP );
        _form.addChild( _rowNetmaskIP );

        _rowNameServer = new GenesisFormRow();
        _rowNameServer.text = LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.nameserver1.text' );
        _inputNameServer = new GenesisFormTextInput( _server.nameServer1.value, LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.nameserver1.prompt' ), _server.nameServer1.validationKey );
        _inputNameServer.restrict = "0-9.";
        _inputNameServer.minLength = 7;
        _inputNameServer.toolTip = LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.nameserver1.tooltip' );
        _inputNameServer.enabled = !_server.dhcp4.value;
        _rowNameServer.content.addChild( _inputNameServer );
        _form.addChild( _rowNameServer );

        _rowNameServer2 = new GenesisFormRow();
        _rowNameServer2.text = LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.nameserver2.text' );
        _inputNameServer2 = new GenesisFormTextInput( _server.nameServer2.value, LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.nameserver2.prompt' ), _server.nameServer2.validationKey );
        _inputNameServer2.restrict = "0-9.";
        _inputNameServer2.minLength = 7;
        _inputNameServer2.toolTip = LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.nameserver2.tooltip' );
        _inputNameServer2.enabled = !_server.dhcp4.value;
        _rowNameServer2.content.addChild( _inputNameServer2 );
        _form.addChild( _rowNameServer2 );

        _rowAlertEmail = new GenesisFormRow();
        _rowAlertEmail.text = LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.alertemail.text' );
        _inputAlertEmail = new GenesisFormTextInput( _server.userEmail.value, LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.alertemail.prompt' ), _server.userEmail.validationKey, true );
        _inputAlertEmail.restrict = "a-zA-Z0-9@.-";
        _inputAlertEmail.minLength = 6;
        _inputAlertEmail.toolTip = LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.alertemail.tooltip' );
        _rowAlertEmail.content.addChild( _inputAlertEmail );
        _form.addChild( _rowAlertEmail );

        _rowCPUs = new GenesisFormRow();
        _rowCPUs.text = LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.cpu.text' );
        _stepperCPUs = new GenesisFormNumericStepper( _server.numCPUs.value, 2, VirtualBox.getInstance().hostInfo.processorcorecount );
        _stepperCPUs.step = 1;
        _stepperCPUs.toolTip = LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.cpu.tooltip' );
        _stepperCPUs.editable = false;
        _rowCPUs.content.addChild( _stepperCPUs );
        _form.addChild( _rowCPUs );

        _rowRAM = new GenesisFormRow();
        _rowRAM.text = LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.ram.text' );
        _stepperRAM = new GenesisFormNumericStepper( _server.memory.value, 4, Math.floor( VirtualBox.getInstance().hostInfo.memorysize / 1024 ) );
        _stepperRAM.step = 1;
        _stepperRAM.toolTip = LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.ram.tooltip' );
        _stepperRAM.editable = false;
        _rowRAM.content.addChild( _stepperRAM );
        _form.addChild( _rowRAM );

        _rowMisc = new GenesisFormRow();
        _rowMisc.text = LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.misc.text' );
        _cbOpenBrowser = new GenesisFormCheckBox( LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.misc.openbrowser' ), _server.openBrowser.value );
        _rowMisc.content.addChild( _cbOpenBrowser );
        _form.addChild( _rowMisc );

        _rowDisableBridgeAdapter = new GenesisFormRow();
        _rowDisableBridgeAdapter.text = LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.expert.text' );
        _cbDisableBridgeAdapter = new GenesisFormCheckBox( LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.expert.disablebridgeadapter' ), _server.disableBridgeAdapter.value );
        _cbDisableBridgeAdapter.addEventListener( Event.CHANGE, _cbDHCP_Or_cbDisableBridgeAdapterChanged );
        _cbDisableBridgeAdapter.selected = _server.disableBridgeAdapter.value;
        _cbDisableBridgeAdapter.enabled = !_server.disableBridgeAdapter.locked;
        _rowDisableBridgeAdapter.content.addChild( _cbDisableBridgeAdapter );
        _form.addChild( _rowDisableBridgeAdapter );

        _rowVagrantPassword = new GenesisFormRow();
        _rowVagrantPassword.text = "Vagrant User Password";
        
        // Create a layout group to hold both the input and the button
        var passwordGroup = new LayoutGroup();
        var passwordLayout = new HorizontalLayout();
        passwordLayout.gap = GenesisApplicationTheme.GRID;
        passwordLayout.verticalAlign = VerticalAlign.MIDDLE;
        passwordGroup.layout = passwordLayout;
        
        _inputVagrantPassword = new GenesisFormTextInput( _server.vagrantUserPassword.value, "Enter vagrant user password" );
        _inputVagrantPassword.displayAsPassword = true;
        _inputVagrantPassword.minLength = 8;
        _inputVagrantPassword.toolTip = "Password for the vagrant user account on the VM";
        _inputVagrantPassword.layoutData = new HorizontalLayoutData( 50 );
        passwordGroup.addChild( _inputVagrantPassword );
        
        _buttonGeneratePassword = new GenesisFormButton( "Generate" );
        _buttonGeneratePassword.addEventListener( TriggerEvent.TRIGGER, _generatePasswordTriggered );
        _buttonGeneratePassword.toolTip = "Generate a random secure password";
        _buttonGeneratePassword.layoutData = new HorizontalLayoutData( 25 );
        passwordGroup.addChild( _buttonGeneratePassword );
        
        _buttonTogglePassword = new GenesisFormButton( "Show" );
        _buttonTogglePassword.addEventListener( TriggerEvent.TRIGGER, _togglePasswordVisibilityTriggered );
        _buttonTogglePassword.toolTip = "Show or hide the password";
        _buttonTogglePassword.layoutData = new HorizontalLayoutData( 25 );
        passwordGroup.addChild( _buttonTogglePassword );
        
        _rowVagrantPassword.content.addChild( passwordGroup );
        _form.addChild( _rowVagrantPassword );

        var line = new HLine();
        line.width = _w;
        this.addChild( line );

        _buttonGroup = new LayoutGroup();
        _buttonGroupLayout = new HorizontalLayout();
        _buttonGroupLayout.gap = GenesisApplicationTheme.GRID * 2;
        _buttonGroupLayout.horizontalAlign = HorizontalAlign.CENTER;
        _buttonGroup.layout = _buttonGroupLayout;
        _buttonSave = new GenesisFormButton( LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.buttons.save' ) );
        _buttonSave.addEventListener( TriggerEvent.TRIGGER, _saveButtonTriggered );
        _buttonSave.width = GenesisApplicationTheme.GRID * 20;
        _buttonCancel = new GenesisFormButton( LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.buttons.cancel' ) );
        _buttonCancel.addEventListener( TriggerEvent.TRIGGER, _cancel );
        _buttonCancel.width = GenesisApplicationTheme.GRID * 20;
        _buttonGroup.addChild( _buttonSave );
        _buttonGroup.addChild( _buttonCancel );
        this.addChild( _buttonGroup );

        _labelMandatory = new Label( LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.info' ) );
        _labelMandatory.variant = GenesisApplicationTheme.LABEL_COPYRIGHT_CENTER;
        this.addChild( _labelMandatory );

        _inputNetworkIP.enabled = !_server.dhcp4.value && !_server.disableBridgeAdapter.value && !_server.networkAddress.locked;
        _inputNameServer.enabled = !_server.dhcp4.value && !_server.disableBridgeAdapter.value && !_server.nameServer1.locked;
        _inputNameServer2.enabled = !_server.dhcp4.value && !_server.disableBridgeAdapter.value && !_server.nameServer2.locked;
        _inputNetmaskIP.enabled = !_server.dhcp4.value && !_server.disableBridgeAdapter.value && !_server.networkNetmask.locked;
        _inputGatewayIP.enabled = !_server.dhcp4.value && !_server.disableBridgeAdapter.value && !_server.networkGateway.locked;
        _cbDHCP.enabled = !_server.dhcp4.locked && !_server.disableBridgeAdapter.value;
        _cbDisableBridgeAdapter.enabled = !_server.disableBridgeAdapter.locked;
        _dropdownNetworkInterface.enabled = !_server.networkBridge.locked && !_server.disableBridgeAdapter.value;
        _inputAlertEmail.enabled = !_server.userEmail.locked;

        _updateForm();

    }

    public function setServer( server:Server ) {

        _server = server;
        
    }

    override public function updateContent( forced:Bool = false ) {
        super.updateContent();

        if ( _form != null ) {
            _inputNameServer.text = _server.nameServer1.value;
            _inputNameServer2.text = _server.nameServer2.value;
            _inputAlertEmail.text = _server.userEmail.value;
            _inputVagrantPassword.text = _server.vagrantUserPassword.value;
            _inputNetworkIP.text = _server.networkAddress.value;
            _inputNetmaskIP.text = _server.networkNetmask.value;
            _inputGatewayIP.text = _server.networkGateway.value;
            _stepperCPUs.value = _server.numCPUs.value;
            _stepperRAM.value = _server.memory.value;
            _cbOpenBrowser.selected = _server.openBrowser.value;
            _cbDHCP.selected = _server.dhcp4.value;

            _inputNetworkIP.enabled = !_server.dhcp4.value && !_server.disableBridgeAdapter.value && !_server.networkAddress.locked;
            _inputNameServer.enabled = !_server.dhcp4.value && !_server.disableBridgeAdapter.value && !_server.nameServer1.locked;
            _inputNameServer2.enabled = !_server.dhcp4.value && !_server.disableBridgeAdapter.value && !_server.nameServer2.locked;
            _inputNetmaskIP.enabled = !_server.dhcp4.value && !_server.disableBridgeAdapter.value && !_server.networkNetmask.locked;
            _inputGatewayIP.enabled = !_server.dhcp4.value && !_server.disableBridgeAdapter.value && !_server.networkGateway.locked;
            _cbDHCP.enabled = !_server.dhcp4.locked && !_server.disableBridgeAdapter.value;
            _cbDisableBridgeAdapter.selected = _server.disableBridgeAdapter.value;
            _cbDisableBridgeAdapter.enabled = !_server.disableBridgeAdapter.locked;
            _dropdownNetworkInterface.enabled = !_server.networkBridge.locked && !_server.disableBridgeAdapter.value;
            _inputAlertEmail.enabled = !_server.userEmail.locked;

            _dropdownNetworkInterface.selectedIndex = 0;
            for ( i in 0..._dropdownNetworkInterface.dataProvider.length ) {
                var d = _dropdownNetworkInterface.dataProvider.get( i );

                // Use getEffectiveNetworkInterface to get the actual interface value
                if ( d.name == _server.getEffectiveNetworkInterface() ) {
                    _dropdownNetworkInterface.selectedIndex = i;
                    break;
                }
            }
        }

        _updateForm();
    }

    function _updateForm() {
        // Check if server or UI components are null to prevent crashes
        if (_server == null || _cbDisableBridgeAdapter == null || 
            _dropdownNetworkInterface == null || _cbDHCP == null || 
            _inputNetworkIP == null || _inputGatewayIP == null || 
            _inputNetmaskIP == null || _inputNameServer == null || 
            _inputNameServer2 == null) {
            champaign.core.logging.Logger.warning('${this}: Cannot update form - server or UI components are null');
            return;
        }

        var canChangeBridgeAdapter:Bool = !_server.disableBridgeAdapter.locked;
        _cbDisableBridgeAdapter.selected = _server.disableBridgeAdapter.value;
        _cbDisableBridgeAdapter.enabled = canChangeBridgeAdapter;
        _cbDisableBridgeAdapter.update();
        _cbDisableBridgeAdapter.validateNow();
        _cbDisableBridgeAdapter.invalidate();

        var canChangeNetworkValues:Bool = !_server.disableBridgeAdapter.locked && !_server.disableBridgeAdapter.value;
        _dropdownNetworkInterface.enabled = canChangeNetworkValues && !_server.networkBridge.locked;
        _cbDHCP.enabled = canChangeNetworkValues && !_server.dhcp4.locked;
        _inputNetworkIP.enabled = canChangeNetworkValues && !_server.dhcp4.locked && !_server.dhcp4.value;
        _inputGatewayIP.enabled = canChangeNetworkValues && !_server.dhcp4.locked && !_server.dhcp4.value;
        _inputNetmaskIP.enabled = canChangeNetworkValues && !_server.dhcp4.locked && !_server.dhcp4.value;
        _inputNameServer.enabled = canChangeNetworkValues && !_server.dhcp4.locked && !_server.dhcp4.value;
        _inputNameServer2.enabled = canChangeNetworkValues && !_server.dhcp4.locked && !_server.dhcp4.value;
    }

    function _cbDHCP_Or_cbDisableBridgeAdapterChanged( ?e:Event ) {

        _server.disableBridgeAdapter.value = _cbDisableBridgeAdapter.selected;
        _server.dhcp4.value = _cbDHCP.selected;

        _updateForm();

    }

    function _generatePasswordTriggered( e:TriggerEvent ) {

        // Generate a random 16-character password using alphanumeric characters
        var newPassword = StrTools.randomString( StrTools.ALPHANUMERIC, 16 );
        _inputVagrantPassword.text = newPassword;

    }

    function _togglePasswordVisibilityTriggered( e:TriggerEvent ) {

        // Toggle the password visibility state
        _passwordVisible = !_passwordVisible;
        
        // Update the input field display mode
        _inputVagrantPassword.displayAsPassword = !_passwordVisible;
        
        // Trigger proper Feathers UI revalidation
        _inputVagrantPassword.setInvalid();
        
        // Update the button text
        _buttonTogglePassword.text = _passwordVisible ? "Hide" : "Show";

    }

    override function _cancel( ?e:Dynamic ) {
        // For advanced config, we don't remove provisional servers on cancel
        // Instead, we just return to the basic config page with no changes
        
        // Use CANCEL_PAGE to return to the basic config page
        var evt = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.CANCEL_PAGE );
        if (_server != null) {
            evt.server = _server;
            // Check that provisioner exists before accessing type to avoid null reference
            if (_server.provisioner != null) {
                evt.provisionerType = _server.provisioner.type;
                champaign.core.logging.Logger.info('${this}: Canceling advanced config with provisioner type: ${evt.provisionerType}');
            } else {
                champaign.core.logging.Logger.warning('${this}: Server has no provisioner, cannot determine type');
            }
        } else {
            champaign.core.logging.Logger.warning('${this}: No server object available for cancel event');
        }
        
        // The SuperHumanInstaller.hx _cancelAdvancedConfigureServer method will handle navigation
        this.dispatchEvent( evt );
    }
    
    function _saveButtonTriggered( e:TriggerEvent ) {

        if ( !_form.isValid() ) return;

        _server.nameServer1.value = StringTools.trim( _inputNameServer.text );
        _server.nameServer2.value = StringTools.trim( _inputNameServer2.text );
        _server.networkAddress.value = StringTools.trim( _inputNetworkIP.text );
        _server.networkNetmask.value = StringTools.trim( _inputNetmaskIP.text );
        _server.networkGateway.value = StringTools.trim( _inputGatewayIP.text );
        _server.userEmail.value = StringTools.trim( _inputAlertEmail.text );
        _server.numCPUs.value = Std.int( _stepperCPUs.value );
        _server.memory.value = Std.int( _stepperRAM.value );
        _server.openBrowser.value = _cbOpenBrowser.selected;
        // Get the selected network interface
        var selectedInterface = _dropdownNetworkInterface.selectedItem.name;
        
        // Handle "Default" (empty string) case
        if (selectedInterface == "") {
            // Use the default from preferences
            var defaultNic = SuperHumanInstaller.getInstance().config.preferences.defaultNetworkInterface;
            if (defaultNic != null && defaultNic != "" && defaultNic != "none") {
                selectedInterface = defaultNic;
            }
        }
        
        // Set the value in the server object
        _server.networkBridge.value = selectedInterface;
        champaign.core.logging.Logger.info('${this}: Set network bridge to "${selectedInterface}"');
        _server.dhcp4.value = _cbDHCP.selected;
        _server.disableBridgeAdapter.value = _cbDisableBridgeAdapter.selected;
        _server.vagrantUserPassword.value = StringTools.trim( _inputVagrantPassword.text );

        var evt = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.SAVE_ADVANCED_SERVER_CONFIGURATION );
        evt.server = _server;
        this.dispatchEvent( evt );

    }
    
}
