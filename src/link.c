

// Copyright (c) 1999-2006 by Digital Mars
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

#if linux
#include	<sys/types.h>
#include	<sys/wait.h>
#include	<unistd.h>
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
#if _WIN32
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
    else
    {	// Generate exe file name from first obj name
	char *n = (char *)global.params.objfiles->data[0];
	char *ex;

	n = FileName::name(n);
	FileName *fn = FileName::forceExt(n, "exe");
	global.params.exefile = fn->toChars();
    }

    cmdbuf.writeByte(',');
    if (global.params.run)
	cmdbuf.writestring("nul");
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
#elif linux
    pid_t childpid;
    int i;
    int status;

    // Build argv[]
    Array argv;

    char *cc = getenv("CC");
    if (!cc)
	cc = "gcc";
    argv.push((void *)cc);
    argv.insert(1, global.params.objfiles);

    // None of that a.out stuff. Use explicit exe file name, or
    // generate one from name of first source file.
    argv.push((void *)"-o");
    if (global.params.exefile)
    {
	argv.push(global.params.exefile);
    }
    else
    {	// Generate exe file name from first obj name
	char *n = (char *)global.params.objfiles->data[0];
	char *e;
	char *ex;

	n = FileName::name(n);
	e = FileName::ext(n);
	if (e)
	{
	    e--;			// back up over '.'
	    ex = (char *)mem.malloc(e - n + 1);
	    memcpy(ex, n, e - n);
	    ex[e - n] = 0;
	}
	else
	    ex = (char *)"a.out";	// no extension, so give up
	argv.push(ex);
	global.params.exefile = ex;
    }

    argv.insert(argv.dim, global.params.libfiles);

    if (global.params.symdebug)
	argv.push((void *)"-g");

    argv.push((void *)"-m32");

    argv.push((void *)"-lphobos");	// turns into /usr/lib/libphobos.a
    argv.push((void *)"-lpthread");
    argv.push((void *)"-lm");

    if (0 && global.params.exefile)
    {
	/* This switch enables what is known as 'smart linking'
	 * in the Windows world, where unreferenced sections
	 * are removed from the executable. It eliminates unreferenced
	 * functions, essentially making a 'library' out of a module.
	 * Although it is documented to work with ld version 2.13,
	 * in practice it does not, but just seems to be ignored.
	 * Thomas Kuehne has verified that it works with ld 2.16.1.
	 * BUG: disabled because it causes exception handling to fail
	 */
	argv.push((void *)"-Xlinker");
	argv.push((void *)"--gc-sections");
    }

    for (i = 0; i < global.params.linkswitches->dim; i++)
    {
	argv.push((void *)"-Xlinker");
	argv.push((void *) global.params.linkswitches->data[i]);
    }

    if (!global.params.quiet)
    {
	// Print it
	for (i = 0; i < argv.dim; i++)
	    printf("%s ", (char *)argv.data[i]);
	printf("\n");
	fflush(stdout);
    }

    argv.push(NULL);
    childpid = fork();
    if (childpid == 0)
    {
	execvp((char *)argv.data[0], (char **)argv.data);
	perror((char *)argv.data[0]);		// failed to execute
	return -1;
    }

    waitpid(childpid, &status, 0);

    status=WEXITSTATUS(status);
    if (status)
	printf("--- errorlevel %d\n", status);
    return status;
#else
    printf ("Linking is not yet supported for this version of DMD.\n");
    return -1;
#endif
}

/**********************************
 * Delete generated EXE file.
 */

void deleteExeFile()
{
    if (global.params.exefile)
    {
	//printf("deleteExeFile() %s\n", global.params.exefile);
	remove(global.params.exefile);
    }
}

/******************************
 * Execute a rule.  Return the status.
 *	cmd	program to run
 *	args	arguments to cmd, as a string
 *	useenv	if cmd knows about _CMDLINE environment variable
 */

#if _WIN32
int executecmd(char *cmd, char *args, int useenv)
{
    int status;
    char *buff;
    size_t len;

    if (!global.params.quiet || global.params.verbose)
    {
	printf("%s %s\n", cmd, args);
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
//    if (global.params.verbose)
//	printf("\n");
    if (status)
    {
	if (status == -1)
	    printf("Can't run '%s', check PATH\n", cmd);
	else
	    printf("--- errorlevel %d\n", status);
    }
    return status;
}
#endif

/**************************************
 * Attempt to find command to execute by first looking in the directory
 * where DMD was run from.
 * Returns:
 *	-1	did not find command there
 *	!=-1	exit status from command
 */

#if _WIN32
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
#endif

/***************************************
 * Run the compiled program.
 * Return exit status.
 */

int runProgram()
{
    //printf("runProgram()\n");
    if (global.params.verbose)
    {
	printf("%s", global.params.exefile);
	for (size_t i = 0; i < global.params.runargs_length; i++)
	    printf(" %s", (char *)global.params.runargs[i]);
	printf("\n");
    }

    // Build argv[]
    Array argv;

    argv.push((void *)global.params.exefile);
    for (size_t i = 0; i < global.params.runargs_length; i++)
	argv.push((void *)global.params.runargs[i]);
    argv.push(NULL);

#if _WIN32
    char *ex = FileName::name(global.params.exefile);
    if (ex == global.params.exefile)
	ex = FileName::combine(".", ex);
    else
	ex = global.params.exefile;
    return spawnv(0,ex,(char **)argv.data);
#elif linux
    pid_t childpid;
    int status;

    childpid = fork();
    if (childpid == 0)
    {
	char *fn = (char *)argv.data[0];
	if (!FileName::absolute(fn))
	{   // Make it "./fn"
	    fn = FileName::combine(".", fn);
	}
	execv(fn, (char **)argv.data);
	perror(fn);		// failed to execute
	return -1;
    }

    waitpid(childpid, &status, 0);

    status = WEXITSTATUS(status);
    return status;
#else
    assert(0);
#endif
}
