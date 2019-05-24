/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1995-1998 by Symantec
 *              Copyright (C) 2000-2019 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/ee.d, backend/ee.d)
 */
module dmd.backend.ee;

/*
 * Code to handle debugger expression evaluation
 */

version (SPP) {}
else:

import core.stdc.stdio;
import core.stdc.string;
import core.stdc.time;
import dmd.backend.cc;
import dmd.backend.cdef;
import dmd.backend.global;
import dmd.backend.type;
import dmd.backend.oper;
import dmd.backend.el;
import dmd.backend.exh;
import dmd.backend.cgcv;
import dmd.backend.code_x86 : code;
version (SCPP)
{
import parser;
}

import dmd.backend.iasm;

extern(C++):

version (MARS)
{
__gshared EEcontext eecontext;
}

/**************************************************
* This is to support compiling expressions within the context of a function.
*/

struct EEcontext
{
    uint EElinnum;              // line number to insert expression
    char *EEexpr;               // expression
    char *EEtypedef;            // typedef identifier
    byte EEpending;             // !=0 means we haven't compiled it yet
    byte EEimminent;            // we've installed it in the source text
    byte EEcompile;             // we're compiling for the EE expression
    byte EEin;                  // we are parsing an EE expression
    elem *EEelem;               // compiled version of EEexpr
    Symbol *EEfunc;             // function expression is in
    code *EEcode;               // generated code


//////////////////////////////////////
// Convert any symbols generated for the debugger expression to SCstack
// storage class.

    void convs(uint marksi)
    {
        uint u;
        uint top;
        symtab_t *ps;

    // Change all generated SCauto's to SCstack's
version (SCPP)
{
        ps = &globsym;
}
else
{
        ps = cstate.CSpsymtab;
}
        top = ps.top;
        //printf("eecontext_convs(%d,%d)\n",marksi,top);
        foreach(Symbol *s; ps.tab[u .. top])
        {
            s = ps.tab[u];
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
        if (!EEimminent)
            return;

        type *t;
        uint marksi;
        Symbol *s;

        //printf("imminent\n");
        marksi = globsym.top;
        EEin++;
        s = symbol_genauto(tspvoid);
        EEelem = func_expr_dtor(true);
        t = EEelem.ET;
        if (tybasic(t.Tty) != TYvoid)
        {   uint op;
            elem *e;

            e = el_unat(OPind,t,el_var(s));
            op = tyaggregate(t.Tty) ? OPstreq : OPeq;
            EEelem = el_bint(op,t,e,EEelem);
        }
        EEin--;
        EEimminent = 0;
        EEfunc = funcsym_p;

        convs(marksi);

        // Generate the typedef
        if (EEtypedef && config.fulltypes)
        {   Symbol *s;

            s = symbol_name(EEtypedef,SCtypedef,t);
            cv_outsym(s);
            symbol_free(s);
        }
    }
}
}


