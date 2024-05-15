package prominic.helpers;

import openfl.utils.ByteArray;
import openfl.filesystem.FileStream;
import openfl.filesystem.File;
import openfl.filesystem.FileMode;

enum ReadDataFormat
{
    DATA_FORMAT_STRING;
    DATA_FORMAT_BYTEARRAY;
}

class FileUtil  
{
	 /**
     * Simple read to a given file/path
     * @required
     * target: File (read-destination)
     * dataFormat: String (return data type after read)
     * @return
     * Object
     */
    public static function readFromFile(target:File, dataFormat:ReadDataFormat=DATA_FORMAT_STRING):Dynamic
    {
        var loadedBytes:ByteArray = null;
        var loadedString:String = null;
        var fs:FileStream = new FileStream();
        fs.open(target, FileMode.READ);
        if (dataFormat == DATA_FORMAT_STRING) loadedString = fs.readUTFBytes(fs.bytesAvailable);
        else 
        {
            loadedBytes = new ByteArray();
            fs.readBytes(loadedBytes);
        }
        fs.close();
        
        return ((loadedString != null) ? loadedString : loadedBytes);
    }
}