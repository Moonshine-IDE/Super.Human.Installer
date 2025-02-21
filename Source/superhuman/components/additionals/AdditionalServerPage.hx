package superhuman.components.additionals;

import openfl.events.MouseEvent;
import superhuman.server.provisioners.ProvisionerType;
import superhuman.managers.ProvisionerManager;
import superhuman.server.definitions.ProvisionerDefinition;
import genesis.application.components.Page;
import  superhuman.application.ApplicationData;
import genesis.application.managers.LanguageManager;
import genesis.application.theme.GenesisApplicationTheme;
import feathers.events.TriggerEvent;
import superhuman.events.SuperHumanApplicationEvent;
import superhuman.server.AdditionalServer;
import superhuman.server.Server;

@:build(mxhx.macros.MXHXComponent.build())
class AdditionalServerPage extends Page
{
	final _width:Float = GenesisApplicationTheme.GRID * 100;
		
	private var _server:AdditionalServer;
	private var _appData:ApplicationData;
	
	public function new()
	{
		super();
	}

	override function initialize() {

        super.initialize();

		titleGroup.width = _width;
		firstLine.width = _width;

		advancedLink.text = LanguageManager.getInstance().getString( 'serverconfigpage.advancedlink' );
        advancedLink.addEventListener( MouseEvent.CLICK, _advancedLinkTriggered );

		rowCoreComponentVersion.text = LanguageManager.getInstance().getString( 'serverconfigpage.form.provisioner.text' );
		dropdownCoreComponentVersion.dataProvider = ProvisionerManager.getBundledProvisionerCollection(ProvisionerType.AdditionalProvisioner);
		dropdownCoreComponentVersion.itemToText = ( item:ProvisionerDefinition ) -> {
            return item.name;
        };

		rowCoreComponentHostname.text = LanguageManager.getInstance().getString( 'additionalserverconfigpage.form.hostname.text' );
		inputHostname.prompt = LanguageManager.getInstance().getString( 'additionalserverconfigpage.form.hostname.prompt' );
		inputHostname.validationKey = AdditionalServer._HOSTNAME;

		rowExistingDominoServer.text = LanguageManager.getInstance().getString( 'additionalserverconfigpage.form.existingdominoservername.text' );
		inputExistingDominoServer.prompt = LanguageManager.getInstance().getString( 'additionalserverconfigpage.form.existingdominoservername.prompt' );
		inputExistingDominoServer.validationKey = AdditionalServer._HOSTNAME_WITH_PATH;

		rowExistingServerIp.text = LanguageManager.getInstance().getString( 'additionalserverconfigpage.form.existingserveripaddress.text' );
		inputExistingServerIp.prompt = LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.networkip.prompt' );
		inputExistingServerIp.validationKey = Server._VK_IP;

		rowNewServerId.text = LanguageManager.getInstance().getString( 'additionalserverconfigpage.form.newserveridfile.text' );

		buttonNewServerId.text = ( _server.safeIdExists() ) ? LanguageManager.getInstance().getString( 'serverconfigpage.form.safeid.buttonlocateagain' ) : LanguageManager.getInstance().getString( 'serverconfigpage.form.safeid.buttonlocate' );
		buttonNewServerId.icon = ( _server.safeIdExists() ) ? GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_OK ) : GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_WARNING ) ;
        buttonNewServerId.enabled = !_server.userSafeId.locked;
		buttonNewServerId.addEventListener( TriggerEvent.TRIGGER, _buttonProvisionerServerIdTriggered );
		
		rowRoles.text = LanguageManager.getInstance().getString( 'serverconfigpage.form.roles.text' );
        buttonRoles.text = LanguageManager.getInstance().getString( 'serverconfigpage.form.roles.button' );
        buttonRoles.icon = ( _server.areRolesValid() ) ? GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_OK ) : GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_WARNING  );
        buttonRoles.enabled = !_server.roles.locked;
		buttonRoles.addEventListener( TriggerEvent.TRIGGER, _buttonRolesTriggered );

		secondLine.width = _width;
		
		buttonSave.text = LanguageManager.getInstance().getString( 'settingspage.buttons.save' );
		buttonSave.addEventListener( TriggerEvent.TRIGGER, _saveButtonTriggered );
		 
		buttonClose.text = LanguageManager.getInstance().getString( 'settingspage.buttons.cancel' );
		buttonClose.addEventListener( TriggerEvent.TRIGGER, _buttonCloseTriggered );
	}


	public function setServer( server:AdditionalServer ) {
        _server = server;

		labelTitle.text = LanguageManager.getInstance().getString( 'serverconfigpage.title', Std.string( _server.id ) );
    }

	override function updateContent( forced:Bool = false ) {

        super.updateContent();

		if (form == null) return;

		labelTitle.text = LanguageManager.getInstance().getString( 'serverconfigpage.title', Std.string( _server.id ) );
		if ( forced || ( inputHostname.text == null || inputHostname.text == "" ) ) inputHostname.text = _server.hostname.value;
	//	inputHostname.variant = null;
		inputHostname.enabled = !_server.hostname.locked;
		
		if (  forced || ( inputExistingDominoServer.text == null || inputExistingDominoServer.text == "" ) ) inputExistingDominoServer.text = _server.existingServerName.value;
		//inputExistingDominoServer.variant = null;
		inputExistingDominoServer.enabled = !_server.existingServerName.locked;

		if (  forced || ( inputExistingServerIp.text == null || inputExistingServerIp.text == "" ) ) inputExistingServerIp.text = _server.existingServerIpAddress.value;
		inputExistingServerIp.variant = null;
		inputExistingServerIp.enabled = !_server.existingServerIpAddress.locked;

		buttonRoles.setValidity( _server.areRolesValid() );
		buttonRoles.icon = ( _server.areRolesValid() ) ? GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_OK ) : GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_WARNING  );
		buttonNewServerId.icon = ( _server.safeIdExists() ) ? GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_OK ) : GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_WARNING  );
		buttonNewServerId.text = ( _server.safeIdExists() ) ? LanguageManager.getInstance().getString( 'serverconfigpage.form.safeid.buttonlocateagain' ) : LanguageManager.getInstance().getString( 'serverconfigpage.form.safeid.buttonlocate' );
		buttonNewServerId.setValidity( _server.safeIdExists() );
		buttonNewServerId.enabled = !_server.userSafeId.locked;

		buttonRoles.enabled = !_server.roles.locked;
		buttonSave.enabled = !_server.hostname.locked;

		if ( dropdownCoreComponentVersion.selectedIndex == -1 || forced ) {

			if (dropdownCoreComponentVersion.dataProvider != null)
			{
				for ( i in 0...dropdownCoreComponentVersion.dataProvider.length ) {
	
					var d:ProvisionerDefinition = dropdownCoreComponentVersion.dataProvider.get( i );
	
					if ( d.data.version == _server.provisioner.version ) {
	
						dropdownCoreComponentVersion.selectedIndex = i;
						break;
	
					}
	
				}
			}
		}

		dropdownCoreComponentVersion.enabled = !_server.hostname.locked;
    }

	function _advancedLinkTriggered( e:MouseEvent ) {
        var evt = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.ADVANCED_CONFIGURE_SERVER );
		evt.provisionerType = ProvisionerType.AdditionalProvisioner;
        evt.server = this._server;
        this.dispatchEvent( evt );
    }

	function _buttonProvisionerServerIdTriggered( e:TriggerEvent ) {
        _server.locateServerProvisionerId( _provisionerServerIdLocated );
    }

	function _provisionerServerIdLocated() {
        buttonNewServerId.setValidity( true );
        buttonNewServerId.icon = ( buttonNewServerId.isValid() ) ? GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_OK ) : GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_WARNING );
        buttonNewServerId.text = ( buttonNewServerId.isValid() ) ? LanguageManager.getInstance().getString( 'serverconfigpage.form.safeid.buttonlocateagain' ) : LanguageManager.getInstance().getString( 'serverconfigpage.form.safeid.buttonlocate' );
	}

	function _buttonRolesTriggered( e:TriggerEvent ) {

        var evt = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.CONFIGURE_ROLES );
        evt.server = this._server;
        this.dispatchEvent( evt );
	}

	function _saveButtonTriggered(e:TriggerEvent) {
		buttonNewServerId.setValidity( _server.safeIdExists() );
        buttonRoles.setValidity( _server.areRolesValid() );

        if ( !form.isValid() || !_server.safeIdExists() || !_server.areRolesValid() ) {
            return;
        }

        // Making sure the event is fired
        var a = _server.roles.value.copy();
        _server.roles.value = a;
        _server.syncMethod = SuperHumanInstaller.getInstance().config.preferences.syncmethod;
        _server.hostname.value = StringTools.trim( inputHostname.text );
		_server.existingServerName.value = StringTools.trim( inputExistingDominoServer.text );
		_server.organization.value = StringTools.trim( inputExistingDominoServer.text );
		_server.existingServerIpAddress.value = StringTools.trim( inputExistingServerIp.text );
		
		var dvv:ProvisionerDefinition = cast dropdownCoreComponentVersion.selectedItem;
			_server.updateProvisioner( dvv.data );
	
		if (_server.isValid()) {		
			SuperHumanInstaller.getInstance().config.user.lastusedsafeid = _server.userSafeId.value;
			
			var evt = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.SAVE_SERVER_CONFIGURATION );
				evt.server = _server;
			this.dispatchEvent( evt );
    		}
	}
	
	function _buttonCloseTriggered( e:TriggerEvent ) {
        this.dispatchEvent( new SuperHumanApplicationEvent( SuperHumanApplicationEvent.CANCEL_PAGE ) );
    }
}