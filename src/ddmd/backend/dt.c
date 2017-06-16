/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1984-1998 by Symantec
 *              Copyright (c) 2000-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     Distributed under the Boost Software License, Version 1.0.
 *              http://www.boost.org/LICENSE_1_0.txt
 * Source:      https://github.com/dlang/dmd/blob/master/src/ddmd/backend/dt.c
 */

#if !SPP

#include        <stdio.h>
#include        <string.h>
#include        <stdlib.h>
#include        <time.h>
#include        "cc.h"
#include        "oper.h"
#include        "global.h"
#include        "el.h"
#include        "type.h"
#include        "dt.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

static dt_t *dt_freelist;

/**********************************************
 * Allocate a data definition struct.
 */

static dt_t *dt_calloc(int dtx)
{
    dt_t *dt = dt_freelist;
    if (!dt)
    {
        const size_t n = 4096 / sizeof(dt_t);
        dt_t *chunk = (dt_t *)mem_fmalloc(n * sizeof(dt_t));
        for (size_t i = 0; i < n - 1; ++i)
        {
            chunk[i].DTnext = &chunk[i + 1];
        }
        chunk[n - 1].DTnext = NULL;
        dt_freelist = chunk;
        dt = chunk;
    }

    dt_freelist = dt->DTnext;
#ifdef DEBUG
    memset(dt, 0xBE, sizeof(*dt));
#endif
    dt->DTnext = NULL;
    dt->dt = dtx;
    return dt;
}

/**********************************************
 * Free a data definition struct.
 */

void dt_free(dt_t *dt)
{
    if (dt)
    {
        dt_t *dtn = dt;
        while (1)
        {
            switch (dtn->dt)
            {
                case DT_abytes:
                case DT_nbytes:
                    mem_free(dtn->DTpbytes);
                    break;
            }
            dt_t *dtnext = dtn->DTnext;
            if (!dtnext)
                break;
            dtn = dtnext;
        }
        dtn->DTnext = dt_freelist;
        dt_freelist = dt;
    }
}

/*********************************
 * Free free list.
 */

void dt_term()
{
#if 0 && TERMCODE
    dt_t *dtn;

    while (dt_freelist)
    {   dtn = dt_freelist->DTnext;
        mem_ffree(dt_freelist);
        dt_freelist = dtn;
    }
#endif
}

dt_t **dtend(dt_t **pdtend)
{
    while (*pdtend)
        pdtend = &((*pdtend)->DTnext);
    return pdtend;
}


/*********************************
 */
void dtpatchoffset(dt_t *dt, unsigned offset)
{
    dt->DToffset = offset;
}

/**************************
 * Make a common block for s.
 */

void init_common(symbol *s)
{
    //printf("init_common('%s')\n", s->Sident);

    unsigned size = type_size(s->Stype);
    if (size)
    {
        dt_t *dt = dt_calloc(DT_common);
        dt->DTazeros = size;
        s->Sdt = dt;
    }
}

/**********************************
 * Compute size of a dt
 */

unsigned dt_size(const dt_t *dtstart)
{
    unsigned datasize = 0;
    for (const dt_t *dt = dtstart; dt; dt = dt->DTnext)
    {
        switch (dt->dt)
        {   case DT_abytes:
                datasize += size(dt->Dty);
                break;
            case DT_ibytes:
                datasize += dt->DTn;
                break;
            case DT_nbytes:
                datasize += dt->DTnbytes;
                break;
            case DT_azeros:
                datasize += dt->DTazeros;
                break;
            case DT_common:
                break;
            case DT_xoff:
            case DT_coff:
                datasize += size(dt->Dty);
                break;
            default:
#ifdef DEBUG
                dbg_printf("dt = %p, dt = %d\n",dt,dt->dt);
#endif
                assert(0);
        }
    }
    return datasize;
}

/************************************
 * Return true if dt is all zeros.
 */

bool dtallzeros(const dt_t *dt)
{
    return dt->dt == DT_azeros && !dt->DTnext;
}

/************************************
 * Return true if dt contains pointers (requires relocations).
 */

bool dtpointers(const dt_t *dtstart)
{
    for (const dt_t *dt = dtstart; dt; dt = dt->DTnext)
    {
        switch (dt->dt)
        {
        case DT_abytes:
        case DT_xoff:
        case DT_coff:
            return true;
        }
    }
    return false;
}

/***********************************
 * Turn DT_azeros into DTcommon
 */

void dt2common(dt_t **pdt)
{
    assert((*pdt)->dt == DT_azeros);
    (*pdt)->dt = DT_common;
}

/**************************** DtBuilder implementation ************************/

DtBuilder::DtBuilder()
{
    head = NULL;
    pTail = &head;
}

/*************************
 * Finish and return completed data structure.
 */
dt_t *DtBuilder::finish()
{
    /* Merge all the 0s at the start of the list
     * so we can later check for dtallzeros()
     */
    if (head && head->dt == DT_azeros)
    {
        while (1)
        {
            dt_t *dtn = head->DTnext;
            if (!(dtn && dtn->dt == DT_azeros))
                break;

            // combine head and dtn
            head->DTazeros += dtn->DTazeros;
            head->DTnext = dtn->DTnext;
            dtn->DTnext = NULL;
            dt_free(dtn);
        }
    }

    return head;
}

/***********************9
 * Append data represented by ptr[0..size]
 */
void DtBuilder::nbytes(unsigned size, const char *ptr)
{
    if (!size)
        return;

    dt_t *dt;

    if (size < DTibytesMax)
    {   dt = dt_calloc(DT_ibytes);
        dt->DTn = size;
        memcpy(dt->DTdata,ptr,size);
    }
    else
    {
        dt = dt_calloc(DT_nbytes);
        dt->DTnbytes = size;
        dt->DTpbytes = (char *) MEM_PH_MALLOC(size);
        memcpy(dt->DTpbytes,ptr,size);
    }

    assert(!*pTail);
    *pTail = dt;
    pTail = &dt->DTnext;
    assert(!*pTail);
}

/*****************************************
 * Write a reference to the data ptr[0..size+nzeros]
 */
void DtBuilder::abytes(tym_t ty, unsigned offset, unsigned size, const char *ptr, unsigned nzeros)
{
    dt_t *dt = dt_calloc(DT_abytes);
    dt->DTnbytes = size + nzeros;
    dt->DTpbytes = (char *) MEM_PH_MALLOC(size + nzeros);
    dt->Dty = ty;
    dt->DTabytes = offset;
    memcpy(dt->DTpbytes,ptr,size);
    if (nzeros)
        memset(dt->DTpbytes + size, 0, nzeros);

    assert(!*pTail);
    *pTail = dt;
    pTail = &dt->DTnext;
    assert(!*pTail);
}

void DtBuilder::abytes(unsigned offset, unsigned size, const char *ptr, unsigned nzeros)
{
    abytes(TYnptr, offset, size, ptr, nzeros);
}

/**************************************
 * Write 4 bytes of value.
 */
void DtBuilder::dword(int value)
{
    if (value == 0)
    {
        nzeros(4);
        return;
    }

    dt_t *dt = dt_calloc(DT_ibytes);
    dt->DTn = 4;

    union { char* cp; int* lp; } u;
    u.cp = dt->DTdata;
    *u.lp = value;

    assert(!*pTail);
    *pTail = dt;
    pTail = &dt->DTnext;
    assert(!*pTail);
}

/***********************
 * Write a size_t value.
 */
void DtBuilder::size(d_ulong value)
{
    if (value == 0)
    {
        nzeros(NPTRSIZE);
        return;
    }
    dt_t *dt = dt_calloc(DT_ibytes);
    dt->DTn = NPTRSIZE;

    union { char* cp; int* lp; } u;
    u.cp = dt->DTdata;
    *u.lp = value;
    if (NPTRSIZE == 8)
        u.lp[1] = value >> 32;

    assert(!*pTail);
    *pTail = dt;
    pTail = &dt->DTnext;
    assert(!*pTail);
}

/***********************
 * Write a bunch of zeros
 */
void DtBuilder::nzeros(unsigned size)
{
    if (!size)
        return;
    assert((long) size > 0);

    dt_t *dt = dt_calloc(DT_azeros);
    dt->DTazeros = size;

    assert(!*pTail);
    *pTail = dt;
    pTail = &dt->DTnext;
    assert(!*pTail);
}

/*************************
 * Write a reference to s+offset
 */
void DtBuilder::xoff(Symbol *s, unsigned offset, tym_t ty)
{
    dt_t *dt = dt_calloc(DT_xoff);
    dt->DTsym = s;
    dt->DToffset = offset;
    dt->Dty = ty;

    assert(!*pTail);
    *pTail = dt;
    pTail = &dt->DTnext;
    assert(!*pTail);
}

/******************************
 * Create reference to s+offset
 */
void DtBuilder::xoff(Symbol *s, unsigned offset)
{
    xoff(s, offset, TYnptr);
}

/*******************************
 * Like xoff(), but returns handle with which to patch 'offset' value.
 */
dt_t *DtBuilder::xoffpatch(Symbol *s, unsigned offset, tym_t ty)
{
    dt_t *dt = dt_calloc(DT_xoff);
    dt->DTsym = s;
    dt->DToffset = offset;
    dt->Dty = ty;

    dt_t **pxoff = pTail;

    assert(!*pTail);
    *pTail = dt;
    pTail = &dt->DTnext;
    assert(!*pTail);

    return *pxoff;
}

/*************************************
 * Create a reference to another dt.
 * Returns: the internal symbol used for the other dt
 */
Symbol *DtBuilder::dtoff(dt_t *dt, unsigned offset)
{
    type *t = type_alloc(TYint);
    t->Tcount++;
    Symbol *s = symbol_calloc("internal");
    s->Sclass = SCstatic;
    s->Sfl = FLextern;
    s->Sflags |= SFLnodebug;
    s->Stype = t;
    s->Sdt = dt;
    outdata(s);

    xoff(s, offset);
    return s;
}

/********************************
 * Write reference to offset in code segment.
 */
void DtBuilder::coff(unsigned offset)
{
    dt_t *dt = dt_calloc(DT_coff);
#if TARGET_SEGMENTED
    dt->Dty = TYcptr;
#else
    dt->Dty = TYnptr;
#endif
    dt->DToffset = offset;

    assert(!*pTail);
    *pTail = dt;
    pTail = &dt->DTnext;
    assert(!*pTail);
}


/**********************
 * Append dt to data.
 */
void DtBuilder::cat(dt_t *dt)
{
    assert(!*pTail);
    *pTail = dt;
    pTail = &dt->DTnext;
    while (*pTail)
        pTail = &((*pTail)->DTnext);
    assert(!*pTail);
}

/**********************
 * Append dtb to data.
 */
void DtBuilder::cat(DtBuilder *dtb)
{
    assert(!*pTail);
    *pTail = dtb->head;
    pTail = dtb->pTail;
    assert(!*pTail);
}

/**************************************
 * Repeat a list of dt_t's count times.
 */
void DtBuilder::repeat(dt_t *dt, d_size_t count)
{
    if (!count)
        return;

    unsigned size = dt_size(dt);
    if (!size)
        return;

    if (dtallzeros(dt))
    {
        if (head && dtallzeros(head))
            head->DTazeros += size * count;
        else
            nzeros(size * count);
        return;
    }

    if (dtpointers(dt))
    {
        dt_t *dtp = NULL;
        dt_t **pdt = &dtp;
        for (size_t i = 0; i < count; ++i)
        {
            for (dt_t *dtn = dt; dtn; dtn = dtn->DTnext)
            {
                dt_t *dtx = dt_calloc(dtn->dt);
                *dtx = *dtn;
                dtx->DTnext = NULL;
                switch (dtx->dt)
                {
                    case DT_abytes:
                    case DT_nbytes:
                        dtx->DTpbytes = (char *) MEM_PH_MALLOC(dtx->DTnbytes);
                        memcpy(dtx->DTpbytes, dtn->DTpbytes, dtx->DTnbytes);
                        break;
                }

                *pdt = dtx;
                pdt = &dtx->DTnext;
            }
        }
        assert(!*pTail);
        *pTail = dtp;
        assert(*pdt == NULL);
        pTail = pdt;
        return;
    }

    char *p = (char *)MEM_PH_MALLOC(size * count);
    size_t offset = 0;

    for (dt_t *dtn = dt; dtn; dtn = dtn->DTnext)
    {
        switch (dtn->dt)
        {
            case DT_nbytes:
                memcpy(p + offset, dtn->DTpbytes, dtn->DTnbytes);
                offset += dtn->DTnbytes;
                break;
            case DT_ibytes:
                memcpy(p + offset, dtn->DTdata, dtn->DTn);
                offset += dtn->DTn;
                break;
            case DT_azeros:
                memset(p + offset, 0, dtn->DTazeros);
                offset += dtn->DTazeros;
                break;
            default:
#ifdef DEBUG
                printf("dt = %p, dt = %d\n",dt,dt->dt);
#endif
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
    dtx->DTnbytes = size * count;
    dtx->DTpbytes = p;


    assert(!*pTail);
    *pTail = dtx;
    pTail = &dtx->DTnext;
    assert(!*pTail);
}

/***************************
 * Return size of data.
 */
unsigned DtBuilder::length()
{
    return dt_size(head);
}

/************************
 * Return true if size of data is 0.
 */
bool DtBuilder::isZeroLength()
{
    return head == NULL;
}

#endif /* !SPP */
