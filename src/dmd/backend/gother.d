/**
 * Other data flow analysis based optimizations.
 *
 * Copyright:   Copyright (C) 1986-1998 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     Distributed under the Boost Software License, Version 1.0.
 *              http://www.boost.org/LICENSE_1_0.txt
 * Source:      https://github.com/dlang/dmd/blob/master/src/dmd/backend/gother.d
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/backend/gother.d
 * Documentation: https://dlang.org/phobos/dmd_backend_gother.html
 */

module dmd.backend.gother;

version (SCPP)
    version = COMPILE;
version (MARS)
    version = COMPILE;

version (COMPILE)
{

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.time;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.code_x86;
import dmd.backend.oper;
import dmd.backend.global;
import dmd.backend.goh;
import dmd.backend.el;
import dmd.backend.outbuf;
import dmd.backend.symtab;
import dmd.backend.ty;
import dmd.backend.type;

import dmd.backend.barray;
import dmd.backend.dlist;
import dmd.backend.dvec;

nothrow:
@safe:

@trusted
char symbol_isintab(const Symbol *s) { return sytab[s.Sclass] & SCSS; }

extern (C++):

version (SCPP)
    import parser;

version (MARS)
    import dmd.backend.errors;

/**********************************************************************/

alias Elemdatas = Rarray!(Elemdata);

// Lists to help identify ranges of variables
struct Elemdata
{
nothrow:
    elem *pelem;            // the elem in question
    block *pblock;          // which block it's in
    Barray!(elem*) rdlist;  // list of definition elems for *pelem

    /***************************
     * Reset memory so this allocation can be re-used.
     */
    @trusted
    void reset()
    {
        rdlist.reset();
    }

    /******************
     * Initialize instance at ed.
     */
    void emplace(elem *e,block *b)
    {
        this.pelem = e;
        this.pblock = b;
    }
}

/********************************
 * Find `e` in Elemdata list.
 * Params:
 *      e = elem to find
 * Returns:
 *      Elemdata entry if found,
 *      null if not
 */
@trusted
Elemdata* find(ref Elemdatas eds, elem *e)
{
    foreach (ref edl; eds)
    {
        if (edl.pelem == e)
            return &edl;
    }
    return null;
}

/*****************
 * Free list of Elemdata's.
 */

private void elemdatafree(ref Elemdatas eds)
{
    foreach (ref ed; eds)
        ed.reset();
    eds.reset();
}

private __gshared
{
    Elemdatas eqeqlist;       // array of Elemdata's of OPeqeq & OPne elems
    Elemdatas rellist;        // array of Elemdata's of relop elems
    Elemdatas inclist;        // array of Elemdata's of increment elems
}

/*************************** Constant Propagation ***************************/


/**************************
 * Constant propagation.
 * Also detects use of variable before any possible def.
 */

@trusted
void constprop()
{
    rd_compute();
    intranges(rellist, inclist); // compute integer ranges
    eqeqranges(eqeqlist);        // see if we can eliminate some relationals
    elemdatafree(eqeqlist);
    elemdatafree(rellist);
    elemdatafree(inclist);
}

/************************************
 * Compute reaching definitions.
 * Note: RD vectors are destroyed by this.
 */

private __gshared block *thisblock;

@trusted
private void rd_compute()
{
    if (debugc) printf("constprop()\n");
    assert(dfo);
    flowrd();               /* compute reaching definitions (rd)    */
    if (go.defnod.length == 0)     /* if no reaching defs                  */
        return;
    assert(rellist.length == 0 && inclist.length == 0 && eqeqlist.length == 0);
    block_clearvisit();
    foreach (b; dfo[])    // for each block
    {
        switch (b.BC)
        {
            case BCjcatch:
            case BC_finally:
            case BC_lpad:
            case BCasm:
            case BCcatch:
                block_visit(b);
                break;

            default:
                break;
        }
    }

    foreach (i, b; dfo[])    // for each block
    {
        thisblock = b;

        //printf("block %d Bin ",i); vec_println(b.Binrd);
        //printf("       Bout "); vec_println(b.Boutrd);

        if (b.Bflags & BFLvisited)
            continue;                   // not reliable for this block
        if (b.Belem)
        {
            conpropwalk(b.Belem,b.Binrd);

            debug
            if (!(vec_equal(b.Binrd,b.Boutrd)))
            {
                int j;

                printf("block %d Binrd ", cast(int) i); vec_println(b.Binrd);
                printf("       Boutrd "); vec_println(b.Boutrd);
                WReqn(b.Belem);
                printf("\n");
                vec_xorass(b.Binrd,b.Boutrd);
                j = cast(int)vec_index(0,b.Binrd);
                WReqn(go.defnod[j].DNelem);
                printf("\n");
            }

            assert(vec_equal(b.Binrd,b.Boutrd));
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
@trusted
private void conpropwalk(elem *n,vec_t IN)
{
    vec_t L,R;
    elem *t;

    assert(n && IN);
    //printf("conpropwalk()\n"),elem_print(n);
    const op = n.Eoper;
    if (op == OPcolon || op == OPcolon2)
    {
        L = vec_clone(IN);
        switch (el_returns(n.EV.E1) * 2 | el_returns(n.EV.E2))
        {
            case 3: // E1 and E2 return
                conpropwalk(n.EV.E1,L);
                conpropwalk(n.EV.E2,IN);
                vec_orass(IN,L);                // IN = L | R
                break;

            case 2: // E1 returns
                conpropwalk(n.EV.E1,IN);
                conpropwalk(n.EV.E2,L);
                break;

            case 1: // E2 returns
                conpropwalk(n.EV.E1,L);
                conpropwalk(n.EV.E2,IN);
                break;

            case 0: // neither returns
                conpropwalk(n.EV.E1,L);
                vec_copy(L,IN);
                conpropwalk(n.EV.E2,L);
                break;

            default:
                break;
        }
        vec_free(L);
    }
    else if (op == OPandand || op == OPoror)
    {
        conpropwalk(n.EV.E1,IN);
        R = vec_clone(IN);
        conpropwalk(n.EV.E2,R);
        if (el_returns(n.EV.E2))
            vec_orass(IN,R);                // IN |= R
        vec_free(R);
    }
    else if (OTunary(op))
        goto L3;
    else if (ERTOL(n))
    {
        conpropwalk(n.EV.E2,IN);
      L3:
        t = n.EV.E1;
        if (OTassign(op))
        {
            if (t.Eoper == OPvar)
            {
                // Note that the following ignores OPnegass
                if (OTopeq(op) && sytab[t.EV.Vsym.Sclass] & SCRD)
                {
                    Barray!(elem*) rdl;
                    listrds(IN,t,null,&rdl);
                    if (!(config.flags & CFGnowarning)) // if warnings are enabled
                        chkrd(t,rdl);
                    if (auto e = chkprop(t,rdl))
                    {   // Replace (t op= exp) with (t = e op exp)

                        e = el_copytree(e);
                        e.Ety = t.Ety;
                        n.EV.E2 = el_bin(opeqtoop(op),n.Ety,e,n.EV.E2);
                        n.Eoper = OPeq;
                    }
                    rdl.dtor();
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
        {   t = n.EV.E1;
            if (t.Eoper != OPvar)
                conpropwalk(t,IN);
        }
        else
            conpropwalk(n.EV.E1,IN);
        conpropwalk(n.EV.E2,IN);
    }

    // Collect data for subsequent optimizations
    if (OTbinary(op) && n.EV.E1.Eoper == OPvar && n.EV.E2.Eoper == OPconst)
    {
        switch (op)
        {
            case OPlt:
            case OPgt:
            case OPle:
            case OPge:
                // Collect compare elems and their rd's in the rellist list
                if (tyintegral(n.EV.E1.Ety) &&
                    tyintegral(n.EV.E2.Ety)
                   )
                {
                    //printf("appending to rellist\n"); elem_print(n);
                    //printf("\trellist IN: "); vec_print(IN); printf("\n");
                    auto pdata = rellist.push();
                    pdata.emplace(n,thisblock);
                    listrds(IN, n.EV.E1, null, &pdata.rdlist);
                }
                break;

            case OPaddass:
            case OPminass:
            case OPpostinc:
            case OPpostdec:
                // Collect increment elems and their rd's in the inclist list
                if (tyintegral(n.EV.E1.Ety))
                {
                    //printf("appending to inclist\n"); elem_print(n);
                    //printf("\tinclist IN: "); vec_print(IN); printf("\n");
                    auto pdata = inclist.push();
                    pdata.emplace(n,thisblock);
                    listrds(IN, n.EV.E1, null, &pdata.rdlist);
                }
                break;

            case OPne:
            case OPeqeq:
                // Collect compare elems and their rd's in the rellist list
                if (tyintegral(n.EV.E1.Ety))
                {   //printf("appending to eqeqlist\n"); elem_print(n);
                    auto pdata = eqeqlist.push();
                    pdata.emplace(n,thisblock);
                    listrds(IN, n.EV.E1, null, &pdata.rdlist);
                }
                break;

            default:
                break;
        }
    }


    if (OTdef(op))                  /* if definition elem           */
        updaterd(n,IN,null);        /* then update IN vector        */

    /* now we get to the part that checks to see if we can  */
    /* propagate a constant.                                */
    if (op == OPvar && sytab[n.EV.Vsym.Sclass] & SCRD)
    {
        //printf("const prop: %s\n", n.EV.Vsym.Sident);
        Barray!(elem*) rdl;
        listrds(IN,n,null,&rdl);

        if (!(config.flags & CFGnowarning))     // if warnings are enabled
            chkrd(n,rdl);
        elem *e = chkprop(n,rdl);
        if (e)
        {   tym_t nty;

            nty = n.Ety;
            el_copy(n,e);
            n.Ety = nty;                       // retain original type
        }
        rdl.dtor();
    }
}

/******************************
 * Give error if there are no reaching defs for variable v.
 */

@trusted
private void chkrd(elem *n, Barray!(elem*) rdlist)
{
    Symbol *sv;
    int unambig;

    sv = n.EV.Vsym;
    assert(sytab[sv.Sclass] & SCRD);
    if (sv.Sflags & SFLnord)           // if already printed a warning
        return;
    if (sv.ty() & (mTYvolatile | mTYshared))
        return;
    unambig = sv.Sflags & SFLunambig;
    foreach (d; rdlist)
    {
        elem_debug(d);
        if (d.Eoper == OPasm)          /* OPasm elems ruin everything  */
            return;
        if (OTassign(d.Eoper))
        {
            if (d.EV.E1.Eoper == OPvar)
            {
                if (d.EV.E1.EV.Vsym == sv)
                    return;
            }
            else if (!unambig)
                return;
        }
        else
        {
            if (!unambig)
                return;
        }
    }

    // If there are any asm blocks, don't print the message
    foreach (b; dfo[])
        if (b.BC == BCasm)
            return;

    // If variable contains bit fields, don't print message (because if
    // bit field is the first set, then we get a spurious warning).
    // STL uses 0 sized structs to transmit type information, so
    // don't complain about them being used before set.
    if (type_struct(sv.Stype))
    {
        if (sv.Stype.Ttag.Sstruct.Sflags & (STRbitfields | STR0size))
            return;
    }

    static if (0)
    {
        // If variable is zero length static array, don't print message.
        // BUG: Suppress error even if variable is initialized with void.
        if (sv.Stype.Tty == TYarray && sv.Stype.Tdim == 0)
        {
            printf("sv.Sident = %s\n", sv.Sident);
            return;
        }
    }

    version (SCPP)
    {
        {   Outbuffer buf;
            char *p2;

            type_tostring(&buf, sv.Stype);
            buf.writeByte(' ');
            buf.write(sv.Sident.ptr);
            p2 = buf.toString();
            warerr(WM.WM_used_b4_set, p2);     // variable used before set
        }
    }

    version (MARS)
    {
        /* Watch out for:
            void test()
            {
                void[0] x;
                auto y = x;
            }
         */
        if (type_size(sv.Stype) != 0)
        {
            error(n.Esrcpos.Sfilename, n.Esrcpos.Slinnum, n.Esrcpos.Scharnum,
                "variable %s used before set", sv.Sident.ptr);
        }
    }

    sv.Sflags |= SFLnord;              // no redundant messages
    //elem_print(n);
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
 *      null    do not propagate constant
 *      e       constant elem that we should replace n with
 */

@trusted
private elem * chkprop(elem *n, Barray!(elem*) rdlist)
{
    elem *foundelem = null;
    int unambig;
    Symbol *sv;
    tym_t nty;
    uint nsize;
    targ_size_t noff;

    //printf("checkprop: "); WReqn(n); printf("\n");
    assert(n && n.Eoper == OPvar);
    elem_debug(n);
    sv = n.EV.Vsym;
    assert(sytab[sv.Sclass] & SCRD);
    nty = n.Ety;
    if (!tyscalar(nty))
        goto noprop;
    nsize = cast(uint)size(nty);
    noff = n.EV.Voffset;
    unambig = sv.Sflags & SFLunambig;
    foreach (d; rdlist)
    {
        elem_debug(d);

        //printf("\trd: "); WReqn(d); printf("\n");
        if (d.Eoper == OPasm)          /* OPasm elems ruin everything  */
            goto noprop;

        // Runs afoul of Buzilla 4506
        /*if (OTassign(d.Eoper) && EBIN(d))*/      // if assignment elem

        if (OTassign(d.Eoper))      // if assignment elem
        {
            elem *t = d.EV.E1;

            if (t.Eoper == OPvar)
            {
                assert(t.EV.Vsym == sv);

                if (d.Eoper == OPstreq ||
                    !tyscalar(t.Ety))
                    goto noprop;        // not worth bothering with these cases

                if (d.Eoper == OPnegass)
                    goto noprop;        // don't bother with this case, either

                /* Everything must match or we must skip this variable  */
                /* (in case of assigning to overlapping unions, etc.)   */
                if (t.EV.Voffset != noff ||
                    /* If sizes match, we are ok        */
                    size(t.Ety) != nsize &&
                        !(d.EV.E2.Eoper == OPconst && size(t.Ety) > nsize && !tyfloating(d.EV.E2.Ety)))
                    goto noprop;
            }
            else
            {
                if (unambig)            /* unambiguous assignments only */
                    continue;
                goto noprop;
            }
            if (d.Eoper != OPeq)
                goto noprop;
        }
        else                            /* must be a call elem          */
        {
            if (unambig)
                continue;
            else
                goto noprop;            /* could be affected            */
        }

        if (d.EV.E2.Eoper == OPconst || d.EV.E2.Eoper == OPrelconst)
        {
            if (foundelem)              /* already found one            */
            {                           /* then they must be the same   */
                if (!el_match(foundelem,d.EV.E2))
                    goto noprop;
            }
            else                        /* else this is it              */
                foundelem = d.EV.E2;
        }
        else
            goto noprop;
    }

    if (foundelem)                      /* if we got one                 */
    {                                   /* replace n with foundelem      */
        debug if (debugc)
        {
            printf("const prop (");
            WReqn(n);
            printf(" replaced by ");
            WReqn(foundelem);
            printf("), %p to %p\n",foundelem,n);
        }
        go.changes++;
        return foundelem;
    }
noprop:
    return null;
}

/***********************************
 * Find all the reaching defs of OPvar e.
 * Params:
 *      IN = vector of definition nodes
 *      e = OPvar
 *      f = if not null, set RD bits in it
 *      rdlist = if not null, append reaching defs to it
 */

@trusted
void listrds(vec_t IN,elem *e,vec_t f, Barray!(elem*)* rdlist)
{
    uint i;
    uint unambig;
    Symbol *s;
    uint nsize;
    targ_size_t noff;
    tym_t ty;

    //printf("listrds: "); WReqn(e); printf("\n");
    assert(IN);
    assert(e.Eoper == OPvar);
    s = e.EV.Vsym;
    ty = e.Ety;
    if (tyscalar(ty))
        nsize = cast(uint)size(ty);
    noff = e.EV.Voffset;
    unambig = s.Sflags & SFLunambig;
    if (f)
        vec_clear(f);
    for (i = 0; (i = cast(uint) vec_index(i, IN)) < go.defnod.length; ++i)
    {
        elem *d = go.defnod[i].DNelem;
        //printf("\tlooking at "); WReqn(d); printf("\n");
        const op = d.Eoper;
        if (op == OPasm)                // assume ASM elems define everything
            goto listit;
        if (OTassign(op))
        {   elem *t = d.EV.E1;

            if (t.Eoper == OPvar && t.EV.Vsym == s)
            {   if (op == OPstreq)
                    goto listit;
                if (!tyscalar(ty) || !tyscalar(t.Ety))
                    goto listit;
                // If t does not overlap e, then it doesn't affect things
                if (noff + nsize > t.EV.Voffset &&
                    t.EV.Voffset + size(t.Ety) > noff)
                    goto listit;                // it's an assignment to s
            }
            else if (t.Eoper != OPvar && !unambig)
                goto listit;            /* assignment through pointer   */
        }
        else if (!unambig)
            goto listit;                /* probably a function call     */
        continue;

    listit:
        //printf("\tlisting "); WReqn(d); printf("\n");
        if (f)
            vec_setbit(i,f);
        else
            (*rdlist).push(d);     // add the definition node
    }
}

/********************************************
 * Look at reaching defs for expressions of the form (v == c) and (v != c).
 * If all definitions of v are c or are not c, then we can replace the
 * expression with 1 or 0.
 * Params:
 *      eqeqlist = array of == and != expressions
 */

@trusted
private void eqeqranges(ref Elemdatas eqeqlist)
{
    Symbol *v;
    int sz;
    elem *e;
    targ_llong c;
    int result;

    foreach (ref rel; eqeqlist)
    {
        e = rel.pelem;
        v = e.EV.E1.EV.Vsym;
        if (!(sytab[v.Sclass] & SCRD))
            continue;
        sz = tysize(e.EV.E1.Ety);
        c = el_tolong(e.EV.E2);

        result = -1;                    // result not known yet
        foreach (erd; rel.rdlist)
        {
            elem *erd1;
            int szrd;
            int tmp;

            elem_debug(erd);
            if (erd.Eoper != OPeq ||
                (erd1 = erd.EV.E1).Eoper != OPvar ||
                erd.EV.E2.Eoper != OPconst
               )
                goto L1;
            szrd = tysize(erd1.Ety);
            if (erd1.EV.Voffset + szrd <= e.EV.E1.EV.Voffset ||
                e.EV.E1.EV.Voffset + sz <= erd1.EV.Voffset)
                continue;               // doesn't affect us, skip it
            if (szrd != sz || e.EV.E1.EV.Voffset != erd1.EV.Voffset)
                goto L1;                // overlapping - forget it

            tmp = (c == el_tolong(erd.EV.E2));
            if (result == -1)
                result = tmp;
            else if (result != tmp)
                goto L1;
        }
        if (result >= 0)
        {
            //printf("replacing with %d\n",result);
            el_free(e.EV.E1);
            el_free(e.EV.E2);
            e.EV.Vint = (e.Eoper == OPeqeq) ? result : result ^ 1;
            e.Eoper = OPconst;
        }
    L1:
    }
}

/******************************
 * Examine rellist and inclist to determine if any of the signed compare
 * elems in rellist can be replace by unsigned compares.
 * Params:
 *      rellist = array of relationals in function
 *      inclist = array of increment elems in function
 */

@trusted
private void intranges(ref Elemdatas rellist, ref Elemdatas inclist)
{
    block *rb;
    block *ib;
    Symbol *v;
    elem *rdeq;
    elem *rdinc;
    uint incop,relatop;
    targ_llong initial,increment,final_;

    if (debugc) printf("intranges()\n");
    static if (0)
    {
        foreach (int i, ref rel; rellist)
        {
            printf("[%d] rel.pelem: ", i); WReqn(rel.pelem); printf("\n");
        }
    }

    foreach (ref rel; rellist)
    {
        rb = rel.pblock;
        //printf("rel.pelem: "); WReqn(rel.pelem); printf("\n");
        assert(rel.pelem.EV.E1.Eoper == OPvar);
        v = rel.pelem.EV.E1.EV.Vsym;

        // RD info is only reliable for registers and autos
        if (!(sytab[v.Sclass] & SCRD))
            continue;

        /* Look for two rd's: an = and an increment     */
        if (rel.rdlist.length != 2)
            continue;
        rdeq = rel.rdlist[1];
        if (rdeq.Eoper != OPeq)
        {   rdinc = rdeq;
            rdeq = rel.rdlist[0];
            if (rdeq.Eoper != OPeq)
                continue;
        }
        else
            rdinc = rel.rdlist[0];

        static if (0)
        {
            printf("\neq:  "); WReqn(rdeq); printf("\n");
            printf("rel: "); WReqn(rel.pelem); printf("\n");
            printf("inc: "); WReqn(rdinc); printf("\n");
        }

        incop = rdinc.Eoper;
        if (!OTpost(incop) && incop != OPaddass && incop != OPminass)
            continue;

        /* lvalues should be unambiguous defs   */
        if (rdeq.EV.E1.Eoper != OPvar || rdinc.EV.E1.Eoper != OPvar)
            continue;
        /* rvalues should be constants          */
        if (rdeq.EV.E2.Eoper != OPconst || rdinc.EV.E2.Eoper != OPconst)
            continue;

        /* Ensure that the only defs reaching the increment elem (rdinc) */
        /* are rdeq and rdinc.                                          */
        foreach (ref iel; inclist)
        {
            elem *rd1;
            elem *rd2;

            ib = iel.pblock;
            if (iel.pelem != rdinc)
                continue;               /* not our increment elem       */
            if (iel.rdlist.length != 2)
            {
                //printf("!= 2\n");
                break;
            }
            rd1 = iel.rdlist[0];
            rd2 = iel.rdlist[1];
            /* The rd's for the relational elem (rdeq,rdinc) must be    */
            /* the same as the rd's for tne increment elem (rd1,rd2).   */
            if (rd1 == rdeq && rd2 == rdinc || rd1 == rdinc && rd2 == rdeq)
                goto found;
        }
        goto nextrel;

    found:
        // Check that all paths from rdinc to rdinc must pass through rdrel
        {
            int i;

            // ib:      block of increment
            // rb:      block of relational
            i = loopcheck(ib,ib,rb);
            block_clearvisit();
            if (i)
                continue;
        }

        /* Gather initial, increment, and final values for loop */
        initial = el_tolong(rdeq.EV.E2);
        increment = el_tolong(rdinc.EV.E2);
        if (incop == OPpostdec || incop == OPminass)
            increment = -increment;
        relatop = rel.pelem.Eoper;
        final_ = el_tolong(rel.pelem.EV.E2);
        //printf("initial = %d, increment = %d, final_ = %d\n",initial,increment,final_);

        /* Determine if we can make the relational an unsigned  */
        if (initial >= 0)
        {
            if (final_ == 0 && relatop == OPge)
            {
                /* if the relation is (i >= 0) there is likely some dependency
                 * on switching sign, so do not make it unsigned
                 */
            }
            else if (final_ >= initial)
            {
                if (increment > 0 && ((final_ - initial) % increment) == 0)
                    goto makeuns;
            }
            else if (final_ >= 0)
            {   /* 0 <= final_ < initial */
                if (increment < 0 && ((final_ - initial) % increment) == 0 &&
                    !(final_ + increment < 0 &&
                        (relatop == OPge || relatop == OPlt)
                     )
                   )
                {
                makeuns:
                    if (!tyuns(rel.pelem.EV.E2.Ety))
                    {
                        rel.pelem.EV.E2.Ety = touns(rel.pelem.EV.E2.Ety);
                        rel.pelem.Nflags |= NFLtouns;

                        debug
                        if (debugc)
                        {   WReqn(rel.pelem);
                            printf(" made unsigned, initial = %lld, increment = %lld," ~
                                   " final_ = %lld\n",cast(long)initial,cast(long)increment,cast(long)final_);
                        }
                        go.changes++;
                    }

                    static if (0)
                    {
                        // Eliminate loop if it is empty
                        if (relatop == OPlt &&
                            rb.BC == BCiftrue &&
                            list_block(rb.Bsucc) == rb &&
                            rb.Belem.Eoper == OPcomma &&
                            rb.Belem.EV.E1 == rdinc &&
                            rb.Belem.EV.E2 == rel.pelem
                           )
                        {
                            rel.pelem.Eoper = OPeq;
                            rel.pelem.Ety = rel.pelem.EV.E1.Ety;
                            rb.BC = BCgoto;
                            list_subtract(&rb.Bsucc,rb);
                            list_subtract(&rb.Bpred,rb);

                            debug
                                if (debugc)
                                {
                                    WReqn(rel.pelem);
                                    printf(" eliminated loop\n");
                                }

                            go.changes++;
                        }
                    }
                }
            }
        }

      nextrel:
    }
}

/******************************
 * Look for initialization and increment expressions in loop.
 * Very similar to intranges().
 * Params:
 *   rellist = list of relationals in function
 *   inclist = list of increment elems in function.
 *   erel = loop compare expression of the form (v < c)
 *   rdeq = set to loop initialization of v
 *   rdinc = set to loop increment of v
 * Returns:
 *   false if cannot find rdeq or rdinc
 */

@trusted
private bool returnResult(bool result)
{
    elemdatafree(eqeqlist);
    elemdatafree(rellist);
    elemdatafree(inclist);
    return result;
}

@trusted
bool findloopparameters(elem* erel, ref elem* rdeq, ref elem* rdinc)
{
    if (debugc) printf("findloopparameters()\n");
    const bool log = false;

    assert(erel.EV.E1.Eoper == OPvar);
    Symbol* v = erel.EV.E1.EV.Vsym;

    // RD info is only reliable for registers and autos
    if (!(sytab[v.Sclass] & SCRD))
        return false;

    rd_compute();       // compute rellist, inclist, eqeqlist

    /* Find `erel` in `rellist`
     */
    Elemdata* rel = rellist.find(erel);
    if (!rel)
    {
        if (log) printf("\trel not found\n");
        return returnResult(false);
    }

    block* rb = rel.pblock;
    //printf("rel.pelem: "); WReqn(rel.pelem); printf("\n");


    // Look for one reaching definition: an increment
    if (rel.rdlist.length != 1)
    {
        if (log) printf("\tnitems = %d\n", cast(int)rel.rdlist.length);
        return returnResult(false);
    }

    rdinc = rel.rdlist[0];

    static if (0)
    {
        printf("\neq:  "); WReqn(rdeq); printf("\n");
        printf("rel: "); WReqn(rel.pelem); printf("\n");
        printf("inc: "); WReqn(rdinc); printf("\n");
    }

    uint incop = rdinc.Eoper;
    if (!OTpost(incop) && incop != OPaddass && incop != OPminass)
    {
        if (log) printf("\tnot += or -=\n");
        return returnResult(false);
    }

    Elemdata* iel = inclist.find(rdinc);
    if (!iel)
    {
        if (log) printf("\trdinc not found\n");
        return returnResult(false);
    }

    /* The increment should have two reaching definitions:
     *   the initialization
     *   the increment itself
     * We already have the increment (as rdinc), but need the initialization (rdeq)
     */
    if (iel.rdlist.length != 2)
    {
        if (log) printf("nitems != 2\n");
        return returnResult(false);
    }
    elem *rd1 = iel.rdlist[0];
    elem *rd2 = iel.rdlist[1];
    if (rd1 == rdinc)
        rdeq = rd2;
    else if (rd2 == rdinc)
        rdeq = rd1;
    else
    {
        if (log) printf("\tnot (rdeq,rdinc)\n");
        return returnResult(false);
    }

    // lvalues should be unambiguous defs
    if (rdeq.Eoper != OPeq || rdeq.EV.E1.Eoper != OPvar || rdinc.EV.E1.Eoper != OPvar)
    {
        if (log) printf("\tnot OPvar\n");
        return returnResult(false);
    }

    // rvalues should be constants
    if (rdeq.EV.E2.Eoper != OPconst || rdinc.EV.E2.Eoper != OPconst)
    {
        if (log) printf("\tnot OPconst\n");
        return returnResult(false);
    }

    /* Check that all paths from rdinc to rdinc must pass through rdrel
     * iel.pblock = block of increment
     * rel.pblock = block of relational
     */
    int i = loopcheck(iel.pblock,iel.pblock,rel.pblock);
    block_clearvisit();
    if (i)
    {
        if (log) printf("\tnot loopcheck()\n");
        return returnResult(false);
    }

    return returnResult(true);
}

/***********************
 * Return true if there is a path from start to inc without
 * passing through rel.
 */

@trusted
private int loopcheck(block *start,block *inc,block *rel)
{
    if (!(start.Bflags & BFLvisited))
    {   start.Bflags |= BFLvisited;    /* guarantee eventual termination */
        foreach (list; ListRange(start.Bsucc))
        {
            block *b = cast(block *) list_ptr(list);
            if (b != rel && (b == inc || loopcheck(b,inc,rel)))
                return true;
        }
    }
    return false;
}

/****************************
 * Do copy propagation.
 * Copy propagation elems are of the form OPvar=OPvar, and they are
 * in go.expnod[].
 */


@trusted
void copyprop()
{
    out_regcand(&globsym);
    if (debugc) printf("copyprop()\n");
    assert(dfo);

Louter:
    while (1)
    {
        flowcp();               /* compute available copy statements    */
        if (go.exptop <= 1)
            return;             // none available
        static if (0)
        {
            foreach (i; 1 .. go.exptop)
            {
                printf("go.expnod[%d] = (",i);
                WReqn(go.expnod[i]);
                printf(");\n");
            }
        }
        foreach (i, b; dfo[])    // for each block
        {
            if (b.Belem)
            {
                bool recalc;
                static if (0)
                {
                    printf("B%d, elem (",i);
                    WReqn(b.Belem); printf(")\nBin  ");
                    vec_println(b.Bin);
                    recalc = copyPropWalk(b.Belem,b.Bin);
                    printf("Bino ");
                    vec_println(b.Bin);
                    printf("Bout ");
                    vec_println(b.Bout);
                }
                else
                {
                    recalc = copyPropWalk(b.Belem,b.Bin);
                }
                /*assert(vec_equal(b.Bin,b.Bout));              */
                /* The previous assert() is correct except      */
                /* for the following case:                      */
                /*      a=b; d=a; a=b;                          */
                /* The vectors don't match because the          */
                /* equations changed to:                        */
                /*      a=b; d=b; a=b;                          */
                /* and the d=b copy elem now reaches the end    */
                /* of the block (the d=a elem didn't).          */
                if (recalc)
                    continue Louter;
            }
        }
        return;
    }
}

/*****************************
 * Walk tree n, doing copy propagation as we go.
 * Keep IN up to date.
 * Params:
 *      n = tree to walk & do copy propagation in
 *      IN = vector of live copy expressions, updated as progress is made
 * Returns:
 *      true if need to recalculate data flow equations and try again
 */

@trusted
private bool copyPropWalk(elem *n,vec_t IN)
{
    bool recalc = false;
    int nocp = 0;

    void cpwalk(elem* n, vec_t IN)
    {
        assert(n && IN);
        /*chkvecdim(go.exptop,0);*/
        if (recalc)
            return;

        elem *t;
        const op = n.Eoper;
        if (op == OPcolon || op == OPcolon2)
        {
            vec_t L = vec_clone(IN);
            cpwalk(n.EV.E1,L);
            cpwalk(n.EV.E2,IN);
            vec_andass(IN,L);               // IN = L & R
            vec_free(L);
        }
        else if (op == OPandand || op == OPoror)
        {
            cpwalk(n.EV.E1,IN);
            vec_t L = vec_clone(IN);
            cpwalk(n.EV.E2,L);
            vec_andass(IN,L);               // IN = L & R
            vec_free(L);
        }
        else if (OTunary(op))
        {
            t = n.EV.E1;
            if (OTassign(op))
            {
                if (t.Eoper == OPind)
                    cpwalk(t.EV.E1,IN);
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
        {
            cpwalk(n.EV.E2,IN);
            t = n.EV.E1;
            if (t.Eoper == OPind)
                cpwalk(t,IN);
            else
            {
                debug if (t.Eoper != OPvar) elem_print(n);
                assert(t.Eoper == OPvar);
            }
        }
        else if (ERTOL(n))
        {
            cpwalk(n.EV.E2,IN);
            cpwalk(n.EV.E1,IN);
        }
        else if (OTbinary(op))
        {
            cpwalk(n.EV.E1,IN);
            cpwalk(n.EV.E2,IN);
        }

        if (OTdef(op))                  // if definition elem
        {
            int ambig;              /* true if ambiguous def        */

            ambig = !OTassign(op) || t.Eoper == OPind;
            uint i;
            for (i = 0; (i = cast(uint) vec_index(i, IN)) < go.exptop; ++i) // for each active copy elem
            {
                Symbol *v;

                if (op == OPasm)
                    goto clr;

                /* If this elem could kill the lvalue or the rvalue, */
                /*      Clear bit in IN.                        */
                v = go.expnod[i].EV.E1.EV.Vsym;
                if (ambig)
                {
                    if (!(v.Sflags & SFLunambig))
                        goto clr;
                }
                else
                {
                    if (v == t.EV.Vsym)
                        goto clr;
                }
                v = go.expnod[i].EV.E2.EV.Vsym;
                if (ambig)
                {
                    if (!(v.Sflags & SFLunambig))
                        goto clr;
                }
                else
                {
                    if (v == t.EV.Vsym)
                        goto clr;
                }
                continue;

            clr:                        /* this copy elem is not available */
                vec_clearbit(i,IN);     /* so remove it from the vector */
            } /* foreach */

            /* If this is a copy elem in go.expnod[]   */
            /*      Set bit in IN.                     */
            if ((op == OPeq || op == OPstreq) && n.EV.E1.Eoper == OPvar &&
                n.EV.E2.Eoper == OPvar && n.Eexp)
                vec_setbit(n.Eexp,IN);
        }
        else if (op == OPvar && !nocp)  // if reference to variable v
        {
            Symbol *v = n.EV.Vsym;

            //printf("Checking copyprop for '%s', ty=x%x\n", v.Sident.ptr,n.Ety);
            symbol_debug(v);
            const ty = n.Ety;
            uint sz = tysize(n.Ety);
            if (sz == -1 && !tyfunc(n.Ety))
                sz = cast(uint)type_size(v.Stype);

            elem *foundelem = null;
            Symbol *f;
            for (uint i = 0; (i = cast(uint) vec_index(i, IN)) < go.exptop; ++i) // for all active copy elems
            {
                elem* c = go.expnod[i];
                assert(c);

                uint csz = tysize(c.EV.E1.Ety);
                if (c.Eoper == OPstreq)
                    csz = cast(uint)type_size(c.ET);
                assert(cast(int)csz >= 0);

                //printf("  looking at: ("); WReqn(c); printf("), ty=x%x\n",c.EV.E1.Ety);
                /* Not only must symbol numbers match, but      */
                /* offsets too (in case of arrays) and sizes    */
                /* (in case of unions).                         */
                if (v == c.EV.E1.EV.Vsym &&
                    n.EV.Voffset >= c.EV.E1.EV.Voffset &&
                    n.EV.Voffset + sz <= c.EV.E1.EV.Voffset + csz)
                {
                    if (foundelem)
                    {
                        if (c.EV.E2.EV.Vsym != f)
                            goto noprop;
                    }
                    else
                    {
                        foundelem = c;
                        f = foundelem.EV.E2.EV.Vsym;
                    }
                }
            }
            if (foundelem)          /* if we can do the copy prop   */
            {
                debug if (debugc)
                {
                    printf("Copyprop, '%s'(%d) replaced with '%s'(%d)\n",
                        (v.Sident[0]) ? cast(char *)v.Sident.ptr : "temp".ptr, cast(int) v.Ssymnum,
                        (f.Sident[0]) ? cast(char *)f.Sident.ptr : "temp".ptr, cast(int) f.Ssymnum);
                }

                type *nt = n.ET;
                targ_size_t noffset = n.EV.Voffset;
                el_copy(n,foundelem.EV.E2);
                n.Ety = ty;    // retain original type
                n.ET = nt;
                n.EV.Voffset += noffset - foundelem.EV.E1.EV.Voffset;

                /* original => rewrite
                 *  v = f
                 *  g = v   => g = f
                 *  f = x
                 *  d = g   => d = f !!error
                 * Therefore, if n appears as an rvalue in go.expnod[], then recalc
                 */
                for (size_t j = 1; j < go.exptop; ++j)
                {
                    //printf("go.expnod[%d]: ", j); elem_print(go.expnod[j]);
                    if (go.expnod[j].EV.E2 == n)
                    {
                        recalc = true;
                        break;
                    }
                }

                go.changes++;
            }
            //else printf("not found\n");
        noprop:
            {   }
        }
    }

    cpwalk(n, IN);
    return recalc;
}

/********************************
 * Remove dead assignments. Those are assignments to a variable v
 * for which there are no subsequent uses of v.
 */

private __gshared
{
    Barray!(elem*) assnod;      /* array of pointers to asg elems       */
    vec_t ambigref;             /* vector of assignment elems that      */
                                /* are referenced when an ambiguous     */
                                /* reference is done (as in *p or call) */
}

@trusted
void rmdeadass()
{
    if (debugc) printf("rmdeadass()\n");
    flowlv();                       /* compute live variables       */
    foreach (b; dfo[])         // for each block b
    {
        if (!b.Belem)          /* if no elems at all           */
            continue;
        if (b.Btry)            // if in try-block guarded body
            continue;
        const assnum = numasg(b.Belem);   // # of assignment elems
        if (assnum == 0)                  // if no assignment elems
            continue;

        assnod.setLength(assnum);         // pre-allocate sufficient room
        vec_t DEAD = vec_calloc(assnum);
        vec_t POSS = vec_calloc(assnum);

        ambigref = vec_calloc(assnum);
        assnod.setLength(0);
        accumda(b.Belem,DEAD,POSS);    // fill assnod[], compute DEAD and POSS
        assert(assnum == assnod.length);
        vec_free(ambigref);

        vec_orass(POSS,DEAD);   /* POSS |= DEAD                 */
        for (uint j = 0; (j = cast(uint) vec_index(j, POSS)) < assnum; ++j) // for each possible dead asg.
        {
            Symbol *v;      /* v = target of assignment     */
            elem *n;
            elem *nv;

            n = assnod[j];
            nv = n.EV.E1;
            v = nv.EV.Vsym;
            if (!symbol_isintab(v)) // not considered
                continue;
            //printf("assnod[%d]: ",j); WReqn(n); printf("\n");
            //printf("\tPOSS\n");
            /* If not positively dead but v is live on a    */
            /* successor to b, then v is live.              */
            //printf("\tDEAD=%d, live=%d\n",vec_testbit(j,DEAD),vec_testbit(v.Ssymnum,b.Boutlv));
            if (!vec_testbit(j,DEAD) && vec_testbit(v.Ssymnum,b.Boutlv))
                continue;
            /* volatile/shared variables are not dead              */
            if ((v.ty() | nv.Ety) & (mTYvolatile | mTYshared))
                continue;

            /* Do not mix up floating and integer variables
             * https://issues.dlang.org/show_bug.cgi?id=20363
             */
            if (OTbinary(n.Eoper))
            {
                elem* e2 = n.EV.E2;
                if (e2.Eoper == OPvar &&
                    config.fpxmmregs &&
                    !tyfloating(v.Stype.Tty) != !tyfloating(e2.EV.Vsym.Stype.Tty)
                   )
                    continue;
            }

            debug if (debugc)
            {
                printf("dead assignment (");
                WReqn(n);
                if (vec_testbit(j,DEAD))
                    printf(") DEAD\n");
                else
                    printf(") Boutlv\n");
            }
            elimass(n);
            go.changes++;
        } /* foreach */
        vec_free(DEAD);
        vec_free(POSS);
    } /* for */
}

/***************************
 * Remove side effect of assignment elem.
 */

@trusted
void elimass(elem *n)
{   elem *e1;

    switch (n.Eoper)
    {
        case OPvecsto:
            n.EV.E2.Eoper = OPcomma;
            goto case OPeq;

        case OPeq:
        case OPstreq:
            /* (V=e) => (random constant,e)     */
            /* Watch out for (a=b=c) stuff!     */
            /* Don't screw up assnod[]. */
            n.Eoper = OPcomma;
            n.Ety |= n.EV.E2.Ety & (mTYconst | mTYvolatile | mTYimmutable | mTYshared
                 | mTYfar
                );
            n.EV.E1.Eoper = OPconst;
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
            n.Eoper = cast(ubyte)opeqtoop(n.Eoper);
            break;

        case OPpostinc: /* (V i++ c) => V       */
        case OPpostdec: /* (V i-- c) => V       */
            e1 = n.EV.E1;
            el_free(n.EV.E2);
            el_copy(n,e1);
            el_free(e1);
            break;

        case OPnegass:
            n.Eoper = OPneg;
            break;

        case OPbtc:
        case OPbtr:
        case OPbts:
            n.Eoper = OPbt;
            break;

        case OPcmpxchg:
            n.Eoper = OPcomma;
            n.EV.E2.Eoper = OPcomma;
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

@trusted
private uint numasg(elem *e)
{
    assert(e);
    if (OTassign(e.Eoper) && e.EV.E1.Eoper == OPvar)
    {
        e.Nflags |= NFLassign;
        return 1 + numasg(e.EV.E1) + (OTbinary(e.Eoper) ? numasg(e.EV.E2) : 0);
    }
    e.Nflags &= ~NFLassign;
    return OTunary(e.Eoper) ? numasg(e.EV.E1) :
           OTbinary(e.Eoper) ? numasg(e.EV.E1) + numasg(e.EV.E2) : 0;
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

@trusted
private void accumda(elem *n,vec_t DEAD, vec_t POSS)
{
  LtailRecurse:
    assert(n && DEAD && POSS);
    const op = n.Eoper;
    switch (op)
    {
        case OPcolon:
        case OPcolon2:
        {
            vec_t Pl = vec_clone(POSS);
            vec_t Pr = vec_clone(POSS);
            vec_t Dl = vec_calloc(vec_numbits(POSS));
            vec_t Dr = vec_calloc(vec_numbits(POSS));
            accumda(n.EV.E1,Dl,Pl);
            accumda(n.EV.E2,Dr,Pr);

            /* D |= P & (Dl & Dr) | ~P & (Dl | Dr)  */
            /* P = P & (Pl & Pr) | ~P & (Pl | Pr)   */
            /*   = Pl & Pr | ~P & (Pl | Pr)         */
            const vecdim = cast(uint)vec_dim(DEAD);
            for (uint i = 0; i < vecdim; i++)
            {
                DEAD[i] |= (POSS[i] & Dl[i] & Dr[i]) |
                           (~POSS[i] & (Dl[i] | Dr[i]));
                POSS[i] = (Pl[i] & Pr[i]) | (~POSS[i] & (Pl[i] | Pr[i]));
            }
            vec_free(Pl); vec_free(Pr); vec_free(Dl); vec_free(Dr);
            break;
        }

        case OPandand:
        case OPoror:
        {
            accumda(n.EV.E1,DEAD,POSS);
            // Substituting into the above equations Pl=P and Dl=0:
            // D |= Dr - P
            // P = Pr
            vec_t Pr = vec_clone(POSS);
            vec_t Dr = vec_calloc(vec_numbits(POSS));
            accumda(n.EV.E2,Dr,Pr);
            vec_subass(Dr,POSS);
            vec_orass(DEAD,Dr);
            vec_copy(POSS,Pr);
            vec_free(Pr); vec_free(Dr);
            break;
        }

        case OPvar:
        {
            Symbol *v = n.EV.Vsym;
            targ_size_t voff = n.EV.Voffset;
            uint vsize = tysize(n.Ety);

            // We have a reference. Clear all bits in POSS that
            // could be referenced.

            foreach (const i; 0 .. cast(uint)assnod.length)
            {
                elem *ti = assnod[i].EV.E1;
                if (v == ti.EV.Vsym &&
                    ((vsize == -1 || tysize(ti.Ety) == -1) ||
                     // If symbol references overlap
                     (voff + vsize > ti.EV.Voffset &&
                      ti.EV.Voffset + tysize(ti.Ety) > voff)
                    )
                   )
                {
                    vec_clearbit(i,POSS);
                }
            }
            break;
        }

        case OPasm:         // reference everything
            foreach (const i; 0 .. cast(uint)assnod.length)
                vec_clearbit(i,POSS);
            break;

        case OPbt:
            accumda(n.EV.E1,DEAD,POSS);
            accumda(n.EV.E2,DEAD,POSS);
            vec_subass(POSS,ambigref);      // remove possibly refed
            break;

        case OPind:
        case OPucall:
        case OPucallns:
        case OPvp_fp:
            accumda(n.EV.E1,DEAD,POSS);
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
            accumda(n.EV.E2,DEAD,POSS);
            goto case OPstrlen;

        case OPstrlen:
            accumda(n.EV.E1,DEAD,POSS);
            vec_subass(POSS,ambigref);      // remove possibly refed
                                            // assignments from list
                                            // of possibly dead ones
            break;

        case OPstrcat:
        case OPstrcmp:
        case OPmemcmp:
            accumda(n.EV.E1,DEAD,POSS);
            accumda(n.EV.E2,DEAD,POSS);
            vec_subass(POSS,ambigref);      // remove possibly refed
                                            // assignments from list
                                            // of possibly dead ones
            break;

        default:
            if (OTassign(op))
            {
                elem *t;

                if (ERTOL(n))
                    accumda(n.EV.E2,DEAD,POSS);
                t = n.EV.E1;
                // if not (v = expression) then gen refs of left tree
                if (op != OPeq && op != OPstreq)
                    accumda(n.EV.E1,DEAD,POSS);
                else if (OTunary(t.Eoper))         // if (*e = expression)
                    accumda(t.EV.E1,DEAD,POSS);
                else if (OTbinary(t.Eoper))
                {
                    accumda(t.EV.E1,DEAD,POSS);
                    accumda(t.EV.E2,DEAD,POSS);
                }
                if (!ERTOL(n) && op != OPnegass)
                    accumda(n.EV.E2,DEAD,POSS);

                // if unambiguous assignment, post all possibilities
                // to DEAD
                if ((op == OPeq || op == OPstreq) && t.Eoper == OPvar)
                {
                    uint tsz = tysize(t.Ety);
                    if (n.Eoper == OPstreq)
                        tsz = cast(uint)type_size(n.ET);
                    foreach (const i; 0 .. cast(uint)assnod.length)
                    {
                        elem *ti = assnod[i].EV.E1;

                        uint tisz = tysize(ti.Ety);
                        if (assnod[i].Eoper == OPstreq)
                            tisz = cast(uint)type_size(assnod[i].ET);

                        // There may be some problem with this next
                        // statement with unions.
                        if (ti.EV.Vsym == t.EV.Vsym &&
                            ti.EV.Voffset == t.EV.Voffset &&
                            tisz == tsz &&
                            !(t.Ety & (mTYvolatile | mTYshared)) &&
                            //t.EV.Vsym.Sflags & SFLunambig &&
                            vec_testbit(i,POSS))
                        {
                            vec_setbit(i,DEAD);
                        }
                    }
                }

                // if assignment operator, post this def to POSS
                if (n.Nflags & NFLassign)
                {
                    const i = cast(uint)assnod.length;
                    vec_setbit(i,POSS);

                    // if variable could be referenced by a pointer
                    // or a function call, mark the assignment in
                    // ambigref
                    if (!(t.EV.Vsym.Sflags & SFLunambig))
                    {
                        vec_setbit(i,ambigref);

                        debug if (debugc)
                        {
                            printf("ambiguous lvalue: ");
                            WReqn(n);
                            printf("\n");
                        }
                    }

                    assnod.push(n);
                }
            }
            else if (OTrtol(op))
            {
                accumda(n.EV.E2,DEAD,POSS);
                n = n.EV.E1;
                goto LtailRecurse;              //  accumda(n.EV.E1,DEAD,POSS);
            }
            else if (OTbinary(op))
            {
                accumda(n.EV.E1,DEAD,POSS);
                n = n.EV.E2;
                goto LtailRecurse;              //  accumda(n.EV.E2,DEAD,POSS);
            }
            else if (OTunary(op))
            {
                n = n.EV.E1;
                goto LtailRecurse;              //  accumda(n.EV.E1,DEAD,POSS);
            }
            break;
    }
}


/***************************
 * Mark all dead variables. Only worry about register candidates.
 * Compute live ranges for register candidates.
 * Be careful not to compute live ranges for members of structures (CLMOS).
 */
@trusted
void deadvar()
{
        assert(dfo);

        /* First, mark each candidate as dead.  */
        /* Initialize vectors for live ranges.  */
        for (SYMIDX i = 0; i < globsym.length; i++)
        {
            Symbol *s = globsym[i];

            if (s.Sflags & SFLunambig)
            {
                s.Sflags |= SFLdead;
                if (s.Sflags & GTregcand)
                {
                    s.Srange = vec_realloc(s.Srange, dfo.length);
                    vec_clear(s.Srange);
                }
            }
        }

        /* Go through trees and "liven" each one we see.        */
        foreach (i, b; dfo[])
            if (b.Belem)
                dvwalk(b.Belem,cast(uint)i);

        /* Compute live variables. Set bit for block in live range      */
        /* if variable is in the IN set for that block.                 */
        flowlv();                       /* compute live variables       */
        for (SYMIDX i = 0; i < globsym.length; i++)
        {
            if (globsym[i].Srange /*&& globsym[i].Sclass != CLMOS*/)
                foreach (j, b; dfo[])
                    if (vec_testbit(i,b.Binlv))
                        vec_setbit(cast(uint)j,globsym[i].Srange);
        }

        /* Print results        */
        for (SYMIDX i = 0; i < globsym.length; i++)
        {
            char *p;
            Symbol *s = globsym[i];

            if (s.Sflags & SFLdead && s.Sclass != SCparameter && s.Sclass != SCregpar)
                s.Sflags &= ~GTregcand;    // do not put dead variables in registers
            debug
            {
                p = cast(char *) s.Sident.ptr ;
                if (s.Sflags & SFLdead)
                    if (debugc) printf("Symbol %d '%s' is dead\n",cast(int) i,p);
                if (debugc && s.Srange /*&& s.Sclass != CLMOS*/)
                {
                    printf("Live range for %d '%s': ",cast(int) i,p);
                    vec_println(s.Srange);
                }
            }
        }
}


/*****************************
 * Tree walk support routine for deadvar().
 * Input:
 *      n = elem to look at
 *      i = block index
 */
@trusted
private void dvwalk(elem *n,uint i)
{
    for (; true; n = n.EV.E1)
    {
        assert(n);
        if (n.Eoper == OPvar || n.Eoper == OPrelconst)
        {
            Symbol *s = n.EV.Vsym;

            s.Sflags &= ~SFLdead;
            if (s.Srange)
                vec_setbit(i,s.Srange);
        }
        else if (!OTleaf(n.Eoper))
        {
            if (OTbinary(n.Eoper))
                dvwalk(n.EV.E2,i);
            continue;
        }
        break;
    }
}

/*********************************
 * Optimize very busy expressions (VBEs).
 */

private __gshared vec_t blockseen; /* which blocks we have visited         */

@trusted
void verybusyexp()
{
    elem **pn;
    uint j,l;

    if (debugc) printf("verybusyexp()\n");
    flowvbe();                      /* compute VBEs                 */
    if (go.exptop <= 1) return;        /* if no VBEs                   */
    assert(go.expblk.length);
    if (blockinit())
        return;                     // can't handle ASM blocks
    compdom();                      /* compute dominators           */
    /*setvecdim(go.exptop);*/
    genkillae();                    /* compute Bgen and Bkill for   */
                                    /* AEs                          */
    /*chkvecdim(go.exptop,0);*/
    blockseen = vec_calloc(dfo.length);

    /* Go backwards through dfo so that VBEs are evaluated as       */
    /* close as possible to where they are used.                    */
    foreach_reverse (i, b; dfo[])     // for each block
    {
        int done;

        /* Do not hoist things to blocks that do not            */
        /* divide the flow of control.                          */

        switch (b.BC)
        {
            case BCiftrue:
            case BCswitch:
                break;

            default:
                continue;
        }

        /* Find pointer to last statement in current elem */
        pn = &(b.Belem);
        if (*pn)
        {
            while ((*pn).Eoper == OPcomma)
                pn = &((*pn).EV.E2);
            /* If last statement has side effects,  */
            /* don't do these VBEs. Potentially we  */
            /* could by assigning the result to     */
            /* a temporary, and rewriting the tree  */
            /* from (n) to (T=n,T) and installing   */
            /* the VBE as (T=n,VBE,T). This         */
            /* may not buy us very much, so we will */
            /* just skip it for now.                */
            /*if (sideeffect(*pn))*/
            if (!(*pn).Eexp)
                continue;
        }

        /* Eliminate all elems that have already been           */
        /* hoisted (indicated by go.expnod[] == 0).                */
        /* Constants are not useful as VBEs.                    */
        /* Eliminate all elems from Bout that are not in blocks */
        /* that are dominated by b.                             */
        static if (0)
        {
            printf("block %d Bout = ",i);
            vec_println(b.Bout);
        }
        done = true;
        for (j = 0; (j = cast(uint) vec_index(j, b.Bout)) < go.exptop; ++j)
        {
            if (go.expnod[j] == null ||
                !!OTleaf(go.expnod[j].Eoper) ||
                !dom(b,go.expblk[j]))
                vec_clearbit(j,b.Bout);
            else
                done = false;
        }
        if (done) continue;

        /* Eliminate from Bout all elems that are killed by     */
        /* a block between b and that elem.                     */
        static if (0)
        {
            printf("block %d Bout = ",i);
            vec_println(b.Bout);
        }
        for (j = 0; (j = cast(uint) vec_index(j, b.Bout)) < go.exptop; ++j)
        {
            vec_clear(blockseen);
            foreach (bl; ListRange(go.expblk[j].Bpred))
            {
                if (killed(j,list_block(bl),b))
                {
                    vec_clearbit(j,b.Bout);
                    break;
                }
            }
        }

        /* For each elem still left, make sure that there       */
        /* exists a path from b to j along which there is       */
        /* no other use of j (else it would be a CSE, and       */
        /* it would be a waste of time to hoist it).            */
        static if (0)
        {
            printf("block %d Bout = ",i);
            vec_println(b.Bout);
        }

        for (j = 0; (j = cast(uint) vec_index(j, b.Bout)) < go.exptop; ++j)
        {
            vec_clear(blockseen);
            foreach (bl; ListRange(go.expblk[j].Bpred))
            {
                if (ispath(j,list_block(bl),b))
                    goto L2;
            }
            vec_clearbit(j,b.Bout);        /* thar ain't no path   */
        L2:
        }


        /* For each elem that appears more than once in Bout    */
        /*      We have a VBE.                                  */
        static if (0)
        {
            printf("block %d Bout = ",i);
            vec_println(b.Bout);
        }

        for (j = 0; (j = cast(uint) vec_index(j, b.Bout)) < go.exptop; ++j)
        {
            uint k;
            for (k = j + 1; k < go.exptop; k++)
            {   if (vec_testbit(k,b.Bout) &&
                        el_match(go.expnod[j],go.expnod[k]))
                            goto foundvbe;
            }
            continue;               /* no VBE here          */

        foundvbe:                   /* we got one           */
            debug
            {
                if (debugc)
                {   printf("VBE %d,%d, block %d (",j,k, cast(int) i);
                    WReqn(go.expnod[j]);
                    printf(");\n");
                }
            }
            *pn = el_bin(OPcomma,(*pn).Ety,
                         el_copytree(go.expnod[j]),*pn);

            /* Mark all the vbe elems found but one (the    */
            /* go.expnod[j] one) so that the expression will   */
            /* only be hoisted again if other occurrences   */
            /* of the expression are found later. This      */
            /* will substitute for the fact that the        */
            /* el_copytree() expression does not appear in go.expnod[]. */
            l = k;
            do
            {
                if (k == l || (vec_testbit(k,b.Bout) &&
                    el_match(go.expnod[j],go.expnod[k])))
                {
                    /* Fix so nobody else will      */
                    /* vbe this elem                */
                    go.expnod[k] = null;
                    vec_clearbit(k,b.Bout);
                }
            } while (++k < go.exptop);
            go.changes++;
        } /* foreach */
    } /* for */
    vec_free(blockseen);
}

/****************************
 * Return true if elem j is killed somewhere
 * between b and bp.
 */

@trusted
private int killed(uint j,block *bp,block *b)
{
    if (bp == b || vec_testbit(bp.Bdfoidx,blockseen))
        return false;
    if (vec_testbit(j,bp.Bkill))
        return true;
    vec_setbit(bp.Bdfoidx,blockseen);      /* mark as visited              */
    foreach (bl; ListRange(bp.Bpred))
        if (killed(j,list_block(bl),b))
            return true;
    return false;
}

/***************************
 * Return true if there is a path from b to bp along which
 * elem j is not used.
 * Input:
 *      b .    block where we want to put the VBE
 *      bp .   block somewhere between b and block containing j
 *      j =     VBE expression elem candidate (index into go.expnod[])
 */

@trusted
private int ispath(uint j,block *bp,block *b)
{
    /*chkvecdim(go.exptop,0);*/
    if (bp == b) return true;              /* the trivial case             */
    if (vec_testbit(bp.Bdfoidx,blockseen))
        return false;                      /* already seen this block      */
    vec_setbit(bp.Bdfoidx,blockseen);      /* we've visited this block     */

    /* false if elem j is used in block bp (and reaches the end     */
    /* of bp, indicated by it being an AE in Bgen)                  */
    uint i;
    for (i = 0; (i = cast(uint) vec_index(i, bp.Bgen)) < go.exptop; ++i) // look thru used expressions
    {
        if (i != j && go.expnod[i] && el_match(go.expnod[i],go.expnod[j]))
            return false;
    }

    /* Not used in bp, see if there is a path through a predecessor */
    /* of bp                                                        */
    foreach (bl; ListRange(bp.Bpred))
        if (ispath(j,list_block(bl),b))
            return true;

    return false;           /* j is used along all paths            */
}

}
