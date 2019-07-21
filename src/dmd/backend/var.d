/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2019 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/var.d, backend/var.d)
 */

module dmd.backend.var;

/* Global variables for PARSER  */

import core.stdc.stdio;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.code;
import dmd.backend.dlist;
import dmd.backend.goh;
import dmd.backend.obj;
import dmd.backend.oper;
import dmd.backend.ty;
import dmd.backend.type;

version (SPP)
{
    import parser;
    import phstring;
}
version (SCPP)
{
    import parser;
    import phstring;
}
version (HTOD)
{
    import parser;
    import phstring;
}

extern (C++):

nothrow:

mixin(import("tytab.d"));

__gshared:

/* Global flags:
 */

char PARSER = 0;                    // indicate we're in the parser
char OPTIMIZER = 0;                 // indicate we're in the optimizer
int structalign;                /* alignment for members of structures  */
char dbcs = 0;                      // current double byte character set

int TYptrdiff = TYint;
int TYsize = TYuint;
int TYsize_t = TYuint;
int TYaarray = TYnptr;
int TYdelegate = TYllong;
int TYdarray = TYullong;

char debuga=0,debugb=0,debugc=0,debugd=0,debuge=0,debugf=0,debugr=0,debugs=0,debugt=0,debugu=0,debugw=0,debugx=0,debugy=0;

version (MARS) { } else
{
linkage_t linkage;
int linkage_spec = 0;           /* using the default                    */

/* Function types       */
/* LINK_MAXDIM = C,C++,Pascal,FORTRAN,syscall,stdcall,Mars */
static if (MEMMODELS == 1)
{
tym_t[LINK_MAXDIM] functypetab =
[
    TYnfunc,
    TYnpfunc,
    TYnpfunc,
    TYnfunc,
];
}
else
{
tym_t[MEMMODELS][LINK_MAXDIM] functypetab =
[
    [ TYnfunc,  TYffunc,  TYnfunc,  TYffunc,  TYffunc  ],
    [ TYnfunc,  TYffunc,  TYnfunc,  TYffunc,  TYffunc  ],
    [ TYnpfunc, TYfpfunc, TYnpfunc, TYfpfunc, TYfpfunc ],
    [ TYnpfunc, TYfpfunc, TYnpfunc, TYfpfunc, TYfpfunc ],
    [ TYnfunc,  TYffunc,  TYnfunc,  TYffunc,  TYffunc  ],
    [ TYnsfunc, TYfsfunc, TYnsfunc, TYfsfunc, TYfsfunc ],
    [ TYjfunc,  TYfpfunc, TYnpfunc, TYfpfunc, TYfpfunc ],
];
}

/* Function mangling    */
/* LINK_MAXDIM = C,C++,Pascal,FORTRAN,syscall,stdcall */
mangle_t[LINK_MAXDIM] funcmangletab =
[
    mTYman_c,
    mTYman_cpp,
    mTYman_pas,
    mTYman_for,
    mTYman_sys,
    mTYman_std,
    mTYman_d,
];

/* Name mangling for global variables   */
mangle_t[LINK_MAXDIM] varmangletab =
[
    mTYman_c,
    mTYman_cpp,
    mTYman_pas,mTYman_for,mTYman_sys,mTYman_std,mTYman_d
];
}

/* File variables: */

char *argv0;                    // argv[0] (program name)
extern (C)
{
FILE *fdep = null;              // dependency file stream pointer
FILE *flst = null;              // list file stream pointer
FILE *fin = null;               // input file
version (SPP)
{
FILE *fout;
}
}

// htod
char *fdmodulename = null;
extern (C) FILE *fdmodule = null;

char*   foutdir = null,       // directory to place output files in
        finname = null,
        foutname = null,
        fsymname = null,
        fphreadname = null,
        ftdbname = null,
        fdepname = null,
        flstname = null;       /* the filename strings                 */

version (SPP)
{
    phstring_t fdeplist;
    phstring_t pathlist;            // include paths
}
version (SCPP)
{
    phstring_t fdeplist;
    phstring_t pathlist;            // include paths
}
version (HTOD)
{
    phstring_t fdeplist;
    phstring_t pathlist;            // include paths
}

int pathsysi;                   // -isystem= index
list_t headers;                 /* pre-include files                    */

/* Data from lexical analyzer: */

uint idhash = 0;    // hash value of identifier
int xc = ' ';           // character last read

/* Data for pragma processor:
 */

int colnumber = 0;              /* current column number                */

/* Other variables: */

int level = 0;                  /* declaration level                    */
                                /* 0: top level                         */
                                /* 1: function parameter declarations   */
                                /* 2: function local declarations       */
                                /* 3+: compound statement decls         */

param_t *paramlst = null;       /* function parameter list              */
tym_t pointertype = TYnptr;     /* default data pointer type            */

/************************
 * Bit masks
 */

const uint[32] mask =
        [1,2,4,8,16,32,64,128,256,512,1024,2048,4096,8192,16384,0x8000,
         0x10000,0x20000,0x40000,0x80000,0x100000,0x200000,0x400000,0x800000,
         0x1000000,0x2000000,0x4000000,0x8000000,
         0x10000000,0x20000000,0x40000000,0x80000000];

static if (0)
{
const uint[32] maskl =
        [1,2,4,8,0x10,0x20,0x40,0x80,
         0x100,0x200,0x400,0x800,0x1000,0x2000,0x4000,0x8000,
         0x10000,0x20000,0x40000,0x80000,0x100000,0x200000,0x400000,0x800000,
         0x1000000,0x2000000,0x4000000,0x8000000,
         0x10000000,0x20000000,0x40000000,0x80000000];
}


/* From util.c */

/*****************************
 * SCxxxx types.
 */

version (SPP) { } else
{

char[SCMAX] sytab =
[
    /* unde */     SCEXP|SCKEP|SCSCT,      /* undefined                            */
    /* auto */     SCEXP|SCSS|SCRD  ,      /* automatic (stack)                    */
    /* static */   SCEXP|SCKEP|SCSCT,      /* statically allocated                 */
    /* thread */   SCEXP|SCKEP      ,      /* thread local                         */
    /* extern */   SCEXP|SCKEP|SCSCT,      /* external                             */
    /* register */ SCEXP|SCSS|SCRD  ,      /* registered variable                  */
    /* pseudo */   SCEXP            ,      /* pseudo register variable             */
    /* global */   SCEXP|SCKEP|SCSCT,      /* top level global definition          */
    /* comdat */   SCEXP|SCKEP|SCSCT,      /* initialized common block             */
    /* parameter */SCEXP|SCSS       ,      /* function parameter                   */
    /* regpar */   SCEXP|SCSS       ,      /* function register parameter          */
    /* fastpar */  SCEXP|SCSS       ,      /* function parameter passed in register */
    /* shadowreg */SCEXP|SCSS       ,      /* function parameter passed in register, shadowed on stack */
    /* typedef */  0                ,      /* type definition                      */
    /* explicit */ 0                ,      /* explicit                             */
    /* mutable */  0                ,      /* mutable                              */
    /* label */    0                ,      /* goto label                           */
    /* struct */   SCKEP            ,      /* struct/class/union tag name          */
    /* enum */     0                ,      /* enum tag name                        */
    /* field */    SCEXP|SCKEP      ,      /* bit field of struct or union         */
    /* const */    SCEXP|SCSCT      ,      /* constant integer                     */
    /* member */   SCEXP|SCKEP|SCSCT,      /* member of struct or union            */
    /* anon */     0                ,      /* member of anonymous union            */
    /* inline */   SCEXP|SCKEP      ,      /* for inline functions                 */
    /* sinline */  SCEXP|SCKEP      ,      /* for static inline functions          */
    /* einline */  SCEXP|SCKEP      ,      /* for extern inline functions          */
    /* overload */ SCEXP            ,      /* for overloaded function names        */
    /* friend */   0                ,      /* friend of a class                    */
    /* virtual */  0                ,      /* virtual function                     */
    /* locstat */  SCEXP|SCSCT      ,      /* static, but local to a function      */
    /* template */ 0                ,      /* class template                       */
    /* functempl */0                ,      /* function template                    */
    /* ftexpspec */0                ,      /* function template explicit specialization */
    /* linkage */  0                ,      /* function linkage symbol              */
    /* public */   SCEXP|SCKEP|SCSCT,      /* generate a pubdef for this           */
    /* comdef */   SCEXP|SCKEP|SCSCT,      /* uninitialized common block           */
    /* bprel */    SCEXP|SCSS       ,      /* variable at fixed offset from frame pointer */
    /* namespace */0                ,      /* namespace                            */
    /* alias */    0                ,      /* alias to another symbol              */
    /* funcalias */0                ,      /* alias to another function symbol     */
    /* memalias */ 0                ,      /* alias to base class member           */
    /* stack */    SCEXP|SCSS       ,      /* offset from stack pointer (not frame pointer) */
    /* adl */      0                ,      /* list of ADL symbols for overloading  */
];

}

extern (C) int controlc_saw = 0;              /* a control C was seen         */
symtab_t globsym;               /* global symbol table                  */
Pstate pstate;                  // parser state
Cstate cstate;                  // compiler state

uint
         maxblks = 0,   /* array max for all block stuff                */
                        /* dfoblks <= numblks <= maxblks                */
         numcse;        /* number of common subexpressions              */

GlobalOptimizer go;

/* From debug.c */
const(char)*[32] regstring = ["AX","CX","DX","BX","SP","BP","SI","DI",
                             "R8","R9","R10","R11","R12","R13","R14","R15",
                             "XMM0","XMM1","XMM2","XMM3","XMM4","XMM5","XMM6","XMM7",
                             "ES","PSW","STACK","ST0","ST01","NOREG","RMload","RMstore"];

/* From nwc.c */

type *chartype;                 /* default 'char' type                  */

Obj objmod = null;

__gshared uint[256] tytab =
() {
    uint[256] tab;
    foreach (i; TXptr)        { tab[i] |= TYFLptr; }
    foreach (i; TXptr_nflat)  { tab[i] |= TYFLptr; }
    foreach (i; TXreal)       { tab[i] |= TYFLreal; }
    foreach (i; TXintegral)   { tab[i] |= TYFLintegral; }
    foreach (i; TXimaginary)  { tab[i] |= TYFLimaginary; }
    foreach (i; TXcomplex)    { tab[i] |= TYFLcomplex; }
    foreach (i; TXuns)        { tab[i] |= TYFLuns; }
    foreach (i; TXmptr)       { tab[i] |= TYFLmptr; }
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


extern (C) __gshared const(char)*[TYMAX] tystring =
[
    TYbool    : "bool",
    TYchar    : "char",
    TYschar   : "signed char",
    TYuchar   : "unsigned char",
    TYchar16  : "char16_t",
    TYshort   : "short",
    TYwchar_t : "wchar_t",
    TYushort  : "unsigned short",

    TYenum    : "enum",
    TYint     : "int",
    TYuint    : "unsigned",

    TYlong    : "long",
    TYulong   : "unsigned long",
    TYdchar   : "dchar",
    TYllong   : "long long",
    TYullong  : "uns long long",
    TYcent    : "cent",
    TYucent   : "ucent",
    TYfloat   : "float",
    TYdouble  : "double",
    TYdouble_alias : "double alias",
    TYldouble : "long double",

    TYifloat   : "imaginary float",
    TYidouble  : "imaginary double",
    TYildouble : "imaginary long double",

    TYcfloat   : "complex float",
    TYcdouble  : "complex double",
    TYcldouble : "complex long double",

    TYfloat4  : "float[4]",
    TYdouble2 : "double[2]",
    TYschar16 : "signed char[16]",
    TYuchar16 : "unsigned char[16]",
    TYshort8  : "short[8]",
    TYushort8 : "unsigned short[8]",
    TYlong4   : "long[4]",
    TYulong4  : "unsigned long[4]",
    TYllong2  : "long long[2]",
    TYullong2 : "unsigned long long[2]",

    TYfloat8  : "float[8]",
    TYdouble4 : "double[4]",
    TYschar32 : "signed char[32]",
    TYuchar32 : "unsigned char[32]",
    TYshort16 : "short[16]",
    TYushort16 : "unsigned short[16]",
    TYlong8   : "long[8]",
    TYulong8  : "unsigned long[8]",
    TYllong4  : "long long[4]",
    TYullong4 : "unsigned long long[4]",

    TYfloat16 : "float[16]",
    TYdouble8 : "double[8]",
    TYschar64 : "signed char[64]",
    TYuchar64 : "unsigned char[64]",
    TYshort32 : "short[32]",
    TYushort32 : "unsigned short[32]",
    TYlong16  : "long[16]",
    TYulong16 : "unsigned long[16]",
    TYllong8  : "long long[8]",
    TYullong8 : "unsigned long long[8]",

    TYnullptr : "nullptr_t",
    TYnptr    : "*",
    TYref     : "&",
    TYvoid    : "void",
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
    TYfgPtr    : "__fg *",
    TYffunc    : "far C func",
    TYfpfunc   : "far Pascal func",
    TYfsfunc   : "far std func",
    TYf16func  : "_far16 Pascal func",
    TYnsysfunc : "sys func",
    TYfsysfunc : "far sys func",
    TYfref     : "__far &",

    TYifunc    : "interrupt func",
    TYmemptr   : "memptr",
    TYident    : "ident",
    TYtemplate : "template",
    TYvtshape  : "vtshape",
];

// Map to unsigned version of type
__gshared tym_t[256] tytouns =
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


private:

enum TXptr       = [ TYnptr ];
enum TXptr_nflat = [ TYsptr,TYcptr,TYf16ptr,TYfptr,TYhptr,TYvptr,TYimmutPtr,TYsharePtr,TYfgPtr ];
enum TXreal      = [ TYfloat,TYdouble,TYdouble_alias,TYldouble,
                     TYfloat4,TYdouble2,
                     TYfloat8,TYdouble4,
                     TYfloat16,TYdouble8,
                   ];
enum TXimaginary = [ TYifloat,TYidouble,TYildouble, ];
enum TXcomplex   = [ TYcfloat,TYcdouble,TYcldouble, ];
enum TXintegral  = [ TYbool,TYchar,TYschar,TYuchar,TYshort,
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
enum TXref       = [ TYnref,TYref ];
enum TXfunc      = [ TYnfunc,TYnpfunc,TYnsfunc,TYifunc,TYmfunc,TYjfunc,TYhfunc ];
enum TXref_nflat = [ TYfref ];
enum TXfunc_nflat= [ TYffunc,TYfpfunc,TYf16func,TYfsfunc,TYnsysfunc,TYfsysfunc, ];
enum TXuns       = [ TYuchar,TYushort,TYuint,TYulong,
                     TYwchar_t,
                     TYuchar16,TYushort8,TYulong4,TYullong2,
                     TYdchar,TYullong,TYucent,TYchar16 ];
enum TXmptr      = [ TYmemptr ];
enum TXnullptr   = [ TYnullptr ];
enum TXfv        = [ TYfptr, TYvptr ];
enum TXfarfunc   = [ TYffunc,TYfpfunc,TYfsfunc,TYfsysfunc ];
enum TXpasfunc   = [ TYnpfunc,TYnsfunc,TYmfunc,TYjfunc ];
enum TXpasfunc_nf = [ TYfpfunc,TYf16func,TYfsfunc, ];
enum TXrevfunc    = [ TYnpfunc,TYjfunc ];
enum TXrevfunc_nf = [ TYfpfunc,TYf16func, ];
enum TXshort      = [ TYbool,TYchar,TYschar,TYuchar,TYshort,
                      TYwchar_t,TYushort,TYchar16 ];
enum TXaggregate  = [ TYstruct,TYarray ];
enum TXxmmreg     = [
                     TYfloat,TYdouble,TYifloat,TYidouble,
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
enum TXsimd       = [
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

