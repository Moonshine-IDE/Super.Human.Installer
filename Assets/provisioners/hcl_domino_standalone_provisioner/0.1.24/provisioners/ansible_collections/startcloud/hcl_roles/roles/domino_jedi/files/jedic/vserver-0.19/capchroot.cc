/*
	This chroot command does very little. Once the chroot
	system call is executed, it (option) remove the CAP_SYS_CHROOT
	capability. Then it executes its argument
*/
#include <stdio.h>
#include <string.h>
#include <pwd.h>
#include <errno.h>
#include <unistd.h>
#include "vutil.h"
#include <linux/capability.h>

int main (int argc, char *argv[])
{
	if (argc < 3){
		fprintf (stderr,"capchroot version %s\n",VERSION);
		fprintf (stderr
			,"capchroot --nochroot directory [ --suid user ] command argument\n"
			 "\n"
			 "--nochroot remove the CAP_SYS_CHROOT capability\n"
			 "           after the chroot system call.\n"
			 "--suid switch to a different user (in the vserver context)\n"
			 "       before executing the command.\n");
	}else{
		const char *uid = NULL;
		bool nochroot = false;
		int dir;
		for (dir=1; dir<argc; dir++){
			const char *arg = argv[dir];
			if (arg[0] != '-' && arg[1] != '-'){
				break;
			}else if (strcmp(arg,"--nochroot")==0){
				nochroot = true;
			}else if (strcmp(arg,"--suid")==0){
				dir++;
				uid = argv[dir];
			}
			
		}
		if (chroot (argv[dir]) == -1){
			fprintf (stderr,"Can't chroot to directory %s (%s)\n",argv[dir]
				,strerror(errno));
		}else{
			if (nochroot){
				call_new_s_context (-2,1<<CAP_SYS_CHROOT,0);
			}

			if (uid != NULL) {
				struct passwd *p = getpwnam(uid);
				if  (p == NULL) {
					fprintf (stderr,"User not found %s (%s)\n",uid
						,strerror(errno));
					exit (-1);
				}else{
					setuid(p->pw_uid);
					argv[dir-1]="/bin/sh";
					argv[dir]="-c";
					dir-=2;
				}
			}
			int cmd = dir + 1;
			execvp (argv[cmd],argv+cmd);
			fprintf (stderr,"Can't execute %s (%s)\n",argv[cmd]
				,strerror(errno));
		}
	}
	return -1;
}


