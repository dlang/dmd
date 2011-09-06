
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
#include "init.h"


/*******************************************
 * We need an opAssign for the struct if
 * it has a destructor or a postblit.
 * We need to generate one if a user-specified one does not exist.
 */

int StructDeclaration::needOpAssign()
{
#define X 0
    if (X) printf("StructDeclaration::needOpAssign() %s\n", toChars());
    if (hasIdentityAssign)
        goto Ldontneed;

    if (dtor || postblit)
        goto Lneed;

    /* If any of the fields need an opAssign, then we
     * need it too.
     */
    for (size_t i = 0; i < fields.dim; i++)
    {
        Dsymbol *s = fields.tdata()[i];
        VarDeclaration *v = s->isVarDeclaration();
        assert(v && v->storage_class & STCfield);
        if (v->storage_class & STCref)
            continue;
        Type *tv = v->type->toBasetype();
        while (tv->ty == Tsarray)
        {   TypeSArray *ta = (TypeSArray *)tv;
            tv = tv->nextOf()->toBasetype();
        }
        if (tv->ty == Tstruct)
        {   TypeStruct *ts = (TypeStruct *)tv;
            StructDeclaration *sd = ts->sym;
            if (sd->needOpAssign())
                goto Lneed;
        }
    }
Ldontneed:
    if (X) printf("\tdontneed\n");
    return 0;

Lneed:
    if (X) printf("\tneed\n");
    return 1;
#undef X
}

/*******************************************
 * We need an opEquals for the struct if
 * any fields has an opEquals.
 * Generate one if a user-specified one does not exist.
 */

int StructDeclaration::needOpEquals()
{
#define X 0
    if (X) printf("StructDeclaration::needOpEquals() %s\n", toChars());

    /* If any of the fields has an opEquals, then we
     * need it too.
     */
    for (size_t i = 0; i < fields.dim; i++)
    {
        Dsymbol *s = fields.tdata()[i];
        VarDeclaration *v = s->isVarDeclaration();
        assert(v && v->storage_class & STCfield);
        if (v->storage_class & STCref)
            continue;
        Type *tv = v->type->toBasetype();
        while (tv->ty == Tsarray)
        {   TypeSArray *ta = (TypeSArray *)tv;
            tv = tv->nextOf()->toBasetype();
        }
        if (tv->ty == Tstruct)
        {   TypeStruct *ts = (TypeStruct *)tv;
            StructDeclaration *sd = ts->sym;
            if (sd->eq)
                goto Lneed;
        }
    }
    if (X) printf("\tdontneed\n");
    return 0;

Lneed:
    if (X) printf("\tneed\n");
    return 1;
#undef X
}

/******************************************
 * Build opAssign for struct.
 *      S* opAssign(S s) { ... }
 *
 * Note that s will be constructed onto the stack, probably copy-constructed.
 * Then, the body is:
 *      S tmp = *this;  // bit copy
 *      *this = s;      // bit copy
 *      tmp.dtor();
 * Instead of running the destructor on s, run it on tmp instead.
 */

FuncDeclaration *StructDeclaration::buildOpAssign(Scope *sc)
{
    if (!needOpAssign())
        return NULL;

    //printf("StructDeclaration::buildOpAssign() %s\n", toChars());

    FuncDeclaration *fop = NULL;

    Parameter *param = new Parameter(STCnodtor, type, Id::p, NULL);
    Parameters *fparams = new Parameters;
    fparams->push(param);
    Type *ftype = new TypeFunction(fparams, handle, FALSE, LINKd);
#if STRUCTTHISREF
    ((TypeFunction *)ftype)->isref = 1;
#endif

    fop = new FuncDeclaration(loc, 0, Id::assign, STCundefined, ftype);

    Expression *e = NULL;
    if (postblit)
    {   /* Swap:
         *    tmp = *this; *this = s; tmp.dtor();
         */
        //printf("\tswap copy\n");
        Identifier *idtmp = Lexer::uniqueId("__tmp");
        VarDeclaration *tmp;
        AssignExp *ec = NULL;
        if (dtor)
        {
            tmp = new VarDeclaration(0, type, idtmp, new VoidInitializer(0));
            tmp->noscope = 1;
            tmp->storage_class |= STCctfe;
            e = new DeclarationExp(0, tmp);
            ec = new AssignExp(0,
                new VarExp(0, tmp),
#if STRUCTTHISREF
                new ThisExp(0)
#else
                new PtrExp(0, new ThisExp(0))
#endif
                );
            ec->op = TOKblit;
            e = Expression::combine(e, ec);
        }
        ec = new AssignExp(0,
#if STRUCTTHISREF
                new ThisExp(0),
#else
                new PtrExp(0, new ThisExp(0)),
#endif
                new IdentifierExp(0, Id::p));
        ec->op = TOKblit;
        e = Expression::combine(e, ec);
        if (dtor)
        {
            /* Instead of running the destructor on s, run it
             * on tmp. This avoids needing to copy tmp back in to s.
             */
            Expression *ec2 = new DotVarExp(0, new VarExp(0, tmp), dtor, 0);
            ec2 = new CallExp(0, ec2);
            e = Expression::combine(e, ec2);
        }
    }
    else
    {   /* Do memberwise copy
         */
        //printf("\tmemberwise copy\n");
        for (size_t i = 0; i < fields.dim; i++)
        {
            Dsymbol *s = fields.tdata()[i];
            VarDeclaration *v = s->isVarDeclaration();
            assert(v && v->storage_class & STCfield);
            // this.v = s.v;
            AssignExp *ec = new AssignExp(0,
                new DotVarExp(0, new ThisExp(0), v, 0),
                new DotVarExp(0, new IdentifierExp(0, Id::p), v, 0));
            ec->op = TOKblit;
            e = Expression::combine(e, ec);
        }
    }
    Statement *s1 = new ExpStatement(0, e);

    /* Add:
     *   return this;
     */
    e = new ThisExp(0);
    Statement *s2 = new ReturnStatement(0, e);

    fop->fbody = new CompoundStatement(0, s1, s2);

    members->push(fop);
    fop->addMember(sc, this, 1);

    sc = sc->push();
    sc->stc = 0;
    sc->linkage = LINKd;

    fop->semantic(sc);

    sc->pop();

    //printf("-StructDeclaration::buildOpAssign() %s\n", toChars());

    return fop;
}

/******************************************
 * Build opEquals for struct.
 *      const bool opEquals(const ref S s) { ... }
 */

FuncDeclaration *StructDeclaration::buildOpEquals(Scope *sc)
{
    if (!needOpEquals())
        return NULL;
    //printf("StructDeclaration::buildOpEquals() %s\n", toChars());
    Loc loc = this->loc;

    Parameters *parameters = new Parameters;
#if STRUCTTHISREF
    // bool opEquals(ref const T) const;
    Parameter *param = new Parameter(STCref, type->constOf(), Id::p, NULL);
#else
    // bool opEquals(const T*) const;
    Parameter *param = new Parameter(STCin, type->pointerTo(), Id::p, NULL);
#endif

    parameters->push(param);
    TypeFunction *ftype = new TypeFunction(parameters, Type::tbool, 0, LINKd);
    ftype->mod = MODconst;
    ftype = (TypeFunction *)ftype->semantic(loc, sc);

    FuncDeclaration *fop = new FuncDeclaration(loc, 0, Id::eq, STCundefined, ftype);

    Expression *e = NULL;
    /* Do memberwise compare
     */
    //printf("\tmemberwise compare\n");
    for (size_t i = 0; i < fields.dim; i++)
    {
        Dsymbol *s = fields.tdata()[i];
        VarDeclaration *v = s->isVarDeclaration();
        assert(v && v->storage_class & STCfield);
        if (v->storage_class & STCref)
            assert(0);                  // what should we do with this?
        // this.v == s.v;
        EqualExp *ec = new EqualExp(TOKequal, loc,
            new DotVarExp(loc, new ThisExp(loc), v, 0),
            new DotVarExp(loc, new IdentifierExp(loc, Id::p), v, 0));
        if (e)
            e = new AndAndExp(loc, e, ec);
        else
            e = ec;
    }
    if (!e)
        e = new IntegerExp(loc, 1, Type::tbool);
    fop->fbody = new ReturnStatement(loc, e);

    members->push(fop);
    fop->addMember(sc, this, 1);

    sc = sc->push();
    sc->stc = 0;
    sc->linkage = LINKd;

    fop->semantic(sc);

    sc->pop();

    //printf("-StructDeclaration::buildOpEquals() %s\n", toChars());

    return fop;
}


/*******************************************
 * Build copy constructor for struct.
 * Copy constructors are compiler generated only, and are only
 * callable from the compiler. They are not user accessible.
 * A copy constructor is:
 *    void cpctpr(ref S s)
 *    {
 *      *this = s;
 *      this.postBlit();
 *    }
 * This is done so:
 *      - postBlit() never sees uninitialized data
 *      - memcpy can be much more efficient than memberwise copy
 *      - no fields are overlooked
 */

FuncDeclaration *StructDeclaration::buildCpCtor(Scope *sc)
{
    //printf("StructDeclaration::buildCpCtor() %s\n", toChars());
    FuncDeclaration *fcp = NULL;

    /* Copy constructor is only necessary if there is a postblit function,
     * otherwise the code generator will just do a bit copy.
     */
    if (postblit)
    {
        //printf("generating cpctor\n");

        Parameter *param = new Parameter(STCref, type, Id::p, NULL);
        Parameters *fparams = new Parameters;
        fparams->push(param);
        Type *ftype = new TypeFunction(fparams, Type::tvoid, FALSE, LINKd);

        fcp = new FuncDeclaration(loc, 0, Id::cpctor, STCundefined, ftype);
        fcp->storage_class |= postblit->storage_class & STCdisable;

        if (!(fcp->storage_class & STCdisable))
        {
            // Build *this = p;
            Expression *e = new ThisExp(0);
#if !STRUCTTHISREF
            e = new PtrExp(0, e);
#endif
            AssignExp *ea = new AssignExp(0, e, new IdentifierExp(0, Id::p));
            ea->op = TOKblit;
            Statement *s = new ExpStatement(0, ea);

            // Build postBlit();
            e = new VarExp(0, postblit, 0);
            e = new CallExp(0, e);

            s = new CompoundStatement(0, s, new ExpStatement(0, e));
            fcp->fbody = s;
        }
        else
            fcp->fbody = new ExpStatement(0, (Expression *)NULL);

        members->push(fcp);

        sc = sc->push();
        sc->stc = 0;
        sc->linkage = LINKd;

        fcp->semantic(sc);

        sc->pop();
    }

    return fcp;
}

/*****************************************
 * Create inclusive postblit for struct by aggregating
 * all the postblits in postblits[] with the postblits for
 * all the members.
 * Note the close similarity with AggregateDeclaration::buildDtor(),
 * and the ordering changes (runs forward instead of backwards).
 */

#if DMDV2
FuncDeclaration *StructDeclaration::buildPostBlit(Scope *sc)
{
    //printf("StructDeclaration::buildPostBlit() %s\n", toChars());
    Expression *e = NULL;
    StorageClass stc = 0;

    for (size_t i = 0; i < fields.dim; i++)
    {
        Dsymbol *s = fields.tdata()[i];
        VarDeclaration *v = s->isVarDeclaration();
        assert(v && v->storage_class & STCfield);
        if (v->storage_class & STCref)
            continue;
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
            if (sd->postblit)
            {
                stc |= sd->postblit->storage_class & STCdisable;

                if (stc & STCdisable)
                {
                    e = NULL;
                    break;
                }

                // this.v
                Expression *ex = new ThisExp(0);
                ex = new DotVarExp(0, ex, v, 0);

                if (dim == 0)
                {   // this.v.postblit()
                    ex = new DotVarExp(0, ex, sd->postblit, 0);
                    ex = new CallExp(0, ex);
                }
                else
                {
                    // Typeinfo.postblit(cast(void*)&this.v);
                    Expression *ea = new AddrExp(0, ex);
                    ea = new CastExp(0, ea, Type::tvoid->pointerTo());

                    Expression *et = v->type->getTypeInfo(sc);
                    et = new DotIdExp(0, et, Id::postblit);

                    ex = new CallExp(0, et, ea);
                }
                e = Expression::combine(e, ex); // combine in forward order
            }
        }
    }

    /* Build our own "postblit" which executes e
     */
    if (e || (stc & STCdisable))
    {   //printf("Building __fieldPostBlit()\n");
        PostBlitDeclaration *dd = new PostBlitDeclaration(loc, 0, Lexer::idPool("__fieldPostBlit"));
        dd->storage_class |= stc;
        dd->fbody = new ExpStatement(0, e);
        postblits.shift(dd);
        members->push(dd);
        dd->semantic(sc);
    }

    switch (postblits.dim)
    {
        case 0:
            return NULL;

        case 1:
            return postblits.tdata()[0];

        default:
            e = NULL;
            for (size_t i = 0; i < postblits.dim; i++)
            {   FuncDeclaration *fd = postblits.tdata()[i];
                stc |= fd->storage_class & STCdisable;
                if (stc & STCdisable)
                {
                    e = NULL;
                    break;
                }
                Expression *ex = new ThisExp(0);
                ex = new DotVarExp(0, ex, fd, 0);
                ex = new CallExp(0, ex);
                e = Expression::combine(e, ex);
            }
            PostBlitDeclaration *dd = new PostBlitDeclaration(loc, 0, Lexer::idPool("__aggrPostBlit"));
            dd->storage_class |= stc;
            dd->fbody = new ExpStatement(0, e);
            members->push(dd);
            dd->semantic(sc);
            return dd;
    }
}

#endif

/*****************************************
 * Create inclusive destructor for struct/class by aggregating
 * all the destructors in dtors[] with the destructors for
 * all the members.
 * Note the close similarity with StructDeclaration::buildPostBlit(),
 * and the ordering changes (runs backward instead of forwards).
 */

FuncDeclaration *AggregateDeclaration::buildDtor(Scope *sc)
{
    //printf("AggregateDeclaration::buildDtor() %s\n", toChars());
    Expression *e = NULL;

#if DMDV2
    for (size_t i = 0; i < fields.dim; i++)
    {
        Dsymbol *s = fields.tdata()[i];
        VarDeclaration *v = s->isVarDeclaration();
        assert(v && v->storage_class & STCfield);
        if (v->storage_class & STCref)
            continue;
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

                if (dim == 0)
                {   // this.v.dtor()
                    ex = new DotVarExp(0, ex, sd->dtor, 0);
                    ex = new CallExp(0, ex);
                }
                else
                {
                    // Typeinfo.destroy(cast(void*)&this.v);
                    Expression *ea = new AddrExp(0, ex);
                    ea = new CastExp(0, ea, Type::tvoid->pointerTo());

                    Expression *et = v->type->getTypeInfo(sc);
                    et = new DotIdExp(0, et, Id::destroy);

                    ex = new CallExp(0, et, ea);
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
            return dtors.tdata()[0];

        default:
            e = NULL;
            for (size_t i = 0; i < dtors.dim; i++)
            {   FuncDeclaration *fd = dtors.tdata()[i];
                Expression *ex = new ThisExp(0);
                ex = new DotVarExp(0, ex, fd, 0);
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


