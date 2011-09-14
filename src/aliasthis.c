
// Compiler implementation of the D programming language
// Copyright (c) 2009-2009 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <assert.h>

#include "mars.h"
#include "identifier.h"
#include "aliasthis.h"
#include "scope.h"
#include "aggregate.h"
#include "dsymbol.h"

#if DMDV2


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
        if (ad->aliasthis)
            error("there can be only one alias this");
        assert(ad->members);
        Dsymbol *s = ad->search(loc, ident, 0);
        if (!s)
            ::error(loc, "undefined identifier %s", ident->toChars());
        ad->aliasthis = s;
    }
    else
        error("alias this can only appear in struct or class declaration, not %s", parent ? parent->toChars() : "nowhere");
}

const char *AliasThis::kind()
{
    return "alias this";
}

void AliasThis::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("alias ");
    buf->writestring(ident->toChars());
    buf->writestring(" this;\n");
}

#endif
