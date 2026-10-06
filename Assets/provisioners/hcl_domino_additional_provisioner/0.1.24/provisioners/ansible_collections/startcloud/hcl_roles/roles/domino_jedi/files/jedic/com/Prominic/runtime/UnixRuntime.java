package com.Prominic.runtime;

import java.util.StringTokenizer;

public class UnixRuntime {




/**
 * Kills the unix process represented by the pid
 * Creation date: (8/21/2001 1:11:40 PM)
 * @param pid int The unix process identifier
 * @throws java.lang.SecurityException If there aren't the right to kill the process
 */
public static void killProcess(int pid) throws java.lang.SecurityException {
	//sendSignal(pid, 9);
}

/**
 * Start an unix process.
 * Creation date: (8/21/2001 1:11:40 PM)
 * @param cmd java.lang.String The command
 * @return com.Prominic.runtime.UnixProcess The started process
 */
public static UnixProcess exec(String cmd) {
	return new UnixProcess(cmd);
}








/**
 * Start an unix process.
 * Creation date: (8/21/2001 1:11:40 PM)
 * @param cmd java.lang.String[] The command
 * @return com.Prominic.runtime.UnixProcess The started process
 */
public static UnixProcess exec(String cmd[]) {
	return new UnixProcess(cmd);
}
	

/**
 * Start an unix process.
 * Creation date: (8/21/2001 1:11:40 PM)
 * @param cmd java.lang.String[] The command
 * @param stdoutfilename java.lang.String The output filename for the process
 * @param stderrfilename java.lang.String The error filename for the process
 * @param stdinfilename java.lang.String The input filename for the process
 * @return com.Prominic.runtime.UnixProcess The started process
 */
public static UnixProcess exec(
	String cmd[],
	String stdoutfilename,
	String stderrfilename,
	String stdinfilename) {
	    
	return new UnixProcess(cmd, stdoutfilename, stderrfilename, stdinfilename);
}










	
	static {
		System.loadLibrary("unixruntime");
		//initialize();
	}

/**
 * Start an unix process.
 * Creation date: (8/21/2001 1:11:40 PM)
 * @param cmd java.lang.String The command
 * @param stdoutfilename java.lang.String The output filename for the process
 * @param stderrfilename java.lang.String The error filename for the process
 * @param stdinfilename java.lang.String The input filename for the process
 * @return com.Prominic.runtime.UnixProcess The started process
 */
public static UnixProcess exec(
	String cmd,
	String stdoutfilename,
	String stderrfilename,
	String stdinfilename) {
	    
	return new UnixProcess(cmd, stdoutfilename, stderrfilename, stdinfilename);
}	


/**
 * Start an unix process.
 * Creation date: (8/21/2001 1:11:40 PM)
 * @param uid int The process will be start by the user specified by its uid
 * @param cmd java.lang.String[] The command
 * @return com.Prominic.runtime.UnixProcess The started process
 */
public static UnixProcess exec(int uid, String cmd[]) {
	return new UnixProcess(uid, cmd);
}

/**
 * Start an unix process.
 * Creation date: (8/21/2001 1:11:40 PM)
 * @param uid int The process will be start by the user specified by its uid
 * @param cmd java.lang.String[] The command
 * @param stdoutfilename java.lang.String The output filename for the process
 * @param stderrfilename java.lang.String The error filename for the process
 * @param stdinfilename java.lang.String The input filename for the process
 * @return com.Prominic.runtime.UnixProcess The started process
 */
public static UnixProcess exec(
	int uid,
	String cmd[],
	String stdoutfilename,
	String stderrfilename,
	String stdinfilename) {
	    
	return new UnixProcess(uid,cmd, stdoutfilename, stderrfilename, stdinfilename);
}

/**
 * Start an unix process.
 * Creation date: (8/21/2001 1:11:40 PM)
 * @param uid int The process will be start by the user specified by its uid
 * @param gid int The process will be start by the group specified by its gid
 * @param cmd java.lang.String[] The command
 * @return com.Prominic.runtime.UnixProcess The started process
 */
public static UnixProcess exec(int uid, int gid, String[] cmd) {
	return new UnixProcess(uid, gid, cmd);
}

/**
 * Start an unix process.
 * Creation date: (8/21/2001 1:11:40 PM)
 * @param uid int The process will be start by the user specified by its uid
 * @param gid int The process will be start by the group specified by its gid
 * @param cmd java.lang.String[] The command
 * @param stdoutfilename java.lang.String The output filename for the process
 * @param stderrfilename java.lang.String The error filename for the process
 * @param stdinfilename java.lang.String The input filename for the process
 * @return com.Prominic.runtime.UnixProcess The started process
 */
public static UnixProcess exec(
	int uid,
	int gid,
	String cmd[],
	String stdoutfilename,
	String stderrfilename,
	String stdinfilename) {
	    
	return new UnixProcess(uid, gid, cmd, stdoutfilename, stderrfilename, stdinfilename);
}

/**
 * Start an unix process.
 * Creation date: (8/21/2001 1:11:40 PM)
 * @param uid int The process will be start by the user specified by its uid
 * @param gid int The process will be start by the group specified by its gid
 * @param cmd java.lang.String The command
 * @return com.Prominic.runtime.UnixProcess The started process
 */
public static UnixProcess exec(int uid, int gid, String cmd) {
	return new UnixProcess(uid, gid, cmd);
}

/**
 * Start an unix process.
 * Creation date: (8/21/2001 1:11:40 PM)
 * @param uid int The process will be start by the user specified by its uid
 * @param gid int The process will be start by the group specified by its gid
 * @param cmd java.lang.String The command
 * @param stdoutfilename java.lang.String The output filename for the process
 * @param stderrfilename java.lang.String The error filename for the process
 * @param stdinfilename java.lang.String The input filename for the process
 * @return com.Prominic.runtime.UnixProcess The started process
 */
public static UnixProcess exec(
	int uid,
	int gid,
	String cmd,
	String stdoutfilename,
	String stderrfilename,
	String stdinfilename) {
	    
	return new UnixProcess(uid, gid, cmd, stdoutfilename, stderrfilename, stdinfilename);
}

/**
 * Start an unix process.
 * Creation date: (8/21/2001 1:11:40 PM)
 * @param uid int The process will be start by the user specified by its uid
 * @param cmd java.lang.String The command
 * @return com.Prominic.runtime.UnixProcess The started process
 */
public static UnixProcess exec(int uid, String cmd) {
	return new UnixProcess(uid, cmd);
}

/**
 * Start an unix process.
 * Creation date: (8/21/2001 1:11:40 PM)
 * @param uid int The process will be start by the user specified by its uid
 * @param gid int The process will be start by the group specified by its gid
 * @param cmd java.lang.String The command
 * @param stdoutfilename java.lang.String The output filename for the process
 * @param stderrfilename java.lang.String The error filename for the process
 * @param stdinfilename java.lang.String The input filename for the process
 * @return com.Prominic.runtime.UnixProcess The started process
 */
public static UnixProcess exec(
	int uid,
	String cmd,
	String stdoutfilename,
	String stderrfilename,
	String stdinfilename) {
	    
	return new UnixProcess(uid,cmd, stdoutfilename, stderrfilename, stdinfilename);
}

	private static int runningProcesses = 0;

/**
 * Insert the method's description here.
 * Creation date: (10/31/2001 7:11:26 PM)
 * @param newRunningProcesses int
 */
protected synchronized static void decrementRunningProcesses() {
	runningProcesses--;
}

/**
 * Insert the method's description here.
 * Creation date: (10/31/2001 7:13:06 PM)
 * @return int
 */
public static int getRunningProcesses() {
	return runningProcesses;
}

/**
 * Insert the method's description here.
 * Creation date: (10/31/2001 7:11:26 PM)
 * @return int
 */
protected synchronized static int incrementRunningProcesses() {
	runningProcesses++;
	return runningProcesses;
}
}