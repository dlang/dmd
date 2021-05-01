/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1984-1995 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/dcgcv.d, backend/dcgcv.d)
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/backend/dcgcv.d
 */

module dmd.backend.dcgcv;

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
import dmd.backend.cgcv;
import dmd.backend.code;
import dmd.backend.code_x86;
import dmd.backend.cv4;
import dmd.backend.dlist;
import dmd.backend.dvec;
import dmd.backend.el;
import dmd.backend.global;
import dmd.backend.mem;
import dmd.backend.obj;
import dmd.backend.outbuf;
import dmd.backend.symtab;
import dmd.backend.ty;
import dmd.backend.type;

import dmd.backend.barray;

version (SCPP)
{
    import cpp;
    import msgs2;
    import parser;
}
version (MARS)
{
    import dmd.backend.dvarstats;
}

extern (C++):

nothrow:
@safe:

enum SYMDEB_TDB = false;

@trusted
extern (C) void TOOFFSET(void* p, targ_size_t value)
{
    switch (_tysize[TYnptr])
    {
        case 2: *cast(ushort*)p = cast(ushort)value; break;
        case 4: *cast(uint*)  p = cast(uint)  value; break;
        case 8: *cast(ulong*) p = cast(ulong) value; break;
        default:
            assert(0);
    }
}

extern __gshared char* ftdbname;

// Convert from SFL visibilities to CV4 protections
uint SFLtoATTR(uint sfl) { return 4 - ((sfl & SFLpmask) >> 5); }

__gshared
{

/* Dynamic array of debtyp_t's  */
private Barray!(debtyp_t*) debtyp;

private vec_t debtypvec;     // vector of used entries
enum DEBTYPVECDIM = 16_001;   //8009 //3001     // dimension of debtypvec (should be prime)

enum DEBTYPHASHDIM = 1009;
private uint[DEBTYPHASHDIM] debtyphash;

private Outbuffer *reset_symbuf; // Keep pointers to reset symbols

@trusted
idx_t DEB_NULL() { return cgcv.deb_offset; }        // index of null debug type record

/* This limitation is because of 4K page sizes
 * in optlink/cv/cvhashes.asm
 */
enum CVIDMAX = (0xFF0-20);   // the -20 is picked by trial and error

enum LOCATsegrel = 0xC000;

/* Unfortunately, the fixup stuff is different for EASY OMF and Microsoft */
enum EASY_LCFDoffset  =      (LOCATsegrel | 0x1404);
enum EASY_LCFDpointer =      (LOCATsegrel | 0x1800);

enum LCFD32offset     =      (LOCATsegrel | 0x2404);
enum LCFD32pointer    =      (LOCATsegrel | 0x2C00);
enum LCFD16pointer    =      (LOCATsegrel | 0x0C00);

version (MARS)
    extern Cgcv cgcv; // already declared in cgcv.d
else
    Cgcv cgcv;

}

version (MARS)
    enum MARS = true;
else
    enum MARS = false;

/******************************************
 * Return number of bytes consumed in OBJ file by a name.
 */

@trusted
int cv_stringbytes(const(char)* name)
{
    int len = cast(int)strlen(name);
    if (config.fulltypes == CV8)
        return len + 1;
    if (len > CVIDMAX)
        len = CVIDMAX;
    return len + ((len > 255) ? 4 : 1);
}

/******************************************
 * Stuff a namestring into p.
 * Returns:
 *      number of bytes consumed
 */

@trusted
int cv_namestring(ubyte *p, const(char)* name, int length = -1)
{
    size_t len = (length >= 0) ? length : strlen(name);
    if (config.fulltypes == CV8)
    {
        size_t numBytesWritten = len + ((length < 0) ? 1 : 0);
        memcpy(p, name, numBytesWritten);
        if(config.flags2 & CFG2gms)
        {
            for(int i = 0; i < len; i++)
            {
                if(p[i] == '.')
                    p[i] = '@';
            }
        }
        return cast(int)numBytesWritten;
    }
    if (len > 255)
    {   p[0] = 0xFF;
        p[1] = 0;
        if (len > CVIDMAX)
            len = CVIDMAX;
        TOWORD(p + 2,cast(uint)len);
        memcpy(p + 4,name,len);
        len += 4;
    }
    else
    {   p[0] = cast(ubyte)len;
        memcpy(p + 1,name,len);
        len++;
    }
    return cast(int)len;
}

/***********************************
 * Compute debug register number for symbol s.
 * Returns:
 *      0..7    byte registers
 *      8..15   word registers
 *      16..23  dword registers
 */

@trusted
private int cv_regnum(Symbol *s)
{
    uint reg = s.Sreglsw;
    if (s.Sclass == SCpseudo)
    {
version (SCPP)
        reg = pseudoreg[reg];
    }
    else
    {
        assert(reg < 8);
        assert(s.Sfl == FLreg);
        switch (type_size(s.Stype))
        {
            case LONGSIZE:
            case 3:             reg += 8;
                                goto case;

            case SHORTSIZE:     reg += 8;
                                goto case;

            case CHARSIZE:      break;

            case LLONGSIZE:
                reg += (s.Sregmsw << 8) + (16 << 8) + 16;
                if (config.fulltypes == CV4)
                    reg += (1 << 8);
                break;

            default:
static if (0)
{
                symbol_print(s);
                type_print(s.Stype);
                printf("size = %d\n",type_size(s.Stype));
}
                assert(0);
        }
    }
    if (config.fulltypes == CV4)
        reg++;
    return reg;
}

/***********************************
 * Allocate a debtyp_t.
 */
@trusted
debtyp_t * debtyp_alloc(uint length)
{
    debtyp_t *d;
    uint pad = 0;

    //printf("len = %u, x%x\n", length, length);
    if (config.fulltypes == CV8)
    {   // length+2 must lie on 4 byte boundary
        pad = ((length + 2 + 3) & ~3) - (length + 2);
        length += pad;
    }

    length < 0x10000 || assert(0);
    const len = debtyp_t.sizeof - (d.data).sizeof + length;
debug
{
    d = cast(debtyp_t *) mem_malloc(len /*+ 1*/);
    memset(d, 0xAA, len);
//    (cast(char*)d)[len] = 0x2E;
}
else
{
    d = cast(debtyp_t *) malloc(debtyp_t.sizeof - (d.data).sizeof + length);
}
    d.length = cast(ushort)length;
    if (pad)
    {
        __gshared const ubyte[3] padx = [0xF3, 0xF2, 0xF1];
        memcpy(d.data.ptr + length - pad, padx.ptr + 3 - pad, pad);
    }
    //printf("debtyp_alloc(%d) = %p\n", length, d);
    return d;
}

/***********************************
 * Free a debtyp_t.
 */

@trusted
private void debtyp_free(debtyp_t *d)
{
    //printf("debtyp_free(length = %d, %p)\n", d.length, d);
    //fflush(stdout);
debug
{
    assert(d.length < 0x10000);
    uint len = debtyp_t.sizeof - (d.data).sizeof + d.length;
//    assert((cast(char*)d)[len] == 0x2E);
    memset(d, 0x55, len);
    mem_free(d);
}
else
{
    free(d);
}
}

static if (0)
{
void debtyp_check(debtyp_t *d,int linnum)
{   int i;
    __gshared char c;

    //printf("linnum = %d\n",linnum);
    //printf(" length = %d\n",d.length);
    for (i = 0; i < d.length; i++)
        c = d.data.ptr[i];
}

void debtyp_check(debtyp_t* d) { debtyp_check(d,__LINE__); }
}
else
{
void debtyp_check(debtyp_t* d) { }
}

/***********************************
 * Search for debtyp_t in debtyp[]. If it is there, return the index
 * of it, and free d. Otherwise, add it.
 * Returns:
 *      index in debtyp[]
 */

@trusted
idx_t cv_debtyp(debtyp_t *d)
{
    ushort length;
    uint hashi;

    assert(d);
    length = d.length;
    //printf("length = %3d\n",length);
static if (SYMDEB_TDB)
{
    if (config.fulltypes == CVTDB)
    {
            idx_t result;

static if (1)
{
            assert(length);
            debtyp_check(d);
            result = tdb_typidx(&d.length);
}
else
{
            ubyte *buf;

            // Allocate buffer
            buf = malloc(6 + length);
            if (!buf)
                err_nomem();                    // out of memory

            // Fill the buffer
            TOLONG(buf,cgcv.signature);
            memcpy(buf + 4,cast(char *)d + uint.sizeof,2 + length);

static if (0)
{
{int i;
 for (i=0;i<length;i++)
 printf("%02x ",buf[6+i]);
 printf("\n");
}
}
            result = tdb_typidx(buf,6 + length);
}
            //printf("result = x%x\n",result);
            debtyp_free(d);
            return result;
    }
}
    if (length)
    {   uint hash;

        hash = length;
        if (length >= uint.sizeof)
        {
            // Hash consists of the sum of the first 4 bytes with the last 4 bytes
            union U { ubyte* cp; uint* up; }
            U un = void;
            un.cp = d.data.ptr;
            hash += *un.up;
            un.cp += length - uint.sizeof;
            hash += *un.up;
        }
        hashi = hash % DEBTYPHASHDIM;
        hash %= DEBTYPVECDIM;
//printf(" hashi = %d", hashi);

        if (vec_testbit(hash,debtypvec))
        {
//printf(" test");
            // Threaded list is much faster
            for (uint u = debtyphash[hashi]; u; u = debtyp[u].prev)
            //for (uint u = debtyp.length; u--; )
            {
                if (length == debtyp[u].length &&
                    memcmp(d.data.ptr,debtyp[u].data.ptr,length) == 0)
                {   debtyp_free(d);
//printf(" match %d\n",u);
                    return u + cgcv.deb_offset;
                }
            }
        }
        else
            vec_setbit(hash,debtypvec);
    }
    else
        hashi = 1;
//printf(" add   %d\n",debtyp.length);
    d.prev = debtyphash[hashi];
    debtyphash[hashi] = cast(uint)debtyp.length;

    /* It's not already in the array, so add it */
    debtyp.push(d);
    version (SCPP)
    {
        if (debtyp.length >= 0xE000)
            err_fatal(EM_2manytypes,0xE000);         // too many types
    }

    return cast(uint)debtyp.length - 1 + cgcv.deb_offset;
}

@trusted
idx_t cv_numdebtypes()
{
    return cast(idx_t)debtyp.length;
}

/****************************
 * Store a null record at DEB_NULL.
 */

@trusted
void cv_init()
{   debtyp_t *d;

    //printf("cv_init()\n");

    // Initialize statics
    debtyp.setLength(0);
    if (!ftdbname)
        ftdbname = cast(char *)"symc.tdb".ptr;

    memset(&cgcv,0,cgcv.sizeof);
    cgcv.sz_idx = 2;
    cgcv.LCFDoffset = LCFD32offset;
    cgcv.LCFDpointer = LCFD16pointer;

    debtypvec = vec_calloc(DEBTYPVECDIM);
    memset(debtyphash.ptr,0,debtyphash.sizeof);

    if (reset_symbuf)
    {
        Symbol **p = cast(Symbol **)reset_symbuf.buf;
        const size_t n = reset_symbuf.length() / (Symbol *).sizeof;
        for (size_t i = 0; i < n; ++i)
            symbol_reset(p[i]);
        reset_symbuf.reset();
    }
    else
    {
        reset_symbuf = cast(Outbuffer*) calloc(1, Outbuffer.sizeof);
        assert(reset_symbuf);
        reset_symbuf.reserve(10 * (Symbol*).sizeof);
    }

    /* Reset for different OBJ file formats     */
    if (I32 || I64)
    {
        // Adjust values in old CV tables for 32 bit ints
        dttab[TYenum] = dttab[TYlong];
        dttab[TYint]  = dttab[TYlong];
        dttab[TYuint] = dttab[TYulong];

        // Adjust Codeview 4 values for 32 bit ints and 32 bit pointer offsets
        dttab4[TYenum] = 0x74;
        dttab4[TYint]  = 0x74;
        dttab4[TYuint] = 0x75;
        if (I64)
        {
            dttab4[TYptr]  = 0x600;
            dttab4[TYnptr] = 0x600;
            dttab4[TYsptr] = 0x600;
            dttab4[TYimmutPtr] = 0x600;
            dttab4[TYsharePtr] = 0x600;
            dttab4[TYrestrictPtr] = 0x600;
            dttab4[TYfgPtr] = 0x600;
        }
        else
        {
            dttab4[TYptr]  = 0x400;
            dttab4[TYsptr] = 0x400;
            dttab4[TYnptr] = 0x400;
            dttab4[TYimmutPtr] = 0x400;
            dttab4[TYsharePtr] = 0x400;
            dttab4[TYrestrictPtr] = 0x400;
            dttab4[TYfgPtr] = 0x400;
        }
        dttab4[TYcptr] = 0x400;
        dttab4[TYfptr] = 0x500;

        if (config.flags & CFGeasyomf)
        {   cgcv.LCFDoffset  = EASY_LCFDoffset;
            cgcv.LCFDpointer = EASY_LCFDpointer;
            assert(config.fulltypes == CVOLD);
        }
        else
            cgcv.LCFDpointer = LCFD32pointer;

        if (config.exe & EX_flat)
            cgcv.FD_code = 0x10;
    }

    if (config.fulltypes >= CV4)
    {   int flags;
        __gshared ushort[5] memmodel = [0,0x100,0x20,0x120,0x120];
        char[1 + (VERSION).sizeof] version_;
        ubyte[8 + (version_).sizeof] debsym;

        // Put out signature indicating CV4 format
        switch (config.fulltypes)
        {
            case CV4:
                cgcv.signature = 1;
                break;

            case CV8:
                cgcv.signature = 4;
                break;

            default:
            {   const(char)* x = "1MYS";
                cgcv.signature = *cast(int *) x;
                break;
            }
        }

        cgcv.deb_offset = 0x1000;

        if (config.fulltypes == CV8)
        {   cgcv.sz_idx = 4;
            return;     // figure out rest later
        }

        if (config.fulltypes >= CVSYM)
        {   cgcv.sz_idx = 4;
            if (!(config.flags2 & CFG2phgen))
                cgcv.deb_offset = 0x80000000;
        }

        objmod.write_bytes(SegData[DEBSYM],4,&cgcv.signature);

        // Allocate an LF_ARGLIST with no arguments
        if (config.fulltypes == CV4)
        {   d = debtyp_alloc(4);
            TOWORD(d.data.ptr,LF_ARGLIST);
            TOWORD(d.data.ptr + 2,0);
        }
        else
        {   d = debtyp_alloc(6);
            TOWORD(d.data.ptr,LF_ARGLIST);
            TOLONG(d.data.ptr + 2,0);
        }

        // Put out S_COMPILE record
        TOWORD(debsym.ptr + 2,S_COMPILE);
        switch (config.target_cpu)
        {
            case TARGET_8086:   debsym[4] = 0;  break;
            case TARGET_80286:  debsym[4] = 2;  break;
            case TARGET_80386:  debsym[4] = 3;  break;
            case TARGET_80486:  debsym[4] = 4;  break;

            case TARGET_Pentium:
            case TARGET_PentiumMMX:
                                debsym[4] = 5;  break;

            case TARGET_PentiumPro:
            case TARGET_PentiumII:
                                debsym[4] = 6;  break;
            default:    assert(0);
        }
        debsym[5] = (CPP != 0);         // 0==C, 1==C++
        flags = (config.inline8087) ? (0<<3) : (1<<3);
        if (I32)
            flags |= 0x80;              // 32 bit addresses
        flags |= memmodel[config.memmodel];
        TOWORD(debsym.ptr + 6,flags);
        version_[0] = 'Z';
        strcpy(version_.ptr + 1,VERSION);
        cv_namestring(debsym.ptr + 8,version_.ptr);
        TOWORD(debsym.ptr,6 + (version_).sizeof);
        objmod.write_bytes(SegData[DEBSYM],8 + (version_).sizeof,debsym.ptr);

static if (SYMDEB_TDB)
{
        // Put out S_TDBNAME record
        if (config.fulltypes == CVTDB)
        {
            ubyte[50] buf = void;

            pstate.STtdbtimestamp = tdb_gettimestamp();
            size_t len = cv_stringbytes(ftdbname);
            ubyte *ds = (8 + len <= buf.sizeof) ? buf : cast(ubyte *) malloc(8 + len);
            assert(ds);
            TOWORD(ds,6 + len);
            TOWORD(ds + 2,S_TDBNAME);
            TOLONG(ds + 4,pstate.STtdbtimestamp);
            cv_namestring(ds + 8,ftdbname);
            objmod.write_bytes(SegData[DEBSYM],8 + len,ds);
            if (ds != buf)
                free(ds);
        }
}
    }
    else
    {
        assert(0);
    }
    if (config.fulltypes == CVTDB)
        cgcv.deb_offset = cv_debtyp(d);
    else
        cv_debtyp(d);
}

/////////////////////////// CodeView 4 ///////////////////////////////

/***********************************
 * Return number of bytes required to store a numeric leaf.
 */

uint cv4_numericbytes(uint value)
{   uint u;

    if (value < 0x8000)
        u = 2;
    else if (value < 0x10000)
        u = 4;
    else
        u = 6;
    return u;
}

/********************************
 * Store numeric leaf.
 * Must use exact same number of bytes as cv4_numericbytes().
 */

@trusted
void cv4_storenumeric(ubyte *p, uint value)
{
    if (value < 0x8000)
        TOWORD(p,value);
    else if (value < 0x10000)
    {   TOWORD(p,LF_USHORT);
        p += 2;
        TOWORD(p,value);
    }
    else
    {   TOWORD(p,LF_ULONG);
        *cast(targ_ulong *)(p + 2) = cast(uint) value;
    }
}

/***********************************
 * Return number of bytes required to store a signed numeric leaf.
 * Params:
 *   value = value to store
 * Returns:
 *   number of bytes required for storing value
 */
uint cv4_signednumericbytes(int value)
{
    uint u;
    if (value >= 0 && value < 0x8000)
        u = 2;
    else if (value == cast(short)value)
        u = 4;
    else
        u = 6;
    return u;
}

/********************************
 * Store signed numeric leaf.
 * Must use exact same number of bytes as cv4_signednumericbytes().
 * Params:
 *   p = address where to store value
 *   value = value to store
 */
@trusted
void cv4_storesignednumeric(ubyte *p, int value)
{
    if (value >= 0 && value < 0x8000)
        TOWORD(p, value);
    else if (value == cast(short)value)
    {
        TOWORD(p, LF_SHORT);
        TOWORD(p + 2, value);
    }
    else
    {
        TOWORD(p,LF_LONG);
        TOLONG(p + 2, value);
    }
}

/*********************************
 * Generate a type index for a parameter list.
 */

@trusted
idx_t cv4_arglist(type *t,uint *pnparam)
{   uint u;
    uint nparam;
    idx_t paramidx;
    debtyp_t *d;
    param_t *p;

    // Compute nparam, number of parameters
    nparam = 0;
    for (p = t.Tparamtypes; p; p = p.Pnext)
        nparam++;
    *pnparam = nparam;

    // Construct an LF_ARGLIST of those parameters
    if (nparam == 0)
    {
        if (config.fulltypes == CV8)
        {
            d = debtyp_alloc(2 + 4 + 4);
            TOWORD(d.data.ptr,LF_ARGLIST_V2);
            TOLONG(d.data.ptr + 2,1);
            TOLONG(d.data.ptr + 6,0);
            paramidx = cv_debtyp(d);
        }
        else
            paramidx = DEB_NULL;
    }
    else
    {
        switch (config.fulltypes)
        {
            case CV8:
                d = debtyp_alloc(2 + 4 + nparam * 4);
                TOWORD(d.data.ptr,LF_ARGLIST_V2);
                TOLONG(d.data.ptr + 2,nparam);

                p = t.Tparamtypes;
                for (u = 0; u < nparam; u++)
                {   TOLONG(d.data.ptr + 6 + u * 4,cv4_typidx(p.Ptype));
                    p = p.Pnext;
                }
                break;

            case CV4:
                d = debtyp_alloc(2 + 2 + nparam * 2);
                TOWORD(d.data.ptr,LF_ARGLIST);
                TOWORD(d.data.ptr + 2,nparam);

                p = t.Tparamtypes;
                for (u = 0; u < nparam; u++)
                {   TOWORD(d.data.ptr + 4 + u * 2,cv4_typidx(p.Ptype));
                    p = p.Pnext;
                }
                break;

            default:
                d = debtyp_alloc(2 + 4 + nparam * 4);
                TOWORD(d.data.ptr,LF_ARGLIST);
                TOLONG(d.data.ptr + 2,nparam);

                p = t.Tparamtypes;
                for (u = 0; u < nparam; u++)
                {   TOLONG(d.data.ptr + 6 + u * 4,cv4_typidx(p.Ptype));
                    p = p.Pnext;
                }
                break;
        }
        paramidx = cv_debtyp(d);
    }
    return paramidx;
}

/*****************************
 * Build LF_METHODLIST for overloaded member function.
 * Output:
 *      *pcount         # of entries in method list
 * Returns:
 *      type index of method list
 *      0 don't do this one
 */

version (SCPP)
{

private int cv4_methodlist(Symbol *sf,int *pcount)
{   int count;
    int mlen;
    Symbol *s;
    debtyp_t *d;
    ubyte *p;
    ushort attribute;

    symbol_debug(sf);

    // First, compute how big the method list is
    count = 0;
    mlen = 2;
    for (s = sf; s; s = s.Sfunc.Foversym)
    {
        if (s.Sclass == SCtypedef || s.Sclass == SCfunctempl)
            continue;
        if (s.Sfunc.Fflags & Fnodebug)
            continue;
        if (s.Sfunc.Fflags & Fintro)
            mlen += 4;
        mlen += cgcv.sz_idx * 2;
        count++;
    }

    if (!count)
        return 0;

    // Allocate and fill it in
    d = debtyp_alloc(mlen);
    p = d.data.ptr;
    TOWORD(p,LF_METHODLIST);
    p += 2;
    for (s = sf; s; s = s.Sfunc.Foversym)
    {
        if (s.Sclass == SCtypedef || s.Sclass == SCfunctempl)
            continue;
        if (s.Sfunc.Fflags & Fnodebug)
            continue;
        attribute = cast(ushort)SFLtoATTR(s.Sflags);
        // Make sure no overlapping bits
        assert((Fvirtual | Fpure | Fintro | Fstatic) == (Fvirtual ^ Fpure ^ Fintro ^ Fstatic));
        switch ((s.Sfunc.Fflags & (Fvirtual | Fstatic)) |
                (s.Sfunc.Fflags & (Fpure | Fintro)))
        {
            // BUG: should we have 0x0C, friend functions?
            case Fstatic:                       attribute |= 0x08; break;
            case Fvirtual:                      attribute |= 0x04; break;
            case Fvirtual | Fintro:             attribute |= 0x10; break;
            case Fvirtual | Fpure:              attribute |= 0x14; break;
            case Fvirtual | Fintro | Fpure:     attribute |= 0x18; break;

            case 0:
                break;

            default:
                symbol_print(s);
                assert(0);
        }
        TOIDX(p,attribute);
        p += cgcv.sz_idx;
        TOIDX(p,cv4_symtypidx(s));
        p += cgcv.sz_idx;
        if (s.Sfunc.Fflags & Fintro)
        {   TOLONG(p,cpp_vtbloffset(cast(Classsym *)s.Sscope,s));
            p += 4;
        }
    }
    assert(p - d.data.ptr == mlen);

    *pcount = count;
    return cv_debtyp(d);
}

}

/**********************************
 * Pretty-print indentifier for CV4 types.
 */

version (SCPP)
{

private const(char)* cv4_prettyident(Symbol *s)
{   Symbol *stmp;

    stmp = s.Sscope;
    s.Sscope = null;           // trick cpp_prettyident into leaving off ::
    const p = cpp_prettyident(s);
    s.Sscope = cast(Classsym *)stmp;
    return p;
}

}

/****************************
 * Return type index of struct.
 * Input:
 *      s       struct tag symbol
 *      flags
 *          0   generate a reference to s
 *          1   just saw the definition of s
 *          2   saw key function for class s
 *          3   no longer have a key function for class s
 */

@trusted
idx_t cv4_struct(Classsym *s,int flags)
{   targ_size_t size;
    debtyp_t* d,dt;
    uint len;
    uint nfields,fnamelen;
    idx_t typidx;
    type *t;
    struct_t *st;
    const(char)* id;
version (SCPP)
{
    baseclass_t *b;
}
    uint numidx;
    uint leaf;
    uint property;
    uint attribute;
    ubyte *p;
    int refonly;
    int i;
    int count;                  // COUNT field in LF_CLASS

    symbol_debug(s);
    assert(config.fulltypes >= CV4);
    st = s.Sstruct;
    if (st.Sflags & STRanonymous)      // if anonymous class/union
        return 0;

    //printf("cv4_struct(%s,%d)\n",s.Sident.ptr,flags);
    t = s.Stype;
    //printf("t = %p, Tflags = x%x\n", t, t.Tflags);
    type_debug(t);

    // Determine if we should do a reference or a definition
    refonly = 1;                        // assume reference only
    if (MARS || t.Tflags & TFsizeunknown || st.Sflags & STRoutdef)
    {
        //printf("ref only\n");
    }
    else
    {
        // We have a definition that we have not put out yet
        switch (flags)
        {
            case 0:                     // reference to s
version (SCPP)
{
                if (!CPP ||
                    config.flags2 & (CFG2fulltypes | CFG2hdrdebug) ||
                    !(st.Sflags & STRvtblext))
                    refonly = 0;
}
else
{
                refonly = 0;
}
                break;

            case 1:                     // saw def of s
                if (!s.Stypidx)        // if not forward referenced
                    return 0;
version (SCPP)
{
                if (!CPP ||
                    config.flags2 & CFG2fulltypes ||
                    !(st.Sflags & STRvtblext))
                    refonly = 0;
}
                break;

version (SCPP)
{
            case 2:                     // saw key func for s
                if (config.flags2 & CFG2fulltypes)
                    return 0;
                refonly = 0;
                break;

            case 3:                     // no longer have key func for s
                if (!s.Stypidx || config.flags2 & CFG2fulltypes)
                    return 0;
                refonly = 0;
                break;
}
            default:
                assert(0);
        }
    }

    if (MARS || refonly)
    {
        if (s.Stypidx)                 // if reference already generated
        {   //assert(s.Stypidx - cgcv.deb_offset < debtyp.length);
            return s.Stypidx;          // use already existing reference
        }
        size = 0;
        property = 0x80;                // class is forward referenced
    }
    else
    {   size = type_size(t);
        st.Sflags |= STRoutdef;
        property = 0;
    }

version (SCPP)
{
    if (CPP)
    {
        if (s.Sscope)                  // if class is nested
            property |= 8;
        if (st.Sctor || st.Sdtor)
            property |= 2;              // class has ctors and/or dtors
        if (st.Sopoverload)
            property |= 4;              // class has overloaded operators
        if (st.Scastoverload)
            property |= 0x40;           // class has casting methods
        if (st.Sopeq && !(st.Sopeq.Sfunc.Fflags & Fnodebug))
            property |= 0x20;           // class has overloaded assignment
    }
}
    id = prettyident(s);
    if (config.fulltypes == CV4)
    {   numidx = (st.Sflags & STRunion) ? 8 : 12;
        len = numidx + cv4_numericbytes(cast(uint)size);
        d = debtyp_alloc(len + cv_stringbytes(id));
        cv4_storenumeric(d.data.ptr + numidx,cast(uint)size);
    }
    else
    {   numidx = (st.Sflags & STRunion) ? 10 : 18;
        len = numidx + 4;
        d = debtyp_alloc(len + cv_stringbytes(id));
        TOLONG(d.data.ptr + numidx,cast(uint)size);
    }
    len += cv_namestring(d.data.ptr + len,id);
    switch (s.Sclass)
    {
        case SCstruct:
            leaf = LF_STRUCTURE;
            if (st.Sflags & STRunion)
            {   leaf = LF_UNION;
                break;
            }
            if (st.Sflags & STRclass)
                leaf = LF_CLASS;
            goto L1;
        L1:
            if (config.fulltypes == CV4)
                TOWORD(d.data.ptr + 8,0);          // dList
            else
                TOLONG(d.data.ptr + 10,0);         // dList
        if (CPP)
        {
version (SCPP)
{
            debtyp_t *vshape;
            ubyte descriptor;

            const n = list_nitems(st.Svirtual);
            if (n == 0)                         // if no virtual functions
            {
                if (config.fulltypes == CV4)
                    TOWORD(d.data.ptr + 10,0);             // vshape is 0
                else
                    TOLONG(d.data.ptr + 14,0);             // vshape is 0
            }
            else
            {
                vshape = debtyp_alloc(4 + (n + 1) / 2);
                TOWORD(vshape.data.ptr,LF_VTSHAPE);
                TOWORD(vshape.data.ptr + 2,1);

                uint n2 = 0;
                descriptor = 0;
                foreach (vl; ListRange(st.Svirtual))
                {   mptr_t *m;
                    tym_t ty;

                    m = list_mptr(vl);
                    symbol_debug(m.MPf);
                    ty = tybasic(m.MPf.ty());
                    assert(tyfunc(ty));
                    if (_tysize[TYint] == 4)
                        descriptor |= 5;
                    if (tyfarfunc(ty))
                        descriptor++;
                    vshape.data.ptr[4 + n2 / 2] = descriptor;
                    descriptor <<= 4;
                    n2++;
                }
                if (config.fulltypes == CV4)
                    TOWORD(d.data.ptr + 10,cv_debtyp(vshape));     // vshape
                else
                    TOLONG(d.data.ptr + 14,cv_debtyp(vshape));     // vshape
            }
}
        }
        else
        {
            if (config.fulltypes == CV4)
                TOWORD(d.data.ptr + 10,0);         // vshape
            else
                TOLONG(d.data.ptr + 14,0);         // vshape
        }
            break;

        default:
            symbol_print(s);
            assert(0);
    }
    TOWORD(d.data.ptr,leaf);

    // Assign a number to prevent infinite recursion if a struct member
    // references the same struct.
    if (config.fulltypes == CVTDB)
    {
static if (SYMDEB_TDB)
{
        TOWORD(d.data.ptr + 2,0);          // number of fields
        TOLONG(d.data.ptr + 6,0);          // field list is 0
        TOWORD(d.data.ptr + 4,property | 0x80);    // set fwd ref bit
static if (0)
{
printf("fwd struct ref\n");
{int i;
 printf("len = %d, length = %d\n",len,d.length);
 for (i=0;i<d.length;i++)
 printf("%02x ",d.data.ptr[i]);
 printf("\n");
}
}
        debtyp_check(d);
        s.Stypidx = tdb_typidx(&d.length);    // forward reference it
}
    }
    else
    {
        d.length = 0;                  // so cv_debtyp() will allocate new
        s.Stypidx = cv_debtyp(d);
        d.length = cast(ushort)len;    // restore length
    }
    reset_symbuf.write((&s)[0 .. 1]);

    if (refonly)                        // if reference only
    {
        //printf("refonly\n");
        TOWORD(d.data.ptr + 2,0);          // count: number of fields is 0
        if (config.fulltypes == CV4)
        {   TOWORD(d.data.ptr + 4,0);              // field list is 0
            TOWORD(d.data.ptr + 6,property);
        }
        else
        {   TOLONG(d.data.ptr + 6,0);              // field list is 0
            TOWORD(d.data.ptr + 4,property);
        }
        return s.Stypidx;
    }

version (MARS)
    util_progress();
else
    file_progress();

    // Compute the number of fields, and the length of the fieldlist record
    nfields = 0;
    fnamelen = 2;
version (SCPP)
{
    if (CPP)
    {
    // Base classes come first
    for (b = st.Sbase; b; b = b.BCnext)
    {
        if (b.BCflags & BCFvirtual)    // skip virtual base classes
            continue;
        nfields++;
        fnamelen += ((config.fulltypes == CV4) ? 6 : 8) +
                    cv4_numericbytes(b.BCoffset);
    }

    // Now virtual base classes (direct and indirect)
    for (b = st.Svirtbase; b; b = b.BCnext)
    {
        nfields++;
        fnamelen += ((config.fulltypes == CV4) ? 8 : 12) +
                        cv4_numericbytes(st.Svbptr_off) +
                        cv4_numericbytes(b.BCvbtbloff / _tysize[TYint]);
    }

    // Now friend classes
    i = list_nitems(st.Sfriendclass);
    nfields += i;
    fnamelen += i * ((config.fulltypes == CV4) ? 4 : 8);

    // Now friend functions
    foreach (sl; ListRange(st.Sfriendfuncs))
    {   Symbol *sf = list_symbol(sl);

        symbol_debug(sf);
        if (sf.Sclass == SCfunctempl)
            continue;
        nfields++;
        fnamelen += ((config.fulltypes == CV4) ? 4 : 6) +
                    cv_stringbytes(cpp_unmangleident(sf.Sident.ptr));
    }
    }
}
    count = nfields;
    foreach (sl; ListRange(st.Sfldlst))
    {   Symbol *sf = list_symbol(sl);
        targ_size_t offset;

        symbol_debug(sf);
        const(char)* sfid = sf.Sident.ptr;
        switch (sf.Sclass)
        {
            case SCmember:
            case SCfield:
                if (CPP && sf == s.Sstruct.Svptr)
                    fnamelen += ((config.fulltypes == CV4) ? 4 : 8);
                else
                {   offset = sf.Smemoff;
                    fnamelen += ((config.fulltypes == CV4) ? 6 : 8) +
                                cv4_numericbytes(cast(uint)offset) + cv_stringbytes(sfid);
                }
                break;

version (SCPP)
{
            case SCstruct:
                if (sf.Sstruct.Sflags & STRanonymous)
                    continue;
                if (sf.Sstruct.Sflags & STRnotagname)
                    sfid = cpp_name_none.ptr;
                property |= 0x10;       // class contains nested classes
                goto Lnest2;

            case SCenum:
                if (sf.Senum.SEflags & SENnotagname)
                    sfid = cpp_name_none.ptr;
                goto Lnest2;

            case SCtypedef:
            Lnest2:
                fnamelen += ((config.fulltypes == CV4) ? 4 : 8) +
                            cv_stringbytes(sfid);
                break;

            case SCextern:
            case SCcomdef:
            case SCglobal:
            case SCstatic:
            case SCinline:
            case SCsinline:
            case SCeinline:
            case SCcomdat:
                if (tyfunc(sf.ty()))
                {   Symbol *so;
                    int nfuncs;

                    nfuncs = 0;
                    for (so = sf; so; so = so.Sfunc.Foversym)
                    {
                        if (so.Sclass == SCtypedef ||
                            so.Sclass == SCfunctempl ||
                            so.Sfunc.Fflags & Fnodebug)       // if compiler generated
                            continue;                   // skip it
                        nfuncs++;
                    }
                    if (nfuncs == 0)
                        continue;

                    if (nfuncs > 1)
                        count += nfuncs - 1;

                    sfid = cv4_prettyident(sf);
                }
                fnamelen += ((config.fulltypes == CV4) ? 6 : 8) +
                            cv_stringbytes(sfid);
                break;
}

            default:
                continue;
        }
        nfields++;
        count++;
    }

    TOWORD(d.data.ptr + 2,count);
    if (config.fulltypes == CV4)
        TOWORD(d.data.ptr + 6,property);
    else
        TOWORD(d.data.ptr + 4,property);

    // Generate fieldlist type record
    dt = debtyp_alloc(fnamelen);
    p = dt.data.ptr;
    TOWORD(p,LF_FIELDLIST);

    // And fill it in
    p += 2;
version (SCPP)
{
    if (CPP)
    {
    // Put out real base classes
    for (b = st.Sbase; b; b = b.BCnext)
    {   targ_size_t offset;

        if (b.BCflags & BCFvirtual)    // skip virtual base classes
            continue;
        offset = b.BCoffset;
        typidx = cv4_symtypidx(b.BCbase);

        attribute = (b.BCflags & BCFpmask);
        if (attribute & 4)
            attribute = 1;
        else
            attribute = 4 - attribute;

        TOWORD(p,LF_BCLASS);
        if (config.fulltypes == CV4)
        {   TOWORD(p + 2,typidx);
            TOWORD(p + 4,attribute);
            p += 6;
        }
        else
        {   TOLONG(p + 4,typidx);
            TOWORD(p + 2,attribute);
            p += 8;
        }

        cv4_storenumeric(p,offset);
        p += cv4_numericbytes(offset);
    }

    // Now direct followed by indirect virtual base classes
    i = LF_VBCLASS;
    do
    {
        for (b = st.Svirtbase; b; b = b.BCnext)
        {   targ_size_t vbpoff,vboff;
            type *vbptype;              // type of virtual base pointer
            idx_t vbpidx;

            if (baseclass_find(st.Sbase,b.BCbase))    // if direct vbase
            {   if (i == LF_IVBCLASS)
                    continue;
            }
            else
            {   if (i == LF_VBCLASS)
                    continue;
            }

            typidx = cv4_symtypidx(b.BCbase);

            vbptype = type_allocn(TYarray,tstypes[TYint]);
            vbptype.Tflags |= TFsizeunknown;
            vbptype = newpointer(vbptype);
            vbptype.Tcount++;
            vbpidx = cv4_typidx(vbptype);
            type_free(vbptype);

            attribute = (b.BCflags & BCFpmask);
            if (attribute & 4)
                attribute = 1;
            else
                attribute = 4 - attribute;

            vbpoff = st.Svbptr_off;
            vboff = b.BCvbtbloff / _tysize[TYint];

            if (config.fulltypes == CV4)
            {   TOWORD(p,i);
                TOWORD(p + 2,typidx);
                TOWORD(p + 4,vbpidx);
                TOWORD(p + 6,attribute);
                p += 8;
            }
            else
            {   TOWORD(p,i);
                TOLONG(p + 4,typidx);           // btype
                TOLONG(p + 8,vbpidx);           // vbtype
                TOWORD(p + 2,attribute);
                p += 12;
            }

            cv4_storenumeric(p,vbpoff);
            p += cv4_numericbytes(vbpoff);
            cv4_storenumeric(p,vboff);
            p += cv4_numericbytes(vboff);
        }
        i ^= LF_VBCLASS ^ LF_IVBCLASS;          // toggle between them
    } while (i != LF_VBCLASS);

    // Now friend classes
    foreach (sl; ListRange(s.Sstruct.Sfriendclass))
    {   Symbol *sf = list_symbol(sl);

        symbol_debug(sf);
        typidx = cv4_symtypidx(sf);
        if (config.fulltypes == CV4)
        {   TOWORD(p,LF_FRIENDCLS);
            TOWORD(p + 2,typidx);
            p += 4;
        }
        else
        {   TOLONG(p,LF_FRIENDCLS);
            TOLONG(p + 4,typidx);
            p += 8;
        }
    }

    // Now friend functions
    foreach (sl; ListRange(s.Sstruct.Sfriendfuncs))
    {   Symbol *sf = list_symbol(sl);

        symbol_debug(sf);
        if (sf.Sclass == SCfunctempl)
            continue;
        typidx = cv4_symtypidx(sf);
        TOWORD(p,LF_FRIENDFCN);
        if (config.fulltypes == CV4)
        {   TOWORD(p + 2,typidx);
            p += 4;
        }
        else
        {   TOLONG(p + 2,typidx);
            p += 6;
        }
        p += cv_namestring(p,cpp_unmangleident(sf.Sident.ptr));
    }
    }
}
    foreach (sl; ListRange(s.Sstruct.Sfldlst))
    {   Symbol *sf = list_symbol(sl);
        targ_size_t offset;

        symbol_debug(sf);
        const(char)* sfid = sf.Sident.ptr;
        switch (sf.Sclass)
        {
            case SCfield:
            {   debtyp_t *db;

                if (config.fulltypes == CV4)
                {   db = debtyp_alloc(6);
                    TOWORD(db.data.ptr,LF_BITFIELD);
                    db.data.ptr[2] = sf.Swidth;
                    db.data.ptr[3] = sf.Sbit;
                    TOWORD(db.data.ptr + 4,cv4_symtypidx(sf));
                }
                else
                {   db = debtyp_alloc(8);
                    TOWORD(db.data.ptr,LF_BITFIELD);
                    db.data.ptr[6] = sf.Swidth;
                    db.data.ptr[7] = sf.Sbit;
                    TOLONG(db.data.ptr + 2,cv4_symtypidx(sf));
                }
                typidx = cv_debtyp(db);
                goto L3;
            }

            case SCmember:
                typidx = cv4_symtypidx(sf);
            L3:
version (SCPP)
{
                if (CPP && sf == s.Sstruct.Svptr)
                {
                    if (config.fulltypes == CV4)
                    {   TOWORD(p,LF_VFUNCTAB);
                        TOWORD(p + 2,typidx);
                        p += 4;
                    }
                    else
                    {   TOLONG(p,LF_VFUNCTAB);          // 0 fill 2 bytes
                        TOLONG(p + 4,typidx);
                        p += 8;
                    }
                    break;
                }
}
                offset = sf.Smemoff;
                TOWORD(p,LF_MEMBER);
version (SCPP)
{
                attribute = CPP ? SFLtoATTR(sf.Sflags) : 0;
                assert((attribute & ~3) == 0);
}
else
{
                attribute = 0;
}
                if (config.fulltypes == CV4)
                {   TOWORD(p + 2,typidx);
                    TOWORD(p + 4,attribute);
                    p += 6;
                }
                else
                {   TOLONG(p + 4,typidx);
                    TOWORD(p + 2,attribute);
                    p += 8;
                }
                cv4_storenumeric(p,cast(uint)offset);
                p += cv4_numericbytes(cast(uint)offset);
                p += cv_namestring(p,sfid);
                break;

version (SCPP)
{
            case SCstruct:
                if (sf.Sstruct.Sflags & STRanonymous)
                    continue;
                if (sf.Sstruct.Sflags & STRnotagname)
                    sfid = cpp_name_none.ptr;
                goto Lnest;

            case SCenum:
                if (sf.Senum.SEflags & SENnotagname)
                    sfid = cpp_name_none.ptr;
                goto Lnest;

            case SCtypedef:
            Lnest:
                TOWORD(p,LF_NESTTYPE);
                typidx = cv4_symtypidx(sf);
                if (config.fulltypes == CV4)
                {   TOWORD(p + 2,typidx);
                    p += 4;
                }
                else
                {   TOLONG(p + 4,typidx);
                    p += 8;
                }
            L2:
                p += cv_namestring(p,sfid);
                break;

            case SCextern:
            case SCcomdef:
            case SCglobal:
            case SCstatic:
            case SCinline:
            case SCsinline:
            case SCeinline:
            case SCcomdat:
                if (tyfunc(sf.ty()))
                {   int count2;

                    typidx = cv4_methodlist(sf,&count2);
                    if (!typidx)
                        break;
                    sfid = cv4_prettyident(sf);
                    TOWORD(p,LF_METHOD);
                    TOWORD(p + 2,count2);
                    p += 4;
                    TOIDX(p,typidx);
                    p += cgcv.sz_idx;
                    goto L2;
                }
                else
                {
                    TOWORD(p,LF_STMEMBER);
                    typidx = cv4_symtypidx(sf);
                    attribute = SFLtoATTR(sf.Sflags);
                    if (config.fulltypes == CV4)
                    {   TOWORD(p + 2,typidx);
                        TOWORD(p + 4,attribute);
                        p += 6;
                    }
                    else
                    {   TOLONG(p + 4,typidx);
                        TOWORD(p + 2,attribute);
                        p += 8;
                    }
                    goto L2;
                }
                break;
}

            default:
                continue;
        }
    }
    //printf("fnamelen = %d, p-dt.data = %d\n",fnamelen,p-dt.data);
    assert(p - dt.data.ptr == fnamelen);
    if (config.fulltypes == CV4)
        TOWORD(d.data.ptr + 4,cv_debtyp(dt));
    else
        TOLONG(d.data.ptr + 6,cv_debtyp(dt));

static if (SYMDEB_TDB)
{
    if (config.fulltypes == CVTDB)
    {
        s.Stypidx = cv_debtyp(d);
        reset_symbuf.write(&s, (s).sizeof);
    }
}
version (SCPP)
{
    if (CPP)
    {
        symbol_debug(s);
        if (st.Sflags & STRglobal)
            list_prepend(&cgcv.list,s);
        else
            cv4_outsym(s);
    }
}
    return s.Stypidx;
}

/****************************
 * Return type index of enum.
 */

version (SCPP)
{
@trusted
private uint cv4_enum(Symbol *s)
{
    debtyp_t* d,dt;
    uint nfields,fnamelen;
    uint len;
    type *t;
    type *tbase;
    uint property;
    uint attribute;
    int i;
    char *id;

    symbol_debug(s);
    if (s.Stypidx)                     // if already converted
    {   //assert(s.Stypidx - cgcv.deb_offset < debtyp.length);
        return s.Stypidx;
    }

    //printf("cv4_enum(%s)\n",s.Sident.ptr);
    t = s.Stype;
    type_debug(t);
    tbase = t.Tnext;
    property = 0;
    if (s.Senum.SEflags & SENforward)
        property |= 0x80;               // enum is forward referenced

    id = s.Sident.ptr;
    if (s.Senum.SEflags & SENnotagname)
        id = cpp_name_none.ptr;
    if (config.fulltypes == CV4)
    {   len = 10;
        d = debtyp_alloc(len + cv_stringbytes(id));
        TOWORD(d.data.ptr,LF_ENUM);
        TOWORD(d.data.ptr + 4,cv4_typidx(tbase));
        TOWORD(d.data.ptr + 8,property);
    }
    else
    {   len = 14;
        d = debtyp_alloc(len + cv_stringbytes(id));
        TOWORD(d.data.ptr,LF_ENUM);
        TOLONG(d.data.ptr + 6,cv4_typidx(tbase));
        TOWORD(d.data.ptr + 4,property);
    }
    len += cv_namestring(d.data.ptr + len,id);

    // Assign a number to prevent infinite recursion if an enum member
    // references the same enum.
    if (config.fulltypes == CVTDB)
    {
static if (SYMDEB_TDB)
{
        debtyp_t *df;

        TOWORD(d.data.ptr + 2,0);
        TOWORD(d.data.ptr + 6,0);
        debtyp_check(d);
        s.Stypidx = tdb_typidx(&d.length);    // forward reference it
}
    }
    else
    {
        d.length = 0;                  // so cv_debtyp() will allocate new
        s.Stypidx = cv_debtyp(d);
        d.length = cast(ushort)len;           // restore length
    }
    reset_symbuf.write((&s)[0 .. 1]);

    // Compute the number of fields, and the length of the fieldlist record
    nfields = 0;
    fnamelen = 2;
    foreach (sl; ListRange(s.Senum.SEenumlist))
    {   Symbol *sf = list_symbol(sl);
        uint value;

        symbol_debug(sf);
        value = cast(uint)el_tolongt(sf.Svalue);
        nfields++;
        fnamelen += 4 + cv4_numericbytes(value) + cv_stringbytes(sf.Sident.ptr);
    }

    TOWORD(d.data.ptr + 2,nfields);

    // If forward reference, then field list is 0
    if (s.Senum.SEflags & SENforward)
    {
        TOWORD(d.data.ptr + 6,0);
        return s.Stypidx;
    }

    // Generate fieldlist type record
    dt = debtyp_alloc(fnamelen);
    TOWORD(dt.data.ptr,LF_FIELDLIST);

    // And fill it in
    i = 2;
    foreach (sl; ListRange(s.Senum.SEenumlist))
    {   Symbol *sf = list_symbol(sl);
        uint value;

        symbol_debug(sf);
        value = cast(uint)el_tolongt(sf.Svalue);
        TOWORD(dt.data.ptr + i,LF_ENUMERATE);
        attribute = SFLtoATTR(sf.Sflags);
        TOWORD(dt.data.ptr + i + 2,attribute);
        cv4_storenumeric(dt.data.ptr + i + 4,value);
        i += 4 + cv4_numericbytes(value);
        i += cv_namestring(dt.data.ptr + i,sf.Sident.ptr);

        // If enum is not a member of a class, output enum members as constants
        if (!isclassmember(s))
        {   symbol_debug(sf);
            cv4_outsym(sf);
        }
    }
    assert(i == fnamelen);
    if (config.fulltypes == CV4)
        TOWORD(d.data.ptr + 6,cv_debtyp(dt));
    else
        TOLONG(d.data.ptr + 10,cv_debtyp(dt));

    symbol_debug(s);
    if (CPP)
        cv4_outsym(s);
    return s.Stypidx;
}

}
else
{
@trusted
private uint cv4_fwdenum(type* t)
{
    Symbol* s = t.Ttag;

    // write a forward reference enum record that is enough for the linker to
    // fold with original definition from EnumDeclaration
    uint bty = dttab4[tybasic(t.Tnext.Tty)];
    const id = prettyident(s);
    uint len = config.fulltypes == CV8 ? 14 : 10;
    debtyp_t* d = debtyp_alloc(len + cv_stringbytes(id));
    switch (config.fulltypes)
    {
        case CV8:
            TOWORD(d.data.ptr, LF_ENUM_V3);
            TOLONG(d.data.ptr + 2, 0);    // count
            TOWORD(d.data.ptr + 4, 0x80); // property : forward reference
            TOLONG(d.data.ptr + 6, bty);  // memtype
            TOLONG(d.data.ptr + 10, 0);   // fieldlist
            break;

        case CV4:
            TOWORD(d.data.ptr,LF_ENUM);
            TOWORD(d.data.ptr + 2, 0);    // count
            TOWORD(d.data.ptr + 4, bty);  // memtype
            TOLONG(d.data.ptr + 6, 0);    // fieldlist
            TOWORD(d.data.ptr + 8, 0x80); // property : forward reference
            break;

        default:
            assert(0);
    }
    cv_namestring(d.data.ptr + len, id);
    s.Stypidx = cv_debtyp(d);
    return s.Stypidx;
}

}
/************************************************
 * Return 'calling convention' type of function.
 */

ubyte cv4_callconv(type *t)
{   ubyte call;

    switch (tybasic(t.Tty))
    {
        case TYffunc:   call = 1;       break;
        case TYfpfunc:  call = 3;       break;
        case TYf16func: call = 3;       break;
        case TYfsfunc:  call = 8;       break;
        case TYnsysfunc: call = 9;      break;
        case TYfsysfunc: call = 10;     break;
        case TYnfunc:   call = 0;       break;
        case TYnpfunc:  call = 2;       break;
        case TYnsfunc:  call = 7;       break;
        case TYifunc:   call = 1;       break;
        case TYjfunc:   call = 2;       break;
        case TYmfunc:   call = 11;      break;  // this call
        default:
            assert(0);
    }
    return call;
}

/**********************************************
 * Return type index for the type of a symbol.
 */

version (MARS)
{

private uint cv4_symtypidx(Symbol *s)
{
    return cv4_typidx(s.Stype);
}

}

version (SCPP)
{

@trusted
private uint cv4_symtypidx(Symbol *s)
{   type *t;
    debtyp_t *d;
    ubyte *p;

    if (!CPP)
        return cv4_typidx(s.Stype);
    symbol_debug(s);
    if (isclassmember(s))
    {   t = s.Stype;
        if (tyfunc(t.Tty))
        {   param_t *pa;
            uint nparam;
            idx_t paramidx;
            idx_t thisidx;
            uint u;
            func_t *f;
            ubyte call;

            // It's a member function, which gets a special type record

            f = s.Sfunc;
            if (f.Fflags & Fstatic)
                thisidx = dttab4[TYvoid];
            else
            {   type *tthis = cpp_thistype(s.Stype,cast(Classsym *)s.Sscope);

                thisidx = cv4_typidx(tthis);
                type_free(tthis);
            }

            paramidx = cv4_arglist(t,&nparam);
            call = cv4_callconv(t);

            if (config.fulltypes == CV4)
            {
                d = debtyp_alloc(18);
                p = d.data.ptr;
                TOWORD(p,LF_MFUNCTION);
                TOWORD(p + 2,cv4_typidx(t.Tnext));
                TOWORD(p + 4,cv4_symtypidx(s.Sscope));
                TOWORD(p + 6,thisidx);
                p[8] = call;
                p[9] = 0;                               // reserved
                TOWORD(p + 10,nparam);
                TOWORD(p + 12,paramidx);
                TOLONG(p + 14,0);                       // thisadjust
            }
            else
            {
                d = debtyp_alloc(26);
                p = d.data.ptr;
                TOWORD(p,LF_MFUNCTION);
                TOLONG(p + 2,cv4_typidx(t.Tnext));
                TOLONG(p + 6,cv4_symtypidx(s.Sscope));
                TOLONG(p + 10,thisidx);
                p[14] = call;
                p[15] = 0;                              // reserved
                TOWORD(p + 16,nparam);
                TOLONG(p + 18,paramidx);
                TOLONG(p + 22,0);                       // thisadjust
            }
            return cv_debtyp(d);
        }
    }
    return cv4_typidx(s.Stype);
}

}

/***********************************
 * Return CV4 type index for a type.
 */

@trusted
uint cv4_typidx(type *t)
{   uint typidx;
    uint u;
    uint next;
    uint key;
    debtyp_t *d;
    targ_size_t size;
    tym_t tym;
    tym_t tycv;
    tym_t tymnext;
    type *tv;
    uint dt;
    uint attribute;
    ubyte call;

    //printf("cv4_typidx(%p)\n",t);
    if (!t)
        return dttab4[TYint];           // assume int
    type_debug(t);
    next = cv4_typidx(t.Tnext);
    tycv = t.Tty;
    tym = tybasic(tycv);
    tycv &= mTYconst | mTYvolatile | mTYimmutable;
    attribute = 0;
L1:
    dt = dttab4[tym];
    switch (tym)
    {
        case TYllong:
            if (t.Tnext)
                goto Ldelegate;
            assert(dt);
            typidx = dt;
            break;

        case TYullong:
            if (t.Tnext)
                goto Ldarray;
            assert(dt);
            typidx = dt;
            break;

        case TYvoid:
        case TYnoreturn:
        case TYchar:
        case TYschar:
        case TYuchar:
        case TYchar16:
        case TYshort:
        case TYushort:
        case TYint:
        case TYuint:
        case TYulong:
        case TYlong:
        case TYfloat:
        case TYdouble:
        case TYdouble_alias:
        case TYldouble:
        case TYifloat:
        case TYidouble:
        case TYildouble:
        case TYcfloat:
        case TYcdouble:
        case TYcldouble:
        case TYbool:
        case TYwchar_t:
        case TYdchar:
            assert(dt);
            typidx = dt;
            break;

        case TYnptr:
        case TYimmutPtr:
        case TYsharePtr:
        case TYrestrictPtr:
version (MARS)
{
            if (t.Tkey)
                goto Laarray;
}
            goto Lptr;
        case TYsptr:
        case TYcptr:
        case TYfgPtr:
        Lptr:
                        attribute |= I32 ? 10 : 0;      goto L2;

        case TYfptr:
        case TYvptr:    attribute |= I32 ? 11 : 1;      goto L2;
        case TYhptr:    attribute |= 2; goto L2;

        L2:
            if (config.fulltypes == CV4)
            {
                // This is a hack to duplicate bugs in VC, so that the VC
                // debugger will work.
                tymnext = t.Tnext ? t.Tnext.Tty : TYint;
                if (tymnext & (mTYconst | mTYimmutable | mTYvolatile) &&
                    !tycv &&
                    tyarithmetic(tymnext) &&
                    !(attribute & 0xE0)
                   )
                {
                    typidx = dt | dttab4[tybasic(tymnext)];
                    break;
                }
            }
            if ((next & 0xFF00) == 0 && !(attribute & 0xE0))
                typidx = next | dt;
            else
            {
                if (tycv & (mTYconst | mTYimmutable))
                    attribute |= 0x400;
                if (tycv & mTYvolatile)
                    attribute |= 0x200;
                tycv = 0;
                switch (config.fulltypes)
                {
                    case CV4:
                        d = debtyp_alloc(6);
                        TOWORD(d.data.ptr,LF_POINTER);
                        TOWORD(d.data.ptr + 2,attribute);
                        TOWORD(d.data.ptr + 4,next);
                        break;

                    case CV8:
                        d = debtyp_alloc(10);
                        TOWORD(d.data.ptr,0x1002);
                        TOLONG(d.data.ptr + 2,next);
                        // see https://github.com/Microsoft/microsoft-pdb/blob/master/include/cvinfo.h#L1514
                        // add size and pointer type (PTR_64 or PTR_NEAR32)
                        attribute |= (I64 ? (8 << 13) | 0xC : (4 << 13) | 0xA);
                        // convert reference to r-value reference to remove & from type display in debugger
                        if (attribute & 0x20)
                            attribute |= 0x80;
                        TOLONG(d.data.ptr + 6,attribute);
                        break;

                    default:
                        d = debtyp_alloc(10);
                        TOWORD(d.data.ptr,LF_POINTER);
                        TOLONG(d.data.ptr + 2,attribute);
                        TOLONG(d.data.ptr + 6,next);
                        break;
                }
                typidx = cv_debtyp(d);
            }
            break;

        Ldarray:
            switch (config.fulltypes)
            {
version (MARS)
{
                case CV8:
                {
                    typidx = cv8_darray(t, next);
                    break;
                }
}
                case CV4:
static if (1)
{
                    d = debtyp_alloc(12);
                    TOWORD(d.data.ptr, LF_OEM);
                    TOWORD(d.data.ptr + 2, OEM);
                    TOWORD(d.data.ptr + 4, 1);     // 1 = dynamic array
                    TOWORD(d.data.ptr + 6, 2);     // count of type indices to follow
                    TOWORD(d.data.ptr + 8, 0x12);  // index type, T_LONG
                    TOWORD(d.data.ptr + 10, next); // element type
}
else
{
                    d = debtyp_alloc(6);
                    TOWORD(d.data.ptr,LF_DYN_ARRAY);
                    TOWORD(d.data.ptr + 2, 0x12);  // T_LONG
                    TOWORD(d.data.ptr + 4, next);
}
                    typidx = cv_debtyp(d);
                    break;

                default:
                    assert(0);
            }

            break;

        Laarray:
version (MARS)
{
            key = cv4_typidx(t.Tkey);
            switch (config.fulltypes)
            {
                case CV8:
                    typidx = cv8_daarray(t, key, next);
                    break;

                case CV4:
static if (1)
{
                    d = debtyp_alloc(12);
                    TOWORD(d.data.ptr, LF_OEM);
                    TOWORD(d.data.ptr + 2, OEM);
                    TOWORD(d.data.ptr + 4, 2);     // 2 = associative array
                    TOWORD(d.data.ptr + 6, 2);     // count of type indices to follow
                    TOWORD(d.data.ptr + 8, key);   // key type
                    TOWORD(d.data.ptr + 10, next); // element type
}
else
{
                    d = debtyp_alloc(6);
                    TOWORD(d.data.ptr,LF_ASSOC_ARRAY);
                    TOWORD(d.data.ptr + 2, key);   // key type
                    TOWORD(d.data.ptr + 4, next);  // element type
}
                    typidx = cv_debtyp(d);
                    break;

                default:
                    assert(0);
            }
}
            break;

        Ldelegate:
            switch (config.fulltypes)
            {
version (MARS)
{
                case CV8:
                    typidx = cv8_ddelegate(t, next);
                    break;
}

                case CV4:
                    tv = type_fake(TYnptr);
                    tv.Tcount++;
                    key = cv4_typidx(tv);
                    type_free(tv);
static if (1)
{
                    d = debtyp_alloc(12);
                    TOWORD(d.data.ptr, LF_OEM);
                    TOWORD(d.data.ptr + 2, OEM);
                    TOWORD(d.data.ptr + 4, 3);     // 3 = delegate
                    TOWORD(d.data.ptr + 6, 2);     // count of type indices to follow
                    TOWORD(d.data.ptr + 8, key);   // type of 'this', which is void*
                    TOWORD(d.data.ptr + 10, next); // function type
}
else
{
                    d = debtyp_alloc(6);
                    TOWORD(d.data.ptr,LF_DELEGATE);
                    TOWORD(d.data.ptr + 2, key);   // type of 'this', which is void*
                    TOWORD(d.data.ptr + 4, next);  // function type
}
                    typidx = cv_debtyp(d);
                    break;

                default:
                    assert(0);
            }
            break;

        case TYcent:
            if (t.Tnext)
                goto Ldelegate;
            assert(dt);
            typidx = dt;
            break;

        case TYucent:
            if (t.Tnext)
                goto Ldarray;
            assert(dt);
            typidx = dt;
            break;

        case TYarray:
        {   if (t.Tflags & TFsizeunknown)
                size = 0;               // don't complain if don't know size
            else
                size = type_size(t);
        Larray:
            u = cv4_numericbytes(cast(uint)size);
            uint idxtype = I32 ? 0x12 : 0x11;  // T_LONG : T_SHORT
            if (I64)
                idxtype = 0x23;                    // T_UQUAD
            if(next == dttab4[TYvoid])    // do not encode void[n], this confuses the debugger
                next = dttab4[TYuchar];   // use ubyte instead
            switch (config.fulltypes)
            {
                case CV8:
                    d = debtyp_alloc(10 + u + 1);
                    TOWORD(d.data.ptr,0x1503);
                    TOLONG(d.data.ptr + 2,next);
                    TOLONG(d.data.ptr + 6,idxtype);
                    d.data.ptr[10 + u] = 0;             // no name
                    cv4_storenumeric(d.data.ptr + 10,cast(uint)size);
                    break;

                case CV4:
                    d = debtyp_alloc(6 + u + 1);
                    TOWORD(d.data.ptr,LF_ARRAY);
                    TOWORD(d.data.ptr + 2,next);
                    TOWORD(d.data.ptr + 4,idxtype);
                    d.data.ptr[6 + u] = 0;             // no name
                    cv4_storenumeric(d.data.ptr + 6,cast(uint)size);
                    break;

                default:
                    d = debtyp_alloc(10 + u + 1);
                    TOWORD(d.data.ptr,LF_ARRAY);
                    TOLONG(d.data.ptr + 2,next);
                    TOLONG(d.data.ptr + 6,idxtype);
                    d.data.ptr[10 + u] = 0;            // no name
                    cv4_storenumeric(d.data.ptr + 10,cast(uint)size);
                    break;
            }
            typidx = cv_debtyp(d);
            break;
        }

        case TYffunc:
        case TYfpfunc:
        case TYf16func:
        case TYfsfunc:
        case TYnsysfunc:
        case TYfsysfunc:
        case TYnfunc:
        case TYnpfunc:
        case TYnsfunc:
        case TYmfunc:
        case TYjfunc:
        case TYifunc:
        {
            param_t *p;
            uint nparam;
            idx_t paramidx;

            call = cv4_callconv(t);
            paramidx = cv4_arglist(t,&nparam);

            // Construct an LF_PROCEDURE
            switch (config.fulltypes)
            {
                case CV8:
                    d = debtyp_alloc(2 + 4 + 1 + 1 + 2 + 4);
                    TOWORD(d.data.ptr,LF_PROCEDURE_V2);
                    TOLONG(d.data.ptr + 2,next);       // return type
                    d.data.ptr[6] = call;
                    d.data.ptr[7] = 0;                 // reserved
                    TOWORD(d.data.ptr + 8,nparam);
                    TOLONG(d.data.ptr + 10,paramidx);
                    break;

                case CV4:
                    d = debtyp_alloc(2 + 2 + 1 + 1 + 2 + 2);
                    TOWORD(d.data.ptr,LF_PROCEDURE);
                    TOWORD(d.data.ptr + 2,next);               // return type
                    d.data.ptr[4] = call;
                    d.data.ptr[5] = 0;                 // reserved
                    TOWORD(d.data.ptr + 6,nparam);
                    TOWORD(d.data.ptr + 8,paramidx);
                    break;

                default:
                    d = debtyp_alloc(2 + 4 + 1 + 1 + 2 + 4);
                    TOWORD(d.data.ptr,LF_PROCEDURE);
                    TOLONG(d.data.ptr + 2,next);               // return type
                    d.data.ptr[6] = call;
                    d.data.ptr[7] = 0;                 // reserved
                    TOWORD(d.data.ptr + 8,nparam);
                    TOLONG(d.data.ptr + 10,paramidx);
                    break;
            }

            typidx = cv_debtyp(d);
            break;
        }

        case TYstruct:
        {
            if (config.fulltypes == CV8)
            {
version (MARS)
{
                typidx = cv8_fwdref(t.Ttag);
}
            }
            else
            {
                int foo = t.Ttag.Stypidx;
                typidx = cv4_struct(t.Ttag,0);
                //printf("struct '%s' %x %x\n", t.Ttag.Sident.ptr, foo, typidx);
            }
            break;
        }

        case TYenum:
            if (CPP)
            {
version (SCPP)
{
                typidx = cv4_enum(t.Ttag);
}
            }
            else
                typidx = cv4_fwdenum(t);
            break;

version (SCPP)
{
        case TYvtshape:
        {   uint count;
            ubyte *p;
            ubyte descriptor;

            count = 1 + list_nitems(t.Ttag.Sstruct.Svirtual);
            d = debtyp_alloc(4 + ((count + 1) >> 1));
            p = d.data.ptr;
            TOWORD(p,LF_VTSHAPE);
            TOWORD(p + 2,count);
            descriptor = I32 ? 0x55 : (LARGECODE ? 0x11 : 0);
            memset(p + 4,descriptor,(count + 1) >> 1);

            typidx = cv_debtyp(d);
            break;
        }

        case TYref:
        case TYnref:
        case TYfref:
            attribute |= 0x20;          // indicate reference pointer
            goto case;

        case TYmemptr:
            tym = tybasic(tym_conv(t)); // convert to C data type
            goto L1;                    // and try again
}

version (MARS)
{
        case TYref:
        case TYnref:
            attribute |= 0x20;          // indicate reference pointer
            tym = TYnptr;               // convert to C data type
            goto L1;                    // and try again
}

        case TYnullptr:
            tym = TYnptr;
            next = cv4_typidx(tstypes[TYvoid]);  // rewrite as void*
            t = tspvoid;
            goto L1;

        // vector types
        case TYfloat4:  size = 16; next = dttab4[TYfloat];  goto Larray;
        case TYdouble2: size = 16; next = dttab4[TYdouble]; goto Larray;
        case TYschar16: size = 16; next = dttab4[TYschar];  goto Larray;
        case TYuchar16: size = 16; next = dttab4[TYuchar];  goto Larray;
        case TYshort8:  size = 16; next = dttab4[TYshort];  goto Larray;
        case TYushort8: size = 16; next = dttab4[TYushort]; goto Larray;
        case TYlong4:   size = 16; next = dttab4[TYlong];   goto Larray;
        case TYulong4:  size = 16; next = dttab4[TYulong];  goto Larray;
        case TYllong2:  size = 16; next = dttab4[TYllong];  goto Larray;
        case TYullong2: size = 16; next = dttab4[TYullong]; goto Larray;

        case TYfloat8:   size = 32; next = dttab4[TYfloat];  goto Larray;
        case TYdouble4:  size = 32; next = dttab4[TYdouble]; goto Larray;
        case TYschar32:  size = 32; next = dttab4[TYschar];  goto Larray;
        case TYuchar32:  size = 32; next = dttab4[TYuchar];  goto Larray;
        case TYshort16:  size = 32; next = dttab4[TYshort];  goto Larray;
        case TYushort16: size = 32; next = dttab4[TYushort]; goto Larray;
        case TYlong8:    size = 32; next = dttab4[TYlong];   goto Larray;
        case TYulong8:   size = 32; next = dttab4[TYulong];  goto Larray;
        case TYllong4:   size = 32; next = dttab4[TYllong];  goto Larray;
        case TYullong4:  size = 32; next = dttab4[TYullong]; goto Larray;

        case TYfloat16:  size = 64; next = dttab4[TYfloat];  goto Larray;
        case TYdouble8:  size = 64; next = dttab4[TYdouble]; goto Larray;
        case TYschar64:  size = 64; next = dttab4[TYschar];  goto Larray;
        case TYuchar64:  size = 64; next = dttab4[TYuchar];  goto Larray;
        case TYshort32:  size = 64; next = dttab4[TYshort];  goto Larray;
        case TYushort32: size = 64; next = dttab4[TYushort]; goto Larray;
        case TYlong16:   size = 64; next = dttab4[TYlong];   goto Larray;
        case TYulong16:  size = 64; next = dttab4[TYulong];  goto Larray;
        case TYllong8:   size = 64; next = dttab4[TYllong];  goto Larray;
        case TYullong8:  size = 64; next = dttab4[TYullong]; goto Larray;

        default:
            debug
            WRTYxx(tym);

            assert(0);
    }

    // Add in const and/or volatile modifiers
    if (tycv & (mTYconst | mTYimmutable | mTYvolatile))
    {   uint modifier;

        modifier = (tycv & (mTYconst | mTYimmutable)) ? 1 : 0;
        modifier |= (tycv & mTYvolatile) ? 2 : 0;
        switch (config.fulltypes)
        {
            case CV8:
                d = debtyp_alloc(8);
                TOWORD(d.data.ptr,0x1001);
                TOLONG(d.data.ptr + 2,typidx);
                TOWORD(d.data.ptr + 6,modifier);
                break;

            case CV4:
                d = debtyp_alloc(6);
                TOWORD(d.data.ptr,LF_MODIFIER);
                TOWORD(d.data.ptr + 2,modifier);
                TOWORD(d.data.ptr + 4,typidx);
                break;

            default:
                d = debtyp_alloc(10);
                TOWORD(d.data.ptr,LF_MODIFIER);
                TOLONG(d.data.ptr + 2,modifier);
                TOLONG(d.data.ptr + 6,typidx);
                break;
        }
        typidx = cv_debtyp(d);
    }

    assert(typidx);
    return typidx;
}

/******************************************
 * Write out symbol s.
 */

@trusted
private void cv4_outsym(Symbol *s)
{
    uint len;
    type *t;
    uint length;
    uint u;
    tym_t tym;
    const(char)* id;
    ubyte *debsym = null;
    ubyte[64] buf = void;

    //printf("cv4_outsym(%s)\n",s.Sident.ptr);
    symbol_debug(s);
version (MARS)
{
    if (s.Sflags & SFLnodebug)
        return;
}
    t = s.Stype;
    type_debug(t);
    tym = tybasic(t.Tty);
    if (tyfunc(tym) && s.Sclass != SCtypedef)
    {   int framedatum,targetdatum,fd;
        char idfree;
        idx_t typidx;

        if (s != funcsym_p)
            return;
version (SCPP)
{
        if (CPP && isclassmember(s))            // if method
        {   Outbuffer buf2;

            param_tostring(&buf2,s.Stype);
            buf2.prependBytes(cpp_prettyident(s));
            char* s2 = buf2.toString();
            const len2 = strlen(s2);
            id = cast(char*)alloca(len2 + 1);
            assert(id);
            memcpy(cast(void*)id, s2, len2 + 1);
        }
        else
        {
            id = prettyident(s);
        }
}
else
{
        id = s.prettyIdent ? s.prettyIdent : s.Sident.ptr;
}
        len = cv_stringbytes(id);

        // Length of record
        length = 2 + 2 + 4 * 3 + _tysize[TYint] * 4 + 2 + cgcv.sz_idx + 1;
        debsym = (length + len <= (buf).sizeof) ? buf.ptr : cast(ubyte *) malloc(length + len);
        assert(debsym);
        memset(debsym,0,length + len);

        // Symbol type
        u = (s.Sclass == SCstatic) ? S_LPROC16 : S_GPROC16;
        if (I32)
            u += S_GPROC32 - S_GPROC16;
        TOWORD(debsym + 2,u);

        if (config.fulltypes == CV4)
        {
            // Offsets
            if (I32)
            {   TOLONG(debsym + 16,cast(uint)s.Ssize);           // proc length
                TOLONG(debsym + 20,cast(uint)startoffset);        // debug start
                TOLONG(debsym + 24,cast(uint)retoffset);          // debug end
                u = 28;                                 // offset to fixup
            }
            else
            {   TOWORD(debsym + 16,cast(uint)s.Ssize);           // proc length
                TOWORD(debsym + 18,cast(uint)startoffset);        // debug start
                TOWORD(debsym + 20,cast(uint)retoffset);          // debug end
                u = 22;                                 // offset to fixup
            }
            length += cv_namestring(debsym + u + _tysize[TYint] + 2 + cgcv.sz_idx + 1,id);
            typidx = cv4_symtypidx(s);
            TOIDX(debsym + u + _tysize[TYint] + 2,typidx);     // proc type
            debsym[u + _tysize[TYint] + 2 + cgcv.sz_idx] = tyfarfunc(tym) ? 4 : 0;
            TOWORD(debsym,length - 2);
        }
        else
        {
            // Offsets
            if (I32)
            {   TOLONG(debsym + 16 + cgcv.sz_idx,cast(uint)s.Ssize);             // proc length
                TOLONG(debsym + 20 + cgcv.sz_idx,cast(uint)startoffset);  // debug start
                TOLONG(debsym + 24 + cgcv.sz_idx,cast(uint)retoffset);            // debug end
                u = 28;                                         // offset to fixup
            }
            else
            {   TOWORD(debsym + 16 + cgcv.sz_idx,cast(uint)s.Ssize);             // proc length
                TOWORD(debsym + 18 + cgcv.sz_idx,cast(uint)startoffset);  // debug start
                TOWORD(debsym + 20 + cgcv.sz_idx,cast(uint)retoffset);            // debug end
                u = 22;                                         // offset to fixup
            }
            u += cgcv.sz_idx;
            length += cv_namestring(debsym + u + _tysize[TYint] + 2 + 1,id);
            typidx = cv4_symtypidx(s);
            TOIDX(debsym + 16,typidx);                  // proc type
            debsym[u + _tysize[TYint] + 2] = tyfarfunc(tym) ? 4 : 0;
            TOWORD(debsym,length - 2);
        }

        uint soffset = cast(uint)Offset(DEBSYM);
        objmod.write_bytes(SegData[DEBSYM],length,debsym);

        // Put out fixup for function start offset
        objmod.reftoident(DEBSYM,soffset + u,s,0,CFseg | CFoff);
    }
    else
    {   targ_size_t base;
        int reg;
        uint fd;
        uint idx1,idx2;
        uint value;
        uint fixoff;
        idx_t typidx;

        typidx = cv4_typidx(t);
version (MARS)
{
        id = s.prettyIdent ? s.prettyIdent : prettyident(s);
}
else
{
        id = prettyident(s);
}
        len = cast(uint)strlen(id);
        debsym = (39 + IDOHD + len <= (buf).sizeof) ? buf.ptr : cast(ubyte *) malloc(39 + IDOHD + len);
        assert(debsym);
        switch (s.Sclass)
        {
            case SCparameter:
            case SCregpar:
                if (s.Sfl == FLreg)
                {
                    s.Sfl = FLpara;
                    cv4_outsym(s);
                    s.Sfl = FLreg;
                    goto case_register;
                }
                base = Para.size - BPoff;    // cancel out add of BPoff
                goto L1;

            case SCauto:
                if (s.Sfl == FLreg)
                    goto case_register;
            case_auto:
                base = Auto.size;
            L1:
                if (s.Sscope) // local variables moved into the closure cannot be emitted directly
                    goto Lret;
                TOWORD(debsym + 2,I32 ? S_BPREL32 : S_BPREL16);
                if (config.fulltypes == CV4)
                {   TOOFFSET(debsym + 4,s.Soffset + base + BPoff);
                    TOIDX(debsym + 4 + _tysize[TYint],typidx);
                }
                else
                {   TOOFFSET(debsym + 4 + cgcv.sz_idx,s.Soffset + base + BPoff);
                    TOIDX(debsym + 4,typidx);
                }
                length = 2 + 2 + _tysize[TYint] + cgcv.sz_idx;
                length += cv_namestring(debsym + length,id);
                TOWORD(debsym,length - 2);
                break;

            case SCbprel:
                base = -BPoff;
                goto L1;

            case SCfastpar:
                if (s.Sfl != FLreg)
                {   base = Fast.size;
                    goto L1;
                }
                goto case_register;

            case SCregister:
                if (s.Sfl != FLreg)
                    goto case_auto;
                goto case_register;

            case SCpseudo:
            case_register:
                TOWORD(debsym + 2,S_REGISTER);
                reg = cv_regnum(s);
                TOIDX(debsym + 4,typidx);
                TOWORD(debsym + 4 + cgcv.sz_idx,reg);
                length = 2 * 3 + cgcv.sz_idx;
                length += 1 + cv_namestring(debsym + length,id);
                TOWORD(debsym,length - 2);
                break;

            case SCextern:
            case SCcomdef:
                // Common blocks have a non-zero Sxtrnnum and an UNKNOWN seg
                if (!(s.Sxtrnnum && s.Sseg == UNKNOWN)) // if it's not really a common block
                {
                        goto Lret;
                }
                goto case;
            case SCglobal:
            case SCcomdat:
                u = S_GDATA16;
                goto L2;

            case SCstatic:
            case SClocstat:
                u = S_LDATA16;
            L2:
                if (I32)
                    u += S_GDATA32 - S_GDATA16;
                TOWORD(debsym + 2,u);
                if (config.fulltypes == CV4)
                {
                    fixoff = 4;
                    length = 2 + 2 + _tysize[TYint] + 2;
                    TOOFFSET(debsym + fixoff,s.Soffset);
                    TOWORD(debsym + fixoff + _tysize[TYint],0);
                    TOIDX(debsym + length,typidx);
                }
                else
                {
                    fixoff = 8;
                    length = 2 + 2 + _tysize[TYint] + 2;
                    TOOFFSET(debsym + fixoff,s.Soffset);
                    TOWORD(debsym + fixoff + _tysize[TYint],0);        // segment
                    TOIDX(debsym + 4,typidx);
                }
                length += cgcv.sz_idx;
                length += cv_namestring(debsym + length,id);
                TOWORD(debsym,length - 2);
                assert(length <= 40 + len);

                if (s.Sseg == UNKNOWN || s.Sclass == SCcomdat) // if common block
                {
                    if (config.exe & EX_flat)
                    {
                        fd = 0x16;
                        idx1 = DGROUPIDX;
                        idx2 = s.Sxtrnnum;
                    }
                    else
                    {
                        fd = 0x26;
                        idx1 = idx2 = s.Sxtrnnum;
                    }
                }
                else if (s.ty() & (mTYfar | mTYcs))
                {
                    fd = 0x04;
                    idx1 = idx2 = SegData[s.Sseg].segidx;
                }
                else
                {   fd = 0x14;
                    idx1 = DGROUPIDX;
                    idx2 = SegData[s.Sseg].segidx;
                }
                /* Because of the linker limitations, the length cannot
                 * exceed 0x1000.
                 * See optlink\cv\cvhashes.asm
                 */
                assert(length <= 0x1000);
                if (idx2 != 0)
                {   uint offset = cast(uint)Offset(DEBSYM);
                    objmod.write_bytes(SegData[DEBSYM],length,debsym);
                    objmod.write_long(DEBSYM,offset + fixoff,cast(uint)s.Soffset,
                        cgcv.LCFDpointer + fd,idx1,idx2);
                }
                goto Lret;

static if (1)
{
            case SCtypedef:
                s.Stypidx = typidx;
                reset_symbuf.write((&s)[0 .. 1]);
                goto L4;

            case SCstruct:
                if (s.Sstruct.Sflags & STRnotagname)
                    goto Lret;
                goto L4;

            case SCenum:
version (SCPP)
{
                if (CPP && s.Senum.SEflags & SENnotagname)
                    goto Lret;
}
            L4:
                // Output a 'user-defined type' for the tag name
                TOWORD(debsym + 2,S_UDT);
                TOIDX(debsym + 4,typidx);
                length = 2 + 2 + cgcv.sz_idx;
                length += cv_namestring(debsym + length,id);
                TOWORD(debsym,length - 2);
                list_subtract(&cgcv.list,s);
                break;

            case SCconst:
                // The only constants are enum members
                value = cast(uint)el_tolongt(s.Svalue);
                TOWORD(debsym + 2,S_CONST);
                TOIDX(debsym + 4,typidx);
                length = 4 + cgcv.sz_idx;
                cv4_storenumeric(debsym + length,value);
                length += cv4_numericbytes(value);
                length += cv_namestring(debsym + length,id);
                TOWORD(debsym,length - 2);
                break;
}
            default:
                goto Lret;
        }
        assert(length <= 40 + len);
        objmod.write_bytes(SegData[DEBSYM],length,debsym);
    }
Lret:
    if (debsym != buf.ptr)
        free(debsym);
}

/******************************************
 * Write out any deferred symbols.
 */

@trusted
private void cv_outlist()
{
    while (cgcv.list)
        cv_outsym(cast(Symbol *) list_pop(&cgcv.list));
}

/******************************************
 * Write out symbol table for current function.
 */

@trusted
private void cv4_func(Funcsym *s, ref symtab_t symtab)
{
    int endarg;

    cv4_outsym(s);              // put out function symbol
version (MARS)
{
    __gshared Funcsym* sfunc;
    __gshared int cntOpenBlocks;
    sfunc = s;
    cntOpenBlocks = 0;

    struct cv4
    {
    nothrow:
        // record for CV record S_BLOCK32
        struct block32_data
        {
            ushort len;
            ushort id;
            uint pParent;
            uint pEnd;
            uint length;
            uint offset;
            ushort seg;
            ubyte[2] name;
        }

      extern (C++):

        static void endArgs()
        {
            __gshared ushort[2] endargs = [ 2, S_ENDARG ];
            objmod.write_bytes(SegData[DEBSYM],(endargs).sizeof,endargs.ptr);
        }
        static void beginBlock(int offset, int length)
        {
            if (++cntOpenBlocks >= 255)
                return; // optlink does not like more than 255 scope blocks

            uint soffset = cast(uint)Offset(DEBSYM);
            // parent and end to be filled by linker
            block32_data block32 = { (block32_data).sizeof - 2, S_BLOCK32, 0, 0, length, 0, 0, [ 0, '\0' ] };
            objmod.write_bytes(SegData[DEBSYM], (block32).sizeof, &block32);
            size_t offOffset = cast(char*)&block32.offset - cast(char*)&block32;
            objmod.reftoident(DEBSYM, soffset + offOffset, sfunc, offset + sfunc.Soffset, CFseg | CFoff);
        }
        static void endBlock()
        {
            if (cntOpenBlocks-- >= 255)
                return; // optlink does not like more than 255 scope blocks

            __gshared ushort[2] endargs = [ 2, S_END ];
            objmod.write_bytes(SegData[DEBSYM],(endargs).sizeof,endargs.ptr);
        }
    }

    varStats_writeSymbolTable(symtab, &cv4_outsym, &cv4.endArgs, &cv4.beginBlock, &cv4.endBlock);
}
else
{
    // Put out local symbols
    endarg = 0;
    foreach (sa; symtab[])
    {   //printf("symtab[%d] = %p\n",si,symtab[si]);
        cv4_outsym(sa);
    }
}

    // Put out function return record
    if (1)
    {   ubyte[2+2+2+1+1+4] sreturn = void;
        ushort flags;
        ubyte style;
        tym_t ty;
        tym_t tyret;
        uint u;

        u = 2+2+1;
        ty = tybasic(s.ty());

        flags = tyrevfunc(ty) ? 0 : 1;
        flags |= typfunc(ty) ? 0 : 2;
        TOWORD(sreturn.ptr + 4,flags);

        tyret = tybasic(s.Stype.Tnext.Tty);
        switch (tyret)
        {
            case TYvoid:
            default:
                style = 0;
                break;

            case TYbool:
            case TYchar:
            case TYschar:
            case TYuchar:
                sreturn[7] = 1;
                sreturn[8] = 1;         // AL
                goto L1;

            case TYwchar_t:
            case TYchar16:
            case TYshort:
            case TYushort:
                goto case_ax;

            case TYint:
            case TYuint:
            case TYsptr:
            case TYcptr:
            case TYnullptr:
            case TYnptr:
            case TYnref:
                if (I32)
                    goto case_eax;
                else
                    goto case_ax;

            case TYfloat:
            case TYifloat:
                if (config.exe & EX_flat)
                    goto case_st0;
                goto case;

            case TYlong:
            case TYulong:
            case TYdchar:
                if (I32)
                    goto case_eax;
                else
                    goto case_dxax;

            case TYfptr:
            case TYhptr:
                if (I32)
                    goto case_edxeax;
                else
                    goto case_dxax;

            case TYvptr:
                if (I32)
                    goto case_edxebx;
                else
                    goto case_dxbx;

            case TYdouble:
            case TYidouble:
            case TYdouble_alias:
                if (config.exe & EX_flat)
                    goto case_st0;
                if (I32)
                    goto case_edxeax;
                else
                    goto case_axbxcxdx;

            case TYllong:
            case TYullong:
                assert(I32);
                goto case_edxeax;

            case TYldouble:
            case TYildouble:
                goto case_st0;

            case TYcfloat:
            case TYcdouble:
            case TYcldouble:
                goto case_st01;

            case_ax:
                sreturn[7] = 1;
                sreturn[8] = 9;         // AX
                goto L1;

            case_eax:
                sreturn[7] = 1;
                sreturn[8] = 17;        // EAX
                goto L1;


            case_dxax:
                sreturn[7] = 2;
                sreturn[8] = 11;        // DX
                sreturn[9] = 9;         // AX
                goto L1;

            case_dxbx:
                sreturn[7] = 2;
                sreturn[8] = 11;        // DX
                sreturn[9] = 12;        // BX
                goto L1;

            case_axbxcxdx:
                sreturn[7] = 4;
                sreturn[8] = 9;         // AX
                sreturn[9] = 12;        // BX
                sreturn[10] = 10;       // CX
                sreturn[11] = 11;       // DX
                goto L1;

            case_edxeax:
                sreturn[7] = 2;
                sreturn[8] = 19;        // EDX
                sreturn[9] = 17;        // EAX
                goto L1;

            case_edxebx:
                sreturn[7] = 2;
                sreturn[8] = 19;        // EDX
                sreturn[9] = 20;        // EBX
                goto L1;

            case_st0:
                sreturn[7] = 1;
                sreturn[8] = 128;       // ST0
                goto L1;

            case_st01:
                sreturn[7] = 2;
                sreturn[8] = 128;       // ST0 (imaginary)
                sreturn[9] = 129;       // ST1 (real)
                goto L1;

            L1:
                style = 1;
                u += sreturn[7] + 1;
                break;
        }
        sreturn[6] = style;

        TOWORD(sreturn.ptr,u);
        TOWORD(sreturn.ptr + 2,S_RETURN);
        objmod.write_bytes(SegData[DEBSYM],u + 2,sreturn.ptr);
    }

    // Put out end scope
    {   __gshared ushort[2] endproc = [ 2,S_END ];

        objmod.write_bytes(SegData[DEBSYM],(endproc).sizeof,endproc.ptr);
    }

    cv_outlist();
}

//////////////////////////////////////////////////////////

/******************************************
 * Write out data to .OBJ file.
 */

@trusted
void cv_term()
{
    //printf("cv_term(): debtyp.length = %d\n",debtyp.length);

    segidx_t typeseg = objmod.seg_debugT();

    switch (config.fulltypes)
    {
        case CV4:
        case CVSYM:
            cv_outlist();
            goto case;
        case CV8:
            objmod.write_bytes(SegData[typeseg],4,&cgcv.signature);
            if (debtyp.length != 1 || config.fulltypes == CV8)
            {
                for (uint u = 0; u < debtyp.length; u++)
                {   debtyp_t *d = debtyp[u];

                    objmod.write_bytes(SegData[typeseg],2 + d.length,cast(char *)d + uint.sizeof);
                    debtyp_free(d);
                }
            }
            else if (debtyp.length)
            {
                debtyp_free(debtyp[0]);
            }
            break;

static if (SYMDEB_TDB)
{
        case CVTDB:
            cv_outlist();
static if (1)
{
            tdb_term();
}
else
{
        {   ubyte *buf;
            ubyte *p;
            size_t len;

            // Calculate size of buffer
            len = 4;
            for (uint u = 0; u < debtyp.length; u++)
            {   debtyp_t *d = debtyp[u];

                len += 2 + d.length;
            }

            // Allocate buffer
            buf = malloc(len);
            if (!buf)
                err_nomem();                    // out of memory

            // Fill the buffer
            TOLONG(buf,cgcv.signature);
            p = buf + 4;
            for (uint u = 0; u < debtyp.length; u++)
            {   debtyp_t *d = debtyp[u];

                len = 2 + d.length;
                memcpy(p,cast(char *)d + uint.sizeof,len);
                p += len;
            }

            tdb_write(buf,len,debtyp.length);
        }
}
            break;
}

        default:
            assert(0);
    }

    // debtyp.dtor();  // save for later
    vec_free(debtypvec);
    debtypvec = null;
}

/******************************************
 * Write out symbol table for current function.
 */

@trusted
void cv_func(Funcsym *s)
{
version (SCPP)
{
    if (errcnt)                 // if we had any errors
        return;                 // don't bother putting stuff in .OBJ file
}

    //printf("cv_func('%s')\n",s.Sident.ptr);
version (MARS)
{
    if (s.Sflags & SFLnodebug)
        return;
}
else
{
    if (CPP && s.Sfunc.Fflags & Fnodebug)     // if don't generate debug info
        return;
}
    switch (config.fulltypes)
    {
        case CV4:
        case CVSYM:
        case CVTDB:
            cv4_func(s, globsym);
            break;

        default:
            assert(0);
    }
}

/******************************************
 * Write out symbol table for current function.
 */

@trusted
void cv_outsym(Symbol *s)
{
    //printf("cv_outsym('%s')\n",s.Sident.ptr);
    symbol_debug(s);
version (MARS)
{
    if (s.Sflags & SFLnodebug)
        return;
}
    switch (config.fulltypes)
    {
        case CV4:
        case CVSYM:
        case CVTDB:
            cv4_outsym(s);
            break;

version (MARS)
{
        case CV8:
            cv8_outsym(s);
            break;
}

        default:
            assert(0);
    }
}

/******************************************
 * Return cv type index for a type.
 */

@trusted
uint cv_typidx(type *t)
{   uint ti;

    //printf("cv_typidx(%p)\n",t);
    switch (config.fulltypes)
    {
        case CV4:
        case CVTDB:
        case CVSYM:
        case CV8:
            ti = cv4_typidx(t);
            break;

        default:
            debug
            printf("fulltypes = %d\n",config.fulltypes);

            assert(0);
    }
    return ti;
}

}
