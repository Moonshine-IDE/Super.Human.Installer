package superhuman.browser;

import prominic.sys.tools.SysTools;
import sys.FileSystem;

class BrowserData {
	
	public var browserType:String;
	public var browserName:String;    
    	public var executablePath:String;
    public var isDefault:Bool;
    public var exists:Bool;
    public var downloadUrl:String;
    
	public function new(browserType:String, isDefault:Bool = false, browserName:String = "", executablePath:String = "", exists:Bool = false) {
		this.browserType = browserType;
		this.isDefault = isDefault;
		this.browserName = browserName;
		this.executablePath = executablePath;
		this.exists = exists;
		
		_setDefaultValues(browserType);
	}
	
	function _setDefaultValues(browserType:String) {
		if (this.browserName == "") {
			this.browserName = browserType; 
		}
		
		switch browserType {
			case Browsers.GOOGLE_CHROME:
					if (this.executablePath == "")
					{
						#if linux
						
						#elseif mac
						this.executablePath = "/Applications/Google Chrome.app";
						#elseif windows
						this.executablePath = "C:/Program Files/Google/Chrome/Application/chrome.exe";
						#end
					}
					
					this.downloadUrl = "https://www.google.com/intl/en/chrome/";
			case Browsers.BRAVE:
					if (this.executablePath == "")
					{
						#if linux
						
						#elseif mac
						this.executablePath = "/Applications/Brave Browser.app";
						#elseif windows
						this.executablePath = "C:/Program Files/BraveSoftware/Brave-Browser/Application/brave.exe";
						#end
					}
					
					this.downloadUrl = "https://brave.com/";
			case Browsers.OPERA:
					if (this.executablePath == "")
					{
						#if linux
						
						#elseif mac
						this.executablePath = "/Applications/Opera.app";
						#elseif windows
						var userName = SysTools.getWindowsUserName();
						this.executablePath = "C:/Users/${userName}/AppData/Local/Programs/Opera/launcher.exe";
						#end
					}
					
					this.downloadUrl = "https://www.opera.com/";
			case Browsers.MICROSOFT_EDGE:
					if (this.executablePath == "")
					{
						#if windows
						this.executablePath = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe";
						#end
					}
					
					this.downloadUrl = "https://www.microsoft.com/en-us/edge";
			case Browsers.SAFARI:
					if (this.executablePath == "")
					{
						this.executablePath = "/Applications/Safari.app";
					}
					
					this.downloadUrl = "https://www.apple.com/safari/";
			case Browsers.CHROMIUM:
			case Browsers.INTERNET_EXPLORER:
			default:
				if (this.executablePath == "")
				{
					#if linux
					
					#elseif mac
					this.executablePath = "/Applications/Firefox.app";
					#elseif windows
					this.executablePath = "C:/Program Files/Mozilla Firefox/firefox.exe";
					#end
				}
				this.downloadUrl = "https://www.mozilla.org/en-US/firefox/new/";
		}
		
		this.exists = FileSystem.exists(this.executablePath);
	}
}