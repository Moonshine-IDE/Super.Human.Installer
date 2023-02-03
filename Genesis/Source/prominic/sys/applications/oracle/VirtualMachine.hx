package prominic.sys.applications.oracle;

typedef VirtualMachine = {

    // states with 'list vms' command:
    // starting
    // running
    // power off

    ?CfgFile:String,
    ?LogFldr:String,
    ?SnapFldr:String,
    ?VMState:String,
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
    ?id:String,
    ?longmode:String,
    ?memory:Int,
    ?name:String,
    ?nestedhwvirt:String,
    ?ostype:String,
    ?pae:String,
    ?pagefusion:String,
    ?root:String,
    ?triplefaultreset:String,
    ?vram:Int,
    ?x2apic:String,

}