/*
 * Copyright (c) 1994-1998 by Symantec
 * Copyright (c) 2000-2013 by Digital Mars
 * All Rights Reserved
 * http://www.digitalmars.com
 * Written by Walter Bright
 *
 * This source file is made available for personal use
 * only. The license is in backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */

// Support for D exception handling

#include        <stdio.h>
#include        <string.h>
#include        <stdlib.h>
#include        <time.h>

#include        "cc.h"
#include        "el.h"
#include        "code.h"
#include        "oper.h"
#include        "global.h"
#include        "type.h"
#include        "dt.h"
#include        "exh.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

/* If we do our own EH tables and stack walking scheme
 * (Otherwise use NT Structured Exception Handling)
 */
#if (TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS)
#define OUREH 1
#elif TARGET_WINDOS
#define OUREH I64
#else
#error fix
#endif

extern void error(const char *filename, unsigned linnum, unsigned charnum, const char *format, ...);

/****************************
 * Generate and output scope table.
 */

symbol *except_gentables()
{
    //printf("except_gentables()\n");
    if (OUREH)
    {
        // BUG: alloca() changes the stack size, which is not reflected
        // in the fixed eh tables.
        if (usedalloca)
            error(NULL, 0, 0, "cannot mix core.std.stdlib.alloca() and exception handling in %s()", funcsym_p->Sident);

        char name[13+5+1];
        static int tmpnum;
        sprintf(name,"_HandlerTable%d",tmpnum++);

        symbol *s = symbol_name(name,SCstatic,tsint);
        symbol_keep(s);
        symbol_debug(s);

        except_fillInEHTable(s);

        outdata(s);                 // output the scope table

        objmod->ehtables(funcsym_p,funcsym_p->Ssize,s);
    }
    return NULL;
}

/**********************************************
 * Initializes the symbol s with the contents of the exception handler table.
 */

/* This is what the type should be on the target machine, not the host compiler
 *
 * struct Guard
 * {
 *    if (OUREH)
 *    {
 *        unsigned offset;        // offset of start of guarded section (Linux)
 *        unsigned endoffset;     // ending offset of guarded section (Linux)
 *    }
 *    int last_index;             // previous index (enclosing guarded section)
 *    unsigned catchoffset;       // offset to catch block from symbol
 *    void *finally;              // finally code to execute
 * }
 */

void except_fillInEHTable(symbol *s)
{
    unsigned fsize = NPTRSIZE;             // target size of function pointer
    dt_t **pdt = &s->Sdt;

    /*
        void*           pointer to start of function (Windows)
        unsigned        offset of ESP from EBP
        unsigned        offset from start of function to return code
        unsigned nguards;       // dimension of guard[] (Linux)
        Guard guard[];          // sorted such that the enclosing guarded sections come first
      catchoffset:
        unsigned ncatches;      // number of catch blocks
        {   void *type;         // symbol representing type
            unsigned bpoffset;  // EBP offset of catch variable
            void *handler;      // catch handler code
        } catch[];
     */

/* Be careful of this, as we need the sizeof Guard on the target, not
 * in the compiler.
 */
    unsigned GUARD_SIZE;
    if (OUREH)
        GUARD_SIZE = (I64 ? 3*8 : 5*4);
    else
        GUARD_SIZE = 3*4;

    int sz = 0;

    // Address of start of function
    if (OUREH)
    {
    }
    else
    {
        symbol_debug(funcsym_p);
        pdt = dtxoff(pdt,funcsym_p,0,TYnptr);
        sz += fsize;
    }

    //printf("ehtables: func = %s, offset = x%x, startblock->Boffset = x%x\n", funcsym_p->Sident, funcsym_p->Soffset, startblock->Boffset);

    // Get offset of ESP from EBP
    long spoff = cod3_spoff();
    pdt = dtdword(pdt,spoff);
    sz += 4;

    // Offset from start of function to return code
    pdt = dtdword(pdt,retoffset);
    sz += 4;

    // First, calculate starting catch offset
    int guarddim = 0;                               // max dimension of guard[]
    int ndctors = 0;                                // number of ESCdctor's
    for (block *b = startblock; b; b = b->Bnext)
    {
        if (b->BC == BC_try && b->Bscope_index >= guarddim)
            guarddim = b->Bscope_index + 1;
//      printf("b->BC = %2d, Bscope_index = %2d, last_index = %2d, offset = x%x\n",
//              b->BC, b->Bscope_index, b->Blast_index, b->Boffset);
        if (usednteh & EHcleanup)
            for (code *c = b->Bcode; c; c = code_next(c))
            {
                if (c->Iop == (ESCAPE | ESCddtor))
                    ndctors++;
            }
    }
    //printf("guarddim = %d, ndctors = %d\n", guarddim, ndctors);

    if (OUREH)
    {   pdt = dtsize_t(pdt,guarddim + ndctors);
    sz += NPTRSIZE;
    }

    unsigned catchoffset = sz + (guarddim + ndctors) * GUARD_SIZE;

    // Generate guard[]
    int i = 0;
    for (block *b = startblock; b; b = b->Bnext)
    {
        //printf("b = %p, b->Btry = %p, b->offset = %x\n", b, b->Btry, b->Boffset);
        if (b->BC == BC_try)
        {
            assert(b->Bscope_index >= i);
            if (i < b->Bscope_index)
            {   int fillsize = (b->Bscope_index - i) * GUARD_SIZE;
                pdt = dtnzeros(pdt, fillsize);
                sz += fillsize;
            }
            i = b->Bscope_index + 1;

            int nsucc = b->numSucc();

            if (OUREH)
            {
            //printf("DHandlerInfo: offset = %x", (int)(b->Boffset - startblock->Boffset));
            pdt = dtdword(pdt,b->Boffset - startblock->Boffset);        // offset to start of block

            // Compute ending offset
            unsigned endoffset;
            for (block *bn = b->Bnext; 1; bn = bn->Bnext)
            {
                //printf("\tbn = %p, bn->Btry = %p, bn->offset = %x\n", bn, bn->Btry, bn->Boffset);
                assert(bn);
                if (bn->Btry == b->Btry)
                {    endoffset = bn->Boffset - startblock->Boffset;
                     break;
                }
            }
            //printf(" endoffset = %x, prev_index = %d\n", endoffset, b->Blast_index);
            pdt = dtdword(pdt,endoffset);               // offset past end of guarded block
            }

            pdt = dtdword(pdt,b->Blast_index);          // parent index

            if (b->jcatchvar)                           // if try-catch
            {
                assert(catchoffset);
                pdt = dtdword(pdt,catchoffset);
                pdt = dtsize_t(pdt,0);                  // no finally handler

                catchoffset += NPTRSIZE + (nsucc - 1) * (3 * NPTRSIZE);
            }
            else                                        // else try-finally
            {
                assert(nsucc == 2);
                pdt = dtdword(pdt,0);           // no catch offset
                block *bhandler = b->nthSucc(1);
                assert(bhandler->BC == BC_finally);
                // To successor of BC_finally block
                bhandler = bhandler->nthSucc(0);
                // finally handler address
                if (OUREH)
                {
                    assert(bhandler->Boffset > startblock->Boffset);
                    pdt = dtsize_t(pdt,bhandler->Boffset - startblock->Boffset);    // finally handler offset
                }
                else
                    pdt = dtcoff(pdt,bhandler->Boffset);
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
        #define STACKINC 16
        int stackbuf[STACKINC];
        int *stack = stackbuf;
        int stackmax = STACKINC;

    int scopeindex = guarddim;
    for (block *b = startblock; b; b = b->Bnext)
    {
        /* Set up stack of scope indices
         */
        stack[0] = b->Btry ? b->Btry->Bscope_index : -1;
        int stacki = 1;

        unsigned boffset = b->Boffset;
        for (code *c = b->Bcode; c; c = code_next(c))
        {
            if (c->Iop == (ESCAPE | ESCdctor))
            {
                code *c2 = code_next(c);
                if (config.flags2 & CFG2seh)
                    nteh_patchindex(c2, scopeindex);
                if (OUREH)
                    pdt = dtdword(pdt,boffset - startblock->Boffset); // guard offset
                // Find corresponding ddtor instruction
                int n = 0;
                unsigned eoffset = boffset;
                unsigned foffset;
                for (; 1; c2 = code_next(c2))
                {
                    // Bugzilla 13720: optimizer might elide the corresponding ddtor
                    if (!c2)
                        goto Lnodtor;

                    if (c2->Iop == (ESCAPE | ESCddtor))
                    {
                        if (n)
                            n--;
                        else
                        {
                            foffset = eoffset;
                            code *cf = code_next(c2);
                            if (config.flags2 & CFG2seh)
                            {
                                nteh_patchindex(cf, stack[stacki - 1]);
                                foffset += calccodsize(cf);
                                cf = code_next(cf);
                            }
                            foffset += calccodsize(cf);
                            while (!cf->isJumpOP())
                            {
                                cf = code_next(cf);
                                foffset += calccodsize(cf);
                            }
                            // issue 9438
                            //cf = code_next(cf);
                            //foffset += calccodsize(cf);
                            if (OUREH)
                                pdt = dtdword(pdt,eoffset - startblock->Boffset); // guard offset
                            break;
                        }
                    }
                    else if (c2->Iop == (ESCAPE | ESCdctor))
                    {
                        n++;
                    }
                    else
                        eoffset += calccodsize(c2);
                }
                //printf("boffset = %x, eoffset = %x, foffset = %x\n", boffset, eoffset, foffset);
                pdt = dtdword(pdt,stack[stacki - 1]);   // parent index
                pdt = dtdword(pdt,0);           // no catch offset
                if (OUREH)
                {
                    assert(foffset > startblock->Boffset);
                    pdt = dtsize_t(pdt,foffset - startblock->Boffset);    // finally handler offset
                }
                else
                    pdt = dtcoff(pdt,foffset);  // finally handler address
                if (stacki == stackmax)
                {   // stack[] is out of space; enlarge it
                    int *pi = (int *)malloc((stackmax + STACKINC) * sizeof(int));
                    assert(pi);
                    memcpy(pi, stack, stackmax * sizeof(int));
                    if (stack != stackbuf)
                        free(stack);
                    stack = pi;
                    stackmax += STACKINC;
                }
                stack[stacki++] = scopeindex;
                ++scopeindex;
                sz += GUARD_SIZE;
            }
            else if (c->Iop == (ESCAPE | ESCddtor))
            {
                stacki--;
                assert(stacki != 0);
            }
        Lnodtor:
            boffset += calccodsize(c);
        }
    }
        if (stack != stackbuf)
            free(stack);
    }

    // Generate catch[]
    for (block *b = startblock; b; b = b->Bnext)
    {
        if (b->BC == BC_try && b->jcatchvar)         // if try-catch
        {
            int nsucc = b->numSucc();
            pdt = dtsize_t(pdt,nsucc - 1);           // # of catch blocks
            sz += NPTRSIZE;

            for (int i = 1; i < nsucc; ++i)
            {
                block *bcatch = b->nthSucc(i);

                pdt = dtxoff(pdt,bcatch->Bcatchtype,0,TYjhandle);

                pdt = dtsize_t(pdt,cod3_bpoffset(b->jcatchvar));     // EBP offset

                // catch handler address
                if (OUREH)
                {
                    assert(bcatch->Boffset > startblock->Boffset);
                    pdt = dtsize_t(pdt,bcatch->Boffset - startblock->Boffset);  // catch handler offset
                }
                else
                    pdt = dtcoff(pdt,bcatch->Boffset);

                sz += 3 * NPTRSIZE;
            }
        }
    }
    assert(sz != 0);
}

