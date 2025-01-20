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

import feathers.controls.Button;
import feathers.controls.Label;
import feathers.controls.LayoutGroup;
import feathers.layout.HorizontalLayoutData;
import genesis.application.theme.GenesisApplicationTheme;

class Footer extends LayoutGroup {

    var _label:Label;
    var _iconWarning:Button;
    var _labelSysInfo:Label;
    var _spacer:LayoutGroup;

    public var appInfo( get, set ):String;
    var _appInfo:String;
    function get_appInfo():String return _appInfo;
    function set_appInfo( value:String ):String {
        _appInfo = value;
        if ( _label != null ) {
            _label.text = _appInfo;
            _spacer.includeInLayout = _spacer.visible = ( _sysInfo != null && _sysInfo != "" );
        }
        return _appInfo;
    }

    public var sysInfo( get, set ):String;
    var _sysInfo:String;
    function get_sysInfo():String return _sysInfo;
    function set_sysInfo( value:String ):String {
        _sysInfo = value;
        if ( _labelSysInfo != null ) {
            _labelSysInfo.text = _sysInfo;
            _spacer.includeInLayout = _spacer.visible = ( _sysInfo != null && _sysInfo != "" );
        }
        return _sysInfo;
    }

    public var warning( get, set ):String;
    var _warning:String;
    function get_warning():String return _warning;
    function set_warning( value:String ):String {
        _warning = value;
        if ( _warning != null ) {
            _iconWarning.toolTip = _warning;
            _iconWarning.includeInLayout = _iconWarning.visible = (_warning != null && _warning != "" );
        }
        return _warning;
    }

    public function new() {

        super();

        this.variant = GenesisApplicationTheme.LAYOUT_GROUP_FOOTER;

        _labelSysInfo = new Label();
        _labelSysInfo.variant = GenesisApplicationTheme.LABEL_COPYRIGHT;
        _labelSysInfo.text = ( _sysInfo != null ) ? _sysInfo : "";
        this.addChild( _labelSysInfo );

        _iconWarning = new Button();
        _iconWarning.includeInLayout = _iconWarning.visible = ( _warning != null && _warning != "" );
        _iconWarning.variant = GenesisApplicationTheme.BUTTON_BROWSER_WARNING;
        _iconWarning.icon = new AdvancedAssetLoader( GenesisApplicationTheme.getAssetPath( GenesisApplicationTheme.ICON_WARNING ) );
        _iconWarning.toolTip = ( _warning != null ) ? _warning : "";
        this.addChild( _iconWarning );
        
        _spacer = new LayoutGroup();
        _spacer.layoutData = new HorizontalLayoutData( 100 );
        _spacer.includeInLayout = _spacer.visible = ( _sysInfo != null && _sysInfo != "" );
        this.addChild( _spacer );

        _label = new Label();
        _label.variant = GenesisApplicationTheme.LABEL_COPYRIGHT;
        _label.text = ( _appInfo != null ) ? _appInfo : "";
        this.addChild( _label );

    }

}