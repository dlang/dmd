
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#pragma once

#include "dsymbol.h"


struct Identifier;
struct Scope;
struct OutBuffer;
struct Module;
struct Package;

struct Import : Dsymbol
{
    Module *mod;
    Package *pkg;		// leftmost package/module
    Array *packages;		// array of Identifier's representing packages
    Identifier *id;		// module Identifier

    Import(Loc loc, Array *packages, Identifier *id);
    char *kind();
    void semantic(Scope *sc);
    void semantic2(Scope *sc);
    Dsymbol *search(Identifier *ident);
    int overloadInsert(Dsymbol *s);
    void toCBuffer(OutBuffer *buf);
};

