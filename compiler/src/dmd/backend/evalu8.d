/**
 * Constant folding
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2025 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/compiler/src/dmd/backend/evalu8.d, backend/evalu8.d)
 */

module dmd.backend.evalu8;

import core.stdc.math;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
static import core.bitop;

//#if _MSC_VER
//#define isnan _isnan
//#endif

import dmd.backend.bcomplex;
import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.oper;
import dmd.backend.global;
import dmd.backend.el;
import dmd.backend.ty;
import dmd.backend.type;

import dmd.common.int128;


nothrow:
@safe:

import dmd.backend.fp : testFE, clearFE, statusFE, have_float_except;

/**********************
 * Return boolean result of constant elem.
 */

int boolres(elem* e)
{   int b;

    //printf("boolres()\n");
    //elem_print(e);
    elem_debug(e);
    assert((statusFE() & 0x3800) == 0);
    switch (e.Eoper)
    {
        case OPrelconst:
        case OPstring:
            return true;

        case OPconst:
            switch (tybasic(typemask(e)))
            {   case TYchar:
                case TYuchar:
                case TYschar:
                case TYchar16:
                case TYshort:
                case TYushort:
                case TYint:
                case TYuint:
                case TYbool:
                case TYwchar_t:
                case TYenum:
                case TYmemptr:
                case TYlong:
                case TYulong:
                case TYdchar:
                case TYllong:
                case TYullong:
                case TYsptr:
                case TYcptr:
                case TYhptr:
                case TYfptr:
                case TYvptr:
                case TYnptr:
                case TYimmutPtr:
                case TYsharePtr:
                case TYrestrictPtr:
                case TYfgPtr:
                    b = el_tolong(e) != 0;
                    break;
                case TYnref: // reference can't be converted to bool
                    assert(0);

                case TYfloat:
                case TYifloat:
                case TYdouble:
                case TYidouble:
                case TYdouble_alias:
                case TYildouble:
                case TYldouble:
                {   targ_ldouble ld = el_toldoubled(e);

                    if (isnan(ld))
                        b = 1;
                    else
                        b = (ld != 0);
                    break;
                }
                case TYcfloat:
                    if (isnan(e.Vcfloat.re) || isnan(e.Vcfloat.im))
                        b = 1;
                    else
                        b = e.Vcfloat.re != 0 || e.Vcfloat.im != 0;
                    break;
                case TYcdouble:
                case TYdouble2:
                    if (isnan(e.Vcdouble.re) || isnan(e.Vcdouble.im))
                        b = 1;
                    else
                        b = e.Vcdouble.re != 0 || e.Vcdouble.im != 0;
                    break;
                case TYcldouble:
                    if (isnan(e.Vcldouble.re) || isnan(e.Vcldouble.im))
                        b = 1;
                    else
                        b = e.Vcldouble.re != 0 || e.Vcldouble.im != 0;
                    break;

                case TYstruct:  // happens on syntax error of (struct x)0
                    assert(0);

                case TYvoid:    /* happens if we get syntax errors or
                                       on RHS of && || expressions */
                    b = 0;
                    break;

                case TYcent:
                case TYucent:
                case TYschar16:
                case TYuchar16:
                case TYshort8:
                case TYushort8:
                case TYlong4:
                case TYulong4:
                case TYllong2:
                case TYullong2:
                    b = e.Vcent.lo || e.Vcent.hi;
                    break;

                case TYfloat4:
                {   b = 0;
                    foreach (f; e.Vfloat4)
                    {
                        if (f != 0)
                        {   b = 1;
                            break;
                        }
                    }
                    break;
                }

                case TYschar32:
                case TYuchar32:
                case TYshort16:
                case TYushort16:
                case TYlong8:
                case TYulong8:
                case TYllong4:
                case TYullong4:
                    b = 0;
                    foreach (elem; e.Vulong8)
                        b |= elem != 0;
                    break;

                case TYfloat8:
                    b = 0;
                    foreach (f; e.Vfloat8)
                    {
                        if (f != 0)
                        {   b = 1;
                            break;
                        }
                    }
                    break;

                case TYdouble4:
                    b = 0;
                    foreach (f; e.Vdouble4)
                    {
                        if (f != 0)
                        {   b = 1;
                            break;
                        }
                    }
                    break;

                default:
                    break;  // can be the result of other errors
            }
            break;
        default:
            assert(0);
    }
    return b;
}


/***************************
 * Return true if expression will always evaluate to true.
 */

@trusted
int iftrue(elem* e)
{
    while (1)
    {
        assert(e);
        elem_debug(e);
        switch (e.Eoper)
        {
            case OPcomma:
            case OPinfo:
                e = e.E2;
                break;

            case OPrelconst:
            case OPconst:
            case OPstring:
                return boolres(e);

            case OPoror:
                return tybasic(e.E2.Ety) == TYnoreturn;

            default:
                return false;
        }
    }
}

/***************************
 * Return true if expression will always evaluate to false.
 */

@trusted
int iffalse(elem* e)
{
    while (1)
    {
        assert(e);
        elem_debug(e);
        switch (e.Eoper)
        {
            case OPcomma:
            case OPinfo:
                e = e.E2;
                break;

            case OPconst:
                return !boolres(e);

            case OPandand:
                return tybasic(e.E2.Ety) == TYnoreturn;

            default:
                return false;
        }
    }
}


/******************************
 * Evaluate a node with only constants as leaves.
 * Return with the result.
 */

@trusted
elem* evalu8(elem* e, Goal goal)
{
    elem* e1;
    elem* e2;
    tym_t tym,tym2,uns;
    uint op;
    targ_int i1,i2;
    targ_llong l1,l2;
    targ_ldouble d1,d2;
    elem esave = void;

    static bool unordered(T)(T d1, T d2) { return isnan(d1) || isnan(d2); }

    assert((statusFE() & 0x3800) == 0);
    assert(e && !OTleaf(e.Eoper));
    op = e.Eoper;
    elem_debug(e);
    e1 = e.E1;

    //printf("evalu8(): "); elem_print(e);
    elem_debug(e1);
    if (e1.Eoper == OPconst && !tyvector(e1.Ety))
    {
        tym2 = 0;
        e2 = null;
        if (OTbinary(e.Eoper))
        {   e2 = e.E2;
            elem_debug(e2);
            if (e2.Eoper == OPconst && !tyvector(e2.Ety))
            {
                i2 = cast(targ_int)(l2 = el_tolong(e2));
                d2 = el_toldoubled(e2);
            }
            else
                return e;
            tym2 = tybasic(typemask(e2));
        }
        else
        {
            tym2 = 0;
            e2 = null;
            i2 = 0;             // not used, but static analyzer complains
            l2 = 0;             // "
            d2 = 0;             // "
        }
        i1 = cast(targ_int)(l1 = el_tolong(e1));
        d1 = el_toldoubled(e1);
        tym = tybasic(typemask(e1));    /* type of op is type of left child */

        // Huge pointers are always evaluated at runtime
        if (tym == TYhptr && (l1 != 0 || l2 != 0))
            return e;

        esave = *e;
        clearFE();
    }
    else
        return e;

    /* if left or right leaf is unsigned, this is an unsigned operation */
    uns = tyuns(tym) | tyuns(tym2);

  /*elem_print(e);*/
  //dbg_printf("x%lx %s x%lx = ", l1, oper_str(op), l2);
static if (0)
{
  if (0 && e2)
  {
      debug printf("d1 = %Lg, d2 = %Lg, op = %d, OPne = %d, tym = x%lx\n",d1,d2,op,OPne,tym);
      debug printf("tym1 = x%lx, tym2 = x%lx, e2 = %g\n",tym,tym2,e2.Vdouble);

      Vconst u = void;
      debug printf("d1 = x%16llx\n", (u.Vldouble = d1, u.Vullong));
      debug printf("d2 = x%16llx\n", (u.Vldouble = d2, u.Vullong));
  }
}
  switch (op)
  {
    case OPadd:
        switch (tym)
        {
            case TYfloat:
                switch (tym2)
                {
                    case TYfloat:
                        e.Vfloat = e1.Vfloat + e2.Vfloat;
                        break;
                    case TYifloat:
                        e.Vcfloat.re = e1.Vfloat;
                        e.Vcfloat.im = e2.Vfloat;
                        break;
                    case TYcfloat:
                        e.Vcfloat.re = e1.Vfloat + e2.Vcfloat.re;
                        e.Vcfloat.im = 0            + e2.Vcfloat.im;
                        break;
                    default:
                        assert(0);
                }
                break;
            case TYdouble:
            case TYdouble_alias:
                switch (tym2)
                {
                    case TYdouble:
                    case TYdouble_alias:
                            e.Vdouble = e1.Vdouble + e2.Vdouble;
                        break;
                    case TYidouble:
                        e.Vcdouble.re = e1.Vdouble;
                        e.Vcdouble.im = e2.Vdouble;
                        break;
                    case TYcdouble:
                        e.Vcdouble.re = e1.Vdouble + e2.Vcdouble.re;
                        e.Vcdouble.im = 0             + e2.Vcdouble.im;
                        break;
                    default:
                        assert(0);
                }
                break;
            case TYldouble:
                switch (tym2)
                {
                    case TYldouble:
                        e.Vldouble = d1 + d2;
                        break;
                    case TYildouble:
                        e.Vcldouble.re = d1;
                        e.Vcldouble.im = d2;
                        break;
                    case TYcldouble:
                        e.Vcldouble.re = d1 + e2.Vcldouble.re;
                        e.Vcldouble.im = 0  + e2.Vcldouble.im;
                        break;
                    default:
                        assert(0);
                }
                break;
            case TYifloat:
                switch (tym2)
                {
                    case TYfloat:
                        e.Vcfloat.re = e2.Vfloat;
                        e.Vcfloat.im = e1.Vfloat;
                        break;
                    case TYifloat:
                        e.Vfloat = e1.Vfloat + e2.Vfloat;
                        break;
                    case TYcfloat:
                        e.Vcfloat.re = 0            + e2.Vcfloat.re;
                        e.Vcfloat.im = e1.Vfloat + e2.Vcfloat.im;
                        break;
                    default:
                        assert(0);
                }
                break;
            case TYidouble:
                switch (tym2)
                {
                    case TYdouble:
                        e.Vcdouble.re = e2.Vdouble;
                        e.Vcdouble.im = e1.Vdouble;
                        break;
                    case TYidouble:
                        e.Vdouble = e1.Vdouble + e2.Vdouble;
                        break;
                    case TYcdouble:
                        e.Vcdouble.re = 0             + e2.Vcdouble.re;
                        e.Vcdouble.im = e1.Vdouble + e2.Vcdouble.im;
                        break;
                    default:
                        assert(0);
                }
                break;
            case TYildouble:
                switch (tym2)
                {
                    case TYldouble:
                        e.Vcldouble.re = d2;
                        e.Vcldouble.im = d1;
                        break;
                    case TYildouble:
                        e.Vldouble = d1 + d2;
                        break;
                    case TYcldouble:
                        e.Vcldouble.re = 0  + e2.Vcldouble.re;
                        e.Vcldouble.im = d1 + e2.Vcldouble.im;
                        break;
                    default:
                        assert(0);
                }
                break;
            case TYcfloat:
                switch (tym2)
                {
                    case TYfloat:
                        e.Vcfloat.re = e1.Vcfloat.re + e2.Vfloat;
                        e.Vcfloat.im = e1.Vcfloat.im;
                        break;
                    case TYifloat:
                        e.Vcfloat.re = e1.Vcfloat.re;
                        e.Vcfloat.im = e1.Vcfloat.im + e2.Vfloat;
                        break;
                    case TYcfloat:
                        e.Vcfloat.re = e1.Vcfloat.re + e2.Vcfloat.re;
                        e.Vcfloat.im = e1.Vcfloat.im + e2.Vcfloat.im;
                        break;
                    default:
                        assert(0);
                }
                break;
            case TYcdouble:
                switch (tym2)
                {
                    case TYdouble:
                        e.Vcdouble.re = e1.Vcdouble.re + e2.Vdouble;
                        e.Vcdouble.im = e1.Vcdouble.im;
                        break;
                    case TYidouble:
                        e.Vcdouble.re = e1.Vcdouble.re;
                        e.Vcdouble.im = e1.Vcdouble.im + e2.Vdouble;
                        break;
                    case TYcdouble:
                        e.Vcdouble.re = e1.Vcdouble.re + e2.Vcdouble.re;
                        e.Vcdouble.im = e1.Vcdouble.im + e2.Vcdouble.im;
                        break;
                    default:
                        assert(0);
                }
                break;
            case TYcldouble:
                switch (tym2)
                {
                    case TYldouble:
                        e.Vcldouble.re = e1.Vcldouble.re + d2;
                        e.Vcldouble.im = e1.Vcldouble.im;
                        break;
                    case TYildouble:
                        e.Vcldouble.re = e1.Vcldouble.re;
                        e.Vcldouble.im = e1.Vcldouble.im + d2;
                        break;
                    case TYcldouble:
                        e.Vcldouble.re = e1.Vcldouble.re + e2.Vcldouble.re;
                        e.Vcldouble.im = e1.Vcldouble.im + e2.Vcldouble.im;
                        break;
                    default:
                        assert(0);
                }
                break;

            case TYcent:
            case TYucent:
                e.Vcent = dmd.common.int128.add(e1.Vcent, e2.Vcent);
                break;

            default:
                if (_tysize[TYint] == 2)
                {   if (tyfv(tym))
                        e.Vlong = cast(targ_long)((l1 & 0xFFFF0000) |
                            cast(targ_ushort) (cast(targ_ushort) l1 + i2));
                    else if (tyfv(tym2))
                        e.Vlong = cast(targ_long)((l2 & 0xFFFF0000) |
                            cast(targ_ushort) (i1 + cast(targ_ushort) l2));
                    else if (tyintegral(tym) || typtr(tym))
                        e.Vllong = l1 + l2;
                    else
                        assert(0);
                }
                else if (tyintegral(tym) || typtr(tym))
                    e.Vllong = l1 + l2;
                else
                    assert(0);
                break;
        }
        break;

    case OPmin:
        switch (tym)
        {
            case TYfloat:
                switch (tym2)
                {
                    case TYfloat:
                        e.Vfloat = e1.Vfloat - e2.Vfloat;
                        break;
                    case TYifloat:
                        e.Vcfloat.re =  e1.Vfloat;
                        e.Vcfloat.im = -e2.Vfloat;
                        break;
                    case TYcfloat:
                        e.Vcfloat.re = e1.Vfloat - e2.Vcfloat.re;
                        e.Vcfloat.im = 0            - e2.Vcfloat.im;
                        break;
                    default:
                        assert(0);
                }
                break;
            case TYdouble:
            case TYdouble_alias:
                switch (tym2)
                {
                    case TYdouble:
                    case TYdouble_alias:
                        e.Vdouble = e1.Vdouble - e2.Vdouble;
                        break;
                    case TYidouble:
                        e.Vcdouble.re =  e1.Vdouble;
                        e.Vcdouble.im = -e2.Vdouble;
                        break;
                    case TYcdouble:
                        e.Vcdouble.re = e1.Vdouble - e2.Vcdouble.re;
                        e.Vcdouble.im = 0             - e2.Vcdouble.im;
                        break;
                    default:
                        assert(0);
                }
                break;
            case TYldouble:
                switch (tym2)
                {
                    case TYldouble:
                        e.Vldouble = d1 - d2;
                        break;
                    case TYildouble:
                        e.Vcldouble.re =  d1;
                        e.Vcldouble.im = -d2;
                        break;
                    case TYcldouble:
                        e.Vcldouble.re = d1 - e2.Vcldouble.re;
                        e.Vcldouble.im = 0  - e2.Vcldouble.im;
                        break;
                    default:
                        assert(0);
                }
                break;
            case TYifloat:
                switch (tym2)
                {
                    case TYfloat:
                        e.Vcfloat.re = -e2.Vfloat;
                        e.Vcfloat.im =  e1.Vfloat;
                        break;
                    case TYifloat:
                        e.Vfloat = e1.Vfloat - e2.Vfloat;
                        break;
                    case TYcfloat:
                        e.Vcfloat.re = 0            - e2.Vcfloat.re;
                        e.Vcfloat.im = e1.Vfloat - e2.Vcfloat.im;
                        break;
                    default:
                        assert(0);
                }
                break;
            case TYidouble:
                switch (tym2)
                {
                    case TYdouble:
                        e.Vcdouble.re = -e2.Vdouble;
                        e.Vcdouble.im =  e1.Vdouble;
                        break;
                    case TYidouble:
                        e.Vdouble = e1.Vdouble - e2.Vdouble;
                        break;
                    case TYcdouble:
                        e.Vcdouble.re = 0             - e2.Vcdouble.re;
                        e.Vcdouble.im = e1.Vdouble - e2.Vcdouble.im;
                        break;
                    default:
                        assert(0);
                }
                break;
            case TYildouble:
                switch (tym2)
                {
                    case TYldouble:
                        e.Vcldouble.re = -d2;
                        e.Vcldouble.im =  d1;
                        break;
                    case TYildouble:
                        e.Vldouble = d1 - d2;
                        break;
                    case TYcldouble:
                        e.Vcldouble.re = 0  - e2.Vcldouble.re;
                        e.Vcldouble.im = d1 - e2.Vcldouble.im;
                        break;
                    default:
                        assert(0);
                }
                break;
            case TYcfloat:
                switch (tym2)
                {
                    case TYfloat:
                        e.Vcfloat.re = e1.Vcfloat.re - e2.Vfloat;
                        e.Vcfloat.im = e1.Vcfloat.im;
                        break;
                    case TYifloat:
                        e.Vcfloat.re = e1.Vcfloat.re;
                        e.Vcfloat.im = e1.Vcfloat.im - e2.Vfloat;
                        break;
                    case TYcfloat:
                        e.Vcfloat.re = e1.Vcfloat.re - e2.Vcfloat.re;
                        e.Vcfloat.im = e1.Vcfloat.im - e2.Vcfloat.im;
                        break;
                    default:
                        assert(0);
                }
                break;
            case TYcdouble:
                switch (tym2)
                {
                    case TYdouble:
                        e.Vcdouble.re = e1.Vcdouble.re - e2.Vdouble;
                        e.Vcdouble.im = e1.Vcdouble.im;
                        break;
                    case TYidouble:
                        e.Vcdouble.re = e1.Vcdouble.re;
                        e.Vcdouble.im = e1.Vcdouble.im - e2.Vdouble;
                        break;
                    case TYcdouble:
                        e.Vcdouble.re = e1.Vcdouble.re - e2.Vcdouble.re;
                        e.Vcdouble.im = e1.Vcdouble.im - e2.Vcdouble.im;
                        break;
                    default:
                        assert(0);
                }
                break;
            case TYcldouble:
                switch (tym2)
                {
                    case TYldouble:
                        e.Vcldouble.re = e1.Vcldouble.re - d2;
                        e.Vcldouble.im = e1.Vcldouble.im;
                        break;
                    case TYildouble:
                        e.Vcldouble.re = e1.Vcldouble.re;
                        e.Vcldouble.im = e1.Vcldouble.im - d2;
                        break;
                    case TYcldouble:
                        e.Vcldouble.re = e1.Vcldouble.re - e2.Vcldouble.re;
                        e.Vcldouble.im = e1.Vcldouble.im - e2.Vcldouble.im;
                        break;
                    default:
                        assert(0);
                }
                break;

            case TYcent:
            case TYucent:
                e.Vcent = dmd.common.int128.sub(e1.Vcent, e2.Vcent);
                break;

            default:
                if (_tysize[TYint] == 2 &&
                    tyfv(tym) && _tysize[tym2] == 2)
                    e.Vllong = (l1 & 0xFFFF0000) |
                        cast(targ_ushort) (cast(targ_ushort) l1 - i2);
                else if (tyintegral(tym) || typtr(tym))
                    e.Vllong = l1 - l2;
                else
                    assert(0);
                break;
        }
        break;
    case OPmul:
        if (tym == TYcent || tym == TYucent)
            e.Vcent = dmd.common.int128.mul(e1.Vcent, e2.Vcent);
        else if (tyintegral(tym) || typtr(tym))
            e.Vllong = l1 * l2;
        else
        {   switch (tym)
            {
                case TYfloat:
                    switch (tym2)
                    {
                        case TYfloat:
                        case TYifloat:
                            e.Vfloat = e1.Vfloat * e2.Vfloat;
                            break;
                        case TYcfloat:
                            e.Vcfloat.re = e1.Vfloat * e2.Vcfloat.re;
                            e.Vcfloat.im = e1.Vfloat * e2.Vcfloat.im;
                            break;
                        default:
                            assert(0);
                    }
                    break;
                case TYdouble:
                case TYdouble_alias:
                    switch (tym2)
                    {
                        case TYdouble:
                        case TYdouble_alias:
                        case TYidouble:
                            e.Vdouble = e1.Vdouble * e2.Vdouble;
                            break;
                        case TYcdouble:
                            e.Vcdouble.re = e1.Vdouble * e2.Vcdouble.re;
                            e.Vcdouble.im = e1.Vdouble * e2.Vcdouble.im;
                            break;
                        default:
                            assert(0);
                    }
                    break;
                case TYldouble:
                    switch (tym2)
                    {
                        case TYldouble:
                        case TYildouble:
                            e.Vldouble = d1 * d2;
                            break;
                        case TYcldouble:
                            e.Vcldouble.re = d1 * e2.Vcldouble.re;
                            e.Vcldouble.im = d1 * e2.Vcldouble.im;
                            break;
                        default:
                            assert(0);
                    }
                    break;
                case TYifloat:
                    switch (tym2)
                    {
                        case TYfloat:
                            e.Vfloat = e1.Vfloat * e2.Vfloat;
                            break;
                        case TYifloat:
                            e.Vfloat = -e1.Vfloat * e2.Vfloat;
                            break;
                        case TYcfloat:
                            e.Vcfloat.re = -e1.Vfloat * e2.Vcfloat.im;
                            e.Vcfloat.im =  e1.Vfloat * e2.Vcfloat.re;
                            break;
                        default:
                            assert(0);
                    }
                    break;
                case TYidouble:
                    switch (tym2)
                    {
                        case TYdouble:
                            e.Vdouble = e1.Vdouble * e2.Vdouble;
                            break;
                        case TYidouble:
                            e.Vdouble = -e1.Vdouble * e2.Vdouble;
                            break;
                        case TYcdouble:
                            e.Vcdouble.re = -e1.Vdouble * e2.Vcdouble.im;
                            e.Vcdouble.im =  e1.Vdouble * e2.Vcdouble.re;
                            break;
                        default:
                            assert(0);
                    }
                    break;
                case TYildouble:
                    switch (tym2)
                    {
                        case TYldouble:
                            e.Vldouble = d1 * d2;
                            break;
                        case TYildouble:
                            e.Vldouble = -d1 * d2;
                            break;
                        case TYcldouble:
                            e.Vcldouble.re = -d1 * e2.Vcldouble.im;
                            e.Vcldouble.im =  d1 * e2.Vcldouble.re;
                            break;
                        default:
                            assert(0);
                    }
                    break;
                case TYcfloat:
                    switch (tym2)
                    {
                        case TYfloat:
                            e.Vcfloat.re = e1.Vcfloat.re * e2.Vfloat;
                            e.Vcfloat.im = e1.Vcfloat.im * e2.Vfloat;
                            break;
                        case TYifloat:
                            e.Vcfloat.re = -e1.Vcfloat.im * e2.Vfloat;
                            e.Vcfloat.im =  e1.Vcfloat.re * e2.Vfloat;
                            break;
                        case TYcfloat:
                            e.Vcfloat = Complex_f.mul(e1.Vcfloat, e2.Vcfloat);
                            break;
                        default:
                            assert(0);
                    }
                    break;
                case TYcdouble:
                    switch (tym2)
                    {
                        case TYdouble:
                            e.Vcdouble.re = e1.Vcdouble.re * e2.Vdouble;
                            e.Vcdouble.im = e1.Vcdouble.im * e2.Vdouble;
                            break;
                        case TYidouble:
                            e.Vcdouble.re = -e1.Vcdouble.im * e2.Vdouble;
                            e.Vcdouble.im =  e1.Vcdouble.re * e2.Vdouble;
                            break;
                        case TYcdouble:
                            e.Vcdouble = Complex_d.mul(e1.Vcdouble, e2.Vcdouble);
                            break;
                        default:
                            assert(0);
                    }
                    break;
                case TYcldouble:
                    switch (tym2)
                    {
                        case TYldouble:
                            e.Vcldouble.re = e1.Vcldouble.re * d2;
                            e.Vcldouble.im = e1.Vcldouble.im * d2;
                            break;
                        case TYildouble:
                            e.Vcldouble.re = -e1.Vcldouble.im * d2;
                            e.Vcldouble.im =  e1.Vcldouble.re * d2;
                            break;
                        case TYcldouble:
                            e.Vcldouble = Complex_ld.mul(e1.Vcldouble, e2.Vcldouble);
                            break;
                        default:
                            assert(0);
                    }
                    break;
                default:
                    debug printf("tym = x%x\n",tym);
                    debug elem_print(e);
                    assert(0);
            }
        }
        break;
    case OPdiv:
        if (!boolres(e2))                       // divide by 0
        {
            if (!tyfloating(tym))
                goto div0;
        }
        if (uns)
        {
            if (tym == TYucent)
                e.Vcent = dmd.common.int128.udiv(e1.Vcent, e2.Vcent);
            else
                e.Vullong = (cast(targ_ullong) l1) / (cast(targ_ullong) l2);
        }
        else if (tym == TYcent)
            e.Vcent = dmd.common.int128.div(e1.Vcent, e2.Vcent);
        else
        {   switch (tym)
            {
                case TYfloat:
                    switch (tym2)
                    {
                        case TYfloat:
                            e.Vfloat = e1.Vfloat / e2.Vfloat;
                            break;
                        case TYifloat:
                            e.Vfloat = -e1.Vfloat / e2.Vfloat;
                            break;
                        case TYcfloat:
                            e.Vcfloat.re = cast(float)d1;
                            e.Vcfloat.im = 0;
                            e.Vcfloat = Complex_f.div(e.Vcfloat, e2.Vcfloat);
                            break;
                        default:
                            assert(0);
                    }
                    break;
                case TYdouble:
                case TYdouble_alias:
                    switch (tym2)
                    {
                        case TYdouble:
                        case TYdouble_alias:
                            e.Vdouble = e1.Vdouble / e2.Vdouble;
                            break;
                        case TYldouble:
                            // cast is required because Vldouble is a soft type on windows
                            e.Vdouble = cast(double)(e1.Vdouble / e2.Vldouble);
                            break;
                        case TYidouble:
                            e.Vdouble = -e1.Vdouble / e2.Vdouble;
                            break;
                        case TYcdouble:
                            e.Vcdouble.re = cast(double)d1;
                            e.Vcdouble.im = 0;
                            e.Vcdouble = Complex_d.div(e.Vcdouble, e2.Vcdouble);
                            break;
                        default:
                            assert(0);
                    }
                    break;
                case TYldouble:
                    switch (tym2)
                    {
                        case TYldouble:
                            e.Vldouble = d1 / d2;
                            break;
                        case TYildouble:
                            e.Vldouble = -d1 / d2;
                            break;
                        case TYcldouble:
                            e.Vcldouble.re = d1;
                            e.Vcldouble.im = 0;
                            e.Vcldouble = Complex_ld.div(e.Vcldouble, e2.Vcldouble);
                            break;
                        default:
                            assert(0);
                    }
                    break;
                case TYifloat:
                    switch (tym2)
                    {
                        case TYfloat:
                        case TYifloat:
                            e.Vfloat = e1.Vfloat / e2.Vfloat;
                            break;
                        case TYcfloat:
                            e.Vcfloat.re = 0;
                            e.Vcfloat.im = e1.Vfloat;
                            e.Vcfloat = Complex_f.div(e.Vcfloat, e2.Vcfloat);
                            break;
                        default:
                            assert(0);
                    }
                    break;
                case TYidouble:
                    switch (tym2)
                    {
                        case TYdouble:
                        case TYidouble:
                            e.Vdouble = e1.Vdouble / e2.Vdouble;
                            break;
                        case TYcdouble:
                            e.Vcdouble.re = 0;
                            e.Vcdouble.im = e1.Vdouble;
                            e.Vcdouble = Complex_d.div(e.Vcdouble, e2.Vcdouble);
                            break;
                        default:
                            assert(0);
                    }
                    break;
                case TYildouble:
                    switch (tym2)
                    {
                        case TYldouble:
                        case TYildouble:
                            e.Vldouble = d1 / d2;
                            break;
                        case TYcldouble:
                            e.Vcldouble.re = 0;
                            e.Vcldouble.im = d1;
                            e.Vcldouble = Complex_ld.div(e.Vcldouble, e2.Vcldouble);
                            break;
                        default:
                            assert(0);
                    }
                    break;
                case TYcfloat:
                    switch (tym2)
                    {
                        case TYfloat:
                            e.Vcfloat.re = e1.Vcfloat.re / e2.Vfloat;
                            e.Vcfloat.im = e1.Vcfloat.im / e2.Vfloat;
                            break;
                        case TYifloat:
                            e.Vcfloat.re =  e1.Vcfloat.im / e2.Vfloat;
                            e.Vcfloat.im = -e1.Vcfloat.re / e2.Vfloat;
                            break;
                        case TYcfloat:
                            e.Vcfloat = Complex_f.div(e1.Vcfloat, e2.Vcfloat);
                            break;
                        default:
                            assert(0);
                    }
                    break;
                case TYcdouble:
                    switch (tym2)
                    {
                        case TYdouble:
                            e.Vcdouble.re = e1.Vcdouble.re / e2.Vdouble;
                            e.Vcdouble.im = e1.Vcdouble.im / e2.Vdouble;
                            break;
                        case TYidouble:
                            e.Vcdouble.re =  e1.Vcdouble.im / e2.Vdouble;
                            e.Vcdouble.im = -e1.Vcdouble.re / e2.Vdouble;
                            break;
                        case TYcdouble:
                            e.Vcdouble = Complex_d.div(e1.Vcdouble, e2.Vcdouble);
                            break;
                        default:
                            assert(0);
                    }
                    break;
                case TYcldouble:
                    switch (tym2)
                    {
                        case TYldouble:
                            e.Vcldouble.re = e1.Vcldouble.re / d2;
                            e.Vcldouble.im = e1.Vcldouble.im / d2;
                            break;
                        case TYildouble:
                            e.Vcldouble.re =  e1.Vcldouble.im / d2;
                            e.Vcldouble.im = -e1.Vcldouble.re / d2;
                            break;
                        case TYcldouble:
                            e.Vcldouble = Complex_ld.div(e1.Vcldouble, e2.Vcldouble);
                            break;
                        default:
                            assert(0);
                    }
                    break;
                default:
                    e.Vllong = l1 / l2;
                    break;
            }
        }
        break;
    case OPmod:
        if (!tyfloating(tym))
        {
            if (!boolres(e2))
            {
                div0:
                    error(e.Esrcpos, "divide by zero");
                    break;

                overflow:
                    error(e.Esrcpos, "integer overflow");
                    break;
            }
        }
        if (uns)
        {
            if (tym == TYucent)
                dmd.common.int128.udivmod(e1.Vcent, e2.Vcent, e.Vcent);
            else
                e.Vullong = (cast(targ_ullong) l1) % (cast(targ_ullong) l2);
        }
        else if (tym == TYcent)
            dmd.common.int128.divmod(e1.Vcent, e2.Vcent, e.Vcent);
        else
        {
            // BUG: what do we do for imaginary, complex?
            switch (tym)
            {   case TYdouble:
                case TYidouble:
                case TYdouble_alias:
                    e.Vdouble = fmod(e1.Vdouble,e2.Vdouble);
                    break;
                case TYfloat:
                case TYifloat:
                    e.Vfloat = fmodf(e1.Vfloat,e2.Vfloat);
                    break;
                case TYldouble:
                case TYildouble:
                    e.Vldouble = _modulo(d1, d2);
                    break;
                case TYcfloat:
                    switch (tym2)
                    {
                        case TYfloat:
                        case TYifloat:
                            e.Vcfloat.re = fmodf(e1.Vcfloat.re, e2.Vfloat);
                            e.Vcfloat.im = fmodf(e1.Vcfloat.im, e2.Vfloat);
                            break;
                        default:
                            assert(0);
                    }
                    break;
                case TYcdouble:
                    switch (tym2)
                    {
                        case TYdouble:
                        case TYidouble:
                            e.Vcdouble.re = fmod(e1.Vcdouble.re, e2.Vdouble);
                            e.Vcdouble.im = fmod(e1.Vcdouble.im, e2.Vdouble);
                            break;
                        default:
                            assert(0);
                    }
                    break;
                case TYcldouble:
                    switch (tym2)
                    {
                        case TYldouble:
                        case TYildouble:
                            e.Vcldouble.re = _modulo(e1.Vcldouble.re, d2);
                            e.Vcldouble.im = _modulo(e1.Vcldouble.im, d2);
                            break;
                        default:
                            assert(0);
                    }
                    break;
                default:
                    e.Vllong = l1 % l2;
                    break;
            }
        }
        break;
    case OPremquo:
    {
        targ_llong rem, quo;

        assert(!(tym == TYcent || tym == TYucent));     // not yet
        assert(!tyfloating(tym));
        if (!boolres(e2))
            goto div0;
        if (uns)
        {
            rem = (cast(targ_ullong) l1) % (cast(targ_ullong) l2);
            quo = (cast(targ_ullong) l1) / (cast(targ_ullong) l2);
        }
        else if (l1 == 0x8000_0000_0000_0000 && l2 == -1L)
            goto overflow;  // overflow
        else
        {
            rem = l1 % l2;
            quo = l1 / l2;
        }
        switch (tysize(tym))
        {
            case 2:
                e.Vllong = (rem << 16) | (quo & 0xFFFF);
                break;
            case 4:
                e.Vllong = (rem << 32) | (quo & 0xFFFFFFFF);
                break;
            case 8:
                e.Vcent.lo = quo;
                e.Vcent.hi = rem;
                break;
            default:
                assert(0);
        }
        break;
    }
    case OPand:
        if (tym == TYcent || tym == TYucent)
            e.Vcent = dmd.common.int128.and(e1.Vcent, e2.Vcent);
        else
            e.Vllong = l1 & l2;
        break;
    case OPor:
        if (tym == TYcent || tym == TYucent)
            e.Vcent = dmd.common.int128.or(e1.Vcent, e2.Vcent);
        else
            e.Vllong = l1 | l2;
        break;
    case OPxor:
        if (tym == TYcent || tym == TYucent)
            e.Vcent = dmd.common.int128.xor(e1.Vcent, e2.Vcent);
        else
            e.Vllong = l1 ^ l2;
        break;
    case OPnot:
        e.Vint = boolres(e1) ^ true;
        break;
    case OPcom:
        if (tym == TYcent || tym == TYucent)
            e.Vcent = dmd.common.int128.com(e1.Vcent);
        else
            e.Vllong = ~l1;
        break;
    case OPcomma:
        e.EV = e2.EV;
        break;
    case OPoror:
        e.Vint = boolres(e1) || boolres(e2);
        break;
    case OPandand:
        e.Vint = boolres(e1) && boolres(e2);
        break;
    case OPshl:
        if (tym == TYcent || tym == TYucent)
            e.Vcent = dmd.common.int128.shl(e1.Vcent, i2);
        else if (cast(targ_ullong) i2 < targ_ullong.sizeof * 8)
            e.Vllong = l1 << i2;
        else
            e.Vllong = 0;
        break;
    case OPshr:
        if (tym == TYcent || tym == TYucent)
        {
            e.Vcent = dmd.common.int128.shr(e1.Vcent, i2);
            break;
        }
        if (cast(targ_ullong) i2 > targ_ullong.sizeof * 8)
            i2 = targ_ullong.sizeof * 8;
        // Always unsigned
        e.Vullong = (cast(targ_ullong) l1) >> i2;
        break;

    case OPbtst:
        if (cast(targ_ullong) i2 > targ_ullong.sizeof * 8)
            i2 = targ_ullong.sizeof * 8;
        e.Vullong = ((cast(targ_ullong) l1) >> i2) & 1;
        break;

    case OPashr:
        if (tym == TYcent || tym == TYucent)
        {
            e.Vcent = dmd.common.int128.sar(e1.Vcent, i2);
            break;
        }
        if (cast(targ_ullong) i2 > targ_ullong.sizeof * 8)
            i2 = targ_ullong.sizeof * 8;
        // Always signed
        e.Vllong = l1 >> i2;
        break;

    case OPpair:
        switch (tysize(e.Ety))
        {
            case 4:
                e.Vlong = (i2 << 16) | (i1 & 0xFFFF);
                break;
            case 8:
                if (tyfloating(tym))
                {
                    e.Vcfloat.re = cast(float)d1;
                    e.Vcfloat.im = cast(float)d2;
                }
                else
                    e.Vllong = (l2 << 32) | (l1 & 0xFFFFFFFF);
                break;
            case 16:
                if (tyfloating(tym))
                {
                    e.Vcdouble.re = cast(double)d1;
                    e.Vcdouble.im = cast(double)d2;
                }
                else
                {
                    e.Vcent.lo = l1;
                    e.Vcent.hi = l2;
                }
                break;

            case -1:            // can happen for TYstruct
                return e;       // don't const fold it

            default:
                if (tyfloating(tym))
                {
                    e.Vcldouble.re = d1;
                    e.Vcldouble.im = d2;
                }
                else
                {
                    elem_print(e);
                    assert(0);
                }
                break;
        }
        break;

    case OPrpair:
        switch (tysize(e.Ety))
        {
            case 4:
                e.Vlong = (i1 << 16) | (i2 & 0xFFFF);
                break;
            case 8:
                e.Vllong = (l1 << 32) | (l2 & 0xFFFFFFFF);
                if (tyfloating(tym))
                {
                    e.Vcfloat.re = cast(float)d2;
                    e.Vcfloat.im = cast(float)d1;
                }
                else
                    e.Vllong = (l1 << 32) | (l2 & 0xFFFFFFFF);
                break;
            case 16:
                if (tyfloating(tym))
                {
                    e.Vcdouble.re = cast(double)d2;
                    e.Vcdouble.im = cast(double)d1;
                }
                else
                {
                    e.Vcent.lo = l2;
                    e.Vcent.hi = l1;
                }
                break;
            default:
                if (tyfloating(tym))
                {
                    e.Vcldouble.re = d2;
                    e.Vcldouble.im = d1;
                }
                else
                {
                    assert(0);
                }
                break;
        }
        break;

    case OPneg:
        // Avoid converting NANS to NAN
        memcpy(&e.Vcldouble,&e1.Vcldouble,e.Vcldouble.sizeof);
        switch (tym)
        {   case TYdouble:
            case TYidouble:
            case TYdouble_alias:
                e.Vdouble = -e.Vdouble;
                break;
            case TYfloat:
            case TYifloat:
                e.Vfloat = -e.Vfloat;
                break;
            case TYldouble:
            case TYildouble:
                e.Vldouble = -e.Vldouble;
                break;
            case TYcfloat:
                e.Vcfloat.re = -e.Vcfloat.re;
                e.Vcfloat.im = -e.Vcfloat.im;
                break;
            case TYcdouble:
                e.Vcdouble.re = -e.Vcdouble.re;
                e.Vcdouble.im = -e.Vcdouble.im;
                break;
            case TYcldouble:
                e.Vcldouble.re = -e.Vcldouble.re;
                e.Vcldouble.im = -e.Vcldouble.im;
                break;

            case TYcent:
            case TYucent:
                e.Vcent = dmd.common.int128.neg(e1.Vcent);
                break;

            default:
                e.Vllong = -l1;
                break;
        }
        break;
    case OPabs:
        switch (tym)
        {
            case TYdouble:
            case TYidouble:
            case TYdouble_alias:
                e.Vdouble = fabs(e1.Vdouble);
                break;
            case TYfloat:
            case TYifloat:
version (DigitalMars)
                e.Vfloat = fabsf(e1.Vfloat);
else
                e.Vfloat = fabs(e1.Vfloat);

                break;
            case TYldouble:
            case TYildouble:
                e.Vldouble = fabsl(d1);
                break;
            case TYcfloat:
                e.Vfloat = cast(float)Complex_f.abs(e1.Vcfloat);
                break;
            case TYcdouble:
                e.Vdouble = cast(double)Complex_d.abs(e1.Vcdouble);
                break;
            case TYcldouble:
                e.Vldouble = Complex_ld.abs(e1.Vcldouble);
                break;
            case TYcent:
            case TYucent:
                e.Vcent = cast(long)e1.Vcent.hi < 0 ? dmd.common.int128.neg(e1.Vcent) : e1.Vcent;
                break;
            default:
                e.Vllong = l1 < 0 ? -l1 : l1;
                break;
        }
        break;

    case OPsqrt:
    case OPsin:
    case OPcos:
    case OPrndtol:
    case OPrint:
        return e;

    case OPngt:
    case OPgt:
        if (!tyfloating(tym))
            goto Lnle;
        e.Vint = (op == OPngt) ^ (d1 > d2);
        break;

    case OPnle:
    Lnle:
    case OPle:
    {
        int b;
        if (uns)
        {
            if (tym == TYucent)
                b = dmd.common.int128.ule(e1.Vcent, e2.Vcent);
            else
                b = cast(int)((cast(targ_ullong) l1) <= (cast(targ_ullong) l2));
        }
        else
        {
            if (tyfloating(tym))
                b = cast(int)(!unordered(d1, d2) && d1 <= d2);
            else if (tym == TYcent)
                b = dmd.common.int128.le(e1.Vcent, e2.Vcent);
            else
                b = cast(int)(l1 <= l2);
        }
        e.Vint = (op != OPle) ^ b;
        break;
    }

    case OPnge:
    case OPge:
        if (!tyfloating(tym))
            goto Lnlt;
        e.Vint = (op == OPnge) ^ (!unordered(d1, d2) && d1 >= d2);
        break;

    case OPnlt:
    Lnlt:
    case OPlt:
    {
        int b;
        if (uns)
        {
            if (tym == TYucent)
                b = dmd.common.int128.ult(e1.Vcent, e2.Vcent);
            else
                b = cast(int)((cast(targ_ullong) l1) < (cast(targ_ullong) l2));
        }
        else
        {
            if (tyfloating(tym))
                b = cast(int)(!unordered(d1, d2) && d1 < d2);
            else if (tym == TYcent)
                b = dmd.common.int128.lt(e1.Vcent, e2.Vcent);
            else
                b = cast(int)(l1 < l2);
        }
        e.Vint = (op != OPlt) ^ b;
        break;
    }

    case OPne:
    case OPeqeq:
    {
        int b;
        if (tyfloating(tym))
        {
            switch (tybasic(tym))
            {
                case TYcfloat:
                    if (isnan(e1.Vcfloat.re) || isnan(e1.Vcfloat.im) ||
                        isnan(e2.Vcfloat.re) || isnan(e2.Vcfloat.im))
                        b = 0;
                    else
                        b = cast(int)((e1.Vcfloat.re == e2.Vcfloat.re) &&
                                      (e1.Vcfloat.im == e2.Vcfloat.im));
                    break;
                case TYcdouble:
                    if (isnan(e1.Vcdouble.re) || isnan(e1.Vcdouble.im) ||
                        isnan(e2.Vcdouble.re) || isnan(e2.Vcdouble.im))
                        b = 0;
                    else
                        b = cast(int)((e1.Vcdouble.re == e2.Vcdouble.re) &&
                                      (e1.Vcdouble.im == e2.Vcdouble.im));
                    break;
                case TYcldouble:
                    if (isnan(e1.Vcldouble.re) || isnan(e1.Vcldouble.im) ||
                        isnan(e2.Vcldouble.re) || isnan(e2.Vcldouble.im))
                        b = 0;
                    else
                        b = cast(int)((e1.Vcldouble.re == e2.Vcldouble.re) &&
                                      (e1.Vcldouble.im == e2.Vcldouble.im));
                    break;
                default:
                    b = cast(int)(d1 == d2);
                    break;
            }
            //printf("%Lg + %Lgi, %Lg + %Lgi\n", e1.Vcldouble.re, e1.Vcldouble.im, e2.Vcldouble.re, e2.Vcldouble.im);
        }
        else if (tym == TYcent || tym == TYucent)
            b = cast(int)(e1.Vcent == e2.Vcent);
        else
            b = cast(int)(l1 == l2);
        e.Vint = (op == OPne) ^ b;
        break;
    }

    case OPord:
    case OPunord:
        // BUG: complex numbers
        e.Vint = (op == OPord) ^ (unordered(d1, d2)); // !<>=
        break;

    case OPnlg:
    case OPlg:
        // BUG: complex numbers
        e.Vint = (op == OPnlg) ^ (!unordered(d1, d2) && d1 != d2); // <>
        break;

    case OPnleg:
    case OPleg:
        // BUG: complex numbers
        e.Vint = (op == OPnleg) ^ (!unordered(d1, d2)); // <>=
        break;

    case OPnule:
    case OPule:
        // BUG: complex numbers
        e.Vint = (op == OPnule) ^ (unordered(d1, d2) || d1 <= d2); // !>
        break;

    case OPnul:
    case OPul:
        // BUG: complex numbers
        e.Vint = (op == OPnul) ^ (unordered(d1, d2) || d1 < d2); // !>=
        break;

    case OPnuge:
    case OPuge:
        // BUG: complex numbers
        e.Vint = (op == OPnuge) ^ (unordered(d1, d2) || d1 >= d2); // !<
        break;

    case OPnug:
    case OPug:
        // BUG: complex numbers
        e.Vint = (op == OPnug) ^ (unordered(d1, d2) || d1 > d2); // !<=
        break;

    case OPnue:
    case OPue:
        // BUG: complex numbers
        e.Vint = (op == OPnue) ^ (unordered(d1, d2) || d1 == d2); // !<>
        break;

    case OPs16_32:
        e.Vlong = cast(targ_short) i1;
        break;
    case OPnp_fp:
    case OPu16_32:
        e.Vulong = cast(targ_ushort) i1;
        break;
    case OPd_u32:
        e.Vulong = cast(targ_ulong)d1;
        //printf("OPd_u32: dbl = %g, ulng = x%lx\n",d1,e.Vulong);
        break;
    case OPd_s32:
        e.Vlong = cast(targ_long)d1;
        break;
    case OPu32_d:
        e.Vdouble = cast(uint) l1;
        break;
    case OPs32_d:
        e.Vdouble = cast(int) l1;
        break;
    case OPd_s16:
        e.Vint = cast(targ_int)d1;
        break;
    case OPs16_d:
        e.Vdouble = cast(targ_short) i1;
        break;
    case OPd_u16:
        e.Vushort = cast(targ_ushort)d1;
        break;
    case OPu16_d:
        e.Vdouble = cast(targ_ushort) i1;
        break;
    case OPd_s64:
        e.Vllong = cast(targ_llong)d1;
        break;
    case OPd_u64:
    case OPld_u64:
        e.Vullong = cast(targ_ullong)d1;
        break;
    case OPs64_d:
        e.Vdouble = l1;
        break;
    case OPu64_d:
        e.Vdouble = cast(targ_ullong) l1;
        break;
    case OPd_f:
        assert((statusFE() & 0x3800) == 0);
        e.Vfloat = e1.Vdouble;
        if (tycomplex(tym))
            e.Vcfloat.im = e1.Vcdouble.im;
        assert((statusFE() & 0x3800) == 0);
        break;
    case OPf_d:
        e.Vdouble = e1.Vfloat;
        if (tycomplex(tym))
            e.Vcdouble.im = e1.Vcfloat.im;
        break;
    case OPd_ld:
        e.Vldouble = e1.Vdouble;
        if (tycomplex(tym))
            e.Vcldouble.im = e1.Vcdouble.im;
        break;
    case OPld_d:
        e.Vdouble = cast(double)e1.Vldouble;
        if (tycomplex(tym))
            e.Vcdouble.im = cast(double)e1.Vcldouble.im;
        break;
    case OPc_r:
        e.EV = e1.EV;
        break;
    case OPc_i:
        switch (tym)
        {
            case TYcfloat:
                e.Vfloat = e1.Vcfloat.im;
                break;
            case TYcdouble:
                e.Vdouble = e1.Vcdouble.im;
                break;
            case TYcldouble:
                e.Vldouble = e1.Vcldouble.im;
                break;
            default:
                assert(0);
        }
        break;
    case OPs8_16:
        e.Vint = cast(targ_schar) i1;
        break;
    case OPu8_16:
        e.Vint = i1 & 0xFF;
        break;
    case OP16_8:
        e.Vint = i1;
        break;
    case OPbool:
        e.Vint = boolres(e1);
        break;
    case OP32_16:
    case OPoffset:
        e.Vint = cast(targ_int)l1;
        break;

    case OP64_32:
        e.Vlong = cast(targ_long)l1;
        break;
    case OPs32_64:
        e.Vllong = cast(targ_long) l1;
        break;
    case OPu32_64:
        e.Vllong = cast(targ_ulong) l1;
        break;

    case OP128_64:
        e.Vllong = e1.Vcent.lo;
        break;
    case OPs64_128:
        e.Vcent.lo = e1.Vllong;
        e.Vcent.hi = 0;
        if (cast(targ_llong)e.Vcent.lo < 0)
            e.Vcent.hi = ~cast(targ_ullong)0;
        break;
    case OPu64_128:
        e.Vcent.lo = e1.Vullong;
        e.Vcent.hi = 0;
        break;

    case OPmsw:
        switch (tysize(tym))
        {
            case 4:
                e.Vllong = (l1 >> 16) & 0xFFFF;
                break;
            case 8:
                e.Vllong = (l1 >> 32) & 0xFFFFFFFF;
                break;
            case 16:
                e.Vllong = e1.Vcent.hi;
                break;
            default:
                assert(0);
        }
        break;
    case OPb_8:
        e.Vlong = i1 & 1;
        break;
    case OPbswap:
        if (tysize(tym) == 2)
        {
            e.Vint = ((i1 >> 8) & 0x00FF) |
                        ((i1 << 8) & 0xFF00);
        }
        else if (tysize(tym) == 4)
            e.Vint = core.bitop.bswap(cast(uint) i1);
        else if (tysize(tym) == 8)
            e.Vllong = core.bitop.bswap(cast(ulong) l1);
        else
        {
            e.Vcent.hi = core.bitop.bswap(e1.Vcent.lo);
            e.Vcent.lo = core.bitop.bswap(e1.Vcent.hi);
        }
        break;

    case OPpopcnt:
    {
        // Eliminate any unwanted sign extension
        switch (tysize(tym))
        {
            case 1:     l1 &= 0xFF;       break;
            case 2:     l1 &= 0xFFFF;     break;
            case 4:     l1 &= 0xFFFFFFFF; break;
            case 8:     break;
            default:    assert(0);
        }
        e.Vllong = core.bitop.popcnt(cast(ulong) l1);
        break;
    }

    case OProl:
    case OPror:
    {   uint n = i2;
        if (op == OPror)
            n = -n;
        switch (tysize(tym))
        {
            case 1:
                n &= 7;
                e.Vuchar = cast(ubyte)((i1 << n) | ((i1 & 0xFF) >> (8 - n)));
                break;
            case 2:
                n &= 0xF;
                e.Vushort = cast(targ_ushort)((i1 << n) | ((i1 & 0xFFFF) >> (16 - n)));
                break;
            case 4:
                n &= 0x1F;
                e.Vulong = cast(targ_ulong)((i1 << n) | ((i1 & 0xFFFFFFFF) >> (32 - n)));
                break;
            case 8:
                n &= 0x3F;
                e.Vullong = cast(targ_ullong)((l1 << n) | ((l1 & 0xFFFFFFFFFFFFFFFFL) >> (64 - n)));
                break;
            case 16:
                e.Vcent = dmd.common.int128.rol(e1.Vcent, n);
                break;
            default:
                assert(0);
        }
        break;
    }
    case OPind:
static if (0) // && MARS
{
        /* The problem with this is that although the only reaching definition
         * of the variable is null, it still may never get executed, as in:
         *   int* p = null; if (p) *p = 3;
         * and the error will be spurious.
         */
        if (l1 >= 0 && l1 < 4096)
        {
            error(e.Esrcpos, "dereference of null pointer");
            e.E1.Vlong = 4096;     // suppress redundant messages
        }
}
        return e;

    case OPvecfill:
        switch (tybasic(e.Ety))
        {
            // 16 byte vectors
            case TYfloat4:
                foreach (ref lhsElem; e.Vfloat4)
                    lhsElem = e1.Vfloat;
                break;
            case TYdouble2:
                foreach (ref lhsElem; e.Vdouble2)
                    lhsElem = e1.Vdouble;
                break;
            case TYschar16:
            case TYuchar16:
                foreach (ref lhsElem; e.Vuchar16)
                    lhsElem = cast(targ_uchar)i1;
                break;
            case TYshort8:
            case TYushort8:
                foreach (ref lhsElem; e.Vushort8)
                    lhsElem = cast(targ_ushort)i1;
                break;
            case TYlong4:
            case TYulong4:
                foreach (ref lhsElem; e.Vulong4)
                    lhsElem = cast(targ_ulong)i1;
                break;
            case TYllong2:
            case TYullong2:
                foreach (ref lhsElem; e.Vullong2)
                    lhsElem = cast(targ_ullong)l1;
                break;

            // 32 byte vectors
            case TYfloat8:
                foreach (ref lhsElem; e.Vfloat8)
                    lhsElem = e1.Vfloat;
                break;
            case TYdouble4:
                foreach (ref lhsElem; e.Vdouble4)
                    lhsElem = e1.Vdouble;
                break;
            case TYschar32:
            case TYuchar32:
                foreach (ref lhsElem; e.Vuchar32)
                    lhsElem = cast(targ_uchar)i1;
                break;
            case TYshort16:
            case TYushort16:
                foreach (ref lhsElem; e.Vushort16)
                    lhsElem = cast(targ_ushort)i1;
                break;
            case TYlong8:
            case TYulong8:
                foreach (ref lhsElem; e.Vulong8)
                    lhsElem = cast(targ_ulong)i1;
                break;
            case TYllong4:
            case TYullong4:
                foreach (ref lhsElem; e.Vullong4)
                    lhsElem = cast(targ_ullong)l1;
                break;

            default:
                assert(0);
        }
        break;

    default:
        return e;
  }

    if (!(goal & Goal.ignoreExceptions) &&
        (config.flags4 & CFG4fastfloat) == 0 && testFE() &&
        (have_float_except() || tyfloating(tym) || tyfloating(tybasic(typemask(e))))
       )
    {
        // Exceptions happened. Do not fold the constants.
        *e = esave;
        return e;
    }
    else
    {
    }

  /*debug printf("result = x%lx\n",e.Vlong);*/
  e.Eoper = OPconst;
  el_free(e1);
  if (e2)
        el_free(e2);
  //printf("2: %x\n", statusFE());
  assert((statusFE() & 0x3800) == 0);
  //printf("evalu8() returns: "); elem_print(e);
  return e;
}

/******************************
 * This is the same as the one in el.c, but uses native D reals
 * instead of the soft long double ones.
 */

extern (D) targ_ldouble el_toldoubled(elem* e)
{
    targ_ldouble result;

    elem_debug(e);
    assert(e.Eoper == OPconst);
    switch (tybasic(typemask(e)))
    {
        case TYfloat:
        case TYifloat:
            result = e.Vfloat;
            break;
        case TYdouble:
        case TYidouble:
        case TYdouble_alias:
            result = e.Vdouble;
            break;
        case TYldouble:
        case TYildouble:
            result = e.Vldouble;
            break;
        default:
            result = 0;
            break;
    }
    return result;
}

/***************************************
 * Copy of _modulo from fp.c. Here to help with linking problems.
 */
version (CRuntime_Microsoft)
{
    extern (D) private targ_ldouble _modulo(targ_ldouble x, targ_ldouble y)
    {
        return cast(targ_ldouble)fmodl(cast(real)x, cast(real)y);
    }
    import core.stdc.math : isnan;
    static if (!is(targ_ldouble == real))
        extern (D) private int isnan(targ_ldouble x)
        {
            return isnan(cast(real)x);
        }
    import core.stdc.math : fabsl;
    import dmd.root.longdouble : fabsl; // needed if longdouble is longdouble_soft
}
else
{
    import dmd.backend.fp : _modulo;
}
