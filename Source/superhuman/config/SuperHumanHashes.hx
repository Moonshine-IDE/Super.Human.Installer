package superhuman.config;

class SuperHumanHashes
{
	public static final validHashes:Map<String, Map<String, Array<{}>>> = [
		
		"domino" => [ "installers" => [{ hash: "89a59f845d120055859a2c638809a75c", version: {majorVersion: "14", minorVersion: "0", patchVersion: "0", fullVersion: "14.0.0"}}, 
									   { hash: "4153dfbb571b1284ac424824aa0e25e4", version: {majorVersion: "12", minorVersion: "0", patchVersion: "2", fullVersion: "12.0.2"} },
									   { hash: "ee9dd49653d4e4352cf23d0ae59936c8", version: {majorVersion: "12", minorVersion: "0", patchVersion: "2", fullVersion: "12.0.1"}} ], 
					  "hotfixes" => [], 
					  "fixpacks" => [{hash: "6bd5e7d65939f6ebc189bef118ee06f5", version: { fullVersion: "FP1",}},
					  				 {hash: "255cf7862db4b6bd9c0d3a4444bd064d", version: { fullVersion: "FP2",}},
									 {hash: "30803d849e3eb46f35242a72372548fd", version: { fullVersion: "FP1"}},
									  {hash: "f7753e4a0d80c64ecf15f781e8ea920a", version: { fullVersion: "FP2"}},
									  {hash: "0d19fdaa92716e3f097014e6800102ff", version: { fullVersion: "FP4"}},]],
		"appdevpack" => [ "installers" => [ { hash: "b84248ae22a57efe19dac360bd2aafc2", version: { majorVersion: "1", minorVersion: "0", patch: "15", fullVersion: "1.0.15"} }]],
		"leap" => [ "installers" => [ { hash: "080235c0f0cce7cc3446e01ffccf0046", version: { majorVersion: "1", minorVersion: "0", patch: "5", fullVersion: "1.0.5" } },
									{ hash: "de4589d2b1b087acdf666f100abfbfda", version: { majorVersion: "1", minorVersion: "1", patch: "1", fullVersion: "1.1.1.18" } } ]],
		"nomadweb" => [ "installers" => [ { hash: "044c7a71598f41cd3ddb88c5b4c9b403" }, 
										 { hash: "8f3e42f4f5105467c99cfd56b8b4a755", version: { majorVersion: "1", minorVersion: "0", patch: "6", fullVersion: "1.0.6"} }, 
										 { hash: "fe2dd37e6d05ea832d8ecc4f0e1dbe80", version: { majorVersion: "1", minorVersion: "0", patch: "8", fullVersion: "1.0.8"} },
										 { hash: "378880b838aeeb4db513ebf05a8a7285", version: { majorVersion: "1", minorVersion: "0", patch: "9", fullVersion: "1.0.9"} },
										 { hash: "697d89eb78fa6c1512e0ee199fa0c97c", version: { majorVersion: "1", minorVersion: "0", patch: "10", fullVersion: "1.0.10"} },
										{ hash: "5908ea3a43571ec55f380908dfd5b69f", version: { majorVersion: "1", minorVersion: "0", patch: "12", fullVersion: "1.0.12"} },
										{ hash: "fb86ec43be9c8e7c9fa7928f5b592ed1", version: { majorVersion: "1", minorVersion: "0", patch: "13", fullVersion: "1.0.13"} } ]],
		"traveler" => [ "installers" => [ { hash: "4a195e3282536de175a2979def40527d" }, 
										 { hash: "4118ee30d590289070f2d29ecf1b34cb", version: { majorVersion: "12", minorVersion: "0", patch: "2", fullVersion: "12.0.2" }}, 
										 { hash: "216807509d96f65c7a76b878fc4c4bd5", version: { majorVersion: "12", minorVersion: "0", patch: "2", fixPackVersion: "FP1", fullVersion: "12.0.2"} },
										 { hash: "fc262f2b9cc334604cb830b371043468", version: { majorVersion: "14", minorVersion: "0", patch: "0", fullVersion: "14.0.0"} },
										{ hash: "58f8bfab4165246a3b12490a4e661f69", version: { majorVersion: "14", minorVersion: "0", patch: "0", fixPackVersion: "FP1", fullVersion: "14.0.0"} } ]],
		"verse" => [ "installers" => [ { hash: "dfad6854171e964427550454c5f006ee", version: { majorVersion: "3", minorVersion: "0", patch: "0", fullVersion: "3.0.0" } },
										{ hash: "21a13b648fdaac3b516ac9880c106041", version: { majorVersion: "3", minorVersion: "2", patch: "2", fullVersion: "3.2.2" } } ]],
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
	
	public static function getHash(installerType:String, hashType:String, fullVersion:String):String
	{
		var installers:Array<Dynamic> = validHashes.get(installerType).get( hashType );
		
		var filteredHashes:Array<Dynamic> = installers.filter(function(item:Dynamic):Bool {
			return item.fullVersion == fullVersion;
		});
		
		if (filteredHashes != null && filteredHashes.length > 0)
		{
			return filteredHashes.shift();
		}
		
		return "";
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