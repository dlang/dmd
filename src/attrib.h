
// Compiler implementation of the D programming language
// Copyright (c) 1999-2012 by Digital Mars
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

class Expression;
class Statement;
class LabelDsymbol;
class Initializer;
class Module;
class Condition;
struct HdrGenState;

/**************************************************************/

class AttribDeclaration : public Dsymbol
{
public:
    Dsymbols *decl;     // array of Dsymbol's

    AttribDeclaration(Dsymbols *decl);
    virtual Dsymbols *include(Scope *sc, ScopeDsymbol *s);
    int apply(Dsymbol_apply_ft_t fp, void *param);
    int addMember(Scope *sc, ScopeDsymbol *s, int memnum);
    void setScopeNewSc(Scope *sc,
        StorageClass newstc, LINK linkage, PROT protection, int explictProtection,
        structalign_t structalign);
    void semanticNewSc(Scope *sc,
        StorageClass newstc, LINK linkage, PROT protection, int explictProtection,
        structalign_t structalign);
    void semantic(Scope *sc);
    void semantic2(Scope *sc);
    void semantic3(Scope *sc);
    void inlineScan();
    void addComment(const utf8_t *comment);
    void emitComment(Scope *sc);
    const char *kind();
    bool oneMember(Dsymbol **ps, Identifier *ident);
    void setFieldOffset(AggregateDeclaration *ad, unsigned *poffset, bool isunion);
    bool hasPointers();
    bool hasStaticCtorOrDtor();
    void checkCtorConstInit();
    void addLocalClass(ClassDeclarations *);
#if DMD_OBJC
    void addObjcSymbols(ClassDeclarations *classes, ClassDeclarations *categories);
#endif

    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    AttribDeclaration *isAttribDeclaration() { return this; }

    void toObjFile(int multiobj);                       // compile to .obj file
    void accept(Visitor *v) { v->visit(this); }
};

class StorageClassDeclaration : public AttribDeclaration
{
public:
    StorageClass stc;

    StorageClassDeclaration(StorageClass stc, Dsymbols *decl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void setScope(Scope *sc);
    void semantic(Scope *sc);
    bool oneMember(Dsymbol **ps, Identifier *ident);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);

    static const char *stcToChars(char tmp[], StorageClass& stc);
    static void stcToCBuffer(OutBuffer *buf, StorageClass stc);
    void accept(Visitor *v) { v->visit(this); }
};

class DeprecatedDeclaration : public StorageClassDeclaration
{
public:
    Expression *msg;

    DeprecatedDeclaration(Expression *msg, Dsymbols *decl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void setScope(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    void accept(Visitor *v) { v->visit(this); }
};

class LinkDeclaration : public AttribDeclaration
{
public:
    LINK linkage;

    LinkDeclaration(LINK p, Dsymbols *decl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void setScope(Scope *sc);
    void semantic(Scope *sc);
    void semantic3(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    char *toChars();
    void accept(Visitor *v) { v->visit(this); }
};

class ProtDeclaration : public AttribDeclaration
{
public:
    PROT protection;

    ProtDeclaration(PROT p, Dsymbols *decl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void importAll(Scope *sc);
    void setScope(Scope *sc);
    void semantic(Scope *sc);
    void emitComment(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);

    static void protectionToCBuffer(OutBuffer *buf, PROT protection);
    void accept(Visitor *v) { v->visit(this); }
};

class AlignDeclaration : public AttribDeclaration
{
public:
    unsigned salign;

    AlignDeclaration(unsigned sa, Dsymbols *decl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void setScope(Scope *sc);
    void semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    void accept(Visitor *v) { v->visit(this); }
};

class AnonDeclaration : public AttribDeclaration
{
public:
    bool isunion;
    structalign_t alignment;
    int sem;                    // 1 if successful semantic()

    AnonDeclaration(Loc loc, bool isunion, Dsymbols *decl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void semantic(Scope *sc);
    void setFieldOffset(AggregateDeclaration *ad, unsigned *poffset, bool isunion);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    const char *kind();
    void accept(Visitor *v) { v->visit(this); }
};

class PragmaDeclaration : public AttribDeclaration
{
public:
    Expressions *args;          // array of Expression's

    PragmaDeclaration(Loc loc, Identifier *ident, Expressions *args, Dsymbols *decl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void semantic(Scope *sc);
    void setScope(Scope *sc);
    bool oneMember(Dsymbol **ps, Identifier *ident);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    const char *kind();
    void toObjFile(int multiobj);                       // compile to .obj file
    void accept(Visitor *v) { v->visit(this); }
};

class ConditionalDeclaration : public AttribDeclaration
{
public:
    Condition *condition;
    Dsymbols *elsedecl; // array of Dsymbol's for else block

    ConditionalDeclaration(Condition *condition, Dsymbols *decl, Dsymbols *elsedecl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    bool oneMember(Dsymbol **ps, Identifier *ident);
    void emitComment(Scope *sc);
    Dsymbols *include(Scope *sc, ScopeDsymbol *s);
    void addComment(const utf8_t *comment);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    void importAll(Scope *sc);
    void setScope(Scope *sc);
    void accept(Visitor *v) { v->visit(this); }
};

class StaticIfDeclaration : public ConditionalDeclaration
{
public:
    ScopeDsymbol *sd;
    int addisdone;

    StaticIfDeclaration(Condition *condition, Dsymbols *decl, Dsymbols *elsedecl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    Dsymbols *include(Scope *sc, ScopeDsymbol *s);
    int addMember(Scope *sc, ScopeDsymbol *s, int memnum);
    void semantic(Scope *sc);
    void importAll(Scope *sc);
    void setScope(Scope *sc);
    const char *kind();
    void accept(Visitor *v) { v->visit(this); }
};

// Mixin declarations

class CompileDeclaration : public AttribDeclaration
{
public:
    Expression *exp;

    ScopeDsymbol *sd;
    int compiled;

    CompileDeclaration(Loc loc, Expression *exp);
    Dsymbol *syntaxCopy(Dsymbol *s);
    int addMember(Scope *sc, ScopeDsymbol *sd, int memnum);
    void compileIt(Scope *sc);
    void semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    const char *kind();
    void accept(Visitor *v) { v->visit(this); }
};

/**
 * User defined attributes look like:
 *      [ args, ... ]
 */
class UserAttributeDeclaration : public AttribDeclaration
{
public:
    Expressions *atts;

    UserAttributeDeclaration(Expressions *atts, Dsymbols *decl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void semantic(Scope *sc);
    void setScope(Scope *sc);
    static Expressions *concat(Expressions *udas1, Expressions *udas2);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    const char *kind();
    void accept(Visitor *v) { v->visit(this); }
};

#endif /* DMD_ATTRIB_H */
