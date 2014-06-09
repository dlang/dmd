
/* Compiler implementation of the D programming language
 * Copyright (c) 2009-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/aliasthis.h
 */

#ifndef DMD_ALIASTHIS_H
#define DMD_ALIASTHIS_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

#include "mars.h"
#include "dsymbol.h"

/**************************************************************/

class AliasThis : public Dsymbol
{
public:
   // alias Identifier this;
    Identifier *ident;

    AliasThis(Loc loc, Identifier *ident);

    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);
    const char *kind();
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    AliasThis *isAliasThis() { return this; }
    void accept(Visitor *v) { v->visit(this); }
};

#endif
