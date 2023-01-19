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

package genesis.application.components;

import feathers.controls.LayoutGroup;
import feathers.layout.HorizontalAlign;
import feathers.layout.VerticalAlign;
import feathers.layout.VerticalLayout;
import feathers.layout.VerticalLayoutData;
import genesis.application.events.GenesisApplicationEvent;
import genesis.application.theme.GenesisApplicationTheme;
import openfl.display.DisplayObject;
import superhuman.events.SuperHumanApplicationEvent;
import superhuman.theme.SuperHumanInstallerTheme;

@:styleContext
class Page extends LayoutGroup {

    var _content:LayoutGroup;
    var _overlay:LayoutGroup;

    public function new() {

        super();

        var lyt = new VerticalLayout();
        lyt.horizontalAlign = HorizontalAlign.CENTER;
        lyt.verticalAlign = VerticalAlign.MIDDLE;
        lyt.setPadding( GenesisApplicationTheme.GRID * 2 );
        lyt.gap = GenesisApplicationTheme.GRID * 2;

        _content = new LayoutGroup();
        _content.maxWidth = GenesisApplicationTheme.GRID * 125;
        _content.layout = lyt;
        _content.layoutData = new VerticalLayoutData( 100, 100 );
        super.addChild( _content );

        _overlay = new LayoutGroup();
        _overlay.includeInLayout = false;
        _overlay.variant = SuperHumanInstallerTheme.LAYOUT_GROUP_APP_CHECKER_OVERLAY;
		_overlay.visible = false;
        super.addChild( _overlay );

    }

    override function addChild( child:DisplayObject ):DisplayObject {

        return _content.addChildAt(child, _content.numChildren);

    }

    override function update() {

        super.update();

        _overlay.width = this.parent.parent.width;
        _overlay.height = this.parent.parent.height;

    }

    public function updateContent( forced:Bool = false ) { }

    function _forwardEvent( e:GenesisApplicationEvent ) {

        this.dispatchEvent( e );

    }

    function _cancel( ?e:Dynamic ) {

        this.dispatchEvent( new SuperHumanApplicationEvent( SuperHumanApplicationEvent.CANCEL_PAGE ) );

    }

}