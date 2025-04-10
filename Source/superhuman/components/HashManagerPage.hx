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
import superhuman.events.SuperHumanApplicationEvent;
import superhuman.server.cache.SuperHumanCachedFile;
import superhuman.server.cache.SuperHumanFileCache;
import superhuman.theme.SuperHumanInstallerTheme;
import sys.FileSystem;

/**
 * Page for managing the file hash cache
 */
class HashManagerPage extends Page {
    // Constants
    final _width:Float = GenesisApplicationTheme.GRID * 140; // Increased width like SecretsPage
    
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
    
    public function new() {
        super();
    }
    
    override function initialize() {
        super.initialize();
        
        _content.width = _width;
        _content.maxWidth = GenesisApplicationTheme.GRID * 150;
        
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
        
        // Add header row with proper styling matching the FileEntryItem structure
        var headerContainer = new LayoutGroup();
        var headerBackground = new RectangleSkin();
        headerBackground.fill = FillStyle.SolidColor(0x444444);
        headerContainer.backgroundSkin = headerBackground;
        headerContainer.height = GenesisApplicationTheme.GRID * 6; // Increased height for header row
        headerContainer.layoutData = new VerticalLayoutData(100);
        
        // Create header layout matching the item layout
        var headerColumnsLayout = new HorizontalLayout();
        headerColumnsLayout.paddingLeft = GenesisApplicationTheme.GRID * 2;
        headerColumnsLayout.paddingRight = GenesisApplicationTheme.GRID * 2;
        headerColumnsLayout.gap = GenesisApplicationTheme.GRID * 2;
        headerColumnsLayout.verticalAlign = VerticalAlign.MIDDLE;
        headerContainer.layout = headerColumnsLayout;
        
    // Create filename column group
    var filenameHeaderGroup = new LayoutGroup();
    filenameHeaderGroup.width = FileEntryItem.FILENAME_WIDTH;
    var filenameHeaderLayout = new HorizontalLayout();
    filenameHeaderLayout.paddingRight = GenesisApplicationTheme.GRID;
    filenameHeaderLayout.verticalAlign = VerticalAlign.MIDDLE;
    filenameHeaderGroup.layout = filenameHeaderLayout;
    headerContainer.addChild(filenameHeaderGroup);
    
    // Add filename header label
    var filenameHeader = new Label();
    filenameHeader.text = "FILENAME";
    filenameHeader.variant = GenesisApplicationTheme.LABEL_LARGE;
    filenameHeaderGroup.addChild(filenameHeader);
    
    // Create hash column group
    var hashHeaderGroup = new LayoutGroup();
    hashHeaderGroup.width = FileEntryItem.HASH_WIDTH;
    var hashHeaderLayout = new HorizontalLayout();
    hashHeaderLayout.paddingRight = GenesisApplicationTheme.GRID;
    hashHeaderLayout.verticalAlign = VerticalAlign.MIDDLE;
    hashHeaderGroup.layout = hashHeaderLayout;
    headerContainer.addChild(hashHeaderGroup);
    
    // Add hash header label
    var hashHeader = new Label();
    hashHeader.text = "HASH";
    hashHeader.variant = GenesisApplicationTheme.LABEL_LARGE;
    hashHeaderGroup.addChild(hashHeader);
        
        // Create role column group
        var roleHeaderGroup = new LayoutGroup();
        roleHeaderGroup.width = FileEntryItem.ROLE_WIDTH;
        var roleHeaderLayout = new HorizontalLayout();
        roleHeaderLayout.paddingRight = GenesisApplicationTheme.GRID;
        roleHeaderLayout.verticalAlign = VerticalAlign.MIDDLE;
        roleHeaderGroup.layout = roleHeaderLayout;
        headerContainer.addChild(roleHeaderGroup);
        
        // Add role header label
        var roleHeader = new Label();
        roleHeader.text = "ROLE";
        roleHeader.variant = GenesisApplicationTheme.LABEL_LARGE;
        roleHeaderGroup.addChild(roleHeader);
        
        // Create type column group
        var typeHeaderGroup = new LayoutGroup();
        typeHeaderGroup.width = FileEntryItem.TYPE_WIDTH;
        var typeHeaderLayout = new HorizontalLayout();
        typeHeaderLayout.paddingRight = GenesisApplicationTheme.GRID;
        typeHeaderLayout.verticalAlign = VerticalAlign.MIDDLE;
        typeHeaderGroup.layout = typeHeaderLayout;
        headerContainer.addChild(typeHeaderGroup);
        
        // Add type header label
        var typeHeader = new Label();
        typeHeader.text = "TYPE";
        typeHeader.variant = GenesisApplicationTheme.LABEL_LARGE;
        typeHeaderGroup.addChild(typeHeader);
        
        // Create version column group
        var versionHeaderGroup = new LayoutGroup();
        versionHeaderGroup.width = FileEntryItem.VERSION_WIDTH;
        var versionHeaderLayout = new HorizontalLayout();
        versionHeaderLayout.verticalAlign = VerticalAlign.MIDDLE;
        versionHeaderGroup.layout = versionHeaderLayout;
        headerContainer.addChild(versionHeaderGroup);
        
        // Add version header label
        var versionHeader = new Label();
        versionHeader.text = "VERSION";
        versionHeader.variant = GenesisApplicationTheme.LABEL_LARGE;
        versionHeaderGroup.addChild(versionHeader);
        
        _listGroup.addChild(headerContainer);
        
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
            "domino", "appdevpack", "leap", "nomadweb", "traveler", "verse", "domino-rest-api"
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
     * Load cached files from the registry
     */
    public function loadCachedFiles():Void {
        // Remove existing file items from the list group
        while (_listGroup.numChildren > 1) {
            _listGroup.removeChildAt(_listGroup.numChildren - 1);
        }
        
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
        
        // Show the file path when editing
        if (_filePathLabel != null && _filePathContainer != null) {
            // Set path text and make container visible
            _filePathLabel.text = _editingFile.path;
            _filePathContainer.visible = _filePathContainer.includeInLayout = true;
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
    public static final FILENAME_WIDTH:Float = GenesisApplicationTheme.GRID * 40; // Reduced width for filename
    public static final HASH_WIDTH:Float = GenesisApplicationTheme.GRID * 30; // Added width for hash
    public static final ROLE_WIDTH:Float = GenesisApplicationTheme.GRID * 15;
    public static final TYPE_WIDTH:Float = GenesisApplicationTheme.GRID * 15;
    public static final VERSION_WIDTH:Float = GenesisApplicationTheme.GRID * 20;
    
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
        hashLabel.text = cachedFile.hash.substr(0, 15) + "..."; // Show abbreviated hash
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
    
    /**
     * Update labels with file data
     */
    private function updateLabels():Void {
        // Create status indicator text
        var statusText = cachedFile.exists ? " ✓" : " ⚠";
        var statusColor = cachedFile.exists ? 0x44aa44 : 0xaa4444;
        
        // Format filename
        var filenameText = cachedFile.originalFilename;
        
        // Check if the filename appears to be a placeholder (unknown.unknown)
        if (filenameText == "unknown.unknown" || filenameText.indexOf("unknown.unknown") >= 0) {
            filenameText = "No file in cache";
        } else if (filenameText.length > 30) {
            // Truncate long filenames
            filenameText = filenameText.substr(0, 27) + "...";
        }
        
        // Display filename with status indicator
        _filenameLabel.text = filenameText + statusText;
        
        // Create tooltip with all details
        _filenameLabel.toolTip = "Filename: " + 
                                (cachedFile.originalFilename == "unknown.unknown" || 
                                 cachedFile.originalFilename.indexOf("unknown.unknown") >= 0 ? 
                                 "No file in cache" : cachedFile.originalFilename) + 
                                "\nHash: " + cachedFile.hash +
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
    
    override function layoutGroup_removedFromStageHandler(event:Event) {
        // Clean up event listeners
        this.removeEventListener(MouseEvent.CLICK, _onClick);
        super.layoutGroup_removedFromStageHandler(event);
    }
}
