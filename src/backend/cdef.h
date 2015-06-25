// Copyright (C) 1985-1998 by Symantec
// Copyright (C) 2000-2011 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */


/* Macros defined by the compiler, not the code:

    Compiler:
        __DMC__         Digital Mars compiler
        _MSC_VER        Microsoft compiler
        __GNUC__        Gnu compiler
        __clang__       Clang compiler
        __llvm__        Compiler using LLVM as backend (LLVM-GCC/Clang)

    Host operating system:
        _WIN32          Microsoft NT, Windows 95, Windows 98, Win32s, Windows 2000
        _WIN64          Windows for AMD64
        __linux__       Linux
        __APPLE__       Mac OSX
        __FreeBSD__     FreeBSD
        __OpenBSD__     OpenBSD
        __sun           Solaris, OpenSolaris, SunOS, OpenIndiana, etc
        __OS2__         IBM OS/2
        DOS386          32 bit DOS extended executable
        DOS16RM         Rational Systems 286 DOS extender

    Compiler executable type:
        _WINDLL         if building a _WIN32 DLL

    Host CPU:
        _M_I86          Intel processor
        _M_AMD64        AMD 64 processor

    Hosts no longer supported:
        __OS2__         IBM OS/2
        DOS386          32 bit DOS extended executable
        DOS16RM         Rational Systems 286 DOS extender
        _MSDOS          MSDOS

One and only one of these macros must be set by the makefile:

        SPP             Build C/C++ preprocessor
        SCPP            Build C/C++ compiler
        MARS            Build Mars compiler
 */

/* Windows/DOS/DOSX Version
 * ------------------------
 * There are two main issues: hosting the compiler on windows,
 * and generating (targetting) windows/dos/dosx executables.
 * The "_WIN32" and "__DMC__" macros control hosting issues
 * for operating system and compiler dependencies, respectively.
 * To target linux executables, use OMFOBJ for things specific to the
 * OMF object file format, and TARGET_WINDOS for things specific to
 * the windows/dos/dosx memory model.
 * If this is all done right, one could generate a win/dos/dosx object file
 * even when compiling on linux, and vice versa.
 * The compiler source code currently uses these macros very inconsistently
 * with these goals, and should be fixed.
 */

/* Linux Version
 * -------------
 * There are two main issues: hosting the compiler on linux,
 * and generating (targetting) linux executables.
 * The "linux" and "__GNUC__" macros control hosting issues
 * for operating system and compiler dependencies, respectively.
 * To target linux executables, use ELFOBJ for things specific to the
 * ELF object file format, and TARGET_LINUX for things specific to
 * the linux memory model.
 * If this is all done right, one could generate a linux object file
 * even when compiling on win32, and vice versa.
 * The compiler source code currently uses these macros very inconsistently
 * with these goals, and should be fixed.
 */

/* OSX Version
 * -------------
 * There are two main issues: hosting the compiler on OSX,
 * and generating (targetting) OSX executables.
 * The "__APPLE__" and "__GNUC__" macros control hosting issues
 * for operating system and compiler dependencies, respectively.
 * To target OSX executables, use MACHOBJ for things specific to the
 * MACH-O object file format, and TARGET_OSX for things specific to
 * the OSX memory model.
 * If this is all done right, one could generate an OSX object file
 * even when compiling on win32, and vice versa.
 * The compiler source code currently uses these macros very inconsistently
 * with these goals, and should be fixed.
 */

/* FreeBSD Version
 * -------------
 * There are two main issues: hosting the compiler on FreeBSD,
 * and generating (targetting) FreeBSD executables.
 * The "__FreeBSD__" and "__GNUC__" macros control hosting issues
 * for operating system and compiler dependencies, respectively.
 * To target FreeBSD executables, use ELFOBJ for things specific to the
 * ELF object file format, and TARGET_FREEBSD for things specific to
 * the FreeBSD memory model.
 * If this is all done right, one could generate a FreeBSD object file
 * even when compiling on win32, and vice versa.
 * The compiler source code currently uses these macros very inconsistently
 * with these goals, and should be fixed.
 */

/* OpenBSD Version
 * -------------
 * There are two main issues: hosting the compiler on OpenBSD,
 * and generating (targetting) OpenBSD executables.
 * The "__OpenBSD__" and "__GNUC__" macros control hosting issues
 * for operating system and compiler dependencies, respectively.
 * To target OpenBSD executables, use ELFOBJ for things specific to the
 * ELF object file format, and TARGET_FREEBSD for things specific to
 * the OpenBSD memory model.
 * If this is all done right, one could generate a OpenBSD object file
 * even when compiling on win32, and vice versa.
 * The compiler source code currently uses these macros very inconsistently
 * with these goals, and should be fixed.
 */

/* Solaris Version
 * -------------
 * There are two main issues: hosting the compiler on Solaris,
 * and generating (targetting) Solaris executables.
 * The "__sun" and "__GNUC__" macros control hosting issues
 * for operating system and compiler dependencies, respectively.
 * To target Solaris executables, use ELFOBJ for things specific to the
 * ELF object file format, and TARGET_SOLARIS for things specific to
 * the Solaris memory model.
 * If this is all done right, one could generate a Solaris object file
 * even when compiling on win32, and vice versa.
 * The compiler source code currently uses these macros very inconsistently
 * with these goals, and should be fixed.
 */

#ifndef CDEF_H
#define CDEF_H  1

#define VERSION "8.58.0"        // for banner and imbedding in .OBJ file
#define VERSIONHEX "0x858"      // for __DMC__ macro
#define VERSIONINT 0x858        // for precompiled headers and DLL version


/***********************************
 * Target machine types:
 */

#if !MARS
#define DM_TARGET_CPU_X86 1
#define TX86            1               // target is Intel 80X86 processor
#endif

#if DM_TARGET_CPU_X86
#define TX86            1               // target is Intel 80X86 processor
#endif

// Set to 1 using the makefile
#ifndef TARGET_LINUX
#if 0 //__linux__
#define TARGET_LINUX    1
#else
#define TARGET_LINUX    0               // target is a linux executable
#endif
#endif

// Set to 1 using the makefile
#ifndef TARGET_OSX
#define TARGET_OSX      0               // target is an OSX executable
#endif

// Set to 1 using the makefile
#ifndef TARGET_FREEBSD
#define TARGET_FREEBSD  0               // target is a FreeBSD executable
#endif

// Set to 1 using the makefile
#ifndef TARGET_OPENBSD
#define TARGET_OPENBSD  0               // target is an OpenBSD executable
#endif

// Set to 1 using the makefile
#ifndef TARGET_SOLARIS
#define TARGET_SOLARIS  0               // target is a Solaris executable
#endif

// This is the default
#ifndef TARGET_WINDOS
#define TARGET_WINDOS   (!(TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS))
#endif

#if __GNUC__
#include "cdeflnx.h"
#endif

#if _WINDLL
#define SUFFIX  "nd"
#elif _WIN64
#define SUFFIX  "a"
#elif _WIN32
#define SUFFIX  "n"
#else
#define SUFFIX  ""
#endif

// C++ Language Features
#define ANGLE_BRACKET_HACK      0       // >> means two template arglist closes

// C Language Features
#define CPP_COMMENT             1       // allow C++ style comments

// C/C++ Language Features
#define IMPLIED_PRAGMA_ONCE     1       // include guards count as #pragma once
#define PSEUDO_REGS             1
#define INLINE_ASM              1       // support inline assembler
#define HIDDENPARAM_1ST_ARG     1
#define HEADER_LIST             1
#define PASCAL_STRINGS          0
#define KEYWORD_WITH            1
#define EECONTEXT               1
#define LOCALE                  0       // locale support for Unicode conversion
#define HEXFLOATS               1       // support hex floating point constants
#define OVERLOAD_CV_PARAM       1       // if int foo(int i) and int foo(const int i)
                                        // are different
#define CPP0X                   1       // support C++0x features

// Support generating code for 16 bit memory models
#define SIXTEENBIT              (SCPP && TARGET_WINDOS)

/* Set for supporting the FLAT memory model.
 * This is not quite the same as !SIXTEENBIT, as one could
 * have near/far with 32 bit code.
 */
#define TARGET_SEGMENTED     (!MARS && TARGET_WINDOS)


#define STATEMENT_SCOPES CPP

#if __GNUC__
#define LDOUBLE                 0       // no support for true long doubles
#else
#define LDOUBLE         (config.exe == EX_NT)   // support true long doubles
#endif

#if _MSC_VER
#include "longdouble.h"
#else
typedef long double longdouble;
#endif

// Precompiled header variations
#define MEMORYHX        (_WINDLL && _WIN32)     // HX and SYM files are cached in memory
#define MMFIO           (_WIN32 || __linux__ || __APPLE__ || __FreeBSD__ || __OpenBSD__ || __sun)  // if memory mapped files
#define LINEARALLOC     _WIN32  // if we can reserve address ranges

// H_STYLE takes on one of these precompiled header methods
#define H_NONE          1       // no hydration/dehydration necessary
#define H_BIT0          2       // bit 0 of the pointer determines if pointer
                                // is dehydrated, an offset is added to
                                // hydrate it
#define H_OFFSET        4       // the address range of the pointer determines
                                // if pointer is dehydrated, and an offset is
                                // added to hydrate it. No dehydration necessary.
#define H_COMPLEX       8       // dehydrated pointers have bit 0 set, hydrated
                                // pointers are in non-contiguous buffers

// Do we need hydration code
#define HYDRATE         (H_STYLE & (H_BIT0 | H_OFFSET | H_COMPLEX))

// Do we need dehydration code
#define DEHYDRATE       (H_STYLE & (H_BIT0 | H_COMPLEX))

// Determine hydration style
//      NT console:     H_NONE
//      NT DLL:         H_OFFSET
//      DOSX:           H_COMPLEX
#if MARS
#define H_STYLE         H_NONE                  // precompiled headers only used for C/C++ compiler
#else
#if MMFIO
#if _WINDLL
#define H_STYLE         H_OFFSET
#else
#define H_STYLE         H_OFFSET //H_NONE
#endif
#elif LINEARALLOC
#define H_STYLE         H_BIT0
#else
#define H_STYLE         H_COMPLEX
#endif
#endif

// NT structured exception handling
//      0: no support
//      1: old style
//      2: new style
#define NTEXCEPTIONS            2

#define NEWSTATICDTOR           1       // support new style static destructors

// For Shared Code Base
#define TARGET_INLINEFUNC_NAMES
#define PASCAL pascal
#if _WINDLL
#define dbg_printf dll_printf
#else
#define dbg_printf printf
#endif

#ifndef ERRSTREAM
#define ERRSTREAM stdout
#endif
#define err_printf printf
#define err_vprintf vfprintf
#define err_fputc fputc
#define dbg_fputc fputc
#define LF '\n'
#define LF_STR "\n"
#define CR '\r'
#define ANSI        config.ansi_c
#define ANSI_STRICT config.ansi_c
#define ANSI_RELAX  config.ansi_c
#ifndef TRIGRAPHS
#define TRIGRAPHS   ANSI
#endif
#define ARG_TRUE
#define ARG_FALSE
#define T80x86(x)       x

// For Share MEM_ macros - default to mem_xxx package
// PH           precompiled header
// PARF         parser, life of function
// PARC         parser, life of compilation
// BEF          back end, function
// BEC          back end, compilation

#define MEM_PH_FREE      mem_free
#define MEM_PARF_FREE    mem_free
#define MEM_PARC_FREE    mem_free
#define MEM_BEF_FREE     mem_free
#define MEM_BEC_FREE     mem_free

#define MEM_PH_CALLOC    mem_calloc
#define MEM_PARC_CALLOC  mem_calloc
#define MEM_PARF_CALLOC  mem_calloc
#define MEM_BEF_CALLOC   mem_calloc
#define MEM_BEC_CALLOC   mem_calloc

#define MEM_PH_MALLOC    mem_malloc
#define MEM_PARC_MALLOC  mem_malloc
#define MEM_PARF_MALLOC  mem_malloc
#define MEM_BEF_MALLOC   mem_malloc
#define MEM_BEC_MALLOC   mem_malloc

#define MEM_PH_STRDUP    mem_strdup
#define MEM_PARC_STRDUP  mem_strdup
#define MEM_PARF_STRDUP  mem_strdup
#define MEM_BEF_STRDUP   mem_strdup
#define MEM_BEC_STRDUP   mem_strdup

#define MEM_PH_REALLOC   mem_realloc
#define MEM_PARC_REALLOC mem_realloc
#define MEM_PARF_REALLOC mem_realloc
#define MEM_PERM_REALLOC mem_realloc
#define MEM_BEF_REALLOC  mem_realloc
#define MEM_BEC_REALLOC  mem_realloc

#define MEM_PH_FREEFP    mem_freefp
#define MEM_PARC_FREEFP  mem_freefp
#define MEM_PARF_FREEFP  mem_freefp
#define MEM_BEF_FREEFP   mem_freefp
#define MEM_BEC_FREEFP   mem_freefp


// If we can use 386 instruction set (possible in 16 bit code)
#define I386 (config.target_cpu >= TARGET_80386)

// If we are generating 32 bit code
#if MARS
#define I16     0               // no 16 bit code for D
#define I32     (NPTRSIZE == 4)
#define I64     (NPTRSIZE == 8) // 1 if generating 64 bit code
#else
#define I16     (NPTRSIZE == 2)
#define I32     (NPTRSIZE == 4)
#define I64     (NPTRSIZE == 8) // 1 if generating 64 bit code
#endif

/**********************************
 * Limits & machine dependent stuff.
 */

/* Define stuff that's different between VAX and IBMPC.
 * HOSTBYTESWAPPED      TRUE if on the host machine the bytes are
 *                      swapped (TRUE for 6809, 68000, FALSE for 8088
 *                      and VAX).
 */


#define EXIT_BREAK      255     // aborted compile with ^C

/* Take advantage of machines that can store a word, lsb first  */
#if _M_I86              // if Intel processor
#define TOWORD(ptr,val) (*(unsigned short *)(ptr) = (unsigned short)(val))
#define TOLONG(ptr,val) (*(unsigned *)(ptr) = (unsigned)(val))
#else
#define TOWORD(ptr,val) (((ptr)[0] = (unsigned char)(val)),\
                         ((ptr)[1] = (unsigned char)((val) >> 8)))
#define TOLONG(ptr,val) (((ptr)[0] = (unsigned char)(val)),\
                         ((ptr)[1] = (unsigned char)((val) >> 8)),\
                         ((ptr)[2] = (unsigned char)((val) >> 16)),\
                         ((ptr)[3] = (unsigned char)((val) >> 24)))
#endif

#define TOOFFSET(a,b)   (I32 ? TOLONG(a,b) : TOWORD(a,b))

/***************************
 * Target machine data types as they appear on the host.
 */

typedef signed char     targ_char;
typedef unsigned char   targ_uchar;
typedef signed char     targ_schar;
typedef short           targ_short;
typedef unsigned short  targ_ushort;
typedef int             targ_long;
typedef unsigned        targ_ulong;
typedef long long       targ_llong;
typedef unsigned long long      targ_ullong;
typedef float           targ_float;
typedef double          targ_double;
typedef longdouble      targ_ldouble;

// Extract most significant register from constant
#define MSREG(p)        ((REGSIZE == 2) ? (p) >> 16 : ((sizeof(targ_llong) == 8) ? (p) >> 32 : 0))

typedef int             targ_int;
typedef unsigned        targ_uns;

/* Sizes of base data types in bytes */

#define CHARSIZE        1
#define SHORTSIZE       2
#define WCHARSIZE       2       // 2 for WIN32, 4 for linux/OSX/FreeBSD/OpenBSD/Solaris
#define LONGSIZE        4
#define LLONGSIZE       8
#define CENTSIZE        16
#define FLOATSIZE       4
#define DOUBLESIZE      8
#if TARGET_OSX
#define LNGDBLSIZE      16      // 80 bit reals
#elif TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
#define LNGDBLSIZE      12      // 80 bit reals
#else
#define LNGDBLSIZE      10      // 80 bit reals
#endif
#define TMAXSIZE        LNGDBLSIZE      // largest size a constant can be

#if 0
#define NDPSAVESIZE     DOUBLESIZE
#else
#define NDPSAVESIZE     LNGDBLSIZE
#endif

#define intsize         tysize[TYint]
#define REGSIZE         tysize[TYnptr]
#define NPTRSIZE        tysize[TYnptr]
#define FPTRSIZE        tysize[TYfptr]
#define REGMASK         0xFFFF

// targ_llong is also used to store host pointers, so it should have at least their size
#if TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS || TARGET_OSX || MARS
typedef targ_llong      targ_ptrdiff_t; /* ptrdiff_t for target machine  */
typedef targ_ullong     targ_size_t;    /* size_t for the target machine */
#else
typedef targ_int        targ_ptrdiff_t; /* ptrdiff_t for target machine  */
typedef targ_uns        targ_size_t;    /* size_t for the target machine */
#endif

/* Enable/disable various features
   (Some features may no longer work the old way when compiled out,
    I don't test the old ways once the new way is set.)
 */
#define THUNKS          1       /* use thunks for virtual functions     */
#define SEPNEWDEL       1       // new/delete are not called within the ctor/dtor,
                                // they are separate
#define VBTABLES        1       // use Microsoft object model
#define UNICODE         1       // support Unicode (wchar_t is unsigned short)
#define DLCMSGS         0       // if 1, have all messages in a file
#define NEWMANGLE       TARGET_WINDOS   // use MS name mangling scheme
#define NEWTEMPMANGLE   (!(config.flags4 & CFG4oldtmangle))     // do new template mangling
#define USEDLLSHELL     _WINDLL
#define FARCLASSES      1       // support near/far classes
#define MFUNC           (I32) //0 && config.exe == EX_NT)       // member functions are TYmfunc
#define CV3             0       // 1 means support CV3 debug format

/* Object module format
 */
#ifndef OMFOBJ
#define OMFOBJ          TARGET_WINDOS
#endif
#ifndef ELFOBJ
#define ELFOBJ          (TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS)
#endif
#ifndef MACHOBJ
#define MACHOBJ         TARGET_OSX
#endif

#define SYMDEB_CODEVIEW TARGET_WINDOS
#define SYMDEB_DWARF    (TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS || TARGET_OSX)

#define TOOLKIT_H

/* Masks so we can easily check size */
#define CHARMASK        (0xFFL)
#define SHORTMASK       (0xFFFFL)
#define INTMASK         SHORTMASK
#define LONGMASK        0xFFFFFFFF

/* Common constants often checked for */
#define LLONGMASK       0xFFFFFFFFFFFFFFFFLL
#define ZEROLL          0LL
#define MINLL           0x8000000000000000LL
#define MAXLL           0x7FFFFFFFFFFFFFFFLL

#define Smodel 0        /* 64k code, 64k data, or flat model           */

#ifndef MEMMODELS
#define LARGEDATA       (config.memmodel & 6)
#define LARGECODE       (config.memmodel & 5)

#define Mmodel 1        /* large code, 64k data         */
#define Cmodel 2        /* 64k code, large data         */
#define Lmodel 3        /* large code, large data       */
#define Vmodel 4        /* large code, large data, vcm  */
#define MEMMODELS 5     /* number of memory models      */
#endif

/* Segments     */
#define CODE    1       /* code segment                 */
#define DATA    2       /* initialized data             */
#define CDATA   3       /* constant data                */
#define UDATA   4       /* uninitialized data           */
#define CDATAREL 5      /* constant data with relocs    */
#define UNKNOWN -1      /* unknown segment              */
#define DGROUPIDX 1     /* group index of DGROUP        */

#define KEEPBITFIELDS 0 /* 0 means code generator cannot handle bit fields, */
                        /* so replace them with shifts and masks        */

#define REGMAX  29      // registers are numbered 0..10

typedef unsigned        tym_t;          // data type big enough for type masks
typedef int             SYMIDX;         // symbol table index

#if 0
#if defined(__DMC__) && __DMC__ < 0x81e
typedef int bool;
#endif
#define bool int
#endif

#define _chkstack()     (void)0

/* For 32 bit compilations, we don't need far keyword   */
#if 1
#define far
#define _far
#define __far
#define __cs
#endif

#if _WINDLL
#define COPYRIGHT "Copyright © 2001 Digital Mars"
#else
#ifdef DEBUG
#define COPYRIGHT "Copyright (C) Digital Mars 2000-2013.  All Rights Reserved.\n\
Written by Walter Bright\n\
*****BETA TEST VERSION*****"
#else
#if __linux__
#define COPYRIGHT "Copyright (C) Digital Mars 2000-2013.  All Rights Reserved.\n\
Written by Walter Bright, Linux version by Pat Nelson"
#else
#define COPYRIGHT "Copyright (C) Digital Mars 2000-2013.  All Rights Reserved.\n\
Written by Walter Bright"
#endif
#endif
#endif

/**********************************
 * Configuration
 */

/* Linkage type         */
typedef enum LINKAGE
{
    LINK_C,                     /* C style                              */
    LINK_CPP,                   /* C++ style                            */
    LINK_PASCAL,                /* Pascal style                         */
    LINK_FORTRAN,
    LINK_SYSCALL,
    LINK_STDCALL,
    LINK_D,                     // D code
    LINK_MAXDIM                 /* array dimension                      */
} linkage_t;


// This part of the configuration is saved in the precompiled header for use
// in comparing to make sure it hasn't changed.

struct Config
{
    char language;              // 'C' = C, 'D' = C++
//#define CPP (config.language == 'D')
    char version[8];            // = VERSION
    char exetype[3];            // distinguish exe types so PH
                                // files are distinct (= SUFFIX)

    char target_cpu;            // instruction selection
    char target_scheduler;      // instruction scheduling (normally same as selection)
#define TARGET_8086             0
#define TARGET_80286            2
#define TARGET_80386            3
#define TARGET_80486            4
#define TARGET_Pentium          5
#define TARGET_PentiumMMX       6
#define TARGET_PentiumPro       7
#define TARGET_PentiumII        8
#define TARGET_AMD64            9       (32 or 64 bit mode)

    short versionint;           // intermediate file version (= VERSIONINT)
    int defstructalign;         // struct alignment specified by command line
    short hxversion;            // HX version number
    char fulltypes;
#define CVNONE  0               // No symbolic info
#define CVOLD   1               // Codeview 1 symbolic info
#define CV4     2               // Codeview 4 symbolic info
#define CVSYM   3               // Symantec format
#define CVTDB   4               // Symantec format written to file
#define CVDWARF_C 5             // Dwarf in C format
#define CVDWARF_D 6             // Dwarf in D format
#define CVSTABS 7               // Elf Stabs in C format
#define CV8     8               // Codeview 8 symbolic info

    unsigned wflags;            // flags for Windows code generation
#       define WFwindows 1      // generating code for Windows app or DLL
#       define WFdll     2      // generating code for Windows DLL
#       define WFincbp   4      // mark far stack frame with inc BP / dec BP
#       define WFloadds  8      // assume __loadds for all functions
#       define WFexpdef  0x10   // generate export definition records for
                                // exported functions
#       define WFss      0x20   // load DS from SS
#       define WFreduced 0x40   // skip DS load for non-exported functions
#       define WFdgroup  0x80   // load DS from DGROUP
#       define WFexport  0x100  // assume __export for all far functions
#       define WFds      0x200  // load DS from DS
#       define WFmacros  0x400  // define predefined windows macros
#       define WFssneds  0x800  // SS != DS
#       define WFthunk   0x1000 // use fixups instead of direct ref to CS
#       define WFsaveds  0x2000 // use push/pop DS for far functions
#       define WFdsnedgroup 0x4000      // DS != DGROUP
#       define WFexe     0x8000 // generating code for Windows EXE

    bool fpxmmregs;             // use XMM registers for floating point
    char inline8087;            /* 0:   emulator
                                   1:   IEEE 754 inline 8087 code
                                   2:   fast inline 8087 code
                                 */
    short memmodel;             // 0:S,X,N,F, 1:M, 2:C, 3:L, 4:V
    unsigned objfmt;            // target object format
#define OBJ_OMF         1
#define OBJ_MSCOFF      2
#define OBJ_ELF         4
#define OBJ_MACH        8
    unsigned exe;               // target operating system
#define EX_DOSX         1       // DOSX 386 program
#define EX_ZPM          2       // ZPM 286 program
#define EX_RATIONAL     4       // RATIONAL 286 program
#define EX_PHARLAP      8       // PHARLAP 386 program
#define EX_COM          0x10    // MSDOS .COM program
//#define EX_WIN16      0x20    // Windows 3.x 16 bit program
#define EX_OS2          0x40    // OS/2 2.0 32 bit program
#define EX_OS1          0x80    // OS/2 1.x 16 bit program
#define EX_NT           0x100   // NT
#define EX_MZ           0x200   // MSDOS real mode program
#define EX_XENIX        0x400
#define EX_SCOUNIX      0x800
#define EX_UNIXSVR4     0x1000
#define EX_LINUX        0x2000
#define EX_WIN64        0x4000  // AMD64 and Windows (64 bit mode)
#define EX_LINUX64      0x8000  // AMD64 and Linux (64 bit mode)
#define EX_OSX          0x10000
#define EX_OSX64        0x20000
#define EX_FREEBSD      0x40000
#define EX_FREEBSD64    0x80000
#define EX_SOLARIS      0x100000
#define EX_SOLARIS64    0x200000
#define EX_OPENBSD      0x400000
#define EX_OPENBSD64    0x800000

#define EX_flat         (EX_OS2 | EX_NT | EX_LINUX | EX_WIN64 | EX_LINUX64 | \
                         EX_OSX | EX_OSX64 | EX_FREEBSD | EX_FREEBSD64 | \
                         EX_OPENBSD | EX_OPENBSD64 | \
                         EX_SOLARIS | EX_SOLARIS64)
#define EX_dos          (EX_DOSX | EX_ZPM | EX_RATIONAL | EX_PHARLAP | \
                         EX_COM | EX_MZ /*| EX_WIN16*/)

/* CFGX: flags ignored in precompiled headers
 * CFGY: flags copied from precompiled headers into current config
 */
    unsigned flags;
#define CFGuchar        1       // chars are unsigned
#define CFGsegs         2       // new code seg for each far func
#define CFGtrace        4       // output trace functions
#define CFGglobal       8       // make all static functions global
#define CFGstack        0x20    // add stack overflow checking
#define CFGalwaysframe  0x40    // always generate stack frame
#define CFGnoebp        0x80    // do not use EBP as general purpose register
#define CFGromable      0x100   // put switch tables in code segment
#define CFGeasyomf      0x200   // generate Pharlap Easy-OMF format
#define CFGfarvtbls     0x800   // store vtables in far segments
#define CFGnoinlines    0x1000  // do not inline functions
#define CFGnowarning    0x8000  // disable warnings
#define CFGX    (CFGnowarning)
    unsigned flags2;
#define CFG2comdat      1       // use initialized common blocks
#define CFG2nodeflib    2       // no default library imbedded in OBJ file
#define CFG2browse      4       // generate browse records
#define CFG2dyntyping   8       // generate dynamic typing information
#define CFG2fulltypes   0x10    // don't optimize CV4 class info
#define CFG2warniserr   0x20    // treat warnings as errors
#define CFG2phauto      0x40    // automatic precompiled headers
#define CFG2phuse       0x80    // use precompiled headers
#define CFG2phgen       0x100   // generate precompiled header
#define CFG2once        0x200   // only include header files once
#define CFG2hdrdebug    0x400   // generate debug info for header
#define CFG2phautoy     0x800   // fast build precompiled headers
#define CFG2noobj       0x1000  // we are not generating a .OBJ file
#define CFG2noerrmax    0x4000  // no error count maximum
#define CFG2expand      0x8000  // expanded output to list file
#define CFG2seh         0x10000 // use Win32 SEH to support any exception handling
#define CFG2stomp       0x20000 // enable stack stomping code
#define CFG2gms         0x40000 // optimize debug symbols for microsoft debuggers
#define CFGX2   (CFG2warniserr | CFG2phuse | CFG2phgen | CFG2phauto | \
                 CFG2once | CFG2hdrdebug | CFG2noobj | CFG2noerrmax | \
                 CFG2expand | CFG2nodeflib | CFG2stomp | CFG2gms)
    unsigned flags3;
#define CFG3ju          1       // char == unsigned char
#define CFG3eh          4       // generate exception handling stuff
#define CFG3strcod      8       // strings are placed in code segment
#define CFG3eseqds      0x10    // ES == DS at all times
#define CFG3ptrchk      0x20    // generate pointer validation code
#define CFG3strictproto 0x40    // strict prototyping
#define CFG3autoproto   0x80    // auto prototyping
#define CFG3rtti        0x100   // add RTTI support
#define CFG3relax       0x200   // relaxed type checking (C only)
#define CFG3cpp         0x400   // C++ compile
#define CFG3igninc      0x800   // ignore standard include directory
#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
#define CFG3mars        0x1000  // use mars libs and headers
#define NO_FAR          (TRUE)  // always ignore __far and __huge keywords
#else
#define CFG3nofar       0x1000  // ignore __far and __huge keywords
#define NO_FAR          (config.flags3 & CFG3nofar)
#endif
#define CFG3noline      0x2000  // do not output #line directives
#define CFG3comment     0x4000  // leave comments in preprocessed output
#define CFG3cppcomment  0x8000  // allow C++ style comments
#define CFG3wkfloat     0x10000 // make floating point references weak externs
#define CFG3digraphs    0x20000 // support ANSI C++ digraphs
#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
#define CFG3semirelax   0x40000 // moderate relaxed type checking
#endif
#define CFG3pic         0x80000 // position independent code
#define CFGX3   (CFG3strcod | CFG3ptrchk)

    unsigned flags4;
#define CFG4speed       1       // optimized for speed
#define CFG4space       2       // optimized for space
#define CFG4optimized   (CFG4speed | CFG4space)
#define CFG4allcomdat   4       // place all functions in COMDATs
#define CFG4fastfloat   8       // fast floating point (-ff)
#define CFG4fdivcall    0x10    // make function call for FDIV opcodes
#define CFG4tempinst    0x20    // instantiate templates for undefined functions
#define CFG4oldstdmangle 0x40   // do stdcall mangling without @
#define CFG4pascal      0x80    // default to pascal linkage
#define CFG4stdcall     0x100   // default to std calling convention
#define CFG4cacheph     0x200   // cache precompiled headers in memory
#define CFG4alternate   0x400   // if alternate digraph tokens
#define CFG4bool        0x800   // support 'bool' as basic type
#define CFG4wchar_t     0x1000  // support 'wchar_t' as basic type
#define CFG4notempexp   0x2000  // no instantiation of template functions
#define CFG4anew        0x4000  // allow operator new[] and delete[] overloading
#define CFG4oldtmangle  0x8000  // use old template name mangling
#define CFG4dllrtl      0x10000 // link with DLL RTL
#define CFG4noemptybaseopt 0x40000      // turn off empty base class optimization
#define CFG4stackalign  CFG4speed       // align stack to 8 bytes
#define CFG4nowchar_t   0x80000 // use unsigned short name mangling for wchar_t
#define CFG4forscope    0x100000 // new C++ for scoping rules
#define CFG4warnccast   0x200000 // warn about C style casts
#define CFG4adl         0x400000 // argument dependent lookup
#define CFG4enumoverload 0x800000 // enum overloading
#define CFG4implicitfromvoid 0x1000000  // allow implicit cast from void* to T*
#define CFG4dependent        0x2000000  // dependent / non-dependent lookup
#define CFG4wchar_is_long    0x4000000  // wchar_t is 4 bytes
#define CFG4underscore       0x8000000  // prepend _ for C mangling
#define CFGX4           (CFG4optimized | CFG4fastfloat | CFG4fdivcall | \
                         CFG4tempinst | CFG4cacheph | CFG4notempexp | \
                         CFG4stackalign | CFG4dependent)
#define CFGY4           (CFG4nowchar_t | CFG4noemptybaseopt | CFG4adl | \
                         CFG4enumoverload | CFG4implicitfromvoid | \
                         CFG4wchar_is_long | CFG4underscore)

    unsigned flags5;
#define CFG5debug       1       // compile in __debug code
#define CFG5in          2       // compile in __in code
#define CFG5out         4       // compile in __out code
#define CFG5invariant   8       // compile in __invariant code

#if HTOD
    unsigned htodFlags;         // configuration for htod
#define HTODFinclude    1       // -hi drill down into #include files
#define HTODFsysinclude 2       // -hs drill down into system #include files
#define HTODFtypedef    4       // -ht drill down into typedefs
#define HTODFcdecl      8       // -hc skip C declarations as comments
#endif
    char ansi_c;                // strict ANSI C
                                // 89 for ANSI C89, 99 for ANSI C99
    char asian_char;            /* 0: normal, 1: Japanese, 2: Chinese   */
                                /* and Taiwanese, 3: Korean             */
    unsigned threshold;         // data larger than threshold is assumed to
                                // be far (16 bit models only)
#define THRESHMAX 0xFFFF        // if threshold == THRESHMAX, all data defaults
                                // to near
    enum LINKAGE linkage;       // default function call linkage
};

// Configuration that is not saved in precompiled header

typedef struct Configv
{
    char addlinenumbers;        // put line number info in .OBJ file
    char verbose;               // 0: compile quietly (no messages)
                                // 1: show progress to DLL (default)
                                // 2: full verbosity
    char *csegname;             // code segment name
    char *deflibname;           // default library name
    enum LANG language;         // message language
    int errmax;                 // max error count
} Configv;

struct Classsym;
struct Symbol;
struct LIST;
struct elem;

typedef unsigned char reg_t;    // register number
typedef unsigned regm_t;        // Register mask type
struct immed_t
{   targ_size_t value[REGMAX];  // immediate values in registers
    regm_t mval;                // Mask of which values in regimmed.value[] are valid
};


struct cse_t
{   elem *value[REGMAX];        // expression values in registers
    regm_t mval;                // mask of which values in value[] are valid
    regm_t mops;                // subset of mval that contain common subs that need
                                // to be stored in csextab[] if they are destroyed
};

struct con_t
{   cse_t cse;                  // CSEs in registers
    immed_t immed;              // immediate values in registers
    regm_t mvar;                // mask of register variables
    regm_t mpvar;               // mask of SCfastpar, SCshadowreg register variables
    regm_t indexregs;           // !=0 if more than 1 uncommitted index register
    regm_t used;                // mask of registers used
    regm_t params;              // mask of registers which still contain register
                                // function parameters
};

/*********************************
 * Bootstrap complex types.
 */

#include "bcomplex.h"

/*********************************
 * Union of all data types. Storage allocated must be the right
 * size of the data on the TARGET, not the host.
 */

struct Cent
{
    targ_ullong lsw;
    targ_ullong msw;
};

union eve
{
        targ_char       Vchar;
        targ_schar      Vschar;
        targ_uchar      Vuchar;
        targ_short      Vshort;
        targ_ushort     Vushort;
        targ_int        Vint;
        targ_uns        Vuns;
        targ_long       Vlong;
        targ_ulong      Vulong;
        targ_llong      Vllong;
        targ_ullong     Vullong;
        Cent            Vcent;
        targ_float      Vfloat4[4];
        targ_double     Vdouble2[2];
        targ_float      Vfloat;
        targ_double     Vdouble;
        targ_ldouble    Vldouble;
        Complex_f       Vcfloat;   // 2x float
        Complex_d       Vcdouble;  // 2x double
        Complex_ld      Vcldouble; // 2x long double
        targ_size_t     Vpointer;
        targ_ptrdiff_t  Vptrdiff;
        targ_uchar      Vreg;   // register number for OPreg elems
        struct                  // 48 bit 386 far pointer
        {   targ_long   Voff;
            targ_ushort Vseg;
        } Vfp;
        struct
        {
            targ_size_t Voffset;// offset from symbol
            Symbol *Vsym;       // pointer to symbol table
            union
            {   struct PARAM *Vtal;     // template-argument-list for SCfunctempl,
                                // used only to transmit it to cpp_overload()
                LIST *Erd;      // OPvar: reaching definitions
            } spu;
        } sp;
        struct
        {
            targ_size_t Voffset;// member pointer offset
            Classsym *Vsym;     // struct tag
            elem *ethis;        // OPrelconst: 'this' for member pointer
        } sm;
        struct
        {
            targ_size_t Voffset;// offset from string
            char *Vstring;      // pointer to string (OPstring or OPasm)
            targ_size_t Vstrlen;// length of string
        } ss;
        struct
        {
            elem *Eleft;        // left child for unary & binary nodes
            elem *Eright;       // right child for binary nodes
            Symbol *Edtor;      // OPctor: destructor
        } eop;
#if MARS
        struct
        {
            elem *Eleft;        // left child for OPddtor
            void *Edecl;        // VarDeclaration being constructed
        } ed;                   // OPdctor,OPddtor
#endif
};                              // variants for each type of elem

// Symbols

#ifdef DEBUG
#define IDSYMBOL        IDsymbol,
#else
#define IDSYMBOL
#endif

#if SCPP
#define SYMBOLZERO      0,0,0,
#elif MARS
#define SYMBOLZERO      0,0,
#else
#define SYMBOLZERO
#endif

#if TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
#define UNIXFIELDS      (unsigned)-1,(unsigned)-1,0,0,
#elif TARGET_OSX
#define UNIXFIELDS      (unsigned)-1,(unsigned)-1,0,0,0,
#else
#define UNIXFIELDS
#endif

typedef unsigned SYMFLGS;
#if MARS
#define SYM_PREDEF_SZ 40
#else
#define SYM_PREDEF_SZ 22
#endif

#define SYMBOLY(fl,regsaved,name,flags) \
        {IDSYMBOL \
         (symbol *)0,(symbol *)0,(symbol *)0,(dt_t *)0,0,(type *)0,{0},\
         SYMBOLZERO\
         UNIXFIELDS\
         SCextern,(fl),(flags),0,0,0,0,0,0,0,{0},(regsaved),{name}}

/**********************************
 * Storage classes
 * This macro is used to generate parallel tables and the enum values.
 */

#define ENUMSCMAC       \
    X(unde,     SCEXP|SCKEP|SCSCT)      /* undefined                            */ \
    X(auto,     SCEXP|SCSS|SCRD  )      /* automatic (stack)                    */ \
    X(static,   SCEXP|SCKEP|SCSCT)      /* statically allocated                 */ \
    X(thread,   SCEXP|SCKEP      )      /* thread local                         */ \
    X(extern,   SCEXP|SCKEP|SCSCT)      /* external                             */ \
    X(register, SCEXP|SCSS|SCRD  )      /* registered variable                  */ \
    X(pseudo,   SCEXP            )      /* pseudo register variable             */ \
    X(global,   SCEXP|SCKEP|SCSCT)      /* top level global definition          */ \
    X(comdat,   SCEXP|SCKEP|SCSCT)      /* initialized common block             */ \
    X(parameter,SCEXP|SCSS       )      /* function parameter                   */ \
    X(regpar,   SCEXP|SCSS       )      /* function register parameter          */ \
    X(fastpar,  SCEXP|SCSS       )      /* function parameter passed in register */ \
    X(shadowreg,SCEXP|SCSS       )      /* function parameter passed in register, shadowed on stack */ \
    X(typedef,  0                )      /* type definition                      */ \
    X(explicit, 0                )      /* explicit                             */ \
    X(mutable,  0                )      /* mutable                              */ \
    X(label,    0                )      /* goto label                           */ \
    X(struct,   SCKEP            )      /* struct/class/union tag name          */ \
    X(enum,     0                )      /* enum tag name                        */ \
    X(field,    SCEXP|SCKEP      )      /* bit field of struct or union         */ \
    X(const,    SCEXP|SCSCT      )      /* constant integer                     */ \
    X(member,   SCEXP|SCKEP|SCSCT)      /* member of struct or union            */ \
    X(anon,     0                )      /* member of anonymous union            */ \
    X(inline,   SCEXP|SCKEP      )      /* for inline functions                 */ \
    X(sinline,  SCEXP|SCKEP      )      /* for static inline functions          */ \
    X(einline,  SCEXP|SCKEP      )      /* for extern inline functions          */ \
    X(overload, SCEXP            )      /* for overloaded function names        */ \
    X(friend,   0                )      /* friend of a class                    */ \
    X(virtual,  0                )      /* virtual function                     */ \
    X(locstat,  SCEXP|SCSCT      )      /* static, but local to a function      */ \
    X(template, 0                )      /* class template                       */ \
    X(functempl,0                )      /* function template                    */ \
    X(ftexpspec,0                )      /* function template explicit specialization */ \
    X(linkage,  0                )      /* function linkage symbol              */ \
    X(public,   SCEXP|SCKEP|SCSCT)      /* generate a pubdef for this           */ \
    X(comdef,   SCEXP|SCKEP|SCSCT)      /* uninitialized common block           */ \
    X(bprel,    SCEXP|SCSS       )      /* variable at fixed offset from frame pointer */ \
    X(namespace,0                )      /* namespace                            */ \
    X(alias,    0                )      /* alias to another symbol              */ \
    X(funcalias,0                )      /* alias to another function symbol     */ \
    X(memalias,0                 )      /* alias to base class member           */ \
    X(stack,    SCEXP|SCSS       )      /* offset from stack pointer (not frame pointer) */ \
    X(adl,      0                )      /* list of ADL symbols for overloading  */ \

    //X(union,SCKEP)    /* union tag name                       */
    //X(class,SCKEP)    /* class tag name                       */

#define ClassInline(c) ((c) == SCinline || (c) == SCsinline || (c) == SCeinline)
#define SymInline(s)   ClassInline((s)->Sclass)

enum SC {
    #define X(a,b)      SC##a,
        ENUMSCMAC       // generate the enum values
        SCMAX           // array dimension
    #undef X
};

#define TAG_ARGUMENTS

/*******************************
 * Swap two integers.
 */

inline void swap(int *a,int *b)
{ int tmp;

  tmp = *a;
  *a = *b;
  *b = tmp;
}


#endif /* CDEF_H */
