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

import feathers.layout.VerticalListLayout;
import feathers.layout.VerticalLayout;
import feathers.layout.HorizontalLayoutData;
import feathers.layout.VerticalLayoutData;
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

@:styleContext
class BrowsersList extends ListView {

    public function new( ?dataProvider:IFlatCollection<BrowserData> ) {

        super( dataProvider );
		
        this.layout = new VerticalListLayout();
        
        var recycler = DisplayObjectRecycler.withFunction( () -> {

            var item = new BrowserItem();
            return item;

        } );
		
        recycler.update = ( item:BrowserItem, state:ListViewItemState) -> {
			item.updateBroswer(state.data);
        };

        recycler.reset = ( item:BrowserItem, state:ListViewItemState) -> {

        

        };

        recycler.destroy = ( item:BrowserItem ) -> {

            

        };

        this.itemRendererRecycler = recycler;

    }

    function _forwardEvent( e:SuperHumanApplicationEvent ) {

        this.dispatchEvent( e );

    }

}

@:styleContext
class BrowserItem extends LayoutGroupItemRenderer {

    var _labelBrowserGroupLayout:HorizontalLayout;
	var _labelBrowserGroup:LayoutGroup;
    var _labelBrowserName:Label;

    var _checkBrowserStatus:Check;

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
        
        _checkBrowserStatus = new Check();
        _checkBrowserStatus.enabled = false;
        this.addChild(_checkBrowserStatus);
    }
    
    public function updateBroswer(browserData:BrowserData) {
    		_labelBrowserName.text = browserData.browserName;
    }
}