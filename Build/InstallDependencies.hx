import sys.io.Process;
import sys.io.File;
import haxe.io.Path;
import sys.FileSystem;

class InstallDependencies {
    public static function main() {
        // Install required libraries
        installHaxelib("hxcpp", "git", "https://github.com/HaxeFoundation/hxcpp.git v4.3.86");
        installHaxelib("lime", "install", "8.2.2");
        installHaxelib("format", "install", "");
        installHaxelib("hxp", "install", "");
        installHaxelib("yaml", "git", "https://github.com/Sword352/hx-yaml master");
        installHaxelib("lime-samples", "git", "https://github.com/openfl/lime-samples");
        installHaxelib("openfl", "install", "9.4.1");
        installHaxelib("flixel", "install", "");
        installHaxelib("hxWindowColorMode", "install", "");
        installHaxelib("feathersui", "git", "https://github.com/feathersui/feathersui-openfl.git");
        installHaxelib("champaign", "git", "https://github.com/Moonshine-IDE/Champaign.git");
        installHaxelib("mxhx-component", "git", "https://github.com/mxhx-dev/mxhx-component.git");
        installHaxelib("mxhx-feathersui", "git", "https://github.com/mxhx-dev/mxhx-feathersui.git");
        
        // Run OpenFL setup
        var process = new Process("haxelib", ["run", "openfl", "setup", "-y"]);
        var exitCode = process.exitCode();
        Sys.println("OpenFL setup completed with exit code: " + exitCode);
        
        // List installed libraries
        process = new Process("haxelib", ["list"]);
        Sys.println(process.stdout.readAll().toString());
        
        Sys.println("All dependencies installed successfully!");
    }
    
    private static function installHaxelib(name:String, command:String, args:String) {
        var cmdArgs = command == "install" ? 
            ["install", name] : 
            [command, name, args];
        
        if (args != "" && command == "install") {
            cmdArgs.push(args);
        }
        
        Sys.println('Installing $name...');
        var process = new Process("haxelib", cmdArgs);
        var exitCode = process.exitCode();
        if (exitCode != 0) {
            Sys.println("Error installing " + name + ": " + process.stderr.readAll().toString());
        } else {
            Sys.println(name + " installed successfully");
        }
    }
}
