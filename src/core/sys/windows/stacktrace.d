/**
 * ...
 *
 * Copyright: Copyright Benjamin Thaut 2010 - 2011.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Benjamin Thaut, Sean Kelly
 * Source:    $(DRUNTIMESRC core/sys/windows/_stacktrace.d)
 */

/*          Copyright Benjamin Thaut 2010 - 2011.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.sys.windows.stacktrace;


import core.demangle;
import core.runtime;
import core.stdc.stdlib;
import core.stdc.string;
import core.sys.windows.dbghelp;
import core.sys.windows.windows;

//debug=PRINTF;
debug(PRINTF) import core.stdc.stdio;

extern(Windows)
{
    DWORD GetEnvironmentVariableA(LPCSTR lpName, LPSTR pBuffer, DWORD nSize);
    void  RtlCaptureContext(CONTEXT* ContextRecord);

    alias LONG function(void*) UnhandeledExceptionFilterFunc;
    void* SetUnhandledExceptionFilter(void* handler);
}


private
{
    /+
    extern(Windows) static LONG unhandeledExceptionFilterHandler(void* info)
    {
        printStackTrace();
        return 0;
    }


    static void printStackTrace()
    {
        auto stack = TraceHandler( null );
        foreach( char[] s; stack )
        {
            printf( "%s\n",s );
        }
    }
    +/


    __gshared immutable bool initialized;
}


class StackTrace : Throwable.TraceInfo
{
public:
    this()
    {
        if( initialized )
            m_trace = trace();
    }


    int opApply( scope int delegate(ref char[]) dg )
    {
        return opApply( (ref size_t, ref char[] buf)
                        {
                            return dg( buf );
                        });
    }


    int opApply( scope int delegate(ref size_t, ref char[]) dg )
    {
        int result;

        foreach( i, e; m_trace )
        {
            if( (result = dg( i, e )) != 0 )
                break;
        }
        return result;
    }


    @safe override string toString() const pure nothrow
    {
        string result;

        foreach( e; m_trace )
        {
            result ~= e ~ "\n";
        }
        return result;
    }


private:
    char[][] m_trace;


    static char[][] trace()
    {
        synchronized( StackTrace.classinfo )
        {
            return traceNoSync();
        }
    }


    static char[][] traceNoSync()
    {
        auto         dbghelp  = DbgHelp.get();
        auto         hThread  = GetCurrentThread();
        auto         hProcess = GetCurrentProcess();
        STACKFRAME64 stackframe;
        DWORD        imageType;
        char[][]     trace;
        CONTEXT      c;

        c.ContextFlags = CONTEXT_FULL;
        RtlCaptureContext( &c );

        //x86
        imageType                   = IMAGE_FILE_MACHINE_I386;
        stackframe.AddrPC.Offset    = cast(DWORD64) c.Eip;
        stackframe.AddrPC.Mode      = ADDRESS_MODE.AddrModeFlat;
        stackframe.AddrFrame.Offset = cast(DWORD64) c.Ebp;
        stackframe.AddrFrame.Mode   = ADDRESS_MODE.AddrModeFlat;
        stackframe.AddrStack.Offset = cast(DWORD64) c.Esp;
        stackframe.AddrStack.Mode   = ADDRESS_MODE.AddrModeFlat;

        enum MAX_NAMELEN = 1024;
        auto symbolSize = IMAGEHLP_SYMBOL64.sizeof + MAX_NAMELEN;
        auto symbol     = cast(IMAGEHLP_SYMBOL64*) calloc( symbolSize, 1 );

        static assert((IMAGEHLP_SYMBOL64.sizeof + MAX_NAMELEN) <= uint.max, "symbolSize should never exceed uint.max");

        symbol.SizeOfStruct  = cast(DWORD)symbolSize;
        symbol.MaxNameLength = MAX_NAMELEN;

        IMAGEHLP_LINE64 line;
        line.SizeOfStruct = IMAGEHLP_LINE64.sizeof;

        debug(PRINTF) printf("Callstack:\n");
        for( int frameNum = 0; ; frameNum++ )
        {
            if( dbghelp.StackWalk64( imageType,
                                     hProcess,
                                     hThread,
                                     &stackframe,
                                     &c,
                                     null,
                                     cast(FunctionTableAccessProc64) dbghelp.SymFunctionTableAccess64,
                                     cast(GetModuleBaseProc64) dbghelp.SymGetModuleBase64,
                                     null) != TRUE )
            {
                debug(PRINTF) printf("End of Callstack\n");
                break;
            }

            if( stackframe.AddrPC.Offset == stackframe.AddrReturn.Offset )
            {
                debug(PRINTF) printf("Endless callstack\n");
                trace ~= "...".dup;
                break;
            }

            if( stackframe.AddrPC.Offset != 0 )
            {
                immutable pc = stackframe.AddrPC.Offset;
                if (dbghelp.SymGetSymFromAddr64(hProcess, pc, null, symbol) &&
                    *symbol.Name.ptr)
                {
                    auto symName = (cast(char*)symbol.Name.ptr)[0 .. strlen(symbol.Name.ptr)];
                    char[2048] demangleBuf=void;
                    symName = demangle(symName, demangleBuf);

                    DWORD disp;
                    if (dbghelp.SymGetLineFromAddr64(hProcess, pc, &disp, &line))
                    {
                        char[20] numBuf=void;
                        trace ~= symName.dup ~ " at " ~
                            line.FileName[0 .. strlen(line.FileName)] ~
                            "(" ~ format(numBuf[], line.LineNumber) ~ ")";
                    }
                    else
                        trace ~= symName.dup;
                }
                else
                {
                    char[22] numBuf=void;
                    auto val = format(numBuf[], stackframe.AddrPC.Offset, 16);
                    trace ~= val.dup;
                }
            }
        }
        free( symbol );
        return trace;
    }


    // TODO: Remove this in favor of an external conversion.
    static char[] format( char[] buf, ulong val, uint base = 10 )
    in
    {
        assert( buf.length > 9 );
    }
    body
    {
        auto p = buf.ptr + buf.length;

        if( base < 11 )
        {
            do
            {
                *--p = cast(char)(val % base + '0');
            } while( val /= base );
        }
        else if( base < 37 )
        {
            do
            {
                auto x = val % base;
                *--p = cast(char)(x < 10 ? x + '0' : (x - 10) + 'A');
            } while( val /= base );
        }
        else
        {
            assert( false, "base too large" );
        }
        return buf[p - buf.ptr .. $];
    }
}


// For unknown reasons dbghelp.dll fails to load dmd's embedded
// CodeView information if an explicit base address is specified.
// As a workaround we reload any module without debug information.
extern(Windows) BOOL CodeViewFixup(PCSTR ModuleName, DWORD64 BaseOfDll, PVOID)
{
    auto dbghelp = DbgHelp.get();
    auto hProcess = GetCurrentProcess();

    IMAGEHLP_MODULE64 moduleInfo;
    moduleInfo.SizeOfStruct = IMAGEHLP_MODULE64.sizeof;

    if (!dbghelp.SymGetModuleInfo64(hProcess, BaseOfDll, &moduleInfo))
        return TRUE;
    if (moduleInfo.SymType != SYM_TYPE.SymNone)
        return TRUE;

    if (!dbghelp.SymUnloadModule64(hProcess, BaseOfDll))
        return TRUE;
    auto img = moduleInfo.ImageName.ptr;
    if (!dbghelp.SymLoadModule64(hProcess, null, img, null, 0, 0))
        return TRUE;

    debug(PRINTF) printf("Reloaded symbols for %s\n", img);
    return TRUE;
}


shared static this()
{
    auto dbghelp = DbgHelp.get();

    if( dbghelp is null )
        return; // dbghelp.dll not available

    auto hProcess = GetCurrentProcess();
    auto pid      = GetCurrentProcessId();

    auto symOptions = dbghelp.SymGetOptions();
    symOptions |= SYMOPT_LOAD_LINES;
    symOptions |= SYMOPT_FAIL_CRITICAL_ERRORS;
    symOptions  = dbghelp.SymSetOptions( symOptions );

    if (!dbghelp.SymInitialize(hProcess, null, TRUE))
        return;

    dbghelp.SymEnumerateModules64(hProcess, &CodeViewFixup, null);

    initialized = true;
    //SetUnhandledExceptionFilter( &unhandeledExceptionFilterHandler );
}
