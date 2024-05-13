package superhuman.application;

import prominic.sys.tools.SysTools;
import sys.FileSystem;
import superhuman.application.Applications;

class ApplicationData {
	
	public var appId:String = Applications.FILE_ZILLA;
	public var appName:String = Applications.FILE_ZILLA;    
    	public var executablePath:String;
    public var exists:Bool;
    
    
	public function new(appId:String) {
		_setDefaultValues(appId);
	}
	
	function _setDefaultValues(appId:String) {
		if (this.appId == "") {
			this.appId = Applications.FILE_ZILLA; 
		}
		if (this.appName == "") {
			this.appName = Applications.FILE_ZILLA;
		}
		
		switch appId {
			case Applications.FILE_ZILLA:
			if (this.executablePath == null)
			{
				#if linux
				
				#elseif mac
				this.executablePath = "/Applications/FileZilla.app/Contents/MacOS/filezilla";
				#elseif windows
				this.executablePath = "";
				#end
			}
		}
		
		this.exists = FileSystem.exists(this.executablePath);
	}
}