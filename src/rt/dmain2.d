/**
 * Contains druntime startup and shutdown routines.
 *
 * Copyright: Copyright Digital Mars 2000 - 2013.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Walter Bright, Sean Kelly
 * Source: $(DRUNTIMESRC src/rt/_dmain2.d)
 */

module rt.dmain2;

private
{
    import rt.memory;
    import rt.sections;
    import rt.util.console;
    import rt.util.string;
    import core.stdc.stddef;
    import core.stdc.stdlib;
    import core.stdc.string;
    import core.stdc.stdio;   // for printf()
    import core.stdc.errno : errno;
}

version (Windows)
{
    private import core.stdc.wchar_;

    extern (Windows)
    {
        alias int function() FARPROC;
        FARPROC    GetProcAddress(void*, in char*);
        void*      LoadLibraryA(in char*);
        void*      LoadLibraryW(in wchar_t*);
        int        FreeLibrary(void*);
        void*      LocalFree(void*);
        wchar_t*   GetCommandLineW();
        wchar_t**  CommandLineToArgvW(in wchar_t*, int*);
        export int WideCharToMultiByte(uint, uint, in wchar_t*, int, char*, int, in char*, int*);
        export int MultiByteToWideChar(uint, uint, in char*, int, wchar_t*, int);
        int        IsDebuggerPresent();
    }
    pragma(lib, "shell32.lib"); // needed for CommandLineToArgvW
}

version (FreeBSD)
{
    import core.stdc.fenv;
}

extern (C) void _STI_monitor_staticctor();
extern (C) void _STD_monitor_staticdtor();
extern (C) void _STI_critical_init();
extern (C) void _STD_critical_term();
extern (C) void gc_init();
extern (C) void gc_term();
extern (C) void rt_moduleCtor();
extern (C) void rt_moduleTlsCtor();
extern (C) void rt_moduleDtor();
extern (C) void rt_moduleTlsDtor();
extern (C) void thread_joinAll();
extern (C) bool runModuleUnitTests();

version (OSX)
{
    // The bottom of the stack
    extern (C) __gshared void* __osx_stack_end = cast(void*)0xC0000000;
}

/***********************************
 * These are a temporary means of providing a GC hook for DLL use.  They may be
 * replaced with some other similar functionality later.
 */
extern (C)
{
    void* gc_getProxy();
    void  gc_setProxy(void* p);
    void  gc_clrProxy();

    alias void* function()      gcGetFn;
    alias void  function(void*) gcSetFn;
    alias void  function()      gcClrFn;
}

version (Windows)
{
    /*******************************************
     * Loads a DLL written in D with the name 'name'.
     * Returns:
     *      opaque handle to the DLL if successfully loaded
     *      null if failure
     */
    extern (C) void* rt_loadLibrary(const char* name)
    {
        return initLibrary(.LoadLibraryA(name));
    }

    extern (C) void* rt_loadLibraryW(const wchar_t* name)
    {
        return initLibrary(.LoadLibraryW(name));
    }

    void* initLibrary(void* mod)
    {
        // BUG: LoadLibrary() call calls rt_init(), which fails if proxy is not set!
        // (What? LoadLibrary() is a Windows API call, it shouldn't call rt_init().)
        if (mod is null)
            return mod;
        gcSetFn gcSet = cast(gcSetFn) GetProcAddress(mod, "gc_setProxy");
        if (gcSet !is null)
        {   // BUG: Set proxy, but too late
            gcSet(gc_getProxy());
        }
        return mod;
    }

    /*************************************
     * Unloads DLL that was previously loaded by rt_loadLibrary().
     * Input:
     *      ptr     the handle returned by rt_loadLibrary()
     * Returns:
     *      true    succeeded
     *      false   some failure happened
     */
    extern (C) bool rt_unloadLibrary(void* ptr)
    {
        gcClrFn gcClr  = cast(gcClrFn) GetProcAddress(ptr, "gc_clrProxy");
        if (gcClr !is null)
            gcClr();
        return FreeLibrary(ptr) != 0;
    }
}

/* To get out-of-band access to the args[] passed to main().
 */

__gshared string[] _d_args = null;

extern (C) string[] rt_args()
{
    return _d_args;
}

// This variable is only ever set by a debugger on initialization so it should
// be fine to leave it as __gshared.
extern (C) __gshared bool rt_trapExceptions = true;

alias void delegate(Throwable) ExceptionHandler;

/**********************************************
 * Initialize druntime.
 * If a C program wishes to call D code, and there's no D main(), then it
 * must call rt_init() and rt_term().
 * If it fails, call dg. Except that what dg might be
 * able to do is undetermined, since the state of druntime
 * will not be known.
 * This needs rethinking.
 */
extern (C) bool rt_init(ExceptionHandler dg = null)
{
    _STI_monitor_staticctor();
    _STI_critical_init();

    try
    {
        initSections();
        gc_init();
        initStaticDataGC();
        rt_moduleCtor();
        rt_moduleTlsCtor();
        return true;
    }
    catch (Throwable e)
    {
        /* Note that if we get here, the runtime is in an unknown state.
         * I'm not sure what the point of calling dg is.
         */
        if (dg)
            dg(e);
        else
            throw e;    // rethrow, don't silently ignore error
        /* Rethrow, and the two STD functions aren't called?
         * This needs rethinking.
         */
    }
    _STD_critical_term();
    _STD_monitor_staticdtor();
    return false;
}

/**********************************************
 * Terminate use of druntime.
 * If it fails, call dg. Except that what dg might be
 * able to do is undetermined, since the state of druntime
 * will not be known.
 * This needs rethinking.
 */
extern (C) bool rt_term(ExceptionHandler dg = null)
{
    try
    {
        rt_moduleTlsDtor();
        thread_joinAll();
        rt_moduleDtor();
        gc_term();
        finiSections();
        return true;
    }
    catch (Throwable e)
    {
        if (dg)
            dg(e);
    }
    finally
    {
        _STD_critical_term();
        _STD_monitor_staticdtor();
    }
    return false;
}

/***********************************
 * Provide out-of-band access to the original C argc/argv
 * passed to this program via main(argc,argv).
 */

struct CArgs
{
    int argc;
    char** argv;
}

__gshared CArgs _cArgs;

extern (C) CArgs rt_cArgs()
{
    return _cArgs;
}

/***********************************
 * Run the given main function.
 * Its purpose is to wrap the D main()
 * function and catch any unhandled exceptions.
 */
private alias extern(C) int function(char[][] args) MainFunc;

extern (C) int _d_run_main(int argc, char **argv, MainFunc mainFunc)
{
    // Remember the original C argc/argv
    _cArgs.argc = argc;
    _cArgs.argv = argv;

    int result;

    version (OSX)
    {   /* OSX does not provide a way to get at the top of the
         * stack, except for the magic value 0xC0000000.
         * But as far as the gc is concerned, argv is at the top
         * of the main thread's stack, so save the address of that.
         */
        __osx_stack_end = cast(void*)&argv;
    }

    version (FreeBSD) version (D_InlineAsm_X86)
    {
        /*
         * FreeBSD/i386 sets the FPU precision mode to 53 bit double.
         * Make it 64 bit extended.
         */
        ushort fpucw;
        asm
        {
            fstsw   fpucw;
            or      fpucw, 0b11_00_111111; // 11: use 64 bit extended-precision
                                           // 111111: mask all FP exceptions
            fldcw   fpucw;
        }
    }

    version (Win64)
    {
        auto fp = __iob_func();
        stdin = &fp[0];
        stdout = &fp[1];
        stderr = &fp[2];

        // ensure that sprintf generates only 2 digit exponent when writing floating point values
        _set_output_format(_TWO_DIGIT_EXPONENT);

        // enable full precision for reals
        asm
        {
            push    RAX;
            fstcw   word ptr [RSP];
            or      [RSP], 0b11_00_111111; // 11: use 64 bit extended-precision
                                           // 111111: mask all FP exceptions
            fldcw   word ptr [RSP];
            pop     RAX;
        }
    }

    // Allocate args[] on the stack
    char[][] args = (cast(char[]*) alloca(argc * (char[]).sizeof))[0 .. argc];

    version (Windows)
    {
        /* Because we want args[] to be UTF-8, and Windows doesn't guarantee that,
         * we ignore argc/argv and go get the Windows command line again as UTF-16.
         * Then, reparse into wargc/wargs, and then use Windows API to convert
         * to UTF-8.
         */
        const wchar_t* wCommandLine = GetCommandLineW();
        immutable size_t wCommandLineLength = wcslen(wCommandLine);
        int wargc;
        wchar_t** wargs = CommandLineToArgvW(wCommandLine, &wargc);
        assert(wargc == argc);

        // This is required because WideCharToMultiByte requires int as input.
        assert(wCommandLineLength <= cast(size_t) int.max, "Wide char command line length must not exceed int.max");

        immutable size_t totalArgsLength = WideCharToMultiByte(65001, 0, wCommandLine, cast(int)wCommandLineLength, null, 0, null, null);
        {
            char* totalArgsBuff = cast(char*) alloca(totalArgsLength);
            size_t j = 0;
            foreach (i; 0 .. wargc)
            {
                immutable size_t wlen = wcslen(wargs[i]);
                assert(wlen <= cast(size_t) int.max, "wlen cannot exceed int.max");
                immutable int len = WideCharToMultiByte(65001, 0, &wargs[i][0], cast(int) wlen, null, 0, null, null);
                args[i] = totalArgsBuff[j .. j + len];
                if (len == 0)
                    continue;
                j += len;
                assert(j <= totalArgsLength);
                WideCharToMultiByte(65001, 0, &wargs[i][0], cast(int) wlen, &args[i][0], len, null, null);
            }
        }
        LocalFree(wargs);
        wargs = null;
        wargc = 0;
    }
    else version (Posix)
    {
        size_t totalArgsLength = 0;
        foreach(i, ref arg; args)
        {
            arg = argv[i][0 .. strlen(argv[i])];
            totalArgsLength += arg.length;
        }
    }
    else
        static assert(0);

    /* Create a copy of args[] on the stack, and set the global _d_args to refer to it.
     * Why a copy instead of just using args[] is unclear.
     * This also means that when this function returns, _d_args will refer to garbage.
     */
    {
        auto buff = cast(char[]*) alloca(argc * (char[]).sizeof + totalArgsLength);

        char[][] argsCopy = buff[0 .. argc];
        auto argBuff = cast(char*) (buff + argc);
        foreach(i, arg; args)
        {
            argsCopy[i] = (argBuff[0 .. arg.length] = arg[]);
            argBuff += arg.length;
        }
        _d_args = cast(string[]) argsCopy;
    }

    bool trapExceptions = rt_trapExceptions;

    version (Windows)
    {
        if (IsDebuggerPresent())
            trapExceptions = false;
    }

    void tryExec(scope void delegate() dg)
    {
        void printLocLine(Throwable t)
        {
            if (t.file)
            {
               console(t.classinfo.name)("@")(t.file)("(")(t.line)(")");
            }
            else
            {
                console(t.classinfo.name);
            }
            console("\n");
        }

        void printMsgLine(Throwable t)
        {
            if (t.file)
            {
               console(t.classinfo.name)("@")(t.file)("(")(t.line)(")");
            }
            else
            {
                console(t.classinfo.name);
            }
            if (t.msg)
            {
                console(": ")(t.msg);
            }
            console("\n");
        }

        void printInfoBlock(Throwable t)
        {
            if (t.info)
            {
                console("----------------\n");
                foreach (i; t.info)
                    console(i)("\n");
                console("----------------\n");
            }
        }

        void print(Throwable t)
        {
            Throwable firstWithBypass = null;

            for (; t; t = t.next)
            {
                printMsgLine(t);
                printInfoBlock(t);
                auto e = cast(Error) t;
                if (e && e.bypassedException)
                {
                    console("Bypasses ");
                    printLocLine(e.bypassedException);
                    if (firstWithBypass is null)
                        firstWithBypass = t;
                }
            }
            if (firstWithBypass is null)
                return;
            console("=== Bypassed ===\n");
            for (t = firstWithBypass; t; t = t.next)
            {
                auto e = cast(Error) t;
                if (e && e.bypassedException)
                    print(e.bypassedException);
            }
        }

        if (trapExceptions)
        {
            try
            {
                dg();
            }
            catch (Throwable t)
            {
                print(t);
                result = EXIT_FAILURE;
            }
        }
        else
        {
            dg();
        }
    }

    // NOTE: The lifetime of a process is much like the lifetime of an object:
    //       it is initialized, then used, then destroyed.  If initialization
    //       fails, the successive two steps are never reached.  However, if
    //       initialization succeeds, then cleanup will occur even if the use
    //       step fails in some way.  Here, the use phase consists of running
    //       the user's main function.  If main terminates with an exception,
    //       the exception is handled and then cleanup begins.  An exception
    //       thrown during cleanup, however, will abort the cleanup process.
    void runMain()
    {
        if (runModuleUnitTests())
            tryExec({ result = mainFunc(args); });
        else
            result = EXIT_FAILURE;
    }

    void runMainWithInit()
    {
        if (rt_init() && runModuleUnitTests())
            tryExec({ result = mainFunc(args); });
        else
            result = EXIT_FAILURE;

        if (!rt_term())
            result = (result == EXIT_SUCCESS) ? EXIT_FAILURE : result;
    }

    version (linux) // initialization is done in rt.sections_linux
        tryExec(&runMain);
    else
        tryExec(&runMainWithInit);

    // Issue 10344: flush stdout and return nonzero on failure
    if (.fflush(.stdout) != 0)
    {
        .fprintf(.stderr, "Failed to flush stdout: %s\n", .strerror(.errno));
        if (result == 0)
        {
            result = EXIT_FAILURE;
        }
    }

    return result;
}
