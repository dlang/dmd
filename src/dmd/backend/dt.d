/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      https://github.com/dlang/dmd/blob/master/src/dmd/backend/dt.d
 * Documentation:  https://dlang.org/phobos/dmd_backend_dt.html
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/backend/dt.d
 */

module dmd.backend.dt;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.global;
import dmd.backend.mem;
import dmd.backend.ty;
import dmd.backend.type;

nothrow:
@nogc:
@safe:

extern (C++):

/**********************************************
 * Free a data definition struct.
 */

@trusted
void dt_free(dt_t *dt)
{
    if (dt)
    {
        dt_t *dtn = dt;
        while (1)
        {
            switch (dtn.dt)
            {
                case DT_abytes:
                case DT_nbytes:
                    mem_free(dtn.DTpbytes);
                    break;

                default:
                    break;
            }
            dt_t *dtnext = dtn.DTnext;
            if (!dtnext)
                break;
            dtn = dtnext;
        }
        dtn.DTnext = dt_freelist;
        dt_freelist = dt;
    }
}

/*********************************
 * Free free list.
 */

void dt_term()
{
static if (0 && TERMCODE)
{
    dt_t *dtn;

    while (dt_freelist)
    {   dtn = dt_freelist.DTnext;
        mem_ffree(dt_freelist);
        dt_freelist = dtn;
    }
}
}

dt_t **dtend(dt_t **pdtend)
{
    while (*pdtend)
        pdtend = &((*pdtend).DTnext);
    return pdtend;
}


/*********************************
 */
void dtpatchoffset(dt_t *dt, uint offset)
{
    dt.DToffset = offset;
}

/**************************
 * Make a common block for s.
 */

@trusted
void init_common(Symbol *s)
{
    //printf("init_common('%s')\n", s.Sident);

    uint size = cast(uint)type_size(s.Stype);
    if (size)
    {
        dt_t *dt = dt_calloc(DT_common);
        dt.DTazeros = size;
        s.Sdt = dt;
    }
}

/**********************************
 * Compute size of a dt
 */

@trusted
uint dt_size(const(dt_t)* dtstart)
{
    uint datasize = 0;
    for (auto dt = dtstart; dt; dt = dt.DTnext)
    {
        switch (dt.dt)
        {
            case DT_abytes:
                datasize += size(dt.Dty);
                break;
            case DT_ibytes:
                datasize += dt.DTn;
                break;
            case DT_nbytes:
                datasize += dt.DTnbytes;
                break;
            case DT_azeros:
                datasize += dt.DTazeros;
                break;
            case DT_common:
                break;
            case DT_xoff:
            case DT_coff:
                datasize += size(dt.Dty);
                break;
            default:
                debug printf("dt = %p, dt = %d\n",dt,dt.dt);
                assert(0);
        }
    }
    return datasize;
}

/************************************
 * Return true if dt is all zeros.
 */

bool dtallzeros(const(dt_t)* dt)
{
    return dt.dt == DT_azeros && !dt.DTnext;
}

/************************************
 * Return true if dt contains pointers (requires relocations).
 */

bool dtpointers(const(dt_t)* dtstart)
{
    for (auto dt = dtstart; dt; dt = dt.DTnext)
    {
        switch (dt.dt)
        {
            case DT_abytes:
            case DT_xoff:
            case DT_coff:
                return true;

            default:
                break;
        }
    }
    return false;
}

/***********************************
 * Turn DT_azeros into DTcommon
 */

void dt2common(dt_t **pdt)
{
    assert((*pdt).dt == DT_azeros);
    (*pdt).dt = DT_common;
}

/**********************************************************/

struct DtBuilder
{
private:

    dt_t* head;
    dt_t** pTail;

public:
nothrow:
@nogc:
    @trusted
    this(int dummy)
    {
        pTail = &head;
    }

    /*************************
     * Finish and return completed data structure.
     */
    dt_t *finish()
    {
        /* Merge all the 0s at the start of the list
         * so we can later check for dtallzeros()
         */
        if (head && head.dt == DT_azeros)
        {
            while (1)
            {
                dt_t *dtn = head.DTnext;
                if (!(dtn && dtn.dt == DT_azeros))
                    break;

                // combine head and dtn
                head.DTazeros += dtn.DTazeros;
                head.DTnext = dtn.DTnext;
                dtn.DTnext = null;
                dt_free(dtn);
            }
        }

        return head;
    }

    /***********************
     * Append data represented by ptr[0..size]
     */
    @trusted
    void nbytes(uint size, const(char)* ptr)
    {
        if (!size)
            return;

        dt_t *dt;

        if (size < dt_t.DTibytesMax)
        {   dt = dt_calloc(DT_ibytes);
            dt.DTn = cast(ubyte)size;
            memcpy(dt.DTdata.ptr,ptr,size);
        }
        else
        {
            dt = dt_calloc(DT_nbytes);
            dt.DTnbytes = size;
            dt.DTpbytes = cast(byte *) mem_malloc(size);
            memcpy(dt.DTpbytes,ptr,size);
        }

        assert(!*pTail);
        *pTail = dt;
        pTail = &dt.DTnext;
        assert(!*pTail);
    }

    /*****************************************
     * Write a reference to the data ptr[0..size+nzeros]
     * Params:
     *  ty = pointer type
     *  offset = to be added to offset of data generated
     *  size = number of bytes pointed to by ptr
     *  ptr = points to data bytes
     *  nzeros = number of zero bytes to add to the end
     *  _align = alignment of pointed-to data
     */
    @trusted
    void abytes(tym_t ty, uint offset, uint size, const(char)* ptr, uint nzeros, ubyte _align)
    {
        dt_t *dt = dt_calloc(DT_abytes);
        dt.DTnbytes = size + nzeros;
        dt.DTpbytes = cast(byte *) mem_malloc(size + nzeros);
        dt.Dty = cast(ubyte)ty;
        dt.DTalign = _align;
        dt.DTabytes = offset;
        memcpy(dt.DTpbytes,ptr,size);
        if (nzeros)
            memset(dt.DTpbytes + size, 0, nzeros);

        assert(!*pTail);
        *pTail = dt;
        pTail = &dt.DTnext;
        assert(!*pTail);
    }

    void abytes(uint offset, uint size, const(char)* ptr, uint nzeros, ubyte _align)
    {
        abytes(TYnptr, offset, size, ptr, nzeros, _align);
    }

    /**************************************
     * Write 4 bytes of value.
     */
    @trusted
    void dword(int value)
    {
        if (value == 0)
        {
            nzeros(4);
            return;
        }

        dt_t *dt = dt_calloc(DT_ibytes);
        dt.DTn = 4;

        union U { char* cp; int* lp; }
        U u = void;
        u.cp = cast(char*)dt.DTdata.ptr;
        *u.lp = value;

        assert(!*pTail);
        *pTail = dt;
        pTail = &dt.DTnext;
        assert(!*pTail);
    }

    /***********************
     * Write a size_t value.
     */
    @trusted
    void size(ulong value)
    {
        if (value == 0)
        {
            nzeros(_tysize[TYnptr]);
            return;
        }
        dt_t *dt = dt_calloc(DT_ibytes);
        dt.DTn = _tysize[TYnptr];

        union U { char* cp; int* lp; }
        U u = void;
        u.cp = cast(char*)dt.DTdata.ptr;
        *u.lp = cast(int)value;
        if (_tysize[TYnptr] == 8)
            u.lp[1] = cast(int)(value >> 32);

        assert(!*pTail);
        *pTail = dt;
        pTail = &dt.DTnext;
        assert(!*pTail);
    }

    /***********************
     * Write a bunch of zeros
     */
    void nzeros(uint size)
    {
        if (!size)
            return;
        assert(cast(int) size > 0);

        dt_t *dt = dt_calloc(DT_azeros);
        dt.DTazeros = size;

        assert(!*pTail);
        *pTail = dt;
        pTail = &dt.DTnext;
        assert(!*pTail);
    }

    /*************************
     * Write a reference to s+offset
     */
    @trusted
    void xoff(Symbol *s, uint offset, tym_t ty)
    {
        dt_t *dt = dt_calloc(DT_xoff);
        dt.DTsym = s;
        dt.DToffset = offset;
        dt.Dty = cast(ubyte)ty;

        assert(!*pTail);
        *pTail = dt;
        pTail = &dt.DTnext;
        assert(!*pTail);
    }

    /******************************
     * Create reference to s+offset
     */
    void xoff(Symbol *s, uint offset)
    {
        xoff(s, offset, TYnptr);
    }

    /*******************************
     * Like xoff(), but returns handle with which to patch 'offset' value.
     */
    @trusted
    dt_t *xoffpatch(Symbol *s, uint offset, tym_t ty)
    {
        dt_t *dt = dt_calloc(DT_xoff);
        dt.DTsym = s;
        dt.DToffset = offset;
        dt.Dty = cast(ubyte)ty;

        dt_t **pxoff = pTail;

        assert(!*pTail);
        *pTail = dt;
        pTail = &dt.DTnext;
        assert(!*pTail);

        return *pxoff;
    }

    /*************************************
     * Create a reference to another dt.
     * Returns: the internal symbol used for the other dt
     */
    @trusted
    Symbol *dtoff(dt_t *dt, uint offset)
    {
        type *t = type_alloc(TYint);
        t.Tcount++;
        Symbol *s = symbol_calloc("internal");
        s.Sclass = SCstatic;
        s.Sfl = FLextern;
        s.Sflags |= SFLnodebug;
        s.Stype = t;
        s.Sdt = dt;
        outdata(s);

        xoff(s, offset);
        return s;
    }

    /********************************
     * Write reference to offset in code segment.
     */
    @trusted
    void coff(uint offset)
    {
        dt_t *dt = dt_calloc(DT_coff);

        if (config.exe & EX_segmented)
            dt.Dty = TYcptr;
        else
            dt.Dty = TYnptr;

        dt.DToffset = offset;

        assert(!*pTail);
        *pTail = dt;
        pTail = &dt.DTnext;
        assert(!*pTail);
    }


    /**********************
     * Append dt to data.
     */
    void cat(dt_t *dt)
    {
        assert(!*pTail);
        *pTail = dt;
        pTail = &dt.DTnext;
        while (*pTail)
            pTail = &((*pTail).DTnext);
        assert(!*pTail);
    }

    /**********************
     * Append dtb to data.
     */
    void cat(ref DtBuilder dtb)
    {
        assert(!*pTail);
        *pTail = dtb.head;
        pTail = dtb.pTail;
        assert(!*pTail);
    }

    /**************************************
     * Repeat a list of dt_t's count times.
     */
    @trusted
    void repeat(dt_t *dt, size_t count)
    {
        if (!count)
            return;

        uint size = dt_size(dt);
        if (!size)
            return;

        if (dtallzeros(dt))
        {
            if (head && dtallzeros(head))
                head.DTazeros += size * count;
            else
                nzeros(cast(uint)(size * count));
            return;
        }

        if (dtpointers(dt))
        {
            dt_t *dtp = null;
            dt_t **pdt = &dtp;
            for (size_t i = 0; i < count; ++i)
            {
                for (dt_t *dtn = dt; dtn; dtn = dtn.DTnext)
                {
                    dt_t *dtx = dt_calloc(dtn.dt);
                    *dtx = *dtn;
                    dtx.DTnext = null;
                    switch (dtx.dt)
                    {
                        case DT_abytes:
                        case DT_nbytes:
                            dtx.DTpbytes = cast(byte *) mem_malloc(dtx.DTnbytes);
                            memcpy(dtx.DTpbytes, dtn.DTpbytes, dtx.DTnbytes);
                            break;

                        default:
                            break;
                    }

                    *pdt = dtx;
                    pdt = &dtx.DTnext;
                }
            }
            assert(!*pTail);
            *pTail = dtp;
            assert(*pdt == null);
            pTail = pdt;
            return;
        }

        char *p = cast(char *)mem_malloc(size * count);
        size_t offset = 0;

        for (dt_t *dtn = dt; dtn; dtn = dtn.DTnext)
        {
            switch (dtn.dt)
            {
                case DT_nbytes:
                    memcpy(p + offset, dtn.DTpbytes, dtn.DTnbytes);
                    offset += dtn.DTnbytes;
                    break;
                case DT_ibytes:
                    memcpy(p + offset, dtn.DTdata.ptr, dtn.DTn);
                    offset += dtn.DTn;
                    break;
                case DT_azeros:
                    memset(p + offset, 0, cast(uint)dtn.DTazeros);
                    offset += dtn.DTazeros;
                    break;
                default:
                    debug printf("dt = %p, dt = %d\n",dt,dt.dt);
                    assert(0);
            }
        }
        assert(offset == size);

        for (size_t i = 1; i < count; ++i)
        {
            memcpy(p + offset, p, size);
            offset += size;
        }

        dt_t *dtx = dt_calloc(DT_nbytes);
        dtx.DTnbytes = cast(uint)(size * count);
        dtx.DTpbytes = cast(byte*)p;


        assert(!*pTail);
        *pTail = dtx;
        pTail = &dtx.DTnext;
        assert(!*pTail);
    }

    /***************************
     * Return size of data.
     */
    uint length()
    {
        return dt_size(head);
    }

    /************************
     * Return true if size of data is 0.
     */
    bool isZeroLength()
    {
        return head == null;
    }
}

private __gshared dt_t *dt_freelist;

/**********************************************
 * Allocate a data definition struct.
 */

@trusted
private dt_t *dt_calloc(int dtx)
{
    dt_t *dt = dt_freelist;
    if (!dt)
    {
        const size_t n = 4096 / dt_t.sizeof;
        dt_t *chunk = cast(dt_t *)mem_fmalloc(n * dt_t.sizeof);
        for (size_t i = 0; i < n - 1; ++i)
        {
            chunk[i].DTnext = &chunk[i + 1];
        }
        chunk[n - 1].DTnext = null;
        dt_freelist = chunk;
        dt = chunk;
    }

    dt_freelist = dt.DTnext;
    debug memset(dt, 0xBE, (*dt).sizeof);
    dt.DTnext = null;
    dt.dt = cast(char)dtx;
    return dt;
}


/******************************************
 * Temporary hack to initialize a dt_t* for C.
 */

dt_t* dt_get_nzeros(uint n)
{
    dt_t *dt = dt_calloc(DT_azeros);
    dt.DTazeros = n;
    return dt;
}
