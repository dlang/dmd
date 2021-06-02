/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Manage the memory allocated on the runtime stack to save Common Subexpressions (CSE).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
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
@safe:

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
    elem*   e;              // pointer to elem
    code    csimple;        // if CSEsimple, this is the code to regenerate it
    regm_t  regm;           // mask of register stored there
    int     slot;           // slot number
    ubyte   flags;          // flag bytes

  nothrow:

    /************************
     * Initialize at function entry.
     */
    @trusted
    static void initialize()
    {
        csextab.setLength(64);  // reserve some space
    }

    /************************
     * Start for generating code for this function.
     * After ending generation, call finish().
     */
    @trusted
    static void start()
    {
        csextab.setLength(0);               // no entries in table yet
        slotSize = REGSIZE;
        alignment_ = REGSIZE;
    }

    /*******************************
     * Create and add a new CSE entry.
     * Returns:
     *  pointer to created entry
     */
    @trusted
    static CSE* add()
    {
        foreach (ref cse; csextab)
        {
            if (cse.e == null)  // can share with previously used one
            {
                cse.flags &= CSEload;
                return &cse;
            }
        }

        // create new one
        const slot = cast(int)csextab.length;
        CSE cse;
        cse.slot = slot;
        csextab.push(cse);
        return &csextab[slot];
    }

    /********************************
     * Update slot size and alignment to worst case.
     *
     * A bit wasteful of stack space.
     * Params: e = elem with a size and an alignment
     */
    @trusted
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
            alignment_ = alignsize;
            STACKALIGN = alignsize;
            enforcealign = true;
        }
    }

    /****
     * Get range of all CSEs filtered by matching `e`,
     * starting with most recent.
     * Params: e = elem to match
     * Returns:
     *  input range
     */
    @trusted
    static auto filter(const elem* e)
    {
        struct Range
        {
            const elem* e;
            int i;

          nothrow:

            bool empty()
            {
                while (i)
                {
                    if (csextab[i - 1].e == e)
                        return false;
                    --i;
                }
                return true;
            }

            ref CSE front() { return csextab[i - 1]; }

            void popFront() { --i; }
        }

        return Range(e, cast(int)csextab.length);
    }

    /*********************
     * Remove instances of `e` from CSE table.
     * Params: e = elem to remove
     */
    @trusted
    static void remove(const elem* e)
    {
        foreach (ref cse; csextab[])
        {
            if (cse.e == e)
                cse.e = null;
        }
    }

    /************************
     * Create mask of registers from CSEs that refer to `e`.
     * Params: e = elem to match
     * Returns:
     *  mask
     */
    @trusted
    static regm_t mask(const elem* e)
    {
        regm_t result = 0;
        foreach (ref cse; csextab[])
        {
            if (cse.e)
                elem_debug(cse.e);
            if (cse.e == e)
                result |= cse.regm;
        }
        return result;
    }

    /***
     * Finish generating code for this function.
     *
     * Get rid of unused cse temporaries by shrinking the array.
     * References: loaded()
     */
    @trusted
    static void finish()
    {
        while (csextab.length != 0 && (csextab[csextab.length - 1].flags & CSEload) == 0)
            csextab.setLength(csextab.length - 1);
    }

    /**** The rest of the functions can be called only after finish() ****/

    /******************
     * Returns:
     *    total size used by CSE's
     */
    @trusted
    static uint size()
    {
        return cast(uint)csextab.length * CSE.slotSize;
    }

    /*********************
     * Returns:
     *  alignment needed for CSE region of the stack
     */
    @trusted
    static uint alignment()
    {
        return alignment_;
    }

    /// Returns: offset of slot i from start of CSE region
    @trusted
    static uint offset(int i)
    {
        return i * slotSize;
    }

    /// Returns: true if CSE was ever loaded
    @trusted
    static bool loaded(int i)
    {
        return i < csextab.length &&   // array could be shrunk for non-CSEload entries
               (csextab[i].flags & CSEload);
    }

  private:
  __gshared:
    Barray!CSE csextab;     // CSE table (allocated for each function)
    uint slotSize;          // size of each slot in table
    uint alignment_;        // alignment for the table
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
