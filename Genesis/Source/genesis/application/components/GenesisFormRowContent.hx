package genesis.application.components;

import feathers.core.FeathersControl;
import openfl.display.DisplayObject;
import feathers.controls.LayoutGroup;
import feathers.layout.HorizontalLayoutData;

@:styleContext
class GenesisFormRowContent extends LayoutGroup {

    public function new() {

        super();

    }

    override function addChildAt( child:DisplayObject, index:Int ):DisplayObject {

        var fc = cast( child, FeathersControl );

        if ( fc != null ) {

            fc.layoutData = new HorizontalLayoutData( 100 );

        }

        return super.addChildAt( child, index );

    }

}