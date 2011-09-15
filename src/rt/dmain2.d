/**
 * Contains main program entry point and support routines.
 *
 * Copyright: Copyright Digital Mars 2000 - 2010.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright, Sean Kelly
 */

/*          Copyright Digital Mars 2000 - 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.dmain2;

private
{
    import rt.memory;
    import rt.util.console;
    import rt.util.string;
    import core.stdc.stddef;
    import core.stdc.stdlib;
    import core.stdc.string;
    import core.stdc.stdio;   // for printf()
}

version (Windows)
{
    private import core.stdc.wchar_;

    extern (Windows) uint       GetVersion();
    extern (Windows) alias int function() FARPROC;
    extern (Windows) FARPROC    GetProcAddress(void*, in char*);
    extern (Windows) void*      LoadLibraryA(in char*);
    extern (Windows) int        FreeLibrary(void*);
    extern (Windows) void*      LocalFree(void*);
    extern (Windows) wchar_t*   GetCommandLineW();
    extern (Windows) wchar_t**  CommandLineToArgvW(wchar_t*, int*);
    extern (Windows) export int WideCharToMultiByte(uint, uint, wchar_t*, int, char*, int, char*, int);
    pragma(lib, "shell32.lib"); // needed for CommandLineToArgvW

    wchar_t** doCommandLineToArgvW(wchar_t* cmdLine, int* numArgs)
    {
        if (GetVersion() < 0x80000000)
        {
            return CommandLineToArgvW(cmdLine, numArgs);
        }
        // TODO: Handle this manually for Win98 and earlier.
        return CommandLineToArgvW(cmdLine, numArgs);
    }
}

version (all)
{
    extern (C) Throwable.TraceInfo _d_traceContext(void* ptr = null);

    extern (C) void _d_createTrace(Object *o)
    {
        auto t = cast(Throwable) o;

        if (t !is null && t.info is null &&
            cast(byte*) t !is t.classinfo.init.ptr)
        {
            t.info = _d_traceContext();
        }
    }
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
extern (C) void _minit();
extern (C) void _moduleCtor();
extern (C) void _moduleDtor();
extern (C) void thread_joinAll();
extern (C) void rt_lifetimeInit();

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

extern (C) void* rt_loadLibrary(in char[] name)
{
    version (Windows)
    {
        // Load a DLL at runtime
        char[260] temp = void;
        temp[0 .. name.length] = name[];
        temp[name.length] = cast(char) 0;
        // BUG: LoadLibraryA() call calls rt_init(), which fails if proxy is not set!
        void* ptr = LoadLibraryA(temp.ptr);
        if (ptr is null)
            return ptr;
        gcSetFn gcSet = cast(gcSetFn) GetProcAddress(ptr, "gc_setProxy");
        if (gcSet !is null)
        {   // BUG: Set proxy, but too late
            gcSet(gc_getProxy());
        }
        return ptr;

    }
    else version (Posix)
    {
        throw new Exception("rt_loadLibrary not yet implemented on Posix.");
    }
}

extern (C) bool rt_unloadLibrary(void* ptr)
{
    version (Windows)
    {
        gcClrFn gcClr  = cast(gcClrFn) GetProcAddress(ptr, "gc_clrProxy");
        if (gcClr !is null)
            gcClr();
        return FreeLibrary(ptr) != 0;
    }
    else version (Posix)
    {
        throw new Exception("rt_unloadLibrary not yet implemented on Posix.");
    }
}

/***********************************
 * These functions must be defined for any D program linked
 * against this library.
 */
extern (C) void onAssertError(string file, size_t line);
extern (C) void onAssertErrorMsg(string file, size_t line, string msg);
extern (C) void onUnittestErrorMsg(string file, size_t line, string msg);
extern (C) void onRangeError(string file, size_t line);
extern (C) void onHiddenFuncError(Object o);
extern (C) void onSwitchError(string file, size_t line);
extern (C) bool runModuleUnitTests();

// this function is called from the utf module
//extern (C) void onUnicodeError(string msg, size_t idx);

/***********************************
 * These are internal callbacks for various language errors.
 */

extern (C)
{
    // Use ModuleInfo to get file name for "m" versions

    void _d_assertm(ModuleInfo* m, uint line)
    {
        onAssertError(m.name, line);
    }

    void _d_assert_msg(string msg, string file, uint line)
    {
        onAssertErrorMsg(file, line, msg);
    }

    void _d_assert(string file, uint line)
    {
        onAssertError(file, line);
    }

    void _d_unittestm(ModuleInfo* m, uint line)
    {
        _d_unittest(m.name, line);
    }

    void _d_unittest_msg(string msg, string file, uint line)
    {
        onUnittestErrorMsg(file, line, msg);
    }

    void _d_unittest(string file, uint line)
    {
        _d_unittest_msg("unittest failure", file, line);
    }

    void _d_array_bounds(ModuleInfo* m, uint line)
    {
        onRangeError(m.name, line);
    }

    void _d_switch_error(ModuleInfo* m, uint line)
    {
        onSwitchError(m.name, line);
    }

}

extern (C) void _d_hidden_func()
{
    Object o;
    version(X86)
        asm
        {
            mov o, EAX;
        }
    else version(X86_64)
        asm
        {
            mov o, RDI;
        }
    else
        static assert(0, "unknown os");

    onHiddenFuncError(o);
}

shared bool _d_isHalting = false;

extern (C) bool rt_isHalting()
{
    return _d_isHalting;
}

__gshared string[] _d_args = null;

extern (C) string[] rt_args()
{
    return _d_args;
}

// This variable is only ever set by a debugger on initialization so it should
// be fine to leave it as __gshared.
extern (C) __gshared bool rt_trapExceptions = true;

void _d_criticalInit()
{
    version (Posix)
    {
        _STI_monitor_staticctor();
        _STI_critical_init();
    }
}

alias void delegate(Throwable) ExceptionHandler;

extern (C) bool rt_init(ExceptionHandler dg = null)
{
    _d_criticalInit();

    try
    {
        gc_init();
        initStaticDataGC();
        version (Windows)
            _minit();
        rt_lifetimeInit();
        _moduleCtor();
        _moduleTlsCtor();
        runModuleUnitTests();
        return true;
    }
    catch (Throwable e)
    {
        if (dg)
            dg(e);
        else
            throw e;    // rethrow, don't silently ignore error
    }
    _d_criticalTerm();
    return false;
}

void _d_criticalTerm()
{
    version (Posix)
    {
        _STD_critical_term();
        _STD_monitor_staticdtor();
    }
}

extern (C) bool rt_term(ExceptionHandler dg = null)
{
    try
    {
        _moduleTlsDtor();
        thread_joinAll();
        _d_isHalting = true;
        _moduleDtor();
        gc_term();
        return true;
    }
    catch (Throwable e)
    {
        if (dg)
            dg(e);
    }
    finally
    {
        _d_criticalTerm();
    }
    return false;
}

/***********************************
 * The D main() function supplied by the user's program
 */
int main(char[][] args);

/***********************************
 * Substitutes for the C main() function.
 * It's purpose is to wrap the call to the D main()
 * function and catch any unhandled exceptions.
 */

extern (C) int main(int argc, char** argv)
{
    char[][] args;
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

    version (Posix)
    {
        _STI_monitor_staticctor();
        _STI_critical_init();
    }

    version (Windows)
    {
        wchar_t*  wcbuf = GetCommandLineW();
        size_t 	  wclen = wcslen(wcbuf);
        int       wargc = 0;
        wchar_t** wargs = CommandLineToArgvW(wcbuf, &wargc);
        assert(wargc == argc);

        // This is required because WideCharToMultiByte requires int as input.
        assert(wclen <= int.max, "wclen must not exceed int.max");

        char*     cargp = null;
        size_t    cargl = WideCharToMultiByte(65001, 0, wcbuf, cast(int)wclen, null, 0, null, 0);

        cargp = cast(char*) alloca(cargl);
        args  = ((cast(char[]*) alloca(wargc * (char[]).sizeof)))[0 .. wargc];

        for (size_t i = 0, p = 0; i < wargc; i++)
        {
            size_t wlen = wcslen(wargs[i]);
            assert(wlen <= int.max, "wlen cannot exceed int.max");
            int clen = WideCharToMultiByte(65001, 0, &wargs[i][0], cast(int)wlen, null, 0, null, 0);
            args[i]  = cargp[p .. p+clen];
            p += clen; assert(p <= cargl);
            WideCharToMultiByte(65001, 0, &wargs[i][0], cast(int)wlen, &args[i][0], clen, null, 0);
        }
        LocalFree(wargs);
        wargs = null;
        wargc = 0;
    }
    else version (Posix)
    {
        char[]* am = cast(char[]*) malloc(argc * (char[]).sizeof);
        scope(exit) free(am);

        for (size_t i = 0; i < argc; i++)
        {
            auto len = strlen(argv[i]);
            am[i] = argv[i][0 .. len];
        }
        args = am[0 .. argc];
    }
    _d_args = cast(string[]) args;

    bool trapExceptions = rt_trapExceptions;

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
        result = main(args);
    }

    void runAll()
    {
        gc_init();
        initStaticDataGC();
        version (Windows)
            _minit();
        rt_lifetimeInit();
        _moduleCtor();
        _moduleTlsCtor();
        if (runModuleUnitTests())
            tryExec(&runMain);
        else
            result = EXIT_FAILURE;
        _moduleTlsDtor();
        thread_joinAll();
        _d_isHalting = true;
        _moduleDtor();
        gc_term();
    }

    tryExec(&runAll);

    version (Posix)
    {
        _STD_critical_term();
        _STD_monitor_staticdtor();
    }
    return result;
}
