/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (c) 2000-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     Distributed under the Boost Software License, Version 1.0.
 *              http://www.boost.org/LICENSE_1_0.txt
 * Source:      https://github.com/dlang/dmd/blob/master/src/ddmd/backend/debug.c
 */

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

#define ferr(p) printf("%s",(p))

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
    printf("%11s ",str_class(c));
}

/***************************
 * Write out oper numbers.
 */

void WROP(unsigned oper)
{
  if (oper >= OPMAX)
  {     printf("op = x%x, OPMAX = %d\n",oper,OPMAX);
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
    if (t & mTYnear)
        printf("mTYnear|");
    if (t & mTYfar)
        printf("mTYfar|");
    if (t & mTYcs)
        printf("mTYcs|");
    if (t & mTYconst)
        printf("mTYconst|");
    if (t & mTYvolatile)
        printf("mTYvolatile|");
#if !MARS && (__linux__ || __APPLE__ || __FreeBSD__ || __OpenBSD__ || __sun)
    if (t & mTYtransu)
        printf("mTYtransu|");
#endif
    t = tybasic(t);
    if (t >= TYMAX)
    {   printf("TY %lx\n",(long)t);
        assert(0);
    }
    printf("TY%s ",tystring[tybasic(t)]);
}

void WRBC(unsigned bc)
{ static char bcs[][7] =
        {"unde  ","goto  ","true  ","ret   ","retexp",
         "exit  ","asm   ","switch","ifthen","jmptab",
         "try   ","catch ","jump  ",
         "_try  ","_filte","_final","_ret  ","_excep",
         "jcatch","_lpad ",
        };

    assert(sizeof(bcs) / sizeof(bcs[0]) == BCMAX);
    assert(bc < BCMAX);
    printf("BC%s",bcs[bc]);
}

/************************
 * Write arglst
 */

void WRarglst(list_t a)
{ int n = 1;

  if (!a) printf("0 args\n");
  while (a)
  {     const char* c = (const char*)list_ptr(a);
        printf("arg %d: '%s'\n", n, c ? c : "NULL");
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
        printf(";\n\t");
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
            printf("%ld",(long)type_size(e->ET));
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
                printf("%s",e->EV.sp.Vsym->Sident);
                if (e->EV.sp.Vsym->Ssymnum != -1)
                    printf("(%d)",e->EV.sp.Vsym->Ssymnum);
                if (e->Eoffset != 0)
                {
                    if (sizeof(e->Eoffset) == 8)
                        printf(".x%llx", (unsigned long long)e->Eoffset);
                    else
                        printf(".%ld",(long)e->Eoffset);
                }
                break;
            case OPasm:
            case OPstring:
                printf("\"%s\"",e->EV.ss.Vstring);
                if (e->EV.ss.Voffset)
                    printf("+%ld",(long)e->EV.ss.Voffset);
                break;
            case OPmark:
            case OPgot:
            case OPframeptr:
            case OPhalt:
            case OPdctor:
            case OPddtor:
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
                        printf("B%d (%p) ",b->Bdfoidx,b);
                else
                        printf("%p ",b);
        }
        ferr("\n");
}

void WRdefnod()
{ register int i;

  for (i = 0; i < go.deftop; i++)
  {     printf("defnod[%d] in B%d = (", go.defnod[i].DNblock->Bdfoidx, i);
        WReqn(go.defnod[i].DNelem);
        printf(");\n");
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
         "funcar",
    };

    if ((unsigned)fl >= (unsigned)FLMAX)
        printf("FL%d",fl);
    else
      printf("FL%s",fls[fl]);
}

/***********************
 * Write out block.
 */

void WRblock(block *b)
{
    if (OPTIMIZER)
    {
        if (b && b->Bweight)
                printf("B%d: (%p), weight=%d",b->Bdfoidx,b,b->Bweight);
        else
                printf("block %p",b);
        if (!b)
        {       ferr("\n");
                return;
        }
        printf(" flags=x%x weight=%d",b->Bflags,b->Bweight);
        //printf("\tfile %p, line %d",b->Bfilptr,b->Blinnum);
        printf(" ");
        WRBC(b->BC);
        printf(" Btry=%p Bindex=%d",b->Btry,b->Bindex);
        if (b->BC == BCtry)
            printf(" catchvar = %p",b->catchvar);
        printf("\n");
        printf("\tBpred: "); WRblocklist(b->Bpred);
        printf("\tBsucc: "); WRblocklist(b->Bsucc);
        if (b->Belem)
        {       if (debugf)                     /* if full output       */
                        elem_print(b->Belem);
                else
                {       ferr("\t");
                        WReqn(b->Belem);
                        printf(";\n");
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

        assert(b);
        printf("***** block %p ", b);
        WRBC(b->BC);
        if (b->Btry)
            printf(" Btry=%p",b->Btry);
        if (b->Bindex)
            printf(" Bindex=%d",b->Bindex);
        if (b->BC == BC_finally)
            printf(" b_ret=%p", b->BS.BI_FINALLY.b_ret);
#if MARS
        if (b->Bsrcpos.Sfilename)
            printf(" %s(%u)", b->Bsrcpos.Sfilename, b->Bsrcpos.Slinnum);
#endif
        printf("\n");
        if (b->Belem) elem_print(b->Belem);
        if (b->Bpred)
        {
            printf("\tBpred:");
            for (list_t bl = b->Bpred; bl; bl = list_next(bl))
                printf(" %p",list_block(bl));
            printf("\n");
        }
        list_t bl = b->Bsucc;
        switch (b->BC)
        {
            case BCswitch:
                pu = b->BS.Bswitch;
                assert(pu);
                ncases = *pu;
                printf("\tncases = %d\n",ncases);
                printf("\tdefault: %p\n",list_block(bl));
                while (ncases--)
                {   bl = list_next(bl);
                    printf("\tcase %lld: %p\n",(long long)*++pu,list_block(bl));
                }
                break;
            case BCiftrue:
            case BCgoto:
            case BCasm:
            case BCtry:
            case BCcatch:
            case BCjcatch:
            case BC_try:
            case BC_filter:
            case BC_finally:
            case BC_lpad:
            case BC_ret:
            case BC_except:

            Lsucc:
                if (bl)
                {
                    printf("\tBsucc:");
                    for ( ; bl; bl = list_next(bl))
                        printf(" %p",list_block(bl));
                    printf("\n");
                }
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

        printf("func: '%s'\n",funcsym_p->Sident);
        for (b = startblock; b; b = b->Bnext)
                WRblock(b);
}

#endif /* DEBUG */
