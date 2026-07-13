/**
 * Windows API header module
 *
 * Translated from MinGW API for MS-Windows 3.12
 *
 * Authors: Stewart Gordon
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source: $(DRUNTIMESRC core/sys/windows/_basetsd.d)
 */
module core.sys.windows.basetsd;
version (Windows):

// [SnakE 2009-02-23] Moved HANDLE definition here from winnt.d to avoid
// 'forwatd template reference' to CPtr from winnt.d caused by a circular
// import.
alias HANDLE = void*;

alias PHANDLE = HANDLE*, LPHANDLE = HANDLE*;

// helper for aligned structs
// alignVal 0 means the default align.
// _alignSpec as parameter does not pollute namespace.
package mixin template AlignedStr(int alignVal, string name, string memberlist,
                                    string _alignSpec = !alignVal ? "align" : "align("~alignVal.stringof~")" )
{
    mixin( _alignSpec ~ " struct " ~ name ~" { " ~ _alignSpec ~":"~ memberlist~" }" );
}

version (CoreUnittest) {
    private mixin AlignedStr!(16, "_Test_Aligned_Str", q{char a; char b;});
    private mixin AlignedStr!(0, "_Test_NoAligned_Str", q{char a; char b;});
}

version (Win64) {
    alias __int3264 = long;
enum ulong ADDRESS_TAG_BIT = 0x40000000000;

    alias INT_PTR = long, LONG_PTR = long;
    alias PINT_PTR = long*, PLONG_PTR = long*;
    alias UINT_PTR = ulong, ULONG_PTR = ulong, HANDLE_PTR = ulong;
    alias PUINT_PTR = ulong*, PULONG_PTR = ulong*;
    alias HALF_PTR = int;
    alias PHALF_PTR = int*;
    alias UHALF_PTR = uint;
    alias PUHALF_PTR = uint*;

    uint HandleToULong()(void* h) { return(cast(uint) cast(ULONG_PTR) h); }
    int HandleToLong()(void* h)   { return(cast(int) cast(LONG_PTR) h); }
    void* ULongToHandle()(uint h) { return(cast(void*) cast(UINT_PTR) h); }
    void* LongToHandle()(int h)   { return(cast(void*) cast(INT_PTR) h); }
    uint PtrToUlong()(void* p)    { return(cast(uint) cast(ULONG_PTR) p); }
    uint PtrToUint()(void* p)     { return(cast(uint) cast(UINT_PTR) p); }
    ushort PtrToUshort()(void* p) { return(cast(ushort) cast(uint) cast(ULONG_PTR) p); }
    int PtrToLong()(void* p)      { return(cast(int) cast(LONG_PTR) p); }
    int PtrToInt()(void* p)       { return(cast(int) cast(INT_PTR) p); }
    short PtrToShort()(void* p)   { return(cast(short) cast(int) cast(LONG_PTR) p); }
    void* IntToPtr()(int i)       { return(cast(void*) cast(INT_PTR) i); }
    void* UIntToPtr()(uint ui)    { return(cast(void*) cast(UINT_PTR) ui); }
    void* LongToPtr()(int l)      { return(cast(void*) cast(LONG_PTR) l); }
    void* ULongToPtr()(uint ul)   { return(cast(void*) cast(ULONG_PTR) ul); }

} else {
    alias __int3264 = int;
enum uint ADDRESS_TAG_BIT = 0x80000000;

    alias INT_PTR = int, LONG_PTR = int;
    alias PINT_PTR = int*, PLONG_PTR = int*;
    alias UINT_PTR = uint, ULONG_PTR = uint, HANDLE_PTR = uint;
    alias PUINT_PTR = uint*, PULONG_PTR = uint*;
    alias HALF_PTR = short;
    alias PHALF_PTR = short*;
    alias UHALF_PTR = ushort;
    alias PUHALF_PTR = ushort*;

    uint HandleToUlong()(HANDLE h)      { return cast(uint) h; }
    int HandleToLong()(HANDLE h)        { return cast(int) h; }
    HANDLE LongToHandle()(LONG_PTR h)   { return cast(HANDLE)h; }
    uint PtrToUlong(const(void)* p)    { return cast(uint) p; }
    uint PtrToUint(const(void)* p)     { return cast(uint) p; }
    int PtrToInt(const(void)* p)       { return cast(int) p; }
    ushort PtrToUshort(const(void)* p) { return cast(ushort) p; }
    short PtrToShort(const(void)* p)   { return cast(short) p; }
    void* IntToPtr()(int i)             { return cast(void*) i; }
    void* UIntToPtr()(uint ui)          { return cast(void*) ui; }
    alias LongToPtr = IntToPtr;
    alias ULongToPtr = UIntToPtr;
}

alias UintToPtr = UIntToPtr, UlongToPtr = UIntToPtr;

enum : UINT_PTR {
    MAXUINT_PTR = UINT_PTR.max
}

enum : INT_PTR {
    MAXINT_PTR = INT_PTR.max,
    MININT_PTR = INT_PTR.min
}

enum : ULONG_PTR {
    MAXULONG_PTR = ULONG_PTR.max
}

enum : LONG_PTR {
    MAXLONG_PTR = LONG_PTR.max,
    MINLONG_PTR = LONG_PTR.min
}

enum : UHALF_PTR {
    MAXUHALF_PTR = UHALF_PTR.max
}

enum : HALF_PTR {
    MAXHALF_PTR = HALF_PTR.max,
    MINHALF_PTR = HALF_PTR.min
}

alias INT8 = byte;
alias PINT8 = byte*;
alias UINT8 = ubyte;
alias PUINT8 = ubyte*;

alias INT16 = short;
alias PINT16 = short*;
alias UINT16 = ushort;
alias PUINT16 = ushort*;

alias LONG32 = int, INT32 = int;
alias PLONG32 = int*, PINT32 = int*;
alias ULONG32 = uint, DWORD32 = uint, UINT32 = uint;
alias PULONG32 = uint*, PDWORD32 = uint*, PUINT32 = uint*;

alias SIZE_T = ULONG_PTR, DWORD_PTR = ULONG_PTR;
alias PSIZE_T = ULONG_PTR*, PDWORD_PTR = ULONG_PTR*;
alias SSIZE_T = LONG_PTR;
alias PSSIZE_T = LONG_PTR*;

alias LONG64 = long, INT64 = long;
alias PLONG64 = long*, PINT64 = long*;
alias ULONG64 = ulong, DWORD64 = ulong, UINT64 = ulong;
alias PULONG64 = ulong*, PDWORD64 = ulong*, PUINT64 = ulong*;
