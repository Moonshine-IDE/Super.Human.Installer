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

package superhuman.theme;

import feathers.controls.ToggleButtonState;
import feathers.controls.LayoutGroup;
import feathers.controls.TextInputState;
import feathers.layout.AnchorLayout;
import feathers.layout.AnchorLayoutData;
import feathers.layout.HorizontalAlign;
import feathers.layout.HorizontalLayout;
import feathers.layout.VerticalAlign;
import feathers.layout.VerticalLayout;
import feathers.layout.VerticalLayoutData;
import feathers.skins.RectangleSkin;
import feathers.text.TextFormat;
import genesis.application.theme.GenesisApplicationTheme;
import superhuman.components.Console;
import superhuman.components.ServerList;
import superhuman.components.SystemInfoBox;
import superhuman.components.WarningBox;
import superhuman.components.serviceType.ServiceTypeGrid;

class SuperHumanInstallerTheme extends GenesisApplicationTheme {

    public static final APPLICATION_MIN_HEIGHT:Int = 760;
    public static final APPLICATION_MIN_WIDTH:Int = 1060;
    public static final IMAGE_ICON:String = "assets/images/logo.png";
    public static final IMAGE_LOGO:String = "assets/images/servers.png";
    public static final LAYOUT_GROUP_APP_CHECKER_OVERLAY:String = "layout-group-app-checker-overlay";
    public static final LAYOUT_GROUP_SERVER_BUTTON_GROUP:String = "layout-group-server-button-group";
    public static final TEXT_AREA_CONSOLE:String = "text-area-console";
    public static final GRID_VIEW_HEADER_VARIANT:String = "grid-view-header-variant";
	public static final GRID_VIEW_COLUMN_VARIANT:String = "grid-view-column-variant";
    public static final SCROLL_CONTAINER_DARK:String = "scroll-container-dark";

    static var _instance:SuperHumanInstallerTheme;

    static public function getInstance():SuperHumanInstallerTheme return _instance;

    public var consoleTextFormat( get, never ):TextFormat;
    function get_consoleTextFormat() return _themeTypography.ConsoleText;

    public var consoleTextErrorFormat( get, never ):TextFormat;
    function get_consoleTextErrorFormat() return _themeTypography.ConsoleTextError;

    public var themeTypography(get, never):Typography;
    function get_themeTypography() return _themeTypography;
    
    public function new( mode:ThemeMode = ThemeMode.Dark ) {

        super( mode );

        _instance = this;

    }

    override function _init() {

        super._init();

        this.styleProvider.setStyleFunction( Console, null, _setConsoleStyles );
        this.styleProvider.setStyleFunction( ConsoleTextList, null, _setConsoleTextListStyles );
        this.styleProvider.setStyleFunction( ConsoleTextListItemRenderer, null, _setConsoleTextListItemRendererStyles );
        this.styleProvider.setStyleFunction( LayoutGroup, LAYOUT_GROUP_APP_CHECKER_OVERLAY, _setLayoutGroupAppCheckerOverlayStyles );
        this.styleProvider.setStyleFunction( LayoutGroup, LAYOUT_GROUP_SERVER_BUTTON_GROUP, _setLayoutGroupServerButtonGroupStyles );
        this.styleProvider.setStyleFunction( ServerItem, null, _setServerItemStyles );
        this.styleProvider.setStyleFunction( ServerList, null, _setServerListStyles );
        this.styleProvider.setStyleFunction( SystemInfoBox, null, _setSystemInfoBoxStyles );
        this.styleProvider.setStyleFunction( WarningBox, null, _setWarningBoxStyles );
		this.styleProvider.setStyleFunction( GridViewHeader, GRID_VIEW_HEADER_VARIANT, _setGridViewHeaderStyles);
		this.styleProvider.setStyleFunction( GridViewColumnMultiline, GRID_VIEW_COLUMN_VARIANT, _setGridViewColumnStyles);
        this.styleProvider.setStyleFunction( ScrollContainer, SCROLL_CONTAINER_DARK, _setScrollContainerDarkStyles);
    }

    function _setConsoleStyles( console:Console ) {

        console.backgroundSkin = new RectangleSkin( FillStyle.SolidColor( _themeColors.ConsoleBackground ) );
        console.layoutData = AnchorLayoutData.fill();
        var layout = new VerticalLayout();
        console.layout = layout;

    }

    function _setConsoleTextListStyles( textList:ConsoleTextList ) {

        textList.layoutData = new VerticalLayoutData( 100, 100 );
        textList.setPadding( GenesisApplicationTheme.GRID * 2 );
        textList.virtualLayout = true;

        var layout = new VerticalLayout();
        textList.layout = layout;

    }

    function _setConsoleTextListItemRendererStyles( itemRenderer:ConsoleTextListItemRenderer ) {

        var layout = new HorizontalLayout();
        itemRenderer.layout = layout;
        itemRenderer.layoutData = new VerticalLayoutData( 100 );
        itemRenderer.textFormat = ( itemRenderer.isError ) ? _themeTypography.ConsoleTextError : _themeTypography.ConsoleText;

    }

    function _setLayoutGroupAppCheckerOverlayStyles( group:LayoutGroup ) {

        group.layout = new AnchorLayout();

    }

    function _setLayoutGroupServerButtonGroupStyles( group:LayoutGroup ) {

        group.layoutData = new VerticalLayoutData( 100 );
        var layout = new HorizontalLayout();
        layout.paddingTop = GenesisApplicationTheme.GRID * 2;
        layout.gap = GenesisApplicationTheme.GRID;
        group.layout = layout;

    }

    function _setWarningBoxStyles( box:WarningBox ) {

        var r = new RectangleSkin( FillStyle.SolidColor( _themeColors.Box ), LineStyle.SolidColor( 1, _themeColors.Warning ) );
        r.alpha = .3;
        r.cornerRadius = GenesisApplicationTheme.GRID;
        box.backgroundSkin = r;

        box.width = GenesisApplicationTheme.GRID * 120;

        var layout = new HorizontalLayout();
        layout.setPadding( GenesisApplicationTheme.GRID * 2 );
        box.layout = layout;

    }

    function _setGridViewHeaderStyles( box:GridViewHeader ) {
		var backgroundSkin = new RectangleSkin();
			backgroundSkin.fill = SolidColor(0x444444);
	
			box.backgroundSkin = backgroundSkin;
			box.minHeight = 35;
	}
	
	function _setGridViewColumnStyles( box:GridViewColumnMultiline ) {
		var backgroundSkin = new RectangleSkin();
			backgroundSkin.fill = SolidColor(0x222222);
			backgroundSkin.selectedFill = SolidColor(0x666666);
			backgroundSkin.disabledFill = SolidColor(0x222222);
			
			box.backgroundSkin = backgroundSkin;
			box.minHeight = 35;
	}
	
    function _setServerListStyles( list:ServerList ) {

        var layout = new VerticalLayout();
        layout.gap = GenesisApplicationTheme.GRID * 2;
        layout.verticalAlign = VerticalAlign.TOP;
        list.layout = layout;
        list.layoutData = new VerticalLayoutData( 100, 100 );
        list.autoHideScrollBars = false;
        list.fixedScrollBars = true;
        list.virtualLayout = false;

    }

    function _setServerItemStyles( item:ServerItem ) {

        var r = new RectangleSkin( FillStyle.SolidColor( _themeColors.Box ) );
        r.cornerRadius = GenesisApplicationTheme.GRID;
        item.backgroundSkin = r;

        var layout = new VerticalLayout();
        layout.setPadding( GenesisApplicationTheme.GRID * 2 );
        item.layout = layout;
        item.layoutData = new VerticalLayoutData( 100 );

    }

    function _setSystemInfoBoxStyles( box:SystemInfoBox ) {

        //box.layoutData = new VerticalLayoutData( 100 );

        var r = new RectangleSkin( FillStyle.SolidColor( _themeColors.Box ) );
        r.alpha = .3;
        r.cornerRadius = GenesisApplicationTheme.GRID;
        box.backgroundSkin = r;

        var layout = new HorizontalLayout();
        layout.horizontalAlign = HorizontalAlign.CENTER;
        layout.verticalAlign = VerticalAlign.MIDDLE;
        layout.setPadding( GenesisApplicationTheme.GRID * 1 );
        layout.paddingLeft = layout.paddingRight = GenesisApplicationTheme.GRID * 2;
        layout.gap = GenesisApplicationTheme.GRID * 2;
        box.layout = layout;

    }
    
    function _setScrollContainerDarkStyles( container:ScrollContainer ) {
        // Apply dark theme styling to match the ServerList
        container.autoHideScrollBars = false;
        container.fixedScrollBars = true;
        
        // Use the same background color as the Box color in the theme
        var backgroundSkin = new RectangleSkin( FillStyle.SolidColor( _themeColors.Box ) );
        container.backgroundSkin = backgroundSkin;
    }

}

class SuperHumanPopUpOverlay extends LayoutGroup {

    static var _instance:SuperHumanPopUpOverlay;

    public static function getInstance():SuperHumanPopUpOverlay {

        if ( _instance == null ) _instance = new SuperHumanPopUpOverlay();
        return _instance;

    }

    function new() {

        super();

        var r = new RectangleSkin( FillStyle.SolidColor( 0x222222, .75 ) );
        this.backgroundSkin = r;

    }

}
