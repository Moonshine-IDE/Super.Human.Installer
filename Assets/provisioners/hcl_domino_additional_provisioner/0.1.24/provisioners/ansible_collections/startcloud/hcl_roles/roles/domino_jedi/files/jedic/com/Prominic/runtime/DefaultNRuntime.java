package com.Prominic.runtime;

/**
 * Wrapper of the NRuntime around the default Java Runtime.
 * Creation date: (8/17/2001 4:44:08 PM)
 * @author: Administrator
 */
public class DefaultNRuntime extends NRuntime {
/**
 * DefaultNRuntime constructor comment.
 */
public DefaultNRuntime() {
	super();
}
/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:44:08 PM)
 * @param file java.lang.String
 * @param mode int
 * @exception java.io.IOException The exception description.
 * @exception java.lang.SecurityException The exception description.
 */
public void chmod(String file, int mode) throws java.io.IOException, SecurityException {}
/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:44:08 PM)
 * @param file java.lang.String
 * @param uid int
 * @param gid int
 * @exception java.io.IOException The exception description.
 * @exception java.lang.SecurityException The exception description.
 */
public void chown(String file, int uid, int gid) throws java.io.IOException, SecurityException {}
/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:44:08 PM)
 * @return com.Prominic.runtime.NProcess
 * @param command java.lang.String[]
 * @exception java.io.IOException The exception description.
 */
public NProcess exec(java.lang.String[] command) throws java.io.IOException {
	return new DefaultNProcess(Runtime.getRuntime().exec(command));
}
/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:44:08 PM)
 * @return com.Prominic.runtime.NProcess
 * @param command java.lang.String
 * @exception java.io.IOException The exception description.
 */
public NProcess exec(String command) throws java.io.IOException {
	return new DefaultNProcess(Runtime.getRuntime().exec(command));
}
/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:44:08 PM)
 * @param pid int
 * @exception java.lang.SecurityException The exception description.
 */
public void killProcess(int pid) throws SecurityException {}
/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:44:08 PM)
 * @param pid int
 * @param signal int
 * @exception java.lang.SecurityException The exception description.
 */
public void signalProcess(int pid, int signal) throws SecurityException {}
/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:44:08 PM)
 * @return int
 * @param cmd java.lang.String
 */
public int system(String cmd) {
	return 0;
}

/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:44:08 PM)
 * @param file java.lang.String
 * @param gid int
 * @exception java.io.IOException The exception description.
 * @exception java.lang.SecurityException The exception description.
 */
public void chgrp(String file, int gid) throws java.io.IOException, SecurityException {}

/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:44:08 PM)
 * @param file java.lang.String
 * @param uid int
 * @exception java.io.IOException The exception description.
 * @exception java.lang.SecurityException The exception description.
 */
public void chown(String file, int uid) throws java.io.IOException, SecurityException {}

/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:44:08 PM)
 * @return com.Prominic.runtime.NProcess
 * @param command java.lang.String[]
 * @exception java.io.IOException The exception description.
 */
public NProcess exec(java.lang.String[] command, String stdout, String stderr, String stdin) throws java.io.IOException {
	return new DefaultNProcess(Runtime.getRuntime().exec(command));
}

/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:44:08 PM)
 * @return com.Prominic.runtime.NProcess
 * @param command java.lang.String[]
 * @exception java.io.IOException The exception description.
 */
public NProcess exec(int uid, java.lang.String[] command) throws java.io.IOException {
	return new DefaultNProcess(Runtime.getRuntime().exec(command));
}

/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:44:08 PM)
 * @return com.Prominic.runtime.NProcess
 * @param command java.lang.String[]
 * @exception java.io.IOException The exception description.
 */
public NProcess exec(int uid, java.lang.String[] command, String stdout, String stderr, String stdin) throws java.io.IOException {
	return new DefaultNProcess(Runtime.getRuntime().exec(command));
}

/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:44:08 PM)
 * @return com.Prominic.runtime.NProcess
 * @param command java.lang.String[]
 * @exception java.io.IOException The exception description.
 */
public NProcess exec(int uid, int gid, java.lang.String[] command) throws java.io.IOException {
	return new DefaultNProcess(Runtime.getRuntime().exec(command));
}

/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:44:08 PM)
 * @return com.Prominic.runtime.NProcess
 * @param command java.lang.String[]
 * @exception java.io.IOException The exception description.
 */
public NProcess exec(int uid, int gid, java.lang.String[] command, String stdout, String stderr, String stdin) throws java.io.IOException {
	return new DefaultNProcess(Runtime.getRuntime().exec(command));
}

/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:44:08 PM)
 * @return com.Prominic.runtime.NProcess
 * @param command java.lang.String
 * @exception java.io.IOException The exception description.
 */
public NProcess exec(int uid, int gid, String command) throws java.io.IOException {
	return new DefaultNProcess(Runtime.getRuntime().exec(command));
}

/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:44:08 PM)
 * @return com.Prominic.runtime.NProcess
 * @param command java.lang.String
 * @exception java.io.IOException The exception description.
 */
public NProcess exec(int uid, int gid, String command, String stdout, String stdin, String stderr) throws java.io.IOException {
	return new DefaultNProcess(Runtime.getRuntime().exec(command));
}

/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:44:08 PM)
 * @return com.Prominic.runtime.NProcess
 * @param command java.lang.String
 * @exception java.io.IOException The exception description.
 */
public NProcess exec(int uid, String command) throws java.io.IOException {
	return new DefaultNProcess(Runtime.getRuntime().exec(command));
}

/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:44:08 PM)
 * @return com.Prominic.runtime.NProcess
 * @param command java.lang.String
 * @exception java.io.IOException The exception description.
 */
public NProcess exec(int uid, String command, String stdout, String stdin, String stderr) throws java.io.IOException {
	return new DefaultNProcess(Runtime.getRuntime().exec(command));
}

/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:44:08 PM)
 * @return com.Prominic.runtime.NProcess
 * @param command java.lang.String
 * @exception java.io.IOException The exception description.
 */
public NProcess exec(String command, String stdout, String stdin, String stderr) throws java.io.IOException {
	return new DefaultNProcess(Runtime.getRuntime().exec(command));
}
}