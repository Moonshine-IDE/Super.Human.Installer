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
import feathers.controls.Button;
import feathers.controls.Label;
import feathers.controls.LayoutGroup;
import feathers.controls.ScrollContainer;
import feathers.events.TriggerEvent;
import feathers.layout.HorizontalAlign;
import feathers.layout.HorizontalLayout;
import feathers.layout.HorizontalLayoutData;
import feathers.layout.VerticalAlign;
import feathers.layout.VerticalLayout;
import feathers.layout.VerticalLayoutData;
import genesis.application.components.GenesisFormButton;
import genesis.application.components.HLine;
import genesis.application.components.Page;
import genesis.application.managers.LanguageManager;
import genesis.application.theme.GenesisApplicationTheme;
import openfl.events.MouseEvent;
import prominic.sys.applications.bin.Shell;
import prominic.sys.applications.oracle.VirtualBox;
import prominic.sys.applications.oracle.VirtualBoxMachine;
import superhuman.events.SuperHumanApplicationEvent;
import superhuman.server.Server;
import superhuman.theme.SuperHumanInstallerTheme;

/**
 * Page for displaying detailed VirtualBox VM information
 */
class VMDetailsPage extends Page {

    final _width:Float = GenesisApplicationTheme.GRID * 120;

    // UI Components
    private var _titleGroup:LayoutGroup;
    private var _titleLabel:Label;
    private var _serverLabel:Label;
    private var _scrollContainer:ScrollContainer;
    private var _detailsContainer:LayoutGroup;
    private var _buttonGroup:LayoutGroup;
    private var _buttonRefresh:GenesisFormButton;
    private var _buttonOpenVirtualBox:GenesisFormButton;
    private var _buttonClose:GenesisFormButton;
    
    // Data
    private var _server:Server;
    private var _vmMachine:VirtualBoxMachine;
    
    public function new() {
        super();
    }

    override function initialize() {
        super.initialize();

        _content.width = _width;
        _content.maxWidth = GenesisApplicationTheme.GRID * 130;

        // Create title group
        _titleGroup = new LayoutGroup();
        var titleLayout = new HorizontalLayout();
        titleLayout.horizontalAlign = HorizontalAlign.LEFT;
        titleLayout.verticalAlign = VerticalAlign.MIDDLE;
        titleLayout.gap = GenesisApplicationTheme.GRID * 2;
        _titleGroup.layout = titleLayout;
        _titleGroup.width = _width;
        this.addChild(_titleGroup);

        _titleLabel = new Label();
        _titleLabel.text = "Virtual Machine Details";
        _titleLabel.variant = GenesisApplicationTheme.LABEL_LARGE;
        _titleLabel.layoutData = new HorizontalLayoutData(100);
        _titleGroup.addChild(_titleLabel);

        _serverLabel = new Label();
        _serverLabel.variant = GenesisApplicationTheme.LABEL_COPYRIGHT;
        _titleGroup.addChild(_serverLabel);

        // Add separator line
        var titleLine = new HLine();
        titleLine.width = _width;
        this.addChild(titleLine);

        // Create scroll container for VM details
        _scrollContainer = new ScrollContainer();
        _scrollContainer.variant = SuperHumanInstallerTheme.SCROLL_CONTAINER_DARK;
        _scrollContainer.layoutData = new VerticalLayoutData(100, 100);
        _scrollContainer.autoHideScrollBars = false;
        _scrollContainer.fixedScrollBars = true;

        // Set up vertical layout for the scroll container
        var scrollLayout = new VerticalLayout();
        scrollLayout.horizontalAlign = HorizontalAlign.LEFT;
        scrollLayout.gap = GenesisApplicationTheme.GRID * 2;
        scrollLayout.paddingTop = GenesisApplicationTheme.GRID * 2;
        scrollLayout.paddingBottom = GenesisApplicationTheme.GRID * 2;
        scrollLayout.paddingLeft = GenesisApplicationTheme.GRID * 2;
        scrollLayout.paddingRight = GenesisApplicationTheme.GRID * 3; // Extra padding for scrollbar
        _scrollContainer.layout = scrollLayout;

        this.addChild(_scrollContainer);

        // Create details container
        _detailsContainer = new LayoutGroup();
        _detailsContainer.layoutData = new VerticalLayoutData(100);
        var detailsLayout = new VerticalLayout();
        detailsLayout.gap = GenesisApplicationTheme.GRID * 2;
        detailsLayout.horizontalAlign = HorizontalAlign.LEFT;
        _detailsContainer.layout = detailsLayout;
        _scrollContainer.addChild(_detailsContainer);

        // Add bottom separator and buttons
        var bottomLine = new HLine();
        bottomLine.width = _width;
        this.addChild(bottomLine);

        // Create button group
        _buttonGroup = new LayoutGroup();
        var buttonLayout = new HorizontalLayout();
        buttonLayout.gap = GenesisApplicationTheme.GRID * 2;
        buttonLayout.horizontalAlign = HorizontalAlign.CENTER;
        _buttonGroup.layout = buttonLayout;

        _buttonRefresh = new GenesisFormButton("Refresh");
        _buttonRefresh.addEventListener(TriggerEvent.TRIGGER, _refreshButtonTriggered);
        _buttonRefresh.width = GenesisApplicationTheme.GRID * 15;
        _buttonGroup.addChild(_buttonRefresh);

        _buttonOpenVirtualBox = new GenesisFormButton("VirtualBox");
        _buttonOpenVirtualBox.addEventListener(TriggerEvent.TRIGGER, _openVirtualBoxTriggered);
        _buttonOpenVirtualBox.width = GenesisApplicationTheme.GRID * 18;
        _buttonGroup.addChild(_buttonOpenVirtualBox);

        _buttonClose = new GenesisFormButton("Close");
        _buttonClose.addEventListener(TriggerEvent.TRIGGER, _closeButtonTriggered);
        _buttonClose.width = GenesisApplicationTheme.GRID * 15;
        _buttonGroup.addChild(_buttonClose);

        this.addChild(_buttonGroup);
        
        // If server was set before initialization, update the UI now
        if (_server != null) {
            // Update title to show server info
            _titleLabel.text = 'Virtual Machine Details - Server #${_server.id}';
            _serverLabel.text = '${_server.fqdn}';
            
            // Build the details display if we have VM data
            if (_vmMachine != null) {
                _updateVMDetails();
            }
        }
    }

    /**
     * Set the server to display VM details for
     * @param server The server containing the VM
     */
    public function setServer(server:Server):Void {
        _server = server;
        
        if (_server != null) {
            // Get VM machine data
            _vmMachine = _server.combinedVirtualMachine.value.virtualBoxMachine;
            
            // Only update UI if components are initialized
            if (_titleLabel != null && _serverLabel != null) {
                // Update title to show server info
                _titleLabel.text = 'Virtual Machine Details - Server #${_server.id}';
                _serverLabel.text = '${_server.fqdn}';
                
                // Build the details display
                _updateVMDetails();
            }
            // If UI isn't ready yet, the initialize() method will handle the update
        }
    }

    /**
     * Update the VM details display
     */
    private function _updateVMDetails():Void {
        // Don't update if UI components aren't initialized yet
        if (_detailsContainer == null) {
            return;
        }
        
        // Clear existing details
        _detailsContainer.removeChildren();

        if (_vmMachine == null) {
            var noVMLabel = new Label();
            noVMLabel.text = "No VirtualBox VM information available for this server.";
            noVMLabel.variant = GenesisApplicationTheme.LABEL_COPYRIGHT;
            _detailsContainer.addChild(noVMLabel);
            return;
        }

        // Create Hardware Information section
        _addSection("Hardware Information", [
            _createDetailRow("VM Name", _vmMachine.name),
            _createDetailRow("VM ID", _vmMachine.virtualBoxId),
            _createDetailRow("State", _vmMachine.virtualBoxState),
            _createDetailRow("CPUs", _vmMachine.cpus != null ? '${_vmMachine.cpus}' : "Not specified"),
            _createDetailRow("CPU Execution Cap", _vmMachine.cpuexecutioncap != null ? '${_vmMachine.cpuexecutioncap}%' : "Not specified"),
            _createDetailRow("Memory", _vmMachine.memory != null ? '${_vmMachine.memory} MB' : "Not specified"),
            _createDetailRow("Video Memory", _vmMachine.vram != null ? '${_vmMachine.vram} MB' : "Not specified")
        ]);

        // Create System Information section
        _addSection("System Information", [
            _createDetailRow("Hardware UUID", _vmMachine.hardwareuuid),
            _createDetailRow("Operating System", _vmMachine.ostype),
            _createDetailRow("Description", _vmMachine.description),
            _createDetailRow("Chipset", _vmMachine.chipset),
            _createDetailRow("Firmware", _vmMachine.firmware),
            _createDetailRow("CPU Profile", _vmMachine.cpuprofile),
            _createDetailRow("Encryption", _vmMachine.encryption != null ? (_vmMachine.encryption ? "Enabled" : "Disabled") : "Not specified")
        ]);

        // Create Virtualization Features section
        _addSection("Virtualization Features", [
            _createDetailRow("Physical Address Extension (PAE)", _vmMachine.pae),
            _createDetailRow("Long Mode Support", _vmMachine.longmode),
            _createDetailRow("APIC", _vmMachine.apic),
            _createDetailRow("X2APIC", _vmMachine.x2apic),
            _createDetailRow("Nested VT-x/AMD-V", _vmMachine.nestedhwvirt),
            _createDetailRow("HPET", _vmMachine.hpet),
            _createDetailRow("Page Fusion", _vmMachine.pagefusion),
            _createDetailRow("Triple Fault Reset", _vmMachine.triplefaultreset)
        ]);

        // Create File Locations section
        var fileLocationRows = [];
        
        if (_vmMachine.CfgFile != null) {
            fileLocationRows.push(_createFilePathRow("Configuration File", _vmMachine.CfgFile));
        }
        if (_vmMachine.LogFldr != null) {
            fileLocationRows.push(_createFilePathRow("Log Folder", _vmMachine.LogFldr));
        }
        if (_vmMachine.SnapFldr != null) {
            fileLocationRows.push(_createFilePathRow("Snapshot Folder", _vmMachine.SnapFldr));
        }
        if (_vmMachine.root != null) {
            fileLocationRows.push(_createFilePathRow("VM Root Directory", _vmMachine.root));
        }

        if (fileLocationRows.length > 0) {
            _addSection("File Locations", fileLocationRows);
        }
    }

    /**
     * Add a section with title and rows
     * @param title Section title
     * @param rows Array of row components
     */
    private function _addSection(title:String, rows:Array<LayoutGroup>):Void {
        // Add section title
        var sectionTitle = new Label();
        sectionTitle.text = title;
        sectionTitle.variant = GenesisApplicationTheme.LABEL_LARGE;
        sectionTitle.layoutData = new VerticalLayoutData(100);
        _detailsContainer.addChild(sectionTitle);

        // Add section content container
        var sectionContainer = new LayoutGroup();
        var sectionLayout = new VerticalLayout();
        sectionLayout.gap = GenesisApplicationTheme.GRID;
        sectionLayout.paddingLeft = GenesisApplicationTheme.GRID * 2;
        sectionContainer.layout = sectionLayout;
        sectionContainer.layoutData = new VerticalLayoutData(100);
        _detailsContainer.addChild(sectionContainer);

        // Add all rows to section
        for (row in rows) {
            if (row != null) {
                sectionContainer.addChild(row);
            }
        }

        // Add separator after section
        var separator = new HLine();
        separator.alpha = 0.3;
        separator.width = _width * 0.9;
        separator.layoutData = new VerticalLayoutData(90);
        _detailsContainer.addChild(separator);
    }

    /**
     * Create a detail row with label and value
     * @param label The field label
     * @param value The field value
     * @return LayoutGroup containing the row
     */
    private function _createDetailRow(label:String, value:Dynamic):LayoutGroup {
        // Skip rows with null/empty values
        if (value == null || value == "") {
            return null;
        }

        var row = new LayoutGroup();
        var rowLayout = new HorizontalLayout();
        rowLayout.verticalAlign = VerticalAlign.TOP;
        rowLayout.gap = GenesisApplicationTheme.GRID * 2;
        row.layout = rowLayout;
        row.layoutData = new VerticalLayoutData(100);

        // Create label
        var labelComponent = new Label();
        labelComponent.text = label + ":";
        labelComponent.variant = GenesisApplicationTheme.LABEL_DEFAULT;
        labelComponent.width = GenesisApplicationTheme.GRID * 30; // Fixed width for alignment
        row.addChild(labelComponent);

        // Create value label
        var valueComponent = new Label();
        valueComponent.text = Std.string(value);
        valueComponent.variant = GenesisApplicationTheme.LABEL_COPYRIGHT;
        valueComponent.wordWrap = true;
        valueComponent.layoutData = new HorizontalLayoutData(100);
        row.addChild(valueComponent);

        return row;
    }

    /**
     * Create a file path row with an "Open" button
     * @param label The field label
     * @param filePath The file path
     * @return LayoutGroup containing the row
     */
    private function _createFilePathRow(label:String, filePath:String):LayoutGroup {
        if (filePath == null || filePath == "") {
            return null;
        }

        var row = new LayoutGroup();
        var rowLayout = new HorizontalLayout();
        rowLayout.verticalAlign = VerticalAlign.MIDDLE;
        rowLayout.gap = GenesisApplicationTheme.GRID;
        row.layout = rowLayout;
        row.layoutData = new VerticalLayoutData(100);

        // Create label
        var labelComponent = new Label();
        labelComponent.text = label + ":";
        labelComponent.variant = GenesisApplicationTheme.LABEL_DEFAULT;
        labelComponent.width = GenesisApplicationTheme.GRID * 30; // Fixed width for alignment
        row.addChild(labelComponent);

        // Create value label (clickable)
        var valueComponent = new Label();
        valueComponent.text = filePath;
        valueComponent.variant = GenesisApplicationTheme.LABEL_LINK;
        valueComponent.wordWrap = true;
        valueComponent.buttonMode = valueComponent.useHandCursor = true;
        valueComponent.layoutData = new HorizontalLayoutData(100);
        valueComponent.addEventListener(MouseEvent.CLICK, function(_) {
            _openFileLocation(filePath);
        });
        valueComponent.toolTip = "Click to open location";
        row.addChild(valueComponent);

        // Create open button
        var openButton = new Button();
        openButton.text = "Open";
        openButton.icon = GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_FOLDER);
        openButton.variant = GenesisApplicationTheme.BUTTON_SELECT_FILE;
        openButton.width = GenesisApplicationTheme.GRID * 12;
        openButton.addEventListener(TriggerEvent.TRIGGER, function(_) {
            _openFileLocation(filePath);
        });
        row.addChild(openButton);

        // Create copy button for the path
        var copyButton = new Button();
        copyButton.text = "Copy";
        copyButton.icon = GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_COPY);
        copyButton.variant = GenesisApplicationTheme.BUTTON_SELECT_FILE;
        copyButton.width = GenesisApplicationTheme.GRID * 12;
        copyButton.toolTip = "Copy path to clipboard";
        copyButton.addEventListener(TriggerEvent.TRIGGER, function(_) {
            _copyToClipboard(filePath);
        });
        row.addChild(copyButton);

        return row;
    }

    /**
     * Open a file or folder location in the system file manager
     * @param path The file or folder path to open
     */
    private function _openFileLocation(path:String):Void {
        if (path == null || path == "") {
            return;
        }

        try {
            // Check if it's a file or directory
            if (sys.FileSystem.exists(path)) {
                if (sys.FileSystem.isDirectory(path)) {
                    // Open directory directly
                    Shell.getInstance().open([path]);
                } else {
                    // Open parent directory and select file
                    var parentDir = haxe.io.Path.directory(path);
                    Shell.getInstance().open([parentDir]);
                }
                Logger.info('${this}: Opened file location: ${path}');
            } else {
                Logger.warning('${this}: File or directory does not exist: ${path}');
                // Try opening parent directory as fallback
                var parentDir = haxe.io.Path.directory(path);
                if (sys.FileSystem.exists(parentDir)) {
                    Shell.getInstance().open([parentDir]);
                }
            }
        } catch (e:Dynamic) {
            Logger.error('${this}: Error opening file location: ${e}');
        }
    }

    /**
     * Copy text to clipboard
     * @param text The text to copy
     */
    private function _copyToClipboard(text:String):Void {
        var event = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.COPY_TO_CLIPBOARD);
        event.data = text;
        this.dispatchEvent(event);
    }

    /**
     * Refresh VM information by getting latest data from VirtualBox
     */
    private function _refreshVMInfo():Void {
        if (_server == null || !_server.vmExistsInVirtualBox()) {
            Logger.warning('${this}: Cannot refresh VM info - no VM exists for this server');
            return;
        }

        Logger.info('${this}: Refreshing VM information for server ${_server.id}');

        // Disable refresh button during update
        _buttonRefresh.enabled = false;
        _buttonRefresh.text = "Refreshing...";

        // Add listener for when VM info is refreshed
        VirtualBox.getInstance().onShowVMInfo.add(_onVMInfoRefreshed);

        // Request fresh VM info from VirtualBox
        var executor = VirtualBox.getInstance().getShowVMInfo(_server.combinedVirtualMachine.value.virtualBoxMachine, true);
        if (executor != null) {
            executor.execute();
        } else {
            // Re-enable button if executor couldn't be created
            _buttonRefresh.enabled = true;
            _buttonRefresh.text = "Refresh";
            Logger.error('${this}: Could not create VM info executor');
        }
    }

    /**
     * Handle VM info refresh completion
     */
    private function _onVMInfoRefreshed(machine:VirtualBoxMachine):Void {
        // Check if this is for our VM
        if (machine.virtualBoxId != _server.combinedVirtualMachine.value.virtualBoxMachine.virtualBoxId) {
            return;
        }

        // Remove the listener
        VirtualBox.getInstance().onShowVMInfo.remove(_onVMInfoRefreshed);

        // Update the server's VM data
        _server.setVirtualBoxMachine(machine);
        
        // Get the updated VM machine data
        _vmMachine = _server.combinedVirtualMachine.value.virtualBoxMachine;

        // Update the display
        _updateVMDetails();

        // Re-enable refresh button
        _buttonRefresh.enabled = true;
        _buttonRefresh.text = "Refresh";

        Logger.info('${this}: VM information refreshed successfully');
    }

    /**
     * Handle refresh button click
     */
    private function _refreshButtonTriggered(e:TriggerEvent):Void {
        _refreshVMInfo();
    }

    /**
     * Handle open VirtualBox GUI button click
     */
    private function _openVirtualBoxTriggered(e:TriggerEvent):Void {
        var event = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.OPEN_VIRTUALBOX_GUI);
        this.dispatchEvent(event);
    }

    /**
     * Handle close button click
     */
    private function _closeButtonTriggered(e:TriggerEvent):Void {
        var event = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.CANCEL_PAGE);
        this.dispatchEvent(event);
    }

    /**
     * Update the content when server data changes
     */
    override function updateContent(forced:Bool = false):Void {
        super.updateContent(forced);
        
        if (forced && _server != null) {
            // Refresh VM machine data
            _vmMachine = _server.combinedVirtualMachine.value.virtualBoxMachine;
            _updateVMDetails();
        }
    }
}
