// Copyright (C) 1986-1998 by Symantec
// Copyright (C) 2000-2015 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */

#if (SCPP || MARS) && !HTOD

#include        <stdio.h>
#include        <time.h>

#include        "cc.h"
#include        "global.h"
#include        "el.h"
#include        "go.h"
#include        "oper.h"
#include        "list.h"
#include        "type.h"

#if SCPP
#include        "parser.h"
#endif

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

extern void error(const char *filename, unsigned linnum, unsigned charnum, const char *format, ...);

STATIC void rd_free_elem(elem *e);
STATIC void rd_compute();
STATIC void conpropwalk(elem *n , vec_t IN);
STATIC void chkrd(elem *n , list_t rdlist);
STATIC elem * chkprop(elem *n , list_t rdlist);
STATIC void arrayboundsrds(void);
STATIC void eqeqranges(void);
STATIC void intranges(void);
STATIC int loopcheck(block *start , block *inc , block *rel);
STATIC void cpwalk(elem *n , vec_t IN);
STATIC unsigned numasg(elem *e);
STATIC void accumda(elem *n , vec_t DEAD , vec_t POSS);
STATIC void dvwalk(elem *n , unsigned i);
STATIC int killed(unsigned j , block *bp , block *b);
STATIC int ispath(unsigned j , block *bp , block *b);

/**********************************************************************/

// Lists to help identify ranges of variables
struct Elemdata
{       Elemdata *next;         // linked list
        elem *pelem;            // the elem in question
        block *pblock;          // which block it's in
        list_t  rdlist;         // list of definition elems for *pelem

        static Elemdata *ctor(elem *e,block *b,list_t rd);
};

Elemdata *Elemdata::ctor(elem *e,block *b,list_t rd)
{   Elemdata *ed;

    ed = (Elemdata *) MEM_BEF_CALLOC(sizeof(Elemdata));
    ed->pelem = e;
    ed->pblock = b;
    ed->rdlist = rd;
    return ed;
}


/*****************
 * Free list of Elemdata's.
 */

STATIC void elemdatafree(Elemdata **plist)
{   Elemdata *el;
    Elemdata *eln;

    for (el = *plist; el; el = eln)
    {   eln = el->next;
        list_free(&el->rdlist);
        MEM_BEF_FREE(el);
    }
    *plist = NULL;
}

static Elemdata *arraylist = NULL;      // list of Elemdata's of OParray elems
static Elemdata *eqeqlist = NULL;       // list of Elemdata's of OPeqeq & OPne elems
static Elemdata *rellist = NULL;        // list of Elemdata's of relop elems
static Elemdata *inclist = NULL;        // list of Elemdata's of increment elems

enum Rdtype { RDarraybounds, RDconstprop };
static Rdtype rdtype;

/*************************** Constant Propagation ***************************/


/**************************
 * Constant propagation.
 * Also detects use of variable before any possible def.
 */

void constprop()
{
    rdtype = RDconstprop;
    rd_compute();
    intranges();                // compute integer ranges
#if 0
    eqeqranges();               // see if we can eliminate some relationals
#endif
    elemdatafree(&eqeqlist);
    elemdatafree(&rellist);
    elemdatafree(&inclist);
}

/************************************
 * Compute reaching definitions.
 * Note: RD vectors are destroyed by this.
 */

static block *thisblock;

STATIC void rd_compute()
{       unsigned i;

        cmes("constprop()\n");
        assert(dfo);
        flowrd();               /* compute reaching definitions (rd)    */
        if (deftop == 0)        /* if no reaching defs                  */
                return;
        assert(rellist == NULL && inclist == NULL && eqeqlist == NULL && arraylist == NULL);
        block_clearvisit();
        for (i = 0; i < dfotop; i++)    /* for each block               */
        {   block *b = dfo[i];

            switch (b->BC)
            {
#if MARS
                case BCjcatch:
#endif
                case BC_finally:
                case BCasm:
                case BCcatch:
                    block_visit(b);
                    break;
            }
        }

        for (i = 0; i < dfotop; i++)    /* for each block               */
        {       block *b;

                b = dfo[i];
                thisblock = b;
#if 0
                dbg_printf("block %d Bin ",i); vec_println(b->Binrd);
                dbg_printf("       Bout "); vec_println(b->Boutrd);
#endif
                if (b->Bflags & BFLvisited)
                    continue;                   // not reliable for this block
                if (b->Belem)
                {
                        conpropwalk(b->Belem,b->Binrd);
#ifdef DEBUG
                        if (!(vec_equal(b->Binrd,b->Boutrd)))
                        {       int j;

                                dbg_printf("block %d Binrd ",i); vec_println(b->Binrd);
                                dbg_printf("       Boutrd "); vec_println(b->Boutrd);
                                WReqn(b->Belem);
                                dbg_printf("\n");
                                vec_xorass(b->Binrd,b->Boutrd);
                                j = vec_index(0,b->Binrd);
                                WReqn(defnod[j].DNelem);
                                dbg_printf("\n");
                        }
#endif
                        assert(vec_equal(b->Binrd,b->Boutrd));
                }
        }
}

/***************************
 * Support routine for constprop().
 *      Visit each elem in order
 *              If elem is a reference to a variable, and
 *              all the reaching defs of that variable are
 *              defining it to be a specific constant,
 *                      Replace reference with that constant.
 *              Generate warning if no reaching defs for a
 *              variable, and the variable is on the stack
 *              or in a register.
 *              If elem is an assignment or function call or OPasm
 *                      Modify vector of reaching defs.
 */

STATIC void conpropwalk(elem *n,vec_t IN)
{       unsigned op;
        Elemdata *pdata;
        vec_t L,R;
        elem *t;

        assert(n && IN);
        /*chkvecdim(deftop,0);*/
        //printf("conpropwalk()\n"),elem_print(n);
        op = n->Eoper;
        if (op == OPcolon || op == OPcolon2)
        {       L = vec_clone(IN);
                conpropwalk(n->E1,L);
                conpropwalk(n->E2,IN);
                vec_orass(IN,L);                /* IN = L | R           */
                vec_free(L);
        }
        else if (op == OPandand || op == OPoror)
        {       conpropwalk(n->E1,IN);
                R = vec_clone(IN);
                conpropwalk(n->E2,R);
                vec_orass(IN,R);                /* IN |= R              */
                vec_free(R);
        }
        else if (OTunary(op))
                goto L3;
        else if (ERTOL(n))
        {       conpropwalk(n->E2,IN);
            L3:
                t = n->E1;
                if (OTassign(op))
                {
                    if (t->Eoper == OPvar)
                    {
                        // Note that the following ignores OPnegass
                        if (rdtype == RDconstprop &&
                            OTopeq(op) && sytab[t->EV.sp.Vsym->Sclass] & SCRD)
                        {   elem *e;
                            list_t rdl;

                            rdl = listrds(IN,t,NULL);
                            if (!(config.flags & CFGnowarning)) // if warnings are enabled
                                chkrd(t,rdl);
                            e = chkprop(t,rdl);
                            if (e)
                            {   // Replace (t op= exp) with (t = e op exp)

                                e = el_copytree(e);
                                e->Ety = t->Ety;
                                n->E2 = el_bin(opeqtoop(op),n->Ety,e,n->E2);
                                n->Eoper = OPeq;
                            }
                            list_free(&rdl);
                        }
                    }
                    else
                        conpropwalk(t,IN);
                }
                else
                        conpropwalk(t,IN);
        }
        else if (OTbinary(op))
        {
            if (OTassign(op))
            {   t = Elvalue(n);
                if (t->Eoper != OPvar)
                    conpropwalk(t,IN);
            }
            else
                conpropwalk(n->E1,IN);
            conpropwalk(n->E2,IN);
        }

        // Collect data for subsequent optimizations
        if (OTbinary(op) && n->E1->Eoper == OPvar && n->E2->Eoper == OPconst)
        {
            switch (op)
            {
                case OPlt:
                case OPgt:
                case OPle:
                case OPge:
                    // Collect compare elems and their rd's in the rellist list
                    if (rdtype == RDconstprop &&
                        tyintegral(n->E1->Ety) &&
                        tyintegral(n->E2->Ety)
                       )
                    {
                        //dbg_printf("appending to rellist\n"); elem_print(n);
                        pdata = Elemdata::ctor(n,thisblock,listrds(IN,n->E1,NULL));
                        pdata->next = rellist;
                        rellist = pdata;
                    }
                    break;

                case OPaddass:
                case OPminass:
                case OPpostinc:
                case OPpostdec:
                    // Collect increment elems and their rd's in the inclist list
                    if (rdtype == RDconstprop &&
                        tyintegral(n->E1->Ety))
                    {
                        //dbg_printf("appending to inclist\n"); elem_print(n);
                        pdata = Elemdata::ctor(n,thisblock,listrds(IN,n->E1,NULL));
                        pdata->next = inclist;
                        inclist = pdata;
                    }
                    break;

                case OPne:
                case OPeqeq:
                    // Collect compare elems and their rd's in the rellist list
                    if (rdtype == RDconstprop &&
                        tyintegral(n->E1->Ety))
                    {   //dbg_printf("appending to eqeqlist\n"); elem_print(n);
                        pdata = Elemdata::ctor(n,thisblock,listrds(IN,n->E1,NULL));
                        pdata->next = eqeqlist;
                        eqeqlist = pdata;
                    }
                    break;
            }
        }


        if (OTdef(op))                  /* if definition elem           */
            updaterd(n,IN,NULL);        /* then update IN vector        */

        /* now we get to the part that checks to see if we can  */
        /* propagate a constant.                                */
        if (op == OPvar && sytab[n->EV.sp.Vsym->Sclass] & SCRD)
        {   list_t rdl;

            //printf("const prop: %s\n", n->EV.sp.Vsym->Sident);
            rdl = listrds(IN,n,NULL);
            if (rdtype == RDconstprop)
            {   elem *e;

                if (!(config.flags & CFGnowarning))     // if warnings are enabled
                    chkrd(n,rdl);
                e = chkprop(n,rdl);
                if (e)
                {   tym_t nty;

                    nty = n->Ety;
                    el_copy(n,e);
                    n->Ety = nty;                       // retain original type
                }
                list_free(&rdl);
            }
        }
}

/******************************
 * Give error if there are no reaching defs for variable v.
 */

STATIC void chkrd(elem *n,list_t rdlist)
{   unsigned i;
    symbol *sv;
    int unambig;

    sv = n->EV.sp.Vsym;
    assert(sytab[sv->Sclass] & SCRD);
    if (sv->Sflags & SFLnord)           // if already printed a warning
        return;
    if (sv->ty() & mTYvolatile)
        return;
    unambig = sv->Sflags & SFLunambig;
    for (list_t l = rdlist; l; l = list_next(l))
    {   elem *d = (elem *) list_ptr(l);

        elem_debug(d);
        if (d->Eoper == OPasm)          /* OPasm elems ruin everything  */
            return;
        if (OTassign(d->Eoper))
        {
                if (d->E1->Eoper == OPvar)
                {       if (d->E1->EV.sp.Vsym == sv)
                                return;
                }
                else if (!unambig)
                        return;
        }
        else
        {       if (!unambig)
                        return;
        }
    }

    // If there are any asm blocks, don't print the message
    for (i = 0; i < dfotop; i++)
        if (dfo[i]->BC == BCasm)
            return;

    // If variable contains bit fields, don't print message (because if
    // bit field is the first set, then we get a spurious warning).
    // STL uses 0 sized structs to transmit type information, so
    // don't complain about them being used before set.
    if (type_struct(sv->Stype))
    {
        if (sv->Stype->Ttag->Sstruct->Sflags & (STRbitfields | STR0size))
            return;
    }
#if 0
    // If variable is zero length static array, don't print message.
    // BUG: Suppress error even if variable is initialized with void.
    if (sv->Stype->Tty == TYarray && sv->Stype->Tdim == 0)
    {
        printf("sv->Sident = %s\n", sv->Sident);
        return;
    }
#endif
#if SCPP
    {   Outbuffer buf;
        char *p2;

        type_tostring(&buf, sv->Stype);
        buf.writeByte(' ');
        buf.write(sv->Sident);
        p2 = buf.toString();
        warerr(WM_used_b4_set, p2);     // variable used before set
    }
#endif
#if MARS
    /* Watch out for:
        void test()
        {
            void[0] x;
            auto y = x;
        }
     */
    if (type_size(sv->Stype) != 0)
    {
        error(n->Esrcpos.Sfilename, n->Esrcpos.Slinnum, n->Esrcpos.Scharnum,
            "variable %s used before set", sv->Sident);
    }
#endif

    sv->Sflags |= SFLnord;              // no redundant messages
#ifdef DEBUG
    //elem_print(n);
#endif
}

/**********************************
 * Look through the vector of reaching defs (IN) to see
 * if all defs of n are of the same constant. If so, replace
 * n with that constant.
 * Bit fields are gross, so don't propagate anything with assignments
 * to a bit field.
 * Note the flaw in the reaching def vector. There is currently no way
 * to detect RDs from when the function is invoked, i.e. RDs for parameters,
 * statics and globals. This could be fixed by adding dummy defs for
 * them before startblock, but we just kludge it and don't propagate
 * stuff for them.
 * Returns:
 *      NULL    do not propagate constant
 *      e       constant elem that we should replace n with
 */

STATIC elem * chkprop(elem *n,list_t rdlist)
{
    elem *foundelem = NULL;
    int unambig;
    symbol *sv;
    tym_t nty;
    unsigned nsize;
    targ_size_t noff;
    list_t l;

    //printf("checkprop: "); WReqn(n); printf("\n");
    assert(n && n->Eoper == OPvar);
    elem_debug(n);
    sv = n->EV.sp.Vsym;
    assert(sytab[sv->Sclass] & SCRD);
    nty = n->Ety;
    if (!tyscalar(nty))
        goto noprop;
    nsize = size(nty);
    noff = n->EV.sp.Voffset;
    unambig = sv->Sflags & SFLunambig;
    for (l = rdlist; l; l = list_next(l))
    {   elem *d = (elem *) list_ptr(l);

        elem_debug(d);

        //printf("\trd: "); WReqn(d); printf("\n");
        if (d->Eoper == OPasm)          /* OPasm elems ruin everything  */
            goto noprop;

        // Runs afoul of Buzilla 4506
        /*if (OTassign(d->Eoper) && EBIN(d))*/      // if assignment elem

        if (OTassign(d->Eoper))      // if assignment elem
        {   elem *t = Elvalue(d);

            if (t->Eoper == OPvar)
            {   assert(t->EV.sp.Vsym == sv);

                if (d->Eoper == OPstreq ||
                    !tyscalar(t->Ety))
                    goto noprop;        // not worth bothering with these cases

                if (d->Eoper == OPnegass)
                    goto noprop;        // don't bother with this case, either

                /* Everything must match or we must skip this variable  */
                /* (in case of assigning to overlapping unions, etc.)   */
                if (t->EV.sp.Voffset != noff ||
                    /* If sizes match, we are ok        */
                    size(t->Ety) != nsize &&
                        !(d->E2->Eoper == OPconst && size(t->Ety) > nsize && !tyfloating(d->E2->Ety)))
                    goto noprop;
            }
            else
            {   if (unambig)            /* unambiguous assignments only */
                    continue;
                goto noprop;
            }
            if (d->Eoper != OPeq)
                goto noprop;
        }
        else                            /* must be a call elem          */
        {
            if (unambig)
                continue;
            else
                goto noprop;            /* could be affected            */
        }

        if (d->E2->Eoper == OPconst || d->E2->Eoper == OPrelconst)
        {
            if (foundelem)              /* already found one            */
            {                           /* then they must be the same   */
                if (!el_match(foundelem,d->E2))
                    goto noprop;
            }
            else                        /* else this is it              */
                foundelem = d->E2;
        }
        else
            goto noprop;
    }

    if (foundelem)                      /* if we got one                 */
    {                                   /* replace n with foundelem      */
#ifdef DEBUG
        if (debugc)
        {       dbg_printf("const prop (");
                WReqn(n);
                dbg_printf(" replaced by ");
                WReqn(foundelem);
                dbg_printf("), %p to %p\n",foundelem,n);
        }
#endif
        changes++;
        return foundelem;
    }
noprop:
    return NULL;
}

/***********************************
 * Find all the reaching defs of OPvar e.
 * Put into a linked list, or just set the RD bits in a vector.
 *
 */

list_t listrds(vec_t IN,elem *e,vec_t f)
{
    unsigned i;
    unsigned unambig;
    Symbol *s;
    unsigned nsize;
    targ_size_t noff;
    tym_t ty;

    //printf("listrds: "); WReqn(e); printf("\n");
    assert(IN);
    list_t rdlist = NULL;
    assert(e->Eoper == OPvar);
    s = e->EV.sp.Vsym;
    ty = e->Ety;
    if (tyscalar(ty))
        nsize = size(ty);
    noff = e->EV.sp.Voffset;
    unambig = s->Sflags & SFLunambig;
    if (f)
        vec_clear(f);
    foreach (i, deftop, IN)
    {
        elem *d = defnod[i].DNelem;
        //dbg_printf("\tlooking at "); WReqn(d); dbg_printf("\n");
        unsigned op = d->Eoper;
        if (op == OPasm)                // assume ASM elems define everything
            goto listit;
        if (OTassign(op))
        {   elem *t = Elvalue(d);

            if (t->Eoper == OPvar && t->EV.sp.Vsym == s)
            {   if (op == OPstreq)
                    goto listit;
                if (!tyscalar(ty) || !tyscalar(t->Ety))
                    goto listit;
                // If t does not overlap e, then it doesn't affect things
                if (noff + nsize > t->EV.sp.Voffset &&
                    t->EV.sp.Voffset + size(t->Ety) > noff)
                    goto listit;                // it's an assignment to s
            }
            else if (t->Eoper != OPvar && !unambig)
                goto listit;            /* assignment through pointer   */
        }
        else if (!unambig)
            goto listit;                /* probably a function call     */
        continue;

    listit:
        //dbg_printf("\tlisting "); WReqn(d); dbg_printf("\n");
        if (f)
            vec_setbit(i,f);
        else
            list_prepend(&rdlist,d);     // add the definition node
    }
    return rdlist;
}

/********************************************
 * Look at reaching defs for expressions of the form (v == c) and (v != c).
 * If all definitions of v are c or are not c, then we can replace the
 * expression with 1 or 0.
 */

STATIC void eqeqranges()
{   Elemdata *rel;
    list_t rdl;
    Symbol *v;
    int sz;
    elem *e;
    targ_llong c;
    int result;

    for (rel = eqeqlist; rel; rel = rel->next)
    {
        e = rel->pelem;
        v = e->E1->EV.sp.Vsym;
        if (!(sytab[v->Sclass] & SCRD))
            continue;
        sz = tysize(e->E1->Ety);
        c = el_tolong(e->E2);

        result = -1;                    // result not known yet
        for (rdl = rel->rdlist; rdl; rdl = list_next(rdl))
        {   elem *erd = (elem *) list_ptr(rdl);
            elem *erd1;
            int szrd;
            int tmp;

            elem_debug(erd);
            if (erd->Eoper != OPeq ||
                (erd1 = erd->E1)->Eoper != OPvar ||
                erd->E2->Eoper != OPconst
               )
                goto L1;
            szrd = tysize(erd1->Ety);
            if (erd1->EV.sp.Voffset + szrd <= e->E1->EV.sp.Voffset ||
                e->E1->EV.sp.Voffset + sz <= erd1->EV.sp.Voffset)
                continue;               // doesn't affect us, skip it
            if (szrd != sz || e->E1->EV.sp.Voffset != erd1->EV.sp.Voffset)
                goto L1;                // overlapping - forget it

            tmp = (c == el_tolong(erd->E2));
            if (result == -1)
                result = tmp;
            else if (result != tmp)
                goto L1;
        }
        if (result >= 0)
        {
            //printf("replacing with %d\n",result);
            el_free(e->E1);
            el_free(e->E2);
            e->EV.Vint = (e->Eoper == OPeqeq) ? result : result ^ 1;
            e->Eoper = OPconst;
        }
    L1: ;
    }
}

/******************************
 * Examine rellist and inclist to determine if any of the signed compare
 * elems in rellist can be replace by unsigned compares.
 * rellist is list of relationals in function.
 * inclist is list of increment elems in function.
 */

STATIC void intranges()
{   Elemdata *rel,*iel;
    block *rb,*ib;
    symbol *v;
    elem *rdeq,*rdinc;
    unsigned incop,relatop;
    targ_int initial,increment,final;

    cmes("intranges()\n");
    for (rel = rellist; rel; rel = rel->next)
    {
        rb = rel->pblock;
        //dbg_printf("rel->pelem: "); WReqn(rel->pelem); dbg_printf("\n");
        assert(rel->pelem->E1->Eoper == OPvar);
        v = rel->pelem->E1->EV.sp.Vsym;

        // RD info is only reliable for registers and autos
        if (!(sytab[v->Sclass] & SCRD))
            continue;

        /* Look for two rd's: an = and an increment     */
        if (list_nitems(rel->rdlist) != 2)
            continue;
        rdeq = list_elem(list_next(rel->rdlist));
        if (rdeq->Eoper != OPeq)
        {   rdinc = rdeq;
            rdeq = list_elem(rel->rdlist);
            if (rdeq->Eoper != OPeq)
                continue;
        }
        else
            rdinc = list_elem(rel->rdlist);
#if 0
        printf("\neq:  "); WReqn(rdeq); printf("\n");
        printf("rel: "); WReqn(rel->pelem); printf("\n");
        printf("inc: "); WReqn(rdinc); printf("\n");
#endif
        incop = rdinc->Eoper;
        if (!OTpost(incop) && incop != OPaddass && incop != OPminass)
            continue;

        /* lvalues should be unambiguous defs   */
        if (rdeq->E1->Eoper != OPvar || rdinc->E1->Eoper != OPvar)
            continue;
        /* rvalues should be constants          */
        if (rdeq->E2->Eoper != OPconst || rdinc->E2->Eoper != OPconst)
            continue;

        /* Ensure that the only defs reaching the increment elem (rdinc) */
        /* are rdeq and rdinc.                                          */
        for (iel = inclist; TRUE; iel = iel->next)
        {   elem *rd1,*rd2;

            if (!iel)
                goto nextrel;
            ib = iel->pblock;
            if (iel->pelem != rdinc)
                continue;               /* not our increment elem       */
            if (list_nitems(iel->rdlist) != 2)
            {   //printf("!= 2\n");
                goto nextrel;
            }
            rd1 = list_elem(iel->rdlist);
            rd2 = list_elem(list_next(iel->rdlist));
            /* The rd's for the relational elem (rdeq,rdinc) must be    */
            /* the same as the rd's for tne increment elem (rd1,rd2).   */
            if (rd1 == rdeq && rd2 == rdinc || rd1 == rdinc && rd2 == rdeq)
                break;
        }

        // Check that all paths from rdinc to rdinc must pass through rdrel
        {   int i;

            // ib:      block of increment
            // rb:      block of relational
            i = loopcheck(ib,ib,rb);
            block_clearvisit();
            if (i)
                continue;
        }

        /* Gather initial, increment, and final values for loop */
        initial = el_tolong(rdeq->E2);
        increment = el_tolong(rdinc->E2);
        if (incop == OPpostdec || incop == OPminass)
            increment = -increment;
        relatop = rel->pelem->Eoper;
        final = el_tolong(rel->pelem->E2);
        //printf("initial = %d, increment = %d, final = %d\n",initial,increment,final);

        /* Determine if we can make the relational an unsigned  */
        if (initial >= 0)
        {   if (final >= initial)
            {   if (increment > 0 && ((final - initial) % increment) == 0)
                    goto makeuns;
            }
            else if (final >= 0)
            {   /* 0 <= final < initial */
                if (increment < 0 && ((final - initial) % increment) == 0 &&
                    !(final + increment < 0 &&
                        (relatop == OPge || relatop == OPlt)
                     )
                   )
                {
                makeuns:
                    if (!tyuns(rel->pelem->E2->Ety))
                    {
                        rel->pelem->E2->Ety = touns(rel->pelem->E2->Ety);
                        rel->pelem->Nflags |= NFLtouns;
#ifdef DEBUG
                        if (debugc)
                        {   WReqn(rel->pelem);
                            printf(" made unsigned, initial = %ld, increment = %ld,\
 final = %ld\n",(long int)initial,(long int)increment,(long int)final);
                        }
#endif
                        changes++;
                    }
#if 0
                    // Eliminate loop if it is empty
                    if (relatop == OPlt &&
                        rb->BC == BCiftrue &&
                        list_block(rb->Bsucc) == rb &&
                        rb->Belem->Eoper == OPcomma &&
                        rb->Belem->E1 == rdinc &&
                        rb->Belem->E2 == rel->pelem
                       )
                     {
                        rel->pelem->Eoper = OPeq;
                        rel->pelem->Ety = rel->pelem->E1->Ety;
                        rb->BC = BCgoto;
                        list_subtract(&rb->Bsucc,rb);
                        list_subtract(&rb->Bpred,rb);
#ifdef DEBUG
                        if (debugc)
                        {   WReqn(rel->pelem);
                            dbg_printf(" eliminated loop\n");
                        }
#endif
                        changes++;
                     }
#endif
                }
            }
        }

      nextrel:
        ;
    }
}

/***********************
 * Return TRUE if there is a path from start to inc without
 * passing through rel.
 */

STATIC int loopcheck(block *start,block *inc,block *rel)
{   list_t list;
    block *b;

    if (!(start->Bflags & BFLvisited))
    {   start->Bflags |= BFLvisited;    /* guarantee eventual termination */
        for (list = start->Bsucc; list; list = list_next(list))
        {   b = (block *) list_ptr(list);
            if (b != rel && (b == inc || loopcheck(b,inc,rel)))
                return TRUE;
        }
    }
    return FALSE;
}

/****************************
 * Do copy propagation.
 * Copy propagation elems are of the form OPvar=OPvar, and they are
 * in expnod[].
 */

static int recalc;

void copyprop()
{       unsigned i;

        out_regcand(&globsym);
        cmes("copyprop()\n");
        assert(dfo);
Lagain:
        flowcp();               /* compute available copy statements    */
        if (exptop <= 1)
                return;                 /* none available               */
#if 0
        for (i = 1; i < exptop; i++)
        {       dbg_printf("expnod[%d] = (",i);
                WReqn(expnod[i]);
                dbg_printf(");\n");
        }
#endif
        recalc = 0;
        for (i = 0; i < dfotop; i++)    /* for each block               */
        {       block *b;

                b = dfo[i];
                if (b->Belem)
                {
#if 0
                        dbg_printf("B%d, elem (",i);
                        WReqn(b->Belem); dbg_printf(")\nBin  ");
                        vec_println(b->Bin);
                        cpwalk(b->Belem,b->Bin);
                        dbg_printf("Bino ");
                        vec_println(b->Bin);
                        dbg_printf("Bout ");
                        vec_println(b->Bout);
#else
                        cpwalk(b->Belem,b->Bin);
#endif
                        /*assert(vec_equal(b->Bin,b->Bout));            */
                        /* The previous assert() is correct except      */
                        /* for the following case:                      */
                        /*      a=b; d=a; a=b;                          */
                        /* The vectors don't match because the          */
                        /* equations changed to:                        */
                        /*      a=b; d=b; a=b;                          */
                        /* and the d=b copy elem now reaches the end    */
                        /* of the block (the d=a elem didn't).          */
                }
                if (recalc)
                    goto Lagain;
        }
}

/*****************************
 * Walk tree n, doing copy propagation as we go.
 * Keep IN up to date.
 */

STATIC void cpwalk(elem *n,vec_t IN)
{       unsigned op,i;
        elem *t;
        vec_t L;

        static int nocp;

        assert(n && IN);
        /*chkvecdim(exptop,0);*/
        if (recalc)
            return;
        op = n->Eoper;
        if (op == OPcolon || op == OPcolon2)
        {
                L = vec_clone(IN);
                cpwalk(n->E1,L);
                cpwalk(n->E2,IN);
                vec_andass(IN,L);               // IN = L & R
                vec_free(L);
        }
        else if (op == OPandand || op == OPoror)
        {       cpwalk(n->E1,IN);
                L = vec_clone(IN);
                cpwalk(n->E2,L);
                vec_andass(IN,L);               // IN = L & R
                vec_free(L);
        }
        else if (OTunary(op))
        {
                t = n->E1;
                if (OTassign(op))
                {   if (t->Eoper == OPind)
                        cpwalk(t->E1,IN);
                }
                else if (op == OPctor || op == OPdtor)
                {
                    /* This kludge is necessary because in except_pop()
                     * an el_match is done on the lvalue. If copy propagation
                     * changes the OPctor but not the corresponding OPdtor,
                     * then the match won't happen and except_pop()
                     * will fail.
                     */
                    nocp++;
                    cpwalk(t,IN);
                    nocp--;
                }
                else
                    cpwalk(t,IN);
        }
        else if (OTassign(op))
        {       cpwalk(n->E2,IN);
                t = Elvalue(n);
                if (t->Eoper == OPind)
                        cpwalk(t,IN);
                else
                {
#ifdef DEBUG
                        if (t->Eoper != OPvar) elem_print(n);
#endif
                        assert(t->Eoper == OPvar);
                }
        }
        else if (ERTOL(n))
        {       cpwalk(n->E2,IN);
                cpwalk(n->E1,IN);
        }
        else if (OTbinary(op))
        {
                cpwalk(n->E1,IN);
                cpwalk(n->E2,IN);
        }

        if (OTdef(op))                  // if definition elem
        {       int ambig;              /* TRUE if ambiguous def        */

                ambig = !OTassign(op) || t->Eoper == OPind;
                foreach (i,exptop,IN)           /* for each active copy elem */
                {       symbol *v;

                        if (op == OPasm)
                                goto clr;

                        /* If this elem could kill the lvalue or the rvalue, */
                        /*      Clear bit in IN.                        */
                        v = expnod[i]->E1->EV.sp.Vsym;
                        if (ambig)
                        {       if (!(v->Sflags & SFLunambig))
                                        goto clr;
                        }
                        else
                        {       if (v == t->EV.sp.Vsym)
                                        goto clr;
                        }
                        v = expnod[i]->E2->EV.sp.Vsym;
                        if (ambig)
                        {       if (!(v->Sflags & SFLunambig))
                                        goto clr;
                        }
                        else
                        {       if (v == t->EV.sp.Vsym)
                                        goto clr;
                        }
                        continue;

                    clr:                /* this copy elem is not available */
                        vec_clearbit(i,IN);     /* so remove it from the vector */
                } /* foreach */

                /* If this is a copy elem in expnod[]   */
                /*      Set bit in IN.                  */
                if ((op == OPeq || op == OPstreq) && n->E1->Eoper == OPvar &&
                    n->E2->Eoper == OPvar && n->Eexp)
                        vec_setbit(n->Eexp,IN);
        }
        else if (op == OPvar && !nocp)  // if reference to variable v
        {       symbol *v = n->EV.sp.Vsym;
                symbol *f;
                elem *foundelem = NULL;
                tym_t ty;

                //dbg_printf("Checking copyprop for '%s', ty=x%x\n",v->Sident,n->Ety);
                symbol_debug(v);
                ty = n->Ety;
                unsigned sz = tysize(n->Ety);
                if (sz == -1 && !tyfunc(n->Ety))
                    sz = type_size(v->Stype);

                foreach(i,exptop,IN)    /* for all active copy elems    */
                {       elem *c;

                        c = expnod[i];
                        assert(c);

                        unsigned csz = tysize(c->E1->Ety);
                        if (c->Eoper == OPstreq)
                            csz = type_size(c->ET);
                        assert((int)csz >= 0);

                        //dbg_printf("looking at: ("); WReqn(c); dbg_printf("), ty=x%x\n",c->E1->Ety);
                        /* Not only must symbol numbers match, but      */
                        /* offsets too (in case of arrays) and sizes    */
                        /* (in case of unions).                         */
                        if (v == c->E1->EV.sp.Vsym &&
                            n->EV.sp.Voffset == c->E1->EV.sp.Voffset &&
                            sz <= csz)
                        {       if (foundelem)
                                {       if (c->E2->EV.sp.Vsym != f)
                                                goto noprop;
                                }
                                else
                                {       foundelem = c;
                                        f = foundelem->E2->EV.sp.Vsym;
                                }
                        }
                }
                if (foundelem)          /* if we can do the copy prop   */
                {
#ifdef DEBUG
                        if (debugc)
                        {
                            printf("Copyprop, from '%s'(%d) to '%s'(%d)\n",
                                (v->Sident) ? (char *)v->Sident : "temp", v->Ssymnum,
                                (f->Sident) ? (char *)f->Sident : "temp", f->Ssymnum);
                        }
#endif
                        type *nt = n->ET;
                        el_copy(n,foundelem->E2);
                        n->Ety = ty;    // retain original type
                        n->ET = nt;

                        /* original => rewrite
                         *  v = f
                         *  g = v   => g = f
                         *  f = x
                         *  d = g   => d = f !!error
                         * Therefore, if g appears as an rvalue in expnod[], then recalc
                         */
                        for (size_t i = 1; i < exptop; ++i)
                        {
                            if (expnod[i]->E2 == n)
                            {
                                symbol *g = expnod[i]->E1->EV.sp.Vsym;
                                for (size_t j = 1; j < exptop; ++j)
                                {
                                    if (expnod[j]->E2->EV.sp.Vsym == g)
                                    {
                                        ++recalc;
                                        break;
                                    }
                                }
                                break;
                            }
                        }

                        changes++;
                }
                //else dbg_printf("not found\n");
            noprop:
                ;
        }
}

/********************************
 * Remove dead assignments. Those are assignments to a variable v
 * for which there are no subsequent uses of v.
 */

static unsigned asstop,         /* # of assignment elems in assnod[]    */
                assmax = 0,     /* size of assnod[]                     */
                assnum;         /* current position in assnod[]         */
static elem **assnod = NULL;    /* array of pointers to asg elems       */
static vec_t ambigref;          /* vector of assignment elems that      */
                                /* are referenced when an ambiguous     */
                                /* reference is done (as in *p or call) */

void rmdeadass()
{       unsigned i,j;
        vec_t DEAD,POSS;

        cmes("rmdeadass()\n");
        flowlv();                       /* compute live variables       */
        for (i = 0; i < dfotop; i++)    /* for each block b             */
        {       block *b = dfo[i];

                if (!b->Belem)          /* if no elems at all           */
                        continue;
                if (b->Btry)            // if in try-block guarded body
                        continue;
                asstop = numasg(b->Belem);      /* # of assignment elems */
                if (asstop == 0)        /* if no assignment elems       */
                        continue;
                if (asstop > assmax)    /* if we need to reallocate     */
                {       assnod = (elem **)
                        util_realloc(assnod,sizeof(elem *),asstop);
                        assmax = asstop;
                }
                /*setvecdim(asstop);*/
                DEAD = vec_calloc(asstop);
                POSS = vec_calloc(asstop);
                ambigref = vec_calloc(asstop);
                assnum = 0;
                accumda(b->Belem,DEAD,POSS);    /* compute DEAD and POSS */
                assert(assnum == asstop);
                vec_free(ambigref);
                vec_orass(POSS,DEAD);   /* POSS |= DEAD                 */
                foreach (j,asstop,POSS) /* for each possible dead asg.  */
                {       symbol *v;      /* v = target of assignment     */
                        elem *n,*nv;

                        n = assnod[j];
                        nv = Elvalue(n);
                        v = nv->EV.sp.Vsym;
                        if (!symbol_isintab(v)) // not considered
                            continue;
                        //printf("assnod[%d]: ",j); WReqn(n); printf("\n");
                        //printf("\tPOSS\n");
                        /* If not positively dead but v is live on a    */
                        /* successor to b, then v is live.              */
                        //printf("\tDEAD=%d, live=%d\n",vec_testbit(j,DEAD),vec_testbit(v->Ssymnum,b->Boutlv));
                        if (!vec_testbit(j,DEAD) && vec_testbit(v->Ssymnum,b->Boutlv))
                                continue;
                        /* volatile variables are not dead              */
                        if ((v->ty() | nv->Ety) & mTYvolatile)
                            continue;
#ifdef DEBUG
                        if (debugc)
                        {       dbg_printf("dead assignment (");
                                WReqn(n);
                                if (vec_testbit(j,DEAD))
                                        dbg_printf(") DEAD\n");
                                else
                                        dbg_printf(") Boutlv\n");
                        }
#endif
                        elimass(n);
                        changes++;
                } /* foreach */
                vec_free(DEAD);
                vec_free(POSS);
        } /* for */
        util_free(assnod);
        assnod = NULL;
        assmax = 0;
}

/***************************
 * Remove side effect of assignment elem.
 */

void elimass(elem *n)
{   elem *e1;

    switch (n->Eoper)
    {
        case OPvecsto:
            n->E2->Eoper = OPcomma;
        case OPeq:
        case OPstreq:
            /* (V=e) => (random constant,e)     */
            /* Watch out for (a=b=c) stuff!     */
            /* Don't screw up assnod[]. */
            n->Eoper = OPcomma;
            n->Ety |= n->E2->Ety & (mTYconst | mTYvolatile | mTYimmutable | mTYshared
#if TARGET_SEGMENTED
                 | mTYfar
#endif
                );
            n->E1->Eoper = OPconst;
            break;
        /* Convert (V op= e) to (V op e)        */
        case OPaddass:
        case OPminass:
        case OPmulass:
        case OPdivass:
        case OPorass:
        case OPandass:
        case OPxorass:
        case OPmodass:
        case OPshlass:
        case OPshrass:
        case OPashrass:
            n->Eoper = opeqtoop(n->Eoper);
            break;
        case OPpostinc: /* (V i++ c) => V       */
        case OPpostdec: /* (V i-- c) => V       */
            e1 = n->E1;
            el_free(n->E2);
            el_copy(n,e1);
            el_free(e1);
            break;
        case OPnegass:
            n->Eoper = OPneg;
            break;
        case OPbtc:
        case OPbtr:
        case OPbts:
            n->Eoper = OPbt;
            break;
        default:
            assert(0);
    }
}

/************************
 * Compute number of =,op=,i++,i--,--i,++i elems.
 * (Unambiguous assignments only. Ambiguous ones would always be live.)
 * Some compilers generate better code for ?: than if-then-else.
 */

STATIC unsigned numasg(elem *e)
{
  assert(e);
  if (OTassign(e->Eoper) && e->E1->Eoper == OPvar)
  {     e->Nflags |= NFLassign;
        return 1 + numasg(e->E1) + (OTbinary(e->Eoper) ? numasg(e->E2) : 0);
  }
  e->Nflags &= ~NFLassign;
  return OTunary(e->Eoper) ? numasg(e->E1) :
        OTbinary(e->Eoper) ? numasg(e->E1) + numasg(e->E2) : 0;
}

/******************************
 * Tree walk routine for rmdeadass().
 *      DEAD    =       assignments which are dead
 *      POSS    =       assignments which are possibly dead
 * The algorithm is basically:
 *      if we have an assignment to v,
 *              for all defs of v in POSS
 *                      set corresponding bits in DEAD
 *              set bit for this def in POSS
 *      if we have a reference to v,
 *              clear all bits in POSS that are refs of v
 */

STATIC void accumda(elem *n,vec_t DEAD, vec_t POSS)
{       vec_t Pl,Pr,Dl,Dr;
        unsigned i,op,vecdim;

        /*chkvecdim(asstop,0);*/
        assert(n && DEAD && POSS);
        op = n->Eoper;
        switch (op)
        {   case OPcolon:
            case OPcolon2:
                Pl = vec_clone(POSS);
                Pr = vec_clone(POSS);
                Dl = vec_calloc(asstop);
                Dr = vec_calloc(asstop);
                accumda(n->E1,Dl,Pl);
                accumda(n->E2,Dr,Pr);

                /* D |= P & (Dl & Dr) | ~P & (Dl | Dr)  */
                /* P = P & (Pl & Pr) | ~P & (Pl | Pr)   */
                /*   = Pl & Pr | ~P & (Pl | Pr)         */
                vecdim = vec_dim(DEAD);
                for (i = 0; i < vecdim; i++)
                {       DEAD[i] |= (POSS[i] & Dl[i] & Dr[i]) |
                                   (~POSS[i] & (Dl[i] | Dr[i]));
                        POSS[i] = (Pl[i] & Pr[i]) | (~POSS[i] & (Pl[i] | Pr[i]));
                }
                vec_free(Pl); vec_free(Pr); vec_free(Dl); vec_free(Dr);
                break;

            case OPandand:
            case OPoror:
                accumda(n->E1,DEAD,POSS);
                // Substituting into the above equations Pl=P and Dl=0:
                // D |= Dr - P
                // P = Pr
                Pr = vec_clone(POSS);
                Dr = vec_calloc(asstop);
                accumda(n->E2,Dr,Pr);
                vec_subass(Dr,POSS);
                vec_orass(DEAD,Dr);
                vec_copy(POSS,Pr);
                vec_free(Pr); vec_free(Dr);
                break;

            case OPvar:
            {   symbol *v = n->EV.sp.Vsym;
                targ_size_t voff = n->EV.sp.Voffset;
                unsigned vsize = tysize(n->Ety);

                // We have a reference. Clear all bits in POSS that
                // could be referenced.

                for (i = 0; i < assnum; i++)
                {   elem *ti;

                    ti = Elvalue(assnod[i]);
                    if (v == ti->EV.sp.Vsym &&
                        ((vsize == -1 || tysize(ti->Ety) == -1) ||
                         // If symbol references overlap
                         (voff + vsize > ti->EV.sp.Voffset &&
                          ti->EV.sp.Voffset + tysize(ti->Ety) > voff)
                        )
                       )
                    {
                        vec_clearbit(i,POSS);
                    }
                }
                break;
            }

            case OPasm:         // reference everything
                for (i = 0; i < assnum; i++)
                    vec_clearbit(i,POSS);
                break;

            case OPind:
            case OPucall:
            case OPucallns:
#if TARGET_SEGMENTED
            case OPvp_fp:
#endif
                accumda(n->E1,DEAD,POSS);
                vec_subass(POSS,ambigref);      // remove possibly refed
                                                // assignments from list
                                                // of possibly dead ones
                break;

            case OPconst:
                break;

            case OPcall:
            case OPcallns:
            case OPmemcpy:
            case OPstrcpy:
            case OPmemset:
                accumda(n->E2,DEAD,POSS);
            case OPstrlen:
                accumda(n->E1,DEAD,POSS);
                vec_subass(POSS,ambigref);      // remove possibly refed
                                                // assignments from list
                                                // of possibly dead ones
                break;

            case OPnewarray:
            case OPmultinewarray:
            case OParray:
            case OPfield:
            case OPstrcat:
            case OPstrcmp:
            case OPmemcmp:
                accumda(n->E1,DEAD,POSS);
                accumda(n->E2,DEAD,POSS);
                vec_subass(POSS,ambigref);      // remove possibly refed
                                                // assignments from list
                                                // of possibly dead ones
                break;

            default:
                if (OTassign(op))
                {   elem *t;

                    if (ERTOL(n))
                        accumda(n->E2,DEAD,POSS);
                    t = Elvalue(n);
                    // if not (v = expression) then gen refs of left tree
                    if (op != OPeq && op != OPstreq)
                        accumda(n->E1,DEAD,POSS);
                    else if (OTunary(t->Eoper))         // if (*e = expression)
                        accumda(t->E1,DEAD,POSS);
                    else if (OTbinary(t->Eoper))
                    {   accumda(t->E1,DEAD,POSS);
                        accumda(t->E2,DEAD,POSS);
                    }
                    if (!ERTOL(n) && op != OPnegass)
                        accumda(n->E2,DEAD,POSS);

                    // if unambiguous assignment, post all possibilities
                    // to DEAD
                    if ((op == OPeq || op == OPstreq) && t->Eoper == OPvar)
                    {
                        unsigned tsz = tysize(t->Ety);
                        if (n->Eoper == OPstreq)
                            tsz = type_size(n->ET);
                        for (i = 0; i < assnum; i++)
                        {   elem *ti = Elvalue(assnod[i]);

                            unsigned tisz = tysize(ti->Ety);
                            if (assnod[i]->Eoper == OPstreq)
                                tisz = type_size(assnod[i]->ET);

                            // There may be some problem with this next
                            // statement with unions.
                            if (ti->EV.sp.Vsym == t->EV.sp.Vsym &&
                                ti->EV.sp.Voffset == t->EV.sp.Voffset &&
                                tisz == tsz &&
                                !(t->Ety & mTYvolatile) &&
                                //t->EV.sp.Vsym->Sflags & SFLunambig &&
                                vec_testbit(i,POSS))
                            {
                                    vec_setbit(i,DEAD);
                            }
                        }
                    }

                    // if assignment operator, post this def to POSS
                    if (n->Nflags & NFLassign)
                    {   assnod[assnum] = n;
                        vec_setbit(assnum,POSS);

                        // if variable could be referenced by a pointer
                        // or a function call, mark the assignment in
                        // ambigref
                        if (!(t->EV.sp.Vsym->Sflags & SFLunambig))
                        {       vec_setbit(assnum,ambigref);
#if DEBUG
                                if (debugc)
                                {       dbg_printf("ambiguous lvalue: ");
                                        WReqn(n);
                                        dbg_printf("\n");
                                }
#endif
                        }

                        assnum++;
                    }
                }
                else if (OTrtol(op))
                {   accumda(n->E2,DEAD,POSS);
                    accumda(n->E1,DEAD,POSS);
                }
                else if (OTbinary(op))
                {   accumda(n->E1,DEAD,POSS);
                    accumda(n->E2,DEAD,POSS);
                }
                else if (OTunary(op))
                    accumda(n->E1,DEAD,POSS);
                break;
        }
}

/***************************
 * Mark all dead variables. Only worry about register candidates.
 * Compute live ranges for register candidates.
 * Be careful not to compute live ranges for members of structures (CLMOS).
 */

void deadvar()
{       SYMIDX i;

        assert(dfo);

        /* First, mark each candidate as dead.  */
        /* Initialize vectors for live ranges.  */
        /*setvecdim(dfotop);*/
        for (i = 0; i < globsym.top; i++)
        {   symbol *s = globsym.tab[i];

            if (s->Sflags & SFLunambig)
            {
                s->Sflags |= SFLdead;
                if (s->Sflags & GTregcand)
                {   if (s->Srange)
                        vec_clear(s->Srange);
                    else
                        s->Srange = vec_calloc(maxblks);
                }
            }
        }

        /* Go through trees and "liven" each one we see.        */
        for (i = 0; i < dfotop; i++)
                if (dfo[i]->Belem)
                        dvwalk(dfo[i]->Belem,i);

        /* Compute live variables. Set bit for block in live range      */
        /* if variable is in the IN set for that block.                 */
        flowlv();                       /* compute live variables       */
        for (i = 0; i < globsym.top; i++)
        {       unsigned j;

                if (globsym.tab[i]->Srange /*&& globsym.tab[i]->Sclass != CLMOS*/)
                        for (j = 0; j < dfotop; j++)
                                if (vec_testbit(i,dfo[j]->Binlv))
                                        vec_setbit(j,globsym.tab[i]->Srange);
        }

        /* Print results        */
        for (i = 0; i < globsym.top; i++)
        {       char *p;
                symbol *s = globsym.tab[i];

                if (s->Sflags & SFLdead && s->Sclass != SCparameter && s->Sclass != SCregpar)
                    s->Sflags &= ~GTregcand;    // do not put dead variables in registers
#ifdef DEBUG
                p = (char *) s->Sident ;
                if (s->Sflags & SFLdead)
                    cmes3("Symbol %d '%s' is dead\n",i,p);
                if (debugc && s->Srange /*&& s->Sclass != CLMOS*/)
                {       dbg_printf("Live range for %d '%s': ",i,p);
                        vec_println(s->Srange);
                }
#endif
        }
}

/*****************************
 * Tree walk support routine for deadvar().
 * Input:
 *      n = elem to look at
 *      i = block index
 */

STATIC void dvwalk(elem *n,unsigned i)
{
  for (; TRUE; n = n->E1)
  {     assert(n);
        if (n->Eoper == OPvar || n->Eoper == OPrelconst)
        {       symbol *s = n->EV.sp.Vsym;

                s->Sflags &= ~SFLdead;
                if (s->Srange)
                        vec_setbit(i,s->Srange);
        }
        else if (!OTleaf(n->Eoper))
        {       if (OTbinary(n->Eoper))
                        dvwalk(n->E2,i);
                continue;
        }
        break;
  }
}

/*********************************
 * Optimize very busy expressions (VBEs).
 */

static vec_t blockseen; /* which blocks we have visited         */

void verybusyexp()
{       elem **pn;
        int i;
        unsigned j,k,l;

        cmes("verybusyexp()\n");
        flowvbe();                      /* compute VBEs                 */
        if (exptop <= 1) return;        /* if no VBEs                   */
        assert(expblk);
        if (blockinit())
            return;                     // can't handle ASM blocks
        compdom();                      /* compute dominators           */
        /*setvecdim(exptop);*/
        genkillae();                    /* compute Bgen and Bkill for   */
                                        /* AEs                          */
        /*chkvecdim(exptop,0);*/
        blockseen = vec_calloc(dfotop);

        /* Go backwards through dfo so that VBEs are evaluated as       */
        /* close as possible to where they are used.                    */
        for (i = dfotop; --i >= 0;)     /* for each block               */
        {       block *b = dfo[i];
                int done;

                /* Do not hoist things to blocks that do not            */
                /* divide the flow of control.                          */

                switch (b->BC)
                {       case BCiftrue:
                        case BCswitch:
                                break;
                        default:
                                continue;
                }

                /* Find pointer to last statement in current elem */
                pn = &(b->Belem);
                if (*pn)
                {       while ((*pn)->Eoper == OPcomma)
                                pn = &((*pn)->E2);
                        /* If last statement has side effects,  */
                        /* don't do these VBEs. Potentially we  */
                        /* could by assigning the result to     */
                        /* a temporary, and rewriting the tree  */
                        /* from (n) to (T=n,T) and installing   */
                        /* the VBE as (T=n,VBE,T). This         */
                        /* may not buy us very much, so we will */
                        /* just skip it for now.                */
                        /*if (sideeffect(*pn))*/
                        if (!(*pn)->Eexp)
                                continue;
                }

                /* Eliminate all elems that have already been           */
                /* hoisted (indicated by expnod[] == 0).                */
                /* Constants are not useful as VBEs.                    */
                /* Eliminate all elems from Bout that are not in blocks */
                /* that are dominated by b.                             */
#if 0
                dbg_printf("block %d Bout = ",i);
                vec_println(b->Bout);
#endif
                done = TRUE;
                foreach (j,exptop,b->Bout)
                {       if (expnod[j] == 0 ||
                            !!OTleaf(expnod[j]->Eoper) ||
                            !dom(b,expblk[j]))
                                vec_clearbit(j,b->Bout);
                        else
                                done = FALSE;
                }
                if (done) continue;

                /* Eliminate from Bout all elems that are killed by     */
                /* a block between b and that elem.                     */
#if 0
                dbg_printf("block %d Bout = ",i);
                vec_println(b->Bout);
#endif

                foreach (j,exptop,b->Bout)
                {       list_t bl;

                        vec_clear(blockseen);
                        for (bl = expblk[j]->Bpred; bl; bl = list_next(bl))
                        {       if (killed(j,list_block(bl),b))
                                {       vec_clearbit(j,b->Bout);
                                        break;
                                }
                        }
                }

                /* For each elem still left, make sure that there       */
                /* exists a path from b to j along which there is       */
                /* no other use of j (else it would be a CSE, and       */
                /* it would be a waste of time to hoist it).            */
#if 0
                dbg_printf("block %d Bout = ",i);
                vec_println(b->Bout);
#endif

                foreach (j,exptop,b->Bout)
                {       list_t bl;

                        vec_clear(blockseen);
                        for (bl = expblk[j]->Bpred; bl; bl = list_next(bl))
                        {       if (ispath(j,list_block(bl),b))
                                        goto L2;
                        }
                        vec_clearbit(j,b->Bout);        /* thar ain't no path   */
                    L2: ;
                }


                /* For each elem that appears more than once in Bout    */
                /*      We have a VBE.                                  */
#if 0
                dbg_printf("block %d Bout = ",i);
                vec_println(b->Bout);
#endif

                foreach (j,exptop,b->Bout)
                {
                        for (k = j + 1; k < exptop; k++)
                        {       if (vec_testbit(k,b->Bout) &&
                                    el_match(expnod[j],expnod[k]))
                                        goto foundvbe;
                        }
                        continue;               /* no VBE here          */

                    foundvbe:                   /* we got one           */
#ifdef DEBUG
                        if (debugc)
                        {   dbg_printf("VBE %d,%d, block %d (",j,k,i);
                            WReqn(expnod[j]);
                            dbg_printf(");\n");
                        }
#endif
                        *pn = el_bin(OPcomma,(*pn)->Ety,
                                el_copytree(expnod[j]),*pn);

                        /* Mark all the vbe elems found but one (the    */
                        /* expnod[j] one) so that the expression will   */
                        /* only be hoisted again if other occurrances   */
                        /* of the expression are found later. This      */
                        /* will substitute for the fact that the        */
                        /* el_copytree() expression does not appear in expnod[]. */
                        l = k;
                        do
                        {       if ( k == l || (vec_testbit(k,b->Bout) &&
                                    el_match(expnod[j],expnod[k])))
                                {
                                        /* Fix so nobody else will      */
                                        /* vbe this elem                */
                                        expnod[k] = NULL;
                                        vec_clearbit(k,b->Bout);
                                }
                        } while (++k < exptop);
                        changes++;
                } /* foreach */
        } /* for */
        vec_free(blockseen);
}

/****************************
 * Return TRUE if elem j is killed somewhere
 * between b and bp.
 */

STATIC int killed(unsigned j,block *bp,block *b)
{       list_t bl;

        if (bp == b || vec_testbit(bp->Bdfoidx,blockseen))
                return FALSE;
        if (vec_testbit(j,bp->Bkill))
                return TRUE;
        vec_setbit(bp->Bdfoidx,blockseen);      /* mark as visited              */
        for (bl = bp->Bpred; bl; bl = list_next(bl))
                if (killed(j,list_block(bl),b))
                        return TRUE;
        return FALSE;
}

/***************************
 * Return TRUE if there is a path from b to bp along which
 * elem j is not used.
 * Input:
 *      b ->    block where we want to put the VBE
 *      bp ->   block somewhere between b and block containing j
 *      j =     VBE expression elem candidate (index into expnod[])
 */

STATIC int ispath(unsigned j,block *bp,block *b)
{       list_t bl;
        unsigned i;

        /*chkvecdim(exptop,0);*/
        if (bp == b) return TRUE;       /* the trivial case             */
        if (vec_testbit(bp->Bdfoidx,blockseen))
                return FALSE;           /* already seen this block      */
        vec_setbit(bp->Bdfoidx,blockseen);      /* we've visited this block     */

        /* FALSE if elem j is used in block bp (and reaches the end     */
        /* of bp, indicated by it being an AE in Bgen)                  */
        foreach (i,exptop,bp->Bgen)     /* look thru used expressions   */
        {       if (i != j && expnod[i] && el_match(expnod[i],expnod[j]))
                        return FALSE;
        }

        /* Not used in bp, see if there is a path through a predecessor */
        /* of bp                                                        */
        for (bl = bp->Bpred; bl; bl = list_next(bl))
                if (ispath(j,list_block(bl),b))
                        return TRUE;

        return FALSE;           /* j is used along all paths            */
}

#endif
