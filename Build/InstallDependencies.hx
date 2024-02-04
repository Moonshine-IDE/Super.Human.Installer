// Usage:
// $: haxe --run InstallDependencies.hx --target=windows --haxelibpath=C:/MoonshineSDKs/Haxe/lib

class InstallDependencies {
    public static function main() {
        var namedArgs = parseNamedArguments(Sys.args());

        trace('Installing dependencies...');
        trace('target: ${namedArgs["target"]}');
        trace('haxelibpath: ${namedArgs["haxelibpath"]}');
        installDependencies(namedArgs['target'], namedArgs['haxelibpath']);
    }

    static function parseNamedArguments(args:Array<String>):Map<String, String> {
        var result = new Map<String, String>();

        for (arg in args) {
            if (StringTools.startsWith(arg, "--")) {
                var parts = arg.split('=');
                var key = parts[0].substr(2); // Remove the "--" prefix
                var value = parts.length > 1 ? parts[1] : "";
                result.set(key, value);
            }
        }

        return result;
    }

    public static function installDependencies(target:String, haxelibPath:String) {        
        Sys.command('haxelib --global update haxelib --quiet --never');

        // Install hxcpp
        Sys.command('haxelib install hxcpp --quiet --never');
        
        // Clone lime
        Sys.command('git clone --recursive --depth 1 --branch develop https://github.com/openfl/lime');
        Sys.command('haxelib dev lime lime');

        // Install lime dependencies
        Sys.command('haxelib install format --quiet');
        Sys.command('haxelib install hxp --quiet');
        Sys.command('haxelib git lime-samples https://github.com/openfl/lime-samples --quiet');

        // Rebuild lime
        Sys.command('haxelib run lime rebuild ${target} -release -clean');

        // Install and setup openfl
        Sys.command('haxelib git openfl https://github.com/openfl/openfl.git develop --quiet --never');
        Sys.command('haxelib run openfl setup --quiet --never');

        // Install other dependencies
        Sys.command('haxelib git feathersui https://github.com/feathersui/feathersui-openfl.git --quiet --never');
        Sys.command('haxelib git champaign https://github.com/Moonshine-IDE/Champaign.git --quiet --never');
    }
}