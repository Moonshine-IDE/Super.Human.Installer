package com.Prominic.runtime;

/**
 * Insert the type's description here.
 * Creation date: (8/13/2001 2:47:24 PM)
 * @author: Administrator
 */
public class ProcessEvent extends java.util.EventObject {
	public final static int KILL = 9;
	public final static int INTERRUPTED = 100;
	private int id;
/**
 * ProcessEvent constructor comment.
 * @param source java.lang.Object
 */
public ProcessEvent(Object source) {
	super(source);
}
/**
 * ProcessEvent constructor comment.
 * @param source java.lang.Object
 */
public ProcessEvent(Object source, int id) {
	super(source);
	setId(id);
}
/**
 * Insert the method's description here.
 * Creation date: (8/13/2001 2:47:47 PM)
 * @return int
 */
public int getId() {
	return id;
}
/**
 * Insert the method's description here.
 * Creation date: (8/13/2001 2:47:47 PM)
 * @param newId int
 */
protected void setId(int newId) {
	id = newId;
}
}