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
module core.sys.windows.dbghelp;


import core.sys.windows.windows;


alias CHAR TCHAR;

/*
enum ADDRESS_MODE : DWORD
{
    AddrMode1616 = 0,
    AddrMode1632 = 1,
    AddrModeReal = 2,
    AddrModeFlat = 3,
}
*/
enum : DWORD
{
    SYMOPT_FAIL_CRITICAL_ERRORS = 0x00000200,
    SYMOPT_LOAD_LINES           = 0x00000010,
}

struct GUID
{
    uint     Data1;
    ushort   Data2;
    ushort   Data3;
    ubyte[8] Data4;
}
/+
struct ADDRESS64
{
    DWORD64      Offset;
    WORD         Segment;
    ADDRESS_MODE Mode;
}

struct KDHELP64
{
    DWORD64 Thread;
    DWORD   ThCallbackStack;
    DWORD   ThCallbackBStore;
    DWORD   NextCallback;
    DWORD   FramePointer;
    DWORD64 KiCallUserMode;
    DWORD64 KeUserCallbackDispatcher;
    DWORD64 SystemRangeStart;
    DWORD64 KiUserExceptionDispatcher;
    DWORD64[7] Reserved;
}

struct STACKFRAME64
{
    ADDRESS64  AddrPC;
    ADDRESS64  AddrReturn;
    ADDRESS64  AddrFrame;
    ADDRESS64  AddrStack;
    ADDRESS64  AddrBStore;
    PVOID      FuncTableEntry;
    DWORD64[4] Params;
    BOOL       Far;
    BOOL       Virtual;
    DWORD64[3] Reserved;
    KDHELP64   KdHelp;
}
+/
enum : DWORD
{
    IMAGE_FILE_MACHINE_I386  = 0x014c,
    IMGAE_FILE_MACHINE_IA64  = 0x0200,
    IMAGE_FILE_MACHINE_AMD64 = 0x8664,
}

struct IMAGEHLP_LINE64
{
    DWORD   SizeOfStruct;
    PVOID   Key;
    DWORD   LineNumber;
    PTSTR   FileName;
    DWORD64 Address;
}

enum SYM_TYPE : int
{
    SymNone = 0,
    SymCoff,
    SymCv,
    SymPdb,
    SymExport,
    SymDeferred,
    SymSym,
    SymDia,
    SymVirtual,
    NumSymTypes,
}

struct IMAGEHLP_MODULE64
{
    DWORD      SizeOfStruct;
    DWORD64    BaseOfImage;
    DWORD      ImageSize;
    DWORD      TimeDateStamp;
    DWORD      CheckSum;
    DWORD      NumSyms;
    SYM_TYPE   SymType;
    TCHAR[32]  ModuleName;
    TCHAR[256] ImageName;
    TCHAR[256] LoadedImageName;
    TCHAR[256] LoadedPdbName;
    DWORD      CVSig;
    TCHAR[MAX_PATH*3] CVData;
    DWORD      PdbSig;
    GUID       PdbSig70;
    DWORD      PdbAge;
    BOOL       PdbUnmatched;
    BOOL       DbgUnmachted;
    BOOL       LineNumbers;
    BOOL       GlobalSymbols;
    BOOL       TypeInfo;
    BOOL       SourceIndexed;
    BOOL       Publics;
}

struct IMAGEHLP_SYMBOL64
{
    DWORD    SizeOfStruct;
    DWORD64  Address;
    DWORD    Size;
    DWORD    Flags;
    DWORD    MaxNameLength;
    TCHAR[1] Name;
}

extern(System)
{
    alias BOOL    function(HANDLE hProcess, DWORD64 lpBaseAddress, PVOID lpBuffer, DWORD nSize, LPDWORD lpNumberOfBytesRead) ReadProcessMemoryProc64;
    alias PVOID   function(HANDLE hProcess, DWORD64 AddrBase) FunctionTableAccessProc64;
    alias DWORD64 function(HANDLE hProcess, DWORD64 Address) GetModuleBaseProc64;
    alias DWORD64 function(HANDLE hProcess, HANDLE hThread, ADDRESS64 *lpaddr) TranslateAddressProc64;

    alias BOOL    function(HANDLE hProcess, PCSTR UserSearchPath, bool fInvadeProcess) SymInitializeFunc;
    alias BOOL    function(HANDLE hProcess) SymCleanupFunc;
    alias DWORD   function(DWORD SymOptions) SymSetOptionsFunc;
    alias DWORD   function() SymGetOptionsFunc;
    alias PVOID   function(HANDLE hProcess, DWORD64 AddrBase) SymFunctionTableAccess64Func;
    alias BOOL    function(DWORD MachineType, HANDLE hProcess, HANDLE hThread, STACKFRAME64 *StackFrame, PVOID ContextRecord,
                             ReadProcessMemoryProc64 ReadMemoryRoutine, FunctionTableAccessProc64 FunctoinTableAccess,
                             GetModuleBaseProc64 GetModuleBaseRoutine, TranslateAddressProc64 TranslateAddress) StackWalk64Func;
    alias BOOL    function(HANDLE hProcess, DWORD64 dwAddr, PDWORD pdwDisplacement, IMAGEHLP_LINE64 *line) SymGetLineFromAddr64Func;
    alias DWORD64 function(HANDLE hProcess, DWORD64 dwAddr) SymGetModuleBase64Func;
    alias BOOL    function(HANDLE hProcess, DWORD64 dwAddr, IMAGEHLP_MODULE64 *ModuleInfo) SymGetModuleInfo64Func;
    alias BOOL    function(HANDLE hProcess, DWORD64 Address, DWORD64 *Displacement, IMAGEHLP_SYMBOL64 *Symbol) SymGetSymFromAddr64Func;
    alias DWORD   function(PCTSTR DecoratedName, PTSTR UnDecoratedName, DWORD UndecoratedLength, DWORD Flags) UnDecorateSymbolNameFunc;
    alias DWORD64 function(HANDLE hProcess, HANDLE hFile, PCSTR ImageName, PCSTR ModuleName, DWORD64 BaseOfDll, DWORD SizeOfDll) SymLoadModule64Func;
    alias BOOL    function(HANDLE HProcess, PTSTR SearchPath, DWORD SearchPathLength) SymGetSearchPathFunc;
    alias BOOL    function(HANDLE hProcess, DWORD64 Address) SymUnloadModule64Func;
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
    SymUnloadModule64Func    SymUnloadModule64;

    static DbgHelp* get()
    {
        if( sm_hndl != sm_hndl.init )
            return &sm_inst;
        if( (sm_hndl = LoadLibraryA( "dbghelp.dll" )) != sm_hndl.init )
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
            sm_inst.SymLoadModule64          = cast(SymLoadModule64Func) GetProcAddress(sm_hndl,"SymLoadModule64");
            sm_inst.SymGetSearchPath         = cast(SymGetSearchPathFunc) GetProcAddress(sm_hndl,"SymGetSearchPath");
            sm_inst.SymUnloadModule64        = cast(SymUnloadModule64Func) GetProcAddress(sm_hndl,"SymUnloadModule64");

            assert( sm_inst.SymInitialize && sm_inst.SymCleanup && sm_inst.StackWalk64 && sm_inst.SymGetOptions &&
                    sm_inst.SymSetOptions && sm_inst.SymFunctionTableAccess64 && sm_inst.SymGetLineFromAddr64 &&
                    sm_inst.SymGetModuleBase64 && sm_inst.SymGetModuleInfo64 && sm_inst.SymGetSymFromAddr64 &&
                    sm_inst.SymLoadModule64 && sm_inst.SymGetSearchPath && sm_inst.SymUnloadModule64);

            return &sm_inst;
        }
        return null;
    }

    shared static ~this()
    {
        if( sm_hndl != sm_hndl.init )
            FreeLibrary( sm_hndl );
    }

private:
    __gshared DbgHelp sm_inst;
    __gshared HANDLE  sm_hndl;
}
