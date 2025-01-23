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

package superhuman.components.applications;

import superhuman.theme.SuperHumanInstallerTheme;
import feathers.events.TriggerEvent;
import genesis.application.managers.LanguageManager;
import genesis.application.components.GenesisButton;
import feathers.skins.RectangleSkin;
import genesis.application.components.AdvancedAssetLoader;
import feathers.controls.Button;
import openfl.events.Event;
import feathers.layout.VerticalListLayout;
import feathers.layout.HorizontalLayoutData;
import feathers.layout.VerticalAlign;
import genesis.application.theme.GenesisApplicationTheme;
import feathers.data.ListViewItemState;
import feathers.controls.dataRenderers.LayoutGroupItemRenderer;
import feathers.controls.Label;
import feathers.controls.Check;
import feathers.controls.LayoutGroup;
import feathers.controls.ListView;
import feathers.layout.HorizontalLayout;
import superhuman.browser.BrowserData;
import feathers.data.IFlatCollection;
import superhuman.events.SuperHumanApplicationEvent;
import feathers.utils.DisplayObjectRecycler;
import superhuman.application.ApplicationData;

@:styleContext
class ApplicationsList extends ListView {

    public function new( ?dataProvider:IFlatCollection<ApplicationData> ) {

        super( dataProvider );
		
        this.layout = new VerticalListLayout();

        var recycler = DisplayObjectRecycler.withFunction( () -> {
			
            var item = new ApplicationItem();
            	    //item.addEventListener(BrowserItem.BROWSER_ITEM_CHANGE, _browserItemChange);
            		item.addEventListener(SuperHumanApplicationEvent.CONFIGURE_APPLICATION, _configureApp);
            		
            return item;

        } );
		
        recycler.update = ( item:ApplicationItem, state:ListViewItemState) -> {
			item.updateAppData(state.data);
        };

        recycler.reset = ( item:ApplicationItem, state:ListViewItemState) -> {
        		item.updateAppData(state.data);
        };

        recycler.destroy = ( item:ApplicationItem ) -> {
			//item.removeEventListener(BrowserItem.BROWSER_ITEM_CHANGE, _browserItemChange);
			item.removeEventListener(SuperHumanApplicationEvent.CONFIGURE_APPLICATION, _configureApp);
        };

        this.itemRendererRecycler = recycler;
    }

    function _forwardEvent( e:SuperHumanApplicationEvent ) {

        this.dispatchEvent( e );
    }
    
    function _appItemChange(e:SuperHumanApplicationEvent) {
    		_forwardEvent(e);
    }
    
    function _configureApp(e:SuperHumanApplicationEvent) {
    		_forwardEvent(e);
    }
}

@:styleContext
class ApplicationItem extends LayoutGroupItemRenderer {

	public static final APPLICATION_ITEM_CHANGE:String = "applicationItemChange";
	
    var _labelBrowserName:Label;

    var _statusGroup:LayoutGroup;
    var _buttonIconExists:Button;
    var _buttonConfigure:GenesisButton;
    
    var _appData:ApplicationData;
    
    public function new() {

        super();

    }
    
    override function initialize() {

        super.initialize();

       var horizontalLayout = new HorizontalLayout();
        	   horizontalLayout.paddingRight = 5;
        	   horizontalLayout.paddingLeft = 5;
        	   horizontalLayout.paddingTop = 5;
        	   horizontalLayout.paddingBottom = 5;
        	   horizontalLayout.verticalAlign = VerticalAlign.MIDDLE;
        		
        this.layout = horizontalLayout;

        _labelBrowserName = new Label();
        _labelBrowserName.layoutData = new HorizontalLayoutData(100);
        this.addChild(_labelBrowserName);
        
        horizontalLayout = new HorizontalLayout();
        horizontalLayout.horizontalAlign = RIGHT;
        horizontalLayout.gap = 4;
        
        _statusGroup = new LayoutGroup();
        _statusGroup.layout = horizontalLayout;        
        this.addChild(_statusGroup);
        
        _buttonIconExists = new Button();
        _buttonIconExists.variant = GenesisApplicationTheme.BUTTON_BROWSER_WARNING;
        _buttonIconExists.icon = GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_WARNING );
        _buttonIconExists.visible = _buttonIconExists.includeInLayout = false;
        _statusGroup.addChild(_buttonIconExists);
             
        _buttonConfigure = new GenesisButton(LanguageManager.getInstance().getString("settingspage.browser.configurebrowser"));
        _buttonConfigure.addEventListener(TriggerEvent.TRIGGER, _buttonConfigureTriggered);
        _statusGroup.addChild(_buttonConfigure);
    }
    
    public function updateAppData(appData:ApplicationData) {
    		_appData = appData;
    		_labelBrowserName.text = appData.appName;
    		
    		_buttonIconExists.visible = _buttonIconExists.includeInLayout = appData.exists == false;
    }

    function _buttonConfigureTriggered(event:TriggerEvent) {
    		var setupAppEvent = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.CONFIGURE_APPLICATION);
    			setupAppEvent.appData = _appData;
    		this.dispatchEvent(setupAppEvent);
    }
}