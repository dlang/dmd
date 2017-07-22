// Copyright (C) 1985-1998 by Symantec
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

#ifndef GO_H
#define GO_H 1

/***************************************
 * Bit masks for various optimizations.
 */

typedef unsigned mftype;        /* a type big enough for all the flags  */

#define MFdc    1               // dead code
#define MFda    2               // dead assignments
#define MFdv    4               // dead variables
#define MFreg   8               // register variables
#define MFcse   0x10            // global common subexpressions
#define MFvbe   0x20            // very busy expressions
#define MFtime  0x40            // favor time (speed) over space
#define MFli    0x80            // loop invariants
#define MFliv   0x100           // loop induction variables
#define MFcp    0x200           // copy propagation
#define MFcnp   0x400           // constant propagation
#define MFloop  0x800           // loop till no more changes
#define MFtree  0x1000          // optelem (tree optimization)
#define MFlocal 0x2000          // localize expressions
#define MFall   (~0)            // do everything

/**********************************
 * Definition elem vector, used for reaching definitions.
 */

typedef struct DN
    {
        elem    *DNelem;        // pointer to definition elem
        block   *DNblock;       // pointer to block that the elem is in
    } dn;

/* Global Variables */
extern unsigned optab[];
extern mftype mfoptim;
extern unsigned changes;        /* # of optimizations performed         */
extern struct DN *defnod;       /* array of definition elems            */
extern unsigned deftop;         /* # of entries in defnod[]             */
extern elem **expnod;           /* array of expression elems            */
extern unsigned exptop;         /* top of expnod[]                      */
extern block **expblk;          /* parallel array of block pointers     */
extern vec_t defkill;           /* vector of AEs killed by an ambiguous */
                                /* definition                           */
extern vec_t starkill;          /* vector of AEs killed by a definition */
                                /* of something that somebody could be  */
                                /* pointing to                          */
extern vec_t vptrkill;          /* vector of AEs killed by an access    */

/* gdag.c */
void builddags(void);
void boolopt(void);
void opt_arraybounds();

/* gflow.c */
void flowrd(),flowlv(),flowae(),flowvbe(),
     flowcp(),flowae(),genkillae(),flowarraybounds();
int ae_field_affect(elem *lvalue,elem *e);

/* glocal.c */
void localize(void);

/* gloop.c */
int blockinit(void);
void compdom(void);
void loopopt(void);
void updaterd(elem *n,vec_t GEN,vec_t KILL);

/* gother.c */
void rd_arraybounds(void);
void rd_free();
void constprop(void);
void copyprop(void);
void rmdeadass(void);
void elimass(elem *);
void deadvar(void);
void verybusyexp(void);
list_t listrds(vec_t, elem *, vec_t);

#endif /*  GO_H */
