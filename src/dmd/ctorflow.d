/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Manage flow analysis for constructors.
 *
 * Copyright:   Copyright (C) 1999-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/ctorflow.d, _ctorflow.d)
 * Documentation:  https://dlang.org/phobos/dmd_ctorflow.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/ctorflow.d
 */

module dmd.ctorflow;

import core.stdc.stdio;

import dmd.root.rmem;

enum CSX : ushort
{
    none            = 0,
    this_ctor       = 0x01,     /// called this()
    super_ctor      = 0x02,     /// called super()
    this_           = 0x04,     /// referenced this
    super_          = 0x08,     /// referenced super
    label           = 0x10,     /// seen a label
    return_         = 0x20,     /// seen a return statement
    any_ctor        = 0x40,     /// either this() or super() was called
    halt            = 0x80,     /// assert(0)
    deprecate_18719 = 0x100,    // issue deprecation for Issue 18719 - delete when deprecation period is over
}

/***********
 * Primitive flow analysis for constructors
 */
struct CtorFlow
{
    CSX callSuper;      /// state of calling other constructors

    CSX[] fieldinit;    /// state of field initializations

    void allocFieldinit(size_t dim)
    {
        fieldinit = (cast(CSX*)mem.xcalloc(CSX.sizeof, dim))[0 .. dim];
    }

    void freeFieldinit()
    {
        if (fieldinit.ptr)
            mem.xfree(fieldinit.ptr);
        fieldinit = null;
    }

    CSX[] saveFieldInit()
    {
        CSX[] fi = null;
        if (fieldinit.length) // copy
        {
            const dim = fieldinit.length;
            fi = (cast(CSX*)mem.xmalloc(CSX.sizeof * dim))[0 .. dim];
            fi[] = fieldinit[];
        }
        return fi;
    }

    /***********************
     * Create a deep copy of `this`
     * Returns:
     *  a copy
     */
    CtorFlow clone()
    {
        return CtorFlow(callSuper, saveFieldInit());
    }

    /**********************************
     * Set CSX bits in flow analysis state
     * Params:
     *  csx = bits to set
     */
    void orCSX(CSX csx) nothrow pure
    {
        callSuper |= csx;
        foreach (ref u; fieldinit)
            u |= csx;
    }

    /******************************
     * OR CSX bits to `this`
     * Params:
     *  ctorflow = bits to OR in
     */
    void OR(const ref CtorFlow ctorflow)
    {
        callSuper |= ctorflow.callSuper;
        if (fieldinit.length && ctorflow.fieldinit.length)
        {
            assert(fieldinit.length == ctorflow.fieldinit.length);
            foreach (i, u; ctorflow.fieldinit)
                fieldinit[i] |= u;
        }
    }
}


/****************************************
 * Merge fi flow analysis results into fieldInit.
 * Params:
 *      fieldInit = the path to merge fi into
 *      fi = the other path
 * Returns:
 *      false means either fieldInit or fi skips initialization
 */
bool mergeFieldInitX(ref CSX fieldInit, const CSX fi)
{
    if (fi != fieldInit)
    {
        // Have any branches returned?
        bool aRet = (fi & CSX.return_) != 0;
        bool bRet = (fieldInit & CSX.return_) != 0;
        // Have any branches halted?
        bool aHalt = (fi & CSX.halt) != 0;
        bool bHalt = (fieldInit & CSX.halt) != 0;
        bool ok;
        if (aHalt && bHalt)
        {
            ok = true;
            fieldInit = CSX.halt;
        }
        else if (!aHalt && aRet)
        {
            ok = (fi & CSX.this_ctor);
            fieldInit = fieldInit;
        }
        else if (!bHalt && bRet)
        {
            ok = (fieldInit & CSX.this_ctor);
            fieldInit = fi;
        }
        else if (aHalt)
        {
            ok = (fieldInit & CSX.this_ctor);
            fieldInit = fieldInit;
        }
        else if (bHalt)
        {
            ok = (fi & CSX.this_ctor);
            fieldInit = fi;
        }
        else
        {
            ok = !((fieldInit ^ fi) & CSX.this_ctor);
            fieldInit |= fi;
        }
        return ok;
    }
    return true;
}

