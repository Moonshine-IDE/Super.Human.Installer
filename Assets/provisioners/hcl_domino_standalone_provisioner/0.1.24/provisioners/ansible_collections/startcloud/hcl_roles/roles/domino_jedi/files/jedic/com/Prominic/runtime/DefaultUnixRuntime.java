package com.Prominic.runtime;

/**
 * Insert the type's description here.
 * Creation date: (8/17/2001 5:13:35 PM)
 * @author: Administrator
 */
public class DefaultUnixRuntime extends NRuntime {
/**
 * DefaultUnixRuntime constructor comment.
 */
public DefaultUnixRuntime() {
	super();
}
/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 5:13:35 PM)
 * @param file java.lang.String
 * @param mode int
 * @exception java.io.IOException The exception description.
 * @exception java.lang.SecurityException The exception description.
 */
public void chmod(String file, int mode) throws java.io.IOException, SecurityException {
	//UnixRuntime.chmod(file,mode);	
}
/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 5:13:35 PM)
 * @param file java.lang.String
 * @param uid int
 * @param gid int
 * @exception java.io.IOException The exception description.
 * @exception java.lang.SecurityException The exception description.
 */
public void chown(String file, int uid, int gid) throws java.io.IOException, SecurityException {
	//UnixRuntime.chown(file,uid,gid);
}
/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 5:13:35 PM)
 * @return com.Prominic.runtime.NProcess
 * @param command java.lang.String[]
 * @exception java.io.IOException The exception description.
 */
public NProcess exec(java.lang.String[] command) throws java.io.IOException {
	return new DefaultUnixProcess(UnixRuntime.exec(command));
}

public NProcess exec(java.lang.String[] command,String stdout, String stderr, String stdin) throws java.io.IOException {
	return new DefaultUnixProcess(UnixRuntime.exec(command, stdout, stderr, stdin));
}
/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 5:13:35 PM)
 * @return com.Prominic.runtime.NProcess
 * @param command java.lang.String
 * @exception java.io.IOException The exception description.
 */
public NProcess exec(String command) throws java.io.IOException {
	return new DefaultUnixProcess(UnixRuntime.exec(command));
}
/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 5:13:35 PM)
 * @param pid int
 * @exception java.lang.SecurityException The exception description.
 */
public void killProcess(int pid) throws SecurityException {
	//UnixRuntime.killProcess(pid);	
}
/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 5:13:35 PM)
 * @param pid int
 * @param signal int
 * @exception java.lang.SecurityException The exception description.
 */
public void signalProcess(int pid, int signal) throws SecurityException {
	//UnixRuntime.sendSignal(pid,signal);	
}
/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 5:13:35 PM)
 * @return int
 * @param cmd java.lang.String
 */
public int system(String command) {
	return -1;
	//return UnixRuntime.system(command);
}

/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 5:13:35 PM)
 * @param file java.lang.String
 * @param gid int
 * @exception java.io.IOException The exception description.
 * @exception java.lang.SecurityException The exception description.
 */
public void chgrp(String file, int gid) throws java.io.IOException, SecurityException {
	//UnixRuntime.chgrp(file,gid);	
}

/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 5:13:35 PM)
 * @param file java.lang.String
 * @param uid int
 * @exception java.io.IOException The exception description.
 * @exception java.lang.SecurityException The exception description.
 */
public void chown(String file, int uid) throws java.io.IOException, SecurityException {
	//UnixRuntime.chown(file,uid);
}

/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 5:13:35 PM)
 * @return com.Prominic.runtime.NProcess
 * @param command java.lang.String[]
 * @exception java.io.IOException The exception description.
 */
public NProcess exec(int uid, java.lang.String[] command) throws java.io.IOException {
	return new DefaultUnixProcess(UnixRuntime.exec(uid, command));
}

public NProcess exec(int uid, java.lang.String[] command,String stdout, String stderr, String stdin) throws java.io.IOException {
	return new DefaultUnixProcess(UnixRuntime.exec(uid, command, stdout, stderr, stdin));
}

/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 5:13:35 PM)
 * @return com.Prominic.runtime.NProcess
 * @param command java.lang.String[]
 * @exception java.io.IOException The exception description.
 */
public NProcess exec(int uid, int gid, java.lang.String[] command) throws java.io.IOException {
	return new DefaultUnixProcess(UnixRuntime.exec(uid,gid,command));
}

public NProcess exec(int uid, int gid, java.lang.String[] command,String stdout, String stderr, String stdin) throws java.io.IOException {
	return new DefaultUnixProcess(UnixRuntime.exec(uid,gid,command, stdout, stderr, stdin));
}

/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 5:13:35 PM)
 * @return com.Prominic.runtime.NProcess
 * @param command java.lang.String
 * @exception java.io.IOException The exception description.
 */
public NProcess exec(int uid, int gid, String command) throws java.io.IOException {
	return new DefaultUnixProcess(UnixRuntime.exec(uid,gid,command));
}

/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 5:13:35 PM)
 * @return com.Prominic.runtime.NProcess
 * @param command java.lang.String
 * @exception java.io.IOException The exception description.
 */
public NProcess exec(int uid, int gid, String command,String stdout, String stderr, String stdin) throws java.io.IOException {
	return new DefaultUnixProcess(UnixRuntime.exec(uid,gid,command,stdout, stderr, stdin));
}

/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 5:13:35 PM)
 * @return com.Prominic.runtime.NProcess
 * @param command java.lang.String
 * @exception java.io.IOException The exception description.
 */
public NProcess exec(int uid, String command) throws java.io.IOException {
	return new DefaultUnixProcess(UnixRuntime.exec(uid, command));
}

/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 5:13:35 PM)
 * @return com.Prominic.runtime.NProcess
 * @param command java.lang.String
 * @exception java.io.IOException The exception description.
 */
public NProcess exec(int uid, String command,String stdout, String stderr, String stdin) throws java.io.IOException {
	return new DefaultUnixProcess(UnixRuntime.exec(uid, command,stdout, stderr, stdin));
}

/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 5:13:35 PM)
 * @return com.Prominic.runtime.NProcess
 * @param command java.lang.String
 * @exception java.io.IOException The exception description.
 */
public NProcess exec(String command,String stdout, String stderr, String stdin) throws java.io.IOException {
	return new DefaultUnixProcess(UnixRuntime.exec(command,stdout, stderr, stdin));
}
}