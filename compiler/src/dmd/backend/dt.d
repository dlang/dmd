/**
 * Intermediate representation for static data
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1999-2025 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
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


/**********************************************
 * Free a data definition struct.
 */

@trusted
void dt_free(dt_t* dt)
{
    if (dt)
    {
        dt_t* dtn = dt;
        while (1)
        {
            switch (dtn.dt)
            {
                case DT.abytes:
                case DT.nbytes:
                    mem_free(dtn.DTpbytes);
                    break;

                default:
                    break;
            }
            dt_t* dtnext = dtn.DTnext;
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
    dt_t* dtn;

    while (dt_freelist)
    {   dtn = dt_freelist.DTnext;
        mem_ffree(dt_freelist);
        dt_freelist = dtn;
    }
}
}

dt_t** dtend(dt_t** pdtend)
{
    while (*pdtend)
        pdtend = &((*pdtend).DTnext);
    return pdtend;
}


/*********************************
 */
void dtpatchoffset(dt_t* dt, uint offset)
{
    dt.DToffset = offset;
}

/**************************
 * Make a common block for s.
 */
void init_common(Symbol* s)
{
    //printf("init_common('%s')\n", s.Sident);

    uint size = cast(uint)type_size(s.Stype);
    if (size)
    {
        dt_t* dt = dt_calloc(DT.common);
        dt.DTazeros = size;
        s.Sdt = dt;
    }
}

/**********************************
 * Compute size of a dt
 */
uint dt_size(const(dt_t)* dtstart)
{
    uint datasize = 0;
    for (auto dt = dtstart; dt; dt = dt.DTnext)
    {
        switch (dt.dt)
        {
            case DT.abytes:
                datasize += size(dt.Dty);
                break;
            case DT.ibytes:
                datasize += dt.DTn;
                break;
            case DT.nbytes:
                datasize += dt.DTnbytes;
                break;
            case DT.azeros:
                datasize += dt.DTazeros;
                break;
            case DT.common:
                break;
            case DT.xoff:
            case DT.coff:
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
    return dt && dt.dt == DT.azeros && !dt.DTnext;
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
            case DT.abytes:
            case DT.xoff:
            case DT.coff:
                return true;

            default:
                break;
        }
    }
    return false;
}

/***********************************
 * Turn DT.azeros into DTcommon
 */

void dt2common(dt_t** pdt)
{
    assert((*pdt).dt == DT.azeros);
    (*pdt).dt = DT.common;
}

/**********************************************************/

struct DtBuilder
{
private:

    dt_t* head;
    dt_t** pTail;

public:
nothrow:
    @trusted
    this(int dummy)
    {
        pTail = &head;
    }

    /************************************
     * Useful for checking if DtBuilder got initialized.
     */
    void checkInitialized()
    {
        if (!head)
            assert(pTail == &head);
    }

    /************************************
     * Print state of DtBuilder for debugging.
     */
    void print()
    {
        debug printf("DtBuilder: %p head: %p, pTail: %p\n", &head, head, pTail);
    }

    /*************************
     * Finish and return completed data structure.
     */
    dt_t* finish()
    {
        /* Merge all the 0s at the start of the list
         * so we can later check for dtallzeros()
         */
        if (head && head.dt == DT.azeros)
        {
            while (1)
            {
                dt_t* dtn = head.DTnext;
                if (!(dtn && dtn.dt == DT.azeros))
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
    void nbytes(const(char)[] ptr)
    {
        return nbytes(cast(const(ubyte)[]) ptr);
    }

    /// ditto
    @trusted
    void nbytes(const(ubyte)[] data)
    {
        if (!data.length)
            return;

        bool allZero = true;
        foreach (i; 0 .. data.length)
        {
            if (data.ptr[i] != 0)
            {
                allZero = false;
                break;
            }
        }
        if (allZero)
            return nzeros(data.length);

        dt_t* dt;

        if (data.length < dt_t.DTibytesMax)
        {
            dt = dt_calloc(DT.ibytes);
            dt.DTn = cast(ubyte) data.length;
            memcpy(dt.DTdata.ptr, data.ptr, data.length);
        }
        else
        {
            dt = dt_calloc(DT.nbytes);
            dt.DTnbytes = data.length;
            dt.DTpbytes = cast(byte*) mem_malloc(data.length);
            memcpy(dt.DTpbytes, data.ptr, data.length);
        }

        assert(!*pTail);
        *pTail = dt;
        pTail = &dt.DTnext;
        assert(!*pTail);
    }

    /*****************************************
     * Write a reference to `data` with `nzeros` zero bytes at the end.
     * Params:
     *  ty = pointer type
     *  offset = to be added to offset of data generated
     *  data = data to write
     *  nzeros = number of zero bytes to add to the end
     *  _align = log2() of byte alignment of pointed-to data
     */
    @trusted
    void abytes(tym_t ty, uint offset, const(char)[] data, uint nzeros, ubyte _align)
    {
        dt_t* dt = dt_calloc(DT.abytes);
        const n = data.length + nzeros;
        assert(n >= data.length);      // overflow check
        dt.DTnbytes = n;
        dt.DTpbytes = cast(byte*) mem_malloc(n);
        dt.Dty = cast(ubyte)ty;
        dt.DTalign = _align;
        dt.DTabytes = offset;

        dt.DTpbytes[0 .. data.length] = cast(const(byte)[]) data[];
        if (nzeros)
            dt.DTpbytes[data.length .. data.length + nzeros] = 0;

        assert(!*pTail);
        *pTail = dt;
        pTail = &dt.DTnext;
        assert(!*pTail);
    }

    void abytes(uint offset, const(char)[] data, uint nzeros, ubyte _align)
    {
        abytes(TYnptr, offset, data, nzeros, _align);
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

        dt_t* dt = dt_calloc(DT.ibytes);
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
        dt_t* dt = dt_calloc(DT.ibytes);
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
    void nzeros(size_t size)
    {
        if (!size)
            return;
        assert(cast(int) size > 0);

        dt_t* dt = dt_calloc(DT.azeros);
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
    void xoff(Symbol* s, uint offset, tym_t ty)
    {
        dt_t* dt = dt_calloc(DT.xoff);
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
    void xoff(Symbol* s, uint offset)
    {
        xoff(s, offset, TYnptr);
    }

    /*******************************
     * Like xoff(), but returns handle with which to patch 'offset' value.
     */
    @trusted
    dt_t* xoffpatch(Symbol* s, uint offset, tym_t ty)
    {
        dt_t* dt = dt_calloc(DT.xoff);
        dt.DTsym = s;
        dt.DToffset = offset;
        dt.Dty = cast(ubyte)ty;

        dt_t** pxoff = pTail;

        assert(!*pTail);
        *pTail = dt;
        pTail = &dt.DTnext;
        assert(!*pTail);

        return* pxoff;
    }

    /*************************************
     * Create a reference to another dt.
     * Returns: the internal symbol used for the other dt
     */
    Symbol* dtoff(dt_t* dt, uint offset)
    {
        type* t = type_alloc(TYint);
        t.Tcount++;
        Symbol* s = symbol_calloc("internal");
        s.Sclass = SC.static_;
        s.Sfl = FL.extern_;
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
        dt_t* dt = dt_calloc(DT.coff);

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
    void cat(dt_t* dt)
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
        if (dtb.head) // if non-zero length
        {
            assert(!*pTail);
            *pTail = dtb.head;
            pTail = dtb.pTail; // if dtb is zero length, this will point pTail to dtb.head, oops
            assert(!*pTail);
        }
    }

    /**************************************
     * Repeat a list of dt_t's count times.
     */
    @trusted
    void repeat(dt_t* dt, size_t count)
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
            dt_t* dtp = null;
            dt_t** pdt = &dtp;
            for (size_t i = 0; i < count; ++i)
            {
                for (dt_t* dtn = dt; dtn; dtn = dtn.DTnext)
                {
                    dt_t* dtx = dt_calloc(dtn.dt);
                    *dtx = *dtn;
                    dtx.DTnext = null;
                    switch (dtx.dt)
                    {
                        case DT.abytes:
                        case DT.nbytes:
                            dtx.DTpbytes = cast(byte*) mem_malloc(dtx.DTnbytes);
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

        const n = size * count;
        assert(n >= size);
        char* p = cast(char*)mem_malloc(n);
        size_t offset = 0;

        for (dt_t* dtn = dt; dtn; dtn = dtn.DTnext)
        {
            switch (dtn.dt)
            {
                case DT.nbytes:
                    memcpy(p + offset, dtn.DTpbytes, dtn.DTnbytes);
                    offset += dtn.DTnbytes;
                    break;
                case DT.ibytes:
                    memcpy(p + offset, dtn.DTdata.ptr, dtn.DTn);
                    offset += dtn.DTn;
                    break;
                case DT.azeros:
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

        dt_t* dtx = dt_calloc(DT.nbytes);
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

private __gshared dt_t* dt_freelist;

/**********************************************
 * Allocate a data definition struct.
 */

@trusted
private dt_t* dt_calloc(DT dtx)
{
    dt_t* dt = dt_freelist;
    if (!dt)
    {
        const size_t n = 4096 / dt_t.sizeof;
        dt_t* chunk = cast(dt_t*)mem_fmalloc(n * dt_t.sizeof);
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
    dt.dt = dtx;
    return dt;
}


/******************************************
 * Temporary hack to initialize a dt_t* for C.
 */

dt_t* dt_get_nzeros(uint n)
{
    dt_t* dt = dt_calloc(DT.azeros);
    dt.DTazeros = n;
    return dt;
}
