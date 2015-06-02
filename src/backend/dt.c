// Copyright (C) 1984-1998 by Symantec
// Copyright (C) 2000-2013 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in backendlicense.txt
 * For any other uses, please contact Digital Mars.
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
    dt_t *dt;
    static dt_t dtzero;

    if (dt_freelist)
    {
        dt = dt_freelist;
        dt_freelist = dt->DTnext;
        *dt = dtzero;
    }
    else
        dt = (dt_t *) mem_fcalloc(sizeof(dt_t));
    dt->dt = dtx;
    return dt;
}

/**********************************************
 * Free a data definition struct.
 */

void dt_free(dt_t *dt)
{   dt_t *dtn;

    for (; dt; dt = dtn)
    {
        switch (dt->dt)
        {
            case DT_abytes:
            case DT_nbytes:
                mem_free(dt->DTpbytes);
                break;
        }
        dtn = dt->DTnext;
        dt->DTnext = dt_freelist;
        dt_freelist = dt;
    }
}

/*********************************
 * Free free list.
 */

void dt_term()
{
#if TERMCODE
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

/**********************
 * Construct a DT_azeros record, and return it.
 * Increment dsout.
 */

dt_t **dtnzeros(dt_t **pdtend,unsigned size)
{   dt_t *dt;

    //printf("dtnzeros(x%x)\n",size);
    assert((long) size >= 0);
    while (*pdtend)
        pdtend = &((*pdtend)->DTnext);
    if (size)
    {   dt = dt_calloc(DT_azeros);
        dt->DTazeros = size;
        *pdtend = dt;
        pdtend = &dt->DTnext;
#if SCPP
        dsout += size;
#endif
    }
    return pdtend;
}

/**********************
 * Construct a DTsymsize record.
 */

void dtsymsize(symbol *s)
{
    symbol_debug(s);
    s->Sdt = dt_calloc(DT_symsize);
}

/**********************
 * Construct a DTnbytes record, and return it.
 */

dt_t ** dtnbytes(dt_t **pdtend,unsigned size,const char *ptr)
{   dt_t *dt;

    while (*pdtend)
        pdtend = &((*pdtend)->DTnext);
    if (size)
    {
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
        *pdtend = dt;
        pdtend = &dt->DTnext;
    }
    return pdtend;
}

/**********************
 * Construct a DTabytes record, and return it.
 */

dt_t **dtabytes(dt_t **pdtend, unsigned offset, unsigned size, const char *ptr)
{
    return dtabytes(pdtend, TYnptr, offset, size, ptr);
}

dt_t **dtabytes(dt_t **pdtend,tym_t ty, unsigned offset, unsigned size, const char *ptr)
{   dt_t *dt;

    while (*pdtend)
        pdtend = &((*pdtend)->DTnext);

    dt = dt_calloc(DT_abytes);
    dt->DTnbytes = size;
    dt->DTpbytes = (char *) MEM_PH_MALLOC(size);
    dt->Dty = ty;
    dt->DTabytes = offset;
    memcpy(dt->DTpbytes,ptr,size);

    *pdtend = dt;
    pdtend = &dt->DTnext;
    return pdtend;
}

/**********************
 * Construct a DTibytes record, and return it.
 */

dt_t ** dtdword(dt_t **pdtend, int value)
{   dt_t *dt;

    while (*pdtend)
        pdtend = &((*pdtend)->DTnext);
    dt = dt_calloc(DT_ibytes);
    dt->DTn = 4;

    union { char* cp; int* lp; } u;
    u.cp = dt->DTdata;
    *u.lp = value;

    *pdtend = dt;
    pdtend = &dt->DTnext;
    return pdtend;
}

dt_t ** dtsize_t(dt_t **pdtend, unsigned long long value)
{   dt_t *dt;

    while (*pdtend)
        pdtend = &((*pdtend)->DTnext);
    dt = dt_calloc(DT_ibytes);
    dt->DTn = NPTRSIZE;

    union { char* cp; int* lp; } u;
    u.cp = dt->DTdata;
    *u.lp = value;
    if (NPTRSIZE == 8)
        u.lp[1] = value >> 32;

    *pdtend = dt;
    pdtend = &dt->DTnext;
    return pdtend;
}

/**********************
 * Concatenate two dt_t's.
 */

dt_t ** dtcat(dt_t **pdtend,dt_t *dt)
{
    while (*pdtend)
        pdtend = &((*pdtend)->DTnext);
    *pdtend = dt;
    pdtend = &dt->DTnext;
    return pdtend;
}

/**********************
 * Construct a DTcoff record, and return it.
 */

dt_t ** dtcoff(dt_t **pdtend,unsigned offset)
{   dt_t *dt;

    while (*pdtend)
        pdtend = &((*pdtend)->DTnext);
    dt = dt_calloc(DT_coff);
#if TARGET_SEGMENTED
    dt->Dty = TYcptr;
#else
    dt->Dty = TYnptr;
#endif
    dt->DToffset = offset;
    *pdtend = dt;
    pdtend = &dt->DTnext;
    return pdtend;
}

/**********************
 * Construct a DTxoff record, and return it.
 */

dt_t ** dtxoff(dt_t **pdtend,symbol *s,unsigned offset)
{
    return dtxoff(pdtend, s, offset, TYnptr);
}

dt_t ** dtxoff(dt_t **pdtend,symbol *s,unsigned offset,tym_t ty)
{   dt_t *dt;

    symbol_debug(s);
    while (*pdtend)
        pdtend = &((*pdtend)->DTnext);
    dt = dt_calloc(DT_xoff);
    dt->DTsym = s;
    dt->DToffset = offset;
    dt->Dty = ty;
    *pdtend = dt;
    pdtend = &dt->DTnext;
    return pdtend;
}

/*************************************
 * Create a reference to another dt.
 */
dt_t **dtdtoff(dt_t **pdtend, dt_t *dt, unsigned offset)
{
    type *t = type_alloc(TYint);
    t->Tcount++;
    Symbol *s = symbol_calloc("internal");
    s->Sclass = SCstatic;
    s->Sfl = FLextern;
    s->Sflags |= SFLnodebug;
    s->Stype = t;
    s->Sdt = dt;
    slist_add(s);
    outdata(s);
    return dtxoff(pdtend, s, offset);
}

/**************************
 * 'Optimize' a list of dt_t's.
 * (Try to collapse it into one DT_azeros object.)
 */

void dt_optimize(dt_t *dt)
{   dt_t *dtn;

    if (dt)
    {   for (; 1; dt = dtn)
        {
            dtn = dt->DTnext;
            if (!dtn)
                break;
            if (dt->dt == DT_azeros)
            {
                if (dtn->dt == DT_azeros)
                {
                    dt->DTazeros += dtn->DTazeros;
                    dt->dt = DT_azeros;
                    dt->DTnext = dtn->DTnext;
                    dtn->DTnext = NULL;
                    dt_free(dtn);
                    dtn = dt;
                }
            }
        }
    }
}

/**************************
 * Make a common block for s.
 */

void init_common(symbol *s)
{
    //printf("init_common('%s')\n", s->Sident);
    dtnzeros(&s->Sdt,type_size(s->Stype));
    if (s->Sdt)
        s->Sdt->dt = DT_common;
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
            case DT_symsize:
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


#endif /* !SPP */
