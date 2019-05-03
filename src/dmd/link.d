/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2019 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/link.d, _link.d)
 * Documentation:  https://dlang.org/phobos/dmd_link.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/link.d
 */

module dmd.link;

import core.stdc.ctype;
import core.stdc.stdio;
import core.stdc.string;
import core.sys.posix.stdio;
import core.sys.posix.stdlib;
import core.sys.posix.unistd;
import core.sys.windows.winbase;
import core.sys.windows.windef;
import core.sys.windows.winreg;
import dmd.errors;
import dmd.globals;
import dmd.root.file;
import dmd.root.filename;
import dmd.root.outbuffer;
import dmd.root.rmem;
import dmd.utils;

version (Posix) extern (C) int pipe(int*);
version (Windows) extern (C) int putenv(const char*);
version (Windows) extern (C) int spawnlp(int, const char*, const char*, const char*, const char*);
version (Windows) extern (C) int spawnl(int, const char*, const char*, const char*, const char*);
version (Windows) extern (C) int spawnv(int, const char*, const char**);
version (CRuntime_Microsoft)
{
  // until the new windows bindings are available when building dmd.
  static if(!is(STARTUPINFOA))
  {
    alias STARTUPINFOA = STARTUPINFO;

    // dwCreationFlags for CreateProcess() and CreateProcessAsUser()
    enum : DWORD {
      DEBUG_PROCESS               = 0x00000001,
      DEBUG_ONLY_THIS_PROCESS     = 0x00000002,
      CREATE_SUSPENDED            = 0x00000004,
      DETACHED_PROCESS            = 0x00000008,
      CREATE_NEW_CONSOLE          = 0x00000010,
      NORMAL_PRIORITY_CLASS       = 0x00000020,
      IDLE_PRIORITY_CLASS         = 0x00000040,
      HIGH_PRIORITY_CLASS         = 0x00000080,
      REALTIME_PRIORITY_CLASS     = 0x00000100,
      CREATE_NEW_PROCESS_GROUP    = 0x00000200,
      CREATE_UNICODE_ENVIRONMENT  = 0x00000400,
      CREATE_SEPARATE_WOW_VDM     = 0x00000800,
      CREATE_SHARED_WOW_VDM       = 0x00001000,
      CREATE_FORCEDOS             = 0x00002000,
      BELOW_NORMAL_PRIORITY_CLASS = 0x00004000,
      ABOVE_NORMAL_PRIORITY_CLASS = 0x00008000,
      CREATE_BREAKAWAY_FROM_JOB   = 0x01000000,
      CREATE_WITH_USERPROFILE     = 0x02000000,
      CREATE_DEFAULT_ERROR_MODE   = 0x04000000,
      CREATE_NO_WINDOW            = 0x08000000,
      PROFILE_USER                = 0x10000000,
      PROFILE_KERNEL              = 0x20000000,
      PROFILE_SERVER              = 0x40000000
    }
  }
}

/****************************************
 * Write filename to cmdbuf, quoting if necessary.
 */
private void writeFilename(OutBuffer* buf, const(char)[] filename)
{
    /* Loop and see if we need to quote
     */
    foreach (const char c; filename)
    {
        if (isalnum(c) || c == '_')
            continue;
        /* Need to quote
         */
        buf.writeByte('"');
        buf.writestring(filename);
        buf.writeByte('"');
        return;
    }
    /* No quoting necessary
     */
    buf.writestring(filename);
}

private void writeFilename(OutBuffer* buf, const(char)* filename)
{
    writeFilename(buf, filename.toDString());
}

version (Posix)
{
    /*****************************
     * As it forwards the linker error message to stderr, checks for the presence
     * of an error indicating lack of a main function (NME_ERR_MSG).
     *
     * Returns:
     *      1 if there is a no main error
     *     -1 if there is an IO error
     *      0 otherwise
     */
    private int findNoMainError(int fd)
    {
        version (OSX)
        {
            static immutable(char*) nmeErrorMessage = "`__Dmain`, referenced from:";
        }
        else
        {
            static immutable(char*) nmeErrorMessage = "undefined reference to `_Dmain`";
        }
        FILE* stream = fdopen(fd, "r");
        if (stream is null)
            return -1;
        const(size_t) len = 64 * 1024 - 1;
        char[len + 1] buffer; // + '\0'
        size_t beg = 0, end = len;
        bool nmeFound = false;
        for (;;)
        {
            // read linker output
            const(size_t) n = fread(&buffer[beg], 1, len - beg, stream);
            if (beg + n < len && ferror(stream))
                return -1;
            buffer[(end = beg + n)] = '\0';
            // search error message, stop at last complete line
            const(char)* lastSep = strrchr(buffer.ptr, '\n');
            if (lastSep)
                buffer[(end = lastSep - &buffer[0])] = '\0';
            if (strstr(&buffer[0], nmeErrorMessage))
                nmeFound = true;
            if (lastSep)
                buffer[end++] = '\n';
            if (fwrite(&buffer[0], 1, end, stderr) < end)
                return -1;
            if (beg + n < len && feof(stream))
                break;
            // copy over truncated last line
            memcpy(&buffer[0], &buffer[end], (beg = len - end));
        }
        return nmeFound ? 1 : 0;
    }
}

/*****************************
 * Run the linker.  Return status of execution.
 */
public int runLINK()
{
    const phobosLibname = global.params.betterC ? null :
        global.params.symdebug ? global.params.debuglibname : global.params.defaultlibname;

    version (Windows)
    {
        if (phobosLibname)
            global.params.libfiles.push(phobosLibname);

        if (global.params.mscoff)
        {
            OutBuffer cmdbuf;
            cmdbuf.writestring("/NOLOGO");
            for (size_t i = 0; i < global.params.objfiles.dim; i++)
            {
                cmdbuf.writeByte(' ');
                const(char)* p = global.params.objfiles[i];
                writeFilename(&cmdbuf, p);
            }
            if (global.params.resfile)
            {
                cmdbuf.writeByte(' ');
                writeFilename(&cmdbuf, global.params.resfile);
            }
            cmdbuf.writeByte(' ');
            if (global.params.exefile)
            {
                cmdbuf.writestring("/OUT:");
                writeFilename(&cmdbuf, global.params.exefile);
            }
            else
            {
                /* Generate exe file name from first obj name.
                 * No need to add it to cmdbuf because the linker will default to it.
                 */
                const(char)* n = global.params.objfiles[0];
                n = FileName.name(n);
                global.params.exefile = FileName.forceExt(n, "exe");
            }
            // Make sure path to exe file exists
            ensurePathToNameExists(Loc.initial, global.params.exefile);
            cmdbuf.writeByte(' ');
            if (global.params.mapfile)
            {
                cmdbuf.writestring("/MAP:");
                writeFilename(&cmdbuf, global.params.mapfile);
            }
            else if (global.params.map)
            {
                const(char)* fn = FileName.forceExt(global.params.exefile, "map");
                const(char)* path = FileName.path(global.params.exefile);
                const(char)* p;
                if (path[0] == '\0')
                    p = FileName.combine(global.params.objdir, fn);
                else
                    p = fn;
                cmdbuf.writestring("/MAP:");
                writeFilename(&cmdbuf, p);
            }
            for (size_t i = 0; i < global.params.libfiles.dim; i++)
            {
                cmdbuf.writeByte(' ');
                cmdbuf.writestring("/DEFAULTLIB:");
                writeFilename(&cmdbuf, global.params.libfiles[i]);
            }
            if (global.params.deffile)
            {
                cmdbuf.writeByte(' ');
                cmdbuf.writestring("/DEF:");
                writeFilename(&cmdbuf, global.params.deffile);
            }
            if (global.params.symdebug)
            {
                cmdbuf.writeByte(' ');
                cmdbuf.writestring("/DEBUG");
                // in release mode we need to reactivate /OPT:REF after /DEBUG
                if (global.params.release)
                    cmdbuf.writestring(" /OPT:REF");
            }
            if (global.params.dll)
            {
                cmdbuf.writeByte(' ');
                cmdbuf.writestring("/DLL");
            }
            for (size_t i = 0; i < global.params.linkswitches.dim; i++)
            {
                cmdbuf.writeByte(' ');
                cmdbuf.writestring(global.params.linkswitches[i]);
            }

            VSOptions vsopt;
            vsopt.initialize();
            const(char)* lflags = vsopt.linkOptions(global.params.is64bit);
            if (lflags)
            {
                cmdbuf.writeByte(' ');
                cmdbuf.writestring(lflags);
            }
            char* p = cmdbuf.peekString();
            const(char)* lnkfilename = null;
            const size_t plen = strlen(p);
            if (plen > 7000)
            {
                lnkfilename = FileName.forceExt(global.params.exefile, "lnk");
                auto flnk = File(lnkfilename);
                flnk.setbuffer(p, plen);
                flnk._ref = 1;
                if (flnk.write())
                    error(Loc.initial, "error writing file %s", lnkfilename);
                if (strlen(lnkfilename) < plen)
                    sprintf(p, "@%s", lnkfilename);
            }
            const(char)* linkcmd = getenv(global.params.is64bit ? "LINKCMD64" : "LINKCMD");
            if (!linkcmd)
                linkcmd = getenv("LINKCMD"); // backward compatible
            if (!linkcmd)
                linkcmd = vsopt.linkerPath(global.params.is64bit);

            const int status = executecmd(linkcmd, p);
            if (lnkfilename)
            {
                remove(lnkfilename);
                FileName.free(lnkfilename);
            }
            return status;
        }
        else
        {
            OutBuffer cmdbuf;
            global.params.libfiles.push("user32");
            global.params.libfiles.push("kernel32");
            for (size_t i = 0; i < global.params.objfiles.dim; i++)
            {
                if (i)
                    cmdbuf.writeByte('+');
                const(char)* p = global.params.objfiles[i];
                const(char)* basename = FileName.removeExt(FileName.name(p));
                const(char)* ext = FileName.ext(p);
                if (ext && !strchr(basename, '.'))
                {
                    // Write name sans extension (but not if a double extension)
                    writeFilename(&cmdbuf, p[0 .. ext - p - 1]);
                }
                else
                    writeFilename(&cmdbuf, p);
                FileName.free(basename);
            }
            cmdbuf.writeByte(',');
            if (global.params.exefile)
                writeFilename(&cmdbuf, global.params.exefile);
            else
            {
                /* Generate exe file name from first obj name.
                 * No need to add it to cmdbuf because the linker will default to it.
                 */
                const(char)* n = global.params.objfiles[0];
                n = FileName.name(n);
                global.params.exefile = FileName.forceExt(n, "exe");
            }
            // Make sure path to exe file exists
            ensurePathToNameExists(Loc.initial, global.params.exefile);
            cmdbuf.writeByte(',');
            if (global.params.mapfile)
                writeFilename(&cmdbuf, global.params.mapfile);
            else if (global.params.map)
            {
                const(char)* fn = FileName.forceExt(global.params.exefile, "map");
                const(char)* path = FileName.path(global.params.exefile);
                const(char)* p;
                if (path[0] == '\0')
                    p = FileName.combine(global.params.objdir, fn);
                else
                    p = fn;
                writeFilename(&cmdbuf, p);
            }
            else
                cmdbuf.writestring("nul");
            cmdbuf.writeByte(',');
            for (size_t i = 0; i < global.params.libfiles.dim; i++)
            {
                if (i)
                    cmdbuf.writeByte('+');
                writeFilename(&cmdbuf, global.params.libfiles[i]);
            }
            if (global.params.deffile)
            {
                cmdbuf.writeByte(',');
                writeFilename(&cmdbuf, global.params.deffile);
            }
            /* Eliminate unnecessary trailing commas    */
            while (1)
            {
                const size_t i = cmdbuf.offset;
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
            version (none)
            {
                if (debuginfo)
                    cmdbuf.writestring("/li");
                if (codeview)
                {
                    cmdbuf.writestring("/co");
                    if (codeview3)
                        cmdbuf.writestring(":3");
                }
            }
            else
            {
                if (global.params.symdebug)
                    cmdbuf.writestring("/co");
            }
            cmdbuf.writestring("/noi");
            for (size_t i = 0; i < global.params.linkswitches.dim; i++)
            {
                cmdbuf.writestring(global.params.linkswitches[i]);
            }
            cmdbuf.writeByte(';');
            char* p = cmdbuf.peekString();
            const(char)* lnkfilename = null;
            const size_t plen = strlen(p);
            if (plen > 7000)
            {
                lnkfilename = FileName.forceExt(global.params.exefile, "lnk");
                auto flnk = File(lnkfilename);
                flnk.setbuffer(p, plen);
                flnk._ref = 1;
                if (flnk.write())
                    error(Loc.initial, "error writing file %s", lnkfilename);
                if (strlen(lnkfilename) < plen)
                    sprintf(p, "@%s", lnkfilename);
            }
            const(char)* linkcmd = getenv("LINKCMD");
            if (!linkcmd)
                linkcmd = "link";
            const int status = executecmd(linkcmd, p);
            if (lnkfilename)
            {
                remove(lnkfilename);
                FileName.free(lnkfilename);
            }
            return status;
        }
    }
    else version (Posix)
    {
        pid_t childpid;
        int status;
        // Build argv[]
        Strings argv;
        const(char)* cc = getenv("CC");
        if (!cc)
        {
            argv.push("cc");
        }
        else
        {
            // Split CC command to support link driver arguments such as -fpie or -flto.
            char *arg = strdup(cc);
            const(char)* tok = strtok(arg, " ");
            while (tok)
            {
                argv.push(mem.xstrdup(tok));
                tok = strtok(null, " ");
            }
            free(arg);
        }
        argv.append(&global.params.objfiles);
        version (OSX)
        {
            // If we are on Mac OS X and linking a dynamic library,
            // add the "-dynamiclib" flag
            if (global.params.dll)
                argv.push("-dynamiclib");
        }
        else version (Posix)
        {
            if (global.params.dll)
                argv.push("-shared");
        }
        // None of that a.out stuff. Use explicit exe file name, or
        // generate one from name of first source file.
        argv.push("-o");
        if (global.params.exefile)
        {
            argv.push(global.params.exefile);
        }
        else if (global.params.run)
        {
            version (all)
            {
                char[L_tmpnam + 14 + 1] name;
                strcpy(name.ptr, P_tmpdir);
                strcat(name.ptr, "/dmd_runXXXXXX");
                int fd = mkstemp(name.ptr);
                if (fd == -1)
                {
                    error(Loc.initial, "error creating temporary file");
                    return 1;
                }
                else
                    close(fd);
                global.params.exefile = mem.xstrdup(name.ptr);
                argv.push(global.params.exefile);
            }
            else
            {
                /* The use of tmpnam raises the issue of "is this a security hole"?
                 * The hole is that after tmpnam and before the file is opened,
                 * the attacker modifies the file system to get control of the
                 * file with that name. I do not know if this is an issue in
                 * this context.
                 * We cannot just replace it with mkstemp, because this name is
                 * passed to the linker that actually opens the file and writes to it.
                 */
                char[L_tmpnam + 1] s;
                char* n = tmpnam(s.ptr);
                global.params.exefile = mem.xstrdup(n);
                argv.push(global.params.exefile);
            }
        }
        else
        {
            // Generate exe file name from first obj name
            const(char)[] n = global.params.objfiles[0].toDString();
            const(char)[] ex;
            n = FileName.name(n);
            if (const e = FileName.ext(n))
            {
                if (global.params.dll)
                    ex = FileName.forceExt(ex, global.dll_ext.toDString());
                else
                    ex = FileName.removeExt(n);
            }
            else
                ex = "a.out"; // no extension, so give up
            argv.push(ex.ptr);
            global.params.exefile = ex.ptr;
        }
        // Make sure path to exe file exists
        ensurePathToNameExists(Loc.initial, global.params.exefile);
        if (global.params.symdebug)
            argv.push("-g");
        if (global.params.is64bit)
            argv.push("-m64");
        else
            argv.push("-m32");
        version (OSX)
        {
            /* Without this switch, ld generates messages of the form:
             * ld: warning: could not create compact unwind for __Dmain: offset of saved registers too far to encode
             * meaning they are further than 255 bytes from the frame register.
             * ld reverts to the old method instead.
             * See: https://ghc.haskell.org/trac/ghc/ticket/5019
             * which gives this tidbit:
             * "When a C++ (or x86_64 Objective-C) exception is thrown, the runtime must unwind the
             *  stack looking for some function to catch the exception.  Traditionally, the unwind
             *  information is stored in the __TEXT/__eh_frame section of each executable as Dwarf
             *  CFI (call frame information).  Beginning in Mac OS X 10.6, the unwind information is
             *  also encoded in the __TEXT/__unwind_info section using a two-level lookup table of
             *  compact unwind encodings.
             *  The unwinddump tool displays the content of the __TEXT/__unwind_info section."
             *
             * A better fix would be to save the registers next to the frame pointer.
             */
            argv.push("-Xlinker");
            argv.push("-no_compact_unwind");
        }
        if (global.params.map || global.params.mapfile)
        {
            argv.push("-Xlinker");
            version (OSX)
            {
                argv.push("-map");
            }
            else
            {
                argv.push("-Map");
            }
            if (!global.params.mapfile)
            {
                const(char)* fn = FileName.forceExt(global.params.exefile, "map");
                const(char)* path = FileName.path(global.params.exefile);
                const(char)* p;
                if (path[0] == '\0')
                    p = FileName.combine(global.params.objdir, fn);
                else
                    p = fn;
                global.params.mapfile = cast(char*)p;
            }
            argv.push("-Xlinker");
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
            argv.push("-Xlinker");
            argv.push("--gc-sections");
        }
        // return true if flagp should be ordered in with the library flags
        static bool flagIsLibraryRelated(const char* flagp)
        {
            const flag = flagp[0 .. strlen(flagp)];
            bool startsWith(string needle)
            {
                return flag.length >= needle.length && flag[0 .. needle.length] == needle;
            }

            return startsWith("-l") || startsWith("-L")
                || flag == "-(" || flag == "-)"
                || flag == "--start-group" || flag == "--end-group"
                || FileName.equalsExt(flagp, "a")
            ;
        }
        /* Add libraries. The order of libraries passed is:
         *  1. link switches others than with -L command line switch,
               e.g. --whole-archive "lib.a" --no-whole-archive     (global.params.linkswitches)
         *  2. static libraries ending with *.a     (global.params.libfiles)
         *  3. link switches passed with -L command line switch  (global.params.linkswitches)
         *  4. libraries specified by pragma(lib), which were appended
         *     to global.params.libfiles. These are prefixed with "-l"
         *  5. dynamic libraries passed to the command line (global.params.dllfiles)
         *  6. standard libraries.
         */
        foreach (p; global.params.linkswitches)
        {
            if (p && p[0] && !flagIsLibraryRelated(p))
            {
                argv.push("-Xlinker");
                argv.push(p);
            }
        }
        foreach (p; global.params.libfiles)
        {
            if (FileName.equalsExt(p, "a"))
                argv.push(p);
        }
        foreach (p; global.params.linkswitches)
        {
            if (!p || !p[0] || flagIsLibraryRelated(p))
            {
                if (!(p && p[0] == '-' && (p[1] == 'l' || p[1] == 'L')))
                {
                    // Don't need -Xlinker if switch starts with -l or -L.
                    // Eliding -Xlinker is significant for -L since it allows our paths
                    // to take precedence over gcc defaults.
                    // All other link switches were already added in step 1.
                    argv.push("-Xlinker");
                }
                argv.push(p);
            }
        }
        foreach (p; global.params.libfiles)
        {
            if (!FileName.equalsExt(p, "a"))
            {
                const plen = strlen(p);
                char* s = cast(char*)mem.xmalloc(plen + 3);
                s[0] = '-';
                s[1] = 'l';
                memcpy(s + 2, p, plen + 1);
                argv.push(s);
            }
        }
        foreach (p; global.params.dllfiles)
        {
            argv.push(p);
        }
        /* D runtime libraries must go after user specified libraries
         * passed with -l.
         */
        const libname = phobosLibname.toDString();
        if (libname.length)
        {
            const bufsize = 2 + libname.length + 1;
            auto buf = (cast(char*) malloc(bufsize))[0 .. bufsize];
            buf[0 .. 2] = "-l";

            char* getbuf(const(char)[] suffix)
            {
                buf[2 .. 2 + suffix.length] = suffix[];
                buf[2 + suffix.length] = 0;
                return buf.ptr;
            }

            if (libname.length > 3 + 2 && libname[0 .. 3] == "lib")
            {
                if (libname[$-2 .. $] == ".a")
                {
                    argv.push("-Xlinker");
                    argv.push("-Bstatic");
                    argv.push(getbuf(libname[3 .. $-2]));
                    argv.push("-Xlinker");
                    argv.push("-Bdynamic");
                }
                else if (libname[$-3 .. $] == ".so")
                    argv.push(getbuf(libname[3 .. $-3]));
                else
                    argv.push(getbuf(libname));
            }
            else
            {
                argv.push(getbuf(libname));
            }
        }
        //argv.push("-ldruntime");
        argv.push("-lpthread");
        argv.push("-lm");
        version (linux)
        {
            // Changes in ld for Ubuntu 11.10 require this to appear after phobos2
            argv.push("-lrt");
            // Link against libdl for phobos usage of dlopen
            argv.push("-ldl");
        }
        if (global.params.verbose)
        {
            // Print it
            OutBuffer buf;
            for (size_t i = 0; i < argv.dim; i++)
            {
                buf.writestring(argv[i]);
                buf.writeByte(' ');
            }
            message(buf.peekString());
        }
        argv.push(null);
        // set up pipes
        int[2] fds;
        if (pipe(fds.ptr) == -1)
        {
            perror("unable to create pipe to linker");
            return -1;
        }
        childpid = fork();
        if (childpid == 0)
        {
            // pipe linker stderr to fds[0]
            dup2(fds[1], STDERR_FILENO);
            close(fds[0]);
            execvp(argv[0], argv.tdata());
            perror(argv[0]); // failed to execute
            return -1;
        }
        else if (childpid == -1)
        {
            perror("unable to fork");
            return -1;
        }
        close(fds[1]);
        const(int) nme = findNoMainError(fds[0]);
        waitpid(childpid, &status, 0);
        if (WIFEXITED(status))
        {
            status = WEXITSTATUS(status);
            if (status)
            {
                if (nme == -1)
                {
                    perror("error with the linker pipe");
                    return -1;
                }
                else
                {
                    error(Loc.initial, "linker exited with status %d", status);
                    if (nme == 1)
                        error(Loc.initial, "no main function specified");
                }
            }
        }
        else if (WIFSIGNALED(status))
        {
            error(Loc.initial, "linker killed by signal %d", WTERMSIG(status));
            status = 1;
        }
        return status;
    }
    else
    {
        error(Loc.initial, "linking is not yet supported for this version of DMD.");
        return -1;
    }
}


/******************************
 * Execute a rule.  Return the status.
 *      cmd     program to run
 *      args    arguments to cmd, as a string
 */
version (Windows)
{
    private int executecmd(const(char)* cmd, const(char)* args)
    {
        int status;
        size_t len;
        if (global.params.verbose)
            message("%s %s", cmd, args);
        if (!global.params.mscoff)
        {
            if ((len = strlen(args)) > 255)
            {
                char* q = cast(char*)alloca(8 + len + 1);
                sprintf(q, "_CMDLINE=%s", args);
                status = putenv(q);
                if (status == 0)
                {
                    args = "@_CMDLINE";
                }
                else
                {
                    error(Loc.initial, "command line length of %d is too long", len);
                }
            }
        }
        // Normalize executable path separators
        // https://issues.dlang.org/show_bug.cgi?id=9330
        cmd = toWinPath(cmd);
        version (CRuntime_Microsoft)
        {
            // Open scope so dmd doesn't complain about alloca + exception handling
            {
                // Use process spawning through the WinAPI to avoid issues with executearg0 and spawnlp
                OutBuffer cmdbuf;
                cmdbuf.writestring("\"");
                cmdbuf.writestring(cmd);
                cmdbuf.writestring("\" ");
                cmdbuf.writestring(args);

                STARTUPINFOA startInf;
                startInf.dwFlags = STARTF_USESTDHANDLES;
                startInf.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
                startInf.hStdOutput = GetStdHandle(STD_OUTPUT_HANDLE);
                startInf.hStdError = GetStdHandle(STD_ERROR_HANDLE);
                PROCESS_INFORMATION procInf;

                BOOL b = CreateProcessA(null, cmdbuf.peekString(), null, null, 1, NORMAL_PRIORITY_CLASS, null, null, &startInf, &procInf);
                if (b)
                {
                    WaitForSingleObject(procInf.hProcess, INFINITE);
                    DWORD returnCode;
                    GetExitCodeProcess(procInf.hProcess, &returnCode);
                    status = returnCode;
                    CloseHandle(procInf.hProcess);
                }
                else
                {
                    status = -1;
                }
            }
        }
        else
        {
            status = executearg0(cmd, args);
            if (status == -1)
            {
                status = spawnlp(0, cmd, cmd, args, null);
            }
        }
        if (status)
        {
            if (status == -1)
                error(Loc.initial, "can't run '%s', check PATH", cmd);
            else
                error(Loc.initial, "linker exited with status %d", status);
        }
        return status;
    }
}

/**************************************
 * Attempt to find command to execute by first looking in the directory
 * where DMD was run from.
 * Returns:
 *      -1      did not find command there
 *      !=-1    exit status from command
 */
version (Windows)
{
    private int executearg0(const(char)* cmd, const(char)* args)
    {
        const argv0 = global.params.argv0;
        //printf("argv0='%s', cmd='%s', args='%s'\n",argv0,cmd,args);
        // If cmd is fully qualified, we don't do this
        if (FileName.absolute(cmd))
            return -1;
        const file = FileName.replaceName(argv0, cmd.toDString);
        //printf("spawning '%s'\n",file);
        // spawnlp returns intptr_t in some systems, not int
        return spawnl(0, file.ptr, file.ptr, args, null);
    }
}

/***************************************
 * Run the compiled program.
 * Return exit status.
 */
public int runProgram()
{
    //printf("runProgram()\n");
    if (global.params.verbose)
    {
        OutBuffer buf;
        buf.writestring(global.params.exefile);
        for (size_t i = 0; i < global.params.runargs.dim; ++i)
        {
            buf.writeByte(' ');
            buf.writestring(global.params.runargs[i]);
        }
        message(buf.peekString());
    }
    // Build argv[]
    Strings argv;
    argv.push(global.params.exefile);
    for (size_t i = 0; i < global.params.runargs.dim; ++i)
    {
        const(char)* a = global.params.runargs[i];
        version (Windows)
        {
            // BUG: what about " appearing in the string?
            if (strchr(a, ' '))
            {
                char* b = cast(char*)mem.xmalloc(3 + strlen(a));
                sprintf(b, "\"%s\"", a);
                a = b;
            }
        }
        argv.push(a);
    }
    argv.push(null);
    version (Windows)
    {
        const(char)* ex = FileName.name(global.params.exefile);
        if (ex == global.params.exefile)
            ex = FileName.combine(".", ex);
        else
            ex = global.params.exefile;
        // spawnlp returns intptr_t in some systems, not int
        return spawnv(0, ex, argv.tdata());
    }
    else version (Posix)
    {
        pid_t childpid;
        int status;
        childpid = fork();
        if (childpid == 0)
        {
            const(char)* fn = argv[0];
            if (!FileName.absolute(fn))
            {
                // Make it "./fn"
                fn = FileName.combine(".", fn);
            }
            execv(fn, argv.tdata());
            perror(fn); // failed to execute
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
            error(Loc.initial, "program killed by signal %d", WTERMSIG(status));
            status = 1;
        }
        return status;
    }
    else
    {
        assert(0);
    }
}

version (Windows)
{
    struct VSOptions
    {
        // evaluated once at startup, reflecting the result of vcvarsall.bat
        //  from the current environment or the latest Visual Studio installation
        const(char)* WindowsSdkDir;
        const(char)* WindowsSdkVersion;
        const(char)* UCRTSdkDir;
        const(char)* UCRTVersion;
        const(char)* VSInstallDir;
        const(char)* VCInstallDir;
        const(char)* VCToolsInstallDir; // used by VS 2017+

        /**
         * fill member variables from environment or registry
         */
        void initialize()
        {
            detectWindowsSDK();
            detectUCRT();
            detectVSInstallDir();
            detectVCInstallDir();
            detectVCToolsInstallDir();
        }

        /**
         * retrieve the name of the default C runtime library
         * Params:
         *   x64 = target architecture (x86 if false)
         * Returns:
         *   name of the default C runtime library
         */
        const(char)* defaultRuntimeLibrary(bool x64)
        {
            if (VCInstallDir is null)
            {
                detectVCInstallDir();
                detectVCToolsInstallDir();
            }
            if (getVCLibDir(x64))
                return "libcmt";
            else
                return "msvcrt100"; // mingw replacement
        }

        /**
         * retrieve options to be passed to the Microsoft linker
         * Params:
         *   x64 = target architecture (x86 if false)
         * Returns:
         *   allocated string of options to add to the linker command line
         */
        const(char)* linkOptions(bool x64)
        {
            OutBuffer cmdbuf;
            if (auto vclibdir = getVCLibDir(x64))
            {
                cmdbuf.writestring(" /LIBPATH:\"");
                cmdbuf.writestring(vclibdir);
                cmdbuf.writeByte('\"');

                if (FileName.exists(FileName.combine(vclibdir, "legacy_stdio_definitions.lib")))
                {
                    // VS2015 or later use UCRT
                    cmdbuf.writestring(" legacy_stdio_definitions.lib");
                    if (auto p = getUCRTLibPath(x64))
                    {
                        cmdbuf.writestring(" /LIBPATH:\"");
                        cmdbuf.writestring(p);
                        cmdbuf.writeByte('\"');
                    }
                }
            }
            if (auto p = getSDKLibPath(x64))
            {
                cmdbuf.writestring(" /LIBPATH:\"");
                cmdbuf.writestring(p);
                cmdbuf.writeByte('\"');
            }
            if (auto p = getenv("DXSDK_DIR"))
            {
                // support for old DX SDK installations
                cmdbuf.writestring(" /LIBPATH:\"");
                cmdbuf.writestring(p);
                cmdbuf.writestring(x64 ? `\Lib\x64"` : `\Lib\x86"`);
            }
            return cmdbuf.extractChars();
        }

        /**
         * retrieve path to the Microsoft linker executable
         * also modifies PATH environment variable if necessary to find conditionally loaded DLLs
         * Params:
         *   x64 = target architecture (x86 if false)
         * Returns:
         *   absolute path to link.exe, just "link.exe" if not found
         */
        const(char)* linkerPath(bool x64)
        {
            const(char)* addpath;
            if (auto p = getVCBinDir(x64, addpath))
            {
                OutBuffer cmdbuf;
                cmdbuf.writestring(p);
                cmdbuf.writestring(r"\link.exe");
                if (addpath)
                {
                    // debug info needs DLLs from $(VSInstallDir)\Common7\IDE for most linker versions
                    //  so prepend it too the PATH environment variable
                    const char* path = getenv("PATH");
                    const pathlen = strlen(path);
                    const addpathlen = strlen(addpath);

                    char* npath = cast(char*)mem.xmalloc(5 + pathlen + 1 + addpathlen + 1);
                    memcpy(npath, "PATH=".ptr, 5);
                    memcpy(npath + 5, addpath, addpathlen);
                    npath[5 + addpathlen] = ';';
                    memcpy(npath + 5 + addpathlen + 1, path, pathlen + 1);
                    putenv(npath);
                }
                return cmdbuf.extractChars();
            }

            // try lld-link.exe alongside dmd.exe
            char[MAX_PATH + 1] dmdpath = void;
            const len = GetModuleFileNameA(null, dmdpath.ptr, dmdpath.length);
            if (len <= MAX_PATH)
            {
                auto lldpath = FileName.replaceName(dmdpath[0 .. len], "lld-link.exe");
                if (FileName.exists(lldpath))
                    return lldpath.ptr;
            }

            // search PATH to avoid createProcess preferring "link.exe" from the dmd folder
            Strings* paths = FileName.splitPath(getenv("PATH"));
            if (auto p = FileName.searchPath(paths, "link.exe"[], false))
                return p.ptr;
            return "link.exe";
        }

    private:
        /**
         * detect WindowsSdkDir and WindowsSDKVersion from environment or registry
         */
        void detectWindowsSDK()
        {
            if (WindowsSdkDir is null)
                WindowsSdkDir = getenv("WindowsSdkDir");

            if (WindowsSdkDir is null)
            {
                WindowsSdkDir = GetRegistryString(r"Microsoft\Windows Kits\Installed Roots", "KitsRoot10");
                if (WindowsSdkDir && !findLatestSDKDir(FileName.combine(WindowsSdkDir, "Include"), r"um\windows.h"))
                    WindowsSdkDir = null;
            }
            if (WindowsSdkDir is null)
            {
                WindowsSdkDir = GetRegistryString(r"Microsoft\Microsoft SDKs\Windows\v8.1", "InstallationFolder");
                if (WindowsSdkDir && !FileName.exists(FileName.combine(WindowsSdkDir, "Lib")))
                    WindowsSdkDir = null;
            }
            if (WindowsSdkDir is null)
            {
                WindowsSdkDir = GetRegistryString(r"Microsoft\Microsoft SDKs\Windows\v8.0", "InstallationFolder");
                if (WindowsSdkDir && !FileName.exists(FileName.combine(WindowsSdkDir, "Lib")))
                    WindowsSdkDir = null;
            }
            if (WindowsSdkDir is null)
            {
                WindowsSdkDir = GetRegistryString(r"Microsoft\Microsoft SDKs\Windows", "CurrentInstallationFolder");
                if (WindowsSdkDir && !FileName.exists(FileName.combine(WindowsSdkDir, "Lib")))
                    WindowsSdkDir = null;
            }

            if (WindowsSdkVersion is null)
                WindowsSdkVersion = getenv("WindowsSdkVersion");

            if (WindowsSdkVersion is null && WindowsSdkDir !is null)
            {
                const(char)* rootsDir = FileName.combine(WindowsSdkDir, "Include");
                WindowsSdkVersion = findLatestSDKDir(rootsDir, r"um\windows.h");
            }
        }

        /**
         * detect UCRTSdkDir and UCRTVersion from environment or registry
         */
        void detectUCRT()
        {
            if (UCRTSdkDir is null)
                UCRTSdkDir = getenv("UniversalCRTSdkDir");

            if (UCRTSdkDir is null)
                UCRTSdkDir = GetRegistryString(r"Microsoft\Windows Kits\Installed Roots", "KitsRoot10");

            if (UCRTVersion is null)
                UCRTVersion = getenv("UCRTVersion");

            if (UCRTVersion is null && UCRTSdkDir !is null)
            {
                const(char)* rootsDir = FileName.combine(UCRTSdkDir, "Lib");
                UCRTVersion = findLatestSDKDir(rootsDir, r"ucrt\x86\libucrt.lib");
            }
        }

        /**
         * detect VSInstallDir from environment or registry
         */
        void detectVSInstallDir()
        {
            if (VSInstallDir is null)
                VSInstallDir = getenv("VSINSTALLDIR");

            if (VSInstallDir is null)
                VSInstallDir = detectVSInstallDirViaCOM();

            if (VSInstallDir is null)
                VSInstallDir = GetRegistryString(r"Microsoft\VisualStudio\SxS\VS7", "15.0"); // VS2017

            if (VSInstallDir is null)
                foreach (const(char)* ver; ["14.0".ptr, "12.0", "11.0", "10.0", "9.0"])
                {
                    VSInstallDir = GetRegistryString(FileName.combine(r"Microsoft\VisualStudio", ver), "InstallDir");
                    if (VSInstallDir)
                        break;
                }
        }

        /**
         * detect VCInstallDir from environment or registry
         */
        void detectVCInstallDir()
        {
            if (VCInstallDir is null)
                VCInstallDir = getenv("VCINSTALLDIR");

            if (VCInstallDir is null)
                if (VSInstallDir && FileName.exists(FileName.combine(VSInstallDir, "VC")))
                    VCInstallDir = FileName.combine(VSInstallDir, "VC");

            // detect from registry (build tools?)
            if (VCInstallDir is null)
                foreach (const(char)* ver; ["14.0".ptr, "12.0", "11.0", "10.0", "9.0"])
                {
                    auto regPath = FileName.buildPath(r"Microsoft\VisualStudio", ver, r"Setup\VC");
                    VCInstallDir = GetRegistryString(regPath, "ProductDir");
                    if (VCInstallDir)
                        break;
                }
        }

        /**
         * detect VCToolsInstallDir from environment or registry (only used by VC 2017)
         */
        void detectVCToolsInstallDir()
        {
            if (VCToolsInstallDir is null)
                VCToolsInstallDir = getenv("VCTOOLSINSTALLDIR");

            if (VCToolsInstallDir is null && VCInstallDir)
            {
                const(char)* defverFile = FileName.combine(VCInstallDir, r"Auxiliary\Build\Microsoft.VCToolsVersion.default.txt");
                if (!FileName.exists(defverFile)) // file renamed with VS2019 Preview 2
                    defverFile = FileName.combine(VCInstallDir, r"Auxiliary\Build\Microsoft.VCToolsVersion.v142.default.txt");
                if (FileName.exists(defverFile))
                {
                    // VS 2017
                    File f = File(defverFile);
                    if (!f.read()) // returns true on error (!), adds sentinel 0 at end of file
                    {
                        auto ver = cast(char*)f.buffer;
                        // trim version number
                        while (*ver && isspace(*ver))
                            ver++;
                        auto p = ver;
                        while (*p == '.' || (*p >= '0' && *p <= '9'))
                            p++;
                        *p = 0;

                        if (ver && *ver)
                            VCToolsInstallDir = FileName.buildPath(VCInstallDir, r"Tools\MSVC", ver);
                    }
                }
            }
        }

        /**
         * get Visual C bin folder
         * Params:
         *   x64 = target architecture (x86 if false)
         *   addpath = [out] path that needs to be added to the PATH environment variable
         * Returns:
         *   folder containing the VC executables
         *
         * Selects the binary path according to the host and target OS, but verifies
         * that link.exe exists in that folder and falls back to 32-bit host/target if
         * missing
         * Note: differences for the linker binaries are small, they all
         * allow cross compilation
         */
        const(char)* getVCBinDir(bool x64, out const(char)* addpath)
        {
            static const(char)* linkExists(const(char)* p)
            {
                auto lp = FileName.combine(p, "link.exe");
                return FileName.exists(lp) ? p : null;
            }

            const bool isHost64 = isWin64Host();
            if (VCToolsInstallDir !is null)
            {
                if (isHost64)
                {
                    if (x64)
                    {
                        if (auto p = linkExists(FileName.combine(VCToolsInstallDir, r"bin\HostX64\x64")))
                            return p;
                        // in case of missing linker, prefer other host binaries over other target architecture
                    }
                    else
                    {
                        if (auto p = linkExists(FileName.combine(VCToolsInstallDir, r"bin\HostX64\x86")))
                        {
                            addpath = FileName.combine(VCToolsInstallDir, r"bin\HostX64\x64");
                            return p;
                        }
                    }
                }
                if (x64)
                {
                    if (auto p = linkExists(FileName.combine(VCToolsInstallDir, r"bin\HostX86\x64")))
                    {
                        addpath = FileName.combine(VCToolsInstallDir, r"bin\HostX86\x86");
                        return p;
                    }
                }
                if (auto p = linkExists(FileName.combine(VCToolsInstallDir, r"bin\HostX86\x86")))
                    return p;
            }
            if (VCInstallDir !is null)
            {
                if (isHost64)
                {
                    if (x64)
                    {
                        if (auto p = linkExists(FileName.combine(VCInstallDir, r"bin\amd64")))
                            return p;
                        // in case of missing linker, prefer other host binaries over other target architecture
                    }
                    else
                    {
                        if (auto p = linkExists(FileName.combine(VCInstallDir, r"bin\amd64_x86")))
                        {
                            addpath = FileName.combine(VCInstallDir, r"bin\amd64");
                            return p;
                        }
                    }
                }

                if (VSInstallDir)
                    addpath = FileName.combine(VSInstallDir, r"Common7\IDE");
                else
                    addpath = FileName.combine(VCInstallDir, r"bin");

                if (x64)
                    if (auto p = linkExists(FileName.combine(VCInstallDir, r"x86_amd64")))
                        return p;

                if (auto p = linkExists(FileName.combine(VCInstallDir, r"bin\HostX86\x86")))
                    return p;
            }
            return null;
        }

        /**
        * get Visual C Library folder
        * Params:
        *   x64 = target architecture (x86 if false)
        * Returns:
        *   folder containing the the VC runtime libraries
        */
        const(char)* getVCLibDir(bool x64)
        {
            if (VCToolsInstallDir !is null)
                return FileName.combine(VCToolsInstallDir, x64 ? r"lib\x64" : r"lib\x86");
            if (VCInstallDir !is null)
                return FileName.combine(VCInstallDir, x64 ? r"lib\amd64" : "lib");
            return null;
        }

        /**
         * get the path to the universal CRT libraries
         * Params:
         *   x64 = target architecture (x86 if false)
         * Returns:
         *   folder containing the universal CRT libraries
         */
        const(char)* getUCRTLibPath(bool x64)
        {
            if (UCRTSdkDir && UCRTVersion)
               return FileName.buildPath(UCRTSdkDir, "Lib", UCRTVersion, x64 ? r"ucrt\x64" : r"ucrt\x86");
            return null;
        }

        /**
         * get the path to the Windows SDK CRT libraries
         * Params:
         *   x64 = target architecture (x86 if false)
         * Returns:
         *   folder containing the Windows SDK libraries
         */
        const(char)* getSDKLibPath(bool x64)
        {
            if (WindowsSdkDir)
            {
                const(char)* arch = x64 ? "x64" : "x86";
                auto sdk = FileName.combine(WindowsSdkDir, "lib");
                if (WindowsSdkVersion &&
                    FileName.exists(FileName.buildPath(sdk, WindowsSdkVersion, "um", arch, "kernel32.lib"))) // SDK 10.0
                    return FileName.buildPath(sdk, WindowsSdkVersion, "um", arch);
                else if (FileName.exists(FileName.buildPath(sdk, r"win8\um", arch, "kernel32.lib"))) // SDK 8.0
                    return FileName.buildPath(sdk, r"win8\um", arch);
                else if (FileName.exists(FileName.buildPath(sdk, r"winv6.3\um", arch, "kernel32.lib"))) // SDK 8.1
                    return FileName.buildPath(sdk, r"winv6.3\um", arch);
                else if (x64 && FileName.exists(FileName.buildPath(sdk, arch, "kernel32.lib"))) // SDK 7.1 or earlier
                    return FileName.buildPath(sdk, arch);
                else if (!x64 && FileName.exists(FileName.buildPath(sdk, "kernel32.lib"))) // SDK 7.1 or earlier
                    return sdk;
            }

            // try mingw fallback relative to phobos library folder that's part of LIB
            Strings* libpaths = FileName.splitPath(getenv("LIB"));
            if (auto p = FileName.searchPath(libpaths, r"mingw\kernel32.lib"[], false))
                return FileName.path(p).ptr;

            return null;
        }

        // iterate through subdirectories named by SDK version in baseDir and return the
        //  one with the largest version that also contains the test file
        static const(char)* findLatestSDKDir(const(char)* baseDir, const(char)* testfile)
        {
            auto allfiles = FileName.combine(baseDir, "*");
            WIN32_FIND_DATAA fileinfo;
            HANDLE h = FindFirstFileA(allfiles, &fileinfo);
            if (h == INVALID_HANDLE_VALUE)
                return null;

            char* res = null;
            do
            {
                if (fileinfo.cFileName[0] >= '1' && fileinfo.cFileName[0] <= '9')
                    if (res is null || strcmp(res, fileinfo.cFileName.ptr) < 0)
                        if (FileName.exists(FileName.buildPath(baseDir, fileinfo.cFileName.ptr, testfile)))
                        {
                            const len = strlen(fileinfo.cFileName.ptr) + 1;
                            res = cast(char*) memcpy(mem.xrealloc(res, len), fileinfo.cFileName.ptr, len);
                        }
            }
            while(FindNextFileA(h, &fileinfo));

            if (!FindClose(h))
                res = null;
            return res;
        }

        pragma(lib, "advapi32.lib");

        /**
         * read a string from the 32-bit registry
         * Params:
         *  softwareKeyPath = path below HKLM\SOFTWARE
         *  valueName       = name of the value to read
         * Returns:
         *  the registry value if it exists and has string type
         */
        const(char)* GetRegistryString(const(char)* softwareKeyPath, const(char)* valueName)
        {
            enum x64hive = false; // VS registry entries always in 32-bit hive

            version(Win64)
                enum prefix = x64hive ? r"SOFTWARE\" : r"SOFTWARE\WOW6432Node\";
            else
                enum prefix = r"SOFTWARE\";

            char[260] regPath = void;
            const len = strlen(softwareKeyPath);
            assert(len + prefix.length < regPath.length);

            memcpy(regPath.ptr, prefix.ptr, prefix.length);
            memcpy(regPath.ptr + prefix.length, softwareKeyPath, len + 1);

            enum KEY_WOW64_64KEY = 0x000100; // not defined in core.sys.windows.winnt due to restrictive version
            enum KEY_WOW64_32KEY = 0x000200;
            HKEY key;
            LONG lRes = RegOpenKeyExA(HKEY_LOCAL_MACHINE, regPath.ptr, (x64hive ? KEY_WOW64_64KEY : KEY_WOW64_32KEY), KEY_READ, &key);
            if (FAILED(lRes))
                return null;
            scope(exit) RegCloseKey(key);

            char[260] buf = void;
            DWORD cnt = buf.length * char.sizeof;
            DWORD type;
            int hr = RegQueryValueExA(key, valueName, null, &type, cast(ubyte*) buf.ptr, &cnt);
            if (hr == 0 && cnt > 0)
                return buf.dup.ptr;
            if (hr != ERROR_MORE_DATA || type != REG_SZ)
                return null;

            scope char[] pbuf = new char[cnt + 1];
            RegQueryValueExA(key, valueName, null, &type, cast(ubyte*) pbuf.ptr, &cnt);
            return pbuf.ptr;
        }

        /***
         * get architecture of host OS
         */
        static bool isWin64Host()
        {
            version (Win64)
            {
                return true;
            }
            else
            {
                // running as a 32-bit process on a 64-bit host?
                alias fnIsWow64Process = extern(Windows) BOOL function(HANDLE, PBOOL);
                __gshared fnIsWow64Process pIsWow64Process;

                if (!pIsWow64Process)
                {
                    //IsWow64Process is not available on all supported versions of Windows.
                    pIsWow64Process = cast(fnIsWow64Process) GetProcAddress(GetModuleHandleA("kernel32"), "IsWow64Process");
                    if (!pIsWow64Process)
                        return false;
                }
                BOOL bIsWow64 = FALSE;
                if (!pIsWow64Process(GetCurrentProcess(), &bIsWow64))
                    return false;

                return bIsWow64 != 0;
            }
        }
    }

    ///////////////////////////////////////////////////////////////////////
    // COM interfaces to find VS2017+ installations
    import core.sys.windows.com;
    import core.sys.windows.wtypes : BSTR;
    import core.sys.windows.winnls : WideCharToMultiByte, CP_UTF8;
    import core.sys.windows.oleauto : SysFreeString;

    pragma(lib, "ole32.lib");
    pragma(lib, "oleaut32.lib");

    interface ISetupInstance : IUnknown
    {
        // static const GUID iid = uuid("B41463C3-8866-43B5-BC33-2B0676F7F42E");
        static const GUID iid = { 0xB41463C3, 0x8866, 0x43B5, [ 0xBC, 0x33, 0x2B, 0x06, 0x76, 0xF7, 0xF4, 0x2E ] };

        int GetInstanceId(BSTR* pbstrInstanceId);
        int GetInstallDate(LPFILETIME pInstallDate);
        int GetInstallationName(BSTR* pbstrInstallationName);
        int GetInstallationPath(BSTR* pbstrInstallationPath);
        int GetInstallationVersion(BSTR* pbstrInstallationVersion);
        int GetDisplayName(LCID lcid, BSTR* pbstrDisplayName);
        int GetDescription(LCID lcid, BSTR* pbstrDescription);
        int ResolvePath(LPCOLESTR pwszRelativePath, BSTR* pbstrAbsolutePath);
    }

    interface IEnumSetupInstances : IUnknown
    {
        // static const GUID iid = uuid("6380BCFF-41D3-4B2E-8B2E-BF8A6810C848");

        int Next(ULONG celt, ISetupInstance* rgelt, ULONG* pceltFetched);
        int Skip(ULONG celt);
        int Reset();
        int Clone(IEnumSetupInstances* ppenum);
    }

    interface ISetupConfiguration : IUnknown
    {
        // static const GUID iid = uuid("42843719-DB4C-46C2-8E7C-64F1816EFD5B");
        static const GUID iid = { 0x42843719, 0xDB4C, 0x46C2, [ 0x8E, 0x7C, 0x64, 0xF1, 0x81, 0x6E, 0xFD, 0x5B ] };

        int EnumInstances(IEnumSetupInstances* ppEnumInstances) ;
        int GetInstanceForCurrentProcess(ISetupInstance* ppInstance);
        int GetInstanceForPath(LPCWSTR wzPath, ISetupInstance* ppInstance);
    }

    const GUID iid_SetupConfiguration = { 0x177F0C4A, 0x1CD3, 0x4DE7, [ 0xA3, 0x2C, 0x71, 0xDB, 0xBB, 0x9F, 0xA3, 0x6D ] };

    const(char)* detectVSInstallDirViaCOM()
    {
        CoInitialize(null);
        scope(exit) CoUninitialize();

        ISetupConfiguration setup;
        IEnumSetupInstances instances;
        ISetupInstance instance;
        DWORD fetched;

        HRESULT hr = CoCreateInstance(&iid_SetupConfiguration, null, CLSCTX_ALL, &ISetupConfiguration.iid, cast(void**) &setup);
        if (hr != S_OK || !setup)
            return null;
        scope(exit) setup.Release();

        if (setup.EnumInstances(&instances) != S_OK)
            return null;
        scope(exit) instances.Release();

        while (instances.Next(1, &instance, &fetched) == S_OK && fetched)
        {
            BSTR bstrInstallDir;
            if (instance.GetInstallationPath(&bstrInstallDir) != S_OK)
                continue;

            char[260] path;
            int len = WideCharToMultiByte(CP_UTF8, 0, bstrInstallDir, -1, path.ptr, 260, null, null);
            SysFreeString(bstrInstallDir);

            if (len > 0)
                return path[0..len].idup.ptr;
        }
        return null;
    }
}
