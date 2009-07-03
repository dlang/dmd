
// Compiler implementation of the D programming language
// Copyright (c) 1999-2006 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef DMD_VERSION_H
#define DMD_VERSION_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

#include "dsymbol.h"

struct OutBuffer;
struct HdrGenState;

struct DebugSymbol : Dsymbol
{
    unsigned level;

    DebugSymbol(Loc loc, Identifier *ident);
    DebugSymbol(Loc loc, unsigned level);
    Dsymbol *syntaxCopy(Dsymbol *);

    int addMember(Scope *sc, ScopeDsymbol *s, int memnum);
    void semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    const char *kind();
};

struct VersionSymbol : Dsymbol
{
    unsigned level;

    VersionSymbol(Loc loc, Identifier *ident);
    VersionSymbol(Loc loc, unsigned level);
    Dsymbol *syntaxCopy(Dsymbol *);

    int addMember(Scope *sc, ScopeDsymbol *s, int memnum);
    void semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    const char *kind();
};

#endif /* DMD_VERSION_H */
