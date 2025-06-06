package superhuman.components.browsers;

import genesis.application.components.GenesisButton;
import lime.ui.FileDialog;
import lime.ui.FileDialogType;
import openfl.events.Event;
import superhuman.theme.SuperHumanInstallerTheme;
import sys.FileSystem;
import feathers.text.TextFormat;
import feathers.controls.Check;
import feathers.controls.Button;
import genesis.application.components.GenesisFormButton;
import superhuman.browser.BrowserData;
import feathers.controls.Label;
import superhuman.events.SuperHumanApplicationEvent;
import feathers.events.TriggerEvent;
import feathers.layout.HorizontalAlign;
import genesis.application.components.HLine;
import feathers.layout.HorizontalLayoutData;
import feathers.layout.VerticalAlign;
import feathers.layout.VerticalLayoutData;
import genesis.application.managers.LanguageManager;
import feathers.layout.HorizontalLayout;
import genesis.application.theme.GenesisApplicationTheme;
import feathers.layout.VerticalLayout;
import feathers.controls.LayoutGroup;
import feathers.controls.TextInput;
import genesis.application.components.Page;

class SetupBrowserPage extends Page {
	
	final _width:Float = GenesisApplicationTheme.GRID * 100;

	var _titleGroup:LayoutGroup;
	var _labelTitle:Label;
	
	var _browserNotDetectedGroup:LayoutGroup;
	var _labelBrowserNotDetectedError:Label;
	
	var _browserNameGroup:LayoutGroup;
	var _textInputBrowserName:TextInput;
	
	var _execPathGroup:LayoutGroup;
	var _textInputPath:TextInput;
	var _locatePath:Button;
	 
	var _defaultBrowserGroup:LayoutGroup;
	var _checkDefaultBrowser:Check;
	var _buttonDownloadBrowser:GenesisButton;
	
	var _buttonGroup:LayoutGroup;
    var _buttonGroupLayout:HorizontalLayout;
    var _buttonSave:GenesisFormButton;
    var _buttonClose:GenesisFormButton;
	
    var _browserData:BrowserData;
    
	public function new()
	{
		super();
		
		var titleGroupLayout = new HorizontalLayout();
        		titleGroupLayout.horizontalAlign = HorizontalAlign.RIGHT;
        		titleGroupLayout.verticalAlign = VerticalAlign.MIDDLE;
        		
        _titleGroup = new LayoutGroup();
        _titleGroup.layout = titleGroupLayout;
        _titleGroup.width = _width;
        this.addChild( _titleGroup );

        _labelTitle = new Label();
        _labelTitle.variant = GenesisApplicationTheme.LABEL_LARGE;
        _labelTitle.layoutData = new HorizontalLayoutData( 100 );
        _titleGroup.addChild( _labelTitle );
        
        var line = new HLine();
            line.width = _width;
    	    this.addChild( line );
 
    	    titleGroupLayout = new HorizontalLayout();
    	    titleGroupLayout.horizontalAlign = HorizontalAlign.CENTER;
    	    titleGroupLayout.verticalAlign = VerticalAlign.MIDDLE;
    	    
        _browserNotDetectedGroup = new LayoutGroup();
        _browserNotDetectedGroup.layout = titleGroupLayout;
        _browserNotDetectedGroup.width = _width;
        _browserNotDetectedGroup.visible = _browserNotDetectedGroup.includeInLayout = false;
        this.addChild(_browserNotDetectedGroup);
        
        _labelBrowserNotDetectedError = new Label();
        _labelBrowserNotDetectedError.variant = GenesisApplicationTheme.LABEL_ERROR;
        _browserNotDetectedGroup.addChild(_labelBrowserNotDetectedError);
        
		var horizontalGroupLayout = new HorizontalLayout();
			horizontalGroupLayout.verticalAlign = VerticalAlign.MIDDLE;
			
		_browserNameGroup = new LayoutGroup();
		_browserNameGroup.width = _width;
		_browserNameGroup.layout = horizontalGroupLayout;
		this.addChild(_browserNameGroup);
		
		_textInputBrowserName = new TextInput( "", LanguageManager.getInstance().getString( 'settingspage.browser.browsername' ) );
		_textInputBrowserName.layoutData = new HorizontalLayoutData(100);
		_browserNameGroup.addChild(_textInputBrowserName);
		
		horizontalGroupLayout = new HorizontalLayout();
		horizontalGroupLayout.verticalAlign = VerticalAlign.MIDDLE;
		horizontalGroupLayout.gap = 4;
		
		_execPathGroup = new LayoutGroup();	
		_execPathGroup.width = _width;
		_execPathGroup.layout = horizontalGroupLayout;
		this.addChild(_execPathGroup);
		
		_textInputPath = new TextInput("", LanguageManager.getInstance().getString('settingspage.browser.executablebrowserpath'));
		_textInputPath.layoutData = new HorizontalLayoutData(100);
		_textInputPath.enabled = true;
		_textInputPath.addEventListener(Event.CHANGE, _textInputPathChanged);
		_execPathGroup.addChild(_textInputPath);
		
		_locatePath = new Button(LanguageManager.getInstance().getString('settingspage.browser.locatebrowser'));
		_locatePath.variant = GenesisApplicationTheme.BUTTON_SELECT_FILE;
		_locatePath.addEventListener(TriggerEvent.TRIGGER, _locatePathTriggered);
		_locatePath.visible = _locatePath.includeInLayout = true;
		_execPathGroup.addChild(_locatePath);
		
		horizontalGroupLayout = new HorizontalLayout();
		horizontalGroupLayout.verticalAlign = VerticalAlign.MIDDLE;
		
		_defaultBrowserGroup = new LayoutGroup();	
		_defaultBrowserGroup.width = _width;
		_defaultBrowserGroup.layout = horizontalGroupLayout;
		this.addChild(_defaultBrowserGroup);
		
		_checkDefaultBrowser = new Check(LanguageManager.getInstance().getString('settingspage.browser.defaultbrowser'));
		_checkDefaultBrowser.variant = GenesisApplicationTheme.CHECK_MEDIUM;
		_checkDefaultBrowser.layoutData = new HorizontalLayoutData(100);
		_defaultBrowserGroup.addChild(_checkDefaultBrowser);
		
		_buttonDownloadBrowser = new GenesisButton(LanguageManager.getInstance().getString( 'updatepage.buttondownload' ));
		_buttonDownloadBrowser.addEventListener(TriggerEvent.TRIGGER, _buttonDownloadBrowserTriggered);
		_defaultBrowserGroup.addChild(_buttonDownloadBrowser);
		
		var line = new HLine();
        		line.width = _width;
    		this.addChild( line );
    	      
        _buttonGroup = new LayoutGroup();
        _buttonGroupLayout = new HorizontalLayout();
        _buttonGroupLayout.gap = GenesisApplicationTheme.GRID * 2;
        _buttonGroupLayout.horizontalAlign = HorizontalAlign.CENTER;
        _buttonGroup.layout = _buttonGroupLayout;
        this.addChild( _buttonGroup );

        _buttonSave = new GenesisFormButton( LanguageManager.getInstance().getString( 'settingspage.buttons.save' ) );
        _buttonSave.addEventListener( TriggerEvent.TRIGGER, _saveButtonTriggered );
        _buttonGroup.addChild(_buttonSave);
        
        _buttonClose = new GenesisFormButton( LanguageManager.getInstance().getString( 'settingspage.buttons.cancel' ) );
        _buttonClose.addEventListener( TriggerEvent.TRIGGER, _buttonCloseTriggered );
        _buttonGroup.addChild( _buttonClose );
	}
	
	public function setBrowserData(data:BrowserData) {
		_browserData = data;
		_labelTitle.text = LanguageManager.getInstance().getString( 'settingspage.browser.titlebrowserpath', data.browserName );
		_textInputBrowserName.text = data.browserName;
		_textInputPath.text = data.executablePath;
		_checkDefaultBrowser.selected = data.isDefault;
		_checkDefaultBrowser.enabled = data.exists;
		_buttonDownloadBrowser.visible = _buttonDownloadBrowser.includeInLayout = data.downloadUrl != null;
		_labelBrowserNotDetectedError.text = LanguageManager.getInstance().getString('settingspage.browser.browsernotdetected', data.browserName);
		_browserNotDetectedGroup.visible = _browserNotDetectedGroup.includeInLayout = data.exists == false;
	}

	function _saveButtonTriggered(e:TriggerEvent) {
		if (_browserData.isDefault != _checkDefaultBrowser.selected)
		{
			_browserData.isDefault = _checkDefaultBrowser.selected;
			var refreshDefaultBrowserEvent = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.REFRESH_DEFAULT_BROWSER);
				refreshDefaultBrowserEvent.browserData = _browserData;
			this.dispatchEvent(refreshDefaultBrowserEvent);
		}
		
		_browserData.browserName = _textInputBrowserName.text;
		_browserData.executablePath = _textInputPath.text;
		
		// Update the exists flag based on the file path before saving
		_browserData.exists = _textInputPath.text != null && _textInputPath.text != "" && FileSystem.exists(_textInputPath.text);
		
		var superHumanAppEvent = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.REFRESH_BROWSERS_PAGE);
			superHumanAppEvent.browserData = _browserData;
		this.dispatchEvent(superHumanAppEvent);
		
		this.dispatchEvent( new SuperHumanApplicationEvent( SuperHumanApplicationEvent.CLOSE_BROWSERS_SETUP ) );
	}
	    
    function _buttonDownloadBrowserTriggered(e:TriggerEvent) {
    		var superHumanAppEvent = new SuperHumanApplicationEvent(SuperHumanApplicationEvent.OPEN_DOWNLOAD_BROWSER);
    			superHumanAppEvent.browserData = _browserData;
    			
    		this.dispatchEvent(superHumanAppEvent);
    }
    
	function _buttonCloseTriggered( e:TriggerEvent ) {
        this.dispatchEvent( new SuperHumanApplicationEvent( SuperHumanApplicationEvent.CLOSE_BROWSERS_SETUP ) );
    }
    
    /**
     * Handler for the locate path button click
     */
    function _locatePathTriggered(e:TriggerEvent) {
        var fileDialog = new FileDialog();
        fileDialog.onSelect.add(_onFileSelected);
        
        // Open the file dialog (Lime's FileDialog doesn't support title or filters directly)
        fileDialog.browse(FileDialogType.OPEN);
    }
    
    /**
     * Handler for file selection from the file dialog
     */
    function _onFileSelected(path:String) {
        if (path != null && path != "") {
            _textInputPath.text = path;
            _validatePath(path);
        }
    }
    
    /**
     * Handler for manual text input changes in the path field
     */
    function _textInputPathChanged(e:Event) {
        _validatePath(_textInputPath.text);
    }
    
    /**
     * Validates if the provided path exists and updates UI accordingly
     */
    function _validatePath(path:String) {
        if (path != null && path != "") {
            var exists = FileSystem.exists(path);
            _browserData.executablePath = path;
            _browserData.exists = exists;
            
            // Update UI based on existence
            _browserNotDetectedGroup.visible = _browserNotDetectedGroup.includeInLayout = !exists;
            _checkDefaultBrowser.enabled = exists;
        }
    }
}
