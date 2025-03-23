package com.Prominic.runtime;

import java.util.*;
import java.io.*;

/**
 * Insert the type's description here.
 * Creation date: (8/17/2001 3:43:28 PM)
 * @author: Administrator
 */
public class DefaultUnixProcess implements NProcess {
	private UnixProcess process;

	private boolean running = true;
/**
 * DefaultUnixProcess constructor comment.
 */
public DefaultUnixProcess() {
	this(null);
}
/**
 * DefaultUnixProcess constructor comment.
 */
public DefaultUnixProcess(UnixProcess process) {
	super();
	this.process = process;
}
/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 3:43:28 PM)
 * @param listener com.Prominic.jdi.spawning.ProcessEventListener
 */
public void addProcessEventListener(ProcessEventListener listener) throws IllegalThreadStateException {
	process.addProcessEventListener(listener);	
}
/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:53:33 PM)
 */
public void destroy() {
	process.destroy();	
}

/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 3:43:28 PM)
 * @return int
 * @exception java.io.IOException The exception description.
 */
public int exitValue() throws
		IllegalThreadStateException,
		InterruptedException,
		java.io.IOException,
		java.io.FileNotFoundException,
		SecurityException,
		UnixRuntimeException {
	return process.exitValue();
}
/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 3:43:28 PM)
 * @return java.io.InputStream
 * @exception java.io.IOException The exception description.
 */
public java.io.InputStream getErrorStream() throws java.io.IOException {
	//throw new java.io.IOException("Feature not implemented");
	if (stderr != null) return stderr;
	if (process.getStderrFilename() != null) {
		stderr = new FileInputStream(process.getStderrFilename());
		return stderr;
	}
	else
	throw new FileNotFoundException("error stream not available");
}
/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 3:43:28 PM)
 * @return java.io.InputStream
 * @exception java.io.IOException The exception description.
 */
public java.io.InputStream getInputStream() throws java.io.IOException {
	//throw new java.io.IOException("Feature not implemented");
	if (stdout != null) return stdout;
	if (process.getStdoutFilename() != null) {
		stdout = new FileInputStream(process.getStdoutFilename());
		return stdout;
	}
	else
	throw new FileNotFoundException("input stream not available");
	
}

/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 3:43:28 PM)
 * @return java.io.OutputStream
 * @exception java.io.IOException The exception description.
 */
public java.io.OutputStream getOutputStream() throws java.io.IOException {
	//throw new java.io.IOException("Feature not implemented");
	if (stdin != null) return stdin;
	if (process.getStdinFilename() != null) {
		stdin = new FileOutputStream(process.getStdinFilename());
		return stdin;
	}
	else
	throw new FileNotFoundException("output stream not available");
}
/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:57:35 PM)
 * @return int
 * @exception java.lang.IllegalThreadStateException The exception description.
 */
public int getPid() throws java.lang.IllegalThreadStateException {
	return process.getPid();
}
/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 5:00:26 PM)
 * @return com.Prominic.runtime.UnixProcess
 */
protected UnixProcess getProcess() {
	return process;
}
/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 3:43:28 PM)
 * @return boolean
 */
public boolean isRunning() {
	return process.isRunning();
}
/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 3:43:28 PM)
 * @param listener com.Prominic.jdi.spawning.ProcessEventListener
 */
public void removeProcessEventListener(ProcessEventListener listener) {
	process.removeProcessEventListener(listener);
}


/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 5:00:26 PM)
 * @param newProcess com.Prominic.runtime.UnixProcess
 */
protected void setProcess(UnixProcess newProcess) {
	process = newProcess;
}
/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 3:43:28 PM)
 * @param signal int
 * @exception java.io.IOException The exception description.
 */
public void signal(int signal) throws java.io.IOException {}
/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 3:43:28 PM)
 * @param time int
 * @exception java.lang.InterruptedException The exception description.
 */
public void waitFor() throws InterruptedException {
	/*synchronized (this) {
		while(isRunning())
		wait();
	}*/
	process.waitFor();
}
/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 3:43:28 PM)
 * @param time int
 * @exception java.lang.InterruptedException The exception description.
 */
public void waitFor(long time) throws InterruptedException {
	long now = System.currentTimeMillis();
//	synchronized (this) {
		while (System.currentTimeMillis() - now < time && isRunning())
		Thread.sleep(100);
//		wait(time + now - System.currentTimeMillis());
//	}
}

	private InputStream stderr;
	private OutputStream stdin;
	private InputStream stdout;

/**
 * Insert the method's description here.
 * Creation date: (8/28/2001 1:13:07 PM)
 * @exception java.lang.Throwable The exception description.
 */
public void finalize() throws java.lang.Throwable {
	process.finalize();
	if (stdin != null) stdin.close();
	if (stdout != null) stdout.close();
	if (stderr != null) stderr.close();
	/*(new File(process.getStdoutFilename())).delete();
	(new File(process.getStderrFilename())).delete();
	(new File(process.getStdinFilename())).delete();*/
}
}