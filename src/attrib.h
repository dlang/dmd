
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/attrib.h
 */

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

/**************************************************************/

class AttribDeclaration : public Dsymbol
{
public:
    Dsymbols *decl;     // array of Dsymbol's

    AttribDeclaration(Dsymbols *decl);
    virtual Dsymbols *include(Scope *sc, ScopeDsymbol *sds);
    int apply(Dsymbol_apply_ft_t fp, void *param);
    static Scope *createNewScope(Scope *sc,
        StorageClass newstc, LINK linkage, Prot protection, int explictProtection,
        structalign_t structalign, PINLINE inlining);
    virtual Scope *newScope(Scope *sc);
    void addMember(Scope *sc, ScopeDsymbol *sds);
    void setScope(Scope *sc);
    void importAll(Scope *sc);
    void semantic(Scope *sc);
    void semantic2(Scope *sc);
    void semantic3(Scope *sc);
    void addComment(const utf8_t *comment);
    const char *kind();
    bool oneMember(Dsymbol **ps, Identifier *ident);
    void setFieldOffset(AggregateDeclaration *ad, unsigned *poffset, bool isunion);
    bool hasPointers();
    bool hasStaticCtorOrDtor();
    void checkCtorConstInit();
    void addLocalClass(ClassDeclarations *);
    AttribDeclaration *isAttribDeclaration() { return this; }

    void accept(Visitor *v) { v->visit(this); }
};

class StorageClassDeclaration : public AttribDeclaration
{
public:
    StorageClass stc;

    StorageClassDeclaration(StorageClass stc, Dsymbols *decl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    Scope *newScope(Scope *sc);
    bool oneMember(Dsymbol **ps, Identifier *ident);

    void accept(Visitor *v) { v->visit(this); }
};

class DeprecatedDeclaration : public StorageClassDeclaration
{
public:
    Expression *msg;

    DeprecatedDeclaration(Expression *msg, Dsymbols *decl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void setScope(Scope *sc);
    void accept(Visitor *v) { v->visit(this); }
};

class LinkDeclaration : public AttribDeclaration
{
public:
    LINK linkage;

    LinkDeclaration(LINK p, Dsymbols *decl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    Scope *newScope(Scope *sc);
    char *toChars();
    void accept(Visitor *v) { v->visit(this); }
};

class ProtDeclaration : public AttribDeclaration
{
public:
    Prot protection;
    Identifiers* pkg_identifiers;

    ProtDeclaration(Loc loc, Prot p, Dsymbols *decl);
    ProtDeclaration(Loc loc, Identifiers* pkg_identifiers, Dsymbols *decl);

    Dsymbol *syntaxCopy(Dsymbol *s);
    Scope *newScope(Scope *sc);
    void addMember(Scope *sc, ScopeDsymbol *sds);
    const char *kind();
    const char *toPrettyChars(bool unused);
    void accept(Visitor *v) { v->visit(this); }
};

class AlignDeclaration : public AttribDeclaration
{
public:
    unsigned salign;

    AlignDeclaration(unsigned sa, Dsymbols *decl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    Scope *newScope(Scope *sc);
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
    Scope *newScope(Scope *sc);
    const char *kind();
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
    Dsymbols *include(Scope *sc, ScopeDsymbol *sds);
    void addComment(const utf8_t *comment);
    void setScope(Scope *sc);
    void accept(Visitor *v) { v->visit(this); }
};

class StaticIfDeclaration : public ConditionalDeclaration
{
public:
    ScopeDsymbol *scopesym;
    int addisdone;

    StaticIfDeclaration(Condition *condition, Dsymbols *decl, Dsymbols *elsedecl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    Dsymbols *include(Scope *sc, ScopeDsymbol *sds);
    void addMember(Scope *sc, ScopeDsymbol *sds);
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

    ScopeDsymbol *scopesym;
    int compiled;

    CompileDeclaration(Loc loc, Expression *exp);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void addMember(Scope *sc, ScopeDsymbol *sds);
    void setScope(Scope *sc);
    void compileIt(Scope *sc);
    void semantic(Scope *sc);
    const char *kind();
    void accept(Visitor *v) { v->visit(this); }
};

/**
 * User defined attributes look like:
 *      @(args, ...)
 */
class UserAttributeDeclaration : public AttribDeclaration
{
public:
    Expressions *atts;

    UserAttributeDeclaration(Expressions *atts, Dsymbols *decl);
    Dsymbol *syntaxCopy(Dsymbol *s);
    Scope *newScope(Scope *sc);
    void semantic(Scope *sc);
    void semantic2(Scope *sc);
    void setScope(Scope *sc);
    static Expressions *concat(Expressions *udas1, Expressions *udas2);
    Expressions *getAttributes();
    const char *kind();
    void accept(Visitor *v) { v->visit(this); }
};

#endif /* DMD_ATTRIB_H */
