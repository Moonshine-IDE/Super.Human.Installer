package prominic.sys.applications.utm;

typedef UTMMachine = {

    // states from 'utmctl list' command:
    // running
    // stopped
    // paused
    
    ?name:String,
    ?path:String,
    ?status:String,
    ?serverId:Int,
    ?vmId:String,

}
