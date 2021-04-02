/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2021 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/evalu8.d, backend/evalu8.d)
 */

module dmd.backend.evalu8;

version (SPP)
{
}
else
{

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

version (SCPP)
{
import msgs2;
import parser;
import scopeh;
}

extern (C++):

nothrow:
@safe:

version (MARS)
    import dmd.backend.errors;

// fp.c
int testFE();
void clearFE();
int statusFE();
bool have_float_except();


/**********************
 * Return boolean result of constant elem.
 */

int boolres(elem *e)
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

version (SCPP)
{
        case OPvar:
            assert(CPP && PARSER);
            el_toconst(e);
            assert(e.Eoper == OPconst);
            goto case OPconst;
}
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
                    if (isnan(e.EV.Vcfloat.re) || isnan(e.EV.Vcfloat.im))
                        b = 1;
                    else
                        b = e.EV.Vcfloat.re != 0 || e.EV.Vcfloat.im != 0;
                    break;
                case TYcdouble:
                case TYdouble2:
                    if (isnan(e.EV.Vcdouble.re) || isnan(e.EV.Vcdouble.im))
                        b = 1;
                    else
                        b = e.EV.Vcdouble.re != 0 || e.EV.Vcdouble.im != 0;
                    break;
                case TYcldouble:
                    if (isnan(e.EV.Vcldouble.re) || isnan(e.EV.Vcldouble.im))
                        b = 1;
                    else
                        b = e.EV.Vcldouble.re != 0 || e.EV.Vcldouble.im != 0;
                    break;

                case TYstruct:  // happens on syntax error of (struct x)0
                version (SCPP)
                {
                    assert(errcnt);
                    goto case TYvoid;
                }
                else
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
                    b = e.EV.Vcent.lsw || e.EV.Vcent.msw;
                    break;

                case TYfloat4:
                {   b = 0;
                    foreach (f; e.EV.Vfloat4)
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
                    foreach (elem; e.EV.Vulong8)
                        b |= elem != 0;
                    break;

                case TYfloat8:
                    b = 0;
                    foreach (f; e.EV.Vfloat8)
                    {
                        if (f != 0)
                        {   b = 1;
                            break;
                        }
                    }
                    break;

                case TYdouble4:
                    b = 0;
                    foreach (f; e.EV.Vdouble4)
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
int iftrue(elem *e)
{
    while (1)
    {
        assert(e);
        elem_debug(e);
        switch (e.Eoper)
        {
            case OPcomma:
            case OPinfo:
                e = e.EV.E2;
                break;

            case OPrelconst:
            case OPconst:
            case OPstring:
                return boolres(e);

            case OPoror:
                return tybasic(e.EV.E2.Ety) == TYnoreturn;

            default:
                return false;
        }
    }
}

/***************************
 * Return true if expression will always evaluate to false.
 */

@trusted
int iffalse(elem *e)
{
    while (1)
    {
        assert(e);
        elem_debug(e);
        switch (e.Eoper)
        {
            case OPcomma:
            case OPinfo:
                e = e.EV.E2;
                break;

            case OPconst:
                return !boolres(e);

            case OPandand:
                return tybasic(e.EV.E2.Ety) == TYnoreturn;

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
elem * evalu8(elem *e, goal_t goal)
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
    e1 = e.EV.E1;

    //printf("evalu8(): "); elem_print(e);
    elem_debug(e1);
    if (e1.Eoper == OPconst && !tyvector(e1.Ety))
    {
        tym2 = 0;
        e2 = null;
        if (OTbinary(e.Eoper))
        {   e2 = e.EV.E2;
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
  /*dbg_printf("x%lx ",l1); WROP(op); dbg_printf("x%lx = ",l2);*/
static if (0)
{
  if (0 && e2)
  {
      debug printf("d1 = %Lg, d2 = %Lg, op = %d, OPne = %d, tym = x%lx\n",d1,d2,op,OPne,tym);
      debug printf("tym1 = x%lx, tym2 = x%lx, e2 = %g\n",tym,tym2,e2.EV.Vdouble);

      eve u;
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
                        e.EV.Vfloat = e1.EV.Vfloat + e2.EV.Vfloat;
                        break;
                    case TYifloat:
                        e.EV.Vcfloat.re = e1.EV.Vfloat;
                        e.EV.Vcfloat.im = e2.EV.Vfloat;
                        break;
                    case TYcfloat:
                        e.EV.Vcfloat.re = e1.EV.Vfloat + e2.EV.Vcfloat.re;
                        e.EV.Vcfloat.im = 0            + e2.EV.Vcfloat.im;
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
                            e.EV.Vdouble = e1.EV.Vdouble + e2.EV.Vdouble;
                        break;
                    case TYidouble:
                        e.EV.Vcdouble.re = e1.EV.Vdouble;
                        e.EV.Vcdouble.im = e2.EV.Vdouble;
                        break;
                    case TYcdouble:
                        e.EV.Vcdouble.re = e1.EV.Vdouble + e2.EV.Vcdouble.re;
                        e.EV.Vcdouble.im = 0             + e2.EV.Vcdouble.im;
                        break;
                    default:
                        assert(0);
                }
                break;
            case TYldouble:
                switch (tym2)
                {
                    case TYldouble:
                        e.EV.Vldouble = d1 + d2;
                        break;
                    case TYildouble:
                        e.EV.Vcldouble.re = d1;
                        e.EV.Vcldouble.im = d2;
                        break;
                    case TYcldouble:
                        e.EV.Vcldouble.re = d1 + e2.EV.Vcldouble.re;
                        e.EV.Vcldouble.im = 0  + e2.EV.Vcldouble.im;
                        break;
                    default:
                        assert(0);
                }
                break;
            case TYifloat:
                switch (tym2)
                {
                    case TYfloat:
                        e.EV.Vcfloat.re = e2.EV.Vfloat;
                        e.EV.Vcfloat.im = e1.EV.Vfloat;
                        break;
                    case TYifloat:
                        e.EV.Vfloat = e1.EV.Vfloat + e2.EV.Vfloat;
                        break;
                    case TYcfloat:
                        e.EV.Vcfloat.re = 0            + e2.EV.Vcfloat.re;
                        e.EV.Vcfloat.im = e1.EV.Vfloat + e2.EV.Vcfloat.im;
                        break;
                    default:
                        assert(0);
                }
                break;
            case TYidouble:
                switch (tym2)
                {
                    case TYdouble:
                        e.EV.Vcdouble.re = e2.EV.Vdouble;
                        e.EV.Vcdouble.im = e1.EV.Vdouble;
                        break;
                    case TYidouble:
                        e.EV.Vdouble = e1.EV.Vdouble + e2.EV.Vdouble;
                        break;
                    case TYcdouble:
                        e.EV.Vcdouble.re = 0             + e2.EV.Vcdouble.re;
                        e.EV.Vcdouble.im = e1.EV.Vdouble + e2.EV.Vcdouble.im;
                        break;
                    default:
                        assert(0);
                }
                break;
            case TYildouble:
                switch (tym2)
                {
                    case TYldouble:
                        e.EV.Vcldouble.re = d2;
                        e.EV.Vcldouble.im = d1;
                        break;
                    case TYildouble:
                        e.EV.Vldouble = d1 + d2;
                        break;
                    case TYcldouble:
                        e.EV.Vcldouble.re = 0  + e2.EV.Vcldouble.re;
                        e.EV.Vcldouble.im = d1 + e2.EV.Vcldouble.im;
                        break;
                    default:
                        assert(0);
                }
                break;
            case TYcfloat:
                switch (tym2)
                {
                    case TYfloat:
                        e.EV.Vcfloat.re = e1.EV.Vcfloat.re + e2.EV.Vfloat;
                        e.EV.Vcfloat.im = e1.EV.Vcfloat.im;
                        break;
                    case TYifloat:
                        e.EV.Vcfloat.re = e1.EV.Vcfloat.re;
                        e.EV.Vcfloat.im = e1.EV.Vcfloat.im + e2.EV.Vfloat;
                        break;
                    case TYcfloat:
                        e.EV.Vcfloat.re = e1.EV.Vcfloat.re + e2.EV.Vcfloat.re;
                        e.EV.Vcfloat.im = e1.EV.Vcfloat.im + e2.EV.Vcfloat.im;
                        break;
                    default:
                        assert(0);
                }
                break;
            case TYcdouble:
                switch (tym2)
                {
                    case TYdouble:
                        e.EV.Vcdouble.re = e1.EV.Vcdouble.re + e2.EV.Vdouble;
                        e.EV.Vcdouble.im = e1.EV.Vcdouble.im;
                        break;
                    case TYidouble:
                        e.EV.Vcdouble.re = e1.EV.Vcdouble.re;
                        e.EV.Vcdouble.im = e1.EV.Vcdouble.im + e2.EV.Vdouble;
                        break;
                    case TYcdouble:
                        e.EV.Vcdouble.re = e1.EV.Vcdouble.re + e2.EV.Vcdouble.re;
                        e.EV.Vcdouble.im = e1.EV.Vcdouble.im + e2.EV.Vcdouble.im;
                        break;
                    default:
                        assert(0);
                }
                break;
            case TYcldouble:
                switch (tym2)
                {
                    case TYldouble:
                        e.EV.Vcldouble.re = e1.EV.Vcldouble.re + d2;
                        e.EV.Vcldouble.im = e1.EV.Vcldouble.im;
                        break;
                    case TYildouble:
                        e.EV.Vcldouble.re = e1.EV.Vcldouble.re;
                        e.EV.Vcldouble.im = e1.EV.Vcldouble.im + d2;
                        break;
                    case TYcldouble:
                        e.EV.Vcldouble.re = e1.EV.Vcldouble.re + e2.EV.Vcldouble.re;
                        e.EV.Vcldouble.im = e1.EV.Vcldouble.im + e2.EV.Vcldouble.im;
                        break;
                    default:
                        assert(0);
                }
                break;

            default:
                if (_tysize[TYint] == 2)
                {   if (tyfv(tym))
                        e.EV.Vlong = cast(targ_long)((l1 & 0xFFFF0000) |
                            cast(targ_ushort) (cast(targ_ushort) l1 + i2));
                    else if (tyfv(tym2))
                        e.EV.Vlong = cast(targ_long)((l2 & 0xFFFF0000) |
                            cast(targ_ushort) (i1 + cast(targ_ushort) l2));
                    else if (tyintegral(tym) || typtr(tym))
                        e.EV.Vllong = l1 + l2;
                    else
                        assert(0);
                }
                else if (tyintegral(tym) || typtr(tym))
                    e.EV.Vllong = l1 + l2;
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
                        e.EV.Vfloat = e1.EV.Vfloat - e2.EV.Vfloat;
                        break;
                    case TYifloat:
                        e.EV.Vcfloat.re =  e1.EV.Vfloat;
                        e.EV.Vcfloat.im = -e2.EV.Vfloat;
                        break;
                    case TYcfloat:
                        e.EV.Vcfloat.re = e1.EV.Vfloat - e2.EV.Vcfloat.re;
                        e.EV.Vcfloat.im = 0            - e2.EV.Vcfloat.im;
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
                        e.EV.Vdouble = e1.EV.Vdouble - e2.EV.Vdouble;
                        break;
                    case TYidouble:
                        e.EV.Vcdouble.re =  e1.EV.Vdouble;
                        e.EV.Vcdouble.im = -e2.EV.Vdouble;
                        break;
                    case TYcdouble:
                        e.EV.Vcdouble.re = e1.EV.Vdouble - e2.EV.Vcdouble.re;
                        e.EV.Vcdouble.im = 0             - e2.EV.Vcdouble.im;
                        break;
                    default:
                        assert(0);
                }
                break;
            case TYldouble:
                switch (tym2)
                {
                    case TYldouble:
                        e.EV.Vldouble = d1 - d2;
                        break;
                    case TYildouble:
                        e.EV.Vcldouble.re =  d1;
                        e.EV.Vcldouble.im = -d2;
                        break;
                    case TYcldouble:
                        e.EV.Vcldouble.re = d1 - e2.EV.Vcldouble.re;
                        e.EV.Vcldouble.im = 0  - e2.EV.Vcldouble.im;
                        break;
                    default:
                        assert(0);
                }
                break;
            case TYifloat:
                switch (tym2)
                {
                    case TYfloat:
                        e.EV.Vcfloat.re = -e2.EV.Vfloat;
                        e.EV.Vcfloat.im =  e1.EV.Vfloat;
                        break;
                    case TYifloat:
                        e.EV.Vfloat = e1.EV.Vfloat - e2.EV.Vfloat;
                        break;
                    case TYcfloat:
                        e.EV.Vcfloat.re = 0            - e2.EV.Vcfloat.re;
                        e.EV.Vcfloat.im = e1.EV.Vfloat - e2.EV.Vcfloat.im;
                        break;
                    default:
                        assert(0);
                }
                break;
            case TYidouble:
                switch (tym2)
                {
                    case TYdouble:
                        e.EV.Vcdouble.re = -e2.EV.Vdouble;
                        e.EV.Vcdouble.im =  e1.EV.Vdouble;
                        break;
                    case TYidouble:
                        e.EV.Vdouble = e1.EV.Vdouble - e2.EV.Vdouble;
                        break;
                    case TYcdouble:
                        e.EV.Vcdouble.re = 0             - e2.EV.Vcdouble.re;
                        e.EV.Vcdouble.im = e1.EV.Vdouble - e2.EV.Vcdouble.im;
                        break;
                    default:
                        assert(0);
                }
                break;
            case TYildouble:
                switch (tym2)
                {
                    case TYldouble:
                        e.EV.Vcldouble.re = -d2;
                        e.EV.Vcldouble.im =  d1;
                        break;
                    case TYildouble:
                        e.EV.Vldouble = d1 - d2;
                        break;
                    case TYcldouble:
                        e.EV.Vcldouble.re = 0  - e2.EV.Vcldouble.re;
                        e.EV.Vcldouble.im = d1 - e2.EV.Vcldouble.im;
                        break;
                    default:
                        assert(0);
                }
                break;
            case TYcfloat:
                switch (tym2)
                {
                    case TYfloat:
                        e.EV.Vcfloat.re = e1.EV.Vcfloat.re - e2.EV.Vfloat;
                        e.EV.Vcfloat.im = e1.EV.Vcfloat.im;
                        break;
                    case TYifloat:
                        e.EV.Vcfloat.re = e1.EV.Vcfloat.re;
                        e.EV.Vcfloat.im = e1.EV.Vcfloat.im - e2.EV.Vfloat;
                        break;
                    case TYcfloat:
                        e.EV.Vcfloat.re = e1.EV.Vcfloat.re - e2.EV.Vcfloat.re;
                        e.EV.Vcfloat.im = e1.EV.Vcfloat.im - e2.EV.Vcfloat.im;
                        break;
                    default:
                        assert(0);
                }
                break;
            case TYcdouble:
                switch (tym2)
                {
                    case TYdouble:
                        e.EV.Vcdouble.re = e1.EV.Vcdouble.re - e2.EV.Vdouble;
                        e.EV.Vcdouble.im = e1.EV.Vcdouble.im;
                        break;
                    case TYidouble:
                        e.EV.Vcdouble.re = e1.EV.Vcdouble.re;
                        e.EV.Vcdouble.im = e1.EV.Vcdouble.im - e2.EV.Vdouble;
                        break;
                    case TYcdouble:
                        e.EV.Vcdouble.re = e1.EV.Vcdouble.re - e2.EV.Vcdouble.re;
                        e.EV.Vcdouble.im = e1.EV.Vcdouble.im - e2.EV.Vcdouble.im;
                        break;
                    default:
                        assert(0);
                }
                break;
            case TYcldouble:
                switch (tym2)
                {
                    case TYldouble:
                        e.EV.Vcldouble.re = e1.EV.Vcldouble.re - d2;
                        e.EV.Vcldouble.im = e1.EV.Vcldouble.im;
                        break;
                    case TYildouble:
                        e.EV.Vcldouble.re = e1.EV.Vcldouble.re;
                        e.EV.Vcldouble.im = e1.EV.Vcldouble.im - d2;
                        break;
                    case TYcldouble:
                        e.EV.Vcldouble.re = e1.EV.Vcldouble.re - e2.EV.Vcldouble.re;
                        e.EV.Vcldouble.im = e1.EV.Vcldouble.im - e2.EV.Vcldouble.im;
                        break;
                    default:
                        assert(0);
                }
                break;

            default:
                if (_tysize[TYint] == 2 &&
                    tyfv(tym) && _tysize[tym2] == 2)
                    e.EV.Vllong = (l1 & 0xFFFF0000) |
                        cast(targ_ushort) (cast(targ_ushort) l1 - i2);
                else if (tyintegral(tym) || typtr(tym))
                    e.EV.Vllong = l1 - l2;
                else
                    assert(0);
                break;
        }
        break;
    case OPmul:
        if (tyintegral(tym) || typtr(tym))
            e.EV.Vllong = l1 * l2;
        else
        {   switch (tym)
            {
                case TYfloat:
                    switch (tym2)
                    {
                        case TYfloat:
                        case TYifloat:
                            e.EV.Vfloat = e1.EV.Vfloat * e2.EV.Vfloat;
                            break;
                        case TYcfloat:
                            e.EV.Vcfloat.re = e1.EV.Vfloat * e2.EV.Vcfloat.re;
                            e.EV.Vcfloat.im = e1.EV.Vfloat * e2.EV.Vcfloat.im;
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
                            e.EV.Vdouble = e1.EV.Vdouble * e2.EV.Vdouble;
                            break;
                        case TYcdouble:
                            e.EV.Vcdouble.re = e1.EV.Vdouble * e2.EV.Vcdouble.re;
                            e.EV.Vcdouble.im = e1.EV.Vdouble * e2.EV.Vcdouble.im;
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
                            e.EV.Vldouble = d1 * d2;
                            break;
                        case TYcldouble:
                            e.EV.Vcldouble.re = d1 * e2.EV.Vcldouble.re;
                            e.EV.Vcldouble.im = d1 * e2.EV.Vcldouble.im;
                            break;
                        default:
                            assert(0);
                    }
                    break;
                case TYifloat:
                    switch (tym2)
                    {
                        case TYfloat:
                            e.EV.Vfloat = e1.EV.Vfloat * e2.EV.Vfloat;
                            break;
                        case TYifloat:
                            e.EV.Vfloat = -e1.EV.Vfloat * e2.EV.Vfloat;
                            break;
                        case TYcfloat:
                            e.EV.Vcfloat.re = -e1.EV.Vfloat * e2.EV.Vcfloat.im;
                            e.EV.Vcfloat.im =  e1.EV.Vfloat * e2.EV.Vcfloat.re;
                            break;
                        default:
                            assert(0);
                    }
                    break;
                case TYidouble:
                    switch (tym2)
                    {
                        case TYdouble:
                            e.EV.Vdouble = e1.EV.Vdouble * e2.EV.Vdouble;
                            break;
                        case TYidouble:
                            e.EV.Vdouble = -e1.EV.Vdouble * e2.EV.Vdouble;
                            break;
                        case TYcdouble:
                            e.EV.Vcdouble.re = -e1.EV.Vdouble * e2.EV.Vcdouble.im;
                            e.EV.Vcdouble.im =  e1.EV.Vdouble * e2.EV.Vcdouble.re;
                            break;
                        default:
                            assert(0);
                    }
                    break;
                case TYildouble:
                    switch (tym2)
                    {
                        case TYldouble:
                            e.EV.Vldouble = d1 * d2;
                            break;
                        case TYildouble:
                            e.EV.Vldouble = -d1 * d2;
                            break;
                        case TYcldouble:
                            e.EV.Vcldouble.re = -d1 * e2.EV.Vcldouble.im;
                            e.EV.Vcldouble.im =  d1 * e2.EV.Vcldouble.re;
                            break;
                        default:
                            assert(0);
                    }
                    break;
                case TYcfloat:
                    switch (tym2)
                    {
                        case TYfloat:
                            e.EV.Vcfloat.re = e1.EV.Vcfloat.re * e2.EV.Vfloat;
                            e.EV.Vcfloat.im = e1.EV.Vcfloat.im * e2.EV.Vfloat;
                            break;
                        case TYifloat:
                            e.EV.Vcfloat.re = -e1.EV.Vcfloat.im * e2.EV.Vfloat;
                            e.EV.Vcfloat.im =  e1.EV.Vcfloat.re * e2.EV.Vfloat;
                            break;
                        case TYcfloat:
                            e.EV.Vcfloat = Complex_f.mul(e1.EV.Vcfloat, e2.EV.Vcfloat);
                            break;
                        default:
                            assert(0);
                    }
                    break;
                case TYcdouble:
                    switch (tym2)
                    {
                        case TYdouble:
                            e.EV.Vcdouble.re = e1.EV.Vcdouble.re * e2.EV.Vdouble;
                            e.EV.Vcdouble.im = e1.EV.Vcdouble.im * e2.EV.Vdouble;
                            break;
                        case TYidouble:
                            e.EV.Vcdouble.re = -e1.EV.Vcdouble.im * e2.EV.Vdouble;
                            e.EV.Vcdouble.im =  e1.EV.Vcdouble.re * e2.EV.Vdouble;
                            break;
                        case TYcdouble:
                            e.EV.Vcdouble = Complex_d.mul(e1.EV.Vcdouble, e2.EV.Vcdouble);
                            break;
                        default:
                            assert(0);
                    }
                    break;
                case TYcldouble:
                    switch (tym2)
                    {
                        case TYldouble:
                            e.EV.Vcldouble.re = e1.EV.Vcldouble.re * d2;
                            e.EV.Vcldouble.im = e1.EV.Vcldouble.im * d2;
                            break;
                        case TYildouble:
                            e.EV.Vcldouble.re = -e1.EV.Vcldouble.im * d2;
                            e.EV.Vcldouble.im =  e1.EV.Vcldouble.re * d2;
                            break;
                        case TYcldouble:
                            e.EV.Vcldouble = Complex_ld.mul(e1.EV.Vcldouble, e2.EV.Vcldouble);
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
            e.EV.Vullong = (cast(targ_ullong) l1) / (cast(targ_ullong) l2);
        else
        {   switch (tym)
            {
                case TYfloat:
                    switch (tym2)
                    {
                        case TYfloat:
                            e.EV.Vfloat = e1.EV.Vfloat / e2.EV.Vfloat;
                            break;
                        case TYifloat:
                            e.EV.Vfloat = -e1.EV.Vfloat / e2.EV.Vfloat;
                            break;
                        case TYcfloat:
                            e.EV.Vcfloat.re = cast(float)d1;
                            e.EV.Vcfloat.im = 0;
                            e.EV.Vcfloat = Complex_f.div(e.EV.Vcfloat, e2.EV.Vcfloat);
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
                            e.EV.Vdouble = e1.EV.Vdouble / e2.EV.Vdouble;
                            break;
                        case TYidouble:
                            e.EV.Vdouble = -e1.EV.Vdouble / e2.EV.Vdouble;
                            break;
                        case TYcdouble:
                            e.EV.Vcdouble.re = cast(double)d1;
                            e.EV.Vcdouble.im = 0;
                            e.EV.Vcdouble = Complex_d.div(e.EV.Vcdouble, e2.EV.Vcdouble);
                            break;
                        default:
                            assert(0);
                    }
                    break;
                case TYldouble:
                    switch (tym2)
                    {
                        case TYldouble:
                            e.EV.Vldouble = d1 / d2;
                            break;
                        case TYildouble:
                            e.EV.Vldouble = -d1 / d2;
                            break;
                        case TYcldouble:
                            e.EV.Vcldouble.re = d1;
                            e.EV.Vcldouble.im = 0;
                            e.EV.Vcldouble = Complex_ld.div(e.EV.Vcldouble, e2.EV.Vcldouble);
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
                            e.EV.Vfloat = e1.EV.Vfloat / e2.EV.Vfloat;
                            break;
                        case TYcfloat:
                            e.EV.Vcfloat.re = 0;
                            e.EV.Vcfloat.im = e1.EV.Vfloat;
                            e.EV.Vcfloat = Complex_f.div(e.EV.Vcfloat, e2.EV.Vcfloat);
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
                            e.EV.Vdouble = e1.EV.Vdouble / e2.EV.Vdouble;
                            break;
                        case TYcdouble:
                            e.EV.Vcdouble.re = 0;
                            e.EV.Vcdouble.im = e1.EV.Vdouble;
                            e.EV.Vcdouble = Complex_d.div(e.EV.Vcdouble, e2.EV.Vcdouble);
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
                            e.EV.Vldouble = d1 / d2;
                            break;
                        case TYcldouble:
                            e.EV.Vcldouble.re = 0;
                            e.EV.Vcldouble.im = d1;
                            e.EV.Vcldouble = Complex_ld.div(e.EV.Vcldouble, e2.EV.Vcldouble);
                            break;
                        default:
                            assert(0);
                    }
                    break;
                case TYcfloat:
                    switch (tym2)
                    {
                        case TYfloat:
                            e.EV.Vcfloat.re = e1.EV.Vcfloat.re / e2.EV.Vfloat;
                            e.EV.Vcfloat.im = e1.EV.Vcfloat.im / e2.EV.Vfloat;
                            break;
                        case TYifloat:
                            e.EV.Vcfloat.re =  e1.EV.Vcfloat.im / e2.EV.Vfloat;
                            e.EV.Vcfloat.im = -e1.EV.Vcfloat.re / e2.EV.Vfloat;
                            break;
                        case TYcfloat:
                            e.EV.Vcfloat = Complex_f.div(e1.EV.Vcfloat, e2.EV.Vcfloat);
                            break;
                        default:
                            assert(0);
                    }
                    break;
                case TYcdouble:
                    switch (tym2)
                    {
                        case TYdouble:
                            e.EV.Vcdouble.re = e1.EV.Vcdouble.re / e2.EV.Vdouble;
                            e.EV.Vcdouble.im = e1.EV.Vcdouble.im / e2.EV.Vdouble;
                            break;
                        case TYidouble:
                            e.EV.Vcdouble.re =  e1.EV.Vcdouble.im / e2.EV.Vdouble;
                            e.EV.Vcdouble.im = -e1.EV.Vcdouble.re / e2.EV.Vdouble;
                            break;
                        case TYcdouble:
                            e.EV.Vcdouble = Complex_d.div(e1.EV.Vcdouble, e2.EV.Vcdouble);
                            break;
                        default:
                            assert(0);
                    }
                    break;
                case TYcldouble:
                    switch (tym2)
                    {
                        case TYldouble:
                            e.EV.Vcldouble.re = e1.EV.Vcldouble.re / d2;
                            e.EV.Vcldouble.im = e1.EV.Vcldouble.im / d2;
                            break;
                        case TYildouble:
                            e.EV.Vcldouble.re =  e1.EV.Vcldouble.im / d2;
                            e.EV.Vcldouble.im = -e1.EV.Vcldouble.re / d2;
                            break;
                        case TYcldouble:
                            e.EV.Vcldouble = Complex_ld.div(e1.EV.Vcldouble, e2.EV.Vcldouble);
                            break;
                        default:
                            assert(0);
                    }
                    break;
                default:
                    e.EV.Vllong = l1 / l2;
                    break;
            }
        }
        break;
    case OPmod:
version (MARS)
{
        if (!tyfloating(tym))
        {
            if (!boolres(e2))
            {
                div0:
                    error(e.Esrcpos.Sfilename, e.Esrcpos.Slinnum, e.Esrcpos.Scharnum, "divide by zero");
                    break;

                overflow:
                    error(e.Esrcpos.Sfilename, e.Esrcpos.Slinnum, e.Esrcpos.Scharnum, "integer overflow");
                    break;
            }
        }
}
else
{
        if (1)
        {
            if (!boolres(e2))
            {
                div0:
                overflow:
                    version (SCPP)
                        synerr(EM_divby0);
                    break;
            }
        }
}
        if (uns)
            e.EV.Vullong = (cast(targ_ullong) l1) % (cast(targ_ullong) l2);
        else
        {
            // BUG: what do we do for imaginary, complex?
            switch (tym)
            {   case TYdouble:
                case TYidouble:
                case TYdouble_alias:
                    e.EV.Vdouble = fmod(e1.EV.Vdouble,e2.EV.Vdouble);
                    break;
                case TYfloat:
                case TYifloat:
                    e.EV.Vfloat = fmodf(e1.EV.Vfloat,e2.EV.Vfloat);
                    break;
                case TYldouble:
                case TYildouble:
                    e.EV.Vldouble = _modulo(d1, d2);
                    break;
                case TYcfloat:
                    switch (tym2)
                    {
                        case TYfloat:
                        case TYifloat:
                            e.EV.Vcfloat.re = fmodf(e1.EV.Vcfloat.re, e2.EV.Vfloat);
                            e.EV.Vcfloat.im = fmodf(e1.EV.Vcfloat.im, e2.EV.Vfloat);
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
                            e.EV.Vcdouble.re = fmod(e1.EV.Vcdouble.re, e2.EV.Vdouble);
                            e.EV.Vcdouble.im = fmod(e1.EV.Vcdouble.im, e2.EV.Vdouble);
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
                            e.EV.Vcldouble.re = _modulo(e1.EV.Vcldouble.re, d2);
                            e.EV.Vcldouble.im = _modulo(e1.EV.Vcldouble.im, d2);
                            break;
                        default:
                            assert(0);
                    }
                    break;
                default:
                    e.EV.Vllong = l1 % l2;
                    break;
            }
        }
        break;
    case OPremquo:
    {
        targ_llong rem, quo;

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
                e.EV.Vllong = (rem << 16) | (quo & 0xFFFF);
                break;
            case 4:
                e.EV.Vllong = (rem << 32) | (quo & 0xFFFFFFFF);
                break;
            case 8:
                e.EV.Vcent.lsw = quo;
                e.EV.Vcent.msw = rem;
                break;
            default:
                assert(0);
        }
        break;
    }
    case OPand:
        e.EV.Vllong = l1 & l2;
        break;
    case OPor:
        e.EV.Vllong = l1 | l2;
        break;
    case OPxor:
        e.EV.Vllong = l1 ^ l2;
        break;
    case OPnot:
        e.EV.Vint = boolres(e1) ^ true;
        break;
    case OPcom:
        e.EV.Vllong = ~l1;
        break;
    case OPcomma:
        e.EV = e2.EV;
        break;
    case OPoror:
        e.EV.Vint = boolres(e1) || boolres(e2);
        break;
    case OPandand:
        e.EV.Vint = boolres(e1) && boolres(e2);
        break;
    case OPshl:
        if (cast(targ_ullong) i2 < targ_ullong.sizeof * 8)
            e.EV.Vllong = l1 << i2;
        else
            e.EV.Vllong = 0;
        break;
    case OPshr:
        if (cast(targ_ullong) i2 > targ_ullong.sizeof * 8)
            i2 = targ_ullong.sizeof * 8;
version (SCPP)
{
        if (tyuns(tym))
        {   //printf("unsigned\n");
            e.EV.Vullong = (cast(targ_ullong) l1) >> i2;
        }
        else
        {   //printf("signed\n");
            e.EV.Vllong = l1 >> i2;
        }
}
version (MARS)
{
        // Always unsigned
        e.EV.Vullong = (cast(targ_ullong) l1) >> i2;
}
        break;

    case OPbtst:
        if (cast(targ_ullong) i2 > targ_ullong.sizeof * 8)
            i2 = targ_ullong.sizeof * 8;
        e.EV.Vullong = ((cast(targ_ullong) l1) >> i2) & 1;
        break;

version (MARS)
{
    case OPashr:
        if (cast(targ_ullong) i2 > targ_ullong.sizeof * 8)
            i2 = targ_ullong.sizeof * 8;
        // Always signed
        e.EV.Vllong = l1 >> i2;
        break;
}

    case OPpair:
        switch (tysize(e.Ety))
        {
            case 4:
                e.EV.Vlong = (i2 << 16) | (i1 & 0xFFFF);
                break;
            case 8:
                if (tyfloating(tym))
                {
                    e.EV.Vcfloat.re = cast(float)d1;
                    e.EV.Vcfloat.im = cast(float)d2;
                }
                else
                    e.EV.Vllong = (l2 << 32) | (l1 & 0xFFFFFFFF);
                break;
            case 16:
                if (tyfloating(tym))
                {
                    e.EV.Vcdouble.re = cast(double)d1;
                    e.EV.Vcdouble.im = cast(double)d2;
                }
                else
                {
                    e.EV.Vcent.lsw = l1;
                    e.EV.Vcent.msw = l2;
                }
                break;

            case -1:            // can happen for TYstruct
                return e;       // don't const fold it

            default:
                if (tyfloating(tym))
                {
                    e.EV.Vcldouble.re = d1;
                    e.EV.Vcldouble.im = d2;
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
                e.EV.Vlong = (i1 << 16) | (i2 & 0xFFFF);
                break;
            case 8:
                e.EV.Vllong = (l1 << 32) | (l2 & 0xFFFFFFFF);
                if (tyfloating(tym))
                {
                    e.EV.Vcfloat.re = cast(float)d2;
                    e.EV.Vcfloat.im = cast(float)d1;
                }
                else
                    e.EV.Vllong = (l1 << 32) | (l2 & 0xFFFFFFFF);
                break;
            case 16:
                if (tyfloating(tym))
                {
                    e.EV.Vcdouble.re = cast(double)d2;
                    e.EV.Vcdouble.im = cast(double)d1;
                }
                else
                {
                    e.EV.Vcent.lsw = l2;
                    e.EV.Vcent.msw = l1;
                }
                break;
            default:
                if (tyfloating(tym))
                {
                    e.EV.Vcldouble.re = d2;
                    e.EV.Vcldouble.im = d1;
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
        memcpy(&e.EV.Vcldouble,&e1.EV.Vcldouble,e.EV.Vcldouble.sizeof);
        switch (tym)
        {   case TYdouble:
            case TYidouble:
            case TYdouble_alias:
                e.EV.Vdouble = -e.EV.Vdouble;
                break;
            case TYfloat:
            case TYifloat:
                e.EV.Vfloat = -e.EV.Vfloat;
                break;
            case TYldouble:
            case TYildouble:
                e.EV.Vldouble = -e.EV.Vldouble;
                break;
            case TYcfloat:
                e.EV.Vcfloat.re = -e.EV.Vcfloat.re;
                e.EV.Vcfloat.im = -e.EV.Vcfloat.im;
                break;
            case TYcdouble:
                e.EV.Vcdouble.re = -e.EV.Vcdouble.re;
                e.EV.Vcdouble.im = -e.EV.Vcdouble.im;
                break;
            case TYcldouble:
                e.EV.Vcldouble.re = -e.EV.Vcldouble.re;
                e.EV.Vcldouble.im = -e.EV.Vcldouble.im;
                break;
            default:
                e.EV.Vllong = -l1;
                break;
        }
        break;
    case OPabs:
        switch (tym)
        {
            case TYdouble:
            case TYidouble:
            case TYdouble_alias:
                e.EV.Vdouble = fabs(e1.EV.Vdouble);
                break;
            case TYfloat:
            case TYifloat:
version (DigitalMars)
                e.EV.Vfloat = fabsf(e1.EV.Vfloat);
else
                e.EV.Vfloat = fabs(e1.EV.Vfloat);

                break;
            case TYldouble:
            case TYildouble:
                e.EV.Vldouble = fabsl(d1);
                break;
            case TYcfloat:
                e.EV.Vfloat = cast(float)Complex_f.abs(e1.EV.Vcfloat);
                break;
            case TYcdouble:
                e.EV.Vdouble = cast(double)Complex_d.abs(e1.EV.Vcdouble);
                break;
            case TYcldouble:
                e.EV.Vldouble = Complex_ld.abs(e1.EV.Vcldouble);
                break;
            default:
                e.EV.Vllong = l1 < 0 ? -l1 : l1;
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
        e.EV.Vint = (op == OPngt) ^ (d1 > d2);
        break;

    case OPnle:
    Lnle:
    case OPle:
    {
        int b;
        if (uns)
        {
            b = cast(int)((cast(targ_ullong) l1) <= (cast(targ_ullong) l2));
        }
        else
        {
            if (tyfloating(tym))
                b = cast(int)(!unordered(d1, d2) && d1 <= d2);
            else
                b = cast(int)(l1 <= l2);
        }
        e.EV.Vint = (op != OPle) ^ b;
        break;
    }

    case OPnge:
    case OPge:
        if (!tyfloating(tym))
            goto Lnlt;
        e.EV.Vint = (op == OPnge) ^ (!unordered(d1, d2) && d1 >= d2);
        break;

    case OPnlt:
    Lnlt:
    case OPlt:
    {
        int b;
        if (uns)
        {
            b = cast(int)((cast(targ_ullong) l1) < (cast(targ_ullong) l2));
        }
        else
        {
            if (tyfloating(tym))
                b = cast(int)(!unordered(d1, d2) && d1 < d2);
            else
                b = cast(int)(l1 < l2);
        }
        e.EV.Vint = (op != OPlt) ^ b;
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
                    if (isnan(e1.EV.Vcfloat.re) || isnan(e1.EV.Vcfloat.im) ||
                        isnan(e2.EV.Vcfloat.re) || isnan(e2.EV.Vcfloat.im))
                        b = 0;
                    else
                        b = cast(int)((e1.EV.Vcfloat.re == e2.EV.Vcfloat.re) &&
                                      (e1.EV.Vcfloat.im == e2.EV.Vcfloat.im));
                    break;
                case TYcdouble:
                    if (isnan(e1.EV.Vcdouble.re) || isnan(e1.EV.Vcdouble.im) ||
                        isnan(e2.EV.Vcdouble.re) || isnan(e2.EV.Vcdouble.im))
                        b = 0;
                    else
                        b = cast(int)((e1.EV.Vcdouble.re == e2.EV.Vcdouble.re) &&
                                      (e1.EV.Vcdouble.im == e2.EV.Vcdouble.im));
                    break;
                case TYcldouble:
                    if (isnan(e1.EV.Vcldouble.re) || isnan(e1.EV.Vcldouble.im) ||
                        isnan(e2.EV.Vcldouble.re) || isnan(e2.EV.Vcldouble.im))
                        b = 0;
                    else
                        b = cast(int)((e1.EV.Vcldouble.re == e2.EV.Vcldouble.re) &&
                                      (e1.EV.Vcldouble.im == e2.EV.Vcldouble.im));
                    break;
                default:
                    b = cast(int)(d1 == d2);
                    break;
            }
            //printf("%Lg + %Lgi, %Lg + %Lgi\n", e1.EV.Vcldouble.re, e1.EV.Vcldouble.im, e2.EV.Vcldouble.re, e2.EV.Vcldouble.im);
        }
        else
            b = cast(int)(l1 == l2);
        e.EV.Vint = (op == OPne) ^ b;
        break;
    }

    case OPord:
    case OPunord:
        // BUG: complex numbers
        e.EV.Vint = (op == OPord) ^ (unordered(d1, d2)); // !<>=
        break;

    case OPnlg:
    case OPlg:
        // BUG: complex numbers
        e.EV.Vint = (op == OPnlg) ^ (!unordered(d1, d2) && d1 != d2); // <>
        break;

    case OPnleg:
    case OPleg:
        // BUG: complex numbers
        e.EV.Vint = (op == OPnleg) ^ (!unordered(d1, d2)); // <>=
        break;

    case OPnule:
    case OPule:
        // BUG: complex numbers
        e.EV.Vint = (op == OPnule) ^ (unordered(d1, d2) || d1 <= d2); // !>
        break;

    case OPnul:
    case OPul:
        // BUG: complex numbers
        e.EV.Vint = (op == OPnul) ^ (unordered(d1, d2) || d1 < d2); // !>=
        break;

    case OPnuge:
    case OPuge:
        // BUG: complex numbers
        e.EV.Vint = (op == OPnuge) ^ (unordered(d1, d2) || d1 >= d2); // !<
        break;

    case OPnug:
    case OPug:
        // BUG: complex numbers
        e.EV.Vint = (op == OPnug) ^ (unordered(d1, d2) || d1 > d2); // !<=
        break;

    case OPnue:
    case OPue:
        // BUG: complex numbers
        e.EV.Vint = (op == OPnue) ^ (unordered(d1, d2) || d1 == d2); // !<>
        break;

    case OPs16_32:
        e.EV.Vlong = cast(targ_short) i1;
        break;
    case OPnp_fp:
    case OPu16_32:
        e.EV.Vulong = cast(targ_ushort) i1;
        break;
    case OPd_u32:
        e.EV.Vulong = cast(targ_ulong)d1;
        //printf("OPd_u32: dbl = %g, ulng = x%lx\n",d1,e.EV.Vulong);
        break;
    case OPd_s32:
        e.EV.Vlong = cast(targ_long)d1;
        break;
    case OPu32_d:
        e.EV.Vdouble = cast(uint) l1;
        break;
    case OPs32_d:
        e.EV.Vdouble = cast(int) l1;
        break;
    case OPd_s16:
        e.EV.Vint = cast(targ_int)d1;
        break;
    case OPs16_d:
        e.EV.Vdouble = cast(targ_short) i1;
        break;
    case OPd_u16:
        e.EV.Vushort = cast(targ_ushort)d1;
        break;
    case OPu16_d:
        e.EV.Vdouble = cast(targ_ushort) i1;
        break;
    case OPd_s64:
        e.EV.Vllong = cast(targ_llong)d1;
        break;
    case OPd_u64:
    case OPld_u64:
        e.EV.Vullong = cast(targ_ullong)d1;
        break;
    case OPs64_d:
        e.EV.Vdouble = l1;
        break;
    case OPu64_d:
        e.EV.Vdouble = cast(targ_ullong) l1;
        break;
    case OPd_f:
        assert((statusFE() & 0x3800) == 0);
        e.EV.Vfloat = e1.EV.Vdouble;
        if (tycomplex(tym))
            e.EV.Vcfloat.im = e1.EV.Vcdouble.im;
        assert((statusFE() & 0x3800) == 0);
        break;
    case OPf_d:
        e.EV.Vdouble = e1.EV.Vfloat;
        if (tycomplex(tym))
            e.EV.Vcdouble.im = e1.EV.Vcfloat.im;
        break;
    case OPd_ld:
        e.EV.Vldouble = e1.EV.Vdouble;
        if (tycomplex(tym))
            e.EV.Vcldouble.im = e1.EV.Vcdouble.im;
        break;
    case OPld_d:
        e.EV.Vdouble = cast(double)e1.EV.Vldouble;
        if (tycomplex(tym))
            e.EV.Vcdouble.im = cast(double)e1.EV.Vcldouble.im;
        break;
    case OPc_r:
        e.EV = e1.EV;
        break;
    case OPc_i:
        switch (tym)
        {
            case TYcfloat:
                e.EV.Vfloat = e1.EV.Vcfloat.im;
                break;
            case TYcdouble:
                e.EV.Vdouble = e1.EV.Vcdouble.im;
                break;
            case TYcldouble:
                e.EV.Vldouble = e1.EV.Vcldouble.im;
                break;
            default:
                assert(0);
        }
        break;
    case OPs8_16:
        e.EV.Vint = cast(targ_schar) i1;
        break;
    case OPu8_16:
        e.EV.Vint = i1 & 0xFF;
        break;
    case OP16_8:
        e.EV.Vint = i1;
        break;
    case OPbool:
        e.EV.Vint = boolres(e1);
        break;
    case OP32_16:
    case OPoffset:
        e.EV.Vint = cast(targ_int)l1;
        break;

    case OP64_32:
        e.EV.Vlong = cast(targ_long)l1;
        break;
    case OPs32_64:
        e.EV.Vllong = cast(targ_long) l1;
        break;
    case OPu32_64:
        e.EV.Vllong = cast(targ_ulong) l1;
        break;

    case OP128_64:
        e.EV.Vllong = e1.EV.Vcent.lsw;
        break;
    case OPs64_128:
        e.EV.Vcent.lsw = e1.EV.Vllong;
        e.EV.Vcent.msw = 0;
        if (cast(targ_llong)e.EV.Vcent.lsw < 0)
            e.EV.Vcent.msw = ~cast(targ_ullong)0;
        break;
    case OPu64_128:
        e.EV.Vcent.lsw = e1.EV.Vullong;
        e.EV.Vcent.msw = 0;
        break;

    case OPmsw:
        switch (tysize(tym))
        {
            case 4:
                e.EV.Vllong = (l1 >> 16) & 0xFFFF;
                break;
            case 8:
                e.EV.Vllong = (l1 >> 32) & 0xFFFFFFFF;
                break;
            case 16:
                e.EV.Vllong = e1.EV.Vcent.msw;
                break;
            default:
                assert(0);
        }
        break;
    case OPb_8:
        e.EV.Vlong = i1 & 1;
        break;
    case OPbswap:
        if (tysize(tym) == 2)
        {
            e.EV.Vint = ((i1 >> 8) & 0x00FF) |
                        ((i1 << 8) & 0xFF00);
        }
        else if (tysize(tym) == 4)
            e.EV.Vint = core.bitop.bswap(cast(uint) i1);
        else
            e.EV.Vllong = core.bitop.bswap(cast(ulong) l1);
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
        e.EV.Vllong = core.bitop.popcnt(cast(ulong) l1);
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
                e.EV.Vuchar = cast(ubyte)((i1 << n) | ((i1 & 0xFF) >> (8 - n)));
                break;
            case 2:
                n &= 0xF;
                e.EV.Vushort = cast(targ_ushort)((i1 << n) | ((i1 & 0xFFFF) >> (16 - n)));
                break;
            case 4:
                n &= 0x1F;
                e.EV.Vulong = cast(targ_ulong)((i1 << n) | ((i1 & 0xFFFFFFFF) >> (32 - n)));
                break;
            case 8:
                n &= 0x3F;
                e.EV.Vullong = cast(targ_ullong)((l1 << n) | ((l1 & 0xFFFFFFFFFFFFFFFFL) >> (64 - n)));
                break;
            //case 16:
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
            error(e.Esrcpos.Sfilename, e.Esrcpos.Slinnum, e.Esrcpos.Scharnum,
                "dereference of null pointer");
            e.EV.E1.EV.Vlong = 4096;     // suppress redundant messages
        }
}
        return e;

    case OPvecfill:
        switch (tybasic(e.Ety))
        {
            // 16 byte vectors
            case TYfloat4:
                foreach (ref lhsElem; e.EV.Vfloat4)
                    lhsElem = e1.EV.Vfloat;
                break;
            case TYdouble2:
                foreach (ref lhsElem; e.EV.Vdouble2)
                    lhsElem = e1.EV.Vdouble;
                break;
            case TYschar16:
            case TYuchar16:
                foreach (ref lhsElem; e.EV.Vuchar16)
                    lhsElem = cast(targ_uchar)i1;
                break;
            case TYshort8:
            case TYushort8:
                foreach (ref lhsElem; e.EV.Vushort8)
                    lhsElem = cast(targ_ushort)i1;
                break;
            case TYlong4:
            case TYulong4:
                foreach (ref lhsElem; e.EV.Vulong4)
                    lhsElem = cast(targ_ulong)i1;
                break;
            case TYllong2:
            case TYullong2:
                foreach (ref lhsElem; e.EV.Vullong2)
                    lhsElem = cast(targ_ullong)l1;
                break;

            // 32 byte vectors
            case TYfloat8:
                foreach (ref lhsElem; e.EV.Vfloat8)
                    lhsElem = e1.EV.Vfloat;
                break;
            case TYdouble4:
                foreach (ref lhsElem; e.EV.Vdouble4)
                    lhsElem = e1.EV.Vdouble;
                break;
            case TYschar32:
            case TYuchar32:
                foreach (ref lhsElem; e.EV.Vuchar32)
                    lhsElem = cast(targ_uchar)i1;
                break;
            case TYshort16:
            case TYushort16:
                foreach (ref lhsElem; e.EV.Vushort16)
                    lhsElem = cast(targ_ushort)i1;
                break;
            case TYlong8:
            case TYulong8:
                foreach (ref lhsElem; e.EV.Vulong8)
                    lhsElem = cast(targ_ulong)i1;
                break;
            case TYllong4:
            case TYullong4:
                foreach (ref lhsElem; e.EV.Vullong4)
                    lhsElem = cast(targ_ullong)l1;
                break;

            default:
                assert(0);
        }
        break;

    default:
        return e;
  }

    int flags;

    if (!(goal & GOALignore_exceptions) &&
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
version (SCPP)
{
        if ((flags = statusFE()) & 0x3F)
        {   // Should also give diagnostic warning for:
            // overflow, underflow, denormal, invalid
            if (flags & 0x04)
                warerr(WM.WM_divby0);
    //      else if (flags & 0x08)          // overflow
    //          warerr(WM.WM_badnumber);
        }
}
    }

  /*debug printf("result = x%lx\n",e.EV.Vlong);*/
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

extern (D) targ_ldouble el_toldoubled(elem *e)
{
    targ_ldouble result;

    elem_debug(e);
    assert(e.Eoper == OPconst);
    switch (tybasic(typemask(e)))
    {
        case TYfloat:
        case TYifloat:
            result = e.EV.Vfloat;
            break;
        case TYdouble:
        case TYidouble:
        case TYdouble_alias:
            result = e.EV.Vdouble;
            break;
        case TYldouble:
        case TYildouble:
            result = e.EV.Vldouble;
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
    targ_ldouble _modulo(targ_ldouble x, targ_ldouble y);
}
}
