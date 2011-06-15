
// Compiler implementation of the D programming language
// Copyright (c) 1999-2010 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef DMD_ATTRIB_H
#define DMD_ATTRIB_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

#include "dsymbol.h"

struct Expression;
struct Statement;
struct LabelDsymbol;
struct Initializer;
struct Module;
struct Condition;
struct HdrGenState;

/**************************************************************/

struct AttribDeclaration : Dsymbol
{
    Dsymbols *decl;     // array of Dsymbol's

    AttribDeclaration(Dsymbols *decl);
    virtual Dsymbols *include(Scope *sc, ScopeDsymbol *s);
    int addMember(Scope *sc, ScopeDsymbol *s, int memnum);
    void setScopeNewSc(Scope *sc,
        StorageClass newstc, enum LINK linkage, enum PROT protection, int explictProtection,
        unsigned structalign);
    void semanticNewSc(Scope *sc,
        StorageClass newstc, enum LINK linkage, enum PROT protection, int explictProtection,
        unsigned structalign);
    void semantic(Scope *sc);
    void semantic2(Scope *sc);
    void semantic3(Scope *sc);
    void inlineScan();
    void addComment(unsigned char *comment);
    void emitComment(Scope *sc);
    const char *kind();
    int oneMember(Dsymbol **ps);
    int hasPointers();
    void checkCtorConstInit();
    void addLocalClass(ClassDeclarations *);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    void toJsonBuffer(OutBuffer *buf);
    AttribDeclaration *isAttribDeclaration() { return this; }

    void toObjFile(int multiobj);                       // compile to .obj file
    int cvMember(unsigned char *p);
};

struct StorageClassDeclaration: AttribDeclaration
{
    StorageClass stc;

    StorageClassDeclaration(StorageClass stc, Dsymbols *decl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void setScope(Scope *sc);
    void semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);

    static void stcToCBuffer(OutBuffer *buf, StorageClass stc);
};

struct LinkDeclaration : AttribDeclaration
{
    enum LINK linkage;

    LinkDeclaration(enum LINK p, Dsymbols *decl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void setScope(Scope *sc);
    void semantic(Scope *sc);
    void semantic3(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    char *toChars();
};

struct ProtDeclaration : AttribDeclaration
{
    enum PROT protection;

    ProtDeclaration(enum PROT p, Dsymbols *decl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void importAll(Scope *sc);
    void setScope(Scope *sc);
    void semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);

    static void protectionToCBuffer(OutBuffer *buf, enum PROT protection);
};

struct AlignDeclaration : AttribDeclaration
{
    unsigned salign;

    AlignDeclaration(unsigned sa, Dsymbols *decl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void setScope(Scope *sc);
    void semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
};

struct AnonDeclaration : AttribDeclaration
{
    int isunion;
    int sem;                    // 1 if successful semantic()

    AnonDeclaration(Loc loc, int isunion, Dsymbols *decl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    const char *kind();
};

struct PragmaDeclaration : AttribDeclaration
{
    Expressions *args;          // array of Expression's

    PragmaDeclaration(Loc loc, Identifier *ident, Expressions *args, Dsymbols *decl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void semantic(Scope *sc);
    void setScope(Scope *sc);
    int oneMember(Dsymbol **ps);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    const char *kind();
    void toObjFile(int multiobj);                       // compile to .obj file
};

struct ConditionalDeclaration : AttribDeclaration
{
    Condition *condition;
    Dsymbols *elsedecl; // array of Dsymbol's for else block

    ConditionalDeclaration(Condition *condition, Dsymbols *decl, Dsymbols *elsedecl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    int oneMember(Dsymbol **ps);
    void emitComment(Scope *sc);
    Dsymbols *include(Scope *sc, ScopeDsymbol *s);
    void addComment(unsigned char *comment);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    void toJsonBuffer(OutBuffer *buf);
    void importAll(Scope *sc);
    void setScope(Scope *sc);
};

struct StaticIfDeclaration : ConditionalDeclaration
{
    ScopeDsymbol *sd;
    int addisdone;

    StaticIfDeclaration(Condition *condition, Dsymbols *decl, Dsymbols *elsedecl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    int addMember(Scope *sc, ScopeDsymbol *s, int memnum);
    void semantic(Scope *sc);
    void importAll(Scope *sc);
    void setScope(Scope *sc);
    const char *kind();
};

// Mixin declarations

struct CompileDeclaration : AttribDeclaration
{
    Expression *exp;

    ScopeDsymbol *sd;
    int compiled;

    CompileDeclaration(Loc loc, Expression *exp);
    Dsymbol *syntaxCopy(Dsymbol *s);
    int addMember(Scope *sc, ScopeDsymbol *sd, int memnum);
    void compileIt(Scope *sc);
    void semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
};

#endif /* DMD_ATTRIB_H */
