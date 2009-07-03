
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef DMD_ENUM_H
#define DMD_ENUM_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

#include "root.h"
#include "dsymbol.h"

struct Identifier;
struct Type;
struct Expression;
#ifdef _DH
struct HdrGenState;
#endif

struct EnumDeclaration : ScopeDsymbol
{
    Type *type;			// the TypeEnum
    Type *memtype;		// type of the members
    integer_t maxval;
    integer_t minval;
    integer_t defaultval;	// default initializer

    EnumDeclaration(Loc loc, Identifier *id, Type *memtype);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void semantic(Scope *sc);
    int oneMember(Dsymbol **ps);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    Type *getType();
    char *kind();

    void emitComment(Scope *sc);
    void toDocBuffer(OutBuffer *buf);

    EnumDeclaration *isEnumDeclaration() { return this; }

    void toObjFile();			// compile to .obj file
    void toDebug();
    int cvMember(unsigned char *p);
};


struct EnumMember : Dsymbol
{
    Expression *value;

    EnumMember(Loc loc, Identifier *id, Expression *value);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    char *kind();

    void emitComment(Scope *sc);
    void toDocBuffer(OutBuffer *buf);

    EnumMember *isEnumMember() { return this; }
};

#endif /* DMD_ENUM_H */
