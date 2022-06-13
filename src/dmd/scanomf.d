/**
 * Extract symbols from an OMF object file.
 *
 * Copyright:   Copyright (C) 1999-2022 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/scanomf.d, _scanomf.d)
 * Documentation:  https://dlang.org/phobos/dmd_scanomf.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/scanomf.d
 */

module dmd.scanomf;

import core.stdc.string;
import core.stdc.stdlib;
import dmd.globals;
import dmd.root.rmem;
import dmd.common.outbuffer;
import dmd.root.string;
import dmd.arraytypes;
import dmd.errors;

private enum LOG = false;

/*****************************************
 * Reads an object module from base[] and passes the names
 * of any exported symbols to (*pAddSymbol)().
 * Params:
 *      pAddSymbol =  function to pass the names to
 *      base =        array of contents of object module
 *      module_name = name of the object module (used for error messages)
 *      loc =         location to use for error printing
 */
void scanOmfObjModule(void delegate(const(char)[] name, int pickAny) pAddSymbol,
        const(ubyte)[] base, const(char)* module_name, Loc loc)
{
    static if (LOG)
    {
        printf("scanOmfObjModule(%s)\n", module_name);
    }
    int easyomf;
    char[LIBIDMAX + 1] name;
    Strings names;
    scope(exit)
        for (size_t u = 1; u < names.dim; u++)
            free(cast(void*)names[u]);
    names.push(null); // don't use index 0
    easyomf = 0; // assume not EASY-OMF
    auto pend = cast(const(ubyte)*)base.ptr + base.length;
    const(ubyte)* pnext;
    for (auto p = cast(const(ubyte)*)base.ptr; 1; p = pnext)
    {
        assert(p < pend);
        ubyte recTyp = *p++;
        ushort recLen = *cast(ushort*)p;
        p += 2;
        pnext = p + recLen;
        recLen--; // forget the checksum
        switch (recTyp)
        {
        case LNAMES:
        case LLNAMES:
            while (p + 1 < pnext)
            {
                parseName(&p, name.ptr);
                char* copy = cast(char*)Mem.check(strdup(name.ptr));
                names.push(copy);
            }
            break;
        case PUBDEF:
            if (easyomf)
                recTyp = PUB386; // convert to MS format
            goto case;
        case PUB386:
            if (!(parseIdx(&p) | parseIdx(&p)))
                p += 2; // skip seg, grp, frame
            while (p + 1 < pnext)
            {
                parseName(&p, name.ptr);
                p += (recTyp == PUBDEF) ? 2 : 4; // skip offset
                parseIdx(&p); // skip type index
                pAddSymbol(name[0 .. strlen(name.ptr)], 0);
            }
            break;
        case COMDAT:
            if (easyomf)
                recTyp = COMDAT + 1; // convert to MS format
            goto case;
        case COMDAT + 1:
            {
                int pickAny = 0;
                if (*p++ & 5) // if continuation or local comdat
                    break;
                ubyte attr = *p++;
                if (attr & 0xF0) // attr: if multiple instances allowed
                    pickAny = 1;
                p++; // align
                p += 2; // enum data offset
                if (recTyp == COMDAT + 1)
                    p += 2; // enum data offset
                parseIdx(&p); // type index
                if ((attr & 0x0F) == 0) // if explicit allocation
                {
                    parseIdx(&p); // base group
                    parseIdx(&p); // base segment
                }
                uint idx = parseIdx(&p); // public name index
                if (idx == 0 || idx >= names.dim)
                {
                    //debug(printf("[s] name idx=%d, uCntNames=%d\n", idx, uCntNames));
                    error(loc, "corrupt COMDAT");
                    return;
                }
                //printf("[s] name='%s'\n",name);
                const(char)* n = names[idx];
                pAddSymbol(n.toDString(), pickAny);
                break;
            }
        case COMDEF:
            {
                while (p + 1 < pnext)
                {
                    parseName(&p, name.ptr);
                    parseIdx(&p); // type index
                    skipDataType(&p); // data type
                    pAddSymbol(name[0 .. strlen(name.ptr)], 1);
                }
                break;
            }
        case ALIAS:
            while (p + 1 < pnext)
            {
                parseName(&p, name.ptr);
                pAddSymbol(name[0 .. strlen(name.ptr)], 0);
                parseName(&p, name.ptr);
            }
            break;
        case MODEND:
        case M386END:
            return;
        case COMENT:
            // Recognize Phar Lap EASY-OMF format
            {
                __gshared ubyte* omfstr1 = [0x80, 0xAA, '8', '0', '3', '8', '6'];
                if (recLen == (omfstr1).sizeof)
                {
                    for (uint i = 0; i < (omfstr1).sizeof; i++)
                        if (*p++ != omfstr1[i])
                            goto L1;
                    easyomf = 1;
                    break;
                L1:
                }
            }
            // Recognize .IMPDEF Import Definition Records
            {
                __gshared ubyte* omfstr2 = [0, 0xA0, 1];
                if (recLen >= 7)
                {
                    p++;
                    for (uint i = 1; i < (omfstr2).sizeof; i++)
                        if (*p++ != omfstr2[i])
                            goto L2;
                    p++; // skip OrdFlag field
                    parseName(&p, name.ptr);
                    pAddSymbol(name[0 .. strlen(name.ptr)], 0);
                    break;
                L2:
                }
            }
            break;
        default:
            // ignore
        }
    }
}

/*************************************************
 * Scan a block of memory buf[0..buflen], pulling out each
 * OMF object module in it and sending the info in it to (*pAddObjModule).
 * Returns:
 *      true for corrupt OMF data
 */
bool scanOmfLib(void delegate(char* name, void* base, size_t length) pAddObjModule, void* buf, size_t buflen, uint pagesize)
{
    /* Split up the buffer buf[0..buflen] into multiple object modules,
     * each aligned on a pagesize boundary.
     */
    const(ubyte)* base = null;
    char[LIBIDMAX + 1] name;
    auto p = cast(const(ubyte)*)buf;
    auto pend = p + buflen;
    const(ubyte)* pnext;
    for (; p < pend; p = pnext) // for each OMF record
    {
        if (p + 3 >= pend)
            return true; // corrupt
        ubyte recTyp = *p;
        ushort recLen = *cast(const(ushort)*)(p + 1);
        pnext = p + 3 + recLen;
        if (pnext > pend)
            return true; // corrupt
        recLen--; // forget the checksum
        switch (recTyp)
        {
        case LHEADR:
        case THEADR:
            if (!base)
            {
                base = p;
                p += 3;
                parseName(&p, name.ptr);
                if (name[0] == 'C' && name[1] == 0) // old C compilers did this
                    base = pnext; // skip past THEADR
            }
            break;
        case MODEND:
        case M386END:
            {
                if (base)
                {
                    pAddObjModule(name.ptr, cast(ubyte*)base, pnext - base);
                    base = null;
                }
                // Round up to next page
                uint t = cast(uint)(pnext - cast(const(ubyte)*)buf);
                t = (t + pagesize - 1) & ~cast(uint)(pagesize - 1);
                pnext = cast(const(ubyte)*)buf + t;
                break;
            }
        default:
            // ignore
        }
    }
    return (base !is null); // missing MODEND record
}

uint OMFObjSize(const(void)* base, uint length, const(char)* name)
{
    ubyte c = *cast(const(ubyte)*)base;
    if (c != THEADR && c != LHEADR)
    {
        size_t len = strlen(name);
        assert(len <= LIBIDMAX);
        length += len + 5;
    }
    return length;
}

void writeOMFObj(OutBuffer* buf, const(void)* base, uint length, const(char)* name)
{
    ubyte c = *cast(const(ubyte)*)base;
    if (c != THEADR && c != LHEADR)
    {
        const len = strlen(name);
        assert(len <= LIBIDMAX);
        ubyte[4 + LIBIDMAX + 1] header;
        header[0] = THEADR;
        header[1] = cast(ubyte)(2 + len);
        header[2] = 0;
        header[3] = cast(ubyte)len;
        assert(len <= 0xFF - 2);
        memcpy(4 + header.ptr, name, len);
        // Compute and store record checksum
        uint n = cast(uint)(len + 4);
        ubyte checksum = 0;
        ubyte* p = header.ptr;
        while (n--)
        {
            checksum -= *p;
            p++;
        }
        *p = checksum;
        buf.write(header.ptr[0 .. len + 5]);
    }
    buf.write(base[0 .. length]);
}

private: // for the remainder of this module

/**************************
 * Record types:
 */
enum RHEADR = 0x6E;
enum REGINT = 0x70;
enum REDATA = 0x72;
enum RIDATA = 0x74;
enum OVLDEF = 0x76;
enum ENDREC = 0x78;
enum BLKDEF = 0x7A;
enum BLKEND = 0x7C;
enum DEBSYM = 0x7E;
enum THEADR = 0x80;
enum LHEADR = 0x82;
enum PEDATA = 0x84;
enum PIDATA = 0x86;
enum COMENT = 0x88;
enum MODEND = 0x8A;
enum M386END = 0x8B; /* 32 bit module end record */
enum EXTDEF = 0x8C;
enum TYPDEF = 0x8E;
enum PUBDEF = 0x90;
enum PUB386 = 0x91;
enum LOCSYM = 0x92;
enum LINNUM = 0x94;
enum LNAMES = 0x96;
enum SEGDEF = 0x98;
enum GRPDEF = 0x9A;
enum FIXUPP = 0x9C;
/*#define (none)        0x9E    */
enum LEDATA = 0xA0;
enum LIDATA = 0xA2;
enum LIBHED = 0xA4;
enum LIBNAM = 0xA6;
enum LIBLOC = 0xA8;
enum LIBDIC = 0xAA;
enum COMDEF = 0xB0;
enum LEXTDEF = 0xB4;
enum LPUBDEF = 0xB6;
enum LCOMDEF = 0xB8;
enum CEXTDEF = 0xBC;
enum COMDAT = 0xC2;
enum LINSYM = 0xC4;
enum ALIAS = 0xC6;
enum LLNAMES = 0xCA;
enum LIBIDMAX = (512 - 0x25 - 3 - 4);

// max size that will fit in dictionary
extern (C++) void parseName(const(ubyte)** pp, char* name)
{
    auto p = *pp;
    uint len = *p++;
    if (len == 0xFF && *p == 0) // if long name
    {
        len = p[1] & 0xFF;
        len |= cast(uint)p[2] << 8;
        p += 3;
        assert(len <= LIBIDMAX);
    }
    memcpy(name, p, len);
    name[len] = 0;
    *pp = p + len;
}

ushort parseIdx(const(ubyte)** pp)
{
    auto p = *pp;
    const c = *p++;
    ushort idx = (0x80 & c) ? ((0x7F & c) << 8) + *p++ : c;
    *pp = p;
    return idx;
}

// skip numeric field of a data type of a COMDEF record
void skipNumericField(const(ubyte)** pp)
{
    const(ubyte)* p = *pp;
    const c = *p++;
    if (c == 0x81)
        p += 2;
    else if (c == 0x84)
        p += 3;
    else if (c == 0x88)
        p += 4;
    else
        assert(c <= 0x80);
    *pp = p;
}

// skip data type of a COMDEF record
void skipDataType(const(ubyte)** pp)
{
    auto p = *pp;
    const c = *p++;
    if (c == 0x61)
    {
        // FAR data
        skipNumericField(&p);
        skipNumericField(&p);
    }
    else if (c == 0x62)
    {
        // NEAR data
        skipNumericField(&p);
    }
    else
    {
        assert(1 <= c && c <= 0x5f); // Borland segment indices
    }
    *pp = p;
}
