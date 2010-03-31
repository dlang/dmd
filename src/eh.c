//_ eh.c
// Copyright (c) 2000-2009 by Digital Mars, http://www.digitalmars.com
// All Rights Reserved
// Written by Walter Bright
// Support for D exception handling

#include        <stdio.h>
#include        <string.h>
#include        <time.h>

#include        "cc.h"
#include        "el.h"
#include        "code.h"
#include        "oper.h"
#include        "global.h"
#include        "type.h"
#include        "dt.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

/****************************
 * Generate and output scope table.
 */

symbol *except_gentables()
{
    //printf("except_gentables()\n");
#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_SOLARIS
    symbol *s;
    int sz;                     // size so far
    dt_t **pdt;
    unsigned fsize;             // target size of function pointer
    long spoff;
    block *b;
    int guarddim;
    int i;

    // BUG: alloca() changes the stack size, which is not reflected
    // in the fixed eh tables.
    assert(!usedalloca);

    s = symbol_generate(SCstatic,tsint);
    s->Sseg = UNKNOWN;
    symbol_keep(s);
    symbol_debug(s);

    fsize = 4;
    pdt = &s->Sdt;
    sz = 0;

    /*
        void*           pointer to start of function
        unsigned        offset of ESP from EBP
        unsigned        offset from start of function to return code
        unsigned nguards;       // dimension of guard[]
        {   unsigned offset;    // offset of start of guarded section
            unsigned endoffset; // ending offset of guarded section
            int last_index;     // previous index (enclosing guarded section)
            unsigned catchoffset;       // offset to catch block from symbol
            void *finally;      // finally code to execute
        } guard[];
      catchoffset:
        unsigned ncatches;      // number of catch blocks
        {   void *type;         // symbol representing type
            unsigned bpoffset;  // EBP offset of catch variable
            void *handler;      // catch handler code
        } catch[];
     */
#define GUARD_SIZE      5       // number of 4 byte values in one guard

    sz = 0;

    // Address of start of function
    symbol_debug(funcsym_p);
    pdt = dtxoff(pdt,funcsym_p,0,TYnptr);
    sz += fsize;

    //printf("ehtables: func = %s, offset = x%x, startblock->Boffset = x%x\n", funcsym_p->Sident, funcsym_p->Soffset, startblock->Boffset);

    // Get offset of ESP from EBP
    spoff = cod3_spoff();
    pdt = dtdword(pdt,spoff);
    sz += 4;

    // Offset from start of function to return code
    pdt = dtdword(pdt,retoffset);
    sz += 4;

    // First, calculate starting catch offset
    guarddim = 0;                               // max dimension of guard[]
    for (b = startblock; b; b = b->Bnext)
    {
        if (b->BC == BC_try && b->Bscope_index >= guarddim)
            guarddim = b->Bscope_index + 1;
//      printf("b->BC = %2d, Bscope_index = %2d, last_index = %2d, offset = x%x\n",
//              b->BC, b->Bscope_index, b->Blast_index, b->Boffset);
    }

    pdt = dtdword(pdt,guarddim);
    sz += 4;

    unsigned catchoffset = sz + guarddim * (GUARD_SIZE * 4);

    // Generate guard[]
    i = 0;
    for (b = startblock; b; b = b->Bnext)
    {
        //printf("b = %p, b->Btry = %p, b->offset = %x\n", b, b->Btry, b->Boffset);
        if (b->BC == BC_try)
        {   dt_t *dt;
            block *bhandler;
            int nsucc;
            unsigned endoffset;
            block *bn;

            assert(b->Bscope_index >= i);
            if (i < b->Bscope_index)
            {   int fillsize = (b->Bscope_index - i) * (GUARD_SIZE * 4);
                pdt = dtnzeros(pdt, fillsize);
                sz += fillsize;
            }
            i = b->Bscope_index + 1;

            nsucc = list_nitems(b->Bsucc);
            pdt = dtdword(pdt,b->Boffset - startblock->Boffset);        // offset to start of block

            // Compute ending offset
            for (bn = b->Bnext; 1; bn = bn->Bnext)
            {
                //printf("\tbn = %p, bn->Btry = %p, bn->offset = %x\n", bn, bn->Btry, bn->Boffset);
                assert(bn);
                if (bn->Btry == b->Btry)
                {    endoffset = bn->Boffset - startblock->Boffset;
                     break;
                }
            }
            pdt = dtdword(pdt,endoffset);               // offset past end of guarded block

            pdt = dtdword(pdt,b->Blast_index);          // parent index

            if (b->jcatchvar)                           // if try-catch
            {
                pdt = dtdword(pdt,catchoffset);
                pdt = dtdword(pdt,0);                   // no finally handler

                catchoffset += 4 + (nsucc - 1) * (3 * 4);
            }
            else                                        // else try-finally
            {
                assert(nsucc == 2);
                pdt = dtdword(pdt,0);           // no catch offset
                bhandler = list_block(list_next(b->Bsucc));
                assert(bhandler->BC == BC_finally);
                // To successor of BC_finally block
                bhandler = list_block(bhandler->Bsucc);
                pdt = dtxoff(pdt,funcsym_p,bhandler->Boffset - startblock->Boffset, TYnptr);    // finally handler address
                //pdt = dtcoff(pdt,bhandler->Boffset);  // finally handler address
            }
            sz += GUARD_SIZE + 4;
        }
    }

    // Generate catch[]
    for (b = startblock; b; b = b->Bnext)
    {
        if (b->BC == BC_try)
        {   block *bhandler;
            int nsucc;

            if (b->jcatchvar)                           // if try-catch
            {   list_t bl;

                nsucc = list_nitems(b->Bsucc);
                pdt = dtdword(pdt,nsucc - 1);           // # of catch blocks
                sz += 4;

                for (bl = list_next(b->Bsucc); bl; bl = list_next(bl))
                {
                    block *bcatch = list_block(bl);

                    pdt = dtxoff(pdt,bcatch->Bcatchtype,0,TYjhandle);

                    pdt = dtdword(pdt,cod3_bpoffset(b->jcatchvar));     // EBP offset

                    pdt = dtxoff(pdt,funcsym_p,bcatch->Boffset - startblock->Boffset, TYnptr);  // catch handler address
                    //pdt = dtcoff(pdt,bcatch->Boffset);        // catch handler address

                    sz += 3 * 4;
                }
            }
        }
    }
    assert(sz != 0);

    outdata(s);                 // output the scope table

    obj_ehtables(funcsym_p,funcsym_p->Ssize,s);
#endif
    return NULL;
}
