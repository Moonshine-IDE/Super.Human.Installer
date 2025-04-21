package com.Prominic.runtime;

/**
 * Insert the type's description here.
 * Creation date: (8/13/2001 2:46:58 PM)
 * @author: Administrator
 */
public interface ProcessEventListener {
/**
 * Insert the method's description here.
 * Creation date: (8/13/2001 2:48:27 PM)
 * @param event com.Prominic.jdi.spawning.ProcessEvent
 */
void handleProcessEvent(ProcessEvent event);
}