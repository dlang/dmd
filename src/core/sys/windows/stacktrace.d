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
version(Windows):

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


    int opApply( scope int delegate(ref const(char[])) dg ) const
    {
        return opApply( (ref size_t, ref const(char[]) buf)
                        {
                            return dg( buf );
                        });
    }


    int opApply( scope int delegate(ref size_t, ref const(char[])) dg ) const
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
        CONTEXT      ctxt;

        ctxt.ContextFlags = CONTEXT_FULL;
        RtlCaptureContext(&ctxt);

        //x86
        STACKFRAME64 stackframe;
        with (stackframe)
        {
            version(X86) 
            {
                enum Flat = ADDRESS_MODE.AddrModeFlat;
                AddrPC.Offset    = ctxt.Eip;
                AddrPC.Mode      = Flat;
                AddrFrame.Offset = ctxt.Ebp;
                AddrFrame.Mode   = Flat;
                AddrStack.Offset = ctxt.Esp;
                AddrStack.Mode   = Flat;
            }
	    else version(X86_64)
            {
                enum Flat = ADDRESS_MODE.AddrModeFlat;
                AddrPC.Offset    = ctxt.Rip;
                AddrPC.Mode      = Flat;
                AddrFrame.Offset = ctxt.Rbp;
                AddrFrame.Mode   = Flat;
                AddrStack.Offset = ctxt.Rsp;
                AddrStack.Mode   = Flat;
            }
        }

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

        version (X86)         enum imageType = IMAGE_FILE_MACHINE_I386;
        else version (X86_64) enum imageType = IMAGE_FILE_MACHINE_AMD64;
        else                  static assert(0, "unimplemented");

        char[][] trace;
        debug(PRINTF) printf("Callstack:\n");
        while (dbghelp.StackWalk64(imageType, hProcess, hThread, &stackframe,
                                   &ctxt, null, null, null, null))
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
                    IMAGEHLP_LINE64 line=void;
                    line.SizeOfStruct = IMAGEHLP_LINE64.sizeof;

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


// Workaround OPTLINK bug (Bugzilla 8263)
extern(Windows) BOOL FixupDebugHeader(HANDLE hProcess, ULONG ActionCode,
                                      ulong CallbackContext, ulong UserContext)
{
    if (ActionCode == CBA_READ_MEMORY)
    {
        auto p = cast(IMAGEHLP_CBA_READ_MEMORY*)CallbackContext;
        if (!(p.addr & 0xFF) && p.bytes == 0x1C &&
            // IMAGE_DEBUG_DIRECTORY.PointerToRawData
            (*cast(DWORD*)(p.addr + 24) & 0xFF) == 0x20)
        {
            immutable base = DbgHelp.get().SymGetModuleBase64(hProcess, p.addr);
            // IMAGE_DEBUG_DIRECTORY.AddressOfRawData
            if (base + *cast(DWORD*)(p.addr + 20) == p.addr + 0x1C &&
                *cast(DWORD*)(p.addr + 0x1C) == 0 &&
                *cast(DWORD*)(p.addr + 0x20) == ('N'|'B'<<8|'0'<<16|'9'<<24))
            {
                debug(PRINTF) printf("fixup IMAGE_DEBUG_DIRECTORY.AddressOfRawData\n");
                memcpy(p.buf, cast(void*)p.addr, 0x1C);
                *cast(DWORD*)(p.buf + 20) = cast(DWORD)(p.addr - base) + 0x20;
                *p.bytesread = 0x1C;
                return TRUE;
            }
        }
    }
    return FALSE;
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
    symOptions |= SYMOPT_DEFERRED_LOAD;
    symOptions  = dbghelp.SymSetOptions( symOptions );

    if (!dbghelp.SymInitialize(hProcess, null, TRUE))
        return;

    dbghelp.SymRegisterCallback64(hProcess, &FixupDebugHeader, 0);

    initialized = true;
}
