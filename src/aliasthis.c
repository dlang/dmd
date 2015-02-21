
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

Expression *resolveAliasThis(Scope *sc, Expression *e)
{
    AggregateDeclaration *ad = isAggregate(e->type);

    if (ad && ad->aliasthis)
    {
        Loc loc = e->loc;
        Type *tthis = (e->op == TOKtype ? e->type : NULL);
        e = new DotIdExp(loc, e, ad->aliasthis->ident);
        e = e->semantic(sc);
        if (tthis && ad->aliasthis->needThis())
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
    Dsymbol *parent = sc->parent;
    if (parent)
        parent = parent->pastMixin();
    AggregateDeclaration *ad = NULL;
    if (parent)
        ad = parent->isAggregateDeclaration();
    if (ad)
    {
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
        else if (ad->aliasthis && s != ad->aliasthis)
            error("there can be only one alias this");

        if (ad->type->ty == Tstruct && ((TypeStruct *)ad->type)->sym != ad)
        {
            AggregateDeclaration *ad2 = ((TypeStruct *)ad->type)->sym;
            assert(ad2->type == Type::terror);
            ad->aliasthis = ad2->aliasthis;
            return;
        }

        /* disable the alias this conversion so the implicit conversion check
         * doesn't use it.
         */
        ad->aliasthis = NULL;

        Dsymbol *sx = s;
        if (sx->isAliasDeclaration())
            sx = sx->toAlias();
        Declaration *d = sx->isDeclaration();
        if (d && !d->isTupleDeclaration())
        {
            Type *t = d->type;
            assert(t);
            if (ad->type->implicitConvTo(t) > MATCHnomatch)
            {
                ::error(loc, "alias this is not reachable as %s already converts to %s", ad->toChars(), t->toChars());
            }
        }

        ad->aliasthis = s;
    }
    else
        error("alias this can only appear in struct or class declaration, not %s", parent ? parent->toChars() : "nowhere");
}

const char *AliasThis::kind()
{
    return "alias this";
}
