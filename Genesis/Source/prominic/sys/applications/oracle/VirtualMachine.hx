package prominic.sys.applications.oracle;

typedef VirtualMachine = {

    ?name:String,
    ?id:String,
    ?root:String,
    ?encryption:Bool,
    ?memory:Int,
    ?vram:Int,
    ?cpuexecutioncap:Int,
    ?cpus:Int,
    ?VMState:String,
    ?CfgFile:String,
    ?SnapFldr:String,
    ?LogFldr:String,
    ?description:String,
    ?hardwareuuid:String,
    ?ostype:String,
    ?pagefusion:String,
    ?hpet:String,
    ?cpuprofile:String,
    ?chipset:String,
    ?firmware:String,
    ?pae:String,
    ?longmode:String,
    ?triplefaultreset:String,
    ?apic:String,
    ?x2apic:String,
    ?nestedhwvirt:String,

}