/**
 * Windows API header module
 *
 * Translated from MinGW Windows headers
 *
 * Authors: Stewart Gordon
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source: $(DRUNTIMESRC core/sys/windows/_ntdef.d)
 */
module core.sys.windows.ntdef;
version (Windows):

import core.sys.windows.basetsd, core.sys.windows.subauth, core.sys.windows.windef, core.sys.windows.winnt;

enum uint
    OBJ_INHERIT          = 0x0002,
    OBJ_PERMANENT        = 0x0010,
    OBJ_EXCLUSIVE        = 0x0020,
    OBJ_CASE_INSENSITIVE = 0x0040,
    OBJ_OPENIF           = 0x0080,
    OBJ_OPENLINK         = 0x0100,
    OBJ_VALID_ATTRIBUTES = 0x01F2;

void InitializeObjectAttributes(OBJECT_ATTRIBUTES* p, UNICODE_STRING* n,
      uint a, HANDLE r, void* s) {
    with (*p) {
        Length = OBJECT_ATTRIBUTES.sizeof;
        RootDirectory = r;
        Attributes = a;
        ObjectName = n;
        SecurityDescriptor = s;
        SecurityQualityOfService = null;
    }
}

pragma(inline, true) @safe pure nothrow @nogc {
    bool NT_SUCCESS()(NTSTATUS Status)     { return Status >= 0; }
    bool NT_INFORMATION()(NTSTATUS Status) { return ((cast(ULONG) Status) >> 30) == 1; }
    bool NT_WARNING()(NTSTATUS Status)     { return ((cast(ULONG) Status) >> 30) == 2; }
    bool NT_ERROR()(NTSTATUS Status)       { return ((cast(ULONG) Status) >> 30) == 3; }
}

/*  In MinGW, NTSTATUS, UNICODE_STRING, STRING and their associated pointer
 *  type aliases are defined in ntdef.h, ntsecapi.h and subauth.h, each of
 *  which checks that none of the others is already included.
 */
alias NTSTATUS = int;
alias PNTSTATUS = int*;

struct UNICODE_STRING {
    USHORT Length;
    USHORT MaximumLength;
    PWSTR  Buffer;
}
alias PUNICODE_STRING = UNICODE_STRING*;
alias PCUNICODE_STRING = const(UNICODE_STRING)*;

struct STRING {
    USHORT Length;
    USHORT MaximumLength;
    PCHAR  Buffer;
}
alias ANSI_STRING = STRING, OEM_STRING = STRING;
alias PSTRING = STRING*, PANSI_STRING = STRING*, POEM_STRING = STRING*;

alias PHYSICAL_ADDRESS = LARGE_INTEGER;
alias PPHYSICAL_ADDRESS = LARGE_INTEGER*;

enum SECTION_INHERIT {
    ViewShare = 1,
    ViewUnmap
}

/*  In MinGW, this is defined in ntdef.h and ntsecapi.h, each of which checks
 *  that the other isn't already included.
 */
struct OBJECT_ATTRIBUTES {
    ULONG           Length = OBJECT_ATTRIBUTES.sizeof;
    HANDLE          RootDirectory;
    PUNICODE_STRING ObjectName;
    ULONG           Attributes;
    PVOID           SecurityDescriptor;
    PVOID           SecurityQualityOfService;
}
alias POBJECT_ATTRIBUTES = OBJECT_ATTRIBUTES*;
