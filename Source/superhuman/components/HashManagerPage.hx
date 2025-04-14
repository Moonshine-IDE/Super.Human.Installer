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
import feathers.controls.Label;
import feathers.controls.LayoutGroup;
import feathers.controls.PopUpListView;
import feathers.controls.ScrollContainer;
import feathers.controls.TextInput;
import genesis.application.components.ProgressBar;
import feathers.data.ArrayCollection;
import feathers.events.TriggerEvent;
import feathers.layout.HorizontalAlign;
import feathers.layout.HorizontalLayout;
import feathers.layout.HorizontalLayoutData;
import feathers.layout.VerticalAlign;
import feathers.layout.VerticalLayout;
import feathers.layout.VerticalLayoutData;
import feathers.skins.RectangleSkin;
import feathers.graphics.FillStyle;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.MouseEvent;
import genesis.application.components.GenesisForm;
import genesis.application.components.GenesisFormButton;
import genesis.application.components.GenesisFormRow;
import genesis.application.components.HLine;
import genesis.application.components.Page;
import genesis.application.managers.LanguageManager;
import genesis.application.managers.ToastManager;
import genesis.application.theme.GenesisApplicationTheme;
import haxe.io.Path;
import lime.ui.FileDialog;
import lime.ui.FileDialogType;
import prominic.sys.io.FileTools;
import superhuman.components.DownloadDialog;
import superhuman.downloaders.HCLDownloader;
import superhuman.events.SuperHumanApplicationEvent;
import superhuman.server.cache.SuperHumanCachedFile;
import superhuman.server.cache.SuperHumanFileCache;
import superhuman.theme.SuperHumanInstallerTheme;
import sys.FileSystem;
import openfl.Lib;

/**
 * Page for managing the file hash cache
 */
class HashManagerPage extends Page {
    // Constants
    final _width:Float = GenesisApplicationTheme.GRID * 154; // Increased width by 10%
    
    // Form elements
    private var _buttonCancel:GenesisFormButton;
    private var _buttonGroup:LayoutGroup;
    private var _buttonGroupLayout:HorizontalLayout;
    private var _buttonSave:GenesisFormButton;
    private var _label:Label;
    private var _titleGroup:LayoutGroup;
    
    // File list elements
    private var _listGroup:LayoutGroup;
    private var _listGroupLayout:VerticalLayout;
    private var _fileCollection:Array<SuperHumanCachedFile>;
    private var _buttonAddFile:Button;
    private var _buttonEditFile:Button;
    private var _buttonDeleteFile:Button;
    private var _buttonOpenCacheDir:Button;
    private var _scrollContainer:ScrollContainer;
    
    // Sorting properties
    private var _currentSortColumn:String = "role"; // Default sort column (changed from filename)
    private var _currentSortAscending:Bool = true; // Default sort direction
    
    // Selected file item
    private var _selectedFileItem:FileEntryItem = null;
    
    // File dialog for adding files
    private var _fileDialog:FileDialog;
    
    // Add/Edit file form elements
    private var _addEditForm:GenesisForm;
    private var _rowRole:GenesisFormRow;
    private var _dropdownRole:PopUpListView;
    private var _rowType:GenesisFormRow;
    private var _dropdownType:PopUpListView;
    private var _rowVersion:GenesisFormRow;
    private var _inputMajorVersion:TextInput;
    private var _inputMinorVersion:TextInput;
    private var _inputPatchVersion:TextInput;
    private var _inputFullVersion:TextInput;
    private var _buttonAddEditCancel:GenesisFormButton;
    private var _buttonAddEditSave:GenesisFormButton;
    
    // File being edited
    private var _editingFile:SuperHumanCachedFile;
    private var _tempSourceFilePath:String;
    
    // File path display components
    private var _filePathRow:GenesisFormRow;
    private var _filePathLabel:Label;
    private var _filePathContainer:LayoutGroup;
    
    // Progress components
    private var _progressOverlay:LayoutGroup;
    private var _progressBar:ProgressBar;
    private var _progressLabel:Label;
    
    // Hash display components
    private var _hashRow:GenesisFormRow;
    private var _hashLabel:Label;
    
    public function new() {
        super();
    }
    
    override function initialize() {
        super.initialize();
        
        // Add event listener for REFRESH_HASH_MANAGER event
        if (Lib.current != null) {
            Lib.current.stage.addEventListener(SuperHumanApplicationEvent.REFRESH_HASH_MANAGER, onRefreshHashManager);
            Logger.info('HashManagerPage: Added listener for REFRESH_HASH_MANAGER event');
        }
        
        _content.width = _width;
        _content.maxWidth = GenesisApplicationTheme.GRID * 165; // Increased to match new page width
        
        // Create title group
        _titleGroup = new LayoutGroup();
        var _titleGroupLayout = new HorizontalLayout();
        _titleGroupLayout.horizontalAlign = HorizontalAlign.LEFT;
        _titleGroupLayout.verticalAlign = VerticalAlign.MIDDLE;
        _titleGroup.layout = _titleGroupLayout;
        _titleGroup.width = _width;
        this.addChild(_titleGroup);
        
        _label = new Label();
        _label.text = "Installer Files & Hashes";
        _label.variant = GenesisApplicationTheme.LABEL_LARGE;
        _label.layoutData = new HorizontalLayoutData(100);
        _label.wordWrap = false; // Prevent wrapping to ensure it stays on one line
        _titleGroup.addChild(_label);
        
        var line = new HLine();
        line.width = _width;
        this.addChild(line);
        
        // Create a fixed action button bar that won't scroll
        var actionGroup = new LayoutGroup();
        actionGroup.layoutData = new VerticalLayoutData(100);
        var actionLayout = new HorizontalLayout();
        actionLayout.gap = GenesisApplicationTheme.GRID;
        actionLayout.verticalAlign = VerticalAlign.MIDDLE;
        actionLayout.paddingTop = GenesisApplicationTheme.GRID;
        actionLayout.paddingBottom = GenesisApplicationTheme.GRID;
        actionLayout.paddingLeft = GenesisApplicationTheme.GRID * 2;
        actionLayout.paddingRight = GenesisApplicationTheme.GRID * 2;
        actionGroup.layout = actionLayout;
        this.addChild(actionGroup);
        
        // Create header label for the fixed section
        var fixedHeaderLabel = new Label();
        fixedHeaderLabel.text = "Cached Files";
        fixedHeaderLabel.variant = GenesisApplicationTheme.LABEL_LARGE;
        fixedHeaderLabel.layoutData = new HorizontalLayoutData(100);
        actionGroup.addChild(fixedHeaderLabel);
        
        // Create button group that stays fixed
        var fixedButtonGroup = new LayoutGroup();
        var fixedButtonLayout = new HorizontalLayout();
        fixedButtonLayout.gap = GenesisApplicationTheme.GRID * 2;
        fixedButtonGroup.layout = fixedButtonLayout;
        actionGroup.addChild(fixedButtonGroup);
        
        // Create add button
        _buttonAddFile = new Button("Add File");
        _buttonAddFile.icon = GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_UPLOAD);
        _buttonAddFile.addEventListener(TriggerEvent.TRIGGER, _addFileButtonTriggered);
        fixedButtonGroup.addChild(_buttonAddFile);
        
        // Create edit button
        _buttonEditFile = new Button("Edit");
        _buttonEditFile.icon = GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_SETTINGS);
        _buttonEditFile.addEventListener(TriggerEvent.TRIGGER, _editFileButtonTriggered);
        _buttonEditFile.enabled = false; // Disabled until selection
        fixedButtonGroup.addChild(_buttonEditFile);
        
        // Create delete button
        _buttonDeleteFile = new Button("Delete");
        _buttonDeleteFile.icon = GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_DELETE);
        _buttonDeleteFile.addEventListener(TriggerEvent.TRIGGER, _deleteFileButtonTriggered);
        _buttonDeleteFile.enabled = false; // Disabled until selection
        fixedButtonGroup.addChild(_buttonDeleteFile);

        // Create open cache directory button
        _buttonOpenCacheDir = new Button("Show Cache");
        _buttonOpenCacheDir.icon = GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_FOLDER);
        _buttonOpenCacheDir.addEventListener(TriggerEvent.TRIGGER, _openCacheDirButtonTriggered);
        fixedButtonGroup.addChild(_buttonOpenCacheDir);
        
        // Add a separator line after the fixed buttons
        var actionLine = new HLine();
        actionLine.width = _width;
        this.addChild(actionLine);
        
        // Create main scroll container
        _scrollContainer = new ScrollContainer();
        _scrollContainer.variant = SuperHumanInstallerTheme.SCROLL_CONTAINER_DARK;
        _scrollContainer.layoutData = new VerticalLayoutData(100, 100);
        _scrollContainer.autoHideScrollBars = false;
        _scrollContainer.fixedScrollBars = true;
        
        // Set up vertical layout for the scroll container
        var scrollLayout = new VerticalLayout();
        scrollLayout.horizontalAlign = HorizontalAlign.CENTER;
        scrollLayout.gap = GenesisApplicationTheme.GRID;
        scrollLayout.paddingTop = GenesisApplicationTheme.GRID * 2;
        scrollLayout.paddingBottom = GenesisApplicationTheme.GRID * 2;
        scrollLayout.paddingLeft = GenesisApplicationTheme.GRID * 2;
        scrollLayout.paddingRight = GenesisApplicationTheme.GRID * 3; // Extra padding for scrollbar
        _scrollContainer.layout = scrollLayout;
        
        // Add the scroll container to the page
        this.addChild(_scrollContainer);
        
        // Create file list group
        _listGroup = new LayoutGroup();
        _listGroup.layoutData = new VerticalLayoutData(100);
        _listGroupLayout = new VerticalLayout();
        _listGroupLayout.gap = GenesisApplicationTheme.GRID;
        _listGroup.layout = _listGroupLayout;
        _scrollContainer.addChild(_listGroup);
        
        // Create sortable headers
        _listGroup.addChild(createSortableHeaders());
        
        // Initialize file collection
        _fileCollection = [];
        
        // Create add/edit form (initially hidden)
        _addEditForm = new GenesisForm();
        _addEditForm.visible = _addEditForm.includeInLayout = false;
        _scrollContainer.addChild(_addEditForm);
        
        // Create role row
        _rowRole = new GenesisFormRow();
        _rowRole.text = "Role";
        _addEditForm.addChild(_rowRole);
        
        // Create role dropdown
        _dropdownRole = new PopUpListView();
        _dropdownRole.dataProvider = new ArrayCollection<String>([
            "domino", "leap", "nomadweb", "traveler", "verse", "domino-rest-api"
        ]);
        _rowRole.content.addChild(_dropdownRole);
        
        // Create type row
        _rowType = new GenesisFormRow();
        _rowType.text = "Type";
        _addEditForm.addChild(_rowType);
        
        // Create type dropdown
        _dropdownType = new PopUpListView();
        _dropdownType.dataProvider = new ArrayCollection<String>([
            "installers", "hotfixes", "fixpacks"
        ]);
        _rowType.content.addChild(_dropdownType);
        
        // Create version row
        _rowVersion = new GenesisFormRow();
        _rowVersion.text = "Version";
        _addEditForm.addChild(_rowVersion);
        
        // Create version inputs
        var versionGroup = new LayoutGroup();
        var versionLayout = new HorizontalLayout();
        versionLayout.gap = GenesisApplicationTheme.GRID;
        versionGroup.layout = versionLayout;
        _rowVersion.content.addChild(versionGroup);
        
        // Major version
        var majorLabel = new Label();
        majorLabel.text = "Major:";
        versionGroup.addChild(majorLabel);
        
        _inputMajorVersion = new TextInput();
        _inputMajorVersion.width = GenesisApplicationTheme.GRID * 10;
        versionGroup.addChild(_inputMajorVersion);
        
        // Minor version
        var minorLabel = new Label();
        minorLabel.text = "Minor:";
        versionGroup.addChild(minorLabel);
        
        _inputMinorVersion = new TextInput();
        _inputMinorVersion.width = GenesisApplicationTheme.GRID * 10;
        versionGroup.addChild(_inputMinorVersion);
        
        // Patch version
        var patchLabel = new Label();
        patchLabel.text = "Patch:";
        versionGroup.addChild(patchLabel);
        
        _inputPatchVersion = new TextInput();
        _inputPatchVersion.width = GenesisApplicationTheme.GRID * 10;
        versionGroup.addChild(_inputPatchVersion);
        
        // Full version row
        var fullVersionRow = new GenesisFormRow();
        fullVersionRow.text = "Full Version";
        _addEditForm.addChild(fullVersionRow);
        
        _inputFullVersion = new TextInput();
        fullVersionRow.content.addChild(_inputFullVersion);
        
        // Hash display row - will be visible only in edit mode
        var hashRow = new GenesisFormRow();
        hashRow.text = "File Hash";
        _addEditForm.addChild(hashRow);
        
        var hashLabel = new Label();
        hashRow.content.addChild(hashLabel);
        
        // Store reference to hash row and label for toggling visibility
        _hashRow = hashRow;
        _hashLabel = hashLabel;
        
        // Add/Edit form buttons
        var addEditButtonGroup = new LayoutGroup();
        addEditButtonGroup.layoutData = new VerticalLayoutData(100); // Make sure it takes full width
        var addEditButtonLayout = new HorizontalLayout();
        addEditButtonLayout.gap = GenesisApplicationTheme.GRID * 2;
        addEditButtonLayout.horizontalAlign = HorizontalAlign.CENTER; // Center align the buttons
        addEditButtonGroup.layout = addEditButtonLayout;
        _addEditForm.addChild(addEditButtonGroup);
        
        // Create a container that will be centered
        var buttonContainer = new LayoutGroup();
        var buttonContainerLayout = new HorizontalLayout();
        buttonContainerLayout.gap = GenesisApplicationTheme.GRID * 2;
        buttonContainer.layout = buttonContainerLayout;
        addEditButtonGroup.addChild(buttonContainer);
        
        _buttonAddEditSave = new GenesisFormButton("Save");
        _buttonAddEditSave.addEventListener(TriggerEvent.TRIGGER, _saveAddEditButtonTriggered);
        _buttonAddEditSave.width = GenesisApplicationTheme.GRID * 20;
        buttonContainer.addChild(_buttonAddEditSave);
        
        _buttonAddEditCancel = new GenesisFormButton("Cancel");
        _buttonAddEditCancel.addEventListener(TriggerEvent.TRIGGER, _cancelAddEditButtonTriggered);
        _buttonAddEditCancel.width = GenesisApplicationTheme.GRID * 20;
        buttonContainer.addChild(_buttonAddEditCancel);
        
        // Create file path display container with a background to make it stand out
        var filePathContainer = new LayoutGroup();
        filePathContainer.layoutData = new VerticalLayoutData(100);
        var filePathLayout = new VerticalLayout();
        filePathLayout.paddingTop = GenesisApplicationTheme.GRID * 2;
        filePathLayout.paddingBottom = GenesisApplicationTheme.GRID * 2;
        filePathLayout.paddingLeft = GenesisApplicationTheme.GRID * 4;
        filePathLayout.paddingRight = GenesisApplicationTheme.GRID * 4;
        filePathContainer.layout = filePathLayout;
        
        // No background for the file path container as requested
        
        // Create the file path label
        _filePathLabel = new Label();
        _filePathLabel.variant = GenesisApplicationTheme.LABEL_SMALL_CENTERED; // Using small centered font
        _filePathLabel.wordWrap = true;
        _filePathLabel.layoutData = new VerticalLayoutData(100); // Take full width
        filePathContainer.addChild(_filePathLabel);
        
        // Initially hide the container
        filePathContainer.visible = filePathContainer.includeInLayout = false;
        
        // Store reference to container for toggling visibility
        _filePathContainer = filePathContainer;
        
        // Add the container right after the add/edit form in the scroll container
        _scrollContainer.addChild(filePathContainer);

        var bottomLine = new HLine();
        bottomLine.width = _width;
        this.addChild(bottomLine);
        
        // Create bottom button group
        _buttonGroup = new LayoutGroup();
        _buttonGroupLayout = new HorizontalLayout();
        _buttonGroupLayout.gap = GenesisApplicationTheme.GRID * 2;
        _buttonGroupLayout.horizontalAlign = HorizontalAlign.CENTER;
        _buttonGroup.layout = _buttonGroupLayout;
        _buttonSave = new GenesisFormButton("Save");
        _buttonSave.addEventListener(TriggerEvent.TRIGGER, _saveButtonTriggered);
        _buttonSave.width = GenesisApplicationTheme.GRID * 20;
        _buttonCancel = new GenesisFormButton("Cancel");
        _buttonCancel.addEventListener(TriggerEvent.TRIGGER, _cancelButtonTriggered);
        _buttonCancel.width = GenesisApplicationTheme.GRID * 20;
        _buttonGroup.addChild(_buttonSave);
        _buttonGroup.addChild(_buttonCancel);
        this.addChild(_buttonGroup);
        
        // Load cached files
        loadCachedFiles();
    }
    
    /**
     * Function to display file information in the list
     */
    private function _fileItemToText(item:SuperHumanCachedFile):String {
        if (item == null) return "";
        
        var filename = item.originalFilename;
        var role = item.role;
        var type = item.type;
        var exists = item.exists ? "✓" : "✗";
        
        // Format version info
        var version = "";
        if (item.version != null && item.version.fullVersion != null) {
            version = item.version.fullVersion;
        } else if (item.version != null) {
            var parts = [];
            if (item.version.majorVersion != null) parts.push(item.version.majorVersion);
            if (item.version.minorVersion != null) parts.push(item.version.minorVersion);
            if (item.version.patchVersion != null) parts.push(item.version.patchVersion);
            
            if (parts.length > 0) {
                version = parts.join(".");
            }
        }
        
        return '${filename} [${role}/${type}] - ${version} ${exists}';
    }
    
    /**
     * Create sortable column headers
     */
    private function createSortableHeaders():LayoutGroup {
        var headerContainer = new LayoutGroup();
        // Remove background completely for the header row
        headerContainer.backgroundSkin = null;
        headerContainer.height = GenesisApplicationTheme.GRID * 6; // Increased height for header row
        headerContainer.layoutData = new VerticalLayoutData(100);
        
        // Create header layout matching the item layout
        var headerColumnsLayout = new HorizontalLayout();
        headerColumnsLayout.paddingLeft = GenesisApplicationTheme.GRID * 2;
        headerColumnsLayout.paddingRight = GenesisApplicationTheme.GRID * 2;
        headerColumnsLayout.gap = GenesisApplicationTheme.GRID * 2;
        headerColumnsLayout.verticalAlign = VerticalAlign.MIDDLE;
        headerContainer.layout = headerColumnsLayout;
        
        // Create filename column group with sort button
        var filenameHeaderGroup = new LayoutGroup();
        filenameHeaderGroup.width = FileEntryItem.FILENAME_WIDTH;
        var filenameHeaderLayout = new HorizontalLayout();
        filenameHeaderLayout.paddingRight = GenesisApplicationTheme.GRID;
        filenameHeaderLayout.verticalAlign = VerticalAlign.MIDDLE;
        filenameHeaderGroup.layout = filenameHeaderLayout;
        headerContainer.addChild(filenameHeaderGroup);
        
        // Add filename sort button with bold text
        var filenameHeader = new Button();
        filenameHeader.text = "FILENAME" + (_currentSortColumn == "filename" ? (_currentSortAscending ? " ▲" : " ▼") : "");
        // Use default button style instead of tiny
        
        // Apply bold white text formatting
        var filenameFormat = new openfl.text.TextFormat();
        filenameFormat.bold = true;
        filenameFormat.color = 0xFFFFFF; // White text
        filenameHeader.textFormat = filenameFormat;
        
        // Remove button background
        filenameHeader.backgroundSkin = null;
        
        filenameHeader.addEventListener(TriggerEvent.TRIGGER, (e) -> _sortColumnTriggered("filename"));
        filenameHeaderGroup.addChild(filenameHeader);
        
        // Create hash column group with sort button
        var hashHeaderGroup = new LayoutGroup();
        hashHeaderGroup.width = FileEntryItem.HASH_WIDTH;
        var hashHeaderLayout = new HorizontalLayout();
        hashHeaderLayout.paddingRight = GenesisApplicationTheme.GRID;
        hashHeaderLayout.verticalAlign = VerticalAlign.MIDDLE;
        hashHeaderGroup.layout = hashHeaderLayout;
        headerContainer.addChild(hashHeaderGroup);
        
        // Add hash sort button with bold text
        var hashHeader = new Button();
        hashHeader.text = "HASH" + (_currentSortColumn == "hash" ? (_currentSortAscending ? " ▲" : " ▼") : "");
        // Use default button style instead of tiny
        
        // Apply bold white text formatting
        var hashFormat = new openfl.text.TextFormat();
        hashFormat.bold = true;
        hashFormat.color = 0xFFFFFF; // White text
        hashHeader.textFormat = hashFormat;
        
        // Remove button background
        hashHeader.backgroundSkin = null;
        
        hashHeader.addEventListener(TriggerEvent.TRIGGER, (e) -> _sortColumnTriggered("hash"));
        hashHeaderGroup.addChild(hashHeader);
        
        // Create role column group with sort button
        var roleHeaderGroup = new LayoutGroup();
        roleHeaderGroup.width = FileEntryItem.ROLE_WIDTH;
        var roleHeaderLayout = new HorizontalLayout();
        roleHeaderLayout.paddingRight = GenesisApplicationTheme.GRID;
        roleHeaderLayout.verticalAlign = VerticalAlign.MIDDLE;
        roleHeaderGroup.layout = roleHeaderLayout;
        headerContainer.addChild(roleHeaderGroup);
        
        // Add role sort button with bold text
        var roleHeader = new Button();
        roleHeader.text = "ROLE" + (_currentSortColumn == "role" ? (_currentSortAscending ? " ▲" : " ▼") : "");
        // Use default button style instead of tiny
        
        // Apply bold white text formatting
        var roleFormat = new openfl.text.TextFormat();
        roleFormat.bold = true;
        roleFormat.color = 0xFFFFFF; // White text
        roleHeader.textFormat = roleFormat;
        
        // Remove button background
        roleHeader.backgroundSkin = null;
        
        roleHeader.addEventListener(TriggerEvent.TRIGGER, (e) -> _sortColumnTriggered("role"));
        roleHeaderGroup.addChild(roleHeader);
        
        // Create type column group with sort button
        var typeHeaderGroup = new LayoutGroup();
        typeHeaderGroup.width = FileEntryItem.TYPE_WIDTH;
        var typeHeaderLayout = new HorizontalLayout();
        typeHeaderLayout.paddingRight = GenesisApplicationTheme.GRID;
        typeHeaderLayout.verticalAlign = VerticalAlign.MIDDLE;
        typeHeaderGroup.layout = typeHeaderLayout;
        headerContainer.addChild(typeHeaderGroup);
        
        // Add type sort button with bold text
        var typeHeader = new Button();
        typeHeader.text = "TYPE" + (_currentSortColumn == "type" ? (_currentSortAscending ? " ▲" : " ▼") : "");
        // Use default button style instead of tiny
        
        // Apply bold white text formatting
        var typeFormat = new openfl.text.TextFormat();
        typeFormat.bold = true;
        typeFormat.color = 0xFFFFFF; // White text
        typeHeader.textFormat = typeFormat;
        
        // Remove button background
        typeHeader.backgroundSkin = null;
        
        typeHeader.addEventListener(TriggerEvent.TRIGGER, (e) -> _sortColumnTriggered("type"));
        typeHeaderGroup.addChild(typeHeader);
        
        // Create version column group with sort button
        var versionHeaderGroup = new LayoutGroup();
        versionHeaderGroup.width = FileEntryItem.VERSION_WIDTH;
        var versionHeaderLayout = new HorizontalLayout();
        versionHeaderLayout.verticalAlign = VerticalAlign.MIDDLE;
        versionHeaderGroup.layout = versionHeaderLayout;
        headerContainer.addChild(versionHeaderGroup);
        
        // Add version sort button with bold text
        var versionHeader = new Button();
        versionHeader.text = "VERSION" + (_currentSortColumn == "version" ? (_currentSortAscending ? " ▲" : " ▼") : "");
        // Use default button style instead of tiny
        
        // Apply bold white text formatting
        var versionFormat = new openfl.text.TextFormat();
        versionFormat.bold = true;
        versionFormat.color = 0xFFFFFF; // White text
        versionHeader.textFormat = versionFormat;
        
        // Remove button background
        versionHeader.backgroundSkin = null;
        
        versionHeader.addEventListener(TriggerEvent.TRIGGER, (e) -> _sortColumnTriggered("version"));
        versionHeaderGroup.addChild(versionHeader);
        
        return headerContainer;
    }
    
    /**
     * Method to sort the file collection based on the current sort settings
     */
    private function sortFiles():Void {
        if (_fileCollection == null || _fileCollection.length == 0) return;
        
        // Sort the file collection based on the current sort column and direction
        _fileCollection.sort((a, b) -> {
            var result:Int = 0;
            
            // Compare based on the selected column
            switch (_currentSortColumn) {
                case "filename":
                    result = a.originalFilename.toLowerCase() < b.originalFilename.toLowerCase() ? -1 : 1;
                
                case "hash":
                    result = a.hash < b.hash ? -1 : 1;
                
                case "role":
                    // Handle potential null values
                    var roleA = a.role != null ? a.role.toLowerCase() : "";
                    var roleB = b.role != null ? b.role.toLowerCase() : "";
                    result = roleA < roleB ? -1 : 1;
                
                case "type":
                    // Handle potential null values
                    var typeA = a.type != null ? a.type.toLowerCase() : "";
                    var typeB = b.type != null ? b.type.toLowerCase() : "";
                    result = typeA < typeB ? -1 : 1;
                
                case "version":
                    // Extract version for comparison
                    var versionA = "";
                    var versionB = "";
                    
                    if (a.version != null && a.version.fullVersion != null) {
                        versionA = a.version.fullVersion;
                    }
                    
                    if (b.version != null && b.version.fullVersion != null) {
                        versionB = b.version.fullVersion;
                    }
                    
                    result = versionA < versionB ? -1 : 1;
            }
            
            // Reverse the result if sorting in descending order
            return _currentSortAscending ? result : -result;
        });
    }
    
    /**
     * Handle column header click for sorting
     */
    private function _sortColumnTriggered(column:String):Void {
        // If clicking the same column, toggle sort direction
        if (_currentSortColumn == column) {
            _currentSortAscending = !_currentSortAscending;
        } else {
            // New column, set it as the current sort column and default to ascending
            _currentSortColumn = column;
            _currentSortAscending = true;
        }
        
        // Refresh the list with the new sorting
        refreshFileList();
    }
    
    /**
     * Refresh the file list with current sorting
     */
    private function refreshFileList():Void {
        // Sort the file collection based on current sort settings
        sortFiles();
        
        // Remove all items including the header row
        while (_listGroup.numChildren > 0) {
            _listGroup.removeChildAt(_listGroup.numChildren - 1);
        }
        
        // Recreate the header row with updated sort indicators
        _listGroup.addChild(createSortableHeaders());
        
        // Create file item components for each sorted entry
        for (i in 0..._fileCollection.length) {
            var file = _fileCollection[i];
            
            // Create file entry item
            var item = new FileEntryItem(file, i % 2 == 0);
            item.parentPage = this; // Set parent page reference
            _listGroup.addChild(item);
            
            // Add separator line
            if (i < _fileCollection.length - 1) {
                var line = new HLine();
                line.layoutData = new VerticalLayoutData(100);
                line.alpha = 0.5;
                _listGroup.addChild(line);
            }
        }
        
        // Update UI state
        updateUI();
    }
    
    /**
     * Load cached files from the registry
     */
    public function loadCachedFiles():Void {
        // Remove all items including the header row
        while (_listGroup.numChildren > 0) {
            _listGroup.removeChildAt(_listGroup.numChildren - 1);
        }
        
        // Recreate the header row with updated sort indicators
        _listGroup.addChild(createSortableHeaders());
        
        // Reset selection
        _selectedFileItem = null;
        
        // Clear current collection
        _fileCollection = [];
        
        try {
            // Get registry from SuperHumanFileCache with error handling
            var fileCache = SuperHumanFileCache.getInstance();
            
            // Ensure the cache is properly initialized
            if (fileCache == null) {
                Logger.error('Failed to get FileCache instance');
                return;
            }
            
            var registry = fileCache.getRegistry();
            if (registry == null) {
                Logger.error('Registry is null');
                return;
            }
            
            // Debug log the registry structure before flattening
            Logger.info('Registry structure before flattening:');
            for (role in registry.keys()) {
                var roleMap = registry.get(role);
                if (roleMap != null) {
                    for (type in roleMap.keys()) {
                        var entries = roleMap.get(type);
                        if (entries != null) {
                            Logger.info('  Role: ${role}, Type: ${type}, Entries: ${entries.length}');
                        }
                    }
                }
            }
            
            // Flatten the registry into a list with null checks
            for (role in registry.keys()) {
                var roleMap = registry.get(role);
                if (roleMap == null) {
                    Logger.warning('Role map is null for role ${role}, skipping');
                    continue;
                }
                
                for (type in roleMap.keys()) {
                    var entries = roleMap.get(type);
                    if (entries == null) {
                        Logger.warning('Entries are null for type ${type} in role ${role}, skipping');
                        continue;
                    }
                    
                    for (entry in entries) {
                        if (entry == null) {
                            Logger.warning('Null entry found in ${role}/${type}, skipping');
                            continue;
                        }
                        _fileCollection.push(entry);
                    }
                }
            }
            
            Logger.info('Loaded ${_fileCollection.length} cached files');
            
            // Create file item components for each entry
            for (i in 0..._fileCollection.length) {
                var file = _fileCollection[i];
                
                // Create file entry item
                var item = new FileEntryItem(file, i % 2 == 0);
                item.parentPage = this; // Set parent page reference
                _listGroup.addChild(item);
                
                // Add separator line
                if (i < _fileCollection.length - 1) {
                    var line = new HLine();
                    line.layoutData = new VerticalLayoutData(100);
                    line.alpha = 0.5;
                    _listGroup.addChild(line);
                }
            }
            
            // Update UI state
            updateUI();
            
        } catch (e) {
            Logger.error('Error loading cached files: ${e}');
        }
    }
    
    /**
     * Direct selection method called by FileEntryItem instances
     * @param item The item to select
     */
    public function selectItem(item:FileEntryItem):Void {
        // Skip if item is null
        if (item == null) return;
        
        // Deselect previous item if different
        if (_selectedFileItem != null && _selectedFileItem != item) {
            _selectedFileItem.selected = false;
        }
        
        // Toggle selection of the current item
        if (_selectedFileItem == item) {
            item.selected = !item.selected;
            _selectedFileItem = item.selected ? item : null;
        } else {
            // Set new selected item
            _selectedFileItem = item;
            _selectedFileItem.selected = true;
        }
        
        // Update UI
        updateUI();
    }
    
    /**
     * Update the UI based on the current state
     */
    public function updateUI():Void {
        var hasSelection = _selectedFileItem != null;
        _buttonEditFile.enabled = hasSelection;
        _buttonDeleteFile.enabled = hasSelection;
    }
    
    /**
     * Handle add file button
     */
    private function _addFileButtonTriggered(e:TriggerEvent):Void {
        // Show file dialog to select a file
        if (_fileDialog != null) return;
        
        var dir = lime.system.System.userDirectory;
        _fileDialog = new FileDialog();
        
        _fileDialog.onSelect.add(path -> {
            _tempSourceFilePath = path;
            _fileDialog.onSelect.removeAll();
            _fileDialog.onCancel.removeAll();
            _fileDialog = null;
            
            // Reset form for adding new file
            _editingFile = null;
            
            // Set default values
            _dropdownRole.selectedIndex = 0;
            _dropdownType.selectedIndex = 0;
            _inputMajorVersion.text = "";
            _inputMinorVersion.text = "";
            _inputPatchVersion.text = "";
            _inputFullVersion.text = "";
            
            // Show the add/edit form
            _listGroup.visible = _listGroup.includeInLayout = false;
            _addEditForm.visible = _addEditForm.includeInLayout = true;
            // Hide file path container when adding a new file
            _filePathContainer.visible = _filePathContainer.includeInLayout = false;
            // Hide bottom buttons when showing the form
            _buttonGroup.visible = _buttonGroup.includeInLayout = false;
            _buttonAddEditSave.text = "Add File";
        });
        
        _fileDialog.onCancel.add(() -> {
            _fileDialog.onCancel.removeAll();
            _fileDialog.onSelect.removeAll();
            _fileDialog = null;
        });
        
        _fileDialog.browse(FileDialogType.OPEN, null, dir, "Select file to cache");
    }
    
    /**
     * Handle edit file button
     */
    // Button for replacing missing files in edit form
    private var _buttonReplaceFile:GenesisFormButton;
    private var _rowReplaceFile:GenesisFormRow;
    
    private function _editFileButtonTriggered(e:TriggerEvent):Void {
        if (_selectedFileItem == null) return;
        
        // Get the selected file
        _editingFile = _selectedFileItem.cachedFile;
        _tempSourceFilePath = null;
        
        // Set form values
        var roleIndex = _dropdownRole.dataProvider.indexOf(_editingFile.role);
        _dropdownRole.selectedIndex = roleIndex >= 0 ? roleIndex : 0;
        
        var typeIndex = _dropdownType.dataProvider.indexOf(_editingFile.type);
        _dropdownType.selectedIndex = typeIndex >= 0 ? typeIndex : 0;
        
        if (_editingFile.version != null) {
            _inputMajorVersion.text = _editingFile.version.majorVersion != null ? _editingFile.version.majorVersion : "";
            _inputMinorVersion.text = _editingFile.version.minorVersion != null ? _editingFile.version.minorVersion : "";
            _inputPatchVersion.text = _editingFile.version.patchVersion != null ? _editingFile.version.patchVersion : "";
            _inputFullVersion.text = _editingFile.version.fullVersion != null ? _editingFile.version.fullVersion : "";
        } else {
            _inputMajorVersion.text = "";
            _inputMinorVersion.text = "";
            _inputPatchVersion.text = "";
            _inputFullVersion.text = "";
        }
        
        // Check if the file exists and show replacement button if needed
        if (_rowReplaceFile == null) {
            // Create the row for replace file button if it doesn't exist
            _rowReplaceFile = new GenesisFormRow();
            _rowReplaceFile.text = "Replace File";
            
            _buttonReplaceFile = new GenesisFormButton("Browse...");
            _buttonReplaceFile.addEventListener(TriggerEvent.TRIGGER, _replaceFileButtonTriggered);
            _buttonReplaceFile.width = GenesisApplicationTheme.GRID * 20;
            _rowReplaceFile.content.addChild(_buttonReplaceFile);
            
            // Insert after the version row but before the buttons
            _addEditForm.addChildAt(_rowReplaceFile, _addEditForm.numChildren - 1);
        }
        
        // Show/hide replace button based on file existence
        _rowReplaceFile.visible = _rowReplaceFile.includeInLayout = !_editingFile.exists;
        
        // Show the file path and hash when editing
        if (_filePathLabel != null && _filePathContainer != null && _hashLabel != null) {
            // Set path text and make container visible
            _filePathLabel.text = _editingFile.path;
            _filePathContainer.visible = _filePathContainer.includeInLayout = true;
            
        // Only display SHA256 hash, no fallback to MD5
        _hashLabel.text = Reflect.hasField(_editingFile, "sha256") && _editingFile.sha256 != null ? 
                          _editingFile.sha256 : "SHA256 not available";
        }
        
        // Show the add/edit form
        _listGroup.visible = _listGroup.includeInLayout = false;
        _addEditForm.visible = _addEditForm.includeInLayout = true;
        // Hide bottom buttons when showing the edit form
        _buttonGroup.visible = _buttonGroup.includeInLayout = false;
        _buttonAddEditSave.text = "Update File";
    }
    
    /**
     * Handle replace file button in edit form
     */
    private function _replaceFileButtonTriggered(e:TriggerEvent):Void {
        if (_fileDialog != null) return;
        
        var dir = lime.system.System.userDirectory;
        _fileDialog = new FileDialog();
        
        _fileDialog.onSelect.add(path -> {
            _tempSourceFilePath = path;
            _fileDialog.onSelect.removeAll();
            _fileDialog.onCancel.removeAll();
            _fileDialog = null;
            
            // Show message that file has been selected
            _buttonReplaceFile.text = "File Selected";
        });
        
        _fileDialog.onCancel.add(() -> {
            _fileDialog.onCancel.removeAll();
            _fileDialog.onSelect.removeAll();
            _fileDialog = null;
        });
        
        _fileDialog.browse(FileDialogType.OPEN, null, dir, "Select replacement file");
    }
    
    /**
     * Handle delete file button
     */
    private function _deleteFileButtonTriggered(e:TriggerEvent):Void {
        if (_selectedFileItem == null) return;
        
        var selectedFile = _selectedFileItem.cachedFile;
        
        Alert.show(
            'Are you sure you want to remove "${selectedFile.originalFilename}" from the cache?',
            "Remove File",
            ["Remove", "Cancel"],
            (state) -> {
                if (state.index == 0) {
                    // Remove file from cache
                    if (SuperHumanFileCache.getInstance().removeFile(selectedFile)) {
                        // Reload cached files
                        loadCachedFiles();
                        ToastManager.getInstance().showToast("File removed from cache");
                    } else {
                        ToastManager.getInstance().showToast("Failed to remove file from cache");
                    }
                }
            }
        );
    }
    
    /**
     * Handle save button in add/edit form
     */
    private function _saveAddEditButtonTriggered(e:TriggerEvent):Void {
        // Get values from form
        var role = _dropdownRole.selectedItem;
        var type = _dropdownType.selectedItem;
        
        // Create version object
        var version:Dynamic = {};
        
        if (_inputMajorVersion.text != null && _inputMajorVersion.text.length > 0) {
            Reflect.setField(version, "majorVersion", _inputMajorVersion.text);
        }
        
        if (_inputMinorVersion.text != null && _inputMinorVersion.text.length > 0) {
            Reflect.setField(version, "minorVersion", _inputMinorVersion.text);
        }
        
        if (_inputPatchVersion.text != null && _inputPatchVersion.text.length > 0) {
            Reflect.setField(version, "patchVersion", _inputPatchVersion.text);
        }
        
        if (_inputFullVersion.text != null && _inputFullVersion.text.length > 0) {
            Reflect.setField(version, "fullVersion", _inputFullVersion.text);
        } else if (Reflect.hasField(version, "majorVersion")) {
            // Auto-generate full version if not provided
            var fullVersion = version.majorVersion;
            if (Reflect.hasField(version, "minorVersion")) {
                fullVersion += "." + version.minorVersion;
                if (Reflect.hasField(version, "patchVersion")) {
                    fullVersion += "." + version.patchVersion;
                }
            }
            Reflect.setField(version, "fullVersion", fullVersion);
        }
        
        if (_editingFile != null) {
            // Update existing file
            _editingFile.role = role;
            _editingFile.type = type;
            _editingFile.version = version;
            
            // If we have a replacement file, handle it differently
            if (_tempSourceFilePath != null && !_editingFile.exists) {
                // Pass the original hash to the addFile method to handle cleanup
                var result = SuperHumanFileCache.getInstance().addFile(_tempSourceFilePath, role, type, version, _editingFile.hash);
                if (result != null) {
                    ToastManager.getInstance().showToast("File replaced in cache");
                } else {
                    ToastManager.getInstance().showToast("Failed to replace file in cache");
                }
            } else {
                // Just update metadata if we're not replacing the file
                if (SuperHumanFileCache.getInstance().updateFileMetadata(_editingFile)) {
                    ToastManager.getInstance().showToast("File updated in cache");
                } else {
                    ToastManager.getInstance().showToast("Failed to update file in cache");
                }
            }
        } else if (_tempSourceFilePath != null) {
            // Add new file
            var result = SuperHumanFileCache.getInstance().addFile(_tempSourceFilePath, role, type, version);
            if (result != null) {
                ToastManager.getInstance().showToast("File added to cache");
            } else {
                ToastManager.getInstance().showToast("Failed to add file to cache");
            }
        }
        
        // Reset form and button state
        _editingFile = null;
        _tempSourceFilePath = null;
        if (_buttonReplaceFile != null) {
            _buttonReplaceFile.text = "Browse...";
        }
        
        // Hide file path container
        _filePathContainer.visible = _filePathContainer.includeInLayout = false;
        
        // Show file list
        _listGroup.visible = _listGroup.includeInLayout = true;
        _addEditForm.visible = _addEditForm.includeInLayout = false;
        // Show bottom buttons again
        _buttonGroup.visible = _buttonGroup.includeInLayout = true;
        
        // Reload cached files
        loadCachedFiles();
    }
    
    /**
     * Handle cancel button in add/edit form
     */
    private function _cancelAddEditButtonTriggered(e:TriggerEvent):Void {
        // Reset form
        _editingFile = null;
        _tempSourceFilePath = null;
        
        // Hide file path container
        _filePathContainer.visible = _filePathContainer.includeInLayout = false;
        
        // Show file list
        _listGroup.visible = _listGroup.includeInLayout = true;
        _addEditForm.visible = _addEditForm.includeInLayout = false;
        // Show bottom buttons again
        _buttonGroup.visible = _buttonGroup.includeInLayout = true;
    }
    
    /**
     * Handle save button
     */
    private function _saveButtonTriggered(e:TriggerEvent):Void {
        // Save any changes (already done when adding/editing/deleting files)
        this.dispatchEvent(new SuperHumanApplicationEvent(SuperHumanApplicationEvent.SAVE_APP_CONFIGURATION));
    }
    
    /**
     * Handle cancel button
     */
    private function _cancelButtonTriggered(e:TriggerEvent):Void {
        this.dispatchEvent(new SuperHumanApplicationEvent(SuperHumanApplicationEvent.CANCEL_PAGE));
    }
    
    /**
     * Handle open cache directory button
     */
    private function _openCacheDirButtonTriggered(e:TriggerEvent):Void {
        var event = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.OPEN_FILE_CACHE_DIRECTORY);
        this.dispatchEvent(event);
    }
    
    /**
     * Handle REFRESH_HASH_MANAGER event from other components
     * This allows external components (like DownloadDialog) to trigger a refresh
     */
    private function onRefreshHashManager(e:Event):Void {
        Logger.info('HashManagerPage: Received REFRESH_HASH_MANAGER event, refreshing file list');
        loadCachedFiles();
    }
}

/**
 * Custom component for displaying a cached file entry in the list
 */
class FileEntryItem extends LayoutGroup {
    // The cached file this item represents
    public var cachedFile:SuperHumanCachedFile;
    
    // Selection state
    private var _selected:Bool = false;
    
    // Keep track of whether this is an even row
    private var _isEven:Bool;
    
    // UI elements
    private var _filenameGroup:LayoutGroup;
    private var _filenameLabel:Label;
    private var _roleGroup:LayoutGroup;
    private var _roleLabel:Label;
    private var _typeGroup:LayoutGroup;
    private var _typeLabel:Label;
    private var _versionGroup:LayoutGroup;
    private var _versionLabel:Label;
    private var _background:RectangleSkin;
    private var _layout:HorizontalLayout;
    
    // Background colors
    private static final COLOR_EVEN:Int = 0x1e1e1e;
    private static final COLOR_ODD:Int = 0x252525;
    private static final COLOR_SELECTED:Int = 0x004080;
    
    // Column widths - made public so they can be accessed from HashManagerPage
    public static final FILENAME_WIDTH:Float = GenesisApplicationTheme.GRID * 66; // Redistributed some width to hash column
    public static final HASH_WIDTH:Float = GenesisApplicationTheme.GRID * 28; // Increased by 3 grid units
    public static final ROLE_WIDTH:Float = GenesisApplicationTheme.GRID * 20;
    public static final TYPE_WIDTH:Float = GenesisApplicationTheme.GRID * 12;
    public static final VERSION_WIDTH:Float = GenesisApplicationTheme.GRID * 18;
    
    public function new(file:SuperHumanCachedFile, isEven:Bool) {
        super();
        
        this.cachedFile = file;
        this._isEven = isEven;
        
        // Set up basic layout properties
        this.height = GenesisApplicationTheme.GRID * 4;
        this.layoutData = new VerticalLayoutData(100);
        
        // Set up mouse event listeners for selection
        this.addEventListener(MouseEvent.CLICK, _onClick);
        
        // Set up background
        _background = new RectangleSkin(FillStyle.SolidColor(isEven ? COLOR_EVEN : COLOR_ODD));
        this.backgroundSkin = _background;
        
        // Create horizontal layout with moderate spacing
        _layout = new HorizontalLayout();
        _layout.paddingLeft = GenesisApplicationTheme.GRID * 2;
        _layout.paddingRight = GenesisApplicationTheme.GRID * 2;
        _layout.gap = GenesisApplicationTheme.GRID * 2;
        _layout.verticalAlign = VerticalAlign.MIDDLE;
        this.layout = _layout;
        
        // Create filename column with fixed width
        _filenameGroup = new LayoutGroup();
        _filenameGroup.width = FILENAME_WIDTH;
        var filenameLayout = new HorizontalLayout();
        filenameLayout.paddingRight = GenesisApplicationTheme.GRID;
        filenameLayout.verticalAlign = VerticalAlign.MIDDLE;
        _filenameGroup.layout = filenameLayout;
        this.addChild(_filenameGroup);
        
        _filenameLabel = new Label();
        _filenameLabel.wordWrap = false;
        _filenameGroup.addChild(_filenameLabel);
        
        // Create hash column
        var hashGroup = new LayoutGroup();
        hashGroup.width = HASH_WIDTH;
        var hashLayout = new HorizontalLayout();
        hashLayout.paddingRight = GenesisApplicationTheme.GRID;
        hashLayout.verticalAlign = VerticalAlign.MIDDLE;
        hashGroup.layout = hashLayout;
        this.addChild(hashGroup);
        
        var hashLabel = new Label();
        hashLabel.wordWrap = false;
        // Only display SHA256 hash, no fallback to MD5
        var hashToDisplay = Reflect.hasField(cachedFile, "sha256") && cachedFile.sha256 != null ? 
                            cachedFile.sha256 : "SHA256 not available";
        hashLabel.text = hashToDisplay.length > 15 ? hashToDisplay.substr(0, 15) + "..." : hashToDisplay; // Show abbreviated hash if needed
        hashGroup.addChild(hashLabel);
        
        // Create role column with fixed width
        _roleGroup = new LayoutGroup();
        _roleGroup.width = ROLE_WIDTH;
        var roleLayout = new HorizontalLayout();
        roleLayout.paddingRight = GenesisApplicationTheme.GRID;
        roleLayout.verticalAlign = VerticalAlign.MIDDLE;
        _roleGroup.layout = roleLayout;
        this.addChild(_roleGroup);
        
        _roleLabel = new Label();
        _roleLabel.wordWrap = false;
        _roleGroup.addChild(_roleLabel);
        
        // Create type column with fixed width
        _typeGroup = new LayoutGroup();
        _typeGroup.width = TYPE_WIDTH;
        var typeLayout = new HorizontalLayout();
        typeLayout.paddingRight = GenesisApplicationTheme.GRID;
        typeLayout.verticalAlign = VerticalAlign.MIDDLE;
        _typeGroup.layout = typeLayout;
        this.addChild(_typeGroup);
        
        _typeLabel = new Label();
        _typeLabel.wordWrap = false;
        _typeGroup.addChild(_typeLabel);
        
        // Create version column with fixed width
        _versionGroup = new LayoutGroup();
        _versionGroup.width = VERSION_WIDTH;
        var versionLayout = new HorizontalLayout();
        versionLayout.verticalAlign = VerticalAlign.MIDDLE;
        _versionGroup.layout = versionLayout;
        this.addChild(_versionGroup);
        
        _versionLabel = new Label();
        _versionLabel.wordWrap = false;
        _versionGroup.addChild(_versionLabel);
        
        // Set the label text
        updateLabels();
    }
    
    // Status icon buttons
    private var _warningIconButton:Button;
    private var _statusIconButton:Button;
    
    /**
     * Update labels with file data
     */
    private function updateLabels():Void {
        // Format filename
        var filenameText = cachedFile.originalFilename;
        
        // Check if the file exists in the cache
        var fileMissing = !cachedFile.exists;
        
        // Create warning icon button if needed and not already created
        if (fileMissing && _warningIconButton == null) {
            _warningIconButton = new Button();
            _warningIconButton.icon = GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_WARNING);
            _warningIconButton.variant = GenesisApplicationTheme.BUTTON_ICON_NO_PADDING;
            
            // Add event listener to show download dialog for missing files
            _warningIconButton.addEventListener(TriggerEvent.TRIGGER, (e) -> {
                // Stop propagation to avoid triggering row selection
                e.stopPropagation();
                
                // Only proceed if it's a missing file (which it should be for unknown files)
                if (!cachedFile.exists) {
                    Logger.error('UNKNOWN FILE CLICK: Showing download dialog for ${cachedFile.originalFilename}');
                    _showDownloadDialog(cachedFile);
                }
            });
            
            // Insert at beginning of filename group
            _filenameGroup.addChildAt(_warningIconButton, 0);
        }
        
        // Create status icon button if not already created
        if (!fileMissing && _statusIconButton == null) {
            _statusIconButton = new Button();
            // Icon will be set based on existence
            _statusIconButton.variant = GenesisApplicationTheme.BUTTON_ICON_NO_PADDING;
            
            // Add download functionality when clicking status icon
            _statusIconButton.addEventListener(TriggerEvent.TRIGGER, _statusIconButtonTriggered);
            
            // Insert at beginning of filename group
            _filenameGroup.addChildAt(_statusIconButton, 0);
        }
        
        // Check if the file is missing from cache
        if (fileMissing) {
            // Try to get expected filename from registry if the file is missing
            var expectedFilename = cachedFile.originalFilename;
            
            // Check if originalFilename is usable (not "unknown.unknown")
            if (expectedFilename != null && expectedFilename != "unknown.unknown") {
                filenameText = expectedFilename;
            } else {
                // Try to find filename in initial registry
                var registryEntry = superhuman.config.SuperHumanHashes.findHashEntry(cachedFile.hash);
                if (registryEntry != null && Reflect.hasField(registryEntry, "fileName")) {
                    var fileName = Reflect.field(registryEntry, "fileName");
                    if (fileName != null && fileName != "unknown.unknown") {
                        filenameText = fileName;
                    } else {
                        filenameText = "No file in cache";
                    }
                } else {
                    filenameText = "No file in cache";
                }
            }
            
            // Make sure warning icon is visible and status icon is hidden
            if (_warningIconButton != null) {
                _warningIconButton.visible = true;
            }
            if (_statusIconButton != null) {
                _statusIconButton.visible = false;
            } 
        } else {
            // Hide warning icon and show status icon
            if (_warningIconButton != null) {
                _warningIconButton.visible = false;
            }
            
            // Update status icon based on file existence
            if (_statusIconButton != null) {
                _statusIconButton.visible = true;
                if (cachedFile.exists) {
                    _statusIconButton.icon = GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_OK);
                } else {
                    _statusIconButton.icon = GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_WARNING);
                }
            }
            
            if (filenameText.length > 45) {
                // Truncate long filenames - showing more characters before ellipsis
                filenameText = filenameText.substr(0, 42) + "...";
            }
        }
        
        // Display filename (without the status indicators since we use icons now)
        _filenameLabel.text = filenameText;
        
        // Create tooltip with all details
        var hashInfo = Reflect.hasField(cachedFile, "sha256") && cachedFile.sha256 != null ? 
                       "SHA256: " + cachedFile.sha256 : 
                       "SHA256 not available";
        
        _filenameLabel.toolTip = "Filename: " + 
                                (fileMissing ? "No file in cache" : cachedFile.originalFilename) + 
                                "\n" + hashInfo +
                                (cachedFile.exists ? "" : "\nWarning: File is missing from cache");
                                
        Logger.verbose('FileEntryItem: Displaying file with original name "${cachedFile.originalFilename}" as "${filenameText}"');
        
        // Set role and type
        _roleLabel.text = cachedFile.role;
        _typeLabel.text = cachedFile.type;
        
        // Format version info
        var version = "";
        if (cachedFile.version != null && cachedFile.version.fullVersion != null) {
            version = cachedFile.version.fullVersion;
        } else if (cachedFile.version != null) {
            var parts = [];
            if (cachedFile.version.majorVersion != null) parts.push(cachedFile.version.majorVersion);
            if (cachedFile.version.minorVersion != null) parts.push(cachedFile.version.minorVersion);
            if (cachedFile.version.patchVersion != null) parts.push(cachedFile.version.patchVersion);
            
            if (parts.length > 0) {
                version = parts.join(".");
            }
        }
        _versionLabel.text = version;
    }
    
    /**
     * Store a reference to the HashManagerPage parent
     */
    public var parentPage:HashManagerPage;
    
    /**
     * Handle click events
     */
    private function _onClick(e:MouseEvent):Void {
        // Don't use event dispatch at all, directly call the parent method
        if (parentPage != null) {
            parentPage.selectItem(this);
        }
    }
    
    /**
     * Get or set the selected state
     */
    public var selected(get, set):Bool;
    
    private function get_selected():Bool {
        return _selected;
    }
    
    private function set_selected(value:Bool):Bool {
        // Only update if state is changing
        if (_selected != value) {
            _selected = value;
            
            // Update background fill - use the stored _isEven value to determine color
            if (_selected) {
                _background.fill = FillStyle.SolidColor(COLOR_SELECTED);
            } else {
                _background.fill = FillStyle.SolidColor(_isEven ? COLOR_EVEN : COLOR_ODD);
            }
        }
        
        return _selected;
    }
    
    /**
     * Handle status icon button click
     */
    private function _statusIconButtonTriggered(e:TriggerEvent):Void {
        // Prevent event propagation to avoid triggering row selection
        e.stopPropagation();
        
        // Only handle clicks for missing files
        if (cachedFile.exists) return;
        
        // Log critical point - this confirms the click handler is being executed
        Logger.error('CLICK DETECTED: Attempting to show download dialog for missing file: ${cachedFile.originalFilename}');
        
        try {
            // Get token information before showing dialog
            var hclDownloader = HCLDownloader.getInstance();
            if (hclDownloader == null) {
                Logger.error('HCLDownloader instance is null');
                return;
            }
            
            // Explicitly log token information
            var hclTokens = hclDownloader.getAvailableHCLTokens();
            var customResources = hclDownloader.getAvailableCustomResources();
            
            Logger.error('Available HCL tokens: ${hclTokens.length}, Custom resources: ${customResources.length}');
            
            if (hclTokens.length > 0) {
                Logger.error('First HCL token name: ${hclTokens[0].name}');
            }
            
            // Store the parent sprite to help with positioning
            var parentSprite = this.stage != null ? cast(this.stage.root, Sprite) : null;
            
            // Show download dialog with explicit error logging
            Logger.error('About to create DownloadDialog');
            var dialog = DownloadDialog.show(
                cachedFile,
                "Download Missing File",
                (state) -> {
                    Logger.error('Download dialog result: index=${state.index}');
                    
                    if (state.index == 1) { // Download button clicked
                        // Get token name and source type from dialog
                        var tokenName = ""; 
                        var isHCLSource = true;
                        
                        try {
                            if (Reflect.hasField(state, "userData")) {
                                var userData = Reflect.field(state, "userData");
                                Logger.error('UserData received: ${userData != null}');
                                
                                if (userData != null && Reflect.hasField(userData, "tokenName")) {
                                    tokenName = Std.string(Reflect.field(userData, "tokenName"));
                                    isHCLSource = Reflect.field(userData, "isHCLSource");
                                    Logger.error('Using token: ${tokenName}, HCL source: ${isHCLSource}');
                                } else {
                                    Logger.error('UserData missing tokenName field');
                                }
                            } else {
                                Logger.error('State object missing userData field');
                            }
                        } catch (e:Dynamic) {
                            Logger.error('Error extracting userData: ${e}');
                        }
                    
                    if (tokenName != null && tokenName.length > 0) {
                        // Get direct access to HCLDownloader
                        var downloader = superhuman.downloaders.HCLDownloader.getInstance();
                        
                        // Add event listeners for download
                        downloader.onDownloadStart.add(_onDownloadStart);
                        downloader.onDownloadProgress.add(_onDownloadProgress);
                        downloader.onDownloadComplete.add(_onDownloadComplete);
                        downloader.onDownloadError.add(_onDownloadError);
                        
                        // Start download with appropriate method
                        if (isHCLSource) {
                            downloader.downloadFileWithHCLToken(cachedFile, tokenName);
                        } else {
                            downloader.downloadFileWithCustomResource(cachedFile, tokenName);
                        }
                    }
                } else if (state.index == 2) { // Secrets button clicked
                    // Navigate to secrets page
                    parentPage.dispatchEvent(new SuperHumanApplicationEvent(SuperHumanApplicationEvent.OPEN_SECRETS_PAGE));
                }
            });
        } catch (e:Dynamic) {
            Logger.error('Error showing download dialog: ${e}');
        }
    }
    
    /**
     * Handle download start event
     */
    private function _onDownloadStart(downloader:superhuman.downloaders.HCLDownloader, file:SuperHumanCachedFile):Void {
        // Show progress or notification
        if (parentPage != null) {
            genesis.application.managers.ToastManager.getInstance().showToast('Downloading ${file.originalFilename}...');
        }
    }
    
    /**
     * Handle download progress event
     */
    private function _onDownloadProgress(downloader:superhuman.downloaders.HCLDownloader, file:SuperHumanCachedFile, progress:Float):Void {
        // Update progress if needed
    }
    
    /**
     * Handle download complete event
     */
    private function _onDownloadComplete(downloader:superhuman.downloaders.HCLDownloader, file:SuperHumanCachedFile, success:Bool):Void {
        // Clean up event listeners
        downloader.onDownloadStart.remove(_onDownloadStart);
        downloader.onDownloadProgress.remove(_onDownloadProgress);
        downloader.onDownloadComplete.remove(_onDownloadComplete);
        downloader.onDownloadError.remove(_onDownloadError);
        
        if (success) {
            if (parentPage != null) {
                genesis.application.managers.ToastManager.getInstance().showToast('Downloaded ${file.originalFilename} successfully');
                parentPage.loadCachedFiles(); // Refresh file list
            }
            
            // Update icon to show file exists
            if (_statusIconButton != null) {
                _statusIconButton.icon = genesis.application.theme.GenesisApplicationTheme.getCommonIcon(genesis.application.theme.GenesisApplicationTheme.ICON_OK);
            }
        }
    }
    
    /**
     * Handle download error event
     */
    private function _onDownloadError(downloader:superhuman.downloaders.HCLDownloader, file:SuperHumanCachedFile, error:String):Void {
        // Clean up event listeners
        downloader.onDownloadStart.remove(_onDownloadStart);
        downloader.onDownloadProgress.remove(_onDownloadProgress);
        downloader.onDownloadComplete.remove(_onDownloadComplete);
        downloader.onDownloadError.remove(_onDownloadError);
        
        if (parentPage != null) {
            genesis.application.managers.ToastManager.getInstance().showToast('Error downloading ${file.originalFilename}: ${error}');
        }
    }
    
    override function layoutGroup_removedFromStageHandler(event:Event) {
        // Clean up event listeners
        this.removeEventListener(MouseEvent.CLICK, _onClick);
        super.layoutGroup_removedFromStageHandler(event);
    }
    
    /**
     * Show download dialog for a cached file
     * @param file The file to download
     */
    private function _showDownloadDialog(file:SuperHumanCachedFile):Void {
        if (file == null) {
            Logger.error('Cannot show download dialog for null file');
            return;
        }
        
        try {
            // Get token information before showing dialog
            var hclDownloader = HCLDownloader.getInstance();
            if (hclDownloader == null) {
                Logger.error('HCLDownloader instance is null');
                return;
            }
            
            // Explicitly log token information
            var hclTokens = hclDownloader.getAvailableHCLTokens();
            var customResources = hclDownloader.getAvailableCustomResources();
            
            if (hclTokens == null) {
                hclTokens = [];
                Logger.error('HCL tokens array is null, using empty array');
            }
            
            if (customResources == null) {
                customResources = [];
                Logger.error('Custom resources array is null, using empty array');
            }
            
            Logger.error('Available HCL tokens: ${hclTokens.length}, Custom resources: ${customResources.length}');
            
            if (hclTokens.length > 0) {
                Logger.error('First HCL token name: ${hclTokens[0].name}');
            }
            
            // Store the parent sprite to help with positioning
            var parentSprite = this.stage != null ? cast(this.stage.root, Sprite) : null;
            
            // Show download dialog with explicit error logging
            Logger.error('Creating DownloadDialog for ${file.originalFilename}');
            var dialog = DownloadDialog.show(
                file,
                "Download Missing File",
                (state) -> {
                    if (state == null) {
                        Logger.error('Dialog callback received null state');
                        return;
                    }
                    
                    Logger.error('Download dialog result: index=${state.index}');
                    
                    if (state.index == 1) { // Download button clicked
                        // Get token name and source type from dialog
                        var tokenName = ""; 
                        var isHCLSource = true;
                        
                        try {
                            if (Reflect.hasField(state, "userData")) {
                                var userData = Reflect.field(state, "userData");
                                Logger.error('UserData received: ${userData != null}');
                                
                                if (userData != null && Reflect.hasField(userData, "tokenName")) {
                                    tokenName = Std.string(Reflect.field(userData, "tokenName"));
                                    isHCLSource = Reflect.field(userData, "isHCLSource");
                                    Logger.error('Using token: ${tokenName}, HCL source: ${isHCLSource}');
                                } else {
                                    Logger.error('UserData missing tokenName field');
                                }
                            } else {
                                Logger.error('State object missing userData field');
                            }
                        } catch (e:Dynamic) {
                            Logger.error('Error extracting userData: ${e}');
                        }
                        
                        if (tokenName != null && tokenName.length > 0) {
                            // Get direct access to HCLDownloader
                            var downloader = superhuman.downloaders.HCLDownloader.getInstance();
                            
                            // Add event listeners for download
                            downloader.onDownloadStart.add(_onDownloadStart);
                            downloader.onDownloadProgress.add(_onDownloadProgress);
                            downloader.onDownloadComplete.add(_onDownloadComplete);
                            downloader.onDownloadError.add(_onDownloadError);
                            
                            // Start download with appropriate method
                            if (isHCLSource) {
                                Logger.error('Starting HCL download with token: ${tokenName}');
                                downloader.downloadFileWithHCLToken(file, tokenName);
                            } else {
                                Logger.error('Starting custom download with resource: ${tokenName}');
                                downloader.downloadFileWithCustomResource(file, tokenName);
                            }
                        }
                    } else if (state.index == 2) { // Secrets button clicked
                        // Navigate to secrets page
                        if (parentPage != null) {
                            parentPage.dispatchEvent(new SuperHumanApplicationEvent(SuperHumanApplicationEvent.OPEN_SECRETS_PAGE));
                        } else {
                            Logger.error('Cannot navigate to secrets page: parentPage is null');
                        }
                    }
                },
                parentSprite
            );
        } catch (e:Dynamic) {
            Logger.error('Error showing download dialog: ${e}');
        }
    }
}
