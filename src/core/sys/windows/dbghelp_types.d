/**
 * ...
 *
 * Copyright: Copyright Benjamin Thaut 2010 - 2011.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Benjamin Thaut, Sean Kelly
 * Source:    $(DRUNTIMESRC core/sys/windows/_dbghelp_types.d)
 */

module core.sys.windows.dbghelp_types;

import core.sys.windows.windows;

version (Windows):

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
    SYMOPT_DEFERRED_LOAD        = 0x00000004,
    SYMOPT_FAIL_CRITICAL_ERRORS = 0x00000200,
    SYMOPT_LOAD_LINES           = 0x00000010,
    SYMOPT_DEBUG                = 0x80000000,
}

enum : ULONG
{
    CBA_READ_MEMORY             = 0x00000006,
    CBA_DEBUG_INFO              = 0x10000000,
}

public import core.sys.windows.basetyps : GUID;

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
    DWORD64 StackBase;
    DWORD64 StackLimit;
    DWORD64[5] Reserved;
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

public import core.sys.windows.winnt : IMAGE_FILE_MACHINE_I386, IMAGE_FILE_MACHINE_IA64, IMAGE_FILE_MACHINE_AMD64;

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
    // new elements: 07-Jun-2002
    version (none)
    {
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
    }
    // new elements: 17-Dec-2003
    version (none)
    {
        BOOL       SourceIndexed;
        BOOL       Publics;
    }
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


struct IMAGEHLP_CBA_READ_MEMORY
{
    DWORD64 addr;
    PVOID   buf;
    DWORD   bytes;
    DWORD   *bytesread;
}

struct API_VERSION
{
    USHORT MajorVersion;
    USHORT MinorVersion;
    USHORT Revision;
    USHORT Reserved;
}
