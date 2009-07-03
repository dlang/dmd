
// Copyright (c) 1999-2006 by Digital Mars
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
#include "arraytypes.h"
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
struct FuncDeclaration;
struct HdrGenState;
enum MATCH;

struct TemplateDeclaration : ScopeDsymbol
{
    TemplateParameters *parameters;	// array of TemplateParameter's
    Array instances;		// array of TemplateInstance's

    TemplateDeclaration *overnext;	// next overloaded TemplateDeclaration
    Scope *scope;
    Dsymbol *onemember;		// if !=NULL then one member of this template

    TemplateDeclaration(Loc loc, Identifier *id, TemplateParameters *parameters, Array *decldefs);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);
    int overloadInsert(Dsymbol *s);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    char *kind();
    char *toChars();

    void emitComment(Scope *sc);
//    void toDocBuffer(OutBuffer *buf);

    MATCH matchWithInstance(TemplateInstance *ti, Array *atypes, int flag);
    int leastAsSpecialized(TemplateDeclaration *td2);

    MATCH deduceMatch(Array *targsi, Array *fargs, Array *dedargs);
    FuncDeclaration *deduce(Scope *sc, Loc loc, Array *targsi, Expressions *fargs);
    void declareParameter(Scope *sc, TemplateParameter *tp, Object *o);

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
    virtual void toCBuffer(OutBuffer *buf, HdrGenState *hgs) = 0;
    virtual Object *specialization() = 0;
    virtual Object *defaultArg(Scope *sc) = 0;

    /* If TemplateParameter's match as far as overloading goes.
     */
    virtual int overloadMatch(TemplateParameter *) = 0;

    /* Match actual argument against parameter.
     */
    virtual MATCH matchArg(Scope *sc, Object *oarg, int i, TemplateParameters *parameters, Array *dedtypes, Declaration **psparam) = 0;

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
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    Object *specialization();
    Object *defaultArg(Scope *sc);
    int overloadMatch(TemplateParameter *);
    MATCH matchArg(Scope *sc, Object *oarg, int i, TemplateParameters *parameters, Array *dedtypes, Declaration **psparam);
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
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    Object *specialization();
    Object *defaultArg(Scope *sc);
    int overloadMatch(TemplateParameter *);
    MATCH matchArg(Scope *sc, Object *oarg, int i, TemplateParameters *parameters, Array *dedtypes, Declaration **psparam);
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
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    Object *specialization();
    Object *defaultArg(Scope *sc);
    int overloadMatch(TemplateParameter *);
    MATCH matchArg(Scope *sc, Object *oarg, int i, TemplateParameters *parameters, Array *dedtypes, Declaration **psparam);
    void *dummyArg();
};

struct TemplateInstance : ScopeDsymbol
{
    /* Given:
     *	template abc(T:T*, S, int V)
     *	instance foo.bar.abc(int*, char, 10*10)
     */
    Array idents;		// Array of Identifiers [foo, bar, abc]
    Array *tiargs;		// Array of Types/Expressions of template
				// instance arguments [int*, char, 10*10]

    Array tdtypes;		// Array of Types/Expressions corresponding
				// to TemplateDeclaration.parameters
				// [int, char, 100]

    TemplateDeclaration *tempdecl;	// referenced by foo.bar.abc
    TemplateInstance *inst;		// refer to existing instance
    ScopeDsymbol *argsym;	// argument symbol table
    AliasDeclaration *aliasdecl;	// !=NULL if instance is an alias for its
					// sole member
    WithScopeSymbol *withsym;		// if a member of a with statement
    int semanticdone;	// has semantic() been done?
    int nest;		// for recursion detection
    int havetempdecl;	// 1 if used second constructor
#ifdef IN_GCC
    /* On some targets, it is necessary to know whether a symbol
       will be emitted in the output or not before the symbol
       is used.  This can be different from getModule(). */
    Module * objFileModule;
#endif

    TemplateInstance(Loc loc, Identifier *temp_id);
    TemplateInstance(Loc loc, TemplateDeclaration *tempdecl, Array *tiargs);
    Dsymbol *syntaxCopy(Dsymbol *);
    void addIdent(Identifier *ident);
    void semantic(Scope *sc);
    void semantic2(Scope *sc);
    void semantic3(Scope *sc);
    void inlineScan();
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    Dsymbol *toAlias();			// resolve real symbol
    char *kind();
    int oneMember(Dsymbol **ps);
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

    Scope *scope;		// for forward referencing

    TemplateMixin(Loc loc, Identifier *ident, TypeTypeof *tqual, Array *idents, Array *tiargs);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void semantic(Scope *sc);
    void semantic2(Scope *sc);
    void semantic3(Scope *sc);
    void inlineScan();
    char *kind();
    int oneMember(Dsymbol **ps);
    char *toChars();
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);

    void toObjFile();			// compile to .obj file

    TemplateMixin *isTemplateMixin() { return this; }
};

#endif /* DMD_TEMPLATE_H */
