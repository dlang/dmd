/**
 * Support for exception handling for EH_DM and EH_WIN32.
 * Generate exception handling tables.
 *
 * Copyright:   Copyright (C) 1994-1998 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/eh.d, _eh.d)
 * Documentation:  https://dlang.org/phobos/dmd_eh.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/eh.d
 */

module dmd.eh;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.globals;
import dmd.errors;
import dmd.target;

import dmd.root.rmem;

import dmd.backend.barray;
import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.code;
import dmd.backend.code_x86;
import dmd.backend.dt;
import dmd.backend.el;
import dmd.backend.global;
import dmd.backend.obj;
import dmd.backend.ty;
import dmd.backend.type;

extern (C++):


package(dmd) @property @nogc nothrow auto NPTRSIZE() { return _tysize[TYnptr]; }

/****************************
 * Generate and output scope table.
 */

Symbol *except_gentables()
{
    //printf("except_gentables()\n");
    if (config.ehmethod == EHmethod.EH_DM && !(funcsym_p.Sfunc.Fflags3 & Feh_none))
    {
        // BUG: alloca() changes the stack size, which is not reflected
        // in the fixed eh tables.
        if (Alloca.size)
            error(null, 0, 0, "cannot mix `core.std.stdlib.alloca()` and exception handling in `%s()`", &funcsym_p.Sident[0]);

        char[13+5+1] name = void;
        __gshared int tmpnum;
        sprintf(name.ptr,"_HandlerTable%d",tmpnum++);

        Symbol *s = symbol_name(name.ptr,SCstatic,tstypes[TYint]);
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
 *    void *finally;              // finally code to execute
 * }
 */

void except_fillInEHTable(Symbol *s)
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
        {   void *type;         // Symbol representing type
            uint bpoffset;      // EBP offset of catch variable
            void *handler;      // catch handler code
        } catch[];
     */

/* Be careful of this, as we need the sizeof Guard on the target, not
 * in the compiler.
 */
    uint GUARD_SIZE;
    if (config.ehmethod == EHmethod.EH_DM)
        GUARD_SIZE = (target.is64bit ? 3*8 : 5*4);
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
    dtb.dword(cast(int)retoffset);
    sz += 4;

    // First, calculate starting catch offset
    int guarddim = 0;                               // max dimension of guard[]
    int ndctors = 0;                                // number of ESCdctor's
    foreach (b; BlockRange(startblock))
    {
        if (b.BC == BC_try && b.Bscope_index >= guarddim)
            guarddim = b.Bscope_index + 1;
//      printf("b.BC = %2d, Bscope_index = %2d, last_index = %2d, offset = x%x\n",
//              b.BC, b.Bscope_index, b.Blast_index, b.Boffset);
        if (usednteh & EHcleanup)
            for (code *c = b.Bcode; c; c = code_next(c))
            {
                if (c.Iop == (ESCAPE | ESCddtor))
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
    foreach (b; BlockRange(startblock))
    {
        //printf("b = %p, b.Btry = %p, b.offset = %x\n", b, b.Btry, b.Boffset);
        if (b.BC == BC_try)
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
            //printf("DHandlerInfo: offset = %x", (int)(b.Boffset - startblock.Boffset));
            dtb.dword(cast(int)(b.Boffset - startblock.Boffset));    // offset to start of block

            // Compute ending offset
            uint endoffset;
            for (block *bn = b.Bnext; 1; bn = bn.Bnext)
            {
                //printf("\tbn = %p, bn.Btry = %p, bn.offset = %x\n", bn, bn.Btry, bn.Boffset);
                assert(bn);
                if (bn.Btry == b.Btry)
                {    endoffset = cast(uint)(bn.Boffset - startblock.Boffset);
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
                block *bhandler = b.nthSucc(1);
                assert(bhandler.BC == BC_finally);
                // To successor of BC_finally block
                bhandler = bhandler.nthSucc(0);
                // finally handler address
                if (config.ehmethod == EHmethod.EH_DM)
                {
                    assert(bhandler.Boffset > startblock.Boffset);
                    dtb.size(bhandler.Boffset - startblock.Boffset);    // finally handler offset
                }
                else
                    dtb.coff(cast(uint)bhandler.Boffset);
            }
            sz += GUARD_SIZE;
        }
    }

    /* Append to guard[] the guard blocks for temporaries that are created and destroyed
     * within a single expression. These are marked by the special instruction pairs
     * (ESCAPE | ESCdctor) and (ESCAPE | ESCddtor).
     */
    if (usednteh & EHcleanup)
    {
        Barray!int stack;

    int scopeindex = guarddim;
    foreach (b; BlockRange(startblock))
    {
        /* Set up stack of scope indices
         */
        stack.push(b.Btry ? b.Btry.Bscope_index : -1);

        uint boffset = cast(uint)b.Boffset;
        for (code *c = b.Bcode; c; c = code_next(c))
        {
            if (c.Iop == (ESCAPE | ESCdctor))
            {
                code *c2 = code_next(c);
                if (config.ehmethod == EHmethod.EH_WIN32)
                    nteh_patchindex(c2, scopeindex);
                if (config.ehmethod == EHmethod.EH_DM)
                    dtb.dword(cast(int)(boffset - startblock.Boffset)); // guard offset
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

                    if (c2.Iop == (ESCAPE | ESCddtor))
                    {
                        if (n)
                            n--;
                        else
                        {
                            foffset = eoffset;
                            code *cf = code_next(c2);
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
                            // issue 9438
                            //cf = code_next(cf);
                            //foffset += calccodsize(cf);
                            if (config.ehmethod == EHmethod.EH_DM)
                                dtb.dword(cast(int)(eoffset - startblock.Boffset)); // guard offset
                            break;
                        }
                    }
                    else if (c2.Iop == (ESCAPE | ESCdctor))
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
                    assert(foffset > startblock.Boffset);
                    dtb.size(foffset - startblock.Boffset);    // finally handler offset
                }
                else
                    dtb.coff(foffset);  // finally handler address
                stack.push(scopeindex);
                ++scopeindex;
                sz += GUARD_SIZE;
            }
            else if (c.Iop == (ESCAPE | ESCddtor))
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
    foreach (b; BlockRange(startblock))
    {
        if (b.BC == BC_try && b.jcatchvar)         // if try-catch
        {
            int nsucc = b.numSucc();
            dtb.size(nsucc - 1);           // # of catch blocks
            sz += NPTRSIZE;

            for (int j = 1; j < nsucc; ++j)
            {
                block *bcatch = b.nthSucc(j);

                dtb.xoff(bcatch.Bcatchtype,0,TYnptr);

                dtb.size(cod3_bpoffset(b.jcatchvar));     // EBP offset

                // catch handler address
                if (config.ehmethod == EHmethod.EH_DM)
                {
                    assert(bcatch.Boffset > startblock.Boffset);
                    dtb.size(bcatch.Boffset - startblock.Boffset);  // catch handler offset
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
