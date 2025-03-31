/**
 * Invoke the linker as a separate process.
 *
 * Copyright:   Copyright (C) 1999-2025 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/link.d, _link.d)
 * Documentation:  https://dlang.org/phobos/dmd_link.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/link.d
 */

module dmd.link;

import core.stdc.ctype;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.astenums;
import dmd.compiler : includeImports;
import dmd.dmdparams;
import dmd.errors;
import dmd.errorsink;
import dmd.globals;
import dmd.location;
import dmd.root.array;
import dmd.root.env;
import dmd.root.file;
import dmd.root.filename;
import dmd.common.outbuffer;
import dmd.common.smallbuffer;
import dmd.root.rmem;
import dmd.root.string;
import dmd.utils;
import dmd.target;

version (Posix)
{
    import core.sys.posix.stdio;
    import core.sys.posix.stdlib;
    import core.sys.posix.unistd;

    extern (C)
    {
        int pipe(int*);
        pid_t vfork(); // work around lack of 'vfork' in older druntime binding for non-Glibc
    }
}
else version (Windows)
{
    import core.sys.windows.windows;
    import core.sys.windows.wtypes;
    import core.sys.windows.psapi;
    import core.sys.windows.winbase;
    import core.sys.windows.windef;
    import dmd.vsoptions;

    /* https://www.digitalmars.com/rtl/process.html#_spawn
     * https://docs.microsoft.com/en-us/cpp/c-runtime-library/reference/spawnvp-wspawnvp?view=msvc-170
     */
    extern (C)
    {
        int spawnlp(int, const char*, const char*, const char*, const char*);
        int spawnl(int, const char*, const char*, const char*, const char*);
        int spawnv(int, const char*, const char**);
        int spawnvp(int, const char*, const char**);
        enum _P_WAIT = 0;
    }

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
else
    static assert(0, "unsupported operating system");

version (Posix)
{
    /*****************************
     * Extract stderr piped through `fd` into OutBuffer `o` so it can be parsed for better error messages.
     *
     * Returns: `true` on success, `false` on IO error
     */
    private bool pipeProcessOutput(int fd, ref OutBuffer o)
    {
        FILE* stream = fdopen(fd, "r");
        if (stream is null)
            return false;
        const(size_t) len = 64 * 1024 - 1;
        char[len + 1] buffer = '\0'; // + '\0'
        size_t beg = 0, end = len;
        for (;;)
        {
            // read linker output
            const(size_t) n = fread(&buffer[beg], 1, len - beg, stream);
            if (beg + n < len && ferror(stream))
                return false;
            end = beg + n;

            o.writestring(buffer[0 .. end]);
            if (fwrite(&buffer[0], char.sizeof, end, stderr) < end)
                return false;
            if (beg + n < len && feof(stream))
                break;
            // copy over truncated last line
            memcpy(&buffer[0], &buffer[end], (beg = len - end));
        }
        return true;
    }
}

version (Windows)
{
    private void writeQuotedArgIfNeeded(ref OutBuffer buffer, const(char)* arg)
    {
        bool quote = false;
        for (size_t i = 0; arg[i]; ++i)
        {
            if (arg[i] == '"')
            {
                quote = false;
                break;
            }

            if (arg[i] == ' ')
                quote = true;
        }

        if (quote)
            buffer.writeByte('"');
        buffer.writestring(arg);
        if (quote)
            buffer.writeByte('"');
    }

    unittest
    {
        OutBuffer buffer;

        const(char)[] test(string arg)
        {
            buffer.reset();
            buffer.writeQuotedArgIfNeeded(arg.ptr);
            return buffer[];
        }

        assert(test("arg") == `arg`);
        assert(test("arg with spaces") == `"arg with spaces"`);
        assert(test(`"/LIBPATH:dir with spaces"`) == `"/LIBPATH:dir with spaces"`);
        assert(test(`/LIBPATH:"dir with spaces"`) == `/LIBPATH:"dir with spaces"`);
    }
}

enum STATUS_FAILED = -1;

/*****************************
 * Run the linker.
 * Params:
 *      verbose = print command to be executed
 *      eSink = message sink
 *  Returns: status of execution. STATUS_FAILED if failed for other reasons
 */
public int runLINK(bool verbose, ErrorSink eSink)
{
    const phobosLibname = finalDefaultlibname();

    void setExeFile()
    {
        /* Generate exe file name from first obj name.
         * No need to add it to cmdbuf because the linker will default to it.
         */
        const char[] n = FileName.name(global.params.objfiles[0].toDString);
        global.params.exefile = FileName.forceExt(n, "exe");
    }

    const(char)[] getMapFilename()
    {
        const(char)[] fn = FileName.forceExt(global.params.exefile, map_ext);
        const(char)[] path = FileName.path(global.params.exefile);
        return path.length ? fn : FileName.combine(global.params.objdir, fn);
    }

    version (Windows)
    {
        if (phobosLibname)
            global.params.libfiles.push(phobosLibname.xarraydup.ptr);

        if (target.objectFormat() == Target.ObjectFormat.coff)
        {
            OutBuffer cmdbuf;
            cmdbuf.writestring("/NOLOGO");
            for (size_t i = 0; i < global.params.objfiles.length; i++)
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
                setExeFile();
            }
            // Make sure path to exe file exists
            if (!ensurePathToNameExists(Loc.initial, global.params.exefile))
                return STATUS_FAILED;
            cmdbuf.writeByte(' ');
            if (global.params.mapfile)
            {
                cmdbuf.writestring("/MAP:");
                writeFilename(&cmdbuf, global.params.mapfile);
            }
            else if (driverParams.map)
            {
                cmdbuf.writestring("/MAP:");
                writeFilename(&cmdbuf, getMapFilename());
            }
            for (size_t i = 0; i < global.params.libfiles.length; i++)
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
            if (driverParams.symdebug)
            {
                cmdbuf.writeByte(' ');
                cmdbuf.writestring("/DEBUG");
                // in release mode we need to reactivate /OPT:REF after /DEBUG
                if (global.params.release)
                    cmdbuf.writestring(" /OPT:REF");
            }
            if (driverParams.dll)
            {
                cmdbuf.writeByte(' ');
                cmdbuf.writestring("/DLL");
            }
            for (size_t i = 0; i < global.params.linkswitches.length; i++)
            {
                cmdbuf.writeByte(' ');
                cmdbuf.writeQuotedArgIfNeeded(global.params.linkswitches[i]);
            }

            VSOptions vsopt;
            // if a runtime library (msvcrtNNN.lib) from the mingw folder is selected explicitly, do not detect VS and use lld
            if (driverParams.mscrtlib.length <= 6 ||
                driverParams.mscrtlib[0..6] != "msvcrt" || !isdigit(driverParams.mscrtlib[6]))
                vsopt.initialize();

            const(char)* linkcmd = getenv(target.isX86_64 ? "LINKCMD64" : "LINKCMD");
            if (!linkcmd)
                linkcmd = getenv("LINKCMD"); // backward compatible
            if (!linkcmd)
                linkcmd = vsopt.linkerPath(target.isX86_64);

            if (target.isX86 && FileName.equals(FileName.name(linkcmd), "lld-link.exe"))
            {
                // object files not SAFESEH compliant, but LLD is more picky than MS link
                cmdbuf.writestring(" /SAFESEH:NO");
                // if we are using LLD as a fallback, don't link to any VS libs even if
                // we detected a VS installation and they are present
                vsopt.uninitialize();
            }

            if (const(char)* lflags = vsopt.linkOptions(target.isX86_64))
            {
                cmdbuf.writeByte(' ');
                cmdbuf.writestring(lflags);
            }

            cmdbuf.writeByte(0); // null terminate the buffer
            char[] p = cmdbuf.extractSlice()[0 .. $-1];
            const(char)[] lnkfilename;
            if (p.length > 7000)
            {
                lnkfilename = FileName.forceExt(global.params.exefile, "lnk");
                if (!writeFile(Loc.initial, lnkfilename, p))
                    return STATUS_FAILED;
                if (lnkfilename.length < p.length)
                {
                    p[0] = '@';
                    p[1 ..  lnkfilename.length +1] = lnkfilename;
                    p[lnkfilename.length +1] = 0;
                }
            }

            OutBuffer buf;
            const int status = executecmd(linkcmd, p.ptr, verbose, eSink, buf);
            if (lnkfilename)
            {
                lnkfilename.toCStringThen!(lf => remove(lf.ptr));
                FileName.free(lnkfilename.ptr);
            }
            parseLinkerOutput(cast(const(char)[]) buf.peekSlice(), new ErrorSinkCompiler(), global.params.betterC, includeImports);
            return status;
        }
        else
        {
            assert(0);
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
            char* arg = cast(char*)Mem.check(strdup(cc));
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
            if (driverParams.dll)
                argv.push("-dynamiclib");
        }
        else version (Posix)
        {
            if (driverParams.dll)
                argv.push("-shared");
        }
        // None of that a.out stuff. Use explicit exe file name, or
        // generate one from name of first source file.
        argv.push("-o");
        if (global.params.exefile)
        {
            argv.push(global.params.exefile.xarraydup.ptr);
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
                    eSink.error(Loc.initial, "error creating temporary file");
                    return 1;
                }
                else
                    close(fd);
                global.params.exefile = name.arraydup;
                argv.push(global.params.exefile.xarraydup.ptr);
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
                if (driverParams.dll)
                    ex = FileName.forceExt(ex, target.dll_ext);
                else
                    ex = FileName.removeExt(n);
            }
            else
                ex = "a.out"; // no extension, so give up
            argv.push(ex.ptr);
            global.params.exefile = ex;
        }
        // Make sure path to exe file exists
        if (!ensurePathToNameExists(Loc.initial, global.params.exefile))
            return STATUS_FAILED;
        if (driverParams.symdebug)
            argv.push("-g");
        if (target.isX86_64)
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
        if (driverParams.map || global.params.mapfile.length)
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
            if (!global.params.mapfile.length)
            {
                const(char)[] fn = FileName.forceExt(global.params.exefile, map_ext);
                const(char)[] path = FileName.path(global.params.exefile);
                global.params.mapfile = path.length ? fn : FileName.combine(global.params.objdir, fn);
            }
            argv.push("-Xlinker");
            argv.push(global.params.mapfile.xarraydup.ptr);
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
        static bool flagIsLibraryRelated(const char* p)
        {
            const flag = p.toDString();

            return startsWith(p, "-l") || startsWith(p, "-L")
                || flag == "-(" || flag == "-)"
                || flag == "--start-group" || flag == "--end-group"
                || FileName.equalsExt(p, "a")
            ;
        }

        /* Add libraries. The order of libraries passed is:
         *  1. link switches without a -L prefix,
               e.g. --whole-archive "lib.a" --no-whole-archive     (global.params.linkswitches)
         *  2. static libraries ending with *.a     (global.params.libfiles)
         *  3. link switches with a -L prefix  (global.params.linkswitches)
         *  4. libraries specified by pragma(lib), which were appended
         *     to global.params.libfiles. These are prefixed with "-l"
         *  5. dynamic libraries passed to the command line (global.params.dllfiles)
         *  6. standard libraries.
         */

        // STEP 1
        foreach (pi, p; global.params.linkswitches)
        {
            if (p && p[0] && !flagIsLibraryRelated(p))
            {
                if (!global.params.linkswitchIsForCC[pi])
                    argv.push("-Xlinker");
                argv.push(p);
            }
        }

        // STEP 2
        foreach (p; global.params.libfiles)
        {
            if (FileName.equalsExt(p, "a"))
                argv.push(p);
        }

        // STEP 3
        foreach (pi, p; global.params.linkswitches)
        {
            if (p && p[0] && flagIsLibraryRelated(p))
            {
                if (!startsWith(p, "-l") && !startsWith(p, "-L") && !global.params.linkswitchIsForCC[pi])
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

        // STEP 4
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

        // STEP 5
        foreach (p; global.params.dllfiles)
        {
            argv.push(p);
        }

        // STEP 6
        /* D runtime libraries must go after user specified libraries
         * passed with -l.
         */
        const libname = phobosLibname;
        if (libname.length)
        {
            const bufsize = 2 + libname.length + 1;
            auto buf = (cast(char*) malloc(bufsize))[0 .. bufsize];
            Mem.check(buf.ptr);
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
        else version (OpenBSD)
        {
            // Link against -lc++abi for Unwind symbols
            argv.push("-lc++abi");
            // Link against -lexecinfo for backtrace symbols
            argv.push("-lexecinfo");
        }
        OutBuffer buf;
        foreach (i; 0 .. argv.length)
        {
            buf.writestring(argv[i]);
            buf.writeByte(' ');
        }
        const(char)* linkerCommand = buf.peekChars();

        if (verbose)
            eSink.message(Loc.initial, "%s", linkerCommand);

        argv.push(null);
        // set up pipes
        int[2] fds;
        if (pipe(fds.ptr) == -1)
        {
            perror("unable to create pipe to linker");
            return -1;
        }
        // vfork instead of fork to avoid https://issues.dlang.org/show_bug.cgi?id=21089
        childpid = vfork();
        if (childpid == 0)
        {
            // pipe linker stderr to fds[0]
            dup2(fds[1], STDERR_FILENO);
            close(fds[0]);
            execvp(argv[0], argv.tdata());
            perror(argv[0]); // failed to execute
            _exit(-1);
        }
        else if (childpid == -1)
        {
            perror("unable to fork");
            return STATUS_FAILED;
        }
        close(fds[1]);
        OutBuffer outputBuf;
        const pipeSuccess = pipeProcessOutput(fds[0], outputBuf);

        ///
        waitpid(childpid, &status, 0);
        if (WIFEXITED(status))
        {
            status = WEXITSTATUS(status);
            if (status)
            {
                if (!pipeSuccess)
                {
                    perror("error with the linker pipe");
                    return -1;
                }
                else
                {
                    parseLinkerOutput(cast(const(char)[]) outputBuf.peekSlice(), new ErrorSinkCompiler(), global.params.betterC, includeImports);
                    eSink.error(Loc.initial, "linker exited with status %d", status);
                    eSink.errorSupplemental(Loc.initial, "%s", linkerCommand);
                }
            }
        }
        else if (WIFSIGNALED(status))
        {
            eSink.error(Loc.initial, "linker killed by signal %d", WTERMSIG(status));
            status = 1;
        }
        return status;
    }
    else
    {
        eSink.error(Loc.initial, "linking is not yet supported for this version of DMD.");
        return -1;
    }
}


/******************************
 * Execute a rule.
 * Params:
 *      cmd =   program to run
 *      args =  arguments to cmd, as a string
 *      verbose = print command to be executed
 *      eSink = message sink
 * Returns:
 *      the status
 */
version (Windows)
{
    private int executecmd(const(char)* cmd, const(char)* args, bool verbose, ErrorSink eSink, ref OutBuffer buf)
    {
        int status;
        if (verbose)
            eSink.message(Loc.initial, "%s %s", cmd, args);
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

                HANDLE[2] pipe;
                SECURITY_ATTRIBUTES saAttr;
                saAttr.nLength = SECURITY_ATTRIBUTES.sizeof;
                saAttr.bInheritHandle = true;
                saAttr.lpSecurityDescriptor = null;
                if (!CreatePipe(&pipe[0], &pipe[1], &saAttr, /*buffer size suggestion*/ 0))
                {
                    GetLastError();
                }
                if (!SetHandleInformation(pipe[0], /*mask*/ HANDLE_FLAG_INHERIT, /*flags*/ 0))
                {
                    GetLastError();
                }

                STARTUPINFOA startInf;
                startInf.cb = startInf.sizeof;
                startInf.dwFlags = STARTF_USESTDHANDLES;
                startInf.hStdInput = GetStdHandle(STD_INPUT_HANDLE);
                startInf.hStdOutput = pipe[1];
                startInf.hStdError = GetStdHandle(STD_ERROR_HANDLE);
                PROCESS_INFORMATION procInf;

                BOOL b = CreateProcessA(null, cmdbuf.peekChars(), null, null, 1, NORMAL_PRIORITY_CLASS, null, null, &startInf, &procInf);
                CloseHandle(pipe[1]); // child does not need this end

                ubyte[1024] buffer;
                DWORD bytesRead;
                for (;;)
                {
                    if (ReadFile(pipe[0], buffer.ptr, buffer.length, &bytesRead, /*lpOverlapped*/ null))
                    {
                        fwrite(buffer.ptr, bytesRead, ubyte.sizeof, stderr);
                        buf.write(buffer[0 .. bytesRead]);
                    }
                    else
                        break;
                }

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
                eSink.error(Loc.initial, "can't run '%s', check PATH", cmd);
            else
            {
                eSink.error(Loc.initial, "linker exited with status %d", status);
                errorSupplemental(Loc.initial, "%s %s", cmd, args);
            }
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
        if (FileName.absolute(cmd.toDString()))
            return -1;
        const file = FileName.replaceName(argv0, cmd.toDString);
        //printf("spawning '%s'\n",file);
        // spawnlp returns intptr_t in some systems, not int
        return spawnl(0, file.ptr, file.ptr, args, null);
    }
}

/***************************************
 * Run the compiled program.
 * Params:
 *      exefile = program name
 *      runargs = arguments to exefile
 *      verbose = print command to be executed
 *      eSink = message sink
 * Returns: exit status
 */
public int runProgram(const char[] exefile, const char*[] runargs, bool verbose, ErrorSink eSink)
{
    //printf("runProgram()\n");

    // print command line to user
    if (verbose)
    {
        OutBuffer buf;
        buf.writestring(exefile);
        foreach (arg; runargs)
        {
            buf.writeByte(' ');
            buf.writestring(arg);
        }
        eSink.message(Loc.initial, buf.peekChars());
    }

    // Build argv[]
    Strings argv;
    argv.push(exefile.xarraydup.ptr);
    foreach (arg; runargs)
    {
        version (Windows)
        {
            // BUG: what about " appearing in the string?
            if (strchr(arg, ' '))
            {
                const blen = 3 + strlen(arg);
                char* b = cast(char*)mem.xmalloc(blen);
                snprintf(b, blen, "\"%s\"", arg);
                argv.push(b);
                continue;
            }
        }
        argv.push(arg);
    }
    argv.push(null);

    // Execute program
    version (Windows)
    {
        const(char)[] ex = FileName.name(exefile);
        if (ex == exefile)
            ex = FileName.combine(".", ex);
        else
            ex = exefile;
        // spawnlp returns intptr_t in some systems, not int
        return spawnv(0, ex.xarraydup.ptr, argv.tdata());
    }
    else version (Posix)
    {
        pid_t childpid;
        int status;
        childpid = fork();
        if (childpid == 0)
        {
            const(char)[] fn = argv[0].toDString();
            // Make it "./fn" if needed
            if (!FileName.absolute(fn))
                fn = FileName.combine(".", fn);
            fn.toCStringThen!((fnp) {
                    execv(fnp.ptr, argv.tdata());
                    // If execv returns, it failed to execute
                    perror(fnp.ptr);
                });
            _exit(-1);
        }
        waitpid(childpid, &status, 0);
        if (WIFEXITED(status))
        {
            status = WEXITSTATUS(status);
            //printf("--- errorlevel %d\n", status);
        }
        else if (WIFSIGNALED(status))
        {
            eSink.error(Loc.initial, "program killed by signal %d", WTERMSIG(status));
            status = 1;
        }
        return status;
    }
    else
    {
        assert(0);
    }
}

/***************************************
 * Run the C preprocessor.
 * Params:
 *    loc = source location where preprocess is requested from
 *    cpp = name of C preprocessor program
 *    filename = C source file name
 *    importc_h = filename of importc.h
 *    cppswitches = array of switches to pass to C preprocessor
 *    verbose = print progress to eSink
 *    eSink = for verbose messages and error messages
 *    defines = buffer to append any `#define` and `#undef` lines encountered to
 *    text = set to preprocessed text
 * Returns:
 *    error status, 0 for success
 */
public int runPreprocessor(Loc loc, const(char)[] cpp, const(char)[] filename, const(char)* importc_h, ref Array!(const(char)*) cppswitches,
    bool verbose, ErrorSink eSink, ref OutBuffer defines, out DArray!ubyte text)
{
    //printf("runPreprocessor() cpp: %.*s filename: %.*s\n", cast(int)cpp.length, cpp.ptr, cast(int)filename.length, filename.ptr);

    version (Windows)
    {
        // generate unique temporary file name for preprocessed output
        const(char)* tmpname = tmpnam(null);
        assert(tmpname);
        const(char)[] ifilename = tmpname[0 .. strlen(tmpname) + 1];
        ifilename = xarraydup(ifilename);
        const(char)[] output = ifilename;

        int returnResult(int status)
        {
            if (status)
            {
                eSink.error(loc, "C preprocess command %.*s failed for file %s, exit status %d\n",
                    cast(int)cpp.length, cpp.ptr, filename.ptr, status);
                return STATUS_FAILED;
            }
            //printf("C preprocess succeeded %s\n", ifilename.ptr);
            OutBuffer buf;
            auto readResult = File.read(ifilename, buf);
            File.remove(ifilename.ptr);
            Mem.xfree(cast(void*)ifilename.ptr);
            if (readResult)
                return STATUS_FAILED;
            text = DArray!ubyte(cast(ubyte[])buf.extractSlice(true));
            return 0;
        }

        // Build argv[]
        Strings argv;
        if (target.objectFormat() == Target.ObjectFormat.coff)
        {
            static if (1)
            {
                /* Run command, intercept stdout, remove first line that CL insists on emitting
                 */
                OutBuffer buf;
                buf.writestring(cpp);
                buf.printf(" /P /Zc:preprocessor /PD /nologo /utf-8 %.*s /FI%s /Fi%.*s",
                    cast(int)filename.length, filename.ptr, importc_h, cast(int)output.length, output.ptr);

                /* Append preprocessor switches to command line
                 */
                foreach (a; cppswitches)
                {
                    if (a && a[0])
                    {
                        buf.writeByte(' ');
                        buf.writestring(a);
                    }
                }

                if (verbose)
                    eSink.message(Loc.initial, buf.peekChars());

                ubyte[2048] buffer = void;

                OutBuffer linebuf;      // each line from stdout
                bool print = false;     // print line collected from stdout

                /* Collect text captured from stdout to linebuf[].
                 * Then decide to print or discard the contents.
                 * Discarding lines that consist only of a filename is necessary to pass
                 * the D test suite which diffs the output. CL's emission of filenames cannot
                 * be turned off.
                 */
                void sink(ubyte[] data)
                {
                    foreach (c; data)
                    {
                        switch (c)
                        {
                            case '\r':
                                break;

                            case '\n':
                                if (print)
                                    printf("%s\n", linebuf.peekChars());

                                // set up for next line
                                linebuf.setsize(0);
                                print = false;
                                break;

                            case '\t':
                            case ';':
                            case '(':
                            case '\'':
                            case '"':   // various non-filename characters
                                print = true; // mean it's not a filename
                                goto default;

                            default:
                                linebuf.writeByte(c);
                                break;
                        }
                    }
                }

                // Convert command to wchar
                wchar[1024] scratch = void;
                auto smbuf = SmallBuffer!wchar(scratch.length, scratch[]);

                // INCLUDE
                static VSOptions vsopt; // cache, as this can be expensive
                static Strings includePaths;
                if (includePaths.length == 0)
                {
                    if (!vsopt.VSInstallDir)
                        vsopt.initialize();

                    if (auto vcincludedir = vsopt.getVCIncludeDir())
                        includePaths.push(vcincludedir);
                    else
                        return STATUS_FAILED;

                    if (auto sdkincludedir = vsopt.getSDKIncludePath())
                    {
                        includePaths.push(FileName.combine(sdkincludedir, "ucrt"));
                        includePaths.push(FileName.combine(sdkincludedir, "shared"));
                        includePaths.push(FileName.combine(sdkincludedir, "um"));
                        includePaths.push(FileName.combine(sdkincludedir, "winrt"));
                        includePaths.push(FileName.combine(sdkincludedir, "cppwinrt"));
                    }
                    else
                    {
                        includePaths = Strings.init;
                        return STATUS_FAILED;
                    }
                }

                // Get current environment variable and rollback
                auto oldIncludePathLen = GetEnvironmentVariableW("INCLUDE"w.ptr, null, 0);
                wchar* oldIncludePaths = cast(wchar*)mem.xmalloc(oldIncludePathLen * wchar.sizeof);
                oldIncludePathLen = GetEnvironmentVariableW("INCLUDE"w.ptr, oldIncludePaths, oldIncludePathLen);
                scope (exit)
                {
                    SetEnvironmentVariableW("INCLUDE"w.ptr, oldIncludePaths);
                    mem.xfree(oldIncludePaths);
                }

                // Make new environment variable
                OutBuffer envbuf;
                foreach (inc; includePaths[])
                {
                    if (FileName.exists(inc) == 2)
                    {
                        envbuf.write(cast(const ubyte[])toWStringz(inc[0..strlen(inc)], smbuf));
                        envbuf.writewchar(';');
                    }
                }
                envbuf.write(cast(const ubyte[])oldIncludePaths[0..oldIncludePathLen]);
                envbuf.writewchar('\0');
                // Temporarily set INCLUDE environment variable
                SetEnvironmentVariableW("INCLUDE"w.ptr, cast(LPCWSTR)envbuf.buf);

                auto szCommand = toWStringz(buf.peekChars()[0 .. buf.length], smbuf);

                int exitCode = runProcessCollectStdout(szCommand.ptr, buffer[], &sink);

                if (linebuf.length && print)  // anything leftover from stdout collection
                    printf("%s\n", defines.peekChars());

                return returnResult(exitCode);
            }
            else
            {
                argv.push("cl".ptr);            // null terminated copy
                argv.push("/P".ptr);            // preprocess only
                argv.push("/nologo".ptr);       // don't print logo
                argv.push(filename.xarraydup.ptr);   // and the input

                OutBuffer buf;
                buf.writestring("/Fi");       // https://docs.microsoft.com/en-us/cpp/build/reference/fi-preprocess-output-file-name?view=msvc-170
                buf.writeStringz(output);
                argv.push(buf.extractData()); // output file

                argv.push(null);                     // argv[] always ends with a null
                // spawnlp returns intptr_t in some systems, not int
                auto exitCode = spawnvp(_P_WAIT, "cl".ptr, argv.tdata());
                return returnResult(exitCode);
            }
        }
        else
        {
            assert(0);
        }
    }
    else version (Posix)
    {
        // Build argv[]
        Strings argv;
        argv.push(cpp.xarraydup.ptr);       // null terminated copy

        foreach (p; cppswitches)
        {
            if (p && p[0])
                argv.push(p);
        }

        // Set memory model
        argv.push(target.isX86_64 ? "-m64" : "-m32");

        // merge #define's with output
        argv.push("-dD");       // https://gcc.gnu.org/onlinedocs/cpp/Invocation.html#index-dD

        // need to redefine some macros in importc.h
        argv.push("-Wno-builtin-macro-redefined");

        if (target.os == Target.OS.OSX)
        {
            argv.push("-fno-blocks");       // disable clang blocks extension
            argv.push("-E");                // run preprocessor only for clang
            argv.push("-include");          // OSX cpp has switch order dependencies
            argv.push(importc_h);
            argv.push(filename.xarraydup.ptr);  // and the input
        }
        else
        {
            argv.push(filename.xarraydup.ptr);  // and the input
            argv.push("-include");
            argv.push(importc_h);
        }
        argv.push(null);                    // argv[] always ends with a null

        if (verbose)
        {
            OutBuffer buf;

            foreach (i, a; argv[])
            {
                if (a)
                {
                    if (i)
                        buf.writeByte(' ');
                    buf.writestring(a);
                }
            }
            eSink.message(Loc.initial, buf.peekChars());
        }

        // pipe so we can read the output of the preprocssor
        int[2] pipefd;      // [0] is read, [1] is write
        if (pipe(&pipefd[0]) == -1)
        {
            perror("pipe");     // failed to create pipe
            return STATUS_FAILED;
        }

        pid_t childpid = fork();
        if (childpid == -1)
        {
            perror("fork failed");     // fork failed
            return STATUS_FAILED;
        }

        if (childpid == 0)
        {   // we're in the child process which will fork the preprocessor
            close(pipefd[0]);  // don't need read
            dup2(pipefd[1], STDOUT_FILENO);  // stdout to our pipe

            const(char)[] fn = argv[0].toDString();
            fn.toCStringThen!((fnp) {
                    execvp(fnp.ptr, argv.tdata());
                    perror(fnp.ptr);   // execv returned, so it must have failed
                    _exit(-1);
                });
            _exit(-1);
        }

        // Read the stdout from the preprocessor and append it to buffer
        close(pipefd[1]);  // don't need write
        OutBuffer buffer;
        ubyte[1024] tmp = void;
        ptrdiff_t nread;
        while ((nread = read(pipefd[0], tmp.ptr, tmp.length)) > 0)
            buffer.write(tmp[0 .. nread]);

        if (nread == -1)
        {
            perror("read");
            return STATUS_FAILED;
        }

        int status;
        waitpid(childpid, &status, 0);
        if (WIFEXITED(status))
        {
            status = WEXITSTATUS(status);
            //printf("--- errorlevel %d\n", status);
        }
        else if (WIFSIGNALED(status))
        {
            eSink.error(Loc.initial, "program killed by signal %d", WTERMSIG(status));
            status = 1;
        }

        if (status)
        {
            eSink.error(loc, "C preprocess command %.*s failed for file %s, exit status %d\n",
                cast(int)cpp.length, cpp.ptr, filename.ptr, status);
            return STATUS_FAILED;
        }

        text = DArray!ubyte(cast(ubyte[])buffer.extractSlice(true));
        return 0;
    }
    else
    {
        assert(0);
    }
}

/*********************************
 * Run a command and intercept its stdout, which is redirected
 * to sink().
 * Params:
 *      szCommand = command to run
 *      buffer = buffer to collect stdout data to
 *      sink = stdout data is sent to sink()
 * Returns:
 *      0 on success
 * Reference:
 *      Based on
 *      https://github.com/dlang/visuald/blob/master/tools/pipedmd.d#L252
 */
version (Windows)
int runProcessCollectStdout(const(wchar)* szCommand, ubyte[] buffer, void delegate(ubyte[]) sink)
{
    //printf("runProcess() command: %ls\n", szCommand);
    // Set the bInheritHandle flag so pipe handles are inherited.
    SECURITY_ATTRIBUTES saAttr;
    saAttr.nLength = SECURITY_ATTRIBUTES.sizeof;
    saAttr.bInheritHandle = TRUE;
    saAttr.lpSecurityDescriptor = null;

    // Create a pipe for the child process's STDOUT.
    HANDLE hStdOutRead;
    HANDLE hStdOutWrite;
    if ( !CreatePipe(&hStdOutRead, &hStdOutWrite, &saAttr, 0) )
            assert(0);
    // Ensure the read handle to the pipe for STDOUT is not inherited.
    if ( !SetHandleInformation(hStdOutRead, HANDLE_FLAG_INHERIT, 0) )
            assert(0);

    // Another pipe
    HANDLE hStdInRead;
    HANDLE hStdInWrite;
    if ( !CreatePipe(&hStdInRead, &hStdInWrite, &saAttr, 0) )
            assert(0);
    if ( !SetHandleInformation(hStdInWrite, HANDLE_FLAG_INHERIT, 0) )
            assert(0);

    // Set up members of the PROCESS_INFORMATION structure.
    PROCESS_INFORMATION piProcInfo;
    memset( &piProcInfo, 0, PROCESS_INFORMATION.sizeof );

    // Set up members of the STARTUPINFO structure.
    // This structure specifies the STDIN and STDOUT handles for redirection.
    STARTUPINFOW siStartInfo;
    memset( &siStartInfo, 0, STARTUPINFOW.sizeof );
    siStartInfo.cb = STARTUPINFOW.sizeof;
    siStartInfo.hStdError = hStdOutWrite;
    siStartInfo.hStdOutput = hStdOutWrite;
    siStartInfo.hStdInput = hStdInRead;
    siStartInfo.dwFlags |= STARTF_USESTDHANDLES;

    // https://docs.microsoft.com/en-us/windows/win32/api/processthreadsapi/nf-processthreadsapi-createprocessw
    BOOL bSuccess = CreateProcessW(null,
                          cast(wchar*)szCommand,     // command line
                          null,          // process security attributes
                          null,          // primary thread security attributes
                          TRUE,          // handles are inherited
                          CREATE_SUSPENDED,             // creation flags
                          null,          // use parent's environment
                          null,          // use parent's current directory
                          &siStartInfo,  // STARTUPINFO pointer
                          &piProcInfo);  // receives PROCESS_INFORMATION

    if (!bSuccess)
    {
        printf("failed launching %ls\n", cast(wchar*)szCommand); // https://issues.dlang.org/show_bug.cgi?id=21958
        return 1;
    }

    ResumeThread(piProcInfo.hThread);

    DWORD bytesFilled = 0;
    DWORD bytesAvailable = 0;
    DWORD bytesRead = 0;
    DWORD exitCode = 0;

    while (true)
    {
        bSuccess = GetExitCodeProcess(piProcInfo.hProcess, &exitCode);
        // flush pipe even if program finished
        DWORD dwlen = cast(DWORD)buffer.length;
        if (bSuccess)
            bSuccess = PeekNamedPipe(hStdOutRead, buffer.ptr + bytesFilled, dwlen - bytesFilled, &bytesRead, &bytesAvailable, null);
        if (bSuccess && bytesRead > 0)
            bSuccess = ReadFile(hStdOutRead, buffer.ptr + bytesFilled, dwlen - bytesFilled, &bytesRead, null);
        if (bSuccess && bytesRead > 0)
        {
            sink(buffer[0 .. bytesRead]);
            continue; // keep on reading from pipe before returning
        }

        if (!bSuccess || exitCode != 259) //259 == STILL_ACTIVE
        {
            break;
        }
        Sleep(1);
    }

    // close the handles to the process
    CloseHandle(hStdInWrite);
    CloseHandle(hStdOutRead);
    CloseHandle(piProcInfo.hProcess);
    CloseHandle(piProcInfo.hThread);

    return exitCode;
}

/****************************************
 * Write filename to cmdbuf, quoting if necessary.
 */
private void writeFilename(OutBuffer* buf, const(char)* filename)
{
    writeFilename(buf, filename.toDString());
}

private void writeFilename(OutBuffer* buf, const(char)[] filename) @safe
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

/**
Translate linker output to more user-friendly error messages, by extracting mangled symbols and demangling them
Params:
    linkerOutput = text that the linker printed
    eSink = sink for translated errors
    betterC = whether the `-betterC` flag is set (to give more specific help when druntime symbols are missing)
    iFlag = whether the `-i` flag is set, to give a suggestion to use it if it is not already used
*/
void parseLinkerOutput(const(char)[] linkerOutput, ErrorSink eSink, bool betterC, bool iFlag)
{
    // Some linkers quote symbols like `so' or 'so', strip the quotes
    static string unquote(string s)
    {
        if (s.length < 2)
            return s;
        if (s[0] == '\'' || s[0] == '`' || s[0] == '"')
            s = s[1 .. $];
        if (s[$ - 1] == '\'' || s[$ - 1] == '"')
            s = s[0 .. $ - 1];
        return s;
    }

    static string stripLeft(string s)
    {
        while (s.length > 0 && s[0] == ' ')
            s = s[1 .. $];
        return s;
    }

    bool missingCSymbols = false;
    bool missingDsymbols = false;
    bool missingDruntimeSymbols = false;
    bool missingPhobosSymbols = false;
    bool missingMain = false;

    void missingSymbol(const(char)[] name, const(char)[] referencedFrom)
    {
        import core.demangle: demangle;
        if (name.startsWith("__D"))
            name = name[1 .. $]; // MS LINK prepends underscore to the existing one

        bool alreadyDemangled = !!findSplit(name, ".");
        auto sym = alreadyDemangled ? name : demangle(name);

        if (sym == "main")
            missingMain = true;
        else if (sym.startsWith("core."))
            missingDruntimeSymbols = true;
        else if (sym.startsWith("std."))
            missingPhobosSymbols = true;
        else if (sym != name && !alreadyDemangled)
            missingDsymbols = true;
        else
            missingCSymbols = true;

        eSink.error(Loc.initial, "undefined reference to `%.*s`", cast(int) sym.length, sym.ptr);
        if (referencedFrom.length > 0)
        {
            if (referencedFrom.startsWith("__D"))
                referencedFrom = referencedFrom[1 .. $];

            const(char)[] refFunc = demangle(referencedFrom);
            eSink.errorSupplemental(Loc.initial, "referenced from `%.*s`", cast(int) refFunc.length, refFunc.ptr);
        }
    }

    string lastSymbol;
    void parseLine(const char[] line)
    {
        if (auto s0 = line.findSplit(" undefined reference to "))
        {
            if (string sym = unquote(s0[2]))
            {
                if (auto r = s0[0].findBetween("(.text.", "["))
                    missingSymbol(sym, r);
                else if (auto r = s0[0].findBetween(":function ", ":(.text"))
                    missingSymbol(sym, r);
                else
                    missingSymbol(sym, null);
            }
        }
        if (auto s0 = line.findSplit("LNK2019: unresolved external symbol "))
        {
            if (auto s1 = s0[2].findSplit(" referenced in function "))
                missingSymbol(s1[0], s1[2]);
            else
                missingSymbol(s0[2], null);
        }
        if (auto s0 = line.findSplit("undefined symbol: "))
        {
            missingSymbol(s0[2], null);
        }
        if (auto s0 = line.findSplit(", referenced from:"))
        {
            if (string sym = unquote(stripLeft(s0[0])))
            {
                lastSymbol = sym; // ;missingSymbol(sym, null);
            }
        }
        if (lastSymbol.length > 0)
        {
            if (auto s0 = line.findSplit(" in "))
                missingSymbol(lastSymbol, stripLeft(s0[0]));
            else
                missingSymbol(lastSymbol,null);

            lastSymbol = null;
        }

    }

    size_t s = 0;
    foreach (i; 0 .. linkerOutput.length)
    {
        if (linkerOutput[i] == '\n')
        {
            const cr = i > 0 && linkerOutput[i - 1] == '\r';
            parseLine(linkerOutput[s .. i - cr]);
            s = i + 1;
        }
    }
    parseLine(linkerOutput[s .. $]);

    if (missingMain)
        eSink.errorSupplemental(Loc.initial, "perhaps define a `void main() {}` function or use the `-main` switch");
    else if (missingDruntimeSymbols || missingPhobosSymbols)
    {
        const(char)* missingLib = missingDruntimeSymbols ? "druntime" : "phobos";
        if (betterC)
            eSink.errorSupplemental(Loc.initial, "the `-betterC` flag prevents linking with %s", missingLib);
        else
            eSink.errorSupplemental(Loc.initial, "perhaps there is a mismatch in compiler and %s version", missingLib);
    }
    else if (missingDsymbols)
    {
        if (iFlag)
            eSink.errorSupplemental(Loc.initial, "perhaps `.d` files need to be added on the command line");
        else
            eSink.errorSupplemental(Loc.initial, "perhaps `.d` files need to be added on the command line, or use `-i` to compile imports");
    }
    else if (missingCSymbols)
        eSink.errorSupplemental(Loc.initial, "perhaps a library needs to be added with the `-L` flag or `pragma(lib, ...)`");
}

unittest
{
    // The following strings are the output of various linkers for this code:
    // module app; void f(); void g() { f(); }

    // ld (bfd is very similar)
    string ldOutput = "
/usr/bin/ld: app.o: in function `_D3app1gFZv':
app.d:(.text._D3app1gFZv[_D3app1gFZv]+0x5): undefined reference to `_D3app1fFZv'
";

    // lld (mold is very similar)
    string lldOutput = "
ld.lld: error: undefined symbol: _D3app1fFZv
>>> referenced by app.d
>>>               app.o:(_D3app1gFZv)
>>> did you mean: _D3app1gFZv
>>> defined in: app.o
";

    // gold linker
    string goldOutput = "
app.o:app.d:function _D3app1gFZv:(.text._D3app1gFZv+0x5): error: undefined reference to '_D3app1fFZv'
";

    // Microsoft LINK
    string linkOutput = "
app.obj : error LNK2019: unresolved external symbol __D3app1fFZv referenced in function __D3app1gFZv
app.exe : fatal error LNK1120: 1 unresolved externals
";

    // ld on MacOS
    string macLd0 = `
Undefined symbols for architecture arm64:
  "__D3app1fFZv", referenced from:
      __D3app1gFZv in app.o
  "__D3app1hFZv", referenced from:
      __D3app1fFZv in app.o
ld: symbol(s) not found for architecture arm64
clang: error: linker command failed with exit code 1 (use -v to see invocation)
`;

    string macLd1 = `
ld: Undefined symbols:
  __D3app1fFZv, referenced from:
  __D3app1gFZv in test6.o
clang: error: linker command failed with exit code 1 (use -v to see invocation)
`;

    class ErrorSinkTest : ErrorSinkNull
    {
        OutBuffer result;
        extern(C++): override:

        void verror(Loc loc, const(char)* format, va_list ap)
        {
            result.writestring("Error: ");
            result.vprintf(format, ap);
            result.writestring("\n");
        }

        void verrorSupplemental(Loc loc, const(char)* format, va_list ap)
        {
            result.vprintf(format, ap);
            result.writestring("\n");
        }
    }

    void test(string linkerName, string output, bool betterC, bool iFlag, string expectedErrors)
    {
        auto testSink = new ErrorSinkTest();
        parseLinkerOutput(output, testSink, betterC, iFlag);

        string result = testSink.result.extractSlice;
        assert(result == expectedErrors, "Failure parsing linker output of " ~ linkerName ~
            "\n# Expected output:\n" ~ expectedErrors ~ "# Actual output:\n" ~ result);
    }

    string expected = "Error: undefined reference to `void app.f()`
referenced from `void app.g()`
perhaps `.d` files need to be added on the command line, or use `-i` to compile imports
";

    test("ld", ldOutput, /*betterC*/ false, /*iFlag*/ false, expected);
    test("gold", goldOutput, /*betterC*/ false, /*iFlag*/ false, expected);
    test("link", linkOutput, /*betterC*/ false, /*iFlag*/ false, expected);

    test("ld", macLd0, /*betterC*/ false, /*iFlag*/ false,
"Error: undefined reference to `void app.f()`
Error: undefined reference to `void app.h()`
perhaps `.d` files need to be added on the command line, or use `-i` to compile imports
");

    test("ld", macLd1, /*betterC*/ false, /*iFlag*/ false,
"Error: undefined reference to `void app.f()`
perhaps `.d` files need to be added on the command line, or use `-i` to compile imports
");

    test("lld", lldOutput, /*betterC*/ false, /*iFlag*/ true,
"Error: undefined reference to `void app.f()`
perhaps `.d` files need to be added on the command line
");

    string missingMainOutput = "
/usr/bin/ld: /usr/lib/gcc/x86_64-pc-linux-gnu/13.2.1/../../../../lib/Scrt1.o: in function `_start':
(.text+0x1b): undefined reference to `main'
";

    test("ld", missingMainOutput, /*betterC*/ false, /*iFlag*/ false,
"Error: undefined reference to `main`
perhaps define a `void main() {}` function or use the `-main` switch
");

    string missingExternCOutput = "
/usr/bin/ld: app.o: in function `_D3app__T2αVAyaa3_616263ZQrFZv':
../test/app.d:(.text._D3app__T2αVAyaa3_616263ZQrFZv[_D3app__T2αVAyaa3_616263ZQrFZv]+0x5): undefined reference to `my_A'
/usr/bin/ld: ../test/app.d:(.text._D3app__T2αVAyaa3_616263ZQrFZv[_D3app__T2αVAyaa3_616263ZQrFZv]+0xa): undefined reference to `my_B'
";

    test("ld", missingExternCOutput, /*betterC*/ true, /*iFlag*/ false,
"Error: undefined reference to `my_A`
referenced from `void app.α!(\"abc\").α()`
Error: undefined reference to `my_B`
referenced from `void app.α!(\"abc\").α()`
perhaps a library needs to be added with the `-L` flag or `pragma(lib, ...)`
");

    string betterCError = "
/usr/bin/ld: test_.o: in function `main':
../test/test_.d:(.text.main[main]+0xa): undefined reference to `core.time.dur!(\"msecs\").dur(long)'
/usr/bin/ld: ../test/test_.d:(.text.main[main]+0x12): undefined reference to `core.thread.osthread.Thread.sleep(core.time.Duration)'
";

    test("ld", betterCError, /*betterC*/ true, /*iFlag*/ false,
"Error: undefined reference to `core.time.dur!(\"msecs\").dur(long)`
referenced from `main`
Error: undefined reference to `core.thread.osthread.Thread.sleep(core.time.Duration)`
referenced from `main`
the `-betterC` flag prevents linking with druntime
");

}
