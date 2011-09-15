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
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.sys.windows.stacktrace;


import core.demangle;
import core.runtime;
import core.stdc.stdlib;
import core.stdc.string;
import core.sys.windows.dbghelp;
import core.sys.windows.windows;
import core.stdc.stdio;


extern(Windows)
{
    DWORD GetEnvironmentVariableA(LPCSTR lpName, LPSTR pBuffer, DWORD nSize);
    void  RtlCaptureContext(CONTEXT* ContextRecord);

    alias LONG function(void*) UnhandeledExceptionFilterFunc;
    void* SetUnhandledExceptionFilter(void* handler);
}


enum : uint
{
    MAX_MODULE_NAME32 = 255,
    TH32CS_SNAPMODULE = 0x00000008,
    MAX_NAMELEN       = 1024,
};


extern(System)
{
    alias HANDLE function(DWORD dwFlags, DWORD th32ProcessID) CreateToolhelp32SnapshotFunc;
    alias BOOL   function(HANDLE hSnapshot, MODULEENTRY32 *lpme) Module32FirstFunc;
    alias BOOL   function(HANDLE hSnapshot, MODULEENTRY32 *lpme) Module32NextFunc;
}


struct MODULEENTRY32
{
    DWORD   dwSize;
    DWORD   th32ModuleID;
    DWORD   th32ProcessID;
    DWORD   GlblcntUsage;
    DWORD   ProccntUsage;
    BYTE*   modBaseAddr;
    DWORD   modBaseSize;
    HMODULE hModule;
    CHAR[MAX_MODULE_NAME32 + 1] szModule;
    CHAR[MAX_PATH] szExePath;
}


private
{
    string generateSearchPath()
    {
        __gshared string[3] defaultPathList = ["_NT_SYMBOL_PATH",
                                               "_NT_ALTERNATE_SYMBOL_PATH",
                                               "SYSTEMROOT"];

        string         path;
        char[MAX_PATH] temp;
        DWORD          len;

        if( (len = GetCurrentDirectoryA( temp.length, temp.ptr )) > 0 )
        {
            path ~= temp[0 .. len] ~ ";";
        }
        if( (len = GetModuleFileNameA( null,temp.ptr,temp.length )) > 0 )
        {
            foreach_reverse( i, ref char e; temp[0 .. len] )
            {
                if( e == '\\' || e == '/' || e == ':' )
                {
                    len -= i;
                    break;
                }
            }
            if( len > 0 )
            {
                path ~= temp[0 .. len] ~ ";";
            }
        }
        foreach( e; defaultPathList )
        {
            if( (len = GetEnvironmentVariableA( e.ptr, temp.ptr, temp.length )) > 0 )
            {
                path ~= temp[0 .. len] ~ ";";
            }
        }
        return path;
    }


    bool loadModules( HANDLE hProcess, DWORD pid )
    {
        __gshared string[2] systemDlls = ["kernel32.dll", "tlhelp32.dll"];

        CreateToolhelp32SnapshotFunc CreateToolhelp32Snapshot;
        Module32FirstFunc            Module32First;
        Module32NextFunc             Module32Next;
        HMODULE                      dll;

        foreach( e; systemDlls )
        {
            if( (dll = cast(HMODULE) Runtime.loadLibrary( e )) is null )
                continue;
            CreateToolhelp32Snapshot = cast(CreateToolhelp32SnapshotFunc) GetProcAddress( dll,"CreateToolhelp32Snapshot" );
            Module32First            = cast(Module32FirstFunc) GetProcAddress( dll,"Module32First" );
            Module32Next             = cast(Module32NextFunc) GetProcAddress( dll,"Module32Next" );
            if( CreateToolhelp32Snapshot !is null && Module32First !is null && Module32Next !is null )
                break;
            Runtime.unloadLibrary( dll );
            dll = null;
        }
        if( dll is null )
        {
            return false;
        }

        auto hSnap = CreateToolhelp32Snapshot( TH32CS_SNAPMODULE, pid );
        if( hSnap == INVALID_HANDLE_VALUE )
            return false;

        MODULEENTRY32 moduleEntry;
        moduleEntry.dwSize = MODULEENTRY32.sizeof;

        auto more  = cast(bool) Module32First( hSnap, &moduleEntry );
        int  count = 0;

        while( more )
        {
            count++;
            loadModule( hProcess,
                        moduleEntry.szExePath.ptr,
                        moduleEntry.szModule.ptr,
                        cast(DWORD64) moduleEntry.modBaseAddr,
                        moduleEntry.modBaseSize );
            more = cast(bool) Module32Next( hSnap, &moduleEntry );
        }

        CloseHandle( hSnap );
        Runtime.unloadLibrary( dll );
        return count > 0;
    }


    void loadModule( HANDLE hProcess, PCSTR img, PCSTR mod, DWORD64 baseAddr, DWORD size )
    {
        auto dbghelp       = DbgHelp.get();
        DWORD64 moduleAddr = dbghelp.SymLoadModule64( hProcess,
                                                      HANDLE.init,
                                                      img,
                                                      mod,
                                                      baseAddr,
                                                      size );
        if( moduleAddr == 0 )
            return;

        IMAGEHLP_MODULE64 moduleInfo;
        moduleInfo.SizeOfStruct = IMAGEHLP_MODULE64.sizeof;

        if( dbghelp.SymGetModuleInfo64( hProcess, moduleAddr, &moduleInfo ) == TRUE )
        {
            if( moduleInfo.SymType == SYM_TYPE.SymNone )
            {
                dbghelp.SymUnloadModule64( hProcess, moduleAddr );
                moduleAddr = dbghelp.SymLoadModule64( hProcess,
                                                      HANDLE.init,
                                                      img,
                                                      null,
                                                      cast(DWORD64) 0,
                                                      0 );
                if( moduleAddr == 0 )
                    return;
            }
        }
        //printf( "Successfully loaded module %s\n", img );
    }


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


    __gshared invariant bool initialized;
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


    override string toString()
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

        auto symbolSize = IMAGEHLP_SYMBOL64.sizeof + MAX_NAMELEN;
        auto symbol     = cast(IMAGEHLP_SYMBOL64*) calloc( symbolSize, 1 );

        static assert((IMAGEHLP_SYMBOL64.sizeof + MAX_NAMELEN) <= uint.max, "symbolSize should never exceed uint.max");

        symbol.SizeOfStruct  = cast(DWORD)symbolSize;
        symbol.MaxNameLength = MAX_NAMELEN;

        IMAGEHLP_LINE64 line;
        line.SizeOfStruct = IMAGEHLP_LINE64.sizeof;

        IMAGEHLP_MODULE64 moduleInfo;
        moduleInfo.SizeOfStruct = IMAGEHLP_MODULE64.sizeof;

        //printf( "Callstack:\n" );
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
                //printf( "End of Callstack\n" );
                break;
            }

            if( stackframe.AddrPC.Offset == stackframe.AddrReturn.Offset )
            {
                //printf( "Endless callstack\n" );
                trace ~= "...".dup;
                break;
            }

            if( stackframe.AddrPC.Offset != 0 )
            {
                DWORD64 offset;

                if( dbghelp.SymGetSymFromAddr64( hProcess,
                                                 stackframe.AddrPC.Offset,
                                                 &offset,
                                                 symbol ) == TRUE )
                {
                    DWORD    displacement;
                    char[]   lineBuf;
                    char[20] temp;

                    if( dbghelp.SymGetLineFromAddr64( hProcess, stackframe.AddrPC.Offset, &displacement, &line ) == TRUE )
                    {
                        char[2048] demangleBuf;
                        auto       symbolName = (cast(char*) symbol.Name.ptr)[0 .. strlen(symbol.Name.ptr)];

                        // displacement bytes from beginning of line
                        trace ~= line.FileName[0 .. strlen( line.FileName )] ~
                                 "(" ~ format( temp[], line.LineNumber ) ~ "): " ~
                                 demangle( symbolName, demangleBuf );
                    }
                }
                else
                {
                    char[22] temp;
                    auto     val = format( temp[], stackframe.AddrPC.Offset, 16 );
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


shared static this()
{
    auto dbghelp = DbgHelp.get();

    if( dbghelp is null )
        return; // dbghelp.dll not available

    auto hProcess = GetCurrentProcess();
    auto pid      = GetCurrentProcessId();
    auto symPath  = generateSearchPath() ~ 0;
    auto ret      = dbghelp.SymInitialize( hProcess,
                                           symPath.ptr,
                                           FALSE );
    assert( ret != FALSE );

    auto symOptions = dbghelp.SymGetOptions();
    symOptions |= SYMOPT_LOAD_LINES;
    symOptions |= SYMOPT_FAIL_CRITICAL_ERRORS;
    symOptions  = dbghelp.SymSetOptions( symOptions );

    if( !loadModules( hProcess, pid ) )
        {} // for now it's fine if the modules don't load
    initialized = true;
    //SetUnhandledExceptionFilter( &unhandeledExceptionFilterHandler );
}
