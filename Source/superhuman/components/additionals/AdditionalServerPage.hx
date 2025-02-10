package superhuman.components.additionals;

import sys.FileSystem;
import openfl.events.MouseEvent;
import superhuman.server.provisioners.ProvisionerType;
import haxe.io.Path;
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
		
	private var _server:Server;
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
		inputHostname.prompt = LanguageManager.getInstance().getString( 'serverconfigpage.form.hostname.prompt' );

		rowExistingDominoServer.text = LanguageManager.getInstance().getString( 'additionalserverconfigpage.form.existingdominoservername.text' );
		inputExistingDominoServer.prompt = LanguageManager.getInstance().getString( 'serverconfigpage.form.orgcert.prompt' );

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


	public function setServer( server:Server ) {
        _server = server;

		labelTitle.text = LanguageManager.getInstance().getString( 'serverconfigpage.title', Std.string( _server.id ) );
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