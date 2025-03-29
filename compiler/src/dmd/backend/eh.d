/**
 * Support for exception handling for EH_DM and EH_WIN32.
 * Generate exception handling tables.
 *
 * Copyright:   Copyright (C) 1994-1998 by Symantec
 *              Copyright (C) 2000-2025 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/backend/eh.d, _eh.d)
 * Documentation:  https://dlang.org/phobos/dmd_eh.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/compiler/src/dmd/backend/eh.d
 */

module dmd.backend.eh;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.backend.barray;
import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.code;
import dmd.backend.x86.code_x86;
import dmd.backend.dt;
import dmd.backend.el;
import dmd.backend.global;
import dmd.backend.obj;
import dmd.backend.ty;
import dmd.backend.type;

nothrow:
@safe:

package(dmd) @property @nogc nothrow auto @trusted NPTRSIZE() { return _tysize[TYnptr]; }

/****************************
 * Generate and output scope table.
 */

@trusted
Symbol* except_gentables()
{
    //printf("except_gentables()\n");
    if (config.ehmethod == EHmethod.EH_DM && !(funcsym_p.Sfunc.Fflags3 & Feh_none))
    {
        // BUG: alloca() changes the stack size, which is not reflected
        // in the fixed eh tables.
        if (cgstate.Alloca.size)
            error(Srcpos.init, "cannot mix `core.std.stdlib.alloca()` and exception handling in `%s()`", &funcsym_p.Sident[0]);

        char[13+5+1] name = void;
        __gshared int tmpnum;
        const len = snprintf(name.ptr, name.length, "_HandlerTable%d", tmpnum++);

        Symbol* s = symbol_name(name[0 .. len],SC.static_,tstypes[TYint]);
        symbol_keep(s);
        //symbol_debug(s);

        except_fillInEHTable(s);

        outdata(s);                 // output the scope table

        objmod.ehtables(funcsym_p,cast(uint)funcsym_p.Ssize,s);
    }
    return null;
}

/**********************************************
 * Initializes the Symbol s with the contents of the exception handler table.
 */

/* This is what the type should be on the target machine, not the host compiler
 *
 * struct Guard
 * {
 *    if (EHmethod.EH_DM)
 *    {
 *        uint offset;            // offset of start of guarded section (Linux)
 *        uint endoffset;         // ending offset of guarded section (Linux)
 *    }
 *    int last_index;             // previous index (enclosing guarded section)
 *    uint catchoffset;           // offset to catch block from Symbol
 *    void* finally;              // finally code to execute
 * }
 */
@trusted
void except_fillInEHTable(Symbol* s)
{
    uint fsize = NPTRSIZE;             // target size of function pointer
    auto dtb = DtBuilder(0);

    /*
        void*           pointer to start of function (Windows)
        uint            offset of ESP from EBP
        uint            offset from start of function to return code
        uint nguards;           // dimension of guard[] (Linux)
        Guard guard[];          // sorted such that the enclosing guarded sections come first
      catchoffset:
        uint ncatches;          // number of catch blocks
        {   void* type;         // Symbol representing type
            uint bpoffset;      // EBP offset of catch variable
            void* handler;      // catch handler code
        } catch[];
     */

/* Be careful of this, as we need the sizeof Guard on the target, not
 * in the compiler.
 */
    uint GUARD_SIZE;
    if (config.ehmethod == EHmethod.EH_DM)
        GUARD_SIZE = (I64() ? 3*8 : 5*4);
    else if (config.ehmethod == EHmethod.EH_WIN32)
        GUARD_SIZE = 3*4;
    else
        assert(0);

    int sz = 0;

    // Address of start of function
    if (config.ehmethod == EHmethod.EH_WIN32)
    {
        //symbol_debug(funcsym_p);
        dtb.xoff(funcsym_p,0,TYnptr);
        sz += fsize;
    }

    //printf("ehtables: func = %s, offset = x%x, startblock.Boffset = x%x\n", funcsym_p.Sident, funcsym_p.Soffset, startblock.Boffset);

    // Get offset of ESP from EBP
    long spoff = cod3_spoff();
    dtb.dword(cast(int)spoff);
    sz += 4;

    // Offset from start of function to return code
    dtb.dword(cast(int)cgstate.retoffset);
    sz += 4;

    // First, calculate starting catch offset
    int guarddim = 0;                               // max dimension of guard[]
    int ndctors = 0;                                // number of PSOP.dctor's
    foreach (b; BlockRange(bo.startblock))
    {
        if (b.bc == BC._try && b.Bscope_index >= guarddim)
            guarddim = b.Bscope_index + 1;
//      printf("b.bc = %2d, Bscope_index = %2d, last_index = %2d, offset = x%x\n",
//              b.bc, b.Bscope_index, b.Blast_index, b.Boffset);
        if (cgstate.usednteh & EHcleanup)
            for (code* c = b.Bcode; c; c = code_next(c))
            {
                if (c.Iop == PSOP.ddtor)
                    ndctors++;
            }
    }
    //printf("guarddim = %d, ndctors = %d\n", guarddim, ndctors);

    if (config.ehmethod == EHmethod.EH_DM)
    {
        dtb.size(guarddim + ndctors);
        sz += NPTRSIZE;
    }

    uint catchoffset = sz + (guarddim + ndctors) * GUARD_SIZE;

    // Generate guard[]
    int i = 0;
    foreach (b; BlockRange(bo.startblock))
    {
        //printf("b = %p, b.Btry = %p, b.offset = %x\n", b, b.Btry, b.Boffset);
        if (b.bc == BC._try)
        {
            assert(b.Bscope_index >= i);
            if (i < b.Bscope_index)
            {   int fillsize = (b.Bscope_index - i) * GUARD_SIZE;
                dtb.nzeros( fillsize);
                sz += fillsize;
            }
            i = b.Bscope_index + 1;

            int nsucc = b.numSucc();

            if (config.ehmethod == EHmethod.EH_DM)
            {
            //printf("DHandlerInfo: offset = %x", cast(int)(b.Boffset - startblock.Boffset));
            dtb.dword(cast(int)(b.Boffset - bo.startblock.Boffset));    // offset to start of block

            // Compute ending offset
            uint endoffset;
            for (block* bn = b.Bnext; 1; bn = bn.Bnext)
            {
                //printf("\tbn = %p, bn.Btry = %p, bn.offset = %x\n", bn, bn.Btry, bn.Boffset);
                assert(bn);
                if (bn.Btry == b.Btry)
                {    endoffset = cast(uint)(bn.Boffset - bo.startblock.Boffset);
                     break;
                }
            }
            //printf(" endoffset = %x, prev_index = %d\n", endoffset, b.Blast_index);
            dtb.dword(endoffset);               // offset past end of guarded block
            }

            dtb.dword(b.Blast_index);          // parent index

            if (b.jcatchvar)                           // if try-catch
            {
                assert(catchoffset);
                dtb.dword(catchoffset);
                dtb.size(0);                  // no finally handler

                catchoffset += NPTRSIZE + (nsucc - 1) * (3 * NPTRSIZE);
            }
            else                                        // else try-finally
            {
                assert(nsucc == 2);
                dtb.dword(0);           // no catch offset
                block* bhandler = b.nthSucc(1);
                assert(bhandler.bc == BC._finally);
                // To successor of BC._finally block
                bhandler = bhandler.nthSucc(0);
                // finally handler address
                if (config.ehmethod == EHmethod.EH_DM)
                {
                    assert(bhandler.Boffset > bo.startblock.Boffset);
                    dtb.size(bhandler.Boffset - bo.startblock.Boffset);    // finally handler offset
                }
                else
                    dtb.coff(cast(uint)bhandler.Boffset);
            }
            sz += GUARD_SIZE;
        }
    }

    /* Append to guard[] the guard blocks for temporaries that are created and destroyed
     * within a single expression. These are marked by the special instruction pairs
     * PSOP.dctor and PSOP.ddtor.
     */
    if (cgstate.usednteh & EHcleanup)
    {
        Barray!int stack;

    int scopeindex = guarddim;
    foreach (b; BlockRange(bo.startblock))
    {
        /* Set up stack of scope indices
         */
        stack.push(b.Btry ? b.Btry.Bscope_index : -1);

        uint boffset = cast(uint)b.Boffset;
        for (code* c = b.Bcode; c; c = code_next(c))
        {
            if (c.Iop == PSOP.dctor)
            {
                code* c2 = code_next(c);
                if (config.ehmethod == EHmethod.EH_WIN32)
                    nteh_patchindex(c2, scopeindex);
                if (config.ehmethod == EHmethod.EH_DM)
                    dtb.dword(cast(int)(boffset - bo.startblock.Boffset)); // guard offset
                // Find corresponding ddtor instruction
                int n = 0;
                uint eoffset = boffset;
                uint foffset;
                for (; 1; c2 = code_next(c2))
                {
                    // https://issues.dlang.org/show_bug.cgi?id=13720
                    // optimizer might elide the corresponding ddtor
                    if (!c2)
                        goto Lnodtor;

                    if (c2.Iop == PSOP.ddtor)
                    {
                        if (n)
                            n--;
                        else
                        {
                            foffset = eoffset;
                            code* cf = code_next(c2);
                            if (config.ehmethod == EHmethod.EH_WIN32)
                            {
                                nteh_patchindex(cf, stack[stack.length - 1]);
                                foffset += calccodsize(cf);
                                cf = code_next(cf);
                            }
                            foffset += calccodsize(cf);
                            while (!cf.isJumpOP())
                            {
                                cf = code_next(cf);
                                foffset += calccodsize(cf);
                            }
                            // https://issues.dlang.org/show_bug.cgi?id=9438
                            //cf = code_next(cf);
                            //foffset += calccodsize(cf);
                            if (config.ehmethod == EHmethod.EH_DM)
                                dtb.dword(cast(int)(eoffset - bo.startblock.Boffset)); // guard offset
                            break;
                        }
                    }
                    else if (c2.Iop == PSOP.dctor)
                    {
                        n++;
                    }
                    else
                        eoffset += calccodsize(c2);
                }
                //printf("boffset = %x, eoffset = %x, foffset = %x\n", boffset, eoffset, foffset);
                dtb.dword(stack[stack.length - 1]);   // parent index
                dtb.dword(0);           // no catch offset
                if (config.ehmethod == EHmethod.EH_DM)
                {
                    assert(foffset > bo.startblock.Boffset);
                    dtb.size(foffset - bo.startblock.Boffset);    // finally handler offset
                }
                else
                    dtb.coff(foffset);  // finally handler address
                stack.push(scopeindex);
                ++scopeindex;
                sz += GUARD_SIZE;
            }
            else if (c.Iop == PSOP.ddtor)
            {
                stack.setLength(stack.length - 1);
                assert(stack.length != 0);
            }
        Lnodtor:
            boffset += calccodsize(c);
        }
    }
        stack.dtor();
    }

    // Generate catch[]
    foreach (b; BlockRange(bo.startblock))
    {
        if (b.bc == BC._try && b.jcatchvar)         // if try-catch
        {
            int nsucc = b.numSucc();
            dtb.size(nsucc - 1);           // # of catch blocks
            sz += NPTRSIZE;

            for (int j = 1; j < nsucc; ++j)
            {
                block* bcatch = b.nthSucc(j);

                dtb.xoff(bcatch.Bcatchtype,0,TYnptr);

                dtb.size(cod3_bpoffset(b.jcatchvar));     // EBP offset

                // catch handler address
                if (config.ehmethod == EHmethod.EH_DM)
                {
                    assert(bcatch.Boffset > bo.startblock.Boffset);
                    dtb.size(bcatch.Boffset - bo.startblock.Boffset);  // catch handler offset
                }
                else
                    dtb.coff(cast(uint)bcatch.Boffset);

                sz += 3 * NPTRSIZE;
            }
        }
    }
    assert(sz != 0);
    s.Sdt = dtb.finish();
}
