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
package superhuman.components.browsers;

import openfl.events.MouseEvent;
import superhuman.components.browsers.BrowsersList.BrowserItem;
import openfl.events.Event;
import feathers.layout.VerticalAlign;
import feathers.controls.Label;
import feathers.layout.HorizontalAlign;
import superhuman.events.SuperHumanApplicationEvent;
import genesis.application.managers.LanguageManager;
import feathers.controls.Button;
import feathers.layout.HorizontalLayout;
import genesis.application.theme.GenesisApplicationTheme;
import feathers.layout.VerticalLayoutData;
import genesis.application.components.HLine;
import genesis.application.components.Page;
import feathers.controls.LayoutGroup;
import feathers.layout.VerticalLayout;
import feathers.layout.HorizontalLayoutData;
import feathers.data.ArrayCollection;
import superhuman.browser.BrowserData;
import feathers.events.TriggerEvent;
import feathers.skins.RectangleSkin;

class BrowsersPage extends Page {
	
	final _width:Float = GenesisApplicationTheme.GRID * 100;
	var _titleGroup:LayoutGroup;
	var _titleLabel:Label;
	
	var _hintGroup:LayoutGroup;
	var _hintLabel:Label;
	
    var _browsersList:BrowsersList;
    
    var _buttonGroup:LayoutGroup;
    var _buttonGroupLayout:HorizontalLayout;
    var _buttonClose:Button;
    
    var _browsers:ArrayCollection<BrowserData>;
   
    public function new( browsers:Array<BrowserData> ) {

        super();

        _browsers = new ArrayCollection(browsers);
    }

    override function initialize() {

        super.initialize();
  		
        var skin = new RectangleSkin();
			skin.border = SolidColor(1.0, 0x999999);
			skin.fill = SolidColor(0xcccccc);
			
        var titleGroupLayout = new VerticalLayout();
        		titleGroupLayout.horizontalAlign = HorizontalAlign.LEFT;
        		titleGroupLayout.verticalAlign = VerticalAlign.MIDDLE;
        		
        _titleGroup = new LayoutGroup();
        _titleGroup.layout = titleGroupLayout;
        _titleGroup.width = _width;
        this.addChild( _titleGroup );

        _titleLabel = new Label();
        _titleLabel.text = LanguageManager.getInstance().getString( 'settingspage.browser.titlesetupbrowser' );
        _titleLabel.variant = GenesisApplicationTheme.LABEL_LARGE;
        _titleLabel.layoutData = new HorizontalLayoutData( 100 );
        _titleGroup.addChild( _titleLabel );
        
        var line = new HLine();
            line.width = _width;
    	    this.addChild( line );
    	    
    	    titleGroupLayout = new VerticalLayout();
        titleGroupLayout.horizontalAlign = HorizontalAlign.RIGHT;
    		titleGroupLayout.verticalAlign = VerticalAlign.MIDDLE;
        		
        _hintGroup = new LayoutGroup();
        _hintGroup.layout = titleGroupLayout;
        _hintGroup.width = _width;
        this.addChild(_hintGroup);
        
        _hintLabel = new Label();
        _hintLabel.text = LanguageManager.getInstance().getString('settingspage.browser.doubleclickhint');
        _hintLabel.variant = GenesisApplicationTheme.LABEL_COPYRIGHT;
        _hintGroup.addChild(_hintLabel);
        
  		_browsersList = new BrowsersList(_browsers);
  		_browsersList.doubleClickEnabled = true;
  		_browsersList.addEventListener( MouseEvent.DOUBLE_CLICK, _browserListChanged );
  		_browsersList.addEventListener(BrowserItem.BROWSER_ITEM_CHANGE, _browserItemChange);
  		_browsersList.width = _width;
  		this.addChild(_browsersList);

        line = new HLine();
        line.width = _width;
    	    this.addChild( line );
    	      
        _buttonGroup = new LayoutGroup();
        _buttonGroupLayout = new HorizontalLayout();
        _buttonGroupLayout.gap = GenesisApplicationTheme.GRID * 2;
        _buttonGroupLayout.horizontalAlign = HorizontalAlign.CENTER;
        _buttonGroup.layout = _buttonGroupLayout;
        this.addChild( _buttonGroup );

        _buttonClose = new Button( LanguageManager.getInstance().getString( 'rolepage.buttons.close' ) );
        _buttonClose.addEventListener( TriggerEvent.TRIGGER, _buttonCloseTriggered );
        _buttonGroup.addChild( _buttonClose );
    }
    
    public function refreshBrowsers() {
    		_browsersList.dataProvider.updateAll();
    }
    
    function _browserListChanged(e:Event) {
    		var browserData:BrowserData = _browsersList.selectedItem;	
    		if (browserData == null) return;
    		
    		var setupBrowserEvent = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.SETUP_BROWSER);
    			setupBrowserEvent.browserData = browserData;
    		
    		this.dispatchEvent( setupBrowserEvent );
    }
    
    function _browserItemChange(e:SuperHumanApplicationEvent) {
    		var setupBrowserEvent = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.SAVE_APP_BROWSERS_CONFIGURATION);
    			setupBrowserEvent.browserData = e.browserData;
    		
    		this.dispatchEvent( setupBrowserEvent );	
    }
    
    function _buttonCloseTriggered( e:TriggerEvent ) {
        this.dispatchEvent( new SuperHumanApplicationEvent( SuperHumanApplicationEvent.CLOSE_BROWSERS ) );
    }
}