
// Compiler implementation of the D programming language
// Copyright (c) 1999-2008 by Digital Mars
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
    /* enum ident : memtype { ... }
     */
    Type *type;                 // the TypeEnum
    Type *memtype;              // type of the members
    PROT protection;

#if DMDV1
    dinteger_t maxval;
    dinteger_t minval;
    dinteger_t defaultval;      // default initializer
#else
    Expression *maxval;
    Expression *minval;
    Expression *defaultval;     // default initializer
#endif
    bool isdeprecated;
    int isdone;                 // 0: not done
                                // 1: semantic() successfully completed

    EnumDeclaration(Loc loc, Identifier *id, Type *memtype);
    Dsymbol *syntaxCopy(Dsymbol *s);
    int addMember(Scope *sc, ScopeDsymbol *sd, int memnum);
    void setScope(Scope *sc);
    void semantic0(Scope *sc);
    void semantic(Scope *sc);
    int oneMember(Dsymbol **ps, Identifier *ident = NULL);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    Type *getType();
    const char *kind();
#if DMDV2
    Dsymbol *search(Loc, Identifier *ident, int flags);
#endif
    bool isDeprecated();                // is Dsymbol deprecated?

    void emitComment(Scope *sc);
    void toJson(JsonOut *json);
    void toDocBuffer(OutBuffer *buf, Scope *sc);

    EnumDeclaration *isEnumDeclaration() { return this; }

    bool objFileDone;  // if toObjFile was already called
    void toObjFile(int multiobj);                       // compile to .obj file
    void toDebug();
    int cvMember(unsigned char *p);

    Symbol *sinit;
    Symbol *toInitializer();
};


class EnumMember : public Dsymbol
{
public:
    EnumDeclaration *ed;
    Expression *value;
    Type *type;
    VarDeclaration *vd;

    EnumMember(Loc loc, Identifier *id, Expression *value, Type *type);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    const char *kind();
    void semantic(Scope *sc);
    Expression *getVarExp(Loc loc, Scope *sc);

    void emitComment(Scope *sc);
    void toJson(JsonOut *json);
    void toDocBuffer(OutBuffer *buf, Scope *sc);

    EnumMember *isEnumMember() { return this; }
};

#endif /* DMD_ENUM_H */
