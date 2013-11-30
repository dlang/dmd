
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
#include "template.h"


/*******************************************
 * Merge function attributes pure, nothrow, @safe, and @disable
 */
StorageClass mergeFuncAttrs(StorageClass s1, StorageClass s2)
{
    StorageClass stc = 0;
    StorageClass sa = s1 & s2;
    StorageClass so = s1 | s2;

    if (so & STCsystem)
        stc |= STCsystem;
    else if (sa & STCtrusted)
        stc |= STCtrusted;
    else if ((so & (STCtrusted | STCsafe)) == (STCtrusted | STCsafe))
        stc |= STCtrusted;
    else if (sa & STCsafe)
        stc |= STCsafe;

    if (sa & STCpure)
        stc |= STCpure;

    if (sa & STCnothrow)
        stc |= STCnothrow;

    if (so & STCdisable)
        stc |= STCdisable;

    return stc;
}

/*******************************************
 * Check given opAssign symbol is really identity opAssign or not.
 */

FuncDeclaration *AggregateDeclaration::hasIdentityOpAssign(Scope *sc)
{
    Dsymbol *assign = search_function(this, Id::assign);
    if (assign)
    {
        /* check identity opAssign exists
         */
        Expression *er = new NullExp(loc, type);        // dummy rvalue
        Expression *el = new IdentifierExp(loc, Id::p); // dummy lvalue
        el->type = type;
        Expressions *a = new Expressions();
        a->setDim(1);
        FuncDeclaration *f = NULL;

        unsigned errors = global.startGagging();    // Do not report errors, even if the
        unsigned oldspec = global.speculativeGag;   // template opAssign fbody makes it.
        global.speculativeGag = global.gag;
        sc = sc->push();
        sc->tinst = NULL;
        sc->speculative = true;

        for (size_t i = 0; i < 2; i++)
        {
            (*a)[0] = (i == 0 ? er : el);
            f = resolveFuncCall(loc, sc, assign, NULL, type, a, 1);
            if (f)
                break;
        }

        sc = sc->pop();
        global.speculativeGag = oldspec;
        global.endGagging(errors);

        if (f)
        {
            int varargs;
            Parameters *fparams = f->getParameters(&varargs);
            if (fparams->dim >= 1)
            {
                Parameter *arg0 = Parameter::getNth(fparams, 0);
                if (arg0->type->toDsymbol(NULL) != this)
                    f = NULL;
            }
        }
        // BUGS: This detection mechanism cannot find some opAssign-s like follows:
        // struct S { void opAssign(ref immutable S) const; }
        return f;
    }
    return NULL;
}

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
        goto Lneed;         // because has identity==elaborate opAssign

    if (dtor || postblit)
        goto Lneed;

    /* If any of the fields need an opAssign, then we
     * need it too.
     */
    for (size_t i = 0; i < fields.dim; i++)
    {
        Dsymbol *s = fields[i];
        VarDeclaration *v = s->isVarDeclaration();
        assert(v && v->isField());
        if (v->storage_class & STCref)
            continue;
        Type *tv = v->type->baseElemOf();
        if (tv->ty == Tstruct)
        {
            TypeStruct *ts = (TypeStruct *)tv;
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

/******************************************
 * Build opAssign for struct.
 *      ref S opAssign(S s) { ... }
 *
 * Note that s will be constructed onto the stack, and probably
 * copy-constructed in caller site.
 *
 * If S has copy copy construction and/or destructor,
 * the body will make bit-wise object swap:
 *          S __tmp = this; // bit copy
 *          this = s;       // bit copy
 *          __tmp.dtor();
 * Instead of running the destructor on s, run it on tmp instead.
 *
 * Otherwise, the body will make member-wise assignments:
 * Then, the body is:
 *          this.field1 = s.field1;
 *          this.field2 = s.field2;
 *          ...;
 */

FuncDeclaration *StructDeclaration::buildOpAssign(Scope *sc)
{
    if (FuncDeclaration *f = hasIdentityOpAssign(sc))
    {
        hasIdentityAssign = 1;
        return f;
    }
    // Even if non-identity opAssign is defined, built-in identity opAssign
    // will be defined.

    if (!needOpAssign())
        return NULL;

    //printf("StructDeclaration::buildOpAssign() %s\n", toChars());
    StorageClass stc = STCsafe | STCnothrow | STCpure;
    Loc declLoc = this->loc;
    Loc loc = Loc();    // internal code should have no loc to prevent coverage

    if (dtor || postblit)
    {
        if (dtor)
        {
            stc = mergeFuncAttrs(stc, dtor->storage_class);
            if (stc & STCsafe)
                stc = (stc & ~STCsafe) | STCtrusted;
        }
    }
    else
    {
        for (size_t i = 0; i < fields.dim; i++)
        {
            Dsymbol *s = fields[i];
            VarDeclaration *v = s->isVarDeclaration();
            assert(v && v->isField());
            if (v->storage_class & STCref)
                continue;
            Type *tv = v->type->baseElemOf();
            if (tv->ty == Tstruct)
            {
                TypeStruct *ts = (TypeStruct *)tv;
                StructDeclaration *sd = ts->sym;
                if (FuncDeclaration *f = sd->hasIdentityOpAssign(sc))
                    stc = mergeFuncAttrs(stc, f->storage_class);
            }
        }
    }

    Parameters *fparams = new Parameters;
    fparams->push(new Parameter(STCnodtor, type, Id::p, NULL));
    Type *tf = new TypeFunction(fparams, handle, 0, LINKd, stc | STCref);

    FuncDeclaration *fop = new FuncDeclaration(declLoc, Loc(), Id::assign, stc, tf);

    Expression *e = NULL;
    if (stc & STCdisable)
    {
    }
    else if (dtor || postblit)
    {
        /* Do swap this and rhs
         *    tmp = this; this = s; tmp.dtor();
         */
        //printf("\tswap copy\n");
        Identifier *idtmp = Lexer::uniqueId("__tmp");
        VarDeclaration *tmp;
        AssignExp *ec = NULL;
        if (dtor)
        {
            tmp = new VarDeclaration(loc, type, idtmp, new VoidInitializer(loc));
            tmp->noscope = 1;
            tmp->storage_class |= STCtemp | STCctfe;
            e = new DeclarationExp(loc, tmp);
            ec = new AssignExp(loc,
                new VarExp(loc, tmp),
                new ThisExp(loc)
                );
            ec->op = TOKblit;
            e = Expression::combine(e, ec);
        }
        ec = new AssignExp(loc,
                new ThisExp(loc),
                new IdentifierExp(loc, Id::p));
        ec->op = TOKblit;
        e = Expression::combine(e, ec);
        if (dtor)
        {
            /* Instead of running the destructor on s, run it
             * on tmp. This avoids needing to copy tmp back in to s.
             */
            Expression *ec2 = new DotVarExp(loc, new VarExp(loc, tmp), dtor, 0);
            ec2 = new CallExp(loc, ec2);
            e = Expression::combine(e, ec2);
        }
    }
    else
    {
        /* Do memberwise copy
         */
        //printf("\tmemberwise copy\n");
        for (size_t i = 0; i < fields.dim; i++)
        {
            Dsymbol *s = fields[i];
            VarDeclaration *v = s->isVarDeclaration();
            assert(v && v->isField());
            // this.v = s.v;
            AssignExp *ec = new AssignExp(loc,
                new DotVarExp(loc, new ThisExp(loc), v, 0),
                new DotVarExp(loc, new IdentifierExp(loc, Id::p), v, 0));
            e = Expression::combine(e, ec);
        }
    }
    if (e)
    {
        Statement *s1 = new ExpStatement(loc, e);

        /* Add:
         *   return this;
         */
        e = new ThisExp(loc);
        Statement *s2 = new ReturnStatement(loc, e);

        fop->fbody = new CompoundStatement(loc, s1, s2);
    }

    Dsymbol *s = fop;
#if 1   // workaround until fixing issue 1528
    Dsymbol *assign = search_function(this, Id::assign);
    if (assign && assign->isTemplateDeclaration())
    {
        // Wrap a template around the function declaration
        TemplateParameters *tpl = new TemplateParameters();
        Dsymbols *decldefs = new Dsymbols();
        decldefs->push(s);
        TemplateDeclaration *tempdecl =
            new TemplateDeclaration(assign->loc, fop->ident, tpl, NULL, decldefs);
        s = tempdecl;
    }
#endif
    members->push(s);
    s->addMember(sc, this, 1);
    this->hasIdentityAssign = 1;        // temporary mark identity assignable

    unsigned errors = global.startGagging();    // Do not report errors, even if the
    unsigned oldspec = global.speculativeGag;   // template opAssign fbody makes it.
    global.speculativeGag = global.gag;
    Scope *sc2 = sc->push();
    sc2->stc = 0;
    sc2->linkage = LINKd;
    sc2->speculative = true;

    s->semantic(sc2);
    s->semantic2(sc2);
    s->semantic3(sc2);

    sc2->pop();
    global.speculativeGag = oldspec;
    if (global.endGagging(errors))    // if errors happened
    {   // Disable generated opAssign, because some members forbid identity assignment.
        fop->storage_class |= STCdisable;
        fop->fbody = NULL;  // remove fbody which contains the error
    }

    //printf("-StructDeclaration::buildOpAssign() %s %s, errors = %d\n", toChars(), s->kind(), (fop->storage_class & STCdisable) != 0);

    return fop;
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

    if (hasIdentityEquals)
        goto Lneed;

    if (isUnionDeclaration())
        goto Ldontneed;

    /* If any of the fields has an opEquals, then we
     * need it too.
     */
    for (size_t i = 0; i < fields.dim; i++)
    {
        Dsymbol *s = fields[i];
        VarDeclaration *v = s->isVarDeclaration();
        assert(v && v->isField());
        if (v->storage_class & STCref)
            continue;
        Type *tv = v->type->toBasetype();
        if (tv->isfloating())
            goto Lneed;
        if (tv->ty == Tarray)
            goto Lneed;
        if (tv->ty == Taarray)
            goto Lneed;
        if (tv->ty == Tclass)
            goto Lneed;
        tv = tv->baseElemOf();
        if (tv->ty == Tstruct)
        {
            TypeStruct *ts = (TypeStruct *)tv;
            StructDeclaration *sd = ts->sym;
            if (sd->needOpEquals())
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

FuncDeclaration *AggregateDeclaration::hasIdentityOpEquals(Scope *sc)
{
    Dsymbol *eq = search_function(this, Id::eq);
    if (eq)
    {
        /* check identity opEquals exists
         */
        Expression *er = new NullExp(loc, NULL);        // dummy rvalue
        Expression *el = new IdentifierExp(loc, Id::p); // dummy lvalue
        Expressions *a = new Expressions();
        a->setDim(1);
        for (size_t i = 0; ; i++)
        {
            Type *tthis;
            if (i == 0) tthis = type;
            if (i == 1) tthis = type->constOf();
            if (i == 2) tthis = type->immutableOf();
            if (i == 3) tthis = type->sharedOf();
            if (i == 4) tthis = type->sharedConstOf();
            if (i == 5) break;
            FuncDeclaration *f = NULL;

            unsigned errors = global.startGagging();    // Do not report errors, even if the
            unsigned oldspec = global.speculativeGag;   // template opAssign fbody makes it.
            global.speculativeGag = global.gag;
            sc = sc->push();
            sc->tinst = NULL;
            sc->speculative = true;

            for (size_t j = 0; j < 2; j++)
            {
                (*a)[0] = (j == 0 ? er : el);
                (*a)[0]->type = tthis;
                f = resolveFuncCall(loc, sc, eq, NULL, tthis, a, 1);
                if (f)
                    break;
            }

            sc = sc->pop();
            global.speculativeGag = oldspec;
            global.endGagging(errors);

            if (f)
                return f;
        }
    }
    return NULL;
}

/******************************************
 * Build opEquals for struct.
 *      const bool opEquals(const S s) { ... }
 *
 * By fixing bugzilla 3789, opEquals is changed to be never implicitly generated.
 * Now, struct objects comparison s1 == s2 is translated to:
 *      s1.tupleof == s2.tupleof
 * to calculate structural equality. See EqualExp::semantic.
 */

FuncDeclaration *StructDeclaration::buildOpEquals(Scope *sc)
{
    if (FuncDeclaration *f = hasIdentityOpEquals(sc))
    {
        hasIdentityEquals = 1;
    }
    return NULL;
}

/******************************************
 * Build __xopEquals for TypeInfo_Struct
 *      static bool __xopEquals(ref const S p, ref const S q)
 *      {
 *          return p == q;
 *      }
 *
 * This is called by TypeInfo.equals(p1, p2). If the struct does not support
 * const objects comparison, it will throw "not implemented" Error in runtime.
 */

FuncDeclaration *StructDeclaration::buildXopEquals(Scope *sc)
{
    if (!needOpEquals())
        return NULL;        // bitwise comparison would work

    //printf("StructDeclaration::buildXopEquals() %s\n", toChars());
    if (Dsymbol *eq = search_function(this, Id::eq))
    {
        if (FuncDeclaration *fd = eq->isFuncDeclaration())
        {
            TypeFunction *tfeqptr;
            {
                Scope scx;

                /* const bool opEquals(ref const S s);
                 */
                Parameters *parameters = new Parameters;
                parameters->push(new Parameter(STCref | STCconst, type, NULL, NULL));
                tfeqptr = new TypeFunction(parameters, Type::tbool, 0, LINKd);
                tfeqptr->mod = MODconst;
                tfeqptr = (TypeFunction *)tfeqptr->semantic(Loc(), &scx);
            }
            fd = fd->overloadExactMatch(tfeqptr);
            if (fd)
                return fd;
        }
    }

    if (!xerreq)
    {
        Identifier *id = Lexer::idPool("_xopEquals");
        Expression *e = new IdentifierExp(loc, Id::empty);
        e = new DotIdExp(loc, e, Id::object);
        e = new DotIdExp(loc, e, id);
        e = e->semantic(sc);
        Dsymbol *s = getDsymbol(e);
        if (!s)
        {
            ::error(Loc(), "ICE: %s not found in object module. You must update druntime", id->toChars());
            fatal();
        }
        assert(s);
        xerreq = s->isFuncDeclaration();
    }

    Loc declLoc = Loc();    // loc is unnecessary so __xopEquals is never called directly
    Loc loc = Loc();        // loc is unnecessary so errors are gagged

    Parameters *parameters = new Parameters;
    parameters->push(new Parameter(STCref | STCconst, type, Id::p, NULL));
    parameters->push(new Parameter(STCref | STCconst, type, Id::q, NULL));
    TypeFunction *tf = new TypeFunction(parameters, Type::tbool, 0, LINKd);
    tf = (TypeFunction *)tf->semantic(loc, sc);

    Identifier *id = Lexer::idPool("__xopEquals");
    FuncDeclaration *fop = new FuncDeclaration(declLoc, Loc(), id, STCstatic, tf);

    Expression *e1 = new IdentifierExp(loc, Id::p);
    Expression *e2 = new IdentifierExp(loc, Id::q);
    Expression *e = new EqualExp(TOKequal, loc, e1, e2);

    fop->fbody = new ReturnStatement(loc, e);

    unsigned errors = global.startGagging();    // Do not report errors
    Scope *sc2 = sc->push();
    sc2->stc = 0;
    sc2->linkage = LINKd;

    fop->semantic(sc2);
    fop->semantic2(sc2);

    sc2->pop();
    if (global.endGagging(errors))    // if errors happened
        fop = xerreq;

    return fop;
}

/******************************************
 * Build __xopCmp for TypeInfo_Struct
 *      static bool __xopCmp(ref const S p, ref const S q)
 *      {
 *          return p.opCmp(q);
 *      }
 *
 * This is called by TypeInfo.compare(p1, p2). If the struct does not support
 * const objects comparison, it will throw "not implemented" Error in runtime.
 */

FuncDeclaration *StructDeclaration::buildXopCmp(Scope *sc)
{
    //printf("StructDeclaration::buildXopCmp() %s\n", toChars());
    if (Dsymbol *cmp = search_function(this, Id::cmp))
    {
        if (FuncDeclaration *fd = cmp->isFuncDeclaration())
        {
            TypeFunction *tfcmpptr;
            {
                Scope scx;

                /* const int opCmp(ref const S s);
                 */
                Parameters *parameters = new Parameters;
                parameters->push(new Parameter(STCref | STCconst, type, NULL, NULL));
                tfcmpptr = new TypeFunction(parameters, Type::tint32, 0, LINKd);
                tfcmpptr->mod = MODconst;
                tfcmpptr = (TypeFunction *)tfcmpptr->semantic(Loc(), &scx);
            }
            fd = fd->overloadExactMatch(tfcmpptr);
            if (fd)
                return fd;
        }
    }
    else
    {
#if 0   // FIXME: doesn't work for recursive alias this
        /* Check opCmp member exists.
         * Consider 'alias this', but except opDispatch.
         */
        Expression *e = new DsymbolExp(loc, this);
        e = new DotIdExp(loc, e, Id::cmp);
        Scope *sc2 = sc->push();
        e = e->trySemantic(sc2);
        sc2->pop();
        if (e)
        {
            Dsymbol *s = NULL;
            switch (e->op)
            {
                case TOKoverloadset:    s = ((OverExp *)e)->vars;       break;
                case TOKimport:         s = ((ScopeExp *)e)->sds;       break;
                case TOKvar:            s = ((VarExp *)e)->var;         break;
                default:                break;
            }
            if (!s || s->ident != Id::cmp)
                e = NULL;   // there's no valid member 'opCmp'
        }
        if (!e)
            return NULL;    // bitwise comparison would work
        /* Essentially, a struct which does not define opCmp is not comparable.
         * At this time, typeid(S).compare might be correct that throwing "not implement" Error.
         * But implementing it would break existing code, such as:
         *
         * struct S { int value; }  // no opCmp
         * int[S] aa;   // Currently AA key uses bitwise comparison
         *              // (It's default behavior of TypeInfo_Strust.compare).
         *
         * Not sure we should fix this inconsistency, so just keep current behavior.
         */
#else
        return NULL;
#endif
    }

    if (!xerrcmp)
    {
        Identifier *id = Lexer::idPool("_xopCmp");
        Expression *e = new IdentifierExp(loc, Id::empty);
        e = new DotIdExp(loc, e, Id::object);
        e = new DotIdExp(loc, e, id);
        e = e->semantic(sc);
        Dsymbol *s = getDsymbol(e);
        if (!s)
        {
            ::error(Loc(), "ICE: %s not found in object module. You must update druntime", id->toChars());
            fatal();
        }
        assert(s);
        xerrcmp = s->isFuncDeclaration();
    }

    Loc declLoc = Loc();    // loc is unnecessary so __xopCmp is never called directly
    Loc loc = Loc();        // loc is unnecessary so errors are gagged

    Parameters *parameters = new Parameters;
    parameters->push(new Parameter(STCref | STCconst, type, Id::p, NULL));
    parameters->push(new Parameter(STCref | STCconst, type, Id::q, NULL));
    TypeFunction *tf = new TypeFunction(parameters, Type::tint32, 0, LINKd);
    tf = (TypeFunction *)tf->semantic(loc, sc);

    Identifier *id = Lexer::idPool("__xopCmp");
    FuncDeclaration *fop = new FuncDeclaration(declLoc, Loc(), id, STCstatic, tf);

    Expression *e1 = new IdentifierExp(loc, Id::p);
    Expression *e2 = new IdentifierExp(loc, Id::q);
    Expression *e = new CallExp(loc, new DotIdExp(loc, e1, Id::cmp), e2);

    fop->fbody = new ReturnStatement(loc, e);

    unsigned errors = global.startGagging();    // Do not report errors
    Scope *sc2 = sc->push();
    sc2->stc = 0;
    sc2->linkage = LINKd;

    fop->semantic(sc2);
    fop->semantic2(sc2);

    sc2->pop();
    if (global.endGagging(errors))    // if errors happened
        fop = xerrcmp;

    return fop;
}

/*******************************************
 * Build copy constructor for struct.
 *      void __cpctpr(ref const S s) const [pure nothrow @trusted]
 *      {
 *          (*cast(S*)&this) = *cast(S*)s;
 *          (*cast(S*)&this).postBlit();
 *      }
 *
 * Copy constructors are compiler generated only, and are only
 * callable from the compiler. They are not user accessible.
 *
 * This is done so:
 *      - postBlit() never sees uninitialized data
 *      - memcpy can be much more efficient than memberwise copy
 *      - no fields are overlooked
 */

FuncDeclaration *StructDeclaration::buildCpCtor(Scope *sc)
{
    /* Copy constructor is only necessary if there is a postblit function,
     * otherwise the code generator will just do a bit copy.
     */
    if (!postblit)
        return NULL;

    //printf("StructDeclaration::buildCpCtor() %s\n", toChars());
    StorageClass stc = STCsafe | STCnothrow | STCpure;
    Loc declLoc = postblit->loc;
    Loc loc = Loc();    // internal code should have no loc to prevent coverage

    stc = mergeFuncAttrs(stc, postblit->storage_class);
    if (stc & STCsafe)  // change to @trusted for unsafe casts
        stc = (stc & ~STCsafe) | STCtrusted;

    Parameters *fparams = new Parameters;
    fparams->push(new Parameter(STCref, type->constOf(), Id::p, NULL));
    Type *tf = new TypeFunction(fparams, Type::tvoid, 0, LINKd, stc);
    tf->mod = MODconst;

    FuncDeclaration *fcp = new FuncDeclaration(declLoc, Loc(), Id::cpctor, stc, tf);

    if (!(stc & STCdisable))
    {
        // Build *this = p;
        Expression *e = new ThisExp(loc);
        AssignExp *ea = new AssignExp(loc,
            new PtrExp(loc, new CastExp(loc, new AddrExp(loc, e), type->mutableOf()->pointerTo())),
            new PtrExp(loc, new CastExp(loc, new AddrExp(loc, new IdentifierExp(loc, Id::p)), type->mutableOf()->pointerTo()))
        );
        ea->op = TOKblit;
        Statement *s = new ExpStatement(loc, ea);

        // Build postBlit();
        e = new ThisExp(loc);
        e = new PtrExp(loc, new CastExp(loc, new AddrExp(loc, e), type->mutableOf()->pointerTo()));
        e = new DotVarExp(loc, e, postblit, 0);
        e = new CallExp(loc, e);

        s = new CompoundStatement(loc, s, new ExpStatement(loc, e));
        fcp->fbody = s;
    }

    members->push(fcp);

    sc = sc->push();
    sc->stc = 0;
    sc->linkage = LINKd;

    fcp->semantic(sc);

    sc->pop();

    return fcp;
}

/*****************************************
 * Create inclusive postblit for struct by aggregating
 * all the postblits in postblits[] with the postblits for
 * all the members.
 * Note the close similarity with AggregateDeclaration::buildDtor(),
 * and the ordering changes (runs forward instead of backwards).
 */

FuncDeclaration *StructDeclaration::buildPostBlit(Scope *sc)
{
    //printf("StructDeclaration::buildPostBlit() %s\n", toChars());
    StorageClass stc = STCsafe | STCnothrow | STCpure;
    Loc declLoc = postblits.dim ? postblits[0]->loc : this->loc;
    Loc loc = Loc();    // internal code should have no loc to prevent coverage

    Expression *e = NULL;
    for (size_t i = 0; i < fields.dim; i++)
    {
        Dsymbol *s = fields[i];
        VarDeclaration *v = s->isVarDeclaration();
        assert(v && v->isField());
        if (v->storage_class & STCref)
            continue;
        Type *tv = v->type->toBasetype();
        dinteger_t dim = 1;
        while (tv->ty == Tsarray)
        {
            TypeSArray *tsa = (TypeSArray *)tv;
            dim *= tsa->dim->toInteger();
            tv = tsa->next->toBasetype();
        }
        if (tv->ty == Tstruct)
        {
            TypeStruct *ts = (TypeStruct *)tv;
            StructDeclaration *sd = ts->sym;
            if (sd->postblit && dim)
            {
                stc = mergeFuncAttrs(stc, sd->postblit->storage_class);
                if (stc & STCdisable)
                {
                    e = NULL;
                    break;
                }

                // this.v
                Expression *ex = new ThisExp(loc);
                ex = new DotVarExp(loc, ex, v, 0);

                if (v->type->toBasetype()->ty == Tstruct)
                {   // this.v.postblit()
                    ex = new DotVarExp(loc, ex, sd->postblit, 0);
                    ex = new CallExp(loc, ex);
                }
                else
                {
                    // Typeinfo.postblit(cast(void*)&this.v);
                    Expression *ea = new AddrExp(loc, ex);
                    ea = new CastExp(loc, ea, Type::tvoid->pointerTo());

                    Expression *et = v->type->getTypeInfo(sc);
                    et = new DotIdExp(loc, et, Id::postblit);

                    ex = new CallExp(loc, et, ea);
                }
                e = Expression::combine(e, ex); // combine in forward order
            }
        }
    }

    /* Build our own "postblit" which executes e
     */
    if (e || (stc & STCdisable))
    {   //printf("Building __fieldPostBlit()\n");
        PostBlitDeclaration *dd = new PostBlitDeclaration(declLoc, Loc(), stc, Lexer::idPool("__fieldPostBlit"));
        dd->fbody = new ExpStatement(loc, e);
        postblits.shift(dd);
        members->push(dd);
        dd->semantic(sc);
    }

    switch (postblits.dim)
    {
        case 0:
            return NULL;

        case 1:
            return postblits[0];

        default:
            e = NULL;
            stc = STCsafe | STCnothrow | STCpure;
            for (size_t i = 0; i < postblits.dim; i++)
            {
                FuncDeclaration *fd = postblits[i];
                stc = mergeFuncAttrs(stc, fd->storage_class);
                if (stc & STCdisable)
                {
                    e = NULL;
                    break;
                }
                Expression *ex = new ThisExp(loc);
                ex = new DotVarExp(loc, ex, fd, 0);
                ex = new CallExp(loc, ex);
                e = Expression::combine(e, ex);
            }
            PostBlitDeclaration *dd = new PostBlitDeclaration(declLoc, Loc(), stc, Lexer::idPool("__aggrPostBlit"));
            dd->fbody = new ExpStatement(loc, e);
            members->push(dd);
            dd->semantic(sc);
            return dd;
    }
}

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
    StorageClass stc = STCsafe | STCnothrow | STCpure;
    Loc declLoc = dtors.dim ? dtors[0]->loc : this->loc;
    Loc loc = Loc();    // internal code should have no loc to prevent coverage

    Expression *e = NULL;
    for (size_t i = 0; i < fields.dim; i++)
    {
        Dsymbol *s = fields[i];
        VarDeclaration *v = s->isVarDeclaration();
        assert(v && v->isField());
        if (v->storage_class & STCref)
            continue;
        Type *tv = v->type->toBasetype();
        dinteger_t dim = 1;
        while (tv->ty == Tsarray)
        {
            TypeSArray *tsa = (TypeSArray *)tv;
            dim *= tsa->dim->toInteger();
            tv = tsa->next->toBasetype();
        }
        if (tv->ty == Tstruct)
        {
            TypeStruct *ts = (TypeStruct *)tv;
            StructDeclaration *sd = ts->sym;
            if (sd->dtor && dim)
            {
                stc = mergeFuncAttrs(stc, sd->dtor->storage_class);
                if (stc & STCdisable)
                {
                    e = NULL;
                    break;
                }

                // this.v
                Expression *ex = new ThisExp(loc);
                ex = new DotVarExp(loc, ex, v, 0);

                if (v->type->toBasetype()->ty == Tstruct)
                {   // this.v.dtor()
                    ex = new DotVarExp(loc, ex, sd->dtor, 0);
                    ex = new CallExp(loc, ex);
                }
                else
                {
                    // Typeinfo.destroy(cast(void*)&this.v);
                    Expression *ea = new AddrExp(loc, ex);
                    ea = new CastExp(loc, ea, Type::tvoid->pointerTo());

                    Expression *et = v->type->getTypeInfo(sc);
                    et = new DotIdExp(loc, et, Id::destroy);

                    ex = new CallExp(loc, et, ea);
                }
                e = Expression::combine(ex, e); // combine in reverse order
            }
        }
    }

    /* Build our own "destructor" which executes e
     */
    if (e || (stc & STCdisable))
    {   //printf("Building __fieldDtor()\n");
        DtorDeclaration *dd = new DtorDeclaration(declLoc, Loc(), stc, Lexer::idPool("__fieldDtor"));
        dd->fbody = new ExpStatement(loc, e);
        dtors.shift(dd);
        members->push(dd);
        dd->semantic(sc);
    }

    switch (dtors.dim)
    {
        case 0:
            return NULL;

        case 1:
            return dtors[0];

        default:
            e = NULL;
            stc = STCsafe | STCnothrow | STCpure;
            for (size_t i = 0; i < dtors.dim; i++)
            {
                FuncDeclaration *fd = dtors[i];
                stc = mergeFuncAttrs(stc, fd->storage_class);
                if (stc & STCdisable)
                {
                    e = NULL;
                    break;
                }
                Expression *ex = new ThisExp(loc);
                ex = new DotVarExp(loc, ex, fd, 0);
                ex = new CallExp(loc, ex);
                e = Expression::combine(ex, e);
            }
            DtorDeclaration *dd = new DtorDeclaration(declLoc, Loc(), stc, Lexer::idPool("__aggrDtor"));
            dd->fbody = new ExpStatement(loc, e);
            members->push(dd);
            dd->semantic(sc);
            return dd;
    }
}

/******************************************
 * Create inclusive invariant for struct/class by aggregating
 * all the invariants in invs[].
 *      void __invariant() const [pure nothrow @trusted]
 *      {
 *          invs[0](), invs[1](), ...;
 *      }
 */

FuncDeclaration *AggregateDeclaration::buildInv(Scope *sc)
{
    StorageClass stc = STCsafe | STCnothrow | STCpure;
    Loc declLoc = this->loc;
    Loc loc = Loc();    // internal code should have no loc to prevent coverage

    switch (invs.dim)
    {
        case 0:
            return NULL;

        case 1:
            // Don't return invs[0] so it has uniquely generated name.
            /* fall through */

        default:
            Expression *e = NULL;
            StorageClass stcx = 0;
            for (size_t i = 0; i < invs.dim; i++)
            {
                stc = mergeFuncAttrs(stc, invs[i]->storage_class);
                if (stc & STCdisable)
                {
                    // What should do?
                }
                StorageClass stcy = invs[i]->storage_class & (STCshared | STCsynchronized);
                if (i == 0)
                    stcx = stcy;
                else if (stcx ^ stcy)
                {
            #if 1   // currently rejects
                    error(invs[i]->loc, "mixing invariants with shared/synchronized differene is not supported");
                    e = NULL;
                    break;
            #endif
                }
                e = Expression::combine(e, new CallExp(loc, new VarExp(loc, invs[i])));
            }
            InvariantDeclaration *inv;
            inv = new InvariantDeclaration(declLoc, Loc(), stc | stcx, Id::classInvariant);
            inv->fbody = new ExpStatement(loc, e);
            members->push(inv);
            inv->semantic(sc);
            return inv;
    }
}

