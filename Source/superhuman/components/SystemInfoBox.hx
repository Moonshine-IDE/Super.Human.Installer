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

import feathers.controls.Label;
import feathers.controls.LayoutGroup;
import genesis.application.managers.LanguageManager;
import genesis.application.theme.GenesisApplicationTheme;
import openfl.events.MouseEvent;
import prominic.sys.applications.hashicorp.Vagrant.VagrantMachine;
import prominic.sys.applications.oracle.VirtualMachine;
import superhuman.events.SuperHumanApplicationEvent;

@:styleContext
class SystemInfoBox extends LayoutGroup {

    var _openVirtualBoxGUILabel:Label;
    var _vagrantMachines:Array<VagrantMachine>;
    var _vagrantMachinesLabel:Label;
    var _virtualBoxMachines:Array<VirtualMachine>;
    var _virtualBoxMachinesLabel:Label;

    public var vagrantMachines( get, set ):Array<VagrantMachine>;
    function get_vagrantMachines() return _vagrantMachines;
    function set_vagrantMachines( value ) {
        _vagrantMachines = value;
        if ( _vagrantMachinesLabel != null ) _vagrantMachinesLabel.text = LanguageManager.getInstance().getString( 'serverpage.systeminfo.vagrant', Std.string( _vagrantMachines.length ) );
        return _vagrantMachines;
    }

    public var virtualBoxMachines( get, set ):Array<VirtualMachine>;
    function get_virtualBoxMachines() return _virtualBoxMachines;
    function set_virtualBoxMachines( value ) {
        _virtualBoxMachines = value;
        if ( _virtualBoxMachinesLabel != null ) _virtualBoxMachinesLabel.text = LanguageManager.getInstance().getString( 'serverpage.systeminfo.virtualbox', Std.string( _virtualBoxMachines.length ) );
        return _virtualBoxMachines;
    }

    public function new() {

        super();

    }

    override function initialize() {

        super.initialize();

        _vagrantMachinesLabel = new Label();
        _vagrantMachinesLabel.variant = GenesisApplicationTheme.LABEL_COPYRIGHT;
        if ( _vagrantMachines != null ) _vagrantMachinesLabel.text = LanguageManager.getInstance().getString( 'serverpage.systeminfo.vagrant', Std.string( _vagrantMachines.length ) );
        this.addChild( _vagrantMachinesLabel );

        _virtualBoxMachinesLabel = new Label();
        _virtualBoxMachinesLabel.variant = GenesisApplicationTheme.LABEL_COPYRIGHT;
        if ( _virtualBoxMachines != null ) _virtualBoxMachinesLabel.text = LanguageManager.getInstance().getString( 'serverpage.systeminfo.virtualbox', Std.string( _virtualBoxMachines.length ) );
        this.addChild( _virtualBoxMachinesLabel );

        _openVirtualBoxGUILabel = new Label( LanguageManager.getInstance().getString( 'serverpage.systeminfo.openvirtualbox' ) );
        _openVirtualBoxGUILabel.variant = GenesisApplicationTheme.LABEL_LINK_SMALL;
        _openVirtualBoxGUILabel.useHandCursor = _openVirtualBoxGUILabel.buttonMode = true;
        _openVirtualBoxGUILabel.addEventListener( MouseEvent.CLICK, _openVirtualBoxGUILabelClicked );
        this.addChild( _openVirtualBoxGUILabel );

    }

    function _openVirtualBoxGUILabelClicked( e:MouseEvent ) {

        var evt = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.OPEN_VIRTUALBOX_GUI );
        this.dispatchEvent( evt );

    }
    
}