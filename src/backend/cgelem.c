// Copyright (C) 1985-1998 by Symantec
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
#include        <time.h>
#include        <stdlib.h>

#include        "cc.h"
#include        "oper.h"
#include        "global.h"
#include        "el.h"
#include        "dt.h"
#include        "code.h"
#include        "type.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

extern void error(const char *filename, unsigned linnum, unsigned charnum, const char *format, ...);

STATIC elem * optelem(elem *,goal_t);
STATIC elem * elarray(elem *e);
STATIC elem * eldiv(elem *, goal_t goal);

extern elem * evalu8(elem *, goal_t goal);

static bool again;

/*****************************
 */

STATIC elem * cgel_lvalue(elem *e)
{   elem *e1;
    elem *e11;
    int op;

    //printf("cgel_lvalue()\n"); elem_print(e);
    e1 = e->E1;
    op = e->Eoper;
    if (e1->Eoper == OPbit)
    {
        e11 = e1->E1;

        if (e11->Eoper == OPcomma)
        {
            // Replace (((e,v) bit x) op e2) with (e,((v bit x) op e2))
            e1->E1 = e11->E2;
            e11->E2 = e;
            e11->Ety = e->Ety;
            e11->ET = e->ET;
            e = e11;
            goto L1;
        }
        else if (OTassign(e11->Eoper))
        {
            // Replace (((e op= v) bit x) op e2) with ((e op= v) , ((e bit x) op e2))
            e1->E1 = el_copytree(e11->E1);
            e = el_bin(OPcomma,e->Ety,e11,e);
            goto L1;
        }
    }
    else if (e1->Eoper == OPcomma)
    {
        // Replace ((e,v) op e2) with (e,(v op e2))
        e->Eoper = OPcomma;
        e1->Eoper = op;
        e1->Ety = e->Ety;
        e1->ET = e->ET;
        e->E1 = e1->E1;
        e1->E1 = e1->E2;
        e1->E2 = e->E2;
        e->E2 = e1;
        goto L1;
    }
    else if (OTassign(e1->Eoper))
    {
        // Replace ((e op= v) op e2) with ((e op= v) , (e op e2))
        e->E1 = el_copytree(e1->E1);
        e = el_bin(OPcomma,e->Ety,e1,e);
    L1:
        e = optelem(e,GOALvalue);
    }
    return e;
}


/******************************
 * Scan down commas.
 */

STATIC elem * elscancommas(elem *e)
{
    while (e->Eoper == OPcomma
#if SCPP
           || e->Eoper == OPinfo
#endif
          )
        e = e->E2;
    return e;
}

/*************************
 * Return TRUE if elem is the constant 1.
 */

int elemisone(elem *e)
{
    if (e->Eoper == OPconst)
    {   switch (tybasic(e->Ety))
        {
            case TYchar:
            case TYuchar:
            case TYschar:
            case TYchar16:
            case TYshort:
            case TYushort:
            case TYint:
            case TYuint:
            case TYlong:
            case TYulong:
            case TYllong:
            case TYullong:
            case TYnullptr:
#if TARGET_SEGMENTED
            case TYsptr:
            case TYcptr:
            case TYhptr:
            case TYfptr:
            case TYvptr:
#endif
            case TYnptr:
            case TYbool:
            case TYwchar_t:
            case TYdchar:
                if (el_tolong(e) != 1)
                    goto nomatch;
                break;
            case TYldouble:
            case TYildouble:
                if (e->EV.Vldouble != 1)
                    goto nomatch;
                break;
            case TYdouble:
            case TYidouble:
            case TYdouble_alias:
                if (e->EV.Vdouble != 1)
                        goto nomatch;
                break;
            case TYfloat:
            case TYifloat:
                if (e->EV.Vfloat != 1)
                        goto nomatch;
                break;
            default:
                goto nomatch;
        }
        return TRUE;
    }

nomatch:
    return FALSE;
}

/*************************
 * Return TRUE if elem is the constant -1.
 */

int elemisnegone(elem *e)
{
    if (e->Eoper == OPconst)
    {   switch (tybasic(e->Ety))
        {
            case TYchar:
            case TYuchar:
            case TYschar:
            case TYchar16:
            case TYshort:
            case TYushort:
            case TYint:
            case TYuint:
            case TYlong:
            case TYulong:
            case TYllong:
            case TYullong:
            case TYnullptr:
            case TYnptr:
#if TARGET_SEGMENTED
            case TYsptr:
            case TYcptr:
            case TYhptr:
            case TYfptr:
            case TYvptr:
#endif
            case TYbool:
            case TYwchar_t:
            case TYdchar:
                if (el_tolong(e) != -1)
                    goto nomatch;
                break;
            case TYldouble:
            //case TYildouble:
                if (e->EV.Vldouble != -1)
                    goto nomatch;
                break;
            case TYdouble:
            //case TYidouble:
            case TYdouble_alias:
                if (e->EV.Vdouble != -1)
                        goto nomatch;
                break;
            case TYfloat:
            //case TYifloat:
                if (e->EV.Vfloat != -1)
                        goto nomatch;
                break;
            default:
                goto nomatch;
        }
        return TRUE;
    }

nomatch:
    return FALSE;
}

/**********************************
 * Swap relational operators (like if we swapped the leaves).
 */

unsigned swaprel(unsigned op)
{
    assert(op < (unsigned) OPMAX);
    if (OTrel(op))
        op = rel_swap(op);
    return op;
}

/**************************
 * Replace e1 by t=e1, replace e2 by t.
 */

STATIC void fixside(elem **pe1,elem **pe2)
{ tym_t tym;
  elem *tmp,*e2;

  tym = (*pe1)->Ety;
  tmp = el_alloctmp(tym);
  *pe1 = el_bin(OPeq,tym,tmp,*pe1);
  e2 = el_copytree(tmp);
  el_free(*pe2);
  *pe2 = e2;
}



/****************************
 * Compute the 'cost' of evaluating a elem. Could be done
 * as Sethi-Ullman numbers, but that ain't worth the bother.
 * We'll fake it.
 */

#define cost(n) (opcost[n->Eoper])

/*******************************
 * For floating point expressions, the cost would be the number
 * of registers in the FPU stack needed.
 */

int fcost(elem *e)
{
    int cost;
    int cost1;
    int cost2;

    //printf("fcost()\n");
    switch (e->Eoper)
    {
        case OPadd:
        case OPmin:
        case OPmul:
        case OPdiv:
            cost1 = fcost(e->E1);
            cost2 = fcost(e->E2);
            cost = cost2 + 1;
            if (cost1 > cost)
                cost = cost1;
            break;

        case OPcall:
        case OPucall:
            cost = 8;
            break;

        case OPneg:
        case OPabs:
            return fcost(e->E1);

        case OPvar:
        case OPconst:
        case OPind:
        default:
            return 1;
    }
    if (cost > 8)
        cost = 8;
    return cost;
}

/*******************************
 * The lvalue of an op= is a conversion operator. Since the code
 * generator cannot handle this, we will have to fix it here. The
 * general strategy is:
 *      (conv) e1 op= e2        =>      e1 = (conv) e1 op e2
 * Since e1 can only be evaluated once, if it is an expression we
 * must use a temporary.
 */

STATIC elem *fixconvop(elem *e)
{       elem *e1,*e2,*ed,*T;
        elem *ex;
        elem **pe;
        unsigned cop,icop,op;
        tym_t tycop,tym,tyme;
        static unsigned char invconvtab[] =
        {
                OPbool,         // OPb_8
                OPs32_d,        // OPd_s32
                OPd_s32,        // OPs32_d
                OPs16_d,        /* OPd_s16      */
                OPd_s16,        /* OPs16_d      */
                OPu16_d,        // OPd_u16
                OPd_u16,        // OPu16_d
                OPu32_d,        /* OPd_u32      */
                OPd_u32,        /* OPu32_d      */
                OPs64_d,        // OPd_s64
                OPd_s64,        // OPs64_d
                OPu64_d,        // OPd_u64
                OPd_u64,        // OPu64_d
                OPf_d,          // OPd_f
                OPd_f,          // OPf_d
                OP32_16,        // OPs16_32
                OP32_16,        // OPu16_32
                OPs16_32,       // OP32_16
                OP16_8,         // OPu8_16
                OP16_8,         // OPs8_16
                OPs8_16,        // OP16_8
                OP64_32,        // OPu32_64
                OP64_32,        // OPs32_64
                OPs32_64,       // OP64_32
                OP128_64,       // OPu64_128
                OP128_64,       // OPs64_128
                OPs64_128,      // OP128_64
#if TARGET_SEGMENTED
                0,              /* OPvp_fp      */
                0,              /* OPcvp_fp     */
                OPnp_fp,        /* OPoffset     */
                OPoffset,       /* OPnp_fp      */
                OPf16p_np,      /* OPnp_f16p    */
                OPnp_f16p,      /* OPf16p_np    */
#endif
                OPd_ld,         // OPld_d
                OPld_d,         // OPd_ld
                OPu64_d,        // OPld_u64
        };

//dbg_printf("fixconvop before\n");
//elem_print(e);
        assert(arraysize(invconvtab) == CNVOPMAX - CNVOPMIN + 1);
        assert(e);
        tyme = e->Ety;
        cop = e->E1->Eoper;             /* the conversion operator      */
        assert(cop <= CNVOPMAX);

        if (e->E1->E1->Eoper == OPcomma)
        {   /* conv(a,b) op= e2
             *   =>
             * a, (conv(b) op= e2)
             */
            elem *ecomma = e->E1->E1;
            e->E1->E1 = ecomma->E2;
            e->E1->E1->Ety = ecomma->Ety;
            ecomma->E2 = e;
            ecomma->Ety = e->Ety;
            return optelem(ecomma, GOALvalue);
        }

        if (e->E1->Eoper == OPd_f && OTconv(e->E1->E1->Eoper) && tyintegral(tyme))
        {   e1 = e->E1;
            e->E1 = e1->E1;
            e->E2 = el_una(OPf_d, e->E1->Ety, e->E2);
            e1->E1 = NULL;
            el_free(e1);
            return fixconvop(e);
        }

        tycop = e->E1->Ety;
        tym = e->E1->E1->Ety;
        e->E1 = el_selecte1(e->E1);     /* dump it for now              */
        e1 = e->E1;
        e1->Ety = tym;
        e2 = e->E2;
        assert(e1 && e2);
        /* select inverse conversion operator   */
        icop = invconvtab[convidx(cop)];

        /* First, let's see if we can just throw it away.       */
        /* (unslng or shtlng) e op= e2  => e op= (lngsht) e2    */
        if (OTwid(e->Eoper) &&
                (cop == OPs16_32 || cop == OPu16_32 ||
                 cop == OPu8_16 || cop == OPs8_16))
        {   if (e->Eoper != OPshlass && e->Eoper != OPshrass && e->Eoper != OPashrass)
                e->E2 = el_una(icop,tym,e2);
//dbg_printf("after1\n");
//elem_print(e);
            return e;
        }

        /* Oh well, just split up the op and the =.                     */
        op = opeqtoop(e->Eoper);        /* convert op= to op            */
        e->Eoper = OPeq;                /* just plain =                 */
        ed = el_copytree(e1);           /* duplicate e1                 */
                                        /* make: e1 = (icop) ((cop) ed op e2)*/
        e->E2 = el_una(icop,e1->Ety,
                                 el_bin(op,tycop,el_una(cop,tycop,ed),
                                                      e2));

//printf("after1\n");
//elem_print(e);

        if (op == OPdiv &&
            tybasic(e2->Ety) == TYcdouble)
        {
            if (tycop == TYdouble)
            {
                e->E2->E1->Ety = tybasic(e2->Ety);
                e->E2->E1 = el_una(OPc_r, tycop, e->E2->E1);
            }
            else if (tycop == TYidouble)
            {
                e->E2->E1->Ety = tybasic(e2->Ety);
                e->E2->E1 = el_una(OPc_i, tycop, e->E2->E1);
            }
        }

        if (op == OPdiv &&
            tybasic(e2->Ety) == TYcfloat)
        {
            if (tycop == TYfloat)
            {
                e->E2->E1->Ety = tybasic(e2->Ety);
                e->E2->E1 = el_una(OPc_r, tycop, e->E2->E1);
            }
            else if (tycop == TYifloat)
            {
                e->E2->E1->Ety = tybasic(e2->Ety);
                e->E2->E1 = el_una(OPc_i, tycop, e->E2->E1);
            }
        }

        /* Handle case of multiple conversion operators on lvalue       */
        /* (such as (intdbl 8int char += double))                       */
        ex = e;
        pe = &e;
        while (OTconv(ed->Eoper))
        {   unsigned copx = ed->Eoper;
            tym_t tymx;

            icop = invconvtab[convidx(copx)];
            tymx = ex->E1->E1->Ety;
            ex->E1 = el_selecte1(ex->E1);       // dump it for now
            e1 = ex->E1;
            e1->Ety = tymx;
            ex->E2 = el_una(icop,e1->Ety,ex->E2);
            ex->Ety = tymx;
            tym = tymx;

            if (ex->Ety != tyme)
            {   *pe = el_una(copx, ed->Ety, ex);
                pe = &(*pe)->E1;
            }

            ed = ed->E1;
        }
//dbg_printf("after2\n");
//elem_print(e);

        e->Ety = tym;
        if (tym != tyme &&
            !(tyintegral(tym) && tyintegral(tyme) && tysize(tym) == tysize(tyme)))
            e = el_una(cop, tyme, e);

        if (ed->Eoper == OPbit)         /* special handling             */
        {
                ed = ed->E1;
                e1 = e1->E1;            /* go down one                  */
        }
        /* If we have a *, must assign a temporary to the expression    */
        /* underneath it (even if it's a var, as e2 may modify the var). */
        if (ed->Eoper == OPind)
        {       T = el_alloctmp(ed->E1->Ety); /* make temporary         */
                ed->E1 = el_bin(OPeq,T->Ety,T,ed->E1); /* ed: *(T=e)    */
                el_free(e1->E1);
                e1->E1 = el_copytree(T);
        }
//dbg_printf("after3\n");
//elem_print(e);
        return e;
}

STATIC elem * elerr(elem *e, goal_t goal)
{
#ifdef DEBUG
    elem_print(e);
#endif
    assert(0);
    return (elem *)NULL;
}

/* For ops with no optimizations */

STATIC elem * elzot(elem *e, goal_t goal)
{ return e; }

/****************************
 */

STATIC elem * elstring(elem *e, goal_t goal)
{
#if 0 // now handled by el_convert()
    if (!OPTIMIZER)
        el_convstring(e);       // convert string to OPrelconst
#endif
    return e;
}

/************************
 */

#if TARGET_SEGMENTED
/************************
 * Convert far pointer to pointer.
 */

STATIC void eltonear(elem **pe)
{   tym_t ty;
    elem *e = *pe;

    ty = e->E1->Ety;
    e = el_selecte1(e);
    e->Ety = ty;
    *pe = optelem(e,GOALvalue);
}
#endif

/************************
 */

STATIC elem * elstrcpy(elem *e, goal_t goal)
{   tym_t ty;

    elem_debug(e);
    switch (e->E2->Eoper)
    {
#if TARGET_SEGMENTED
        case OPnp_fp:
            if (OPTIMIZER)
            {
                eltonear(&e->E2);
                e = optelem(e,GOALvalue);
            }
            break;
#endif
        case OPstring:
            /* Replace strcpy(e1,"string") with memcpy(e1,"string",sizeof("string")) */
            // As streq
            e->Eoper = OPstreq;
            type *t = type_allocn(TYarray, tschar);
            t->Tdim = strlen(e->E2->EV.ss.Vstring) + 1;
            e->ET = t;
            t->Tcount++;
            e->E1 = el_una(OPind,TYstruct,e->E1);
            e->E2 = el_una(OPind,TYstruct,e->E2);

            e = el_bin(OPcomma,e->Ety,e,el_copytree(e->E1->E1));
            if (el_sideeffect(e->E2))
                fixside(&e->E1->E1->E1,&e->E2);
            e = optelem(e,GOALvalue);
            break;
    }
    return e;
}

/************************
 */

STATIC elem * elstrcmp(elem *e, goal_t goal)
{
    elem_debug(e);
    if (OPTIMIZER)
    {
#if TARGET_SEGMENTED
        if (e->E1->Eoper == OPnp_fp)
            eltonear(&e->E1);
#endif
        switch (e->E2->Eoper)
        {
#if TARGET_SEGMENTED
            case OPnp_fp:
                eltonear(&e->E2);
                break;
#endif

            case OPstring:
                // Replace strcmp(e1,"string") with memcmp(e1,"string",sizeof("string"))
                e->Eoper = OPparam;
                e = el_bin(OPmemcmp,e->Ety,e,el_long(TYint,strlen(e->E2->EV.ss.Vstring) + 1));
                e = optelem(e,GOALvalue);
                break;
        }
    }
    return e;
}

/****************************
 * For OPmemcmp, OPmemcpy, OPmemset.
 */

STATIC elem * elmemxxx(elem *e, goal_t goal)
{
    elem_debug(e);
    if (OPTIMIZER)
    {   elem *ex;

        ex = e->E1;
        switch (e->Eoper)
        {   case OPmemcmp:
#if TARGET_SEGMENTED
                if (ex->E1->Eoper == OPnp_fp)
                    eltonear(&ex->E1);
                if (ex->E2->Eoper == OPnp_fp)
                    eltonear(&ex->E2);
#endif
                break;

            case OPmemset:
#if TARGET_SEGMENTED
                if (ex->Eoper == OPnp_fp)
                    eltonear(&ex);
                else
#endif
                {
                    // lvalue OPmemset (nbytes param value)
                    elem *enbytes = e->E2->E1;
                    elem *evalue = e->E2->E2;

#if MARS
                    if (enbytes->Eoper == OPconst && evalue->Eoper == OPconst
                        /* && tybasic(e->E1->Ety) == TYstruct*/)
                    {   tym_t tym;
                        tym_t ety;
                        int nbytes = el_tolong(enbytes);
                        targ_llong value = el_tolong(evalue);
                        elem *e1 = e->E1;
                        elem *tmp;

                        if (e1->Eoper == OPcomma || OTassign(e1->Eoper))
                            return cgel_lvalue(e);    // replace (e,v)op=e2 with e,(v op= e2)

                        switch (nbytes)
                        {
                            case CHARSIZE:      tym = TYchar;   goto L1;
                            case SHORTSIZE:     tym = TYshort;  goto L1;
                            case LONGSIZE:      tym = TYlong;   goto L1;
                            case LLONGSIZE:     if (intsize == 2)
                                                    goto Ldefault;
                                                tym = TYllong;  goto L1;
                            L1:
                                ety = e->Ety;
                                memset(&value, value & 0xFF, sizeof(value));
                                evalue->EV.Vullong = value;
                                evalue->Ety = tym;
                                e->Eoper = OPeq;
                                e->Ety = (e->Ety & ~mTYbasic) | tym;
                                if (tybasic(e1->Ety) == TYstruct)
                                    e1->Ety = tym;
                                else
                                    e->E1 = el_una(OPind, tym, e1);
                                tmp = el_same(&e->E1);
                                tmp = el_una(OPaddr, ety, tmp);
                                e->E2->Ety = tym;
                                e->E2 = el_selecte2(e->E2);
                                e = el_combine(e, tmp);
                                e = optelem(e,GOALvalue);
                                break;

                            default:
                            Ldefault:
                                break;
                        }
                    }
#endif
                }
                break;

            case OPmemcpy:
#if TARGET_SEGMENTED
                if (ex->Eoper == OPnp_fp)
                    eltonear(&e->E1);
#endif
                ex = e->E2;
#if TARGET_SEGMENTED
                if (ex->E1->Eoper == OPnp_fp)
                    eltonear(&ex->E1);
#endif
                if (ex->E2->Eoper == OPconst)
                {
                    if (!boolres(ex->E2))
                    {   // Copying 0 bytes, so remove memcpy
                        e->E2 = e->E1;
                        e->E1 = ex->E1;
                        ex->E1 = NULL;
                        e->Eoper = OPcomma;
                        el_free(ex);
                        return optelem(e, GOALvalue);
                    }
                    // Convert OPmemcpy to OPstreq
                    e->Eoper = OPstreq;
                    type *t = type_allocn(TYarray, tschar);
                    t->Tdim = el_tolong(ex->E2);
                    e->ET = t;
                    t->Tcount++;
                    e->E1 = el_una(OPind,TYstruct,e->E1);
                    e->E2 = el_una(OPind,TYstruct,ex->E1);
                    ex->E1 = NULL;
                    el_free(ex);
                    ex = el_copytree(e->E1->E1);
#if TARGET_SEGMENTED
                    if (tysize(e->Ety) > tysize(ex->Ety))
                        ex = el_una(OPnp_fp,e->Ety,ex);
#endif
                    e = el_bin(OPcomma,e->Ety,e,ex);
                    if (el_sideeffect(e->E2))
                        fixside(&e->E1->E1->E1,&e->E2);
                    return optelem(e,GOALvalue);
                }
                break;

            default:
                assert(0);
        }
    }
    return e;
}


/***********************
 *        +             #       (combine offsets with addresses)
 *       / \    =>      |
 *      #   c          v,c
 *      |
 *      v
 */

STATIC elem * eladd(elem *e, goal_t goal)
{ elem *e1,*e2;
  int sz;

  //printf("eladd(%p)\n",e);
  targ_size_t ptrmask = ~(targ_size_t)0;
  if (NPTRSIZE <= 4)
        ptrmask = 0xFFFFFFFF;
L1:
  e1 = e->E1;
  e2 = e->E2;
  if (e2->Eoper == OPconst)
  {
#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
        if (e1->Eoper == OPrelconst && e1->EV.sp.Vsym->Sfl == FLgot)
                goto ret;
#endif
        if (e1->Eoper == OPrelconst             /* if (&v) + c          */
            || e1->Eoper == OPstring
           )
        {
                e1->EV.sp.Voffset += e2->EV.Vpointer;
                e1->EV.sp.Voffset &= ptrmask;
                e = el_selecte1(e);
                goto ret;
        }
  }
  else if (e1->Eoper == OPconst)
  {
#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
        if (e2->Eoper == OPrelconst && e2->EV.sp.Vsym->Sfl == FLgot)
                goto ret;
#endif
        if (e2->Eoper == OPrelconst             /* if c + (&v)          */
            || e2->Eoper == OPstring
           )
        {
                e2->EV.sp.Voffset += e1->EV.Vpointer;
                e2->EV.sp.Voffset &= ptrmask;
                e = el_selecte2(e);
                goto ret;
        }
  }

  if (!OPTIMIZER)
        goto ret;

  /* Replace ((e + &v) + c) with (e + (&v+c))   */
  if (e2->Eoper == OPconst && e1->Eoper == OPadd &&
        (e1->E2->Eoper == OPrelconst || e1->E2->Eoper == OPstring))
  {
        e1->E2->EV.sp.Voffset += e2->EV.Vpointer;
        e1->E2->EV.sp.Voffset &= ptrmask;
        e = el_selecte1(e);
        goto L1;
  }
  /* Replace ((e + c) + &v) with (e + (&v+c))   */
  else if ((e2->Eoper == OPrelconst || e2->Eoper == OPstring) &&
           e1->Eoper == OPadd && cnst(e1->E2))
  {
        e2->EV.sp.Voffset += e1->E2->EV.Vpointer;
        e2->EV.sp.Voffset &= ptrmask;
        e->E1 = el_selecte1(e1);
        goto L1;                        /* try and find some more       */
  }
  /* Replace (e1 + -e) with (e1 - e)    */
  else if (e2->Eoper == OPneg)
  {     e->E2 = el_selecte1(e2);
        e->Eoper = OPmin;
        again = 1;
        return e;
  }
  /* Replace (-v + e) with (e + -v)     */
  else if (e1->Eoper == OPneg && OTleaf(e1->E1->Eoper))
  {     e->E1 = e2;
        e->E2 = e1;                     /* swap leaves                  */
        goto L1;
  }
  /* Replace ((e - e2) + e2) with (e)                   */
  /* The optimizer sometimes generates this case        */
  else if (!tyfloating(e->Ety) &&       /* no floating bugs             */
        e1->Eoper == OPmin &&
        el_match(e1->E2,e2) &&
        !el_sideeffect(e2))
  {     tym_t tym = e->Ety;

        e = el_selecte1(el_selecte1(e));
        e->Ety = tym;                   /* retain original type         */
        return e;
  }
  /* Replace ((e - #v+c1) + #v+c2) with ((e - c1) + c2) */
  else if (e2->Eoper == OPrelconst &&
           e1->Eoper == OPmin &&
           e1->E2->Eoper == OPrelconst &&
           e1->E2->EV.sp.Vsym == e2->EV.sp.Vsym)
  {     e2->Eoper = OPconst;
        e2->Ety = TYint;
        e1->Ety = e1->E1->Ety;
        e1->E2->Eoper = OPconst;
        e1->E2->Ety = TYint;
        {
#if TARGET_SEGMENTED
            /* Watch out for pointer types changing, requiring a conversion */
            tym_t ety,e11ty;

            ety = tybasic(e->Ety);
            e11ty = tybasic(e1->E1->Ety);
            if (typtr(ety) && typtr(e11ty) &&
                tysize[ety] != tysize[e11ty])
            {
                e = el_una((tysize[ety] > tysize[e11ty]) ? OPnp_fp : OPoffset,
                            e->Ety,e);
                e->E1->Ety = e1->Ety;
            }
#endif
        }
        again = 1;
        return e;
  }
  /* Replace (e + e) with (e * 2)       */
  else if (el_match(e1,e2) && !el_sideeffect(e1) && !tyfloating(e->Ety))
  {
        e->Eoper = OPmul;
        el_free(e2);
        e->E2 = el_long(e->Ety,2);
        again = 1;
        return e;
  }
  // Replace ((e11 + c) + e2) with ((e11 + e2) + c)
  if (e1->Eoper == OPadd && e1->E2->Eoper == OPconst &&
      (e2->Eoper == OPvar || !OTleaf(e2->Eoper)) &&
      tysize(e1->Ety) == tysize(e2->Ety) &&
      tysize(e1->E2->Ety) == tysize(e2->Ety))
  {
        e->E2 = e1->E2;
        e1->E2 = e2;
        e1->Ety = e->Ety;
        goto ret;
  }

    // Replace (~e1 + 1) with (-e1)
    if (e1->Eoper == OPcom && e2->Eoper == OPconst && el_tolong(e2) == 1)
    {
        e = el_selecte1(e);
        e->Eoper = OPneg;
        e = optelem(e, goal);
        goto ret;
    }

    // Replace ((e11 - e12) + e2) with ((e11 + e2) - e12)
    // (this should increase the number of LEA possibilities)
    sz = tysize(e->Ety);
    if (e1->Eoper == OPmin &&
        tysize(e1->Ety) == sz &&
        tysize(e2->Ety) == sz &&
        tysize(e1->E1->Ety) == sz &&
        tysize(e1->E2->Ety) == sz &&
        !tyfloating(e->Ety)
       )
    {
        e->Eoper = OPmin;
        e->E2 = e1->E2;
        e1->E2 = e2;
        e1->Eoper = OPadd;
    }

ret:
  return e;
}


/************************
 * Multiply (for OPmul && OPmulass)
 *      e * (c**2) => e << c    ;replace multiply by power of 2 with shift
 */

STATIC elem * elmul(elem *e, goal_t goal)
{
  tym_t tym = e->Ety;

  if (OPTIMIZER)
  {
        // Replace -a*-b with a*b.
        // This is valid for all floating point types as well as integers.
        if (tyarithmetic(tym) && e->E2->Eoper == OPneg && e->E1->Eoper == OPneg)
        {
            e->E1 = el_selecte1(e->E1);
            e->E2 = el_selecte1(e->E2);
        }
  }

  elem *e2 = e->E2;
  if (e2->Eoper == OPconst)             /* try to replace multiplies with shifts */
  {
        if (OPTIMIZER)
        {
            elem *e1 = e->E1;
            unsigned op1 = e1->Eoper;

            if (tyintegral(tym) &&              // skip floating types
                OTbinary(op1) &&
                e1->E2->Eoper == OPconst
               )
            {
                /* Attempt to replace ((e + c1) * c2) with (e * c2 + (c1 * c2))
                 * because the + can be frequently folded out (merged into an
                 * array offset, for example.
                 */
                if (op1 == OPadd)
                {
                    e->Eoper = OPadd;
                    e1->Eoper = OPmul;
                    e->E2 = el_bin(OPmul,tym,e1->E2,e2);
                    e1->E2 = el_copytree(e2);
                    again = 1;
                    return e;
                }

                // ((e << c1) * c2) => e * ((1 << c1) * c2)
                if (op1 == OPshl)
                {
                    e2->EV.Vullong *= (targ_ullong)1 << el_tolong(e1->E2);
                    e1->E2->EV.Vullong = 0;
                    again = 1;
                    return e;
                }
            }

            if (elemisnegone(e2))
            {
                e->Eoper = (e->Eoper == OPmul) ? OPneg : OPnegass;
                e->E2 = NULL;
                el_free(e2);
                return e;
            }
        }

        if (tyintegral(tym))
        {   int i;

            i = ispow2(el_tolong(e2));          /* check for power of 2 */
            if (i != -1)                        /* if it is a power of 2 */
            {   e2->EV.Vint = i;
                e2->Ety = TYint;
                e->Eoper = (e->Eoper == OPmul)  /* convert to shift left */
                        ? OPshl : OPshlass;
                again = 1;
                return e;
            }
            else if (el_allbits(e2,-1))
                goto Lneg;
        }
        else if (elemisnegone(e2) && !tycomplex(e->E1->Ety))
        {
            goto Lneg;
        }
  }
    return e;

Lneg:
    e->Eoper = (e->Eoper == OPmul)      /* convert to negate */
            ? OPneg : OPnegass;
    el_free(e->E2);
    e->E2 = NULL;
    again = 1;
    return e;
}

/************************
 * Subtract
 *        -               +
 *       / \    =>       / \            (propagate minuses)
 *      e   c           e   -c
 */

STATIC elem * elmin(elem *e, goal_t goal)
{ elem *e2;

L1:
  e2 = e->E2;

  if (OPTIMIZER)
  {

  tym_t tym = e->Ety;
  elem *e1 = e->E1;
  if (e2->Eoper == OPrelconst)
  {     if (e1->Eoper == OPrelconst && e1->EV.sp.Vsym == e2->EV.sp.Vsym)
        {       e->Eoper = OPconst;
                e->EV.Vint = e1->EV.sp.Voffset - e2->EV.sp.Voffset;
                el_free(e1);
                el_free(e2);
                return e;
        }
  }

  /* Convert subtraction of long pointers to subtraction of integers    */
  if (tyfv(e2->Ety) && tyfv(e1->Ety))
  {     e->E1 = el_una(OP32_16,tym,e1);
        e->E2 = el_una(OP32_16,tym,e2);
        return optelem(e,GOALvalue);
  }

  /* Replace (0 - e2) with (-e2)        */
  if (cnst(e1) && !boolres(e1) &&
      !(tycomplex(tym) && !tycomplex(e1->Ety) && !tycomplex(e2->Ety)) &&
      !tyvector(e1->Ety)
     )
  {
        e->E1 = e2;
        e->E2 = NULL;
        e->Eoper = OPneg;
        el_free(e1);
        return optelem(e,GOALvalue);
  }

  /* Replace (e - e) with (0)   */
  if (el_match(e1,e2) && !el_sideeffect(e1))
  {     el_free(e);
        e = el_calloc();
        e->Eoper = OPconst;
        e->Ety = tym;
        return e;
  }

  /* Replace (e1 + c1) - (e2 + c2) with (e1 - e2) + (c1 - c2), but not  */
  /* for floating or far or huge pointers!                              */
  if (e1->Eoper == OPadd && e2->Eoper == OPadd &&
      cnst(e1->E2) && cnst(e2->E2) &&
      (tyintegral(tym) || tybasic(tym) == TYjhandle || tybasic(tym) == TYnptr
#if TARGET_SEGMENTED
       || tybasic(tym) == TYsptr
#endif
      ))
  {
        e->Eoper = OPadd;
        e1->Eoper = OPmin;
        e2->Eoper = OPmin;
        elem *tmp = e1->E2;
        e1->E2 = e2->E1;
        e2->E1 = tmp;
        return optelem(e,GOALvalue);
  }

    // Replace (-e1 - 1) with (~e1)
    if (e1->Eoper == OPneg && e2->Eoper == OPconst && tyintegral(tym) && el_tolong(e2) == 1)
    {
        e = el_selecte1(e);
        e->Eoper = OPcom;
        e = optelem(e, goal);
        return e;
    }

  }

#if TX86 && !(MARS)
    if (tybasic(e2->Ety) == TYhptr && tybasic(e->E1->Ety) == TYhptr)
    {   // Convert to _aNahdiff(e1,e2)
        static symbol hdiff = SYMBOLY(FLfunc,mBX|mCX|mSI|mDI|mBP|mES,"_aNahdiff",0);

        if (LARGECODE)
            hdiff.Sident[2] = 'F';
        hdiff.Stype = tsclib;
        e->Eoper = OPcall;
        e->E2 = el_bin(OPparam,TYint,e2,e->E1);
        e->E1 = el_var(&hdiff);
        return e;
    }
#endif

  /* Disallow the optimization on doubles. The - operator is not        */
  /* rearrangable by K+R, and can cause floating point problems if      */
  /* converted to an add ((a + 1.0) - 1.0 shouldn't be folded).         */
  if (cnst(e2) && !tyfloating(e2->Ety))
  {     e->E2 = el_una(OPneg,e2->Ety,e2);
        e->Eoper = OPadd;
        return optelem(e,GOALvalue);
  }
  return e;
}

/*****************************
 * OPand,OPor,OPxor
 * This should be expanded to include long type stuff.
 */

STATIC elem * elbitwise(elem *e, goal_t goal)
{
    //printf("elbitwise(e = %p, goal = x%x)\n", e, goal);

    elem *e2 = e->E2;
    elem *e1 = e->E1;
    int op = e1->Eoper;
    unsigned sz = tysize(e2->Ety);

    if (e2->Eoper == OPconst)
    {
        switch (sz)
        {
            case CHARSIZE:
                /* Replace (c & 0xFF) with (c)  */
                if (OPTIMIZER && e2->EV.Vuchar == CHARMASK)
                {
                L1:
                    switch (e->Eoper)
                    {   case OPand:     /* (c & 0xFF) => (c)    */
                            return el_selecte1(e);
                        case OPor:      /* (c | 0xFF) => (0xFF) */
                            return el_selecte2(e);
                        case OPxor:     /* (c ^ 0xFF) => (~c)   */
                            return el_una(OPcom,e->Ety,el_selecte1(e));
                        default:
                            assert(0);
                    }
                }
                break;

            case LONGSIZE:
            {
                if (!OPTIMIZER)
                    break;
                targ_ulong ul = e2->EV.Vulong;

                if (ul == 0xFFFFFFFF)           /* if e1 & 0xFFFFFFFF   */
                    goto L1;
                /* (x >> 16) & 0xFFFF => ((unsigned long)x >> 16)       */
                if (ul == 0xFFFF && e->Eoper == OPand && (op == OPshr || op == OPashr) &&
                    e1->E2->Eoper == OPconst && el_tolong(e1->E2) == 16)
                {   elem *e11 = e1->E1;

                    e11->Ety = touns(e11->Ety) | (e11->Ety & ~mTYbasic);
                    goto L1;
                }

                /* Replace (L & 0x0000XXXX) with (unslng)((lngsht) & 0xXXXX) */
                if (intsize < LONGSIZE &&
                    e->Eoper == OPand &&
                    ul <= SHORTMASK)
                {       tym_t tym = e->Ety;
                        e->E1 = el_una(OP32_16,TYushort,e->E1);
                        e->E2 = el_una(OP32_16,TYushort,e->E2);
                        e->Ety = TYushort;
                        e = el_una(OPu16_32,tym,e);
                        goto Lopt;
                }

                // Replace ((s8sht)L & 0xFF) with (u8sht)L
                if (ul == 0xFF && intsize == LONGSIZE && e->Eoper == OPand &&
                    (op == OPs8_16 || op == OPu8_16)
                   )
                {
                    e1->Eoper = OPu8_16;
                    e = el_selecte1(e);
                    goto Lopt;
                }
                break;
            }

            case SHORTSIZE:
            {
                targ_short i = e2->EV.Vshort;
                if (i == (targ_short)SHORTMASK) // e2 & 0xFFFF
                    goto L1;

                /* (x >> 8) & 0xFF => ((unsigned short)x >> 8)          */
                if (OPTIMIZER && i == 0xFF && e->Eoper == OPand &&
                    (op == OPshr || op == OPashr) && e1->E2->Eoper == OPconst && e1->E2->EV.Vint == 8)
                {   elem *e11 = e1->E1;

                    e11->Ety = touns(e11->Ety) | (e11->Ety & ~mTYbasic);
                    goto L1;
                }

                // (s8_16(e) & 0xFF) => u8_16(e)
                if (OPTIMIZER && op == OPs8_16 && e->Eoper == OPand &&
                    i == 0xFF)
                {
                    e1->Eoper = OPu8_16;
                    e = el_selecte1(e);
                    goto Lopt;
                }

                if (
                    /* OK for unsigned if AND or high bits of i are 0   */
                    op == OPu8_16 && (e->Eoper == OPand || !(i & ~0xFF)) ||
                    /* OK for signed if i is 'sign-extended'    */
                    op == OPs8_16 && (targ_short)(targ_schar)i == i
                   )
                {
                        /* Convert ((u8int) e) & i) to (u8int)(e & (int8) i) */
                        /* or similar for s8int                              */
                        e = el_una(e1->Eoper,e->Ety,e);
                        e->E1->Ety = e1->Ety = e1->E1->Ety;
                        e->E1->E1 = el_selecte1(e1);
                        e->E1->E2 = el_una(OP16_8,e->E1->Ety,e->E1->E2);
                        goto Lopt;
                }
                break;
            }

            case LLONGSIZE:
                if (OPTIMIZER)
                {
                    if (e2->EV.Vullong == LLONGMASK)
                        goto L1;
                }
                break;
        }
        if (OPTIMIZER && sz < 16)
        {   targ_ullong ul = el_tolong(e2);

            if (e->Eoper == OPor && op == OPand && e1->E2->Eoper == OPconst)
            {
                // ((x & c1) | c2) => (x | c2)
                targ_ullong c3;

                c3 = ul | e1->E2->EV.Vullong;
                switch (sz)
                {   case CHARSIZE:
                        if ((c3 & CHARMASK) == CHARMASK)
                            goto L2;
                        break;
                    case SHORTSIZE:
                        if ((c3 & SHORTMASK) == SHORTMASK)
                            goto L2;
                        break;
                    case LONGSIZE:
                        if ((c3 & LONGMASK) == LONGMASK)
                        {
                        L2:
                            e1->E2->EV.Vullong = c3;
                            e->E1 = elbitwise(e1, GOALvalue);
                            goto Lopt;
                        }
                        break;

                    case LLONGSIZE:
                        if ((c3 & LLONGMASK) == LLONGMASK)
                            goto L2;
                        break;

                    default:
                        assert(0);
                }
            }

            if (op == OPs16_32 && (ul & 0xFFFFFFFFFFFF8000LL) == 0 ||
                op == OPu16_32 && (ul & 0xFFFFFFFFFFFF0000LL) == 0 ||
                op == OPs8_16  && (ul & 0xFFFFFFFFFFFFFF80LL) == 0 ||
                op == OPu8_16  && (ul & 0xFFFFFFFFFFFFFF00LL) == 0 ||
                op == OPs32_64 && (ul & 0xFFFFFFFF80000000LL) == 0 ||
                op == OPu32_64 && (ul & 0xFFFFFFFF00000000LL) == 0
               )
            {
                if (e->Eoper == OPand)
                {   if (op == OPs16_32 && (ul & 0x8000) == 0)
                        e1->Eoper = OPu16_32;
                    else if (op == OPs8_16  && (ul & 0x80) == 0)
                        e1->Eoper = OPu8_16;
                    else if (op == OPs32_64 && (ul & 0x80000000) == 0)
                        e1->Eoper = OPu32_64;
                }

                // ((shtlng)s & c) => ((shtlng)(s & c)
                e1->Ety = e->Ety;
                e->Ety = e2->Ety = e1->E1->Ety;
                e->E1 = e1->E1;
                e1->E1 = e;
                e = e1;
                goto Lopt;
            }

            // Replace (((a & b) ^ c) & d) with ((a ^ c) & e), where
            // e is (b&d).
            if (e->Eoper == OPand && op == OPxor && e1->E1->Eoper == OPand &&
                e1->E1->E2->Eoper == OPconst)
            {
                e2->EV.Vullong &= e1->E1->E2->EV.Vullong;
                e1->E1 = el_selecte1(e1->E1);
                goto Lopt;
            }

            // Replace ((a >> b) & 1) with (a btst b)
            if ((I32 || I64) &&
                e->Eoper == OPand &&
                ul == 1 &&
                (e->E1->Eoper == OPshr || e->E1->Eoper == OPashr) &&
                sz <= REGSIZE
               )
            {
                e->E1->Eoper = OPbtst;
                e = el_selecte1(e);
                goto Lopt;
            }
        }
    }

    if (OPTIMIZER && goal & GOALflags && (I32 || I64) && e->Eoper == OPand &&
        (sz == 4 || sz == 8))
    {
        /* These should all compile to a BT instruction when -O, for -m32 and -m64
         * int bt32(uint *p, uint b) { return ((p[b >> 5] & (1 << (b & 0x1F)))) != 0; }
         * int bt64a(ulong *p, uint b) { return ((p[b >> 6] & (1L << (b & 63)))) != 0; }
         * int bt64b(ulong *p, size_t b) { return ((p[b >> 6] & (1L << (b & 63)))) != 0; }
         */

        #define ELCONST(e,c) ((e)->Eoper == OPconst && el_tolong(e) == (c))
        int pow2sz = ispow2(sz);
        elem **pb1;
        elem **pb2;
        elem **pp;
        elem *e12;              // the (b & 31), which may be preceded by (64_32)
        elem *e2111;            // the (b >>> 5), which may be preceded by (u32_64)

        if (e1->Eoper == OPind)
        {   // Swap e1 and e2 so that e1 is the mask and e2 is the memory location
            e2 = e1;
            e1 = e->E2;
        }

        /* Replace:
         *  ((1 << (b & 31))   &   *(((b >>> 5) << 2) + p)
         * with:
         *  p bt b
         */
        if (e1->Eoper == OPshl &&
            ELCONST(e1->E1,1) &&
            ((e12 = e1->E2), 1) &&
            ((e12->Eoper == OP64_32 && ((e12 = e12->E1),1)),
            e12->Eoper == OPand) &&
            ELCONST(e12->E2,sz * 8 - 1) &&

            e2->Eoper == OPind &&
            e2->E1->Eoper == OPadd &&
            e2->E1->E1->Eoper == OPshl &&
            ELCONST(e2->E1->E1->E2,pow2sz) &&
            ((e2111 = e2->E1->E1->E1), 1) &&
            ((e2111->Eoper == OPu32_64 && ((e2111 = e2111->E1),1)),
            e2111->Eoper == OPshr) &&
            ELCONST(e2111->E2,pow2sz + 3)
           )
        {
            pb1 = &e12->E1;
            pb2 = &e2111->E1;
            pp  = &e2->E1->E2;

            if (el_match(*pb1, *pb2) &&
                !el_sideeffect(*pb1))
            {
                e->Eoper = OPbt;
                e->E1 = *pp;            // p
                *pp = NULL;
                e->E2 = *pb1;           // b
                *pb1 = NULL;
                *pb2 = NULL;
                el_free(e1);
                el_free(e2);
                return optelem(e,goal);
            }
        }

        /* Replace:
         *  (1 << a) & b
         * with:
         *  b btst a
         */
        if (e1->Eoper == OPshl &&
            ELCONST(e1->E1,1) &&
            tysize(e->E1->Ety) <= REGSIZE)
        {
            e->Eoper = OPbtst;
            e->Ety = TYbool;
            e->E1 = e2;
            e->E2 = e1->E2;
            e->E2->Ety = e->E1->Ety;
            e1->E2 = NULL;
            el_free(e1);
            return optelem(e, goal);
        }
    }

    return e;

Lopt:
#ifdef DEBUG
    static int nest;
    nest++;
    if (nest > 100)
    {   elem_print(e);
        assert(0);
    }
    e = optelem(e,GOALvalue);
    nest--;
    return e;
#endif
    return optelem(e,GOALvalue);
}

/***************************************
 * Fill in ops[maxops] with operands of repeated operator oper.
 * Returns:
 *      true    didn't fail
 *      false   more than maxops operands
 */

bool fillinops(elem **ops, int *opsi, int maxops, int oper, elem *e)
{
    if (e->Eoper == oper)
    {
        if (!fillinops(ops, opsi, maxops, oper, e->E1) ||
            !fillinops(ops, opsi, maxops, oper, e->E2))
            return false;
    }
    else
    {
        if (*opsi >= maxops)
            return false;       // error, too many
        ops[*opsi] = e;
        *opsi += 1;
    }
    return true;
}


/*************************************
 * Replace shift|shift with rotate.
 */

STATIC elem *elor(elem *e, goal_t goal)
{
    /* ROL:     (a << shift) | (a >> (sizeof(a) * 8 - shift))
     * ROR:     (a >> shift) | (a << (sizeof(a) * 8 - shift))
     */
    elem *e1 = e->E1;
    elem *e2 = e->E2;
    unsigned sz = tysize(e->Ety);
    if (sz <= intsize)
    {
        if (e1->Eoper == OPshl && e2->Eoper == OPshr &&
            tyuns(e2->E1->Ety) && e2->E2->Eoper == OPmin &&
            e2->E2->E1->Eoper == OPconst &&
            el_tolong(e2->E2->E1) == sz * 8 &&
            el_match5(e1->E1, e2->E1) &&
            el_match5(e1->E2, e2->E2->E2) &&
            !el_sideeffect(e)
           )
        {
            e1->Eoper = OProl;
            return el_selecte1(e);
        }
        if (e1->Eoper == OPshr && e2->Eoper == OPshl &&
            tyuns(e1->E1->Ety) && e2->E2->Eoper == OPmin &&
            e2->E2->E1->Eoper == OPconst &&
            el_tolong(e2->E2->E1) == sz * 8 &&
            el_match5(e1->E1, e2->E1) &&
            el_match5(e1->E2, e2->E2->E2) &&
            !el_sideeffect(e)
           )
        {
            e1->Eoper = OPror;
            return el_selecte1(e);
        }
        // rotate left by a constant
        if (e1->Eoper == OPshl && e2->Eoper == OPshr &&
            tyuns(e2->E1->Ety) &&
            e1->E2->Eoper == OPconst &&
            e2->E2->Eoper == OPconst &&
            el_tolong(e2->E2) == sz * 8 - el_tolong(e1->E2) &&
            el_match5(e1->E1, e2->E1) &&
            !el_sideeffect(e)
           )
        {
            e1->Eoper = OProl;
            return el_selecte1(e);
        }
        // rotate right by a constant
        if (e1->Eoper == OPshr && e2->Eoper == OPshl &&
            tyuns(e2->E1->Ety) &&
            e1->E2->Eoper == OPconst &&
            e2->E2->Eoper == OPconst &&
            el_tolong(e2->E2) == sz * 8 - el_tolong(e1->E2) &&
            el_match5(e1->E1, e2->E1) &&
            !el_sideeffect(e)
           )
        {
            e1->Eoper = OPror;
            return el_selecte1(e);
        }
    }

    /* BSWAP: (data[0]<< 24) | (data[1]<< 16) | (data[2]<< 8) | (data[3]<< 0)
     */
    if (sz == 4 && OPTIMIZER)
    {   elem *ops[4];
        int opsi = 0;
        if (fillinops(ops, &opsi, 4, OPor, e) && opsi == 4)
        {
            elem *ex = NULL;
            unsigned mask = 0;
            for (int i = 0; i < 4; i++)
            {   elem *eo = ops[i];
                elem *eo2;
                int shift;
                elem *eo111;
                if (eo->Eoper == OPu8_16 &&
                    eo->E1->Eoper == OPind)
                {
                    eo111 = eo->E1->E1;
                    shift = 0;
                }
                else if (eo->Eoper == OPshl &&
                    eo->E1->Eoper == OPu8_16 &&
                    (eo2 = eo->E2)->Eoper == OPconst &&
                    eo->E1->E1->Eoper == OPind)
                {
                    shift = el_tolong(eo2);
                    switch (shift)
                    {   case 8:
                        case 16:
                        case 24:
                            break;
                        default:
                            goto L1;
                    }
                    eo111 = eo->E1->E1->E1;
                }
                else
                    goto L1;
                unsigned off;
                elem *ed;
                if (eo111->Eoper == OPadd)
                {
                    ed = eo111->E1;
                    if (eo111->E2->Eoper != OPconst)
                        goto L1;
                    off = el_tolong(eo111->E2);
                    if (off < 1 || off > 3)
                        goto L1;
                }
                else
                {
                    ed = eo111;
                    off = 0;
                }
                switch ((off << 5) | shift)
                {
                    // BSWAP
                    case (0 << 5) | 24: mask |= 1; break;
                    case (1 << 5) | 16: mask |= 2; break;
                    case (2 << 5) |  8: mask |= 4; break;
                    case (3 << 5) |  0: mask |= 8; break;

                    // No swap
                    case (0 << 5) |  0: mask |= 0x10; break;
                    case (1 << 5) |  8: mask |= 0x20; break;
                    case (2 << 5) | 16: mask |= 0x40; break;
                    case (3 << 5) | 24: mask |= 0x80; break;

                        break;
                    default:
                        goto L1;
                }
                if (ex)
                {
                    if (!el_match(ex, ed))
                        goto L1;
                }
                else
                {   if (el_sideeffect(ed))
                        goto L1;
                    ex = ed;
                }
            }
            /* Got a match, build:
             *   BSWAP(*ex)
             */
            if (mask == 0x0F)
                e = el_una(OPbswap, e->Ety, el_una(OPind, e->Ety, ex));
            else if (mask == 0xF0)
                e = el_una(OPind, e->Ety, ex);
            else
                goto L1;
            return e;
        }
    }
  L1:
    ;

    if (OPTIMIZER)
    {
        /* Replace:
         *   i | (i << c1) | (i << c2) | (i * c3) ...
         * with:
         *   i * (1 + (1 << c1) + (1 << c2) + c3 ...)
         */
        elem *ops[8];    // 8 bytes in a 64 bit register, not likely to need more
        int opsi = 0;
        elem *ei = NULL;
        targ_ullong bits = 0;
        if (fillinops(ops, &opsi, sizeof(ops)/sizeof(ops[0]), OPor, e) && opsi > 1)
        {
            for (int i = 0; i < opsi; ++i)
            {
                elem *eq = ops[i];
                if (eq->Eoper == OPshl && eq->E2->Eoper == OPconst)
                {
                    bits |= 1ULL << el_tolong(eq->E2);
                    eq = eq->E1;
                }
                else if (eq->Eoper == OPmul && eq->E2->Eoper == OPconst)
                {
                    bits |= el_tolong(eq->E2);
                    eq = eq->E1;
                }
                else
                    bits |= 1;
                if (el_sideeffect(eq))
                    goto L2;
                if (ei)
                {
                    if (!el_match(ei, eq))
                        goto L2;
                }
                else
                {
                    ei = eq;
                }
            }
            tym_t ty = e->Ety;

            // Free unused nodes
            el_opFree(e, OPor);
            for (int i = 0; i < opsi; ++i)
            {
                elem *eq = ops[i];
                if ((eq->Eoper == OPshl || eq->Eoper == OPmul) &&
                    eq->E2->Eoper == OPconst)
                {
                    if (eq->E1 == ei)
                        eq->E1 = NULL;
                }
                if (eq != ei)
                    el_free(eq);
            }

            e = el_bin(OPmul, ty, ei, el_long(ty, bits));
            return e;
        }

      L2: ;
    }

    return elbitwise(e, goal);
}

/*************************************
 */

STATIC elem *elxor(elem *e, goal_t goal)
{
    if (OPTIMIZER)
    {
        elem *e1 = e->E1;
        elem *e2 = e->E2;

        /* Recognize:
         *    (a & c) ^ (b & c)  =>  (a ^ b) & c
         */
        if (e1->Eoper == OPand && e2->Eoper == OPand &&
            el_match5(e1->E2, e2->E2) &&
            (e2->E2->Eoper == OPconst || (!el_sideeffect(e2->E1) && !el_sideeffect(e2->E2))))
        {
            el_free(e1->E2);
            e1->E2 = e2->E1;
            e1->Eoper = OPxor;
            e->Eoper = OPand;
            e->E2 = e2->E2;
            e2->E1 = NULL;
            e2->E2 = NULL;
            el_free(e2);
            return optelem(e, GOALvalue);
        }
    }
    return elbitwise(e, goal);
}

/**************************
 * Optimize nots.
 *      ! ! e => bool e
 *      ! bool e => ! e
 *      ! OTrel => !OTrel       (invert the condition)
 *      ! OTconv => !
 */

STATIC elem * elnot(elem *e, goal_t goal)
{ elem *e1;
  unsigned op;

  e1 = e->E1;
  op = e1->Eoper;
  switch (op)
  {     case OPnot:                     // ! ! e => bool e
        case OPbool:                    // ! bool e => ! e
            e1->Eoper = op ^ (OPbool ^ OPnot);
            /* That was a clever substitute for the following:  */
            /* e->Eoper = (op == OPnot) ? OPbool : OPnot;               */
            goto L1;

        default:
            if (OTrel(op))                      /* ! OTrel => !OTrel            */
            {
                  /* Find the logical negation of the operator  */
                  op = rel_not(op);
                  if (!tyfloating(e1->E1->Ety))
                  {   op = rel_integral(op);
                      assert(OTrel(op));
                  }
                  e1->Eoper = op;

            L1: e = optelem(el_selecte1(e), goal);
            }
            else if (tybasic(e1->Ety) == TYbool && tysize(e->Ety) == 1)
            {
                // !e1 => (e1 ^ 1)
                e->Eoper = OPxor;
                e->E2 = el_long(e1->Ety,1);
                e = optelem(e, goal);
            }
#if 0
// Can't use this because what if OPd_s32?
// Note: !(long)(.1) != !(.1)
            else if (OTconv(op))        // don't use case because of differ target
            {                           // conversion operators
                e1->Eoper = e->Eoper;
                goto L1;
            }
#endif
            break;

        case OPs32_d:
        case OPs16_d:
        case OPu16_d:
        case OPu32_d:
        case OPf_d:
        case OPs16_32:
        case OPu16_32:
        case OPu8_16:
        case OPs8_16:
        case OPu32_64:
        case OPs32_64:
#if TARGET_SEGMENTED
        case OPvp_fp:
        case OPcvp_fp:
        case OPnp_fp:
#endif
            e1->Eoper = e->Eoper;
            goto L1;

        case OPcomma:
            /* !(a,b) => (a,!b) */
            e->Eoper = OPcomma;
            e->E1 = e1->E1;             // a
            e->E2 = e1;                 // !
            e1->Eoper = OPnot;
            e1->Ety = e->Ety;
            e1->E1 = e1->E2;            // b
            e1->E2 = NULL;
            e = optelem(e, goal);
            break;
  }
  return e;
}

/*************************
 * Complement
 *      ~ ~ e => e
 */

STATIC elem * elcom(elem *e, goal_t goal)
{ elem *e1;

  e1 = e->E1;
  if (e1->Eoper == OPcom)                       /* ~ ~ e => e           */
        /* Typing problem here  */
        e = el_selecte1(el_selecte1(e));
  return e;
}

/*************************
 * If it is a conditional of a constant
 * then we know which exp to evaluate.
 * BUG:
 *      doesn't detect ("string" ? et : ef)
 */

STATIC elem * elcond(elem *e, goal_t goal)
{   elem *e1;
    elem *ex;

    e1 = e->E1;
    switch (e1->Eoper)
    {   case OPconst:
            if (boolres(e1))
            L1:
                e = el_selecte1(el_selecte2(e));
            else
                e = el_selecte2(el_selecte2(e));
            break;
        case OPrelconst:
        case OPstring:
            goto L1;

        case OPcomma:
            // ((a,b) ? c) => (a,(b ? c))
            e->Eoper = OPcomma;
            e->E1 = e1->E1;
            e1->E1 = e1->E2;
            e1->E2 = e->E2;
            e->E2 = e1;
            e1->Eoper = OPcond;
            e1->Ety = e->Ety;
            return optelem(e,GOALvalue);

        case OPnot:
            // (!a ? b : c) => (a ? c : b)
            ex = e->E2->E1;
            e->E2->E1 = e->E2->E2;
            e->E2->E2 = ex;
            goto L2;

        default:
            if (OTboolnop(e1->Eoper))
            {
        L2:
                e->E1 = e1->E1;
                e1->E1 = NULL;
                el_free(e1);
                return elcond(e,goal);
            }
        {
            if (OPTIMIZER)
            {
            tym_t ty = e->Ety;
            elem *ec1 = e->E2->E1;
            elem *ec2 = e->E2->E2;

            if (tyintegral(ty) && ec1->Eoper == OPconst && ec2->Eoper == OPconst)
            {   targ_llong i1,i2;
                targ_llong b;

                i1 = el_tolong(ec1);
                i2 = el_tolong(ec2);

                /* If b is an integer with only 1 bit set then          */
                /*   replace ((a & b) ? b : 0) with (a & b)             */
                /*   replace ((a & b) ? 0 : b) with ((a & b) ^ b)       */
                if (e1->Eoper == OPand && e1->E2->Eoper == OPconst &&
                    tysize(ty) == tysize(ec1->Ety))
                {
                    b = el_tolong(e1->E2);
                    if (ispow2(b) != -1)        /* if only 1 bit is set */
                    {
                        if (b == i1 && i2 == 0)
                        {   e = el_selecte1(e);
                            e->E1->Ety = ty;
                            e->E2->Ety = ty;
                            e->E2->EV.Vllong = b;
                            return optelem(e,GOALvalue);
                        }
                        else if (i1 == 0 && b == i2)
                        {
                            e1->Ety = ty;
                            e1->E1->Ety = ty;
                            e1->E2->Ety = ty;
                            e1->E2->EV.Vllong = b;
                            e->E1 = el_bin(OPxor,ty,e1,el_long(ty,b));
                            e = el_selecte1(e);
                            return optelem(e,GOALvalue);
                        }
                    }
                }

                /* Replace ((a relop b) ? 1 : 0) with (a relop b)       */
                else if (OTrel(e1->Eoper) &&
                    tysize(ty) <= tysize[TYint])
                {
                    if (i1 == 1 && i2 == 0)
                        e = el_selecte1(e);
                    else if (i1 == 0 && i2 == 1)
                    {
                        e->E1 = el_una(OPnot,ty,e1);
                        e = optelem(el_selecte1(e),GOALvalue);
                    }
                }
#if TX86
                // The next two optimizations attempt to replace with an
                // unsigned compare, which the code generator can generate
                // code for without using jumps.

                // Try to replace (!e1) with (e1 < 1)
                else if (e1->Eoper == OPnot && !OTrel(e1->E1->Eoper))
                {
                    e->E1 = el_bin(OPlt,TYint,e1->E1,el_long(touns(e1->E1->Ety),1));
                    e1->E1 = NULL;
                    el_free(e1);
                }
                // Try to replace (e1) with (e1 >= 1)
                else if (!OTrel(e1->Eoper))
                {
                    if (tyfv(e1->Ety))
                    {
                        if (tysize(e->Ety) == tysize[TYint])
                        {
                            if (i1 == 1 && i2 == 0)
                            {   e->Eoper = OPbool;
                                el_free(e->E2);
                                e->E2 = NULL;
                            }
                            else if (i1 == 0 && i2 == 1)
                            {   e->Eoper = OPnot;
                                el_free(e->E2);
                                e->E2 = NULL;
                            }
                        }
                    }
                    else if(tyintegral(e1->Ety))
                        e->E1 = el_bin(OPge,TYint,e1,el_long(touns(e1->Ety),1));
                }
#endif
            }

            // Try to detect absolute value expression
            // (a < 0) -a : a
            else if ((e1->Eoper == OPlt || e1->Eoper == OPle) &&
                e1->E2->Eoper == OPconst &&
                !boolres(e1->E2) &&
                !tyuns(e1->E1->Ety) &&
                !tyuns(e1->E2->Ety) &&
                ec1->Eoper == OPneg &&
                !el_sideeffect(ec2) &&
                el_match(e->E1->E1,ec2) &&
                el_match(ec1->E1,ec2) &&
                tysize(ty) >= intsize
               )
            {   e->E2->E2 = NULL;
                el_free(e);
                e = el_una(OPabs,ty,ec2);
            }
            // (a >= 0) a : -a
            else if ((e1->Eoper == OPge || e1->Eoper == OPgt) &&
                e1->E2->Eoper == OPconst &&
                !boolres(e1->E2) &&
                !tyuns(e1->E1->Ety) &&
                !tyuns(e1->E2->Ety) &&
                ec2->Eoper == OPneg &&
                !el_sideeffect(ec1) &&
                el_match(e->E1->E1,ec1) &&
                el_match(ec2->E1,ec1) &&
                tysize(ty) >= intsize
               )
            {   e->E2->E1 = NULL;
                el_free(e);
                e = el_una(OPabs,ty,ec1);
            }

            /* Replace:
             *    a ? noreturn : c
             * with:
             *    (a && noreturn), c
             * because that means fewer noreturn cases for the data flow analysis to deal with
             */
            else if (el_noreturn(ec1))
            {
                e->Eoper = OPcomma;
                e->E1 = e->E2;
                e->E2 = ec2;
                e->E1->Eoper = OPandand;
                e->E1->Ety = TYvoid;
                e->E1->E2 = ec1;
                e->E1->E1 = e1;
            }

            /* Replace:
             *    a ? b : noreturn
             * with:
             *    (a || noreturn), b
             */
            else if (el_noreturn(ec2))
            {
                e->Eoper = OPcomma;
                e->E1 = e->E2;
                e->E2 = ec1;
                e->E1->Eoper = OPoror;
                e->E1->Ety = TYvoid;
                e->E1->E2 = ec2;
                e->E1->E1 = e1;
            }

            break;
            }
        }
    }
    return e;
}


/****************************
 * Comma operator.
 *        ,      e
 *       / \  =>                expression with no effect
 *      c   e
 *        ,               ,
 *       / \    =>       / \    operators with no effect
 *      +   e           ,   e
 *     / \             / \
 *    e   e           e   e
 */

STATIC elem * elcomma(elem *e, goal_t goal)
{ register elem *e1,**pe1;
  elem *e2;
  int e1op;
  int changes;

  changes = -1;
L1:
  changes++;
L2:
  //printf("elcomma()\n");
  e2 = e->E2;
  pe1 = &(e->E1);
  e1 = *pe1;
  e1op = e1->Eoper;

  /* c,e => e   */
  if (OTleaf(e1op) && !OTsideff(e1op) && !(e1->Ety & mTYvolatile))
  {     e2->Ety = e->Ety;
        e = el_selecte2(e);
        goto Lret;
  }

  /* ((a op b),e2) => ((a,b),e2)        if op has no side effects       */
  if (!el_sideeffect(e1) && e1op != OPcomma && e1op != OPandand &&
        e1op != OPoror && e1op != OPcond)
  {
        if (OTunary(e1op))
                *pe1 = el_selecte1(e1); /* get rid of e1                */
        else
        {       e1->Eoper = OPcomma;
                e1->Ety = e1->E2->Ety;
        }
        goto L1;
  }

    if (!OPTIMIZER)
        goto Lret;

    /* Replace (a,b),e2 with a,(b,e2)   */
    if (e1op == OPcomma)
    {
        e1->Ety = e->Ety;
        e->E1 = e1->E1;
        e1->E1 = e1->E2;
        e1->E2 = e2;
        e->E2 = elcomma(e1, GOALvalue);
        goto L2;
    }

    if ((OTopeq(e1op) || e1op == OPeq) &&
        (e1->E1->Eoper == OPvar || e1->E1->Eoper == OPind) &&
        !el_sideeffect(e1->E1)
       )
    {
        if (el_match(e1->E1,e2))
            // ((a = b),a) => (a = b)
            e = el_selecte1(e);
        else if (OTrel(e2->Eoper) &&
                 OTleaf(e2->E2->Eoper) &&
                 el_match(e1->E1,e2->E1)
                )
        {   // ((a = b),(a < 0)) => ((a = b) < 0)
            e1->Ety = e2->E1->Ety;
            e->E1 = e2->E1;
            e2->E1 = e1;
            goto L1;
        }
        else if ((e2->Eoper == OPandand ||
                  e2->Eoper == OPoror   ||
                  e2->Eoper == OPcond) &&
                 el_match(e1->E1,e2->E1)
                )
        {
            /* ((a = b),(a || c)) => ((a = b) || c)     */
            e1->Ety = e2->E1->Ety;
            e->E1 = e2->E1;
            e2->E1 = e1;
            e = el_selecte2(e);
            changes++;
            goto Lret;
        }
        else if (e1op == OPeq)
        {
            /* Replace ((a = b),(c = a)) with a,(c = (a = b))   */
            for (; e2->Eoper == OPcomma; e2 = e2->E1)
                ;
            if ((OTopeq(e2->Eoper) || e2->Eoper == OPeq) &&
                el_match(e1->E1,e2->E2) &&
#if 0
                !(e1->E1->Eoper == OPvar && el_appears(e2->E1,e1->E1->EV.sp.Vsym)) &&
#endif
                ERTOL(e2))
            {
                e->E1 = e2->E2;
                e1->Ety = e2->E2->Ety;
                e2->E2 = e1;
                goto L1;
            }
        }
        else
        {
#if 1       // This optimization is undone in eleq().
            // Replace ((a op= b),(a op= c)) with (0,a = (a op b) op c)
            for (; e2->Eoper == OPcomma; e2 = e2->E1)
                ;
            if ((OTopeq(e2->Eoper)) &&
                el_match(e1->E1,e2->E1))
            {   elem *ex;

                e->E1 = el_long(TYint,0);
                e1->Eoper = opeqtoop(e1op);
                e2->E2 = el_bin(opeqtoop(e2->Eoper),e2->Ety,e1,e2->E2);
                e2->Eoper = OPeq;
                goto L1;
            }
#endif
        }
    }
Lret:
    again = changes != 0;
    return e;
}

/********************************
 */

STATIC elem * elremquo(elem *e, goal_t goal)
{
#if 0 && MARS
    if (cnst(e->E2) && !boolres(e->E2))
        error(e->Esrcpos.Sfilename, e->Esrcpos.Slinnum, e->Esrcpos.Scharnum, "divide by zero\n");
#endif
    return e;
}

/********************************
 */

STATIC elem * elmod(elem *e, goal_t goal)
{
    elem *e1;
    elem *e2;
    tym_t tym;

    tym = e->E1->Ety;
    if (!tyfloating(tym))
        return eldiv(e, goal);
    return e;
}

/*****************************
 * Convert divides to >> if power of 2.
 * Can handle OPdiv, OPdivass, OPmod.
 */

STATIC elem * eldiv(elem *e, goal_t goal)
{   elem *e2;
    tym_t tym;
    int uns;

    e2 = e->E2;
    tym = e->E1->Ety;
    uns = tyuns(tym) | tyuns(e2->Ety);
    if (cnst(e2))
    {
#if 0 && MARS
      if (!boolres(e2))
        error(e->Esrcpos.Sfilename, e->Esrcpos.Slinnum, e->Esrcpos.Scharnum, "divide by zero\n");
#endif
      if (uns)
      { int i;

        e2->Ety = touns(e2->Ety);
        i = ispow2(el_tolong(e2));
        if (i != -1)
        {   int op;

            switch (e->Eoper)
            {   case OPdiv:
                    op = OPshr;
                    goto L1;
                case OPdivass:
                    op = OPshrass;
                L1:
                    e2->EV.Vint = i;
                    e2->Ety = TYint;
                    e->E1->Ety = touns(tym);
                    break;

                case OPmod:
                    op = OPand;
                    goto L3;
                case OPmodass:
                    op = OPandass;
                L3:
                    e2->EV.Vullong = el_tolong(e2) - 1;
                    break;

                default:
                    assert(0);
            }
            e->Eoper = op;
            return optelem(e,GOALvalue);
        }
      }
    }

    if (OPTIMIZER)
    {
        if (tyintegral(tym) && (e->Eoper == OPdiv || e->Eoper == OPmod))
        {   int sz = tysize(tym);

            // See if we can replace with OPremquo
            if (sz == REGSIZE
                // Currently don't allow this because OPmsw doesn't work for the case
                //|| (I64 && sz == 4)
                )
            {
                // Don't do it if there are special code sequences in the
                // code generator (see cdmul())
                int pow2;
                if (e->E2->Eoper == OPconst &&
                    !uns &&
                    (pow2 = ispow2(el_tolong(e->E2))) != -1 &&
                    !(config.target_cpu < TARGET_80286 && pow2 != 1 && e->Eoper == OPdiv)
                   )
                    ;
                else
                {
                    assert(sz == 2 || sz == 4 || sz == 8);
                    int op = OPmsw;
                    if (e->Eoper == OPdiv)
                    {
                        op = (sz == 2) ? OP32_16 : (sz == 4) ? OP64_32 : OP128_64;
                    }
                    e->Eoper = OPremquo;
                    e = el_una(op, tym, e);
                    e->E1->Ety = (sz == 2) ? TYlong : (sz == 4) ? TYllong : TYcent;
                }
            }
        }
    }

    return e;
}

/**************************
 * Convert (a op b) op c to a op (b op c).
 */

STATIC elem * swaplog(elem *e, goal_t goal)
{       elem *e1;

        e1 = e->E1;
        e->E1 = e1->E2;
        e1->E2 = e;
        return optelem(e1,goal);
}

STATIC elem * eloror(elem *e, goal_t goal)
{   elem *e1,*e2;
    tym_t t;
    tym_t ty1,ty2;

    e1 = e->E1;
    if (OTboolnop(e1->Eoper))
    {
        e->E1 = e1->E1;
        e1->E1 = NULL;
        el_free(e1);
        return eloror(e, goal);
    }
    e2 = e->E2;
    if (OTboolnop(e2->Eoper))
    {
        e->E2 = e2->E1;
        e2->E1 = NULL;
        el_free(e2);
        return eloror(e, goal);
    }
    if (OPTIMIZER)
    {
        if (e1->Eoper == OPbool)
        {   ty1 = e1->E1->Ety;
            e1 = e->E1 = el_selecte1(e1);
            e1->Ety = ty1;
        }
        if (e1->Eoper == OPoror)
        {       /* convert (a||b)||c to a||(b||c). This will find more CSEs.    */
            return swaplog(e, goal);
        }
        e2 = elscancommas(e2);
        e1 = elscancommas(e1);
    }

    t = e->Ety;
    if (e2->Eoper == OPconst || e2->Eoper == OPrelconst || e2->Eoper == OPstring)
    {
        if (boolres(e2))                /* e1 || 1  => e1 , 1           */
        {   if (e->E2 == e2)
                goto L2;
        }
        else                            /* e1 || 0  =>  bool e1         */
        {   if (e->E2 == e2)
            {
                el_free(e->E2);
                e->E2 = NULL;
                e->Eoper = OPbool;
                goto L3;
            }
        }
    }

    if (e1->Eoper == OPconst || e1->Eoper == OPrelconst || e1->Eoper == OPstring)
    {
        if (boolres(e1))                /* (x,1) || e2  =>  (x,1),1     */
        {
            if (tybasic(e->E2->Ety) == TYvoid)
            {   assert(!goal);
                el_free(e);
                return NULL;
            }
            else
            {
            L2:
                e->Eoper = OPcomma;
                el_free(e->E2);
                e->E2 = el_int(t,1);
            }
        }
        else                            /* (x,0) || e2  =>  (x,0),(bool e2) */
        {   e->Eoper = OPcomma;
            if (tybasic(e->E2->Ety) != TYvoid)
                e->E2 = el_una(OPbool,t,e->E2);
        }
  }
  else if (OPTIMIZER &&
        e->E2->Eoper == OPvar &&
        !OTlogical(e1->Eoper) &&
        tysize(ty2 = e2->Ety) == tysize(ty1 = e1->Ety) &&
        tysize(ty1) <= intsize &&
        !tyfloating(ty2) &&
        !tyfloating(ty1) &&
        !(ty2 & mTYvolatile))
    {   /* Convert (e1 || e2) => (e1 | e2)      */
        e->Eoper = OPor;
        e->Ety = ty1;
        e = el_una(OPbool,t,e);
    }
    else if (OPTIMIZER &&
             e1->Eoper == OPand && e2->Eoper == OPand &&
             tysize(e1->Ety) == tysize(e2->Ety) &&
             el_match(e1->E1,e2->E1) && !el_sideeffect(e1->E1) &&
             !el_sideeffect(e2->E2)
            )
    {   // Convert ((a & b) || (a & c)) => bool(a & (b | c))
        e->Eoper = OPbool;
        e->E2 = NULL;
        e2->Eoper = OPor;
        el_free(e2->E1);
        e2->E1 = e1->E2;
        e1->E2 = e2;
    }
    else
        goto L1;
L3:
    e = optelem(e,GOALvalue);
L1:
    return e;
}

/**********************************************
 * Try to rewrite sequence of || and && with faster operations, such as BT.
 * Returns:
 *      false   nothing changed
 *      true    *pe is rewritten
 */

STATIC bool optim_loglog(elem **pe)
{
    if (I16)
        return false;
    elem *e = *pe;
    int op = e->Eoper;
    assert(op == OPandand || op == OPoror);
    size_t n = el_opN(e, op);
    if (n <= 3)
        return false;
    unsigned ty = e->Ety;
    elem **array = (elem **)malloc(n * sizeof(elem *));
    assert(array);
    elem **p = array;
    el_opArray(&p, e, op);

    bool any = false;
    size_t first, last;
    targ_ullong emin, emax;
    int cmpop = op == OPandand ? OPne : OPeqeq;
    for (size_t i = 0; i < n; ++i)
    {
        elem *eq = array[i];
        if (eq->Eoper == cmpop &&
            eq->E2->Eoper == OPconst &&
            tyintegral(eq->E2->Ety) &&
            !el_sideeffect(eq->E1))
        {
            targ_ullong m = el_tolong(eq->E2);
            if (any)
            {
                if (el_match(array[first]->E1, eq->E1))
                {
                    last = i;
                    if (m < emin)
                        emin = m;
                    if (m > emax)
                        emax = m;
                }
                else if (last - first > 2)
                    break;
                else
                {
                    first = last = i;
                    emin = emax = m;
                }
            }
            else
            {
                any = true;
                first = last = i;
                emin = emax = m;
            }
        }
        else if (any && last - first > 2)
            break;
        else
            any = false;
    }

    //printf("n = %d, count = %d, min = %d, max = %d\n", (int)n, last - first + 1, (int)emin, (int)emax);
    if (any && last - first > 2 && emax - emin < REGSIZE * 8)
    {
        /**
         * Transforms expressions of the form x==c1 || x==c2 || x==c3 || ... into a single
         * comparison by using a bitmapped representation of data, as follows. First, the
         * smallest constant of c1, c2, ... (call it min) is subtracted from all constants
         * and also from x (this step may be elided if all constants are small enough). Then,
         * the test is expressed as
         *   (1 << (x-min)) | ((1 << (c1-min)) | (1 << (c2-min)) | ...)
         * The test is guarded for overflow (x must be no larger than the largest of c1, c2, ...).
         * Since each constant is encoded as a displacement in a bitmap, hitting any bit yields
         * true for the expression.
         *
         * I.e. replace:
         *   e==c1 || e==c2 || e==c3 ...
         * with:
         *   (e - emin) <= (emax - emin) && (1 << (int)(e - emin)) & bits
         * where bits is:
         *   (1<<(c1-emin)) | (1<<(c2-emin)) | (1<<(c3-emin)) ...
         *
         * For the case of:
         *  x!=c1 && x!=c2 && x!=c3 && ...
         * using De Morgan's theorem, rewrite as:
         *   (e - emin) > (emax - emin) || ((1 << (int)(e - emin)) & ~bits)
         */

        // Delete all the || nodes that are no longer referenced
        el_opFree(e, op);

        if (emax < 32)                  // if everything fits in a 32 bit register
            emin = 0;                   // no need for bias

        // Compute bit mask
        targ_ullong bits = 0;
        for (size_t i = first; i <= last; ++i)
        {
            elem *eq = array[i];
            if (0 && eq->E2->Eoper != OPconst)
            {
                printf("eq = %p, eq->E2 = %p\n", eq, eq->E2);
                printf("first = %d, i = %d, last = %d, Eoper = %d\n", (int)first, (int)i, (int)last, eq->E2->Eoper);
                printf("any = %d, n = %d, count = %d, min = %d, max = %d\n", any, (int)n, (int)(last - first + 1), (int)emin, (int)emax);
            }
            assert(eq->E2->Eoper == OPconst);
            bits |= (targ_ullong)1 << (el_tolong(eq->E2) - emin);
        }
        //printf("n = %d, count = %d, min = %d, max = %d\n", (int)n, last - first + 1, (int)emin, (int)emax);
        //printf("bits = x%llx\n", bits);

        if (op == OPandand)
            bits = ~bits;

        unsigned tyc = array[first]->E1->Ety;

        elem *ex = el_bin(OPmin, tyc, array[first]->E1, el_long(tyc,emin));
        ex = el_bin(op == OPandand ? OPgt : OPle, TYbool, ex, el_long(touns(tyc), emax - emin));
        elem *ey = el_bin(OPmin, tyc, array[first + 1]->E1, el_long(tyc,emin));

        tym_t tybits = TYuint;
        if ((emax - emin) >= 32)
        {
            assert(I64);                // need 64 bit BT
            tybits = TYullong;
        }

        // Shift count must be an int
        switch (tysize(tyc))
        {
            case 1:
                ey = el_una(OPu8_16,TYint,ey);
            case 2:
                ey = el_una(OPu16_32,TYint,ey);
                break;
            case 4:
                break;
            case 8:
                ey = el_una(OP64_32,TYint,ey);
                break;
            default:
                assert(0);
        }
#if 1
        ey = el_bin(OPbtst,TYbool,el_long(tybits,bits),ey);
#else
        ey = el_bin(OPshl,tybits,el_long(tybits,1),ey);
        ey = el_bin(OPand,tybits,ey,el_long(tybits,bits));
#endif
        ex = el_bin(op == OPandand ? OPoror : OPandand, ty, ex, ey);

        /* Free unneeded nodes
         */
        array[first]->E1 = NULL;
        el_free(array[first]);
        array[first + 1]->E1 = NULL;
        el_free(array[first + 1]);
        for (size_t i = first + 2; i <= last; ++i)
            el_free(array[i]);

        array[first] = ex;

        for (size_t i = first + 1; i + (last - first) < n; ++i)
            array[i] = array[i + (last - first)];
        n -= last - first;
        (*pe) = el_opCombine(array, n, op, ty);

        free(array);
        return true;
    }

    free(array);
    return false;
}

STATIC elem * elandand(elem *e, goal_t goal)
{
    elem *e1 = e->E1;
    if (OTboolnop(e1->Eoper))
    {
        e->E1 = e1->E1;
        e1->E1 = NULL;
        el_free(e1);
        return elandand(e, goal);
    }
    elem *e2 = e->E2;
    if (OTboolnop(e2->Eoper))
    {
        e->E2 = e2->E1;
        e2->E1 = NULL;
        el_free(e2);
        return elandand(e, goal);
    }
    if (OPTIMIZER)
    {
        /* Recognize: (a >= c1 && a < c2)
         */
        if ((e1->Eoper == OPge || e1->Eoper == OPgt) &&
            (e2->Eoper == OPlt || e2->Eoper == OPle) &&
            e1->E2->Eoper == OPconst && e2->E2->Eoper == OPconst &&
            !el_sideeffect(e1->E1) && el_match(e1->E1, e2->E1) &&
            tyintegral(e1->E1->Ety) &&
            tybasic(e1->E2->Ety) == tybasic(e2->E2->Ety) &&
            tysize(e1->E1->Ety) == NPTRSIZE)
        {
            /* Replace with: ((a - c1) < (c2 - c1))
             */
            targ_llong c1 = el_tolong(e1->E2);
            if (e1->Eoper == OPgt)
                ++c1;
            targ_llong c2 = el_tolong(e2->E2);
            if (0 <= c1 && c1 <= c2)
            {
                e1->Eoper = OPmin;
                e1->Ety = e1->E1->Ety;
                e1->E2->EV.Vllong = c1;
                e->E2 = el_long(touns(e2->E2->Ety), c2 - c1);
                e->Eoper = e2->Eoper;
                el_free(e2);
                return optelem(e, GOALvalue);
            }
        }

        // Look for (!(e >>> c) && ...)
        if (e1->Eoper == OPnot && e1->E1->Eoper == OPshr &&
            e1->E1->E2->Eoper == OPconst)
        {
            // Replace (e >>> c) with (e & x)
            elem *e11 = e1->E1;

            targ_ullong shift = el_tolong(e11->E2);
            if (shift < intsize * 8)
            {   targ_ullong m;

                m = ~0LL << (int)shift;
                e11->Eoper = OPand;
                e11->E2->EV.Vullong = m;
                e11->E2->Ety = e11->Ety;
                return optelem(e,GOALvalue);
            }
        }

        if (e1->Eoper == OPbool)
        {   tym_t t = e1->E1->Ety;
            e1 = e->E1 = el_selecte1(e1);
            e1->Ety = t;
        }
        if (e1->Eoper == OPandand)
        {   /* convert (a&&b)&&c to a&&(b&&c). This will find more CSEs.        */
            return swaplog(e, goal);
        }
        e2 = elscancommas(e2);

        while (1)
        {   e1 = elscancommas(e1);
            if (e1->Eoper == OPeq)
                e1 = e1->E2;
            else
                break;
        }
    }

    if (e2->Eoper == OPconst || e2->Eoper == OPrelconst || e2->Eoper == OPstring)
    {   if (boolres(e2))        /* e1 && (x,1)  =>  e1 ? ((x,1),1) : 0  */
        {
            if (e2 == e->E2)    /* if no x, replace e with (bool e1)    */
            {   el_free(e2);
                e->E2 = NULL;
                e->Eoper = OPbool;
                goto L3;
            }
        }
        else                            /* e1 && (x,0)  =>  e1 , (x,0)  */
        {   if (e2 == e->E2)
            {   e->Eoper = OPcomma;
                goto L3;
            }
        }
    }

  if (e1->Eoper == OPconst || e1->Eoper == OPrelconst || e1->Eoper == OPstring)
  {
        e->Eoper = OPcomma;
        if (boolres(e1))                /* (x,1) && e2  =>  (x,1),bool e2 */
        {
            if (tybasic(e->E2->Ety) != TYvoid)
                e->E2 = el_una(OPbool,e->Ety,e->E2);
        }
        else                            /* (x,0) && e2  =>  (x,0),0     */
        {
            if (tybasic(e->E2->Ety) == TYvoid)
            {   assert(!goal);
                el_free(e);
                return NULL;
            }
            else
            {
                el_free(e->E2);
                e->E2 = el_int(e->Ety,0);
            }
        }
    }
    else
        goto L1;
L3:
    e = optelem(e,GOALvalue);
L1:
    return e;
}

/**************************
 * Reference to bit field
 *       bit
 *       / \    =>      ((e << c) >> b) & m
 *      e  w,b
 *
 * Note that this routine can handle long bit fields, though this may
 * not be supported later on.
 */

STATIC elem * elbit(elem *e, goal_t goal)
{ unsigned wb,w,b,c;
  targ_ullong m;
  elem *e2;
  tym_t tym1;
  unsigned sz;

  tym1 = e->E1->Ety;
  sz = tysize(tym1) * 8;
  e2 = e->E2;
  wb = e2->EV.Vuns;

  w = (wb >> 8) & 0xFF;                 /* width in bits of field       */
  m = ((targ_ullong)1 << w) - 1;        // mask w bits wide
  b = wb & 0xFF;                        /* bits to right of field       */
  c = 0;
  assert(w + b <= sz);

  if (tyuns(tym1))                      /* if unsigned bit field        */
  {
#if 1   /* Should use a more general solution to this   */
        if (w == 8 && sz == 16 && b == 0)
        {
            e->E1 = el_una(OP16_8,TYuchar,e->E1);
            e->Eoper = OPu8_16;
            e->E2 = NULL;
            el_free(e2);
            goto L1;
        }
#endif
        if (w + b == sz)                /* if field is left-justified   */
            m = ~(targ_ullong)0;        // no need to mask
  }
  else                                  /* signed bit field             */
  {
        if (w == 8 && sz == 16 && b == 0)
        {
#if 1
            e->E1 = el_una(OP16_8,TYschar,e->E1);
            e->Eoper = OPs8_16;
            e->E2 = NULL;
            el_free(e2);
            goto L1;
#endif
        }
        m = ~(targ_ullong)0;
        c = sz - (w + b);
        b = sz - w;
  }

  e->Eoper = OPand;

  e2->EV.Vullong = m;                   /* mask w bits wide             */
  e2->Ety = e->Ety;

  e->E1 = el_bin(OPshr,tym1,
                el_bin(OPshl,tym1,e->E1,el_int(TYint,c)),
                el_int(TYint,b));
L1:
  return optelem(e,GOALvalue);               /* optimize result              */
}

/*****************
 * Indirection
 *      * & e => e
 */

STATIC elem * elind(elem *e, goal_t goal)
{ elem *e1;
  tym_t tym;

  tym = e->Ety;
  e1 = e->E1;
  switch (e1->Eoper)
  {     case OPrelconst:
          {
            e->E1->ET = e->ET;
            e = el_selecte1(e);
            e->Eoper = OPvar;
            e->Ety = tym;               /* preserve original type       */
          }
            break;
        case OPadd:
#if TARGET_SEGMENTED
            if (OPTIMIZER)
            {   /* Try to convert far pointer to stack pointer  */
                elem *e12 = e1->E2;

                if (e12->Eoper == OPrelconst &&
                    tybasic(e12->Ety) == TYfptr &&
                    /* If symbol is located on the stack        */
                    sytab[e12->EV.sp.Vsym->Sclass] & SCSS)
                {   e1->Ety = (e1->Ety & (mTYconst | mTYvolatile | mTYimmutable | mTYshared | mTYLINK)) | TYsptr;
                    e12->Ety = (e12->Ety & (mTYconst | mTYvolatile | mTYimmutable | mTYshared | mTYLINK)) | TYsptr;
                }
            }
#endif
            break;
        case OPcomma:
            // Replace (*(ea,eb)) with (ea,*eb)
            e->E1->ET = e->ET;
            type *t = e->ET;
            e = el_selecte1(e);
            e->Ety = tym;
            e->E2 = el_una(OPind,tym,e->E2);
            e->E2->ET = t;
            again = 1;
            return e;
  }
  return e;
}

/*****************
 * Address of.
 *      & v => &v
 *      & * e => e
 *      & (v1 = v2) => ((v1 = v2), &v1)
 */

STATIC elem * eladdr(elem *e, goal_t goal)
{ elem *e1;
  tym_t tym;

  tym = e->Ety;
  e1 = e->E1;
  elem_debug(e1);
  switch (e1->Eoper)
  {
    case OPvar:
        e1->Eoper = OPrelconst;
        e1->EV.sp.Vsym->Sflags &= ~(SFLunambig | GTregcand);
        e1->Ety = tym;
        e = optelem(el_selecte1(e),GOALvalue);
        break;
    case OPind:
    {   tym_t tym2;
        int sz;

        tym2 = e1->E1->Ety;

#if TARGET_SEGMENTED
        /* Watch out for conversions between near and far pointers      */
        sz = tysize(tym) - tysize(tym2);
        if (sz != 0)
        {   int op;

            if (sz > 0)                         /* if &far * near       */
                op = OPnp_fp;
            else                                /* else &near * far     */
                op = OPoffset;
            e->Ety = tym2;
            e = el_una(op,tym,e);
            goto L1;
        }
#endif
        e = el_selecte1(el_selecte1(e));
        e->Ety = tym;
        break;
    }
    case OPcomma:
        /* Replace (&(ea,eb)) with (ea,&eb)     */
        e = el_selecte1(e);
        e->Ety = tym;
        e->E2 = el_una(OPaddr,tym,e->E2);
    L1:
        e = optelem(e,GOALvalue);
        break;
    case OPnegass:
        assert(0);
    default:
        if (OTassign(e1->Eoper))
        {
    case OPstreq:
            //  & (v1 = e) => ((v1 = e), &v1)
            if (e1->E1->Eoper == OPvar)
            {   elem *ex;

                e->Eoper = OPcomma;
                e->E2 = el_una(OPaddr,tym,el_copytree(e1->E1));
                goto L1;
            }
            //  & (*p1 = e) => ((*(t = p1) = e), t)
            else if (e1->E1->Eoper == OPind)
            {   tym_t tym;
                elem *tmp;

                tym = e1->E1->E1->Ety;
                tmp = el_alloctmp(tym);
                e1->E1->E1 = el_bin(OPeq,tym,tmp,e1->E1->E1);
                e->Eoper = OPcomma;
                e->E2 = el_copytree(tmp);
                goto L1;
            }
        }
        break;
    case OPcond:
    {   /* Replace &(x ? y : z) with (x ? &y : &z)      */
        elem *ecolon;

        ecolon = e1->E2;
        ecolon->Ety = tym;
        ecolon->E1 = el_una(OPaddr,tym,ecolon->E1);
        ecolon->E2 = el_una(OPaddr,tym,ecolon->E2);
        e = el_selecte1(e);
        e = optelem(e,GOALvalue);
        break;
    }
    case OPinfo:
        // Replace &(e1 info e2) with (e1 info &e2)
        e = el_selecte1(e);
        e->E2 = el_una(OPaddr,tym,e->E2);
        e = optelem(e,GOALvalue);
        break;
  }
  return e;
}

/*******************************************
 */

STATIC elem * elneg(elem *e, goal_t goal)
{
    if (e->E1->Eoper == OPneg)
    {   e = el_selecte1(e);
        e = el_selecte1(e);
    }
    /* Convert -(e1 + c) to (-e1 - c)
     */
    else if (e->E1->Eoper == OPadd && e->E1->E2->Eoper == OPconst)
    {
        e->Eoper = OPmin;
        e->E2 = e->E1->E2;
        e->E1->Eoper = OPneg;
        e->E1->E2 = NULL;
        e = optelem(e,goal);
    }
    else
        e = evalu8(e, goal);
    return e;
}

STATIC elem * elcall(elem *e, goal_t goal)
{
    if (e->E1->Eoper == OPcomma || OTassign(e->E1->Eoper))
        e = cgel_lvalue(e);
    return e;
}

/***************************
 * Walk tree, converting types to tym.
 */

STATIC void elstructwalk(elem *e,tym_t tym)
{
    tym_t ety;

    while ((ety = tybasic(e->Ety)) == TYstruct ||
           ety == TYarray)
    {   elem_debug(e);
        e->Ety = (e->Ety & ~mTYbasic) | tym;
        switch (e->Eoper)
        {   case OPcomma:
            case OPcond:
            case OPinfo:
                break;
            case OPeq:
            case OPcolon:
            case OPcolon2:
                elstructwalk(e->E1,tym);
                break;
            default:
                return;
        }
        e = e->E2;
    }
}

/*******************************
 * See if we can replace struct operations with simpler ones.
 * For OPstreq and OPstrpar.
 */

elem * elstruct(elem *e, goal_t goal)
{
    //printf("elstruct(%p)\n", e);
    //elem_print(e);
    if (e->Eoper == OPstreq && (e->E1->Eoper == OPcomma || OTassign(e->E1->Eoper)))
        return cgel_lvalue(e);

    if (e->Eoper == OPstreq && e->E2->Eoper == OPcomma)
    {
        /* Replace (e1 streq (e21, e22)) with (e21, (e1 streq e22))
         */
        e->E2->Eoper = e->Eoper;
        e->E2->Ety = e->Ety;
        e->E2->ET = e->ET;
        e->Eoper = OPcomma;
        elem *etmp = e->E1;
        e->E1 = e->E2->E1;
        e->E2->E1 = etmp;
        return optelem(e, goal);
    }

    if (!e->ET)
        return e;
    //printf("\tnumbytes = %d\n", (int)type_size(e->ET));

    tym_t tym = ~0;
    tym_t ty = tybasic(e->ET->Tty);

    type *targ1 = NULL;
    type *targ2 = NULL;
    if (ty == TYstruct)
    {   // If a struct is a wrapper for another type, prefer that other type
        targ1 = e->ET->Ttag->Sstruct->Sarg1type;
        targ2 = e->ET->Ttag->Sstruct->Sarg2type;
    }

    unsigned sz = type_size(e->ET);
    //printf("\tsz = %d\n", (int)sz);
//if (targ1) { printf("targ1\n"); type_print(targ1); }
//if (targ2) { printf("targ2\n"); type_print(targ2); }
    switch ((int)sz)
    {
        case 1:  tym = TYchar;   goto L1;
        case 2:  tym = TYshort;  goto L1;
        case 4:  tym = TYlong;   goto L1;
        case 8:  if (intsize == 2)
                     goto Ldefault;
                 tym = TYllong;  goto L1;

        case 3:  tym = TYlong;  goto L2;
        case 5:
        case 6:
        case 7:  tym = TYllong;
        L2:
            if (e->Eoper == OPstrpar && config.exe == EX_WIN64)
            {
                 goto L1;
            }
            if (e->Eoper == OPstrpar && I64 && ty == TYstruct)
            {
                goto L1;
            }
            tym = ~0;
            goto Ldefault;

        case 10:
        case 12:
            if (tysize(TYldouble) == sz && targ1 && !targ2 && tybasic(targ1->Tty) == TYldouble)
            {   tym = TYldouble;
                goto L1;
            }
        case 9:
        case 11:
        case 13:
        case 14:
        case 15:
            if (e->Eoper == OPstrpar && I64 && ty == TYstruct && config.exe != EX_WIN64)
            {
                goto L1;
            }
            goto Ldefault;

        case 16:
            if (config.fpxmmregs && e->Eoper == OPstreq)
            {
                elem *e2 = e->E2;
                if (tybasic(e2->Ety) == TYstruct &&
                    (EBIN(e2) || EUNA(e2)) &&
                    tysimd(e2->E1->Ety))   // is a vector type
                {   tym = tybasic(e2->E1->Ety);

                    /* This has problems if the destination is not aligned, as happens with
                     *   float4 a,b;
                     *   float[4] c;
                     *   c = cast(float[4])(a + b);
                     */
                    goto L1;
                }
            }
            if (I64 && (ty == TYstruct || (ty == TYarray && config.exe == EX_WIN64)))
            {   tym = TYucent;
                goto L1;
            }
            if (config.exe == EX_WIN64)
                goto Ldefault;
            if (targ1 && !targ2)
                goto L1;
            goto Ldefault;

        L1:
            if (ty == TYstruct)
            {   // This needs to match what TypeFunction::retStyle() does
                if (config.exe == EX_WIN64)
                {
                    //if (e->ET->Ttag->Sstruct->Sflags & STRnotpod)
                        //goto Ldefault;
                }
                // If a struct is a wrapper for another type, prefer that other type
                else if (targ1 && !targ2)
                    tym = targ1->Tty;
                else if (I64 && !targ1 && !targ2)
                {   if (e->ET->Ttag->Sstruct->Sflags & STRnotpod)
                    {
                        // In-memory only
                        goto Ldefault;
                    }
//                    if (type_size(e->ET) == 16)
                        goto Ldefault;
                }
                else if (I64 && targ1 && targ2)
                {   if (tyfloating(tybasic(targ1->Tty)))
                        tym = TYcdouble;
                    else
                        tym = TYucent;
                }
                assert(tym != TYstruct);
            }
            assert(tym != ~0);
            switch (e->Eoper)
            {   case OPstreq:
                    e->Eoper = OPeq;
                    e->Ety = (e->Ety & ~mTYbasic) | tym;
                    elstructwalk(e->E1,tym);
                    elstructwalk(e->E2,tym);
                    e = optelem(e,GOALvalue);
                    break;

                case OPstrpar:
                    e = el_selecte1(e);
                    /* FALL-THROUGH */
                default:                /* called by doptelem()         */
                    elstructwalk(e,tym);
                    break;
            }
            break;
        case 0:
            if (e->Eoper == OPstreq)
            {   e->Eoper = OPcomma;
                e = optelem(e,GOALvalue);
                again = 1;
            }
            else
                goto Ldefault;
            break;

        default:
        Ldefault:
        {
            elem **pe2;
            if (e->Eoper == OPstreq)
                pe2 = &e->E2;
            else if (e->Eoper == OPstrpar)
                pe2 = &e->E1;
            else
                break;
            while ((*pe2)->Eoper == OPcomma)
                pe2 = &(*pe2)->E2;
            elem *e2 = *pe2;

            if (e2->Eoper == OPvar)
                e2->EV.sp.Vsym->Sflags &= ~GTregcand;

            // Convert (x streq (a?y:z)) to (x streq *(a ? &y : &z))
            if (e2->Eoper == OPcond)
            {   tym_t ty2 = e2->Ety;

                /* We should do the analysis to see if we can use
                   something simpler than TYfptr.
                 */
#if TARGET_SEGMENTED
                tym_t typ = (intsize == LONGSIZE) ? TYnptr : TYfptr;
#else
                tym_t typ = TYnptr;
#endif
                e2 = el_una(OPaddr,typ,e2);
                e2 = optelem(e2,GOALvalue);          /* distribute & to x and y leaves */
                *pe2 = el_una(OPind,ty2,e2);
                break;
            }
            break;
        }
    }
    return e;
}

/**************************
 * Assignment. Replace bit field assignment with
 * equivalent tree.
 *              =
 *            /  \
 *           /    r
 *        bit
 *       /   \
 *      l     w,b
 *
 * becomes:
 *          ,
 *         / \
 *        =   (r&m)
 *       / \
 *      l   |
 *         / \
 *  (r&m)<<b  &
 *           / \
 *          l  ~(m<<b)
 * Note:
 *      This depends on the expression (r&m)<<b before l. This is because
 *      of expressions like (l.a = l.b = n). It is an artifact of the way
 *      we do things that this works (cost() will rate the << as more
 *      expensive than the &, and so it will wind up on the left).
 */

STATIC elem * eleq(elem *e, goal_t goal)
{   targ_ullong m;
    unsigned t,w,b;
    unsigned sz;
    elem *l,*l2,*r,*r2,*e1,*eres;
    tym_t tyl;

#if SCPP
    goal_t wantres = goal;
#endif
    e1 = e->E1;

    if (e1->Eoper == OPcomma || OTassign(e1->Eoper))
        return cgel_lvalue(e);

#if 0  // Doesn't work too well, removed
    // Replace (*p++ = e2) with ((*p = e2),*p++)
    if (OPTIMIZER && e1->Eoper == OPind &&
      (e1->E1->Eoper == OPpostinc || e1->E1->Eoper == OPpostdec) &&
      !el_sideeffect(e1->E1->E1)
       )
    {
        e = el_bin(OPcomma,e->Ety,e,e1);
        e->E1->E1 = el_una(OPind,e1->Ety,el_copytree(e1->E1->E1));
        return optelem(e,GOALvalue);
    }
#endif

#if 0 && LNGDBLSIZE == 12
    /* On Linux, long doubles are 12 bytes rather than 10.
     * This means, on assignment, we need to set 12 bytes,
     * so that garbage doesn't creep into the extra 2 bytes
     * and throw off compares.
     */
    tyl = tybasic(e1->Ety);
    if (e1->Eoper == OPvar && (tyl == TYldouble || tyl == TYildouble || tyl == TYcldouble))
    {
#if 1
        elem *ex = el_copytree(e1);
        ex->EV.sp.Voffset += 10;
        ex = el_bin(OPeq, TYshort, ex, el_long(TYshort, 0));
        e = el_combine(ex, e);
        if (tyl == TYcldouble)
        {
            ex = el_copytree(e1);
            ex->EV.sp.Voffset += 10 + 12;
            ex = el_bin(OPeq, TYshort, ex, el_long(TYshort, 0));
            e = el_combine(ex, e);
        }
        return optelem(e, GOALvalue);
#else
        e->Eoper = OPstreq;
        e->Enumbytes = tysize(tyl);
        return elstruct(e);
#endif
    }
#endif

    if (OPTIMIZER)
    {   elem *e2 = e->E2;
        elem *ei;
        int op2 = e2->Eoper;

        // Replace (e1 = *p++) with (e1 = *p, p++, e1)
        ei = e2;
        if (e1->Eoper == OPvar &&
            (op2 == OPind || (OTunary(op2) && (ei = e2->E1)->Eoper == OPind)) &&
            (ei->E1->Eoper == OPpostinc || ei->E1->Eoper == OPpostdec) &&
            !el_sideeffect(e1) &&
            !el_sideeffect(ei->E1->E1)
           )
        {
           e = el_bin(OPcomma,e->Ety,
                e,
                el_bin(OPcomma,e->Ety,ei->E1,el_copytree(e1)));
           ei->E1 = el_copytree(ei->E1->E1);            // copy p
           return optelem(e,GOALvalue);
        }

        /* Replace (e = e) with (e,e)   */
        if (el_match(e1,e2))
        {   e->Eoper = OPcomma;
        L1:
            return optelem(e,GOALvalue);
        }

        // Replace (e1 = (e21 , e22)) with (e21 , (e1 = e22))
        if (op2 == OPcomma)
        {
            e2->Ety = e->Ety;
            e->E2 = e2->E2;
            e2->E2 = e;
            e = e2;
            goto L1;
        }

        if (OTop(op2) && !el_sideeffect(e1)
            && op2 != OPdiv && op2 != OPmod
           )
        {   tym_t ty;
            int op3;

            // Replace (e1 = e1 op e) with (e1 op= e)
            if (el_match(e1,e2->E1))
            {   ty = e2->E2->Ety;
                e->E2 = el_selecte2(e2);
            L2:
                e->E2->Ety = ty;
                e->Eoper = optoopeq(op2);
                goto L1;
            }
            if (OTcommut(op2))
            {
                /* Replace (e1 = e op e1) with (e1 op= e)       */
                if (el_match(e1,e2->E2))
                {   ty = e2->E1->Ety;
                    e->E2 = el_selecte1(e2);
                    goto L2;
                }
            }

#if 0
// Note that this optimization is undone in elcomma(), this results in an
// infinite loop. This optimization is preferable if e1 winds up a register
// variable, the inverse in elcomma() is preferable if e1 winds up in memory.
            // Replace (e1 = (e1 op3 ea) op2 eb) with (e1 op3= ea),(e1 op2= eb)
            op3 = e2->E1->Eoper;
            if (OTop(op3) && el_match(e1,e2->E1->E1) && !el_depends(e1,e2->E2))
            {
                e->Eoper = OPcomma;
                e->E1 = e2->E1;
                e->E1->Eoper = optoopeq(op3);
                e2->E1 = e1;
                e1->Ety = e->E1->Ety;
                e2->Eoper = optoopeq(op2);
                e2->Ety = e->Ety;
                goto L1;
            }
#endif
        }

        if (op2 == OPneg && el_match(e1,e2->E1) && !el_sideeffect(e1))
        {   int offset;

        Ldef:
            // Replace (i = -i) with (negass i)
            e->Eoper = OPnegass;
            e->E2 = NULL;
            el_free(e2);
            return optelem(e, GOALvalue);
        }

        // Replace (x = (y ? z : x)) with ((y && (x = z)),x)
        if (op2 == OPcond && el_match(e1,e2->E2->E2))
        {   elem *e22 = e2->E2;         // e22 is the OPcond

            e->Eoper = OPcomma;
            e->E2 = e1;
            e->E1 = e2;
            e2->Eoper = OPandand;
            e2->Ety = TYint;
            e22->Eoper = OPeq;
            e22->Ety = e->Ety;
            e1 = e22->E1;
            e22->E1 = e22->E2;
            e22->E2 = e1;
            return optelem(e,GOALvalue);
        }

        // Replace (x = (y ? x : z)) with ((y || (x = z)),x)
        if (op2 == OPcond && el_match(e1,e2->E2->E1))
        {   elem *e22 = e2->E2;         // e22 is the OPcond

            e->Eoper = OPcomma;
            e->E2 = e1;
            e->E1 = e2;
            e2->Eoper = OPoror;
            e2->Ety = TYint;
            e22->Eoper = OPeq;
            e22->Ety = e->Ety;
            return optelem(e,GOALvalue);
        }

        // If floating point, replace (x = -y) with (x = y ^ signbit)
        if (op2 == OPneg && (tyreal(e2->Ety) || tyimaginary(e2->Ety)) &&
            (e2->E1->Eoper == OPvar || e2->E1->Eoper == OPind) &&
           /* Turned off for XMM registers because they don't play well with
            * int registers.
            */
           !config.fpxmmregs)
        {   elem *es;
            tym_t ty;

            es = el_calloc();
            es->Eoper = OPconst;
            switch (tysize(e2->Ety))
            {
                case FLOATSIZE:
                    ty = TYlong;
                    es->EV.Vlong = 0x80000000;
                    break;
                case DOUBLESIZE:
#if LONGLONG
                    if (I32)
                    {   ty = TYllong;
                        es->EV.Vllong = 0x8000000000000000LL;
                        break;
                    }
#endif
                default:
                    el_free(es);
                    goto L8;
            }
            es->Ety = ty;
            e1->Ety = ty;
            e2->Ety = ty;
            e2->E1->Ety = ty;
            e2->E2 = es;
            e2->Eoper = OPxor;
            return optelem(e,GOALvalue);
        }
    L8: ;
    }

   if (e1->Eoper == OPcomma)
        return cgel_lvalue(e);
#if MARS
    // No bit fields to deal with
    return e;
#else
  if (e1->Eoper != OPbit)
        return e;
  if (e1->E1->Eoper == OPcomma || OTassign(e1->E1->Eoper))
        return cgel_lvalue(e);
  t = e->Ety;
  l = e1->E1;                           /* lvalue                       */
  r = e->E2;
  tyl = l->Ety;
  sz = tysize(tyl) * 8;
  w = (e1->E2->EV.Vuns >> 8);           /* width in bits of field       */
  m = ((targ_ullong)1 << w) - 1;        // mask w bits wide
  b = e1->E2->EV.Vuns & 0xFF;           /* bits to shift                */

  eres =  el_bin(OPeq,t,
                l,
                el_bin(OPor,t,
                        el_bin(OPshl,t,
                                (r2 = el_bin(OPand,t,r,el_long(t,m))),
                                el_int(TYint,b)
                        ),
                        el_bin(OPand,t,
                                (l2 = el_copytree(l)),
                                el_long(t,~(m << b))
                        )
                )
          );
  eres->Esrcpos = e->Esrcpos;           // save line information
  if (OPTIMIZER && w + b == sz)
        r2->E2->EV.Vllong = ~ZEROLL;    // no need to mask if left justified
  if (wantres)
  {     unsigned c;
        elem **pe;
        elem *e2;

        r = el_copytree(r);
        if (tyuns(tyl))                 /* unsigned bit field           */
        {
            e2 = el_bin(OPand,t,r,el_long(t,m));
            pe = &e2->E1;
        }
        else                            /* signed bit field             */
        {
            c = sz - w;                 /* e2 = (r << c) >> c           */
            e2 = el_bin(OPshr,t,el_bin(OPshl,tyl,r,el_long(TYint,c)),el_long(TYint,c));
            pe = &e2->E1->E1;
        }
        eres = el_bin(OPcomma,t,eres,e2);
        if (EOP(r))
            fixside(&(r2->E1),pe);
  }

  if (EOP(l) && EOP(l->E1))
        fixside(&(l2->E1),&(l->E1));
  e1->E1 = e->E2 = NULL;
  el_free(e);
  return optelem(eres,GOALvalue);
#endif
}

/**********************************
 */

STATIC elem * elnegass(elem *e, goal_t goal)
{
    e = cgel_lvalue(e);
    return e;
}

/**************************
 * Add assignment. Replace bit field assignment with
 * equivalent tree.
 *             +=
 *            /  \
 *           /    r
 *        bit
 *       /   \
 *      l     w,b
 *
 * becomes:
 *                   =
 *                  / \
 *                 l   |
 *                    / \
 *                  <<   \
 *                 /  \   \
 *                &    b   &
 *               / \      / \
 *             op   m    l   ~(m<<b)
 *            /  \
 *           &    r
 *          / \
 *        >>   m
 *       /  \
 *      l    b
 */

STATIC elem * elopass(elem *e, goal_t goal)
{   targ_llong m;
    unsigned w,b,op;
    tym_t t;
    tym_t tyl;
    elem *l,*r,*e1,*l2,*l3,*op2,*eres;

    e1 = e->E1;
    if (OTconv(e1->Eoper))
    {   e = fixconvop(e);
        return optelem(e,GOALvalue);
    }
#if SCPP   // have bit fields to worry about?
    goal_t wantres = goal;
    if (e1->Eoper == OPbit)
    {
        op = opeqtoop(e->Eoper);

        // Make sure t is unsigned
        // so >> doesn't have to be masked
        t = touns(e->Ety);

        assert(tyintegral(t));
        l = e1->E1;                             // lvalue
        tyl = l->Ety;
        r = e->E2;
        w = (e1->E2->EV.Vuns >> 8) & 0xFF;      // width in bits of field
        m = ((targ_llong)1 << w) - 1;           // mask w bits wide
        b = e1->E2->EV.Vuns & 0xFF;             // bits to shift

        if (tyuns(tyl))
        {
            eres = el_bin(OPeq,t,
                    l,
                    el_bin(OPor,t,
                            (op2=el_bin(OPshl,t,
                                    el_bin(OPand,t,
                                            el_bin(op,t,
                                                    el_bin(OPand,t,
                                                        el_bin(OPshr,t,
                                                            (l2=el_copytree(l)),
                                                            el_long(TYint,b)
                                                        ),
                                                        el_long(t,m)
                                                    ),
                                                    r
                                            ),
                                            el_long(t,m)
                                    ),
                                    el_long(TYint,b)
                            )),
                            el_bin(OPand,t,
                                    l3=el_copytree(l),
                                    el_long(t,~(m << b))
                            )
                    )
                );

            if (wantres)
            {   eres = el_bin(OPcomma,t,eres,el_copytree(op2->E1));
                fixside(&(op2->E1),&(eres->E2));
            }
        }
        else
        {   /* signed bit field
               rewrite to:      (l bit w,b) = ((l bit w,b) op r)
             */
            e->Eoper = OPeq;
            e->E2 = el_bin(op,t,el_copytree(e1),r);
            if (l->Eoper == OPind)
                fixside(&e->E2->E1->E1->E1,&l->E1);
            eres = e;
            goto ret;
        }

        if (EOP(l) && EOP(l->E1))
        {   fixside(&(l2->E1),&(l->E1));
            el_free(l3->E1);
            l3->E1 = el_copytree(l->E1);
        }

        e1->E1 = e->E2 = NULL;
        el_free(e);
    ret:
        e = optelem(eres,GOALvalue);
    }
    else
#endif
    {
        if (e1->Eoper == OPcomma || OTassign(e1->Eoper))
            e = cgel_lvalue(e);    // replace (e,v)op=e2 with e,(v op= e2)
        else
        {
            switch (e->Eoper)
            {   case OPmulass:
                    e = elmul(e,GOALvalue);
                    break;
                case OPdivass:
                    // Replace r/=c with r=r/c
                    if (tycomplex(e->E2->Ety) && !tycomplex(e1->Ety))
                    {   elem *ed;

                        e->Eoper = OPeq;
                        if (e1->Eoper == OPind)
                        {   // ed: *(tmp=e1->E1)
                            // e1: *tmp
                            elem *tmp;

                            tmp = el_alloctmp(e1->E1->Ety);
                            ed = el_bin(OPeq, tmp->Ety, tmp, e1->E1);
                            e1->E1 = el_copytree(tmp);
                            ed = el_una(OPind, e1->Ety, ed);
                        }
                        else
                            ed = el_copytree(e1);
                        // e: e1=ed/e2
                        e->E2 = el_bin(OPdiv, e->E2->Ety, ed, e->E2);
                        if (tyreal(e1->Ety))
                            e->E2 = el_una(OPc_r, e1->Ety, e->E2);
                        else
                            e->E2 = el_una(OPc_i, e1->Ety, e->E2);
                        return optelem(e, GOALvalue);
                    }
                    // Repace x/=y with x=x/y
                    if (OPTIMIZER &&
                        tyintegral(e->E1->Ety) &&
                        e->E1->Eoper == OPvar &&
                        !el_sideeffect(e->E1))
                    {
                        e->Eoper = OPeq;
                        e->E2 = el_bin(OPdiv, e->E2->Ety, el_copytree(e->E1), e->E2);
                        return optelem(e, GOALvalue);
                    }
                    e = eldiv(e, GOALvalue);
                    break;

                case OPmodass:
                    // Repace x%=y with x=x%y
                    if (OPTIMIZER &&
                        tyintegral(e->E1->Ety) &&
                        e->E1->Eoper == OPvar &&
                        !el_sideeffect(e->E1))
                    {
                        e->Eoper = OPeq;
                        e->E2 = el_bin(OPmod, e->E2->Ety, el_copytree(e->E1), e->E2);
                        return optelem(e, GOALvalue);
                    }
                    break;
            }
        }
    }
    return e;
}

/**************************
 * Add assignment. Replace bit field post assignment with
 * equivalent tree.
 *      (l bit w,b) ++ r
 * becomes:
 *      (((l bit w,b) += r) - r) & m
 */

STATIC elem * elpost(elem *e, goal_t goal)
{   targ_llong r;
    tym_t ty;
    elem *e1;
    targ_llong m;
    unsigned w,b;

    e1 = e->E1;
    if (e1->Eoper != OPbit)
    {   if (e1->Eoper == OPcomma || OTassign(e1->Eoper))
            return cgel_lvalue(e);    // replace (e,v)op=e2 with e,(v op= e2)
        return e;
    }

    assert(e->E2->Eoper == OPconst);
    r = el_tolong(e->E2);

    w = (e1->E2->EV.Vuns >> 8) & 0xFF;  /* width in bits of field       */
    m = ((targ_llong)1 << w) - 1;       /* mask w bits wide             */

    ty = e->Ety;
    e->Eoper = (e->Eoper == OPpostinc) ? OPaddass : ((r = -r), OPminass);
    e = el_bin(OPmin,ty,e,el_long(ty,r));
    if (tyuns(e1->E1->Ety))             /* if unsigned bit field        */
        e = el_bin(OPand,ty,e,el_long(ty,m));
    return optelem(e,GOALvalue);
}

/***************************
 * Take care of compares.
 *      (e == 0) => (!e)
 *      (e != 0) => (bool e)
 */

STATIC elem * elcmp(elem *e, goal_t goal)
{ elem *e2 = e->E2;
  elem *e1 = e->E1;
  int uns;

  //printf("elcmp(%p)\n",e); elem_print(e);

L1:
  if (OPTIMIZER)
  {
  int op = e->Eoper;

  /* Convert comparison of OPrelconsts of the same symbol to comparisons */
  /* of their offsets.                                                   */
  if (e1->Eoper == OPrelconst && e2->Eoper == OPrelconst &&
      e1->EV.sp.Vsym == e2->EV.sp.Vsym)
  {
        e1->Eoper = OPconst;
        e1->Ety = TYptrdiff;
        e2->Eoper = OPconst;
        e2->Ety = TYptrdiff;
        return optelem(e,GOALvalue);
  }

    // Convert comparison of long pointers to comparison of integers
    if ((op == OPlt || op == OPle || op == OPgt || op == OPge) &&
        tyfv(e2->Ety) && tyfv(e1->Ety))
    {
        e->E1 = el_una(OP32_16,e->Ety,e1);
        e->E2 = el_una(OP32_16,e->Ety,e2);
        return optelem(e,GOALvalue);
    }

    // Convert ((e & 1) == 1) => (e & 1)
    if (op == OPeqeq && e2->Eoper == OPconst && e1->Eoper == OPand)
    {   elem *e12 = e1->E2;

        if (e12->Eoper == OPconst && el_tolong(e2) == 1 && el_tolong(e12) == 1)
        {   tym_t ty1;
            tym_t ty;
            int sz1;
            int sz;

            ty = e->Ety;
            ty1 = e1->Ety;
            e = el_selecte1(e);
            e->Ety = ty1;
            sz = tysize(ty);
            for (sz1 = tysize(ty1); sz1 != sz; sz1 = tysize(e->Ety))
            {
                switch (sz1)
                {
                    case 1:
                        e = el_una(OPu8_16,TYshort,e);
                        break;
                    case 2:
                        if (sz > 2)
                            e = el_una(OPu16_32,TYlong,e);
                        else
                            e = el_una(OP16_8,TYuchar,e);
                        break;
                    case 4:
                        if (sz > 2)
                            e = el_una(OPu32_64,TYshort,e);
                        else
                            e = el_una(OP32_16,TYshort,e);
                        break;
                    case 8:
                        e = el_una(OP64_32,TYlong,e);
                        break;
                    default:
                        assert(0);
                }
            }
            e->Ety = ty;
            return optelem(e,GOALvalue);
        }
    }
  }

  uns = tyuns(e1->Ety) | tyuns(e2->Ety);
  if (cnst(e2))
  {
        tym_t tym;
        int sz;

        if (e1->Eoper == OPu16_32 && e2->EV.Vulong <= (targ_ulong) SHORTMASK ||
                 e1->Eoper == OPs16_32 &&
                 e2->EV.Vlong == (targ_short) e2->EV.Vlong)
        {
                tym = (uns || e1->Eoper == OPu16_32) ? TYushort : TYshort;
                e->E2 = el_una(OP32_16,tym,e2);
                goto L2;
        }

        /* Try to convert to byte/word comparison for ((x & c)==d)
           when mask c essentially casts x to a smaller type
         */
        if (OPTIMIZER &&
            e1->Eoper == OPand &&
            e1->E2->Eoper == OPconst &&
            (sz = tysize(e2->Ety)) > CHARSIZE)
        {   int op;

            assert(tyintegral(e2->Ety) || typtr(e2->Ety));
#if TX86                /* ending up with byte ops in A regs */
            if (!(el_tolong(e2) & ~CHARMASK) &&
                !(el_tolong(e1->E2) & ~CHARMASK)
               )
            {
                if (sz == LLONGSIZE)
                {   e1->E1 = el_una(OP64_32,TYulong,e1->E1);
                    e1->E1 = el_una(OP32_16,TYushort,e1->E1);
                }
                else if (sz == LONGSIZE)
                    e1->E1 = el_una(OP32_16,TYushort,e1->E1);
                tym = TYuchar;
                op = OP16_8;
                goto L4;
            }
#endif
            if (
#if TX86
                intsize == SHORTSIZE && /* not a win when regs are long */
#endif
                sz == LONGSIZE &&
                !(e2->EV.Vulong & ~SHORTMASK) &&
                !(e1->E2->EV.Vulong & ~SHORTMASK)
               )
            {
                tym = TYushort;
                op = OP32_16;
            L4:
                e2->Ety = tym;
                e1->Ety = tym;
                e1->E2->Ety = tym;
                e1->E1 = el_una(op,tym,e1->E1);
                e = optelem(e,GOALvalue);
                goto ret;
            }
        }

        if (e1->Eoper == OPu8_16 && e2->EV.Vuns < 256 ||
                 e1->Eoper == OPs8_16 &&
                 e2->EV.Vint == (targ_schar) e2->EV.Vint)
        {
                tym = (uns || e1->Eoper == OPu8_16) ? TYuchar : TYschar;
                e->E2 = el_una(OP16_8,tym,e2);
            L2:
                tym |= e1->Ety & ~mTYbasic;
                e->E1 = el_selecte1(e1);
                e->E1->Ety = tym;
                e = optelem(e,GOALvalue);
        }
        else if (!boolres(e2))
        {
            switch (e->Eoper)
            {
                targ_int i;

                case OPle:              /* (u <= 0) becomes (u == 0)    */
                    if (!uns)
                        break;
                    /* FALL-THROUGH */
                case OPeqeq:
                    e->Eoper = OPnot;
                    goto L5;
                case OPgt:              /* (u > 0) becomes (u != 0)     */
                    if (!uns)
                        break;
                    /* FALL-THROUGH */
                case OPne:
                    e->Eoper = OPbool;
                L5: el_free(e2);
                    e->E2 = NULL;
                    e = optelem(e,GOALvalue);
                    break;

                case OPge:
                    i = 1;              /* (u >= 0) becomes (u,1)       */
                    goto L3;
                case OPlt:              /* (u < 0) becomes (u,0)        */
                    i = 0;
                L3:
                    if (uns)
                    {
                        e2->EV.Vint = i;
                        e2->Ety = TYint;
                        e->Eoper = OPcomma;
                        e = optelem(e,GOALvalue);
                    }
                    break;
            }
        }
        else if (OPTIMIZER && uns && tysize(e2->Ety) == 2 &&
                 (unsigned short)e2->EV.Vuns == 0x8000 &&
                 (e->Eoper == OPlt || e->Eoper == OPge)
                )
        {       // Convert to signed comparison against 0
                tym_t ty;

                ty = tybasic(e2->Ety);
                switch (tysize[ty])
                {   case 1:     ty = TYschar;   break;
                    case 2:     ty = TYshort;   break;
                    default:    assert(0);
                }
                e->Eoper ^= (OPlt ^ OPge);      // switch between them
                e2->EV.Vuns = 0;
                e2->Ety = ty | (e2->Ety & ~mTYbasic);
                e1->Ety = ty | (e1->Ety & ~mTYbasic);
        }
        else if (OPTIMIZER && e1->Eoper == OPeq &&
                 e1->E2->Eoper == OPconst)
        {    // Convert ((x = c1) rel c2) to ((x = c1),(c1 rel c2)
             elem *ec;

             ec = el_copytree(e1->E2);
             ec->Ety = e1->Ety;
             e->E1 = ec;
             e = el_bin(OPcomma,e->Ety,e1,e);
             e = optelem(e,GOALvalue);
        }
  }
  else if ((
           (e1->Eoper == OPu8_16 || e1->Eoper == OPs8_16)
            || (e1->Eoper == OPu16_32 || e1->Eoper == OPs16_32)
             ) && e1->Eoper == e2->Eoper)
  {     if (uns)
        {   e1->E1->Ety = touns(e1->E1->Ety);
            e2->E1->Ety = touns(e2->E1->Ety);
        }
        e1->Ety = e1->E1->Ety;
        e2->Ety = e2->E1->Ety;
        e->E1 = el_selecte1(e1);
        e->E2 = el_selecte1(e2);
        e = optelem(e,GOALvalue);
  }
ret:
  return e;
}

/*****************************
 * Boolean operator.
 *      OPbool
 */

STATIC elem * elbool(elem *e, goal_t goal)
{
    if (OTlogical(e->E1->Eoper) ||
        // bool bool => bool
        (tybasic(e->E1->Ety) == TYbool && tysize(e->Ety) == 1)
       )
        return el_selecte1(e);

    if (OPTIMIZER)
    {
        int shift;

        // Replace bool(x,1) with (x,1),1
        elem *e1 = elscancommas(e->E1);
        if (cnst(e1) || e1->Eoper == OPrelconst)
        {
            int i = boolres(e1) != 0;
            e->Eoper = OPcomma;
            e->E2 = el_int(e->Ety,i);
            e = optelem(e,GOALvalue);
            return e;
        }

        // Replace bool(e & 1) with (unsigned char)(e & 1)
        else if (e->E1->Eoper == OPand && e->E1->E2->Eoper == OPconst && el_tolong(e->E1->E2) == 1)
        {
        L1:
            unsigned sz = tysize(e->E1->Ety);
            tym_t ty = e->Ety;
            switch (sz)
            {
                case 1:
                    e = el_selecte1(e);
                    break;
                case 2:
                    e->Eoper = OP16_8;
                    break;
                case 4:
                    e->Eoper = OP32_16;
                    e->Ety = TYushort;
                    e = el_una(OP16_8, ty, e);
                    break;
                case 8:
                    e->Eoper = OP64_32;
                    e->Ety = TYulong;
                    e = el_una(OP32_16, TYushort, e);
                    e = el_una(OP16_8, ty, e);
                    break;
                default:
                    assert(0);
            }
            e = optelem(e,GOALvalue);
        }

        // Replace bool(e % 2) with (unsigned char)(e & 1)
        else if (e->E1->Eoper == OPmod && e->E1->E2->Eoper == OPconst && el_tolong(e->E1->E2) == 2)
        {   unsigned sz = tysize(e->E1->Ety);
            tym_t ty = e->Ety;
            e->E1->Eoper = OPand;
            e->E1->E2->EV.Vullong = 1;
            switch (sz)
            {
                case 1:
                    e = el_selecte1(e);
                    break;
                case 2:
                    e->Eoper = OP16_8;
                    break;
                case 4:
                    e->Eoper = OP32_16;
                    e->Ety = TYushort;
                    e = el_una(OP16_8, ty, e);
                    break;
                case 8:
                    e->Eoper = OP64_32;
                    e->Ety = TYulong;
                    e = el_una(OP32_16, TYushort, e);
                    e = el_una(OP16_8, ty, e);
                    break;
                default:
                    assert(0);
            }
            e = optelem(e,GOALvalue);
        }

        // Replace bool((1<<c)&b) with -(b btst c)
        else if ((I32 || I64) &&
                 e->E1->Eoper == OPand &&
                 e->E1->E1->Eoper == OPshl &&
                 e->E1->E1->E1->Eoper == OPconst && el_tolong(e->E1->E1->E1) == 1 &&
                 tysize(e->E1->Ety) <= REGSIZE
                )
        {
            tym_t ty = e->Ety;
            elem *ex = e->E1->E1;
            ex->Eoper = OPbtst;
            e->E1->E1 = NULL;
            ex->E1 = e->E1->E2;
            e->E1->E2 = NULL;
            ex->Ety = e->Ety;
            el_free(e);
            e = ex;
            return optelem(e,GOALvalue);
        }

        // Replace bool(a & c) when c is a power of 2 with ((a >> shift) & 1)
        else if (e->E1->Eoper == OPand &&
                 e->E1->E2->Eoper == OPconst &&
                 (shift = ispow2(el_tolong(e->E1->E2))) != -1
                )
        {
            e->E1->E1 = el_bin(OPshr,e->E1->E1->Ety,e->E1->E1,el_long(TYint, shift));
            e->E1->E2->EV.Vullong = 1;
            goto L1;
        }
    }
    return e;
}


#if TARGET_SEGMENTED
/*********************************
 * Conversions of pointers to far pointers.
 */

STATIC elem * elptrlptr(elem *e, goal_t goal)
{
    if (e->E1->Eoper == OPrelconst || e->E1->Eoper == OPstring)
    {
        e->E1->Ety = e->Ety;
        e = el_selecte1(e);
    }
    return e;
}

/*********************************
 * Conversions of handle pointers to far pointers.
 */
STATIC elem * elvptrfptr(elem *e, goal_t goal)
{   elem *e1;
    elem *e12;
    int op;

    e1 = e->E1;
    if (e1->Eoper == OPadd || e1->Eoper == OPmin)
    {
        e12 = e1->E2;
        if (tybasic(e12->Ety) != TYvptr)
        {
            /* Rewrite (vtof(e11 + e12)) to (vtof(e11) + e12)   */
            op = e->Eoper;
            e->Eoper = e1->Eoper;
            e->E2 = e12;
            e1->Ety = e->Ety;
            e1->Eoper = op;
            e1->E2 = NULL;
            e = optelem(e,GOALvalue);
        }
    }
    return e;
}

#endif

/************************
 * Optimize conversions of longs to ints.
 * Also used for (OPoffset) (TYfptr|TYvptr).
 * Also used for conversions of ints to bytes.
 */

STATIC elem * ellngsht(elem *e, goal_t goal)
{ elem *e1;
  tym_t ty;

  ty = e->Ety;
  e1 = e->E1;
  switch (e1->Eoper)
  { case OPs16_32:
    case OPu16_32:
    case OPu8_16:
    case OPs8_16:
        /* This fix is not quite right. For example, it fails   */
        /* if e->Ety != e->E1->E1->Ety. The difference is when */
        /* one is unsigned and the other isn't.                 */
        if (tysize(ty) != tysize(e->E1->E1->Ety))
            break;
        e = el_selecte1(el_selecte1(e));
        e->Ety = ty;
        return e;
    case OPvar:                 /* simply paint type of variable */
        /* Do not paint type of ints into bytes, as this causes         */
        /* many CSEs to be missed, resulting in bad code.               */
        /* Loading a word anyway is just as fast as loading a byte.     */
        /* for 68000 byte is swapped, load byte != load word */
        if (e->Eoper == OP16_8)
        {
            /* Mark symbol as being used sometimes as a byte to         */
            /* 80X86 - preclude using SI or DI                          */
            /* 68000 - preclude using An                                */
            e1->EV.sp.Vsym->Sflags |= GTbyte;
        }
        else
            e1->Ety = ty;
        e = el_selecte1(e);
        break;
    case OPind:
        e = el_selecte1(e);
        break;

#if TARGET_SEGMENTED
    case OPnp_fp:
        if (e->Eoper != OPoffset)
            goto case_default;
        // Replace (offset)(ptrlptr)e11 with e11
        e = el_selecte1(el_selecte1(e));
        e->Ety = ty;                    // retain original type
        break;
#endif

    default: /* operator */
    case_default:
        /* Attempt to replace (lngsht)(a op b) with             */
        /* ((lngsht)a op (lngsht)b).                            */
        /* op is now an integer op, which is cheaper.           */
        if (OTwid(e1->Eoper) && !OTassign(e1->Eoper))
        {   tym_t ty1;

            ty1 = e1->E1->Ety;
            switch (e->Eoper)
            {   case OP16_8:
                    /* Make sure e1->E1 is of the type we're converting from */
                    if (tysize(ty1) <= intsize)
                    {
                        ty1 = (tyuns(ty1) ? TYuchar : TYschar) |
                                    (ty1 & ~mTYbasic);
                        e1->E1 = el_una(e->Eoper,ty1,e1->E1);
                    }
                    /* Rvalue may be an int if it is a shift operator */
                    if (OTbinary(e1->Eoper))
                    {   tym_t ty2 = e1->E2->Ety;

                        if (tysize(ty2) <= intsize)
                        {
                            ty2 = (tyuns(ty2) ? TYuchar : TYschar) |
                                        (ty2 & ~mTYbasic);
                            e1->E2 = el_una(e->Eoper,ty2,e1->E2);
                        }
                    }
                    break;
#if TARGET_SEGMENTED
                case OPoffset:
                    if (intsize == LONGSIZE)
                    {
                        /* Make sure e1->E1 is of the type we're converting from */
                        if (tysize(ty1) > LONGSIZE)
                        {
                            ty1 = (tyuns(ty1) ? TYuint : TYint) | (ty1 & ~mTYbasic);
                            e1->E1 = el_una(e->Eoper,ty1,e1->E1);
                        }
                        /* Rvalue may be an int if it is a shift operator */
                        if (OTbinary(e1->Eoper))
                        {   tym_t ty2 = e1->E2->Ety;

                            if (tysize(ty2) > LONGSIZE)
                            {
                                ty2 = (tyuns(ty2) ? TYuint : TYint) |
                                            (ty2 & ~mTYbasic);
                                e1->E2 = el_una(e->Eoper,ty2,e1->E2);
                            }
                        }
                        break;
                    }
                    /* FALL-THROUGH */
#endif
                case OP32_16:
                    /* Make sure e1->E1 is of the type we're converting from */
                    if (tysize(ty1) == LONGSIZE)
                    {
                        ty1 = (tyuns(ty1) ? TYushort : TYshort) | (ty1 & ~mTYbasic);
                        e1->E1 = el_una(e->Eoper,ty1,e1->E1);
                    }
                    /* Rvalue may be an int if it is a shift operator */
                    if (OTbinary(e1->Eoper))
                    {   tym_t ty2 = e1->E2->Ety;

                        if (tysize(ty2) == LONGSIZE)
                        {
                            ty2 = (tyuns(ty2) ? TYushort : TYshort) |
                                        (ty2 & ~mTYbasic);
                            e1->E2 = el_una(e->Eoper,ty2,e1->E2);
                        }
                    }
                    break;
                default:
                    assert(0);
            }
            e1->Ety = ty;
            e = el_selecte1(e);
            again = 1;
            return e;
        }
        break;
  }
  return e;
}


/************************
 * Optimize conversions of long longs to ints.
 * OP64_32, OP128_64
 */

STATIC elem * el64_32(elem *e, goal_t goal)
{
  tym_t ty = e->Ety;
  elem *e1 = e->E1;
  switch (e1->Eoper)
  {
    case OPs32_64:
    case OPu32_64:
    case OPs64_128:
    case OPu64_128:
    case OPpair:
        if (tysize(ty) != tysize(e->E1->E1->Ety))
            break;
        e = el_selecte1(el_selecte1(e));
        e->Ety = ty;
        break;

    case OPrpair:
        if (tysize(ty) != tysize(e->E1->E2->Ety))
            break;
        e = el_selecte2(el_selecte1(e));
        e->Ety = ty;
        break;

    case OPvar:                 // simply paint type of variable
    case OPind:
        e = el_selecte1(e);
        break;

    case OPshr:                 // OP64_32(x >> 32) => OPmsw(x)
        if (e1->E2->Eoper == OPconst &&
            (e->Eoper == OP64_32 && el_tolong(e1->E2) == 32 && !I64 ||
             e->Eoper == OP128_64 && el_tolong(e1->E2) == 64 && I64)
           )
        {
            e->Eoper = OPmsw;
            e->E1 = el_selecte1(e->E1);
        }
        break;
  }
  return e;
}


/*******************************
 * Convert complex to real.
 */

STATIC elem *elc_r(elem *e, goal_t goal)
{
    elem *e1 = e->E1;

    if (e1->Eoper == OPvar || e1->Eoper == OPind)
    {
        e1->Ety = e->Ety;
        e = el_selecte1(e);
    }
    return e;
}

/*******************************
 * Convert complex to imaginary.
 */

STATIC elem *elc_i(elem *e, goal_t goal)
{
    elem *e1 = e->E1;

    if (e1->Eoper == OPvar)
    {
        e1->Ety = e->Ety;
        e1->EV.sp.Voffset += tysize(e->Ety);
        e = el_selecte1(e);
    }
    else if (e1->Eoper == OPind)
    {
        e1->Ety = e->Ety;
        e = el_selecte1(e);
        e->E1 = el_bin(OPadd, e->E1->Ety, e->E1, el_long(TYint, tysize(e->Ety)));
        return optelem(e, GOALvalue);
    }

    return e;
}

/******************************
 * Handle OPu8_16 and OPs8_16.
 */

STATIC elem * elbyteint(elem *e, goal_t goal)
{
    if (OTlogical(e->E1->Eoper) || e->E1->Eoper == OPbtst)
    {
        e->E1->Ety = e->Ety;
        e = el_selecte1(e);
        return e;
    }
    return evalu8(e, goal);
}

/******************************
 * OPs32_64
 * OPu32_64
 */
STATIC elem * el32_64(elem *e, goal_t goal)
{
    if (REGSIZE == 8 && e->E1->Eoper == OPbtst)
    {
        e->E1->Ety = e->Ety;
        e = el_selecte1(e);
        return e;
    }
    return evalu8(e, goal);
}

/****************************
 * Handle OPu64_d
 */

STATIC elem *elu64_d(elem *e, goal_t goal)
{
    if (e->E1->Eoper != OPconst && (I64 || (I32 && config.inline8087)))
    {
        /* Rewrite as:
         *    u >= 0 ? OPi64_d(u) : OPi64_d(u & 0x7FFF_FFFF_FFFF_FFFF) + 0x8000_0000_0000_0000
         */
        elem *u = e->E1;
        u->Ety = TYllong;
        elem *u1 = el_copytree(u);
        if (EOP(u))
            fixside(&u, &u1);
        elem *u2 = el_copytree(u1);

        u = el_bin(OPge, TYint, u, el_long(TYllong, 0));

        u1 = el_una(OPs64_d, e->Ety, u1);

        u2 = el_bin(OPand, TYllong, u2, el_long(TYllong, 0x7FFFFFFFFFFFFFFFLL));
        u2 = el_una(OPs64_d, e->Ety, u2);
        elem *eadjust = el_una(OPu64_d, e->Ety, el_long(TYullong, 0x8000000000000000LL));
        u2 = el_bin(OPadd, e->Ety, u2, eadjust);

        e->Eoper = OPcond;
        e->E1 = u;
        e->E2 = el_bin(OPcolon, e->Ety, u1, u2);
        return optelem(e, GOALvalue);
    }
    else
        return evalu8(e, goal);
}


/************************
 * Handle <<, OProl and OPror
 */

STATIC elem *elshl(elem *e, goal_t goal)
{
    if (e->E1->Eoper == OPconst && !boolres(e->E1))             // if e1 is 0
    {   e->E1->Ety = e->Ety;
        e = el_selecte1(e);             // (0 << e2) => 0
    }
    if (OPTIMIZER &&
        e->E2->Eoper == OPconst &&
        (e->E1->Eoper == OPshr || e->E1->Eoper == OPashr) &&
        e->E1->E2->Eoper == OPconst &&
        el_tolong(e->E2) == el_tolong(e->E1->E2))
    {   /* Rewrite:
         *  (x >> c) << c)
         * with:
         *  x & ~((1 << c) - 1);
         */
        targ_ullong c = el_tolong(e->E2);
        e = el_selecte1(e);
        e = el_selecte1(e);
        e = el_bin(OPand, e->Ety, e, el_long(e->Ety, ~((1ULL << c) - 1)));
        return optelem(e, goal);
    }
    return e;
}

/************************
 * Handle >>
 * OPshr, OPashr
 */

STATIC elem * elshr(elem *e, goal_t goal)
{
#if TX86
    tym_t ty = e->Ety;
    elem *e1 = e->E1;
    elem *e2 = e->E2;

    // (x >> 16) replaced with ((shtlng) x+2)
    if (OPTIMIZER &&
        e2->Eoper == OPconst && e2->EV.Vshort == SHORTSIZE * 8 &&
        tysize(ty) == LONGSIZE)
    {
        if (e1->Eoper == OPvar)
        {
            Symbol *s = e1->EV.sp.Vsym;

            if (s->Sclass != SCfastpar && s->Sclass != SCshadowreg)
            {
                e1->EV.sp.Voffset += SHORTSIZE; // address high word in long
                if (I32)
                    // Cannot independently address high word of register
                    s->Sflags &= ~GTregcand;
                goto L1;
            }
        }
        else if (e1->Eoper == OPind)
        {
            /* Replace (*p >> 16) with (shtlng)(*(&*p + 2))     */
            e->E1 = el_una(OPind,TYshort,
                        el_bin(OPadd,e1->E1->Ety,
                                el_una(OPaddr,e1->E1->Ety,e1),
                                el_int(TYint,SHORTSIZE)));
        L1:
            e->Eoper = tyuns(e1->Ety) ? OPu16_32 : OPs16_32;
            el_free(e2);
            e->E2 = NULL;
            e1->Ety = TYshort;
            e = optelem(e,GOALvalue);
        }
    }

    // (x >> 32) replaced with ((lngllng) x+4)
    if (e2->Eoper == OPconst && e2->EV.Vlong == LONGSIZE * 8 &&
        tysize(ty) == LLONGSIZE)
    {
        if (e1->Eoper == OPvar)
        {
            e1->EV.sp.Voffset += LONGSIZE;      // address high dword in longlong
            if (I64)
                // Cannot independently address high word of register
                e1->EV.sp.Vsym->Sflags &= ~GTregcand;
            goto L2;
        }
        else if (e1->Eoper == OPind)
        {
            // Replace (*p >> 32) with (lngllng)(*(&*p + 4))
            e->E1 = el_una(OPind,TYlong,
                        el_bin(OPadd,e1->E1->Ety,
                                el_una(OPaddr,e1->E1->Ety,e1),
                                el_int(TYint,LONGSIZE)));
        L2:
            e->Eoper = tyuns(e1->Ety) ? OPu32_64 : OPs32_64;
            el_free(e2);
            e->E2 = NULL;
            e1->Ety = TYlong;
            e = optelem(e,GOALvalue);
        }
    }
#endif
  return e;
}

/***********************************
 * Handle OPmsw.
 */

elem *elmsw(elem *e, goal_t goal)
{
#if TX86
    tym_t ty = e->Ety;
    elem *e1 = e->E1;

    if (OPTIMIZER &&
        tysize(e1->Ety) == LLONGSIZE &&
        tysize(ty) == LONGSIZE)
    {
        // Replace (int)(msw (long)x) with (int)*(&x+4)
        if (e1->Eoper == OPvar)
        {
            e1->EV.sp.Voffset += LONGSIZE;      // address high dword in longlong
            if (I64)
                // Cannot independently address high word of register
                e1->EV.sp.Vsym->Sflags &= ~GTregcand;
            e1->Ety = ty;
            e = optelem(e1,GOALvalue);
        }
        // Replace (int)(msw (long)*x) with (int)*(&*x+4)
        else if (e1->Eoper == OPind)
        {
            e1 = el_una(OPind,ty,
                el_bin(OPadd,e1->E1->Ety,
                    el_una(OPaddr,e1->E1->Ety,e1),
                    el_int(TYint,LONGSIZE)));
            e = optelem(e1,GOALvalue);
        }
        else
        {
            e = evalu8(e, goal);
        }
    }
    else if (OPTIMIZER && I64 &&
        tysize(e1->Ety) == CENTSIZE &&
        tysize(ty) == LLONGSIZE)
    {
        // Replace (long)(msw (cent)x) with (long)*(&x+8)
        if (e1->Eoper == OPvar)
        {
            e1->EV.sp.Voffset += LLONGSIZE;      // address high dword in longlong
            e1->Ety = ty;
            e = optelem(e1,GOALvalue);
        }
        // Replace (long)(msw (cent)*x) with (long)*(&*x+8)
        else if (e1->Eoper == OPind)
        {
            e1 = el_una(OPind,ty,
                el_bin(OPadd,e1->E1->Ety,
                    el_una(OPaddr,e1->E1->Ety,e1),
                    el_int(TYint,LLONGSIZE)));
            e = optelem(e1,GOALvalue);
        }
        else
        {
            e = evalu8(e, goal);
        }
    }
    else
    {
        e = evalu8(e, goal);
    }

#endif
    return e;
}

/***********************************
 * Handle OPpair, OPrpair.
 */

elem *elpair(elem *e, goal_t goal)
{
    elem *e1;

    //printf("elpair()\n");
    e1 = e->E1;
    if (e1->Eoper == OPconst)
    {
        e->E1 = e->E2;
        e->E2 = e1;
        e->Eoper ^= OPpair ^ OPrpair;
    }
    return e;
}

/********************************
 * Handle OPddtor
 */

elem *elddtor(elem *e, goal_t goal)
{
    return e;
}

/********************************
 * Handle OPinfo, OPmark, OPctor, OPdtor
 */

STATIC elem * elinfo(elem *e, goal_t goal)
{
    //printf("elinfo()\n");
#if NTEXCEPTIONS && SCPP
    if (funcsym_p->Sfunc->Fflags3 & Fnteh)
    {   // Eliminate cleanup info if using NT structured EH
        if (e->Eoper == OPinfo)
            e = el_selecte2(e);
        else
        {   el_free(e);
            e = el_long(TYint,0);
        }
    }
#endif
    return e;
}

/********************************************
 */

STATIC elem * elhstring(elem *e, goal_t goal)
{
    return e;
}

/********************************************
 */

STATIC elem * elnullcheck(elem *e, goal_t goal)
{
    return e;
}


/********************************************
 */

STATIC elem * elclassinit(elem *e, goal_t goal)
{
    return e;
}

/********************************************
 */

STATIC elem * elnewarray(elem *e, goal_t goal)
{
    return e;
}

/********************************************
 */

STATIC elem * elmultinewarray(elem *e, goal_t goal)
{
    return e;
}

/********************************************
 */

STATIC elem * elinstanceof(elem *e, goal_t goal)
{
    return e;
}

/********************************************
 */

STATIC elem * elfinalinstanceof(elem *e, goal_t goal)
{
    return e;
}

/********************************************
 */

STATIC elem * elcheckcast(elem *e, goal_t goal)
{
    return e;
}

/********************************************
 */

STATIC elem * elarraylength(elem *e, goal_t goal)
{
    return e;
}

/********************************************
 */

#if TX86 && MARS
STATIC elem * elvalist(elem *e, goal_t goal)
{
    assert(e->Eoper == OPva_start);

#if TARGET_WINDOS

    assert(config.exe == EX_WIN64); // va_start is not an intrinsic on 32-bit

    // (OPva_start &va)
    // (OPeq (OPind E1) (OPptr &lastNamed+8))
    //elem_print(e);

    // Find last named parameter
    symbol *lastNamed = NULL;
    for (SYMIDX si = 0; si < globsym.top; si++)
    {
        symbol *s = globsym.tab[si];

        if (s->Sclass == SCfastpar || s->Sclass == SCshadowreg)
            lastNamed = s;
    }

    e->Eoper = OPeq;
    e->E1 = el_una(OPind, TYnptr, e->E1);
    if (lastNamed)
    {
        e->E2 = el_ptr(lastNamed);
        e->E2->EV.sp.Voffset = REGSIZE;
    }
    else
        e->E2 = el_long(TYnptr, 0);
    //elem_print(e);

#endif

#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS

    assert(I64); // va_start is not an intrinsic on 32-bit
    // (OPva_start &va)
    // (OPeq (OPind E1) __va_argsave+offset)
    //elem_print(e);

    // Find __va_argsave
    symbol *va_argsave = NULL;
    for (SYMIDX si = 0; si < globsym.top; si++)
    {
        symbol *s = globsym.tab[si];
        if (s->Sident[0] == '_' && strcmp(s->Sident, "__va_argsave") == 0)
        {
            va_argsave = s;
            break;
        }
    }

    e->Eoper = OPeq;
    e->E1 = el_una(OPind, TYnptr, e->E1);
    if (va_argsave)
    {
        e->E2 = el_ptr(va_argsave);
        e->E2->EV.sp.Voffset = 6 * 8 + 8 * 16;
    }
    else
        e->E2 = el_long(TYnptr, 0);
    //elem_print(e);
#endif

    return e;
}
#endif

/********************************************
 */

STATIC elem * elarray(elem *e, goal_t goal)
{
    return e;
}

/********************************************
 */

STATIC elem * elfield(elem *e, goal_t goal)
{
    return e;
}

/******************************************
 * OPparam
 */

STATIC void elparamx(elem *e)
{
    //printf("elparam()\n");
    if (e->E1->Eoper == OPrpair)
    {
        e->E1->Eoper = OPparam;
    }
    else if (e->E1->Eoper == OPpair && !el_sideeffect(e->E1))
    {
        e->E1->Eoper = OPparam;
        elem *ex = e->E1->E2;
        e->E1->E2 = e->E1->E1;
        e->E1->E1 = ex;
    }
#if 0
    // Unfortunately, these don't work because if the last parameter
    // is a pair, and it is a D function, the last parameter will get
    // passed in EAX.
    else if (e->E2->Eoper == OPrpair)
    {
        e->E2->Eoper = OPparam;
    }
    else if (e->E2->Eoper == OPpair)
    {
        e->E2->Eoper = OPparam;
        elem *ex = e->E2->E2;
        e->E2->E2 = e->E2->E1;
        e->E2->E1 = ex;
    }
#endif
}

STATIC elem * elparam(elem *e, goal_t goal)
{
    if (!OPTIMIZER)
    {
        if (!I64)
            elparamx(e);
    }
    return e;
}

/********************************
 * Optimize an element. This routine is recursive!
 * Be careful not to do this if VBEs have been done (else the VBE
 * work will be undone), or if DAGs have been built (will crash if
 * there is more than one parent for an elem).
 * If (goal)
 *      we care about the result.
 */

STATIC elem * optelem(elem *e, goal_t goal)
{ elem *e1,*e2;
  unsigned op;
#include "elxxx.c"                      /* jump table                   */

beg:
#if MARS
    util_progress();
#else
    if (controlc_saw)
        util_exit(EXIT_BREAK);
#endif
    //{ printf("xoptelem: %p ",e); WROP(e->Eoper); dbg_printf(" goal x%x\n", goal); }
    assert(e);
    elem_debug(e);
    assert(e->Ecount == 0);             // no CSEs

    if (OPTIMIZER)
    {
        if (goal)
            e->Nflags &= ~NFLnogoal;
        else
            e->Nflags |= NFLnogoal;
    }

    op = e->Eoper;
    if (OTleaf(op))                     // if not an operator node
    {
        if (goal || OTsideff(op) || e->Ety & mTYvolatile)
        {
            return e;
        }
        else
        {
            retnull:
                el_free(e);
                return NULL;
        }
    }
    else if (OTbinary(op))              // if binary operator
    {   goal_t leftgoal = GOALvalue;
        goal_t rightgoal;

        /* Determine goals for left and right subtrees  */
        rightgoal = (goal || OTsideff(op)) ? GOALvalue : GOALnone;
        switch (op)
        {   case OPcomma:
                e1 = e->E1 = optelem(e->E1,GOALnone);
//              if (e1 && !OTsideff(e1->Eoper))
//                  e1 = e->E1 = optelem(e1, GOALnone);
                e2 = e->E2 = optelem(e->E2,rightgoal);
                if (!e1)
                {   if (!e2)
                        goto retnull;
                    if (!goal)
                        e->Ety = e->E2->Ety;
                    e = el_selecte2(e);
                    return e;
                }
                if (!e2)
                {   e->Ety = e->E1->Ety;
                    return el_selecte1(e);
                }
                if (!goal)
                    e->Ety = e2->Ety;
                return e;

            case OPcond:
                if (!goal)
                {   // Transform x?y:z into x&&y or x||z
                    elem *e2 = e->E2;
                    if (!el_sideeffect(e2->E1))
                    {   e->Eoper = OPoror;
                        e->E2 = el_selecte2(e2);
                        e->Ety = TYint;
                        goto beg;
                    }
                    else if (!el_sideeffect(e2->E2))
                    {   e->Eoper = OPandand;
                        e->E2 = el_selecte1(e2);
                        e->Ety = TYint;
                        goto beg;
                    }
                    assert(e2->Eoper == OPcolon || e2->Eoper == OPcolon2);
                    elem *e21 = e2->E1 = optelem(e2->E1, goal);
                    elem *e22 = e2->E2 = optelem(e2->E2, goal);
                    if (!e21)
                    {
                        if (!e22)
                        {
                            e = el_selecte1(e);
                            goto beg;
                        }
                        // Rewrite (e1 ? null : e22) as (e1 || e22)
                        e->Eoper = OPoror;
                        e->E2 = el_selecte2(e2);
                        goto beg;
                    }
                    if (!e22)
                    {
                        // Rewrite (e1 ? e21 : null) as (e1 && e21)
                        e->Eoper = OPandand;
                        e->E2 = el_selecte1(e2);
                        goto beg;
                    }
                    if (!rightgoal)
                        rightgoal = GOALvalue;
                }
                goto Llog;

            case OPoror:
                if (rightgoal)
                    rightgoal = GOALflags;
                if (OPTIMIZER && optim_loglog(&e))
                    goto beg;
                goto Llog;

            case OPandand:
                if (rightgoal)
                    rightgoal = GOALflags;
                if (OPTIMIZER && optim_loglog(&e))
                    goto beg;

            Llog:               // case (c log f()) with no goal
                if (goal || el_sideeffect(e->E2))
                    leftgoal = GOALflags;
                break;

            default:
                leftgoal = rightgoal;
                break;
            case OPcolon:
            case OPcolon2:
                if (!goal && !el_sideeffect(e))
                    goto retnull;
                leftgoal = rightgoal;
                break;
            case OPmemcmp:
                if (!goal)
                {   // So OPmemcmp is removed cleanly
                    assert(e->E1->Eoper == OPparam);
                    e->E1->Eoper = OPcomma;
                }
                leftgoal = rightgoal;
                break;
        }

        e1 = e->E1;
        if (OTassign(op))
        {   elem *ex = e1;

            while (OTconv(ex->Eoper))
                ex = ex->E1;
            if (ex->Eoper == OPbit)
                ex->E1 = optelem(ex->E1, leftgoal);
            else if (e1->Eoper == OPu64_d)
                e1->E1 = optelem(e1->E1, leftgoal);
            else if ((e1->Eoper == OPd_ld || e1->Eoper == OPd_f) && e1->E1->Eoper == OPu64_d)
                e1->E1->E1 = optelem(e1->E1->E1, leftgoal);
            else
                e1 = e->E1 = optelem(e1,leftgoal);
        }
        else
            e1 = e->E1 = optelem(e1,leftgoal);

        e2 = e->E2 = optelem(e->E2,rightgoal);
        if (!e1)
        {   if (!e2)
                goto retnull;
            return el_selecte2(e);
        }
        if (!e2)
        {
            if (!leftgoal)
                e->Ety = e1->Ety;
            return el_selecte1(e);
        }
        if (op == OPparam && !goal)
            e->Eoper = OPcomma; // DMD bug 6733

        if (cnst(e1) && cnst(e2))
        {
            e = evalu8(e, GOALvalue);
            return e;
        }
        if (OPTIMIZER)
        {
          if (OTassoc(op))
          {
            /* Replace (a op1 (b op2 c)) with ((a op2 b) op1 c)
               (this must come before the leaf swapping, or we could cause
               infinite loops)
             */
            if (e2->Eoper == op &&
                e2->E2->Eoper == OPconst &&
                tysize(e2->E1->Ety) == tysize(e2->E2->Ety) &&
                (!tyfloating(e1->Ety) || e1->Ety == e2->Ety)
               )
            {
              e->E1 = e2;
              e->E2 = e2->E2;
              e2->E2 = e2->E1;
              e2->E1 = e1;
              if (op == OPadd)  /* fix types                    */
              {
                  e1 = e->E1;
                  if (typtr(e1->E2->Ety))
                      e1->Ety = e1->E2->Ety;
                  else
                      /* suppose a and b are ints, and c is a pointer   */
                      /* then this will fix the type of op2 to be int   */
                      e1->Ety = e1->E1->Ety;
              }
              goto beg;
            }

            // Replace ((a op c1) op c2) with (a op (c2 op c1))
            if (e1->Eoper == op &&
                e2->Eoper == OPconst &&
                e1->E2->Eoper == OPconst &&
                e1->E1->Eoper != OPconst &&
                tysize(e2->Ety) == tysize(e1->E2->Ety))
            {
                e->E1 = e1->E1;
                e1->E1 = e2;
                e1->Ety = e2->Ety;
                e->E2 = e1;

                if (tyfloating(e1->Ety))
                {
                    e1 = evalu8(e1, GOALvalue);
                    if (EOP(e1))        // if failed to fold the constants
                    {   // Undo the changes so we don't infinite loop
                        e->E2 = e1->E1;
                        e1->E1 = e->E1;
                        e->E1 = e1;
                    }
                    else
                    {   e->E2 = e1;
                        goto beg;
                    }
                }
                else
                    goto beg;
            }
          }

          if (!OTrtol(op) && op != OPparam && op != OPcolon && op != OPcolon2 &&
              e1->Eoper == OPcomma)
          {     // Convert ((a,b) op c) to (a,(b op c))
                e1->Ety = e->Ety;
                e1->ET = e->ET;
                e->E1 = e1->E2;
                e1->E2 = e;
                e = e1;
                goto beg;
          }
        }

        if (OTcommut(op))                // if commutative
        {
              /* see if we should swap the leaves       */
#if 0
              if (tyfloating(e1->Ety))
              {
                    if (fcost(e2) > fcost(e1))
                    {   e->E1 = e2;
                        e2 = e->E2 = e1;
                        e1 = e->E1;             // reverse the leaves
                        op = e->Eoper = swaprel(op);
                    }
              }
              else
#endif
              if (
#if MARS
                cost(e2) > cost(e1)
                /* Swap only if order of evaluation can be proved
                 * to not matter, as we must evaluate Left-to-Right
                 */
                && (e1->Eoper == OPconst ||
                    e1->Eoper == OPrelconst ||
                    /* Local variables that are not aliased
                     * and are not assigned to in e2
                     */
                    (e1->Eoper == OPvar && e1->EV.sp.Vsym->Sflags & SFLunambig && !el_appears(e2,e1->EV.sp.Vsym)) ||
                    !(el_sideeffect(e1) || el_sideeffect(e2))
                   )
#else
                cost(e2) > cost(e1)
#endif
                 )
              {
                    e->E1 = e2;
                    e2 = e->E2 = e1;
                    e1 = e->E1;         // reverse the leaves
                    op = e->Eoper = swaprel(op);
              }
              if (OTassoc(op))          // if commutative and associative
              {
                  if (EOP(e1) &&
                      op == e1->Eoper &&
                      e1->E2->Eoper == OPconst &&
                      e->Ety == e1->Ety &&
                      tysize(e1->E2->Ety) == tysize(e2->Ety)
#if MARS
                      // Reordering floating point can change the semantics
                      && !tyfloating(e1->Ety)
#endif
                     )
                  {
                        // look for ((e op c1) op c2),
                        // replace with (e op (c1 op c2))
                        if (e2->Eoper == OPconst)
                        {
                            e->E1 = e1->E1;
                            e->E2 = e1;
                            e1->E1 = e1->E2;
                            e1->E2 = e2;
                            e1->Ety = e2->Ety;

                            e1 = e->E1;
                            e2 = e->E2 = evalu8(e->E2, GOALvalue);
                        }
                        else
                        {   // Replace ((e op c) op e2) with ((e op e2) op c)
                            e->E2 = e1->E2;
                            e1->E2 = e2;
                            e2 = e->E2;
                        }
                  }
              }
        }

        if (e2->Eoper == OPconst &&             // if right operand is a constant
            !(OTopeq(op) && OTconv(e1->Eoper))
           )
        {
#ifdef DEBUG
            assert(!(OTeop0e(op) && (OTeop00(op))));
#endif
            if (OTeop0e(op))            /* if e1 op 0 => e1             */
            {
                if (!boolres(e2))       /* if e2 is 0                   */
                {
                    // Don't do it for ANSI floating point
                    if (tyfloating(e1->Ety) && !(config.flags4 & CFG4fastfloat))
                        ;
                    // Don't do it if we're assembling a complex value
                    else if ((tytab[e->E1->Ety & 0xFF] ^
                         tytab[e->E2->Ety & 0xFF]) == (TYFLreal | TYFLimaginary))
                        ;
                    else
                        return optelem(el_selecte1(e),goal);
                }
            }
            else if (OTeop00(op) && !boolres(e2) && !tyfloating(e->Ety))
            {   if (OTassign(op))
                    op = e->Eoper = OPeq;
                else
                    op = e->Eoper = OPcomma;
            }
            if (OTeop1e(op))            /* if e1 op 1 => e1             */
            {
                if (elemisone(e2) && !tyimaginary(e2->Ety))
                    return optelem(el_selecte1(e),goal);
            }
        }

        if (OTpost(op) && !goal)
        {
            op = e->Eoper = (op == OPpostinc) ? OPaddass : OPminass;
        }
  }
  else /* unary operator */
  {
        assert(!e->E2 || op == OPinfo || op == OParraylength || op == OPddtor);
        if (!goal && !OTsideff(op) && !(e->Ety & mTYvolatile))
        {
            tym_t tym = e->E1->Ety;

            e = el_selecte1(e);
            e->Ety = tym;
            return optelem(e,GOALnone);
        }

        e1 = e->E1 = optelem(e->E1,(op == OPbool || op == OPnot) ? GOALflags : GOALvalue);
        if (e1->Eoper == OPconst)
        {
#if TARGET_SEGMENTED
            if (!(op == OPnp_fp && el_tolong(e1) != 0))
#endif
                return evalu8(e, GOALvalue);
        }
        e2 = NULL;
  }

L1:
#ifdef DEBUG
//  if (debugb)
//  {   dbg_printf("optelem: %p ",e); WROP(op); dbg_printf("\n"); }
#endif

#if 0
    {   dbg_printf("xoptelem: %p ",e); WROP(e->Eoper); dbg_printf("\n"); }
  elem_print(e);
  e = (*elxxx[op])(e, goal);
  printf("After:\n");
  elem_print(e);
  return e;
#else
  return (*elxxx[op])(e, goal);
#endif
}

/********************************
 * Optimize and canonicalize an expression tree.
 * Fiddle with double operators so that the rvalue is a pointer
 * (this is needed by the 8086 code generator).
 *
 *         op                      op
 *        /  \                    /  \
 *      e1    e2                e1    ,
 *                                   / \
 *                                  =   &
 *                                 / \   \
 *                               fr   e2  fr
 *
 *      e1 op (*p)              e1 op p
 *      e1 op c                 e1 op &dc
 *      e1 op v                 e1 op &v
 */

elem *doptelem(elem *e, goal_t goal)
{
    //printf("doptelem(e = %p, goal = x%x)\n", e, goal);

    assert(!PARSER);
    do
    {   again = 0;
        e = optelem(e,goal & (GOALflags | GOALvalue | GOALnone));
    } while (again && goal & GOALagain && e);

    /* If entire expression is a struct, and we can replace it with     */
    /* something simpler, do so.                                        */
    if (goal & GOALstruct && e && tybasic(e->Ety) == TYstruct)
        e = elstruct(e, goal);

    return e;
}

/****************************************
 * Do optimizations after bltailrecursion() and before common subexpressions.
 */

void postoptelem(elem *e)
{
    Srcpos pos = {0};

    elem_debug(e);
    while (1)
    {
        if (OTunary(e->Eoper))
        {
            /* This is necessary as the optimizer tends to lose this information
             */
#if MARS
            if (e->Esrcpos.Slinnum > pos.Slinnum)
                pos = e->Esrcpos;
#endif
            if (e->Eoper == OPind)
            {
#if MARS
                if (e->E1->Eoper == OPconst &&
                    el_tolong(e->E1) >= 0 && el_tolong(e->E1) < 4096)
                {
                    error(pos.Sfilename, pos.Slinnum, pos.Scharnum, "null dereference in function %s", funcsym_p->Sident);
                    e->E1->EV.Vlong = 4096;     // suppress redundant messages
                }
#endif
            }
            e = e->E1;
        }
        else if (OTbinary(e->Eoper))
        {
#if MARS
            /* This is necessary as the optimizer tends to lose this information
             */
            if (e->Esrcpos.Slinnum > pos.Slinnum)
                pos = e->Esrcpos;
#endif
            if (e->Eoper == OPparam)
            {
                if (!I64)
                    elparamx(e);
            }
            postoptelem(e->E2);
            e = e->E1;
        }
        else
            break;
    }
}

#endif // !SPP
