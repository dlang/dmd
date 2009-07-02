
// Copyright (c) 1999-2004 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef DMD_TEMPLATE_H
#define DMD_TEMPLATE_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

#include "root.h"
#include "dsymbol.h"

struct OutBuffer;
struct Identifier;
struct TemplateInstance;
struct TemplateParameter;
struct TemplateTypeParameter;
struct TemplateValueParameter;
struct TemplateAliasParameter;
struct Type;
struct Scope;
struct Expression;
struct AliasDeclaration;
enum MATCH;

struct TemplateDeclaration : ScopeDsymbol
{
    Array *parameters;		// array of TemplateParameter's
    Array instances;		// array of TemplateInstance's

    TemplateDeclaration *overnext;	// next overloaded TemplateDeclaration
    Scope *scope;

    TemplateDeclaration(Loc loc, Identifier *id, Array *parameters, Array *decldefs);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);
    int overloadInsert(Dsymbol *s);
    void toCBuffer(OutBuffer *buf);
    char *kind();
    char *toChars();

    MATCH matchWithInstance(TemplateInstance *ti, Array *atypes, int flag);
    int leastAsSpecialized(TemplateDeclaration *td2);

    TemplateDeclaration *isTemplateDeclaration() { return this; }
};

struct TemplateParameter
{
    /* For type-parameter:
     *	template Foo(ident)		// specType is set to NULL
     *	template Foo(ident : specType)
     * For value-parameter:
     *	template Foo(valType ident)	// specValue is set to NULL
     *	template Foo(valType ident : specValue)
     * For alias-parameter:
     *	template Foo(alias ident)
     */

    Loc loc;
    Identifier *ident;

    TemplateParameter(Loc loc, Identifier *ident);

    virtual TemplateTypeParameter  *isTemplateTypeParameter();
    virtual TemplateValueParameter *isTemplateValueParameter();
    virtual TemplateAliasParameter *isTemplateAliasParameter();

    virtual TemplateParameter *syntaxCopy() = 0;
    virtual void semantic(Scope *) = 0;
    virtual void print(Object *oarg, Object *oded) = 0;
    virtual void toCBuffer(OutBuffer *buf) = 0;
    virtual Object *defaultArg(Scope *sc) = 0;

    /* If TemplateParameter's match as far as overloading goes.
     */
    virtual int overloadMatch(TemplateParameter *) = 0;

    /* Match actual argument against parameter.
     */
    virtual MATCH matchArg(Scope *sc, Object *oarg, int i, Array *parameters, Array *dedtypes, Declaration **psparam) = 0;

    /* Create dummy argument based on parameter.
     */
    virtual void *dummyArg() = 0;
};

struct TemplateTypeParameter : TemplateParameter
{
    /* Syntax:
     *	ident : specType = defaultType
     */
    Type *specType;	// type parameter: if !=NULL, this is the type specialization
    Type *defaultType;

    TemplateTypeParameter(Loc loc, Identifier *ident, Type *specType, Type *defaultType);

    TemplateTypeParameter *isTemplateTypeParameter();
    TemplateParameter *syntaxCopy();
    void semantic(Scope *);
    void print(Object *oarg, Object *oded);
    void toCBuffer(OutBuffer *buf);
    Object *defaultArg(Scope *sc);
    int overloadMatch(TemplateParameter *);
    MATCH matchArg(Scope *sc, Object *oarg, int i, Array *parameters, Array *dedtypes, Declaration **psparam);
    void *dummyArg();
};

struct TemplateValueParameter : TemplateParameter
{
    /* Syntax:
     *	valType ident : specValue = defaultValue
     */

    Type *valType;
    Expression *specValue;
    Expression *defaultValue;

    static Expression *edummy;

    TemplateValueParameter(Loc loc, Identifier *ident, Type *valType, Expression *specValue, Expression *defaultValue);

    TemplateValueParameter *isTemplateValueParameter();
    TemplateParameter *syntaxCopy();
    void semantic(Scope *);
    void print(Object *oarg, Object *oded);
    void toCBuffer(OutBuffer *buf);
    Object *defaultArg(Scope *sc);
    int overloadMatch(TemplateParameter *);
    MATCH matchArg(Scope *sc, Object *oarg, int i, Array *parameters, Array *dedtypes, Declaration **psparam);
    void *dummyArg();
};

struct TemplateAliasParameter : TemplateParameter
{
    /* Syntax:
     *	ident : specAlias = defaultAlias
     */

    Type *specAliasT;
    Dsymbol *specAlias;

    Type *defaultAlias;

    static Dsymbol *sdummy;

    TemplateAliasParameter(Loc loc, Identifier *ident, Type *specAliasT, Type *defaultAlias);

    TemplateAliasParameter *isTemplateAliasParameter();
    TemplateParameter *syntaxCopy();
    void semantic(Scope *);
    void print(Object *oarg, Object *oded);
    void toCBuffer(OutBuffer *buf);
    Object *defaultArg(Scope *sc);
    int overloadMatch(TemplateParameter *);
    MATCH matchArg(Scope *sc, Object *oarg, int i, Array *parameters, Array *dedtypes, Declaration **psparam);
    void *dummyArg();
};

struct TemplateInstance : ScopeDsymbol
{
    /* Given:
     *	instance foo.bar.abc(int, char, 10*10)
     */
    Array idents;		// Array of Identifiers [foo, bar, abc]
    Array *tiargs;		// Array of Types/Expressions of template instance arguments [int, char, 10*10]

    TemplateDeclaration *tempdecl;	// referenced by foo.bar.abc
    TemplateInstance *inst;		// refer to existing instance
    Array tdtypes;		// types corresponding to TemplateDeclaration.parameters
    ScopeDsymbol *argsym;	// argument symbol table
    AliasDeclaration *aliasdecl;	// !=NULL if instance is an alias for its
					// sole member
    int semanticdone;	// has semantic() been done?
    int nest;		// for recursion detection

    TemplateInstance(Loc loc, Identifier *temp_id);
    Dsymbol *syntaxCopy(Dsymbol *);
    void addIdent(Identifier *ident);
    void semantic(Scope *sc);
    void semantic2(Scope *sc);
    void semantic3(Scope *sc);
    void inlineScan();
    void toCBuffer(OutBuffer *buf);
    Dsymbol *toAlias();			// resolve real symbol
    char *kind();
    char *toChars();
    char *mangle();

    void toObjFile();			// compile to .obj file

    // Internal
    void semanticTiargs(Scope *sc);
    TemplateDeclaration *findTemplateDeclaration(Scope *sc);
    void declareParameters(Scope *sc);
    Identifier *genIdent();

    TemplateInstance *isTemplateInstance() { return this; }
    AliasDeclaration *isAliasDeclaration();
};

struct TemplateMixin : TemplateInstance
{
    Array *idents;
    TypeTypeof *tqual;

    TemplateMixin(Loc loc, Identifier *ident, TypeTypeof *tqual, Array *idents, Array *tiargs);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void semantic(Scope *sc);
    void semantic2(Scope *sc);
    void semantic3(Scope *sc);
    void inlineScan();
    char *kind();
    Dsymbol *oneMember();
    void toCBuffer(OutBuffer *buf);

    void toObjFile();			// compile to .obj file

    TemplateMixin *isTemplateMixin() { return this; }
};

#endif /* DMD_TEMPLATE_H */
