package genesis.application.components;

import feathers.controls.Label;
import feathers.controls.LayoutGroup;
import feathers.layout.HorizontalLayoutData;
import prominic.core.interfaces.IValidator;


@:styleContext
class GenesisFormRow extends LayoutGroup implements IValidator {

    var _label:Label;

    var _text:String;
    public var text( get, set ):String;
    function get_text() return _text;
    function set_text( value:String ):String {
        if ( _text == value ) return value;
        _text = value;
        if ( _label != null ) _label.text = _text;
        return value;
    }

    var _content:GenesisFormRowContent;
    public var content( get, set ):GenesisFormRowContent;
    function get_content() return _content;
    function set_content( value:GenesisFormRowContent ):GenesisFormRowContent {
        if ( _content == value ) return value;
        if (_content != null)
        {
            if (value != null)
            {
                this.removeChild(_content);
                this.addChild(value);
            }
        }
        _content = value;
        return value;
    }

    public function new() {
        
        super();

        _label = new Label();
        _label.layoutData = new HorizontalLayoutData( 40 );
        this.addChild( _label );

        _content = new GenesisFormRowContent();
        _content.layoutData = new HorizontalLayoutData( 60 );
        this.addChild( _content );
    }

    public function isValid():Bool {

        var v = true;

        for ( i in 0..._content.numChildren ) {

            var c = _content.getChildAt( i );
            if ( c != null && Std.isOfType( c, IValidator ) && !cast( c, IValidator ).isValid() ) v = false;

        }

        return v;

    }

}