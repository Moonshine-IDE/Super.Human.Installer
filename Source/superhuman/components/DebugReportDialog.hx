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
import feathers.controls.Alert;
import feathers.controls.Label;
import feathers.controls.LayoutGroup;
import feathers.controls.TextArea;
import feathers.core.PopUpManager;
import feathers.events.TriggerEvent;
import feathers.layout.HorizontalAlign;
import feathers.layout.HorizontalLayout;
import feathers.layout.HorizontalLayoutData;
import feathers.layout.VerticalAlign;
import feathers.layout.VerticalLayout;
import feathers.layout.VerticalLayoutData;
import genesis.application.components.GenesisFormButton;
import genesis.application.components.GenesisFormTextInput;
import genesis.application.components.HLine;
import genesis.application.managers.LanguageManager;
import genesis.application.managers.ToastManager;
import genesis.application.theme.GenesisApplicationTheme;
import openfl.events.Event;
import superhuman.server.Server;

/**
 * A dialog for collecting user contact information for debug reports
 * Prompts for username, email, and optional description before submitting debug info
 */
class DebugReportDialog {
    
    // Dialog components
    private var _alert:Alert;
    private var _content:LayoutGroup;
    private var _usernameInput:GenesisFormTextInput;
    private var _emailInput:GenesisFormTextInput;
    private var _descriptionInput:TextArea;
    private var _submitButton:GenesisFormButton;
    private var _cancelButton:GenesisFormButton;
    
    // Context for debug report
    private var _server:Server;
    private var _errorType:String;
    private var _debugPackagePath:String;
    private var _callback:(username:String, email:String, description:String) -> Void;
    
    // Result constants
    private static final RESULT_SUBMIT:Int = 0;
    private static final RESULT_CANCEL:Int = 1;
    
    /**
     * Static method to create and show a debug report dialog.
     * @param server Optional server that had the error (null for app crashes)
     * @param errorType Type of error ("crash", "provision_failure", etc.)
     * @param debugPackagePath Optional path to pre-generated debug package
     * @param callback Function to call with user input when submitted
     * @return The created Alert instance
     */
    public static function show(
        server:Server,
        errorType:String,
        debugPackagePath:String = null,
        callback:(username:String, email:String, description:String) -> Void
    ):Alert {
        var dialog = new DebugReportDialog(server, errorType, debugPackagePath, callback);
        return dialog._alert;
    }
    
    /**
     * Constructor
     */
    public function new(
        server:Server,
        errorType:String,
        debugPackagePath:String = null,
        callback:(username:String, email:String, description:String) -> Void
    ) {
        _server = server;
        _errorType = errorType;
        _debugPackagePath = debugPackagePath;
        _callback = callback;
        
        // Create the alert dialog
        _alert = createDialog();
    }
    
    /**
     * Create the dialog
     */
    private function createDialog():Alert {
        // Define width and padding for all components
        final dialogWidth:Float = GenesisApplicationTheme.GRID * 90;
        
        // Create alert with no buttons (we'll add them manually in the content)
        var title = _errorType == "crash" ? "Submit Bug Report" : 
                   (_errorType == "feedback" ? "Submit Feedback" : "Submit Debug Information");
        var alert = Alert.show("", title, [], null);
        
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
        
        // Add information section
        var infoGroup = new LayoutGroup();
        infoGroup.layoutData = new VerticalLayoutData(100);
        
        var infoLayout = new VerticalLayout();
        infoLayout.gap = GenesisApplicationTheme.GRID;
        infoLayout.horizontalAlign = HorizontalAlign.LEFT;
        infoGroup.layout = infoLayout;
        
        // Add description message
        var descriptionLabel = new Label();
        if (_errorType == "crash") {
            descriptionLabel.text = "Help us improve Super Human Installer by submitting this bug report. Your contact information will be used for follow-up if needed.";
        } else if (_errorType == "feedback") {
            descriptionLabel.text = "Share your ideas and suggestions to help us improve Super Human Installer. Your feedback is valuable to us!";
        } else if (_server != null) {
            descriptionLabel.text = 'Submit debug information for server #${_server.id} (${_server.fqdn}) to help us diagnose the issue.';
        } else {
            descriptionLabel.text = "Submit debug information to help us diagnose and fix this issue.";
        }
        descriptionLabel.wordWrap = true;
        descriptionLabel.layoutData = new VerticalLayoutData(100);
        infoGroup.addChild(descriptionLabel);
        
        // Add information about what will be shared
        var dataCollectionLabel = new Label();
        if (_errorType == "crash") {
            dataCollectionLabel.text = "Debug package will include: system information, application logs, and configuration files. A debug package will be created and the support request will open in your browser.";
        } else if (_errorType == "feedback") {
            dataCollectionLabel.text = "Your feedback will be submitted along with basic system information to help us understand your environment. No sensitive data will be included.";
        } else if (_server != null) {
            dataCollectionLabel.text = 'Debug package will include: system information, application logs, server configuration files, console output, and network settings for server #${_server.id}. A debug package will be created and the support request will open in your browser.';
        } else {
            dataCollectionLabel.text = "Debug package will include: system information, application logs, and configuration files. A debug package will be created and the support request will open in your browser.";
        }
        dataCollectionLabel.wordWrap = true;
        dataCollectionLabel.variant = GenesisApplicationTheme.LABEL_COPYRIGHT;
        dataCollectionLabel.layoutData = new VerticalLayoutData(100);
        infoGroup.addChild(dataCollectionLabel);
        
        _content.addChild(infoGroup);
        
        // Add separator
        var separator = new HLine();
        separator.alpha = 0.3;
        separator.width = dialogWidth * 0.9;
        separator.layoutData = new VerticalLayoutData(90);
        _content.addChild(separator);
        
        // Add input section
        var inputGroup = new LayoutGroup();
        inputGroup.layoutData = new VerticalLayoutData(100);
        
        var inputLayout = new VerticalLayout();
        inputLayout.gap = GenesisApplicationTheme.GRID * 2;
        inputLayout.horizontalAlign = HorizontalAlign.LEFT;
        inputGroup.layout = inputLayout;
        
        // Get saved values from user preferences
        var savedUsername = "";
        var savedEmail = "";
        var userConfig = SuperHumanInstaller.getInstance().config.user;
        if (userConfig != null) {
            if (Reflect.hasField(userConfig, "debugReportUsername")) {
                savedUsername = Reflect.field(userConfig, "debugReportUsername");
            }
            if (Reflect.hasField(userConfig, "debugReportEmail")) {
                savedEmail = Reflect.field(userConfig, "debugReportEmail");
            }
        }
        
        // Username input
        var usernameLabel = new Label();
        usernameLabel.text = "Your Name:";
        usernameLabel.variant = GenesisApplicationTheme.LABEL_DEFAULT;
        inputGroup.addChild(usernameLabel);
        
        _usernameInput = new GenesisFormTextInput(savedUsername, "Enter your full name", null, false);
        _usernameInput.minLength = 1;
        _usernameInput.width = dialogWidth * 0.8;
        _usernameInput.addEventListener(Event.CHANGE, _onInputChanged);
        inputGroup.addChild(_usernameInput);
        
        // Email input
        var emailLabel = new Label();
        emailLabel.text = "Email Address:";
        emailLabel.variant = GenesisApplicationTheme.LABEL_DEFAULT;
        inputGroup.addChild(emailLabel);
        
        _emailInput = new GenesisFormTextInput(savedEmail, "Enter your email address", null, false);
        _emailInput.minLength = 1;
        _emailInput.width = dialogWidth * 0.8;
        _emailInput.addEventListener(Event.CHANGE, _onInputChanged);
        inputGroup.addChild(_emailInput);
        
        // Description input
        var descLabel = new Label();
        if (_errorType == "feedback") {
            descLabel.text = "Your Feedback or Suggestion:";
        } else {
            descLabel.text = "Additional Information (Optional):";
        }
        descLabel.variant = GenesisApplicationTheme.LABEL_DEFAULT;
        inputGroup.addChild(descLabel);
        
        _descriptionInput = new TextArea();
        if (_errorType == "feedback") {
            _descriptionInput.prompt = "Share your ideas, feature requests, or suggestions...";
        } else {
            _descriptionInput.prompt = "Describe what you were doing when the issue occurred...";
        }
        _descriptionInput.width = dialogWidth * 0.8;
        _descriptionInput.height = GenesisApplicationTheme.GRID * 15;
        inputGroup.addChild(_descriptionInput);
        
        _content.addChild(inputGroup);
        
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
        
        // Create submit button
        _submitButton = new GenesisFormButton();
        _submitButton.text = "Submit Report";
        _submitButton.width = GenesisApplicationTheme.GRID * 20;
        _submitButton.enabled = false; // Disabled until validation passes
        _submitButton.addEventListener(TriggerEvent.TRIGGER, _onSubmitClicked);
        buttonGroup.addChild(_submitButton);
        
        // Create cancel button
        _cancelButton = new GenesisFormButton();
        _cancelButton.text = "Cancel";
        _cancelButton.width = GenesisApplicationTheme.GRID * 20;
        _cancelButton.addEventListener(TriggerEvent.TRIGGER, _onCancelClicked);
        buttonGroup.addChild(_cancelButton);
        
        _content.addChild(buttonGroup);
        
        // Add custom content to the alert
        alert.addChild(_content);
        
        // Set focus to username field if empty, otherwise email field
        if (savedUsername == null || savedUsername == "") {
            _usernameInput.focusEnabled = true;
        } else {
            _emailInput.focusEnabled = true;
        }
        
        // Initial validation check
        _validateInputs();
        
        return alert;
    }
    
    /**
     * Handle input field changes and validate
     */
    private function _onInputChanged(e:Event):Void {
        _validateInputs();
    }
    
    /**
     * Validate all input fields and update submit button state
     */
    private function _validateInputs():Void {
        var isValid = true;
        
        // Check username
        var username = StringTools.trim(_usernameInput.text);
        if (username == null || username.length == 0) {
            isValid = false;
        }
        
        // Check email
        var email = StringTools.trim(_emailInput.text);
        if (email == null || email.length == 0 || !_emailInput.isValid()) {
            isValid = false;
        }
        
        // Update submit button state
        _submitButton.enabled = isValid;
    }
    
    /**
     * Handle submit button click
     */
    private function _onSubmitClicked(e:TriggerEvent):Void {
        // Validate one more time
        if (!_submitButton.enabled) {
            return;
        }
        
        var username = StringTools.trim(_usernameInput.text);
        var email = StringTools.trim(_emailInput.text);
        var description = StringTools.trim(_descriptionInput.text);
        
        // Save user preferences for future use
        var userConfig = SuperHumanInstaller.getInstance().config.user;
        if (userConfig != null) {
            Reflect.setField(userConfig, "debugReportUsername", username);
            Reflect.setField(userConfig, "debugReportEmail", email);
            Logger.info('DebugReportDialog: Saved user contact info to preferences');
        }
        
        // Call callback with user input first, before closing dialog
        if (_callback != null) {
            try {
                Logger.info('DebugReportDialog: Executing callback with user data');
                _callback(username, email, description);
                Logger.info('DebugReportDialog: Callback execution completed');
            } catch (e:Dynamic) {
                Logger.error('DebugReportDialog: Error in callback execution: ${e}');
            }
        } else {
            Logger.warning('DebugReportDialog: No callback provided');
        }
        
        // Close dialog after callback execution
        _closeDialog();
    }
    
    /**
     * Handle cancel button click
     */
    private function _onCancelClicked(e:TriggerEvent):Void {
        _closeDialog();
    }
    
    /**
     * Close the dialog and clean up resources
     */
    private function _closeDialog():Void {
        // Clean up event listeners
        if (_usernameInput != null) {
            _usernameInput.removeEventListener(Event.CHANGE, _onInputChanged);
        }
        
        if (_emailInput != null) {
            _emailInput.removeEventListener(Event.CHANGE, _onInputChanged);
        }
        
        if (_submitButton != null) {
            _submitButton.removeEventListener(TriggerEvent.TRIGGER, _onSubmitClicked);
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
        _usernameInput = null;
        _emailInput = null;
        _descriptionInput = null;
        _submitButton = null;
        _cancelButton = null;
        
        // Close the alert using PopUpManager
        try {
            if (_alert != null) {
                PopUpManager.removePopUp(_alert);
                _alert = null;
            }
        } catch (e:Dynamic) {
            Logger.error('DebugReportDialog: Error closing dialog: ${e}');
        }
    }
}
