
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/clone.c
 */

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
 * Merge function attributes pure, nothrow, @safe, @nogc, and @disable
 */
StorageClass mergeFuncAttrs(StorageClass s1, FuncDeclaration *f)
{
    StorageClass s2 = (f->storage_class & STCdisable);
    TypeFunction *tf = (TypeFunction *)f->type;
    if (tf->trust == TRUSTsafe)
        s2 |= STCsafe;
    else if (tf->trust == TRUSTsystem)
        s2 |= STCsystem;
    else if (tf->trust == TRUSTtrusted)
        s2 |= STCtrusted;
    if (tf->purity != PUREimpure)
        s2 |= STCpure;
    if (tf->isnothrow)
        s2 |= STCnothrow;
    if (tf->isnogc)
        s2 |= STCnogc;

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

    if (sa & STCnogc)
        stc |= STCnogc;

    if (so & STCdisable)
        stc |= STCdisable;

    return stc;
}

/*******************************************
 * Check given opAssign symbol is really identity opAssign or not.
 */

FuncDeclaration *hasIdentityOpAssign(AggregateDeclaration *ad, Scope *sc)
{
    Dsymbol *assign = search_function(ad, Id::assign);
    if (assign)
    {
        /* check identity opAssign exists
         */
        Expression *er = new NullExp(ad->loc, ad->type);    // dummy rvalue
        Expression *el = new IdentifierExp(ad->loc, Id::p); // dummy lvalue
        el->type = ad->type;
        Expressions *a = new Expressions();
        a->setDim(1);
        FuncDeclaration *f = NULL;

        unsigned errors = global.startGagging();    // Do not report errors, even if the
        sc = sc->push();
        sc->tinst = NULL;
        sc->minst = NULL;

        for (size_t i = 0; i < 2; i++)
        {
            (*a)[0] = (i == 0 ? er : el);
            f = resolveFuncCall(ad->loc, sc, assign, NULL, ad->type, a, 1);
            if (f)
                break;
        }

        sc = sc->pop();
        global.endGagging(errors);

        if (f)
        {
            if (f->errors)
                return NULL;
            int varargs;
            Parameters *fparams = f->getParameters(&varargs);
            if (fparams->dim >= 1)
            {
                Parameter *arg0 = Parameter::getNth(fparams, 0);
                if (arg0->type->toDsymbol(NULL) != ad)
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

bool needOpAssign(StructDeclaration *sd)
{
    //printf("StructDeclaration::needOpAssign() %s\n", sd->toChars());

    if (sd->hasIdentityAssign)
        goto Lneed;         // because has identity==elaborate opAssign

    if (sd->dtor || sd->postblit)
        goto Lneed;

    /* If any of the fields need an opAssign, then we
     * need it too.
     */
    for (size_t i = 0; i < sd->fields.dim; i++)
    {
        VarDeclaration *v = sd->fields[i];
        if (v->storage_class & STCref)
            continue;
        Type *tv = v->type->baseElemOf();
        if (tv->ty == Tstruct)
        {
            TypeStruct *ts = (TypeStruct *)tv;
            if (needOpAssign(ts->sym))
                goto Lneed;
        }
    }
    //printf("\tdontneed\n");
    return false;

Lneed:
    //printf("\tneed\n");
    return true;
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

FuncDeclaration *buildOpAssign(StructDeclaration *sd, Scope *sc)
{
    if (FuncDeclaration *f = hasIdentityOpAssign(sd, sc))
    {
        sd->hasIdentityAssign = true;
        return f;
    }
    // Even if non-identity opAssign is defined, built-in identity opAssign
    // will be defined.

    if (!needOpAssign(sd))
        return NULL;

    //printf("StructDeclaration::buildOpAssign() %s\n", toChars());
    StorageClass stc = STCsafe | STCnothrow | STCpure | STCnogc;
    Loc declLoc = sd->loc;
    Loc loc = Loc();    // internal code should have no loc to prevent coverage

    if (sd->dtor || sd->postblit)
    {
        if (!sd->type->isAssignable())  // Bugzilla 13044
            return NULL;
        if (sd->dtor)
        {
            stc = mergeFuncAttrs(stc, sd->dtor);
            if (stc & STCsafe)
                stc = (stc & ~STCsafe) | STCtrusted;
        }
    }
    else
    {
        for (size_t i = 0; i < sd->fields.dim; i++)
        {
            VarDeclaration *v = sd->fields[i];
            if (v->storage_class & STCref)
                continue;
            Type *tv = v->type->baseElemOf();
            if (tv->ty == Tstruct)
            {
                TypeStruct *ts = (TypeStruct *)tv;
                if (FuncDeclaration *f = hasIdentityOpAssign(ts->sym, sc))
                    stc = mergeFuncAttrs(stc, f);
            }
        }
    }

    Parameters *fparams = new Parameters;
    fparams->push(new Parameter(STCnodtor, sd->type, Id::p, NULL));
    Type *tf = new TypeFunction(fparams, sd->handleType(), 0, LINKd, stc | STCref);

    FuncDeclaration *fop = new FuncDeclaration(declLoc, Loc(), Id::assign, stc, tf);

    Expression *e = NULL;
    if (stc & STCdisable)
    {
    }
    else if (sd->dtor || sd->postblit)
    {
        /* Do swap this and rhs
         *    tmp = this; this = s; tmp.dtor();
         */
        //printf("\tswap copy\n");
        Identifier *idtmp = Lexer::uniqueId("__swap");
        VarDeclaration *tmp = NULL;
        AssignExp *ec = NULL;
        if (sd->dtor)
        {
            tmp = new VarDeclaration(loc, sd->type, idtmp, new VoidInitializer(loc));
            tmp->noscope = 1;
            tmp->storage_class |= STCtemp | STCctfe;
            e = new DeclarationExp(loc, tmp);
            ec = new BlitExp(loc, new VarExp(loc, tmp), new ThisExp(loc));
            e = Expression::combine(e, ec);
        }
        ec = new BlitExp(loc, new ThisExp(loc), new IdentifierExp(loc, Id::p));
        e = Expression::combine(e, ec);
        if (sd->dtor)
        {
            /* Instead of running the destructor on s, run it
             * on tmp. This avoids needing to copy tmp back in to s.
             */
            Expression *ec2 = new DotVarExp(loc, new VarExp(loc, tmp), sd->dtor, 0);
            ec2 = new CallExp(loc, ec2);
            e = Expression::combine(e, ec2);
        }
    }
    else
    {
        /* Do memberwise copy
         */
        //printf("\tmemberwise copy\n");
        for (size_t i = 0; i < sd->fields.dim; i++)
        {
            VarDeclaration *v = sd->fields[i];
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

    sd->members->push(fop);
    fop->addMember(sc, sd, 1);
    sd->hasIdentityAssign = true;        // temporary mark identity assignable

    unsigned errors = global.startGagging();    // Do not report errors, even if the
    Scope *sc2 = sc->push();
    sc2->stc = 0;
    sc2->linkage = LINKd;

    fop->semantic(sc2);
    fop->semantic2(sc2);
    fop->semantic3(sc2);

    sc2->pop();
    if (global.endGagging(errors))    // if errors happened
    {
        // Disable generated opAssign, because some members forbid identity assignment.
        fop->storage_class |= STCdisable;
        fop->fbody = NULL;  // remove fbody which contains the error
    }

    //printf("-StructDeclaration::buildOpAssign() %s, errors = %d\n", sd->toChars(), (fop->storage_class & STCdisable) != 0);

    return fop;
}

/*******************************************
 * We need an opEquals for the struct if
 * any fields has an opEquals.
 * Generate one if a user-specified one does not exist.
 */

bool needOpEquals(StructDeclaration *sd)
{
    //printf("StructDeclaration::needOpEquals() %s\n", sd->toChars());

    if (sd->hasIdentityEquals)
        goto Lneed;

    if (sd->isUnionDeclaration())
        goto Ldontneed;

    /* If any of the fields has an opEquals, then we
     * need it too.
     */
    for (size_t i = 0; i < sd->fields.dim; i++)
    {
        VarDeclaration *v = sd->fields[i];
        if (v->storage_class & STCref)
            continue;
        Type *tv = v->type->toBasetype();
        if (tv->isfloating())
        {
            // This is necessray for:
            //  1. comparison of +0.0 and -0.0 should be true.
            //  2. comparison of NANs should be false always.
            goto Lneed;
        }
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
            if (needOpEquals(ts->sym))
                goto Lneed;
        }
    }
Ldontneed:
    //printf("\tdontneed\n");
    return false;

Lneed:
    //printf("\tneed\n");
    return true;
}

FuncDeclaration *hasIdentityOpEquals(AggregateDeclaration *ad,  Scope *sc)
{
    Dsymbol *eq = search_function(ad, Id::eq);
    if (eq)
    {
        /* check identity opEquals exists
         */
        Expression *er = new NullExp(ad->loc, NULL);        // dummy rvalue
        Expression *el = new IdentifierExp(ad->loc, Id::p); // dummy lvalue
        Expressions *a = new Expressions();
        a->setDim(1);
        for (size_t i = 0; ; i++)
        {
            Type *tthis;
            if (i == 0) tthis = ad->type;
            if (i == 1) tthis = ad->type->constOf();
            if (i == 2) tthis = ad->type->immutableOf();
            if (i == 3) tthis = ad->type->sharedOf();
            if (i == 4) tthis = ad->type->sharedConstOf();
            if (i == 5) break;
            FuncDeclaration *f = NULL;

            unsigned errors = global.startGagging();    // Do not report errors, even if the
            sc = sc->push();
            sc->tinst = NULL;
            sc->minst = NULL;

            for (size_t j = 0; j < 2; j++)
            {
                (*a)[0] = (j == 0 ? er : el);
                (*a)[0]->type = tthis;
                f = resolveFuncCall(ad->loc, sc, eq, NULL, tthis, a, 1);
                if (f)
                    break;
            }

            sc = sc->pop();
            global.endGagging(errors);

            if (f)
            {
                if (f->errors)
                    return NULL;
                return f;
            }
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

FuncDeclaration *buildOpEquals(StructDeclaration *sd, Scope *sc)
{
    if (hasIdentityOpEquals(sd, sc))
    {
        sd->hasIdentityEquals = true;
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

FuncDeclaration *buildXopEquals(StructDeclaration *sd, Scope *sc)
{
    if (!needOpEquals(sd))
        return NULL;        // bitwise comparison would work

    //printf("StructDeclaration::buildXopEquals() %s\n", sd->toChars());
    if (Dsymbol *eq = search_function(sd, Id::eq))
    {
        if (FuncDeclaration *fd = eq->isFuncDeclaration())
        {
            TypeFunction *tfeqptr;
            {
                Scope scx;

                /* const bool opEquals(ref const S s);
                 */
                Parameters *parameters = new Parameters;
                parameters->push(new Parameter(STCref | STCconst, sd->type, NULL, NULL));
                tfeqptr = new TypeFunction(parameters, Type::tbool, 0, LINKd);
                tfeqptr->mod = MODconst;
                tfeqptr = (TypeFunction *)tfeqptr->semantic(Loc(), &scx);
            }
            fd = fd->overloadExactMatch(tfeqptr);
            if (fd)
                return fd;
        }
    }

    if (!sd->xerreq)
    {
        // object._xopEquals
        Identifier *id = Lexer::idPool("_xopEquals");
        Expression *e = new IdentifierExp(sd->loc, Id::empty);
        e = new DotIdExp(sd->loc, e, Id::object);
        e = new DotIdExp(sd->loc, e, id);
        e = e->semantic(sc);
        Dsymbol *s = getDsymbol(e);
        if (!s)
        {
            ::error(Loc(), "ICE: %s not found in object module. You must update druntime", id->toChars());
            fatal();
        }
        assert(s);
        sd->xerreq = s->isFuncDeclaration();
    }

    Loc declLoc = Loc();    // loc is unnecessary so __xopEquals is never called directly
    Loc loc = Loc();        // loc is unnecessary so errors are gagged

    Parameters *parameters = new Parameters;
    parameters->push(new Parameter(STCref | STCconst, sd->type, Id::p, NULL));
    parameters->push(new Parameter(STCref | STCconst, sd->type, Id::q, NULL));
    TypeFunction *tf = new TypeFunction(parameters, Type::tbool, 0, LINKd);

    Identifier *id = Id::xopEquals;
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
        fop = sd->xerreq;

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

FuncDeclaration *buildXopCmp(StructDeclaration *sd, Scope *sc)
{
    //printf("StructDeclaration::buildXopCmp() %s\n", toChars());
    if (Dsymbol *cmp = search_function(sd, Id::cmp))
    {
        if (FuncDeclaration *fd = cmp->isFuncDeclaration())
        {
            TypeFunction *tfcmpptr;
            {
                Scope scx;

                /* const int opCmp(ref const S s);
                 */
                Parameters *parameters = new Parameters;
                parameters->push(new Parameter(STCref | STCconst, sd->type, NULL, NULL));
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
        Expression *e = new DsymbolExp(sd->loc, sd);
        e = new DotIdExp(sd->loc, e, Id::cmp);
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

    if (!sd->xerrcmp)
    {
        // object._xopCmp
        Identifier *id = Lexer::idPool("_xopCmp");
        Expression *e = new IdentifierExp(sd->loc, Id::empty);
        e = new DotIdExp(sd->loc, e, Id::object);
        e = new DotIdExp(sd->loc, e, id);
        e = e->semantic(sc);
        Dsymbol *s = getDsymbol(e);
        if (!s)
        {
            ::error(Loc(), "ICE: %s not found in object module. You must update druntime", id->toChars());
            fatal();
        }
        assert(s);
        sd->xerrcmp = s->isFuncDeclaration();
    }

    Loc declLoc = Loc();    // loc is unnecessary so __xopCmp is never called directly
    Loc loc = Loc();        // loc is unnecessary so errors are gagged

    Parameters *parameters = new Parameters;
    parameters->push(new Parameter(STCref | STCconst, sd->type, Id::p, NULL));
    parameters->push(new Parameter(STCref | STCconst, sd->type, Id::q, NULL));
    TypeFunction *tf = new TypeFunction(parameters, Type::tint32, 0, LINKd);

    Identifier *id = Id::xopCmp;
    FuncDeclaration *fop = new FuncDeclaration(declLoc, Loc(), id, STCstatic, tf);

    Expression *e1 = new IdentifierExp(loc, Id::p);
    Expression *e2 = new IdentifierExp(loc, Id::q);
    Expression *e = new CallExp(loc, new DotIdExp(loc, e2, Id::cmp), e1);

    fop->fbody = new ReturnStatement(loc, e);

    unsigned errors = global.startGagging();    // Do not report errors
    Scope *sc2 = sc->push();
    sc2->stc = 0;
    sc2->linkage = LINKd;

    fop->semantic(sc2);
    fop->semantic2(sc2);

    sc2->pop();
    if (global.endGagging(errors))    // if errors happened
        fop = sd->xerrcmp;

    return fop;
}

/*******************************************
 * We need a toHash for the struct if
 * any fields has a toHash.
 * Generate one if a user-specified one does not exist.
 */

bool needToHash(StructDeclaration *sd)
{
    //printf("StructDeclaration::needToHash() %s\n", sd->toChars());

    if (sd->xhash)
        goto Lneed;

    if (sd->isUnionDeclaration())
        goto Ldontneed;

    /* If any of the fields has an opEquals, then we
     * need it too.
     */
    for (size_t i = 0; i < sd->fields.dim; i++)
    {
        VarDeclaration *v = sd->fields[i];
        if (v->storage_class & STCref)
            continue;
        Type *tv = v->type->toBasetype();
        if (tv->isfloating())
        {
            // This is necessray for:
            //  1. comparison of +0.0 and -0.0 should be true.
            goto Lneed;
        }
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
            if (needToHash(ts->sym))
                goto Lneed;
        }
    }
Ldontneed:
    //printf("\tdontneed\n");
    return false;

Lneed:
    //printf("\tneed\n");
    return true;
}

/******************************************
 * Build __xtoHash for non-bitwise hashing
 *      static hash_t xtoHash(ref const S p) nothrow @trusted;
 */

FuncDeclaration *buildXtoHash(StructDeclaration *sd, Scope *sc)
{
    if (Dsymbol *s = search_function(sd, Id::tohash))
    {
        static TypeFunction *tftohash;
        if (!tftohash)
        {
            tftohash = new TypeFunction(NULL, Type::thash_t, 0, LINKd);
            tftohash->mod = MODconst;
            tftohash = (TypeFunction *)tftohash->merge();
        }

        if (FuncDeclaration *fd = s->isFuncDeclaration())
        {
            fd = fd->overloadExactMatch(tftohash);
            if (fd)
                return fd;
        }
    }

    if (!needToHash(sd))
        return NULL;

    //printf("StructDeclaration::buildXtoHash() %s\n", sd->toPrettyChars());
    Loc declLoc = Loc();    // loc is unnecessary so __xtoHash is never called directly
    Loc loc = Loc();        // internal code should have no loc to prevent coverage

    Parameters *parameters = new Parameters();
    parameters->push(new Parameter(STCref | STCconst, sd->type, Id::p, NULL));
    TypeFunction *tf = new TypeFunction(parameters, Type::thash_t, 0, LINKd, STCnothrow | STCtrusted);

    Identifier *id = Id::xtoHash;
    FuncDeclaration *fop = new FuncDeclaration(declLoc, Loc(), id, STCstatic, tf);

    const char *code =
        "size_t h = 0;"
        "foreach (i, T; typeof(p.tupleof))"
        "    h += typeid(T).getHash(cast(const void*)&p.tupleof[i]);"
        "return h;";
    fop->fbody = new CompileStatement(loc, new StringExp(loc, (char *)code));

    Scope *sc2 = sc->push();
    sc2->stc = 0;
    sc2->linkage = LINKd;

    fop->semantic(sc2);
    fop->semantic2(sc2);

    sc2->pop();

    //printf("%s fop = %s %s\n", sd->toChars(), fop->toChars(), fop->type->toChars());
    return fop;
}

/*******************************************
 * Build copy constructor for struct.
 *      void __cpctpr(ref const S s) [pure nothrow @trusted]
 *      {
 *          this = s;   // blit copy
 *          this.postBlit();
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

FuncDeclaration *buildCpCtor(StructDeclaration *sd, Scope *sc)
{
    /* Copy constructor is only necessary if there is a postblit function,
     * otherwise the code generator will just do a bit copy.
     */
    if (!sd->postblit)
        return NULL;

    //printf("StructDeclaration::buildCpCtor() %s\n", toChars());
    StorageClass stc = STCsafe | STCnothrow | STCpure | STCnogc;
    Loc declLoc = sd->postblit->loc;
    Loc loc = Loc();    // internal code should have no loc to prevent coverage

    stc = mergeFuncAttrs(stc, sd->postblit);
    if (stc & STCsafe)  // change to @trusted for unsafe casts
        stc = (stc & ~STCsafe) | STCtrusted;

    Parameters *fparams = new Parameters;
    fparams->push(new Parameter(STCref, sd->type->constOf(), Id::p, NULL));
    Type *tf = new TypeFunction(fparams, Type::tvoid, 0, LINKd, stc);

    FuncDeclaration *fcp = new FuncDeclaration(declLoc, Loc(), Id::cpctor, stc, tf);

    if (!(stc & STCdisable))
    {
        Expression *e;

        // Build this = p;
        e = new BlitExp(loc,
            new PtrExp(loc, new AddrExp(loc, new ThisExp(loc))),
            new PtrExp(loc, new AddrExp(loc, new IdentifierExp(loc, Id::p)))
        );
        Statement *s = new ExpStatement(loc, e);

        // Build postBlit();
        e = new DotVarExp(loc, new ThisExp(loc), sd->postblit, 0);
        e = new CallExp(loc, e);

        s = new CompoundStatement(loc, s, new ExpStatement(loc, e));
        fcp->fbody = s;
    }

    sd->members->push(fcp);

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

FuncDeclaration *buildPostBlit(StructDeclaration *sd, Scope *sc)
{
    //printf("StructDeclaration::buildPostBlit() %s\n", sd->toChars());
    StorageClass stc = STCsafe | STCnothrow | STCpure | STCnogc;
    Loc declLoc = sd->postblits.dim ? sd->postblits[0]->loc : sd->loc;
    Loc loc = Loc();    // internal code should have no loc to prevent coverage

    Expression *e = NULL;
    for (size_t i = 0; i < sd->postblits.dim; i++)
    {
        stc |= sd->postblits[i]->storage_class & STCdisable;
    }

    for (size_t i = 0; i < sd->fields.dim && !(stc & STCdisable); i++)
    {
        VarDeclaration *v = sd->fields[i];
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
            StructDeclaration *sd2 = ts->sym;
            if (sd2->postblit && dim)
            {
                stc = mergeFuncAttrs(stc, sd2->postblit);
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
                    ex = new DotVarExp(loc, ex, sd2->postblit, 0);
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
    {
        //printf("Building __fieldPostBlit()\n");
        PostBlitDeclaration *dd = new PostBlitDeclaration(declLoc, Loc(), stc, Lexer::idPool("__fieldPostBlit"));
        dd->fbody = new ExpStatement(loc, e);
        sd->postblits.shift(dd);
        sd->members->push(dd);
        dd->semantic(sc);
    }

    switch (sd->postblits.dim)
    {
        case 0:
            return NULL;

        case 1:
            return sd->postblits[0];

        default:
            e = NULL;
            stc = STCsafe | STCnothrow | STCpure | STCnogc;
            for (size_t i = 0; i < sd->postblits.dim; i++)
            {
                FuncDeclaration *fd = sd->postblits[i];
                stc = mergeFuncAttrs(stc, fd);
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
            sd->members->push(dd);
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

FuncDeclaration *buildDtor(AggregateDeclaration *ad, Scope *sc)
{
    //printf("AggregateDeclaration::buildDtor() %s\n", ad->toChars());
    StorageClass stc = STCsafe | STCnothrow | STCpure | STCnogc;
    Loc declLoc = ad->dtors.dim ? ad->dtors[0]->loc : ad->loc;
    Loc loc = Loc();    // internal code should have no loc to prevent coverage

    Expression *e = NULL;
    for (size_t i = 0; i < ad->fields.dim; i++)
    {
        VarDeclaration *v = ad->fields[i];
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
                stc = mergeFuncAttrs(stc, sd->dtor);
                if (stc & STCdisable)
                {
                    e = NULL;
                    break;
                }

                // this.v
                Expression *ex = new ThisExp(loc);
                ex = new DotVarExp(loc, ex, v, 0);

                if (v->type->toBasetype()->ty == Tstruct)
                {
                    // this.v.dtor()
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
    {
        //printf("Building __fieldDtor()\n");
        DtorDeclaration *dd = new DtorDeclaration(declLoc, Loc(), stc, Lexer::idPool("__fieldDtor"));
        dd->fbody = new ExpStatement(loc, e);
        ad->dtors.shift(dd);
        ad->members->push(dd);
        dd->semantic(sc);
    }

    switch (ad->dtors.dim)
    {
        case 0:
            return NULL;

        case 1:
            return ad->dtors[0];

        default:
            e = NULL;
            stc = STCsafe | STCnothrow | STCpure | STCnogc;
            for (size_t i = 0; i < ad->dtors.dim; i++)
            {
                FuncDeclaration *fd = ad->dtors[i];
                stc = mergeFuncAttrs(stc, fd);
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
            ad->members->push(dd);
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

FuncDeclaration *buildInv(AggregateDeclaration *ad, Scope *sc)
{
    StorageClass stc = STCsafe | STCnothrow | STCpure | STCnogc;
    Loc declLoc = ad->loc;
    Loc loc = Loc();    // internal code should have no loc to prevent coverage

    switch (ad->invs.dim)
    {
        case 0:
            return NULL;

        case 1:
            // Don't return invs[0] so it has uniquely generated name.
            /* fall through */

        default:
            Expression *e = NULL;
            StorageClass stcx = 0;
            for (size_t i = 0; i < ad->invs.dim; i++)
            {
                stc = mergeFuncAttrs(stc, ad->invs[i]);
                if (stc & STCdisable)
                {
                    // What should do?
                }
                StorageClass stcy = (ad->invs[i]->storage_class & STCsynchronized) |
                                    (ad->invs[i]->type->mod & MODshared ? STCshared : 0);
                if (i == 0)
                    stcx = stcy;
                else if (stcx ^ stcy)
                {
            #if 1   // currently rejects
                    ad->error(ad->invs[i]->loc, "mixing invariants with shared/synchronized differene is not supported");
                    e = NULL;
                    break;
            #endif
                }
                e = Expression::combine(e, new CallExp(loc, new VarExp(loc, ad->invs[i])));
            }
            InvariantDeclaration *inv;
            inv = new InvariantDeclaration(declLoc, Loc(), stc | stcx, Id::classInvariant);
            inv->fbody = new ExpStatement(loc, e);
            ad->members->push(inv);
            inv->semantic(sc);
            return inv;
    }
}
