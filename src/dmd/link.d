/**
 * Invoke the linker as a separate process.
 *
 * Copyright:   Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
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
import dmd.env;
import dmd.errors;
import dmd.globals;
import dmd.mars;
import dmd.root.file;
import dmd.root.filename;
import dmd.root.outbuffer;
import dmd.root.rmem;
import dmd.root.string;
import dmd.utils;
import dmd.target;
import dmd.vsoptions;

version (Posix) extern (C) int pipe(int*);
version (Windows) extern (C) int spawnlp(int, const char*, const char*, const char*, const char*);
version (Windows) extern (C) int spawnl(int, const char*, const char*, const char*, const char*);
version (Windows) extern (C) int spawnv(int, const char*, const char**);
// Workaround lack of 'vfork' in older druntime binding for non-Glibc
version (Posix) extern(C) pid_t vfork();
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

/*****************************
 * Run the linker.  Return status of execution.
 */
public int runLINK()
{
    const phobosLibname = global.finalDefaultlibname();

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

        if (target.mscoff)
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
            ensurePathToNameExists(Loc.initial, global.params.exefile);
            cmdbuf.writeByte(' ');
            if (global.params.mapfile)
            {
                cmdbuf.writestring("/MAP:");
                writeFilename(&cmdbuf, global.params.mapfile);
            }
            else if (dmdParams.map)
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
            for (size_t i = 0; i < global.params.linkswitches.length; i++)
            {
                cmdbuf.writeByte(' ');
                cmdbuf.writeQuotedArgIfNeeded(global.params.linkswitches[i]);
            }

            VSOptions vsopt;
            // if a runtime library (msvcrtNNN.lib) from the mingw folder is selected explicitly, do not detect VS and use lld
            if (global.params.mscrtlib.length <= 6 ||
                global.params.mscrtlib[0..6] != "msvcrt" || !isdigit(global.params.mscrtlib[6]))
                vsopt.initialize();

            const(char)* lflags = vsopt.linkOptions(target.is64bit);
            if (lflags)
            {
                cmdbuf.writeByte(' ');
                cmdbuf.writestring(lflags);
            }

            const(char)* linkcmd = getenv(target.is64bit ? "LINKCMD64" : "LINKCMD");
            if (!linkcmd)
                linkcmd = getenv("LINKCMD"); // backward compatible
            if (!linkcmd)
                linkcmd = vsopt.linkerPath(target.is64bit);

            // object files not SAFESEH compliant, but LLD is more picky than MS link
            if (!target.is64bit)
                if (FileName.equals(FileName.name(linkcmd), "lld-link.exe"))
                    cmdbuf.writestring(" /SAFESEH:NO");

            cmdbuf.writeByte(0); // null terminate the buffer
            char[] p = cmdbuf.extractSlice()[0 .. $-1];
            const(char)[] lnkfilename;
            if (p.length > 7000)
            {
                lnkfilename = FileName.forceExt(global.params.exefile, "lnk");
                writeFile(Loc.initial, lnkfilename, p);
                if (lnkfilename.length < p.length)
                {
                    p[0] = '@';
                    p[1 ..  lnkfilename.length +1] = lnkfilename;
                    p[lnkfilename.length +1] = 0;
                }
            }

            const int status = executecmd(linkcmd, p.ptr);
            if (lnkfilename)
            {
                lnkfilename.toCStringThen!(lf => remove(lf.ptr));
                FileName.free(lnkfilename.ptr);
            }
            return status;
        }
        else
        {
            OutBuffer cmdbuf;
            global.params.libfiles.push("user32");
            global.params.libfiles.push("kernel32");
            for (size_t i = 0; i < global.params.objfiles.length; i++)
            {
                if (i)
                    cmdbuf.writeByte('+');
                const(char)[] p = global.params.objfiles[i].toDString();
                const(char)[] basename = FileName.removeExt(FileName.name(p));
                const(char)[] ext = FileName.ext(p);
                if (ext.length && !strchr(basename.ptr, '.'))
                {
                    // Write name sans extension (but not if a double extension)
                    writeFilename(&cmdbuf, p[0 .. $ - ext.length - 1]);
                }
                else
                    writeFilename(&cmdbuf, p);
                FileName.free(basename.ptr);
            }
            cmdbuf.writeByte(',');
            if (global.params.exefile)
                writeFilename(&cmdbuf, global.params.exefile);
            else
            {
                setExeFile();
            }
            // Make sure path to exe file exists
            ensurePathToNameExists(Loc.initial, global.params.exefile);
            cmdbuf.writeByte(',');
            if (global.params.mapfile)
                writeFilename(&cmdbuf, global.params.mapfile);
            else if (dmdParams.map)
            {
                writeFilename(&cmdbuf, getMapFilename());
            }
            else
                cmdbuf.writestring("nul");
            cmdbuf.writeByte(',');
            for (size_t i = 0; i < global.params.libfiles.length; i++)
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
                const size_t i = cmdbuf.length;
                if (!i || cmdbuf[i - 1] != ',')
                    break;
                cmdbuf.setsize(cmdbuf.length - 1);
            }
            if (global.params.resfile)
            {
                cmdbuf.writestring("/RC:");
                writeFilename(&cmdbuf, global.params.resfile);
            }
            if (dmdParams.map || global.params.mapfile)
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
            for (size_t i = 0; i < global.params.linkswitches.length; i++)
            {
                cmdbuf.writestring(global.params.linkswitches[i]);
            }
            cmdbuf.writeByte(';');
            cmdbuf.writeByte(0); //null terminate the buffer
            char[] p = cmdbuf.extractSlice()[0 .. $-1];
            const(char)[] lnkfilename;
            if (p.length > 7000)
            {
                lnkfilename = FileName.forceExt(global.params.exefile, "lnk");
                writeFile(Loc.initial, lnkfilename, p);
                if (lnkfilename.length < p.length)
                {
                    p[0] = '@';
                    p[1 .. lnkfilename.length +1] = lnkfilename;
                    p[lnkfilename.length +1] = 0;
                }
            }
            const(char)* linkcmd = getenv("LINKCMD");
            if (!linkcmd)
                linkcmd = "optlink";
            const int status = executecmd(linkcmd, p.ptr);
            if (lnkfilename)
            {
                lnkfilename.toCStringThen!(lf => remove(lf.ptr));
                FileName.free(lnkfilename.ptr);
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
                    error(Loc.initial, "error creating temporary file");
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
                if (global.params.dll)
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
        ensurePathToNameExists(Loc.initial, global.params.exefile);
        if (global.params.symdebug)
            argv.push("-g");
        if (target.is64bit)
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
        if (dmdParams.map || global.params.mapfile.length)
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
            if (!buf)
                Mem.error();
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
            message(buf.peekChars());
        }
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
        if (!target.mscoff)
        {
            if ((len = strlen(args)) > 255)
            {
                status = putenvRestorable("_CMDLINE", args[0 .. len]);
                if (status == 0)
                    args = "@_CMDLINE";
                else
                    error(Loc.initial, "command line length of %llu is too long", cast(ulong) len);
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

                BOOL b = CreateProcessA(null, cmdbuf.peekChars(), null, null, 1, NORMAL_PRIORITY_CLASS, null, null, &startInf, &procInf);
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
        message(buf.peekChars());
    }
    // Build argv[]
    Strings argv;
    argv.push(global.params.exefile.xarraydup.ptr);
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
    restoreEnvVars();
    version (Windows)
    {
        const(char)[] ex = FileName.name(global.params.exefile);
        if (ex == global.params.exefile)
            ex = FileName.combine(".", ex);
        else
            ex = global.params.exefile;
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
