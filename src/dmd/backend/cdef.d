/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/cdef.d, backend/_cdef.d)
 */

module dmd.backend.cdef;

// Online documentation: https://dlang.org/phobos/dmd_backend_cdef.html

import dmd.backend.cc: Classsym, Symbol, param_t, config;
import dmd.backend.el;
import dmd.backend.ty : I32;

import dmd.backend.dlist;

extern (C++):
@nogc:
nothrow:
@safe:

enum VERSION = "9.00.0";        // for banner and imbedding in .OBJ file
enum VERSIONHEX = "0x900";      // for __DMC__ macro
enum VERSIONINT = 0x900;        // for precompiled headers and DLL version

version (SCPP)
    version = XVERSION;
version (SPP)
    version = XVERSION;
version (HTOD)
    version = XVERSION;
version (MARS)
    version = XVERSION;

version (XVERSION)
{
    extern (D) template xversion(string s)
    {
        enum xversion = mixin(`{ version (` ~ s ~ `) return true; else return false; }`)();
    }

    enum TARGET_LINUX   = xversion!`linux`;
    enum TARGET_OSX     = xversion!`OSX`;
    enum TARGET_FREEBSD = xversion!`FreeBSD`;
    enum TARGET_OPENBSD = xversion!`OpenBSD`;
    enum TARGET_SOLARIS = xversion!`Solaris`;
    enum TARGET_WINDOS  = xversion!`Windows`;
    enum TARGET_DRAGONFLYBSD  = xversion!`DragonFlyBSD`;
}


//
//      Attributes
//

//      Types of attributes
enum
{
    ATTR_LINKMOD    = 1,     // link modifier
    ATTR_TYPEMOD    = 2,     // basic type modifier
    ATTR_FUNCINFO   = 4,     // function information
    ATTR_DATAINFO   = 8,     // data information
    ATTR_TRANSU     = 0x10,  // transparent union
    ATTR_IGNORED    = 0x20,  // attribute can be ignored
    ATTR_WARNING    = 0x40,  // attribute was ignored
    ATTR_SEGMENT    = 0x80,  // segment secified
}

//      attribute location in code
enum
{
    ALOC_DECSTART   = 1,   // start of declaration
    ALOC_SYMDEF     = 2,   // symbol defined
    ALOC_PARAM      = 4,   // follows function parameter
    ALOC_FUNC       = 8,   // follows function declaration
}

//#define ATTR_LINK_MODIFIERS (mTYconst|mTYvolatile|mTYcdecl|mTYstdcall)
//#define ATTR_CAN_IGNORE(a) (((a) & (ATTR_LINKMOD|ATTR_TYPEMOD|ATTR_FUNCINFO|ATTR_DATAINFO|ATTR_TRANSU)) == 0)
//#define LNX_CHECK_ATTRIBUTES(a,x) assert(((a) & ~(x|ATTR_IGNORED|ATTR_WARNING)) == 0)

version (_WINDLL)
    enum SUFFIX = "nd";
else version (_WIN64)
    enum SUFFIX = "a";
else version (Win32)
    enum SUFFIX = "n";
else
    enum SUFFIX = "";

// Generate cleanup code
enum TERMCODE = 0;

// C++ Language Features
enum ANGLE_BRACKET_HACK = 0;       // >> means two template arglist closes

// C/C++ Language Features
enum IMPLIED_PRAGMA_ONCE = 1;       // include guards count as #pragma once
enum bool HEADER_LIST = true;

// Support generating code for 16 bit memory models
version (SCPP)
    enum SIXTEENBIT = TARGET_WINDOS != 0;
else
    enum SIXTEENBIT = false;

/* Set for supporting the FLAT memory model.
 * This is not quite the same as !SIXTEENBIT, as one could
 * have near/far with 32 bit code.
 */
version (MARS)
    enum TARGET_SEGMENTED = false;
else
    enum TARGET_SEGMENTED = TARGET_WINDOS;


@trusted
bool LDOUBLE() { return config.exe == EX_WIN32; }   // support true long doubles


// NT structured exception handling
//      0: no support
//      1: old style
//      2: new style
enum NTEXCEPTIONS = 2;

// For Shared Code Base
//#if _WINDLL
//#define dbg_printf dll_printf
//#else
//#define dbg_printf printf
//#endif

//#ifndef ERRSTREAM
//#define ERRSTREAM stdout
//#endif
//#define err_printf printf
//#define err_vprintf vfprintf
//#define err_fputc fputc
//#define dbg_fputc fputc
//#define LF '\n'
//#define LF_STR "\n"
//#define CR '\r'
//#define ANSI        config.ansi_c
//#define ANSI_STRICT config.ansi_c
//#define ANSI_RELAX  config.ansi_c
//#define TRIGRAPHS   ANSI
//#define T80x86(x)       x

// For Share MEM_ macros - default to mem_xxx package
// PH           precompiled header
// PARF         parser, life of function
// PARC         parser, life of compilation
// BEF          back end, function
// BEC          back end, compilation

//#define MEM_PH_FREE      mem_free
//#define MEM_PARF_FREE    mem_free
//#define MEM_PARC_FREE    mem_free
//#define MEM_BEF_FREE     mem_free
//#define MEM_BEC_FREE     mem_free

//#define MEM_PH_CALLOC    mem_calloc
//#define MEM_PARC_CALLOC  mem_calloc
//#define MEM_PARF_CALLOC  mem_calloc
//#define MEM_BEF_CALLOC   mem_calloc
//#define MEM_BEC_CALLOC   mem_calloc

//#define MEM_PH_MALLOC    mem_malloc
//#define MEM_PARC_MALLOC  mem_malloc
//#define MEM_PARF_MALLOC  mem_malloc
//#define MEM_BEF_MALLOC   mem_malloc
//#define MEM_BEC_MALLOC   mem_malloc

//#define MEM_PH_STRDUP    mem_strdup
//#define MEM_PARC_STRDUP  mem_strdup
//#define MEM_PARF_STRDUP  mem_strdup
//#define MEM_BEF_STRDUP   mem_strdup
//#define MEM_BEC_STRDUP   mem_strdup

//#define MEM_PH_REALLOC   mem_realloc
//#define MEM_PARC_REALLOC mem_realloc
//#define MEM_PARF_REALLOC mem_realloc
//#define MEM_PERM_REALLOC mem_realloc
//#define MEM_BEF_REALLOC  mem_realloc
//#define MEM_BEC_REALLOC  mem_realloc

//#define MEM_PH_FREEFP    mem_freefp
//#define MEM_PARC_FREEFP  mem_freefp
//#define MEM_PARF_FREEFP  mem_freefp
//#define MEM_BEF_FREEFP   mem_freefp
//#define MEM_BEC_FREEFP   mem_freefp


// If we can use 386 instruction set (possible in 16 bit code)
//#define I386 (config.target_cpu >= TARGET_80386)

// If we are generating 32 bit code
//#if MARS
//#define I16     0               // no 16 bit code for D
//#define I32     (NPTRSIZE == 4)
//#define I64     (NPTRSIZE == 8) // 1 if generating 64 bit code
//#else
//#define I16     (NPTRSIZE == 2)
//#define I32     (NPTRSIZE == 4)
//#define I64     (NPTRSIZE == 8) // 1 if generating 64 bit code
//#endif

/**********************************
 * Limits & machine dependent stuff.
 */

/* Define stuff that's different between VAX and IBMPC.
 * HOSTBYTESWAPPED      TRUE if on the host machine the bytes are
 *                      swapped (TRUE for 6809, 68000, FALSE for 8088
 *                      and VAX).
 */


enum EXIT_BREAK = 255;     // aborted compile with ^C

/* Take advantage of machines that can store a word, lsb first  */
//#if _M_I86              // if Intel processor
//#define TOWORD(ptr,val) (*(unsigned short *)(ptr) = (unsigned short)(val))
//#define TOLONG(ptr,val) (*(unsigned *)(ptr) = (unsigned)(val))
//#else
//#define TOWORD(ptr,val) (((ptr)[0] = (unsigned char)(val)),\
//                         ((ptr)[1] = (unsigned char)((val) >> 8)))
//#define TOLONG(ptr,val) (((ptr)[0] = (unsigned char)(val)),\
//                         ((ptr)[1] = (unsigned char)((val) >> 8)),\
//                         ((ptr)[2] = (unsigned char)((val) >> 16)),\
//                         ((ptr)[3] = (unsigned char)((val) >> 24)))
//#endif
//
//#define TOOFFSET(a,b)   (I32 ? TOLONG(a,b) : TOWORD(a,b))

/***************************
 * Target machine data types as they appear on the host.
 */

import core.stdc.stdint : int64_t, uint64_t;

alias targ_char = byte;
alias targ_uchar = ubyte;
alias targ_schar = byte;
alias targ_short = short;
alias targ_ushort= ushort;
alias targ_long = int;
alias targ_ulong = uint;
alias targ_llong = int64_t;
alias targ_ullong = uint64_t;
alias targ_float = float;
alias targ_double = double;
public import dmd.root.longdouble : targ_ldouble = longdouble;

// Extract most significant register from constant
int REGSIZE();
ulong MSREG(ulong p) { return (REGSIZE == 2) ? p >> 16 : ((targ_llong.sizeof == 8) ? p >> 32 : 0); }

alias targ_int = int;
alias targ_uns = uint;

/* Sizes of base data types in bytes */
enum
{
    CHARSIZE       = 1,
    SHORTSIZE      = 2,
    WCHARSIZE      = 2,       // 2 for WIN32, 4 for linux/OSX/FreeBSD/OpenBSD/DragonFlyBSD/Solaris
    LONGSIZE       = 4,
    LLONGSIZE      = 8,
    CENTSIZE       = 16,
    FLOATSIZE      = 4,
    DOUBLESIZE     = 8,
    TMAXSIZE       = 16,      // largest size a constant can be
}

//#define intsize         _tysize[TYint]
//#define REGSIZE         _tysize[TYnptr]
//@property @nogc nothrow auto NPTRSIZE() { return _tysize[TYnptr]; }
//#define FPTRSIZE        _tysize[TYfptr]
enum REGMASK = 0xFFFF;

// targ_llong is also used to store host pointers, so it should have at least their size

// 64 bit support
alias targ_ptrdiff_t = int64_t;   // ptrdiff_t for target machine
alias targ_size_t = uint64_t;     // size_t for the target machine

/* Enable/disable various features
   (Some features may no longer work the old way when compiled out,
    I don't test the old ways once the new way is set.)
 */
//#define NEWTEMPMANGLE   (!(config.flags4 & CFG4oldtmangle))     // do new template mangling
//#define USEDLLSHELL     _WINDLL
bool MFUNC() { return I32 != 0; } // && config.exe == EX_WIN32)       // member functions are TYmfunc
enum CV3 = 0;          // 1 means support CV3 debug format


//#define TOOLKIT_H

enum
{
    Smodel = 0,        // 64k code, 64k data, or flat model
    Mmodel = 1,        // large code, 64k data
    Cmodel = 2,        // 64k code, large data
    Lmodel = 3,        // large code, large data
    Vmodel = 4,        // large code, large data, vcm
}

version (MARS)
    enum MEMMODELS = 1; // number of memory models
else
    enum MEMMODELS = 5;

/* Segments     */
enum
{
    CODE      = 1,     // code segment
    DATA      = 2,     // initialized data
    CDATA     = 3,     // constant data
    UDATA     = 4,     // uninitialized data
    CDATAREL  = 5,     // constant data with relocs
    UNKNOWN   = -1,    // unknown segment
    DGROUPIDX = 1,     // group index of DGROUP
}

enum REGMAX = 29;      // registers are numbered 0..10

alias tym_t = uint;    // data type big enough for type masks


version (MARS)
{
}
else
{
version (_WINDLL)
{
/* We reference the required Windows-1252 encoding of the copyright symbol
   by escaping its character code (0xA9) rather than directly embedding it in
   the source text. The character code is invalid in UTF-8, which causes some
   of our source-code preprocessing tools (e.g. tolf) to choke.
 */
    enum COPYRIGHT_SYMBOL = "\xA9";
    enum COPYRIGHT = "Copyright " ~ COPYRIGHT_SYMBOL ~ " 2001 Digital Mars";
}
else
{
    debug
    {
        enum COPYRIGHT = "Copyright (C) Digital Mars 2000-2019.  All Rights Reserved.
Written by Walter Bright
*****BETA TEST VERSION*****";
    }
    else
    {
        version (linux)
        {
            enum COPYRIGHT = "Copyright (C) Digital Mars 2000-2019.  All Rights Reserved.
Written by Walter Bright, Linux version by Pat Nelson";
        }
        else
        {
            enum COPYRIGHT = "Copyright (C) Digital Mars 2000-2019.  All Rights Reserved.
Written by Walter Bright";
        }
    }
}
}

/**********************************
 * Configuration
 */

/* Linkage type         */
enum linkage_t
{
    LINK_C,                     /* C style                              */
    LINK_CPP,                   /* C++ style                            */
    LINK_PASCAL,                /* Pascal style                         */
    LINK_FORTRAN,
    LINK_SYSCALL,
    LINK_STDCALL,
    LINK_D,                     // D code
    LINK_MAXDIM                 /* array dimension                      */
}

/**********************************
 * Exception handling method
 */

enum EHmethod
{
    EH_NONE,                    // no exception handling
    EH_SEH,                     // SEH __try, __except, __finally only
    EH_WIN32,                   // Win32 SEH
    EH_WIN64,                   // Win64 SEH (not supported yet)
    EH_DM,                      // Digital Mars method
    EH_DWARF,                   // Dwarf method
}

// CPU target
alias cpu_target_t = byte;
enum
{
    TARGET_8086             = 0,
    TARGET_80286            = 2,
    TARGET_80386            = 3,
    TARGET_80486            = 4,
    TARGET_Pentium          = 5,
    TARGET_PentiumMMX       = 6,
    TARGET_PentiumPro       = 7,
    TARGET_PentiumII        = 8,
}

// Symbolic debug info
alias symbolic_debug_t = byte;
enum
{
    CVNONE    = 0,           // No symbolic info
    CVOLD     = 1,           // Codeview 1 symbolic info
    CV4       = 2,           // Codeview 4 symbolic info
    CVSYM     = 3,           // Symantec format
    CVTDB     = 4,           // Symantec format written to file
    CVDWARF_C = 5,           // Dwarf in C format
    CVDWARF_D = 6,           // Dwarf in D format
    CVSTABS   = 7,           // Elf Stabs in C format
    CV8       = 8,           // Codeview 8 symbolic info
}

// Windows code gen flags
alias windows_flags_t = uint;
enum
{
    WFwindows    = 1,      // generating code for Windows app or DLL
    WFdll        = 2,      // generating code for Windows DLL
    WFincbp      = 4,      // mark far stack frame with inc BP / dec BP
    WFloadds     = 8,      // assume __loadds for all functions
    WFexpdef     = 0x10,   // generate export definition records for
                           // exported functions
    WFss         = 0x20,   // load DS from SS
    WFreduced    = 0x40,   // skip DS load for non-exported functions
    WFdgroup     = 0x80,   // load DS from DGROUP
    WFexport     = 0x100,  // assume __export for all far functions
    WFds         = 0x200,  // load DS from DS
    WFmacros     = 0x400,  // define predefined windows macros
    WFssneds     = 0x800,  // SS != DS
    WFthunk      = 0x1000, // use fixups instead of direct ref to CS
    WFsaveds     = 0x2000, // use push/pop DS for far functions
    WFdsnedgroup = 0x4000, // DS != DGROUP
    WFexe        = 0x8000, // generating code for Windows EXE
}

// Object file format
alias objfmt_t = uint;
enum
{
    OBJ_OMF         = 1,
    OBJ_MSCOFF      = 2,
    OBJ_ELF         = 4,
    OBJ_MACH        = 8,
}

// Executable file format
alias exefmt_t = uint;
enum
{
    EX_DOSX         = 1,       // DOSX 386 program
    EX_ZPM          = 2,       // ZPM 286 program
    EX_RATIONAL     = 4,       // RATIONAL 286 program
    EX_PHARLAP      = 8,       // PHARLAP 386 program
    EX_COM          = 0x10,    // MSDOS .COM program
    EX_OS2          = 0x40,    // OS/2 2.0 32 bit program
    EX_OS1          = 0x80,    // OS/2 1.x 16 bit program
    EX_WIN32        = 0x100,
    EX_MZ           = 0x200,   // MSDOS real mode program
    EX_LINUX        = 0x2000,
    EX_WIN64        = 0x4000,  // AMD64 and Windows (64 bit mode)
    EX_LINUX64      = 0x8000,  // AMD64 and Linux (64 bit mode)
    EX_OSX          = 0x10000,
    EX_OSX64        = 0x20000,
    EX_FREEBSD      = 0x40000,
    EX_FREEBSD64    = 0x80000,
    EX_SOLARIS      = 0x100000,
    EX_SOLARIS64    = 0x200000,
    EX_OPENBSD      = 0x400000,
    EX_OPENBSD64    = 0x800000,
    EX_DRAGONFLYBSD64 = 0x1000000,
}

// All of them
enum exefmt_t EX_all =
    EX_DOSX      |
    EX_ZPM       |
    EX_RATIONAL  |
    EX_PHARLAP   |
    EX_COM       |
    EX_OS2       |
    EX_OS1       |
    EX_WIN32     |
    EX_MZ        |
    EX_LINUX     |
    EX_WIN64     |
    EX_LINUX64   |
    EX_OSX       |
    EX_OSX64     |
    EX_FREEBSD   |
    EX_FREEBSD64 |
    EX_SOLARIS   |
    EX_SOLARIS64 |
    EX_OPENBSD   |
    EX_OPENBSD64 |
    EX_DRAGONFLYBSD64;

// All segmented memory models
enum exefmt_t EX_segmented = EX_DOSX | EX_ZPM | EX_RATIONAL | EX_PHARLAP |
                        EX_COM | EX_OS1 | EX_MZ;

// All flat memory models (no segment registers)
enum exefmt_t EX_flat = EX_OS2 | EX_WIN32 | EX_WIN64 | EX_posix;

// All DOS executable types
enum exefmt_t EX_dos =  EX_DOSX | EX_ZPM | EX_RATIONAL | EX_PHARLAP |
                         EX_COM | EX_MZ;

// Windows and DOS executable types
enum exefmt_t EX_windos = EX_dos | EX_OS1 | EX_OS2 | EX_WIN32 | EX_WIN64;

// All POSIX systems
enum exefmt_t EX_posix = EX_LINUX   | EX_LINUX64   |
                         EX_OSX     | EX_OSX64     |
                         EX_FREEBSD | EX_FREEBSD64 |
                         EX_SOLARIS | EX_SOLARIS64 |
                         EX_OPENBSD | EX_OPENBSD64 |
                         EX_DRAGONFLYBSD64;

// All 16 bit targets
enum exefmt_t EX_16 = EX_ZPM | EX_RATIONAL | EX_COM | EX_OS1 | EX_MZ;

// All 32 bit targets
enum exefmt_t EX_32 = EX_DOSX | EX_OS2 | EX_PHARLAP |
                EX_WIN32   |
                EX_LINUX   |
                EX_OSX     |
                EX_FREEBSD |
                EX_SOLARIS |
                EX_OPENBSD;

// All 64 bit targets
enum exefmt_t EX_64 =
                EX_WIN64     |
                EX_LINUX64   |
                EX_OSX64     |
                EX_FREEBSD64 |
                EX_SOLARIS64 |
                EX_OPENBSD64 |
                EX_DRAGONFLYBSD64;

// Constraints
static assert(EX_all == (EX_segmented ^ EX_flat));
static assert(EX_all == (EX_16 ^ EX_32 ^ EX_64));
static assert(EX_all == (EX_windos ^ EX_posix));

alias config_flags_t = uint;
enum
{
    CFGuchar        = 1,       // chars are unsigned
    CFGsegs         = 2,       // new code seg for each far func
    CFGtrace        = 4,       // output trace functions
    CFGglobal       = 8,       // make all static functions global
    CFGstack        = 0x10,    // add stack overflow checking
    CFGalwaysframe  = 0x20,    // always generate stack frame
    CFGnoebp        = 0x40,    // do not use EBP as general purpose register
    CFGromable      = 0x80,    // put switch tables in code segment
    CFGeasyomf      = 0x100,   // generate Pharlap Easy-OMF format
    CFGfarvtbls     = 0x200,   // store vtables in far segments
    CFGnoinlines    = 0x400,   // do not inline functions
    CFGnowarning    = 0x800,   // disable warnings
}

alias config_flags2_t = uint;
enum
{
    CFG2comdat      = 1,       // use initialized common blocks
    CFG2nodeflib    = 2,       // no default library imbedded in OBJ file
    CFG2browse      = 4,       // generate browse records
    CFG2dyntyping   = 8,       // generate dynamic typing information
    CFG2fulltypes   = 0x10,    // don't optimize CV4 class info
    CFG2warniserr   = 0x20,    // treat warnings as errors
    CFG2phauto      = 0x40,    // automatic precompiled headers
    CFG2phuse       = 0x80,    // use precompiled headers
    CFG2phgen       = 0x100,   // generate precompiled header
    CFG2once        = 0x200,   // only include header files once
    CFG2hdrdebug    = 0x400,   // generate debug info for header
    CFG2phautoy     = 0x800,   // fast build precompiled headers
    CFG2noobj       = 0x1000,  // we are not generating a .OBJ file
    CFG2noerrmax    = 0x2000,  // no error count maximum
    CFG2expand      = 0x4000,  // expanded output to list file
    CFG2stomp       = 0x8000,  // enable stack stomping code
    CFG2gms         = 0x10000, // optimize debug symbols for microsoft debuggers
}

alias config_flags3_t = uint;
enum
{
    CFG3ju          = 1,       // char == unsigned char
    CFG3eh          = 2,       // generate exception handling stuff
    CFG3strcod      = 4,       // strings are placed in code segment
    CFG3eseqds      = 8,       // ES == DS at all times
    CFG3ptrchk      = 0x10,    // generate pointer validation code
    CFG3strictproto = 0x20,    // strict prototyping
    CFG3autoproto   = 0x40,    // auto prototyping
    CFG3rtti        = 0x80,    // add RTTI support
    CFG3relax       = 0x100,   // relaxed type checking (C only)
    CFG3cpp         = 0x200,   // C++ compile
    CFG3igninc      = 0x400,   // ignore standard include directory
    CFG3mars        = 0x800,   // use mars libs and headers
    CFG3nofar       = 0x1000,  // ignore __far and __huge keywords
    CFG3noline      = 0x2000,  // do not output #line directives
    CFG3comment     = 0x4000,  // leave comments in preprocessed output
    CFG3cppcomment  = 0x8000,  // allow C++ style comments
    CFG3wkfloat     = 0x10000, // make floating point references weak externs
    CFG3digraphs    = 0x20000, // support ANSI C++ digraphs
    CFG3semirelax   = 0x40000, // moderate relaxed type checking (non-Windows targets)
    CFG3pic         = 0x80000, // position independent code
    CFG3pie         = 0x10_0000, // position independent executable (CFG3pic also set)
}

alias config_flags4_t = uint;
enum
{
    CFG4speed            = 1,          // optimized for speed
    CFG4space            = 2,          // optimized for space
    CFG4allcomdat        = 4,          // place all functions in COMDATs
    CFG4fastfloat        = 8,          // fast floating point (-ff)
    CFG4fdivcall         = 0x10,       // make function call for FDIV opcodes
    CFG4tempinst         = 0x20,       // instantiate templates for undefined functions
    CFG4oldstdmangle     = 0x40,       // do stdcall mangling without @
    CFG4pascal           = 0x80,       // default to pascal linkage
    CFG4stdcall          = 0x100,      // default to std calling convention
    CFG4cacheph          = 0x200,      // cache precompiled headers in memory
    CFG4alternate        = 0x400,      // if alternate digraph tokens
    CFG4bool             = 0x800,      // support 'bool' as basic type
    CFG4wchar_t          = 0x1000,     // support 'wchar_t' as basic type
    CFG4notempexp        = 0x2000,     // no instantiation of template functions
    CFG4anew             = 0x4000,     // allow operator new[] and delete[] overloading
    CFG4oldtmangle       = 0x8000,     // use old template name mangling
    CFG4dllrtl           = 0x10000,    // link with DLL RTL
    CFG4noemptybaseopt   = 0x20000,    // turn off empty base class optimization
    CFG4nowchar_t        = 0x40000,    // use unsigned short name mangling for wchar_t
    CFG4forscope         = 0x80000,    // new C++ for scoping rules
    CFG4warnccast        = 0x100000,   // warn about C style casts
    CFG4adl              = 0x200000,   // argument dependent lookup
    CFG4enumoverload     = 0x400000,   // enum overloading
    CFG4implicitfromvoid = 0x800000,   // allow implicit cast from void* to T*
    CFG4dependent        = 0x1000000,  // dependent / non-dependent lookup
    CFG4wchar_is_long    = 0x2000000,  // wchar_t is 4 bytes
    CFG4underscore       = 0x4000000,  // prepend _ for C mangling
}

enum config_flags4_t CFG4optimized  = CFG4speed | CFG4space;
enum config_flags4_t CFG4stackalign = CFG4speed;       // align stack to 8 bytes

alias config_flags5_t = uint;
enum
{
    CFG5debug       = 1,      // compile in __debug code
    CFG5in          = 2,      // compile in __in code
    CFG5out         = 4,      // compile in __out code
    CFG5invariant   = 8,      // compile in __invariant code
}

/* CFGX: flags ignored in precompiled headers
 * CFGY: flags copied from precompiled headers into current config
 */
enum config_flags_t CFGX   = CFGnowarning;
enum config_flags2_t CFGX2 = CFG2warniserr | CFG2phuse | CFG2phgen | CFG2phauto |
                             CFG2once | CFG2hdrdebug | CFG2noobj | CFG2noerrmax |
                             CFG2expand | CFG2nodeflib | CFG2stomp | CFG2gms;
enum config_flags3_t CFGX3 = CFG3strcod | CFG3ptrchk;
enum config_flags4_t CFGX4 = CFG4optimized | CFG4fastfloat | CFG4fdivcall |
                             CFG4tempinst | CFG4cacheph | CFG4notempexp |
                             CFG4stackalign | CFG4dependent;

enum config_flags4_t CFGY4 = CFG4nowchar_t | CFG4noemptybaseopt | CFG4adl |
                             CFG4enumoverload | CFG4implicitfromvoid |
                             CFG4wchar_is_long | CFG4underscore;

// Configuration flags for HTOD executable
alias htod_flags_t = uint;
enum
{
    HTODFinclude    = 1,      // -hi drill down into #include files
    HTODFsysinclude = 2,      // -hs drill down into system #include files
    HTODFtypedef    = 4,      // -ht drill down into typedefs
    HTODFcdecl      = 8,      // -hc skip C declarations as comments
}

// This part of the configuration is saved in the precompiled header for use
// in comparing to make sure it hasn't changed.

struct Config
{
    char language;              // 'C' = C, 'D' = C++
    string _version;            /// Compiler version
    char[3] exetype;            // distinguish exe types so PH
                                // files are distinct (= SUFFIX)

    cpu_target_t target_cpu;       // instruction selection
    cpu_target_t target_scheduler; // instruction scheduling (normally same as selection)

    short versionint;           // intermediate file version (= VERSIONINT)
    int defstructalign;         // struct alignment specified by command line
    short hxversion;            // HX version number
    symbolic_debug_t fulltypes; // format of symbolic debug info

    windows_flags_t wflags;     // flags for Windows code generation

    bool fpxmmregs;             // use XMM registers for floating point
    ubyte avx;                  // use AVX instruction set (0, 1, 2)
    ubyte inline8087;           /* 0:   emulator
                                   1:   IEEE 754 inline 8087 code
                                   2:   fast inline 8087 code
                                 */
    short memmodel;             // 0:S,X,N,F, 1:M, 2:C, 3:L, 4:V
    objfmt_t objfmt;            // target object format
    exefmt_t exe;               // target operating system

    config_flags_t  flags;
    config_flags2_t flags2;
    config_flags3_t flags3;
    config_flags4_t flags4;
    config_flags5_t flags5;

    htod_flags_t htodFlags;     // configuration for htod
    ubyte ansi_c;               // strict ANSI C
                                // 89 for ANSI C89, 99 for ANSI C99
    ubyte asian_char;           // 0: normal, 1: Japanese, 2: Chinese
                                // and Taiwanese, 3: Korean
    uint threshold;             // data larger than threshold is assumed to
                                // be far (16 bit models only)
                                // if threshold == THRESHMAX, all data defaults
                                // to near
    linkage_t linkage;          // default function call linkage
    EHmethod ehmethod;          // exception handling method
    bool useModuleInfo;         // implement ModuleInfo
    bool useTypeInfo;           // implement TypeInfo
    bool useExceptions;         // implement exception handling
    ubyte dwarf;                // DWARF version
}

enum THRESHMAX = 0xFFFF;

// Language for error messages
enum LANG
{
    english,
    german,
    french,
    japanese,
}

// Configuration that is not saved in precompiled header

struct Configv
{
    ubyte addlinenumbers;       // put line number info in .OBJ file
    ubyte verbose;              // 0: compile quietly (no messages)
                                // 1: show progress to DLL (default)
                                // 2: full verbosity
    char* csegname;             // code segment name
    char* deflibname;           // default library name
    LANG language;              // message language
    int errmax;                 // max error count
}

alias reg_t = ubyte;            // register number
alias regm_t = uint;            // Register mask type
struct immed_t
{
    targ_size_t[REGMAX] value;  // immediate values in registers
    regm_t mval;                // Mask of which values in regimmed.value[] are valid
}


struct cse_t
{
    elem*[REGMAX] value;        // expression values in registers
    regm_t mval;                // mask of which values in value[] are valid
    regm_t mops;                // subset of mval that contain common subs that need
                                // to be stored in csextab[] if they are destroyed
}

struct con_t
{
    cse_t cse;                  // CSEs in registers
    immed_t immed;              // immediate values in registers
    regm_t mvar;                // mask of register variables
    regm_t mpvar;               // mask of SCfastpar, SCshadowreg register variables
    regm_t indexregs;           // !=0 if more than 1 uncommitted index register
    regm_t used;                // mask of registers used
    regm_t params;              // mask of registers which still contain register
                                // function parameters
}

/*********************************
 * Bootstrap complex types.
 */

import dmd.backend.bcomplex;

/*********************************
 * Union of all data types. Storage allocated must be the right
 * size of the data on the TARGET, not the host.
 */

struct Cent
{
    targ_ullong lsw;
    targ_ullong msw;
}

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
        targ_float      Vfloat;
        targ_double     Vdouble;
        targ_ldouble    Vldouble;
        Complex_f       Vcfloat;   // 2x float
        Complex_d       Vcdouble;  // 2x double
        Complex_ld      Vcldouble; // 2x long double
        targ_size_t     Vpointer;
        targ_ptrdiff_t  Vptrdiff;
        targ_uchar      Vreg;   // register number for OPreg elems

        // 16 byte vector types
        targ_float[4]   Vfloat4;   // float[4]
        targ_double[2]  Vdouble2;  // double[2]
        targ_schar[16]  Vschar16;  // byte[16]
        targ_uchar[16]  Vuchar16;  // ubyte[16]
        targ_short[8]   Vshort8;   // short[8]
        targ_ushort[8]  Vushort8;  // ushort[8]
        targ_long[4]    Vlong4;    // int[4]
        targ_ulong[4]   Vulong4;   // uint[4]
        targ_llong[2]   Vllong2;   // long[2]
        targ_ullong[2]  Vullong2;  // ulong[2]

        // 32 byte vector types
        targ_float[8]   Vfloat8;   // float[8]
        targ_double[4]  Vdouble4;  // double[4]
        targ_schar[32]  Vschar32;  // byte[32]
        targ_uchar[32]  Vuchar32;  // ubyte[32]
        targ_short[16]  Vshort16;  // short[16]
        targ_ushort[16] Vushort16; // ushort[16]
        targ_long[8]    Vlong8;    // int[8]
        targ_ulong[8]   Vulong8;   // uint[8]
        targ_llong[4]   Vllong4;   // long[4]
        targ_ullong[4]  Vullong4;  // ulong[4]

        struct                  // 48 bit 386 far pointer
        {   targ_long   Voff;
            targ_ushort Vseg;
        }
        struct
        {
            targ_size_t Voffset;// offset from symbol
            Symbol *Vsym;       // pointer to symbol table
            union
            {
                param_t* Vtal;  // template-argument-list for SCfunctempl,
                                // used only to transmit it to cpp_overload()
                LIST* Erd;      // OPvar: reaching definitions
            }
        }
        struct
        {
            targ_size_t Voffset2;// member pointer offset
            Classsym* Vsym2;    // struct tag
            elem* ethis;        // OPrelconst: 'this' for member pointer
        }
        struct
        {
            targ_size_t Voffset3;// offset from string
            char* Vstring;      // pointer to string (OPstring or OPasm)
            size_t Vstrlen;     // length of string
        }
        struct
        {
            elem* E1;           // left child for unary & binary nodes
            elem* E2;           // right child for binary nodes
            Symbol* Edtor;      // OPctor: destructor
        }
        struct
        {
            elem* Eleft2;       // left child for OPddtor
            void* Edecl;        // VarDeclaration being constructed
        }                       // OPdctor,OPddtor
}                               // variants for each type of elem

// Symbols

//#ifdef DEBUG
//#define IDSYMBOL        IDsymbol,
//#else
//#define IDSYMBOL
//#endif

alias SYMFLGS = uint;


/**********************************
 * Storage classes
 */

alias SC = int;
enum
{
    SCunde,           // undefined
    SCauto,           // automatic (stack)
    SCstatic,         // statically allocated
    SCthread,         // thread local
    SCextern,         // external
    SCregister,       // registered variable
    SCpseudo,         // pseudo register variable
    SCglobal,         // top level global definition
    SCcomdat,         // initialized common block
    SCparameter,      // function parameter
    SCregpar,         // function register parameter
    SCfastpar,        // function parameter passed in register
    SCshadowreg,      // function parameter passed in register, shadowed on stack
    SCtypedef,        // type definition
    SCexplicit,       // explicit
    SCmutable,        // mutable
    SClabel,          // goto label
    SCstruct,         // struct/class/union tag name
    SCenum,           // enum tag name
    SCfield,          // bit field of struct or union
    SCconst,          // constant integer
    SCmember,         // member of struct or union
    SCanon,           // member of anonymous union
    SCinline,         // for inline functions
    SCsinline,        // for static inline functions
    SCeinline,        // for extern inline functions
    SCoverload,       // for overloaded function names
    SCfriend,         // friend of a class
    SCvirtual,        // virtual function
    SClocstat,        // static, but local to a function
    SCtemplate,       // class template
    SCfunctempl,      // function template
    SCftexpspec,      // function template explicit specialization
    SClinkage,        // function linkage symbol
    SCpublic,         // generate a pubdef for this
    SCcomdef,         // uninitialized common block
    SCbprel,          // variable at fixed offset from frame pointer
    SCnamespace,      // namespace
    SCalias,          // alias to another symbol
    SCfuncalias,      // alias to another function symbol
    SCmemalias,       // alias to base class member
    SCstack,          // offset from stack pointer (not frame pointer)
    SCadl,            // list of ADL symbols for overloading
    SCMAX
}

int ClassInline(int c) { return c == SCinline || c == SCsinline || c == SCeinline; }
int SymInline(Symbol* s) { return ClassInline(s.Sclass); }

