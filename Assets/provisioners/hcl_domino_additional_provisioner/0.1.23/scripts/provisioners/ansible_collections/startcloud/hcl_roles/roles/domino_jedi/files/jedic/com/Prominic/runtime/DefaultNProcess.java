package com.Prominic.runtime;

import java.util.*;

/**
 * java.lang.Process wrapper
 * Creation date: (8/14/2001 10:45:55 AM)
 * @author: Viorel B STAN (viorel@prominic.com)
 */
public class DefaultNProcess extends Thread implements NProcess  {
	//running process
	private java.lang.Process process;
	//event listeners
	private java.util.Vector listeners;
	private boolean running = true;
/**
 * Create a new DefaultNProcess object.
 */
public DefaultNProcess() {
	this(null);
}
/**
 * Create a new DefaultJProcess wrapper object around the specified process.
 * @param process java.lang.Process;
 */
public DefaultNProcess(Process process) {
	super();
	setProcess(process);
	listeners = new Vector();
	setDaemon(true);
	setPriority(Thread.MIN_PRIORITY);
	start();
}
/**
 * Add a new ProcessEventListener to this process.
 * Creation date: (8/14/2001 10:45:55 AM)
 * @param listener com.Prominic.jdi.spawning.ProcessEventListener
 */
public synchronized void addProcessEventListener(ProcessEventListener listener) throws IllegalThreadStateException{
	if (listeners == null) throw new IllegalThreadStateException();
	listeners.addElement(listener);
}
/**
 * Kill the spawned process.
 * Creation date: (8/17/2001 4:54:03 PM)
 */
public void destroy() {
	if (process != null) getProcess().destroy();
}
/**
 * Dispatch the specified process event to all listeners.
 * Creation date: (8/14/2001 10:51:14 AM)
 * @param event com.Prominic.jdi.spawning.ProcessEvent
 */
protected synchronized void dispatch(ProcessEvent event) {
	Enumeration listeners = this.listeners.elements();
	for(;listeners.hasMoreElements();)
		((ProcessEventListener)listeners.nextElement()).handleProcessEvent(event);
}
/**
 * Return the process exit value.
 * Creation date: (8/14/2001 10:45:55 AM)
 * @return int
 * @exception java.io.IOException.
 */
public int exitValue() throws IllegalThreadStateException {
	return getProcess().exitValue();
}
/**
 * Return a stream to the stderr of the spawned process.
 * Creation date: (8/14/2001 10:45:55 AM)
 * @return java.io.InputStream
 * @exception java.io.IOException.
 */
public java.io.InputStream getErrorStream() throws java.io.IOException {
	return getProcess().getErrorStream();
}
/**
 * Return a reference to the stdout of the spawned process.
 * Creation date: (8/14/2001 10:45:55 AM)
 * @return java.io.InputStream
 * @exception java.io.IOException
 */
public java.io.InputStream getInputStream() throws java.io.IOException {
	return getProcess().getInputStream();
}
/**
 * Return the list of listeners of this process.
 * Creation date: (8/14/2001 10:49:55 AM)
 * @return java.util.Vector
 */
protected java.util.Vector getListeners() {
	return listeners;
}
/**
 * Return a reference to process' stdin stream.
 * Creation date: (8/14/2001 10:45:55 AM)
 * @return java.io.OutputStream
 * @exception java.io.IOException
 */
public java.io.OutputStream getOutputStream() throws java.io.IOException {
	return getProcess().getOutputStream();
}
/**
 * Return the pid of the spawned process.
 * Creation date: (8/17/2001 4:57:55 PM)
 * @return int
 * @exception java.lang.IllegalThreadStateException If the process is still running.
 */
public int getPid() throws java.lang.IllegalThreadStateException {
	return 0;
}
/**
 * Returns the reference to the process object.
 * Creation date: (8/14/2001 10:48:29 AM)
 * @return java.lang.Process
 */
protected java.lang.Process getProcess() {
	return process;
}
/**
 * Returns true if this thread is still doing something.
 * Creation date: (8/14/2001 2:51:54 PM)
 * @return boolean
 */
public boolean isRunning() {
	return running;
}
/**
 * Removes the specified ProcessEventListener from the listeners
 * list associated to this process.
 * Creation date: (8/14/2001 10:45:55 AM)
 * @param listener com.Prominic.jdi.spawning.ProcessEventListener
 */
public synchronized void removeProcessEventListener(ProcessEventListener listener) {
	if (listeners == null) return;
	listeners.removeElement(listener);
}
/**
 * Waits for the process to finish.
 * Creation date: (8/14/2001 10:57:43 AM)
 */
public void run() {
	synchronized (this) {
	try {
		process.waitFor();
		running = false;
	} catch (InterruptedException e) {
		running = false;
		dispatch(new ProcessEvent(this,ProcessEvent.INTERRUPTED));
		notifyAll();
		return;
	}
	dispatch(new ProcessEvent(this,ProcessEvent.KILL));
	setListeners(null);
	notifyAll();
	return;
	}
}
/**
 * Set the vector of ProcessEventListeners.
 * Creation date: (8/14/2001 10:49:55 AM)
 * @param newListeners java.util.Vector
 */
protected void setListeners(java.util.Vector newListeners) {
	listeners = newListeners;
}
/**
 * 
 * Creation date: (8/14/2001 10:48:29 AM)
 * @param newProcess java.lang.Process
 */
protected void setProcess(java.lang.Process newProcess) {
	process = newProcess;
}
/**
 * Send a signal to the spawned process.
 * Creation date: (8/14/2001 10:45:55 AM)
 * @param signal int
 * @exception java.io.IOException
 */
public void signal(int signal) throws java.io.IOException {
	return;
}
/**
 * Wait for the spawned process to finish.
 * Creation date: (8/15/2001 11:40:46 AM)
 * @exception java.lang.InterruptedException If the thread is interrupted.
 */
public void waitFor() throws java.lang.InterruptedException {
	synchronized(this) {
		while (isRunning())
		wait();
	}
}
/**
 * Wait for this process to finish executing. If the specified time (milliseconds)
 * expires, this method returns anyway.
 * Creation date: (8/15/2001 11:40:46 AM)
 * @param time int
 * @exception java.lang.InterruptedException If the thread is interrupted.
 */
public void waitFor(long time) throws java.lang.InterruptedException {
	long now = System.currentTimeMillis();
//	synchronized (this) {
		while (System.currentTimeMillis() - now < time && isRunning())
		sleep(100);
		//wait(time + now - System.currentTimeMillis());
	//}
}
}