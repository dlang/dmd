
// Compiler implementation of the D programming language
// Copyright (c) 1999-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <stdlib.h>
#include <ctype.h>
#include <assert.h>
#include <math.h>

#include "rmem.h"
#include "aav.h"

//#include "port.h"
#include "mtype.h"
#include "init.h"
#include "expression.h"
#include "template.h"
#include "utf.h"
#include "enum.h"
#include "scope.h"
#include "statement.h"
#include "declaration.h"
#include "aggregate.h"
#include "import.h"
#include "id.h"
#include "dsymbol.h"
#include "module.h"
#include "attrib.h"
#include "hdrgen.h"
#include "parse.h"

#define LOGSEMANTIC     0


/************************************************
 * Delegate to be passed to overloadApply() that looks
 * for functions matching a trait.
 */

struct Ptrait
{
    Expression *e1;
    Expressions *exps;          // collected results
    Identifier *ident;          // which trait we're looking for
};

static int fptraits(void *param, Dsymbol *s)
{
    FuncDeclaration *f = s->isFuncDeclaration();
    if (!f)
        return 0;

    Ptrait *p = (Ptrait *)param;
    if (p->ident == Id::getVirtualFunctions && !f->isVirtual())
        return 0;

    if (p->ident == Id::getVirtualMethods && !f->isVirtualMethod())
        return 0;

    Expression *e;
    FuncAliasDeclaration* alias = new FuncAliasDeclaration(f, 0);
    alias->protection = f->protection;
    if (p->e1)
        e = new DotVarExp(Loc(), p->e1, alias);
    else
        e = new DsymbolExp(Loc(), alias);
    p->exps->push(e);
    return 0;
}

/**
 * Collects all unit test functions from the given array of symbols.
 *
 * This is a helper function used by the implementation of __traits(getUnitTests).
 *
 * Input:
 *      symbols             array of symbols to collect the functions from
 *      uniqueUnitTests     an associative array (should actually be a set) to
 *                          keep track of already collected functions. We're
 *                          using an AA here to avoid doing a linear search of unitTests
 *
 * Output:
 *      unitTests           array of DsymbolExp's of the collected unit test functions
 *      uniqueUnitTests     updated with symbols from unitTests[ ]
 */
static void collectUnitTests(Dsymbols *symbols, AA *uniqueUnitTests, Expressions *unitTests)
{
    if (!symbols)
        return;
    for (size_t i = 0; i < symbols->dim; i++)
    {
        Dsymbol *symbol = (*symbols)[i];
        UnitTestDeclaration *unitTest = symbol->isUnitTestDeclaration();
        if (unitTest)
        {
            if (!_aaGetRvalue(uniqueUnitTests, unitTest))
            {
                FuncAliasDeclaration* alias = new FuncAliasDeclaration(unitTest, 0);
                alias->protection = unitTest->protection;
                Expression* e = new DsymbolExp(Loc(), alias);
                unitTests->push(e);
                bool* value = (bool*) _aaGet(&uniqueUnitTests, unitTest);
                *value = true;
            }
        }
        else
        {
            AttribDeclaration *attrDecl = symbol->isAttribDeclaration();

            if (attrDecl)
            {
                Dsymbols *decl = attrDecl->include(NULL, NULL);
                collectUnitTests(decl, uniqueUnitTests, unitTests);
            }
        }
    }
}

/************************ TraitsExp ************************************/

bool isTypeArithmetic(Type *t)       { return t->isintegral() || t->isfloating(); }
bool isTypeFloating(Type *t)         { return t->isfloating(); }
bool isTypeIntegral(Type *t)         { return t->isintegral(); }
bool isTypeScalar(Type *t)           { return t->isscalar(); }
bool isTypeUnsigned(Type *t)         { return t->isunsigned(); }
bool isTypeAssociativeArray(Type *t) { return t->toBasetype()->ty == Taarray; }
bool isTypeStaticArray(Type *t)      { return t->toBasetype()->ty == Tsarray; }
bool isTypeAbstractClass(Type *t)    { return t->toBasetype()->ty == Tclass && ((TypeClass *)t->toBasetype())->sym->isAbstract(); }
bool isTypeFinalClass(Type *t)       { return t->toBasetype()->ty == Tclass && (((TypeClass *)t->toBasetype())->sym->storage_class & STCfinal) != 0; }

Expression *TraitsExp::isTypeX(bool (*fp)(Type *t))
{
    int result = 0;
    if (!args || !args->dim)
        goto Lfalse;
    for (size_t i = 0; i < args->dim; i++)
    {
        Type *t = getType((*args)[i]);
        if (!t || !fp(t))
            goto Lfalse;
    }
    result = 1;
Lfalse:
    return new IntegerExp(loc, result, Type::tbool);
}

bool isFuncAbstractFunction(FuncDeclaration *f) { return f->isAbstract(); }
bool isFuncVirtualFunction(FuncDeclaration *f) { return f->isVirtual(); }
bool isFuncVirtualMethod(FuncDeclaration *f) { return f->isVirtualMethod(); }
bool isFuncFinalFunction(FuncDeclaration *f) { return f->isFinalFunc(); }
bool isFuncStaticFunction(FuncDeclaration *f) { return !f->needThis() && !f->isNested(); }
bool isFuncOverrideFunction(FuncDeclaration *f) { return f->isOverride(); }

Expression *TraitsExp::isFuncX(bool (*fp)(FuncDeclaration *f))
{
    int result = 0;
    if (!args || !args->dim)
        goto Lfalse;
    for (size_t i = 0; i < args->dim; i++)
    {
        Dsymbol *s = getDsymbol((*args)[i]);
        if (!s)
            goto Lfalse;
        FuncDeclaration *f = s->isFuncDeclaration();
        if (!f || !fp(f))
            goto Lfalse;
    }
    result = 1;
Lfalse:
    return new IntegerExp(loc, result, Type::tbool);
}

bool isDeclRef(Declaration *d) { return d->isRef(); }
bool isDeclOut(Declaration *d) { return d->isOut(); }
bool isDeclLazy(Declaration *d) { return (d->storage_class & STClazy) != 0; }

Expression *TraitsExp::isDeclX(bool (*fp)(Declaration *d))
{
    int result = 0;
    if (!args || !args->dim)
        goto Lfalse;
    for (size_t i = 0; i < args->dim; i++)
    {
        Dsymbol *s = getDsymbol((*args)[i]);
        if (!s)
            goto Lfalse;
        Declaration *d = s->isDeclaration();
        if (!d || !fp(d))
            goto Lfalse;
    }
    result = 1;
Lfalse:
    return new IntegerExp(loc, result, Type::tbool);
}

Expression *TraitsExp::semantic(Scope *sc)
{
#if LOGSEMANTIC
    printf("TraitsExp::semantic() %s\n", toChars());
#endif
    if (ident != Id::compiles && ident != Id::isSame &&
        ident != Id::identifier && ident != Id::getProtection)
    {
        TemplateInstance::semanticTiargs(loc, sc, args, 1);
    }
    size_t dim = args ? args->dim : 0;
    Declaration *d;

    if (ident == Id::isArithmetic)
    {
        return isTypeX(&isTypeArithmetic);
    }
    else if (ident == Id::isFloating)
    {
        return isTypeX(&isTypeFloating);
    }
    else if (ident == Id::isIntegral)
    {
        return isTypeX(&isTypeIntegral);
    }
    else if (ident == Id::isScalar)
    {
        return isTypeX(&isTypeScalar);
    }
    else if (ident == Id::isUnsigned)
    {
        return isTypeX(&isTypeUnsigned);
    }
    else if (ident == Id::isAssociativeArray)
    {
        return isTypeX(&isTypeAssociativeArray);
    }
    else if (ident == Id::isStaticArray)
    {
        return isTypeX(&isTypeStaticArray);
    }
    else if (ident == Id::isAbstractClass)
    {
        return isTypeX(&isTypeAbstractClass);
    }
    else if (ident == Id::isFinalClass)
    {
        return isTypeX(&isTypeFinalClass);
    }
    else if (ident == Id::isPOD)
    {
        if (dim != 1)
            goto Ldimerror;
        RootObject *o = (*args)[0];
        Type *t = isType(o);
        StructDeclaration *sd;
        if (!t)
        {
            error("type expected as second argument of __traits %s instead of %s", ident->toChars(), o->toChars());
            goto Lfalse;
        }
        if (t->toBasetype()->ty == Tstruct
              && ((sd = (StructDeclaration *)(((TypeStruct *)t->toBasetype())->sym)) != NULL))
        {
            if (sd->isPOD())
                goto Ltrue;
            else
                goto Lfalse;
        }
        goto Ltrue;
    }
    else if (ident == Id::isNested)
    {
        if (dim != 1)
            goto Ldimerror;
        RootObject *o = (*args)[0];
        Dsymbol *s = getDsymbol(o);
        AggregateDeclaration *a;
        FuncDeclaration *f;

        if (!s) { }
        else if ((a = s->isAggregateDeclaration()) != NULL)
        {
            if (a->isNested())
                goto Ltrue;
            else
                goto Lfalse;
        }
        else if ((f = s->isFuncDeclaration()) != NULL)
        {
            if (f->isNested())
                goto Ltrue;
            else
                goto Lfalse;
        }

        error("aggregate or function expected instead of '%s'", o->toChars());
        goto Lfalse;
    }
    else if (ident == Id::isAbstractFunction)
    {
        return isFuncX(&isFuncAbstractFunction);
    }
    else if (ident == Id::isVirtualFunction)
    {
        return isFuncX(&isFuncVirtualFunction);
    }
    else if (ident == Id::isVirtualMethod)
    {
        return isFuncX(&isFuncVirtualMethod);
    }
    else if (ident == Id::isFinalFunction)
    {
        return isFuncX(&isFuncFinalFunction);
    }
    else if (ident == Id::isStaticFunction)
    {
        return isFuncX(&isFuncStaticFunction);
    }
    else if (ident == Id::isRef)
    {
        return isDeclX(&isDeclRef);
    }
    else if (ident == Id::isOut)
    {
        return isDeclX(&isDeclOut);
    }
    else if (ident == Id::isLazy)
    {
        return isDeclX(&isDeclLazy);
    }
    else if (ident == Id::identifier)
    {   // Get identifier for symbol as a string literal

        /* Specify 0 for bit 0 of the flags argument to semanticTiargs() so that
         * a symbol should not be folded to a constant.
         * Bit 1 means don't convert Parameter to Type if Parameter has an identifier
         */
        TemplateInstance::semanticTiargs(loc, sc, args, 2);

        if (dim != 1)
            goto Ldimerror;
        RootObject *o = (*args)[0];
        Parameter *po = isParameter(o);
        Identifier *id;
        if (po)
        {   id = po->ident;
            assert(id);
        }
        else
        {
            Dsymbol *s = getDsymbol(o);
            if (!s || !s->ident)
            {
                error("argument %s has no identifier", o->toChars());
                goto Lfalse;
            }
            id = s->ident;
        }
        StringExp *se = new StringExp(loc, id->toChars());
        return se->semantic(sc);
    }
    else if (ident == Id::getProtection)
    {
        if (dim != 1)
            goto Ldimerror;

        Scope *sc2 = sc->push();
        sc2->flags = sc->flags | SCOPEnoaccesscheck;
        TemplateInstance::semanticTiargs(loc, sc2, args, 1);
        sc2->pop();

        RootObject *o = (*args)[0];
        Dsymbol *s = getDsymbol(o);
        if (!s)
        {
            if (!isError(o))
                error("argument %s has no protection", o->toChars());
            goto Lfalse;
        }
        if (s->scope)
            s->semantic(s->scope);
        PROT protection = s->prot();

        const char *protName = Pprotectionnames[protection];

        assert(protName);
        StringExp *se = new StringExp(loc, (char *) protName);
        return se->semantic(sc);
    }
    else if (ident == Id::parent)
    {
        if (dim != 1)
            goto Ldimerror;
        RootObject *o = (*args)[0];
        Dsymbol *s = getDsymbol(o);
        if (s)
        {
            if (FuncDeclaration *fd = s->isFuncDeclaration())   // Bugzilla 8943
                s = fd->toAliasFunc();
            if (!s->isImport())  // Bugzilla 8922
                s = s->toParent();
        }
        if (!s || s->isImport())
        {
            error("argument %s has no parent", o->toChars());
            goto Lfalse;
        }
        return (new DsymbolExp(loc, s))->semantic(sc);
    }
    else if (ident == Id::hasMember ||
             ident == Id::getMember ||
             ident == Id::getOverloads ||
             ident == Id::getVirtualMethods ||
             ident == Id::getVirtualFunctions)
    {
        if (dim != 2)
            goto Ldimerror;
        RootObject *o = (*args)[0];
        Expression *e = isExpression((*args)[1]);
        if (!e)
        {   error("expression expected as second argument of __traits %s", ident->toChars());
            goto Lfalse;
        }
        e = e->ctfeInterpret();
        StringExp *se = e->toString();
        if (!se || se->length() == 0)
        {   error("string expected as second argument of __traits %s instead of %s", ident->toChars(), e->toChars());
            goto Lfalse;
        }
        se = se->toUTF8(sc);
        if (se->sz != 1)
        {   error("string must be chars");
            goto Lfalse;
        }
        Identifier *id = Lexer::idPool((char *)se->string);

        /* Prefer dsymbol, because it might need some runtime contexts.
         */
        Dsymbol *sym = getDsymbol(o);
        if (sym)
        {   e = new DsymbolExp(loc, sym);
            e = new DotIdExp(loc, e, id);
        }
        else if (Type *t = isType(o))
            e = typeDotIdExp(loc, t, id);
        else if (Expression *ex = isExpression(o))
            e = new DotIdExp(loc, ex, id);
        else
        {   error("invalid first argument");
            goto Lfalse;
        }

        if (ident == Id::hasMember)
        {
            if (sym)
            {
                Dsymbol *sm = sym->search(loc, id, 0);
                if (sm)
                    goto Ltrue;
            }

            /* Take any errors as meaning it wasn't found
             */
            Scope *sc2 = sc->push();
            e = e->trySemantic(sc2);
            sc2->pop();
            if (!e)
                goto Lfalse;
            else
                goto Ltrue;
        }
        else if (ident == Id::getMember)
        {
            e = e->semantic(sc);
            return e;
        }
        else if (ident == Id::getVirtualFunctions ||
                 ident == Id::getVirtualMethods ||
                 ident == Id::getOverloads)
        {
            unsigned errors = global.errors;
            Expression *ex = e;
            e = e->semantic(sc);
            if (errors < global.errors)
                error("%s cannot be resolved", ex->toChars());

            /* Create tuple of functions of e
             */
            //e->dump(0);
            Expressions *exps = new Expressions();
            FuncDeclaration *f;
            if (e->op == TOKvar)
            {   VarExp *ve = (VarExp *)e;
                f = ve->var->isFuncDeclaration();
                e = NULL;
            }
            else if (e->op == TOKdotvar)
            {   DotVarExp *dve = (DotVarExp *)e;
                f = dve->var->isFuncDeclaration();
                if (dve->e1->op == TOKdottype || dve->e1->op == TOKthis)
                    e = NULL;
                else
                    e = dve->e1;
            }
            else
                f = NULL;
            Ptrait p;
            p.exps = exps;
            p.e1 = e;
            p.ident = ident;
            overloadApply(f, &p, &fptraits);

            TupleExp *tup = new TupleExp(loc, exps);
            return tup->semantic(sc);
        }
        else
            assert(0);
    }
    else if (ident == Id::classInstanceSize)
    {
        if (dim != 1)
            goto Ldimerror;
        RootObject *o = (*args)[0];
        Dsymbol *s = getDsymbol(o);
        ClassDeclaration *cd;
        if (!s || (cd = s->isClassDeclaration()) == NULL)
        {
            error("first argument is not a class");
            goto Lfalse;
        }
        return new IntegerExp(loc, cd->structsize, Type::tsize_t);
    }
    else if (ident == Id::getAttributes)
    {
        if (dim != 1)
            goto Ldimerror;
        RootObject *o = (*args)[0];
        Dsymbol *s = getDsymbol(o);
        if (!s)
        {
        #if 0
            Expression *e = isExpression(o);
            Type *t = isType(o);
            if (e) printf("e = %s %s\n", Token::toChars(e->op), e->toChars());
            if (t) printf("t = %d %s\n", t->ty, t->toChars());
        #endif
            error("first argument is not a symbol");
            goto Lfalse;
        }
        //printf("getAttributes %s, %p\n", s->toChars(), s->userAttributes);
        if (!s->userAttributes)
            s->userAttributes = new Expressions();
        TupleExp *tup = new TupleExp(loc, s->userAttributes);
        return tup->semantic(sc);
    }
    else if (ident == Id::allMembers || ident == Id::derivedMembers)
    {
        if (dim != 1)
            goto Ldimerror;
        RootObject *o = (*args)[0];
        Dsymbol *s = getDsymbol(o);
        ScopeDsymbol *sd;
        if (!s)
        {
            error("argument has no members");
            goto Lfalse;
        }
        Import *import;
        if ((import = s->isImport()) != NULL)
        {   // Bugzilla 9692
            sd = import->mod;
        }
        else if ((sd = s->isScopeDsymbol()) == NULL)
        {
            error("%s %s has no members", s->kind(), s->toChars());
            goto Lfalse;
        }

        // use a struct as local function
        struct PushIdentsDg
        {
            static int dg(void *ctx, size_t n, Dsymbol *sm)
            {
                if (!sm)
                    return 1;
                //printf("\t[%i] %s %s\n", i, sm->kind(), sm->toChars());
                if (sm->ident)
                {
                    if (sm->ident != Id::ctor &&        // backword compatibility
                        sm->ident != Id::dtor &&        // backword compatibility
                        sm->ident != Id::_postblit &&   // backword compatibility
                        memcmp(sm->ident->string, "__", 2) == 0)
                    {
                        return 0;
                    }

                    //printf("\t%s\n", sm->ident->toChars());
                    Identifiers *idents = (Identifiers *)ctx;

                    /* Skip if already present in idents[]
                     */
                    for (size_t j = 0; j < idents->dim; j++)
                    {   Identifier *id = (*idents)[j];
                        if (id == sm->ident)
                            return 0;
#ifdef DEBUG
                        // Avoid using strcmp in the first place due to the performance impact in an O(N^2) loop.
                        assert(strcmp(id->toChars(), sm->ident->toChars()) != 0);
#endif
                    }

                    idents->push(sm->ident);
                }
                else
                {
                    EnumDeclaration *ed = sm->isEnumDeclaration();
                    if (ed)
                    {
                        ScopeDsymbol::foreach(NULL, ed->members, &PushIdentsDg::dg, (Identifiers *)ctx);
                    }
                }
                return 0;
            }
        };

        Identifiers *idents = new Identifiers;

        ScopeDsymbol::foreach(sc, sd->members, &PushIdentsDg::dg, idents);

        ClassDeclaration *cd = sd->isClassDeclaration();
        if (cd && ident == Id::allMembers)
        {
            struct PushBaseMembers
            {
                static void dg(ClassDeclaration *cd, Identifiers *idents)
                {
                    for (size_t i = 0; i < cd->baseclasses->dim; i++)
                    {   ClassDeclaration *cb = (*cd->baseclasses)[i]->base;
                        ScopeDsymbol::foreach(NULL, cb->members, &PushIdentsDg::dg, idents);
                        if (cb->baseclasses->dim)
                            dg(cb, idents);
                    }
                }
            };
            PushBaseMembers::dg(cd, idents);
        }

        // Turn Identifiers into StringExps reusing the allocated array
        assert(sizeof(Expressions) == sizeof(Identifiers));
        Expressions *exps = (Expressions *)idents;
        for (size_t i = 0; i < idents->dim; i++)
        {   Identifier *id = (*idents)[i];
            StringExp *se = new StringExp(loc, id->toChars());
            (*exps)[i] = se;
        }

        /* Making this a tuple is more flexible, as it can be statically unrolled.
         * To make an array literal, enclose __traits in [ ]:
         *   [ __traits(allMembers, ...) ]
         */
        Expression *e = new TupleExp(loc, exps);
        e = e->semantic(sc);
        return e;
    }
    else if (ident == Id::compiles)
    {
        /* Determine if all the objects - types, expressions, or symbols -
         * compile without error
         */
        if (!dim)
            goto Lfalse;

        for (size_t i = 0; i < dim; i++)
        {
            unsigned errors = global.startGagging();
            unsigned oldspec = global.speculativeGag;
            global.speculativeGag = global.gag;
            Scope *sc2 = sc->push();
            sc2->speculative = true;
            sc2->flags = sc->flags & ~SCOPEctfe | SCOPEcompile;
            bool err = false;

            RootObject *o = (*args)[i];
            Type *t = isType(o);
            Expression *e = t ? t->toExpression() : isExpression(o);
            if (!e && t)
            {
                Dsymbol *s;
                t->resolve(loc, sc2, &e, &t, &s);
                if (t)
                {
                    t->semantic(loc, sc2);
                    if (t->ty == Terror)
                        err = true;
                }
                else if (s && s->errors)
                    err = true;
            }
            if (e)
            {
                e = e->semantic(sc2);
                e = e->optimize(WANTvalue);
                if (e->op == TOKerror)
                    err = true;
            }

            sc2->pop();
            global.speculativeGag = oldspec;
            if (global.endGagging(errors) || err)
            {
                goto Lfalse;
            }
        }
        goto Ltrue;
    }
    else if (ident == Id::isSame)
    {   /* Determine if two symbols are the same
         */
        if (dim != 2)
            goto Ldimerror;
        TemplateInstance::semanticTiargs(loc, sc, args, 0);
        RootObject *o1 = (*args)[0];
        RootObject *o2 = (*args)[1];
        Dsymbol *s1 = getDsymbol(o1);
        Dsymbol *s2 = getDsymbol(o2);

        //printf("isSame: %s, %s\n", o1->toChars(), o2->toChars());
#if 0
        printf("o1: %p\n", o1);
        printf("o2: %p\n", o2);
        if (!s1)
        {   Expression *ea = isExpression(o1);
            if (ea)
                printf("%s\n", ea->toChars());
            Type *ta = isType(o1);
            if (ta)
                printf("%s\n", ta->toChars());
            goto Lfalse;
        }
        else
            printf("%s %s\n", s1->kind(), s1->toChars());
#endif
        if (!s1 && !s2)
        {   Expression *ea1 = isExpression(o1);
            Expression *ea2 = isExpression(o2);
            if (ea1 && ea2)
            {
                if (ea1->equals(ea2))
                    goto Ltrue;
            }
        }

        if (!s1 || !s2)
            goto Lfalse;

        s1 = s1->toAlias();
        s2 = s2->toAlias();

        if (s1->isFuncAliasDeclaration())
            s1 = ((FuncAliasDeclaration *)s1)->toAliasFunc();
        if (s2->isFuncAliasDeclaration())
            s2 = ((FuncAliasDeclaration *)s2)->toAliasFunc();

        if (s1 == s2)
            goto Ltrue;
        else
            goto Lfalse;
    }
    else if (ident == Id::getUnitTests)
    {
        if (dim != 1)
            goto Ldimerror;
        RootObject *o = (*args)[0];
        Dsymbol *s = getDsymbol(o);
        if (!s)
        {
            error("argument %s to __traits(getUnitTests) must be a module or aggregate", o->toChars());
            goto Lfalse;
        }

        Import *imp = s->isImport();
        if (imp)  // Bugzilla 10990
            s = imp->mod;

        ScopeDsymbol* scope = s->isScopeDsymbol();

        if (!scope)
        {
            error("argument %s to __traits(getUnitTests) must be a module or aggregate, not a %s", s->toChars(), s->kind());
            goto Lfalse;
        }

        Expressions* unitTests = new Expressions();
        Dsymbols* symbols = scope->members;

        if (global.params.useUnitTests && symbols)
        {
            // Should actually be a set
            AA* uniqueUnitTests = NULL;
            collectUnitTests(symbols, uniqueUnitTests, unitTests);
        }

        TupleExp *tup = new TupleExp(loc, unitTests);
        return tup->semantic(sc);
    }
    else if (ident == Id::isOverrideFunction)
    {
        return isFuncX(&isFuncOverrideFunction);
    }
    else if(ident == Id::getVirtualIndex)
    {
        if (dim != 1)
            goto Ldimerror;
        RootObject *o = (*args)[0];
        Dsymbol *s = getDsymbol(o);
        FuncDeclaration *fd;
        if (!s || (fd = s->isFuncDeclaration()) == NULL)
        {
            error("first argument to __traits(getVirtualIndex) must be a function");
            goto Lfalse;
        }
        fd = fd->toAliasFunc(); // Neccessary to support multiple overloads.
        ptrdiff_t result = fd->isVirtual() ? fd->vtblIndex : -1;
        return new IntegerExp(loc, fd->vtblIndex, Type::tptrdiff_t);
    }
    else
    {   error("unrecognized trait %s", ident->toChars());
        goto Lfalse;
    }

    return NULL;

Ldimerror:
    error("wrong number of arguments %d", (int)dim);
    goto Lfalse;


Lfalse:
    return new IntegerExp(loc, 0, Type::tbool);

Ltrue:
    return new IntegerExp(loc, 1, Type::tbool);
}
