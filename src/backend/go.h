// Copyright (C) 1985-1998 by Symantec
// Copyright (C) 2000-2016 by Digital Mars
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

#ifndef GO_H
#define GO_H 1

/***************************************
 * Bit masks for various optimizations.
 */

typedef unsigned mftype;        /* a type big enough for all the flags  */
enum
{
    MFdc    = 1,               // dead code
    MFda    = 2,               // dead assignments
    MFdv    = 4,               // dead variables
    MFreg   = 8,               // register variables
    MFcse   = 0x10,            // global common subexpressions
    MFvbe   = 0x20,            // very busy expressions
    MFtime  = 0x40,            // favor time (speed) over space
    MFli    = 0x80,            // loop invariants
    MFliv   = 0x100,           // loop induction variables
    MFcp    = 0x200,           // copy propagation
    MFcnp   = 0x400,           // constant propagation
    MFloop  = 0x800,           // loop till no more changes
    MFtree  = 0x1000,          // optelem (tree optimization)
    MFlocal = 0x2000,          // localize expressions
    MFall   = 0xFFFF,          // do everything
};

/**********************************
 * Definition elem vector, used for reaching definitions.
 */

struct DefNode
{
    elem    *DNelem;        // pointer to definition elem
    block   *DNblock;       // pointer to block that the elem is in
};

/* Global Variables */
extern unsigned optab[];

/* Global Optimizer variables
 */
struct GlobalOptimizer
{
    mftype mfoptim;
    unsigned changes;   // # of optimizations performed

    DefNode *defnod;    // array of definition elems
    unsigned deftop;    // # of entries in defnod[]

    elem **expnod;      // array of expression elems
    unsigned exptop;    // top of expnod[]
    block **expblk;     // parallel array of block pointers

    vec_t defkill;      // vector of AEs killed by an ambiguous definition
    vec_t starkill;     // vector of AEs killed by a definition of something that somebody could be
                        // pointing to
    vec_t vptrkill;     // vector of AEs killed by an access
};

extern GlobalOptimizer go;

/* gdag.c */
void builddags();
void boolopt();
void opt_arraybounds();

/* gflow.c */
void flowrd(),flowlv(),flowae(),flowvbe(),
     flowcp(),flowae(),genkillae(),flowarraybounds();
int ae_field_affect(elem *lvalue,elem *e);

/* glocal.c */
void localize();

/* gloop.c */
int blockinit();
void compdom();
void loopopt();
void updaterd(elem *n,vec_t GEN,vec_t KILL);

/* gother.c */
void rd_arraybounds();
void rd_free();
void constprop();
void copyprop();
void rmdeadass();
void elimass(elem *);
void deadvar();
void verybusyexp();
list_t listrds(vec_t, elem *, vec_t);

/* gslice.c */
void sliceStructs();

#endif /*  GO_H */
