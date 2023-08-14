package superhuman.browser;

import champaign.core.logging.Logger;
import prominic.sys.applications.bin.Shell;
import cpp.NativeSys;

class Browsers  
{
    public static final MOZILLA_FIREFOX:String = "Mozilla Firefox";
    public static final GOOGLE_CHROME:String = "Google Chrome";
    public static final BRAVE:String = "Brave Browser";
    public static final OPERA:String = "Opera";
    public static final CHROMIUM:String = "Chromium";
    public static final MICROSOFT_EDGE:String = "Microsoft Edge";
    public static final SAFARI:String = "Safari";
    public static final INTERNET_EXPLORER:String = "Internet Explorer";
    
    public static final DEFAULT_BROWSERS_LIST:Array<BrowserData> = [
    		new BrowserData(Browsers.MOZILLA_FIREFOX, true),
		new BrowserData(Browsers.GOOGLE_CHROME),
		new BrowserData(Browsers.BRAVE),
		new BrowserData(Browsers.OPERA),
		#if windows
		new BrowserData(Browsers.MICROSOFT_EDGE),
		#end
		#if mac
		new BrowserData(Browsers.SAFARI)
		#end
    ];
    
    public static function getDefaultBrowser():Dynamic {
    		var config = SuperHumanInstaller.getInstance().config;
    		if (config.browsers == null)
    		{
    			config.browsers = DEFAULT_BROWSERS_LIST;
    		}
	
		var defaultBrowser = null;
		for (index => element in config.browsers) 
		{
			var b:Dynamic = config.browsers[index];
			if (b.isDefault == true) 
			{
				defaultBrowser = b;
			}
		}

    		return defaultBrowser;
    }
    
    public static function openLink(webAddress:String) {
    		if ( webAddress == null || webAddress.length == 0 ) {

			Logger.error( 'Web address is invalid: \"${webAddress}\"' );
			return;

		}
		
		var defaultBrowser = Browsers.getDefaultBrowser();
		var a = [webAddress];
		#if mac
		a = ["-a" + defaultBrowser.executablePath, webAddress];
		#elseif windows
		a = ["start", '""', '"${defaultBrowser.executablePath}"', '"${webAddress}"'];
		#end
		
		#if windows
		var trim = StringTools.trim( a.join( " " ));
		NativeSys.sys_command(trim);
		#else
		Shell.getInstance().open( a );
		#end	
    }
}