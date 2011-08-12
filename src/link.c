
// Copyright (c) 1999-2011 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.


#include        <stdio.h>
#include        <ctype.h>
#include        <assert.h>
#include        <stdarg.h>
#include        <string.h>
#include        <stdlib.h>

#if _WIN32
#include        <process.h>
#endif

#if linux || __APPLE__ || __FreeBSD__ || __OpenBSD__ || __sun&&__SVR4
#include        <sys/types.h>
#include        <sys/wait.h>
#include        <unistd.h>
#endif

#if linux || __APPLE__
    #define HAS_POSIX_SPAWN 1
    #include        <spawn.h>
    #if __APPLE__
        #include <crt_externs.h>
        #define environ (*(_NSGetEnviron()))
    #endif
#else
    #define HAS_POSIX_SPAWN 0
#endif

#include        "root.h"

#include        "mars.h"

#include        "rmem.h"

#include        "arraytypes.h"

int executecmd(char *cmd, char *args, int useenv);
int executearg0(char *cmd, char *args);

/****************************************
 * Write filename to cmdbuf, quoting if necessary.
 */

void writeFilename(OutBuffer *buf, char *filename, size_t len)
{
    /* Loop and see if we need to quote
     */
    for (size_t i = 0; i < len; i++)
    {   char c = filename[i];

        if (isalnum((unsigned char)c) || c == '_')
            continue;

        /* Need to quote
         */
        buf->writeByte('"');
        buf->write(filename, len);
        buf->writeByte('"');
        return;
    }

    /* No quoting necessary
     */
    buf->write(filename, len);
}

void writeFilename(OutBuffer *buf, char *filename)
{
    writeFilename(buf, filename, strlen(filename));
}

/*****************************
 * Run the linker.  Return status of execution.
 */

int runLINK()
{
#if _WIN32
    char *p;
    int status;
    OutBuffer cmdbuf;

    global.params.libfiles->push("user32");
    global.params.libfiles->push("kernel32");

    for (size_t i = 0; i < global.params.objfiles->dim; i++)
    {
        if (i)
            cmdbuf.writeByte('+');
        p = global.params.objfiles->tdata()[i];
        char *basename = FileName::removeExt(FileName::name(p));
        char *ext = FileName::ext(p);
        if (ext && !strchr(basename, '.'))
            // Write name sans extension (but not if a double extension)
            writeFilename(&cmdbuf, p, ext - p - 1);
        else
            writeFilename(&cmdbuf, p);
        mem.free(basename);
    }
    cmdbuf.writeByte(',');
    if (global.params.exefile)
        writeFilename(&cmdbuf, global.params.exefile);
    else
    {   /* Generate exe file name from first obj name.
         * No need to add it to cmdbuf because the linker will default to it.
         */
        char *n = global.params.objfiles->tdata()[0];
        n = FileName::name(n);
        FileName *fn = FileName::forceExt(n, "exe");
        global.params.exefile = fn->toChars();
    }

    // Make sure path to exe file exists
    {   char *p = FileName::path(global.params.exefile);
        FileName::ensurePathExists(p);
        mem.free(p);
    }

    cmdbuf.writeByte(',');
    if (global.params.mapfile)
        writeFilename(&cmdbuf, global.params.mapfile);
    else if (global.params.map)
    {
        FileName *fn = FileName::forceExt(global.params.exefile, "map");

        char *path = FileName::path(global.params.exefile);
        char *p;
        if (path[0] == '\0')
            p = FileName::combine(global.params.objdir, fn->toChars());
        else
            p = fn->toChars();

        writeFilename(&cmdbuf, p);
    }
    else
        cmdbuf.writestring("nul");
    cmdbuf.writeByte(',');

    for (size_t i = 0; i < global.params.libfiles->dim; i++)
    {
        if (i)
            cmdbuf.writeByte('+');
        writeFilename(&cmdbuf, global.params.libfiles->tdata()[i]);
    }

    if (global.params.deffile)
    {
        cmdbuf.writeByte(',');
        writeFilename(&cmdbuf, global.params.deffile);
    }

    /* Eliminate unnecessary trailing commas    */
    while (1)
    {   size_t i = cmdbuf.offset;
        if (!i || cmdbuf.data[i - 1] != ',')
            break;
        cmdbuf.offset--;
    }

    if (global.params.resfile)
    {
        cmdbuf.writestring("/RC:");
        writeFilename(&cmdbuf, global.params.resfile);
    }

    if (global.params.map || global.params.mapfile)
        cmdbuf.writestring("/m");

#if 0
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
    for (size_t i = 0; i < global.params.linkswitches->dim; i++)
    {
        cmdbuf.writestring(global.params.linkswitches->tdata()[i]);
    }
    cmdbuf.writeByte(';');

    p = cmdbuf.toChars();

    FileName *lnkfilename = NULL;
    size_t plen = strlen(p);
    if (plen > 7000)
    {
        lnkfilename = FileName::forceExt(global.params.exefile, "lnk");
        File flnk(lnkfilename);
        flnk.setbuffer(p, plen);
        flnk.ref = 1;
        if (flnk.write())
            error("error writing file %s", lnkfilename);
        if (lnkfilename->len() < plen)
            sprintf(p, "@%s", lnkfilename->toChars());
    }

    char *linkcmd = getenv("LINKCMD");
    if (!linkcmd)
        linkcmd = "link";
    status = executecmd(linkcmd, p, 1);
    if (lnkfilename)
    {
        remove(lnkfilename->toChars());
        delete lnkfilename;
    }
    return status;
#elif linux || __APPLE__ || __FreeBSD__ || __OpenBSD__ || __sun&&__SVR4
    pid_t childpid;
    int i;
    int status;

    // Build argv[]
    Strings argv;

    const char *cc = getenv("CC");
    if (!cc)
        cc = "gcc";
    argv.push((char *)cc);
    argv.insert(1, global.params.objfiles);

#if __APPLE__
    // If we are on Mac OS X and linking a dynamic library,
    // add the "-dynamiclib" flag
    if (global.params.dll)
        argv.push((char *) "-dynamiclib");
#endif

    // None of that a.out stuff. Use explicit exe file name, or
    // generate one from name of first source file.
    argv.push((char *)"-o");
    if (global.params.exefile)
    {
        if (global.params.dll)
            global.params.exefile = FileName::forceExt(global.params.exefile, global.dll_ext)->toChars();
        argv.push(global.params.exefile);
    }
    else
    {   // Generate exe file name from first obj name
        char *n = global.params.objfiles->tdata()[0];
        char *e;
        char *ex;

        n = FileName::name(n);
        e = FileName::ext(n);
        if (e)
        {
            e--;                        // back up over '.'
            ex = (char *)mem.malloc(e - n + 1);
            memcpy(ex, n, e - n);
            ex[e - n] = 0;
            // If generating dll then force dll extension
            if (global.params.dll)
                ex = FileName::forceExt(ex, global.dll_ext)->toChars();
        }
        else
            ex = (char *)"a.out";       // no extension, so give up
        argv.push(ex);
        global.params.exefile = ex;
    }

    // Make sure path to exe file exists
    {   char *p = FileName::path(global.params.exefile);
        FileName::ensurePathExists(p);
        mem.free(p);
    }

    if (global.params.symdebug)
        argv.push((char *)"-g");

    if (global.params.is64bit)
        argv.push((char *)"-m64");
    else
        argv.push((char *)"-m32");

    if (global.params.map || global.params.mapfile)
    {
        argv.push((char *)"-Xlinker");
#if __APPLE__
        argv.push((char *)"-map");
#else
        argv.push((char *)"-Map");
#endif
        if (!global.params.mapfile)
        {
            FileName *fn = FileName::forceExt(global.params.exefile, "map");

            char *path = FileName::path(global.params.exefile);
            char *p;
            if (path[0] == '\0')
                p = FileName::combine(global.params.objdir, fn->toChars());
            else
                p = fn->toChars();

            global.params.mapfile = p;
        }
        argv.push((char *)"-Xlinker");
        argv.push(global.params.mapfile);
    }

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
         * because EH sections are "unreferenced" and elided
         */
        argv.push((char *)"-Xlinker");
        argv.push((char *)"--gc-sections");
    }

    for (size_t i = 0; i < global.params.linkswitches->dim; i++)
    {   char *p = global.params.linkswitches->tdata()[i];
        if (!p || !p[0] || !(p[0] == '-' && p[1] == 'l'))
            // Don't need -Xlinker if switch starts with -l
            argv.push((char *)"-Xlinker");
        argv.push(p);
    }

    /* Add each library, prefixing it with "-l".
     * The order of libraries passed is:
     *  1. any libraries passed with -L command line switch
     *  2. libraries specified on the command line
     *  3. libraries specified by pragma(lib), which were appended
     *     to global.params.libfiles.
     *  4. standard libraries.
     */
    for (size_t i = 0; i < global.params.libfiles->dim; i++)
    {   char *p = global.params.libfiles->tdata()[i];
        size_t plen = strlen(p);
        if (plen > 2 && p[plen - 2] == '.' && p[plen -1] == 'a')
            argv.push(p);
        else
        {
            char *s = (char *)mem.malloc(plen + 3);
            s[0] = '-';
            s[1] = 'l';
            memcpy(s + 2, p, plen + 1);
            argv.push(s);
        }
    }

    /* Standard libraries must go after user specified libraries
     * passed with -l.
     */
    const char *libname = (global.params.symdebug)
                                ? global.params.debuglibname
                                : global.params.defaultlibname;
    char *buf = (char *)malloc(2 + strlen(libname) + 1);
    strcpy(buf, "-l");
    strcpy(buf + 2, libname);
    argv.push(buf);             // turns into /usr/lib/libphobos2.a

//    argv.push((void *)"-ldruntime");
    argv.push((char *)"-lpthread");
    argv.push((char *)"-lm");

    if (!global.params.quiet || global.params.verbose)
    {
        // Print it
        for (size_t i = 0; i < argv.dim; i++)
            printf("%s ", argv.tdata()[i]);
        printf("\n");
        fflush(stdout);
    }

    argv.push(NULL);
#if HAS_POSIX_SPAWN
    int spawn_err = posix_spawnp(&childpid, argv.tdata()[0], NULL, NULL, argv.tdata(), environ);
    if (spawn_err != 0)
    {
        perror(argv.tdata()[0]);
        return -1;
    }
#else
    childpid = fork();
    if (childpid == 0)
    {
        execvp(argv.tdata()[0], argv.tdata());
        perror(argv.tdata()[0]);           // failed to execute
        return -1;
    }
    else if (childpid == -1)
    {
        perror("Unable to fork");
        return -1;
    }
#endif

    waitpid(childpid, &status, 0);

    if (WIFEXITED(status))
    {
        status = WEXITSTATUS(status);
        if (status)
            printf("--- errorlevel %d\n", status);
    }
    else if (WIFSIGNALED(status))
    {
        printf("--- killed by signal %d\n", WTERMSIG(status));
        status = 1;
    }
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
 *      cmd     program to run
 *      args    arguments to cmd, as a string
 *      useenv  if cmd knows about _CMDLINE environment variable
 */

#if _WIN32
int executecmd(char *cmd, char *args, int useenv)
{
    int status;
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
        {   case 0:     goto L1;
            case 2: envname[0] = '%';   break;
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
//      printf("\n");
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
 *      -1      did not find command there
 *      !=-1    exit status from command
 */

#if _WIN32
int executearg0(char *cmd, char *args)
{
    const char *file;
    char *argv0 = global.params.argv0;

    //printf("argv0='%s', cmd='%s', args='%s'\n",argv0,cmd,args);

    // If cmd is fully qualified, we don't do this
    if (FileName::absolute(cmd))
        return -1;

    file = FileName::replaceName(argv0, cmd);

    //printf("spawning '%s'\n",file);
#if _WIN32
    return spawnl(0,file,file,args,NULL);
#elif linux || __APPLE__ || __FreeBSD__ || __OpenBSD__ || __sun&&__SVR4
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
    Strings argv;

    argv.push(global.params.exefile);
    for (size_t i = 0; i < global.params.runargs_length; i++)
    {   char *a = global.params.runargs[i];

#if _WIN32
        // BUG: what about " appearing in the string?
        if (strchr(a, ' '))
        {   char *b = (char *)mem.malloc(3 + strlen(a));
            sprintf(b, "\"%s\"", a);
            a = b;
        }
#endif
        argv.push(a);
    }
    argv.push(NULL);

#if _WIN32
    char *ex = FileName::name(global.params.exefile);
    if (ex == global.params.exefile)
        ex = FileName::combine(".", ex);
    else
        ex = global.params.exefile;
    return spawnv(0,ex,argv.tdata());
#elif linux || __APPLE__ || __FreeBSD__ || __OpenBSD__ || __sun&&__SVR4
    pid_t childpid;
    int status;

    childpid = fork();
    if (childpid == 0)
    {
        char *fn = argv.tdata()[0];
        if (!FileName::absolute(fn))
        {   // Make it "./fn"
            fn = FileName::combine(".", fn);
        }
        execv(fn, argv.tdata());
        perror(fn);             // failed to execute
        return -1;
    }

    waitpid(childpid, &status, 0);

    if (WIFEXITED(status))
    {
        status = WEXITSTATUS(status);
        //printf("--- errorlevel %d\n", status);
    }
    else if (WIFSIGNALED(status))
    {
        printf("--- killed by signal %d\n", WTERMSIG(status));
        status = 1;
    }
    return status;
#else
    assert(0);
#endif
}
