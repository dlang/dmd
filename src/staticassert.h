
// Compiler implementation of the D programming language
// Copyright (c) 1999-2006 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef DMD_STATICASSERT_H
#define DMD_STATICASSERT_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

#include "dsymbol.h"

struct Expression;
struct HdrGenState;

struct StaticAssert : Dsymbol
{
    Expression *exp;
    Expression *msg;

    StaticAssert(Loc loc, Expression *exp, Expression *msg);

    Dsymbol *syntaxCopy(Dsymbol *s);
    int addMember(Scope *sc, ScopeDsymbol *sd, int memnum);
    void semantic(Scope *sc);
    void semantic2(Scope *sc);
    void inlineScan();
    int oneMember(Dsymbol **ps);
    void toObjFile(int multiobj);
    const char *kind();
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
};

#endif
