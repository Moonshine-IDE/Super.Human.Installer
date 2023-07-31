package superhuman.browser;

class Browsers  
{
    public static final MOZILLA_FIREFOX:String = "Mozilla Firefox";
    public static final GOOGLE_CHROME:String = "Google Chrome";
    public static final CHROMIUM:String = "Chromium";
    public static final MICROSOFT_EDGE:String = "Microsoft Edge";
    public static final BRAVE:String = "Brave";
    public static final OPERA:String = "Opera";
    public static final SAFARI:String = "Safari";
    public static final INTERNET_EXPLORER:String = "Internet Explorer";
    
    public static function getDefaultBrowser():Dynamic {
    		var config = SuperHumanInstaller.getInstance().config;
    		if (config.browsers == null)
    		{
    			config.browsers = [
				new BrowserData(Browsers.MOZILLA_FIREFOX, true),
				new BrowserData(Browsers.GOOGLE_CHROME),
				new BrowserData(Browsers.BRAVE),
				new BrowserData(Browsers.SAFARI)
			];	
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
}