
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/staticassert.h
 */

#ifndef DMD_STATICASSERT_H
#define DMD_STATICASSERT_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

#include "dsymbol.h"

class Expression;
struct HdrGenState;

class StaticAssert : public Dsymbol
{
public:
    Expression *exp;
    Expression *msg;

    StaticAssert(Loc loc, Expression *exp, Expression *msg);

    Dsymbol *syntaxCopy(Dsymbol *s);
    int addMember(Scope *sc, ScopeDsymbol *sds, int memnum);
    void semantic(Scope *sc);
    void semantic2(Scope *sc);
    bool oneMember(Dsymbol **ps, Identifier *ident);
    void toObjFile(bool multiobj);
    const char *kind();
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    void accept(Visitor *v) { v->visit(this); }
};

#endif
