package com.Prominic.runtime;

/**
 * Insert the type's description here.
 * Creation date: (8/14/2001 12:13:31 PM)
 * @author: Administrator
 */
public abstract class NRuntime {
	private static NRuntime runtime = new DefaultNRuntime();
/**
 * Runtime constructor comment.
 */
public NRuntime() {
	super();
}
/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:37:58 PM)
 * @param file java.lang.String
 * @param mode int
 * @exception java.io.IOException The exception description.
 * @exception java.lang.SecurityException The exception description.
 */
public abstract void chmod(String file, int mode) throws java.io.IOException, java.lang.SecurityException;
/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:38:50 PM)
 * @param file java.lang.String
 * @param uid int
 * @param gid int
 * @exception java.io.IOException The exception description.
 * @exception java.lang.SecurityException The exception description.
 */
public abstract void chown(String file, int uid, int gid) throws java.io.IOException, java.lang.SecurityException;
/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:21:37 PM)
 * @return com.Prominic.runtime.NProcess
 * @param command java.lang.String[]
 * @exception java.io.IOException The exception description.
 */
public abstract NProcess exec(String[] command) throws java.io.IOException;
public abstract NProcess exec(String[] command, String stdout, String stderr, String stdin) throws java.io.IOException;
/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:26:08 PM)
 * @return com.Prominic.runtime.NProcess
 * @param command java.lang.String
 * @exception java.io.IOException The exception description.
 */
public abstract NProcess exec(String command) throws java.io.IOException;
/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:16:25 PM)
 * @return com.Prominic.runtime.NRuntime
 */
public static NRuntime getRuntime() {
	return runtime;
}
/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:39:52 PM)
 * @param pid int
 * @exception java.lang.SecurityException The exception description.
 */
public abstract void killProcess(int pid) throws java.lang.SecurityException;
/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:16:25 PM)
 * @param newRuntime com.Prominic.runtime.NRuntime
 */
public static void setRuntime(NRuntime newRuntime) {
	runtime = newRuntime;
}
/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:40:33 PM)
 * @param pid int
 * @param signal int
 * @exception java.lang.SecurityException The exception description.
 */
public abstract void signalProcess(int pid, int signal) throws java.lang.SecurityException;
/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:39:17 PM)
 * @return int
 * @param cmd java.lang.String
 */
public abstract int system(String cmd);

/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:37:58 PM)
 * @param file java.lang.String
 * @param mode int
 * @exception java.io.IOException The exception description.
 * @exception java.lang.SecurityException The exception description.
 */
public abstract void chgrp(String file, int gid) throws java.io.IOException, java.lang.SecurityException;

/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:38:50 PM)
 * @param file java.lang.String
 * @param uid int
 * @param gid int
 * @exception java.io.IOException The exception description.
 * @exception java.lang.SecurityException The exception description.
 */
public abstract void chown(String file, int uid) throws java.io.IOException, java.lang.SecurityException;

/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:21:37 PM)
 * @return com.Prominic.runtime.NProcess
 * @param command java.lang.String[]
 * @exception java.io.IOException The exception description.
 */
public abstract NProcess exec(int uid, String[] command) throws java.io.IOException;

public abstract NProcess exec(int uid, String[] command, String stdout, String stderr, String stdin) throws java.io.IOException;

/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:21:37 PM)
 * @return com.Prominic.runtime.NProcess
 * @param command java.lang.String[]
 * @exception java.io.IOException The exception description.
 */
public abstract NProcess exec(int uid, int gid, String[] command) throws java.io.IOException;

public abstract NProcess exec(int uid, int gid, String[] command, String stdout, String stderr, String stdin) throws java.io.IOException;

/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:26:08 PM)
 * @return com.Prominic.runtime.NProcess
 * @param command java.lang.String
 * @exception java.io.IOException The exception description.
 */
public abstract NProcess exec(int uid, int gid, String command) throws java.io.IOException;

/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:26:08 PM)
 * @return com.Prominic.runtime.NProcess
 * @param command java.lang.String
 * @exception java.io.IOException The exception description.
 */
public abstract NProcess exec(int uid, int gid, String command, String stdout, String stderr, String stdin) throws java.io.IOException;

/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:26:08 PM)
 * @return com.Prominic.runtime.NProcess
 * @param command java.lang.String
 * @exception java.io.IOException The exception description.
 */
public abstract NProcess exec(int uid, String command) throws java.io.IOException;

/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:26:08 PM)
 * @return com.Prominic.runtime.NProcess
 * @param command java.lang.String
 * @exception java.io.IOException The exception description.
 */
public abstract NProcess exec(int uid, String command, String stdout, String stderr, String stdin) throws java.io.IOException;

/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:26:08 PM)
 * @return com.Prominic.runtime.NProcess
 * @param command java.lang.String
 * @exception java.io.IOException The exception description.
 */
public abstract NProcess exec(String command, String stdout, String stderr, String stdin) throws java.io.IOException;
}