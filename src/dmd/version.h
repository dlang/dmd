
/* Compiler implementation of the D programming language
 * Copyright (C) 1999-2018 by The D Language Foundation, All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/dlang/dmd/blob/master/src/dmd/version.h
 */

#ifndef DMD_VERSION_H
#define DMD_VERSION_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

#include "dsymbol.h"

class DebugSymbol : public Dsymbol
{
public:
    unsigned level;

    Dsymbol *syntaxCopy(Dsymbol *);

    const char *toChars();
    void addMember(Scope *sc, ScopeDsymbol *sds);
    const char *kind() const;
    void accept(Visitor *v) { v->visit(this); }
};

class VersionSymbol : public Dsymbol
{
public:
    unsigned level;

    Dsymbol *syntaxCopy(Dsymbol *);

    const char *toChars();
    void addMember(Scope *sc, ScopeDsymbol *sds);
    const char *kind() const;
    void accept(Visitor *v) { v->visit(this); }
};

#endif /* DMD_VERSION_H */
