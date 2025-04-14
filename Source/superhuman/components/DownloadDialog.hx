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
import feathers.controls.Button;
import feathers.controls.Check;
import feathers.controls.Label;
import feathers.controls.LayoutGroup;
import feathers.controls.PopUpListView;
import feathers.controls.ScrollContainer;
import feathers.core.PopUpManager;
import feathers.data.ArrayCollection;
import feathers.events.TriggerEvent;
import feathers.layout.HorizontalAlign;
import feathers.layout.HorizontalLayout;
import feathers.layout.HorizontalLayoutData;
import feathers.layout.VerticalAlign;
import feathers.layout.VerticalLayout;
import feathers.layout.VerticalLayoutData;
import genesis.application.components.GenesisFormButton;
import genesis.application.components.GenesisFormCheckBox;
import genesis.application.components.HLine;
import genesis.application.components.GenesisForm;
import genesis.application.components.GenesisFormRow;
import genesis.application.theme.GenesisApplicationTheme;
import superhuman.downloaders.HCLDownloader;
import superhuman.events.SuperHumanApplicationEvent;
import superhuman.server.cache.SuperHumanCachedFile;
import superhuman.theme.SuperHumanInstallerTheme;
import openfl.display.Sprite;

/**
 * A dialog for downloading missing files from the cache
 */
class DownloadDialog {
    
    // File to download
    private var _file:SuperHumanCachedFile;
    
    // Dialog components
    private var _alert:Alert;
    private var _content:LayoutGroup;
    private var _sourceGroup:LayoutGroup;
    private var _tokenDropdown:PopUpListView;
    private var _hclSourceCheck:GenesisFormCheckBox;
    private var _customSourceCheck:Check;
    private var _downloadButton:GenesisFormButton;
    private var _cancelButton:GenesisFormButton;
    private var _secretsButton:GenesisFormButton;
    
    // Progress indicator components
    private var _progressGroup:LayoutGroup;
    private var _progressBar:genesis.application.components.ProgressBar;
    private var _progressLabel:Label;
    private var _statusLabel:Label;
    
    // Token data
    private var _hclTokens:Array<{name:String, key:String}>;
    private var _customResources:Array<{name:String, url:String}>;
    
    // Downloader instance
    private var _downloader:HCLDownloader;
    
    // Download in progress
    private var _downloadInProgress:Bool = false;
    
    // Callback for when dialog is closed
    private var _callback:(state:{index:Int, ?userData:Dynamic}) -> Void;
    
    // Parent sprite for centering
    private var _parentSprite:Sprite;
    
    // Result constants
    private static final RESULT_CANCEL:Int = 0;
    private static final RESULT_DOWNLOAD:Int = 1;
    private static final RESULT_SECRETS:Int = 2;
    
    /**
     * Static method to create and show a download dialog.
     * @param file The file to download
     * @param title The title of the dialog
     * @param callback Function to call when an option is selected
     * @param parentSprite The parent sprite to center the dialog on
     * @return The created Alert instance
     */
    public static function show(
        file:SuperHumanCachedFile,
        title:String,
        callback:(state:{index:Int, ?userData:Dynamic}) -> Void,
        ?parentSprite:Sprite
    ):Alert {
        var dialog = new DownloadDialog(file, title, callback, parentSprite);
        return dialog._alert;
    }
    
    /**
     * Constructor
     */
    public function new(
        file:SuperHumanCachedFile, 
        title:String, 
        callback:(state:{index:Int, ?userData:Dynamic}) -> Void,
        ?parentSprite:Sprite
    ) {
        _file = file;
        _callback = callback;
        _parentSprite = parentSprite;
        
        // Get downloader instance
        _downloader = HCLDownloader.getInstance();
        
        // Get available tokens
        _hclTokens = _downloader.getAvailableHCLTokens();
        _customResources = _downloader.getAvailableCustomResources();
        
        // Create the alert dialog
        _alert = createDialog(title);
    }
    
    /**
     * Create the dialog
     */
    private function createDialog(title:String):Alert {
        // Define width and padding for all components
        final dialogWidth:Float = GenesisApplicationTheme.GRID * 80; // Increased width
        
        // Create alert with no buttons (we'll add them manually in the content)
        var alert = Alert.show("", title, [], null);
        
        // Set the alert to be wider
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
        verticalLayout.horizontalAlign = HorizontalAlign.CENTER;
        _content.layout = verticalLayout;
        
        // Add file information
        var fileInfoGroup = new LayoutGroup();
        fileInfoGroup.layoutData = new VerticalLayoutData(100);
        
        var fileInfoLayout = new VerticalLayout();
        fileInfoLayout.gap = GenesisApplicationTheme.GRID;
        fileInfoLayout.horizontalAlign = HorizontalAlign.LEFT;
        fileInfoGroup.layout = fileInfoLayout;
        
        // Add file information labels
        var fileNameLabel = new Label("File: " + _file.originalFilename);
        fileNameLabel.wordWrap = true;
        fileNameLabel.layoutData = new VerticalLayoutData(100);
        fileInfoGroup.addChild(fileNameLabel);
        
        var fileRoleLabel = new Label("Role: " + _file.role);
        fileRoleLabel.wordWrap = true;
        fileRoleLabel.layoutData = new VerticalLayoutData(100);
        fileInfoGroup.addChild(fileRoleLabel);
        
        var fileTypeLabel = new Label("Type: " + _file.type);
        fileTypeLabel.wordWrap = true;
        fileTypeLabel.layoutData = new VerticalLayoutData(100);
        fileInfoGroup.addChild(fileTypeLabel);
        
        if (_file.version != null && _file.version.fullVersion != null) {
            var fileVersionLabel = new Label("Version: " + _file.version.fullVersion);
            fileVersionLabel.wordWrap = true;
            fileVersionLabel.layoutData = new VerticalLayoutData(100);
            fileInfoGroup.addChild(fileVersionLabel);
        }
        
        _content.addChild(fileInfoGroup);
        
        // Add SHA256 hash if available
        if (_file.sha256 != null) {
            var shaHashLabel = new Label("SHA256: " + _file.sha256);
            shaHashLabel.wordWrap = true;
            shaHashLabel.layoutData = new VerticalLayoutData(100);
            fileInfoGroup.addChild(shaHashLabel);
        }
        
        // Add separator
        var separator = new HLine();
        separator.alpha = 0.3;
        separator.width = dialogWidth * 0.9;
        separator.layoutData = new VerticalLayoutData(90);
        _content.addChild(separator);
        
        // Determine which token sources are available and configure UI accordingly
        var hasHCLTokens:Bool = (_hclTokens != null && _hclTokens.length > 0);
        var hasCustomResources:Bool = (_customResources != null && _customResources.length > 0);
        
        Logger.error('Dialog setup - HCL Tokens available: ${hasHCLTokens} (${_hclTokens != null ? _hclTokens.length : 0}), Custom resources available: ${hasCustomResources} (${_customResources != null ? _customResources.length : 0})');
        
        if (hasHCLTokens || hasCustomResources) {
            // At least one token source available, show source options with toggle
            _sourceGroup = new LayoutGroup();
            _sourceGroup.layoutData = new VerticalLayoutData(100);
            
            var sourceLabel = new Label("Select Token Source:");
            sourceLabel.layoutData = new VerticalLayoutData(100);
            _content.addChild(sourceLabel);
            
            // Create toggle container with horizontal layout similar to FileSyncSetting
            var toggleContainer = new LayoutGroup();
            var toggleLayout = new HorizontalLayout();
            toggleLayout.gap = GenesisApplicationTheme.GRID * 2;
            toggleLayout.verticalAlign = VerticalAlign.MIDDLE;
            toggleLayout.horizontalAlign = HorizontalAlign.CENTER;
            toggleContainer.layout = toggleLayout;
            
            // Create HCL label (left side)
            var hclLabel = new Label();
            hclLabel.text = "HCL Download Portal";
            hclLabel.variant = GenesisApplicationTheme.LABEL_DEFAULT;
            if (!hasHCLTokens) {
                hclLabel.alpha = 0.5; // Dim if not available
            }
            toggleContainer.addChild(hclLabel);
            
            // Create checkbox toggle with empty text
            _hclSourceCheck = new GenesisFormCheckBox("");
            
            // Logic for checkbox state:
            // - Unchecked = HCL Download Portal (false)
            // - Checked = Custom Resource URL (true)
            
            // Enable the toggle only if both source types are available
            _hclSourceCheck.enabled = (hasHCLTokens && hasCustomResources);
            
            // Default selection logic:
            // - False (unchecked) = HCL Download Portal
            // - True (checked) = Custom Resource URL
            _hclSourceCheck.selected = !hasHCLTokens && hasCustomResources;
            
            _hclSourceCheck.addEventListener(TriggerEvent.TRIGGER, onSourceChanged);
            toggleContainer.addChild(_hclSourceCheck);
            
            // Create Custom label (right side)
            var customLabel = new Label();
            customLabel.text = "Custom Resource URL";
            customLabel.variant = GenesisApplicationTheme.LABEL_DEFAULT;
            if (!hasCustomResources) {
                customLabel.alpha = 0.5; // Dim if not available
            }
            toggleContainer.addChild(customLabel);
            
            // For compatibility with existing code (not actually displayed)
            _customSourceCheck = new Check();
            _customSourceCheck.visible = false;
            _customSourceCheck.includeInLayout = false;
            _customSourceCheck.selected = !_hclSourceCheck.selected;
            
            _sourceGroup.addChild(toggleContainer);
            
            _content.addChild(_sourceGroup);
            
            // Token dropdown
            var tokenRow = new GenesisFormRow();
            tokenRow.text = "Select Token:";
            
            _tokenDropdown = new PopUpListView();
            tokenRow.content.addChild(_tokenDropdown);
            
            // Populate token dropdown with appropriate tokens
            updateTokenDropdown();
            
            _content.addChild(tokenRow);
        } else {
            // No token sources available, inform user
            var noTokensLabel = new Label("No download tokens are configured.");
            noTokensLabel.wordWrap = true;
            noTokensLabel.variant = GenesisApplicationTheme.LABEL_SMALL_CENTERED;
            noTokensLabel.layoutData = new VerticalLayoutData(100);
            _content.addChild(noTokensLabel);
        }
        
        // Create progress indicator (initially hidden)
        _progressGroup = new LayoutGroup();
        _progressGroup.layoutData = new VerticalLayoutData(100);
        _progressGroup.visible = _progressGroup.includeInLayout = false;
        
        var progressLayout = new VerticalLayout();
        progressLayout.gap = GenesisApplicationTheme.GRID;
        progressLayout.horizontalAlign = HorizontalAlign.CENTER;
        _progressGroup.layout = progressLayout;
        
        // Status label
        _statusLabel = new Label("Preparing download...");
        _statusLabel.wordWrap = true;
        _statusLabel.layoutData = new VerticalLayoutData(100);
        _progressGroup.addChild(_statusLabel);
        
        // Progress bar
        _progressBar = new genesis.application.components.ProgressBar();
        _progressBar.width = dialogWidth * 0.8;
        _progressGroup.addChild(_progressBar);
        
        // Progress label
        _progressLabel = new Label("0%");
        _progressGroup.addChild(_progressLabel);
        
        _content.addChild(_progressGroup);
        
        // Create button container centered at the bottom
        var buttonGroup = new LayoutGroup();
        buttonGroup.layoutData = new VerticalLayoutData(100);
        
        var buttonLayout = new HorizontalLayout();
        buttonLayout.gap = GenesisApplicationTheme.GRID * 2;
        buttonLayout.horizontalAlign = HorizontalAlign.CENTER;
        buttonGroup.layout = buttonLayout;
        
        // Create download button
        _downloadButton = new GenesisFormButton("Download File");
        _downloadButton.width = GenesisApplicationTheme.GRID * 20;
        _downloadButton.addEventListener(TriggerEvent.TRIGGER, onDownloadClicked);
        buttonGroup.addChild(_downloadButton);
        
        // Create cancel button
        _cancelButton = new GenesisFormButton("Cancel");
        _cancelButton.width = GenesisApplicationTheme.GRID * 20;
        _cancelButton.addEventListener(TriggerEvent.TRIGGER, onCancelClicked);
        buttonGroup.addChild(_cancelButton);
        
        _content.addChild(buttonGroup);
        
        // Create secrets button row if we have no tokens
        var needsSecretsButton = (_hclTokens.length == 0 && _customResources.length == 0);
        if (needsSecretsButton || _hclTokens.length == 0) {
            var secretsButtonGroup = new LayoutGroup();
            secretsButtonGroup.layoutData = new VerticalLayoutData(100);
            
            var secretsLayout = new HorizontalLayout();
            secretsLayout.horizontalAlign = HorizontalAlign.CENTER;
            secretsButtonGroup.layout = secretsLayout;
            
            _secretsButton = new GenesisFormButton("Go to Secrets Page");
            _secretsButton.width = GenesisApplicationTheme.GRID * 25;
            _secretsButton.addEventListener(TriggerEvent.TRIGGER, onSecretsClicked);
            secretsButtonGroup.addChild(_secretsButton);
            
            _content.addChild(secretsButtonGroup);
        }
        
        // Add custom content to the alert
        alert.addChild(_content);
        
        // Update download button state
        updateDownloadButtonState();
        
        return alert;
    }
    
    /**
     * Update token dropdown based on selected source
     */
    private function updateTokenDropdown():Void {
        // Check if UI elements exist before using them
        if (_hclSourceCheck == null || _tokenDropdown == null) {
            Logger.error('Cannot update token dropdown: UI elements not initialized');
            return;
        }
        
        // Clear existing items
        var items = new ArrayCollection<String>();
        
        // IMPORTANT: Toggle behavior is:
        // - Unchecked/false = HCL Download Portal
        // - Checked/true = Custom Resource URL
        
        if (!_hclSourceCheck.selected) {
            // Use HCL tokens when checkbox is UNCHECKED
            if (_hclTokens != null) {
                for (token in _hclTokens) {
                    if (token != null && token.name != null) {
                        items.add(token.name);
                    }
                }
            }
        } else {
            // Use custom resources when checkbox is CHECKED
            if (_customResources != null) {
                for (resource in _customResources) {
                    if (resource != null && resource.name != null) {
                        items.add(resource.name);
                    }
                }
            }
        }
        
        Logger.error('Updating token dropdown with ${items.length} items');
        _tokenDropdown.dataProvider = items;
        
        // Select first item if available
        if (items.length > 0) {
            _tokenDropdown.selectedIndex = 0;
        }
        
        // Update download button state
        updateDownloadButtonState();
    }
    
    /**
     * Update download button enabled state based on token selection
     */
    private function updateDownloadButtonState():Void {
        var hasTokens = false;
        
        // Check if UI elements exist before using them
        if (_hclSourceCheck == null || _tokenDropdown == null || _downloadButton == null) {
            Logger.error('Cannot update download button state: UI elements not initialized');
            return;
        }
        
        // IMPORTANT: Toggle behavior is:
        // - Unchecked/false = HCL Download Portal
        // - Checked/true = Custom Resource URL
        
        if (!_hclSourceCheck.selected) {
            // HCL tokens (when checkbox is UNCHECKED)
            hasTokens = _hclTokens != null && _hclTokens.length > 0;
        } else {
            // Custom resources (when checkbox is CHECKED)
            hasTokens = _customResources != null && _customResources.length > 0;
        }
        
        _downloadButton.enabled = hasTokens && _tokenDropdown.selectedIndex >= 0;
    }
    
    /**
     * Handle source radio button changes
     */
    private function onSourceChanged(e:TriggerEvent):Void {
        // Ensure radio button behavior (only one selected)
        if (e.target == _hclSourceCheck && _hclSourceCheck.selected) {
            _customSourceCheck.selected = false;
        } else if (e.target == _customSourceCheck && _customSourceCheck.selected) {
            _hclSourceCheck.selected = false;
        } else {
            // Ensure at least one is selected
            if (!_hclSourceCheck.selected && !_customSourceCheck.selected) {
                _hclSourceCheck.selected = true;
            }
        }
        
        // Update token dropdown
        updateTokenDropdown();
    }
    
    /**
     * Handle download button click
     */
    private function onDownloadClicked(e:TriggerEvent):Void {
        // Prevent multiple downloads
        if (_downloadInProgress) {
            Logger.warning("Download already in progress");
            return;
        }
        
        // Get the selected token name and source type
        var tokenName = getSelectedTokenName();
        var isHCLSource = isHCLSourceSelected();
        
        if (tokenName == null || tokenName.length == 0) {
            Logger.error("No token selected for download");
            return;
        }
        
        // Set download in progress flag FIRST to prevent race conditions
        _downloadInProgress = true;
        
        // Show progress UI and hide selection controls
        showProgressUI();
        
        // Clean up any existing listeners first to ensure we don't have duplicates
        cleanupDownloadListeners();
        
        // Set up event listeners for download progress
        _downloader.onDownloadStart.add(onDownloadStart);
        _downloader.onDownloadProgress.add(onDownloadProgress);
        _downloader.onDownloadComplete.add(onDownloadComplete);
        _downloader.onDownloadError.add(onDownloadError);
        
        // Start the download with appropriate method
        if (isHCLSource) {
            _statusLabel.text = "Getting access token from HCL Portal...";
            _downloader.downloadFileWithHCLToken(_file, tokenName);
        } else {
            _statusLabel.text = "Downloading from custom resource...";
            _downloader.downloadFileWithCustomResource(_file, tokenName);
        }
    }
    
    /**
     * Show progress UI, hide other controls
     */
    private function showProgressUI():Void {
        // Hide source selection and token controls
        if (_sourceGroup != null) {
            _sourceGroup.visible = _sourceGroup.includeInLayout = false;
        }
        
        // Hide token dropdown row if present
        for (i in 0..._content.numChildren) {
            var child = _content.getChildAt(i);
            if (Std.is(child, GenesisFormRow)) {
                child.visible = false;
                // Cast to GenesisFormRow to access includeInLayout
                var formRow:GenesisFormRow = cast(child, GenesisFormRow);
                formRow.includeInLayout = false;
            }
        }
        
        // Show progress UI
        _progressGroup.visible = _progressGroup.includeInLayout = true;
        
        // Ensure progress bar takes full available width
        if (_progressBar != null) {
            // Get the width from the dialog/content
            var dialogWidth:Float = (_content != null) ? _content.width : 500;
            
            // Set the progress bar width to a percentage of the dialog width
            _progressBar.width = dialogWidth * 0.85;
            
            // Ensure it has horizontal layout data for proper sizing
            _progressBar.layoutData = new VerticalLayoutData(100);
            
            // Reset to zero
            _progressBar.percentage = 0;
            
            // Force immediate layout update
            _progressBar.validateNow();
        }
        
        // Reset the progress label
        if (_progressLabel != null) {
            _progressLabel.text = "0%";
        }
        
        // Disable buttons during download
        _downloadButton.enabled = false;
        _cancelButton.enabled = true;
        
        if (_secretsButton != null) {
            _secretsButton.visible = _secretsButton.includeInLayout = false;
        }
        
        // Force validation of the entire layout to ensure proper sizing
        if (_progressGroup != null) {
            _progressGroup.validateNow();
        }
        if (_content != null) {
            _content.validateNow();
        }
    }
    
    /**
     * Handle download start event
     */
    private function onDownloadStart(downloader:HCLDownloader, file:SuperHumanCachedFile):Void {
        _statusLabel.text = "Starting download: " + file.originalFilename;
        _progressBar.percentage = 0;
        _progressLabel.text = "0%";
    }
    
    /**
     * Handle download progress event
     */
    private function onDownloadProgress(downloader:HCLDownloader, file:SuperHumanCachedFile, progress:Float):Void {
        // Update progress bar and label
        // Ensure percentage is properly set (0-1 range)
        _progressBar.percentage = Math.min(1.0, Math.max(0.0, progress));
        
        // Update progress text
        var progressPercent = Math.round(progress * 100);
        _progressLabel.text = progressPercent + "%";
        
        // Update status text based on current step
        var currentStep = downloader.currentStep;
        
        if (currentStep == HCLDownloadStep.Downloading) {
            // Only show percentage during actual download
            _statusLabel.text = "Downloading " + file.originalFilename + "... " + progressPercent + "%";
        } else if (currentStep == HCLDownloadStep.WritingFile) {
            _statusLabel.text = "Writing file to disk... " + progressPercent + "%";
        } else if (currentStep == HCLDownloadStep.VerifyingHash) {
            _statusLabel.text = "Validating checksum... " + progressPercent + "%";
        } else if (currentStep == HCLDownloadStep.MovingFile) {
            _statusLabel.text = "Finalizing download... " + progressPercent + "%";
        } else if (currentStep == HCLDownloadStep.Complete) {
            _statusLabel.text = "Download complete!";
        } else {
            // For other steps, show the step name with percentage
            _statusLabel.text = currentStep + "... " + progressPercent + "%";
        }
    }
    
    /**
     * Handle download complete event
     */
    private function onDownloadComplete(downloader:HCLDownloader, file:SuperHumanCachedFile, success:Bool):Void {
        // Set download in progress to false FIRST to prevent race conditions
        _downloadInProgress = false;
        
        // Remove event listeners
        cleanupDownloadListeners();
        
        if (success) {
            _statusLabel.text = "Download completed successfully!";
            _progressBar.percentage = 1.0;
            _progressLabel.text = "100%";
            
            // Disable download button completely to prevent re-clicking
            _downloadButton.enabled = false;
            
            // Create a local variable to track if we've already closed
            var dialogClosed = false;
            
            // Close dialog after a short delay
            haxe.Timer.delay(function() {
                // Only close if not already closed
                if (!dialogClosed) {
                    dialogClosed = true;
                    closeDialog(RESULT_DOWNLOAD);
                }
            }, 1000);
        } else {
            _statusLabel.text = "Download failed.";
            
            // Re-enable download button for retry
            _downloadButton.enabled = true;
        }
    }
    
    /**
     * Handle download error event
     */
    private function onDownloadError(downloader:HCLDownloader, file:SuperHumanCachedFile, error:String):Void {
        // Remove event listeners
        cleanupDownloadListeners();
        
        // Show error message
        _statusLabel.text = "Error: " + error;
        _progressBar.percentage = 0;
        
        // Re-enable download button but keep progress UI visible
        _downloadButton.enabled = true;
        _downloadInProgress = false;
    }
    
    /**
     * Clean up download event listeners
     */
    private function cleanupDownloadListeners():Void {
        _downloader.onDownloadStart.remove(onDownloadStart);
        _downloader.onDownloadProgress.remove(onDownloadProgress);
        _downloader.onDownloadComplete.remove(onDownloadComplete);
        _downloader.onDownloadError.remove(onDownloadError);
    }
    
    /**
     * Handle cancel button click
     */
    private function onCancelClicked(e:TriggerEvent):Void {
        // If download is in progress, confirm before canceling
        if (_downloadInProgress) {
            // Just close for now - we don't have a way to cancel downloads in progress yet
            cleanupDownloadListeners();
        }
        
        closeDialog(RESULT_CANCEL);
    }
    
    /**
     * Handle secrets button click
     */
    private function onSecretsClicked(e:TriggerEvent):Void {
        closeDialog(RESULT_SECRETS);
    }
    
    /**
     * Close the dialog with a result
     */
    private function closeDialog(result:Int):Void {
        // Set download in progress to false first to prevent race conditions
        _downloadInProgress = false;
        
        // Clean up any event listeners
        cleanupDownloadListeners();
        
        // Remove button event listeners to prevent accidental triggering
        if (_downloadButton != null) {
            _downloadButton.removeEventListener(TriggerEvent.TRIGGER, onDownloadClicked);
            _downloadButton = null;
        }
        
        if (_cancelButton != null) {
            _cancelButton.removeEventListener(TriggerEvent.TRIGGER, onCancelClicked);
            _cancelButton = null;
        }
        
        if (_secretsButton != null) {
            _secretsButton.removeEventListener(TriggerEvent.TRIGGER, onSecretsClicked);
            _secretsButton = null;
        }
        
        if (_hclSourceCheck != null) {
            _hclSourceCheck.removeEventListener(TriggerEvent.TRIGGER, onSourceChanged);
            _hclSourceCheck = null;
        }
        
        // Store local reference to callback before nulling instance variable
        var callback = _callback;
        
        // Clear all references for garbage collection
        _callback = null;
        _file = null;
        _alert = null;
        _content = null;
        _sourceGroup = null;
        _tokenDropdown = null;
        _customSourceCheck = null;
        _progressGroup = null;
        _progressBar = null;
        _progressLabel = null;
        _statusLabel = null;
        
        // Close the alert using PopUpManager
        try {
            if (_alert != null) {
                PopUpManager.removePopUp(_alert);
            }
        } catch (e:Dynamic) {
            Logger.error('DownloadDialog: Error closing dialog: ${e}');
        }
        
        // Add token information to callback when download is selected
        if (callback != null) {
            if (result == RESULT_DOWNLOAD) {
                // Include token name and source type in userData
                var tokenName = getSelectedTokenName();
                var isHCLSource = isHCLSourceSelected();
                
                // Create userData object with token info
                callback({
                    index: result,
                    userData: {
                        tokenName: tokenName,
                        isHCLSource: isHCLSource
                    }
                });
            } else {
                // For other results just pass the index
                callback({index: result});
            }
        }
    }
    
    /**
     * Get the selected token name
     */
    public function getSelectedTokenName():String {
        if (_tokenDropdown == null || _tokenDropdown.selectedIndex < 0) return null;
        return _tokenDropdown.selectedItem;
    }
    
    /**
     * Check if HCL source is selected
     */
    public function isHCLSourceSelected():Bool {
        // Default to true if UI isn't initialized yet (prefer HCL download)
        if (_hclSourceCheck == null) return true;
        
        // IMPORTANT: Toggle behavior is:
        // - Unchecked/false = HCL Download Portal
        // - Checked/true = Custom Resource URL
        // So we return the OPPOSITE of the checkbox state
        return !_hclSourceCheck.selected;
    }
}
