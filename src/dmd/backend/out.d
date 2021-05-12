/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1984-1998 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/out.d, backend/out.d)
 */


module dmd.backend.dout;

version (SPP) { } else
{

import core.stdc.stdio;
import core.stdc.string;

import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.cgcv;
import dmd.backend.code;
import dmd.backend.code_x86;
import dmd.backend.cv4;
import dmd.backend.dt;
import dmd.backend.dlist;
import dmd.backend.mem;
import dmd.backend.el;
import dmd.backend.exh;
import dmd.backend.global;
import dmd.backend.goh;
import dmd.backend.obj;
import dmd.backend.oper;
import dmd.backend.outbuf;
import dmd.backend.rtlsym;
import dmd.backend.symtab;
import dmd.backend.ty;
import dmd.backend.type;

import dmd.backend.barray;

version (SCPP)
{
    import cpp;
    import msgs2;
    import parser;
}
version (HTOD)
{
    import cpp;
    import msgs2;
    import parser;
}

version (Windows)
{
    extern (C)
    {
        int stricmp(const(char)*, const(char)*) pure nothrow @nogc;
        int memicmp(const(void)*, const(void)*, size_t) pure nothrow @nogc;
    }
}

extern (C++):

nothrow:
@safe:

// Determine if this Symbol is stored in a COMDAT
@trusted
bool symbol_iscomdat2(Symbol* s)
{
    version (MARS)
    {
        return s.Sclass == SCcomdat ||
            config.flags2 & CFG2comdat && s.Sclass == SCinline ||
            config.flags4 & CFG4allcomdat && s.Sclass == SCglobal;
    }
    else
    {
        return s.Sclass == SCcomdat ||
            config.flags2 & CFG2comdat && s.Sclass == SCinline ||
            config.flags4 & CFG4allcomdat && (s.Sclass == SCglobal || s.Sclass == SCstatic);
    }
}

version (SCPP)
{

/**********************************
 * We put out an external definition.
 */
void out_extdef(Symbol *s)
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
    Obj.codeseg(csegname,0);
}

}

version (HTOD)
{
    void outcsegname(char *csegname) { }
}

/***********************************
 * Output function thunk.
 */
@trusted
extern (C) void outthunk(Symbol *sthunk,Symbol *sfunc,uint p,tym_t thisty,
        targ_size_t d,int i,targ_size_t d2)
{
version (HTOD) { } else
{
    sthunk.Sseg = cseg;
    cod3_thunk(sthunk,sfunc,p,thisty,cast(uint)d,i,cast(uint)d2);
    sthunk.Sfunc.Fflags &= ~Fpending;
    sthunk.Sfunc.Fflags |= Foutput;   /* mark it as having been output */
}
}


/***************************
 * Write out statically allocated data.
 * Input:
 *      s               symbol to be initialized
 */
@trusted
void outdata(Symbol *s)
{
version (HTOD)
{
    return;
}

    int seg;
    targ_size_t offset;
    int flags;
    const int codeseg = cseg;

    symbol_debug(s);

    debug
    debugy && printf("outdata('%s')\n",s.Sident.ptr);

    //printf("outdata('%s', ty=x%x)\n",s.Sident.ptr,s.Stype.Tty);
    //symbol_print(s);

    // Data segment variables are always live on exit from a function
    s.Sflags |= SFLlivexit;

    dt_t *dtstart = s.Sdt;
    s.Sdt = null;                      // it will be free'd
    targ_size_t datasize = 0;
    tym_t ty = s.ty();
version (SCPP)
{
    if (eecontext.EEcompile)
    {   s.Sfl = (s.ty() & mTYfar) ? FLfardata : FLextern;
        s.Sseg = UNKNOWN;
        goto Lret;                      // don't output any data
    }
}
    if (ty & mTYexport && config.wflags & WFexpdef && s.Sclass != SCstatic)
        objmod.export_symbol(s,0);        // export data definition
    for (dt_t *dt = dtstart; dt; dt = dt.DTnext)
    {
        //printf("\tdt = %p, dt = %d\n",dt,dt.dt);
        switch (dt.dt)
        {   case DT_abytes:
            {   // Put out the data for the string, and
                // reserve a spot for a pointer to that string
                datasize += size(dt.Dty);      // reserve spot for pointer to string
                if (tybasic(dt.Dty) == TYcptr)
                {   dt.DTseg = codeseg;
                    dt.DTabytes += Offset(codeseg);
                    goto L1;
                }
                else if (tybasic(dt.Dty) == TYfptr &&
                         dt.DTnbytes > config.threshold)
                {
version (SCPP)
{
                    {
                    targ_size_t foffset;
                    dt.DTseg = objmod.fardata(s.Sident.ptr,dt.DTnbytes,&foffset);
                    dt.DTabytes += foffset;
                    }
}
                L1:
                    objmod.write_bytes(SegData[dt.DTseg],dt.DTnbytes,dt.DTpbytes);
                    break;
                }
                else
                {
                    version (SCPP)
                        alignOffset(DATA, 2 << dt.DTalign);
                    version (MARS)
                        alignOffset(CDATA, 2 << dt.DTalign);
                    dt.DTabytes += objmod.data_readonly(cast(char*)dt.DTpbytes,dt.DTnbytes,&dt.DTseg);
                }
                break;
            }

            case DT_ibytes:
                datasize += dt.DTn;
                break;

            case DT_nbytes:
                //printf("DT_nbytes %d\n", dt.DTnbytes);
                datasize += dt.DTnbytes;
                break;

            case DT_azeros:
                /* A block of zeros
                 */
                //printf("DT_azeros %d\n", dt.DTazeros);
                datasize += dt.DTazeros;
                if (dt == dtstart && !dt.DTnext && s.Sclass != SCcomdat &&
                    (s.Sseg == UNKNOWN || s.Sseg <= UDATA))
                {   /* first and only, so put in BSS segment
                     */
                    switch (ty & mTYLINK)
                    {
version (SCPP)
{
                        case mTYfar:                    // if far data
                            s.Sseg = objmod.fardata(s.Sident.ptr,datasize,&s.Soffset);
                            s.Sfl = FLfardata;
                            break;
}

                        case mTYcs:
                            s.Sseg = codeseg;
                            Offset(codeseg) = _align(datasize,Offset(codeseg));
                            s.Soffset = Offset(codeseg);
                            Offset(codeseg) += datasize;
                            s.Sfl = FLcsdata;
                            break;

                        case mTYthreadData:
                            assert(config.objfmt == OBJ_MACH && I64);
                            goto case;
                        case mTYthread:
                        {   seg_data *pseg = objmod.tlsseg_bss();
                            s.Sseg = pseg.SDseg;
                            objmod.data_start(s, datasize, pseg.SDseg);
                            if (config.objfmt == OBJ_OMF)
                                pseg.SDoffset += datasize;
                            else
                                objmod.lidata(pseg.SDseg, pseg.SDoffset, datasize);
                            s.Sfl = FLtlsdata;
                            break;
                        }

                        default:
                            s.Sseg = UDATA;
                            objmod.data_start(s,datasize,UDATA);
                            objmod.lidata(s.Sseg,s.Soffset,datasize);
                            s.Sfl = FLudata;           // uninitialized data
                            break;
                    }
                    assert(s.Sseg && s.Sseg != UNKNOWN);
                    if (s.Sclass == SCglobal || (s.Sclass == SCstatic && config.objfmt != OBJ_OMF)) // if a pubdef to be done
                        objmod.pubdefsize(s.Sseg,s,s.Soffset,datasize);   // do the definition
                    searchfixlist(s);
                    if (config.fulltypes &&
                        !(s.Sclass == SCstatic && funcsym_p)) // not local static
                    {
                        if (config.objfmt == OBJ_ELF || config.objfmt == OBJ_MACH)
                            dwarf_outsym(s);
                        else
                            cv_outsym(s);
                    }
version (SCPP)
{
                    out_extdef(s);
}
                    goto Lret;
                }
                break;

            case DT_common:
                assert(!dt.DTnext);
                outcommon(s,dt.DTazeros);
                goto Lret;

            case DT_xoff:
            {   Symbol *sb = dt.DTsym;

                if (tyfunc(sb.ty()))
                {
version (SCPP)
{
                    nwc_mustwrite(sb);
}
                }
                else if (sb.Sdt)               // if initializer for symbol
{ if (!s.Sseg) s.Sseg = DATA;
                    outdata(sb);                // write out data for symbol
}
            }
                goto case;
            case DT_coff:
                datasize += size(dt.Dty);
                break;
            default:
                debug
                printf("dt = %p, dt = %d\n",dt,dt.dt);
                assert(0);
        }
    }

    if (s.Sclass == SCcomdat)          // if initialized common block
    {
        seg = objmod.comdatsize(s, datasize);
        switch (ty & mTYLINK)
        {
            case mTYfar:                // if far data
                s.Sfl = FLfardata;
                break;

            case mTYcs:
                s.Sfl = FLcsdata;
                break;

            case mTYnear:
            case 0:
                s.Sfl = FLdata;        // initialized data
                break;

            case mTYthread:
                s.Sfl = FLtlsdata;
                break;

            case mTYweakLinkage:
                s.Sfl = FLdata;        // initialized data
                break;

            default:
                assert(0);
        }
    }
    else
    {
      switch (ty & mTYLINK)
      {
version (SCPP)
{
        case mTYfar:                    // if far data
            seg = objmod.fardata(s.Sident.ptr,datasize,&s.Soffset);
            s.Sfl = FLfardata;
            break;
}

        case mTYcs:
            seg = codeseg;
            Offset(codeseg) = _align(datasize,Offset(codeseg));
            s.Soffset = Offset(codeseg);
            s.Sfl = FLcsdata;
            break;

        case mTYthreadData:
        {
            assert(config.objfmt == OBJ_MACH && I64);

            seg_data *pseg = objmod.tlsseg_data();
            s.Sseg = pseg.SDseg;
            objmod.data_start(s, datasize, s.Sseg);
            seg = pseg.SDseg;
            s.Sfl = FLtlsdata;
            break;
        }
        case mTYthread:
        {
            seg_data *pseg = objmod.tlsseg();
            s.Sseg = pseg.SDseg;
            objmod.data_start(s, datasize, s.Sseg);
            seg = pseg.SDseg;
            s.Sfl = FLtlsdata;
            break;
        }
        case mTYnear:
        case 0:
            if (
                s.Sseg == 0 ||
                s.Sseg == UNKNOWN)
                s.Sseg = DATA;
            seg = objmod.data_start(s,datasize,DATA);
            s.Sfl = FLdata;            // initialized data
            break;

        default:
            assert(0);
      }
    }
    if (s.Sseg == UNKNOWN && (config.objfmt == OBJ_ELF || config.objfmt == OBJ_MACH))
        s.Sseg = seg;
    else if (config.objfmt == OBJ_OMF)
        s.Sseg = seg;
    else
        seg = s.Sseg;

    if (s.Sclass == SCglobal || (s.Sclass == SCstatic && config.objfmt != OBJ_OMF))
        objmod.pubdefsize(seg,s,s.Soffset,datasize);    /* do the definition            */

    assert(s.Sseg != UNKNOWN);
    if (config.fulltypes &&
        !(s.Sclass == SCstatic && funcsym_p)) // not local static
    {
        if (config.objfmt == OBJ_ELF || config.objfmt == OBJ_MACH)
            dwarf_outsym(s);
        else
            cv_outsym(s);
    }
    searchfixlist(s);

    /* Go back through list, now that we know its size, and send out    */
    /* the data.                                                        */

    offset = s.Soffset;

    dt_writeToObj(objmod, dtstart, seg, offset);
    Offset(seg) = offset;
version (SCPP)
{
    out_extdef(s);
}
Lret:
    dt_free(dtstart);
}


/********************************************
 * Write dt to Object file.
 * Params:
 *      objmod = reference to object file
 *      dt = data to write
 *      seg = segment to write it to
 *      offset = starting offset in segment - will get updated to reflect ending offset
 */

@trusted
void dt_writeToObj(Obj objmod, dt_t *dt, int seg, ref targ_size_t offset)
{
    for (; dt; dt = dt.DTnext)
    {
        switch (dt.dt)
        {
            case DT_abytes:
            {
                int flags;
                if (tyreg(dt.Dty))
                    flags = CFoff;
                else
                    flags = CFoff | CFseg;
                if (I64)
                    flags |= CFoffset64;
                if (tybasic(dt.Dty) == TYcptr)
                    objmod.reftocodeseg(seg,offset,dt.DTabytes);
                else
                {
if (config.exe & EX_posix)
{
                    objmod.reftodatseg(seg,offset,dt.DTabytes,dt.DTseg,flags);
}
else
{
                    if (dt.DTseg == DATA)
                        objmod.reftodatseg(seg,offset,dt.DTabytes,DATA,flags);
                    else
                    {
version (MARS)
{
                        if (dt.DTseg == CDATA)
                            objmod.reftodatseg(seg,offset,dt.DTabytes,CDATA,flags);
                        else
                            objmod.reftofarseg(seg,offset,dt.DTabytes,dt.DTseg,flags);
}
else
{
                        objmod.reftofarseg(seg,offset,dt.DTabytes,dt.DTseg,flags);
}
                    }
}
                }
                offset += size(dt.Dty);
                break;
            }

            case DT_ibytes:
                objmod.bytes(seg,offset,dt.DTn,dt.DTdata.ptr);
                offset += dt.DTn;
                break;

            case DT_nbytes:
                objmod.bytes(seg,offset,dt.DTnbytes,dt.DTpbytes);
                offset += dt.DTnbytes;
                break;

            case DT_azeros:
                //printf("objmod.lidata(seg = %d, offset = %d, azeros = %d)\n", seg, offset, dt.DTazeros);
                SegData[seg].SDoffset = offset;
                objmod.lidata(seg,offset,dt.DTazeros);
                offset = SegData[seg].SDoffset;
                break;

            case DT_xoff:
            {
                Symbol *sb = dt.DTsym;          // get external symbol pointer
                targ_size_t a = dt.DToffset;    // offset from it
                int flags;
                if (tyreg(dt.Dty))
                    flags = CFoff;
                else
                    flags = CFoff | CFseg;
                if (I64 && tysize(dt.Dty) == 8)
                    flags |= CFoffset64;
                offset += objmod.reftoident(seg,offset,sb,a,flags);
                break;
            }

            case DT_coff:
                objmod.reftocodeseg(seg,offset,dt.DToffset);
                offset += _tysize[TYint];
                break;

            default:
                //printf("dt = %p, dt = %d\n",dt,dt.dt);
                assert(0);
        }
    }
}


/******************************
 * Output n bytes of a common block, n > 0.
 */

@trusted
void outcommon(Symbol *s,targ_size_t n)
{
    //printf("outcommon('%s',%d)\n",s.Sident.ptr,n);
    if (n != 0)
    {
        assert(s.Sclass == SCglobal);
        if (s.ty() & mTYcs) // if store in code segment
        {
            /* COMDEFs not supported in code segment
             * so put them out as initialized 0s
             */
            auto dtb = DtBuilder(0);
            dtb.nzeros(cast(uint)n);
            s.Sdt = dtb.finish();
            outdata(s);
version (SCPP)
{
            out_extdef(s);
}
        }
        else if (s.ty() & mTYthread) // if store in thread local segment
        {
            if (config.objfmt == OBJ_ELF)
            {
                s.Sclass = SCcomdef;
                objmod.common_block(s, 0, n, 1);
            }
            else
            {
                /* COMDEFs not supported in tls segment
                 * so put them out as COMDATs with initialized 0s
                 */
                s.Sclass = SCcomdat;
                auto dtb = DtBuilder(0);
                dtb.nzeros(cast(uint)n);
                s.Sdt = dtb.finish();
                outdata(s);
version (SCPP)
{
                if (config.objfmt == OBJ_OMF)
                    out_extdef(s);
}
            }
        }
        else
        {
            s.Sclass = SCcomdef;
            if (config.objfmt == OBJ_OMF)
            {
                s.Sxtrnnum = objmod.common_block(s,(s.ty() & mTYfar) == 0,n,1);
                if (s.ty() & mTYfar)
                    s.Sfl = FLfardata;
                else
                    s.Sfl = FLextern;
                s.Sseg = UNKNOWN;
                pstate.STflags |= PFLcomdef;
version (SCPP)
{
                ph_comdef(s);               // notify PH that a COMDEF went out
}
            }
            else
                objmod.common_block(s, 0, n, 1);
        }
        if (config.fulltypes)
        {
            if (config.objfmt == OBJ_ELF || config.objfmt == OBJ_MACH)
                dwarf_outsym(s);
            else
                cv_outsym(s);
        }
    }
}

/*************************************
 * Mark a Symbol as going into a read-only segment.
 */

@trusted
void out_readonly(Symbol *s)
{
    if (config.objfmt == OBJ_ELF || config.objfmt == OBJ_MACH)
    {
        /* Cannot have pointers in CDATA when compiling PIC code, because
         * they require dynamic relocations of the read-only segment.
         * Instead use the .data.rel.ro section.
         * https://issues.dlang.org/show_bug.cgi?id=11171
         */
        if (config.flags3 & CFG3pic && dtpointers(s.Sdt))
            s.Sseg = CDATAREL;
        else
            s.Sseg = CDATA;
    }
    else
    {
        s.Sseg = CDATA;
    }
}

/*************************************
 * Write out a readonly string literal in an implementation-defined
 * manner.
 * Params:
 *      str = pointer to string data (need not have terminating 0)
 *      len = number of characters in string
 *      sz = size of each character (1, 2 or 4)
 * Returns: a Symbol pointing to it.
 */
@trusted
Symbol *out_string_literal(const(char)* str, uint len, uint sz)
{
    tym_t ty = TYchar;
    if (sz == 2)
        ty = TYchar16;
    else if (sz == 4)
        ty = TYdchar;
    Symbol *s = symbol_generate(SCstatic,type_static_array(len, tstypes[ty]));
    switch (config.objfmt)
    {
        case OBJ_ELF:
        case OBJ_MACH:
            s.Sseg = objmod.string_literal_segment(sz);
            break;

        case OBJ_MSCOFF:
        case OBJ_OMF:   // goes into COMDATs, handled elsewhere
        default:
            assert(0);
    }

    /* If there are any embedded zeros, this can't go in the special string segments
     * which assume that 0 is the end of the string.
     */
    switch (sz)
    {
        case 1:
            if (memchr(str, 0, len))
                s.Sseg = CDATA;
            break;

        case 2:
            foreach (i; 0 .. len)
            {
                auto p = cast(const(ushort)*)str;
                if (p[i] == 0)
                {
                    s.Sseg = CDATA;
                    break;
                }
            }
            break;

        case 4:
            foreach (i; 0 .. len)
            {
                auto p = cast(const(uint)*)str;
                if (p[i] == 0)
                {
                    s.Sseg = CDATA;
                    break;
                }
            }
            break;

        default:
            assert(0);
    }

    auto dtb = DtBuilder(0);
    dtb.nbytes(cast(uint)(len * sz), str);
    dtb.nzeros(cast(uint)sz);       // include terminating 0
    s.Sdt = dtb.finish();
    s.Sfl = FLdata;
    s.Salignment = sz;
    outdata(s);
    return s;
}


/******************************
 * Walk expression tree, converting it from a PARSER tree to
 * a code generator tree.
 */

@trusted
/*private*/ void outelem(elem *e, ref bool addressOfParam)
{
    Symbol *s;
    tym_t tym;
    elem *e1;
version (SCPP)
{
    type *t;
}

again:
    assert(e);
    elem_debug(e);

debug
{
    if (OTbinary(e.Eoper))
        assert(e.EV.E1 && e.EV.E2);
//    else if (OTunary(e.Eoper))
//      assert(e.EV.E1 && !e.EV.E2);
}

version (SCPP)
{
    t = e.ET;
    assert(t);
    type_debug(t);
    tym = t.Tty;
    switch (tybasic(tym))
    {
        case TYstruct:
            t.Tcount++;
            break;

        case TYarray:
            t.Tcount++;
            break;

        case TYbool:
        case TYwchar_t:
        case TYchar16:
        case TYmemptr:
        case TYvtshape:
        case TYnullptr:
            tym = tym_conv(t);
            e.ET = null;
            break;

        case TYenum:
            tym = tym_conv(t.Tnext);
            e.ET = null;
            break;

        default:
            e.ET = null;
            break;
    }
    e.Nflags = 0;
    e.Ety = tym;
}

    switch (e.Eoper)
    {
    default:
    Lop:
debug
{
        //if (!EOP(e)) printf("e.Eoper = x%x\n",e.Eoper);
}
        if (OTbinary(e.Eoper))
        {   outelem(e.EV.E1, addressOfParam);
            e = e.EV.E2;
        }
        else if (OTunary(e.Eoper))
        {
            e = e.EV.E1;
        }
        else
            break;
version (SCPP)
{
        type_free(t);
}
        goto again;                     /* iterate instead of recurse   */
    case OPaddr:
        e1 = e.EV.E1;
        if (e1.Eoper == OPvar)
        {   // Fold into an OPrelconst
version (SCPP)
{
            el_copy(e,e1);
            e.ET = t;
}
else
{
            tym = e.Ety;
            el_copy(e,e1);
            e.Ety = tym;
}
            e.Eoper = OPrelconst;
            el_free(e1);
            goto again;
        }
        goto Lop;

    case OPrelconst:
    case OPvar:
    L6:
        s = e.EV.Vsym;
        assert(s);
        symbol_debug(s);
        switch (s.Sclass)
        {
            case SCregpar:
            case SCparameter:
            case SCshadowreg:
                if (e.Eoper == OPrelconst)
                {
                    if (I16)
                        addressOfParam = true;   // taking addr of param list
                    else
                        s.Sflags &= ~(SFLunambig | GTregcand);
                }
                break;

            case SCstatic:
            case SClocstat:
            case SCextern:
            case SCglobal:
            case SCcomdat:
            case SCcomdef:
            case SCpseudo:
            case SCinline:
            case SCsinline:
            case SCeinline:
                s.Sflags |= SFLlivexit;
                goto case;
            case SCauto:
            case SCregister:
            case SCfastpar:
            case SCbprel:
                if (e.Eoper == OPrelconst)
                {
                    s.Sflags &= ~(SFLunambig | GTregcand);
                }
                else if (s.ty() & mTYfar)
                    e.Ety |= mTYfar;
                break;
version (SCPP)
{
            case SCmember:
                err_noinstance(s.Sscope,s);
                goto L5;

            case SCstruct:
                cpperr(EM_no_instance,s.Sident.ptr);       // no instance of class
            L5:
                e.Eoper = OPconst;
                e.Ety = TYint;
                return;

            case SCfuncalias:
                e.EV.Vsym = s.Sfunc.Falias;
                goto L6;

            case SCstack:
                break;

            case SCfunctempl:
                cpperr(EM_no_template_instance, s.Sident.ptr);
                break;

            default:
                symbol_print(s);
                WRclass(cast(SC) s.Sclass);
                assert(0);
}
else
{
            default:
                break;
}
        }
version (SCPP)
{
        if (tyfunc(s.ty()))
        {
            nwc_mustwrite(s);           /* must write out function      */
        }
        else if (s.Sdt)                /* if initializer for symbol    */
            outdata(s);                 // write out data for symbol
        if (config.flags3 & CFG3pic)
        {
            objmod.gotref(s);
        }
}
        break;

    case OPstring:
    case OPconst:
    case OPstrthis:
        break;

    case OPsizeof:
version (SCPP)
{
        e.Eoper = OPconst;
        e.EV.Vlong = type_size(e.EV.Vsym.Stype);
        break;
}
else
{
        assert(0);
}

version (SCPP)
{
    case OPstreq:
    case OPstrpar:
    case OPstrctor:
        type_size(e.EV.E1.ET);
        goto Lop;

    case OPasm:
        break;

    case OPctor:
        nwc_mustwrite(e.EV.Edtor);
        goto case;
    case OPdtor:
        // Don't put 'this' pointers in registers if we need
        // them for EH stack cleanup.
        e1 = e.EV.E1;
        elem_debug(e1);
        if (e1.Eoper == OPadd)
            e1 = e1.EV.E1;
        if (e1.Eoper == OPvar)
            e1.EV.Vsym.Sflags &= ~GTregcand;
        goto Lop;

    case OPmark:
        break;
}
    }
version (SCPP)
{
    type_free(t);
}
}

/*************************************
 * Determine register candidates.
 */

@trusted
void out_regcand(symtab_t *psymtab)
{
    //printf("out_regcand()\n");
    const bool ifunc = (tybasic(funcsym_p.ty()) == TYifunc);
    for (SYMIDX si = 0; si < psymtab.length; si++)
    {   Symbol *s = (*psymtab)[si];

        symbol_debug(s);
        //assert(sytab[s.Sclass] & SCSS);      // only stack variables
        s.Ssymnum = si;                        // Ssymnum trashed by cpp_inlineexpand
        if (!(s.ty() & (mTYvolatile | mTYshared)) &&
            !(ifunc && (s.Sclass == SCparameter || s.Sclass == SCregpar)) &&
            s.Sclass != SCstatic)
            s.Sflags |= (GTregcand | SFLunambig);      // assume register candidate
        else
            s.Sflags &= ~(GTregcand | SFLunambig);
    }

    bool addressOfParam = false;                  // haven't taken addr of param yet
    for (block *b = startblock; b; b = b.Bnext)
    {
        if (b.Belem)
            out_regcand_walk(b.Belem, addressOfParam);

        // Any assembler blocks make everything ambiguous
        if (b.BC == BCasm)
            for (SYMIDX si = 0; si < psymtab.length; si++)
                (*psymtab)[si].Sflags &= ~(SFLunambig | GTregcand);
    }

    // If we took the address of one parameter, assume we took the
    // address of all non-register parameters.
    if (addressOfParam)                      // if took address of a parameter
    {
        for (SYMIDX si = 0; si < psymtab.length; si++)
            if ((*psymtab)[si].Sclass == SCparameter || (*psymtab)[si].Sclass == SCshadowreg)
                (*psymtab)[si].Sflags &= ~(SFLunambig | GTregcand);
    }

}

@trusted
private void out_regcand_walk(elem *e, ref bool addressOfParam)
{
    while (1)
    {   elem_debug(e);

        if (OTbinary(e.Eoper))
        {   if (e.Eoper == OPstreq)
            {   if (e.EV.E1.Eoper == OPvar)
                {
                    Symbol *s = e.EV.E1.EV.Vsym;
                    s.Sflags &= ~(SFLunambig | GTregcand);
                }
                if (e.EV.E2.Eoper == OPvar)
                {
                    Symbol *s = e.EV.E2.EV.Vsym;
                    s.Sflags &= ~(SFLunambig | GTregcand);
                }
            }
            out_regcand_walk(e.EV.E1, addressOfParam);
            e = e.EV.E2;
        }
        else if (OTunary(e.Eoper))
        {
            // Don't put 'this' pointers in registers if we need
            // them for EH stack cleanup.
            if (e.Eoper == OPctor)
            {   elem *e1 = e.EV.E1;

                if (e1.Eoper == OPadd)
                    e1 = e1.EV.E1;
                if (e1.Eoper == OPvar)
                    e1.EV.Vsym.Sflags &= ~GTregcand;
            }
            e = e.EV.E1;
        }
        else
        {   if (e.Eoper == OPrelconst)
            {
                Symbol *s = e.EV.Vsym;
                assert(s);
                symbol_debug(s);
                switch (s.Sclass)
                {
                    case SCregpar:
                    case SCparameter:
                    case SCshadowreg:
                        if (I16)
                            addressOfParam = true;       // taking addr of param list
                        else
                            s.Sflags &= ~(SFLunambig | GTregcand);
                        break;

                    case SCauto:
                    case SCregister:
                    case SCfastpar:
                    case SCbprel:
                        s.Sflags &= ~(SFLunambig | GTregcand);
                        break;

                    default:
                        break;
                }
            }
            else if (e.Eoper == OPvar)
            {
                if (e.EV.Voffset)
                {   if (!(e.EV.Voffset == 1 && tybyte(e.Ety)) &&
                        !(e.EV.Voffset == REGSIZE && tysize(e.Ety) == REGSIZE))
                    {
                        e.EV.Vsym.Sflags &= ~GTregcand;
                    }
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

@trusted
void writefunc(Symbol *sfunc)
{
version (HTOD)
{
    return;
}
else version (SCPP)
{
    writefunc2(sfunc);
}
else
{
    cstate.CSpsymtab = &globsym;
    writefunc2(sfunc);
    cstate.CSpsymtab = null;
}
}

@trusted
private void writefunc2(Symbol *sfunc)
{
    func_t *f = sfunc.Sfunc;

    //printf("writefunc(%s)\n",sfunc.Sident.ptr);
    debug debugy && printf("writefunc(%s)\n",sfunc.Sident.ptr);
version (SCPP)
{
    if (CPP)
    {

    // If constructor or destructor, make sure it has been fixed.
    if (f.Fflags & (Fctor | Fdtor))
        assert(errcnt || f.Fflags & Ffixed);

    // If this function is the 'trigger' to output the vtbl[], do so
    if (f.Fflags3 & Fvtblgen && !eecontext.EEcompile)
    {
        Classsym *stag = cast(Classsym *) sfunc.Sscope;
        {
            SC scvtbl;

            scvtbl = cast(SC) ((config.flags2 & CFG2comdat) ? SCcomdat : SCglobal);
            n2_genvtbl(stag,scvtbl,1);
            n2_genvbtbl(stag,scvtbl,1);
            if (config.exe & EX_windos)
            {
                if (config.fulltypes == CV4)
                    cv4_struct(stag,2);
            }
        }
    }
    }
}

    /* Signify that function has been output                    */
    /* (before inline_do() to prevent infinite recursion!)      */
    f.Fflags &= ~Fpending;
    f.Fflags |= Foutput;

version (SCPP)
{
    if (errcnt)
        return;
}

    if (eecontext.EEcompile && eecontext.EEfunc != sfunc)
        return;

    /* Copy local symbol table onto main one, making sure       */
    /* that the symbol numbers are adjusted accordingly */
    //printf("f.Flocsym.length = %d\n",f.Flocsym.length);
    debug debugy && printf("appending symbols to symtab...\n");
    const nsymbols = f.Flocsym.length;
    globsym.setLength(nsymbols);
    foreach (si; 0 .. nsymbols)
        globsym[si] = f.Flocsym[si];

    assert(startblock == null);
    if (f.Fflags & Finline)            // if keep function around
    {   // Generate copy of function

        block **pb = &startblock;
        for (block *bf = f.Fstartblock; bf; bf = bf.Bnext)
        {
            block *b = block_calloc();
            *pb = b;
            pb = &b.Bnext;

            *b = *bf;
            assert(b.numSucc() == 0);
            assert(!b.Bpred);
            b.Belem = el_copytree(b.Belem);
        }
    }
    else
    {   startblock = sfunc.Sfunc.Fstartblock;
        sfunc.Sfunc.Fstartblock = null;
    }
    assert(startblock);

    /* Do any in-line expansion of function calls inside sfunc  */
version (SCPP)
{
    inline_do(sfunc);
}

version (SCPP)
{
    /* If function is _STIxxxx, add in the auto destructors             */
    if (cpp_stidtors && memcmp("__SI".ptr,sfunc.Sident.ptr,4) == 0)
    {
        assert(startblock.Bnext == null);
        list_t el = cpp_stidtors;
        do
        {
            startblock.Belem = el_combine(startblock.Belem,list_elem(el));
            el = list_next(el);
        } while (el);
        list_free(&cpp_stidtors,FPNULL);
    }
}
    assert(funcsym_p == null);
    funcsym_p = sfunc;
    tym_t tyf = tybasic(sfunc.ty());

version (SCPP)
{
    out_extdef(sfunc);
}

    // TX86 computes parameter offsets in stackoffsets()
    //printf("globsym.length = %d\n", globsym.length);

version (SCPP)
{
    FuncParamRegs fpr = FuncParamRegs_create(tyf);
}

    for (SYMIDX si = 0; si < globsym.length; si++)
    {   Symbol *s = globsym[si];

        symbol_debug(s);
        //printf("symbol %d '%s'\n",si,s.Sident.ptr);

        type_size(s.Stype);    // do any forward template instantiations

        s.Ssymnum = si;        // Ssymnum trashed by cpp_inlineexpand
        s.Sflags &= ~(SFLunambig | GTregcand);
        switch (s.Sclass)
        {
            case SCbprel:
                s.Sfl = FLbprel;
                goto L3;

            case SCauto:
            case SCregister:
                s.Sfl = FLauto;
                goto L3;

version (SCPP)
{
            case SCfastpar:
            case SCregpar:
            case SCparameter:
                if (si == 0 && FuncParamRegs_alloc(fpr, s.Stype, s.Stype.Tty, &s.Spreg, &s.Spreg2))
                {
                    assert(s.Spreg == ((tyf == TYmfunc) ? CX : AX));
                    assert(s.Spreg2 == NOREG);
                    assert(si == 0);
                    s.Sclass = SCfastpar;
                    s.Sfl = FLfast;
                    goto L3;
                }
                assert(s.Sclass != SCfastpar);
}
else
{
            case SCfastpar:
                s.Sfl = FLfast;
                goto L3;

            case SCregpar:
            case SCparameter:
            case SCshadowreg:
}
                s.Sfl = FLpara;
                if (tyf == TYifunc)
                {   s.Sflags |= SFLlivexit;
                    break;
                }
            L3:
                if (!(s.ty() & (mTYvolatile | mTYshared)))
                    s.Sflags |= GTregcand | SFLunambig; // assume register candidate   */
                break;

            case SCpseudo:
                s.Sfl = FLpseudo;
                break;

            case SCstatic:
                break;                  // already taken care of by datadef()

            case SCstack:
                s.Sfl = FLstack;
                break;

            default:
                symbol_print(s);
                assert(0);
        }
    }

    bool addressOfParam = false;  // see if any parameters get their address taken
    bool anyasm = false;
    for (block *b = startblock; b; b = b.Bnext)
    {
        memset(&b._BLU,0,block.sizeof - block._BLU.offsetof);
        if (b.Belem)
        {   outelem(b.Belem, addressOfParam);
version (SCPP)
{
            if (!el_returns(b.Belem) && !(config.flags3 & CFG3eh))
            {   b.BC = BCexit;
                list_free(&b.Bsucc,FPNULL);
            }
}
version (MARS)
{
            if (b.Belem.Eoper == OPhalt)
            {   b.BC = BCexit;
                list_free(&b.Bsucc,FPNULL);
            }
}
        }
        if (b.BC == BCasm)
            anyasm = true;
        if (sfunc.Sflags & SFLexit && (b.BC == BCret || b.BC == BCretexp))
        {   b.BC = BCexit;
            list_free(&b.Bsucc,FPNULL);
        }
        assert(b != b.Bnext);
    }
    PARSER = 0;
    if (eecontext.EEelem)
    {
        const marksi = globsym.length;
        eecontext.EEin++;
        outelem(eecontext.EEelem, addressOfParam);
        eecontext.EEelem = doptelem(eecontext.EEelem,true);
        eecontext.EEin--;
        eecontext_convs(marksi);
    }

    // If we took the address of one parameter, assume we took the
    // address of all non-register parameters.
    if (addressOfParam | anyasm)        // if took address of a parameter
    {
        for (SYMIDX si = 0; si < globsym.length; si++)
            if (anyasm || globsym[si].Sclass == SCparameter)
                globsym[si].Sflags &= ~(SFLunambig | GTregcand);
    }

    block_pred();                       // compute predecessors to blocks
    block_compbcount();                 // eliminate unreachable blocks
    if (go.mfoptim)
    {   OPTIMIZER = 1;
        optfunc();                      /* optimize function            */
        OPTIMIZER = 0;
    }
    else
    {
        //printf("blockopt()\n");
        blockopt(0);                    /* optimize                     */
    }

version (SCPP)
{
    if (CPP)
    {
        version (DEBUG_XSYMGEN)
        {
            /* the internal dataview function is allowed to lie about its return value */
            enum noret = compile_state != kDataView;
        }
        else
            enum noret = true;

        // Look for any blocks that return nothing.
        // Do it after optimization to eliminate any spurious
        // messages like the implicit return on { while(1) { ... } }
        if (tybasic(funcsym_p.Stype.Tnext.Tty) != TYvoid &&
            !(funcsym_p.Sfunc.Fflags & (Fctor | Fdtor | Finvariant))
            && noret
           )
        {
            char err = 0;
            for (block *b = startblock; b; b = b.Bnext)
            {   if (b.BC == BCasm)     // no errors if any asm blocks
                    err |= 2;
                else if (b.BC == BCret)
                    err |= 1;
            }
            if (err == 1)
                func_noreturnvalue();
        }
    }
}
    assert(funcsym_p == sfunc);
    const int CSEGSAVE_DEFAULT = -10_000;        // some unlikely number
    int csegsave = CSEGSAVE_DEFAULT;
    if (eecontext.EEcompile != 1)
    {
        if (symbol_iscomdat2(sfunc))
        {
            csegsave = cseg;
            objmod.comdat(sfunc);
            cseg = sfunc.Sseg;
        }
        else if (config.flags & CFGsegs) // if user set switch for this
        {
            version (SCPP)
                objmod.codeseg(cpp_mangle(funcsym_p),1);
            else
                objmod.codeseg(&funcsym_p.Sident[0], 1);
                                        // generate new code segment
        }
        cod3_align(cseg);               // align start of function
version (HTOD) { } else
{
        objmod.func_start(sfunc);
}
        searchfixlist(sfunc);           // backpatch any refs to this function
    }

    //printf("codgen()\n");
version (SCPP)
{
    if (!errcnt)
        codgen(sfunc);                  // generate code
}
else
{
    codgen(sfunc);                  // generate code
}
    //printf("after codgen for %s Coffset %x\n",sfunc.Sident.ptr,Offset(cseg));
    blocklist_free(&startblock);
version (SCPP)
{
    PARSER = 1;
}
version (HTOD) { } else
{
    objmod.func_term(sfunc);
}
    if (eecontext.EEcompile == 1)
        goto Ldone;
    if (sfunc.Sclass == SCglobal)
    {
        if ((config.objfmt == OBJ_OMF || config.objfmt == OBJ_MSCOFF) && !(config.flags4 & CFG4allcomdat))
        {
            assert(sfunc.Sseg == cseg);
            objmod.pubdef(sfunc.Sseg,sfunc,sfunc.Soffset);       // make a public definition
        }

version (SCPP)
{
version (Win32)
{
        // Determine which startup code to reference
        if (!CPP || !isclassmember(sfunc))              // if not member function
        {   __gshared const(char)*[6] startup =
            [   "__acrtused","__acrtused_winc","__acrtused_dll",
                "__acrtused_con","__wacrtused","__wacrtused_con",
            ];
            int i;

            const(char)* id = sfunc.Sident.ptr;
            switch (id[0])
            {
                case 'D': if (strcmp(id,"DllMain"))
                                break;
                          if (config.exe == EX_WIN32)
                          {     i = 2;
                                goto L2;
                          }
                          break;

                case 'm': if (strcmp(id,"main"))
                                break;
                          if (config.exe == EX_WIN32)
                                i = 3;
                          else if (config.wflags & WFwindows)
                                i = 1;
                          else
                                i = 0;
                          goto L2;

                case 'w': if (strcmp(id,"wmain") == 0)
                          {
                                if (config.exe == EX_WIN32)
                                {   i = 5;
                                    goto L2;
                                }
                                break;
                          }
                          goto case;
                case 'W': if (stricmp(id,"WinMain") == 0)
                          {
                                i = 0;
                                goto L2;
                          }
                          if (stricmp(id,"wWinMain") == 0)
                          {
                                if (config.exe == EX_WIN32)
                                {   i = 4;
                                    goto L2;
                                }
                          }
                          break;

                case 'L':
                case 'l': if (stricmp(id,"LibMain"))
                                break;
                          if (config.exe != EX_WIN32 && config.wflags & WFwindows)
                          {     i = 2;
                                goto L2;
                          }
                          break;

                L2:     objmod.external_def(startup[i]);          // pull in startup code
                        break;

                default:
                    break;
            }
        }
}
}
    }
    if (config.wflags & WFexpdef &&
        sfunc.Sclass != SCstatic &&
        sfunc.Sclass != SCsinline &&
        !(sfunc.Sclass == SCinline && !(config.flags2 & CFG2comdat)) &&
        sfunc.ty() & mTYexport)
        objmod.export_symbol(sfunc,cast(uint)Para.offset);      // export function definition

    if (config.fulltypes && config.fulltypes != CV8)
    {
        if (config.objfmt == OBJ_OMF || config.objfmt == OBJ_MSCOFF)
            cv_func(sfunc);                 // debug info for function
    }

version (MARS)
{
    /* This is to make uplevel references to SCfastpar variables
     * from nested functions work.
     */
    for (SYMIDX si = 0; si < globsym.length; si++)
    {
        Symbol *s = globsym[si];

        switch (s.Sclass)
        {   case SCfastpar:
                s.Sclass = SCauto;
                break;

            default:
                break;
        }
    }
    /* After codgen() and writing debug info for the locals,
     * readjust the offsets of all stack variables so they
     * are relative to the frame pointer.
     * Necessary for nested function access to lexically enclosing frames.
     */
     cod3_adjSymOffsets();
}

    if (symbol_iscomdat2(sfunc))         // if generated a COMDAT
    {
        assert(csegsave != CSEGSAVE_DEFAULT);
        objmod.setcodeseg(csegsave);       // reset to real code seg
        if (config.objfmt == OBJ_MACH)
            assert(cseg == CODE);
    }

    /* Check if function is a constructor or destructor, by     */
    /* seeing if the function name starts with _STI or _STD     */
    {
version (LittleEndian)
{
        short *p = cast(short *) sfunc.Sident.ptr;
        if (p[0] == (('S' << 8) | '_') && (p[1] == (('I' << 8) | 'T') || p[1] == (('D' << 8) | 'T')))
            objmod.setModuleCtorDtor(sfunc, sfunc.Sident.ptr[3] == 'I');
}
else
{
        char *p = sfunc.Sident.ptr;
        if (p[0] == '_' && p[1] == 'S' && p[2] == 'T' &&
            (p[3] == 'I' || p[3] == 'D'))
            objmod.setModuleCtorDtor(sfunc, sfunc.Sident.ptr[3] == 'I');
}
    }

Ldone:
    funcsym_p = null;

version (SCPP)
{
    // Free any added symbols
    freesymtab(globsym[].ptr,nsymbols,globsym.length);
}
    globsym.setLength(0);

    //printf("done with writefunc()\n");
    //dfo.dtor();       // save allocation for next time
}

/*************************
 * Align segment offset.
 * Input:
 *      seg             segment to be aligned
 *      datasize        size in bytes of object to be aligned
 */

@trusted
void alignOffset(int seg,targ_size_t datasize)
{
    targ_size_t alignbytes = _align(datasize,Offset(seg)) - Offset(seg);
    //printf("seg %d datasize = x%x, Offset(seg) = x%x, alignbytes = x%x\n",
      //seg,datasize,Offset(seg),alignbytes);
    if (alignbytes)
        objmod.lidata(seg,Offset(seg),alignbytes);
}

/***************************************
 * Write data into read-only data segment.
 * Return symbol for it.
 */

enum ROMAX = 32;
struct Readonly
{
    Symbol *sym;
    size_t length;
    ubyte[ROMAX] p;
}

enum RMAX = 16;
private __gshared
{
    Readonly[RMAX] readonly;
    size_t readonly_length;
    size_t readonly_i;
}

@trusted
void out_reset()
{
    readonly_length = 0;
    readonly_i = 0;
}

@trusted
Symbol *out_readonly_sym(tym_t ty, void *p, int len)
{
version (HTOD)
{
    return null;
}
else
{
static if (0)
{
    printf("out_readonly_sym(ty = x%x)\n", ty);
    for (int i = 0; i < len; i++)
        printf(" [%d] = %02x\n", i, (cast(ubyte*)p)[i]);
}
    // Look for previous symbol we can reuse
    for (int i = 0; i < readonly_length; i++)
    {
        Readonly *r = &readonly[i];
        if (r.length == len && memcmp(p, r.p.ptr, len) == 0)
            return r.sym;
    }

    Symbol *s;

version (MARS)
{
    bool cdata = config.objfmt == OBJ_ELF ||
                 config.objfmt == OBJ_OMF ||
                 config.objfmt == OBJ_MSCOFF;
}
else
{
    bool cdata = config.objfmt == OBJ_ELF;
}
    if (cdata)
    {
        /* MACHOBJ can't go here, because the const data segment goes into
         * the _TEXT segment, and one cannot have a fixup from _TEXT to _TEXT.
         */
        s = objmod.sym_cdata(ty, cast(char *)p, len);
    }
    else
    {
        uint sz = tysize(ty);

        alignOffset(DATA, sz);
        s = symboldata(Offset(DATA),ty | mTYconst);
        s.Sseg = DATA;
        objmod.write_bytes(SegData[DATA], len, p);
        //printf("s.Sseg = %d:x%x\n", s.Sseg, s.Soffset);
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
        r.length = len;
        r.sym = s;
        memcpy(r.p.ptr, p, len);
    }
    return s;
}
}

/*************************************
 * Output Symbol as a readonly comdat.
 * Params:
 *      s = comdat symbol
 *      p = pointer to the data to write
 *      len = length of that data
 *      nzeros = number of trailing zeros to append
 */
@trusted
void out_readonly_comdat(Symbol *s, const(void)* p, uint len, uint nzeros)
{
    objmod.readonly_comdat(s);         // create comdat segment
    objmod.write_bytes(SegData[s.Sseg], len, cast(void *)p);
    objmod.lidata(s.Sseg, len, nzeros);
}

@trusted
void Srcpos_print(ref const Srcpos srcpos, const(char)* func)
{
    printf("%s(", func);
version (MARS)
{
    printf("Sfilename = %s", srcpos.Sfilename ? srcpos.Sfilename : "null".ptr);
}
else
{
    const sf = srcpos.Sfilptr ? *srcpos.Sfilptr : null;
    printf("Sfilptr = %p (filename = %s)", sf, sf ? sf.SFname : "null".ptr);
}
    printf(", Slinnum = %u", srcpos.Slinnum);
    printf(")\n");
}


}
