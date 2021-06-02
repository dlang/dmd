/**
 * Compiler implementation of the D programming language.
 * Implements LSDA (Language Specific Data Area) table generation
 * for Dwarf Exception Handling.
 *
 * Copyright: Copyright (C) 2015-2021 by The D Language Foundation, All Rights Reserved
 * Authors: Walter Bright, http://www.digitalmars.com
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:    $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/dwarfeh.d, backend/dwarfeh.d)
 */

module dmd.backend.dwarfeh;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.code;
import dmd.backend.code_x86;
import dmd.backend.outbuf;

import dmd.backend.dwarf;
import dmd.backend.dwarf2;

extern (C++):

nothrow:

struct DwEhTableEntry
{
    uint start;
    uint end;           // 1 past end
    uint lpad;          // landing pad
    uint action;        // index into Action Table
    block *bcatch;      // catch block data
    int prev;           // index to enclosing entry (-1 for none)
}

struct DwEhTable
{
nothrow:
    DwEhTableEntry *ptr;    // pointer to table
    uint dim;               // current amount used
    uint capacity;

    DwEhTableEntry *index(uint i)
    {
        if (i >= dim) printf("i = %d dim = %d\n", i, dim);
        assert(i < dim);
        return ptr + i;
    }

    uint push()
    {
        assert(dim <= capacity);
        if (dim == capacity)
        {
            capacity += capacity + 16;
            ptr = cast(DwEhTableEntry *)realloc(ptr, capacity * DwEhTableEntry.sizeof);
            assert(ptr);
        }
        memset(ptr + dim, 0, DwEhTableEntry.sizeof);
        return dim++;
    }
}

private __gshared DwEhTable dwehtable;

/****************************
 * Generate .gcc_except_table, aka LS
 * Params:
 *      sfunc = function to generate table for
 *      seg = .gcc_except_table segment
 *      et = buffer to insert table into
 *      scancode = true if there are destructors in the code (i.e. usednteh & EHcleanup)
 *      startoffset = size of function prolog
 *      retoffset = offset from start of function to epilog
 */

void genDwarfEh(Funcsym *sfunc, int seg, Outbuffer *et, bool scancode, uint startoffset, uint retoffset)
{
    debug
    unittest_dwarfeh();

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

    et.reserve(100);
    block *startblock = sfunc.Sfunc.Fstartblock;
    //printf("genDwarfEh: func = %s, offset = x%x, startblock.Boffset = x%x, scancode = %d startoffset=x%x, retoffset=x%x\n",
      //sfunc.Sident.ptr, cast(int)sfunc.Soffset, cast(int)startblock.Boffset, scancode, startoffset, retoffset);

static if (0)
{
    printf("------- before ----------\n");
    for (block *b = startblock; b; b = b.Bnext) WRblock(b);
    printf("-------------------------\n");
}

    uint startsize = cast(uint)et.length();
    assert((startsize & 3) == 0);       // should be aligned

    DwEhTable *deh = &dwehtable;
    deh.dim = 0;
    Outbuffer atbuf;
    Outbuffer cstbuf;

    /* Build deh table, and Action Table
     */
    int index = -1;
    block *bprev = null;
    // The first entry encompasses the entire function
    {
        uint i = deh.push();
        DwEhTableEntry *d = deh.index(i);
        d.start = cast(uint)(startblock.Boffset + startoffset);
        d.end = cast(uint)(startblock.Boffset + retoffset);
        d.lpad = 0;                    // no cleanup, no catches
        index = i;
    }
    for (block *b = startblock; b; b = b.Bnext)
    {
        if (index > 0 && b.Btry == bprev)
        {
            DwEhTableEntry *d = deh.index(index);
            d.end = cast(uint)b.Boffset;
            index = d.prev;
            if (bprev)
                bprev = bprev.Btry;
        }
        if (b.BC == BC_try)
        {
            uint i = deh.push();
            DwEhTableEntry *d = deh.index(i);
            d.start = cast(uint)b.Boffset;

            block *bf = b.nthSucc(1);
            if (bf.BC == BCjcatch)
            {
                d.lpad = cast(uint)bf.Boffset;
                d.bcatch = bf;
                uint *pat = bf.actionTable;
                uint length = pat[0];
                assert(length);
                uint offset = -1;
                for (uint u = length; u; --u)
                {
                    /* Buy doing depth-first insertion into the Action Table,
                     * we can combine common tails.
                     */
                    offset = actionTableInsert(&atbuf, pat[u], offset);
                }
                d.action = offset + 1;
            }
            else
                d.lpad = cast(uint)bf.nthSucc(0).Boffset;
            d.prev = index;
            index = i;
            bprev = b.Btry;
        }
        if (scancode)
        {
            uint coffset = cast(uint)b.Boffset;
            int n = 0;
            for (code *c = b.Bcode; c; c = code_next(c))
            {
                if (c.Iop == (ESCAPE | ESCdctor))
                {
                    uint i = deh.push();
                    DwEhTableEntry *d = deh.index(i);
                    d.start = coffset;
                    d.prev = index;
                    index = i;
                    ++n;
                }

                if (c.Iop == (ESCAPE | ESCddtor))
                {
                    assert(n > 0);
                    --n;
                    DwEhTableEntry *d = deh.index(index);
                    d.end = coffset;
                    d.lpad = coffset;
                    index = d.prev;
                }
                coffset += calccodsize(c);
            }
            assert(n == 0);
        }
    }
    //printf("deh.dim = %d\n", (int)deh.dim);

static if (1)
{
    /* Build Call Site Table
     * Be sure to not generate empty entries,
     * and generate nested ranges reflecting the layout in the code.
     */
    assert(deh.dim);
    uint end = deh.index(0).start;
    for (uint i = 0; i < deh.dim; ++i)
    {
        DwEhTableEntry *d = deh.index(i);
        if (d.start < d.end)
        {
                void WRITE(uint v)
                {
                    if (config.objfmt == OBJ_ELF)
                        cstbuf.writeuLEB128(v);
                    else
                        cstbuf.write32(v);
                }

                uint CallSiteStart = cast(uint)(d.start - startblock.Boffset);
                WRITE(CallSiteStart);
                uint CallSiteRange = d.end - d.start;
                WRITE(CallSiteRange);
                uint LandingPad = cast(uint)(d.lpad ? d.lpad - startblock.Boffset : 0);
                WRITE(LandingPad);
                uint ActionTable = d.action;
                cstbuf.writeuLEB128(ActionTable);
                //printf("\t%x %x %x %x\n", CallSiteStart, CallSiteRange, LandingPad, ActionTable);
        }
    }
}
else
{
    /* Build Call Site Table
     * Be sure to not generate empty entries,
     * and generate multiple entries for one DwEhTableEntry if the latter
     * is split by nested DwEhTableEntry's. This is based on the (undocumented)
     * presumption that there may not
     * be overlapping entries in the Call Site Table.
     */
    assert(deh.dim);
    uint end = deh.index(0).start;
    for (uint i = 0; i < deh.dim; ++i)
    {
        uint j = i;
        do
        {
            DwEhTableEntry *d = deh.index(j);
            //printf(" [%d] start=%x end=%x lpad=%x action=%x bcatch=%p prev=%d\n",
            //  j, d.start, d.end, d.lpad, d.action, d.bcatch, d.prev);
            if (d.start <= end && end < d.end)
            {
                uint start = end;
                uint dend = d.end;
                if (i + 1 < deh.dim)
                {
                    DwEhTableEntry *dnext = deh.index(i + 1);
                    if (dnext.start < dend)
                        dend = dnext.start;
                }
                if (start < dend)
                {
                    void writeCallSite(void delegate(uint) WRITE)
                    {
                        uint CallSiteStart = start - startblock.Boffset;
                        WRITE(CallSiteStart);
                        uint CallSiteRange = dend - start;
                        WRITE(CallSiteRange);
                        uint LandingPad = d.lpad - startblock.Boffset;
                        cstbuf.WRITE(LandingPad);
                        uint ActionTable = d.action;
                        WRITE(ActionTable);
                        //printf("\t%x %x %x %x\n", CallSiteStart, CallSiteRange, LandingPad, ActionTable);
                    }

                    if (config.objfmt == OBJ_ELF)
                        writeCallSite((uint a) => cstbuf.writeLEB128(a));
                    else if (config.objfmt == OBJ_MACH)
                        writeCallSite((uint a) => cstbuf.write32(a));
                    else
                        assert(0);
                }

                end = dend;
            }
        } while (j--);
    }
}

    /* Write LSDT header */
    const ubyte LPstart = DW_EH_PE_omit;
    et.writeByte(LPstart);
    uint LPbase = 0;
    if (LPstart != DW_EH_PE_omit)
        et.writeuLEB128(LPbase);

    const ubyte TType = (config.flags3 & CFG3pic)
                                ? DW_EH_PE_indirect | DW_EH_PE_pcrel | DW_EH_PE_sdata4
                                : DW_EH_PE_absptr | DW_EH_PE_udata4;
    et.writeByte(TType);

    /* Compute TTbase, which is the sum of:
     *  1. CallSiteFormat
     *  2. encoding of CallSiteTableSize
     *  3. Call Site Table size
     *  4. Action Table size
     *  5. 4 byte alignment
     *  6. Types Table
     * Iterate until it converges.
     */
    uint TTbase = 1;
    uint CallSiteTableSize = cast(uint)cstbuf.length();
    uint oldTTbase;
    do
    {
        oldTTbase = TTbase;
        uint start = cast(uint)((et.length() - startsize) + uLEB128size(TTbase));
        TTbase = cast(uint)(
                1 +
                uLEB128size(CallSiteTableSize) +
                CallSiteTableSize +
                atbuf.length());
        uint sz = start + TTbase;
        TTbase += -sz & 3;      // align to 4
        TTbase += sfunc.Sfunc.typesTable.length * 4;
    } while (TTbase != oldTTbase);

    if (TType != DW_EH_PE_omit)
        et.writeuLEB128(TTbase);
    uint TToffset = cast(uint)(TTbase + et.length() - startsize);

    ubyte CallSiteFormat = 0;
    if (config.objfmt == OBJ_ELF)
        CallSiteFormat = DW_EH_PE_absptr | DW_EH_PE_uleb128;
    else if (config.objfmt == OBJ_MACH)
        CallSiteFormat = DW_EH_PE_absptr | DW_EH_PE_udata4;

    et.writeByte(CallSiteFormat);
    et.writeuLEB128(CallSiteTableSize);


    /* Insert Call Site Table */
    et.write(cstbuf[]);

    /* Insert Action Table */
    et.write(atbuf[]);

    /* Align to 4 */
    for (uint n = (-et.length() & 3); n; --n)
        et.writeByte(0);

    /* Write out Types Table in reverse */
    auto typesTable = sfunc.Sfunc.typesTable[];
    for (int i = cast(int)typesTable.length; i--; )
    {
        Symbol *s = typesTable[i];
        /* MACHOBJ 64: pcrel 1 length 1 extern 1 RELOC_GOT
         *         32: [0] address x004c pcrel 0 length 2 value x224 type 4 RELOC_LOCAL_SECTDIFF
         *             [1] address x0000 pcrel 0 length 2 value x160 type 1 RELOC_PAIR
         */

        if (config.objfmt == OBJ_ELF)
            elf_dwarf_reftoident(seg, et.length(), s, 0);
        else if (config.objfmt == OBJ_MACH)
            mach_dwarf_reftoident(seg, et.length(), s, 0);
    }
    assert(TToffset == et.length() - startsize);
}


/****************************
 * Insert action (ttindex, offset) in Action Table
 * if it is not already there.
 * Params:
 *      atbuf = Action Table
 *      ttindex = Types Table index (1..)
 *      offset = offset of next action, -1 for none
 * Returns:
 *      offset of inserted action
 */
int actionTableInsert(Outbuffer *atbuf, int ttindex, int nextoffset)
{
    //printf("actionTableInsert(%d, %d)\n", ttindex, nextoffset);
    const(ubyte)[] p = (*atbuf)[];
    while (p.length)
    {
        int offset = cast(int) (atbuf.length - p.length);
        int TypeFilter = sLEB128(p);
        int nrpoffset = cast(int) (atbuf.length - p.length);
        int NextRecordPtr = sLEB128(p);

        if (ttindex == TypeFilter &&
            nextoffset == nrpoffset + NextRecordPtr)
            return offset;
    }
    int offset = cast(int)atbuf.length();
    atbuf.writesLEB128(ttindex);
    if (nextoffset == -1)
        nextoffset = 0;
    else
        nextoffset -= atbuf.length();
    atbuf.writesLEB128(nextoffset);
    return offset;
}

debug
void unittest_actionTableInsert()
{
    Outbuffer atbuf;
    static immutable int[3] tt1 = [ 1,2,3 ];
    static immutable int[1] tt2 = [ 2 ];

    int offset = -1;
    for (size_t i = tt1.length; i--; )
    {
        offset = actionTableInsert(&atbuf, tt1[i], offset);
    }
    offset = -1;
    for (size_t i = tt2.length; i--; )
    {
        offset = actionTableInsert(&atbuf, tt2[i], offset);
    }

    static immutable ubyte[8] result = [ 3,0,2,0x7D,1,0x7D,2,0 ];
    //for (int i = 0; i < atbuf.length(); ++i) printf(" %02x\n", atbuf.buf[i]);
    assert(result.sizeof == atbuf.length());
    int r = memcmp(result.ptr, atbuf.buf, atbuf.length());
    assert(r == 0);
}


/**
 * Consumes and decode an unsigned LEB128.
 *
 * Params:
 *     data = reference to a slice holding the LEB128 to decode.
 *            When this function return, the slice will point past the LEB128.
 *
 * Returns:
 *      decoded value
 *
 * See_Also:
 *      https://en.wikipedia.org/wiki/LEB128
 */
private extern(D) uint uLEB128(ref const(ubyte)[] data)
{
    const(ubyte)* q = data.ptr;
    uint result = 0;
    uint shift = 0;
    while (1)
    {
        ubyte byte_ = *q++;
        result |= (byte_ & 0x7F) << shift;
        if ((byte_ & 0x80) == 0)
            break;
        shift += 7;
    }
    data = data[q - data.ptr .. $];
    return result;
}

/**
 * Consumes and decode a signed LEB128.
 *
 * Params:
 *     data = reference to a slice holding the LEB128 to decode.
 *            When this function return, the slice will point past the LEB128.
 *
 * Returns:
 *      decoded value
 *
 * See_Also:
 *      https://en.wikipedia.org/wiki/LEB128
 */
private extern(D) int sLEB128(ref const(ubyte)[] data)
{
    const(ubyte)* q = data.ptr;
    ubyte byte_;

    int result = 0;
    uint shift = 0;
    while (1)
    {
        byte_ = *q++;
        result |= (byte_ & 0x7F) << shift;
        shift += 7;
        if ((byte_ & 0x80) == 0)
            break;
    }
    if (shift < result.sizeof * 8 && (byte_ & 0x40))
        result |= -(1 << shift);
    data = data[q - data.ptr .. $];
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
uint sLEB128size(int value)
{
    uint size = 0;
    while (1)
    {
        ++size;
        ubyte b = value & 0x40;

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
uint uLEB128size(uint value)
{
    uint size = 1;
    while ((value >>= 7) != 0)
        ++size;
    return size;
}

debug
void unittest_LEB128()
{
    Outbuffer buf;

    static immutable int[16] values =
    [
         0,  1,  2,  3,  300,  4000,  50_000,  600_000,
        -0, -1, -2, -3, -300, -4000, -50_000, -600_000,
    ];

    for (size_t i = 0; i < values.length; ++i)
    {
        const int value = values[i];

        buf.reset();
        buf.writeuLEB128(value);
        assert(buf.length() == uLEB128size(value));
        const(ubyte)[] p = buf[];
        int result = uLEB128(p);
        assert(!p.length);
        assert(result == value);

        buf.reset();
        buf.writesLEB128(value);
        assert(buf.length() == sLEB128size(value));
        p = buf[];
        result = sLEB128(p);
        assert(!p.length);
        assert(result == value);
    }
}


debug
void unittest_dwarfeh()
{
    __gshared bool run = false;
    if (run)
        return;
    run = true;

    unittest_LEB128();
    unittest_actionTableInsert();
}

