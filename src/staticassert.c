
// Copyright (c) 1999-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
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

    sc = sc->startCTFE();
    Expression *e = exp->semantic(sc);
    e = resolveProperties(sc, e);
    sc = sc->endCTFE();
    sc = sc->pop();

    // Simplify expression, to make error messages nicer if CTFE fails
    e = e->optimize(0);

    if (!e->type->checkBoolean())
    {
        if (e->type->toBasetype() != Type::terror)
            exp->error("expression %s of type %s does not have a boolean value", exp->toChars(), e->type->toChars());
        return;
    }
    unsigned olderrs = global.errors;
    e = e->ctfeInterpret();
    if (global.errors != olderrs)
    {
        errorSupplemental(loc, "while evaluating: static assert(%s)", exp->toChars());
    }
    else if (e->isBool(false))
    {
        if (msg)
        {
            HdrGenState hgs;
            OutBuffer buf;

            sc = sc->startCTFE();
            msg = msg->semantic(sc);
            msg = resolveProperties(sc, msg);
            sc = sc->endCTFE();
            msg = msg->ctfeInterpret();
            hgs.console = 1;
            StringExp * s = msg->toString();
            if (s)
            {   s->postfix = 0; // Don't display a trailing 'c'
                msg = s;
            }
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
    else if (!e->isBool(true))
    {
        error("(%s) is not evaluatable at compile time", exp->toChars());
    }
}

bool StaticAssert::oneMember(Dsymbol **ps, Identifier *ident)
{
    //printf("StaticAssert::oneMember())\n");
    *ps = NULL;
    return true;
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
        buf->writestring(", ");
        msg->toCBuffer(buf, hgs);
    }
    buf->writestring(");");
    buf->writenl();
}
