
/* Compiler implementation of the D programming language
 * Copyright (C) 2009-2018 by The D Language Foundation, All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/dlang/dmd/blob/master/src/dmd/aliasthis.h
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

    Dsymbol *syntaxCopy(Dsymbol *);
    const char *kind() const;
    AliasThis *isAliasThis() { return this; }
    void accept(Visitor *v) { v->visit(this); }
};

#endif
