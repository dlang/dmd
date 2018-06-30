/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2018 by The D Language Foundation, All Rights Reserved
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
import dmd.backend.ty;
import dmd.backend.type;
version (MARS)
{
    import dmd.backend.varstats;
}
//version (SPP)
    //import dmd.backend.parser;
//else version (SCPP)
    //import dmd.backend.parser;

extern(C++):

/* Global flags:
 */

__gshared
{
char PARSER;                    // indicate we're in the parser
char OPTIMIZER;                 // indicate we're in the optimizer
int structalign;                /* alignment for members of structures  */
char dbcs;                      // current double byte character set

int TYptrdiff = TYint;
int TYsize = TYuint;
int TYsize_t = TYuint;
int TYaarray = TYnptr;
int TYdelegate = TYllong;
int TYdarray = TYullong;

char debuga,debugb,debugc,debugd,debuge,debugf,debugr,debugs,debugt,debugu,debugw,debugx,debugy;

version (MARS) {} else
{
linkage_t linkage;
int linkage_spec = 0;           /* using the default                    */

/* Function types       */
/* LINK_MAXDIM = C,C++,Pascal,FORTRAN,syscall,stdcall,Mars */
static if (MEMMODELS == 1)
{
    static if (TARGET.Linux || TARGET.OSX || TARGET.FreeBSD || TARGET.OpenBSD || TARGET.DragonFlyBSD || TARGET.Solaris)
        tym_t[LINK_MAXDIM] functypetab =
        {
            TYnfunc,
            TYnpfunc,
            TYnpfunc,
            TYnfunc,
        };
    }
else
{
tym_t[MEMMODELS][LINK_MAXDIM] functypetab =
{
    TYnfunc,  TYffunc,  TYnfunc,  TYffunc,  TYffunc,
    TYnfunc,  TYffunc,  TYnfunc,  TYffunc,  TYffunc,
    TYnpfunc, TYfpfunc, TYnpfunc, TYfpfunc, TYfpfunc,
    TYnpfunc, TYfpfunc, TYnpfunc, TYfpfunc, TYfpfunc,
    TYnfunc,  TYffunc,  TYnfunc,  TYffunc,  TYffunc,
    TYnsfunc, TYfsfunc, TYnsfunc, TYfsfunc, TYfsfunc,
    TYjfunc,  TYfpfunc, TYnpfunc, TYfpfunc, TYfpfunc,
};
}

/* Function mangling    */
/* LINK_MAXDIM = C,C++,Pascal,FORTRAN,syscall,stdcall */
mangle_t[LINK_MAXDIM] funcmangletab =
{
    mTYman_c,
    mTYman_cpp,
    mTYman_pas,
    mTYman_for,
    mTYman_sys,
    mTYman_std,
    mTYman_d,
};

/* Name mangling for global variables   */
mangle_t[LINK_MAXDIM] varmangletab =
{
    mTYman_c,
    mTYman_cpp,
    mTYman_pas,mTYman_for,mTYman_sys,mTYman_std,mTYman_d
};
}

/* File variables: */

char *argv0;                    // argv[0] (program name)
FILE *fdep = null;              // dependency file stream pointer
FILE *flst = null;              // list file stream pointer
FILE *fin = null;               // input file
version (SPP)
{
FILE *fout;
}
version (HTOD)
{
char *fdmodulename = null;
FILE *fdmodule = null;
}
char     *foutdir = null,       // directory to place output files in
         finname = null,
        foutname = null,
        fsymname = null,
        fphreadname = null,
        ftdbname = null,
        fdepname = null,
        flstname = null;       /* the filename strings                 */

//#if SPP || SCPP
version (SPP)
    enum SPP_OR_SCPP = true;
else version (SCPP)
    enum SPP_OR_SCPP = true;
else
    enum SPP_OR_SCPP = false;
static if (SPP_OR_SCPP)
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

param_t *paramlst = null;       /* function parameter list            */
tym_t pointertype = TYnptr;     /* default data pointer type            */

/************************
 * Bit masks
 */

const uint[32] mask =
        [1,2,4,8,16,32,64,128,256,512,1024,2048,4096,8192,16384,0x8000,
         0x10000,0x20000,0x40000,0x80000,0x100000,0x200000,0x400000,0x800000,
         0x1000000,0x2000000,0x4000000,0x8000000,
         0x10000000,0x20000000,0x40000000,0x80000000];

static if(0)
{
const ulong[32] maskl =
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

version (SPP) {} else
{

char[SCMAX] sytab;

} /* !SPP */
/*volatile*/ int controlc_saw;              /* a control C was seen         */
symtab_t globsym;               /* global Symbol table                  */
Pstate pstate;                  // parser state
Cstate cstate;                  // compiler state

uint
         maxblks = 0,   /* array max for all block stuff                */
                        /* dfoblks <= numblks <= maxblks                */
         numcse;        /* number of common subexpressions              */

GlobalOptimizer go;

/* From debug.c */
const char*[32] regstring = ["AX","CX","DX","BX","SP","BP","SI","DI",
                             "R8","R9","R10","R11","R12","R13","R14","R15",
                             "XMM0","XMM1","XMM2","XMM3","XMM4","XMM5","XMM6","XMM7",
                             "ES","PSW","STACK","ST0","ST01","NOREG","RMload","RMstore"];

/* From nwc.c */

type *chartype;                 /* default 'char' type                  */

Obj *objmod = null;

version (MARS)
{
    import dmd.backend.varstats;
    VarStatistics varStats;
}

}
