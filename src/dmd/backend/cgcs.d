/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Compute common subexpressions for non-optimized builds.
 *
 * Copyright:   Copyright (C) 1985-1995 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      https://github.com/dlang/dmd/blob/master/src/dmd/backend/cgcs.d
 * Coverage:    https://codecov.io/gh/dlang/dmd/src/master/src/dmd/backend/cgcs.d
 */

module dmd.backend.cgcs;

version (SPP)
{
}
else
{

import core.stdc.stdio;
import core.stdc.stdlib;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.code;
import dmd.backend.el;
import dmd.backend.global;
import dmd.backend.oper;
import dmd.backend.ty;
import dmd.backend.type;

import dmd.backend.barray;
import dmd.backend.dlist;
import dmd.backend.dvec;


nothrow:
@safe:

/*******************************
 * Do common subexpression elimination for non-optimized builds.
 */

@trusted
public extern (C++) void comsubs()
{
    debug if (debugx) printf("comsubs(%p)\n",startblock);

    version (SCPP)
    {
        if (errcnt)
            return;
    }

    comsubs2(startblock, cgcsdata);

    debug if (debugx)
        printf("done with comsubs()\n");
}

/*******************************
 */

@trusted
public extern (C++) void cgcs_term()
{
    cgcsdata.term();
    debug debugw && printf("cgcs_term()\n");
}


/***********************************************************************/

private:

alias hash_t = uint;    // for hash values

/*******************************
 * Eliminate common subexpressions across extended basic blocks.
 * String together as many blocks as we can.
 */
@trusted
void comsubs2(block* startblock, ref CGCS cgcs)
{
    // No longer just compute Bcount - eliminate unreachable blocks too
    block_compbcount();                   // eliminate unreachable blocks

    cgcs.start();

    block* bln;
    for (block* bl = startblock; bl; bl = bln)
    {
        bln = bl.Bnext;
        if (!bl.Belem)
            continue;                   /* if no expression or no parents       */

        // Count up n, the number of blocks in this extended basic block (EBB)
        int n = 1;                      // always at least one block in EBB
        auto blc = bl;
        while (bln && list_nitems(bln.Bpred) == 1 &&
               ((blc.BC == BCiftrue &&
                 blc.nthSucc(1) == bln) ||
                (blc.BC == BCgoto && blc.nthSucc(0) == bln)
               ) &&
               bln.BC != BCasm         // no CSE's extending across ASM blocks
              )
        {
            n++;                    // add block to EBB
            blc = bln;
            bln = blc.Bnext;
        }

        cgcs.reset();

        bln = bl;
        while (n--)                     // while more blocks in EBB
        {
            debug if (debugx)
                printf("cses for block %p\n",bln);

            if (bln.Belem)
                ecom(cgcs, bln.Belem);  // do the tree
            bln = bln.Bnext;
        }
    }
}


/*********************************
 * Struct for each potential CSE
 */

struct HCS
{
    elem* Helem;        /// pointer to elem
    hash_t Hhash;       /// hash value for the elem
}

struct HCSArray
{
    size_t touchstari;
    size_t[2] touchfunci;
}

/**************************************
 * All the global data for this module
 */
struct CGCS
{
    Barray!HCS hcstab;           // array of hcs's
    HCSArray hcsarray;

    // Use a bit vector for quick check if expression is possibly in hcstab[].
    // This results in much faster compiles when hcstab[] gets big.
    vec_t csvec;                 // vector of used entries
    enum CSVECDIM = 16_001; //8009 //3001     // dimension of csvec (should be prime)

  nothrow:

    /*********************************
     * Initialize for this iteration.
     */
    void start()
    {
        if (!csvec)
        {
            csvec = vec_calloc(CGCS.CSVECDIM);
        }
    }

    /*******************************
     * Reset for next time.
     * hcstab[]'s storage is kept instead of reallocated.
     */
    void reset()
    {
        vec_clear(csvec);       // don't free it, recycle storage
        hcstab.reset();
        hcsarray = HCSArray.init;
    }

    /*********************************
     * All done for this compiler instance.
     */
    void term()
    {
        vec_free(csvec);
        csvec = null;
        //hcstab.dtor();  // cache allocation for next iteration
    }

    /****************************
     * Add an elem to the common subexpression table.
     */

    void push(elem *e, hash_t hash)
    {
        hcstab.push(HCS(e, hash));
    }

    /*******************************
     * Eliminate all common subexpressions.
     */

    void touchall()
    {
        foreach (ref hcs; hcstab[])
        {
            hcs.Helem = null;
        }
        const len = hcstab.length;
        hcsarray.touchstari    = len;
        hcsarray.touchfunci[0] = len;
        hcsarray.touchfunci[1] = len;
    }
}

__gshared CGCS cgcsdata;

/*************************
 * Eliminate common subexpressions for an element.
 * Params:
 *      cgcs = cgcsdata
 *      pe = elem that is changed to previous elem if it's a CSE
 */
@trusted
void ecom(ref CGCS cgcs, ref elem* pe)
{
    auto e = pe;
    assert(e);
    elem_debug(e);
    debug assert(e.Ecount == 0);
    //assert(e.Ecomsub == 0);
    const tym = tybasic(e.Ety);
    const op = e.Eoper;
    switch (op)
    {
        case OPconst:
        case OPrelconst:
            break;

        case OPvar:
            if (e.EV.Vsym.ty() & mTYshared)
                return;         // don't cache shared variables
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
            /* Reverse order of evaluation for double op=. This is so that  */
            /* the pushing of the address of the second operand is easier.  */
            /* However, with the 8087 we don't need the kludge.             */
            if (op != OPeq && tym == TYdouble && !config.inline8087)
            {
                if (!OTleaf(e.EV.E1.Eoper))
                    ecom(cgcs, e.EV.E1.EV.E1);
                ecom(cgcs, e.EV.E2);
            }
            else
            {
                /* Don't mark the increment of an i++ or i-- as a CSE, if it */
                /* can be done with an INC or DEC instruction.               */
                if (!(OTpost(op) && elemisone(e.EV.E2)))
                    ecom(cgcs, e.EV.E2);           /* evaluate 2nd operand first   */
        case OPnegass:
                if (!OTleaf(e.EV.E1.Eoper))             /* if lvalue is an operator     */
                {
                    if (e.EV.E1.Eoper != OPind)
                        elem_print(e);
                    assert(e.EV.E1.Eoper == OPind);
                    ecom(cgcs, e.EV.E1.EV.E1);
                }
            }
            touchlvalue(cgcs, e.EV.E1);
            if (!OTpost(op))                /* lvalue of i++ or i-- is not a cse*/
            {
                const hash = cs_comphash(e.EV.E1);
                vec_setbit(hash % CGCS.CSVECDIM,cgcs.csvec);
                cgcs.push(e.EV.E1,hash);              // add lvalue to cgcs.hcstab[]
            }
            return;

        case OPbtc:
        case OPbts:
        case OPbtr:
        case OPcmpxchg:
            ecom(cgcs, e.EV.E1);
            ecom(cgcs, e.EV.E2);
            touchfunc(cgcs, 0);                   // indirect assignment
            return;

        case OPandand:
        case OPoror:
        {
            ecom(cgcs, e.EV.E1);
            const lengthSave = cgcs.hcstab.length;
            auto hcsarraySave = cgcs.hcsarray;
            ecom(cgcs, e.EV.E2);
            cgcs.hcsarray = hcsarraySave;        // no common subs by E2
            cgcs.hcstab.setLength(lengthSave);
            return;                         /* if comsub then logexp() will */
        }

        case OPcond:
        {
            ecom(cgcs, e.EV.E1);
            const lengthSave = cgcs.hcstab.length;
            auto hcsarraySave = cgcs.hcsarray;
            ecom(cgcs, e.EV.E2.EV.E1);               // left condition
            cgcs.hcsarray = hcsarraySave;        // no common subs by E2
            cgcs.hcstab.setLength(lengthSave);
            ecom(cgcs, e.EV.E2.EV.E2);               // right condition
            cgcs.hcsarray = hcsarraySave;        // no common subs by E2
            cgcs.hcstab.setLength(lengthSave);
            return;                         // can't be a common sub
        }

        case OPcall:
        case OPcallns:
            ecom(cgcs, e.EV.E2);                   /* eval right first             */
            goto case OPucall;

        case OPucall:
        case OPucallns:
            ecom(cgcs, e.EV.E1);
            touchfunc(cgcs, 1);
            return;

        case OPstrpar:                      /* so we don't break logexp()   */
        case OPinp:                 /* never CSE the I/O instruction itself */
        case OPprefetch:            // don't CSE E2 or the instruction
            ecom(cgcs, e.EV.E1);
            goto case OPasm;

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
            cgcs.touchall();
            ecom(cgcs, e.EV.E1);
            cgcs.touchall();
            return;

        case OPparam:
        case OPoutp:
            ecom(cgcs, e.EV.E1);
            goto case OPinfo;

        case OPinfo:
            ecom(cgcs, e.EV.E2);
            return;

        case OPcomma:
            ecom(cgcs, e.EV.E1);
            ecom(cgcs, e.EV.E2);
            return;

        case OPremquo:
            ecom(cgcs, e.EV.E1);
            ecom(cgcs, e.EV.E2);
            break;

        case OPvp_fp:
        case OPcvp_fp:
            ecom(cgcs, e.EV.E1);
            touchaccess(cgcs.hcstab, e);
            break;

        case OPind:
            ecom(cgcs, e.EV.E1);
            /* Generally, CSEing a *(double *) results in worse code        */
            if (tyfloating(tym))
                return;
            if (tybasic(e.EV.E1.Ety) == TYsharePtr)
                return;
            break;

        case OPstrcpy:
        case OPstrcat:
        case OPmemcpy:
        case OPmemset:
            ecom(cgcs, e.EV.E2);
            goto case OPsetjmp;

        case OPsetjmp:
            ecom(cgcs, e.EV.E1);
            touchfunc(cgcs, 0);
            return;

        default:                            /* other operators */
            if (!OTbinary(e.Eoper))
               WROP(e.Eoper);
            assert(OTbinary(e.Eoper));
            goto case OPadd;

        case OPadd:
        case OPmin:
        case OPmul:
        case OPdiv:
        case OPor:
        case OPxor:
        case OPand:
        case OPeqeq:
        case OPne:
        case OPscale:
        case OPyl2x:
        case OPyl2xp1:
            ecom(cgcs, e.EV.E1);
            ecom(cgcs, e.EV.E2);
            break;

        case OPstring:
        case OPaddr:
        case OPbit:
            WROP(e.Eoper);
            elem_print(e);
            assert(0);              /* optelem() should have removed these  */

        // Explicitly list all the unary ops for speed
        case OPnot: case OPcom: case OPneg: case OPuadd:
        case OPabs: case OPrndtol: case OPrint:
        case OPpreinc: case OPpredec:
        case OPbool: case OPstrlen: case OPs16_32: case OPu16_32:
        case OPs32_d: case OPu32_d: case OPd_s16: case OPs16_d: case OP32_16:
        case OPf_d:
        case OPld_d:
        case OPc_r: case OPc_i:
        case OPu8_16: case OPs8_16: case OP16_8:
        case OPu32_64: case OPs32_64: case OP64_32: case OPmsw:
        case OPu64_128: case OPs64_128: case OP128_64:
        case OPs64_d: case OPd_u64: case OPu64_d:
        case OPstrctor: case OPu16_d: case OPd_u16:
        case OParrow:
        case OPvoid:
        case OPbsf: case OPbsr: case OPbswap: case OPpopcnt: case OPvector:
        case OPld_u64:
        case OPsqrt: case OPsin: case OPcos:
        case OPoffset: case OPnp_fp: case OPnp_f16p: case OPf16p_np:
        case OPvecfill: case OPtoprec:
            ecom(cgcs, e.EV.E1);
            break;

        case OPd_ld:
            return;

        case OPd_f:
        {
            const op1 = e.EV.E1.Eoper;
            if (config.fpxmmregs &&
                (op1 == OPs32_d ||
                 I64 && (op1 == OPs64_d || op1 == OPu32_d))
               )
                ecom(cgcs, e.EV.E1.EV.E1);   // e and e1 ops are fused (see xmmcnvt())
            else
                ecom(cgcs, e.EV.E1);
            break;
        }

        case OPd_s32:
        case OPd_u32:
        case OPd_s64:
            if (e.EV.E1.Eoper == OPf_d && config.fpxmmregs)
                ecom(cgcs, e.EV.E1.EV.E1);   // e and e1 ops are fused (see xmmcnvt());
            else
                ecom(cgcs, e.EV.E1);
            break;

        case OPhalt:
            return;
    }

    /* don't CSE structures or unions or volatile stuff   */
    if (tym == TYstruct ||
        tym == TYvoid ||
        e.Ety & mTYvolatile)
        return;
    if (tyfloating(tym) && config.inline8087)
    {
        /* can CSE XMM code, but not x87
         */
        if (!(config.fpxmmregs && tyxmmreg(tym)))
            return;
    }

    const hash = cs_comphash(e);                /* must be AFTER leaves are done */

    /* Search for a match in hcstab[].
     * Search backwards, as most likely matches will be towards the end
     * of the list.
     */

    debug if (debugx) printf("elem: %p hash: %6d\n",e,hash);
    int csveci = hash % CGCS.CSVECDIM;
    if (vec_testbit(csveci,cgcs.csvec))
    {
        foreach_reverse (i, ref hcs; cgcs.hcstab[])
        {
            debug if (debugx)
                printf("i: %2d Hhash: %6d Helem: %p\n",
                       cast(int) i,hcs.Hhash,hcs.Helem);

            elem* ehash;
            if (hash == hcs.Hhash && (ehash = hcs.Helem) != null)
            {
                /* if elems are the same and we still have room for more    */
                if (el_match(e,ehash) && ehash.Ecount < 0xFF)
                {
                    /* Make sure leaves are also common subexpressions
                     * to avoid false matches.
                     */
                    if (!OTleaf(op))
                    {
                        if (!e.EV.E1.Ecount)
                            continue;
                        if (OTbinary(op) && !e.EV.E2.Ecount)
                            continue;
                    }
                    ehash.Ecount++;
                    pe = ehash;

                    debug if (debugx)
                        printf("**MATCH** %p with %p\n",e,pe);

                    el_free(e);
                    return;
                }
            }
        }
    }
    else
        vec_setbit(csveci,cgcs.csvec);
    cgcs.push(e,hash);                    // add this elem to hcstab[]
}

/**************************
 * Compute hash function for elem e.
 */

@trusted
hash_t cs_comphash(const elem *e)
{
    elem_debug(e);
    const op = e.Eoper;
    hash_t hash = (e.Ety & (mTYbasic | mTYconst | mTYvolatile)) + (op << 8);
    if (!OTleaf(op))
    {
        hash += cast(hash_t) e.EV.E1;
        if (OTbinary(op))
            hash += cast(hash_t) e.EV.E2;
    }
    else
    {
        hash += e.EV.Vint;
        if (op == OPvar || op == OPrelconst)
            hash += cast(hash_t) e.EV.Vsym;
    }
    return hash;
}

/***************************
 * "touch" the elem.
 * If it is a pointer, "touch" all the suspects
 * who could be pointed to.
 * Eliminate common subs that are indirect loads.
 */

@trusted
void touchlvalue(ref CGCS cgcs, const elem* e)
{
    if (e.Eoper == OPind)                /* if indirect store            */
    {
        /* NOTE: Some types of array assignments do not need
         * to touch all variables. (Like a[5], where a is an
         * array instead of a pointer.)
         */

        touchfunc(cgcs, 0);
        return;
    }

    foreach_reverse (ref hcs; cgcs.hcstab[])
    {
        if (hcs.Helem &&
            hcs.Helem.EV.Vsym == e.EV.Vsym)
            hcs.Helem = null;
    }

    if (!(e.Eoper == OPvar || e.Eoper == OPrelconst))
    {
        elem_print(e);
        assert(0);
    }
    switch (e.EV.Vsym.Sclass)
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
            if (e.EV.Vsym.Sflags & SFLunambig)
                break;
            goto case SCstatic;

        case SCstatic:
        case SCextern:
        case SCglobal:
        case SClocstat:
        case SCcomdat:
        case SCinline:
        case SCsinline:
        case SCeinline:
        case SCcomdef:
            touchstar(cgcs);
            break;

        default:
            elem_print(e);
            symbol_print(e.EV.Vsym);
            assert(0);
    }
}

/**************************
 * "touch" variables that could be changed by a function call or
 * an indirect assignment.
 * Eliminate any subexpressions that are "starred" (they need to
 * be recomputed).
 * Params:
 *      flag =  If 1, then this is a function call.
 *              If 0, then this is an indirect assignment.
 */

@trusted
void touchfunc(ref CGCS cgcs, int flag)
{

    //printf("touchfunc(%d)\n", flag);
    //pe = &cgcs.hcstab[0]; printf("pe = %p, petop = %p\n",pe,petop);
    assert(cgcs.hcsarray.touchfunci[flag] <= cgcs.hcstab.length);

    foreach (ref pe; cgcs.hcstab[cgcs.hcsarray.touchfunci[flag] .. cgcs.hcstab.length])
    {
        const he = pe.Helem;
        if (!he)
            continue;
        switch (he.Eoper)
        {
            case OPvar:
                if (Symbol_isAffected(*he.EV.Vsym))
                {
                    pe.Helem = null;
                    continue;
                }
                break;

            case OPind:
                if (tybasic(he.EV.E1.Ety) == TYimmutPtr)
                    break;
                goto Ltouch;

            case OPstrlen:
            case OPstrcmp:
            case OPmemcmp:
            case OPbt:
                goto Ltouch;

            case OPvp_fp:
            case OPcvp_fp:
                if (flag == 0)          /* function calls destroy vptrfptr's, */
                    break;              /* not indirect assignments     */
            Ltouch:
                pe.Helem = null;
                break;

            default:
                break;
        }
    }
    cgcs.hcsarray.touchfunci[flag] = cgcs.hcstab.length;
}


/*******************************
 * Eliminate all common subexpressions that
 * do any indirection ("starred" elems).
 */

@trusted
void touchstar(ref CGCS cgcs)
{
    foreach (ref hcs; cgcs.hcstab[cgcs.hcsarray.touchstari .. $])
    {
        const e = hcs.Helem;
        if (e &&
               (e.Eoper == OPind && tybasic(e.EV.E1.Ety) != TYimmutPtr ||
                e.Eoper == OPbt) )
            hcs.Helem = null;
    }
    cgcs.hcsarray.touchstari = cgcs.hcstab.length;
}

/*****************************************
 * Eliminate any common subexpressions that could be modified
 * if a handle pointer access occurs.
 */

@trusted
void touchaccess(ref Barray!HCS hcstab, const elem *ev) pure nothrow
{
    const ev1 = ev.EV.E1;
    foreach (ref hcs; hcstab[])
    {
        const e = hcs.Helem;
        /* Invalidate any previous handle pointer accesses that */
        /* are not accesses of ev.                              */
        if (e && (e.Eoper == OPvp_fp || e.Eoper == OPcvp_fp) && e.EV.E1 != ev1)
            hcs.Helem = null;
    }
}

}
