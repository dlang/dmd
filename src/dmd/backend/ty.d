/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1983-1998 by Symantec
 *              Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/ty.d, backend/_ty.d)
 */

module dmd.backend.ty;

// Online documentation: https://dlang.org/phobos/dmd_backend_ty.html

extern (C++):
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
    TYldouble           = 0x14, // 80 bit real

    // Add imaginary and complex types for D and C99
    TYifloat            = 0x15,
    TYidouble           = 0x16,
    TYildouble          = 0x17,
    TYcfloat            = 0x18,
    TYcdouble           = 0x19,
    TYcldouble          = 0x1A,

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

    // Used for C++ compiler
    TYmemptr            = 0x2F, // pointer to member
    TYident             = 0x30, // type-argument
    TYtemplate          = 0x31, // unexpanded class template
    TYvtshape           = 0x32, // virtual function table

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

extern __gshared int TYaarray;                            // D type

// These change depending on memory model
extern __gshared int TYdelegate, TYdarray;                // D types
extern __gshared int TYptrdiff, TYsize, TYsize_t;

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

/* Flags in tytab[] array       */
extern __gshared uint[256] tytab;
enum
{
    TYFLptr         = 1,
    TYFLreal        = 2,
    TYFLintegral    = 4,
    TYFLcomplex     = 8,
    TYFLimaginary   = 0x10,
    TYFLuns         = 0x20,
    TYFLmptr        = 0x40,
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

/* Array to give the size in bytes of a type, -1 means error    */
extern __gshared byte[256] _tysize;
extern __gshared byte[256] _tyalignsize;

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
uint tyscalar(tym_t ty) { return tytab[ty & 0xFF] & (TYFLintegral | TYFLreal | TYFLimaginary | TYFLcomplex | TYFLptr | TYFLmptr | TYFLnullptr | TYFLref); }

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
@trusted
bool tyvector(tym_t ty) { return tybasic(ty) >= TYfloat4 && tybasic(ty) <= TYullong4; }

/* Types that are chars or shorts       */
@trusted
uint tyshort(tym_t ty) { return tytab[ty & 0xFF] & TYFLshort; }

/* Detect TYlong or TYulong     */
@trusted
bool tylong(tym_t ty) { return tybasic(ty) == TYlong || tybasic(ty) == TYulong; }

/* Use to detect a pointer type */
@trusted
uint typtr(tym_t ty) { return tytab[ty & 0xFF] & TYFLptr; }

/* Use to detect a reference type */
@trusted
uint tyref(tym_t ty) { return tytab[ty & 0xFF] & TYFLref; }

/* Use to detect a pointer type or a member pointer     */
@trusted
uint tymptr(tym_t ty) { return tytab[ty & 0xFF] & (TYFLptr | TYFLmptr); }

// Use to detect a nullptr type or a member pointer
@trusted
uint tynullptr(tym_t ty) { return tytab[ty & 0xFF] & TYFLnullptr; }

/* Detect TYfptr or TYvptr      */
@trusted
uint tyfv(tym_t ty) { return tytab[ty & 0xFF] & TYFLfv; }

/* All data types that fit in exactly 8 bits    */
@trusted
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
extern __gshared tym_t[256] tytouns;
@trusted
tym_t touns(tym_t ty) { return tytouns[ty & 0xFF]; }

/* Determine if TYffunc or TYfpfunc (a far function) */
@trusted
uint tyfarfunc(tym_t ty) { return tytab[ty & 0xFF] & TYFLfarfunc; }

// Determine if parameter is a SIMD vector type
@trusted
uint tysimd(tym_t ty) { return tytab[ty & 0xFF] & TYFLsimd; }

/* Determine relaxed type       */
extern __gshared ubyte[TYMAX] _tyrelax;
@trusted
uint tyrelax(tym_t ty) { return _tyrelax[tybasic(ty)]; }


/* Determine functionally equivalent type       */
extern __gshared ubyte[TYMAX] tyequiv;

/* Give an ascii string for a type      */
extern (C) { extern __gshared const(char)*[TYMAX] tystring; }

/* Debugger value for type      */
extern __gshared ubyte[TYMAX] dttab;
extern __gshared ushort[TYMAX] dttab4;


@trusted
bool I16() { return _tysize[TYnptr] == 2; }
@trusted
bool I32() { return _tysize[TYnptr] == 4; }
@trusted
bool I64() { return _tysize[TYnptr] == 8; }

