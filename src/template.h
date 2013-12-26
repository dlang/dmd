
// Compiler implementation of the D programming language
// Copyright (c) 1999-2013 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
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
class Identifier;
class TemplateInstance;
class TemplateParameter;
class TemplateTypeParameter;
class TemplateThisParameter;
class TemplateValueParameter;
class TemplateAliasParameter;
class TemplateTupleParameter;
class Type;
class TypeQualified;
class TypeTypeof;
struct Scope;
class Expression;
class AliasDeclaration;
class FuncDeclaration;
struct HdrGenState;
class Parameter;
enum MATCH;
enum PASS;

class Tuple : public RootObject
{
public:
    Objects objects;

    int dyncast() { return DYNCAST_TUPLE; } // kludge for template.isType()
};


class TemplateDeclaration : public ScopeDsymbol
{
public:
    TemplateParameters *parameters;     // array of TemplateParameter's

    TemplateParameters *origParameters; // originals for Ddoc
    Expression *constraint;

    // Hash table to look up TemplateInstance's of this TemplateDeclaration
    Array<TemplateInstances *> buckets;
    size_t numinstances;                // number of instances in the hash table

    TemplateDeclaration *overnext;      // next overloaded TemplateDeclaration
    TemplateDeclaration *overroot;      // first in overnext list
    FuncDeclaration *funcroot;          // first function in unified overload list

    Dsymbol *onemember;         // if !=NULL then one member of this template

    bool literal;               // this template declaration is a literal
    bool ismixin;               // template declaration is only to be used as a mixin
    bool isstatic;              // this is static template declaration
    PROT protection;

    struct Previous
    {   Previous *prev;
        Scope *sc;
        Objects *dedargs;
    };
    Previous *previous;         // threaded list of previous instantiation attempts on stack

    TemplateDeclaration(Loc loc, Identifier *id, TemplateParameters *parameters,
        Expression *constraint, Dsymbols *decldefs, bool ismixin = false, bool literal = false);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);
    bool overloadInsert(Dsymbol *s);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    bool hasStaticCtorOrDtor();
    const char *kind();
    char *toChars();

    void emitComment(Scope *sc);
    PROT prot();
//    void toDocBuffer(OutBuffer *buf);

    MATCH matchWithInstance(Scope *sc, TemplateInstance *ti, Objects *atypes, Expressions *fargs, int flag);
    MATCH leastAsSpecialized(Scope *sc, TemplateDeclaration *td2, Expressions *fargs);

    MATCH deduceFunctionTemplateMatch(FuncDeclaration *f, Loc loc, Scope *sc, Objects *tiargs, Type *tthis, Expressions *fargs, Objects *dedargs);
    RootObject *declareParameter(Scope *sc, TemplateParameter *tp, RootObject *o);
    FuncDeclaration *doHeaderInstantiation(Scope *sc, Objects *tdargs, Type *tthis, Expressions *fargs);
    TemplateInstance *findExistingInstance(TemplateInstance *tithis, Expressions *fargs);
    TemplateInstance *addInstance(TemplateInstance *ti);
    void removeInstance(TemplateInstance *handle);

    TemplateDeclaration *isTemplateDeclaration() { return this; }

    TemplateTupleParameter *isVariadic();
    bool isOverloadable();

    void makeParamNamesVisibleInConstraint(Scope *paramscope, Expressions *fargs);
    void accept(Visitor *v) { v->visit(this); }
};

class TemplateParameter
{
public:
    /* For type-parameter:
     *  template Foo(ident)             // specType is set to NULL
     *  template Foo(ident : specType)
     * For value-parameter:
     *  template Foo(valType ident)     // specValue is set to NULL
     *  template Foo(valType ident : specValue)
     * For alias-parameter:
     *  template Foo(alias ident)
     * For this-parameter:
     *  template Foo(this ident)
     */

    Loc loc;
    Identifier *ident;

    Declaration *sparam;

    TemplateParameter(Loc loc, Identifier *ident);

    virtual TemplateTypeParameter  *isTemplateTypeParameter();
    virtual TemplateValueParameter *isTemplateValueParameter();
    virtual TemplateAliasParameter *isTemplateAliasParameter();
    virtual TemplateThisParameter *isTemplateThisParameter();
    virtual TemplateTupleParameter *isTemplateTupleParameter();

    virtual TemplateParameter *syntaxCopy() = 0;
    virtual void declareParameter(Scope *sc) = 0;
    virtual void semantic(Scope *sc, TemplateParameters *parameters) = 0;
    virtual void print(RootObject *oarg, RootObject *oded) = 0;
    virtual void toCBuffer(OutBuffer *buf, HdrGenState *hgs) = 0;
    virtual RootObject *specialization() = 0;
    virtual RootObject *defaultArg(Loc loc, Scope *sc) = 0;

    /* If TemplateParameter's match as far as overloading goes.
     */
    virtual int overloadMatch(TemplateParameter *) = 0;

    /* Match actual argument against parameter.
     */
    virtual MATCH matchArg(Loc loc, Scope *sc, Objects *tiargs, size_t i, TemplateParameters *parameters, Objects *dedtypes, Declaration **psparam);
    virtual MATCH matchArg(Scope *sc, RootObject *oarg, size_t i, TemplateParameters *parameters, Objects *dedtypes, Declaration **psparam) = 0;

    /* Create dummy argument based on parameter.
     */
    virtual void *dummyArg() = 0;
};

class TemplateTypeParameter : public TemplateParameter
{
public:
    /* Syntax:
     *  ident : specType = defaultType
     */
    Type *specType;     // type parameter: if !=NULL, this is the type specialization
    Type *defaultType;

    static Type *tdummy;

    TemplateTypeParameter(Loc loc, Identifier *ident, Type *specType, Type *defaultType);

    TemplateTypeParameter *isTemplateTypeParameter();
    TemplateParameter *syntaxCopy();
    void declareParameter(Scope *sc);
    void semantic(Scope *sc, TemplateParameters *parameters);
    void print(RootObject *oarg, RootObject *oded);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    RootObject *specialization();
    RootObject *defaultArg(Loc loc, Scope *sc);
    int overloadMatch(TemplateParameter *);
    MATCH matchArg(Scope *sc, RootObject *oarg, size_t i, TemplateParameters *parameters, Objects *dedtypes, Declaration **psparam);
    void *dummyArg();
};

class TemplateThisParameter : public TemplateTypeParameter
{
public:
    /* Syntax:
     *  this ident : specType = defaultType
     */

    TemplateThisParameter(Loc loc, Identifier *ident, Type *specType, Type *defaultType);

    TemplateThisParameter *isTemplateThisParameter();
    TemplateParameter *syntaxCopy();
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
};

class TemplateValueParameter : public TemplateParameter
{
public:
    /* Syntax:
     *  valType ident : specValue = defaultValue
     */

    Type *valType;
    Expression *specValue;
    Expression *defaultValue;

    static AA *edummies;

    TemplateValueParameter(Loc loc, Identifier *ident, Type *valType, Expression *specValue, Expression *defaultValue);

    TemplateValueParameter *isTemplateValueParameter();
    TemplateParameter *syntaxCopy();
    void declareParameter(Scope *sc);
    void semantic(Scope *sc, TemplateParameters *parameters);
    void print(RootObject *oarg, RootObject *oded);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    RootObject *specialization();
    RootObject *defaultArg(Loc loc, Scope *sc);
    int overloadMatch(TemplateParameter *);
    MATCH matchArg(Scope *sc, RootObject *oarg, size_t i, TemplateParameters *parameters, Objects *dedtypes, Declaration **psparam);
    void *dummyArg();
};

class TemplateAliasParameter : public TemplateParameter
{
public:
    /* Syntax:
     *  specType ident : specAlias = defaultAlias
     */

    Type *specType;
    RootObject *specAlias;
    RootObject *defaultAlias;

    static Dsymbol *sdummy;

    TemplateAliasParameter(Loc loc, Identifier *ident, Type *specType, RootObject *specAlias, RootObject *defaultAlias);

    TemplateAliasParameter *isTemplateAliasParameter();
    TemplateParameter *syntaxCopy();
    void declareParameter(Scope *sc);
    void semantic(Scope *sc, TemplateParameters *parameters);
    void print(RootObject *oarg, RootObject *oded);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    RootObject *specialization();
    RootObject *defaultArg(Loc loc, Scope *sc);
    int overloadMatch(TemplateParameter *);
    MATCH matchArg(Scope *sc, RootObject *oarg, size_t i, TemplateParameters *parameters, Objects *dedtypes, Declaration **psparam);
    void *dummyArg();
};

class TemplateTupleParameter : public TemplateParameter
{
public:
    /* Syntax:
     *  ident ...
     */

    TemplateTupleParameter(Loc loc, Identifier *ident);

    TemplateTupleParameter *isTemplateTupleParameter();
    TemplateParameter *syntaxCopy();
    void declareParameter(Scope *sc);
    void semantic(Scope *sc, TemplateParameters *parameters);
    void print(RootObject *oarg, RootObject *oded);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    RootObject *specialization();
    RootObject *defaultArg(Loc loc, Scope *sc);
    int overloadMatch(TemplateParameter *);
    MATCH matchArg(Loc loc, Scope *sc, Objects *tiargs, size_t i, TemplateParameters *parameters, Objects *dedtypes, Declaration **psparam);
    MATCH matchArg(Scope *sc, RootObject *oarg, size_t i, TemplateParameters *parameters, Objects *dedtypes, Declaration **psparam);
    void *dummyArg();
};

class TemplateInstance : public ScopeDsymbol
{
public:
    /* Given:
     *  foo!(args) =>
     *      name = foo
     *      tiargs = args
     */
    Identifier *name;
    Objects *tiargs;            // Array of Types/Expressions of template
                                // instance arguments [int*, char, 10*10]

    Objects tdtypes;            // Array of Types/Expressions corresponding
                                // to TemplateDeclaration.parameters
                                // [int, char, 100]

    Dsymbol *tempdecl;                  // referenced by foo.bar.abc
    TemplateInstance *inst;             // refer to existing instance
    TemplateInstance *tinst;            // enclosing template instance
    ScopeDsymbol *argsym;               // argument symbol table
    AliasDeclaration *aliasdecl;        // !=NULL if instance is an alias for its
                                        // sole member
    WithScopeSymbol *withsym;           // if a member of a with statement
    int nest;                           // for recursion detection
    bool semantictiargsdone;            // has semanticTiargs() been done?
    bool havetempdecl;                  // if used second constructor
    bool speculative;                   // if only instantiated with errors gagged
    Dsymbol *enclosing;                 // if referencing local symbols, this is the context
    hash_t hash;                        // cached result of hashCode()
    Expressions *fargs;                 // for function template, these are the function arguments
    Module *instantiatingModule;        // the top module that instantiated this instance

    TemplateInstances* deferred;

    TemplateInstance(Loc loc, Identifier *temp_id);
    TemplateInstance(Loc loc, TemplateDeclaration *tempdecl, Objects *tiargs);
    static Objects *arraySyntaxCopy(Objects *objs);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc, Expressions *fargs);
    void semantic(Scope *sc);
    void semantic2(Scope *sc);
    void semantic3(Scope *sc);
    void inlineScan();
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    void toCBufferTiargs(OutBuffer *buf, HdrGenState *hgs);
    Dsymbol *toAlias();                 // resolve real symbol
    const char *kind();
    bool oneMember(Dsymbol **ps, Identifier *ident);
    char *toChars();
    const char *mangle(bool isv = false);
    void printInstantiationTrace();
    Identifier *getIdent();
    int compare(RootObject *o);
    hash_t hashCode();

    void toObjFile(int multiobj);                       // compile to .obj file

    // Internal
    bool findTemplateDeclaration(Scope *sc);
    bool updateTemplateDeclaration(Scope *sc, Dsymbol *s);
    static void semanticTiargs(Loc loc, Scope *sc, Objects *tiargs, int flags);
    bool semanticTiargs(Scope *sc);
    bool findBestMatch(Scope *sc, Expressions *fargs);
    bool needsTypeInference(Scope *sc, int flag = 0);
    bool hasNestedArgs(Objects *tiargs, bool isstatic);
    void declareParameters(Scope *sc);
    Identifier *genIdent(Objects *args);
    void expandMembers(Scope *sc);
    void tryExpandMembers(Scope *sc);
    void trySemantic3(Scope *sc2);

    TemplateInstance *isTemplateInstance() { return this; }
    AliasDeclaration *isAliasDeclaration();
    void accept(Visitor *v) { v->visit(this); }
};

class TemplateMixin : public TemplateInstance
{
public:
    TypeQualified *tqual;

    TemplateMixin(Loc loc, Identifier *ident, TypeQualified *tqual, Objects *tiargs);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void semantic(Scope *sc);
    void semantic2(Scope *sc);
    void semantic3(Scope *sc);
    void inlineScan();
    const char *kind();
    bool oneMember(Dsymbol **ps, Identifier *ident);
    int apply(Dsymbol_apply_ft_t fp, void *param);
    bool hasPointers();
    void setFieldOffset(AggregateDeclaration *ad, unsigned *poffset, bool isunion);
    char *toChars();
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);

    void toObjFile(int multiobj);                       // compile to .obj file

    bool findTemplateDeclaration(Scope *sc);

    TemplateMixin *isTemplateMixin() { return this; }
    void accept(Visitor *v) { v->visit(this); }
};

Expression *isExpression(RootObject *o);
Dsymbol *isDsymbol(RootObject *o);
Type *isType(RootObject *o);
Tuple *isTuple(RootObject *o);
Parameter *isParameter(RootObject *o);
int arrayObjectIsError(Objects *args);
int isError(RootObject *o);
Type *getType(RootObject *o);
Dsymbol *getDsymbol(RootObject *o);

void ObjectToCBuffer(OutBuffer *buf, HdrGenState *hgs, RootObject *oarg);
RootObject *objectSyntaxCopy(RootObject *o);

#endif /* DMD_TEMPLATE_H */
