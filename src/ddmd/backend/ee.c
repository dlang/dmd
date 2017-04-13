/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1995-1998 by Symantec
 *              Copyright (c) 2000-2017 by Digital Mars, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     Distributed under the Boost Software License, Version 1.0.
 *              http://www.boost.org/LICENSE_1_0.txt
 * Source:      https://github.com/dlang/dmd/blob/master/src/ddmd/backend/ee.c
 */


/*
 * Code to handle debugger expression evaluation
 */

#if !SPP

#include        <stdio.h>
#include        <string.h>
#include        <time.h>
#include        "cc.h"
#include        "token.h"
#include        "global.h"
#include        "type.h"
#include        "oper.h"
#include        "el.h"
#include        "exh.h"
#if TX86
#include        "cgcv.h"
#endif

#if SCPP
#include        "parser.h"
#endif

#include        "iasm.h"

static char __file__[] = __FILE__;      /* for tassert.h                */
#include        "tassert.h"

#if MARS
EEcontext eecontext;
#endif

//////////////////////////////////////
// Convert any symbols generated for the debugger expression to SCstack
// storage class.

void eecontext_convs(unsigned marksi)
{   unsigned u;
    unsigned top;
    symtab_t *ps;

    // Change all generated SCauto's to SCstack's
#if SCPP
    ps = &globsym;
#else
    ps = cstate.CSpsymtab;
#endif
    top = ps->top;
    //printf("eecontext_convs(%d,%d)\n",marksi,top);
    for (u = marksi; u < top; u++)
    {   symbol *s;

        s = ps->tab[u];
        switch (s->Sclass)
        {
            case SCauto:
            case SCregister:
                s->Sclass = SCstack;
                s->Sfl = FLstack;
                break;
        }
    }
}

////////////////////////////////////////
// Parse the debugger expression.

#if SCPP

void eecontext_parse()
{
    if (eecontext.EEimminent)
    {   type *t;
        unsigned marksi;
        symbol *s;

        //printf("imminent\n");
        marksi = globsym.top;
        eecontext.EEin++;
        s = symbol_genauto(tspvoid);
        eecontext.EEelem = func_expr_dtor(TRUE);
        t = eecontext.EEelem->ET;
        if (tybasic(t->Tty) != TYvoid)
        {   unsigned op;
            elem *e;

            e = el_unat(OPind,t,el_var(s));
            op = tyaggregate(t->Tty) ? OPstreq : OPeq;
            eecontext.EEelem = el_bint(op,t,e,eecontext.EEelem);
        }
        eecontext.EEin--;
        eecontext.EEimminent = 0;
        eecontext.EEfunc = funcsym_p;

        eecontext_convs(marksi);

        // Generate the typedef
        if (eecontext.EEtypedef && config.fulltypes)
        {   symbol *s;

            s = symbol_name(eecontext.EEtypedef,SCtypedef,t);
            cv_outsym(s);
            symbol_free(s);
        }
    }
}

#endif
#endif
