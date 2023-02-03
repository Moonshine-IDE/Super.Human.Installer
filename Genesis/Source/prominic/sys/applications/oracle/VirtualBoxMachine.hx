package prominic.sys.applications.oracle;

typedef VirtualBoxMachine = {

    // states with 'list vms' command:
    // starting
    // running
    // power off

    ?CfgFile:String,
    ?LogFldr:String,
    ?SnapFldr:String,
    ?apic:String,
    ?chipset:String,
    ?cpuexecutioncap:Int,
    ?cpuprofile:String,
    ?cpus:Int,
    ?description:String,
    ?encryption:Bool,
    ?firmware:String,
    ?hardwareuuid:String,
    ?hpet:String,
    ?longmode:String,
    ?memory:Int,
    ?name:String,
    ?nestedhwvirt:String,
    ?ostype:String,
    ?pae:String,
    ?pagefusion:String,
    ?root:String,
    ?serverId:Int,
    ?triplefaultreset:String,
    ?vram:Int,
    ?x2apic:String,
    ?virtualBoxId:String,
    ?virtualBoxState:String,

}