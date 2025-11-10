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
import superhuman.server.provisioners.ProvisionerType;
import feathers.controls.ToggleButton;
import feathers.utils.DisplayObjectRecycler;
import openfl.events.Event;
import feathers.skins.RectangleSkin;
import openfl.text.TextFormat;
import prominic.sys.io.AbstractExecutor; // Added for async import
import genesis.application.components.ProgressIndicator; // Added for spinner

/**
 * A page that provides the user with different methods to import and manage provisioners
 */
class ProvisionerManagementPage extends Page {

    // Constants
    final _width:Float = GenesisApplicationTheme.GRID * 140;
    
    // Tab indices
    static final TAB_COLLECTION:Int = 0;
    static final TAB_VERSION:Int = 1;
    static final TAB_GITHUB:Int = 2;
    static final TAB_MANAGE:Int = 3;

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
    
    // Manage components
    var _manageForm:GenesisForm;
    var _manageProvisionersList:LayoutGroup;
    
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
        _label.text = LanguageManager.getInstance().getString("provisionermanagementpage.title");
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
            { text: LanguageManager.getInstance().getString("provisionermanagementpage.tabs.collection"), icon: null },
            { text: LanguageManager.getInstance().getString("provisionermanagementpage.tabs.version"), icon: null },
            { text: LanguageManager.getInstance().getString("provisionermanagementpage.tabs.github"), icon: null },
            { text: LanguageManager.getInstance().getString("provisionermanagementpage.tabs.manage"), icon: null }
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
        descLabel.text = LanguageManager.getInstance().getString("provisionermanagementpage.collection.description");
        descLabel.wordWrap = true;
        descLabel.textFormat = new TextFormat("_sans", 14, 0xFFFFFF);
        descLabel.width = _width * 0.70; // Explicitly set width to constrain text
        descContainer.addChild(descLabel);
        
        // Add the description container to the form before any form rows
        _collectionForm.addChild(descContainer);
        
        // Path row
        var pathRow = new GenesisFormRow();
        pathRow.text = LanguageManager.getInstance().getString("provisionermanagementpage.collection.path");
        
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
        
        _collectionPathInput = new GenesisFormTextInput("", LanguageManager.getInstance().getString("provisionermanagementpage.collection.placeholder"));
        _collectionPathInput.width = (_width * 0.8) - 150 - GenesisApplicationTheme.GRID * 17; // Reduced to give more space to browse button
        _collectionPathInput.enabled = false;
        
        _buttonBrowseCollection = new Button();
        _buttonBrowseCollection.text = LanguageManager.getInstance().getString("provisionermanagementpage.buttons.browse");
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
        descLabel.text = LanguageManager.getInstance().getString("provisionermanagementpage.version.description");
        descLabel.wordWrap = true;
        descLabel.textFormat = new TextFormat("_sans", 14, 0xFFFFFF);
        descLabel.width = _width * 0.70; // Explicitly set width to constrain text
        descContainer.addChild(descLabel);
        
        // Add the description container to the form before any form rows
        _versionForm.addChild(descContainer);
        
        // Path row
        var pathRow = new GenesisFormRow();
        pathRow.text = LanguageManager.getInstance().getString("provisionermanagementpage.version.path");
        
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
        
        _versionPathInput = new GenesisFormTextInput("", LanguageManager.getInstance().getString("provisionermanagementpage.version.placeholder"));
        _versionPathInput.width = (_width * 0.8) - 150 - GenesisApplicationTheme.GRID * 17; // Reduced to give more space to browse button
        _versionPathInput.enabled = false;
        
        _buttonBrowseVersion = new Button();
        _buttonBrowseVersion.text = LanguageManager.getInstance().getString("provisionermanagementpage.buttons.browse");
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
        descLabel.text = LanguageManager.getInstance().getString("provisionermanagementpage.github.description");
        descLabel.wordWrap = true;
        descLabel.textFormat = new TextFormat("_sans", 14, 0xFFFFFF);
        descLabel.width = _width * 0.70; // Explicitly set width to constrain text
        descContainer.addChild(descLabel);
        
        // Add the description container to the form before any form rows
        _githubForm.addChild(descContainer);
        
        // GitHub organization/user
        var orgRow = new GenesisFormRow();
        orgRow.text = LanguageManager.getInstance().getString("provisionermanagementpage.github.organization");
        
        // Adjust column widths for label/content ratio (20%/80%)
        var orgLabel = cast(orgRow.getChildAt(0), feathers.core.FeathersControl);
        var orgContent = cast(orgRow.getChildAt(1), feathers.core.FeathersControl);
        if (orgLabel != null) orgLabel.layoutData = new HorizontalLayoutData(20);
        if (orgContent != null) orgContent.layoutData = new HorizontalLayoutData(80);
        
        _githubOrgInput = new GenesisFormTextInput("", LanguageManager.getInstance().getString("provisionermanagementpage.github.organizationPlaceholder"));
        // Set width to match the other input fields
        _githubOrgInput.width = (_width * 0.8) - 150;
        orgRow.content.addChild(_githubOrgInput);
        _githubForm.addChild(orgRow);
        
        // GitHub repository
        var repoRow = new GenesisFormRow();
        repoRow.text = LanguageManager.getInstance().getString("provisionermanagementpage.github.repository");
        
        // Adjust column widths for label/content ratio (20%/80%)
        var repoLabel = cast(repoRow.getChildAt(0), feathers.core.FeathersControl);
        var repoContent = cast(repoRow.getChildAt(1), feathers.core.FeathersControl);
        if (repoLabel != null) repoLabel.layoutData = new HorizontalLayoutData(20);
        if (repoContent != null) repoContent.layoutData = new HorizontalLayoutData(80);
        
        _githubRepoInput = new GenesisFormTextInput("", LanguageManager.getInstance().getString("provisionermanagementpage.github.repositoryPlaceholder"));
        _githubRepoInput.width = (_width * 0.8) - 150;
        repoRow.content.addChild(_githubRepoInput);
        _githubForm.addChild(repoRow);
        
        // GitHub branch
        var branchRow = new GenesisFormRow();
        branchRow.text = LanguageManager.getInstance().getString("provisionermanagementpage.github.branch");
        
        // Adjust column widths for label/content ratio (20%/80%)
        var branchLabel = cast(branchRow.getChildAt(0), feathers.core.FeathersControl);
        var branchContent = cast(branchRow.getChildAt(1), feathers.core.FeathersControl);
        if (branchLabel != null) branchLabel.layoutData = new HorizontalLayoutData(20);
        if (branchContent != null) branchContent.layoutData = new HorizontalLayoutData(80);
        
        _githubBranchInput = new GenesisFormTextInput("main", LanguageManager.getInstance().getString("provisionermanagementpage.github.branchPlaceholder"));
        _githubBranchInput.width = (_width * 0.8) - 150;
        branchRow.content.addChild(_githubBranchInput);
        _githubForm.addChild(branchRow);
        
        // GitHub token selection
        var tokenRow = new GenesisFormRow();
        tokenRow.text = LanguageManager.getInstance().getString("provisionermanagementpage.github.token");
        
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
        gitRow.text = LanguageManager.getInstance().getString("provisionermanagementpage.github.downloadmethod");
        
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
        httpLabel.text = LanguageManager.getInstance().getString("provisionermanagementpage.github.http");
        httpLabel.variant = GenesisApplicationTheme.LABEL_DEFAULT;
        
        // Create a styled toggle checkbox resembling the FileSyncSetting
        _githubUseGit = new genesis.application.components.GenesisFormCheckBox("", false);
        
        // Git label (right side)
        var gitLabel = new Label();
        gitLabel.text = LanguageManager.getInstance().getString("provisionermanagementpage.github.gitclone");
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
        _initializeManageForm();
        
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
        _buttonImport = new GenesisFormButton(LanguageManager.getInstance().getString("provisionermanagementpage.buttons.import"));
        _buttonImport.addEventListener(TriggerEvent.TRIGGER, _importButtonTriggered);
        _buttonImport.width = GenesisApplicationTheme.GRID * 20;
        
        // Cancel button
        _buttonCancel = new GenesisFormButton(LanguageManager.getInstance().getString("provisionermanagementpage.buttons.cancel"));
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
        _manageForm.visible = false;
        _manageForm.includeInLayout = false;
        
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
                
            case TAB_MANAGE:
                // Refresh the manage tab when switching to it
                _refreshManageTab();
                
                _manageForm.visible = true;
                _manageForm.includeInLayout = true;
                _activeTabIndex = TAB_MANAGE;
        }
        
        // Show/hide Import button based on active tab (hide for Manage tab)
        // Always keep Cancel button visible
        var showImportButton = (tabIndex != TAB_MANAGE);
        _buttonImport.visible = showImportButton;
        _buttonImport.includeInLayout = showImportButton;
        
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
        
        _fd.browse(FileDialogType.OPEN_DIRECTORY, null, null, LanguageManager.getInstance().getString("provisionermanagementpage.dialog.selectcollection"));
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
        
        _fd.browse(FileDialogType.OPEN_DIRECTORY, null, null, LanguageManager.getInstance().getString("provisionermanagementpage.dialog.selectversion"));
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
            ToastManager.getInstance().showToast(LanguageManager.getInstance().getString("provisionermanagementpage.toast.selectcollection"));
            return;
        }
        
        // Use the existing import method
        var success = ProvisionerManager.importProvisioner(path);
        
        if (success) {
            ToastManager.getInstance().showToast(LanguageManager.getInstance().getString("provisionermanagementpage.toast.collectionimportsuccess"));
            
            // Dispatch event to notify the application that a provisioner was imported
            var event = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.IMPORT_PROVISIONER);
            this.dispatchEvent(event);
            
            // Close the page
            _closeImportPage();
        } else {
            ToastManager.getInstance().showToast(LanguageManager.getInstance().getString("provisionermanagementpage.toast.collectionimportfail"));
        }
    }

    /**
     * Import a specific provisioner version
     */
    private function _importVersion() {
        var path = _versionPathInput.text;
        
        if (path == null || StringTools.trim(path) == "") {
            ToastManager.getInstance().showToast(LanguageManager.getInstance().getString("provisionermanagementpage.toast.selectversion"));
            return;
        }
        
        // Use the new version import method which we'll add to ProvisionerManager
        var success = ProvisionerManager.importProvisionerVersion(path);
        
        if (success) {
            ToastManager.getInstance().showToast(LanguageManager.getInstance().getString("provisionermanagementpage.toast.versionimportsuccess"));
            
            // Dispatch event to notify the application that a provisioner was imported
            var event = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.IMPORT_PROVISIONER);
            this.dispatchEvent(event);
            
            // Close the page
            _closeImportPage();
        } else {
            ToastManager.getInstance().showToast(LanguageManager.getInstance().getString("provisionermanagementpage.toast.versionimportfail"));
        }
    }

    /**
     * Import a provisioner from GitHub (now asynchronous)
     */
    private function _importFromGitHub() {
        // Prevent multiple imports at once
        if (_isImporting) {
            ToastManager.getInstance().showToast(LanguageManager.getInstance().getString("provisionermanagementpage.toast.importinprogress"));
            return;
        }
        
        var org = _githubOrgInput.text;
        var repo = _githubRepoInput.text;
        var branch = _githubBranchInput.text;
        var useGit = _githubUseGit.selected;
        
        if (org == null || StringTools.trim(org) == "") {
            ToastManager.getInstance().showToast(LanguageManager.getInstance().getString("provisionermanagementpage.toast.enterorganization"));
            return;
        }
        
        if (repo == null || StringTools.trim(repo) == "") {
            ToastManager.getInstance().showToast(LanguageManager.getInstance().getString("provisionermanagementpage.toast.enterrepository"));
            return;
        }
        
        if (branch == null || StringTools.trim(branch) == "") {
            // Default to main if not specified
            branch = "main";
        }
        
        // Only Git clone is supported for async currently
        if (!useGit) {
            ToastManager.getInstance().showToast(LanguageManager.getInstance().getString("provisionermanagementpage.toast.gitclonerequired"));
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
            ToastManager.getInstance().showToast(LanguageManager.getInstance().getString("provisionermanagementpage.toast.startinggithubimport"));
            
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
     * Initialize the manage form for listing and deleting provisioners
     */
    private function _initializeManageForm() {
        _manageForm = new GenesisForm();
        _manageForm.visible = false;
        _manageForm.includeInLayout = false;
        
        // Description container - match other tabs' width pattern
        var descContainer = new LayoutGroup();
        descContainer.width = _width * 0.75; // Match other tabs (was 0.90)
        
        var descLayout = new VerticalLayout();
        descLayout.horizontalAlign = HorizontalAlign.LEFT;
        descLayout.paddingTop = GenesisApplicationTheme.GRID;
        descLayout.paddingBottom = GenesisApplicationTheme.GRID * 2;
        descLayout.paddingLeft = GenesisApplicationTheme.GRID;
        descLayout.paddingRight = GenesisApplicationTheme.GRID;
        descContainer.layout = descLayout;
        
        var descLabel = new Label();
        descLabel.text = LanguageManager.getInstance().getString("provisionermanagementpage.manage.description");
        descLabel.wordWrap = true;
        descLabel.textFormat = new TextFormat("_sans", 14, 0xFFFFFF);
        descLabel.width = _width * 0.70; // Match other tabs (was 0.85)
        descContainer.addChild(descLabel);
        
        _manageForm.addChild(descContainer);
        
        // Create provisioners list directly (no form row wrapper)
        _manageProvisionersList = new LayoutGroup();
        var listLayout = new VerticalLayout();
        listLayout.gap = GenesisApplicationTheme.GRID;
        listLayout.horizontalAlign = HorizontalAlign.LEFT;
        listLayout.paddingLeft = GenesisApplicationTheme.GRID;
        listLayout.paddingRight = GenesisApplicationTheme.GRID;
        _manageProvisionersList.layout = listLayout;
        _manageProvisionersList.width = _width * 0.75; // Match other tabs (was 0.90)
        
        _manageForm.addChild(_manageProvisionersList);
        
        _formContainer.addChild(_manageForm);
    }
    
    /**
     * Refresh the manage tab with current provisioner data
     */
    private function _refreshManageTab() {
        // Clear existing provisioner list
        _manageProvisionersList.removeChildren();
        
        // Get all custom provisioners (exclude built-in ones)
        var allProvisioners = ProvisionerManager.getBundledProvisioners();
        var customProvisioners = [];
        
        for (provisioner in allProvisioners) {
            var provType = Std.string(provisioner.data.type);
            if (provType != Std.string(ProvisionerType.StandaloneProvisioner) &&
                provType != Std.string(ProvisionerType.AdditionalProvisioner) &&
                provType != Std.string(ProvisionerType.Default)) {
                customProvisioners.push(provisioner);
            }
        }
        
        if (customProvisioners.length == 0) {
            // Show "no provisioners" message
            var noProvisionersLabel = new Label();
            noProvisionersLabel.text = LanguageManager.getInstance().getString("provisionermanagementpage.manage.noprovisioners");
            noProvisionersLabel.wordWrap = true;
            noProvisionersLabel.variant = GenesisApplicationTheme.LABEL_COPYRIGHT;
            noProvisionersLabel.width = _width * 0.70;
            _manageProvisionersList.addChild(noProvisionersLabel);
            return;
        }
        
        // Group provisioners by type to show each type with its versions
        var provisionersByType = new Map<String, Array<superhuman.server.definitions.ProvisionerDefinition>>();
        
        for (provisioner in customProvisioners) {
            var type = Std.string(provisioner.data.type);
            if (!provisionersByType.exists(type)) {
                provisionersByType.set(type, []);
            }
            provisionersByType.get(type).push(provisioner);
        }
        
        // Create UI for each provisioner type
        for (type in provisionersByType.keys()) {
            var provisioners = provisionersByType.get(type);
            
            // Create main container with horizontal layout for better positioning
            var mainContainer = new LayoutGroup();
            var mainLayout = new HorizontalLayout();
            mainLayout.gap = GenesisApplicationTheme.GRID * 2;
            mainLayout.verticalAlign = VerticalAlign.MIDDLE;
            mainLayout.paddingTop = GenesisApplicationTheme.GRID;
            mainLayout.paddingBottom = GenesisApplicationTheme.GRID;
            mainLayout.paddingLeft = GenesisApplicationTheme.GRID;
            mainLayout.paddingRight = GenesisApplicationTheme.GRID;
            mainContainer.layout = mainLayout;
            mainContainer.width = (_width * 0.8) - 150; // Match GitHub form field width
            
            // Create a background for this provisioner type
            var typeBg = new RectangleSkin(FillStyle.SolidColor(0x333333));
            typeBg.cornerRadius = GenesisApplicationTheme.GRID / 2;
            typeBg.border = LineStyle.SolidColor(1, 0x444444, 0.3);
            mainContainer.backgroundSkin = typeBg;
            
            // Create left side container for provisioner info
            var infoContainer = new LayoutGroup();
            var infoLayout = new VerticalLayout();
            infoLayout.gap = GenesisApplicationTheme.GRID / 2;
            infoContainer.layout = infoLayout;
            infoContainer.layoutData = new HorizontalLayoutData(75); // Take 75% of width
            
            // Get the first provisioner for metadata
            var firstProvisioner = provisioners[0];
            var metadata = firstProvisioner.metadata;
            var displayName = metadata != null ? metadata.name : type;
            var description = metadata != null ? metadata.description : "Custom provisioner";
            
            // Type header
            var typeLabel = new Label();
            typeLabel.text = displayName;
            typeLabel.variant = GenesisApplicationTheme.LABEL_DEFAULT;
            typeLabel.textFormat = new TextFormat("_sans", 16, 0xFFFFFF, true); // Bold
            infoContainer.addChild(typeLabel);
            
            // Description
            if (description != displayName) {
                var descLabel = new Label();
                descLabel.text = description;
                descLabel.variant = GenesisApplicationTheme.LABEL_COPYRIGHT;
                descLabel.wordWrap = true;
                descLabel.width = _width * 0.55; // Adjust width for left column
                infoContainer.addChild(descLabel);
            }
            
            // Check usage for this entire provisioner type
            var usageCheck = ProvisionerManager.canDeleteProvisioner(type);
            var canDelete = usageCheck.canDelete;
            var serversUsing = usageCheck.serversUsing;
            
            // Usage information
            var usageLabel = new Label();
            if (serversUsing.length > 0) {
                usageLabel.text = 'Used by ${serversUsing.length} server(s)';
                usageLabel.variant = GenesisApplicationTheme.LABEL_ERROR;
            } else {
                usageLabel.text = LanguageManager.getInstance().getString("provisionermanagementpage.manage.nousage");
                usageLabel.variant = GenesisApplicationTheme.LABEL_COPYRIGHT;
            }
            infoContainer.addChild(usageLabel);
            
            // Versions list
            var versionsContainer = new LayoutGroup();
            var versionsLayout = new VerticalLayout();
            versionsLayout.gap = GenesisApplicationTheme.GRID / 4;
            versionsLayout.paddingLeft = GenesisApplicationTheme.GRID;
            versionsContainer.layout = versionsLayout;
            
            for (provisioner in provisioners) {
                var versionLabel = new Label();
                versionLabel.text = 'v${provisioner.data.version}';
                versionLabel.variant = GenesisApplicationTheme.LABEL_COPYRIGHT;
                versionsContainer.addChild(versionLabel);
            }
            
            infoContainer.addChild(versionsContainer);
            mainContainer.addChild(infoContainer);
            
            // Create right side container for buttons (vertically centered)
            var buttonContainer = new LayoutGroup();
            var buttonLayout = new VerticalLayout();
            buttonLayout.gap = GenesisApplicationTheme.GRID;
            buttonLayout.horizontalAlign = HorizontalAlign.CENTER;
            buttonLayout.verticalAlign = VerticalAlign.MIDDLE;
            buttonContainer.layout = buttonLayout;
            buttonContainer.layoutData = new HorizontalLayoutData(25); // Take 25% of width
            
            // Check if this provisioner has GitHub source info
            var hasGitHubSource = _checkHasGitHubSource(type);
            
            // Update status label
            var updateStatusLabel = new Label();
            if (hasGitHubSource) {
                updateStatusLabel.text = ""; // Empty initially for GitHub provisioners
            } else {
                updateStatusLabel.text = "Local only";
            }
            updateStatusLabel.variant = GenesisApplicationTheme.LABEL_COPYRIGHT;
            updateStatusLabel.width = GenesisApplicationTheme.GRID * 12;
            updateStatusLabel.textFormat = new TextFormat("_sans", 10, 0x999999);
            
            // Update button - always enabled for GitHub provisioners
            var updateButton = new GenesisFormButton("Check");
            updateButton.width = GenesisApplicationTheme.GRID * 18; // Wider to prevent text cutoff
            updateButton.enabled = hasGitHubSource; // Enabled for GitHub provisioners
            
            if (hasGitHubSource) {
                updateButton.toolTip = "Check for newer versions on GitHub";
                
                // Add click handler for manual update checking
                updateButton.addEventListener(TriggerEvent.TRIGGER, function(e:TriggerEvent) {
                    _manualCheckForUpdates(type, updateButton, updateStatusLabel);
                });
            } else {
                updateButton.toolTip = "This provisioner was not imported from GitHub";
            }
            
            // Configure button (for token management)
            var configureButton = new GenesisFormButton("Configure");
            configureButton.width = GenesisApplicationTheme.GRID * 18; // Match update button width
            configureButton.enabled = hasGitHubSource;
            configureButton.visible = hasGitHubSource;
            configureButton.includeInLayout = hasGitHubSource;
            
            if (hasGitHubSource) {
                configureButton.toolTip = "Change GitHub token for updates";
                
                // Add click handler for configure button
                configureButton.addEventListener(TriggerEvent.TRIGGER, function(e:TriggerEvent) {
                    _configureProvisionerToken(type);
                });
            }
            
            buttonContainer.addChild(updateStatusLabel);
            buttonContainer.addChild(updateButton);
            buttonContainer.addChild(configureButton);
            
            // Delete button
            var deleteButton = new GenesisFormButton("Delete");
            deleteButton.width = GenesisApplicationTheme.GRID * 18; // Match other button widths
            deleteButton.enabled = canDelete;
            
            if (canDelete) {
                deleteButton.addEventListener(TriggerEvent.TRIGGER, function(e:TriggerEvent) {
                    _deleteProvisionerType(type, serversUsing);
                });
            } else {
                deleteButton.toolTip = 'Cannot delete - used by: ${serversUsing.join(", ")}';
            }
            
            buttonContainer.addChild(deleteButton);
            
            mainContainer.addChild(buttonContainer);
            
            _manageProvisionersList.addChild(mainContainer);
        }
    }
    
    /**
     * Manual update check triggered by user clicking the update button
     */
    private function _manualCheckForUpdates(provisionerType:String, updateButton:GenesisFormButton, statusLabel:Label) {
        // Show checking status
        statusLabel.text = "Checking...";
        statusLabel.textFormat = new TextFormat("_sans", 10, 0xFFFFFF);
        updateButton.enabled = false;
        updateButton.text = "Checking...";
        
        // Call the update check function
        ProvisionerManager.checkForUpdatesAsync(provisionerType, function(hasUpdate:Bool, localVersion:String, remoteVersion:String, errorMessage:String) {
            if (errorMessage != "") {
                // Error occurred during check
                if (errorMessage.indexOf("No GitHub source") >= 0) {
                    statusLabel.text = "Local only";
                    statusLabel.textFormat = new TextFormat("_sans", 10, 0x999999);
                    updateButton.text = "Check for Updates";
                    updateButton.enabled = false;
                } else if (errorMessage.indexOf("Network error") >= 0) {
                    statusLabel.text = "Check failed";
                    statusLabel.textFormat = new TextFormat("_sans", 10, 0xFF6666);
                    updateButton.text = "Retry Check";
                    updateButton.enabled = true;
                } else if (errorMessage.indexOf("token") >= 0 || errorMessage.indexOf("auth") >= 0) {
                    statusLabel.text = "Auth error";
                    statusLabel.textFormat = new TextFormat("_sans", 10, 0xFF6666);
                    updateButton.text = "Retry Check";
                    updateButton.enabled = true;
                } else {
                    statusLabel.text = "Check failed";
                    statusLabel.textFormat = new TextFormat("_sans", 10, 0xFF6666);
                    updateButton.text = "Retry Check";
                    updateButton.enabled = true;
                }
                updateButton.toolTip = errorMessage;
            } else if (hasUpdate) {
                // Update available
                statusLabel.text = 'v${remoteVersion} available';
                statusLabel.textFormat = new TextFormat("_sans", 10, 0x66FF66);
                updateButton.text = "Update";
                updateButton.enabled = true;
                updateButton.toolTip = 'Update from v${localVersion} to v${remoteVersion}';
                
                // Store a reference to the new update function for this specific button
                var updateFunction = function(e:TriggerEvent) {
                    _updateProvisioner(provisionerType, localVersion, remoteVersion);
                };
                
                // Remove all existing listeners and add the new update handler
                var currentListeners = updateButton.hasEventListener(TriggerEvent.TRIGGER);
                if (currentListeners) {
                    // Clear all trigger event listeners by removing and re-adding the button
                    var parent = updateButton.parent;
                    var index = parent.getChildIndex(updateButton);
                    parent.removeChild(updateButton);
                    parent.addChildAt(updateButton, index);
                }
                
                updateButton.addEventListener(TriggerEvent.TRIGGER, updateFunction);
            } else {
                // Up to date
                statusLabel.text = "Up to date";
                statusLabel.textFormat = new TextFormat("_sans", 10, 0x66FF66);
                updateButton.text = "Check";
                updateButton.enabled = true;
                updateButton.toolTip = 'Current version v${localVersion} is up to date - click to check again';
            }
        });
    }
    
    /**
     * Check if a provisioner has GitHub source information
     */
    private function _checkHasGitHubSource(provisionerType:String):Bool {
        try {
            var provisionersDir = ProvisionerManager.getProvisionersDirectory();
            var provisionerPath = haxe.io.Path.addTrailingSlash(provisionersDir) + provisionerType;
            var metadataPath = haxe.io.Path.addTrailingSlash(provisionerPath) + "provisioner-collection.yml";
            
            if (!sys.FileSystem.exists(metadataPath)) {
                return false;
            }
            
            var yamlMetadata = yaml.Yaml.read(metadataPath);
            var githubSource = null;
            
            if (Std.isOfType(yamlMetadata, yaml.util.ObjectMap)) {
                var objMap:yaml.util.ObjectMap<String, Dynamic> = cast yamlMetadata;
                if (objMap.exists("github_source")) {
                    githubSource = objMap.get("github_source");
                }
            } else if (Reflect.hasField(yamlMetadata, "github_source")) {
                githubSource = Reflect.field(yamlMetadata, "github_source");
            }
            
            // Check if GitHub source has the required fields - handle both ObjectMap and regular object cases
            if (githubSource != null) {
                var organization, repository;
                
                if (Std.isOfType(githubSource, yaml.util.ObjectMap)) {
                    var sourceMap:yaml.util.ObjectMap<String, Dynamic> = cast githubSource;
                    organization = sourceMap.get("organization");
                    repository = sourceMap.get("repository");
                } else {
                    organization = Reflect.field(githubSource, "organization");
                    repository = Reflect.field(githubSource, "repository");
                }
                
                return (organization != null && repository != null);
            }
            
            return false;
        } catch (e) {
            return false;
        }
    }
    
    /**
     * Configure the GitHub token for a provisioner
     */
    private function _configureProvisionerToken(provisionerType:String) {
        _showTokenConfigurationDialog(provisionerType);
    }
    
    /**
     * Show token configuration dialog following app's modal pattern
     */
    private function _showTokenConfigurationDialog(provisionerType:String) {
        // Get current token from provisioner metadata
        var currentToken = _getCurrentGitHubToken(provisionerType);
        var currentTokenDisplay = (currentToken != null && currentToken != "") ? currentToken : "None";
        
        // Get available GitHub tokens
        var secrets = SuperHumanInstaller.getInstance().config.secrets;
        var tokenOptions = [];
        
        // Add "None" option first
        tokenOptions.push({text: "None (Public Repository)", value: ""});
        
        // Add all available tokens (excluding the current one)
        if (secrets != null && secrets.git_api_keys != null && secrets.git_api_keys.length > 0) {
            for (gitToken in secrets.git_api_keys) {
                if (gitToken.name != currentToken) {
                    tokenOptions.push({text: gitToken.name, value: gitToken.name});
                }
            }
        }
        
        // Create alert dialog following app pattern
        var alert = feathers.controls.Alert.show("", "Configure GitHub Token", [], null);
        alert.width = GenesisApplicationTheme.GRID * 80;
        
        // Create content container
        var content = new LayoutGroup();
        content.width = GenesisApplicationTheme.GRID * 80;
        content.layoutData = new VerticalLayoutData(100);
        
        var verticalLayout = new VerticalLayout();
        verticalLayout.gap = GenesisApplicationTheme.GRID * 2;
        verticalLayout.paddingTop = GenesisApplicationTheme.GRID * 2;
        verticalLayout.paddingBottom = GenesisApplicationTheme.GRID * 2;
        verticalLayout.paddingLeft = GenesisApplicationTheme.GRID * 4;
        verticalLayout.paddingRight = GenesisApplicationTheme.GRID * 4;
        verticalLayout.horizontalAlign = HorizontalAlign.LEFT;
        content.layout = verticalLayout;
        
        // Provisioner info
        var infoGroup = new LayoutGroup();
        infoGroup.layoutData = new VerticalLayoutData(100);
        
        var infoLayout = new VerticalLayout();
        infoLayout.gap = GenesisApplicationTheme.GRID;
        infoLayout.horizontalAlign = HorizontalAlign.LEFT;
        infoGroup.layout = infoLayout;
        
        var provisionerLabel = new Label();
        provisionerLabel.text = 'Provisioner: ${provisionerType}';
        provisionerLabel.wordWrap = true;
        provisionerLabel.layoutData = new VerticalLayoutData(100);
        infoGroup.addChild(provisionerLabel);
        
        var currentLabel = new Label();
        currentLabel.text = 'Current Token: ${currentTokenDisplay}';
        currentLabel.variant = GenesisApplicationTheme.LABEL_COPYRIGHT;
        currentLabel.layoutData = new VerticalLayoutData(100);
        infoGroup.addChild(currentLabel);
        
        content.addChild(infoGroup);
        
        // Separator
        var separator = new HLine();
        separator.alpha = 0.3;
        separator.width = GenesisApplicationTheme.GRID * 70;
        separator.layoutData = new VerticalLayoutData(90);
        content.addChild(separator);
        
        // Selection section
        var selectionGroup = new LayoutGroup();
        selectionGroup.layoutData = new VerticalLayoutData(100);
        
        var selectionLayout = new VerticalLayout();
        selectionLayout.gap = GenesisApplicationTheme.GRID;
        selectionLayout.horizontalAlign = HorizontalAlign.LEFT;
        selectionGroup.layout = selectionLayout;
        
        var selectLabel = new Label();
        selectLabel.text = "Select New Token:";
        selectLabel.layoutData = new VerticalLayoutData(100);
        selectionGroup.addChild(selectLabel);
        
        // Token dropdown
        var tokenDropdown = new GenesisFormPupUpListView(new ArrayCollection(tokenOptions));
        tokenDropdown.itemToText = function(item:Dynamic):String {
            return item.text;
        };
        tokenDropdown.width = GenesisApplicationTheme.GRID * 60;
        
        // Set current selection
        var currentIndex = 0;
        for (i in 0...tokenOptions.length) {
            if (tokenOptions[i].value == currentToken) {
                currentIndex = i;
                break;
            }
        }
        tokenDropdown.selectedIndex = currentIndex;
        
        selectionGroup.addChild(tokenDropdown);
        content.addChild(selectionGroup);
        
        // Button separator
        var buttonSeparator = new HLine();
        buttonSeparator.alpha = 0.3;
        buttonSeparator.width = GenesisApplicationTheme.GRID * 70;
        buttonSeparator.layoutData = new VerticalLayoutData(90);
        content.addChild(buttonSeparator);
        
        // Button container
        var buttonGroup = new LayoutGroup();
        buttonGroup.layoutData = new VerticalLayoutData(100);
        
        var buttonLayout = new HorizontalLayout();
        buttonLayout.gap = GenesisApplicationTheme.GRID * 2;
        buttonLayout.horizontalAlign = HorizontalAlign.CENTER;
        buttonGroup.layout = buttonLayout;
        
        // OK button
        var okButton = new GenesisFormButton("OK");
        okButton.width = GenesisApplicationTheme.GRID * 15;
        
        // Cancel button
        var cancelButton = new GenesisFormButton("Cancel");
        cancelButton.width = GenesisApplicationTheme.GRID * 15;
        
        // Secrets button
        var secretsButton = new GenesisFormButton("Secrets");
        secretsButton.width = GenesisApplicationTheme.GRID * 15;
        
        buttonGroup.addChild(okButton);
        buttonGroup.addChild(cancelButton);
        buttonGroup.addChild(secretsButton);
        
        content.addChild(buttonGroup);
        
        // Add event handlers
        okButton.addEventListener(TriggerEvent.TRIGGER, function(e:TriggerEvent) {
            var selectedItem = tokenDropdown.selectedItem;
            if (selectedItem != null) {
                var newTokenName = Reflect.field(selectedItem, "value");
                
                // Only update if different from current
                if (newTokenName != currentToken) {
                    if (_updateProvisionerGitHubToken(provisionerType, newTokenName)) {
                        var displayName = (newTokenName == "") ? "None (Public Repository)" : newTokenName;
                        ToastManager.getInstance().showToast('GitHub token updated to: ${displayName}');
                        _refreshManageTab();
                    } else {
                        ToastManager.getInstance().showToast("Failed to update GitHub token");
                    }
                } else {
                    ToastManager.getInstance().showToast("Token unchanged");
                }
            }
            
            // Close dialog properly
            try {
                feathers.core.PopUpManager.removePopUp(alert);
            } catch (e:Dynamic) {
                // Ignore close errors
            }
        });
        
        cancelButton.addEventListener(TriggerEvent.TRIGGER, function(e:TriggerEvent) {
            try {
                feathers.core.PopUpManager.removePopUp(alert);
            } catch (e:Dynamic) {
                // Ignore close errors
            }
        });
        
        secretsButton.addEventListener(TriggerEvent.TRIGGER, function(e:TriggerEvent) {
            try {
                feathers.core.PopUpManager.removePopUp(alert);
            } catch (e:Dynamic) {
                // Ignore close errors
            }
            ToastManager.getInstance().showToast("Opening Secrets page to manage GitHub tokens");
            _closeImportPage();
        });
        
        // Add custom content to the alert
        alert.addChild(content);
    }
    
    /**
     * Update a provisioner to the latest version from GitHub
     */
    private function _updateProvisioner(provisionerType:String, localVersion:String, remoteVersion:String) {
        // Show confirmation dialog
        var confirmMessage = 'Update "${provisionerType}" from v${localVersion} to v${remoteVersion}?\n\nThis will download and install the new version while keeping the existing version.';
        
        feathers.controls.Alert.show(
            confirmMessage,
            'Update ${provisionerType}',
            ["Update", "Cancel"],
            function(state) {
                if (state.index == 0) {
                    // User confirmed update
                    _performProvisionerUpdate(provisionerType);
                }
            }
        );
    }
    
    /**
     * Perform the actual provisioner update using the stored GitHub source metadata
     */
    private function _performProvisionerUpdate(provisionerType:String) {
        // Read GitHub source metadata
        var provisionersDir = ProvisionerManager.getProvisionersDirectory();
        var provisionerPath = haxe.io.Path.addTrailingSlash(provisionersDir) + provisionerType;
        var metadataPath = haxe.io.Path.addTrailingSlash(provisionerPath) + "provisioner-collection.yml";
        
        try {
            var yamlMetadata = yaml.Yaml.read(metadataPath);
            var githubSource = null;
            
            if (Std.isOfType(yamlMetadata, yaml.util.ObjectMap)) {
                var objMap:yaml.util.ObjectMap<String, Dynamic> = cast yamlMetadata;
                if (objMap.exists("github_source")) {
                    githubSource = objMap.get("github_source");
                }
            } else if (Reflect.hasField(yamlMetadata, "github_source")) {
                githubSource = Reflect.field(yamlMetadata, "github_source");
            }
            
            if (githubSource == null) {
                ToastManager.getInstance().showToast("No GitHub source information found for update");
                return;
            }
            
            // Extract GitHub source details - handle both ObjectMap and regular object cases
            var organization, repository, branch, tokenName, importMethod;
            
            if (Std.isOfType(githubSource, yaml.util.ObjectMap)) {
                var sourceMap:yaml.util.ObjectMap<String, Dynamic> = cast githubSource;
                organization = sourceMap.get("organization");
                repository = sourceMap.get("repository");
                branch = sourceMap.get("branch");
                tokenName = sourceMap.get("git_token_name");
                importMethod = sourceMap.get("import_method");
            } else {
                organization = Reflect.field(githubSource, "organization");
                repository = Reflect.field(githubSource, "repository");
                branch = Reflect.field(githubSource, "branch");
                tokenName = Reflect.field(githubSource, "git_token_name");
                importMethod = Reflect.field(githubSource, "import_method");
            }
            
            if (organization == null || repository == null || branch == null) {
                ToastManager.getInstance().showToast("Incomplete GitHub source information");
                return;
            }
            
            // Use the same import method they originally used
            var useGit = (importMethod == "git");
            
            if (!useGit) {
                ToastManager.getInstance().showToast("Update requires Git clone method, but provisioner was imported via HTTP");
                return;
            }
            
            // Add listener for the completion event
            this.addEventListener(SuperHumanApplicationEvent.PROVISIONER_IMPORT_COMPLETE, _onProvisionerUpdateComplete);
            
            // Start the update process (same as import)
            var executor:AbstractExecutor = ProvisionerManager.importProvisionerFromGitHubAsync(
                organization, repository, branch, useGit, tokenName, this
            );
            
            if (executor != null) {
                ToastManager.getInstance().showToast('Starting update of ${provisionerType}...');
                executor.execute();
            } else {
                this.removeEventListener(SuperHumanApplicationEvent.PROVISIONER_IMPORT_COMPLETE, _onProvisionerUpdateComplete);
                ToastManager.getInstance().showToast("Failed to start update process");
            }
            
        } catch (e) {
            ToastManager.getInstance().showToast("Error reading update metadata: " + e);
        }
    }
    
    /**
     * Handle completion of provisioner update
     */
    private function _onProvisionerUpdateComplete(event:SuperHumanApplicationEvent):Void {
        // Remove the listener
        this.removeEventListener(SuperHumanApplicationEvent.PROVISIONER_IMPORT_COMPLETE, _onProvisionerUpdateComplete);
        
        if (event.importSuccess) {
            ToastManager.getInstance().showToast("Provisioner updated successfully!");
            
            // Refresh the manage tab to show new version
            _refreshManageTab();
            
            // Dispatch event to update the application's provisioner cache
            var updateEvent = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.IMPORT_PROVISIONER);
            this.dispatchEvent(updateEvent);
        } else {
            ToastManager.getInstance().showToast("Update failed: " + event.importMessage);
        }
    }
    
    /**
     * Delete a provisioner type after confirmation
     */
    private function _deleteProvisionerType(provisionerType:String, serversUsing:Array<String>) {
        // Show confirmation dialog
        var confirmMessage = 'Are you sure you want to delete the provisioner "${provisionerType}"? This action cannot be undone.';
        
        feathers.controls.Alert.show(
            confirmMessage,
            'Delete ${provisionerType}',
            ["Delete", "Cancel"],
            function(state) {
                if (state.index == 0) {
                    // User confirmed deletion
                    var success = ProvisionerManager.deleteProvisioner(provisionerType);
                    
                    if (success) {
                        ToastManager.getInstance().showToast('Provisioner "${provisionerType}" deleted successfully');
                        
                        // Refresh the manage tab to remove the deleted provisioner
                        _refreshManageTab();
                        
                        // Dispatch event to update the application's provisioner cache
                        var deleteEvent = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.PROVISIONER_DELETED);
                        this.dispatchEvent(deleteEvent);
                    } else {
                        ToastManager.getInstance().showToast('Failed to delete provisioner "${provisionerType}"');
                    }
                }
            }
        );
    }

    /**
     * Get the current GitHub token for a provisioner
     */
    private function _getCurrentGitHubToken(provisionerType:String):String {
        try {
            var provisionersDir = ProvisionerManager.getProvisionersDirectory();
            var provisionerPath = haxe.io.Path.addTrailingSlash(provisionersDir) + provisionerType;
            var metadataPath = haxe.io.Path.addTrailingSlash(provisionerPath) + "provisioner-collection.yml";
            
            if (!sys.FileSystem.exists(metadataPath)) {
                return null;
            }
            
            var yamlMetadata = yaml.Yaml.read(metadataPath);
            var githubSource = null;
            
            if (Std.isOfType(yamlMetadata, yaml.util.ObjectMap)) {
                var objMap:yaml.util.ObjectMap<String, Dynamic> = cast yamlMetadata;
                if (objMap.exists("github_source")) {
                    githubSource = objMap.get("github_source");
                }
            } else if (Reflect.hasField(yamlMetadata, "github_source")) {
                githubSource = Reflect.field(yamlMetadata, "github_source");
            }
            
            if (githubSource != null) {
                var tokenName;
                
                if (Std.isOfType(githubSource, yaml.util.ObjectMap)) {
                    var sourceMap:yaml.util.ObjectMap<String, Dynamic> = cast githubSource;
                    tokenName = sourceMap.get("git_token_name");
                } else {
                    tokenName = Reflect.field(githubSource, "git_token_name");
                }
                
                return tokenName;
            }
            
            return null;
        } catch (e) {
            return null;
        }
    }
    
    /**
     * Update the GitHub token for a provisioner
     */
    private function _updateProvisionerGitHubToken(provisionerType:String, newTokenName:String):Bool {
        try {
            var provisionersDir = ProvisionerManager.getProvisionersDirectory();
            var provisionerPath = haxe.io.Path.addTrailingSlash(provisionersDir) + provisionerType;
            var metadataPath = haxe.io.Path.addTrailingSlash(provisionerPath) + "provisioner-collection.yml";
            
            if (!sys.FileSystem.exists(metadataPath)) {
                return false;
            }
            
            // Read current metadata
            var content = sys.io.File.getContent(metadataPath);
            
            // Update the git_token_name field using string replacement
            var lines = content.split("\n");
            var updatedLines = [];
            var foundGitTokenLine = false;
            
            for (line in lines) {
                if (line.indexOf("git_token_name:") >= 0) {
                    // Update the existing git_token_name line
                    updatedLines.push('  git_token_name: "${newTokenName}"');
                    foundGitTokenLine = true;
                } else {
                    updatedLines.push(line);
                }
            }
            
            // If no git_token_name line was found, we need to add it to the github_source section
            if (!foundGitTokenLine) {
                var newLines = [];
                var inGithubSource = false;
                
                for (line in lines) {
                    newLines.push(line);
                    
                    if (line.indexOf("github_source:") >= 0) {
                        inGithubSource = true;
                    } else if (inGithubSource && StringTools.trim(line) == "" || (line.indexOf(":") >= 0 && !StringTools.startsWith(line, "  "))) {
                        // End of github_source section, add the token line before this
                        if (StringTools.trim(line) != "") {
                            newLines.insert(newLines.length - 1, '  git_token_name: "${newTokenName}"');
                        } else {
                            newLines.push('  git_token_name: "${newTokenName}"');
                        }
                        inGithubSource = false;
                    }
                }
                
                // If we're still in github_source section at end of file
                if (inGithubSource) {
                    newLines.push('  git_token_name: "${newTokenName}"');
                }
                
                updatedLines = newLines;
            }
            
            // Write updated content back to file
            var updatedContent = updatedLines.join("\n");
            sys.io.File.saveContent(metadataPath, updatedContent);
            
            return true;
        } catch (e) {
            return false;
        }
    }

    /**
     * Close the management page
     */
    private function _closeImportPage() {
        this.dispatchEvent(new SuperHumanApplicationEvent(SuperHumanApplicationEvent.CLOSE_PROVISIONER_MANAGEMENT_PAGE));
    }
}
