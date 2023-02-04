package;

import haxe.macro.Context;
import haxe.macro.Expr;
import sys.io.Process;

class BuildMacro {
    
    macro static public function createGitInfo():Array<Field> {

        var defaultGitBranch:String = null;
        var defaultGitCommit:String = null;
        var fields = Context.getBuildFields();

        var p = new Process( 'git', [ "branch", "--show-current" ] );
        var e = p.exitCode();

        if ( e == 0 ) {

            defaultGitBranch = p.stdout.readLine();

        }

        var gitBranch = {

            name: "GIT_BRANCH",
            doc: null,
            meta: [],
            access: [AStatic, APublic],
            kind: FVar(macro:String, macro $v{defaultGitBranch}),
            pos: Context.currentPos(),

        };

        fields.push( gitBranch );

        var p = new Process( 'git', [ "rev-parse", "--short", "HEAD" ] );
        var e = p.exitCode();

        if ( e == 0 ) {

            defaultGitCommit = p.stdout.readLine();

        }

        var gitCommit = {

            name: "GIT_COMMIT",
            doc: null,
            meta: [],
            access: [AStatic, APublic],
            kind: FVar(macro:String, macro $v{defaultGitCommit}),
            pos: Context.currentPos(),

        };

        fields.push( gitCommit );

        return fields;

    }

}