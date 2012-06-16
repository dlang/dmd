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


extern(Windows) void RtlCaptureContext(CONTEXT* ContextRecord);


private __gshared immutable bool initialized;


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

        static struct BufSymbol
        {
        align(1):
            IMAGEHLP_SYMBOL64 _base;
            TCHAR[1024] _buf;
        }
        BufSymbol bufSymbol=void;
        auto symbol = &bufSymbol._base;
        symbol.SizeOfStruct = IMAGEHLP_SYMBOL64.sizeof;
        symbol.MaxNameLength = bufSymbol._buf.length;

        IMAGEHLP_LINE64 line=void;
        line.SizeOfStruct = IMAGEHLP_LINE64.sizeof;

        debug(PRINTF) printf("Callstack:\n");
        while (dbghelp.StackWalk64(imageType, hProcess, hThread, &stackframe,
                                   &c, null, null, null, null))
        {
            if( stackframe.AddrPC.Offset == stackframe.AddrReturn.Offset )
            {
                debug(PRINTF) printf("Endless callstack\n");
                return trace ~ "...".dup;
            }
            else if( stackframe.AddrPC.Offset != 0 )
            {
                immutable pc = stackframe.AddrPC.Offset;
                char[] res;
                if (dbghelp.SymGetSymFromAddr64(hProcess, pc, null, symbol) &&
                    *symbol.Name.ptr)
                {
                    DWORD disp;

                    if (dbghelp.SymGetLineFromAddr64(hProcess, pc, &disp, &line))
                        res = formatStackFrame(cast(void*)pc, symbol.Name.ptr,
                                               line.FileName, line.LineNumber);
                    else
                        res = formatStackFrame(cast(void*)pc, symbol.Name.ptr);
                }
                else
                    res = formatStackFrame(cast(void*)pc);
                trace ~= res;
            }
        }
        debug(PRINTF) printf("End of Callstack\n");
        return trace;
    }

    static char[] formatStackFrame(void* pc)
    {
        import core.stdc.stdio : snprintf;
        char[2+2*size_t.sizeof+1] buf=void;

        immutable len = snprintf(buf.ptr, buf.length, "0x%p", pc);
        len < buf.length || assert(0);
        return buf[0 .. len].dup;
    }

    static char[] formatStackFrame(void* pc, char* symName)
    {
        char[2048] demangleBuf=void;

        auto res = formatStackFrame(pc);
        res ~= " in ";
        res ~= demangle(symName[0 .. strlen(symName)], demangleBuf);
        return res;
    }

    static char[] formatStackFrame(void* pc, char* symName,
                                   in char* fileName, uint lineNum)
    {
        import core.stdc.stdio : snprintf;
        char[11] buf=void;

        auto res = formatStackFrame(pc, symName);
        res ~= " at ";
        res ~= fileName[0 .. strlen(fileName)];
        res ~= "(";
        immutable len = snprintf(buf.ptr, buf.length, "%u", lineNum);
        len < buf.length || assert(0);
        res ~= buf[0 .. len];
        res ~= ")";
        return res;
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

    auto symOptions = dbghelp.SymGetOptions();
    symOptions |= SYMOPT_LOAD_LINES;
    symOptions |= SYMOPT_FAIL_CRITICAL_ERRORS;
    symOptions  = dbghelp.SymSetOptions( symOptions );

    if (!dbghelp.SymInitialize(hProcess, null, TRUE))
        return;

    dbghelp.SymEnumerateModules64(hProcess, &CodeViewFixup, null);

    initialized = true;
}
