package superhuman.application;

import prominic.helpers.PathUtil;
import prominic.sys.tools.SysTools;
import superhuman.application.Applications;

class ApplicationData {
	
	public var appId:String = Applications.FILE_ZILLA;
	public var appName:String = Applications.FILE_ZILLA;    
    public var exists:Bool;
   	public var displayPath:String;
    public var executablePath:String;
    
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
		
		this._setDefaultExecutablePath(this.appId);
		
		this.exists = this.executablePath != null;
	}
	
	function _setDefaultExecutablePath(appId) {
		switch appId {
			case Applications.FILE_ZILLA:
			if (this.executablePath == null || this.executablePath == "")
			{
				#if linux
				this.executablePath = "";
				this.displayPath = "";
				#elseif mac
				this.displayPath = "/Applications/FileZilla.app";
				this.executablePath = PathUtil.getValidatedAppPath(this.displayPath);
				#elseif windows
				this.displayPath = "C:/Program Files/FileZilla FTP Client/filezilla.exe";
				this.executablePath = PathUtil.getValidatedAppPath(this.displayPath);
				#end
			}
		}
	}
}