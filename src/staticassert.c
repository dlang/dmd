
// Copyright (c) 1999-2011 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// http://www.dsource.org/projects/dmd/browser/trunk/src/staticassert.c
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
#include "hdrgen.h"
#include "scope.h"
#include "template.h"
#include "declaration.h"


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
    return 0;           // we didn't add anything
}

void StaticAssert::semantic(Scope *sc)
{
}

void StaticAssert::semantic2(Scope *sc)
{
    //printf("StaticAssert::semantic2() %s\n", toChars());
    ScopeDsymbol *sd = new ScopeDsymbol();
    sc = sc->push(sd);
    sc->flags |= SCOPEstaticassert;
    Expression *e = exp->semantic(sc);
    sc = sc->pop();
    if (e->op == TOKerror)
        return;
    e = e->optimize(WANTvalue | WANTinterpret);
    if (e->isBool(FALSE))
    {
        if (msg)
        {   HdrGenState hgs;
            OutBuffer buf;

            msg = msg->semantic(sc);
            msg = msg->optimize(WANTvalue | WANTinterpret);
            hgs.console = 1;
            msg->toCBuffer(&buf, &hgs);
            error("%s", buf.toChars());
        }
        else
            error("(%s) is false", exp->toChars());
        if (sc->tinst)
            sc->tinst->printInstantiationTrace();
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

void StaticAssert::toObjFile(int multiobj)
{
}

const char *StaticAssert::kind()
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
