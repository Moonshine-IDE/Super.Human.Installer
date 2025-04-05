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

		rowOrganizationDominoServer.text = LanguageManager.getInstance().getString( 'additionalserverconfigpage.form.organizationdominoservername.text' );
		inputOrganizationDominoServer.prompt = LanguageManager.getInstance().getString( 'additionalserverconfigpage.form.organizationdominoservername.prompt' );

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
		inputHostname.enabled = !_server.hostname.locked;
		
		if (  forced || ( inputExistingDominoServer.text == null || inputExistingDominoServer.text == "" ) ) inputExistingDominoServer.text = _server.existingServerName.value;
		inputExistingDominoServer.enabled = !_server.existingServerName.locked;

		if (  forced || ( inputOrganizationDominoServer.text == null || inputOrganizationDominoServer.text == "" ) ) inputOrganizationDominoServer.text = _server.organization.value;
		inputOrganizationDominoServer.enabled = !_server.organization.locked;

		if (  forced || ( inputExistingServerIp.text == null || inputExistingServerIp.text == "" ) ) inputExistingServerIp.text = _server.existingServerIpAddress.value;
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
		_server.organization.value = StringTools.trim( inputOrganizationDominoServer.text );
		_server.existingServerIpAddress.value = StringTools.trim( inputExistingServerIp.text );
		
        // Ensure we don't lose the serverProvisionerId when we update the provisioner
        var currentServerProvisionerId = _server.serverProvisionerId.value;
        
		var dvv:ProvisionerDefinition = cast dropdownCoreComponentVersion.selectedItem;
		_server.updateProvisioner( dvv.data );
        
        // Restore the serverProvisionerId if it was lost or changed to version number
        if (currentServerProvisionerId != null && (_server.serverProvisionerId.value == null || 
            _server.serverProvisionerId.value == dvv.data.version || 
            _server.serverProvisionerId.value != currentServerProvisionerId)) {
            
            _server.serverProvisionerId.value = currentServerProvisionerId;
        }
	
		if (_server.isValid()) {	
            // EXPLICIT: Force the provisioner to copy files regardless of exists check
            _server.provisioner.copyFiles();
            
            // Initialize server files - creates directory and copies provisioner files
            if (_server.provisional) {
                _server.initializeServerFiles();
            }
	
			// Store the selected serverProvisionerId for future use in global settings
			SuperHumanInstaller.getInstance().config.user.lastusedsafeid = _server.serverProvisionerId.value;
            
            // Make sure server.saveData() is called to persist server_provisioner_id
            _server.saveData();
			
			var evt = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.SAVE_SERVER_CONFIGURATION );
				evt.server = _server;
			this.dispatchEvent( evt );
    	}
	}
	
	function _buttonCloseTriggered( e:TriggerEvent ) {
        // Only remove the server if the server directory doesn't exist
        // This ensures we only remove truly new servers that have never been saved
        if (_server != null && !sys.FileSystem.exists(_server.serverDir)) {
            superhuman.managers.ServerManager.getInstance().removeProvisionalServer(_server);
        }
        this.dispatchEvent( new SuperHumanApplicationEvent( SuperHumanApplicationEvent.CANCEL_PAGE ) );
    }
}
