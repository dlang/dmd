
// Copyright (c) 1999-2006 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <string.h>
#include <assert.h>

#include "dsymbol.h"
#include "staticassert.h"
#include "expression.h"
#include "id.h"

/********************************* AttribDeclaration ****************************/

StaticAssert::StaticAssert(Loc loc, Expression *exp, Expression *msg)
	: Dsymbol(Id::empty)
{
    this->loc = loc;
    this->exp = exp;
    this->msg = msg;
}

Dsymbol *StaticAssert::syntaxCopy(Dsymbol *s)
{
    StaticAssert *sa;

    assert(!s);
    sa = new StaticAssert(loc, exp->syntaxCopy(), msg ? msg->syntaxCopy() : NULL);
    return sa;
}

int StaticAssert::addMember(Scope *sc, ScopeDsymbol *sd, int memnum)
{
    return 0;		// we didn't add anything
}

void StaticAssert::semantic(Scope *sc)
{
}

void StaticAssert::semantic2(Scope *sc)
{
    Expression *e;

    e = exp->semantic(sc);
    e = e->optimize(WANTvalue);
    if (e->isBool(FALSE))
    {
	if (msg)
	{
	    msg = msg->semantic(sc);
	    msg = msg->optimize(WANTvalue);
	    char *p = msg->toChars();
	    p = strdup(p);
	    error("(%s) is false, %s", exp->toChars(), p);
	    free(p);
	}
	else
	    error("(%s) is false", exp->toChars());
	if (!global.gag)
	    fatal();
    }
    else if (!e->isBool(TRUE))
    {
	error("(%s) is not evaluatable at compile time", exp->toChars());
    }
}

int StaticAssert::oneMember(Dsymbol **ps)
{
    //printf("StaticAssert::oneMember())\n");
    *ps = NULL;
    return TRUE;
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
    if (msg)
    {
	buf->writeByte(',');
	msg->toCBuffer(buf, hgs);
    }
    buf->writestring(");");
    buf->writenl();
}
