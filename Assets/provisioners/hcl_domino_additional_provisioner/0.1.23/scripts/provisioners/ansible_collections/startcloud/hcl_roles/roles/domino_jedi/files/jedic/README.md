# libunixruntime.so

This is a legacy JNI application that is used as an interface for managing processes on Linux.  We may be able to remove this.

## Build 

This library should be built on the system that you are trying to deploy JeDI to.  Open the source directory (currently /opt/prominic/jedi/src), update the JDK path if necessary, and then run the Makefile:

    make

The compiled library is: `libunixruntime.so`.  Copy it to the OS-specific directory like this:

    cp libunixruntime.so lib/Linux/libunixruntime.so
