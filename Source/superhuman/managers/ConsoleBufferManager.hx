package superhuman.managers;

class ConsoleBufferManager {
    
    static public final buffers:Map<String, ConsoleBuffer> = [];

}

@:forward
abstract ConsoleBuffer( Array<String> ) {

    inline public function new() {

        this = [];

    }

}