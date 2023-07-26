package superhuman.browser;

import haxe.io.Path;

class BrowserData {
	
	public var browserType:String;
	public var browserName:String;    
    	public var executablePath:String;
    public var isDefault:Bool;
    
	public function new(browserType:String, isDefault:Bool = false, browserName:String = "", executablePath:String = "") {
		this.browserType = browserType;
		this.isDefault = isDefault;
		this.browserName = browserName;
		this.executablePath = executablePath;
		
		_setDefaultValues(browserType);
	}
	
	function _setDefaultValues(browserType:String) {
		if (this.browserName == "") {
			this.browserName = browserType; 
		}
		
		if (executablePath == "") {
			switch browserType {
				case Browsers.GOOGLE_CHROME:
					#if linux
					 
					 #elseif mac
					 this.executablePath = "/Applications/Google Chrome.app";
					 #elseif windows
					 this.executablePath = "C:/Program Files/Google/Chrome/Application/chrome.exe";
					 #end
				case Browsers.BRAVE:
					#if linux
					 
					 #elseif mac
					 this.executablePath = "/Applications/Brave Browser.app";
					 #elseif windows
					 this.executablePath = "C:/Program Files/BraveSoftware/Brave-Browser/Application/brave.exe";
					 #end
				case Browsers.SAFARI:
					 this.executablePath = "/Applications/Safari.app";
				case Browsers.CHROMIUM:
				case Browsers.OPERA:
				case Browsers.INTERNET_EXPLORER:
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