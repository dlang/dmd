
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#pragma once

#include "root.h"
#include "dsymbol.h"

struct Identifier;
struct Type;
struct Expression;

struct EnumDeclaration : ScopeDsymbol
{
    Type *type;			// the TypeEnum
    Type *memtype;		// type of the members
    integer_t maxval;
    integer_t minval;
    integer_t defaultval;	// default initializer

    EnumDeclaration(Identifier *id, Type *memtype);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void addMember(ScopeDsymbol *s);
    void semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf);
    Type *getType();
    char *kind();
};


struct EnumMember : Dsymbol
{
    Expression *value;

    EnumMember(Loc loc, Identifier *id, Expression *value);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void toCBuffer(OutBuffer *buf);
    char *kind();
};

