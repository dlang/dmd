
// Compiler implementation of the D programming language
// Copyright (c) 1999-2011 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <assert.h>

#include "root.h"
#include "aggregate.h"
#include "scope.h"
#include "mtype.h"
#include "declaration.h"
#include "module.h"
#include "id.h"
#include "expression.h"
#include "statement.h"


/*********************************
 * Generate expression that calls opClone()
 * for each member of the struct
 * (can be NULL for members that don't need one)
 */

#if DMDV2
Expression *StructDeclaration::cloneMembers()
{
    Expression *e = NULL;

    for (size_t i = 0; i < fields.dim; i++)
    {
        Dsymbol *s = (Dsymbol *)fields.data[i];
        VarDeclaration *v = s->isVarDeclaration();
        assert(v && v->storage_class & STCfield);
        Type *tv = v->type->toBasetype();
        dinteger_t dim = (tv->ty == Tsarray ? 1 : 0);
        while (tv->ty == Tsarray)
        {   TypeSArray *ta = (TypeSArray *)tv;
            dim *= ((TypeSArray *)tv)->dim->toInteger();
            tv = tv->nextOf()->toBasetype();
        }
        if (tv->ty == Tstruct)
        {   TypeStruct *ts = (TypeStruct *)tv;
            StructDeclaration *sd = ts->sym;
            if (sd->opclone)
            {

                // this.v
                Expression *ex = new ThisExp(0);
                ex = new DotVarExp(0, ex, v, 0);

                if (dim == 1)
                {   // this.v.opClone()
                    ex = new DotVarExp(0, ex, sd->opclone, 0);
                    ex = new CallExp(0, ex);
                }
                else
                {
                    // _callOpClones(&this.v, opclone, dim)
                    Expressions *args = new Expressions();
                    args->push(new AddrExp(0, ex));
                    args->push(new SymOffExp(0, sd->opclone, 0));
                    args->push(new IntegerExp(dim));
                    FuncDeclaration *ec = FuncDeclaration::genCfunc(Type::tvoid, "_callOpClones");
                    ex = new CallExp(0, new VarExp(0, ec), args);
                }
                e = Expression::combine(e, ex);
            }
        }
    }
    return e;
}
#endif

/*****************************************
 * Create inclusive destructor for struct by aggregating
 * all the destructors in dtors[] with the destructors for
 * all the members.
 */

FuncDeclaration *AggregateDeclaration::buildDtor(Scope *sc)
{
    //printf("StructDeclaration::buildDtor() %s\n", toChars());
    Expression *e = NULL;

#if DMDV2
    for (size_t i = 0; i < fields.dim; i++)
    {
        Dsymbol *s = (Dsymbol *)fields.data[i];
        VarDeclaration *v = s->isVarDeclaration();
        assert(v && v->storage_class & STCfield);
        Type *tv = v->type->toBasetype();
        dinteger_t dim = (tv->ty == Tsarray ? 1 : 0);
        while (tv->ty == Tsarray)
        {   TypeSArray *ta = (TypeSArray *)tv;
            dim *= ((TypeSArray *)tv)->dim->toInteger();
            tv = tv->nextOf()->toBasetype();
        }
        if (tv->ty == Tstruct)
        {   TypeStruct *ts = (TypeStruct *)tv;
            StructDeclaration *sd = ts->sym;
            if (sd->dtor)
            {   Expression *ex;

                // this.v
                ex = new ThisExp(0);
                ex = new DotVarExp(0, ex, v, 0);

                if (dim == 1)
                {   // this.v.dtor()
                    ex = new DotVarExp(0, ex, sd->dtor, 0);
                    ex = new CallExp(0, ex);
                }
                else
                {
                    // Typeinfo.destroy(cast(void*)&this.v);
                    Expression *ea = new AddrExp(0, ex);
                    ea = new CastExp(0, ea, Type::tvoid->pointerTo());
                    Expressions *args = new Expressions();
                    args->push(ea);

                    Expression *et = v->type->getTypeInfo(sc);
                    et = new DotIdExp(0, et, Id::destroy);

                    ex = new CallExp(0, et, args);
                }
                e = Expression::combine(ex, e); // combine in reverse order
            }
        }
    }

    /* Build our own "destructor" which executes e
     */
    if (e)
    {   //printf("Building __fieldDtor()\n");
        DtorDeclaration *dd = new DtorDeclaration(loc, 0, Lexer::idPool("__fieldDtor"));
        dd->fbody = new ExpStatement(0, e);
        dtors.shift(dd);
        members->push(dd);
        dd->semantic(sc);
    }
#endif

    switch (dtors.dim)
    {
        case 0:
            return NULL;

        case 1:
            return (FuncDeclaration *)dtors.data[0];

        default:
            e = NULL;
            for (size_t i = 0; i < dtors.dim; i++)
            {   FuncDeclaration *fd = (FuncDeclaration *)dtors.data[i];
                Expression *ex = new ThisExp(0);
                ex = new DotVarExp(0, ex, fd);
                ex = new CallExp(0, ex);
                e = Expression::combine(ex, e);
            }
            DtorDeclaration *dd = new DtorDeclaration(loc, 0, Lexer::idPool("__aggrDtor"));
            dd->fbody = new ExpStatement(0, e);
            members->push(dd);
            dd->semantic(sc);
            return dd;
    }
}


