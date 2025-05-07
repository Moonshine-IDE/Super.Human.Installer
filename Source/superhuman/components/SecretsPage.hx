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
import feathers.controls.Check;
import feathers.controls.Label;
import feathers.controls.TextInput;
import genesis.application.components.GenesisButton;
import genesis.application.components.GenesisFormCheckBox;
import feathers.controls.LayoutGroup;
import feathers.controls.ScrollContainer;
import genesis.application.components.GenesisFormTextInput;
import feathers.data.ArrayCollection;
import feathers.events.TriggerEvent;
import openfl.events.Event;
import feathers.layout.AnchorLayoutData;
import feathers.layout.HorizontalAlign;
import feathers.layout.HorizontalLayout;
import feathers.layout.HorizontalLayoutData;
import feathers.layout.VerticalAlign;
import feathers.layout.VerticalLayout;
import feathers.layout.VerticalLayoutData;
import genesis.application.components.GenesisForm;
import genesis.application.components.GenesisFormButton;
import genesis.application.components.GenesisFormRow;
import genesis.application.components.HLine;
import genesis.application.components.Page;
import genesis.application.managers.LanguageManager;
import genesis.application.managers.ToastManager;
import genesis.application.theme.GenesisApplicationTheme;
import superhuman.config.SuperHumanSecrets;
import superhuman.events.SuperHumanApplicationEvent;
import superhuman.theme.SuperHumanInstallerTheme;

class SecretsPage extends Page {

    final _width:Float = GenesisApplicationTheme.GRID * 140;

    var _buttonCancel:GenesisFormButton;
    var _buttonGroup:LayoutGroup;
    var _buttonGroupLayout:HorizontalLayout;
    var _buttonSave:GenesisFormButton;
    var _form:GenesisForm;
    var _label:Label;
    var _titleGroup:LayoutGroup;
    var _scrollContainer:ScrollContainer;

    // HCL Download Portal API Keys
    var _rowHclApiKeys:GenesisFormRow;
    var _hclApiKeysContainer:LayoutGroup;
    var _hclApiKeys:Array<HclApiKeyRow> = [];
    var _buttonAddHclApiKey:Button;
    var _buttonOpenHclPortal:GenesisButton;

    // Git API Keys
    var _rowGitApiKeys:GenesisFormRow;
    var _gitApiKeysContainer:LayoutGroup;
    var _gitApiKeys:Array<GitApiKeyRow> = [];
    var _buttonAddGitApiKey:Button;
    var _buttonOpenGitHub:GenesisButton;

    // Vagrant Atlas Token
    var _rowVagrantTokens:GenesisFormRow;
    var _vagrantTokensContainer:LayoutGroup;
    var _vagrantTokens:Array<VagrantTokenRow> = [];
    var _buttonAddVagrantToken:Button;
    var _buttonOpenHashiCorp:GenesisButton;
    var _buttonOpenBoxVault:GenesisButton;

    // Custom Resource URL
    var _rowCustomResources:GenesisFormRow;
    var _customResourcesContainer:LayoutGroup;
    var _customResources:Array<CustomResourceRow> = [];
    var _buttonAddCustomResource:Button;

    // Docker Hub
    var _rowDockerHub:GenesisFormRow;
    var _dockerHubContainer:LayoutGroup;
    var _dockerHubCredentials:Array<DockerHubRow> = [];
    var _buttonAddDockerHub:Button;
    var _buttonOpenDockerHub:GenesisButton;
    
    // SSH Keys
    var _rowSSHKeys:GenesisFormRow;
    var _sshKeysContainer:LayoutGroup;
    var _sshKeys:Array<SSHKeyRow> = [];
    var _buttonAddSSHKey:Button;
    var _buttonOpenSSHDocs:GenesisButton;

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
        _titleGroupLayout.horizontalAlign = HorizontalAlign.CENTER;
        _titleGroupLayout.verticalAlign = VerticalAlign.MIDDLE;
        _titleGroup.layout = _titleGroupLayout;
        _titleGroup.width = _width;
        this.addChild(_titleGroup);

        _label = new Label();
        _label.text = "Global Secrets";
        _label.variant = GenesisApplicationTheme.LABEL_LARGE;
        _label.layoutData = new HorizontalLayoutData(100);
        _titleGroup.addChild(_label);

        var line = new HLine();
        line.width = _width;
        this.addChild(line);

        // Create a scroll container for the content
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
        scrollLayout.paddingRight = GenesisApplicationTheme.GRID * 3; // Extra padding on right side for scrollbar
        _scrollContainer.layout = scrollLayout;
        
        // Add the scroll container to the page
        this.addChild(_scrollContainer);

        _form = new GenesisForm();
        _form.layoutData = new VerticalLayoutData(90, null);
        // Set form layout properties
        var formLayout = new VerticalLayout();
        formLayout.horizontalAlign = HorizontalAlign.CENTER;
        formLayout.verticalAlign = VerticalAlign.TOP;
        formLayout.gap = GenesisApplicationTheme.GRID;
        _form.layout = formLayout;
        
        _scrollContainer.addChild(_form);

        // Set up vertical layouts for all form rows
        var setupFormRow = function(row:GenesisFormRow, title:String) {
            // Set the text property for the left column label
            row.text = title;
            // Use vertical layout for the content
            var contentLayout = new VerticalLayout();
            contentLayout.gap = GenesisApplicationTheme.GRID;
            contentLayout.horizontalAlign = HorizontalAlign.LEFT;
            row.content.layout = contentLayout;
        };

        // HCL Download Portal API Keys
        _rowHclApiKeys = new GenesisFormRow();
        _form.addChild(_rowHclApiKeys);
        
        // Set the column widths
        var label = cast(_rowHclApiKeys.getChildAt(0), feathers.core.FeathersControl);
        var content = cast(_rowHclApiKeys.getChildAt(1), feathers.core.FeathersControl);
        if (label != null) label.layoutData = new HorizontalLayoutData(40); // Increase from 35% to 40%
        if (content != null) content.layoutData = new HorizontalLayoutData(60); // Decrease from 65% to 60%
        
        // Create a custom label container with vertical layout
        var labelContainer = new LayoutGroup();
        var labelVerticalLayout = new VerticalLayout();
        labelVerticalLayout.gap = GenesisApplicationTheme.GRID;
        labelVerticalLayout.horizontalAlign = HorizontalAlign.LEFT;
        labelContainer.layout = labelVerticalLayout;
        
        // Create header row with title and add button
        var headerRow = new LayoutGroup();
        var headerLayout = new HorizontalLayout();
        headerLayout.horizontalAlign = HorizontalAlign.LEFT;
        headerLayout.verticalAlign = VerticalAlign.MIDDLE;
        headerLayout.gap = GenesisApplicationTheme.GRID;
        headerRow.layout = headerLayout;
        
        // Create the text label
        var textLabel = new Label();
        textLabel.text = "HCL Download Portal API Keys";
        textLabel.width = GenesisApplicationTheme.GRID * 35; // Increased width for better display
        
        // Create add button
        _buttonAddHclApiKey = new Button();
        _buttonAddHclApiKey.icon = GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_ADD);
        _buttonAddHclApiKey.setPadding(0);
        _buttonAddHclApiKey.width = GenesisApplicationTheme.GRID * 3;
        _buttonAddHclApiKey.height = GenesisApplicationTheme.GRID * 3;
        _buttonAddHclApiKey.addEventListener(TriggerEvent.TRIGGER, _addHclApiKey);
        _buttonAddHclApiKey.toolTip = "Add HCL API Key";
        
        // Add text and button to header row
        headerRow.addChild(textLabel);
        headerRow.addChild(_buttonAddHclApiKey);
        
        // Add header row to label container
        labelContainer.addChild(headerRow);
        
        // Create row for web link with icon button and label
        var hclWebLinkRow = new LayoutGroup();
        var hclWebLinkLayout = new HorizontalLayout();
        hclWebLinkLayout.horizontalAlign = HorizontalAlign.LEFT;
        hclWebLinkLayout.verticalAlign = VerticalAlign.MIDDLE;
        hclWebLinkLayout.gap = GenesisApplicationTheme.GRID;
        hclWebLinkRow.layout = hclWebLinkLayout;
        
        // Create button with only icon (no text)
        _buttonOpenHclPortal = new GenesisButton();
        _buttonOpenHclPortal.icon = GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_WEB);
        _buttonOpenHclPortal.text = ""; // Remove text
        _buttonOpenHclPortal.setPadding(0); // Reduce padding for icon-only button
        _buttonOpenHclPortal.width = GenesisApplicationTheme.GRID * 3; // Set fixed width
        _buttonOpenHclPortal.height = GenesisApplicationTheme.GRID * 3; // Set fixed height
        _buttonOpenHclPortal.addEventListener(TriggerEvent.TRIGGER, _buttonOpenHclPortalTriggered);
        _buttonOpenHclPortal.toolTip = "Open HCL Download Portal";
        
        // Create label for link description
        var hclLinkLabel = new Label();
        hclLinkLabel.text = "HCL Software Portal";
        hclLinkLabel.width = GenesisApplicationTheme.GRID * 30;
        
        // Add button and label to row
        hclWebLinkRow.addChild(_buttonOpenHclPortal);
        hclWebLinkRow.addChild(hclLinkLabel);
        
        // Add row to label container
        labelContainer.addChild(hclWebLinkRow);
        
        // Replace the default label with our custom container
        _rowHclApiKeys.removeChildAt(0);
        _rowHclApiKeys.addChildAt(labelContainer, 0);
        cast(labelContainer, feathers.core.FeathersControl).layoutData = new HorizontalLayoutData(40);
        
        // Container for HCL API Key entries
        _hclApiKeysContainer = new LayoutGroup();
        var hclLayout = new VerticalLayout();
        hclLayout.gap = GenesisApplicationTheme.GRID;
        hclLayout.horizontalAlign = HorizontalAlign.LEFT;
        _hclApiKeysContainer.layout = hclLayout;
        _hclApiKeysContainer.width = _width - GenesisApplicationTheme.GRID * 30; // Reduce width to fit in column
        
        // Create a vertical layout for the content area
        var contentLayout = new VerticalLayout();
        contentLayout.gap = GenesisApplicationTheme.GRID;
        contentLayout.horizontalAlign = HorizontalAlign.LEFT;
        contentLayout.paddingTop = 0;
        contentLayout.paddingBottom = 0;
        contentLayout.paddingLeft = 0;
        contentLayout.paddingRight = 0;
        _rowHclApiKeys.content.layout = contentLayout;
        
        // Add entries container to content
        _rowHclApiKeys.content.addChild(_hclApiKeysContainer);

        // No need for the separate button container anymore

        // Add a separator line
        var separator1 = new HLine();
        separator1.width = _width - GenesisApplicationTheme.GRID * 4;
        _form.addChild(separator1);

        // Git Tokens
        _rowGitApiKeys = new GenesisFormRow();
        _form.addChild(_rowGitApiKeys);
        
        // Set the column widths
        var gitLabel = cast(_rowGitApiKeys.getChildAt(0), feathers.core.FeathersControl);
        var gitContent = cast(_rowGitApiKeys.getChildAt(1), feathers.core.FeathersControl);
        if (gitLabel != null) gitLabel.layoutData = new HorizontalLayoutData(40);
        if (gitContent != null) gitContent.layoutData = new HorizontalLayoutData(60);
        
        // Create a custom label container with vertical layout
        var gitLabelContainer = new LayoutGroup();
        var gitLabelVerticalLayout = new VerticalLayout();
        gitLabelVerticalLayout.gap = GenesisApplicationTheme.GRID;
        gitLabelVerticalLayout.horizontalAlign = HorizontalAlign.LEFT;
        gitLabelContainer.layout = gitLabelVerticalLayout;
        
        // Create header row with title and add button
        var gitHeaderRow = new LayoutGroup();
        var gitHeaderLayout = new HorizontalLayout();
        gitHeaderLayout.horizontalAlign = HorizontalAlign.LEFT;
        gitHeaderLayout.verticalAlign = VerticalAlign.MIDDLE;
        gitHeaderLayout.gap = GenesisApplicationTheme.GRID;
        gitHeaderRow.layout = gitHeaderLayout;
        
        // Create the text label
        var gitTextLabel = new Label();
        gitTextLabel.text = "Git Tokens";
        gitTextLabel.width = GenesisApplicationTheme.GRID * 35; // Increased width for better display
        
        // Create add button
        _buttonAddGitApiKey = new Button();
        _buttonAddGitApiKey.icon = GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_ADD);
        _buttonAddGitApiKey.setPadding(0);
        _buttonAddGitApiKey.width = GenesisApplicationTheme.GRID * 3;
        _buttonAddGitApiKey.height = GenesisApplicationTheme.GRID * 3;
        _buttonAddGitApiKey.addEventListener(TriggerEvent.TRIGGER, _addGitApiKey);
        _buttonAddGitApiKey.toolTip = "Add Git Token";
        
        // Add text and button to header row
        gitHeaderRow.addChild(gitTextLabel);
        gitHeaderRow.addChild(_buttonAddGitApiKey);
        
        // Add header row to label container
        gitLabelContainer.addChild(gitHeaderRow);
        
        // Create row for web link with icon button and label
        var gitWebLinkRow = new LayoutGroup();
        var gitWebLinkLayout = new HorizontalLayout();
        gitWebLinkLayout.horizontalAlign = HorizontalAlign.LEFT;
        gitWebLinkLayout.verticalAlign = VerticalAlign.MIDDLE;
        gitWebLinkLayout.gap = GenesisApplicationTheme.GRID;
        gitWebLinkRow.layout = gitWebLinkLayout;
        
        // Create button with only icon (no text)
        _buttonOpenGitHub = new GenesisButton();
        _buttonOpenGitHub.icon = GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_WEB);
        _buttonOpenGitHub.text = ""; // Remove text
        _buttonOpenGitHub.setPadding(0); // Reduce padding for icon-only button
        _buttonOpenGitHub.width = GenesisApplicationTheme.GRID * 3; // Set fixed width
        _buttonOpenGitHub.height = GenesisApplicationTheme.GRID * 3; // Set fixed height
        _buttonOpenGitHub.addEventListener(TriggerEvent.TRIGGER, _buttonOpenGitHubTriggered);
        _buttonOpenGitHub.toolTip = "Open GitHub Tokens Page";
        
        // Create label for link description
        var gitLinkLabel = new Label();
        gitLinkLabel.text = "GitHub";
        gitLinkLabel.width = GenesisApplicationTheme.GRID * 30;
        
        // Add button and label to row
        gitWebLinkRow.addChild(_buttonOpenGitHub);
        gitWebLinkRow.addChild(gitLinkLabel);
        
        // Add row to label container
        gitLabelContainer.addChild(gitWebLinkRow);
        
        // Replace the default label with our custom container
        _rowGitApiKeys.removeChildAt(0);
        _rowGitApiKeys.addChildAt(gitLabelContainer, 0);
        cast(gitLabelContainer, feathers.core.FeathersControl).layoutData = new HorizontalLayoutData(40);
        
        // Container for Git API Key entries
        _gitApiKeysContainer = new LayoutGroup();
        var gitLayout = new VerticalLayout();
        gitLayout.gap = GenesisApplicationTheme.GRID;
        gitLayout.horizontalAlign = HorizontalAlign.LEFT;
        _gitApiKeysContainer.layout = gitLayout;
        _gitApiKeysContainer.width = _width - GenesisApplicationTheme.GRID * 30;
        
        // Create a vertical layout for the content area
        var gitContentLayout = new VerticalLayout();
        gitContentLayout.gap = GenesisApplicationTheme.GRID;
        gitContentLayout.horizontalAlign = HorizontalAlign.LEFT;
        gitContentLayout.paddingTop = 0;
        gitContentLayout.paddingBottom = 0;
        gitContentLayout.paddingLeft = 0;
        gitContentLayout.paddingRight = 0;
        _rowGitApiKeys.content.layout = gitContentLayout;
        
        // Add entries container to content
        _rowGitApiKeys.content.addChild(_gitApiKeysContainer);

        // No need for the separate button container anymore

        // Add a separator line
        var separator2 = new HLine();
        separator2.width = _width - GenesisApplicationTheme.GRID * 4;
        _form.addChild(separator2);

        // Vagrant Atlas Tokens
        _rowVagrantTokens = new GenesisFormRow();
        _form.addChild(_rowVagrantTokens);
        
        // Set the column widths
        var vagrantLabel = cast(_rowVagrantTokens.getChildAt(0), feathers.core.FeathersControl);
        var vagrantContent = cast(_rowVagrantTokens.getChildAt(1), feathers.core.FeathersControl);
        if (vagrantLabel != null) vagrantLabel.layoutData = new HorizontalLayoutData(40);
        if (vagrantContent != null) vagrantContent.layoutData = new HorizontalLayoutData(60);
        
        // Create a custom label container with vertical layout
        var vagrantLabelContainer = new LayoutGroup();
        var vagrantLabelVerticalLayout = new VerticalLayout();
        vagrantLabelVerticalLayout.gap = GenesisApplicationTheme.GRID;
        vagrantLabelVerticalLayout.horizontalAlign = HorizontalAlign.LEFT;
        vagrantLabelContainer.layout = vagrantLabelVerticalLayout;
        
        // Create header row with title and add button
        var vagrantHeaderRow = new LayoutGroup();
        var vagrantHeaderLayout = new HorizontalLayout();
        vagrantHeaderLayout.horizontalAlign = HorizontalAlign.LEFT;
        vagrantHeaderLayout.verticalAlign = VerticalAlign.MIDDLE;
        vagrantHeaderLayout.gap = GenesisApplicationTheme.GRID;
        vagrantHeaderRow.layout = vagrantHeaderLayout;
        
        // Create the text label
        var vagrantTextLabel = new Label();
        vagrantTextLabel.text = "Vagrant Atlas Tokens";
        vagrantTextLabel.width = GenesisApplicationTheme.GRID * 35; // Increased width for better display
        
        // Create add button
        _buttonAddVagrantToken = new Button();
        _buttonAddVagrantToken.icon = GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_ADD);
        _buttonAddVagrantToken.setPadding(0);
        _buttonAddVagrantToken.width = GenesisApplicationTheme.GRID * 3;
        _buttonAddVagrantToken.height = GenesisApplicationTheme.GRID * 3;
        _buttonAddVagrantToken.addEventListener(TriggerEvent.TRIGGER, _addVagrantToken);
        _buttonAddVagrantToken.toolTip = "Add Vagrant Token";
        
        // Add text and button to header row
        vagrantHeaderRow.addChild(vagrantTextLabel);
        vagrantHeaderRow.addChild(_buttonAddVagrantToken);
        
        // Add header row to label container
        vagrantLabelContainer.addChild(vagrantHeaderRow);
        
        // Create row for HashiCorp link
        var hashiCorpWebLinkRow = new LayoutGroup();
        var hashiCorpWebLinkLayout = new HorizontalLayout();
        hashiCorpWebLinkLayout.horizontalAlign = HorizontalAlign.LEFT;
        hashiCorpWebLinkLayout.verticalAlign = VerticalAlign.MIDDLE;
        hashiCorpWebLinkLayout.gap = GenesisApplicationTheme.GRID;
        hashiCorpWebLinkRow.layout = hashiCorpWebLinkLayout;
        
        // Create HashiCorp button with only icon
        _buttonOpenHashiCorp = new GenesisButton();
        _buttonOpenHashiCorp.icon = GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_WEB);
        _buttonOpenHashiCorp.text = ""; // Remove text
        _buttonOpenHashiCorp.setPadding(0); // Reduce padding for icon-only button
        _buttonOpenHashiCorp.width = GenesisApplicationTheme.GRID * 3; // Set fixed width
        _buttonOpenHashiCorp.height = GenesisApplicationTheme.GRID * 3; // Set fixed height
        _buttonOpenHashiCorp.addEventListener(TriggerEvent.TRIGGER, _buttonOpenHashiCorpTriggered);
        _buttonOpenHashiCorp.toolTip = "Open HashiCorp Cloud Portal";
        
        // Create label for HashiCorp link
        var hashiCorpLinkLabel = new Label();
        hashiCorpLinkLabel.text = "HashiCorp Cloud";
        hashiCorpLinkLabel.width = GenesisApplicationTheme.GRID * 30;
        
        // Add HashiCorp button and label to row
        hashiCorpWebLinkRow.addChild(_buttonOpenHashiCorp);
        hashiCorpWebLinkRow.addChild(hashiCorpLinkLabel);
        
        // Create row for BoxVault link
        var boxVaultWebLinkRow = new LayoutGroup();
        var boxVaultWebLinkLayout = new HorizontalLayout();
        boxVaultWebLinkLayout.horizontalAlign = HorizontalAlign.LEFT;
        boxVaultWebLinkLayout.verticalAlign = VerticalAlign.MIDDLE;
        boxVaultWebLinkLayout.gap = GenesisApplicationTheme.GRID;
        boxVaultWebLinkRow.layout = boxVaultWebLinkLayout;
        
        // Create BoxVault button with only icon
        _buttonOpenBoxVault = new GenesisButton();
        _buttonOpenBoxVault.icon = GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_WEB);
        _buttonOpenBoxVault.text = ""; // Remove text
        _buttonOpenBoxVault.setPadding(0); // Reduce padding for icon-only button
        _buttonOpenBoxVault.width = GenesisApplicationTheme.GRID * 3; // Set fixed width
        _buttonOpenBoxVault.height = GenesisApplicationTheme.GRID * 3; // Set fixed height
        _buttonOpenBoxVault.addEventListener(TriggerEvent.TRIGGER, _buttonOpenBoxVaultTriggered);
        _buttonOpenBoxVault.toolTip = "Open BoxVault Portal";
        
        // Create label for BoxVault link
        var boxVaultLinkLabel = new Label();
        boxVaultLinkLabel.text = "BoxVault";
        boxVaultLinkLabel.width = GenesisApplicationTheme.GRID * 30;
        
        // Add BoxVault button and label to row
        boxVaultWebLinkRow.addChild(_buttonOpenBoxVault);
        boxVaultWebLinkRow.addChild(boxVaultLinkLabel);
        
        // Add rows to label container
        vagrantLabelContainer.addChild(hashiCorpWebLinkRow);
        vagrantLabelContainer.addChild(boxVaultWebLinkRow);
        
        // Replace the default label with our custom container
        _rowVagrantTokens.removeChildAt(0);
        _rowVagrantTokens.addChildAt(vagrantLabelContainer, 0);
        cast(vagrantLabelContainer, feathers.core.FeathersControl).layoutData = new HorizontalLayoutData(40);
        
        // Container for Vagrant token entries
        _vagrantTokensContainer = new LayoutGroup();
        var vagrantLayout = new VerticalLayout();
        vagrantLayout.gap = GenesisApplicationTheme.GRID;
        vagrantLayout.horizontalAlign = HorizontalAlign.LEFT;
        _vagrantTokensContainer.layout = vagrantLayout;
        _vagrantTokensContainer.width = _width - GenesisApplicationTheme.GRID * 30;
        
        // Create a vertical layout for the content area
        var vagrantContentLayout = new VerticalLayout();
        vagrantContentLayout.gap = GenesisApplicationTheme.GRID;
        vagrantContentLayout.horizontalAlign = HorizontalAlign.LEFT;
        vagrantContentLayout.paddingTop = 0;
        vagrantContentLayout.paddingBottom = 0;
        vagrantContentLayout.paddingLeft = 0;
        vagrantContentLayout.paddingRight = 0;
        _rowVagrantTokens.content.layout = vagrantContentLayout;
        
        // Add entries container to content
        _rowVagrantTokens.content.addChild(_vagrantTokensContainer);

        // No need for the separate button containers anymore

        // Add a separator line
        var separator3 = new HLine();
        separator3.width = _width - GenesisApplicationTheme.GRID * 4;
        _form.addChild(separator3);

        // Custom Resource URLs
        _rowCustomResources = new GenesisFormRow();
        _form.addChild(_rowCustomResources);
        
        // Set the column widths
        var resourceLabel = cast(_rowCustomResources.getChildAt(0), feathers.core.FeathersControl);
        var resourceContent = cast(_rowCustomResources.getChildAt(1), feathers.core.FeathersControl);
        if (resourceLabel != null) resourceLabel.layoutData = new HorizontalLayoutData(40);
        if (resourceContent != null) resourceContent.layoutData = new HorizontalLayoutData(60);
        
        // Create a custom label container with text + add button
        var resourceLabelContainer = new LayoutGroup();
        var resourceLabelLayout = new HorizontalLayout();
        resourceLabelLayout.horizontalAlign = HorizontalAlign.LEFT;
        resourceLabelLayout.verticalAlign = VerticalAlign.MIDDLE;
        resourceLabelLayout.gap = GenesisApplicationTheme.GRID;
        resourceLabelContainer.layout = resourceLabelLayout;
        
        // Create the text label
        var resourceTextLabel = new Label();
        resourceTextLabel.text = "Custom Resource URLs";
        resourceTextLabel.width = GenesisApplicationTheme.GRID * 35; // Increased width for better display
        
        // Create add button
        _buttonAddCustomResource = new Button();
        _buttonAddCustomResource.icon = GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_ADD);
        _buttonAddCustomResource.setPadding(0);
        _buttonAddCustomResource.width = GenesisApplicationTheme.GRID * 3;
        _buttonAddCustomResource.height = GenesisApplicationTheme.GRID * 3;
        _buttonAddCustomResource.addEventListener(TriggerEvent.TRIGGER, _addCustomResource);
        _buttonAddCustomResource.toolTip = "Add Custom Resource";
        
        // Add text and button to label container
        resourceLabelContainer.addChild(resourceTextLabel);
        resourceLabelContainer.addChild(_buttonAddCustomResource);
        
        // Replace the default label with our custom container
        _rowCustomResources.removeChildAt(0);
        _rowCustomResources.addChildAt(resourceLabelContainer, 0);
        cast(resourceLabelContainer, feathers.core.FeathersControl).layoutData = new HorizontalLayoutData(40);
        
        // Container for Custom Resource entries
        _customResourcesContainer = new LayoutGroup();
        var customResourceLayout = new VerticalLayout();
        customResourceLayout.gap = GenesisApplicationTheme.GRID;
        customResourceLayout.horizontalAlign = HorizontalAlign.LEFT;
        _customResourcesContainer.layout = customResourceLayout;
        _customResourcesContainer.width = _width - GenesisApplicationTheme.GRID * 30;
        
        // Create a vertical layout for the content area
        var resourceContentLayout = new VerticalLayout();
        resourceContentLayout.gap = GenesisApplicationTheme.GRID;
        resourceContentLayout.horizontalAlign = HorizontalAlign.LEFT;
        resourceContentLayout.paddingTop = 0;
        resourceContentLayout.paddingBottom = 0;
        resourceContentLayout.paddingLeft = 0;
        resourceContentLayout.paddingRight = 0;
        _rowCustomResources.content.layout = resourceContentLayout;
        
        // Add entries container to content
        _rowCustomResources.content.addChild(_customResourcesContainer);

        // Add a separator line
        var separator4 = new HLine();
        separator4.width = _width - GenesisApplicationTheme.GRID * 4;
        _form.addChild(separator4);

        // Docker Hub Credentials
        _rowDockerHub = new GenesisFormRow();
        _form.addChild(_rowDockerHub);
        
        // Set the column widths
        var dockerLabel = cast(_rowDockerHub.getChildAt(0), feathers.core.FeathersControl);
        var dockerContent = cast(_rowDockerHub.getChildAt(1), feathers.core.FeathersControl);
        if (dockerLabel != null) dockerLabel.layoutData = new HorizontalLayoutData(40);
        if (dockerContent != null) dockerContent.layoutData = new HorizontalLayoutData(60);
        
        // Create a custom label container with vertical layout
        var dockerLabelContainer = new LayoutGroup();
        var dockerLabelVerticalLayout = new VerticalLayout();
        dockerLabelVerticalLayout.gap = GenesisApplicationTheme.GRID;
        dockerLabelVerticalLayout.horizontalAlign = HorizontalAlign.LEFT;
        dockerLabelContainer.layout = dockerLabelVerticalLayout;
        
        // Create header row with title and add button
        var dockerHeaderRow = new LayoutGroup();
        var dockerHeaderLayout = new HorizontalLayout();
        dockerHeaderLayout.horizontalAlign = HorizontalAlign.LEFT;
        dockerHeaderLayout.verticalAlign = VerticalAlign.MIDDLE;
        dockerHeaderLayout.gap = GenesisApplicationTheme.GRID;
        dockerHeaderRow.layout = dockerHeaderLayout;
        
        // Create the text label
        var dockerTextLabel = new Label();
        dockerTextLabel.text = "Docker Hub Credentials";
        dockerTextLabel.width = GenesisApplicationTheme.GRID * 35; // Increased width for better display
        
        // Create add button
        _buttonAddDockerHub = new Button();
        _buttonAddDockerHub.icon = GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_ADD);
        _buttonAddDockerHub.setPadding(0);
        _buttonAddDockerHub.width = GenesisApplicationTheme.GRID * 3;
        _buttonAddDockerHub.height = GenesisApplicationTheme.GRID * 3;
        _buttonAddDockerHub.addEventListener(TriggerEvent.TRIGGER, _addDockerHub);
        _buttonAddDockerHub.toolTip = "Add Docker Hub Credential";
        
        // Add text and button to header row
        dockerHeaderRow.addChild(dockerTextLabel);
        dockerHeaderRow.addChild(_buttonAddDockerHub);
        
        // Add header row to label container
        dockerLabelContainer.addChild(dockerHeaderRow);
        
        // Create row for Docker Hub link
        var dockerWebLinkRow = new LayoutGroup();
        var dockerWebLinkLayout = new HorizontalLayout();
        dockerWebLinkLayout.horizontalAlign = HorizontalAlign.LEFT;
        dockerWebLinkLayout.verticalAlign = VerticalAlign.MIDDLE;
        dockerWebLinkLayout.gap = GenesisApplicationTheme.GRID;
        dockerWebLinkRow.layout = dockerWebLinkLayout;
        
        // Create button with only icon (no text)
        _buttonOpenDockerHub = new GenesisButton();
        _buttonOpenDockerHub.icon = GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_WEB);
        _buttonOpenDockerHub.text = ""; // Remove text
        _buttonOpenDockerHub.setPadding(0); // Reduce padding for icon-only button
        _buttonOpenDockerHub.width = GenesisApplicationTheme.GRID * 3; // Set fixed width
        _buttonOpenDockerHub.height = GenesisApplicationTheme.GRID * 3; // Set fixed height
        _buttonOpenDockerHub.addEventListener(TriggerEvent.TRIGGER, _buttonOpenDockerHubTriggered);
        _buttonOpenDockerHub.toolTip = "Open Docker Hub Tokens Page";
        
        // Create label for link description
        var dockerLinkLabel = new Label();
        dockerLinkLabel.text = "Docker";
        dockerLinkLabel.width = GenesisApplicationTheme.GRID * 30;
        
        // Add button and label to row
        dockerWebLinkRow.addChild(_buttonOpenDockerHub);
        dockerWebLinkRow.addChild(dockerLinkLabel);
        
        // Add row to label container
        dockerLabelContainer.addChild(dockerWebLinkRow);
        
        // Replace the default label with our custom container
        _rowDockerHub.removeChildAt(0);
        _rowDockerHub.addChildAt(dockerLabelContainer, 0);
        cast(dockerLabelContainer, feathers.core.FeathersControl).layoutData = new HorizontalLayoutData(40);
        
        // Container for Docker Hub entries
        _dockerHubContainer = new LayoutGroup();
        var dockerHubLayout = new VerticalLayout();
        dockerHubLayout.gap = GenesisApplicationTheme.GRID;
        dockerHubLayout.horizontalAlign = HorizontalAlign.LEFT;
        _dockerHubContainer.layout = dockerHubLayout;
        _dockerHubContainer.width = _width - GenesisApplicationTheme.GRID * 30;
        
        // Create a vertical layout for the content area
        var dockerContentLayout = new VerticalLayout();
        dockerContentLayout.gap = GenesisApplicationTheme.GRID;
        dockerContentLayout.horizontalAlign = HorizontalAlign.LEFT;
        dockerContentLayout.paddingTop = 0;
        dockerContentLayout.paddingBottom = 0;
        dockerContentLayout.paddingLeft = 0;
        dockerContentLayout.paddingRight = 0;
        _rowDockerHub.content.layout = dockerContentLayout;
        
        // Add entries container to content
        _rowDockerHub.content.addChild(_dockerHubContainer);

        // No need for the separate button container anymore

        // Add a separator line
        var separator5 = new HLine();
        separator5.width = _width - GenesisApplicationTheme.GRID * 4;
        _form.addChild(separator5);

        // SSH Keys
        _rowSSHKeys = new GenesisFormRow();
        _form.addChild(_rowSSHKeys);
        
        // Set the column widths
        var sshLabel = cast(_rowSSHKeys.getChildAt(0), feathers.core.FeathersControl);
        var sshContent = cast(_rowSSHKeys.getChildAt(1), feathers.core.FeathersControl);
        if (sshLabel != null) sshLabel.layoutData = new HorizontalLayoutData(40);
        if (sshContent != null) sshContent.layoutData = new HorizontalLayoutData(60);
        
        // Create a custom label container with vertical layout
        var sshLabelContainer = new LayoutGroup();
        var sshLabelVerticalLayout = new VerticalLayout();
        sshLabelVerticalLayout.gap = GenesisApplicationTheme.GRID;
        sshLabelVerticalLayout.horizontalAlign = HorizontalAlign.LEFT;
        sshLabelContainer.layout = sshLabelVerticalLayout;
        
        // Create header row with title and add button
        var sshHeaderRow = new LayoutGroup();
        var sshHeaderLayout = new HorizontalLayout();
        sshHeaderLayout.horizontalAlign = HorizontalAlign.LEFT;
        sshHeaderLayout.verticalAlign = VerticalAlign.MIDDLE;
        sshHeaderLayout.gap = GenesisApplicationTheme.GRID;
        sshHeaderRow.layout = sshHeaderLayout;
        
        // Create the text label
        var sshTextLabel = new Label();
        sshTextLabel.text = "SSH Keys";
        sshTextLabel.width = GenesisApplicationTheme.GRID * 35; // Increased width for better display
        
        // Create add button
        _buttonAddSSHKey = new Button();
        _buttonAddSSHKey.icon = GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_ADD);
        _buttonAddSSHKey.setPadding(0);
        _buttonAddSSHKey.width = GenesisApplicationTheme.GRID * 3;
        _buttonAddSSHKey.height = GenesisApplicationTheme.GRID * 3;
        _buttonAddSSHKey.addEventListener(TriggerEvent.TRIGGER, _addSSHKey);
        _buttonAddSSHKey.toolTip = "Add SSH Key";
        
        // Add text and button to header row
        sshHeaderRow.addChild(sshTextLabel);
        sshHeaderRow.addChild(_buttonAddSSHKey);
        
        // Add header row to label container
        sshLabelContainer.addChild(sshHeaderRow);
        
        // Create row for GitHub SSH Keys documentation link
        var sshWebLinkRow = new LayoutGroup();
        var sshWebLinkLayout = new HorizontalLayout();
        sshWebLinkLayout.horizontalAlign = HorizontalAlign.LEFT;
        sshWebLinkLayout.verticalAlign = VerticalAlign.MIDDLE;
        sshWebLinkLayout.gap = GenesisApplicationTheme.GRID;
        sshWebLinkRow.layout = sshWebLinkLayout;
        
        // Create button with only icon (no text)
        _buttonOpenSSHDocs = new GenesisButton();
        _buttonOpenSSHDocs.icon = GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_WEB);
        _buttonOpenSSHDocs.text = ""; // Remove text
        _buttonOpenSSHDocs.setPadding(0); // Reduce padding for icon-only button
        _buttonOpenSSHDocs.width = GenesisApplicationTheme.GRID * 3; // Set fixed width
        _buttonOpenSSHDocs.height = GenesisApplicationTheme.GRID * 3; // Set fixed height
        _buttonOpenSSHDocs.addEventListener(TriggerEvent.TRIGGER, _buttonOpenSSHDocsTriggered);
        _buttonOpenSSHDocs.toolTip = "Open GitHub SSH Keys Documentation";
        
        // Create label for link description
        var sshLinkLabel = new Label();
        sshLinkLabel.text = "GitHub SSH Documentation";
        sshLinkLabel.width = GenesisApplicationTheme.GRID * 30;
        
        // Add button and label to row
        sshWebLinkRow.addChild(_buttonOpenSSHDocs);
        sshWebLinkRow.addChild(sshLinkLabel);
        
        // Add row to label container
        sshLabelContainer.addChild(sshWebLinkRow);
        
        // Replace the default label with our custom container
        _rowSSHKeys.removeChildAt(0);
        _rowSSHKeys.addChildAt(sshLabelContainer, 0);
        cast(sshLabelContainer, feathers.core.FeathersControl).layoutData = new HorizontalLayoutData(40);
        
        // Container for SSH Key entries
        _sshKeysContainer = new LayoutGroup();
        var sshLayout = new VerticalLayout();
        sshLayout.gap = GenesisApplicationTheme.GRID;
        sshLayout.horizontalAlign = HorizontalAlign.LEFT;
        _sshKeysContainer.layout = sshLayout;
        _sshKeysContainer.width = _width - GenesisApplicationTheme.GRID * 30;
        
        // Create a vertical layout for the content area
        var sshContentLayout = new VerticalLayout();
        sshContentLayout.gap = GenesisApplicationTheme.GRID;
        sshContentLayout.horizontalAlign = HorizontalAlign.LEFT;
        sshContentLayout.paddingTop = 0;
        sshContentLayout.paddingBottom = 0;
        sshContentLayout.paddingLeft = 0;
        sshContentLayout.paddingRight = 0;
        _rowSSHKeys.content.layout = sshContentLayout;
        
        // Add entries container to content
        _rowSSHKeys.content.addChild(_sshKeysContainer);

        // Add bottom line and buttons outside the scroll container
        var bottomLine = new HLine();
        bottomLine.width = _width;
        this.addChild(bottomLine);

        // Save/Cancel buttons
        _buttonGroup = new LayoutGroup();
        _buttonGroupLayout = new HorizontalLayout();
        _buttonGroupLayout.gap = GenesisApplicationTheme.GRID * 2;
        _buttonGroupLayout.horizontalAlign = HorizontalAlign.CENTER;
        _buttonGroup.layout = _buttonGroupLayout;
        _buttonSave = new GenesisFormButton("Save");
        _buttonSave.addEventListener(TriggerEvent.TRIGGER, _saveButtonTriggered);
        _buttonSave.width = GenesisApplicationTheme.GRID * 20;
        _buttonCancel = new GenesisFormButton("Cancel");
        _buttonCancel.addEventListener(TriggerEvent.TRIGGER, _cancel);
        _buttonCancel.width = GenesisApplicationTheme.GRID * 20;
        _buttonGroup.addChild(_buttonSave);
        _buttonGroup.addChild(_buttonCancel);
        this.addChild(_buttonGroup);

        // Load data
        updateData();
    }

    public function updateData() {
        // Clear existing rows
        _clearRows();

        // Get the secrets from the configuration
        var secrets = SuperHumanInstaller.getInstance().config.secrets;
        if (secrets == null) return;

        // Load HCL API Keys
        if (secrets.hcl_download_portal_api_keys != null) {
            for (apiKey in secrets.hcl_download_portal_api_keys) {
                _addHclApiKeyRow(apiKey.name, apiKey.key);
            }
        }

        // Load Git API Keys
        if (secrets.git_api_keys != null) {
            for (apiKey in secrets.git_api_keys) {
                _addGitApiKeyRow(apiKey.name, apiKey.key);
            }
        }

        // Load Vagrant Tokens
        if (secrets.vagrant_atlas_token != null) {
            for (token in secrets.vagrant_atlas_token) {
                _addVagrantTokenRow(token.name, token.key);
            }
        }

        // Load Custom Resources
        if (secrets.custom_resource_url != null) {
            for (resource in secrets.custom_resource_url) {
                _addCustomResourceRow(resource.name, resource.url, resource.useAuth, resource.user, resource.pass);
            }
        }

        // Load Docker Hub Credentials
        if (secrets.docker_hub != null) {
            for (dockerCred in secrets.docker_hub) {
                _addDockerHubRow(dockerCred.name, dockerCred.docker_hub_user, dockerCred.docker_hub_token);
            }
        }
        
        // Load SSH Keys
        if (secrets.ssh_keys != null) {
            for (sshKey in secrets.ssh_keys) {
                _addSSHKeyRow(sshKey.name, sshKey.key);
            }
        }
    }

    private function _clearRows() {
        // Remove all HCL API Key rows
        for (row in _hclApiKeys) {
            _hclApiKeysContainer.removeChild(row);
        }
        _hclApiKeys = [];

        // Remove all Git API Key rows
        for (row in _gitApiKeys) {
            _gitApiKeysContainer.removeChild(row);
        }
        _gitApiKeys = [];

        // Remove all Vagrant Token rows
        for (row in _vagrantTokens) {
            _vagrantTokensContainer.removeChild(row);
        }
        _vagrantTokens = [];

        // Remove all Custom Resource rows
        for (row in _customResources) {
            _customResourcesContainer.removeChild(row);
        }
        _customResources = [];

        // Remove all Docker Hub rows
        for (row in _dockerHubCredentials) {
            _dockerHubContainer.removeChild(row);
        }
        _dockerHubCredentials = [];
        
        // Remove all SSH Key rows
        for (row in _sshKeys) {
            _sshKeysContainer.removeChild(row);
        }
        _sshKeys = [];
    }

    private function _addHclApiKey(e:TriggerEvent) {
        _addHclApiKeyRow("", "");
    }

    private function _addHclApiKeyRow(name:String, key:String) {
        var row = new HclApiKeyRow(name, key);
        row.width = _width - GenesisApplicationTheme.GRID * 4;
        row.onDelete = function() {
            _hclApiKeys.remove(row);
            _hclApiKeysContainer.removeChild(row);
        };
        _hclApiKeys.push(row);
        _hclApiKeysContainer.addChild(row);
    }

    private function _addGitApiKey(e:TriggerEvent) {
        _addGitApiKeyRow("", "");
    }

    private function _addGitApiKeyRow(name:String, key:String) {
        var row = new GitApiKeyRow(name, key);
        row.width = _width - GenesisApplicationTheme.GRID * 4;
        row.onDelete = function() {
            _gitApiKeys.remove(row);
            _gitApiKeysContainer.removeChild(row);
        };
        _gitApiKeys.push(row);
        _gitApiKeysContainer.addChild(row);
    }

    private function _addVagrantToken(e:TriggerEvent) {
        _addVagrantTokenRow("", "");
    }

    private function _addVagrantTokenRow(name:String, key:String) {
        var row = new VagrantTokenRow(name, key);
        row.width = _width - GenesisApplicationTheme.GRID * 4;
        row.onDelete = function() {
            _vagrantTokens.remove(row);
            _vagrantTokensContainer.removeChild(row);
        };
        _vagrantTokens.push(row);
        _vagrantTokensContainer.addChild(row);
    }

    private function _addCustomResource(e:TriggerEvent) {
        _addCustomResourceRow("", "", false, "", "");
    }

    private function _addCustomResourceRow(name:String, url:String, useAuth:Bool, user:String, pass:String) {
        var row = new CustomResourceRow(name, url, useAuth, user, pass);
        row.width = _width - GenesisApplicationTheme.GRID * 4;
        row.onDelete = function() {
            _customResources.remove(row);
            _customResourcesContainer.removeChild(row);
        };
        _customResources.push(row);
        _customResourcesContainer.addChild(row);
    }

    private function _addDockerHub(e:TriggerEvent) {
        _addDockerHubRow("", "", "");
    }

    private function _addDockerHubRow(name:String, user:String, token:String) {
        var row = new DockerHubRow(name, user, token);
        row.width = _width - GenesisApplicationTheme.GRID * 4;
        row.onDelete = function() {
            _dockerHubCredentials.remove(row);
            _dockerHubContainer.removeChild(row);
        };
        _dockerHubCredentials.push(row);
        _dockerHubContainer.addChild(row);
    }

    /**
     * Validates a description string to ensure it is not empty and only contains allowed characters.
     * Allowed characters are: uppercase letters, lowercase letters, numbers, dashes, and underscores.
     * @param description The description string to validate
     * @return True if the description is valid, false otherwise
     */
    private function _isValidDescription(description:String):Bool {
        if (description == null || description.length == 0) {
            return false; // Empty descriptions are not allowed
        }
        
        // Regular expression to match only allowed characters
        var regex = ~/^[a-zA-Z0-9_-]*$/;
        return regex.match(description);
    }
    
    /**
     * Validates all description fields in all rows.
     * @return An object containing validation status and message
     */
    private function _validateAllDescriptions():{valid:Bool, message:String, invalidRow:Dynamic} {
        // Check HCL API Keys
        for (row in _hclApiKeys) {
            if (!_isValidDescription(row.getName())) {
                return {
                    valid: false, 
                    message: "HCL API Key description contains invalid characters. Only letters, numbers, dashes and underscores are allowed.",
                    invalidRow: row
                };
            }
        }
        
        // Check Git API Keys
        for (row in _gitApiKeys) {
            if (!_isValidDescription(row.getName())) {
                return {
                    valid: false, 
                    message: "Git API Key description contains invalid characters. Only letters, numbers, dashes and underscores are allowed.",
                    invalidRow: row
                };
            }
        }
        
        // Check Vagrant Tokens
        for (row in _vagrantTokens) {
            if (!_isValidDescription(row.getName())) {
                return {
                    valid: false, 
                    message: "Vagrant Token description contains invalid characters. Only letters, numbers, dashes and underscores are allowed.",
                    invalidRow: row
                };
            }
        }
        
        // Check Custom Resources
        for (row in _customResources) {
            if (!_isValidDescription(row.getName())) {
                return {
                    valid: false, 
                    message: "Custom Resource description contains invalid characters. Only letters, numbers, dashes and underscores are allowed.",
                    invalidRow: row
                };
            }
        }
        
        // Check Docker Hub Credentials
        for (row in _dockerHubCredentials) {
            if (!_isValidDescription(row.getName())) {
                return {
                    valid: false, 
                    message: "Docker Hub Credential description contains invalid characters. Only letters, numbers, dashes and underscores are allowed.",
                    invalidRow: row
                };
            }
        }
        
        // Check SSH Keys
        for (row in _sshKeys) {
            if (!_isValidDescription(row.getName())) {
                return {
                    valid: false, 
                    message: "SSH Key description contains invalid characters. Only letters, numbers, dashes and underscores are allowed.",
                    invalidRow: row
                };
            }
        }
        
        return {valid: true, message: "", invalidRow: null};
    }

    private function _saveButtonTriggered(e:TriggerEvent) {
        // Validate all descriptions before saving
        var validationResult = _validateAllDescriptions();
        if (!validationResult.valid) {
            // Show error message using ToastManager
            ToastManager.getInstance().showToast(validationResult.message);
            
            // Highlight invalid field if possible
            if (validationResult.invalidRow != null) {
                validationResult.invalidRow.highlightDescriptionField();
            }
            
            return; // Stop the save process
        }
        
        // Create the secrets object
        var secrets:SuperHumanSecrets = {};
        
        // Add HCL API Keys
        if (_hclApiKeys.length > 0) {
            secrets.hcl_download_portal_api_keys = [];
            for (row in _hclApiKeys) {
                secrets.hcl_download_portal_api_keys.push({
                    name: row.getName(),
                    key: row.getKey()
                });
            }
        }
        
        // Add Git API Keys
        if (_gitApiKeys.length > 0) {
            secrets.git_api_keys = [];
            for (row in _gitApiKeys) {
                secrets.git_api_keys.push({
                    name: row.getName(),
                    key: row.getKey()
                });
            }
        }
        
        // Add Vagrant Tokens
        if (_vagrantTokens.length > 0) {
            secrets.vagrant_atlas_token = [];
            for (row in _vagrantTokens) {
                secrets.vagrant_atlas_token.push({
                    name: row.getName(),
                    key: row.getKey()
                });
            }
        }
        
        // Add Custom Resources
        if (_customResources.length > 0) {
            secrets.custom_resource_url = [];
            for (row in _customResources) {
                secrets.custom_resource_url.push({
                    name: row.getName(),
                    url: row.getUrl(),
                    useAuth: row.getUseAuth(),
                    user: row.getUser(),
                    pass: row.getPass()
                });
            }
        }
        
        // Add Docker Hub Credentials
        if (_dockerHubCredentials.length > 0) {
            secrets.docker_hub = [];
            for (row in _dockerHubCredentials) {
                secrets.docker_hub.push({
                    name: row.getName(),
                    docker_hub_user: row.getUser(),
                    docker_hub_token: row.getToken()
                });
            }
        }
        
        // Add SSH Keys
        if (_sshKeys.length > 0) {
            secrets.ssh_keys = [];
            for (row in _sshKeys) {
                secrets.ssh_keys.push({
                    name: row.getName(),
                    key: row.getKey()
                });
            }
        }
        
        // Save to configuration
        SuperHumanInstaller.getInstance().config.secrets = secrets;
        
        // Dispatch save event
        this.dispatchEvent(new SuperHumanApplicationEvent(SuperHumanApplicationEvent.SAVE_APP_CONFIGURATION));
    }

    private function _buttonOpenHclPortalTriggered(e:TriggerEvent) {
        var event = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.OPEN_EXTERNAL_URL);
        event.url = "https://my.hcltechsw.com/";
        this.dispatchEvent(event);
    }
    
    private function _buttonOpenGitHubTriggered(e:TriggerEvent) {
        var event = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.OPEN_EXTERNAL_URL);
        event.url = "https://github.com/settings/tokens";
        this.dispatchEvent(event);
    }
    
    private function _buttonOpenHashiCorpTriggered(e:TriggerEvent) {
        var event = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.OPEN_EXTERNAL_URL);
        event.url = "https://cloud.hashicorp.com/";
        this.dispatchEvent(event);
    }
    
    private function _buttonOpenBoxVaultTriggered(e:TriggerEvent) {
        var event = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.OPEN_EXTERNAL_URL);
        event.url = "https://boxvault.startcloud.com";
        this.dispatchEvent(event);
    }
    
    private function _buttonOpenDockerHubTriggered(e:TriggerEvent) {
        var event = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.OPEN_EXTERNAL_URL);
        event.url = "https://hub.docker.com/settings/security";
        this.dispatchEvent(event);
    }
    
    private function _addSSHKey(e:TriggerEvent) {
        _addSSHKeyRow("", "");
    }

    private function _addSSHKeyRow(name:String, key:String) {
        var row = new SSHKeyRow(name, key);
        row.width = _width - GenesisApplicationTheme.GRID * 4;
        row.onDelete = function() {
            _sshKeys.remove(row);
            _sshKeysContainer.removeChild(row);
        };
        _sshKeys.push(row);
        _sshKeysContainer.addChild(row);
    }
    
    private function _buttonOpenSSHDocsTriggered(e:TriggerEvent) {
        var event = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.OPEN_EXTERNAL_URL);
        event.url = "https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent";
        this.dispatchEvent(event);
    }

    override function _cancel(?e:Dynamic) {
        this.dispatchEvent(new SuperHumanApplicationEvent(SuperHumanApplicationEvent.CANCEL_PAGE));
    }
}

// Component for HCL API Key
class HclApiKeyRow extends LayoutGroup {
    private var _nameInput:GenesisFormTextInput;
    private var _keyInput:GenesisFormTextInput;
    private var _deleteButton:Button;
    
    public var onDelete:Void->Void;
    
    /**
     * Highlights the description field to indicate validation error
     */
    public function highlightDescriptionField():Void {
        // Call isValid with validation to highlight the field
        _nameInput.isValid();
    }
    
    public function new(name:String, key:String) {
        super();
        
        // Set up vertical layout
        var mainLayout = new VerticalLayout();
        mainLayout.gap = GenesisApplicationTheme.GRID;
        this.layout = mainLayout;
        this.width = GenesisApplicationTheme.GRID * 90;
        
        // Name row
        var nameRow = new LayoutGroup();
        var nameRowLayout = new HorizontalLayout();
        nameRowLayout.gap = GenesisApplicationTheme.GRID;
        nameRowLayout.verticalAlign = VerticalAlign.MIDDLE;
        nameRow.layout = nameRowLayout;
        
        // Delete button at the beginning of the first row
        _deleteButton = new Button();
        _deleteButton.icon = GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_DESTROY_SMALL);
        _deleteButton.setPadding(0); // Remove padding
        _deleteButton.width = GenesisApplicationTheme.GRID * 3;
        _deleteButton.height = GenesisApplicationTheme.GRID * 3;
        _deleteButton.addEventListener(TriggerEvent.TRIGGER, function(_) {
            if (onDelete != null) onDelete();
        });
        _deleteButton.toolTip = "Delete";
        
        // Name input without separate label - use GenesisFormTextInput with validation
        _nameInput = new GenesisFormTextInput(name, "Enter Description", ~/^[a-zA-Z0-9_-]*$/, false);
        _nameInput.minLength = 1; // At least one character required
        _nameInput.width = GenesisApplicationTheme.GRID * 65; // Fixed width
        
        // Add components to name row
        nameRow.addChild(_deleteButton);
        nameRow.addChild(_nameInput);
        
        // Key row
        var keyRow = new LayoutGroup();
        var keyRowLayout = new HorizontalLayout();
        keyRowLayout.gap = GenesisApplicationTheme.GRID;
        keyRowLayout.verticalAlign = VerticalAlign.MIDDLE;
        keyRow.layout = keyRowLayout;
        
        // Spacer to align with delete button position
        var spacer = new LayoutGroup();
        spacer.width = GenesisApplicationTheme.GRID * 3;
        
        // Key input without separate label
        _keyInput = new GenesisFormTextInput(key, "Enter API Key", null, false);
        _keyInput.width = GenesisApplicationTheme.GRID * 65; // Fixed width
        
        // Add components to key row
        keyRow.addChild(spacer);
        keyRow.addChild(_keyInput);
        
        // Add rows to main container
        this.addChild(nameRow);
        this.addChild(keyRow);
    }
    
    public function getName():String {
        return _nameInput.text;
    }
    
    public function getKey():String {
        return _keyInput.text;
    }
}

// Component for Git API Key
class GitApiKeyRow extends LayoutGroup {
    private var _nameInput:GenesisFormTextInput;
    private var _keyInput:GenesisFormTextInput;
    private var _deleteButton:Button;
    
    public var onDelete:Void->Void;
    
    /**
     * Highlights the description field to indicate validation error
     */
    public function highlightDescriptionField():Void {
        // Call isValid with validation to highlight the field
        _nameInput.isValid();
    }
    
    public function new(name:String, key:String) {
        super();
        
        // Set up vertical layout
        var mainLayout = new VerticalLayout();
        mainLayout.gap = GenesisApplicationTheme.GRID;
        this.layout = mainLayout;
        this.width = GenesisApplicationTheme.GRID * 90;
        
        // Name row
        var nameRow = new LayoutGroup();
        var nameRowLayout = new HorizontalLayout();
        nameRowLayout.gap = GenesisApplicationTheme.GRID;
        nameRowLayout.verticalAlign = VerticalAlign.MIDDLE;
        nameRow.layout = nameRowLayout;
        
        // Delete button at the beginning of the first row
        _deleteButton = new Button();
        _deleteButton.icon = GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_DESTROY_SMALL);
        _deleteButton.setPadding(0); // Remove padding
        _deleteButton.width = GenesisApplicationTheme.GRID * 3;
        _deleteButton.height = GenesisApplicationTheme.GRID * 3;
        _deleteButton.addEventListener(TriggerEvent.TRIGGER, function(_) {
            if (onDelete != null) onDelete();
        });
        _deleteButton.toolTip = "Delete";
        
        // Name input without separate label - use GenesisFormTextInput with validation
        _nameInput = new GenesisFormTextInput(name, "Enter Description", ~/^[a-zA-Z0-9_-]*$/, false);
        _nameInput.minLength = 1; // At least one character required
        _nameInput.width = GenesisApplicationTheme.GRID * 65; // Fixed width
        
        // Add components to name row
        nameRow.addChild(_deleteButton);
        nameRow.addChild(_nameInput);
        
        // Key row
        var keyRow = new LayoutGroup();
        var keyRowLayout = new HorizontalLayout();
        keyRowLayout.gap = GenesisApplicationTheme.GRID;
        keyRowLayout.verticalAlign = VerticalAlign.MIDDLE;
        keyRow.layout = keyRowLayout;
        
        // Spacer to align with delete button position
        var spacer = new LayoutGroup();
        spacer.width = GenesisApplicationTheme.GRID * 3;
        
        // Key input without separate label
        _keyInput = new GenesisFormTextInput(key, "Enter Github Personal Access Token", null, false);
        _keyInput.width = GenesisApplicationTheme.GRID * 65; // Fixed width
        
        // Add components to key row
        keyRow.addChild(spacer);
        keyRow.addChild(_keyInput);
        
        // Add rows to main container
        this.addChild(nameRow);
        this.addChild(keyRow);
    }
    
    public function getName():String {
        return _nameInput.text;
    }
    
    public function getKey():String {
        return _keyInput.text;
    }
}

// Component for Vagrant Token
class VagrantTokenRow extends LayoutGroup {
    private var _nameInput:GenesisFormTextInput;
    private var _keyInput:GenesisFormTextInput;
    private var _deleteButton:Button;
    
    public var onDelete:Void->Void;
    
    /**
     * Highlights the description field to indicate validation error
     */
    public function highlightDescriptionField():Void {
        // Call isValid with validation to highlight the field
        _nameInput.isValid();
    }
    
    public function new(name:String, key:String) {
        super();
        
        // Set up vertical layout
        var mainLayout = new VerticalLayout();
        mainLayout.gap = GenesisApplicationTheme.GRID;
        this.layout = mainLayout;
        this.width = GenesisApplicationTheme.GRID * 90;
        
        // Name row
        var nameRow = new LayoutGroup();
        var nameRowLayout = new HorizontalLayout();
        nameRowLayout.gap = GenesisApplicationTheme.GRID;
        nameRowLayout.verticalAlign = VerticalAlign.MIDDLE;
        nameRow.layout = nameRowLayout;
        
        // Delete button at the beginning of the first row
        _deleteButton = new Button();
        _deleteButton.icon = GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_DESTROY_SMALL);
        _deleteButton.setPadding(0); // Remove padding
        _deleteButton.width = GenesisApplicationTheme.GRID * 3;
        _deleteButton.height = GenesisApplicationTheme.GRID * 3;
        _deleteButton.addEventListener(TriggerEvent.TRIGGER, function(_) {
            if (onDelete != null) onDelete();
        });
        _deleteButton.toolTip = "Delete";
        
        // Name input without separate label - use GenesisFormTextInput with validation
        _nameInput = new GenesisFormTextInput(name, "Enter Description", ~/^[a-zA-Z0-9_-]*$/, false);
        _nameInput.minLength = 1; // At least one character required
        _nameInput.width = GenesisApplicationTheme.GRID * 65; // Fixed width
        
        // Add components to name row
        nameRow.addChild(_deleteButton);
        nameRow.addChild(_nameInput);
        
        // Key row
        var keyRow = new LayoutGroup();
        var keyRowLayout = new HorizontalLayout();
        keyRowLayout.gap = GenesisApplicationTheme.GRID;
        keyRowLayout.verticalAlign = VerticalAlign.MIDDLE;
        keyRow.layout = keyRowLayout;
        
        // Spacer to align with delete button position
        var spacer = new LayoutGroup();
        spacer.width = GenesisApplicationTheme.GRID * 3;
        
        // Key input without separate label
        _keyInput = new GenesisFormTextInput(key, "Enter Token", null, false);
        _keyInput.width = GenesisApplicationTheme.GRID * 65; // Fixed width
        
        // Add components to key row
        keyRow.addChild(spacer);
        keyRow.addChild(_keyInput);
        
        // Add rows to main container
        this.addChild(nameRow);
        this.addChild(keyRow);
    }
    
    public function getName():String {
        return _nameInput.text;
    }
    
    public function getKey():String {
        return _keyInput.text;
    }
}

// Component for Custom Resource
class CustomResourceRow extends LayoutGroup {
    private var _nameInput:GenesisFormTextInput;
    private var _urlInput:GenesisFormTextInput;
    private var _useAuthCheck:GenesisFormCheckBox;
    private var _userInput:GenesisFormTextInput;
    private var _passInput:GenesisFormTextInput;
    private var _deleteButton:Button;
    private var _mainRow:LayoutGroup;
    private var _authRow:LayoutGroup;
    
    public var onDelete:Void->Void;
    
    /**
     * Highlights the description field to indicate validation error
     */
    public function highlightDescriptionField():Void {
        // Call isValid with validation to highlight the field
        _nameInput.isValid();
    }
    
    public function new(name:String, url:String, useAuth:Bool, user:String, pass:String) {
        super();
        
        // Set up vertical layout for the component
        var layout = new VerticalLayout();
        layout.gap = GenesisApplicationTheme.GRID;
        this.layout = layout;
        this.width = GenesisApplicationTheme.GRID * 90;
        
        // Set up vertical layout for the component with rows for each field
        var layout = new VerticalLayout();
        layout.gap = GenesisApplicationTheme.GRID;
        this.layout = layout;
        this.width = GenesisApplicationTheme.GRID * 90;
        
        // Name row
        var nameRow = new LayoutGroup();
        var nameRowLayout = new HorizontalLayout();
        nameRowLayout.gap = GenesisApplicationTheme.GRID;
        nameRowLayout.verticalAlign = VerticalAlign.MIDDLE;
        nameRow.layout = nameRowLayout;
        
        // Delete button at the beginning of the first row
        _deleteButton = new Button();
        _deleteButton.icon = GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_DESTROY_SMALL);
        _deleteButton.setPadding(0); // Remove padding
        _deleteButton.width = GenesisApplicationTheme.GRID * 3;
        _deleteButton.height = GenesisApplicationTheme.GRID * 3;
        _deleteButton.addEventListener(TriggerEvent.TRIGGER, function(_) {
            if (onDelete != null) onDelete();
        });
        _deleteButton.toolTip = "Delete";
        
        // Name input without separate label - use GenesisFormTextInput with validation
        _nameInput = new GenesisFormTextInput(name, "Enter Description", ~/^[a-zA-Z0-9_-]*$/, false);
        _nameInput.minLength = 1; // At least one character required
        _nameInput.width = GenesisApplicationTheme.GRID * 65; // Fixed width
        
        // Add components to name row
        nameRow.addChild(_deleteButton);
        nameRow.addChild(_nameInput);
        
        // URL row
        var urlRow = new LayoutGroup();
        var urlRowLayout = new HorizontalLayout();
        urlRowLayout.gap = GenesisApplicationTheme.GRID;
        urlRowLayout.verticalAlign = VerticalAlign.MIDDLE;
        urlRow.layout = urlRowLayout;
        
        // Spacer to align with delete button position
        var urlSpacer = new LayoutGroup();
        urlSpacer.width = GenesisApplicationTheme.GRID * 3;
        
        // URL input without separate label
        _urlInput = new GenesisFormTextInput(url, "Enter URL", null, false);
        _urlInput.width = GenesisApplicationTheme.GRID * 65; // Fixed width
        
        // Add components to URL row
        urlRow.addChild(urlSpacer);
        urlRow.addChild(_urlInput);
        
        // Auth checkbox row
        var authCheckRow = new LayoutGroup();
        var authCheckRowLayout = new HorizontalLayout();
        authCheckRowLayout.gap = GenesisApplicationTheme.GRID;
        authCheckRowLayout.verticalAlign = VerticalAlign.MIDDLE;
        authCheckRow.layout = authCheckRowLayout;
        
        // Spacer to align with delete button position
        var authSpacer = new LayoutGroup();
        authSpacer.width = GenesisApplicationTheme.GRID * 3;
        
        // Use GenesisFormCheckBox instead of regular Check
        _useAuthCheck = new GenesisFormCheckBox("Use Authentication", useAuth);
        _useAuthCheck.addEventListener(TriggerEvent.TRIGGER, _onUseAuthChanged);
        
        // Add components to auth checkbox row
        authCheckRow.addChild(authSpacer);
        authCheckRow.addChild(_useAuthCheck);
        
        // Add all the main rows to the container
        this.addChild(nameRow);
        this.addChild(urlRow);
        this.addChild(authCheckRow);
        
        // Auth row for username and password
        _authRow = new LayoutGroup();
        var authRowLayout = new VerticalLayout();
        authRowLayout.gap = GenesisApplicationTheme.GRID;
        _authRow.layout = authRowLayout;
        
        // Username row
        var userRow = new LayoutGroup();
        var userRowLayout = new HorizontalLayout();
        userRowLayout.gap = GenesisApplicationTheme.GRID;
        userRowLayout.verticalAlign = VerticalAlign.MIDDLE;
        userRow.layout = userRowLayout;
        
        // Spacer to align with delete button position
        var userSpacer = new LayoutGroup();
        userSpacer.width = GenesisApplicationTheme.GRID * 3;
        
        // User input without separate label
        _userInput = new GenesisFormTextInput(user, "Enter Username", null, false);
        _userInput.width = GenesisApplicationTheme.GRID * 65; // Fixed width
        
        // Add components to username row
        userRow.addChild(userSpacer);
        userRow.addChild(_userInput);
        
        // Password row
        var passRow = new LayoutGroup();
        var passRowLayout = new HorizontalLayout();
        passRowLayout.gap = GenesisApplicationTheme.GRID;
        passRowLayout.verticalAlign = VerticalAlign.MIDDLE;
        passRow.layout = passRowLayout;
        
        // Spacer to align with delete button position
        var passSpacer = new LayoutGroup();
        passSpacer.width = GenesisApplicationTheme.GRID * 3;
        
        // Password input without separate label
        _passInput = new GenesisFormTextInput(pass, "Enter Password", null, false);
        _passInput.displayAsPassword = true;
        _passInput.width = GenesisApplicationTheme.GRID * 65; // Fixed width
        
        // Add components to password row
        passRow.addChild(passSpacer);
        passRow.addChild(_passInput);
        
        // Add username and password rows to auth container
        _authRow.addChild(userRow);
        _authRow.addChild(passRow);
        
        _authRow.visible = _useAuthCheck.selected;
        _authRow.includeInLayout = _useAuthCheck.selected;
        
        this.addChild(_authRow);
    }
    
    private function _onUseAuthChanged(e:TriggerEvent) {
        _authRow.visible = _useAuthCheck.selected;
        _authRow.includeInLayout = _useAuthCheck.selected;
    }
    
    public function getName():String {
        return _nameInput.text;
    }
    
    public function getUrl():String {
        return _urlInput.text;
    }
    
    public function getUseAuth():Bool {
        return _useAuthCheck.selected;
    }
    
    public function getUser():String {
        return _userInput.text;
    }
    
    public function getPass():String {
        return _passInput.text;
    }
}

// Component for SSH Key
class SSHKeyRow extends LayoutGroup {
    private var _nameInput:GenesisFormTextInput;
    private var _keyInput:GenesisFormTextInput;
    private var _deleteButton:Button;
    
    public var onDelete:Void->Void;
    
    /**
     * Highlights the description field to indicate validation error
     */
    public function highlightDescriptionField():Void {
        // Call isValid with validation to highlight the field
        _nameInput.isValid();
    }
    
    public function new(name:String, key:String) {
        super();
        
        // Set up vertical layout
        var mainLayout = new VerticalLayout();
        mainLayout.gap = GenesisApplicationTheme.GRID;
        this.layout = mainLayout;
        this.width = GenesisApplicationTheme.GRID * 90;
        
        // Name row
        var nameRow = new LayoutGroup();
        var nameRowLayout = new HorizontalLayout();
        nameRowLayout.gap = GenesisApplicationTheme.GRID;
        nameRowLayout.verticalAlign = VerticalAlign.MIDDLE;
        nameRow.layout = nameRowLayout;
        
        // Delete button at the beginning of the first row
        _deleteButton = new Button();
        _deleteButton.icon = GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_DESTROY_SMALL);
        _deleteButton.setPadding(0); // Remove padding
        _deleteButton.width = GenesisApplicationTheme.GRID * 3;
        _deleteButton.height = GenesisApplicationTheme.GRID * 3;
        _deleteButton.addEventListener(TriggerEvent.TRIGGER, function(_) {
            if (onDelete != null) onDelete();
        });
        _deleteButton.toolTip = "Delete";
        
        // Name input without separate label - use GenesisFormTextInput with validation
        _nameInput = new GenesisFormTextInput(name, "Enter Description", ~/^[a-zA-Z0-9_-]*$/, false);
        _nameInput.minLength = 1; // At least one character required
        _nameInput.width = GenesisApplicationTheme.GRID * 65; // Fixed width
        
        // Add components to name row
        nameRow.addChild(_deleteButton);
        nameRow.addChild(_nameInput);
        
        // Key row
        var keyRow = new LayoutGroup();
        var keyRowLayout = new HorizontalLayout();
        keyRowLayout.gap = GenesisApplicationTheme.GRID;
        keyRowLayout.verticalAlign = VerticalAlign.MIDDLE;
        keyRow.layout = keyRowLayout;
        
        // Spacer to align with delete button position
        var spacer = new LayoutGroup();
        spacer.width = GenesisApplicationTheme.GRID * 3;
        
        // Key input without separate label
        _keyInput = new GenesisFormTextInput(key, "Enter SSH Key (in PEM format)", null, false);
        _keyInput.width = GenesisApplicationTheme.GRID * 65; // Fixed width
        
        // Add components to key row
        keyRow.addChild(spacer);
        keyRow.addChild(_keyInput);
        
        // Add rows to main container
        this.addChild(nameRow);
        this.addChild(keyRow);
    }
    
    public function getName():String {
        return _nameInput.text;
    }
    
    public function getKey():String {
        return _keyInput.text;
    }
}

// Component for Docker Hub
class DockerHubRow extends LayoutGroup {
    private var _nameInput:GenesisFormTextInput;
    private var _userInput:GenesisFormTextInput;
    private var _tokenInput:GenesisFormTextInput;
    private var _deleteButton:Button;
    
    public var onDelete:Void->Void;
    
    /**
     * Highlights the description field to indicate validation error
     */
    public function highlightDescriptionField():Void {
        // Call isValid with validation to highlight the field
        _nameInput.isValid();
    }
    
    public function new(name:String, user:String, token:String) {
        super();
        
        // Set up vertical layout
        var mainLayout = new VerticalLayout();
        mainLayout.gap = GenesisApplicationTheme.GRID;
        this.layout = mainLayout;
        this.width = GenesisApplicationTheme.GRID * 90;
        
        // Name row
        var nameRow = new LayoutGroup();
        var nameRowLayout = new HorizontalLayout();
        nameRowLayout.gap = GenesisApplicationTheme.GRID;
        nameRowLayout.verticalAlign = VerticalAlign.MIDDLE;
        nameRow.layout = nameRowLayout;
        
        // Delete button at the beginning of the first row
        _deleteButton = new Button();
        _deleteButton.icon = GenesisApplicationTheme.getCommonIcon(GenesisApplicationTheme.ICON_DESTROY_SMALL);
        _deleteButton.setPadding(0); // Remove padding
        _deleteButton.width = GenesisApplicationTheme.GRID * 3;
        _deleteButton.height = GenesisApplicationTheme.GRID * 3;
        _deleteButton.addEventListener(TriggerEvent.TRIGGER, function(_) {
            if (onDelete != null) onDelete();
        });
        _deleteButton.toolTip = "Delete";
        
        // Name input without separate label - use GenesisFormTextInput with validation
        _nameInput = new GenesisFormTextInput(name, "Enter Description", ~/^[a-zA-Z0-9_-]*$/, false);
        _nameInput.minLength = 1; // At least one character required
        _nameInput.width = GenesisApplicationTheme.GRID * 65; // Fixed width
        
        // Add components to name row
        nameRow.addChild(_deleteButton);
        nameRow.addChild(_nameInput);
        
        // User row
        var userRow = new LayoutGroup();
        var userRowLayout = new HorizontalLayout();
        userRowLayout.gap = GenesisApplicationTheme.GRID;
        userRowLayout.verticalAlign = VerticalAlign.MIDDLE;
        userRow.layout = userRowLayout;
        
        // Spacer to align with delete button position
        var spacer1 = new LayoutGroup();
        spacer1.width = GenesisApplicationTheme.GRID * 3;
        
        // User input without separate label
        _userInput = new GenesisFormTextInput(user, "Enter Docker Hub User", null, false);
        _userInput.width = GenesisApplicationTheme.GRID * 65; // Fixed width
        
        // Add components to user row
        userRow.addChild(spacer1);
        userRow.addChild(_userInput);
        
        // Token row
        var tokenRow = new LayoutGroup();
        var tokenRowLayout = new HorizontalLayout();
        tokenRowLayout.gap = GenesisApplicationTheme.GRID;
        tokenRowLayout.verticalAlign = VerticalAlign.MIDDLE;
        tokenRow.layout = tokenRowLayout;
        
        // Spacer to align with delete button position
        var spacer2 = new LayoutGroup();
        spacer2.width = GenesisApplicationTheme.GRID * 3;
        
        // Token input without separate label
        _tokenInput = new GenesisFormTextInput(token, "Enter Docker Hub Token", null, false);
        _tokenInput.width = GenesisApplicationTheme.GRID * 65; // Fixed width
        
        // Add components to token row
        tokenRow.addChild(spacer2);
        tokenRow.addChild(_tokenInput);
        
        // Add rows to main container
        this.addChild(nameRow);
        this.addChild(userRow);
        this.addChild(tokenRow);
    }
    
    public function getName():String {
        return _nameInput.text;
    }
    
    public function getUser():String {
        return _userInput.text;
    }
    
    public function getToken():String {
        return _tokenInput.text;
    }
}
