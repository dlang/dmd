// Copyright (C) 1983-1998 by Symantec
// Copyright (C) 2000-2009 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */


#if __DMC__
#pragma once
#endif

#ifndef TY_H
#define TY_H 1

/*****************************************
 * Data types.
 * (consists of basic type + modifier bits)
 */

// Basic types.
// casttab[][] in exp2.c depends on the order of this
// typromo[] in cpp.c depends on the order too

enum TYM
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
    TYjfunc             = 0x38, // LINKd D function
    TYhfunc             = 0x39, // C function with hidden parameter
    TYnref              = 0x3A, // near reference

    TYcent              = 0x3C, // 128 bit signed integer
    TYucent             = 0x3D, // 128 bit unsigned integer

#if TARGET_SEGMENTED
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
#endif

#if !MARS
    TYmemptr            = 0x2F, // pointer to member
    TYident             = 0x30, // type-argument
    TYtemplate          = 0x31, // unexpanded class template
    TYvtshape           = 0x32, // virtual function table
#endif

    // SIMD vector types        // D type
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

// MARS types
#define TYaarray        TYnptr
#define TYdelegate      (I64 ? TYcent : TYllong)
#define TYdarray        (I64 ? TYucent : TYullong)

    TYMAX               = 0x48,
};

#define mTYbasic        0xFF    /* bit mask for basic types     */
#define tybasic(ty)     ((ty) & mTYbasic)

// These change depending on memory model
extern int TYptrdiff, TYsize, TYsize_t;

/* Linkage type                 */
#define mTYnear         0x0800
#if TARGET_SEGMENTED
#define mTYfar          0x1000
#define mTYcs           0x2000           // in code segment
#endif
#define mTYthread       0x4000
#define mTYLINK         0x7800           // all linkage bits

#if TX86
#define mTYloadds       0x08000
#endif
#define mTYexport       0x10000
#define mTYweak         0x00000
#define mTYimport       0x20000
#define mTYnaked        0x40000
#define mTYMOD          0x78000          // all modifier bits

/* Modifiers to basic types     */

#define mTYarrayhandle  0x0
#define mTYconst        0x100
#define mTYvolatile     0x200
#define mTYrestrict     0               // BUG: add for C99
#define mTYmutable      0               // need to add support
#define mTYunaligned    0               // non-zero for PowerPC

#define mTYimmutable    0x00080000       // immutable data
#define mTYshared       0x00100000       // shared data
#define mTYnothrow      0x00200000       // nothrow function

#if !MARS
#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
#define mTYnoret        0x01000000        // function has no return
#define mTYtransu       0x01000000        // transparent union
#else
#define mTYfar16        0x01000000
#endif
#define mTYstdcall      0x02000000
#define mTYfastcall     0x04000000
#define mTYinterrupt    0x08000000
#define mTYcdecl        0x10000000
#define mTYpascal       0x20000000
#define mTYsyscall      0x40000000
#define mTYjava         0x80000000

#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
#define mTYTFF          0xFE000000
#else
#define mTYTFF          0xFF000000
#endif
#endif

/* Flags in tytab[] array       */
extern unsigned tytab[];
#define TYFLptr         1
#define TYFLreal        2
#define TYFLintegral    4
#define TYFLcomplex     8
#define TYFLimaginary   0x10
#define TYFLuns         0x20
#define TYFLmptr        0x40
#define TYFLfv          0x80    /* TYfptr || TYvptr     */

#define TYFLpascal      0x200       // callee cleans up stack
#define TYFLrevparam    0x400       // function parameters are reversed
#define TYFLnullptr     0x800
#define TYFLshort       0x1000
#define TYFLaggregate   0x2000
#define TYFLfunc        0x4000
#define TYFLref         0x8000
#define TYFLsimd        0x20000     // SIMD vector type
#if TX86
#define TYFLfarfunc     0x100
#define TYFLxmmreg      0x10000     // can be put in XMM register
#endif

/* Groupings of types   */

#define tyintegral(ty)  (tytab[(ty) & 0xFF] & TYFLintegral)

#define tyarithmetic(ty) (tytab[(ty) & 0xFF] & (TYFLintegral | TYFLreal | TYFLimaginary | TYFLcomplex))

#define tyaggregate(ty) (tytab[(ty) & 0xFF] & TYFLaggregate)

#define tyscalar(ty)    (tytab[(ty) & 0xFF] & (TYFLintegral | TYFLreal | TYFLimaginary | TYFLcomplex | TYFLptr | TYFLmptr | TYFLnullptr | TYFLref))

#define tyfloating(ty)  (tytab[(ty) & 0xFF] & (TYFLreal | TYFLimaginary | TYFLcomplex))

#define tyimaginary(ty) (tytab[(ty) & 0xFF] & TYFLimaginary)

#define tycomplex(ty)   (tytab[(ty) & 0xFF] & TYFLcomplex)

#define tyreal(ty)      (tytab[(ty) & 0xFF] & TYFLreal)

// Fits into 64 bit register
#define ty64reg(ty)     (tytab[(ty) & 0xFF] & (TYFLintegral | TYFLptr | TYFLref) && tysize(ty) <= NPTRSIZE)

// Can go in XMM floating point register
#if TX86
#define tyxmmreg(ty)    (tytab[(ty) & 0xFF] & TYFLxmmreg)
#else
#define tyxmmreg(ty)    0
#endif

// Is a vector type
#define tyvector(ty)    (tybasic(ty) >= TYfloat4 && tybasic(ty) <= TYullong2)

#ifndef tyshort
/* Types that are chars or shorts       */
#define tyshort(ty)     (tytab[(ty) & 0xFF] & TYFLshort)
#endif

/* Detect TYlong or TYulong     */
#ifndef tylong
#define tylong(ty)      (tybasic(ty) == TYlong || tybasic(ty) == TYulong)
#endif

/* Use to detect a pointer type */
#ifndef typtr
#define typtr(ty)       (tytab[(ty) & 0xFF] & TYFLptr)
#endif

/* Use to detect a reference type */
#ifndef tyref
#define tyref(ty)       (tytab[(ty) & 0xFF] & TYFLref)
#endif

/* Use to detect a pointer type or a member pointer     */
#ifndef tymptr
#define tymptr(ty)      (tytab[(ty) & 0xFF] & (TYFLptr | TYFLmptr))
#endif

// Use to detect a nullptr type or a member pointer
#ifndef tynullptr
#define tynullptr(ty)      (tytab[(ty) & 0xFF] & TYFLnullptr)
#endif

/* Detect TYfptr or TYvptr      */
#ifndef tyfv
#define tyfv(ty)        (tytab[(ty) & 0xFF] & TYFLfv)
#endif

/* Array to give the size in bytes of a type, -1 means error    */
extern signed char tysize[];
extern signed char tyalignsize[];

// Give size of type
#define tysize(ty)      tysize[(ty) & 0xFF]
#define tyalignsize(ty) tyalignsize[(ty) & 0xFF]

/* All data types that fit in exactly 8 bits    */
#ifndef tybyte
#define tybyte(ty)      (tysize(ty) == 1)
#endif

/* Types that fit into a single machine register        */
#ifndef tyreg
#define tyreg(ty)       (tysize(ty) <= REGSIZE)
#endif

/* Detect function type */
#ifndef tyfunc
#define tyfunc(ty)      (tytab[(ty) & 0xFF] & TYFLfunc)
#endif

/* Detect function type where parameters are pushed left to right    */
#ifndef tyrevfunc
#define tyrevfunc(ty)   (tytab[(ty) & 0xFF] & TYFLrevparam)
#endif

/* Detect unsigned types */
#ifndef tyuns
#define tyuns(ty)       (tytab[(ty) & 0xFF] & (TYFLuns | TYFLptr))
#endif

/* Target dependent info        */
#if TX86
#define TYoffset TYuint         /* offset to an address         */
#endif

/* Detect cpp function type (callee cleans up stack)    */
#ifndef typfunc
#define typfunc(ty)     (tytab[(ty) & 0xFF] & TYFLpascal)
#endif

/* Array to convert a type to its unsigned equivalent   */
extern const tym_t tytouns[];
#ifndef touns
#define touns(ty)       (tytouns[(ty) & 0xFF])
#endif

/* Determine if TYffunc or TYfpfunc (a far function) */
#ifndef tyfarfunc
#if TX86
#define tyfarfunc(ty)   (tytab[(ty) & 0xFF] & TYFLfarfunc)
#else
#define tyfarfunc(ty)   0
#endif
#endif

/* Determine relaxed type       */
#ifndef tyrelax
#define tyrelax(ty)     (_tyrelax[tybasic(ty)])
#endif

// Determine if parameter is a SIMD vector type
#ifndef tysimd
#define tysimd(ty)   (tytab[(ty) & 0xFF] & TYFLsimd)
#endif

/* Array to give the 'relaxed' type for relaxed type checking   */
extern unsigned char _tyrelax[];
#define type_relax      (config.flags3 & CFG3relax)     // !=0 if relaxed type checking
#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
#define type_semirelax  (config.flags3 & CFG3semirelax) // !=0 if semi-relaxed type checking
#else
#define type_semirelax  type_relax
#endif

/* Determine functionally equivalent type       */
extern unsigned char tyequiv[];

/* Give an ascii string for a type      */
extern const char *tystring[];

#if TX86
/* Debugger value for type      */
extern unsigned char dttab[];
extern unsigned short dttab4[];
#endif

#endif /* TY_H */
