/*
 * Unix Runtime Library for Java.
 * (C) 2001 Prominic, Inc. and Prominic.RO SRL
 * All rights reserved.
 * Authors: Viorel B STAN (viorel@prominic.com) and
 *	    Valentin Gheorghita (vali@prominic.com)
 */


#include <sys/resource.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/ipc.h>
#include <sys/sem.h>
#include <signal.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <stdio.h>
#include <sys/wait.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include "UnixProcess.h"


/**
 * Convert the error message in a human readable form.
 */
/*
const char *getErrorMessage(int error)
{
        char *mesg = strerror(error);
        if (!mesg) mesg = "";
        return mesg;
}
*/
/**
 * Set the java enviroment exception if there is no exception.
 */
/*
void setException(JNIEnv *env, int errorCode)
{
        if (!(*env)->ExceptionOccurred(env)) {
                jclass exceptClass;
                switch(errorCode) {
                        case EACCES:
                        case ENOMEM:
                        case EFAULT:
                        case ESRCH:
                        case EROFS:
                        case EPERM:
                                exceptClass = (*env)->FindClass(env, "java/lang/SecurityException");
                                break;
                        case ENOTDIR:
                        case ENOENT:
                        case ENAMETOOLONG:
                                exceptClass = (*env)->FindClass(env, "java/io/FileNotFoundException");
                                break;
                        case E2BIG:
                                exceptClass = (*env)->FindClass(env, "java/lang/IllegalArgumentException");
                                break;
                        case ELOOP:
                        case EIO:
                        case ENOEXEC:
                        case ETXTBSY:
                        case ENFILE:
                        case EMFILE:
                        case EINVAL:
#ifndef AIX
                        case ELIBBAD:
#endif
                        case EISDIR:
                                exceptClass = (*env)->FindClass(env, "java/io/IOException");
                                break;
                        default:
                                exceptClass = (*env)->FindClass(env, "java/lang/Exception");
                }
		if (exceptClass != NULL) {
                (*env)->ThrowNew(env, exceptClass, getErrorMessage(errorCode));
		}
		(*env)->deleteLocalRef(env,exceptClass);
        }
}
*/
/**
 * Close all fds
 */

void close_fds(int n) {
	int i;
	for(i=3;i<n;i++) close(i);//fcntl(i,F_SETFD,FD_CLOEXEC);
}

int notifyWaitingThreads(JNIEnv *env, jobject object) {
  jclass class;
  jmethodID notify_method;

  //notify the waiting threads
  class = (*env)->GetObjectClass(env, object);
  
  if (class == NULL) {
    printf ("ERROR: Unable to get class reference for notify_method\n");
    return -1;
  }
  
  notify_method = (*env)->GetMethodID(env, class, "processDied", "(I)V");
  if (notify_method == NULL) {
    printf("ERROR: Unable to get notify_method reference.\n");
    return -1;
  }
  (*env)->CallVoidMethod(env, object, notify_method, 127);
  if ((*env)->ExceptionOccurred(env)) {
    (*env)->ExceptionDescribe(env);
    (*env)->ExceptionClear(env);
  }
  //end notification
  return 0;
}

/**
 * It stars a process and wait until it is running. It send exceptions in java
 * enviroment. 
 * (Only for library internal use)
 */
int execute(JNIEnv *env, const jobject object, char *name, char **argp, const char* stdoutfilename, const char* stderrfilename, const char* stdinfilename) 
{
                int pid,ppid;
		int max_fds = 1024;
#ifdef USESEMS
		int sem = 0;
		struct sembuf plus = {0,1,0};
		struct sembuf minus = {0,-1,0};
#endif

#ifdef SOLARIS
	        struct rlimit resources = {0};
        	getrlimit(RLIMIT_NOFILE,&resources);
		max_fds = resources.rlim_max;
#ifdef USESEMS
		semctl(sem,1,SETVAL,0);
#endif
		ppid = getpid();
                if ((pid=fork1())==0)
#elif defined(LINUX)
	        struct rlimit resources = {0};
        	getrlimit(RLIMIT_NOFILE,&resources);
		max_fds = resources.rlim_max;
#ifdef USESEMS
	       	if ((sem = semget(IPC_PRIVATE,1,00600|IPC_CREAT|IPC_EXCL)) < 0) {
		  notifyWaitingThreads(env,object);
		  return -1;
		}
#endif
		ppid = getpid();
		if ((pid=fork())==0)
#elif defined(AIX)
		ppid = getpid();
		if ((pid=fork())==0)
#else
		if ((pid=fork())==0)
#endif
				{
                                int nout = -1;
                                int nerr = -1;
                                int nin = -1;
#ifdef USESEMS
				if (sem > 0)
		      		if (semop(sem,&minus,1) < 0) _exit(1);
#endif
			      /* Set the handling for job control signals back to the default.  */
			       	signal (SIGINT, SIG_DFL);
				signal (SIGQUIT, SIG_DFL);
				signal (SIGTSTP, SIG_DFL);
				signal (SIGTTIN, SIG_DFL);
				signal (SIGTTOU, SIG_DFL);
				signal (SIGCHLD, SIG_DFL);

                                close(0);
				close(1);
				close(2);
				if (stdoutfilename != NULL) {
                                        nout = open(stdoutfilename, O_CREAT|O_WRONLY|O_TRUNC,00666);
                                        if (nout != -1) {
                                                dup2(nout,1);
                                        }
                                } else {
					nout = open("/dev/null",O_WRONLY);
					if (nout != -1)
						dup2(nout,1);
				}

                                if (stderrfilename != NULL) {
                                        nerr = open(stderrfilename, O_CREAT|O_WRONLY|O_TRUNC,00666);
                                        if (nerr != -1)
                                                dup2(nerr,2);
                                        
                                } else {
					nerr = open("/dev/null",O_WRONLY);
					if (nerr != -1)
						dup2(nerr,2);
				}

                                if (stdinfilename != NULL) {
                                        nin = open(stdinfilename, O_CREAT|O_RDONLY,00666);
                                        if (nin != -1) {
                                                dup2(nin,0);
                                        }
					}
				close_fds(max_fds);
				
#ifndef USESEMS
				//cheap way to delay child execution
	  			sleep(1);
#endif
				
                                execvp(name,argp);
                                _exit(1);
                } else if (pid!=-1) {
		        int status,fiu;
		      	jclass class;
			jmethodID notify_method;
#ifdef USESEMS
			if (sem > 0) semop(sem,&plus,1);
#endif
		      	for(;;) {
			  fiu = waitpid(pid,&status,WUNTRACED);
			  if ((fiu != pid) && (fiu != 0) && (fiu != -1)) continue;
			  break;
			}
                	//if (errno) perror("Wait: ");
			class = (*env)->GetObjectClass(env, object);
        		if (class == NULL) {
			  printf ("ERROR: Unable to get class reference for notify_method\n");
#ifdef USESEMS
			  if (sem > 0) semctl(sem,1,IPC_RMID);
#endif
			  return -1;
			}

			notify_method = (*env)->GetMethodID(env, class, "processDied", "(I)V");
			if (notify_method == NULL) {
			  printf("ERROR: Unable to get notify_method reference.\n");
#ifdef USESEMS
		   	  if (sem > 0) semctl(sem,1,IPC_RMID);
#endif
			  return -1;
			}
			//        		for(;;) {
                	//fiu = waitpid(pid,&status,WUNTRACED);
                	//if ((fiu != pid) && (fiu != 0) && (fiu != -1)) continue;
      			if (!WIFEXITED(status)) {
			  perror("Unexpected");
			  (*env)->CallVoidMethod(env, object, notify_method, 255);
			} else {
			  (*env)->CallVoidMethod(env, object, notify_method, WEXITSTATUS(status));
			}
			//			(*env)->CallVoidMethod(env, object, notify_method, (status < 0) ? errno : WEXITSTATUS(status));

#ifdef USESEMS
			if (sem > 0) semctl(sem,1,IPC_RMID);
#endif
                         return pid;
			
                } else {
                        /*jclass cls = (*env)->GetObjectClass(env, obj);
                        jfieldID fid = (*env)->GetFieldID(env, cls, "canNotMakeFork", "Z");
                        (*env)->SetBooleanField(env, obj, fid,(jboolean)1 );      */
#ifdef USESEMS
			if (sem > 0) semctl(sem,1,IPC_RMID);
#endif
			notifyWaitingThreads(env,object);
                        return -1;
                }
#ifdef USESEMS
		if (sem > 0) semctl(sem,1,IPC_RMID);
#endif
		return -1;
}

/**
 * Starts a process using exec
 * @return process internal identifier
 */
JNIEXPORT jint JNICALL Java_com_Prominic_runtime_UnixProcess_exec
  (JNIEnv *env, jobject obj, jint uid , jint gid, jobjectArray cmd, 
        jstring stdoutfilename, jstring stderrfilename, jstring stdinfilename)
{
  jint ret,i;
                jsize len;    
                char **argp = NULL;
                const char *_stdoutfilename=NULL, *_stderrfilename=NULL, *_stdinfilename=NULL;

		if (env == NULL || obj == NULL) {
		  printf("FATAL ERROR: JVM WENT NUTS.\n\n");
		  return -1;
		}
                if (cmd == NULL) {
		jclass cls = (*env)->GetObjectClass(env, obj);
		  jfieldID fid = (*env)->GetFieldID(env, cls, "errorCode", "I");
		  (*env)->SetIntField(env, obj, fid, ENOENT);
		  fid = (*env)->GetFieldID(env, cls, "canNotExecute", "Z");
		  (*env)->SetBooleanField(env, obj, fid,JNI_TRUE);
		  return -1;
                }

		 len = (*env)->GetArrayLength(env, cmd);

                if (!len) {
                                jclass cls = (*env)->GetObjectClass(env, obj);
                                jfieldID fid = (*env)->GetFieldID(env, cls, "errorCode", "I");
                                (*env)->SetIntField(env, obj, fid, ENOENT);
                                fid = (*env)->GetFieldID(env, cls, "canNotExecute", "Z");
                                (*env)->SetBooleanField(env, obj, fid,JNI_TRUE );
				return -1;
                }               
		
		if (uid!=-1)
                                if (setuid(uid)==-1) {
				  jclass cls = (*env)->GetObjectClass(env, obj);
				  jfieldID fid = (*env)->GetFieldID(env, cls, "setUidError", "Z");
				  (*env)->SetBooleanField(env, obj, fid,JNI_TRUE );
				  return 1;
                                }
                if (gid!=-1)
                                if (setgid(gid)==-1) {
				  jclass cls = (*env)->GetObjectClass(env, obj);
				  jfieldID fid = (*env)->GetFieldID(env, cls, "setGidError", "Z");
				  (*env)->SetBooleanField(env, obj, fid,JNI_TRUE );
				  return 1;
                                }
		
		
                argp = (char **) malloc(sizeof(char *)*(len+1));
		if (argp == NULL) {
			printf("Out of memory!\n");
			return -1;
		}

                for(i=0;i<len;i++) {
		  jstring jstr = (*env)->GetObjectArrayElement(env,cmd,i);
		  if (jstr == NULL) {
		    printf("ERROR: NULL jstr while initializing argp!\n");
		    goto final;
		  }
		  argp[i] = (char*)(*env)->GetStringUTFChars(env, jstr, NULL);
		  (*env)->DeleteLocalRef(env,jstr);
		}
                argp[len]=0;

                if (stdoutfilename != NULL) {
                _stdoutfilename=(*env)->GetStringUTFChars(env, stdoutfilename, 0);
		}

		if (stderrfilename != NULL) {
                _stderrfilename=(*env)->GetStringUTFChars(env, stderrfilename, 0);
		}

                if (stdinfilename != NULL) {
                _stdinfilename=(*env)->GetStringUTFChars(env, stdinfilename, 0);
		}

		ret = execute(env,obj,argp[0],argp, _stdoutfilename, _stderrfilename, _stdinfilename);

                for(i=0;i<len;i++) {
		  jstring jstr = (*env)->GetObjectArrayElement(env,cmd,i);
		  if (jstr == NULL) {
		    printf("Null jstr while releasing argp resources.\n");
		    goto final;
		    }
		  (*env)->ReleaseStringUTFChars(env, jstr, argp[i]);
		  (*env)->DeleteLocalRef(env,jstr);
		  }
 final:
		if (argp != NULL)
		free(argp); argp = 0;
		
		 if (stdoutfilename != NULL && _stdoutfilename != NULL) (*env)->ReleaseStringUTFChars(env,stdoutfilename,_stdoutfilename);
                if (stdinfilename != NULL && _stdinfilename != NULL) (*env)->ReleaseStringUTFChars(env,stderrfilename,_stderrfilename);
                if (stderrfilename != NULL && _stderrfilename != NULL) (*env)->ReleaseStringUTFChars(env,stdinfilename,_stdinfilename);
                return ret;
}












































