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

package genesis.application.theme;

import feathers.controls.Alert;
import feathers.controls.AssetLoader;
import feathers.controls.Button;
import feathers.controls.ButtonBar;
import feathers.controls.ButtonState;
import feathers.controls.Check;
import feathers.controls.Form;
import feathers.controls.FormItem;
import feathers.controls.Header;
import feathers.controls.Label;
import feathers.controls.LayoutGroup;
import feathers.controls.PageIndicator;
import feathers.controls.PopUpListView;
import feathers.controls.TextArea;
import feathers.controls.TextInput;
import feathers.controls.TextInputState;
import feathers.core.DefaultToolTipManager;
import feathers.graphics.CreateGradientBoxMatrix;
import feathers.layout.AnchorLayoutData;
import feathers.layout.HorizontalAlign;
import feathers.layout.HorizontalLayout;
import feathers.layout.HorizontalLayoutData;
import feathers.layout.RelativePosition;
import feathers.layout.VerticalAlign;
import feathers.layout.VerticalLayout;
import feathers.layout.VerticalLayoutData;
import feathers.skins.CircleSkin;
import feathers.skins.RectangleSkin;
import feathers.text.TextFormat;
import feathers.themes.ClassVariantTheme;
import genesis.application.components.AdvancedAssetLoader;
import genesis.application.components.GenesisForm;
import genesis.application.components.GenesisFormButton;
import genesis.application.components.GenesisFormCheckBox;
import genesis.application.components.GenesisFormPupUpListView;
import genesis.application.components.GenesisFormTextInput;
import genesis.application.components.MainMenu;
import genesis.application.components.MainMenuButton;
import genesis.application.components.Page;
import genesis.application.components.ProgressBar;
import genesis.application.components.Toast;
import lime.system.System;
import openfl.Assets;
import openfl.display.GradientType;
import openfl.filters.DropShadowFilter;
import openfl.text.TextFormatAlign;

class GenesisApplicationTheme extends ClassVariantTheme {

    public static final CORNER_RADIUS:Int = 3;
    public static final GRID:Int = 6;
    public static final DISABLED_ALPHA:Float = .33;

    public static function getAssetPath( id:String ):String {
        
        return Assets.getPath( id );

    }

    public static final APPLICATION:String = "application";
    public static final BUTTON_HIGHLIGHT:String = "button-hightlight";
    public static final BUTTON_SELECT_FILE:String = "button-select-file";
    public static final BUTTON_SMALL:String = "button-small";
    public static final BUTTON_TINY:String = "button-tiny";
    public static final BUTTON_WARNING:String = "button-warning";
    public static final BUTTON_BROWSER_WARNING:String = "button-browser-warning";
    public static final CHECK_LARGE:String = "check-large";
    public static final CHECK_MEDIUM:String = "check-medium";
    public static final INVALID:String = "invalid";
    public static final LABEL_CENTERED:String = "label-centered";
    public static final LABEL_COPYRIGHT:String = "label-copyright";
    public static final LABEL_COPYRIGHT_CENTER:String = "label-copyright-center";
    public static final LABEL_HUGE:String = "label-huge";
    public static final LABEL_LARGE:String = "label-large";
    public static final LABEL_LINK:String = "label-link";
    public static final LABEL_LINK_SMALL:String = "label-link-small";
    public static final LABEL_SMALL_CENTERED:String = "label-small-centered";
    public static final LABEL_TITLE:String = "label-title";
    public static final LABEL_ERROR:String = "label-error";
    public static final LAYOUT_GROUP_CREATE_ACCOUNT:String = "layout-group-create-account";
    public static final LAYOUT_GROUP_FOOTER:String = "layout-group-footer";
    public static final LAYOUT_GROUP_HEADER:String = "layout-group-header";
    public static final LAYOUT_GROUP_HORIZONTAL_LINE:String = "layout-group-horizontal-line";
    public static final LAYOUT_GROUP_LOGIN:String = "layout-group-login";
    public static final LAYOUT_GROUP_TOAST:String = "layout-group-toast";
    public static final LAYOUT_GROUP_TOAST_CONTAINER:String = "layout-group-toast-container";
    public static final LAYOUT_GROUP_PERCENTAGE_BAR:String = "layout-group-percentage-bar";
    public static final PAGE_INDICATOR_INVISIBLE:String = "page-indicator-invisible";
    public static final TEXT_AREA_PRIVACY:String = "text-area-privacy";

    public static final ICON_CHECKBOX_LARGE:String = "assets/images/common/checkbox_large.png";
    public static final ICON_CHECKBOX_LARGE_DISABLED:String = "assets/images/common/checkbox_large_disabled.png";
    public static final ICON_CHECKBOX_LARGE_SELECTED:String = "assets/images/common/checkbox_large_selected.png";
    public static final ICON_CLEAR:String = "assets/images/common/clear.png";
    public static final ICON_CLOSE:String = "assets/images/common/close.png";
    public static final ICON_CONSOLE:String = "assets/images/common/console.png";
    public static final ICON_COPY:String = "assets/images/common/copy.png";
    public static final ICON_DELETE:String = "assets/images/common/delete.png";
    public static final ICON_DESTROY:String = "assets/images/common/destroy.png";
    public static final ICON_DESTROY_SMALL:String = "assets/images/common/destroy_small.png";
    public static final ICON_ERROR:String = "assets/images/common/error.png";
    public static final ICON_FOLDER:String = "assets/images/common/folder.png";
    public static final ICON_GITHUB:String = "assets/images/common/github.png";
    public static final ICON_HELP:String = "assets/images/common/help.png";
    public static final ICON_LOCATE_FILE:String = "assets/images/common/locatefile.png";
    public static final ICON_OK:String = "assets/images/common/ok.png";
    public static final ICON_OUTPUT:String = "assets/images/common/output.png";
    public static final ICON_OUTPUT_ERROR:String = "assets/images/common/output_error.png";
    public static final ICON_OUTPUT_NEW:String = "assets/images/common/output_new.png";
    public static final ICON_REFRESH:String = "assets/images/common/refresh.png";
    public static final ICON_SETTINGS:String = "assets/images/common/settings.png";
    public static final ICON_SETTINGS_WARNING:String = "assets/images/common/settings_warning.png";
    public static final ICON_START:String = "assets/images/common/start.png";
    public static final ICON_STOP:String = "assets/images/common/stop.png";
    public static final ICON_SUSPEND:String = "assets/images/common/suspend.png";
    public static final ICON_UPLOAD:String = "assets/images/common/upload.png";
    public static final ICON_WARNING:String = "assets/images/common/warning.png";
    public static final ICON_WEB:String = "assets/images/common/web.png";

    public static final IMAGE_GENESIS_DIRECTORY:String = "assets/images/genesisdirectory.png";
    public static final IMAGE_HELP:String = "assets/images/help.png";
    public static final IMAGE_SUPPORT:String = "assets/images/support.png";

    var _mode:ThemeMode;
    var _themeColors:ThemeColors;
    var _themeTypography:Typography;

    public function new( mode:ThemeMode = ThemeMode.Dark ) {

        super();

        _mode = mode;

        _init();

    }

    function _init() {

        switch ( _mode ) {

            case ThemeMode.Light:

                _themeColors = {

                    AppGrad1 : Color.White,
                    AppGrad2 : Color.GreyA,
                    Border : Color.Grey8,
                    Box : Color.GreyD,
                    Btn : Color.Blue,
                    BtnHighlight : Color.Green,
                    BtnHighlightHover : Color.Green2,
                    BtnHover : Color.Blue2,
                    BtnText : Color.White,
                    BtnWarning: Color.Orange,
                    BtnWarningHover: Color.OrangeLight,
                    BtnWarningText : Color.Black,
                    ConsoleBackground: Color.GreyD,
                    Error: Color.Red,
                    Input : Color.GreyD,
                    InputFocus : Color.GreyD,
                    Link : Color.Blue,
                    ProgressBar: Color.Green2,
                    ProgressBarBackground: Color.GreyD,
                    Text : Color.Grey2,
                    TextConsole: Color.Grey2,
                    TextDisabled : Color.Grey8,
                    TextPale : Color.Grey4,
                    TextPrompt : Color.Grey4,
                    TextSelectionBackground: Color.Blue,
                    TextTooltip: Color.Grey4,
                    Toast : Color.Black,
                    Toolbar : Color.GreyC,
                    TooltipBackground: Color.GreyC,
                    Warning : Color.Orange,
    
                };

            default:

                _themeColors = {

                    AppGrad1 : Color.Grey2,
                    AppGrad2 : Color.DarkYellow,
                    Border : Color.Grey4,
                    Box : Color.Grey1,
                    Btn : Color.Grey4,
                    BtnHighlight : Color.Green,
                    BtnHighlightHover : Color.Green2,
                    BtnHover : Color.Grey6,
                    BtnText : Color.White,
                    BtnWarning: Color.Orange,
                    BtnWarningHover: Color.OrangeLight,
                    BtnWarningText : Color.Black,
                    ConsoleBackground: Color.Grey2,
                    Error: Color.Red,
                    Input : Color.Grey1,
                    InputFocus : Color.Grey3,
                    Link : Color.Blue,
                    ProgressBar: Color.Green2,
                    ProgressBarBackground: Color.Black,
                    Text : Color.White,
                    TextConsole: Color.White,
                    TextDisabled : Color.Grey8,
                    TextPale : Color.GreyA,
                    TextPrompt : Color.Grey8,
                    TextSelectionBackground: Color.Grey6,
                    TextTooltip: Color.GreyA,
                    Toast : Color.Black,
                    Toolbar : Color.Grey3,
                    TooltipBackground: Color.Grey2,
                    Warning : Color.Orange,
    
                };

        }

        _themeTypography = {

            Button : new TextFormat( "_sans", 14, _themeColors.BtnText ),
            ButtonWarning : new TextFormat( "_sans", 14, _themeColors.BtnWarningText ),
            Check: new TextFormat( "_sans", 14, White),
            ConsoleText:  new TextFormat( "_typewriter", 14, _themeColors.TextConsole ),
            ConsoleTextError:  new TextFormat( "_typewriter", 14, _themeColors.Error ),
            ConsoleTextSelected:  new TextFormat( "_typewriter", 14, _themeColors.TextConsole ),
            Default : new TextFormat( "_sans", 14, _themeColors.Text ),
            DefaultCentered : new TextFormat( "_sans", 14, _themeColors.Text, null, null, null, null, null, TextFormatAlign.CENTER ),
            Disabled : new TextFormat( "_sans", 14, _themeColors.TextDisabled ),
            DropDown : new TextFormat( "_sans", 14, _themeColors.Text ),
            Huge : new TextFormat( "_sans", 24, _themeColors.Text ),
            Large : new TextFormat( "_sans", 18, _themeColors.Text ),
            Link : new TextFormat( "_sans", 14, _themeColors.Link ),
            LinkSmall : new TextFormat( "_sans", 12, _themeColors.Link ),
            Medium : new TextFormat( "_sans", 16, _themeColors.Text ),
            Pale : new TextFormat( "_sans", 12, _themeColors.TextPale ),
            PaleCentered : new TextFormat( "_sans", 12, _themeColors.TextPale, null, null, null, null, null, TextFormatAlign.CENTER ),
            Prompt : new TextFormat( "_sans", 14, _themeColors.TextPrompt ),
            Title : new TextFormat( "_sans", 21, _themeColors.Text ),
            Tooltip : new TextFormat( "_sans", 13, _themeColors.TextTooltip ),

        }

        this.styleProvider.setStyleFunction( Alert, null, _setAlertStyles );
        this.styleProvider.setStyleFunction( AssetLoader, null, _setAssetLoaderStyles );
        this.styleProvider.setStyleFunction( Button, BUTTON_HIGHLIGHT, _setButtonHighlightStyles );
        this.styleProvider.setStyleFunction( Button, BUTTON_SELECT_FILE, _setButtonSelectFileStyles );
        this.styleProvider.setStyleFunction( Button, BUTTON_SMALL, _setButtonSmallStyles );
        this.styleProvider.setStyleFunction( Button, BUTTON_TINY, _setButtonTinyStyles );
        this.styleProvider.setStyleFunction( Button, BUTTON_WARNING, _setButtonWarningStyles );
        this.styleProvider.setStyleFunction( Button, BUTTON_BROWSER_WARNING, _setButtonNoBackgrounIconStyles );
        this.styleProvider.setStyleFunction( Button, GenesisFormPupUpListView.CHILD_VARIANT_BUTTON, _setPopUpListViewButtonStyles );
        this.styleProvider.setStyleFunction( Button, GenesisFormPupUpListView.CHILD_VARIANT_BUTTON_INVALID, _setPopUpListViewInvalidButtonStyles );
        this.styleProvider.setStyleFunction( Button, PopUpListView.CHILD_VARIANT_BUTTON, _setPopUpListViewButtonStyles );
        this.styleProvider.setStyleFunction( Button, null, _setButtonStyles );
        this.styleProvider.setStyleFunction( ButtonBar, Alert.CHILD_VARIANT_BUTTON_BAR, _setAlertButtonBarStyles );
        this.styleProvider.setStyleFunction( Check, CHECK_LARGE, _setCheckLargeStyles );
        this.styleProvider.setStyleFunction( Check, CHECK_MEDIUM, _setCheckMediumStyles );
        this.styleProvider.setStyleFunction( Form, null, _setFormStyles );
        this.styleProvider.setStyleFunction( FormItem, null, _setFormItemStyles );
        this.styleProvider.setStyleFunction( GenesisForm, null, _setGenesisFormStyles );
        this.styleProvider.setStyleFunction( GenesisFormButton, INVALID, _setGenesisFormButtonInvalidStyles );
        this.styleProvider.setStyleFunction( GenesisFormButton, null, _setGenesisFormButtonStyles );
        this.styleProvider.setStyleFunction( GenesisFormCheckBox, null, _setGenesisFormCheckBoxStyles );
        this.styleProvider.setStyleFunction( GenesisFormPupUpListView, INVALID, _setGenesisFormPupUpListViewInvalidStyles );
        this.styleProvider.setStyleFunction( GenesisFormPupUpListView, null, _setGenesisFormPupUpListViewStyles );
        this.styleProvider.setStyleFunction( GenesisFormRow, null, _setGenesisFormRowStyles );
        this.styleProvider.setStyleFunction( GenesisFormRowContent, null, _setGenesisFormRowContentStyles );
        this.styleProvider.setStyleFunction( GenesisFormTextInput, INVALID, _setGenesisTextInputInvalidStyles );
        this.styleProvider.setStyleFunction( GenesisFormTextInput, null, _setGenesisTextInputStyles );
        this.styleProvider.setStyleFunction( Header, Alert.CHILD_VARIANT_HEADER, _setAlertHeaderStyles );
        this.styleProvider.setStyleFunction( Label, Alert.CHILD_VARIANT_MESSAGE_LABEL, _setLabelAlertStyles );
        this.styleProvider.setStyleFunction( Label, DefaultToolTipManager.CHILD_VARIANT_TOOL_TIP, _setToolTipStyles );
        this.styleProvider.setStyleFunction( Label, LABEL_CENTERED, _setLabelCenteredStyles );
        this.styleProvider.setStyleFunction( Label, LABEL_COPYRIGHT, _setLabelCopyrightStyles );
        this.styleProvider.setStyleFunction( Label, LABEL_COPYRIGHT_CENTER, _setLabelCopyrightCenterStyles );
        this.styleProvider.setStyleFunction( Label, LABEL_HUGE, _setLabelHugeStyles );
        this.styleProvider.setStyleFunction( Label, LABEL_LARGE, _setLabelLargeStyles );
        this.styleProvider.setStyleFunction( Label, LABEL_LINK, _setLabelLinkStyles );
        this.styleProvider.setStyleFunction( Label, LABEL_LINK_SMALL, _setLabelLinkSmallStyles );
        this.styleProvider.setStyleFunction( Label, LABEL_SMALL_CENTERED, _setLabelSmallCenteredStyles );
        this.styleProvider.setStyleFunction( Label, LABEL_TITLE, _setLabelTitleStyles );
        this.styleProvider.setStyleFunction( Label, LABEL_ERROR, _setLabelErrorStyles );
        this.styleProvider.setStyleFunction( Label, null, _setLabelStyles );
        this.styleProvider.setStyleFunction( LayoutGroup, APPLICATION, _setApplicationLayoutGroupStyles );
        this.styleProvider.setStyleFunction( LayoutGroup, LAYOUT_GROUP_CREATE_ACCOUNT, _setLayoutGroupCreateAccountStyles );
        this.styleProvider.setStyleFunction( LayoutGroup, LAYOUT_GROUP_FOOTER, _setLayoutGroupFooterStyles );
        this.styleProvider.setStyleFunction( LayoutGroup, LAYOUT_GROUP_HEADER, _setLayoutGroupHeaderStyles );
        this.styleProvider.setStyleFunction( LayoutGroup, LAYOUT_GROUP_HORIZONTAL_LINE, _setLayoutGroupHorizontalLineStyles );
        this.styleProvider.setStyleFunction( LayoutGroup, LAYOUT_GROUP_PERCENTAGE_BAR, _setProgressBarpercentageBarStyles );
        this.styleProvider.setStyleFunction( LayoutGroup, LAYOUT_GROUP_TOAST_CONTAINER, _setLayoutGroupToastContainerStyles );
        this.styleProvider.setStyleFunction( MainMenu, null, _setMainMenuStyles );
        this.styleProvider.setStyleFunction( MainMenuButton, null, _setMainMenuButtonStyles );
        this.styleProvider.setStyleFunction( Page, LAYOUT_GROUP_LOGIN, _setPageLoginStyles );
        this.styleProvider.setStyleFunction( Page, null, _setPageStyles );
        this.styleProvider.setStyleFunction( PageIndicator, PAGE_INDICATOR_INVISIBLE, _setPageIndicatorInvisibleStyles );
        this.styleProvider.setStyleFunction( ProgressBar, null, _setProgressBarStyles );
        this.styleProvider.setStyleFunction( TextArea, TEXT_AREA_PRIVACY, _setTextAreaPrivacyStyles );
        this.styleProvider.setStyleFunction( TextInput, null, _setTextInputStyles );
        this.styleProvider.setStyleFunction( Toast, null, _setToastStyles );

    }

    function _setApplicationLayoutGroupStyles( group:LayoutGroup ) {

        //var r = new RectangleSkin( FillStyle.SolidColor( Color.Grey2 ) );
        var r = new RectangleSkin( FillStyle.Gradient( GradientType.LINEAR, [ _themeColors.AppGrad1, _themeColors.AppGrad2 ], [ 1, 1 ], [ 160, 255 ], CreateGradientBoxMatrix.fromRadians( .5 * Math.PI ) ) );
        group.backgroundSkin = r;

    }

    function _setAssetLoaderStyles( loader:AssetLoader ) {

        loader.scaleX = loader.scaleY = .5;

    }

    function _setButtonStyles( button:Button ) {

        button.textFormat = _themeTypography.Button;
        button.paddingLeft = button.paddingRight = GRID * 2;
        button.paddingBottom = button.paddingTop = GRID;
        button.minWidth = GRID * 10;
        button.disabledTextFormat = _themeTypography.Disabled;

        var defaultSkin = new RectangleSkin( FillStyle.SolidColor( _themeColors.Btn ) );
        defaultSkin.cornerRadius = CORNER_RADIUS;
        button.backgroundSkin = defaultSkin;

        var hoverSkin = new RectangleSkin( FillStyle.SolidColor( _themeColors.BtnHover ) );
        hoverSkin.cornerRadius = CORNER_RADIUS;
        button.setSkinForState( ButtonState.HOVER, hoverSkin );

        var disabledSkin = new RectangleSkin( FillStyle.SolidColor( _themeColors.Btn ) );
        disabledSkin.cornerRadius = CORNER_RADIUS;
        disabledSkin.alpha = DISABLED_ALPHA;
        button.setSkinForState( ButtonState.DISABLED, disabledSkin );

    }

    function _setCheckLargeStyles( check:Check ) {

        check.textFormat = _themeTypography.Large;
        check.icon = new AdvancedAssetLoader( ( _mode == ThemeMode.Dark ) ? getAssetPath( ICON_CHECKBOX_LARGE ) : getAssetPath( ICON_CHECKBOX_LARGE ) );
        check.selectedIcon = new AdvancedAssetLoader( ( _mode == ThemeMode.Dark ) ? getAssetPath( ICON_CHECKBOX_LARGE_SELECTED ) : getAssetPath( ICON_CHECKBOX_LARGE_SELECTED ) );
        check.horizontalAlign = HorizontalAlign.LEFT;

    }

    function _setCheckMediumStyles( check:Check ) {

        check.textFormat = _themeTypography.Medium;
        check.icon = new AdvancedAssetLoader( ( _mode == ThemeMode.Dark ) ? getAssetPath( ICON_CHECKBOX_LARGE ) : getAssetPath( ICON_CHECKBOX_LARGE ) );
        check.selectedIcon = new AdvancedAssetLoader( ( _mode == ThemeMode.Dark ) ? getAssetPath( ICON_CHECKBOX_LARGE_SELECTED ) : getAssetPath( ICON_CHECKBOX_LARGE_SELECTED ) );
        check.horizontalAlign = HorizontalAlign.LEFT;

    }

    function _setButtonWarningStyles( button:Button ) {

        button.textFormat = _themeTypography.ButtonWarning;
        button.paddingLeft = button.paddingRight = GRID * 2;
        button.paddingBottom = button.paddingTop = GRID;
        button.disabledAlpha = .5;
        button.minWidth = GRID * 14;
        button.disabledTextFormat = _themeTypography.Disabled;

        var defaultSkin = new RectangleSkin( FillStyle.SolidColor( _themeColors.BtnWarning ) );
        defaultSkin.cornerRadius = CORNER_RADIUS;
        button.backgroundSkin = defaultSkin;

        var hoverSkin = new RectangleSkin( FillStyle.SolidColor( _themeColors.BtnWarningHover ) );
        hoverSkin.cornerRadius = CORNER_RADIUS;
        button.setSkinForState( ButtonState.HOVER, hoverSkin );

        var disabledSkin = new RectangleSkin( FillStyle.SolidColor( _themeColors.Warning ) );
        disabledSkin.cornerRadius = CORNER_RADIUS;
        disabledSkin.alpha = DISABLED_ALPHA;
        button.setSkinForState( ButtonState.DISABLED, disabledSkin );

    }
    
    function _setButtonNoBackgrounIconStyles( button:Button ) {
    		var defaultSkin = new RectangleSkin( FillStyle.SolidColor( _themeColors.BtnWarning, 0 ) );
        button.backgroundSkin = defaultSkin;
	}

    function _setButtonSelectFileStyles( button:Button ) {

        _setButtonStyles( button );
        button.setPadding( 0 );
        button.paddingLeft = button.paddingRight = GRID;

    }

    function _setButtonHighlightStyles( button:Button ) {

        button.textFormat = _themeTypography.Button;
        button.paddingLeft = button.paddingRight = GRID * 2;
        button.paddingBottom = button.paddingTop = GRID;
        button.minWidth = GRID * 10;
        button.disabledTextFormat = _themeTypography.Disabled;

        var defaultSkin = new RectangleSkin( FillStyle.SolidColor( _themeColors.BtnHighlight ) );
        defaultSkin.cornerRadius = CORNER_RADIUS;
        button.backgroundSkin = defaultSkin;

        var hoverSkin = new RectangleSkin( FillStyle.SolidColor( _themeColors.BtnHighlightHover ) );
        hoverSkin.cornerRadius = CORNER_RADIUS;
        button.setSkinForState( ButtonState.HOVER, hoverSkin );

        var disabledSkin = new RectangleSkin( FillStyle.SolidColor( _themeColors.BtnHighlight ) );
        disabledSkin.cornerRadius = CORNER_RADIUS;
        disabledSkin.alpha = DISABLED_ALPHA;
        button.setSkinForState( ButtonState.DISABLED, disabledSkin );

    }

    function _setButtonSmallStyles( button:Button ) {

        button.setPadding( 4 );

        var defaultSkin = new CircleSkin( FillStyle.SolidColor( _themeColors.Btn ) );
        button.backgroundSkin = defaultSkin;

        var hoverSkin = new CircleSkin( FillStyle.SolidColor( _themeColors.BtnHover ) );
        button.setSkinForState( ButtonState.HOVER, hoverSkin );

        var disabledSkin = new CircleSkin( FillStyle.SolidColor( _themeColors.Btn ) );
        disabledSkin.alpha = DISABLED_ALPHA;
        button.setSkinForState( ButtonState.DISABLED, disabledSkin );

    }

    function _setButtonTinyStyles( button:Button ) {

        _setButtonStyles( button );
        button.setPadding( 0 );
        button.paddingLeft = button.paddingRight = GRID;
        button.textFormat = _themeTypography.Pale;
        button.disabledTextFormat = _themeTypography.Pale;
        button.disabledAlpha = .5;

    }

    function _setFormStyles( form:Form ) { }

    function _setFormItemStyles( item:FormItem ) { }

    function _setGenesisFormStyles( form:GenesisForm ) {

        form.width = GRID * 100;
        var layout = new VerticalLayout();
        layout.gap = GRID * 2;
        form.layout = layout;

    }

    function _setGenesisFormRowStyles( row:GenesisFormRow ) {

        row.layoutData = new VerticalLayoutData( 100 );
        var layout = new HorizontalLayout();
        layout.gap = GRID * 2;
        layout.verticalAlign = VerticalAlign.MIDDLE;
        row.layout = layout;

    }

    function _setGenesisTextInputStyles( textInput:GenesisFormTextInput ) {

        _setTextInputStyles( textInput );

    }

    function _setGenesisTextInputInvalidStyles( textInput:GenesisFormTextInput ) {

        _setGenesisTextInputStyles( textInput );
        var r = new RectangleSkin( FillStyle.SolidColor( _themeColors.Input ), LineStyle.SolidColor( 1, _themeColors.Error ) );
        r.cornerRadius = CORNER_RADIUS;
        textInput.backgroundSkin = r;

    }

    function _setGenesisFormButtonStyles( button:GenesisFormButton ) {

        _setButtonStyles( button );

    }

    function _setGenesisFormCheckBoxStyles( cb:GenesisFormCheckBox ) {

        cb.textFormat = _themeTypography.Default;
        cb.icon = new AdvancedAssetLoader( ( _mode == ThemeMode.Dark ) ? getAssetPath( ICON_CHECKBOX_LARGE ) : getAssetPath( ICON_CHECKBOX_LARGE ) );
        cb.selectedIcon = new AdvancedAssetLoader( ( _mode == ThemeMode.Dark ) ? getAssetPath( ICON_CHECKBOX_LARGE_SELECTED ) : getAssetPath( ICON_CHECKBOX_LARGE_SELECTED ) );
        cb.horizontalAlign = HorizontalAlign.LEFT;

    }

    function _setGenesisFormButtonInvalidStyles( button:GenesisFormButton ) {

        _setButtonStyles( button );

        var defaultSkin = new RectangleSkin( FillStyle.SolidColor( _themeColors.Btn ), LineStyle.SolidColor( 1, _themeColors.Error ) );
        defaultSkin.cornerRadius = CORNER_RADIUS;
        button.backgroundSkin = defaultSkin;

        var hoverSkin = new RectangleSkin( FillStyle.SolidColor( _themeColors.BtnHover ), LineStyle.SolidColor( 1, _themeColors.Error ) );
        hoverSkin.cornerRadius = CORNER_RADIUS;
        button.setSkinForState( ButtonState.HOVER, hoverSkin );

    }

    function _setGenesisFormPupUpListViewStyles( view:GenesisFormPupUpListView ) {

        view.customButtonVariant = GenesisFormPupUpListView.CHILD_VARIANT_BUTTON;

    }

    function _setGenesisFormPupUpListViewInvalidStyles( view:GenesisFormPupUpListView ) {

        view.customButtonVariant = GenesisFormPupUpListView.CHILD_VARIANT_BUTTON_INVALID;

    }

    function _setGenesisFormRowContentStyles( content:GenesisFormRowContent ) {

        var l = new HorizontalLayout();
        l.verticalAlign = VerticalAlign.MIDDLE;
        l.gap = GRID * 2;
        content.layout = l;

    }

    function _setLabelStyles( label:Label ) {

        label.textFormat = _themeTypography.Default;

    }

    function _setLabelCenteredStyles( label:Label ) {

        label.textFormat = _themeTypography.DefaultCentered;

    }

    function _setLabelLargeStyles( label:Label ) {

        label.textFormat = _themeTypography.Large;

    }

    function _setLabelCopyrightStyles( label:Label ) {

        label.textFormat = _themeTypography.Pale;

    }

    function _setLabelCopyrightCenterStyles( label:Label ) {

        label.textFormat = _themeTypography.Pale.clone();
        label.textFormat.align = TextFormatAlign.CENTER;

    }

    function _setLabelSmallCenteredStyles( label:Label ) {

        label.textFormat = _themeTypography.PaleCentered;

    }

    function _setLabelLinkStyles( label:Label ) {

        label.textFormat = _themeTypography.Link;
        label.buttonMode = label.useHandCursor = true;

    }

    function _setLabelLinkSmallStyles( label:Label ) {

        label.textFormat = _themeTypography.LinkSmall;
        label.buttonMode = label.useHandCursor = true;

    }

    function _setLabelTitleStyles( label:Label ) {

        label.textFormat = _themeTypography.Title;

    }

    function _setLabelErrorStyles( label:Label ) {
    		label.textFormat = _themeTypography.ConsoleTextError;
    }
    
    function _setLabelHugeStyles( label:Label ) {

        label.textFormat = _themeTypography.Huge;

    }

    function _setLayoutGroupCreateAccountStyles( group:LayoutGroup ) {

        var layout = new VerticalLayout();
        layout.paddingTop = GRID * 2;
        layout.verticalAlign = VerticalAlign.MIDDLE;
        layout.horizontalAlign = HorizontalAlign.CENTER;
        group.layout = layout;

    }

    function _setLayoutGroupFooterStyles( group:LayoutGroup ) {

        group.height = GRID * 6;
        group.backgroundSkin = new RectangleSkin( FillStyle.SolidColor( _themeColors.Toolbar ) );

        var layout = new HorizontalLayout();
        layout.paddingLeft = layout.paddingRight = GRID * 2;
        layout.verticalAlign = VerticalAlign.MIDDLE;
        layout.horizontalAlign = HorizontalAlign.CENTER;
        group.layout = layout;

    }

    function _setLayoutGroupHeaderStyles( group:LayoutGroup ) {

        group.height = GRID * 10;
        group.backgroundSkin = new RectangleSkin( FillStyle.SolidColor( _themeColors.Toolbar ) );

        var layout = new HorizontalLayout();
        layout.verticalAlign = VerticalAlign.MIDDLE;
        layout.setPadding( GRID * 2 );
        layout.gap = GRID * 2;
        group.layout = layout;

    }

    function _setLayoutGroupHorizontalLineStyles( group:LayoutGroup ) {

        group.backgroundSkin = new RectangleSkin( FillStyle.SolidColor( _themeColors.Border ) );
        group.height = 1;

    }

    function _setLayoutGroupToastContainerStyles( group:LayoutGroup ) {
        
        group.height = group.maxHeight = GRID * 32;
		group.layoutData = new AnchorLayoutData( null, 0, GRID * 10, 0 );
		var _toastGroupLayout = new VerticalLayout();
        _toastGroupLayout.gap = GRID;
		_toastGroupLayout.horizontalAlign = HorizontalAlign.CENTER;
		_toastGroupLayout.verticalAlign = VerticalAlign.BOTTOM;
		group.layout = _toastGroupLayout;

    }

    function _setPageStyles( page:Page ) {

        var layout = new VerticalLayout();
        layout.horizontalAlign = HorizontalAlign.CENTER;
        layout.verticalAlign = VerticalAlign.MIDDLE;
        layout.gap = GenesisApplicationTheme.GRID * 2;

        page.layout = layout;

    }

    function _setPageLoginStyles( page:Page ) {

        _setPageStyles( page );

    }


    function _setPageIndicatorInvisibleStyles( indicator:PageIndicator ) {

        indicator.layout = new HorizontalLayout();
        indicator.visible = indicator.includeInLayout = false;

    }

    function _setPopUpListViewButtonStyles( button:Button ) {
        
        _setButtonStyles( button );

        button.textFormat = _themeTypography.DropDown;

        var defaultSkin = new RectangleSkin( FillStyle.SolidColor( _themeColors.Btn, 0 ), LineStyle.SolidColor( 1, _themeColors.Border ) );
        defaultSkin.cornerRadius = 3;
        button.backgroundSkin = defaultSkin;

        var hoverSkin = new RectangleSkin( FillStyle.SolidColor( _themeColors.BtnHover, .33 ), LineStyle.SolidColor( 1, _themeColors.Border ) );
        hoverSkin.cornerRadius = 3;
        button.setSkinForState( ButtonState.HOVER, hoverSkin );

        button.textFormat.align = TextFormatAlign.LEFT;
        button.horizontalAlign = HorizontalAlign.LEFT;
        button.iconPosition = RelativePosition.RIGHT;
        //var bmp = AssetManager.getTilemap( ICON_EXPAND_MORE );
        //button.icon = bmp;
        button.minGap = GRID * 4;

    }

    function _setPopUpListViewInvalidButtonStyles( button:Button ) {
        
        _setButtonStyles( button );

        button.textFormat = _themeTypography.DropDown;

        var defaultSkin = new RectangleSkin( FillStyle.SolidColor( _themeColors.Btn, 0 ), LineStyle.SolidColor( 1, _themeColors.Error ) );
        defaultSkin.cornerRadius = 3;
        button.backgroundSkin = defaultSkin;

        var hoverSkin = new RectangleSkin( FillStyle.SolidColor( _themeColors.BtnHover, .33 ), LineStyle.SolidColor( 1, _themeColors.Error ) );
        hoverSkin.cornerRadius = 3;
        button.setSkinForState( ButtonState.HOVER, hoverSkin );

        button.textFormat.align = TextFormatAlign.LEFT;
        button.horizontalAlign = HorizontalAlign.LEFT;
        button.iconPosition = RelativePosition.RIGHT;
        //var bmp = AssetManager.getTilemap( ICON_EXPAND_MORE );
        //button.icon = bmp;
        button.minGap = GRID * 4;

    }

    function _setTextInputStyles( input:TextInput ) {

        input.textFormat = _themeTypography.Default;
        input.promptTextFormat = _themeTypography.Prompt;

        var r = new RectangleSkin( FillStyle.SolidColor( _themeColors.Input ), LineStyle.SolidColor( 1, _themeColors.Border ) );
        r.setFillForState( TextInputState.FOCUSED, FillStyle.SolidColor( _themeColors.InputFocus ) );
        r.cornerRadius = CORNER_RADIUS;
        input.backgroundSkin = r;
        input.paddingBottom = input.paddingTop = GRID;
        input.paddingLeft = input.paddingRight = GRID * 2;
        var dr = new RectangleSkin( FillStyle.SolidColor( _themeColors.Input, .5 ), LineStyle.SolidColor( 1, _themeColors.Border, .5 ) );
        dr.cornerRadius = CORNER_RADIUS;
        input.setSkinForState( TextInputState.DISABLED, dr );
        input.disabledTextFormat = _themeTypography.Disabled;

    }

    function _setToastStyles( toast:Toast ) {

        var _toastLayout = new HorizontalLayout();
        _toastLayout.gap = GRID * 2;
        _toastLayout.paddingLeft = _toastLayout.paddingRight = GRID * 3;
        _toastLayout.verticalAlign = VerticalAlign.MIDDLE;
        toast.layout = _toastLayout;

        toast.layoutData = new VerticalLayoutData();
        var bg = new RectangleSkin( FillStyle.SolidColor( _themeColors.Toast ) );
        bg.cornerRadius = GRID;
        toast.backgroundSkin = bg;

        toast.height = GRID * 6;

    }

    function _setToolTipStyles( label:Label ) {

        var r = new RectangleSkin( FillStyle.SolidColor( _themeColors.TooltipBackground ), LineStyle.SolidColor( 1, _themeColors.Border ) );
        r.cornerRadius = CORNER_RADIUS * 2;
        label.backgroundSkin = r;
        label.maxWidth = GRID * 50;
        label.setPadding( GRID );
        label.wordWrap = true;
        label.textFormat = _themeTypography.Tooltip;

    }

    function _setMainMenuStyles( menu:MainMenu ) {

        var layout = new HorizontalLayout();
        layout.gap = GRID * 2;
        layout.verticalAlign = VerticalAlign.MIDDLE;
        menu.layout = layout;

    }

    function _setMainMenuButtonStyles( button:MainMenuButton ) {

        button.textFormat = _themeTypography.Button;
        button.paddingLeft = button.paddingRight = GRID * 2;
        button.paddingBottom = button.paddingTop = GRID;
        button.minWidth = GRID * 10;
        button.disabledTextFormat = _themeTypography.Disabled;

        var defaultSkin = new RectangleSkin( FillStyle.SolidColor( _themeColors.Btn ) );
        defaultSkin.alpha = 0;
        defaultSkin.cornerRadius = CORNER_RADIUS;
        button.backgroundSkin = defaultSkin;

        var hoverSkin = new RectangleSkin( FillStyle.SolidColor( _themeColors.BtnHover ) );
        hoverSkin.cornerRadius = CORNER_RADIUS;
        button.setSkinForState( ButtonState.HOVER, hoverSkin );
        button.setSkinForState( ButtonState.DOWN, hoverSkin );

        var disabledSkin = new RectangleSkin( FillStyle.SolidColor( _themeColors.Btn ) );
        disabledSkin.cornerRadius = CORNER_RADIUS;
        disabledSkin.alpha = DISABLED_ALPHA;
        button.setSkinForState( ButtonState.DISABLED, disabledSkin );

    }

    function _setTextAreaPrivacyStyles( textArea:TextArea ) {

        var r = new RectangleSkin( FillStyle.SolidColor( _themeColors.Box ) );
        r.width = r.height = 100;
        textArea.backgroundSkin = r;
        textArea.setPadding( GRID );
        textArea.textFormat = _themeTypography.Default;

    }

    function _setProgressBarStyles( progressBar:ProgressBar ) {

        progressBar.height = GRID;

        var r = new RectangleSkin( FillStyle.SolidColor( _themeColors.ProgressBarBackground ) );
        r.cornerRadius = GRID / 2;
        progressBar.backgroundSkin = r;

    }

    function _setProgressBarpercentageBarStyles( bar:LayoutGroup ) {

        bar.height = GRID;
        bar.layoutData = new HorizontalLayoutData( 0 );

        var r = new RectangleSkin( FillStyle.SolidColor( _themeColors.ProgressBar ) );
        r.cornerRadius = GRID / 2;
        bar.backgroundSkin = r;

    }

    function _setAlertStyles( alert:Alert ) {

        var r = new RectangleSkin( FillStyle.SolidColor( _themeColors.Box ) );
        alert.backgroundSkin = r;
        alert.maxWidth = GRID * 80;

        var shadow = new DropShadowFilter( GRID * 2, 90, 0, 1, GRID * 6, GRID * 6, .5 );
        alert.filters = [ shadow ];

    }

    function _setLabelAlertStyles( label:Label ) {

        _setLabelStyles( label );
        label.setPadding( GRID * 2 );
        label.wordWrap = true;
        label.maxWidth = GRID * 80;

    }

    function _setAlertHeaderStyles( header:Header ) {

        var r = new RectangleSkin( FillStyle.SolidColor( _themeColors.Toolbar ) );
        header.backgroundSkin = r;
        header.paddingBottom = header.paddingLeft = header.paddingRight = header.paddingTop = GRID * 2;
        header.textFormat = _themeTypography.Large;

    }

    function _setAlertButtonBarStyles( buttonBar:ButtonBar ) {

        var r = new RectangleSkin( FillStyle.SolidColor( _themeColors.Box ) );
        buttonBar.backgroundSkin = r;

        var layout = new HorizontalLayout();
        layout.horizontalAlign = HorizontalAlign.CENTER;
        layout.gap = GRID * 2;
        layout.setPadding( GRID * 2 );
        buttonBar.layout = layout;
        buttonBar.layoutData = new VerticalLayoutData( 100 );

    }

}

enum ThemeMode {

    Dark;
    Light;

}

enum abstract Color( Int ) to Int {
    
    var Black = 0x000000;
    var Blue = 0x4e84ff;
    var Blue2 = 0x2d65e5;
    var DarkBlue = 0x24272d;
    var DarkYellow = 0x2d2d24;
    var Green = 0x158532;
    var Green2 = 0x12b33c;
    var Grey1 = 0x111111;
    var Grey2 = 0x222222;
    var Grey3 = 0x333333;
    var Grey4 = 0x444444;
    var Grey6 = 0x666666;
    var Grey8 = 0x888888;
    var GreyA = 0xAAAAAA;
    var GreyB = 0xBBBBBB;
    var GreyC = 0xCCCCCC;
    var GreyD = 0xDDDDDD;
    var Orange = 0xFFAE00;
    var OrangeLight = 0xFFC74E;
    var Red = 0xff3a3a;
    var White = 0xFFFFFF;

}

typedef ThemeColors = {

    var AppGrad1:Int;
    var AppGrad2:Int;
    var Border:Int;
    var Box:Int;
    var Btn:Int;
    var BtnHighlight:Int;
    var BtnHighlightHover:Int;
    var BtnHover:Int;
    var BtnText:Int;
    var BtnWarning:Int;
    var BtnWarningHover:Int;
    var BtnWarningText:Int;
    var ConsoleBackground:Int;
    var Error:Int;
    var Input:Int;
    var InputFocus:Int;
    var Link:Int;
    var ProgressBar:Int;
    var ProgressBarBackground:Int;
    var Text:Int;
    var TextConsole:Int;
    var TextDisabled:Int;
    var TextPale:Int;
    var TextPrompt:Int;
    var TextSelectionBackground:Int;
    var TextTooltip:Int;
    var Toast:Int;
    var Toolbar:Int;
    var TooltipBackground:Int;
    var Warning:Int;

}

typedef Typography = {

    var Button:TextFormat;
    var ButtonWarning:TextFormat;
    var Check:TextFormat;
    var ConsoleText:TextFormat;
    var ConsoleTextError:TextFormat;
    var ConsoleTextSelected:TextFormat;
    var Default:TextFormat;
    var DefaultCentered:TextFormat;
    var Disabled:TextFormat;
    var DropDown:TextFormat;
    var Huge:TextFormat;
    var Large:TextFormat;
    var Link:TextFormat;
    var LinkSmall:TextFormat;
    var Medium:TextFormat;
    var Pale:TextFormat;
    var PaleCentered:TextFormat;
    var Prompt:TextFormat;
    var Title:TextFormat;
    var Tooltip:TextFormat;

}