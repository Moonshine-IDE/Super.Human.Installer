package superhuman.browser;

import haxe.io.Path;

class BrowserData {
	
	var _browserType:Browsers;
	
	var _browserName:String;
	public var browserName( get, set ):String;
    function get_browserName() return _browserName;
    function set_browserName(value) {
    		if (_browserName != value) {
    			_browserName = value;
    		}
    		return _browserName;
    }
    
    	var _executablePath:String;
    public var executablePath( get, set ):String;
    function get_executablePath() return _executablePath;
    function set_executablePath(value) {
    		if (_executablePath != value) {
    			_executablePath = value;
    		}
    		return _executablePath;
    }
    
    var _isDefault:Bool;
    public var isDefault( get, set ):Bool;
    function get_isDefault() return _isDefault;
    function set_isDefault(value) {
    		if (_isDefault != value) {
    			_isDefault = value;
    		}
    		return _isDefault;
    }
    
	public function new(browserType:Browsers, isDefault:Bool = false, browserName:String = "", executablePath:String = "") {
		_browserType = browserType;
		_isDefault = isDefault;
		_browserName = browserName;
		_executablePath = executablePath;
		
		_setDefaultValues(browserType);
	}
	
	function _setDefaultValues(browserType:Browsers) {
		if (this.browserName == "") {
			this.browserName = StringTools.replace(browserType.getName(), "_", " ");
		}
		
		if (executablePath == "") {
			switch browserType {
				case Google_Chrome:
					#if linux
					 
					 #elseif mac
					 this.executablePath = "/Applications/Google Chrome.app";
					 #elseif windows
					 this.exeexecutablePath = "C:/Program Files/Google/Chrome/Application/chrome.exe";
					 #end
				case Brave:
					#if linux
					 
					 #elseif mac
					 this.executablePath = "/Applications/Brave Browser.app";
					 #elseif windows
					 this.exeexecutablePath = "C:/Program Files/BraveSoftware/Brave-Browser/Application/brave.exe";
					 #end
				case Safari:
					 this.executablePath = "/Applications/Safari.app";
				case Chromium:
				case Opera:
				case Internet_Explorer:
				default:
					#if linux
					 
					 #elseif mac
					 this.executablePath = "/Applications/Firefox.app";
					 #elseif windows
					 this.exeexecutablePath = "C:/Program Files/Mozilla Firefox/firefox.exe";
					 #end
					 isDefault = true;
			}
		}
	}
}