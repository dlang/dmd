/**
 * Compiler implementation of the D programming language.
 * Implements LSDA (Language Specific Data Area) table generation
 * for Dwarf Exception Handling.
 *
 * Copyright: Copyright (c) 2015 by Digital Mars, All Rights Reserved
 * Authors: Walter Bright, http://www.digitalmars.com
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(DMDSRC backend/dwarfeh.c)
 */

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
#include        "outbuf.h"

#include        "dwarf.h"
#include        "dwarf2.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

void dwarf_addrel(int seg, targ_size_t offset, int targseg, targ_size_t val = 0);

int actionTableInsert(Outbuffer *atbuf, int ttindex, int nextoffset);

unsigned long uLEB128(unsigned char **p);
long sLEB128(unsigned char **p);
unsigned uLEB128size(int value);
unsigned sLEB128size(int value);

struct DwEhTableEntry
{
    unsigned start;
    unsigned end;       // 1 past end
    unsigned lpad;      // landing pad
    unsigned action;    // index into Action Table
    block *bcatch;      // catch block data
    int prev;           // index to enclosing entry (-1 for none)
};

struct DwEhTable
{
    DwEhTableEntry *ptr;        // pointer to table
    unsigned dim;               // current amount used
    unsigned capacity;

    DwEhTableEntry *index(unsigned i)
    {
        assert(i < dim);
        return ptr + i;
    }

    unsigned push()
    {
        assert(dim <= capacity);
        if (dim == capacity)
        {
            capacity += capacity + 16;
            ptr = (DwEhTableEntry *)::realloc(ptr, capacity * sizeof(DwEhTableEntry));
            assert(ptr);
        }
        memset(index(dim), 0, sizeof(DwEhTable));
        return dim++;
    }
};

static DwEhTable dwehtable;

/****************************
 * Generate .gcc_except_table, aka LS
 * Params:
 *      sfunc = function to generate table for
 *      seg = .gcc_except_table segment
 *      et = buffer to insert table into
 *      scancode = true if there are destructors in the code (i.e. usednteh & EHcleanup)
 */

symbol *genDwarfEh(Symbol *sfunc, int seg, Outbuffer *et, bool scancode)
{
    assert(config.ehmethod == EH_DWARF);

    /* LPstart = encoding of LPbase
     * LPbase = landing pad base (normally omitted)
     * TType = encoding of TTbase
     * TTbase = offset from next byte to past end of Type Table
     * CallSiteFormat = encoding of fields in Call Site Table
     * CallSiteTableSize = size in bytes of Call Site Table
     * Call Site Table[]:
     *    CallSiteStart
     *    CallSiteRange
     *    LandingPad
     *    ActionRecordPtr
     * Action Table
     *    TypeFilter
     *    NextRecordPtr
     * Type Table
     */

    block *startblock = sfunc->Sfunc->Fstartblock;
    //printf("genDwarfEh: func = %s, offset = x%x, startblock->Boffset = x%x\n", sfunc->Sident, sfunc->Soffset, startblock->Boffset);

    unsigned startsize = et->size();
    assert((startsize & 3) == 0);       // should be aligned

    DwEhTable *deh = &dwehtable;
    Outbuffer atbuf;
    Outbuffer cstbuf;

    /* Build deh table, and Action Table
     */
    int index = -1;
    block *bprev = NULL;
    for (block *b = startblock; b; b = b->Bnext)
    {
        if (index >= 0 && b->Btry == bprev)
        {
            DwEhTableEntry *d = deh->index(index);
            d->end = b->Boffset;
            index = d->prev;
            if (bprev)
                bprev = bprev->Btry;
        }
        if (b->BC == BC_try)
        {
            unsigned i = deh->push();
            DwEhTableEntry *d = deh->index(i);
            d->start = b->Boffset;

            block *bf = b->nthSucc(1);
            d->lpad = bf->Boffset;
            if (bf->BC == BCjcatch)
            {
                d->bcatch = bf;
                unsigned *pat = bf->BS.BIJCATCH.actionTable;
                unsigned length = pat[0];
                assert(length);
                unsigned offset = 0;
                for (unsigned u = length; u; --u)
                {
                    /* Buy doing depth-first insertion into the Action Table,
                     * we can combine common tails.
                     */
                    offset = actionTableInsert(&atbuf, pat[u], offset);
                }
                d->lpad = offset + 1;
            }
            d->prev = index;
            index = i;
            bprev = b->Btry;
        }
        if (scancode)
        {
            unsigned coffset = b->Boffset;
            int n = 0;
            for (code *c = b->Bcode; c; c = code_next(c))
            {
                if (c->Iop == (ESCAPE | ESCdctor))
                {
                    unsigned i = deh->push();
                    DwEhTableEntry *d = deh->index(i);
                    d->start = coffset;
                    d->prev = index;
                    index = i;
                    ++n;
                }

                if (c->Iop == (ESCAPE | ESCddtor))
                {
                    assert(n > 0);
                    --n;
                    DwEhTableEntry *d = deh->index(index);
                    d->end = coffset;
                    d->lpad = coffset;
                    index = d->prev;
                }
                coffset += calccodsize(c);
            }
            assert(n == 0);
        }
    }

    /* Build Call Site Table
     * Be sure to not generate empty entries,
     * and generate multiple entries for one DwEhTableEntry if the latter
     * is split by nested DwEhTableEntry's. This is based on the (undocumented)
     * presumption that there may not
     * be overlapping entries in the Call Site Table.
     */
    unsigned end = 0;
    for (unsigned i = 0; i < deh->dim; ++i)
    {
        unsigned j = i;
        do
        {
            DwEhTableEntry *d = deh->index(j);
            if (d->start <= end && end < d->end)
            {
                unsigned start = end;
                unsigned dend = d->end;
                if (j + 1 < deh->dim)
                {
                    DwEhTableEntry *dnext = deh->index(i + 1);
                    if (dnext->start < dend)
                        dend = dnext->start;
                }
                if (start < dend)
                {
                    unsigned CallSiteStart = start - startblock->Boffset;
                    cstbuf.writeuLEB128(CallSiteStart);
                    unsigned CallSiteRange = dend - start;
                    cstbuf.writeuLEB128(CallSiteRange);
                    unsigned LandingPad = d->lpad - startblock->Boffset;
                    cstbuf.writeuLEB128(LandingPad);
                    unsigned ActionTable = d->action;
                    cstbuf.writeuLEB128(ActionTable);
                }

                end = dend;
            }
        } while (j--);
    }

    /* Write LSDT header */
    const unsigned char LPstart = DW_EH_PE_omit;
    et->writeByte(LPstart);
    unsigned LPbase = 0;
    if (LPstart != DW_EH_PE_omit)
        et->writeuLEB128(LPbase);

    const unsigned char TType = DW_EH_PE_absptr | DW_EH_PE_udata4;
    et->writeByte(TType);

    /* Compute TTbase, which is the sum of:
     *  1. CallSiteFormat
     *  2. encoding of CallSiteTableSize
     *  3. Call Site Table size
     *  4. Action Table size
     *  5. 4 byte alignment
     *  6. Types Table
     * Iterate until it converges.
     */
    unsigned TTbase = 1;
    unsigned CallSiteTableSize = cstbuf.size();
    unsigned oldTTbase;
    do
    {
        oldTTbase = TTbase;
        unsigned start = (et->size() - startsize) + uLEB128size(TTbase);
        TTbase = 1 +
                uLEB128size(CallSiteTableSize) +
                CallSiteTableSize +
                atbuf.size();
        unsigned sz = start + TTbase;
        TTbase += -sz & 3;      // align to 4
        TTbase += sfunc->Sfunc->typesTableDim * 4;
    } while (TTbase != oldTTbase);

    if (TType != DW_EH_PE_omit)
        et->writeuLEB128(TTbase);
    unsigned TToffset = TTbase + et->size() - startsize;

    const unsigned char CallSiteFormat = DW_EH_PE_absptr | DW_EH_PE_uleb128;
    et->writeByte(CallSiteFormat);
    et->writeuLEB128(CallSiteTableSize);


    /* Insert Call Site Table */
    et->write(&cstbuf);

    /* Insert Action Table */
    et->write(&atbuf);

    /* Align to 4 */
    for (unsigned n = (-et->size() & 3); n; --n)
        et->writeByte(0);

    /* Write out Types Table in reverse */
    Symbol **typesTable = sfunc->Sfunc->typesTable;
    for (int i = sfunc->Sfunc->typesTableDim; i--; )
    {
        Symbol *s = typesTable[i];
        dwarf_addrel(seg, et->size(), s->Sseg, s->Soffset);
    }
    assert(TToffset == et->size() - startsize);
}


/****************************
 * Insert action (ttindex, offset) in Action Table
 * if it is not already there.
 * Params:
 *      atbuf = Action Table
 *      ttindex = Types Table index (1..)
 *      offset = offset of next action, 0 for none
 * Returns:
 *      offset of inserted action
 */
int actionTableInsert(Outbuffer *atbuf, int ttindex, int nextoffset)
{
    unsigned char *p;
    for (p = atbuf->buf; p  < atbuf->p; )
    {
        int offset = p - atbuf->buf;
        long TypeFilter = sLEB128(&p);
        int nrpoffset = p - atbuf->buf;
        long NextRecordPtr = sLEB128(&p);

        if (ttindex == TypeFilter &&
            nextoffset == nrpoffset + NextRecordPtr)
            return offset;
    }
    assert(p == atbuf->p);
    int offset = atbuf->size();
    atbuf->writesLEB128(ttindex);
    int nrpoffset = atbuf->size();
    atbuf->writesLEB128(nextoffset - nrpoffset);
    return offset;
}

/******************************
 * Decode Unsigned LEB128.
 * Params:
 *      p = pointer to data pointer, *p is updated
 *      to point past decoded value
 * Returns:
 *      decoded value
 * See_Also:
 *      https://en.wikipedia.org/wiki/LEB128
 */
unsigned long uLEB128(unsigned char **p)
{
    unsigned char *q = *p;
    unsigned long result = 0;
    unsigned shift = 0;
    while (1)
    {
        unsigned char byte = *q++;
        result |= (byte & 0x7F) << shift;
        if ((byte & 0x80) == 0)
            break;
        shift += 7;
    }
    *p = q;
    return result;
}

/******************************
 * Decode Signed LEB128.
 * Params:
 *      p = pointer to data pointer, *p is updated
 *      to point past decoded value
 * Returns:
 *      decoded value
 * See_Also:
 *      https://en.wikipedia.org/wiki/LEB128
 */
long sLEB128(unsigned char **p)
{
    unsigned char *q = *p;
    unsigned char byte;

    long result = 0;
    unsigned shift = 0;
    while (1)
    {
        byte = *q++;
        result |= (byte & 0x7F) << shift;
        shift += 7;
        if ((byte & 0x80) == 0)
            break;
    }
    if (shift < sizeof(result) * 8 && (byte & 0x40))
        result |= -(1 << shift);
    *p = q;
    return result;
}

/******************************
 * Determine size of Signed LEB128 encoded value.
 * Params:
 *      value = value to be encoded
 * Returns:
 *      length of decoded value
 * See_Also:
 *      https://en.wikipedia.org/wiki/LEB128
 */
unsigned sLEB128size(int value)
{
    unsigned size = 0;
    while (1)
    {
        ++size;
        unsigned char b = value & 0x40;

        value >>= 7;            // arithmetic right shift
        if (value == 0 && !b ||
            value == -1 && b)
        {
             break;
        }
    }
    return size;
}

/******************************
 * Determine size of Unsigned LEB128 encoded value.
 * Params:
 *      value = value to be encoded
 * Returns:
 *      length of decoded value
 * See_Also:
 *      https://en.wikipedia.org/wiki/LEB128
 */
unsigned uLEB128size(unsigned value)
{
    unsigned size = 1;
    while ((value >>= 7) != 0)
        ++size;
    return size;
}

