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

package superhuman.components.serviceType;

import superhuman.server.provisioners.ProvisionerType;
import feathers.controls.GridViewColumn;
import genesis.application.theme.GenesisApplicationTheme;
import feathers.controls.Label;
import superhuman.server.data.ServiceTypeData;
import feathers.data.ArrayCollection;
import superhuman.events.SuperHumanApplicationEvent;
import genesis.application.components.GenesisFormButton;
import feathers.events.TriggerEvent;
import genesis.application.components.HLine;
import genesis.application.managers.LanguageManager;
import feathers.layout.HorizontalLayoutData;
import feathers.controls.LayoutGroup;
import feathers.layout.HorizontalLayout;
import feathers.layout.VerticalAlign;
import feathers.layout.HorizontalAlign;
import genesis.application.components.Page;

class ServiceTypePage extends Page {

    final _w:Float = GenesisApplicationTheme.GRID * 100;

    var _titleGroup:LayoutGroup;
	var _labelTitle:Label;
	
	var _serviceTypeGrid:ServiceTypeGrid;
	
	var _buttonGroup:LayoutGroup;
    var _buttonGroupLayout:HorizontalLayout;
    var _buttonSave:GenesisFormButton;
    var _buttonClose:GenesisFormButton;
    
    var _serviceTypesCollection:Array<ServiceTypeData>;
	
    public function new(serviceTypes:Array<ServiceTypeData>) {

        super();
        
        _serviceTypesCollection = serviceTypes;
    }

    override function initialize() {

        super.initialize();

        _content.width = _w;
        
        var titleGroupLayout = new HorizontalLayout();
        		titleGroupLayout.horizontalAlign = HorizontalAlign.RIGHT;
        		titleGroupLayout.verticalAlign = VerticalAlign.MIDDLE;
        		
        _titleGroup = new LayoutGroup();
        _titleGroup.layout = titleGroupLayout;
        _titleGroup.width = _w;
        this.addChild( _titleGroup );

        _labelTitle = new Label();
        _labelTitle.variant = GenesisApplicationTheme.LABEL_LARGE;
        _labelTitle.text = LanguageManager.getInstance().getString( 'servicetypepage.title' );
        _labelTitle.layoutData = new HorizontalLayoutData( 100 );
        _titleGroup.addChild( _labelTitle );
        
        var line = new HLine();
            line.width = _w;
    	    this.addChild( line );
    	    
    	    _serviceTypeGrid = new ServiceTypeGrid(new ArrayCollection(_serviceTypesCollection));
    	    _serviceTypeGrid.width = _w;
    	    _serviceTypeGrid.columns = new ArrayCollection([
			new GridViewColumn("Service", (data) -> data.value),
			new GridViewColumn("Description", (data) -> data.description),
		]);
		this.addChild(_serviceTypeGrid);
		
    	    var line = new HLine();
        		line.width = _w;
    		this.addChild( line );
    		
    		_buttonGroup = new LayoutGroup();
        _buttonGroupLayout = new HorizontalLayout();
        _buttonGroupLayout.gap = GenesisApplicationTheme.GRID * 2;
        _buttonGroupLayout.horizontalAlign = HorizontalAlign.CENTER;
        _buttonGroup.layout = _buttonGroupLayout;
        this.addChild( _buttonGroup );

        _buttonSave = new GenesisFormButton( LanguageManager.getInstance().getString( 'servicetypepage.continue' ) );
        _buttonSave.addEventListener( TriggerEvent.TRIGGER, _continueButtonTriggered );
        _buttonGroup.addChild(_buttonSave);
        
        _buttonClose = new GenesisFormButton( LanguageManager.getInstance().getString( 'settingspage.buttons.cancel' ) );
        _buttonClose.addEventListener( TriggerEvent.TRIGGER, _buttonCloseTriggered );
        _buttonGroup.addChild( _buttonClose );
    }
    
    function _continueButtonTriggered(e:TriggerEvent) {
    		var event = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.CREATE_SERVER );
        		event.provisionerType = ProvisionerType.DemoTasks;
        this.dispatchEvent( event );
	}
	
    function _buttonCloseTriggered( e:TriggerEvent ) {
        this.dispatchEvent( new SuperHumanApplicationEvent( SuperHumanApplicationEvent.CLOSE_SERVICE_TYPE_PAGE ) );
    }
}
