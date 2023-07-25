package superhuman.browser;

import haxe.io.Path;

class BrowserData {
	
	public var browserType:Browsers;
	public var browserName:String;    
    	public var executablePath:String;
    public var isDefault:Bool;
    
	public function new(browserType:Browsers, isDefault:Bool = false, browserName:String = "", executablePath:String = "") {
		this.browserType = browserType;
		this.isDefault = isDefault;
		this.browserName = browserName;
		this.executablePath = executablePath;
		
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
					 this.executablePath = "C:/Program Files/Google/Chrome/Application/chrome.exe";
					 #end
				case Brave:
					#if linux
					 
					 #elseif mac
					 this.executablePath = "/Applications/Brave Browser.app";
					 #elseif windows
					 this.executablePath = "C:/Program Files/BraveSoftware/Brave-Browser/Application/brave.exe";
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
					 this.executablePath = "C:/Program Files/Mozilla Firefox/firefox.exe";
					 #end
			}
		}
	}
}