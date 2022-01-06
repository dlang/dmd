/**
 * Code to handle debugger expression evaluation
 *
 * Compiler implementation of the
 * $(LINK2 https://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1995-1998 by Symantec
 *              Copyright (C) 2000-2022 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 https://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 https://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/ee.d, backend/ee.d)
 */
module dmd.backend.ee;

version (SPP) {} else
{

import core.stdc.stdio;
import core.stdc.string;
import core.stdc.time;
import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.global;
import dmd.backend.symtab;
import dmd.backend.type;
import dmd.backend.oper;
import dmd.backend.el;
import dmd.backend.exh;
import dmd.backend.cgcv;
import dmd.backend.symtab;
version (SCPP)
{
import parser;
}

import dmd.backend.iasm;

extern(C++):

nothrow:

version (MARS)
{
__gshared EEcontext eecontext;
}

//////////////////////////////////////
// Convert any symbols generated for the debugger expression to SCstack
// storage class.

void eecontext_convs(SYMIDX marksi)
{
    symtab_t *ps;

    // Change all generated SCauto's to SCstack's
    version (SCPP)
    {
        ps = &globsym;
    }
    else version (HTOD)
    {
        ps = &globsym;
    }
    else
    {
        ps = cstate.CSpsymtab;
    }
    const top = ps.length;
    //printf("eecontext_convs(%d,%d)\n",marksi,top);
    foreach (u; marksi .. top)
    {
        auto s = (*ps)[u];
        switch (s.Sclass)
        {
            case SCauto:
            case SCregister:
                s.Sclass = SCstack;
                s.Sfl = FLstack;
                break;
            default:
                break;
        }
    }
}

////////////////////////////////////////
// Parse the debugger expression.

version (SCPP)
{

void eecontext_parse()
{
    if (eecontext.EEimminent)
    {   type *t;
        Symbol *s;

        //printf("imminent\n");
        const marksi = globsym.length;
        eecontext.EEin++;
        s = symbol_genauto(tspvoid);
        eecontext.EEelem = func_expr_dtor(true);
        t = eecontext.EEelem.ET;
        if (tybasic(t.Tty) != TYvoid)
        {   uint op;
            elem *e;

            e = el_unat(OPind,t,el_var(s));
            op = tyaggregate(t.Tty) ? OPstreq : OPeq;
            eecontext.EEelem = el_bint(op,t,e,eecontext.EEelem);
        }
        eecontext.EEin--;
        eecontext.EEimminent = 0;
        eecontext.EEfunc = funcsym_p;

        eecontext_convs(marksi);

        // Generate the typedef
        if (eecontext.EEtypedef && config.fulltypes)
        {   Symbol *s;

            s = symbol_name(eecontext.EEtypedef,SCtypedef,t);
            cv_outsym(s);
            symbol_free(s);
        }
    }
}

}
}
