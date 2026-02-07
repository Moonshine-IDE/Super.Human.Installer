CC		= gcc -g
SOLARISJNIPATH	= /usr/local/j2sdk1_3_0_02/include
SOLARISJNIMD	= /Partitions/local/j2sdk1_3_0_02/include/solaris/
#LINUXJNIPATH	= /opt/prominic/jdk/1.3/include
#LINUXJNIMD	= /opt/prominic/jdk/1.3/include/linux
#AIXJNIPATH	= /opt/prominic/jdk/1.3/include
#LINUXJNIPATH	= /opt/prominic/jedi/jdk1.8.0.432-zulu/include
#LINUXJNIMD	= /opt/prominic/jedi/jdk1.8.0.432-zulu/include/linux
#AIXJNIPATH	= /opt/prominic/jedi/jdk1.8.0.432-zulu/include
LINUXJNIPATH	= /opt/prominic/jedi/jdk1.8*/include
LINUXJNIMD	= /opt/prominic/jedi/jdk1.8*/include/linux
AIXJNIPATH	= /opt/prominic/jedi/jdk1.8*/include

linux: class h lib-linux

solaris: class h lib-solaris

aix: class h lib-aix

lib-solaris: UnixRuntimeImp.c UnixProcess.h
	${CC} -DSOLARIS -shared -I ${SOLARISJNIPATH} -I ${SOLARISJNIMD} UnixRuntimeImp.c -o libunixruntime.so -Wall

lib-linux: UnixRuntimeImp.c UnixProcess.h
	${CC} -DDEBUG -DLINUX -shared -I ${LINUXJNIPATH} -I ${LINUXJNIMD} UnixRuntimeImp.c -o libunixruntime.so -Wall
lib-linux-sem: UnixRuntimeImp.c UnixProcess.h
	${CC} -DDEBUG -DLINUX -DUSESEMS -shared -I ${LINUXJNIPATH} -I ${LINUXJNIMD} UnixRuntimeImp.c -o libunixruntime.so -Wall
lib-aix: UnixRuntimeImp.c UnixProcess.h
	${CC} -DAIX -shared -I ${AIXJNIPATH} UnixRuntimeImp.c -o libunixruntime.so -Wall

h: 
	javah -o UnixProcess.h com.Prominic.runtime.UnixProcess

runtime:
	javac com/Prominic/runtime/*.java

class: 
	javac com/Prominic/runtime/UnixProcess.java

tests:
	javac -classpath . ExecThread.java ExecTest.java Tests/*.java

clean:
	-rm *.so *.class UnixProcess.h core

