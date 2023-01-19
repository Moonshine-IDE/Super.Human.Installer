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
import feathers.layout.HorizontalLayout;
import feathers.layout.HorizontalLayoutData;
import genesis.application.theme.GenesisApplicationTheme;

@:styleContext
class ProgressBar extends LayoutGroup {

    var _layout:HorizontalLayout;
    var _percentageBar:LayoutGroup;

    public var percentage( never, set ):Float;
    function set_percentage( value:Float ):Float {
        if ( _percentageBar != null ) cast( _percentageBar.layoutData, HorizontalLayoutData ).percentWidth = value;
        return value;
    }
    
    public function new() {

        super();

    }

    override function initialize() {

        super.initialize();

        _layout = new HorizontalLayout();
        this.layout = _layout;

        _percentageBar = new LayoutGroup();
        _percentageBar.variant = GenesisApplicationTheme.LAYOUT_GROUP_PERCENTAGE_BAR;
        this.addChild( _percentageBar );

    }

}