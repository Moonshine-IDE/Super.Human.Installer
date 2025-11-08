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

import feathers.controls.Alert;
import feathers.controls.Label;
import feathers.controls.LayoutGroup;
import feathers.controls.TextInput;
import feathers.core.PopUpManager;
import feathers.events.TriggerEvent;
import feathers.layout.HorizontalAlign;
import feathers.layout.HorizontalLayout;
import feathers.layout.HorizontalLayoutData;
import feathers.layout.VerticalAlign;
import feathers.layout.VerticalLayout;
import feathers.layout.VerticalLayoutData;
import genesis.application.components.GenesisFormButton;
import genesis.application.components.HLine;
import genesis.application.managers.LanguageManager;
import genesis.application.theme.GenesisApplicationTheme;
import openfl.events.Event;
import openfl.events.KeyboardEvent;
import openfl.ui.Keyboard;
import superhuman.server.Server;

/**
 * A dialog for confirming server deletion with TextInput validation
 * Requires typing "DELETE" exactly to enable deletion options
 */
class DeleteConfirmationDialog {
    
    // Dialog components
    private var _alert:Alert;
    private var _content:LayoutGroup;
    private var _confirmationInput:TextInput;
    private var _removeOnlyButton:GenesisFormButton;
    private var _deleteFilesButton:GenesisFormButton;
    private var _cancelButton:GenesisFormButton;
    private var _validationLabel:Label;
    
    // Server to be deleted
    private var _server:Server;
    
    // Callback for when dialog is closed
    private var _callback:(state:{index:Int}) -> Void;
    
    // Result constants
    private static final RESULT_REMOVE_ONLY:Int = 0;
    private static final RESULT_DELETE_FILES:Int = 1;
    private static final RESULT_CANCEL:Int = 2;
    
    // Required text to enable deletion
    private static final REQUIRED_TEXT:String = "DELETE";
    
    /**
     * Static method to create and show a delete confirmation dialog.
     * @param server The server to be deleted
     * @param callback Function to call when an option is selected
     * @return The created Alert instance
     */
    public static function show(
        server:Server,
        callback:(state:{index:Int}) -> Void
    ):Alert {
        var dialog = new DeleteConfirmationDialog(server, callback);
        return dialog._alert;
    }
    
    /**
     * Constructor
     */
    public function new(
        server:Server,
        callback:(state:{index:Int}) -> Void
    ) {
        _server = server;
        _callback = callback;
        
        // Create the alert dialog
        _alert = createDialog();
    }
    
    /**
     * Create the dialog
     */
    private function createDialog():Alert {
        // Define width and padding for all components
        final dialogWidth:Float = GenesisApplicationTheme.GRID * 80; // Optimal width for readability
        
        // Create alert with no buttons (we'll add them manually in the content)
        var alert = Alert.show("", LanguageManager.getInstance().getString('alert.deleteserver.title'), [], null);
        
        // Set the alert to be proper width
        alert.width = dialogWidth;
        
        // Create content container with vertical layout
        _content = new LayoutGroup();
        _content.width = dialogWidth;
        _content.layoutData = new VerticalLayoutData(100);
        
        var verticalLayout = new VerticalLayout();
        verticalLayout.gap = GenesisApplicationTheme.GRID * 2;
        verticalLayout.paddingTop = GenesisApplicationTheme.GRID * 2;
        verticalLayout.paddingBottom = GenesisApplicationTheme.GRID * 2;
        verticalLayout.paddingLeft = GenesisApplicationTheme.GRID * 4;
        verticalLayout.paddingRight = GenesisApplicationTheme.GRID * 4;
        verticalLayout.horizontalAlign = HorizontalAlign.LEFT;
        _content.layout = verticalLayout;
        
        // Add server information
        var serverInfoGroup = new LayoutGroup();
        serverInfoGroup.layoutData = new VerticalLayoutData(100);
        
        var serverInfoLayout = new VerticalLayout();
        serverInfoLayout.gap = GenesisApplicationTheme.GRID;
        serverInfoLayout.horizontalAlign = HorizontalAlign.LEFT;
        serverInfoGroup.layout = serverInfoLayout;
        
        // Add warning message
        var warningLabel = new Label();
        warningLabel.text = LanguageManager.getInstance().getString('alert.deleteserver.text');
        warningLabel.wordWrap = true;
        warningLabel.layoutData = new VerticalLayoutData(100);
        serverInfoGroup.addChild(warningLabel);
        
        // Add server information
        var serverLabel = new Label();
        serverLabel.text = 'Server ID: ${_server.id} (${_server.fqdn})';
        serverLabel.wordWrap = true;
        serverLabel.variant = GenesisApplicationTheme.LABEL_COPYRIGHT;
        serverLabel.layoutData = new VerticalLayoutData(100);
        serverInfoGroup.addChild(serverLabel);
        
        _content.addChild(serverInfoGroup);
        
        // Add separator
        var separator = new HLine();
        separator.alpha = 0.3;
        separator.width = dialogWidth * 0.9;
        separator.layoutData = new VerticalLayoutData(90);
        _content.addChild(separator);
        
        // Add confirmation section
        var confirmationGroup = new LayoutGroup();
        confirmationGroup.layoutData = new VerticalLayoutData(100);
        
        var confirmationLayout = new VerticalLayout();
        confirmationLayout.gap = GenesisApplicationTheme.GRID;
        confirmationLayout.horizontalAlign = HorizontalAlign.LEFT;
        confirmationGroup.layout = confirmationLayout;
        
        // Add confirmation instructions
        var instructionLabel = new Label();
        instructionLabel.text = LanguageManager.getInstance().getString('alert.deleteserver.confirmtext');
        instructionLabel.wordWrap = true;
        instructionLabel.layoutData = new VerticalLayoutData(100);
        confirmationGroup.addChild(instructionLabel);
        
        // Add text input for confirmation
        _confirmationInput = new TextInput();
        _confirmationInput.prompt = LanguageManager.getInstance().getString('alert.deleteserver.placeholder');
        _confirmationInput.width = dialogWidth * 0.8;
        _confirmationInput.addEventListener(Event.CHANGE, _onConfirmationTextChanged);
        _confirmationInput.addEventListener(KeyboardEvent.KEY_DOWN, _onKeyDown);
        confirmationGroup.addChild(_confirmationInput);
        
        // Add validation feedback label
        _validationLabel = new Label();
        _validationLabel.text = "";
        _validationLabel.variant = GenesisApplicationTheme.LABEL_ERROR;
        _validationLabel.wordWrap = true;
        _validationLabel.layoutData = new VerticalLayoutData(100);
        _validationLabel.visible = _validationLabel.includeInLayout = false;
        confirmationGroup.addChild(_validationLabel);
        
        _content.addChild(confirmationGroup);
        
        // Add separator before buttons
        var buttonSeparator = new HLine();
        buttonSeparator.alpha = 0.3;
        buttonSeparator.width = dialogWidth * 0.9;
        buttonSeparator.layoutData = new VerticalLayoutData(90);
        _content.addChild(buttonSeparator);
        
        // Create button container
        var buttonGroup = new LayoutGroup();
        buttonGroup.layoutData = new VerticalLayoutData(100);
        
        var buttonLayout = new HorizontalLayout();
        buttonLayout.gap = GenesisApplicationTheme.GRID * 2;
        buttonLayout.horizontalAlign = HorizontalAlign.CENTER;
        buttonGroup.layout = buttonLayout;
        
        // Create Remove Only button
        _removeOnlyButton = new GenesisFormButton();
        _removeOnlyButton.text = LanguageManager.getInstance().getString('alert.deleteserver.buttondelete');
        _removeOnlyButton.width = GenesisApplicationTheme.GRID * 22;
        _removeOnlyButton.enabled = false; // Disabled until validation passes
        _removeOnlyButton.addEventListener(TriggerEvent.TRIGGER, _onRemoveOnlyClicked);
        buttonGroup.addChild(_removeOnlyButton);
        
        // Create Delete Files button
        _deleteFilesButton = new GenesisFormButton();
        _deleteFilesButton.text = LanguageManager.getInstance().getString('alert.deleteserver.buttondeletefiles');
        _deleteFilesButton.width = GenesisApplicationTheme.GRID * 22;
        _deleteFilesButton.enabled = false; // Disabled until validation passes
        _deleteFilesButton.addEventListener(TriggerEvent.TRIGGER, _onDeleteFilesClicked);
        buttonGroup.addChild(_deleteFilesButton);
        
        // Create cancel button
        _cancelButton = new GenesisFormButton();
        _cancelButton.text = LanguageManager.getInstance().getString('alert.deleteserver.buttoncancel');
        _cancelButton.width = GenesisApplicationTheme.GRID * 20;
        _cancelButton.addEventListener(TriggerEvent.TRIGGER, _onCancelClicked);
        buttonGroup.addChild(_cancelButton);
        
        _content.addChild(buttonGroup);
        
        // Add custom content to the alert
        alert.addChild(_content);
        
        // Note: Focus is automatically handled by the dialog system
        _confirmationInput.focusEnabled = true;
        
        return alert;
    }
    
    /**
     * Handle confirmation text changes with real-time validation
     */
    private function _onConfirmationTextChanged(e:Event):Void {
        var inputText = _confirmationInput.text;
        var isValid = (inputText == REQUIRED_TEXT);
        
        // Update button states
        _removeOnlyButton.enabled = isValid;
        _deleteFilesButton.enabled = isValid;
        
        // Update validation feedback
        if (inputText.length > 0 && !isValid) {
            _validationLabel.text = LanguageManager.getInstance().getString('alert.deleteserver.validationerror');
            _validationLabel.visible = _validationLabel.includeInLayout = true;
        } else {
            _validationLabel.visible = _validationLabel.includeInLayout = false;
        }
        
        // Visual feedback on input field
        if (inputText.length > 0) {
            _confirmationInput.variant = isValid ? null : GenesisApplicationTheme.INVALID;
        } else {
            _confirmationInput.variant = null;
        }
    }
    
    /**
     * Handle keyboard events for better UX
     */
    private function _onKeyDown(e:KeyboardEvent):Void {
        // If user presses Enter and validation passes, trigger remove only action
        if (e.keyCode == Keyboard.ENTER && _removeOnlyButton.enabled) {
            _closeDialog(RESULT_REMOVE_ONLY);
        }
        // If user presses Escape, cancel the dialog
        else if (e.keyCode == Keyboard.ESCAPE) {
            _closeDialog(RESULT_CANCEL);
        }
    }
    
    /**
     * Handle remove only button click
     */
    private function _onRemoveOnlyClicked(e:TriggerEvent):Void {
        _closeDialog(RESULT_REMOVE_ONLY);
    }
    
    /**
     * Handle delete files button click
     */
    private function _onDeleteFilesClicked(e:TriggerEvent):Void {
        _closeDialog(RESULT_DELETE_FILES);
    }
    
    /**
     * Handle cancel button click
     */
    private function _onCancelClicked(e:TriggerEvent):Void {
        _closeDialog(RESULT_CANCEL);
    }
    
    /**
     * Close the dialog with a result
     */
    private function _closeDialog(result:Int):Void {
        // Clean up event listeners
        if (_confirmationInput != null) {
            _confirmationInput.removeEventListener(Event.CHANGE, _onConfirmationTextChanged);
            _confirmationInput.removeEventListener(KeyboardEvent.KEY_DOWN, _onKeyDown);
        }
        
        if (_removeOnlyButton != null) {
            _removeOnlyButton.removeEventListener(TriggerEvent.TRIGGER, _onRemoveOnlyClicked);
        }
        
        if (_deleteFilesButton != null) {
            _deleteFilesButton.removeEventListener(TriggerEvent.TRIGGER, _onDeleteFilesClicked);
        }
        
        if (_cancelButton != null) {
            _cancelButton.removeEventListener(TriggerEvent.TRIGGER, _onCancelClicked);
        }
        
        // Store local reference to callback before clearing
        var callback = _callback;
        
        // Clear all references for garbage collection
        _callback = null;
        _server = null;
        _content = null;
        _confirmationInput = null;
        _removeOnlyButton = null;
        _deleteFilesButton = null;
        _cancelButton = null;
        _validationLabel = null;
        
        // Close the alert using PopUpManager
        try {
            if (_alert != null) {
                PopUpManager.removePopUp(_alert);
                _alert = null;
            }
        } catch (e:Dynamic) {
            // Log error but continue with callback
        }
        
        // Execute the callback
        if (callback != null) {
            callback({index: result});
        }
    }
}
