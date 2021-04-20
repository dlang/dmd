/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1986-1998 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     Distributed under the Boost Software License, Version 1.0.
 *              http://www.boost.org/LICENSE_1_0.txt
 * Source:      https://github.com/dlang/dmd/blob/master/src/dmd/backend/goh.d
 */

module dmd.backend.goh;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import core.stdc.time;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.oper;
import dmd.backend.global;
import dmd.backend.el;
import dmd.backend.symtab;
import dmd.backend.ty;
import dmd.backend.type;

import dmd.backend.barray;
import dmd.backend.dlist;
import dmd.backend.dvec;

extern (C++):
nothrow:
@safe:

/***************************************
 * Bit masks for various optimizations.
 */

alias mftype = uint;        /* a type big enough for all the flags  */
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
}

/**********************************
 * Definition elem vector, used for reaching definitions.
 */

struct DefNode
{
    elem    *DNelem;        // pointer to definition elem
    block   *DNblock;       // pointer to block that the elem is in
    vec_t    DNunambig;     // vector of unambiguous definitions
}

/* Global Variables */
//extern __gshared uint[] optab;

/* Global Optimizer variables
 */
struct GlobalOptimizer
{
    mftype mfoptim;
    uint changes;       // # of optimizations performed

    Barray!DefNode defnod;    // array of definition elems
    uint unambigtop;    // number of unambiguous defininitions ( <= deftop )

    Barray!(vec_base_t) dnunambig;  // pool to allocate DNunambig vectors from

    Barray!(elem*) expnod;      // array of expression elems
    uint exptop;        // top of expnod[]
    Barray!(block*) expblk;     // parallel array of block pointers

    vec_t defkill;      // vector of AEs killed by an ambiguous definition
    vec_t starkill;     // vector of AEs killed by a definition of something that somebody could be
                        // pointing to
    vec_t vptrkill;     // vector of AEs killed by an access
}

extern __gshared GlobalOptimizer go;

/* gdag.c */
void builddags();
void boolopt();
void opt_arraybounds();

/* gflow.c */
void flowrd();
void flowlv();
void flowvbe();
void flowcp();
void flowae();
void genkillae();
void flowarraybounds();
int ae_field_affect(elem *lvalue,elem *e);

/* glocal.c */
void localize();

/* gloop.c */
int blockinit();
void compdom();
void loopopt();
extern (C) void updaterd(elem *n,vec_t GEN,vec_t KILL);

/* gother.c */
void rd_arraybounds();
void rd_free();
void constprop();
void copyprop();
void rmdeadass();
void elimass(elem *);
void deadvar();
void verybusyexp();
void listrds(vec_t, elem *, vec_t, Barray!(elem*)*);

/* gslice.c */
void sliceStructs(ref symtab_t symtab, block* startblock);

