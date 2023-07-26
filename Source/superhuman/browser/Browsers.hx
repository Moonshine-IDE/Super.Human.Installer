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
    
    public static function getDefaultBrowser():BrowserData {
    		var config = SuperHumanInstaller.getInstance().config;
    		
    		var defaultBrowser = config.browsers.filter(b -> b.isDefault);
    		
    		if (defaultBrowser.length > 0) {
    			return defaultBrowser[0];
    		}
    		
    		defaultBrowser = config.browsers.filter(b -> b.browserType == MOZILLA_FIREFOX);
    		return defaultBrowser[0];
    }
}