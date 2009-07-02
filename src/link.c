

// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.


#include	<stdio.h>
#include	<ctype.h>
#include	<assert.h>
#include	<stdarg.h>
#include	<string.h>
#include	<stdlib.h>

#if _WIN32
#include	<process.h>
#endif

#include	"root.h"

#include	"mars.h"

#if linux
#include	"mem.h"
#endif

int executecmd(char *cmd, char *args, int useenv);
int executearg0(char *cmd, char *args);

/*****************************
 * Run the linker.  Return status of execution.
 */

int runLINK()
{
#ifdef __DMC__
    char *p;
    int i;
    int status;
    OutBuffer cmdbuf;

    global.params.libfiles->push((void *) "user32");
    global.params.libfiles->push((void *) "kernel32");

    for (i = 0; i < global.params.objfiles->dim; i++)
    {
	if (i)
	    cmdbuf.writeByte('+');
	p = (char *)global.params.objfiles->data[i];
	char *ext = FileName::ext(p);
	if (ext)
	    cmdbuf.write(p, ext - p - 1);
	else
	    cmdbuf.writestring(p);
    }
    cmdbuf.writeByte(',');
    if (global.params.exefile)
	cmdbuf.writestring(global.params.exefile);

    cmdbuf.writeByte(',');
//    if (mapfile)
//	cmdbuf.writestring(output);
    cmdbuf.writeByte(',');

    for (i = 0; i < global.params.libfiles->dim; i++)
    {
	if (i)
	    cmdbuf.writeByte('+');
	cmdbuf.writestring((char *) global.params.libfiles->data[i]);
    }

    if (global.params.deffile)
    {
	cmdbuf.writeByte(',');
	cmdbuf.writestring(global.params.deffile);
    }

    /* Eliminate unnecessary trailing commas	*/
    while (1)
    {   i = cmdbuf.offset;
	if (!i || cmdbuf.data[i - 1] != ',')
	    break;
	cmdbuf.offset--;
    }

    if (global.params.resfile)
    {
	cmdbuf.writestring("/RC:");
	cmdbuf.writestring(global.params.resfile);
    }

#if 0
    if (mapfile)
	cmdbuf.writestring("/m");
    if (debuginfo)
	cmdbuf.writestring("/li");
    if (codeview)
    {
	cmdbuf.writestring("/co");
	if (codeview3)
	    cmdbuf.writestring(":3");
    }
#else
    if (global.params.symdebug)
	cmdbuf.writestring("/co");
#endif

    cmdbuf.writestring("/noi");
    for (i = 0; i < global.params.linkswitches->dim; i++)
    {
	cmdbuf.writestring((char *) global.params.linkswitches->data[i]);
    }
    cmdbuf.writeByte(';');

    p = cmdbuf.toChars();

    char *linkcmd = getenv("LINKCMD");
    if (!linkcmd)
	linkcmd = "link";
    status = executecmd(linkcmd, p, 1);
    return status;
#else
    printf ("Linker is not yet completed for this version of DMD Linux.\n");
    return -1;
#endif
}


/******************************
 * Execute a rule.  Return the status.
 *	cmd	program to run
 *	args	arguments to cmd, as a string
 *	useenv	if cmd knows about _CMDLINE environment variable
 */

int executecmd(char *cmd, char *args, int useenv)
{
    int status;
    char *buff;
    size_t len;

//    if (global.params.verbose)
    {
	printf("%s %s\n",cmd,args);
	fflush(stdout);
    }

    if ((len = strlen(args)) > 255)
    {   char *q;
	static char envname[] = "@_CMDLINE";

	envname[0] = '@';
	switch (useenv)
	{   case 0:	goto L1;
	    case 2: envname[0] = '%';	break;
	}
	q = (char *) alloca(sizeof(envname) + len + 1);
	sprintf(q,"%s=%s", envname + 1, args);
	status = putenv(q);
	if (status == 0)
	    args = envname;
	else
	{
	L1:
	    error("command line length of %d is too long",len);
	}
    }

    status = executearg0(cmd,args);
#if _WIN32
    if (status == -1)
	status = spawnlp(0,cmd,cmd,args,NULL);
#endif
    if (global.params.verbose)
	printf("\n");
    if (status)
    {
	if (status == -1)
	    printf("Can't run '%s', check PATH\n", cmd);
	else
	    printf("--- errorlevel %d\n", status);
    }
    return status;
}

/**************************************
 * Attempt to find command to execute by first looking in the directory
 * where DMD was run from.
 * Returns:
 *	-1	did not find command there
 *	!=-1	exit status from command
 */

int executearg0(char *cmd, char *args)
{
    char *file;
    char *argv0 = global.params.argv0;

    //printf("argv0='%s', cmd='%s', args='%s'\n",argv0,cmd,args);

    // If cmd is fully qualified, we don't do this
    if (FileName::absolute(cmd))
	return -1;

    file = FileName::replaceName(argv0, cmd);

    //printf("spawning '%s'\n",file);
#if _WIN32
    return spawnl(0,file,file,args,NULL);
#elif linux
    char *full;
    int cmdl = strlen(cmd);

    full = (char*) mem.malloc(cmdl + strlen(args) + 2);
    if (full == NULL)
	return 1;
    strcpy(full, cmd);
    full [cmdl] = ' ';
    strcpy(full + cmdl + 1, args);

    int result = system(full);

    mem.free(full);
    return result;
#else
    assert(0);
#endif
}


