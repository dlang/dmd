// Copyright (C) 1984-1998 by Symantec
// Copyright (C) 2000-2012 by Digital Mars
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

#include        "cc.h"
#include        "oper.h"
#include        "global.h"
#include        "type.h"
#include        "filespec.h"
#include        "code.h"
#include        "cgcv.h"
#include        "go.h"
#include        "dt.h"
#if SCPP
#include        "parser.h"
#include        "cpp.h"
#include        "el.h"
#include        "code.h"
#endif

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

static  int addrparam;  /* see if any parameters get their address taken */

#if SCPP

/**********************************
 * We put out an external definition.
 */
void out_extdef(symbol *s)
{
    pstate.STflags |= PFLextdef;
    if (//config.flags2 & CFG2phgen ||
        (config.flags2 & (CFG2phauto | CFG2phautoy) &&
            !(pstate.STflags & (PFLhxwrote | PFLhxdone)))
       )

        synerr(EM_data_in_pch,prettyident(s));          // data or code in precompiled header
}

/********************************
 * Put out code segment name record.
 */
void outcsegname(char *csegname)
{
    Obj::codeseg(csegname,0);
}

/***********************************
 * Output function thunk.
 */
void outthunk(symbol *sthunk,symbol *sfunc,unsigned p,tym_t thisty,
        targ_size_t d,int i,targ_size_t d2)
{
    cod3_thunk(sthunk,sfunc,p,thisty,d,i,d2);
    sthunk->Sfunc->Fflags &= ~Fpending;
    sthunk->Sfunc->Fflags |= Foutput;   /* mark it as having been output */
}

#endif

/***************************
 * Write out statically allocated data.
 * Input:
 *      s               symbol to be initialized
 */

void outdata(symbol *s)
{
#if HTOD
    return;
#endif
    targ_size_t datasize,a;
    int seg;
    targ_size_t offset;
    int flags;
    tym_t ty;

    symbol_debug(s);
#ifdef DEBUG
    debugy && dbg_printf("outdata('%s')\n",s->Sident);
#endif
    //printf("outdata('%s', ty=x%x)\n",s->Sident,s->Stype->Tty);
    //symbol_print(s);

    // Data segment variables are always live on exit from a function
    s->Sflags |= SFLlivexit;

    dt_t *dtstart = s->Sdt;
    s->Sdt = NULL;                      // it will be free'd
#if SCPP && TARGET_WINDOS
    if (eecontext.EEcompile)
    {   s->Sfl = (s->ty() & mTYfar) ? FLfardata : FLextern;
        s->Sseg = UNKNOWN;
        goto Lret;                      // don't output any data
    }
#endif
    datasize = 0;
    ty = s->ty();
    if (ty & mTYexport && config.wflags & WFexpdef && s->Sclass != SCstatic)
        objmod->export_symbol(s,0);        // export data definition
    for (dt_t *dt = dtstart; dt; dt = dt->DTnext)
    {
        //printf("\tdt = %p, dt = %d\n",dt,dt->dt);
        switch (dt->dt)
        {   case DT_abytes:
            {   // Put out the data for the string, and
                // reserve a spot for a pointer to that string
                datasize += size(dt->Dty);      // reserve spot for pointer to string
#if TARGET_SEGMENTED
                if (tybasic(dt->Dty) == TYcptr)
                {   dt->DTseg = cseg;
                    dt->DTabytes += Coffset;
                    goto L1;
                }
                else if (tybasic(dt->Dty) == TYfptr &&
                         dt->DTnbytes > config.threshold)
                {
                    targ_size_t foffset;
                    dt->DTseg = objmod->fardata(s->Sident,dt->DTnbytes,&foffset);
                    dt->DTabytes += foffset;
                L1:
                    objmod->write_bytes(SegData[dt->DTseg],dt->DTnbytes,dt->DTpbytes);
                    break;
                }
                else
#endif
                {
                    dt->DTabytes += objmod->data_readonly(dt->DTpbytes,dt->DTnbytes,&dt->DTseg);
                }
                break;
            }
            case DT_ibytes:
                datasize += dt->DTn;
                break;
            case DT_nbytes:
                //printf("DT_nbytes %d\n", dt->DTnbytes);
                datasize += dt->DTnbytes;
                break;
            case DT_symsize:
#if MARS
                assert(0);
#else
                dt->DTazeros = type_size(s->Stype);
#endif
                goto case_azeros;
            case DT_azeros:
                /* A block of zeros
                 */
                //printf("DT_azeros %d\n", dt->DTazeros);
            case_azeros:
                datasize += dt->DTazeros;
                if (dt == dtstart && !dt->DTnext && s->Sclass != SCcomdat)
                {   /* first and only, so put in BSS segment
                     */
                    switch (ty & mTYLINK)
                    {
#if TARGET_SEGMENTED
                        case mTYfar:                    // if far data
                            s->Sseg = objmod->fardata(s->Sident,datasize,&s->Soffset);
                            s->Sfl = FLfardata;
                            break;

                        case mTYcs:
                            s->Sseg = cseg;
                            Coffset = align(datasize,Coffset);
                            s->Soffset = Coffset;
                            Coffset += datasize;
                            s->Sfl = FLcsdata;
                            break;
#endif
                        case mTYthread:
                        {   seg_data *pseg = objmod->tlsseg_bss();
                            s->Sseg = pseg->SDseg;
                            objmod->data_start(s, datasize, pseg->SDseg);
                            if (config.objfmt == OBJ_OMF)
                                pseg->SDoffset += datasize;
                            else
                                objmod->lidata(pseg->SDseg, pseg->SDoffset, datasize);
                            s->Sfl = FLtlsdata;
                            break;
                        }
                        default:
                            s->Sseg = UDATA;
                            objmod->data_start(s,datasize,UDATA);
                            objmod->lidata(s->Sseg,s->Soffset,datasize);
                            s->Sfl = FLudata;           // uninitialized data
                            break;
                    }
                    assert(s->Sseg && s->Sseg != UNKNOWN);
                    if (s->Sclass == SCglobal || (s->Sclass == SCstatic && config.objfmt != OBJ_OMF)) // if a pubdef to be done
                        objmod->pubdefsize(s->Sseg,s,s->Soffset,datasize);   // do the definition
                    searchfixlist(s);
                    if (config.fulltypes &&
                        !(s->Sclass == SCstatic && funcsym_p)) // not local static
                        cv_outsym(s);
#if SCPP
                    out_extdef(s);
#endif
                    goto Lret;
                }
                break;
            case DT_common:
                assert(!dt->DTnext);
                outcommon(s,dt->DTazeros);
                goto Lret;

            case DT_xoff:
            {   symbol *sb = dt->DTsym;

                if (tyfunc(sb->ty()))
#if SCPP
                    nwc_mustwrite(sb);
#else
                    ;
#endif
                else if (sb->Sdt)               // if initializer for symbol
{ if (!s->Sseg) s->Sseg = DATA;
                    outdata(sb);                // write out data for symbol
}
            }
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

    if (s->Sclass == SCcomdat)          // if initialized common block
    {
        seg = objmod->comdatsize(s, datasize);
        switch (ty & mTYLINK)
        {
#if TARGET_SEGMENTED
            case mTYfar:                // if far data
                s->Sfl = FLfardata;
                break;

            case mTYcs:
                s->Sfl = FLcsdata;
                break;
#endif
            case mTYnear:
            case 0:
                s->Sfl = FLdata;        // initialized data
                break;
            case mTYthread:
                s->Sfl = FLtlsdata;
                break;

            default:
                assert(0);
        }
    }
    else
    {
      switch (ty & mTYLINK)
      {
#if TARGET_SEGMENTED
        case mTYfar:                    // if far data
            seg = objmod->fardata(s->Sident,datasize,&s->Soffset);
            s->Sfl = FLfardata;
            break;

        case mTYcs:
            seg = cseg;
            Coffset = align(datasize,Coffset);
            s->Soffset = Coffset;
            s->Sfl = FLcsdata;
            break;
#endif
        case mTYthread:
        {
            seg_data *pseg = objmod->tlsseg();
            s->Sseg = pseg->SDseg;
            objmod->data_start(s, datasize, s->Sseg);
            seg = pseg->SDseg;
            s->Sfl = FLtlsdata;
            break;
        }
        case mTYnear:
        case 0:
            if (
                s->Sseg == 0 ||
                s->Sseg == UNKNOWN)
                s->Sseg = DATA;
            seg = objmod->data_start(s,datasize,DATA);
            s->Sfl = FLdata;            // initialized data
            break;
        default:
            assert(0);
      }
    }
    if (s->Sseg == UNKNOWN && (config.objfmt == OBJ_ELF || config.objfmt == OBJ_MACH))
        s->Sseg = seg;
    else if (config.objfmt == OBJ_OMF)
        s->Sseg = seg;
    else
        seg = s->Sseg;

    if (s->Sclass == SCglobal || (s->Sclass == SCstatic && config.objfmt != OBJ_OMF))
        objmod->pubdefsize(seg,s,s->Soffset,datasize);    /* do the definition            */

    assert(s->Sseg != UNKNOWN);
    if (config.fulltypes &&
        !(s->Sclass == SCstatic && funcsym_p)) // not local static
        cv_outsym(s);
    searchfixlist(s);

    /* Go back through list, now that we know its size, and send out    */
    /* the data.                                                        */

    offset = s->Soffset;

    for (dt_t *dt = dtstart; dt; dt = dt->DTnext)
    {
        switch (dt->dt)
        {   case DT_abytes:
                if (tyreg(dt->Dty))
                    flags = CFoff;
                else
                    flags = CFoff | CFseg;
                if (I64)
                    flags |= CFoffset64;
#if TARGET_SEGMENTED
                if (tybasic(dt->Dty) == TYcptr)
                    objmod->reftocodeseg(seg,offset,dt->DTabytes);
                else
#endif
#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
                    objmod->reftodatseg(seg,offset,dt->DTabytes,dt->DTseg,flags);
#else
                /*else*/ if (dt->DTseg == DATA)
                    objmod->reftodatseg(seg,offset,dt->DTabytes,DATA,flags);
#if MARS
                else if (dt->DTseg == CDATA)
                    objmod->reftodatseg(seg,offset,dt->DTabytes,CDATA,flags);
#endif
                else
                    objmod->reftofarseg(seg,offset,dt->DTabytes,dt->DTseg,flags);
#endif
                offset += size(dt->Dty);
                break;
            case DT_ibytes:
                objmod->bytes(seg,offset,dt->DTn,dt->DTdata);
                offset += dt->DTn;
                break;
            case DT_nbytes:
                objmod->bytes(seg,offset,dt->DTnbytes,dt->DTpbytes);
                offset += dt->DTnbytes;
                break;
            case DT_azeros:
                //printf("objmod->lidata(seg = %d, offset = %d, azeros = %d)\n", seg, offset, dt->DTazeros);
                if (0 && seg == cseg)
                {
                    objmod->lidata(seg,offset,dt->DTazeros);
                    offset += dt->DTazeros;
                }
                else
                {
                    SegData[seg]->SDoffset = offset;
                    objmod->lidata(seg,offset,dt->DTazeros);
                    offset = SegData[seg]->SDoffset;
                }
                break;
            case DT_xoff:
            {
                symbol *sb = dt->DTsym;          // get external symbol pointer
                a = dt->DToffset; // offset from it
                if (tyreg(dt->Dty))
                    flags = CFoff;
                else
                    flags = CFoff | CFseg;
                if (I64 && tysize(dt->Dty) == 8)
                    flags |= CFoffset64;
                offset += objmod->reftoident(seg,offset,sb,a,flags);
                break;
            }
            case DT_coff:
                objmod->reftocodeseg(seg,offset,dt->DToffset);
                offset += intsize;
                break;
            default:
#ifdef DEBUG
                dbg_printf("dt = %p, dt = %d\n",dt,dt->dt);
#endif
                assert(0);
        }
    }
    Offset(seg) = offset;
#if SCPP
    out_extdef(s);
#endif
Lret:
    dt_free(dtstart);
}



/******************************
 * Output n bytes of a common block, n > 0.
 */

void outcommon(symbol *s,targ_size_t n)
{
    //printf("outcommon('%s',%d)\n",s->Sident,n);
    if (n != 0)
    {
        assert(s->Sclass == SCglobal);
#if TARGET_SEGMENTED
        if (s->ty() & mTYcs) // if store in code segment
        {
            /* COMDEFs not supported in code segment
             * so put them out as initialized 0s
             */
            dtnzeros(&s->Sdt,n);
            outdata(s);
#if SCPP
            out_extdef(s);
#endif
        }
        else
#endif
        if (s->ty() & mTYthread) // if store in thread local segment
        {
            if (config.objfmt == OBJ_ELF)
            {
                s->Sclass = SCcomdef;
                objmod->common_block(s, 0, n, 1);
            }
            else
            {
                /* COMDEFs not supported in tls segment
                 * so put them out as COMDATs with initialized 0s
                 */
                s->Sclass = SCcomdat;
                dtnzeros(&s->Sdt,n);
                outdata(s);
#if SCPP
                if (config.objfmt == OBJ_OMF)
                    out_extdef(s);
#endif
            }
        }
        else
        {
            s->Sclass = SCcomdef;
            if (config.objfmt == OBJ_OMF)
            {
#if TARGET_SEGMENTED
                s->Sxtrnnum = objmod->common_block(s,(s->ty() & mTYfar) == 0,n,1);
                if (s->ty() & mTYfar)
                    s->Sfl = FLfardata;
                else
                    s->Sfl = FLextern;
#else
                s->Sxtrnnum = objmod->common_block(s,true,n,1);
                s->Sfl = FLextern;
#endif
                s->Sseg = UNKNOWN;
                pstate.STflags |= PFLcomdef;
#if SCPP
                ph_comdef(s);               // notify PH that a COMDEF went out
#endif
            }
            else
                objmod->common_block(s, 0, n, 1);
        }
        if (config.fulltypes)
            cv_outsym(s);
    }
}

/*************************************
 * Mark a symbol as going into a read-only segment.
 */

void out_readonly(symbol *s)
{
    // The default is DATA
    if (config.objfmt == OBJ_ELF || config.objfmt == OBJ_MACH)
    {
        /* Cannot have pointers in CDATA when compiling PIC code, because
         * they require dynamic relocations of the read-only segment.
         * Instead use the .data.rel.ro section. See Bugzilla 11171.
         */
        if (config.flags3 & CFG3pic && dtpointers(s->Sdt))
            s->Sseg = CDATAREL;
        else
            s->Sseg = CDATA;
    }
    else
    {
        // Haven't really worked out where immutable read-only data can go.
    }
}

/******************************
 * Walk expression tree, converting it from a PARSER tree to
 * a code generator tree.
 */

STATIC void outelem(elem *e)
{
    symbol *s;
    tym_t tym;
    elem *e1;
#if SCPP
    type *t;
#endif

again:
    assert(e);
    elem_debug(e);

#ifdef DEBUG
    if (EBIN(e))
        assert(e->E1 && e->E2);
//    else if (EUNA(e))
//      assert(e->E1 && !e->E2);
#endif

#if SCPP
    t = e->ET;
    assert(t);
    type_debug(t);
    tym = t->Tty;
    switch (tybasic(tym))
    {   case TYstruct:
            t->Tcount++;
            break;

        case TYarray:
            t->Tcount++;
            break;

        case TYbool:
        case TYwchar_t:
        case TYchar16:
        case TYmemptr:
        case TYvtshape:
        case TYnullptr:
            tym = tym_conv(t);
            e->ET = NULL;
            break;

        case TYenum:
            tym = tym_conv(t->Tnext);
            e->ET = NULL;
            break;

        default:
            e->ET = NULL;
            break;
    }
    e->Nflags = 0;
    e->Ety = tym;
#endif

    switch (e->Eoper)
    {
    default:
    Lop:
#if DEBUG
        //if (!EOP(e)) dbg_printf("e->Eoper = x%x\n",e->Eoper);
#endif
        if (EBIN(e))
        {   outelem(e->E1);
            e = e->E2;
        }
        else if (EUNA(e))
        {
            e = e->E1;
        }
        else
            break;
#if SCPP
        type_free(t);
#endif
        goto again;                     /* iterate instead of recurse   */
    case OPaddr:
        e1 = e->E1;
        if (e1->Eoper == OPvar)
        {   // Fold into an OPrelconst
#if SCPP
            el_copy(e,e1);
            e->ET = t;
#else
            tym = e->Ety;
            el_copy(e,e1);
            e->Ety = tym;
#endif
            e->Eoper = OPrelconst;
            el_free(e1);
            goto again;
        }
        goto Lop;

    case OPrelconst:
    case OPvar:
    L6:
        s = e->EV.sp.Vsym;
        assert(s);
        symbol_debug(s);
        switch (s->Sclass)
        {
            case SCregpar:
            case SCparameter:
                if (e->Eoper == OPrelconst)
                    addrparam = TRUE;   // taking addr of param list
                break;

            case SCstatic:
            case SClocstat:
            case SCextern:
            case SCglobal:
            case SCcomdat:
            case SCcomdef:
#if PSEUDO_REGS
            case SCpseudo:
#endif
            case SCinline:
            case SCsinline:
            case SCeinline:
                s->Sflags |= SFLlivexit;
                /* FALL-THROUGH */
            case SCauto:
            case SCregister:
            case SCfastpar:
            case SCbprel:
                if (e->Eoper == OPrelconst)
                {
                    s->Sflags &= ~(SFLunambig | GTregcand);
                }
#if TARGET_SEGMENTED
                else if (s->ty() & mTYfar)
                    e->Ety |= mTYfar;
#endif
                break;
#if SCPP
            case SCmember:
                err_noinstance(s->Sscope,s);
                goto L5;
            case SCstruct:
                cpperr(EM_no_instance,s->Sident);       // no instance of class
            L5:
                e->Eoper = OPconst;
                e->Ety = TYint;
                return;

            case SCfuncalias:
                e->EV.sp.Vsym = s->Sfunc->Falias;
                goto L6;
            case SCstack:
                break;
            case SCfunctempl:
                cpperr(EM_no_template_instance, s->Sident);
                break;
            default:
#ifdef DEBUG
                symbol_print(s);
                WRclass((enum SC) s->Sclass);
#endif
                assert(0);
#endif
        }
#if SCPP
        if (tyfunc(s->ty()))
        {
#if SCPP
            nwc_mustwrite(s);           /* must write out function      */
#else
            ;
#endif
        }
        else if (s->Sdt)                /* if initializer for symbol    */
            outdata(s);                 // write out data for symbol
        if (config.flags3 & CFG3pic)
        {
            objmod->gotref(s);
        }
#endif
        break;
    case OPstring:
    case OPconst:
    case OPstrthis:
        break;
    case OPsizeof:
#if SCPP
        e->Eoper = OPconst;
        e->EV.Vlong = type_size(e->EV.sp.Vsym->Stype);
#else
        assert(0);
#endif
        break;

#if SCPP
    case OPstreq:
    case OPstrpar:
    case OPstrctor:
        type_size(e->E1->ET);
        goto Lop;

    case OPasm:
        break;

    case OPctor:
        nwc_mustwrite(e->EV.eop.Edtor);
    case OPdtor:
        // Don't put 'this' pointers in registers if we need
        // them for EH stack cleanup.
        e1 = e->E1;
        elem_debug(e1);
        if (e1->Eoper == OPadd)
            e1 = e1->E1;
        if (e1->Eoper == OPvar)
            e1->EV.sp.Vsym->Sflags &= ~GTregcand;
        goto Lop;
    case OPmark:
        break;
#endif
    }
#if SCPP
    type_free(t);
#endif
}

/*************************************
 * Determine register candidates.
 */

STATIC void out_regcand_walk(elem *e);

void out_regcand(symtab_t *psymtab)
{
    block *b;
    SYMIDX si;
    int ifunc;

    //printf("out_regcand()\n");
    ifunc = (tybasic(funcsym_p->ty()) == TYifunc);
    for (si = 0; si < psymtab->top; si++)
    {   symbol *s = psymtab->tab[si];

        symbol_debug(s);
        //assert(sytab[s->Sclass] & SCSS);      // only stack variables
        s->Ssymnum = si;                        // Ssymnum trashed by cpp_inlineexpand
        if (!(s->ty() & mTYvolatile) &&
            !(ifunc && (s->Sclass == SCparameter || s->Sclass == SCregpar)) &&
            s->Sclass != SCstatic)
            s->Sflags |= (GTregcand | SFLunambig);      // assume register candidate
        else
            s->Sflags &= ~(GTregcand | SFLunambig);
    }

    addrparam = FALSE;                  // haven't taken addr of param yet
    for (b = startblock; b; b = b->Bnext)
    {
        if (b->Belem)
            out_regcand_walk(b->Belem);

        // Any assembler blocks make everything ambiguous
        if (b->BC == BCasm)
            for (si = 0; si < psymtab->top; si++)
                psymtab->tab[si]->Sflags &= ~(SFLunambig | GTregcand);
    }

    // If we took the address of one parameter, assume we took the
    // address of all non-register parameters.
    if (addrparam)                      // if took address of a parameter
    {
        for (si = 0; si < psymtab->top; si++)
            if (psymtab->tab[si]->Sclass == SCparameter || psymtab->tab[si]->Sclass == SCshadowreg)
                psymtab->tab[si]->Sflags &= ~(SFLunambig | GTregcand);
    }

}

STATIC void out_regcand_walk(elem *e)
{   symbol *s;

    while (1)
    {   elem_debug(e);

        if (EBIN(e))
        {   if (e->Eoper == OPstreq)
            {   if (e->E1->Eoper == OPvar)
                {   s = e->E1->EV.sp.Vsym;
                    s->Sflags &= ~(SFLunambig | GTregcand);
                }
                if (e->E2->Eoper == OPvar)
                {   s = e->E2->EV.sp.Vsym;
                    s->Sflags &= ~(SFLunambig | GTregcand);
                }
            }
            out_regcand_walk(e->E1);
            e = e->E2;
        }
        else if (EUNA(e))
        {
            // Don't put 'this' pointers in registers if we need
            // them for EH stack cleanup.
            if (e->Eoper == OPctor)
            {   elem *e1 = e->E1;

                if (e1->Eoper == OPadd)
                    e1 = e1->E1;
                if (e1->Eoper == OPvar)
                    e1->EV.sp.Vsym->Sflags &= ~GTregcand;
            }
            e = e->E1;
        }
        else
        {   if (e->Eoper == OPrelconst)
            {
                s = e->EV.sp.Vsym;
                assert(s);
                symbol_debug(s);
                switch (s->Sclass)
                {
                    case SCregpar:
                    case SCparameter:
                    case SCshadowreg:
                        addrparam = TRUE;       // taking addr of param list
                        break;
                    case SCauto:
                    case SCregister:
                    case SCfastpar:
                    case SCbprel:
                        s->Sflags &= ~(SFLunambig | GTregcand);
                        break;
                }
            }
            else if (e->Eoper == OPvar)
            {
                if (e->EV.sp.Voffset)
                {   if (!(e->EV.sp.Voffset == 1 && tybyte(e->Ety)))
                        e->EV.sp.Vsym->Sflags &= ~GTregcand;
                }
            }
            break;
        }
    }
}

/**************************
 * Optimize function,
 * generate code for it,
 * and write it out.
 */

STATIC void writefunc2(symbol *sfunc);

void writefunc(symbol *sfunc)
{
#if HTOD
    return;
#elif SCPP
    writefunc2(sfunc);
#else
    cstate.CSpsymtab = &globsym;
    writefunc2(sfunc);
    cstate.CSpsymtab = NULL;
#endif
}

STATIC void writefunc2(symbol *sfunc)
{
    block *b;
    unsigned nsymbols;
    SYMIDX si;
    int anyasm;
    int csegsave;                       // for OMF
    func_t *f = sfunc->Sfunc;
    tym_t tyf;

    //printf("writefunc(%s)\n",sfunc->Sident);
    debug(debugy && dbg_printf("writefunc(%s)\n",sfunc->Sident));
#if SCPP
    if (CPP)
    {

    // If constructor or destructor, make sure it has been fixed.
    if (f->Fflags & (Fctor | Fdtor))
        assert(errcnt || f->Fflags & Ffixed);

    // If this function is the 'trigger' to output the vtbl[], do so
    if (f->Fflags3 & Fvtblgen && !eecontext.EEcompile)
    {   Classsym *stag;

        stag = (Classsym *) sfunc->Sscope;
        {
            enum SC scvtbl;

            scvtbl = (enum SC) ((config.flags2 & CFG2comdat) ? SCcomdat : SCglobal);
            n2_genvtbl(stag,scvtbl,1);
            n2_genvbtbl(stag,scvtbl,1);
#if SYMDEB_CODEVIEW
            if (config.fulltypes == CV4)
                cv4_struct(stag,2);
#endif
        }
    }
    }
#endif

    /* Signify that function has been output                    */
    /* (before inline_do() to prevent infinite recursion!)      */
    f->Fflags &= ~Fpending;
    f->Fflags |= Foutput;

    if (
#if SCPP
        errcnt ||
#endif
        (eecontext.EEcompile && eecontext.EEfunc != sfunc))
        return;

    /* Copy local symbol table onto main one, making sure       */
    /* that the symbol numbers are adjusted accordingly */
    //dbg_printf("f->Flocsym.top = %d\n",f->Flocsym.top);
    nsymbols = f->Flocsym.top;
    if (nsymbols > globsym.symmax)
    {   /* Reallocate globsym.tab[]     */
        globsym.symmax = nsymbols;
        globsym.tab = symtab_realloc(globsym.tab, globsym.symmax);
    }
    debug(debugy && dbg_printf("appending symbols to symtab...\n"));
    assert(globsym.top == 0);
    memcpy(&globsym.tab[0],&f->Flocsym.tab[0],nsymbols * sizeof(symbol *));
    globsym.top = nsymbols;

    assert(startblock == NULL);
    if (f->Fflags & Finline)            // if keep function around
    {   // Generate copy of function
        block *bf;
        block **pb;

        pb = &startblock;
        for (bf = f->Fstartblock; bf; bf = bf->Bnext)
        {
            b = block_calloc();
            *pb = b;
            pb = &b->Bnext;

            *b = *bf;
            assert(!b->Bsucc);
            assert(!b->Bpred);
            b->Belem = el_copytree(b->Belem);
        }
    }
    else
    {   startblock = sfunc->Sfunc->Fstartblock;
        sfunc->Sfunc->Fstartblock = NULL;
    }
    assert(startblock);

    /* Do any in-line expansion of function calls inside sfunc  */
#if SCPP
    inline_do(sfunc);
#endif

#if SCPP
    /* If function is _STIxxxx, add in the auto destructors             */
#if NEWSTATICDTOR
    if (cpp_stidtors && memcmp("__SI",sfunc->Sident,4) == 0)
#else
    if (cpp_stidtors && memcmp("_STI",sfunc->Sident,4) == 0)
#endif
    {   list_t el;

        assert(startblock->Bnext == NULL);
        el = cpp_stidtors;
        do
        {
            startblock->Belem = el_combine(startblock->Belem,list_elem(el));
            el = list_next(el);
        } while (el);
        list_free(&cpp_stidtors,FPNULL);
    }
#endif
    assert(funcsym_p == NULL);
    funcsym_p = sfunc;
    tyf = tybasic(sfunc->ty());

#if SCPP
    out_extdef(sfunc);
#endif

    // TX86 computes parameter offsets in stackoffsets()
    //printf("globsym.top = %d\n", globsym.top);

#if SCPP
    FuncParamRegs fpr(tyf);
#endif

    for (si = 0; si < globsym.top; si++)
    {   symbol *s = globsym.tab[si];

        symbol_debug(s);
        //printf("symbol %d '%s'\n",si,s->Sident);

        type_size(s->Stype);    // do any forward template instantiations

        s->Ssymnum = si;        // Ssymnum trashed by cpp_inlineexpand
        s->Sflags &= ~(SFLunambig | GTregcand);
        switch (s->Sclass)
        {
            case SCbprel:
                s->Sfl = FLbprel;
                goto L3;
            case SCauto:
            case SCregister:
                s->Sfl = FLauto;
                goto L3;
#if SCPP
            case SCfastpar:
            case SCregpar:
            case SCparameter:
                if (si == 0 && fpr.alloc(s->Stype, s->Stype->Tty, &s->Spreg, &s->Spreg2))
                {
                    assert(s->Spreg == ((tyf == TYmfunc) ? CX : AX));
                    assert(s->Spreg2 == NOREG);
                    assert(si == 0);
                    s->Sclass = SCfastpar;
                    s->Sfl = FLfast;
                    goto L3;
                }
                assert(s->Sclass != SCfastpar);
#else
            case SCfastpar:
                s->Sfl = FLfast;
                goto L3;
            case SCregpar:
            case SCparameter:
            case SCshadowreg:
#endif
                s->Sfl = FLpara;
                if (tyf == TYifunc)
                {   s->Sflags |= SFLlivexit;
                    break;
                }
            L3:
                if (!(s->ty() & mTYvolatile))
                    s->Sflags |= GTregcand | SFLunambig; // assume register candidate   */
                break;
#if PSEUDO_REGS
            case SCpseudo:
                s->Sfl = FLpseudo;
                break;
#endif
            case SCstatic:
                break;                  // already taken care of by datadef()
            case SCstack:
                s->Sfl = FLstack;
                break;
            default:
#ifdef DEBUG
                symbol_print(s);
#endif
                assert(0);
        }
    }

    addrparam = FALSE;                  // haven't taken addr of param yet
    anyasm = 0;
    numblks = 0;
    for (b = startblock; b; b = b->Bnext)
    {
        numblks++;                              // redo count
        memset(&b->_BLU,0,sizeof(b->_BLU));
        if (b->Belem)
        {   outelem(b->Belem);
#if SCPP
            if (el_noreturn(b->Belem) && !(config.flags3 & CFG3eh))
            {   b->BC = BCexit;
                list_free(&b->Bsucc,FPNULL);
            }
#endif
#if MARS
            if (b->Belem->Eoper == OPhalt)
            {   b->BC = BCexit;
                list_free(&b->Bsucc,FPNULL);
            }
#endif
        }
        if (b->BC == BCasm)
            anyasm = 1;
        if (sfunc->Sflags & SFLexit && (b->BC == BCret || b->BC == BCretexp))
        {   b->BC = BCexit;
            list_free(&b->Bsucc,FPNULL);
        }
        assert(b != b->Bnext);
    }
    PARSER = 0;
    if (eecontext.EEelem)
    {   unsigned marksi = globsym.top;

        eecontext.EEin++;
        outelem(eecontext.EEelem);
        eecontext.EEelem = doptelem(eecontext.EEelem,TRUE);
        eecontext.EEin--;
        eecontext_convs(marksi);
    }
    maxblks = 3 * numblks;              // allow for increase in # of blocks
    // If we took the address of one parameter, assume we took the
    // address of all non-register parameters.
    if (addrparam | anyasm)             // if took address of a parameter
    {
        for (si = 0; si < globsym.top; si++)
            if (anyasm || globsym.tab[si]->Sclass == SCparameter)
                globsym.tab[si]->Sflags &= ~(SFLunambig | GTregcand);
    }

    block_pred();                       // compute predecessors to blocks
    block_compbcount();                 // eliminate unreachable blocks
    if (go.mfoptim)
    {   OPTIMIZER = 1;
        optfunc();                      /* optimize function            */
        assert(dfo);
        OPTIMIZER = 0;
    }
    else
    {
        //dbg_printf("blockopt()\n");
        blockopt(0);                    /* optimize                     */
    }

#if SCPP
    if (CPP)
    {
        // Look for any blocks that return nothing.
        // Do it after optimization to eliminate any spurious
        // messages like the implicit return on { while(1) { ... } }
        if (tybasic(funcsym_p->Stype->Tnext->Tty) != TYvoid &&
            !(funcsym_p->Sfunc->Fflags & (Fctor | Fdtor | Finvariant))
#if DEBUG_XSYMGEN
            /* the internal dataview function is allowed to lie about its return value */
            && compile_state != kDataView
#endif
           )
        {   char err;

            err = 0;
            for (b = startblock; b; b = b->Bnext)
            {   if (b->BC == BCasm)     // no errors if any asm blocks
                    err |= 2;
                else if (b->BC == BCret)
                    err |= 1;
            }
            if (err == 1)
                func_noreturnvalue();
        }
    }
#endif
    assert(funcsym_p == sfunc);
    if (eecontext.EEcompile != 1)
    {
        if (symbol_iscomdat(sfunc))
        {
            csegsave = cseg;
            objmod->comdat(sfunc);
        }
        else
            if (config.flags & CFGsegs) // if user set switch for this
            {
#if SCPP || TARGET_WINDOS
                objmod->codeseg(cpp_mangle(funcsym_p),1);
#else
                objmod->codeseg(funcsym_p->Sident, 1);
#endif
                                        // generate new code segment
            }
        cod3_align();                   // align start of function
        objmod->func_start(sfunc);
        searchfixlist(sfunc);           // backpatch any refs to this function
    }

    //dbg_printf("codgen()\n");
#if SCPP
    if (!errcnt)
#endif
        codgen();                               // generate code
    //dbg_printf("after codgen for %s Coffset %x\n",sfunc->Sident,Coffset);
    blocklist_free(&startblock);
#if SCPP
    PARSER = 1;
#endif
    objmod->func_term(sfunc);
    if (eecontext.EEcompile == 1)
        goto Ldone;
    if (sfunc->Sclass == SCglobal)
    {
        if ((config.objfmt == OBJ_OMF || config.objfmt == OBJ_MSCOFF) && !(config.flags4 & CFG4allcomdat))
        {
            assert(sfunc->Sseg == cseg);
            objmod->pubdef(sfunc->Sseg,sfunc,sfunc->Soffset);       // make a public definition
        }

#if SCPP && _WIN32
        char *id;
        // Determine which startup code to reference
        if (!CPP || !isclassmember(sfunc))              // if not member function
        {   static char *startup[] =
            {   "__acrtused","__acrtused_winc","__acrtused_dll",
                "__acrtused_con","__wacrtused","__wacrtused_con",
            };
            int i;

            id = sfunc->Sident;
            switch (id[0])
            {
                case 'D': if (strcmp(id,"DllMain"))
                                break;
                          if (config.exe == EX_NT)
                          {     i = 2;
                                goto L2;
                          }
                          break;

                case 'm': if (strcmp(id,"main"))
                                break;
                          if (config.exe == EX_NT)
                                i = 3;
                          else if (config.wflags & WFwindows)
                                i = 1;
                          else
                                i = 0;
                          goto L2;

                case 'w': if (strcmp(id,"wmain") == 0)
                          {
                                if (config.exe == EX_NT)
                                {   i = 5;
                                    goto L2;
                                }
                                break;
                          }
                case 'W': if (stricmp(id,"WinMain") == 0)
                          {
                                i = 0;
                                goto L2;
                          }
                          if (stricmp(id,"wWinMain") == 0)
                          {
                                if (config.exe == EX_NT)
                                {   i = 4;
                                    goto L2;
                                }
                          }
                          break;

                case 'L':
                case 'l': if (stricmp(id,"LibMain"))
                                break;
                          if (config.exe != EX_NT && config.wflags & WFwindows)
                          {     i = 2;
                                goto L2;
                          }
                          break;

                L2:     objmod->external_def(startup[i]);          // pull in startup code
                        break;
            }
        }
#endif
    }
    if (config.wflags & WFexpdef &&
        sfunc->Sclass != SCstatic &&
        sfunc->Sclass != SCsinline &&
        !(sfunc->Sclass == SCinline && !(config.flags2 & CFG2comdat)) &&
        sfunc->ty() & mTYexport)
        objmod->export_symbol(sfunc,Para.offset);      // export function definition

    if (config.fulltypes && config.fulltypes != CV8)
        cv_func(sfunc);                 // debug info for function

#if MARS
    /* This is to make uplevel references to SCfastpar variables
     * from nested functions work.
     */
    for (si = 0; si < globsym.top; si++)
    {
        Symbol *s = globsym.tab[si];

        switch (s->Sclass)
        {   case SCfastpar:
                s->Sclass = SCauto;
                break;
        }
    }
    /* After codgen() and writing debug info for the locals,
     * readjust the offsets of all stack variables so they
     * are relative to the frame pointer.
     * Necessary for nested function access to lexically enclosing frames.
     */
     cod3_adjSymOffsets();
#endif

    if ((config.objfmt == OBJ_OMF || config.objfmt == OBJ_MSCOFF) &&
        symbol_iscomdat(sfunc))         // if generated a COMDAT
        objmod->setcodeseg(csegsave);       // reset to real code seg

    /* Check if function is a constructor or destructor, by     */
    /* seeing if the function name starts with _STI or _STD     */
    {
#if _M_I86
        short *p = (short *) sfunc->Sident;
        if (p[0] == 'S_' && (p[1] == 'IT' || p[1] == 'DT'))
#else
        char *p = sfunc->Sident;
        if (p[0] == '_' && p[1] == 'S' && p[2] == 'T' &&
            (p[3] == 'I' || p[3] == 'D'))
#endif
            objmod->funcptr(sfunc);
    }

Ldone:
    funcsym_p = NULL;

#if SCPP
    // Free any added symbols
    freesymtab(globsym.tab,nsymbols,globsym.top);
#endif
    globsym.top = 0;

    //dbg_printf("done with writefunc()\n");
    util_free(dfo);
    dfo = NULL;
}

/*************************
 * Align segment offset.
 * Input:
 *      seg             segment to be aligned
 *      datasize        size in bytes of object to be aligned
 */

void alignOffset(int seg,targ_size_t datasize)
{
    targ_size_t alignbytes;

    alignbytes = align(datasize,Offset(seg)) - Offset(seg);
    //dbg_printf("seg %d datasize = x%x, Offset(seg) = x%x, alignbytes = x%x\n",
      //seg,datasize,Offset(seg),alignbytes);
    if (alignbytes)
        objmod->lidata(seg,Offset(seg),alignbytes);
}


/***************************************
 * Write data into read-only data segment.
 * Return symbol for it.
 */

#define ROMAX 32
struct Readonly
{
    symbol *sym;
    size_t length;
    unsigned char p[ROMAX];
};

#define RMAX 16
static Readonly readonly[RMAX];
static size_t readonly_length;
static size_t readonly_i;

void out_reset()
{
    readonly_length = 0;
    readonly_i = 0;
}

symbol *out_readonly_sym(tym_t ty, void *p, int len)
{
#if HTOD
    return;
#endif
#if 0
    printf("out_readonly_sym(ty = x%x)\n", ty);
    for (int i = 0; i < len; i++)
        printf(" [%d] = %02x\n", i, ((unsigned char*)p)[i]);
#endif
    // Look for previous symbol we can reuse
    for (int i = 0; i < readonly_length; i++)
    {
        Readonly *r = &readonly[i];
        if (r->length == len && memcmp(p, r->p, len) == 0)
            return r->sym;
    }

    symbol *s;

    if (config.objfmt == OBJ_ELF ||
        (MARS && (config.objfmt == OBJ_OMF || config.objfmt == OBJ_MSCOFF)))
    {
        /* MACHOBJ can't go here, because the const data segment goes into
         * the _TEXT segment, and one cannot have a fixup from _TEXT to _TEXT.
         */
        s = objmod->sym_cdata(ty, (char *)p, len);
    }
    else
    {
        unsigned sz = tysize(ty);

        alignOffset(DATA, sz);
        s = symboldata(Doffset,ty | mTYconst);
        s->Sseg = DATA;
        objmod->write_bytes(SegData[DATA], len, p);
        //printf("s->Sseg = %d:x%x\n", s->Sseg, s->Soffset);
    }

    if (len <= ROMAX)
    {   Readonly *r;

        if (readonly_length < RMAX)
        {
            r = &readonly[readonly_length];
            readonly_length++;
        }
        else
        {   r = &readonly[readonly_i];
            readonly_i++;
            if (readonly_i >= RMAX)
                readonly_i = 0;
        }
        r->length = len;
        r->sym = s;
        memcpy(r->p, p, len);
    }
    return s;
}

void Srcpos::print(const char *func)
{
    printf("%s(", func);
#if MARS
    printf("Sfilename = %s", Sfilename ? Sfilename : "null");
#else
    Sfile *sf = Sfilptr ? *Sfilptr : NULL;
    printf("Sfilptr = %p (filename = %s)", sf, sf ? sf->SFname : "null");
#endif
    printf(", Slinnum = %u", Slinnum);
    printf(")\n");
}


#endif /* !SPP */

