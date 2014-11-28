
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/version.h
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

    DebugSymbol(Loc loc, Identifier *ident);
    DebugSymbol(Loc loc, unsigned level);
    Dsymbol *syntaxCopy(Dsymbol *);

    char *toChars();
    int addMember(Scope *sc, ScopeDsymbol *sds, int memnum);
    void semantic(Scope *sc);
    const char *kind();
    void accept(Visitor *v) { v->visit(this); }
};

class VersionSymbol : public Dsymbol
{
public:
    unsigned level;

    VersionSymbol(Loc loc, Identifier *ident);
    VersionSymbol(Loc loc, unsigned level);
    Dsymbol *syntaxCopy(Dsymbol *);

    char *toChars();
    int addMember(Scope *sc, ScopeDsymbol *sds, int memnum);
    void semantic(Scope *sc);
    const char *kind();
    void accept(Visitor *v) { v->visit(this); }
};

#endif /* DMD_VERSION_H */
