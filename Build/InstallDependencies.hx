class InstallDependencies {
    public static function main() {        
        Sys.command('haxelib install hxcpp');
        Sys.command('git clone --recursive --depth 1 --branch develop https://github.com/openfl/lime');
        Sys.command('haxelib dev lime lime');
        Sys.command('haxelib install format');
        Sys.command('haxelib install hxp');
        Sys.command('haxelib git lime-samples https://github.com/openfl/lime-samples');
        Sys.command('haxelib git openfl https://github.com/openfl/openfl.git develop');
        Sys.command('haxelib run openfl setup');
        Sys.command('haxelib git feathersui https://github.com/feathersui/feathersui-openfl.git');
        Sys.command('haxelib git champaign https://github.com/Moonshine-IDE/Champaign.git');
    }
}