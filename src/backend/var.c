// Copyright (C) 1985-1998 by Symantec
// Copyright (C) 2000-2015 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */

/* Global variables for PARSER  */

#include        <stdio.h>
#include        <time.h>

#include        "cc.h"
#include        "global.h"
#include        "oper.h"
#include        "type.h"
#include        "go.h"
#include        "ty.h"
#include        "code.h"
#if SPP || SCPP
#include        "parser.h"
#endif

#include        "optab.c"
#include        "tytab.c"

#if __DMC__ && _MSDOS
unsigned __cdecl _stack = 100000;       // set default stack size
#endif

/* Global flags:
 */

char PARSER;                    // indicate we're in the parser
char OPTIMIZER;                 // indicate we're in the optimizer
int structalign;                /* alignment for members of structures  */
char dbcs;                      // current double byte character set

int TYptrdiff = TYint;
int TYsize = TYuint;
int TYsize_t = TYuint;

#ifdef DEBUG
char debuga,debugb,debugc,debugd,debuge,debugf,debugr,debugs,debugt,debugu,debugw,debugx,debugy;
#endif

#if !MARS
linkage_t linkage;
int linkage_spec = 0;           /* using the default                    */

/* Function types       */
/* LINK_MAXDIM = C,C++,Pascal,FORTRAN,syscall,stdcall,Jupiter */
#if MEMMODELS == 1
tym_t functypetab[LINK_MAXDIM] =
{
#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
    TYnfunc,
    TYnpfunc,
    TYnpfunc,
    TYnfunc,
#endif
};
#else
tym_t functypetab[LINK_MAXDIM][MEMMODELS] =
{
    TYnfunc,  TYffunc,  TYnfunc,  TYffunc,  TYffunc,
#if VBTABLES
    TYnfunc,  TYffunc,  TYnfunc,  TYffunc,  TYffunc,
#else
    TYnpfunc, TYfpfunc, TYnpfunc, TYfpfunc, TYfpfunc,
#endif
    TYnpfunc, TYfpfunc, TYnpfunc, TYfpfunc, TYfpfunc,
    TYnpfunc, TYfpfunc, TYnpfunc, TYfpfunc, TYfpfunc,
    TYnfunc,  TYffunc,  TYnfunc,  TYffunc,  TYffunc,
    TYnsfunc, TYfsfunc, TYnsfunc, TYfsfunc, TYfsfunc,
    TYjfunc,  TYfpfunc, TYnpfunc, TYfpfunc, TYfpfunc,
};
#endif

/* Function mangling    */
/* LINK_MAXDIM = C,C++,Pascal,FORTRAN,syscall,stdcall */
mangle_t funcmangletab[LINK_MAXDIM] =
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
mangle_t varmangletab[LINK_MAXDIM] =
{
    mTYman_c,
#if NEWMANGLE
    mTYman_cpp,
#else
    mTYman_c,
#endif
    mTYman_pas,mTYman_for,mTYman_sys,mTYman_std,mTYman_d
};
#endif

targ_size_t     dsout = 0;      /* # of bytes actually output to data   */
                                /* segment, used to pad for alignment   */

/* File variables: */

char *argv0;                    // argv[0] (program name)
FILE *fdep = NULL;              // dependency file stream pointer
FILE *flst = NULL;              // list file stream pointer
FILE *fin = NULL;               // input file
#if SPP
FILE *fout;
#endif
#if HTOD
char *fdmodulename = NULL;
FILE *fdmodule = NULL;
#endif
char     *foutdir = NULL,       // directory to place output files in
         *finname = NULL,
        *foutname = NULL,
        *fsymname = NULL,
        *fphreadname = NULL,
        *ftdbname = NULL,
        *fdepname = NULL,
        *flstname = NULL;       /* the filename strings                 */

#if SPP || SCPP
phstring_t fdeplist;
phstring_t pathlist;            // include paths
#endif

int pathsysi;                   // -isystem= index
list_t headers;                 /* pre-include files                    */

/* Data from lexical analyzer: */

unsigned idhash = 0;    // hash value of identifier
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

param_t *paramlst = NULL;       /* function parameter list              */
tym_t pointertype = TYnptr;     /* default data pointer type            */

/************************
 * Bit masks
 */

const unsigned mask[32] =
        {1,2,4,8,16,32,64,128,256,512,1024,2048,4096,8192,16384,0x8000,
         0x10000,0x20000,0x40000,0x80000,0x100000,0x200000,0x400000,0x800000,
         0x1000000,0x2000000,0x4000000,0x8000000,
         0x10000000,0x20000000,0x40000000,0x80000000};

#if 0
const unsigned long maskl[32] =
        {1,2,4,8,0x10,0x20,0x40,0x80,
         0x100,0x200,0x400,0x800,0x1000,0x2000,0x4000,0x8000,
         0x10000,0x20000,0x40000,0x80000,0x100000,0x200000,0x400000,0x800000,
         0x1000000,0x2000000,0x4000000,0x8000000,
         0x10000000,0x20000000,0x40000000,0x80000000};
#endif

/* From util.c */

/*****************************
 * SCxxxx types.
 */

#if !SPP

char sytab[SCMAX] =
{
    #define X(a,b)      b,
        ENUMSCMAC
    #undef X
};

#endif /* !SPP */
volatile int controlc_saw;              /* a control C was seen         */
symtab_t globsym;               /* global symbol table                  */
Pstate pstate;                  // parser state
Cstate cstate;                  // compiler state

/* From go.c */
mftype mfoptim = 0;             // mask of optimizations to perform

unsigned changes;               // # of optimizations performed
struct DN *defnod = NULL;       // array of definition elems

elem **expnod = NULL;   /* array of expression elems                    */
block **expblk = NULL;  /* parallel array of block pointers             */

unsigned
         maxblks = 0,   /* array max for all block stuff                */
                        /* dfoblks <= numblks <= maxblks                */
         numcse,        /* number of common subexpressions              */
         deftop = 0,    /* # of entries in defnod[]                     */
         exptop = 0;    /* top of expnod[]                              */

vec_t   defkill = NULL,         /* vector of AEs killed by an ambiguous */
                                /* definition                           */
        starkill = NULL,        /* vector of AEs killed by a definition */
                                /* of something that somebody could be  */
                                /* pointing to                          */
        vptrkill = NULL;        /* vector of AEs killed by an access    */
                                /* to a vptr                            */

/* From debug.c */
#if DEBUG
const char *regstring[32] = {"AX","CX","DX","BX","SP","BP","SI","DI",
                             "R8","R9","R10","R11","R12","R13","R14","R15",
                             "XMM0","XMM1","XMM2","XMM3","XMM4","XMM5","XMM6","XMM7",
                             "ES","PSW","STACK","ST0","ST01","NOREG","RMload","RMstore"};
#endif

/* From nwc.c */

type *chartype;                 /* default 'char' type                  */

Obj *objmod = NULL;
