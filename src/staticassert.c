
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/staticassert.c
 */

#include <stdio.h>
#include <string.h>
#include <assert.h>

#include "dsymbol.h"
#include "staticassert.h"
#include "expression.h"
#include "id.h"
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
    assert(!s);
    return new StaticAssert(loc, exp->syntaxCopy(), msg ? msg->syntaxCopy() : NULL);
}

int StaticAssert::addMember(Scope *sc, ScopeDsymbol *sds, int memnum)
{
    return 0;           // we didn't add anything
}

void StaticAssert::semantic(Scope *sc)
{
}

void StaticAssert::semantic2(Scope *sc)
{
    //printf("StaticAssert::semantic2() %s\n", toChars());
    ScopeDsymbol *sds = new ScopeDsymbol();
    sc = sc->push(sds);
    sc->tinst = NULL;
    sc->minst = NULL;
    sc->flags |= SCOPEcondition;

    sc = sc->startCTFE();
    Expression *e = exp->semantic(sc);
    e = resolveProperties(sc, e);
    sc = sc->endCTFE();
    sc = sc->pop();

    // Simplify expression, to make error messages nicer if CTFE fails
    e = e->optimize(WANTvalue);

    if (!e->type->isBoolean())
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
            sc = sc->startCTFE();
            msg = msg->semantic(sc);
            msg = resolveProperties(sc, msg);
            sc = sc->endCTFE();
            msg = msg->ctfeInterpret();
            if (StringExp * se = msg->toStringExp())
            {
                // same with pragma(msg)
                se = se->toUTF8(sc);
                error("\"%.*s\"", (int)se->len, (char *)se->string);
            }
            else
                error("%s", msg->toChars());
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

const char *StaticAssert::kind()
{
    return "static assert";
}
