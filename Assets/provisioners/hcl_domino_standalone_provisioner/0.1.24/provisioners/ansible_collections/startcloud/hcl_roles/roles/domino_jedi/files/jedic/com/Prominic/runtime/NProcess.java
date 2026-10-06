package com.Prominic.runtime;

import java.io.*;

/**
 * Insert the type's description here.
 * Creation date: (8/13/2001 2:42:30 PM)
 * @author: Administrator
 */
public interface NProcess {
/**
 * Insert the method's description here.
 * Creation date: (8/13/2001 2:49:00 PM)
 * @param listener com.Prominic.jdi.spawning.ProcessEventListener
 */
void addProcessEventListener(ProcessEventListener listener);
/**
 * Insert the method's description here.
 * Creation date: (8/13/2001 2:45:51 PM)
 * @param signal int
 * @exception java.io.IOException The exception description.
 */
void destroy();
/**
 * Insert the method's description here.
 * Creation date: (8/13/2001 2:43:08 PM)
 * @return int
 * @exception java.io.IOException The exception description.
 */
int exitValue() throws IllegalThreadStateException,
		InterruptedException,
		java.io.IOException,
		java.io.FileNotFoundException,
		SecurityException,
		UnixRuntimeException;
/**
 * Insert the method's description here.
 * Creation date: (8/13/2001 2:44:27 PM)
 * @return java.io.InputStream
 * @exception java.io.IOException The exception description.
 */
InputStream getErrorStream() throws java.io.IOException;
/**
 * Insert the method's description here.
 * Creation date: (8/13/2001 2:43:44 PM)
 * @return java.io.InputStream
 * @exception java.io.IOException The exception description.
 */
InputStream getInputStream() throws IOException;
/**
 * Insert the method's description here.
 * Creation date: (8/13/2001 2:44:54 PM)
 * @return java.io.OutputStream
 * @exception java.io.IOException The exception description.
 */
OutputStream getOutputStream() throws java.io.IOException;
/**
 * Insert the method's description here.
 * Creation date: (8/17/2001 4:57:15 PM)
 * @return int
 * @exception java.lang.IllegalThreadStateException The exception description.
 */
int getPid() throws java.lang.IllegalThreadStateException;
/**
 * Insert the method's description here.
 * Creation date: (8/14/2001 2:51:39 PM)
 * @return boolean
 */
boolean isRunning();
/**
 * Insert the method's description here.
 * Creation date: (8/13/2001 2:49:00 PM)
 * @param listener com.Prominic.jdi.spawning.ProcessEventListener
 */
void removeProcessEventListener(ProcessEventListener listener);
/**
 * Insert the method's description here.
 * Creation date: (8/13/2001 2:45:51 PM)
 * @param signal int
 * @exception java.io.IOException The exception description.
 */
void signal(int signal) throws java.io.IOException;
/**
 * Insert the method's description here.
 * Creation date: (8/15/2001 11:40:14 AM)
 * @param time int
 * @exception java.lang.InterruptedException The exception description.
 */
void waitFor() throws java.lang.InterruptedException;
/**
 * Insert the method's description here.
 * Creation date: (8/15/2001 11:40:14 AM)
 * @param time int
 * @exception java.lang.InterruptedException The exception description.
 */
void waitFor(long time) throws java.lang.InterruptedException;
}