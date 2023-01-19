package superhuman.interfaces;

interface IConsole {
    
    public function appendText( test:String, isError:Bool = false ):Void;
    public function clear():Void;

}