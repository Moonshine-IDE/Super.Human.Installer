package superhuman.application;

class Applications 
{
    public static final FILE_ZILLA:String = "FileZilla";
    
    public static final DEFAULT_APPLICATIONS_LIST:Array<ApplicationData> = [
		new ApplicationData(Applications.FILE_ZILLA),
    ];
    
    public static function normaliseConfigApplications() {
    		var config = SuperHumanInstaller.getInstance().config;
    		if (config.applications == null) 
    		{
    			config.applications = DEFAULT_APPLICATIONS_LIST;
    		}
    		else
    		{
    			var configApps:Array<ApplicationData> = [];
    			for (c => e in config.applications)	
    			{
    				var aConfig:Dynamic = e;
    				var appData:ApplicationData = new ApplicationData(aConfig.appId);
    					appData.appName = aConfig.appName;
    					appData.executablePath = aConfig.executablePath;
    					appData.exists = aConfig.exists;
    				configApps.push(appData);
    			}
    			
    			config.applications = configApps;
    			
			for (index => element in DEFAULT_APPLICATIONS_LIST) 
			{
				var defaultApp = DEFAULT_APPLICATIONS_LIST[index];
				var configApps = config.applications.filter(f -> f.appId == defaultApp.appId);
				if (configApps == null || configApps.length == 0)
				{
					config.applications.push(defaultApp);
				}
			}
    		}
    }
}