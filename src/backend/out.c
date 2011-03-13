// Copyright (C) 1984-1998 by Symantec
// Copyright (C) 2000-2011 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in /dmd/src/dmd/backendlicense.txt
 * or /dm/src/dmd/backendlicense.txt
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
#include        "parser.h"
#include        "filespec.h"
#include        "code.h"
#include        "cgcv.h"
#include        "go.h"
#include        "dt.h"
#if SCPP
#include        "cpp.h"
#include        "el.h"
#endif

#if TARGET_MAC
#include        "TG.h"
#endif

#if TARGET_POWERPC
#include "cgobjxcoff.h"
#include "xcoff.h"
#include "cgfunc.h"
#endif

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

static  int addrparam;  /* see if any parameters get their address taken */

/**********************************
 * We put out an external definition.
 */

#if SCPP

void out_extdef(symbol *s)
{
    pstate.STflags |= PFLextdef;
    if (//config.flags2 & CFG2phgen ||
        (config.flags2 & (CFG2phauto | CFG2phautoy) &&
            !(pstate.STflags & (PFLhxwrote | PFLhxdone)))
       )

        synerr(EM_data_in_pch,prettyident(s));          // data or code in precompiled header
}

#endif

#if TX86 || (!HOST_THINK && (TARGET_68K))
#if SCPP
/********************************
 * Put out code segment name record.
 */

void outcsegname(char *csegname)
{
    obj_codeseg(csegname,0);
}
#endif
#endif

/***********************************
 * Output function thunk.
 */

#if SCPP

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

#if TX86

void outdata(symbol *s)
{
#if HTOD
    return;
#endif
    dt_t *dtstart,*dt;
    targ_size_t datasize,a;
    int seg;
    targ_size_t offset;
    int flags;
    char *p;
    tym_t ty;
    int tls;

    symbol_debug(s);
#ifdef DEBUG
    debugy && dbg_printf("outdata('%s')\n",s->Sident);
#endif
    //printf("outdata('%s', ty=x%x)\n",s->Sident,s->Stype->Tty);
    //symbol_print(s);

    // Data segment variables are always live on exit from a function
    s->Sflags |= SFLlivexit;

    dtstart = s->Sdt;
    s->Sdt = NULL;                      // it will be free'd
#if SCPP && TARGET_WINDOS
    if (eecontext.EEcompile)
    {   s->Sfl = (s->ty() & mTYfar) ? FLfardata : FLextern;
        s->Sseg = UNKNOWN;
        goto Lret;                      // don't output any data
    }
#endif
    datasize = 0;
    tls = 0;
    ty = s->ty();
    if (ty & mTYexport && config.wflags & WFexpdef && s->Sclass != SCstatic)
        obj_export(s,0);        // export data definition
    for (dt = dtstart; dt; dt = dt->DTnext)
    {
        //printf("dt = %p, dt = %d\n",dt,dt->dt);
        switch (dt->dt)
        {   case DT_abytes:
            {   // Put out the data for the string, and
                // reserve a spot for a pointer to that string
#if ELFOBJ || MACHOBJ
                datasize += size(dt->Dty);
                dt->DTabytes += elf_data_cdata(dt->DTpbytes,dt->DTnbytes,&dt->DTseg);
#else
                targ_size_t *poffset;
                datasize += size(dt->Dty);
                if (tybasic(dt->Dty) == TYcptr)
                {   seg = cseg;
                    poffset = &Coffset;
                }
#if SCPP
                else if (tybasic(dt->Dty) == TYfptr &&
                         dt->DTnbytes > config.threshold)
                {
                    seg = obj_fardata(s->Sident,dt->DTnbytes,&offset);
                    poffset = &offset;
                }
#endif
                else
                {   seg = DATA;
                    poffset = &Doffset;
                }
                dt->DTseg = seg;
                dt->DTabytes += *poffset;
                obj_bytes(seg,*poffset,dt->DTnbytes,dt->DTpbytes);
                *poffset += dt->DTnbytes;
#endif
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
#if OMFOBJ
                        case mTYfar:                    // if far data
                            seg = obj_fardata(s->Sident,datasize,&s->Soffset);
                            s->Sfl = FLfardata;
                            break;
#endif
                        case mTYcs:
                            seg = cseg;
                            Coffset = align(datasize,Coffset);
                            s->Soffset = Coffset;
                            Coffset += datasize;
                            s->Sfl = FLcsdata;
                            break;
                        case mTYthread:
                        {   seg_data *pseg = obj_tlsseg_bss();
#if ELFOBJ || MACHOBJ
                            s->Sseg = pseg->SDseg;
                            elf_data_start(s, datasize, pseg->SDseg);
                            obj_lidata(pseg->SDseg, pseg->SDoffset, datasize);
#else
                            targ_size_t TDoffset = pseg->SDoffset;
                            TDoffset = align(datasize,TDoffset);
                            s->Soffset = TDoffset;
                            TDoffset += datasize;
                            pseg->SDoffset = TDoffset;
#endif
                            seg = pseg->SDseg;
                            s->Sfl = FLtlsdata;
                            tls = 1;
                            break;
                        }
                        default:
#if ELFOBJ || MACHOBJ
                            seg = elf_data_start(s,datasize,UDATA);
                            obj_lidata(s->Sseg,s->Soffset,datasize);
#else
                            seg = UDATA;
                            UDoffset = align(datasize,UDoffset);
                            s->Soffset = UDoffset;
                            UDoffset += datasize;
#endif
                            s->Sfl = FLudata;           // uninitialized data
                            break;
                    }
#if ELFOBJ || MACHOBJ
                    assert(s->Sseg != UNKNOWN);
                    if (s->Sclass == SCglobal || s->Sclass == SCstatic)
                        objpubdef(s->Sseg,s,s->Soffset);        /* do the definition    */
                                            /* if a pubdef to be done */
#else
                    s->Sseg = seg;
                    if (s->Sclass == SCglobal)          /* if a pubdef to be done */
                        objpubdef(seg,s,s->Soffset);    /* do the definition    */
#endif
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
                    outdata(sb);                // write out data for symbol
            }
            case DT_coff:
                datasize += size(dt->Dty);
                break;
            case DT_1byte:
                datasize++;
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
        seg = obj_comdat(s);
#if ELFOBJ || OMFOBJ
        s->Soffset = 0;
#endif
        switch (ty & mTYLINK)
        {
#if OMFOBJ
            case mTYfar:                // if far data
                s->Sfl = FLfardata;
                break;
#endif
            case mTYcs:
                s->Sfl = FLcsdata;
                break;
            case mTYnear:
            case 0:
                s->Sfl = FLdata;        // initialized data
                break;
            case mTYthread:
                s->Sfl = FLtlsdata;
                tls = 1;
                break;

            default:
                assert(0);
        }
    }
    else
    {
      switch (ty & mTYLINK)
      {
#if OMFOBJ
        case mTYfar:                    // if far data
            seg = obj_fardata(s->Sident,datasize,&s->Soffset);
            s->Sfl = FLfardata;
            break;
#endif
        case mTYcs:
            assert(OMFOBJ);
            seg = cseg;
            Coffset = align(datasize,Coffset);
            s->Soffset = Coffset;
            s->Sfl = FLcsdata;
            break;
        case mTYthread:
        {   seg_data *pseg = obj_tlsseg();
#if ELFOBJ || MACHOBJ
            s->Sseg = pseg->SDseg;
            elf_data_start(s, datasize, s->Sseg);
//          s->Soffset = pseg->SDoffset;
#else
            targ_size_t TDoffset = pseg->SDoffset;
            TDoffset = align(datasize,TDoffset);
            s->Soffset = TDoffset;
#endif
            seg = pseg->SDseg;
            s->Sfl = FLtlsdata;
            tls = 1;
            break;
        }
        case mTYnear:
        case 0:
#if ELFOBJ || MACHOBJ
            seg = elf_data_start(s,datasize,DATA);
#else
            seg = DATA;
            alignOffset(DATA, datasize);
            s->Soffset = Doffset;
#endif
            s->Sfl = FLdata;            // initialized data
            break;
        default:
            assert(0);
      }
    }
#if ELFOBJ || MACHOBJ
    if (s->Sseg == UNKNOWN)
        s->Sseg = seg;
    else
        seg = s->Sseg;
    if (s->Sclass == SCglobal || s->Sclass == SCstatic)
    {
        objpubdef(s->Sseg,s,s->Soffset);        // do the definition
    }
#else
    s->Sseg = seg;
    if (s->Sclass == SCglobal)          /* if a pubdef to be done       */
        objpubdef(seg,s,s->Soffset);    /* do the definition            */
#endif
    if (config.fulltypes &&
        !(s->Sclass == SCstatic && funcsym_p)) // not local static
        cv_outsym(s);
    searchfixlist(s);

    /* Go back through list, now that we know its size, and send out    */
    /* the data.                                                        */

    offset = s->Soffset;

    for (dt = dtstart; dt; dt = dt->DTnext)
    {
        switch (dt->dt)
        {   case DT_abytes:
                if (tyreg(dt->Dty))
                    flags = CFoff;
                else
                    flags = CFoff | CFseg;
                if (I64)
                    flags |= CFoffset64;
                if (tybasic(dt->Dty) == TYcptr)
                    reftocodseg(seg,offset,dt->DTabytes);
#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_SOLARIS
                else
                    reftodatseg(seg,offset,dt->DTabytes,dt->DTseg,flags);
#else
                else if (dt->DTseg == DATA)
                    reftodatseg(seg,offset,dt->DTabytes,DATA,flags);
                else
                    reftofarseg(seg,offset,dt->DTabytes,dt->DTseg,flags);
#endif
                offset += size(dt->Dty);
                break;
            case DT_ibytes:
                obj_bytes(seg,offset,dt->DTn,dt->DTdata);
                offset += dt->DTn;
                break;
            case DT_nbytes:
                obj_bytes(seg,offset,dt->DTnbytes,dt->DTpbytes);
                offset += dt->DTnbytes;
                break;
            case DT_azeros:
                //printf("obj_lidata(seg = %d, offset = %d, azeros = %d)\n", seg, offset, dt->DTazeros);
                obj_lidata(seg,offset,dt->DTazeros);
                offset += dt->DTazeros;
                break;
            case DT_xoff:
            {
                symbol *sb = dt->DTsym;          // get external symbol pointer
                a = dt->DToffset; // offset from it
                if (tyreg(dt->Dty))
                    flags = CFoff;
                else
                    flags = CFoff | CFseg;
                if (I64)
                    flags |= CFoffset64;
                offset += reftoident(seg,offset,sb,a,flags);
                break;
            }
            case DT_coff:
                reftocodseg(seg,offset,dt->DToffset);
                offset += intsize;
                break;
            case DT_1byte:
                obj_byte(seg,offset++,dt->DTonebyte);
                break;
            default:
#ifdef DEBUG
                dbg_printf("dt = %p, dt = %d\n",dt,dt->dt);
#endif
                assert(0);
        }
    }
#if ELFOBJ || MACHOBJ
    Offset(seg) = offset;
#else
    if (seg == DATA)
        Doffset = offset;
    else if (seg == cseg)
        Coffset = offset;
    else if (tls && s->Sclass != SCcomdat)
    {
        obj_tlsseg()->SDoffset = offset;
    }
#endif
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
        else if (s->ty() & mTYthread) // if store in thread local segment
        {
#if ELFOBJ
            s->Sclass = SCcomdef;
            obj_comdef(s, 0, n, 1);
#else
            /* COMDEFs not supported in tls segment
             * so put them out as COMDATs with initialized 0s
             */
            s->Sclass = SCcomdat;
            dtnzeros(&s->Sdt,n);
            outdata(s);
#if SCPP && OMFOBJ
            out_extdef(s);
#endif
#endif
        }
        else
        {
#if ELFOBJ || MACHOBJ
            s->Sclass = SCcomdef;
            obj_comdef(s, 0, n, 1);
#else
            s->Sclass = SCcomdef;
            s->Sxtrnnum = obj_comdef(s,(s->ty() & mTYfar) == 0,n,1);
            s->Sseg = UNKNOWN;
            if (s->ty() & mTYfar)
                s->Sfl = FLfardata;
            else
                s->Sfl = FLextern;
            pstate.STflags |= PFLcomdef;
#if SCPP
            ph_comdef(s);               // notify PH that a COMDEF went out
#endif
#endif
        }
        if (config.fulltypes)
            cv_outsym(s);
    }
}
#endif // TX86

/******************************
 * Walk expression tree, converting it from a PARSER tree to
 * a code generator tree.
 */

STATIC void outelem(elem *e)
{
    symbol *s;
    char *p;
    targ_size_t sz;
    type *t;
    tym_t tym;
    elem *e1;

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
            case SCtmp:
                if (e->Eoper == OPrelconst)
                {
                    s->Sflags &= ~(SFLunambig | GTregcand);
                }
#if SCPP && TX86 && OMFOBJ
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
#if ELFOBJ || MACHOBJ
        if (config.flags3 & CFG3pic)
        {
            elfobj_gotref(s);
        }
#endif
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
    T80x86(int ifunc;)

    //printf("out_regcand()\n");
    T80x86(ifunc = (tybasic(funcsym_p->ty()) == TYifunc);)
    for (si = 0; si < psymtab->top; si++)
    {   symbol *s = psymtab->tab[si];

        symbol_debug(s);
        //assert(sytab[s->Sclass] & SCSS);      // only stack variables
        s->Ssymnum = si;                        // Ssymnum trashed by cpp_inlineexpand
        if (!(s->ty() & mTYvolatile) &&
#if TX86
            !(ifunc && (s->Sclass == SCparameter || s->Sclass == SCregpar)) &&
#endif
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
            if (psymtab->tab[si]->Sclass == SCparameter)
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
                        addrparam = TRUE;       // taking addr of param list
                        break;
                    case SCauto:
                    case SCregister:
                    case SCtmp:
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
{   unsigned i,n;
    block *b;
    unsigned nsymbols;
    SYMIDX si;
    int anyasm;
    int csegsave;
    targ_size_t coffsetsave;
    func_t *f = sfunc->Sfunc;
    tym_t tyf;
#if TARGET_POWERPC
    type *tyArr;
#endif

    //printf("writefunc(%s)\n",sfunc->Sident);
    debug(debugy && dbg_printf("writefunc(%s)\n",sfunc->Sident));
#if SCPP
    if (CPP)
    {
#if TARGET_MAC
    if (configv.verbose == 2)
        dbg_printf(" %s\n",sfunc->Sident);
#endif // TARGET_MAC

    // If constructor or destructor, make sure it has been fixed.
    if (f->Fflags & (Fctor | Fdtor))
        assert(errcnt || f->Fflags & Ffixed);

    // If this function is the 'trigger' to output the vtbl[], do so
    if (f->Fflags3 & Fvtblgen && !eecontext.EEcompile)
    {   Classsym *stag;

        stag = (Classsym *) sfunc->Sscope;
#if TARGET_MAC
        if (stag->Sstruct->Sflags & STRpasobj)
        {
            po_func_Methout(stag);
        }
        else
#endif // TARGET_MAC
        {
            enum SC scvtbl;

            scvtbl = (enum SC) ((config.flags2 & CFG2comdat) ? SCcomdat : SCglobal);
            n2_genvtbl(stag,scvtbl,1);
#if VBTABLES
            n2_genvbtbl(stag,scvtbl,1);
#endif
#if TX86 && OMFOBJ
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
#if TARGET_POWERPC
    //
    // JTM: I moved the code in cgcntrl.c to here
    // and made SpillSym a global
    //
    // Is it OK to add to globsym.tab here?  When will the memory for the _TMP symbol
    // get freed?       We may need to add an explicit free of this symbol somewhere within
    // this function
    // Need to chat with PLS about this

    // initialize the spill area symbol, fake it to be an array
    tyArr = type_alloc(TYarray);        /* array of                     */
    tyArr->Tdim = 1;
    tyArr->Tnext = tslong;
    SpillSym = symbol_generate(SCtmp, tyArr);
    symbol_add(SpillSym);
    SpillSym->Sfl = FLauto; // mark it as auto since it is the last in that area
#endif

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
#if TARGET_MAC
    Poffset = 0;
#endif
    //printf("globsym.top = %d\n", globsym.top);
    for (si = 0; si < globsym.top; si++)
    {   symbol *s = globsym.tab[si];

        symbol_debug(s);
        //printf("symbol %d '%s'\n",si,s->Sident);

        type_size(s->Stype);    // do any forward template instantiations

        s->Ssymnum = si;        // Ssymnum trashed by cpp_inlineexpand
        s->Sflags &= ~(SFLunambig | GTregcand);
        switch (s->Sclass)
        {
#if SCPP
            case SCfastpar:
            Lfp:
                s->Spreg = (tyf == TYmfunc) ? CX : AX;
            case SCauto:
            case SCregister:
                s->Sfl = FLauto;
                goto L3;
            case SCtmp:
                s->Sfl = FLtmp;
                goto L3;
            case SCbprel:
                s->Sfl = FLbprel;
                goto L3;
            case SCregpar:
            case SCparameter:
                if (tyf == TYjfunc && si == 0 &&
                    type_jparam(s->Stype))
                {   s->Sclass = SCfastpar;      // put last parameter into register
                    goto Lfp;
                }
#else
            case SCfastpar:
            case SCauto:
            case SCregister:
                s->Sfl = FLauto;
                goto L3;
            case SCtmp:
                s->Sfl = FLtmp;
                goto L3;
            case SCbprel:
                s->Sfl = FLbprel;
                goto L3;
            case SCregpar:
            case SCparameter:
#endif
                s->Sfl = FLpara;
#if TARGET_MAC
                {
                unsigned Ssize;
                unsigned short tsize;

                assert(funcsym_p);
                /* Handle case where float parameter is really passed as a double */
                /* Watch out because SFLimplem == SFLdouble (ugh)               */
                if (s->Sflags & SFLdouble)
                {
                    switch(type_size(s->Stype))
                    {
                        case CHARSIZE:
                        case SHORTSIZE:
                            Ssize = 4;
                            break;
                        case FLOATSIZE:
                        case DOUBLESIZE:
#if TARGET_POWERPC
                                Ssize = LNGDBLSIZE;
#else
                            Ssize = (config.inline68881) ? LNGHDBLSIZE:LNGDBLSIZE;
#endif
                            break;
                        default:
                            assert(0);
                    }
                }
                else
                    Ssize = type_size(s->Stype);
#ifdef DEBUG
                if (debugx) dbg_printf("size=%d ",Ssize);
#endif
                Poffset = align(sizeof(targ_short),Poffset);
                                                /* align on short stack boundary */
                s->Sclass = SCparameter;        /* SCregpar used equivalently */
                s->Soffset = Poffset;
                if ( ((Ssize > LONGSIZE) || tyfloating(s->Sty)) &&
                   typasfunc(funcsym_p->Sty) )
                    {                           /* ptr to param was passed for pascal*/
                    s->Sfl = FLptr2param;       /* will need to copy into temporary for pascal */
                    s->Sflags &= ~GTregcand;    /* pascal long dbl ptrs to param float */
                    }
                if(Ssize == CHARSIZE)           /* 68000 stack must stay word aligned */
                    Poffset += CHARSIZE;
                if(tyintegral(tybasic(s->Sty)) && (Ssize > (tsize = size(s->Sty))) )
                    {
                    if(tsize == 1)
                        s->Soffset += 4-CHARSIZE;
                    else if(tsize == SHORTSIZE)
                        s->Soffset += 4-SHORTSIZE;
                    }
                Poffset += ((s->Sfl == FLptr2param) && (Ssize > LONGSIZE)) ? LONGSIZE:Ssize;
                }
#else
                if (tyf == TYifunc)
                {   s->Sflags |= SFLlivexit;
                    break;
                }
#endif
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
    if (mfoptim)
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
    assert(funcsym_p == sfunc);
    if (eecontext.EEcompile != 1)
    {
#if TX86
        if (symbol_iscomdat(sfunc))
        {
            csegsave = cseg;
            coffsetsave = Coffset;
            obj_comdat(sfunc);
        }
        else
            if (config.flags & CFGsegs) // if user set switch for this
            {
#if SCPP || TARGET_WINDOS
                obj_codeseg(cpp_mangle(funcsym_p),1);
#else
                obj_codeseg(funcsym_p->Sident, 1);
#endif
                                        // generate new code segment
            }
        cod3_align();                   // align start of function
#if ELFOBJ || MACHOBJ
        elf_func_start(sfunc);
#else
        sfunc->Sseg = cseg;             // current code seg
#endif
#elif TARGET_MAC
        Coffset = 0;                    // all PC relative from start of this module
#endif
        sfunc->Soffset = Coffset;       // offset of start of function
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
#if ELFOBJ || MACHOBJ
    elf_func_term(sfunc);
#endif
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
#endif
    if (eecontext.EEcompile == 1)
        goto Ldone;
    if (sfunc->Sclass == SCglobal)
    {
        char *id;

#if OMFOBJ
        if (!(config.flags4 & CFG4allcomdat))
            objpubdef(cseg,sfunc,sfunc->Soffset);       // make a public definition
#endif

#if SCPP && _WIN32
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

                L2:     objextdef(startup[i]);          // pull in startup code
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
        obj_export(sfunc,Poffset);      // export function definition

    if (config.fulltypes)
        cv_func(sfunc);                 // debug info for function

#if MARS
    /* After codgen() and writing debug info for the locals,
     * readjust the offsets of all stack variables so they
     * are relative to the frame pointer.
     * Necessary for nested function access to lexically enclosing frames.
     */
     cod3_adjSymOffsets();
#endif

#if OMFOBJ
    if (symbol_iscomdat(sfunc))         // if generated a COMDAT
        obj_setcodeseg(csegsave,coffsetsave);   // reset to real code seg
#endif

    /* Check if function is a constructor or destructor, by     */
    /* seeing if the function name starts with _STI or _STD     */
    {
#if _M_I86
        short *p;

        p = (short *) sfunc->Sident;
        if (p[0] == 'S_' && (p[1] == 'IT' || p[1] == 'DT'))
#else
        char *p;

        p = sfunc->Sident;
        if (p[0] == '_' && p[1] == 'S' && p[2] == 'T' &&
            (p[3] == 'I' || p[3] == 'D'))
#endif
#if !(TARGET_POWERPC)
            obj_funcptr(sfunc);
#else
                ;
#endif
    }

Ldone:
    funcsym_p = NULL;

#if SCPP
    // Free any added symbols
    freesymtab(globsym.tab,nsymbols,globsym.top);
#endif
    globsym.top = 0;

    //dbg_printf("done with writefunc()\n");
#if TX86
    util_free(dfo);
#else
    MEM_PARF_FREE(dfo);
#endif
    dfo = NULL;
#if TARGET_MAC
    release_temp_memory();              /* release temporary memory */
    PARSER = 1;
#endif
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
        obj_lidata(seg,Offset(seg),alignbytes);
#if OMFOBJ
    Offset(seg) += alignbytes;          /* offset of start of data      */
#endif
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

#if ELFOBJ
    /* MACHOBJ can't go here, because the const data segment goes into
     * the _TEXT segment, and one cannot have a fixup from _TEXT to _TEXT.
     */
    s = elf_sym_cdata(ty, (char *)p, len);
#else
    unsigned sz = tysize(ty);

    alignOffset(DATA, sz);
    s = symboldata(Doffset,ty | mTYconst);
    obj_write_bytes(SegData[DATA], len, p);
    //printf("s->Sseg = %d:x%x\n", s->Sseg, s->Soffset);
#endif
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


#if TARGET_MAC
#include "TGout.c"
#endif

#endif /* !SPP */
