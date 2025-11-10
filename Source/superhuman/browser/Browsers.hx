package superhuman.browser;

import champaign.core.logging.Logger;
import prominic.sys.applications.bin.Shell;
import cpp.NativeSys;

class Browsers  
{
    public static final SYSTEM_DEFAULT:String = "System Default";
    public static final MOZILLA_FIREFOX:String = "Mozilla Firefox";
    public static final GOOGLE_CHROME:String = "Google Chrome";
    public static final BRAVE:String = "Brave Browser";
    public static final OPERA:String = "Opera";
    public static final CHROMIUM:String = "Chromium";
    public static final MICROSOFT_EDGE:String = "Microsoft Edge";
    public static final SAFARI:String = "Safari";
    public static final INTERNET_EXPLORER:String = "Internet Explorer";
    
    public static final DEFAULT_BROWSERS_LIST:Array<BrowserData> = [
    		new BrowserData(Browsers.SYSTEM_DEFAULT, true),
    		new BrowserData(Browsers.MOZILLA_FIREFOX),
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
    
    public static function normaliseConfigBrowsersWithDefaultBrowsers() {
    		var config = SuperHumanInstaller.getInstance().config;
    		if (config.browsers == null) 
    		{
    			config.browsers = DEFAULT_BROWSERS_LIST;
    		}
    		else
    		{
    			var configBrowsers:Array<BrowserData> = [];
    			for (c => e in config.browsers)	
    			{
    				var bConfig:Dynamic = e;
    				configBrowsers.push(new BrowserData(bConfig.browserType, bConfig.isDefault, bConfig.browserName, 
    				bConfig.executablePath, bConfig.exists, bConfig.downloadUrl));
    			}
    			
    			config.browsers = configBrowsers;
    			
			for (index => element in DEFAULT_BROWSERS_LIST) 
			{
				var defaultBrowser = DEFAULT_BROWSERS_LIST[index];
				var configBrowser = config.browsers.filter(f -> f.browserType == defaultBrowser.browserType);
				if (configBrowser == null || configBrowser.length == 0)
				{
					config.browsers.push(defaultBrowser);
				}
			}
    		}
    }
    
    public static function getDefaultBrowser():Dynamic {
    		var config = SuperHumanInstaller.getInstance().config;

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
    
    public static function openLink(webAddress:String):Bool {
    		if ( webAddress == null || webAddress.length == 0 ) {
			Logger.error( 'Web address is invalid: \"${webAddress}\"' );
			return false;
		}
		
		Logger.info('Browsers.openLink: Attempting to open URL: ${webAddress}');
		
		var defaultBrowser = Browsers.getDefaultBrowser();
		
		// If no default browser or default doesn't exist, fall back to system default
		if (defaultBrowser == null || !defaultBrowser.exists) {
			Logger.warning('Default browser not found or doesn\'t exist, falling back to system default');
			defaultBrowser = new BrowserData(Browsers.SYSTEM_DEFAULT, true);
		}
		
		Logger.info('Using browser: ${defaultBrowser.browserName} (${defaultBrowser.browserType})');
		
		try {
			// Handle System Default browser type specially
			if (defaultBrowser.browserType == Browsers.SYSTEM_DEFAULT) {
				#if windows
				// Use Windows start command to open with system default browser
				var command = 'start "" "${webAddress}"';
				Logger.info('Opening URL with system default browser command: ${command}');
				var result = NativeSys.sys_command(command);
				Logger.info('System command result: ${result}');
				return result == 0;
				#elseif mac
				// Use Mac open command to open with system default browser
				var a = [webAddress];
				Logger.info('Opening URL with system default browser using open command');
				Shell.getInstance().open( a );
				return true;
				#elseif linux
				// Use xdg-open to open with system default browser
				var a = [webAddress];
				Logger.info('Opening URL with system default browser using xdg-open');
				Shell.getInstance().open( a );
				return true;
				#end
			}
			
			// Handle specific browser types
			var a = [webAddress];
			#if mac
			a = ["-a" + defaultBrowser.executablePath, webAddress];
			#elseif windows
			a = ["start", '""', '"${defaultBrowser.executablePath}"', '"${webAddress}"'];
			#end
			
			Logger.info('Opening URL with ${defaultBrowser.browserName}: ${webAddress}');
			Logger.info('Command args: ${a}');
			
			#if windows
			var trim = StringTools.trim( a.join( " " ));
			Logger.info('Final Windows command: ${trim}');
			var result = NativeSys.sys_command(trim);
			Logger.info('Specific browser command result: ${result}');
			return result == 0;
			#else
			Shell.getInstance().open( a );
			return true;
			#end
		} catch (e) {
			Logger.error('Failed to open URL with ${defaultBrowser.browserName}: ${e}');
			
			// Final fallback: try system default if we haven't already
			if (defaultBrowser.browserType != Browsers.SYSTEM_DEFAULT) {
				Logger.info('Attempting final fallback to system default browser');
				try {
					#if windows
					var fallbackCommand = 'start "" "${webAddress}"';
					Logger.info('Fallback command: ${fallbackCommand}');
					var result = NativeSys.sys_command(fallbackCommand);
					Logger.info('Fallback command result: ${result}');
					return result == 0;
					#elseif mac
					Shell.getInstance().open( [webAddress] );
					return true;
					#elseif linux
					Shell.getInstance().open( [webAddress] );
					return true;
					#end
				} catch (e2) {
					Logger.error('Final fallback also failed: ${e2}');
					return false;
				}
			}
			return false;
		}
    }
}
