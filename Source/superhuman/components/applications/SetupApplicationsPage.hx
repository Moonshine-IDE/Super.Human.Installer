package superhuman.components.applications;

import prominic.helpers.PathUtil;
import lime.ui.FileDialogType;
import haxe.io.Path;
import lime.ui.FileDialog;
import sys.FileSystem;
import genesis.application.components.Page;
import  superhuman.application.ApplicationData;
import feathers.layout.HorizontalLayoutData;
import genesis.application.managers.LanguageManager;
import genesis.application.theme.GenesisApplicationTheme;
import superhuman.events.SuperHumanApplicationEvent;
import feathers.events.TriggerEvent;
import lime.system.System;

@:build(mxhx.macros.MXHXComponent.build())
class SetupApplicationsPage extends Page
{
	final _width:Float = GenesisApplicationTheme.GRID * 100;
	
	private var _appData:ApplicationData;
	
	public function new()
	{
		super();
		
		firstLine.width = _width;

		appNotDetectedGroup.width = _width;
		appNameGroup.width = _width;
		exectPathGroup.width = _width;
		validatePathGroup.width = _width;
		
		textInputAppName.prompt = LanguageManager.getInstance().getString( 'settingspage.applications.appname' );
		textInputPath.prompt = LanguageManager.getInstance().getString('settingspage.applications.executableapppath');
		
		validatePath.text = LanguageManager.getInstance().getString('settingspage.applications.validateapppath');
		validatePath.addEventListener( TriggerEvent.TRIGGER, _validateButtonTriggered);
		
		locatePath.text = LanguageManager.getInstance().getString('settingspage.applications.locateapplication');
		locatePath.addEventListener( TriggerEvent.TRIGGER, _locateButtonTriggered);
		
		secondLine.width = _width;
		
		buttonSave.text = LanguageManager.getInstance().getString( 'settingspage.buttons.save' );
		buttonSave.addEventListener( TriggerEvent.TRIGGER, _saveButtonTriggered );
		 
		buttonClose.text = LanguageManager.getInstance().getString( 'settingspage.buttons.cancel' );
		buttonClose.addEventListener( TriggerEvent.TRIGGER, _buttonCloseTriggered );
	}
	
	public function setAppData(data:ApplicationData) {
		_appData = data;
		
		labelTitle.text = LanguageManager.getInstance().getString( 'settingspage.applications.titleapppath', data.appName );
		textInputAppName.text = data.appName;
		textInputPath.text = data.displayPath;
	}
	
	function _saveButtonTriggered(e:TriggerEvent) {
		_appData.appName = textInputAppName.text;		
		_appData.executablePath = PathUtil.getValidatedAppPath(textInputPath.text);
		if (_appData.executablePath != null)
		{
			_appData.exists = _appData.executablePath != null;
			_appData.displayPath = textInputPath.text;
		}
		else
		{
			_appData.exists = false;
			_appData.displayPath = "";
		}
		
		this.dispatchEvent( new SuperHumanApplicationEvent( SuperHumanApplicationEvent.CLOSE_APPLICATION_SETUP ) );
	}
	
	function _buttonCloseTriggered( e:TriggerEvent ) {
        this.dispatchEvent( new SuperHumanApplicationEvent( SuperHumanApplicationEvent.CLOSE_APPLICATION_SETUP ) );
    }
    
    function _validateButtonTriggered( e:TriggerEvent ) {
    		_appData.executablePath = PathUtil.getValidatedAppPath(textInputPath.text);
		_appData.exists = _appData.executablePath != null;
    		_showError();
    }
    
    function _locateButtonTriggered( e:TriggerEvent ) {

        var dir = ( SuperHumanInstaller.getInstance().config.user.lastuseddirectory != null ) ? SuperHumanInstaller.getInstance().config.user.lastuseddirectory : System.userDirectory;
        var fd = new FileDialog();
        
        var currentDir:String; 
	
        fd.onSelect.add( path -> {
			
        		path = Path.removeTrailingSlashes(path);
            currentDir = Path.directory( path );
            
            if ( currentDir != null ) SuperHumanInstaller.getInstance().config.user.lastuseddirectory = currentDir;

			_appData.executablePath = PathUtil.getValidatedAppPath(path);
			_appData.exists = _appData.executablePath != null;
			_appData.displayPath = path;
			
			textInputPath.text = path;
			_showError();
        } );

        fd.browse( FileDialogType.OPEN, null, dir + "/", LanguageManager.getInstance().getString( 'settingspage.applications.titleapppath', _appData.appName ) );
    }
    
    function _showError() {
    		#if mac
    			notDetected.text = LanguageManager.getInstance().getString('settingspage.applications.appnotdetectedmac');
    		#else
    			notDetected.text = LanguageManager.getInstance().getString('settingspage.applications.appnotdetectedother');
    		#end
    		appNotDetectedGroup.visible = appNotDetectedGroup.includeInLayout = !_appData.exists;
    }
}