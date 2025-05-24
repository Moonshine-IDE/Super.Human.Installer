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
import feathers.controls.Button;
import genesis.application.components.GenesisFormPupUpListView;
import feathers.controls.Check;
import feathers.controls.Label;
import feathers.controls.LayoutGroup;
import feathers.controls.TabBar;
import feathers.data.ArrayCollection;
import StringTools;
import feathers.events.TriggerEvent;
import feathers.layout.HorizontalAlign;
import feathers.layout.HorizontalLayout;
import feathers.layout.HorizontalLayoutData;
import feathers.layout.VerticalAlign;
import feathers.layout.VerticalLayout;
import feathers.layout.VerticalLayoutData;
import genesis.application.components.GenesisForm;
import genesis.application.components.GenesisFormButton;
import genesis.application.components.GenesisFormRow;
import genesis.application.components.GenesisFormTextInput;
import genesis.application.components.HLine;
import genesis.application.components.Page;
import genesis.application.managers.LanguageManager;
import genesis.application.managers.ToastManager;
import genesis.application.theme.GenesisApplicationTheme;
import lime.ui.FileDialog;
import lime.ui.FileDialogType;
import superhuman.events.SuperHumanApplicationEvent;
import superhuman.managers.ProvisionerManager;
import feathers.controls.ToggleButton;
import feathers.utils.DisplayObjectRecycler;
import openfl.events.Event;
import feathers.skins.RectangleSkin;
import openfl.text.TextFormat;
import prominic.sys.io.AbstractExecutor; // Added for async import
import genesis.application.components.ProgressIndicator; // Added for spinner

/**
 * A page that provides the user with different methods to import provisioners
 */
class ProvisionerImportPage extends Page {

    // Constants
    final _width:Float = GenesisApplicationTheme.GRID * 140;
    
    // Tab indices
    static final TAB_COLLECTION:Int = 0;
    static final TAB_VERSION:Int = 1;
    static final TAB_GITHUB:Int = 2;

    // UI Components
    var _titleGroup:LayoutGroup;
    var _label:Label;
    var _tabBar:TabBar;
    var _formContainer:LayoutGroup;
    
    // Collection import components
    var _collectionForm:GenesisForm;
    var _collectionPathInput:GenesisFormTextInput;
    var _buttonBrowseCollection:Button;
    
    // Version import components
    var _versionForm:GenesisForm;
    var _versionPathInput:GenesisFormTextInput;
    var _buttonBrowseVersion:Button;
    
    // GitHub import components
    var _githubForm:GenesisForm;
    var _githubOrgInput:GenesisFormTextInput;
    var _githubRepoInput:GenesisFormTextInput;
    var _githubBranchInput:GenesisFormTextInput;
    var _githubTokenDropdown:GenesisFormPupUpListView;
    var _githubUseGit:Check;
    
    // Common components
    var _buttonGroup:LayoutGroup;
    var _buttonImport:GenesisFormButton;
    var _buttonCancel:GenesisFormButton;
    
    // Data
    var _activeTabIndex:Int = 0;
    var _gitTokens:Array<{name:String, key:String}> = [];
    var _selectedTokenName:String = "";
    
    // File dialog reference
    var _fd:FileDialog;
    
    // State for async import
    var _isImporting:Bool = false;
    var _spinner:ProgressIndicator; // Added spinner instance

    public function new() {
        super();
    }

    
    /**
     * Handle application configuration saved event
     */
    private function _onAppConfigurationSaved(event:SuperHumanApplicationEvent):Void {
        // Reload Git tokens when configuration is saved
        _loadGitTokens();
    }

    /**
     * Initialize the title bar
     */
    private function _initializeTitleBar() {
        // Title group
        _titleGroup = new LayoutGroup();
        var _titleGroupLayout = new HorizontalLayout();
        _titleGroupLayout.horizontalAlign = HorizontalAlign.LEFT;
        _titleGroupLayout.verticalAlign = VerticalAlign.MIDDLE;
        _titleGroup.layout = _titleGroupLayout;
        _titleGroup.width = _width;
        this.addChild(_titleGroup);

        // Title label
        _label = new Label();
        _label.text = LanguageManager.getInstance().getString("provisionerimportpage.title");
        _label.variant = GenesisApplicationTheme.LABEL_LARGE;
        _label.layoutData = new HorizontalLayoutData(100);
        _titleGroup.addChild(_label);

        // Separator line
        var line = new HLine();
        line.width = _width;
        this.addChild(line);
    }

    /**
     * Initialize the tab bar
     */
    private function _initializeTabBar() {
        _tabBar = new TabBar();
        _tabBar.dataProvider = new ArrayCollection([
            { text: LanguageManager.getInstance().getString("provisionerimportpage.tabs.collection"), icon: null },
            { text: LanguageManager.getInstance().getString("provisionerimportpage.tabs.version"), icon: null },
            { text: LanguageManager.getInstance().getString("provisionerimportpage.tabs.github"), icon: null }
        ]);
        
        // Set the itemToText function to properly display tab text
        _tabBar.itemToText = function(item:Dynamic):String {
            return item.text;
        };
        
        // Set background to transparent
        var backgroundSkin = new RectangleSkin(FillStyle.SolidColor(0x0, 0)); // Transparent
        _tabBar.backgroundSkin = backgroundSkin;
        
        // Add tab styling with DisplayObjectRecycler to match dark theme
        _tabBar.tabRecycler = DisplayObjectRecycler.withFunction(() -> {
            var tab = new ToggleButton();
            
            // Apply dark theme styling with transparent default
            var defaultSkin = new RectangleSkin(FillStyle.SolidColor(0x333333, 0.0));
            defaultSkin.cornerRadius = GenesisApplicationTheme.GRID;
            defaultSkin.border = LineStyle.SolidColor(1, 0x444444, 0.5);
            tab.backgroundSkin = defaultSkin;
            
            // Selected state skin (blue highlight)
            var selectedSkin = new RectangleSkin(FillStyle.SolidColor(0x2A5885));
            selectedSkin.cornerRadius = GenesisApplicationTheme.GRID;
            tab.selectedBackgroundSkin = selectedSkin;
            
            // Text format - white text
            tab.textFormat = new TextFormat("_sans", 14, 0xFFFFFF);
            
            // Padding
            tab.paddingTop = GenesisApplicationTheme.GRID;
            tab.paddingBottom = GenesisApplicationTheme.GRID;
            tab.paddingLeft = GenesisApplicationTheme.GRID * 2;
            tab.paddingRight = GenesisApplicationTheme.GRID * 2;
            
            return tab;
        });
        
        _tabBar.width = _width;
        _tabBar.addEventListener(Event.CHANGE, _tabBarChanged);
        _tabBar.addEventListener(TriggerEvent.TRIGGER, _tabBarTriggered);
        this.addChild(_tabBar);
    }
    
    /**
     * Handle tab bar selection changes (using Event.CHANGE)
     */
    private function _tabBarChanged(event:Event) {
        var tabBar = cast(event.target, TabBar);
        var selectedIndex = tabBar.selectedIndex;
        
        _switchTab(selectedIndex);
    }

    /**
     * Initialize the form container
     */
    private function _initializeFormContainer() {
        _formContainer = new LayoutGroup();
        
        // Create a background skin to match dark theme
        var bgSkin = new RectangleSkin(FillStyle.SolidColor(0x222222));
        bgSkin.cornerRadius = GenesisApplicationTheme.GRID;
        _formContainer.backgroundSkin = bgSkin;
        
        // Use vertical layout
        var formLayout = new VerticalLayout();
        formLayout.horizontalAlign = HorizontalAlign.CENTER;
        formLayout.gap = GenesisApplicationTheme.GRID * 2;
        formLayout.paddingTop = GenesisApplicationTheme.GRID * 3;
        formLayout.paddingBottom = GenesisApplicationTheme.GRID * 3;
        formLayout.paddingLeft = GenesisApplicationTheme.GRID; // Reduced padding
        formLayout.paddingRight = GenesisApplicationTheme.GRID; // Reduced padding
        _formContainer.layout = formLayout;
        
        // Set width to 98% of the content width and center it
        _formContainer.width = _width * 0.98;
        
        this.addChild(_formContainer);
    }

    /**
     * Initialize the collection import form
     */
    private function _initializeCollectionForm() {
        _collectionForm = new GenesisForm();
        _collectionForm.visible = false;
        _collectionForm.includeInLayout = false;
        
        // Form styling is handled by the GenesisForm component
        
        // Description - create a special full-width row at the top for the description
        var descContainer = new LayoutGroup();
        descContainer.width = _width * 0.75; // Reduced width to ensure text doesn't overflow
        
        var descLayout = new VerticalLayout();
        descLayout.horizontalAlign = HorizontalAlign.LEFT; // Align text to left
        descLayout.paddingTop = GenesisApplicationTheme.GRID;
        descLayout.paddingBottom = GenesisApplicationTheme.GRID;
        descLayout.paddingLeft = GenesisApplicationTheme.GRID;
        descLayout.paddingRight = GenesisApplicationTheme.GRID;
        descContainer.layout = descLayout;
        
        var descLabel = new Label();
        descLabel.text = LanguageManager.getInstance().getString("provisionerimportpage.collection.description");
        descLabel.wordWrap = true;
        descLabel.textFormat = new TextFormat("_sans", 14, 0xFFFFFF);
        descLabel.width = _width * 0.70; // Explicitly set width to constrain text
        descContainer.addChild(descLabel);
        
        // Add the description container to the form before any form rows
        _collectionForm.addChild(descContainer);
        
        // Path row
        var pathRow = new GenesisFormRow();
        pathRow.text = LanguageManager.getInstance().getString("provisionerimportpage.collection.path");
        
        // Adjust column widths for label/content ratio (20%/80%)
        var label = cast(pathRow.getChildAt(0), feathers.core.FeathersControl);
        var content = cast(pathRow.getChildAt(1), feathers.core.FeathersControl);
        if (label != null) label.layoutData = new HorizontalLayoutData(20); // Reduce from default ~40% to 20%
        if (content != null) content.layoutData = new HorizontalLayoutData(80); // Increase from default ~60% to 80%
        
        var pathContainer = new LayoutGroup();
        var pathLayout = new HorizontalLayout();
        pathLayout.gap = GenesisApplicationTheme.GRID;
        pathLayout.verticalAlign = VerticalAlign.MIDDLE;
        pathContainer.layout = pathLayout;
        
        _collectionPathInput = new GenesisFormTextInput("", LanguageManager.getInstance().getString("provisionerimportpage.collection.placeholder"));
        _collectionPathInput.width = (_width * 0.8) - 150 - GenesisApplicationTheme.GRID * 17; // Reduced to give more space to browse button
        _collectionPathInput.enabled = false;
        
        _buttonBrowseCollection = new Button();
        _buttonBrowseCollection.text = LanguageManager.getInstance().getString("provisionerimportpage.buttons.browse");
        _buttonBrowseCollection.width = GenesisApplicationTheme.GRID * 15; // Increased width
        _buttonBrowseCollection.addEventListener(TriggerEvent.TRIGGER, _browseCollectionButtonTriggered);
        
        pathContainer.addChild(_collectionPathInput);
        pathContainer.addChild(_buttonBrowseCollection);
        
        pathRow.content.addChild(pathContainer);
        _collectionForm.addChild(pathRow);
        
        _formContainer.addChild(_collectionForm);
    }

    /**
     * Initialize the version import form
     */
    private function _initializeVersionForm() {
        _versionForm = new GenesisForm();
        _versionForm.visible = false;
        _versionForm.includeInLayout = false;
        
        // Form styling is handled by the GenesisForm component
        
        // Description - create a special full-width row at the top for the description
        var descContainer = new LayoutGroup();
        descContainer.width = _width * 0.75; // Reduced width to ensure text doesn't overflow
        
        var descLayout = new VerticalLayout();
        descLayout.horizontalAlign = HorizontalAlign.LEFT; // Align text to left
        descLayout.paddingTop = GenesisApplicationTheme.GRID;
        descLayout.paddingBottom = GenesisApplicationTheme.GRID;
        descLayout.paddingLeft = GenesisApplicationTheme.GRID;
        descLayout.paddingRight = GenesisApplicationTheme.GRID;
        descContainer.layout = descLayout;
        
        var descLabel = new Label();
        descLabel.text = LanguageManager.getInstance().getString("provisionerimportpage.version.description");
        descLabel.wordWrap = true;
        descLabel.textFormat = new TextFormat("_sans", 14, 0xFFFFFF);
        descLabel.width = _width * 0.70; // Explicitly set width to constrain text
        descContainer.addChild(descLabel);
        
        // Add the description container to the form before any form rows
        _versionForm.addChild(descContainer);
        
        // Path row
        var pathRow = new GenesisFormRow();
        pathRow.text = LanguageManager.getInstance().getString("provisionerimportpage.version.path");
        
        // Adjust column widths for label/content ratio (20%/80%)
        var label = cast(pathRow.getChildAt(0), feathers.core.FeathersControl);
        var content = cast(pathRow.getChildAt(1), feathers.core.FeathersControl);
        if (label != null) label.layoutData = new HorizontalLayoutData(20); // Reduce from default ~40% to 20%
        if (content != null) content.layoutData = new HorizontalLayoutData(80); // Increase from default ~60% to 80%
        
        var pathContainer = new LayoutGroup();
        var pathLayout = new HorizontalLayout();
        pathLayout.gap = GenesisApplicationTheme.GRID;
        pathLayout.verticalAlign = VerticalAlign.MIDDLE;
        pathContainer.layout = pathLayout;
        
        _versionPathInput = new GenesisFormTextInput("", LanguageManager.getInstance().getString("provisionerimportpage.version.placeholder"));
        _versionPathInput.width = (_width * 0.8) - 150 - GenesisApplicationTheme.GRID * 17; // Reduced to give more space to browse button
        _versionPathInput.enabled = false;
        
        _buttonBrowseVersion = new Button();
        _buttonBrowseVersion.text = LanguageManager.getInstance().getString("provisionerimportpage.buttons.browse");
        _buttonBrowseVersion.width = GenesisApplicationTheme.GRID * 15; // Increased width
        _buttonBrowseVersion.addEventListener(TriggerEvent.TRIGGER, _browseVersionButtonTriggered);
        
        pathContainer.addChild(_versionPathInput);
        pathContainer.addChild(_buttonBrowseVersion);
        
        pathRow.content.addChild(pathContainer);
        _versionForm.addChild(pathRow);
        
        _formContainer.addChild(_versionForm);
    }

    /**
     * Initialize the GitHub import form
     */
    private function _initializeGitHubForm() {
        _githubForm = new GenesisForm();
        _githubForm.visible = false;
        _githubForm.includeInLayout = false;
        
        // Form styling is handled by the GenesisForm component
        
        // Description - create a special full-width row at the top for the description
        var descContainer = new LayoutGroup();
        descContainer.width = _width * 0.75; // Reduced width to ensure text doesn't overflow
        
        var descLayout = new VerticalLayout();
        descLayout.horizontalAlign = HorizontalAlign.LEFT; // Align text to left
        descLayout.paddingTop = GenesisApplicationTheme.GRID;
        descLayout.paddingBottom = GenesisApplicationTheme.GRID;
        descLayout.paddingLeft = GenesisApplicationTheme.GRID;
        descLayout.paddingRight = GenesisApplicationTheme.GRID;
        descContainer.layout = descLayout;
        
        var descLabel = new Label();
        descLabel.text = LanguageManager.getInstance().getString("provisionerimportpage.github.description");
        descLabel.wordWrap = true;
        descLabel.textFormat = new TextFormat("_sans", 14, 0xFFFFFF);
        descLabel.width = _width * 0.70; // Explicitly set width to constrain text
        descContainer.addChild(descLabel);
        
        // Add the description container to the form before any form rows
        _githubForm.addChild(descContainer);
        
        // GitHub organization/user
        var orgRow = new GenesisFormRow();
        orgRow.text = LanguageManager.getInstance().getString("provisionerimportpage.github.organization");
        
        // Adjust column widths for label/content ratio (20%/80%)
        var orgLabel = cast(orgRow.getChildAt(0), feathers.core.FeathersControl);
        var orgContent = cast(orgRow.getChildAt(1), feathers.core.FeathersControl);
        if (orgLabel != null) orgLabel.layoutData = new HorizontalLayoutData(20);
        if (orgContent != null) orgContent.layoutData = new HorizontalLayoutData(80);
        
        _githubOrgInput = new GenesisFormTextInput("", LanguageManager.getInstance().getString("provisionerimportpage.github.organizationPlaceholder"));
        // Set width to match the other input fields
        _githubOrgInput.width = (_width * 0.8) - 150;
        orgRow.content.addChild(_githubOrgInput);
        _githubForm.addChild(orgRow);
        
        // GitHub repository
        var repoRow = new GenesisFormRow();
        repoRow.text = LanguageManager.getInstance().getString("provisionerimportpage.github.repository");
        
        // Adjust column widths for label/content ratio (20%/80%)
        var repoLabel = cast(repoRow.getChildAt(0), feathers.core.FeathersControl);
        var repoContent = cast(repoRow.getChildAt(1), feathers.core.FeathersControl);
        if (repoLabel != null) repoLabel.layoutData = new HorizontalLayoutData(20);
        if (repoContent != null) repoContent.layoutData = new HorizontalLayoutData(80);
        
        _githubRepoInput = new GenesisFormTextInput("", LanguageManager.getInstance().getString("provisionerimportpage.github.repositoryPlaceholder"));
        _githubRepoInput.width = (_width * 0.8) - 150;
        repoRow.content.addChild(_githubRepoInput);
        _githubForm.addChild(repoRow);
        
        // GitHub branch
        var branchRow = new GenesisFormRow();
        branchRow.text = LanguageManager.getInstance().getString("provisionerimportpage.github.branch");
        
        // Adjust column widths for label/content ratio (20%/80%)
        var branchLabel = cast(branchRow.getChildAt(0), feathers.core.FeathersControl);
        var branchContent = cast(branchRow.getChildAt(1), feathers.core.FeathersControl);
        if (branchLabel != null) branchLabel.layoutData = new HorizontalLayoutData(20);
        if (branchContent != null) branchContent.layoutData = new HorizontalLayoutData(80);
        
        _githubBranchInput = new GenesisFormTextInput("main", LanguageManager.getInstance().getString("provisionerimportpage.github.branchPlaceholder"));
        _githubBranchInput.width = (_width * 0.8) - 150;
        branchRow.content.addChild(_githubBranchInput);
        _githubForm.addChild(branchRow);
        
        // GitHub token selection
        var tokenRow = new GenesisFormRow();
        tokenRow.text = LanguageManager.getInstance().getString("provisionerimportpage.github.token");
        
        // Adjust column widths for label/content ratio (20%/80%)
        var tokenLabel = cast(tokenRow.getChildAt(0), feathers.core.FeathersControl);
        var tokenContent = cast(tokenRow.getChildAt(1), feathers.core.FeathersControl);
        if (tokenLabel != null) tokenLabel.layoutData = new HorizontalLayoutData(20);
        if (tokenContent != null) tokenContent.layoutData = new HorizontalLayoutData(80);
        
        // Create a proper dropdown for token selection
        var tokenOptions = new ArrayCollection([{text: "None (Public Repository)", value: ""}]);
        _githubTokenDropdown = new GenesisFormPupUpListView(tokenOptions);
        
        // Set up how to display each item
        _githubTokenDropdown.itemToText = function(item:Dynamic):String {
            return item.text;
        };
        
        // Set width to match other fields
        _githubTokenDropdown.width = (_width * 0.8) - 150;
        
        // Listen for selection changes
        _githubTokenDropdown.addEventListener(Event.CHANGE, _tokenDropdownChanged);
        tokenRow.content.addChild(_githubTokenDropdown);
        _githubForm.addChild(tokenRow);
        
        // Download method toggle (similar to FileSyncSetting)
        var gitRow = new GenesisFormRow();
        gitRow.text = LanguageManager.getInstance().getString("provisionerimportpage.github.downloadmethod");
        
        // Adjust column widths for label/content ratio (20%/80%)
        var gitLabel = cast(gitRow.getChildAt(0), feathers.core.FeathersControl);
        var gitContent = cast(gitRow.getChildAt(1), feathers.core.FeathersControl);
        if (gitLabel != null) gitLabel.layoutData = new HorizontalLayoutData(20);
        if (gitContent != null) gitContent.layoutData = new HorizontalLayoutData(80);
        
        // Create a container for the toggle and labels
        var toggleContainer = new LayoutGroup();
        var toggleLayout = new HorizontalLayout();
        toggleLayout.gap = GenesisApplicationTheme.GRID * 2;
        toggleLayout.verticalAlign = VerticalAlign.MIDDLE;
        toggleContainer.layout = toggleLayout;
        
        // HTTP label (left side)
        var httpLabel = new Label();
        httpLabel.text = LanguageManager.getInstance().getString("provisionerimportpage.github.http");
        httpLabel.variant = GenesisApplicationTheme.LABEL_DEFAULT;
        
        // Create a styled toggle checkbox resembling the FileSyncSetting
        _githubUseGit = new genesis.application.components.GenesisFormCheckBox("", false);
        
        // Git label (right side)
        var gitLabel = new Label();
        gitLabel.text = LanguageManager.getInstance().getString("provisionerimportpage.github.gitclone");
        gitLabel.variant = GenesisApplicationTheme.LABEL_DEFAULT;
        
        // Add components to toggle container
        toggleContainer.addChild(httpLabel);
        toggleContainer.addChild(_githubUseGit);
        toggleContainer.addChild(gitLabel);
        
        // Add container to the row
        gitRow.content.addChild(toggleContainer);
        _githubForm.addChild(gitRow);
        
        _formContainer.addChild(_githubForm);
    }

    /**
     * Set up UI components and event listeners
     */
    override function initialize() {
        super.initialize();
        
        // Set content width and max width
        _content.width = _width;
        _content.maxWidth = GenesisApplicationTheme.GRID * 150;

        // Add event listener for when the page is added to the stage
        this.addEventListener(Event.ADDED_TO_STAGE, _onAddedToStage);
        
        _initializeTitleBar();
        _initializeTabBar();
        _initializeFormContainer();
        _initializeCollectionForm();
        _initializeVersionForm();
        _initializeGitHubForm();
        
        // Initialize the button group
        // Line separator
        var line = new HLine();
        line.width = _width;
        this.addChild(line);
        
        // Button group
        _buttonGroup = new LayoutGroup();
        var buttonLayout = new HorizontalLayout();
        buttonLayout.gap = GenesisApplicationTheme.GRID * 2;
        buttonLayout.horizontalAlign = HorizontalAlign.CENTER;
        _buttonGroup.layout = buttonLayout;
        
        // Import button
        _buttonImport = new GenesisFormButton(LanguageManager.getInstance().getString("provisionerimportpage.buttons.import"));
        _buttonImport.addEventListener(TriggerEvent.TRIGGER, _importButtonTriggered);
        _buttonImport.width = GenesisApplicationTheme.GRID * 20;
        
        // Cancel button
        _buttonCancel = new GenesisFormButton(LanguageManager.getInstance().getString("provisionerimportpage.buttons.cancel"));
        _buttonCancel.addEventListener(TriggerEvent.TRIGGER, _cancelButtonTriggered);
        _buttonCancel.width = GenesisApplicationTheme.GRID * 20;
        
        _buttonGroup.addChild(_buttonImport);
        _buttonGroup.addChild(_buttonCancel);
        this.addChild(_buttonGroup);

        // Initialize spinner (hidden initially)
        _spinner = new ProgressIndicator(24, 16, 0xCCCCCC);
        _spinner.visible = false;
        _spinner.includeInLayout = false;
        // Add layout data to center it if the page layout supports it (assuming VerticalLayout)
        // Note: horizontalAlign is set on the VerticalLayout itself, not the layout data.
        // We assume the page's main VerticalLayout already has horizontalAlign set to CENTER.
        var spinnerLayoutData = new VerticalLayoutData(); 
        _spinner.layoutData = spinnerLayoutData; 
        this.addChild(_spinner); // Add spinner after the button group
        
        // Load Git tokens from secrets
        _loadGitTokens();
        
        // Set initial active tab
        _switchTab(TAB_COLLECTION);
        
        // Listen for configuration change events
        this.addEventListener(SuperHumanApplicationEvent.SAVE_APP_CONFIGURATION, _onAppConfigurationSaved);
    }

    /**
     * Load GitHub tokens from secrets
     * This is called whenever tokens might have changed
     */
    private function _loadGitTokens() {
        // Force a fresh retrieval of the config to ensure we have the latest tokens
        var secrets = SuperHumanInstaller.getInstance().config.secrets;
        
        // Reset tokens array
        _gitTokens = [];
        
        if (secrets != null && secrets.git_api_keys != null && secrets.git_api_keys.length > 0) {
            _gitTokens = secrets.git_api_keys.map(t -> ({name: t.name, key: t.key}));
            
            // Create token dropdown options
            var tokenOptions = [{text: "None (Public Repository)", value: ""}];
            
            for (token in _gitTokens) {
                tokenOptions.push({text: token.name, value: token.name});
            }
            
            // Update dropdown with fresh data
            _githubTokenDropdown.dataProvider = new ArrayCollection(tokenOptions);
        } else {
            // Reset to just the "None" option if no tokens are found
            _githubTokenDropdown.dataProvider = new ArrayCollection([{text: "None (Public Repository)", value: ""}]);
        }
        
        // Reset selection to first item
        if (_githubTokenDropdown.dataProvider.length > 0) {
            _githubTokenDropdown.selectedIndex = 0;
            _selectedTokenName = "";
        }
    }

    /**
     * Handle tab bar selection changes
     */
    private function _tabBarTriggered(event:TriggerEvent) {
        var selectedIndex = _tabBar.selectedIndex;
        _switchTab(selectedIndex);
    }

    /**
     * Switch to a specific tab
     */
    private function _switchTab(tabIndex:Int) {
        // Hide all forms
        _collectionForm.visible = false;
        _collectionForm.includeInLayout = false;
        _versionForm.visible = false;
        _versionForm.includeInLayout = false;
        _githubForm.visible = false;
        _githubForm.includeInLayout = false;
        
        // Show the selected form
        switch (tabIndex) {
            case TAB_COLLECTION:
                _collectionForm.visible = true;
                _collectionForm.includeInLayout = true;
                _activeTabIndex = TAB_COLLECTION;
            
            case TAB_VERSION:
                _versionForm.visible = true;
                _versionForm.includeInLayout = true;
                _activeTabIndex = TAB_VERSION;
            
            case TAB_GITHUB:
                // Always force a fresh load of GitHub tokens when switching to this tab
                // This ensures we always have the most up-to-date token list
                var secrets = SuperHumanInstaller.getInstance().config.secrets;
                _loadGitTokens();
                
                _githubForm.visible = true;
                _githubForm.includeInLayout = true;
                _activeTabIndex = TAB_GITHUB;
        }
        
        // Update tab bar selection to match (in case this was called programmatically)
        _tabBar.selectedIndex = tabIndex;
    }

    /**
     * Handle browse button click for collection import
     */
    private function _browseCollectionButtonTriggered(event:TriggerEvent) {
        if (_fd != null) return;
        
        _fd = new FileDialog();
        
        _fd.onSelect.add(path -> {
            _collectionPathInput.text = path;
            _collectionPathInput.toolTip = path;
            _fd = null;
        });
        
        _fd.onCancel.add(() -> {
            _fd = null;
        });
        
        _fd.browse(FileDialogType.OPEN_DIRECTORY, null, null, LanguageManager.getInstance().getString("provisionerimportpage.dialog.selectcollection"));
    }

    /**
     * Handle browse button click for version import
     */
    private function _browseVersionButtonTriggered(event:TriggerEvent) {
        if (_fd != null) return;
        
        _fd = new FileDialog();
        
        _fd.onSelect.add(path -> {
            _versionPathInput.text = path;
            _versionPathInput.toolTip = path;
            _fd = null;
        });
        
        _fd.onCancel.add(() -> {
            _fd = null;
        });
        
        _fd.browse(FileDialogType.OPEN_DIRECTORY, null, null, LanguageManager.getInstance().getString("provisionerimportpage.dialog.selectversion"));
    }

    /**
     * Handle token dropdown selection change
     */
    private function _tokenDropdownChanged(event:Event) {
        // Get the selected item from the dropdown
        var selectedItem = _githubTokenDropdown.selectedItem;
        
        if (selectedItem != null) {
            // Extract the value from the selected item
            var value = Reflect.field(selectedItem, "value");
            
            // Update the selected token name
            _selectedTokenName = value != null ? value : "";
        } else {
            // Default to empty (no token) if nothing is selected
            _selectedTokenName = "";
        }
    }

    /**
     * Handle import button click - determines which import method to use
     */
    private function _importButtonTriggered(event:TriggerEvent) {
        switch (_activeTabIndex) {
            case TAB_COLLECTION:
                _importCollection();
            case TAB_VERSION:
                _importVersion();
            case TAB_GITHUB:
                _importFromGitHub();
        }
    }

    /**
     * Import a provisioner collection
     */
    private function _importCollection() {
        var path = _collectionPathInput.text;
        
        if (path == null || StringTools.trim(path) == "") {
            ToastManager.getInstance().showToast(LanguageManager.getInstance().getString("provisionerimportpage.toast.selectcollection"));
            return;
        }
        
        // Use the existing import method
        var success = ProvisionerManager.importProvisioner(path);
        
        if (success) {
            ToastManager.getInstance().showToast(LanguageManager.getInstance().getString("provisionerimportpage.toast.collectionimportsuccess"));
            
            // Dispatch event to notify the application that a provisioner was imported
            var event = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.IMPORT_PROVISIONER);
            this.dispatchEvent(event);
            
            // Close the page
            _closeImportPage();
        } else {
            ToastManager.getInstance().showToast(LanguageManager.getInstance().getString("provisionerimportpage.toast.collectionimportfail"));
        }
    }

    /**
     * Import a specific provisioner version
     */
    private function _importVersion() {
        var path = _versionPathInput.text;
        
        if (path == null || StringTools.trim(path) == "") {
            ToastManager.getInstance().showToast(LanguageManager.getInstance().getString("provisionerimportpage.toast.selectversion"));
            return;
        }
        
        // Use the new version import method which we'll add to ProvisionerManager
        var success = ProvisionerManager.importProvisionerVersion(path);
        
        if (success) {
            ToastManager.getInstance().showToast(LanguageManager.getInstance().getString("provisionerimportpage.toast.versionimportsuccess"));
            
            // Dispatch event to notify the application that a provisioner was imported
            var event = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.IMPORT_PROVISIONER);
            this.dispatchEvent(event);
            
            // Close the page
            _closeImportPage();
        } else {
            ToastManager.getInstance().showToast(LanguageManager.getInstance().getString("provisionerimportpage.toast.versionimportfail"));
        }
    }

    /**
     * Import a provisioner from GitHub (now asynchronous)
     */
    private function _importFromGitHub() {
        // Prevent multiple imports at once
        if (_isImporting) {
            ToastManager.getInstance().showToast(LanguageManager.getInstance().getString("provisionerimportpage.toast.importinprogress"));
            return;
        }
        
        var org = _githubOrgInput.text;
        var repo = _githubRepoInput.text;
        var branch = _githubBranchInput.text;
        var useGit = _githubUseGit.selected;
        
        if (org == null || StringTools.trim(org) == "") {
            ToastManager.getInstance().showToast(LanguageManager.getInstance().getString("provisionerimportpage.toast.enterorganization"));
            return;
        }
        
        if (repo == null || StringTools.trim(repo) == "") {
            ToastManager.getInstance().showToast(LanguageManager.getInstance().getString("provisionerimportpage.toast.enterrepository"));
            return;
        }
        
        if (branch == null || StringTools.trim(branch) == "") {
            // Default to main if not specified
            branch = "main";
        }
        
        // Only Git clone is supported for async currently
        if (!useGit) {
            ToastManager.getInstance().showToast(LanguageManager.getInstance().getString("provisionerimportpage.toast.gitclonerequired"));
            return;
        }
        
        // Add listener for the completion event *before* starting
        this.addEventListener(SuperHumanApplicationEvent.PROVISIONER_IMPORT_COMPLETE, _onProvisionerImportComplete);
        
        // Call the asynchronous import function
        var executor:AbstractExecutor = ProvisionerManager.importProvisionerFromGitHubAsync(
            org, repo, branch, useGit, _selectedTokenName, this
        );
        
        if (executor != null) {
            // Start the import process
            _isImporting = true;
            _buttonImport.enabled = false; // Disable button
            _spinner.visible = true; // Show spinner
            _spinner.includeInLayout = true;
            _spinner.start(); // Start spinner animation
            ToastManager.getInstance().showToast(LanguageManager.getInstance().getString("provisionerimportpage.toast.startinggithubimport"));
            
            // Execute the clone process
            executor.execute();
        } else {
            // Setup failed, remove listener
            this.removeEventListener(SuperHumanApplicationEvent.PROVISIONER_IMPORT_COMPLETE, _onProvisionerImportComplete);
            // Error toast is shown by the manager in this case
        }
    }
    
    /**
     * Handles the completion event from the asynchronous provisioner import.
     */
    private function _onProvisionerImportComplete(event:SuperHumanApplicationEvent):Void {
        // Remove the listener immediately
        this.removeEventListener(SuperHumanApplicationEvent.PROVISIONER_IMPORT_COMPLETE, _onProvisionerImportComplete);
        
        // Stop and hide spinner
        _spinner.stop();
        _spinner.visible = false;
        _spinner.includeInLayout = false;

        // Re-enable UI
        _isImporting = false;
        _buttonImport.enabled = true;
        
        // Show result message
        ToastManager.getInstance().showToast(event.importMessage);
        
        if (event.importSuccess) {
            // Defer the potentially heavy event dispatch and page closing to the next frame
            // to allow the current UI updates (button enable, toast) to render first.
            var stageRef = this.stage; // Capture stage reference
            if (stageRef != null) {
                var handler = null;
                handler = function(e:Event):Void {
                    stageRef.removeEventListener(Event.ENTER_FRAME, handler); // Remove listener immediately
                    
                    // Dispatch the original event to update lists etc.
                    var successEvent = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.IMPORT_PROVISIONER);
                    this.dispatchEvent(successEvent);
                    
                    // Close the page on success
                    _closeImportPage();
                };
                stageRef.addEventListener(Event.ENTER_FRAME, handler, false, 0, true);
            } else {
                // Fallback if stage is somehow null (shouldn't happen but good practice)
                var successEvent = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.IMPORT_PROVISIONER);
                this.dispatchEvent(successEvent);
                _closeImportPage();
            }
        }
        // On failure, the page stays open for the user to correct input or try again.
    }

    /**
     * Handle cancel button click
     */
    private function _cancelButtonTriggered(event:TriggerEvent) {
        _closeImportPage();
    }


    /**
     * Clean up event listeners when this page is disposed
     */
    override public function dispose():Void {
        // Remove event listeners
        this.removeEventListener(Event.ADDED_TO_STAGE, _onAddedToStage);
        this.removeEventListener(SuperHumanApplicationEvent.SAVE_APP_CONFIGURATION, _onAppConfigurationSaved);
        // Ensure the import complete listener is removed if the page is closed prematurely
        this.removeEventListener(SuperHumanApplicationEvent.PROVISIONER_IMPORT_COMPLETE, _onProvisionerImportComplete);
        
        super.dispose();
    }
    
    /**
     * Called when this page is added to the stage (becomes visible)
     */
    private function _onAddedToStage(event:Event):Void {
        // Refresh the token list whenever the page is shown
        _loadGitTokens();
    }
    
    /**
     * Close the import page
     */
    private function _closeImportPage() {
        this.dispatchEvent(new SuperHumanApplicationEvent(SuperHumanApplicationEvent.CLOSE_PROVISIONER_IMPORT_PAGE));
    }
}
