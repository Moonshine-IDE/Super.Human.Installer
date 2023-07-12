package superhuman.config;

class SuperHumanHashes
{
	public static final validHashes:Map<String, Map<String, Array<{}>>> = [
		
		"domino" => [ "installers" => [ { hash: "4153dfbb571b1284ac424824aa0e25e4", version: {majorVersion: "12", minorVersion: "02", fullVersion: "12.02"} } ], 
					  "hotfixes" => [], 
					  "fixpacks" => [ {hash: "30803d849e3eb46f35242a72372548fd", version: { fullVersion: "FP1"}} ]],
		"appdevpack" => [ "installers" => [ { hash: "b84248ae22a57efe19dac360bd2aafc2", version: { majorVersion: "1", minorVersion: "0", patch: "15", fullVersion: "1.0.15"} }]],
		"leap" => [ "installers" => [ { hash: "080235c0f0cce7cc3446e01ffccf0046", version: { majorVersion: "1", minorVersion: "0", patch: "5", fullVersion: "1.0.5" } } ]],
		"nomadweb" => [ "installers" => [ { hash: "044c7a71598f41cd3ddb88c5b4c9b403" }, 
										 { hash: "8f3e42f4f5105467c99cfd56b8b4a755", version: { majorVersion: "1", minorVersion: "0", patch: "6", fullVersion: "1.0.6"} }, 
										 { hash: "fe2dd37e6d05ea832d8ecc4f0e1dbe80", version: { majorVersion: "1", minorVersion: "0", patch: "8", fullVersion: "1.0.8"} }]],
		"traveler" => [ "installers" => [ { hash: "4a195e3282536de175a2979def40527d" }, 
										 { hash: "4118ee30d590289070f2d29ecf1b34cb", version: { majorVersion: "12", minorVersion: "0", patch: "2", fullVersion: "12.0.2" }}, 
										 { hash: "216807509d96f65c7a76b878fc4c4bd5", version: { majorVersion: "12", minorVersion: "0", patch: "2", fixPackVersion: "FP1", fullVersion: "12.0.2"} } ]],
		"verse" => [ "installers" => [ { hash: "dfad6854171e964427550454c5f006ee", version: { majorVersion: "3", minorVersion: "0", patch: "0", fullVersion: "3.0.0" } } ]],
		"domino-rest-api" => [ "installers" => [ { hash: "fa990f9bac800726f917cd0ca857f220", version: { majorVersion: "1", minorVersion: "0", patch: "0", fullVersion: "1.0.0" } } ] ]
	];
	
	public static function getInstallersHashes(installerType:String):Array<String> 
	{
		var installersHashes:Array<{}> = validHashes.get(installerType).get( "installers" );
		var hashes:Array<String> = installersHashes.map(function(item:Dynamic):String {
			return item.hash;
		});
		
		return hashes;
	}
	
	public static function getHotFixesHashes(installerType:String):Array<String> 
	{
		var installersHashes:Array<{}> = validHashes.get(installerType).get( "hotfixes" );
		var hashes:Array<String> = installersHashes.map(function(item:Dynamic):String {
			return item.hash;
		});
		
		return hashes;
	}
	
	public static function getFixPacksHashes(installerType:String):Array<String> 
	{
		var installersHashes:Array<{}> = validHashes.get(installerType).get( "fixpacks" );
		var hashes:Array<String> = installersHashes.map(function(item:Dynamic):String {
			return item.hash;
		});
		
		return hashes;
	}
	
	public static function getInstallerVersion(installerType:String, hash:String):{}
	{
		var installersHashes:Array<Dynamic> = validHashes.get(installerType).get( "installers" );
		var version:{} = getVersion(installersHashes, hash);
		
		return version;
	}
	
	public static function getHotfixesVersion(installerType:String, hash:String):{}
	{
		var installersHashes:Array<Dynamic> = validHashes.get(installerType).get( "hotfixes" );
		var version:{} = getVersion(installersHashes, hash);
		
		return version;
	}
	
	public static function getFixpacksVersion(installerType:String, hash:String):{}
	{
		var installersHashes:Array<Dynamic> = validHashes.get(installerType).get( "fixpacks" );
		var version:{} = getVersion(installersHashes, hash);
		
		return version;
	}
	
	private static function getVersion(installerHashes:Array<Dynamic>, hash:String):{}
	{
		var version:{} = null;
		
		var filteredHashes:Array<Dynamic> = installerHashes.filter(function(item:Dynamic):Bool {
			return item.hash == hash;
		});
		
		if (filteredHashes.length > 0)
		{
			version = filteredHashes[0].version;
		}
		
		return version;
	}
}