/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Manage the memory allocated on the runtime stack to save Common Subexpressions (CSE).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2019 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/cgcse.d, backend/cgcse.d)
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/backend/cgcse.d
 */

module dmd.backend.cgcse;

version (SCPP)
    version = COMPILE;
version (MARS)
    version = COMPILE;

version (COMPILE)
{

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.code;
import dmd.backend.code_x86;
import dmd.backend.el;
import dmd.backend.global;
import dmd.backend.ty;

import dmd.backend.barray;

extern (C++):
nothrow:

__gshared Barray!CSE csextab;     /* CSE table (allocated for each function) */

/****************************
 * Table of common subexpressions stored on the stack.
 *      csextab[]       array of info on saved CSEs
 *      CSEpe           pointer to saved elem
 *      CSEregm         mask of register that was saved (so for multi-
 *                      register variables we know which part we have)
 */

enum CSEload       = 1;       // set if the CSE was ever loaded
enum CSEsimple     = 2;       // CSE can be regenerated easily

struct CSE
{
    elem    *e;             // pointer to elem
    code    csimple;        // if CSEsimple, this is the code to regenerate it
    regm_t  regm;           // mask of register stored there
    char    flags;          // flag bytes

  __gshared:
    uint slotSize;          // size of each slot in table
    uint alignment;         // alignment for the table

  nothrow:

    /********************************
     * Update slot size and alignment to worst case.
     * A bit wasteful of stack space.
     */
    static void updateSizeAndAlign(elem* e)
    {
        if (I16)
            return;
        const sz = tysize(e.Ety);
        if (slotSize < sz)
            slotSize = sz;
        const alignsize = el_alignsize(e);

        static if (0)
        printf("set slot size = %d, sz = %d, al = %d, ty = x%x, %s\n",
            slotSize, cast(int)sz, cast(int)alignsize,
            cast(int)tybasic(e.Ety), funcsym_p.Sident.ptr);

        if (alignsize >= 16 && TARGET_STACKALIGN >= 16)
        {
            alignment = alignsize;
            STACKALIGN = alignsize;
            enforcealign = true;
        }
    }
}

// Returns: offset of slot i
uint CSE_offset(int i)
{
    return i * CSE.slotSize;
}

// Returns: true if CSE was ever loaded
bool CSE_loaded(int i)
{
    return i < csextab.length &&   // array could be shrunk for non-CSEload entries
           (csextab[i].flags & CSEload);
}

/********************
 * The above implementation of CSE is inefficient:
 * 1. the optimization to not store CSE's that are never reloaded is based on the slot number,
 * not the CSE. This means that when a slot is shared among multiple CSEs, it is treated
 * as "reloaded" even if only one of the CSEs in that slot is reloaded.
 * 2. updateSizeAndAlign should only be run when reloading when (1) is fixed.
 * 3. all slots are aligned to worst case alignment of any slot.
 * 4. unused slots still get memory allocated to them if they aren't at the end of the
 * slot table.
 *
 * The slot number should be unique to each CSE, and allocation of actual slots should be
 * done after the code is generated, not during generation.
 */


}
