/**
 * Define basic types and type masks
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1983-1998 by Symantec
 *              Copyright (C) 1999-2026 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/backend/ty.d, backend/_ty.d)
 */

module dmd.backend.ty;

// Online documentation: https://dlang.org/phobos/dmd_backend_ty.html

@nogc:
nothrow:
@safe:

alias tym_t = uint;

/*****************************************
 * Data types.
 * (consists of basic type + modifier bits)
 */

// Basic types.
// casttab[][] in exp2.c depends on the order of this
// typromo[] in cpp.c depends on the order too

enum
{
    TYbool              = 0,
    TYchar              = 1,
    TYschar             = 2,    // signed char
    TYuchar             = 3,    // unsigned char
    TYchar8             = 4,
    TYchar16            = 5,
    TYshort             = 6,
    TYwchar_t           = 7,
    TYushort            = 8,    // unsigned short
    TYenum              = 9,    // enumeration value
    TYint               = 0xA,
    TYuint              = 0xB,  // unsigned
    TYlong              = 0xC,
    TYulong             = 0xD,  // unsigned long
    TYdchar             = 0xE,  // 32 bit Unicode char
    TYllong             = 0xF,  // 64 bit long
    TYullong            = 0x10, // 64 bit unsigned long
    TYfloat             = 0x11, // 32 bit real
    TYdouble            = 0x12, // 64 bit real

    // long double is mapped to either of the following at runtime:
    TYdouble_alias      = 0x13, // 64 bit real (but distinct for overload purposes)
    TYreal           = 0x14, // 80 bit real

    // Add imaginary and complex types for D and C99
    TYifloat            = 0x15,
    TYidouble           = 0x16,
    TYireal          = 0x17,
    TYcfloat            = 0x18,
    TYcdouble           = 0x19,
    TYcreal          = 0x1A,

    TYnullptr           = 0x1C,
    TYnptr              = 0x1D, // data segment relative pointer
    TYref               = 0x24, // reference to another type
    TYvoid              = 0x25,
    TYstruct            = 0x26, // watch tyaggregate()
    TYarray             = 0x27, // watch tyaggregate()
    TYnfunc             = 0x28, // near C func
    TYnpfunc            = 0x2A, // near Cpp func
    TYnsfunc            = 0x2C, // near stdcall func
    TYifunc             = 0x2E, // interrupt func
    TYptr               = 0x33, // generic pointer type
    TYmfunc             = 0x37, // NT C++ member func
    TYjfunc             = 0x38, // LINK.d D function
    TYhfunc             = 0x39, // C function with hidden parameter
    TYnref              = 0x3A, // near reference

    TYcent              = 0x3C, // 128 bit signed integer
    TYucent             = 0x3D, // 128 bit unsigned integer

    // Used for segmented architectures
    TYsptr              = 0x1E, // stack segment relative pointer
    TYcptr              = 0x1F, // code segment relative pointer
    TYf16ptr            = 0x20, // special OS/2 far16 pointer
    TYfptr              = 0x21, // far pointer (has segment and offset)
    TYhptr              = 0x22, // huge pointer (has segment and offset)
    TYvptr              = 0x23, // __handle pointer (has segment and offset)
    TYffunc             = 0x29, // far  C func
    TYfpfunc            = 0x2B, // far  Cpp func
    TYfsfunc            = 0x2D, // far stdcall func
    TYf16func           = 0x34, // _far16 _pascal function
    TYnsysfunc          = 0x35, // near __syscall func
    TYfsysfunc          = 0x36, // far __syscall func
    TYfref              = 0x3B, // far reference

    // SIMD 16 byte vector types        // D type
    TYfloat4            = 0x3E, // float[4]
    TYdouble2           = 0x3F, // double[2]
    TYschar16           = 0x40, // byte[16]
    TYuchar16           = 0x41, // ubyte[16]
    TYshort8            = 0x42, // short[8]
    TYushort8           = 0x43, // ushort[8]
    TYlong4             = 0x44, // int[4]
    TYulong4            = 0x45, // uint[4]
    TYllong2            = 0x46, // long[2]
    TYullong2           = 0x47, // ulong[2]

    // SIMD 32 byte vector types        // D type
    TYfloat8            = 0x48, // float[8]
    TYdouble4           = 0x49, // double[4]
    TYschar32           = 0x4A, // byte[32]
    TYuchar32           = 0x4B, // ubyte[32]
    TYshort16           = 0x4C, // short[16]
    TYushort16          = 0x4D, // ushort[16]
    TYlong8             = 0x4E, // int[8]
    TYulong8            = 0x4F, // uint[8]
    TYllong4            = 0x50, // long[4]
    TYullong4           = 0x51, // ulong[4]

    // SIMD 64 byte vector types        // D type
    TYfloat16           = 0x52, // float[16]
    TYdouble8           = 0x53, // double[8]
    TYschar64           = 0x54, // byte[64]
    TYuchar64           = 0x55, // ubyte[64]
    TYshort32           = 0x56, // short[32]
    TYushort32          = 0x57, // ushort[32]
    TYlong16            = 0x58, // int[16]
    TYulong16           = 0x59, // uint[16]
    TYllong8            = 0x5A, // long[8]
    TYullong8           = 0x5B, // ulong[8]

    TYsharePtr          = 0x5C, // pointer to shared data
    TYimmutPtr          = 0x5D, // pointer to immutable data
    TYfgPtr             = 0x5E, // GS: pointer (I32) FS: pointer (I64)
    TYrestrictPtr       = 0x5F, // restrict pointer

    TYnoreturn          = 0x60, // bottom type

    TYMAX               = 0x61,
}

alias TYerror = TYint;

enum
{
    mTYbasic        = 0xFF,          // bit mask for basic types

   // Linkage type
    mTYnear         = 0x0800,
    mTYfar          = 0x1000,        // seg:offset style pointer
    mTYcs           = 0x2000,        // in code segment
    mTYthread       = 0x4000,

    // Used for symbols going in the __thread_data section for TLS variables for Mach-O 64bit
    mTYthreadData   = 0x5000,

    // Used in combination with SCcomdat to output symbols with weak linkage.
    // Compared to a symbol with only SCcomdat, this allows the symbol to be put
    // in any section in the object file.
    mTYweakLinkage  = 0x6000,
    mTYLINK         = 0x7800,        // all linkage bits

    mTYloadds       = 0x08000,       // 16 bit Windows LOADDS attribute
    mTYexport       = 0x10000,
    mTYweak         = 0x00000,
    mTYimport       = 0x20000,
    mTYnaked        = 0x40000,
    mTYMOD          = 0x78000,       // all modifier bits

    // Modifiers to basic types

    mTYarrayhandle  = 0x0,
    mTYconst        = 0x100,
    mTYvolatile     = 0x200,
    mTYrestrict     = 0,             // BUG: add for C99
    mTYmutable      = 0,             // need to add support
    mTYunaligned    = 0,             // non-zero for PowerPC

    mTYimmutable    = 0x00080000,    // immutable data
    mTYshared       = 0x00100000,    // shared data
    mTYnothrow      = 0x00200000,    // nothrow function

    // SROA types
    mTYxmmgpr       = 0x00400000,    // first slice in XMM register, the other in GPR
    mTYgprxmm       = 0x00800000,    // first slice in GPR register, the other in XMM

    mTYnoret        = 0x01000000,    // function has no return
    mTYtransu       = 0x01000000,    // transparent union
    mTYfar16        = 0x01000000,
    mTYstdcall      = 0x02000000,
    mTYfastcall     = 0x04000000,
    mTYinterrupt    = 0x08000000,
    mTYcdecl        = 0x10000000,
    mTYpascal       = 0x20000000,
    mTYsyscall      = 0x40000000,
    mTYjava         = 0x80000000,

    mTYTFF          = 0xFF000000,
}

pure
tym_t tybasic(tym_t ty) { return ty & mTYbasic; }

enum
{
    TYFLptr         = 1,
    TYFLreal        = 2,
    TYFLintegral    = 4,
    TYFLcomplex     = 8,
    TYFLimaginary   = 0x10,
    TYFLuns         = 0x20,
    TYFLfv          = 0x80,       // TYfptr || TYvptr

    TYFLpascal      = 0x200,      // callee cleans up stack
    TYFLrevparam    = 0x400,      // function parameters are reversed
    TYFLnullptr     = 0x800,
    TYFLshort       = 0x1000,
    TYFLaggregate   = 0x2000,
    TYFLfunc        = 0x4000,
    TYFLref         = 0x8000,
    TYFLsimd        = 0x20000,    // SIMD vector type
    TYFLfarfunc     = 0x100,      // __far functions (for segmented architectures)
    TYFLxmmreg      = 0x10000,    // can be put in XMM register
}

// Give size of type
@trusted
byte tysize(tym_t ty)      { return _tysize[ty & 0xFF]; }
@trusted
byte tyalignsize(tym_t ty) { return _tyalignsize[ty & 0xFF]; }


/* Groupings of types   */

@trusted
uint tyintegral(tym_t ty) { return tytab[ty & 0xFF] & TYFLintegral; }

@trusted
uint tyarithmetic(tym_t ty) { return tytab[ty & 0xFF] & (TYFLintegral | TYFLreal | TYFLimaginary | TYFLcomplex); }

@trusted
uint tyaggregate(tym_t ty) { return tytab[ty & 0xFF] & TYFLaggregate; }

@trusted
uint tyscalar(tym_t ty) { return tytab[ty & 0xFF] & (TYFLintegral | TYFLreal | TYFLimaginary | TYFLcomplex | TYFLptr | TYFLnullptr | TYFLref); }

@trusted
uint tyfloating(tym_t ty) { return tytab[ty & 0xFF] & (TYFLreal | TYFLimaginary | TYFLcomplex); }

@trusted
uint tyimaginary(tym_t ty) { return tytab[ty & 0xFF] & TYFLimaginary; }

@trusted
uint tycomplex(tym_t ty) { return tytab[ty & 0xFF] & TYFLcomplex; }

@trusted
uint tyreal(tym_t ty) { return tytab[ty & 0xFF] & TYFLreal; }

// Fits into 64 bit register
@trusted
bool ty64reg(tym_t ty) { return tytab[ty & 0xFF] & (TYFLintegral | TYFLptr | TYFLref) && tysize(ty) <= _tysize[TYnptr]; }

// Can go in XMM floating point register
@trusted
uint tyxmmreg(tym_t ty) { return tytab[ty & 0xFF] & TYFLxmmreg; }

// Is a vector type
bool tyvector(tym_t ty) { return tybasic(ty) >= TYfloat4 && tybasic(ty) <= TYullong4; }

/* Types that are chars or shorts       */
@trusted
uint tyshort(tym_t ty) { return tytab[ty & 0xFF] & TYFLshort; }

/* Detect TYlong or TYulong     */
bool tylong(tym_t ty) { return tybasic(ty) == TYlong || tybasic(ty) == TYulong; }

/* Use to detect a pointer type */
@trusted
uint typtr(tym_t ty) { return tytab[ty & 0xFF] & TYFLptr; }

/* Use to detect a reference type */
@trusted
uint tyref(tym_t ty) { return tytab[ty & 0xFF] & TYFLref; }

// Use to detect a nullptr type
@trusted
uint tynullptr(tym_t ty) { return tytab[ty & 0xFF] & TYFLnullptr; }

/* Detect TYfptr or TYvptr      */
@trusted
uint tyfv(tym_t ty) { return tytab[ty & 0xFF] & TYFLfv; }

/* All data types that fit in exactly 8 bits    */
bool tybyte(tym_t ty) { return tysize(ty) == 1; }

/* Types that fit into a single machine register        */
@trusted
bool tyreg(tym_t ty) { return tysize(ty) <= _tysize[TYnptr]; }

/* Detect function type */
@trusted
uint tyfunc(tym_t ty) { return tytab[ty & 0xFF] & TYFLfunc; }

/* Detect function type where parameters are pushed left to right    */
@trusted
uint tyrevfunc(tym_t ty) { return tytab[ty & 0xFF] & TYFLrevparam; }

/* Detect uint types */
@trusted
uint tyuns(tym_t ty) { return tytab[ty & 0xFF] & (TYFLuns | TYFLptr); }

/* Target dependent info        */
alias TYoffset = TYuint;         // offset to an address

/* Detect cpp function type (callee cleans up stack)    */
@trusted
uint typfunc(tym_t ty) { return tytab[ty & 0xFF] & TYFLpascal; }

/* Array to convert a type to its unsigned equivalent   */
@trusted
tym_t touns(tym_t ty) { return tytouns[ty & 0xFF]; }

/* Determine if TYffunc or TYfpfunc (a far function) */
@trusted
uint tyfarfunc(tym_t ty) { return tytab[ty & 0xFF] & TYFLfarfunc; }

// Determine if parameter is a SIMD vector type
@trusted
uint tysimd(tym_t ty) { return tytab[ty & 0xFF] & TYFLsimd; }

@trusted
uint tyrelax(tym_t ty) { return _tyrelax[tybasic(ty)]; }

@trusted
bool I16() { return _tysize[TYnptr] == 2; }
@trusted
bool I32() { return _tysize[TYnptr] == 4; }
@trusted
bool I64() { return _tysize[TYnptr] == 8; }

__gshared:

// These change depending on memory model
tym_t TYptrdiff = TYint;
tym_t TYsize = TYuint;
tym_t TYsize_t = TYuint;
tym_t TYaarray = TYnptr;
tym_t TYdelegate = TYllong;
tym_t TYdarray = TYullong;
tym_t pointertype = TYnptr;     /* default data pointer type            */

__gshared uint[256] tytab = tytab_init;
private enum tytab_init =
() {
    uint[256] tab;
    foreach (i; TXptr)        { tab[i] |= TYFLptr; }
    foreach (i; TXptr_nflat)  { tab[i] |= TYFLptr; }
    foreach (i; TXreal)       { tab[i] |= TYFLreal; }
    foreach (i; TXintegral)   { tab[i] |= TYFLintegral; }
    foreach (i; TXimaginary)  { tab[i] |= TYFLimaginary; }
    foreach (i; TXcomplex)    { tab[i] |= TYFLcomplex; }
    foreach (i; TXuns)        { tab[i] |= TYFLuns; }
    foreach (i; TXfv)         { tab[i] |= TYFLfv; }
    foreach (i; TXfarfunc)    { tab[i] |= TYFLfarfunc; }
    foreach (i; TXpasfunc)    { tab[i] |= TYFLpascal; }
    foreach (i; TXrevfunc)    { tab[i] |= TYFLrevparam; }
    foreach (i; TXshort)      { tab[i] |= TYFLshort; }
    foreach (i; TXaggregate)  { tab[i] |= TYFLaggregate; }
    foreach (i; TXref)        { tab[i] |= TYFLref; }
    foreach (i; TXfunc)       { tab[i] |= TYFLfunc; }
    foreach (i; TXnullptr)    { tab[i] |= TYFLnullptr; }
    foreach (i; TXpasfunc_nf) { tab[i] |= TYFLpascal; }
    foreach (i; TXrevfunc_nf) { tab[i] |= TYFLrevparam; }
    foreach (i; TXref_nflat)  { tab[i] |= TYFLref; }
    foreach (i; TXfunc_nflat) { tab[i] |= TYFLfunc; }
    foreach (i; TXxmmreg)     { tab[i] |= TYFLxmmreg; }
    foreach (i; TXsimd)       { tab[i] |= TYFLsimd; }
    return tab;
} ();

/// Give an ascii string for a type
__gshared const(char)*[TYMAX] tystring =
() {
    const(char)*[TYMAX] ret = [
        TYbool    : "bool",
        TYchar    : "char",
        TYchar8   : "char8_t",
        TYchar16  : "char16_t",
        TYshort   : "short",

        TYenum    : "enum",
        TYint     : "int",

        TYlong    : "long",
        TYdchar   : "dchar",
        TYcent    : "cent",
        TYucent   : "ucent",
        TYfloat   : "float",
        TYdouble  : "double",
        TYdouble_alias : "double alias",

        TYfloat4  : "float4",
        TYdouble2 : "double2",
        TYshort8  : "short8",
        TYlong4   : "int4",

        TYfloat8  : "float8",
        TYdouble4 : "double4",
        TYshort16 : "short16",
        TYlong8   : "int8",

        TYfloat16 : "float16",
        TYdouble8 : "double8",
        TYshort32 : "short32",
        TYlong16  : "int16",

        TYnptr    : "*",
        TYref     : "&",
        TYvoid    : "void",
        TYnoreturn : "noreturn",
        TYstruct  : "struct",
        TYarray   : "array",
        TYnfunc   : "C func",
        TYnpfunc  : "Pascal func",
        TYnsfunc  : "std func",
        TYptr     : "*",
        TYmfunc   : "member func",
        TYjfunc   : "D func",
        TYhfunc   : "C func",
        TYnref    : "__near &",

        TYsptr     : "__ss *",
        TYcptr     : "__cs *",
        TYf16ptr   : "__far16 *",
        TYfptr     : "__far *",
        TYhptr     : "__huge *",
        TYvptr     : "__handle *",
        TYimmutPtr : "__immutable *",
        TYsharePtr : "__shared *",
        TYrestrictPtr : "__restrict *",
        TYfgPtr    : "__fg *",
        TYffunc    : "far C func",
        TYfpfunc   : "far Pascal func",
        TYfsfunc   : "far std func",
        TYf16func  : "_far16 Pascal func",
        TYnsysfunc : "sys func",
        TYfsysfunc : "far sys func",
        TYfref     : "__far &",

        TYifunc    : "interrupt func",

        TYschar     : "byte",
        TYuchar     : "ubyte",
        TYwchar_t   : "wchar",

        TYnullptr   : "typeof(null)",

        TYushort    : "ushort",
        TYuint      : "uint",
        TYulong     : "ulong",

        TYreal   : "real",

        TYifloat    : "ifloat",
        TYidouble   : "idouble",
        TYireal  : "ireal",

        TYcfloat    : "cfloat",
        TYcdouble   : "cdouble",
        TYcreal  : "creal",

        TYschar16   : "byte[16]",
        TYuchar16   : "ubyte[16]",
        TYushort8   : "ushort[8]",
        TYulong4    : "ulong[4]", // c_ulong
        TYllong2    : "long[2]",
        TYullong2   : "ulong[2]",

        TYschar32   : "byte[32]",
        TYuchar32   : "ubyte[32]",
        TYushort16  : "ushort[16]",
        TYulong8    : "ulong[8]", // c_ulong
        TYllong4    : "long[4]",
        TYullong4   : "ulong[4]",

        TYschar64   : "byte[64]",
        TYuchar64   : "ubyte[64]",
        TYushort32  : "ushort[32]",
        TYulong16   : "ulong[16]", // c_ulong
        TYllong8    : "long[8]",
        TYullong8   : "ulong[8]",
    ];

    ret[TYullong] = ret[TYulong]; // c_ulong
    ret[TYllong]  = ret[TYlong]; // c_long

    return ret;
} ();

/// Map to unsigned version of type
__gshared tym_t[256] tytouns = tytouns_init;
private enum tytouns_init =
() {
    tym_t[256] tab;
    foreach (ty; 0 .. TYMAX)
    {
        tym_t tym;
        switch (ty)
        {
            case TYchar:      tym = TYuchar;    break;
            case TYschar:     tym = TYuchar;    break;
            case TYshort:     tym = TYushort;   break;
            case TYushort:    tym = TYushort;   break;

            case TYenum:      tym = TYuint;     break;
            case TYint:       tym = TYuint;     break;

            case TYlong:      tym = TYulong;    break;
            case TYllong:     tym = TYullong;   break;
            case TYcent:      tym = TYucent;    break;

            case TYschar16:   tym = TYuchar16;  break;
            case TYshort8:    tym = TYushort8;  break;
            case TYlong4:     tym = TYulong4;   break;
            case TYllong2:    tym = TYullong2;  break;

            case TYschar32:   tym = TYuchar32;  break;
            case TYshort16:   tym = TYushort16; break;
            case TYlong8:     tym = TYulong8;   break;
            case TYllong4:    tym = TYullong4;  break;

            case TYschar64:   tym = TYuchar64;  break;
            case TYshort32:   tym = TYushort32; break;
            case TYlong16:    tym = TYulong16;  break;
            case TYllong8:    tym = TYullong8;  break;

            default:          tym = ty;         break;
        }
        tab[ty] = tym;
    }
    return tab;
} ();

/// Map to relaxed version of type
__gshared ubyte[TYMAX] _tyrelax = _tyrelax_init;
private enum _tyrelax_init = (){
    ubyte[TYMAX] tab;
    foreach (ty; 0 .. TYMAX)
    {
        tym_t tym;
        switch (ty)
        {
            case TYbool:      tym = TYchar;  break;
            case TYschar:     tym = TYchar;  break;
            case TYuchar:     tym = TYchar;  break;
            case TYchar8:     tym = TYchar;  break;
            case TYchar16:    tym = TYint;   break;

            case TYshort:     tym = TYint;   break;
            case TYushort:    tym = TYint;   break;
            case TYwchar_t:   tym = TYint;   break;

            case TYenum:      tym = TYint;   break;
            case TYuint:      tym = TYint;   break;

            case TYulong:     tym = TYlong;  break;
            case TYdchar:     tym = TYlong;  break;
            case TYullong:    tym = TYllong; break;
            case TYucent:     tym = TYcent;  break;

            case TYnullptr:   tym = TYptr;   break;

            default:          tym = ty;      break;
        }
        tab[ty] = cast(ubyte)tym;
    }
    return tab;
} ();

/// Map to equivalent version of type
__gshared ubyte[TYMAX] tyequiv = tyequiv_init;
private enum tyequiv_init =
() {
    ubyte[TYMAX] tab;
    foreach (ty; 0 .. TYMAX)
    {
        tym_t tym;
        switch (ty)
        {
            case TYchar:      tym = TYschar;  break;    // chars are signed by default
            case TYint:       tym = TYshort;  break;    // adjusted in util_set32()
            case TYuint:      tym = TYushort; break;    // adjusted in util_set32()

            default:          tym = ty;       break;
        }
        tab[ty] = cast(ubyte)tym;
    }
    return tab;
} ();

/// Size of a type
/// -1 means error

import dmd.backend.cdef : CHARSIZE,SHORTSIZE,WCHARSIZE,LONGSIZE,LLONGSIZE,CENTSIZE,FLOATSIZE,DOUBLESIZE,TMAXSIZE;

__gshared byte[256] _tysize =
[
    TYbool    : 1,
    TYchar    : 1,
    TYschar   : 1,
    TYuchar   : 1,
    TYchar8   : 1,
    TYchar16  : 2,
    TYshort   : SHORTSIZE,
    TYwchar_t : 2,
    TYushort  : SHORTSIZE,

    TYenum    : -1,
    TYint     : 2,
    TYuint    : 2,

    TYlong    : LONGSIZE,
    TYulong   : LONGSIZE,
    TYdchar   : 4,
    TYllong   : LLONGSIZE,
    TYullong  : LLONGSIZE,
    TYcent    : 16,
    TYucent   : 16,
    TYfloat   : FLOATSIZE,
    TYdouble  : DOUBLESIZE,
    TYdouble_alias : 8,
    TYreal : -1,

    TYifloat   : FLOATSIZE,
    TYidouble  : DOUBLESIZE,
    TYireal : -1,

    TYcfloat   : 2*FLOATSIZE,
    TYcdouble  : 2*DOUBLESIZE,
    TYcreal : -1,

    TYfloat4  : 16,
    TYdouble2 : 16,
    TYschar16 : 16,
    TYuchar16 : 16,
    TYshort8  : 16,
    TYushort8 : 16,
    TYlong4   : 16,
    TYulong4  : 16,
    TYllong2  : 16,
    TYullong2 : 16,

    TYfloat8  : 32,
    TYdouble4 : 32,
    TYschar32 : 32,
    TYuchar32 : 32,
    TYshort16 : 32,
    TYushort16 : 32,
    TYlong8   : 32,
    TYulong8  : 32,
    TYllong4  : 32,
    TYullong4 : 32,

    TYfloat16 : 64,
    TYdouble8 : 64,
    TYschar64 : 64,
    TYuchar64 : 64,
    TYshort32 : 64,
    TYushort32 : 64,
    TYlong16  : 64,
    TYulong16 : 64,
    TYllong8  : 64,
    TYullong8 : 64,

    TYnullptr : 2,
    TYnptr    : 2,
    TYref     : -1,
    TYvoid    : -1,
    TYnoreturn : 0,
    TYstruct  : -1,
    TYarray   : -1,
    TYnfunc   : -1,
    TYnpfunc  : -1,
    TYnsfunc  : -1,
    TYptr     : 2,
    TYmfunc   : -1,
    TYjfunc   : -1,
    TYhfunc   : -1,
    TYnref    : 2,

    TYsptr     : 2,
    TYcptr     : 2,
    TYf16ptr   : 4,
    TYfptr     : 4,
    TYhptr     : 4,
    TYvptr     : 4,
    TYimmutPtr : 2,
    TYsharePtr : 2,
    TYrestrictPtr : 2,
    TYfgPtr    : 2,
    TYffunc    : -1,
    TYfpfunc   : -1,
    TYfsfunc   : -1,
    TYf16func  : -1,
    TYnsysfunc : -1,
    TYfsysfunc : -1,
    TYfref     : 4,

    TYifunc    : -1,
];

/// Size of a type to use for alignment
/// -1 means error
// set alignment after we know the target
enum SET_ALIGN = -1;
__gshared byte[256] _tyalignsize =
[
    TYbool    : 1,
    TYchar    : 1,
    TYschar   : 1,
    TYuchar   : 1,
    TYchar8   : 1,
    TYchar16  : 2,
    TYshort   : SHORTSIZE,
    TYwchar_t : 2,
    TYushort  : SHORTSIZE,

    TYenum    : -1,
    TYint     : 2,
    TYuint    : 2,

    TYlong    : LONGSIZE,
    TYulong   : LONGSIZE,
    TYdchar   : 4,
    TYllong   : LLONGSIZE,
    TYullong  : LLONGSIZE,
    TYcent    : 8,
    TYucent   : 8,
    TYfloat   : FLOATSIZE,
    TYdouble  : DOUBLESIZE,
    TYdouble_alias : 8,
    TYreal : SET_ALIGN,

    TYifloat   : FLOATSIZE,
    TYidouble  : DOUBLESIZE,
    TYireal : SET_ALIGN,

    TYcfloat   : 2*FLOATSIZE,
    TYcdouble  : DOUBLESIZE,
    TYcreal : SET_ALIGN,

    TYfloat4  : 16,
    TYdouble2 : 16,
    TYschar16 : 16,
    TYuchar16 : 16,
    TYshort8  : 16,
    TYushort8 : 16,
    TYlong4   : 16,
    TYulong4  : 16,
    TYllong2  : 16,
    TYullong2 : 16,

    TYfloat8  : 32,
    TYdouble4 : 32,
    TYschar32 : 32,
    TYuchar32 : 32,
    TYshort16 : 32,
    TYushort16 : 32,
    TYlong8   : 32,
    TYulong8  : 32,
    TYllong4  : 32,
    TYullong4 : 32,

    TYfloat16 : 64,
    TYdouble8 : 64,
    TYschar64 : 64,
    TYuchar64 : 64,
    TYshort32 : 64,
    TYushort32 : 64,
    TYlong16  : 64,
    TYulong16 : 64,
    TYllong8  : 64,
    TYullong8 : 64,

    TYnullptr : 2,
    TYnptr    : 2,
    TYref     : -1,
    TYvoid    : -1,
    TYnoreturn : 0,
    TYstruct  : -1,
    TYarray   : -1,
    TYnfunc   : -1,
    TYnpfunc  : -1,
    TYnsfunc  : -1,
    TYptr     : 2,
    TYmfunc   : -1,
    TYjfunc   : -1,
    TYhfunc   : -1,
    TYnref    : 2,

    TYsptr     : 2,
    TYcptr     : 2,
    TYf16ptr   : 4,
    TYfptr     : 4,
    TYhptr     : 4,
    TYvptr     : 4,
    TYimmutPtr : 2,
    TYsharePtr : 2,
    TYrestrictPtr : 2,
    TYfgPtr    : 2,
    TYffunc    : -1,
    TYfpfunc   : -1,
    TYfsfunc   : -1,
    TYf16func  : -1,
    TYnsysfunc : -1,
    TYfsysfunc : -1,
    TYfref     : 4,

    TYifunc    : -1,
];


private:
extern(D):

static immutable TXptr        = [ TYnptr ];
static immutable TXptr_nflat  = [ TYsptr,TYcptr,TYf16ptr,TYfptr,TYhptr,TYvptr,TYimmutPtr,TYsharePtr,TYrestrictPtr,TYfgPtr ];
static immutable TXreal       = [ TYfloat,TYdouble,TYdouble_alias,TYreal,
                     TYfloat4,TYdouble2,
                     TYfloat8,TYdouble4,
                     TYfloat16,TYdouble8,
                   ];
static immutable TXimaginary  = [ TYifloat,TYidouble,TYireal, ];
static immutable TXcomplex    = [ TYcfloat,TYcdouble,TYcreal, ];
static immutable TXintegral   = [ TYbool,TYchar,TYschar,TYuchar,TYshort,
                     TYwchar_t,TYushort,TYenum,TYint,TYuint,
                     TYlong,TYulong,TYllong,TYullong,TYdchar,
                     TYschar16,TYuchar16,TYshort8,TYushort8,
                     TYlong4,TYulong4,TYllong2,TYullong2,
                     TYschar32,TYuchar32,TYshort16,TYushort16,
                     TYlong8,TYulong8,TYllong4,TYullong4,
                     TYschar64,TYuchar64,TYshort32,TYushort32,
                     TYlong16,TYulong16,TYllong8,TYullong8,
                     TYchar16,TYcent,TYucent,
                   ];
static immutable TXref        = [ TYnref,TYref ];
static immutable TXfunc       = [ TYnfunc,TYnpfunc,TYnsfunc,TYifunc,TYmfunc,TYjfunc,TYhfunc ];
static immutable TXref_nflat  = [ TYfref ];
static immutable TXfunc_nflat = [ TYffunc,TYfpfunc,TYf16func,TYfsfunc,TYnsysfunc,TYfsysfunc, ];
static immutable TXuns        = [ TYuchar,TYushort,TYuint,TYulong,
                     TYwchar_t,
                     TYuchar16,TYushort8,TYulong4,TYullong2,
                     TYdchar,TYullong,TYucent,TYchar16 ];
static immutable TXnullptr    = [ TYnullptr ];
static immutable TXfv         = [ TYfptr, TYvptr ];
static immutable TXfarfunc    = [ TYffunc,TYfpfunc,TYfsfunc,TYfsysfunc ];
static immutable TXpasfunc    = [ TYnpfunc,TYnsfunc,TYmfunc,TYjfunc ];
static immutable TXpasfunc_nf = [ TYfpfunc,TYf16func,TYfsfunc, ];
static immutable TXrevfunc    = [ TYnpfunc,TYjfunc ];
static immutable TXrevfunc_nf = [ TYfpfunc,TYf16func, ];
static immutable TXshort      = [ TYbool,TYchar,TYschar,TYuchar,TYshort,
                      TYwchar_t,TYushort,TYchar16 ];
static immutable TXaggregate  = [ TYstruct,TYarray ];
static immutable TXxmmreg     = [
                     TYfloat,TYdouble,TYifloat,TYidouble,
                     //TYcfloat,TYcdouble,
                     TYfloat4,TYdouble2,
                     TYschar16,TYuchar16,TYshort8,TYushort8,
                     TYlong4,TYulong4,TYllong2,TYullong2,
                     TYfloat8,TYdouble4,
                     TYschar32,TYuchar32,TYshort16,TYushort16,
                     TYlong8,TYulong8,TYllong4,TYullong4,
                     TYschar64,TYuchar64,TYshort32,TYushort32,
                     TYlong16,TYulong16,TYllong8,TYullong8,
                     TYfloat16,TYdouble8,
                    ];
static immutable TXsimd       = [
                     TYfloat4,TYdouble2,
                     TYschar16,TYuchar16,TYshort8,TYushort8,
                     TYlong4,TYulong4,TYllong2,TYullong2,
                     TYfloat8,TYdouble4,
                     TYschar32,TYuchar32,TYshort16,TYushort16,
                     TYlong8,TYulong8,TYllong4,TYullong4,
                     TYschar64,TYuchar64,TYshort32,TYushort32,
                     TYlong16,TYulong16,TYllong8,TYullong8,
                     TYfloat16,TYdouble8,
                    ];
