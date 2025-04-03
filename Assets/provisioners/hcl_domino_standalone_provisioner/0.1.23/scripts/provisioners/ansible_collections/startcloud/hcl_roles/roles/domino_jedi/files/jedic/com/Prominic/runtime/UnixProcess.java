package com.Prominic.runtime;

import java.util.StringTokenizer;

import java.io.File;
import java.util.Vector;
import java.util.Hashtable;
import java.io.IOException;
import java.util.Enumeration;

/**
 * An unix process. It contains a lot of native methods. To used this class
 * the libunixruntime.so must be in LD_LIBRARY_PATH. The class was tested on
 * linux, aix and solaris machine
 * Creation date: (8/13/2001 2:40:35 PM)
 * @author: Valentin Gheorghita
 */

public class UnixProcess implements Runnable {
	// Tell if the unix process is running
	private boolean running = true;
	// After the process finish its running it will contains the exitcode
	private int exitCode;	
	// Tell if the exec couldn't run
	private boolean canNotExecute = false;
	// Tell if there couldn't make fork to start the process
	private boolean canNotMakeFork = false;
	// Tell if there the shared memory used for internal comunication couldn't be allocated
	private boolean canNotAllocateSharedMemory = false;
	// Tell if the setuid command return error when the process was started as another user
		private boolean setUidError = false;
		// Tell if the setgid command return error when the process was started as another user
		private boolean setGidError = false;
	// The error code. It is filled only is <B>canNotExecute<B> is true
	private int errorCode = -1;
	// the unix pid of the process
	private int pid = -1;
	// The signal which kill the process. This is filled only if the process was stoped by an uncatched signal
	private int signal = -1;

	// The unix command
	private String param[];		

	// The output file name for the process. If it is NULL the stdout will be used
	private String stdoutfilename;
	// The error file name for the process. If it is NULL the stderr will be used
	private String stderrfilename;
	// The input file name for the process. If it is NULL the stdin will be used
	private String stdinfilename;

/**
 * Create and start an unix process specified by command.
 * Creation date: (8/21/2001 1:11:40 PM)
 * @param cmd java.lang.String[] The command
 */

public UnixProcess(String[] cmd) {
	this(-1, cmd);
}        


/**
 * Create and start an unix process specified by command.
 * Creation date: (8/21/2001 1:11:40 PM)
 * @param cmd java.lang.String[] The command
 * @param stdoutfilename java.lang.String The output filename for the process
 * @param stderrfilename java.lang.String The error filename for the process
 * @param stdinfilename java.lang.String The input filename for the process 
 */

public UnixProcess(
	String[] cmd,
	String stdoutfilename,
	String stderrfilename,
	String stdinfilename) {
	    
	this(-1, cmd, stdoutfilename, stderrfilename, stdinfilename);
}        




	
/**
 * The thread start method. It starts the unix process using <b>exec</b> method.
 * Creation date: (8/19/2001 2:42:38 PM)
 */
public void run() {

	while (UnixRuntime.getRunningProcesses() >= MAX_PROCESSES) {
	try {
		Thread.sleep(100);
		//System.out.println("************************ too many processes *********");
	} catch (InterruptedException e) {
	}
	}
	UnixRuntime.incrementRunningProcesses();
	this.pid = exec(uid, gid, param, stdoutfilename, stderrfilename, stdinfilename);
}	

	
/**
 * Tells if the process is running or no.
 * Creation date: (8/19/2001 2:42:38 PM)
 * @return boolean <B>True if the process is running, <B>false</B> else.
 */
public boolean isRunning() {
	return running;
}
	
/**
 * Returns exit code if the process is stoped
 * Creation date: (8/19/2001 2:42:38 PM)
 * @return int The exit code of the unix process
 */
public int exitValue()
	throws
		IllegalThreadStateException,
		InterruptedException,
		java.io.IOException,
		java.io.FileNotFoundException,
		SecurityException,
		UnixRuntimeException {
	        
	if (running)
		throw new IllegalThreadStateException("The command is running.");
	if (canNotAllocateSharedMemory)
		throw new UnixRuntimeException("Can not allocate shared memory");
	if (canNotMakeFork)
		throw new UnixRuntimeException("Can not make fork, need by exec");
	if (setUidError)
		throw new UnixRuntimeException("setuid: Operation not permitted");
	if (setGidError)
				throw new UnixRuntimeException("setgid: Operation not permitted");
	/*if (canNotExecute)
		UnixRuntime.throwException(errorCode);*/
	if (signal != -1)
		throw new InterruptedException(
			"The process was interrupted with signal : " + signal);
	return exitCode;
	
}

/**
 * Stoped the process. If the process is not runnig the method returns imediatly.
 * Creation date: (8/21/2001 1:11:40 PM)
 */

public void destroy() {
	while (running && pid == -1)
		try {
			Thread.currentThread().sleep(10);
		} catch (InterruptedException ex) {
		}
	if (running)
		try {
			UnixRuntime.killProcess(pid);
		} catch (SecurityException sex) {
			sex.printStackTrace();
		};
}

/**
 * Returns the process error file name 
 * Creation date: (8/19/2001 2:42:38 PM)
 * @return java.lang.String The process' error file name
 */
public String getStderrFilename() {
	return stderrfilename;
}

/**
 * Returns the process input file name 
 * Creation date: (8/19/2001 2:42:38 PM)
 * @return java.lang.String The process' input file name
 */
public String getStdinFilename() {
	return stdinfilename;
}

/**
 * Returns the process ouput file name 
 * Creation date: (8/19/2001 2:42:38 PM)
 * @return java.lang.String The process' ouput file name
 */
public String getStdoutFilename() {
	return stdoutfilename;
}

	// The unix group (gid) which is running the unix process
	private int gid = -1;
	// The unix user (uid) which is running the unix process
	private int uid = -1;

/**
 * Create and start an unix process specified by command.
 * Creation date: (8/21/2001 1:11:40 PM)
 * @param uid int The process will be start by the user specified by its uid
 * @param cmd java.lang.String[] The command
 */
public UnixProcess(int uid, String[] cmd) {
	this(uid, -1, cmd);
}

/**
 * Create and start an unix process specified by command.
 * Creation date: (8/21/2001 1:11:40 PM)
 * @param uid int The process will be start by the user specified by its uid
 * @param cmd java.lang.String[] The command
 * @param stdoutfilename java.lang.String The output filename for the process
 * @param stderrfilename java.lang.String The error filename for the process
 * @param stdinfilename java.lang.String The input filename for the process 
 */

public UnixProcess(
	int uid,
	String[] cmd,
	String stdoutfilename,
	String stderrfilename,
	String stdinfilename) {
	    
	this(uid, -1, cmd, stdoutfilename, stderrfilename, stdinfilename);
}

/**
 * Create and start an unix process specified by command.
 * Creation date: (8/21/2001 1:11:40 PM)
 * @param uid int The process will be start by the user specified by its uid
 * @param gid int The process will be start by the group specified by its gid
 * @param cmd java.lang.String[] The command
 */

public UnixProcess(int uid, int gid, String[] cmd) {
	this(uid, gid, cmd, null, null, null);
}

/**
 * Create and start an unix process specified by command.
 * Creation date: (8/21/2001 1:11:40 PM)
 * @param uid int The process will be start by the user specified by its uid
 * @param gid int The process will be start by the group specified by its gid
 * @param cmd java.lang.String[] The command
 * @param stdoutfilename java.lang.String The output filename for the process
 * @param stderrfilename java.lang.String The error filename for the process
 * @param stdinfilename java.lang.String The input filename for the process 
 */
public UnixProcess(
	int uid,
	int gid,
	String[] cmd,
	String stdoutfilename,
	String stderrfilename,
	String stdinfilename) {

	this.uid = uid;
	this.gid = gid;
	this.stdoutfilename = stdoutfilename;
	this.stderrfilename = stderrfilename;
	this.stdinfilename = stdinfilename;

	if (cmd != null) {
		param = new String[cmd.length];
		for (int i = 0; i < cmd.length; i++)
			param[i] = new String(cmd[i]);
	} else
		param = null;
	/*this.pid = exec(uid, gid, param, stdoutfilename, stderrfilename, stdinfilename);
	pids.put(""+pid,this);*/
	Thread th = new Thread(this);
	th.setDaemon(true);
	th.start();
	/*try {
	while (!forked) {
		Thread.sleep(10);
	}
	} catch (InterruptedException e) {
	}*/
}

/**
 * Create and start an unix process specified by command.
 * Creation date: (8/21/2001 1:11:40 PM)
 * @param uid int The process will be start by the user specified by its uid
 * @param gid int The process will be start by the group specified by its gid
 * @param cmd java.lang.String The command
 */

public UnixProcess(int uid, int gid, String cmd) {
	this(uid, gid, cmd, null, null, null);
}

/**
 * Create and start an unix process specified by command.
 * Creation date: (8/21/2001 1:11:40 PM)
 * @param uid int The process will be start by the user specified by its uid
 * @param gid int The process will be start by the group specified by its gid
 * @param cmd java.lang.String The command
 * @param stdoutfilename java.lang.String The output filename for the process
 * @param stderrfilename java.lang.String The error filename for the process
 * @param stdinfilename java.lang.String The input filename for the process 
 */

public UnixProcess(
	int uid,
	int gid,
	String cmd,
	String stdoutfilename,
	String stderrfilename,
	String stdinfilename) {

	this.uid = uid;
	this.gid = gid;
	this.stdoutfilename = stdoutfilename;
	this.stderrfilename = stderrfilename;
	this.stdinfilename = stdinfilename;


	if (cmd != null) {
		int count = 0;
		StringTokenizer st = new StringTokenizer(cmd);
		count = st.countTokens();
		param = new String[count];
		st = new StringTokenizer(cmd);
		count = 0;
		while (st.hasMoreTokens()) {
			param[count++] = st.nextToken();
		}
	} else
		param = null;

	Thread th = new Thread(this);
	th.setDaemon(true);
	th.start();
	
	/*try {
	while (!forked) {
		Thread.sleep(10);
	}
	} catch (InterruptedException e) {
	}*/
}

/**
 * Create and start an unix process specified by command.
 * Creation date: (8/21/2001 1:11:40 PM)
 * @param uid int The process will be start by the user specified by its uid
 * @param cmd java.lang.String The command
 */

public UnixProcess(int uid, String cmd) {
	this(uid, -1, cmd);
}

/**
 * Create and start an unix process specified by command.
 * Creation date: (8/21/2001 1:11:40 PM)
 * @param uid int The process will be start by the user specified by its uid
 * @param cmd java.lang.String The command
 * @param stdoutfilename java.lang.String The output filename for the process
 * @param stderrfilename java.lang.String The error filename for the process
 * @param stdinfilename java.lang.String The input filename for the process 
 */

public UnixProcess(
	int uid,
	String cmd,
	String stdoutfilename,
	String stderrfilename,
	String stdinfilename) {
	    
	this(uid, -1, cmd, stdoutfilename, stderrfilename, stdinfilename);
}

/**
 * Create and start an unix process specified by command.
 * Creation date: (8/21/2001 1:11:40 PM)
 * @param cmd java.lang.String The command
 */

public UnixProcess(String cmd) {
	this(-1, cmd);
}

/**
 * Create and start an unix process specified by command.
 * Creation date: (8/21/2001 1:11:40 PM)
 * @param cmd java.lang.String The command
 * @param stdoutfilename java.lang.String The output filename for the process
 * @param stderrfilename java.lang.String The error filename for the process
 * @param stdinfilename java.lang.String The input filename for the process 
 */

public UnixProcess(
	String cmd,
	String stdoutfilename,
	String stderrfilename,
	String stdinfilename) {
	this(-1, cmd, stdoutfilename, stderrfilename, stdinfilename);
}

/**
 * Starts unix process specified by command.
 * Creation date: (8/21/2001 1:11:40 PM)
 * @param uid int The process will be start by the user specified by its uid
 * @param gid int The process will be start by the group specified by its gid
 * @param cmd java.lang.String[] The command
 * @param stdoutfilename java.lang.String The output filename for the process
 * @param stderrfilename java.lang.String The error filename for the process
 * @param stdinfilename java.lang.String The input filename for the process 
 */

private native int exec(
	int uid,
	int gid,
	String[] cmd,
	String stdoutfilename,
	String stderrfilename,
	String stdinfilename);

	/*private static Hashtable pids = new Hashtable();

	static {
		Thread th = new Thread(new UnixProcess());
		th.setDaemon(true);
		th.start();
	}
*/
	// private boolean forked = false;
	private java.util.Vector listeners = new Vector();
	public static final int MAX_PROCESSES = 64;

/**
 * Insert the method's description here.
 * Creation date: (8/31/2001 2:17:32 PM)
 */
public UnixProcess() {
	super();	
}

/**
 * Insert the method's description here.
 * Creation date: (10/31/2001 7:19:36 PM)
 * @param listener com.Prominic.runtime.ProcessEventListener
 * @exception java.lang.IllegalThreadStateException The exception description.
 */
public void addProcessEventListener(ProcessEventListener listener) throws java.lang.IllegalThreadStateException {
	if (!running) throw new IllegalThreadStateException();
	listeners.addElement(listener);	
}

/**
 * Insert the method's description here.
 * Creation date: (10/31/2001 7:21:03 PM)
 * @param event com.Prominic.runtime.ProcessEvent
 */
protected synchronized void dispatch(ProcessEvent event) {
	Enumeration listeners = this.listeners.elements();
	for(;listeners.hasMoreElements();)
		((ProcessEventListener)listeners.nextElement()).handleProcessEvent(event);
}

/**
 * Insert the method's description here.
 * Creation date: (8/28/2001 1:15:07 PM)
 * @exception java.lang.Throwable The exception description.
 */
public void finalize() throws java.lang.Throwable {
//	destroy();
//	listeners = null;
}

/**
 * Insert the method's description here.
 * Creation date: (10/31/2001 7:19:09 PM)
 * @return java.util.Vector
 */
protected java.util.Vector getListeners() {
	return listeners;
}

/**
 * Insert the method's description here.
 * Creation date: (8/31/2001 1:40:00 PM)
 * @return int
 */
protected int getPid() {
	return this.pid;
}

/**
 * Insert the method's description here.
 * Creation date: (8/29/2001 2:42:35 PM)
 * @param status int
 */
private void processDied(int status) {
	synchronized(this) {
		exitCode = status;
		running = false;
		//pids.remove(""+pid);
		UnixRuntime.decrementRunningProcesses();
		dispatch(new ProcessEvent(this,ProcessEvent.KILL));
		notifyAll();
	}	
}

/**
 * Insert the method's description here.
 * Creation date: (8/29/2001 2:42:35 PM)
 * @param status int
 */
private static void processDied(int pid, int status) {
	/*Enumeration keys = pids.keys();
	for(;keys.hasMoreElements();) {
		String i = (String)keys.nextElement();
		if (i.equals(""+pid))
			((UnixProcess)pids.get(i)).processDied(status);
	}*/
}

/**
 * Insert the method's description here.
 * Creation date: (10/31/2001 7:20:23 PM)
 * @param listener com.Prominic.runtime.ProcessEventListener
 */
public void removeProcessEventListener(ProcessEventListener listener) {
	if (listeners == null) return;
	listeners.removeElement(listener);	
}

/**
 * Insert the method's description here.
 * Creation date: (10/31/2001 7:19:09 PM)
 * @param newListeners java.util.Vector
 */
protected void setListeners(java.util.Vector newListeners) {
	listeners = newListeners;
}

/**
 * Insert the method's description here.
 * Creation date: (8/31/2001 12:49:27 PM)
 * @exception java.lang.InterruptedException The exception description.
 */
public void waitFor() throws java.lang.InterruptedException {
	synchronized (this) {
		while(isRunning())
			wait();
	}
}
}