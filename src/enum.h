
// Compiler implementation of the D programming language
// Copyright (c) 1999-2013 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
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

class Identifier;
class Type;
class Expression;
struct HdrGenState;
class VarDeclaration;

class EnumDeclaration : public ScopeDsymbol
{
public:
    /* The separate, and distinct, cases are:
     *  1. enum { ... }
     *  2. enum : memtype { ... }
     *  3. enum id { ... }
     *  4. enum id : memtype { ... }
     *  5. enum id : memtype;
     *  6. enum id;
     */
    Type *type;                 // the TypeEnum
    Type *memtype;              // type of the members
    PROT protection;

private:
    Expression *maxval;
    Expression *minval;
    Expression *defaultval;     // default initializer

public:
    bool isdeprecated;
    bool added;
    int inuse;

    EnumDeclaration(Loc loc, Identifier *id, Type *memtype);
    Dsymbol *syntaxCopy(Dsymbol *s);
    int addMember(Scope *sc, ScopeDsymbol *sd, int memnum);
    void setScope(Scope *sc);
    void semantic(Scope *sc);
    bool oneMember(Dsymbol **ps, Identifier *ident);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    Type *getType();
    const char *kind();
    Dsymbol *search(Loc, Identifier *ident, int flags = IgnoreNone);
    bool isDeprecated();                // is Dsymbol deprecated?
    PROT prot();
    Expression *getMaxMinValue(Loc loc, Identifier *id);
    Expression *getDefaultValue(Loc loc);
    Type *getMemtype(Loc loc);

    void emitComment(Scope *sc);
    void toDocBuffer(OutBuffer *buf, Scope *sc);

    EnumDeclaration *isEnumDeclaration() { return this; }

    void toObjFile(int multiobj);                       // compile to .obj file
    void toDebug();
    int cvMember(unsigned char *p);

    Symbol *sinit;
    Symbol *toInitializer();
    void accept(Visitor *v) { v->visit(this); }
};


class EnumMember : public Dsymbol
{
public:
    /* Can take the following forms:
     *  1. id
     *  2. id = value
     *  3. type id = value
     */
    Expression *value;
    Type *type;

    EnumDeclaration *ed;
    VarDeclaration *vd;

    EnumMember(Loc loc, Identifier *id, Expression *value, Type *type);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    const char *kind();
    void semantic(Scope *sc);
    Expression *getVarExp(Loc loc, Scope *sc);

    void emitComment(Scope *sc);
    void toDocBuffer(OutBuffer *buf, Scope *sc);

    EnumMember *isEnumMember() { return this; }
    void accept(Visitor *v) { v->visit(this); }
};

#endif /* DMD_ENUM_H */
