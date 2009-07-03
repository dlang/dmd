
// Copyright (c) 1999-2003 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <assert.h>

#include "dsymbol.h"
#include "staticassert.h"
#include "expression.h"
#include "id.h"

/********************************* AttribDeclaration ****************************/

StaticAssert::StaticAssert(Loc loc, Expression *exp)
	: Dsymbol(Id::empty)
{
    this->loc = loc;
    this->exp = exp;
}

Dsymbol *StaticAssert::syntaxCopy(Dsymbol *s)
{
    StaticAssert *sa;

    assert(!s);
    sa = new StaticAssert(loc, exp->syntaxCopy());
    return sa;
}

void StaticAssert::addMember(Scope *sc, ScopeDsymbol *sd)
{
}

void StaticAssert::semantic(Scope *sc)
{
}

void StaticAssert::semantic2(Scope *sc)
{
    Expression *e;

    e = exp->semantic(sc);
    e = e->constFold();
    if (e->isBool(FALSE))
	error("(%s) is false", exp->toChars());
}

void StaticAssert::inlineScan()
{
}

void StaticAssert::toObjFile()
{
}

char *StaticAssert::kind()
{
    return "static assert";
}

void StaticAssert::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring(kind());
    buf->writeByte('(');
    exp->toCBuffer(buf, hgs);
    buf->writestring(");");
    buf->writenl();
}
