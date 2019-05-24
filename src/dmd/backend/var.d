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

mixin(import("optab.d"));
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

extern (C)
{
version (SPP)
{
FILE *fout;
}
}

// htod
char *fdmodulename = null;
extern (C) FILE *fdmodule = null;


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

uint maxblks = 0;   /* array max for all block stuff                */
                        /* dfoblks <= numblks <= maxblks                */


GlobalOptimizer go;

/* From debug.c */
const(char)*[32] regstring = ["AX","CX","DX","BX","SP","BP","SI","DI",
                             "R8","R9","R10","R11","R12","R13","R14","R15",
                             "XMM0","XMM1","XMM2","XMM3","XMM4","XMM5","XMM6","XMM7",
                             "ES","PSW","STACK","ST0","ST01","NOREG","RMload","RMstore"];

/* From nwc.c */

type *chartype;                 /* default 'char' type                  */

Obj objmod = null;


