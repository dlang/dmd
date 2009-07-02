
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
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

struct DebugSymbol : Dsymbol
{
    unsigned level;

    DebugSymbol(Loc loc, Identifier *ident);
    DebugSymbol(Loc loc, unsigned level);
    Dsymbol *syntaxCopy(Dsymbol *);

    void addMember(Scope *sc, ScopeDsymbol *s);
    void semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf);
    char *kind();
};

struct VersionSymbol : Dsymbol
{
    unsigned level;

    VersionSymbol(Loc loc, Identifier *ident);
    VersionSymbol(Loc loc, unsigned level);
    Dsymbol *syntaxCopy(Dsymbol *);

    void addMember(Scope *sc, ScopeDsymbol *s);
    void semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf);
    char *kind();
};

#endif /* DMD_VERSION_H */
