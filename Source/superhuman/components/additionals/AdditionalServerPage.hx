package superhuman.components.additionals;

import sys.FileSystem;
import openfl.events.MouseEvent;
import superhuman.server.provisioners.ProvisionerType;
import superhuman.managers.ProvisionerManager;
import superhuman.server.definitions.ProvisionerDefinition;
import haxe.io.Path;
import genesis.application.components.Page;
import  superhuman.application.ApplicationData;
import genesis.application.managers.LanguageManager;
import genesis.application.theme.GenesisApplicationTheme;
import feathers.events.TriggerEvent;
import superhuman.events.SuperHumanApplicationEvent;
import superhuman.server.AdditionalServer;

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

		firstLine.width = _width;

		rowCoreComponentVersion.text = LanguageManager.getInstance().getString( 'serverconfigpage.form.provisioner.text' );
		dropdownCoreComponentVersion.dataProvider = ProvisionerManager.getBundledProvisionerCollection(ProvisionerType.AdditionalProvisioner);
		dropdownCoreComponentVersion.itemToText = ( item:ProvisionerDefinition ) -> {
            return item.name;
        };

		rowCoreComponentHostname.text = LanguageManager.getInstance().getString( 'additionalserverconfigpage.form.hostname.text' );
		inputHostname.prompt = LanguageManager.getInstance().getString( 'additionalserverconfigpage.form.hostname.prompt' );
		//inputHostname.restrict = AdditionalServer._HOSTNAME;

		rowExistingDominoServer.text = LanguageManager.getInstance().getString( 'additionalserverconfigpage.form.existingdominoservername.text' );
		inputExistingDominoServer.prompt = LanguageManager.getInstance().getString( 'additionalserverconfigpage.form.existingdominoservername.prompt' );
		//inputExistingDominoServer.restrict = AdditionalServer._HOSTNAME_WITH_PATH.;

		rowExistingServerIp.text = LanguageManager.getInstance().getString( 'additionalserverconfigpage.form.existingserveripaddress.text' );
		inputExistingServerIp.prompt = LanguageManager.getInstance().getString( 'serveradvancedconfigpage.form.networkip.prompt' );

		rowNewServerId.text = LanguageManager.getInstance().getString( 'additionalserverconfigpage.form.newserveridfile.text' );

		buttonNewServerId.text = ( _server.safeIdExists() ) ? LanguageManager.getInstance().getString( 'serverconfigpage.form.safeid.buttonlocateagain' ) : LanguageManager.getInstance().getString( 'serverconfigpage.form.safeid.buttonlocate' );
		buttonNewServerId.icon = ( _server.safeIdExists() ) ? GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_OK ) : GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_WARNING ) ;
        buttonNewServerId.enabled = !_server.userSafeId.locked;
		buttonNewServerId.addEventListener( TriggerEvent.TRIGGER, _buttonSafeIdTriggered );

		labelPreviousSafeId.addEventListener( MouseEvent.CLICK, _labelPreviousSafeIdTriggered );
		this.refreshLabelPreviousSafeId();
		
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

		//buttonNewServerId.variant = null;
		buttonRoles.icon = ( _server.areRolesValid() ) ? GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_OK ) : GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_WARNING  );
		buttonRoles.update();
		buttonNewServerId.icon = ( _server.safeIdExists() ) ? GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_OK ) : GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_WARNING  );
		buttonNewServerId.text = ( _server.safeIdExists() ) ? LanguageManager.getInstance().getString( 'serverconfigpage.form.safeid.buttonlocateagain' ) : LanguageManager.getInstance().getString( 'serverconfigpage.form.safeid.buttonlocate' );

		if ( !_server.safeIdExists() && SuperHumanInstaller.getInstance().config.user.lastusedsafeid != null ) {

			rowPreviousSafeId.visible = rowPreviousSafeId.includeInLayout = true;
			var p = Path.withoutDirectory( SuperHumanInstaller.getInstance().config.user.lastusedsafeid );
			rowPreviousSafeId.text = LanguageManager.getInstance().getString( 'serverconfigpage.form.safeid.useprevious', p );

		} else {

			rowPreviousSafeId.visible = rowPreviousSafeId.includeInLayout = false;

		}

		buttonNewServerId.enabled = !_server.userSafeId.locked;
		buttonRoles.enabled = !_server.roles.locked;
		buttonSave.enabled = !_server.hostname.locked;

		if ( dropdownCoreComponentVersion.selectedIndex == -1 || forced ) {

			for ( i in 0...dropdownCoreComponentVersion.dataProvider.length ) {

				var d:ProvisionerDefinition = dropdownCoreComponentVersion.dataProvider.get( i );

				if ( d.data.version == _server.provisioner.version ) {

					dropdownCoreComponentVersion.selectedIndex = i;
					break;

				}

			}

		}

		dropdownCoreComponentVersion.enabled = !_server.hostname.locked;
    }

	function _buttonSafeIdTriggered( e:TriggerEvent ) {
        _server.locateNotesSafeId( _safeIdLocated );
    }

	function _safeIdLocated() {

        buttonNewServerId.setValidity( true );
        buttonNewServerId.icon = ( buttonNewServerId.isValid() ) ? GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_OK ) : GenesisApplicationTheme.getCommonIcon( GenesisApplicationTheme.ICON_WARNING );
        buttonNewServerId.text = ( buttonNewServerId.isValid() ) ? LanguageManager.getInstance().getString( 'serverconfigpage.form.safeid.buttonlocateagain' ) : LanguageManager.getInstance().getString( 'serverconfigpage.form.safeid.buttonlocate' );

		this.refreshLabelPreviousSafeId();
    }

	function _labelPreviousSafeIdTriggered( e:MouseEvent ) {
        if ( !FileSystem.exists( SuperHumanInstaller.getInstance().config.user.lastusedsafeid ) ) {
            SuperHumanInstaller.getInstance().config.user.lastusedsafeid = null;
        }

        _server.userSafeId.value = SuperHumanInstaller.getInstance().config.user.lastusedsafeid;
        _safeIdLocated();
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
		_server.existingServerIpAddress.value = StringTools.trim( inputExistingServerIp.text );
        
        var dvv:ProvisionerDefinition = cast dropdownCoreComponentVersion.selectedItem;
        _server.updateProvisioner( dvv.data );

        SuperHumanInstaller.getInstance().config.user.lastusedsafeid = _server.userSafeId.value;
        
        var evt = new SuperHumanApplicationEvent( SuperHumanApplicationEvent.SAVE_SERVER_CONFIGURATION );
        	evt.server = _server;
        this.dispatchEvent( evt );
	}
	
	function _buttonCloseTriggered( e:TriggerEvent ) {
        this.dispatchEvent( new SuperHumanApplicationEvent( SuperHumanApplicationEvent.CANCEL_PAGE ) );
    }

	function refreshLabelPreviousSafeId() {
		if ( !_server.safeIdExists() && SuperHumanInstaller.getInstance().config.user.lastusedsafeid != null ) {
            rowPreviousSafeId.visible = rowPreviousSafeId.includeInLayout = true;
            var p = Path.withoutDirectory( SuperHumanInstaller.getInstance().config.user.lastusedsafeid );
            labelPreviousSafeId.text = LanguageManager.getInstance().getString( 'serverconfigpage.form.safeid.useprevious', p );
			labelPreviousSafeId.toolTip = SuperHumanInstaller.getInstance().config.user.lastusedsafeid;
        } else {
            rowPreviousSafeId.visible = rowPreviousSafeId.includeInLayout = false;
        }
	}
}