
// Compiler implementation of the D programming language
// Copyright (c) 2009-2009 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef DMD_ALIASTHIS_H
#define DMD_ALIASTHIS_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

#include "mars.h"
#include "dsymbol.h"

/**************************************************************/

#if DMDV2

struct AliasThis : Dsymbol
{
   // alias Identifier this;
    Identifier *ident;

    AliasThis(Loc loc, Identifier *ident);

    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);
    const char *kind();
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    AliasThis *isAliasThis() { return this; }
};

#endif

#endif
