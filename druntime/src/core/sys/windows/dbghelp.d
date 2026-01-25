/**
 * ...
 *
 * Copyright: Copyright Benjamin Thaut 2010 - 2011.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Benjamin Thaut, Sean Kelly
 * Source:    $(DRUNTIMESRC core/sys/windows/_dbghelp.d)
 */

module core.sys.windows.dbghelp;
version (Windows):

import core.sys.windows.winbase /+: FreeLibrary, GetProcAddress, LoadLibraryA+/;
import core.sys.windows.windef;

public import core.sys.windows.dbghelp_types;

extern(Windows)
{
    alias ReadProcessMemoryProc64 = BOOL         function(HANDLE hProcess, DWORD64 lpBaseAddress, PVOID lpBuffer, DWORD nSize, LPDWORD lpNumberOfBytesRead);
    alias FunctionTableAccessProc64 = PVOID        function(HANDLE hProcess, DWORD64 AddrBase);
    alias GetModuleBaseProc64 = DWORD64      function(HANDLE hProcess, DWORD64 Address);
    alias TranslateAddressProc64 = DWORD64      function(HANDLE hProcess, HANDLE hThread, ADDRESS64 *lpaddr);

    alias SymInitializeFunc = BOOL         function(HANDLE hProcess, PCSTR UserSearchPath, bool fInvadeProcess);
    alias SymCleanupFunc = BOOL         function(HANDLE hProcess);
    alias SymSetOptionsFunc = DWORD        function(DWORD SymOptions);
    alias SymGetOptionsFunc = DWORD        function();
    alias SymFunctionTableAccess64Func = PVOID        function(HANDLE hProcess, DWORD64 AddrBase);
    alias StackWalk64Func = BOOL         function(DWORD MachineType, HANDLE hProcess, HANDLE hThread, STACKFRAME64 *StackFrame, PVOID ContextRecord,
                                ReadProcessMemoryProc64 ReadMemoryRoutine, FunctionTableAccessProc64 FunctoinTableAccess,
                                GetModuleBaseProc64 GetModuleBaseRoutine, TranslateAddressProc64 TranslateAddress) @nogc;
    alias SymGetLineFromAddr64Func = BOOL         function(HANDLE hProcess, DWORD64 dwAddr, PDWORD pdwDisplacement, IMAGEHLP_LINEA64 *line);
    alias SymGetModuleBase64Func = DWORD64      function(HANDLE hProcess, DWORD64 dwAddr);
    alias SymGetModuleInfo64Func = BOOL         function(HANDLE hProcess, DWORD64 dwAddr, IMAGEHLP_MODULEA64 *ModuleInfo);
    alias SymGetSymFromAddr64Func = BOOL         function(HANDLE hProcess, DWORD64 Address, DWORD64 *Displacement, IMAGEHLP_SYMBOLA64 *Symbol);
    alias UnDecorateSymbolNameFunc = DWORD        function(PCSTR DecoratedName, PSTR UnDecoratedName, DWORD UndecoratedLength, DWORD Flags);
    alias SymLoadModule64Func = DWORD64      function(HANDLE hProcess, HANDLE hFile, PCSTR ImageName, PCSTR ModuleName, DWORD64 BaseOfDll, DWORD SizeOfDll);
    alias SymGetSearchPathFunc = BOOL         function(HANDLE hProcess, PSTR SearchPath, DWORD SearchPathLength);
    alias SymSetSearchPathFunc = BOOL         function(HANDLE hProcess, PCSTR SearchPath);
    alias SymUnloadModule64Func = BOOL         function(HANDLE hProcess, DWORD64 Address);
    alias PSYMBOL_REGISTERED_CALLBACK64 = BOOL         function(HANDLE hProcess, ULONG ActionCode, ulong CallbackContext, ulong UserContext);
    alias SymRegisterCallback64Func = BOOL         function(HANDLE hProcess, PSYMBOL_REGISTERED_CALLBACK64 CallbackFunction, ulong UserContext);
    alias ImagehlpApiVersionFunc = API_VERSION* function();
}

struct DbgHelp
{
    SymInitializeFunc        SymInitialize;
    SymCleanupFunc           SymCleanup;
    StackWalk64Func          StackWalk64;
    SymGetOptionsFunc        SymGetOptions;
    SymSetOptionsFunc        SymSetOptions;
    SymFunctionTableAccess64Func SymFunctionTableAccess64;
    SymGetLineFromAddr64Func SymGetLineFromAddr64;
    SymGetModuleBase64Func   SymGetModuleBase64;
    SymGetModuleInfo64Func   SymGetModuleInfo64;
    SymGetSymFromAddr64Func  SymGetSymFromAddr64;
    UnDecorateSymbolNameFunc UnDecorateSymbolName;
    SymLoadModule64Func      SymLoadModule64;
    SymGetSearchPathFunc     SymGetSearchPath;
    SymSetSearchPathFunc     SymSetSearchPath;
    SymUnloadModule64Func    SymUnloadModule64;
    SymRegisterCallback64Func SymRegisterCallback64;
    ImagehlpApiVersionFunc   ImagehlpApiVersion;

    static DbgHelp* get() @nogc
    {
        if ( sm_hndl != sm_hndl.init )
            return &sm_inst;
        if ( (sm_hndl = LoadLibraryA( "dbghelp.dll" )) != sm_hndl.init )
        {
            sm_inst.SymInitialize            = cast(SymInitializeFunc) GetProcAddress(sm_hndl,"SymInitialize");
            sm_inst.SymCleanup               = cast(SymCleanupFunc) GetProcAddress(sm_hndl,"SymCleanup");
            sm_inst.StackWalk64              = cast(StackWalk64Func) GetProcAddress(sm_hndl,"StackWalk64");
            sm_inst.SymGetOptions            = cast(SymGetOptionsFunc) GetProcAddress(sm_hndl,"SymGetOptions");
            sm_inst.SymSetOptions            = cast(SymSetOptionsFunc) GetProcAddress(sm_hndl,"SymSetOptions");
            sm_inst.SymFunctionTableAccess64 = cast(SymFunctionTableAccess64Func) GetProcAddress(sm_hndl,"SymFunctionTableAccess64");
            sm_inst.SymGetLineFromAddr64     = cast(SymGetLineFromAddr64Func) GetProcAddress(sm_hndl,"SymGetLineFromAddr64");
            sm_inst.SymGetModuleBase64       = cast(SymGetModuleBase64Func) GetProcAddress(sm_hndl,"SymGetModuleBase64");
            sm_inst.SymGetModuleInfo64       = cast(SymGetModuleInfo64Func) GetProcAddress(sm_hndl,"SymGetModuleInfo64");
            sm_inst.SymGetSymFromAddr64      = cast(SymGetSymFromAddr64Func) GetProcAddress(sm_hndl,"SymGetSymFromAddr64");
            sm_inst.UnDecorateSymbolName     = cast(UnDecorateSymbolNameFunc) GetProcAddress(sm_hndl,"UnDecorateSymbolName");
            sm_inst.SymLoadModule64          = cast(SymLoadModule64Func) GetProcAddress(sm_hndl,"SymLoadModule64");
            sm_inst.SymGetSearchPath         = cast(SymGetSearchPathFunc) GetProcAddress(sm_hndl,"SymGetSearchPath");
            sm_inst.SymSetSearchPath         = cast(SymSetSearchPathFunc) GetProcAddress(sm_hndl,"SymSetSearchPath");
            sm_inst.SymUnloadModule64        = cast(SymUnloadModule64Func) GetProcAddress(sm_hndl,"SymUnloadModule64");
            sm_inst.SymRegisterCallback64    = cast(SymRegisterCallback64Func) GetProcAddress(sm_hndl, "SymRegisterCallback64");
            sm_inst.ImagehlpApiVersion       = cast(ImagehlpApiVersionFunc) GetProcAddress(sm_hndl, "ImagehlpApiVersion");
            assert( sm_inst.SymInitialize && sm_inst.SymCleanup && sm_inst.StackWalk64 && sm_inst.SymGetOptions &&
                    sm_inst.SymSetOptions && sm_inst.SymFunctionTableAccess64 && sm_inst.SymGetLineFromAddr64 &&
                    sm_inst.SymGetModuleBase64 && sm_inst.SymGetModuleInfo64 && sm_inst.SymGetSymFromAddr64 &&
                    sm_inst.UnDecorateSymbolName && sm_inst.SymLoadModule64 && sm_inst.SymGetSearchPath &&
                    sm_inst.SymSetSearchPath && sm_inst.SymUnloadModule64 && sm_inst.SymRegisterCallback64 &&
                    sm_inst.ImagehlpApiVersion);

            return &sm_inst;
        }
        return null;
    }

    shared static ~this()
    {
        if ( sm_hndl != sm_hndl.init )
            FreeLibrary( sm_hndl );
    }

private:
    __gshared DbgHelp sm_inst;
    __gshared HANDLE  sm_hndl;
}
