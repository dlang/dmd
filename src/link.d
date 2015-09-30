// Compiler implementation of the D programming language
// Copyright (c) 1999-2015 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// Distributed under the Boost Software License, Version 1.0.
// http://www.boost.org/LICENSE_1_0.txt

module ddmd.link;

import core.stdc.ctype;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import core.sys.posix.stdio;
import core.sys.posix.stdlib;
import core.sys.posix.sys.wait;
import core.sys.posix.unistd;
import ddmd.errors;
import ddmd.globals;
import ddmd.mars;
import ddmd.root.file;
import ddmd.root.filename;
import ddmd.root.outbuffer;
import ddmd.root.rmem;

version (Posix) extern (C) int pipe(int*);
version (Windows) extern (C) int putenv(const char*);
version (Windows) extern (C) int spawnlp(int, const char*, const char*, const char*, const char*);
version (Windows) extern (C) int spawnl(int, const char*, const char*, const char*, const char*);
version (Windows) extern (C) int spawnv(int, const char*, const char**);
version (CRuntime_Microsoft) extern (Windows) uint GetShortPathNameA(const char* lpszLongPath, char* lpszShortPath, uint cchBuffer);

static if (__linux__ || __APPLE__)
{
    enum HAS_POSIX_SPAWN = 1;
}
else
{
    enum HAS_POSIX_SPAWN = 0;
}

/****************************************
 * Write filename to cmdbuf, quoting if necessary.
 */
extern (C++) void writeFilename(OutBuffer* buf, const(char)* filename, size_t len)
{
    /* Loop and see if we need to quote
     */
    for (size_t i = 0; i < len; i++)
    {
        char c = filename[i];
        if (isalnum(cast(char)c) || c == '_')
            continue;
        /* Need to quote
         */
        buf.writeByte('"');
        buf.write(filename, len);
        buf.writeByte('"');
        return;
    }
    /* No quoting necessary
     */
    buf.write(filename, len);
}

extern (C++) void writeFilename(OutBuffer* buf, const(char)* filename)
{
    writeFilename(buf, filename, strlen(filename));
}

static if (__linux__ || __APPLE__ || __FreeBSD__ || __OpenBSD__ || __sun)
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
    extern (C++) int findNoMainError(int fd)
    {
        version (OSX)
        {
            static __gshared const(char)* nmeErrorMessage = "\"__Dmain\", referenced from:";
        }
        else
        {
            static __gshared const(char)* nmeErrorMessage = "undefined reference to `_Dmain'";
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
extern (C++) int runLINK()
{
    version (Windows)
    {
        if (global.params.mscoff)
        {
            OutBuffer cmdbuf;
            cmdbuf.writestring("/NOLOGO ");
            for (size_t i = 0; i < global.params.objfiles.dim; i++)
            {
                if (i)
                    cmdbuf.writeByte(' ');
                const(char)* p = (*global.params.objfiles)[i];
                const(char)* basename = FileName.removeExt(FileName.name(p));
                const(char)* ext = FileName.ext(p);
                if (ext && !strchr(basename, '.'))
                {
                    // Write name sans extension (but not if a double extension)
                    writeFilename(&cmdbuf, p, ext - p - 1);
                }
                else
                    writeFilename(&cmdbuf, p);
                FileName.free(basename);
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
                const(char)* n = (*global.params.objfiles)[0];
                n = FileName.name(n);
                global.params.exefile = cast(char*)FileName.forceExt(n, "exe");
            }
            // Make sure path to exe file exists
            ensurePathToNameExists(Loc(), global.params.exefile);
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
                writeFilename(&cmdbuf, (*global.params.libfiles)[i]);
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
                cmdbuf.writestring((*global.params.linkswitches)[i]);
            }
            /* Append the path to the VC lib files, and then the SDK lib files
             */
            const(char)* vcinstalldir = getenv("VCINSTALLDIR");
            if (vcinstalldir)
            {
                cmdbuf.writestring(" /LIBPATH:\"");
                cmdbuf.writestring(vcinstalldir);
                if (global.params.is64bit)
                    cmdbuf.writestring("\\lib\\amd64\"");
                else
                    cmdbuf.writestring("\\lib\"");
            }
            const(char)* windowssdkdir = getenv("WindowsSdkDir");
            if (windowssdkdir)
            {
                cmdbuf.writestring(" /LIBPATH:\"");
                cmdbuf.writestring(windowssdkdir);
                if (global.params.is64bit)
                    cmdbuf.writestring("\\lib\\x64\"");
                else
                    cmdbuf.writestring("\\lib\"");
            }
            cmdbuf.writeByte(' ');
            const(char)* lflags;
            if (detectVS14(cmdbuf.peekString()))
            {
                lflags = getenv("LFLAGS_VS14");
                if (!lflags)
                    lflags = "legacy_stdio_definitions.lib";
                // environment variables UniversalCRTSdkDir and UCRTVersion set
                // when running vcvarsall.bat x64
                if (const(char)* UniversalCRTSdkDir = getenv("UniversalCRTSdkDir"))
                    if (const(char)* UCRTVersion = getenv("UCRTVersion"))
                    {
                        cmdbuf.writestring(" /LIBPATH:\"");
                        cmdbuf.writestring(UniversalCRTSdkDir);
                        cmdbuf.writestring("\\lib\\");
                        cmdbuf.writestring(UCRTVersion);
                        if (global.params.is64bit)
                            cmdbuf.writestring("\\ucrt\\x64\"");
                        else
                            cmdbuf.writestring("\\ucrt\\x86\"");
                    }
            }
            else
            {
                lflags = getenv("LFLAGS_VS12");
            }
            if (lflags)
            {
                cmdbuf.writeByte(' ');
                cmdbuf.writestring(lflags);
            }
            char* p = cmdbuf.peekString();
            const(char)* lnkfilename = null;
            size_t plen = strlen(p);
            if (plen > 7000)
            {
                lnkfilename = FileName.forceExt(global.params.exefile, "lnk");
                auto flnk = File(lnkfilename);
                flnk.setbuffer(p, plen);
                flnk._ref = 1;
                if (flnk.write())
                    error(Loc(), "error writing file %s", lnkfilename);
                if (strlen(lnkfilename) < plen)
                    sprintf(p, "@%s", lnkfilename);
            }
            const(char)* linkcmd = getenv(global.params.is64bit ? "LINKCMD64" : "LINKCMD");
            if (!linkcmd)
                linkcmd = getenv("LINKCMD"); // backward compatible
            if (!linkcmd)
            {
                if (vcinstalldir)
                {
                    OutBuffer linkcmdbuf;
                    linkcmdbuf.writestring(vcinstalldir);
                    if (global.params.is64bit)
                        linkcmdbuf.writestring("\\bin\\amd64\\link");
                    else
                        linkcmdbuf.writestring("\\bin\\link");
                    linkcmd = linkcmdbuf.extractString();
                }
                else
                    linkcmd = "optlink";
            }
            int status = executecmd(linkcmd, p);
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
                const(char)* p = (*global.params.objfiles)[i];
                const(char)* basename = FileName.removeExt(FileName.name(p));
                const(char)* ext = FileName.ext(p);
                if (ext && !strchr(basename, '.'))
                {
                    // Write name sans extension (but not if a double extension)
                    writeFilename(&cmdbuf, p, ext - p - 1);
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
                const(char)* n = (*global.params.objfiles)[0];
                n = FileName.name(n);
                global.params.exefile = cast(char*)FileName.forceExt(n, "exe");
            }
            // Make sure path to exe file exists
            ensurePathToNameExists(Loc(), global.params.exefile);
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
                writeFilename(&cmdbuf, (*global.params.libfiles)[i]);
            }
            if (global.params.deffile)
            {
                cmdbuf.writeByte(',');
                writeFilename(&cmdbuf, global.params.deffile);
            }
            /* Eliminate unnecessary trailing commas    */
            while (1)
            {
                size_t i = cmdbuf.offset;
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
                cmdbuf.writestring((*global.params.linkswitches)[i]);
            }
            cmdbuf.writeByte(';');
            char* p = cmdbuf.peekString();
            const(char)* lnkfilename = null;
            size_t plen = strlen(p);
            if (plen > 7000)
            {
                lnkfilename = FileName.forceExt(global.params.exefile, "lnk");
                auto flnk = File(lnkfilename);
                flnk.setbuffer(p, plen);
                flnk._ref = 1;
                if (flnk.write())
                    error(Loc(), "error writing file %s", lnkfilename);
                if (strlen(lnkfilename) < plen)
                    sprintf(p, "@%s", lnkfilename);
            }
            const(char)* linkcmd = getenv("LINKCMD");
            if (!linkcmd)
                linkcmd = "link";
            int status = executecmd(linkcmd, p);
            if (lnkfilename)
            {
                remove(lnkfilename);
                FileName.free(lnkfilename);
            }
            return status;
        }
    }
    else static if (__linux__ || __APPLE__ || __FreeBSD__ || __OpenBSD__ || __sun)
    {
        pid_t childpid;
        int status;
        // Build argv[]
        Strings argv;
        const(char)* cc = getenv("CC");
        if (!cc)
            cc = "gcc";
        argv.push(cc);
        argv.insert(1, global.params.objfiles);
        version (OSX)
        {
            // If we are on Mac OS X and linking a dynamic library,
            // add the "-dynamiclib" flag
            if (global.params.dll)
                argv.push("-dynamiclib");
        }
        else static if (__linux__ || __FreeBSD__ || __OpenBSD__ || __sun)
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
                    error(Loc(), "error creating temporary file");
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
            const(char)* n = (*global.params.objfiles)[0];
            char* ex;
            n = FileName.name(n);
            const(char)* e = FileName.ext(n);
            if (e)
            {
                e--; // back up over '.'
                ex = cast(char*)mem.xmalloc(e - n + 1);
                memcpy(ex, n, e - n);
                ex[e - n] = 0;
                // If generating dll then force dll extension
                if (global.params.dll)
                    ex = cast(char*)FileName.forceExt(ex, global.dll_ext);
            }
            else
                ex = cast(char*)"a.out"; // no extension, so give up
            argv.push(ex);
            global.params.exefile = ex;
        }
        // Make sure path to exe file exists
        ensurePathToNameExists(Loc(), global.params.exefile);
        if (global.params.symdebug)
            argv.push("-g");
        if (global.params.is64bit)
            argv.push("-m64");
        else
            argv.push("-m32");
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
        for (size_t i = 0; i < global.params.linkswitches.dim; i++)
        {
            const(char)* p = (*global.params.linkswitches)[i];
            if (!p || !p[0] || !(p[0] == '-' && (p[1] == 'l' || p[1] == 'L')))
            {
                // Don't need -Xlinker if switch starts with -l or -L.
                // Eliding -Xlinker is significant for -L since it allows our paths
                // to take precedence over gcc defaults.
                argv.push("-Xlinker");
            }
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
        for (size_t i = 0; i < global.params.libfiles.dim; i++)
        {
            const(char)* p = (*global.params.libfiles)[i];
            size_t plen = strlen(p);
            if (plen > 2 && p[plen - 2] == '.' && p[plen - 1] == 'a')
                argv.push(p);
            else
            {
                char* s = cast(char*)mem.xmalloc(plen + 3);
                s[0] = '-';
                s[1] = 'l';
                memcpy(s + 2, p, plen + 1);
                argv.push(s);
            }
        }
        for (size_t i = 0; i < global.params.dllfiles.dim; i++)
        {
            const(char)* p = (*global.params.dllfiles)[i];
            argv.push(p);
        }
        /* Standard libraries must go after user specified libraries
         * passed with -l.
         */
        const(char)* libname = global.params.symdebug ? global.params.debuglibname : global.params.defaultlibname;
        size_t slen = strlen(libname);
        if (slen)
        {
            char* buf = cast(char*)malloc(3 + slen + 1);
            strcpy(buf, "-l");
            /* Use "-l:libname.a" if the library name is complete
             */
            if (slen > 3 + 2 && memcmp(libname, cast(char*)"lib", 3) == 0 && (memcmp(libname + slen - 2, cast(char*)".a", 2) == 0 || memcmp(libname + slen - 3, cast(char*)".so", 3) == 0))
            {
                strcat(buf, ":");
            }
            strcat(buf, libname);
            argv.push(buf); // turns into /usr/lib/libphobos2.a
        }
        //    argv.push("-ldruntime");
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
            for (size_t i = 0; i < argv.dim; i++)
                fprintf(global.stdmsg, "%s ", argv[i]);
            fprintf(global.stdmsg, "\n");
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
            execvp(argv[0], cast(char**)argv.tdata());
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
                    printf("--- errorlevel %d\n", status);
                    if (nme == 1)
                        error(Loc(), "no main function specified");
                }
            }
        }
        else if (WIFSIGNALED(status))
        {
            printf("--- killed by signal %d\n", WTERMSIG(status));
            status = 1;
        }
        return status;
    }
    else
    {
        printf("Linking is not yet supported for this version of DMD.\n");
        return -1;
    }
}

/**********************************
 * Delete generated EXE file.
 */
extern (C++) void deleteExeFile()
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
 */
version (Windows)
{
    extern (C++) int executecmd(const(char)* cmd, const(char)* args)
    {
        int status;
        size_t len;
        if (global.params.verbose)
            fprintf(global.stdmsg, "%s %s\n", cmd, args);
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
                    error(Loc(), "command line length of %d is too long", len);
                }
            }
        }
        // Normalize executable path separators, see Bugzilla 9330
        cmd = toWinPath(cmd);
        version (CRuntime_Microsoft)
        {
            if (strchr(cmd, ' '))
            {
                // MSVCRT: spawn does not work with spaces in the executable
                size_t cmdlen = strlen(cmd);
                char* shortName = (new char[](cmdlen + 1)).ptr; // enough space
                uint plen = GetShortPathNameA(cmd, shortName, cast(uint)cmdlen + 1);
                if (plen > 0 && plen <= cmdlen)
                    cmd = shortName;
            }
        }
        status = executearg0(cmd, args);
        if (status == -1)
        {
            // spawnlp returns intptr_t in some systems, not int
            status = spawnlp(0, cmd, cmd, args, null);
        }
        //    if (global.params.verbose)
        //      fprintf(global.stdmsg, "\n");
        if (status)
        {
            if (status == -1)
                printf("Can't run '%s', check PATH\n", cmd);
            else
                printf("--- errorlevel %d\n", status);
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
    extern (C++) int executearg0(const(char)* cmd, const(char)* args)
    {
        const(char)* file;
        const(char)* argv0 = global.params.argv0;
        //printf("argv0='%s', cmd='%s', args='%s'\n",argv0,cmd,args);
        // If cmd is fully qualified, we don't do this
        if (FileName.absolute(cmd))
            return -1;
        file = FileName.replaceName(argv0, cmd);
        //printf("spawning '%s'\n",file);
        // spawnlp returns intptr_t in some systems, not int
        return spawnl(0, file, file, args, null);
    }
}

/***************************************
 * Run the compiled program.
 * Return exit status.
 */
extern (C++) int runProgram()
{
    //printf("runProgram()\n");
    if (global.params.verbose)
    {
        fprintf(global.stdmsg, "%s", global.params.exefile);
        for (size_t i = 0; i < global.params.runargs.dim; ++i)
            fprintf(global.stdmsg, " %s", global.params.runargs[i]);
        fprintf(global.stdmsg, "\n");
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
    else static if (__linux__ || __APPLE__ || __FreeBSD__ || __OpenBSD__ || __sun)
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
            execv(fn, cast(char**)argv.tdata());
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
            printf("--- killed by signal %d\n", WTERMSIG(status));
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
    /*****************************
     * Detect whether the link will grab libraries from VS 2015 or later
     */
    extern (C++) bool detectVS14(const(char)* cmdline)
    {
        auto libpaths = new Strings();
        // grab library folders passed on the command line
        for (const(char)* p = cmdline; *p;)
        {
            while (isspace(*p))
                p++;
            const(char)* arg = p;
            const(char)* end = arg;
            while (*end && !isspace(*end))
            {
                end++;
                if (end[-1] == '"')
                {
                    while (*end && *end != '"')
                    {
                        if (*end == '\\' && end[1])
                            end++;
                        end++;
                    }
                    if (*end)
                        end++; // skip closing quote
                }
            }
            p = end;
            // remove quotes if spanning complete argument
            if (end > arg + 1 && arg[0] == '"' && end[-1] == '"')
            {
                arg++;
                end--;
            }
            if (arg[0] == '-' || arg[0] == '/')
            {
                if (end - arg > 8 && memicmp(arg + 1, "LIBPATH:", 8) == 0)
                {
                    arg += 9;
                    char* q = cast(char*)memcpy((new char[](end - arg + 1)).ptr, arg, end - arg);
                    q[end - arg] = 0;
                    Strings* paths = FileName.splitPath(q);
                    libpaths.append(paths);
                }
            }
        }
        // append library paths from environment
        if (const(char)* lib = getenv("LIB"))
            libpaths.append(FileName.splitPath(lib));
        // if legacy_stdio_definitions.lib can be found in the same folder as
        // libcmt.lib, libcmt.lib is assumed to be from VS2015 or later
        const(char)* libcmt = FileName.searchPath(libpaths, "libcmt.lib", true);
        if (!libcmt)
            return false;
        const(char)* liblegacy = FileName.replaceName(libcmt, "legacy_stdio_definitions.lib");
        return FileName.exists(liblegacy) == 1;
    }
}
