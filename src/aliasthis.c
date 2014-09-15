
/* Compiler implementation of the D programming language
 * Copyright (c) 2009-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/aliasthis.c
 */

#include <stdio.h>
#include <assert.h>

#include "mars.h"
#include "identifier.h"
#include "aliasthis.h"
#include "scope.h"
#include "aggregate.h"
#include "dsymbol.h"
#include "mtype.h"
#include "declaration.h"
#include "tokens.h"
#include "enum.h"
#include "template.h"
#include "arraytypes.h"
#include "expression.h"

/**
 * Returns expression for the `num`-th alias this symbol ot `e`.
 */
Expression *resolveAliasThis(Scope *sc, Expression *e, size_t num)
{
    AggregateDeclaration *ad = isAggregate(e->type);

    if (ad && ad->aliasThisSymbols)
    {
        Loc loc = e->loc;
        Type *tthis = (e->op == TOKtype ? e->type : NULL);
        e = new DotIdExp(loc, e, (*ad->aliasThisSymbols)[num]->ident);
        e = e->semantic(sc);
        if (tthis && (*ad->aliasThisSymbols)[num]->needThis())
        {
            if (e->op == TOKvar)
            {
                if (FuncDeclaration *f = ((VarExp *)e)->var->isFuncDeclaration())
                {
                    // Bugzilla 13009: Support better match for the overloaded alias this.
                    Type *t;
                    f = f->overloadModMatch(loc, tthis, t);
                    if (f && t)
                    {
                        e = new VarExp(loc, f, 0);  // use better match
                        e = new CallExp(loc, e);
                        goto L1;
                    }
                }
            }
            /* non-@property function is not called inside typeof(),
             * so resolve it ahead.
             */
            {
            int save = sc->intypeof;
            sc->intypeof = 1;   // bypass "need this" error check
            e = resolveProperties(sc, e);
            sc->intypeof = save;
            }

        L1:
            e = new TypeExp(loc, new TypeTypeof(loc, e));
            e = e->semantic(sc);
        }
        e = resolveProperties(sc, e);
    }

    return e;
}

/**
 * iterateAliasThis resolves alias this subtypes for `e` and applies it to `dg`.
 * dg should return true, if appropriate subtype has been found.
 * Otherwise it should returns 0.
 * Also dg can get context through secong parameter `ctx`, which was passed through
 * fourth argument of iterateAliasThis.  `dg` can return result expression through
 * `outexpr` parameter, and if it is not NULL, it will be pushed to `ret` array.
 * At the first stage iterateAliasThis iterates direct "alias this"-es and pushes non-null
 * `outexpr`-es to `ret`. If `dg` for one of direct "alias this"-es returns true then
 * `iterateAliasThis` breaks at this stage and returns true through return value and
 * returned by `dg` expression array through `ret`.
 * Even if true returned by first `dg` call, remaining direct "alias this"-es will be processed.
 *
 * If neither of the direct aliases did not return true iterateAliasThis
 * is recursive applied to direct aliases and base classes and interfaces.
 * If one of those `iterateAliasThis` calls returns true our `iterateAliasThis` will return true.
 * Otherwise it will return 0.
 *
 * The last argument is needed for internal using and should be NULL in user call.
 * It contains a hash table of visited types and used for avoiding of infinity recursion if
 * processed type has a circular alias this subtyping:
 * class A
 * {
 *      B b;
 *      alias b this;
 * }
 *
 * class B
 * {
 *      C c;
 *      alias c this;
 * }
 *
 * class C
 * {
 *      A a;
 *      alias a this;
 * }
 */

bool iterateAliasThis(Scope *sc, Expression *e, IterateAliasThisDg dg,
                      void *ctx, Expressions *ret, bool gagerrors, StringTable *directtypes)
{
    //printf("iterateAliasThis: %s\n", e->toChars());

    Dsymbols *aliasThisSymbols = NULL;
    Type *baseType = e->type->toBasetype();
    if (baseType->ty == Tstruct)
    {
        TypeStruct *ts = (TypeStruct *)baseType;
        aliasThisSymbols = ts->sym->aliasThisSymbols;
    }
    else if (baseType->ty == Tclass)
    {
        TypeClass *ts = (TypeClass *)baseType;
        if (ts->sym->aliasThisSymbols)
        {
            aliasThisSymbols = ts->sym->aliasThisSymbols;
        }
    }
    else
    {
        return false;
    }

    if (!directtypes)
    {
        directtypes = new StringTable();
        directtypes->_init();
    }
    StringValue *depth_counter = directtypes->lookup(e->type->deco, strlen(e->type->deco));
    if (!depth_counter)
    {
        depth_counter = directtypes->insert(e->type->deco, strlen(e->type->deco));
        depth_counter->ptrvalue = (void*)e;
    }
    else if (depth_counter->ptrvalue)
    {
        return false; //This type has already been visited.
    }
    else
    {
        depth_counter->ptrvalue = (void*)e;
    }

    bool r = false;

    if (aliasThisSymbols)
    {
        for (size_t i = 0; i < aliasThisSymbols->dim; ++i)
        {
            unsigned olderrors = 0;
            if (gagerrors)
                olderrors = global.startGagging();
            Expression *e1 = resolveAliasThis(sc, e, i);

            if(gagerrors && global.endGagging(olderrors))
                continue;
            if (e1->type->ty == Terror)
                continue;
            assert(e1->type->deco);

            Expression *e2 = NULL;
            int success = dg(sc, e1, ctx, &e2);
            r = r || success;

            if (e2)
            {
                ret->push(e2);
            }

            if (!success)
            {
                r = iterateAliasThis(sc, e1, dg, ctx, ret, gagerrors, directtypes) || r;
            }
        }
    }

    if (e->type->ty == Tclass)
    {
        ClassDeclaration *cd = ((TypeClass *)e->type)->sym;
        assert(cd->baseclasses);
        for (size_t i = 0; i < cd->baseclasses->dim; ++i)
        {
            ClassDeclaration *bd = (*cd->baseclasses)[i]->base;
            Type *bt = bd->type;
            Expression *e1 = e->castTo(sc, bt);
            r = iterateAliasThis(sc, e1, dg, ctx, ret, gagerrors, directtypes) || r;
        }
    }

    depth_counter->ptrvalue = NULL;
    return r;
}

/**
 * Returns the type of the `idx`-th alias this symbol of the type `t`.
 * If the `islvalue` is not null, `aliasThisOf` sets `*islvalue` to true
 * if alias this symbol may be resolved to a L-value (if it variable of ref-property),
 * otherwise it sets `*islvalue` to false.
 */

Type *aliasThisOf(Type *t, size_t idx, bool *islvalue = NULL)
{
    bool dummy;
    if (!islvalue)
        islvalue = &dummy;
    *islvalue = false;
    AggregateDeclaration *ad = isAggregate(t);
    if (ad && ad->aliasThisSymbols && ad->aliasThisSymbols->dim > idx)
    {
        Dsymbol *s = (*ad->aliasThisSymbols)[idx];
        if (s->isAliasDeclaration())
            s = s->toAlias();
        Declaration *d = s->isDeclaration();
        if (d && !d->isTupleDeclaration())
        {
            assert(d->type);
            Type *t2 = d->type;
            if (d->isVarDeclaration() && d->needThis())
            {
                t2 = t2->addMod(t->mod);
                *islvalue = true; //Variable is always l-value
            }
            else if (d->isFuncDeclaration())
            {
                FuncDeclaration *fd = resolveFuncCall(Loc(), NULL, d, NULL, t, NULL, 1);
                if (fd && fd->errors)
                    return Type::terror;
                if (fd && !fd->type->nextOf() && !fd->functionSemantic())
                    fd = NULL;
                if (fd)
                {
                    t2 = fd->type->nextOf();
                    if (!t2) // issue 14185
                        return Type::terror;
                    t2 = t2->substWildTo(t->mod == 0 ? MODmutable : t->mod);
                    if (((TypeFunction *)fd->type)->isref)
                        *islvalue = true;
                }
                else
                    return Type::terror;
            }
            return t2;
        }
        EnumDeclaration *ed = s->isEnumDeclaration();
        if (ed)
        {
            Type *t2 = ed->type;
            return t2;
        }
        TemplateDeclaration *td = s->isTemplateDeclaration();
        if (td)
        {
            assert(td->scope);
            FuncDeclaration *fd = resolveFuncCall(Loc(), NULL, td, NULL, t, NULL, 1);
            if (fd && fd->errors)
                return Type::terror;
            if (fd && fd->functionSemantic())
            {
                Type *t2 = fd->type->nextOf();
                t2 = t2->substWildTo(t->mod == 0 ? MODmutable : t->mod);
                if (((TypeFunction *)fd->type)->isref)
                    *islvalue = true;
                return t2;
            }
            else
                return Type::terror;
        }
        //printf("%s\n", s->kind());
    }
    return NULL;
}

/**
 * Walks over `from` basetype tree and search types,
 * which can be converted (without alias this subtyping) to `to`.
 * If there are many ways to convert `from` to `to`, this function
 * raises an error and prints all those ways.
 * To prevent infinity loop in types with circular subtyping,
 * pattern "check a flag, lock a flag, do work is a flag wasn't locked, return flag back" is used.
 * `root_from`, `fullSymbolName`, `state` and `matchname` are needed for internal
 * using and should be NULL if the initial call.
 * `root_from` contains the initial `from` type and it is needed for correct error
 * message creating.
 * `fullSymbolName` contains the current symbol name like `TypeA.symbolX.symbolY` and needed
 * for the error message creating.
 * `state` contains current state of the lookup: no matches, there is one match,
 * there are many matches: even if we have found two matches and we are know that
 * we will raise the error, we should find remaining matches for the correct error message.
 * `matchname` contains the full name of the found alias this symbol. It is needed,
 * if we will find anothers matches and will need to raise an error.
 **/
MATCH implicitConvToWithAliasThis(Loc loc, Type *from, Type *to, Type *root_from, OutBuffer *fullSymbolName,
                                  int *state, OutBuffer *matchname)
{
    //printf("implicitConvToWithAliasThis, %s -> %s\n", from->toChars(), to->toChars());
    if (from->aliasthislock & RECtracing)
        return MATCHnomatch;

    unsigned oldatlock = from->aliasthislock;
    from->aliasthislock |= RECtracing;
    if (!fullSymbolName)
    {
        fullSymbolName = new OutBuffer();
        fullSymbolName->writestring(from->toChars());
    }
    int st = 0; //0 - no match
                //1 - match
                //2 - many matches
    if (!state)
        state = &st;

    if (!matchname)
    {
        matchname = new OutBuffer();
    }

    if (!root_from)
    {
        root_from = from;
    }
    int a_count = 0;
    AggregateDeclaration *ad = isAggregate(from);
    if (!ad)
        return MATCHnomatch;
    AggregateDeclaration *err_ad = isAggregate(root_from);
    assert(err_ad);
    if (ad && ad->aliasThisSymbols)
        a_count = (int)ad->aliasThisSymbols->dim;

    MATCH mret = MATCHnomatch;
    for (size_t i = 0; i < a_count; i++)
    {
        bool islvalue = false;
        Type *a = aliasThisOf(from, i, &islvalue);
        if (!a)
            continue;

        unsigned tatt = a->aliasthislock;
        a->aliasthislock |= RECtracing;
        MATCH m = a->implicitConvTo(to);
        a->aliasthislock = tatt;

        if (m != MATCHnomatch)
        {
            if (*state == 0)
            {
                // the first match
                *state = 1;
                mret = m;
                matchname->printf("%s.%s", fullSymbolName->peekString(), (*ad->aliasThisSymbols)[i]->toChars());
            }
            else if (*state == 1)
            {
                // the second match
                *state = 2;
                err_ad->error(loc, "There are many candidates for cast %s to %s; Candidates:",
                              root_from->toChars(), to->toChars());
                err_ad->error(loc, " => %s", matchname->extractString());
                matchname->printf("%s.%s", fullSymbolName->peekString(), (*ad->aliasThisSymbols)[i]->toChars());
                err_ad->error(loc, " => %s", matchname->extractString());
            }
            else
            {
                matchname->printf("%s.%s", fullSymbolName->peekString(), (*ad->aliasThisSymbols)[i]->toChars());
                err_ad->error(loc, " => %s", matchname->extractString());
            }
        }
        else if (!(a->aliasthislock & RECtracing))
        {
            OutBuffer next_buff;
            next_buff.printf("%s.%s", fullSymbolName->peekString(), (*ad->aliasThisSymbols)[i]->toChars());

            MATCH m2 = implicitConvToWithAliasThis(loc, a, to, root_from, &next_buff, state, matchname);

            if (mret == MATCHnomatch)
                mret = m2;
        }
    }

    if (ClassDeclaration *cd = ad ? ad->isClassDeclaration() : NULL)
    {
        for (size_t i = 0; i < cd->baseclasses->dim; i++)
        {
            ClassDeclaration *bd = (*cd->baseclasses)[i]->base;
            Type *bt = (*cd->baseclasses)[i]->type;
            if (!bt)
                bt = bd->type;
            if (!(bt->aliasthislock & RECtracing))
            {
                OutBuffer next_buff;
                next_buff.printf("(cast(%s)%s)", bt->toChars(), fullSymbolName->peekString());

                MATCH m2 = implicitConvToWithAliasThis(loc, bt, to, root_from, &next_buff, state, matchname);

                if (mret == MATCHnomatch)
                    mret = m2;
            }
        }
    }
    from->aliasthislock = oldatlock;
    return mret;
}

/***
 * Returns (through `ret`) all subtypes of `t`, which can be implied via
 * alias this mechanism.
 * The `islvalues` contains the array of bool values: the one value for a
 * one `ret` value.
 * This value is true if appropriate type from `ret` refers to L-value symbol,
 * otherwise this value if false.
 */
void getAliasThisTypes(Type *t, Types *ret, Bools *islvalues)
{
    assert(ret);
    int a_count = 0;
    AggregateDeclaration *ad = isAggregate(t);
    if (ad && ad->aliasThisSymbols)
        a_count = (int)ad->aliasThisSymbols->dim;

    for (size_t i = 0; i < a_count; i++)
    {
        bool islvalue = false;
        Type *a = aliasThisOf(t, i, &islvalue);
        if (!a)
            continue;

        bool duplicate = false;

        for (size_t j = 0; j < ret->dim; ++j)
        {
            if ((*ret)[j]->equals(a))
            {
                duplicate = true;
                break;
            }
        }
        if (!duplicate)
        {
            ret->push(a);
            if (islvalues)
            {
                islvalues->push(islvalue);
            }
            getAliasThisTypes(a, ret);
        }
    }

    if (ClassDeclaration *cd = ad ? ad->isClassDeclaration() : NULL)
    {
        for (size_t i = 0; i < cd->baseclasses->dim; i++)
        {
            ClassDeclaration *bd = (*cd->baseclasses)[i]->base;
            Type *bt = (*cd->baseclasses)[i]->type;
            if (!bt)
                bt = bd->type;
            getAliasThisTypes(bt, ret, islvalues);
        }
    }
}


/****************************************
 * Expand alias this tuples.
 */

TupleDeclaration *isAliasThisTuple(Expression *e)
{
    if (!e->type)
        return NULL;

    Type *t = e->type->toBasetype();
    Lagain:
    if (Dsymbol *s = t->toDsymbol(NULL))
    {
        AggregateDeclaration *ad = s->isAggregateDeclaration();
        if (ad && ad->aliasThisSymbols)
        {
            s = (*ad->aliasThisSymbols)[0]; //Now it works only with single alias this
            if (s && s->isVarDeclaration())
            {
                TupleDeclaration *td = s->isVarDeclaration()->toAlias()->isTupleDeclaration();
                if (td && td->isexp)
                    return td;
            }
            if (Type *att = aliasThisOf(t, 0))
            {
                t = att;
                goto Lagain;
            }
        }
    }
    return NULL;
}

int expandAliasThisTuples(Expressions *exps, size_t starti)
{
    if (!exps || exps->dim == 0)
        return -1;

    for (size_t u = starti; u < exps->dim; u++)
    {
        Expression *exp = (*exps)[u];
        TupleDeclaration *td = isAliasThisTuple(exp);
        if (td)
        {
            exps->remove(u);
            for (size_t i = 0; i<td->objects->dim; ++i)
            {
                Expression *e = isExpression((*td->objects)[i]);
                assert(e);
                assert(e->op == TOKdsymbol);
                DsymbolExp *se = (DsymbolExp *)e;
                Declaration *d = se->s->isDeclaration();
                assert(d);
                e = new DotVarExp(exp->loc, exp, d);
                assert(d->type);
                e->type = d->type;
                exps->insert(u + i, e);
            }
    #if 0
            printf("expansion ->\n");
            for (size_t i = 0; i<exps->dim; ++i)
            {
                Expression *e = (*exps)[i];
                printf("\texps[%d] e = %s %s\n", i, Token::tochars[e->op], e->toChars());
            }
    #endif
            return (int)u;
        }
    }

    return -1;
}

AliasThis::AliasThis(Loc loc, Identifier *ident)
    : Dsymbol(NULL)             // it's anonymous (no identifier)
{
    this->loc = loc;
    this->ident = ident;
}

Dsymbol *AliasThis::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    /* Since there is no semantic information stored here,
     * we don't need to copy it.
     */
    return this;
}

void AliasThis::semantic(Scope *sc)
{
    Dsymbol *p = sc->parent->pastMixin();
    AggregateDeclaration *ad = p->isAggregateDeclaration();
    if (!ad)
    {
        ::error(loc, "alias this can only be a member of aggregate, not %s %s",
            p->kind(), p->toChars());
        return;
    }

    assert(ad->members);
    Dsymbol *s = ad->search(loc, ident);
    if (!s)
    {
        s = sc->search(loc, ident, NULL);
        if (s)
            ::error(loc, "%s is not a member of %s", s->toChars(), ad->toChars());
        else
            ::error(loc, "undefined identifier %s", ident->toChars());
        return;
    }
    TupleDeclaration *td = s->isVarDeclaration() ? s->isVarDeclaration()->toAlias()->isTupleDeclaration() : NULL;

    if (ad->aliasThisSymbols && ad->aliasThisSymbols->dim > 0 && td && !(*ad->aliasThisSymbols)[0]->equals(td))
    {
        ::error(loc, "there can be only one tuple alias this", ident->toChars());
    }
    else if (ad->aliasThisSymbols && ad->aliasThisSymbols->dim > 0 && !td)
    {
        if ((*ad->aliasThisSymbols)[0]->isVarDeclaration() &&
            (*ad->aliasThisSymbols)[0]->isVarDeclaration()->toAlias()->isTupleDeclaration())
        {
            ::error(loc, "there can be only one tuple alias this", ident->toChars());
        }
    }

    if (ad->type->ty == Tstruct && ((TypeStruct *)ad->type)->sym != ad)
    {
        AggregateDeclaration *ad2 = ((TypeStruct *)ad->type)->sym;
        assert(ad2->type == Type::terror);
        ad->aliasThisSymbols = ad2->aliasThisSymbols;
        return;
    }

    /* disable the alias this conversion so the implicit conversion check
     * doesn't use it.
     */
    if (!ad->aliasThisSymbols)
        ad->aliasThisSymbols = new Dsymbols();
    Dsymbol *sx = s;
    if (sx->isAliasDeclaration())
        sx = sx->toAlias();
    Declaration *d = sx->isDeclaration();
    if (d && !d->isTupleDeclaration())
    {
        Type *t = d->type;
        assert(t);
        if (d->isFuncDeclaration())
        {
            t = t->nextOf(); //t is return value;
                             //t may be NULL, if d is a auto function
        }

        if (t)
        {
            /* disable the alias this conversion so the implicit conversion check
            * doesn't use it.
            */
            unsigned oldatlock = ad->type->aliasthislock;
            ad->type->aliasthislock |= RECtracing;
            bool match = ad->type->implicitConvTo(t) > MATCHnomatch;
            ad->type->aliasthislock = oldatlock;
            if (match)
            {
                ::error(loc, "alias this is not reachable as %s already converts to %s", ad->toChars(), t->toChars());
            }

            for (size_t i = 0; i < ad->aliasThisSymbols->dim; ++i)
            {
                Dsymbol *sx2 = (*ad->aliasThisSymbols)[i];
                if (sx2->isAliasDeclaration())
                    sx2 = sx2->toAlias();
                Declaration *d2 = sx2->isDeclaration();
                if (d2 && !d2->isTupleDeclaration())
                {
                    Type *t2 = d2->type;
                    assert(t2);
                    if (t2->equals(t))
                    {
                        ::error(loc, "alias %s this tries to override another alias this with type %s",
                                ident->toChars(), t2->toChars());
                    }
                }
            }
        }
    }

    ad->aliasThisSymbols->push(s);
}

const char *AliasThis::kind()
{
    return "alias this";
}
