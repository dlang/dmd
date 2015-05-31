// Copyright (C) 1985-1998 by Symantec
// Copyright (C) 2000-2015 by Digital Mars
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
#include        <time.h>

#include        "cc.h"
#include        "oper.h"
#include        "global.h"
#include        "code.h"
#include        "type.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

/*********************************
 * Struct for each elem:
 *      Helem   pointer to elem
 *      Hhash   hash value for the elem
 */

typedef struct HCS
        {       elem    *Helem;
                unsigned Hhash;
        } hcs;

static hcs *hcstab = NULL;              /* array of hcs's               */
static unsigned hcsmax = 0;             /* max index into hcstab[]      */

struct HCSArray
{
    unsigned top;                  // # of entries in hcstab[]
    unsigned touchstari;
    unsigned touchfunci[2];
};

static HCSArray hcsarray;

// Use a bit vector for quick check if expression is possibly in hcstab[].
// This results in much faster compiles when hcstab[] gets big.
static vec_t csvec;                     // vector of used entries
#define CSVECDIM        16001 //8009 //3001     // dimension of csvec (should be prime)

STATIC void ecom(elem **);
STATIC unsigned cs_comphash(elem *);
STATIC void addhcstab(elem *,int);
STATIC void touchlvalue(elem *);
STATIC void touchfunc(int);
STATIC void touchstar();
STATIC void touchaccess(elem *);
STATIC void touchall();

/*******************************
 * Eliminate common subexpressions across extended basic blocks.
 * String together as many blocks as we can.
 */

void comsubs()
{ block *bl,*blc,*bln;
  int n;                       /* # of blocks to treat as one  */

//static int xx;
//printf("comsubs() %d\n", ++xx);
//debugx = (xx == 37);

#ifdef DEBUG
  if (debugx) dbg_printf("comsubs(%p)\n",startblock);
#endif

  // No longer do we just compute Bcount. We now eliminate unreachable
  // blocks.
  block_compbcount();                   // eliminate unreachable blocks
#if SCPP
  if (errcnt)
        return;
#endif

  if (!csvec)
  {
        csvec = vec_calloc(CSVECDIM);
  }

  for (bl = startblock; bl; bl = bln)
  {
        bln = bl->Bnext;
        if (!bl->Belem)
                continue;       /* if no expression or no parents       */

        // Count up n, the number of blocks in this extended basic block (EBB)
        n = 1;                          // always at least one block in EBB
        blc = bl;
        while (bln && list_nitems(bln->Bpred) == 1 &&
                ((blc->BC == BCiftrue &&
                  list_block(list_next(blc->Bsucc)) == bln) ||
                 (blc->BC == BCgoto && list_block(blc->Bsucc) == bln)
                ) &&
               bln->BC != BCasm         // no CSE's extending across ASM blocks
              )
        {
                n++;                    // add block to EBB
                blc = bln;
                bln = blc->Bnext;
        }
        vec_clear(csvec);
        hcsarray.top = 0;
        hcsarray.touchstari = 0;
        hcsarray.touchfunci[0] = 0;
        hcsarray.touchfunci[1] = 0;
        bln = bl;
        while (n--)                     // while more blocks in EBB
        {
#ifdef DEBUG
                if (debugx)
                        dbg_printf("cses for block %p\n",bln);
#endif
                if (bln->Belem)
                    ecom(&bln->Belem);  // do the tree
                bln = bln->Bnext;
        }
  }

#ifdef DEBUG
  if (debugx)
        dbg_printf("done with comsubs()\n");
#endif
}

/*******************************
 */

void cgcs_term()
{
    vec_free(csvec);
    csvec = NULL;
#ifdef DEBUG
    debugw && dbg_printf("freeing hcstab\n");
#endif
#if TX86
    util_free(hcstab);
#else
    MEM_PARF_FREE(hcstab);
#endif
    hcstab = NULL;
    hcsmax = 0;
}

/*************************
 * Eliminate common subexpressions for an element.
 */

STATIC void ecom(elem **pe)
{ int i,op;
  HCSArray hcsarraySave;
  unsigned hash;
  elem *e,*ehash;
  tym_t tym;

  e = *pe;
  assert(e);
  elem_debug(e);
#ifdef DEBUG
  assert(e->Ecount == 0);
  //assert(e->Ecomsub == 0);
#endif
  tym = tybasic(e->Ety);
  op = e->Eoper;
  switch (op)
  {
    case OPconst:
    case OPvar:
    case OPrelconst:
        break;
    case OPstreq:
    case OPpostinc:
    case OPpostdec:
    case OPeq:
    case OPaddass:
    case OPminass:
    case OPmulass:
    case OPdivass:
    case OPmodass:
    case OPshrass:
    case OPashrass:
    case OPshlass:
    case OPandass:
    case OPxorass:
    case OPorass:
    case OPvecsto:
#if TX86
        /* Reverse order of evaluation for double op=. This is so that  */
        /* the pushing of the address of the second operand is easier.  */
        /* However, with the 8087 we don't need the kludge.             */
        if (op != OPeq && tym == TYdouble && !config.inline8087)
        {       if (EOP(e->E1))
                        ecom(&e->E1->E1);
                ecom(&e->E2);
        }
        else
#endif
        {
            /* Don't mark the increment of an i++ or i-- as a CSE, if it */
            /* can be done with an INC or DEC instruction.               */
            if (!(OTpost(op) && elemisone(e->E2)))
                ecom(&e->E2);           /* evaluate 2nd operand first   */
    case OPnegass:
            if (EOP(e->E1))             /* if lvalue is an operator     */
            {
#ifdef DEBUG
                if (e->E1->Eoper != OPind)
                    elem_print(e);
#endif
                assert(e->E1->Eoper == OPind);
                ecom(&(e->E1->E1));
            }
        }
        touchlvalue(e->E1);
        if (!OTpost(op))                /* lvalue of i++ or i-- is not a cse*/
        {
            hash = cs_comphash(e->E1);
            vec_setbit(hash % CSVECDIM,csvec);
            addhcstab(e->E1,hash);              // add lvalue to hcstab[]
        }
        return;

    case OPbtc:
    case OPbts:
    case OPbtr:
        ecom(&e->E1);
        ecom(&e->E2);
        touchfunc(0);                   // indirect assignment
        return;

    case OPandand:
    case OPoror:
        ecom(&e->E1);
        hcsarraySave = hcsarray;
        ecom(&e->E2);
        hcsarray = hcsarraySave;        // no common subs by E2
        return;                         /* if comsub then logexp() will */
                                        /* break                        */
    case OPcond:
        ecom(&e->E1);
        hcsarraySave = hcsarray;
        ecom(&e->E2->E1);               // left condition
        hcsarray = hcsarraySave;        // no common subs by E2
        ecom(&e->E2->E2);               // right condition
        hcsarray = hcsarraySave;        // no common subs by E2
        return;                         // can't be a common sub

    case OPcall:
    case OPcallns:
        ecom(&e->E2);                   /* eval right first             */
        /* FALL-THROUGH */
    case OPucall:
    case OPucallns:
        ecom(&e->E1);
        touchfunc(1);
        return;
    case OPstrpar:                      /* so we don't break logexp()   */
#if TX86
    case OPinp:                 /* never CSE the I/O instruction itself */
#endif
        ecom(&e->E1);
        /* FALL-THROUGH */
    case OPasm:
    case OPstrthis:             // don't CSE these
    case OPframeptr:
    case OPgot:
    case OPctor:
    case OPdtor:
    case OPdctor:
    case OPmark:
        return;

    case OPddtor:
        touchall();
        ecom(&e->E1);
        touchall();
        return;

    case OPparam:
#if TX86
    case OPoutp:
#endif
        ecom(&e->E1);
    case OPinfo:
        ecom(&e->E2);
        return;
    case OPcomma:
    case OPremquo:
        ecom(&e->E1);
        ecom(&e->E2);
        break;
#if TARGET_SEGMENTED
    case OPvp_fp:
    case OPcvp_fp:
        ecom(&e->E1);
        touchaccess(e);
        break;
#endif
    case OPind:
        ecom(&e->E1);
        /* Generally, CSEing a *(double *) results in worse code        */
        if (tyfloating(tym))
            return;
        break;
    case OPstrcpy:
    case OPstrcat:
    case OPmemcpy:
    case OPmemset:
        ecom(&e->E2);
    case OPsetjmp:
        ecom(&e->E1);
        touchfunc(0);
        return;
    default:                            /* other operators */
#ifdef DEBUG
        if (!EBIN(e)) WROP(e->Eoper);
#endif
        assert(EBIN(e));
    case OPadd:
    case OPmin:
    case OPmul:
    case OPdiv:
    case OPor:
    case OPxor:
    case OPand:
    case OPeqeq:
    case OPne:
#if TX86
    case OPscale:
    case OPyl2x:
    case OPyl2xp1:
#endif
        ecom(&e->E1);
        ecom(&e->E2);
        break;
    case OPstring:
    case OPaddr:
    case OPbit:
#ifdef DEBUG
        WROP(e->Eoper);
        elem_print(e);
#endif
        assert(0);              /* optelem() should have removed these  */
        /* NOTREACHED */

    // Explicitly list all the unary ops for speed
    case OPnot: case OPcom: case OPneg: case OPuadd:
    case OPabs: case OPrndtol: case OPrint:
    case OPpreinc: case OPpredec:
    case OPbool: case OPstrlen: case OPs16_32: case OPu16_32:
    case OPd_s32: case OPd_u32:
    case OPs32_d: case OPu32_d: case OPd_s16: case OPs16_d: case OP32_16:
    case OPd_f: case OPf_d:
    case OPd_ld: case OPld_d:
    case OPc_r: case OPc_i:
    case OPu8_16: case OPs8_16: case OP16_8:
    case OPu32_64: case OPs32_64: case OP64_32: case OPmsw:
    case OPu64_128: case OPs64_128: case OP128_64:
    case OPd_s64: case OPs64_d: case OPd_u64: case OPu64_d:
    case OPstrctor: case OPu16_d: case OPd_u16:
    case OParrow:
    case OPvoid: case OPnullcheck:
    case OPbsf: case OPbsr: case OPbswap: case OPpopcnt: case OPvector:
    case OPld_u64:
#if TX86
    case OPsqrt: case OPsin: case OPcos:
#endif
#if TARGET_SEGMENTED
    case OPoffset: case OPnp_fp: case OPnp_f16p: case OPf16p_np:
#endif
        ecom(&e->E1);
        break;
    case OPhalt:
        return;
  }

  /* don't CSE structures or unions or volatile stuff   */
  if (tym == TYstruct ||
      tym == TYvoid ||
      e->Ety & mTYvolatile
#if TX86
      || tyxmmreg(tym)
      // don't CSE doubles if inline 8087 code (code generator can't handle it)
      || (tyfloating(tym) && config.inline8087)
#endif
     )
        return;

  hash = cs_comphash(e);                /* must be AFTER leaves are done */

  /* Search for a match in hcstab[].
   * Search backwards, as most likely matches will be towards the end
   * of the list.
   */

#ifdef DEBUG
  if (debugx) dbg_printf("elem: %p hash: %6d\n",e,hash);
#endif
  int csveci = hash % CSVECDIM;
  if (vec_testbit(csveci,csvec))
  {
    for (i = hcsarray.top; i--;)
    {
#ifdef DEBUG
        if (debugx)
            dbg_printf("i: %2d Hhash: %6d Helem: %p\n",
                i,hcstab[i].Hhash,hcstab[i].Helem);
#endif
        if (hash == hcstab[i].Hhash && (ehash = hcstab[i].Helem) != NULL)
        {
            /* if elems are the same and we still have room for more    */
            if (el_match(e,ehash) && ehash->Ecount < 0xFF)
            {
                /* Make sure leaves are also common subexpressions
                 * to avoid false matches.
                 */
                if (!OTleaf(op))
                {
                    if (!e->E1->Ecount)
                        continue;
                    if (OTbinary(op) && !e->E2->Ecount)
                        continue;
                }
                ehash->Ecount++;
                *pe = ehash;
#ifdef DEBUG
                if (debugx)
                        dbg_printf("**MATCH** %p with %p\n",e,*pe);
#endif
                el_free(e);
                return;
            }
        }
    }
  }
  else
    vec_setbit(csveci,csvec);
  addhcstab(e,hash);                    // add this elem to hcstab[]
}

/**************************
 * Compute hash function for elem e.
 */

STATIC unsigned cs_comphash(elem *e)
{   int hash;
    unsigned op;

    elem_debug(e);
    op = e->Eoper;
#if TX86
    hash = (e->Ety & (mTYbasic | mTYconst | mTYvolatile)) + (op << 8);
#else
    hash = e->Ety + op;
#endif
    if (!OTleaf(op))
    {   hash += (size_t) e->E1;
        if (OTbinary(op))
                hash += (size_t) e->E2;
    }
    else
    {   hash += e->EV.Vint;
        if (op == OPvar || op == OPrelconst)
                hash += (size_t) e->EV.sp.Vsym;
    }
    return hash;
}

/****************************
 * Add an elem to the common subexpression table.
 * Recompute hash if it is 0.
 */

STATIC void addhcstab(elem *e,int hash)
{ unsigned h = hcsarray.top;

  if (h >= hcsmax)                      /* need to reallocate table     */
  {
        assert(h == hcsmax);
        // With 32 bit compiles, we've got memory to burn
        hcsmax += hcsmax + 128;
        assert(h < hcsmax);
#if TX86
        hcstab = (hcs *) util_realloc(hcstab,hcsmax,sizeof(hcs));
#else
        hcstab = (hcs *) MEM_PARF_REALLOC(hcstab,hcsmax*sizeof(hcs));
#endif
        //printf("hcstab = %p; hcsarray.top = %d, hcsmax = %d\n",hcstab,hcsarray.top,hcsmax);
  }
  hcstab[h].Helem = e;
  hcstab[h].Hhash = hash;
  hcsarray.top++;
}

/***************************
 * "touch" the elem.
 * If it is a pointer, "touch" all the suspects
 * who could be pointed to.
 * Eliminate common subs that are indirect loads.
 */

STATIC void touchlvalue(elem *e)
{
  if (e->Eoper == OPind)                /* if indirect store            */
  {
        /* NOTE: Some types of array assignments do not need
         * to touch all variables. (Like a[5], where a is an
         * array instead of a pointer.)
         */

        touchfunc(0);
        return;
  }

    for (int i = hcsarray.top; --i >= 0;)
    {   if (hcstab[i].Helem &&
            hcstab[i].Helem->EV.sp.Vsym == e->EV.sp.Vsym)
                hcstab[i].Helem = NULL;
    }

#ifdef DEBUG
    if (!(e->Eoper == OPvar || e->Eoper == OPrelconst))
        elem_print(e);
#endif
    assert(e->Eoper == OPvar || e->Eoper == OPrelconst);
    switch (e->EV.sp.Vsym->Sclass)
    {
        case SCregpar:
        case SCregister:
        case SCpseudo:
            break;
        case SCauto:
        case SCparameter:
        case SCfastpar:
        case SCshadowreg:
        case SCbprel:
            if (e->EV.sp.Vsym->Sflags & SFLunambig)
                break;
            /* FALL-THROUGH */
        case SCstatic:
        case SCextern:
        case SCglobal:
        case SClocstat:
        case SCcomdat:
        case SCinline:
        case SCsinline:
        case SCeinline:
        case SCcomdef:
            touchstar();
            break;
        default:
#ifdef DEBUG
            elem_print(e);
            symbol_print(e->EV.sp.Vsym);
#endif
            assert(0);
    }
}

/**************************
 * "touch" variables that could be changed by a function call or
 * an indirect assignment.
 * Eliminate any subexpressions that are "starred" (they need to
 * be recomputed).
 * Input:
 *      flag    If !=0, then this is a function call.
 *              If 0, then this is an indirect assignment.
 */

STATIC void touchfunc(int flag)
{

    //printf("touchfunc(%d)\n", flag);
    hcs *petop = &hcstab[hcsarray.top];
    //pe = &hcstab[0]; printf("pe = %p, petop = %p\n",pe,petop);
    assert(hcsarray.touchfunci[flag] <= hcsarray.top);
    for (hcs *pe = &hcstab[hcsarray.touchfunci[flag]]; pe < petop; pe++)
    {
        elem *he = pe->Helem;
        if (!he)
                continue;
        switch (he->Eoper)
        {
            case OPvar:
                switch (he->EV.sp.Vsym->Sclass)
                {
                    case SCregpar:
                    case SCregister:
                        break;
                    case SCauto:
                    case SCparameter:
                    case SCfastpar:
                    case SCshadowreg:
                    case SCbprel:
                        //printf("he = '%s'\n", he->EV.sp.Vsym->Sident);
                        if (he->EV.sp.Vsym->Sflags & SFLunambig)
                            break;
                        /* FALL-THROUGH */
                    case SCstatic:
                    case SCextern:
                    case SCcomdef:
                    case SCglobal:
                    case SClocstat:
                    case SCcomdat:
                    case SCpseudo:
                    case SCinline:
                    case SCsinline:
                    case SCeinline:
                        if (!(he->EV.sp.Vsym->ty() & mTYconst))
                            goto L1;
                        break;
                    default:
                        debug(WRclass((enum SC)he->EV.sp.Vsym->Sclass));
                        assert(0);
                }
                break;
            case OPind:
            case OPstrlen:
            case OPstrcmp:
            case OPmemcmp:
            case OPbt:
                goto L1;
#if TARGET_SEGMENTED
            case OPvp_fp:
            case OPcvp_fp:
                if (flag == 0)          /* function calls destroy vptrfptr's, */
                    break;              /* not indirect assignments     */
#endif
            L1:
                pe->Helem = NULL;
                break;
        }
    }
    hcsarray.touchfunci[flag] = hcsarray.top;
}


/*******************************
 * Eliminate all common subexpressions that
 * do any indirection ("starred" elems).
 */

STATIC void touchstar()
{ int i;
  elem *e;

  for (i = hcsarray.touchstari; i < hcsarray.top; i++)
  {     e = hcstab[i].Helem;
        if (e && (e->Eoper == OPind || e->Eoper == OPbt) )
                hcstab[i].Helem = NULL;
  }
  hcsarray.touchstari = hcsarray.top;
}

/*******************************
 * Eliminate all common subexpressions.
 */

STATIC void touchall()
{
    for (unsigned i = 0; i < hcsarray.top; i++)
    {
        hcstab[i].Helem = NULL;
    }
    hcsarray.touchstari = hcsarray.top;
    hcsarray.touchfunci[0] = hcsarray.top;
    hcsarray.touchfunci[1] = hcsarray.top;
}

#if TARGET_SEGMENTED
/*****************************************
 * Eliminate any common subexpressions that could be modified
 * if a handle pointer access occurs.
 */

STATIC void touchaccess(elem *ev)
{ int i;
  elem *e;

  ev = ev->E1;
  for (i = 0; i < hcsarray.top; i++)
  {     e = hcstab[i].Helem;
        /* Invalidate any previous handle pointer accesses that */
        /* are not accesses of ev.                              */
        if (e && (e->Eoper == OPvp_fp || e->Eoper == OPcvp_fp) && e->E1 != ev)
            hcstab[i].Helem = NULL;
  }
}
#endif

#endif // !SPP
