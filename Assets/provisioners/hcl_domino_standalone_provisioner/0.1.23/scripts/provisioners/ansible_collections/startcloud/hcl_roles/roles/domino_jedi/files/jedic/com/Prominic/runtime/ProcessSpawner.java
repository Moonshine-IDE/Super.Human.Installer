package com.Prominic.runtime;

/**
 * Insert the type's description here.
 * Creation date: (8/13/2001 2:40:35 PM)
 * @author: Administrator
 */
public interface ProcessSpawner {
/**
 * Insert the method's description here.
 * Creation date: (8/13/2001 2:41:42 PM)
 * @param command java.lang.String[]
 * @exception java.io.IOException The exception description.
 */
NProcess exec(String[] command) throws java.io.IOException;
/**
 * Insert the method's description here.
 * Creation date: (8/13/2001 2:41:42 PM)
 * @param command java.lang.String[]
 * @exception java.io.IOException The exception description.
 */
NProcess exec(String command) throws java.io.IOException;
}