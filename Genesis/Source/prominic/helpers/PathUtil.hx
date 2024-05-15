package prominic.helpers;
import prominic.helpers.PListUtil.PListEntryId;
import openfl.filesystem.File;
using StringTools;

class PathUtil  
{
	public static function getValidatedAppPath(path:String):String
    {
        var finalExecutablePath:String;
        var splitPath = path.split("/");
        var file:File;

        // for the macOS platform
        #if mac
		var executableFileName:String = null;
		var appExtCount:Int = 3;
		
		// i.e. /applications/cord.app
		finalExecutablePath = (path.substr(path.length - appExtCount, appExtCount) != "app") ? path+".app" : path;
		if (finalExecutablePath.charAt(0) != "/") finalExecutablePath = "/"+finalExecutablePath;

		var appInternalPathToPlist:String = "/Contents/Info.plist";
		/*
		* @note
		* we need some info.plist reading here,
		* as some of the app has different name/cases
		* for their executable file in Contents/MacOS folder
		* and some mac system may has case-sensitive setup.
		* one such issue raised at:
		* https://jira.prominic.net/browse/NATIVE-302
		*/
		file = new File(finalExecutablePath + appInternalPathToPlist);
		if (file.exists)
		{
			var fileContentString = cast(FileUtil.readFromFile(file), String);

			var plist = PListUtil.readFromFile( file.nativePath );
			var executableFileName:String = null;

			if ( plist != null && plist.exist( PListEntryId.CFBundleExecutable ) ) {

				executableFileName = cast plist.get( PListEntryId.CFBundleExecutable ).value;

			} else {

				var pathToReplace:String = splitPath[splitPath.length - 1];
				executableFileName = pathToReplace.replace( ".app", "" );

			}

			var appInternalPathToExec:String = "/Contents/MacOS/";
			// to overcome some silly mis-cnfiguration issue
			// one which came for Cyberlink where info.plist
			// mentioned with executable with wrong casing.
			// to overcome such situation another round of
			// painful checking we've decided to take for
			// every other application validation:
			// https://jira.prominic.net/browse/NATIVE-302
			var exeFolderPath:String = finalExecutablePath + appInternalPathToExec;
			finalExecutablePath += appInternalPathToExec + executableFileName;
			file = new File(finalExecutablePath);
			// if problem in case matching
			// in case-sensitive system
			if (!file.exists)
			{
				file = new File(exeFolderPath);
				var fileLists:Array<File> = file.getDirectoryListing();
				for (file in fileLists)
				{
					if (finalExecutablePath.toLowerCase() == file.nativePath.toLowerCase())
					{
						finalExecutablePath = file.nativePath;
						break;
					}
				}
			}
		}
		#else	
		finalExecutablePath = path;
		file = new File(finalExecutablePath);
		if (file.isDirectory || (file.extension.toLowerCase() != "exe"))
		{
			return null;
		}
		#end
        // searching for the existing file
        if (file.nativePath != finalExecutablePath)
        {
            file = new File(finalExecutablePath);
        }
        if (file.exists)
        {
            file.canonicalize();
            return file.nativePath;
        }

        // unless
        return null;
    }
}