package superhuman.components.additionals;

import superhuman.events.SuperHumanApplicationEvent;
import superhuman.server.definitions.ProvisionerDefinition;
import superhuman.managers.ProvisionerManager;
import superhuman.server.Server;
import lime.ui.FileDialogType;
import genesis.application.components.Page;
import  superhuman.application.ApplicationData;
import genesis.application.managers.LanguageManager;
import genesis.application.theme.GenesisApplicationTheme;
import feathers.events.TriggerEvent;

@:build(mxhx.macros.MXHXComponent.build())
class AdditionalServerPage extends Page
{
	final _width:Float = GenesisApplicationTheme.GRID * 100;
	
	private var _appData:ApplicationData;
	
	public function new()
	{
		super();
		
		firstLine.width = _width;

		rowCoreComponentVersion.text = LanguageManager.getInstance().getString( 'serverconfigpage.form.provisioner.text' );
		dropdownCoreComponentVersion.dataProvider = ProvisionerManager.getBundledProvisionerCollection();
		dropdownCoreComponentVersion.itemToText = ( item:ProvisionerDefinition ) -> {
            return item.name;
        };

		rowCoreComponentHostname.text = LanguageManager.getInstance().getString( 'additionalserverconfigpage.form.hostname.text' );
		rowExistingDominoServer.text = LanguageManager.getInstance().getString( 'additionalserverconfigpage.form.existingdominoservername.text' );
		rowExistingServerIp.text = LanguageManager.getInstance().getString( 'additionalserverconfigpage.form.existingserveripaddress.text' );

		rowNewServerId.text = LanguageManager.getInstance().getString( 'additionalserverconfigpage.form.newserveridfile.text' );
		buttonNewServerId.text = LanguageManager.getInstance().getString( 'serverconfigpage.form.safeid.buttonlocate' );

		secondLine.width = _width;
		
		buttonSave.text = LanguageManager.getInstance().getString( 'settingspage.buttons.save' );
		buttonSave.addEventListener( TriggerEvent.TRIGGER, _saveButtonTriggered );
		 
		buttonClose.text = LanguageManager.getInstance().getString( 'settingspage.buttons.cancel' );
		buttonClose.addEventListener( TriggerEvent.TRIGGER, _buttonCloseTriggered );
	}
	
	private var _server:Server;
	
	public function setServer( server:Server ) {
        _server = server;

		labelTitle.text = LanguageManager.getInstance().getString( 'serverconfigpage.title', Std.string( _server.id ) );
    }

	
	function _saveButtonTriggered(e:TriggerEvent) {
	}
	
	function _buttonCloseTriggered( e:TriggerEvent ) {
        this.dispatchEvent( new SuperHumanApplicationEvent( SuperHumanApplicationEvent.CANCEL_PAGE ) );
    }
}