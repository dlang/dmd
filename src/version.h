
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#pragma once

#include "dsymbol.h"

struct OutBuffer;

struct DebugSymbol : Dsymbol
{
    unsigned level;

    DebugSymbol(Identifier *ident);
    DebugSymbol(unsigned level);

    void addMember(ScopeDsymbol *s);
    void semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf);
};

struct VersionSymbol : Dsymbol
{
    unsigned level;

    VersionSymbol(Identifier *ident);
    VersionSymbol(unsigned level);

    void addMember(ScopeDsymbol *s);
    void semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf);
};
