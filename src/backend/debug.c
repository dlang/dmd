// Copyright (C) 1985-1998 by Symantec
// Copyright (C) 2000-2012 by Digital Mars
// All Rights Reserved
// http://www.digitalmars.com
// Written by Walter Bright
/*
 * This source file is made available for personal use
 * only. The license is in backendlicense.txt
 * For any other uses, please contact Digital Mars.
 */

#ifdef DEBUG
#if !SPP

#include        <stdio.h>
#include        <time.h>

#include        "cc.h"
#include        "oper.h"
#include        "type.h"
#include        "el.h"
#include        "token.h"
#include        "global.h"
#include        "vec.h"
#include        "go.h"
#include        "code.h"
#include        "debtab.c"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

#define ferr(p) dbg_printf("%s",(p))

/*******************************
 * Write out storage class.
 */

char *str_class(enum SC c)
{ static char sc[SCMAX][10] =
  {
        #define X(a,b)  #a,
        ENUMSCMAC
        #undef X
  };
  static char buffer[9 + 3];

  (void) assert(arraysize(sc) == SCMAX);
  if ((unsigned) c < (unsigned) SCMAX)
        sprintf(buffer,"SC%s",sc[(int) c]);
  else
        sprintf(buffer,"SC%u",(unsigned)c);
  return buffer;
}

void WRclass(enum SC c)
{
    dbg_printf("%11s ",str_class(c));
}

/***************************
 * Write out oper numbers.
 */

void WROP(unsigned oper)
{
  if (oper >= OPMAX)
  {     dbg_printf("op = x%x, OPMAX = %d\n",oper,OPMAX);
        assert(0);
  }
  ferr(debtab[oper]);
  ferr(" ");
}

/*******************************
 * Write TYxxxx
 */

void WRTYxx(tym_t t)
{
#if TX86
    if (t & mTYnear)
        dbg_printf("mTYnear|");
#if TARGET_SEGMENTED
    if (t & mTYfar)
        dbg_printf("mTYfar|");
    if (t & mTYcs)
        dbg_printf("mTYcs|");
#endif
#endif
    if (t & mTYconst)
        dbg_printf("mTYconst|");
    if (t & mTYvolatile)
        dbg_printf("mTYvolatile|");
#if !MARS && (__linux__ || __APPLE__ || __FreeBSD__ || __OpenBSD__ || __sun)
    if (t & mTYtransu)
        dbg_printf("mTYtransu|");
#endif
    t = tybasic(t);
    if (t >= TYMAX)
    {   dbg_printf("TY %lx\n",(long)t);
        assert(0);
    }
    dbg_printf("TY%s ",tystring[tybasic(t)]);
}

void WRBC(unsigned bc)
{ static char bcs[][7] =
        {"unde  ","goto  ","true  ","ret   ","retexp",
         "exit  ","asm   ","switch","ifthen","jmptab",
         "try   ","catch ","jump  ",
         "_try  ","_filte","_final","_ret  ","_excep",
         "jcatch",
         "jplace",
        };

    assert(sizeof(bcs) / sizeof(bcs[0]) == BCMAX);
    assert(bc < BCMAX);
    dbg_printf("BC%s",bcs[bc]);
}

/************************
 * Write arglst
 */

void WRarglst(list_t a)
{ int n = 1;

  if (!a) dbg_printf("0 args\n");
  while (a)
  {     const char* c = (const char*)list_ptr(a);
        dbg_printf("arg %d: '%s'\n", n, c ? c : "NULL");
        a = a->next;
        n++;
  }
}

/***************************
 * Write out equation elem.
 */

void WReqn(elem *e)
{ static int nest;

  if (!e)
        return;
  if (OTunary(e->Eoper))
  {
        WROP(e->Eoper);
        if (OTbinary(e->E1->Eoper))
        {       nest++;
                ferr("(");
                WReqn(e->E1);
                ferr(")");
                nest--;
        }
        else
                WReqn(e->E1);
  }
  else if (e->Eoper == OPcomma && !nest)
  {     WReqn(e->E1);
        dbg_printf(";\n\t");
        WReqn(e->E2);
  }
  else if (OTbinary(e->Eoper))
  {
        if (OTbinary(e->E1->Eoper))
        {       nest++;
                ferr("(");
                WReqn(e->E1);
                ferr(")");
                nest--;
        }
        else
                WReqn(e->E1);
        ferr(" ");
        WROP(e->Eoper);
        if (e->Eoper == OPstreq)
            dbg_printf("%ld",(long)type_size(e->ET));
        ferr(" ");
        if (OTbinary(e->E2->Eoper))
        {       nest++;
                ferr("(");
                WReqn(e->E2);
                ferr(")");
                nest--;
        }
        else
                WReqn(e->E2);
  }
  else
  {
        switch (e->Eoper)
        {   case OPconst:
                elem_print_const(e);
                break;
            case OPrelconst:
                ferr("#");
                /* FALL-THROUGH */
            case OPvar:
                dbg_printf("%s",e->EV.sp.Vsym->Sident);
                if (e->EV.sp.Vsym->Ssymnum != -1)
                    dbg_printf("(%d)",e->EV.sp.Vsym->Ssymnum);
                if (e->Eoffset != 0)
                {
                    if (sizeof(e->Eoffset) == 8)
                        dbg_printf(".x%llx", e->Eoffset);
                    else
                        dbg_printf(".%ld",(long)e->Eoffset);
                }
                break;
            case OPasm:
            case OPstring:
                dbg_printf("\"%s\"",e->EV.ss.Vstring);
                if (e->EV.ss.Voffset)
                    dbg_printf("+%ld",(long)e->EV.ss.Voffset);
                break;
            case OPmark:
            case OPgot:
            case OPframeptr:
            case OPhalt:
                WROP(e->Eoper);
                break;
            case OPstrthis:
                break;
            default:
                WROP(e->Eoper);
                assert(0);
        }
  }
}

void WRblocklist(list_t bl)
{
        for (; bl; bl = list_next(bl))
        {       register block *b = list_block(bl);

                if (b && b->Bweight)
                        dbg_printf("B%d (%p) ",b->Bdfoidx,b);
                else
                        dbg_printf("%p ",b);
        }
        ferr("\n");
}

void WRdefnod()
{ register int i;

  for (i = 0; i < deftop; i++)
  {     dbg_printf("defnod[%d] in B%d = (",defnod[i].DNblock->Bdfoidx,i);
        WReqn(defnod[i].DNelem);
        dbg_printf(");\n");
  }
}

void WRFL(enum FL fl)
{
    static const char fls[FLMAX][7] =
    {    "unde  ","const ","oper  ","func  ","data  ",
         "reg   ",
         "pseudo",
         "auto  ","fast  ","para  ","extrn ",
         "code  ","block ","udata ","cs    ","swit  ",
         "fltrg ","offst ","datsg ",
         "ctor  ","dtor  ","regsav","asm   ",
         "ndp   ",
         "farda ","csdat ",
         "local ","tlsdat",
         "bprel ","frameh","blocko","alloca",
         "stack ","dsym  ",
         "got   ","gotoff",
    };

    if ((unsigned)fl >= (unsigned)FLMAX)
        dbg_printf("FL%d",fl);
    else
      dbg_printf("FL%s",fls[fl]);
}

/***********************
 * Write out block.
 */

void WRblock(block *b)
{
    if (OPTIMIZER)
    {
        if (b && b->Bweight)
                dbg_printf("B%d: (%p), weight=%d",b->Bdfoidx,b,b->Bweight);
        else
                dbg_printf("block %p",b);
        if (!b)
        {       ferr("\n");
                return;
        }
        dbg_printf(" flags=x%x weight=%d",b->Bflags,b->Bweight);
#if 0
        dbg_printf("\tfile %p, line %d",b->Bfilptr,b->Blinnum);
#endif
        dbg_printf(" ");
        WRBC(b->BC);
        dbg_printf(" Btry=%p Bindex=%d",b->Btry,b->Bindex);
#if SCPP
        if (b->BC == BCtry)
            dbg_printf(" catchvar = %p",b->catchvar);
#endif
        dbg_printf("\n");
        dbg_printf("\tBpred: "); WRblocklist(b->Bpred);
        dbg_printf("\tBsucc: "); WRblocklist(b->Bsucc);
        if (b->Belem)
        {       if (debugf)                     /* if full output       */
                        elem_print(b->Belem);
                else
                {       ferr("\t");
                        WReqn(b->Belem);
                        dbg_printf(";\n");
                }
        }
        if (b->Bcode)
            b->Bcode->print();
        ferr("\n");
    }
    else
    {
        targ_llong *pu;
        int ncases;
        list_t bl;

        assert(b);
        dbg_printf("********* Basic Block %p ************\n",b);
        if (b->Belem) elem_print(b->Belem);
        dbg_printf("block: ");
printf("%p %d ", b, b->BC);
        WRBC(b->BC);
        dbg_printf(" Btry=%p Bindex=%d",b->Btry,b->Bindex);
#if MARS
        if (b->Bsrcpos.Sfilename)
            dbg_printf(" %s(%u)", b->Bsrcpos.Sfilename, b->Bsrcpos.Slinnum);
#endif
        dbg_printf("\n");
        dbg_printf("\tBpred:\n");
        for (bl = b->Bpred; bl; bl = list_next(bl))
            dbg_printf("\t%p\n",list_block(bl));
        bl = b->Bsucc;
        switch (b->BC)
        {
            case BCswitch:
                pu = b->BS.Bswitch;
                assert(pu);
                ncases = *pu;
                dbg_printf("\tncases = %d\n",ncases);
                dbg_printf("\tdefault: %p\n",list_block(bl));
                while (ncases--)
                {   bl = list_next(bl);
                    dbg_printf("\tcase %lld: %p\n",*++pu,list_block(bl));
                }
                break;
            case BCiftrue:
            case BCgoto:
            case BCasm:
#if SCPP
            case BCtry:
            case BCcatch:
#endif
            case BCjcatch:
            case BC_try:
            case BC_filter:
            case BC_finally:
            case BC_ret:
            case BC_except:

            Lsucc:
                dbg_printf("\tBsucc:\n");
                for ( ; bl; bl = list_next(bl))
                    dbg_printf("\t%p\n",list_block(bl));
                break;
            case BCret:
            case BCretexp:
            case BCexit:
                break;
            default:
                assert(0);
        }
    }
}

void WRfunc()
{
        block *b;

        dbg_printf("func: '%s'\n",funcsym_p->Sident);
        for (b = startblock; b; b = b->Bnext)
                WRblock(b);
}

#endif /* DEBUG */
#endif /* !SPP */
