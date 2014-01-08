
// Compiler implementation of the D programming language
// Copyright (c) 1999-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef DMD_DSYMBOL_H
#define DMD_DSYMBOL_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

#include "root.h"
#include "stringtable.h"

#include "mars.h"
#include "arraytypes.h"
#include "visitor.h"

class Identifier;
struct Scope;
class DsymbolTable;
class Declaration;
class ThisDeclaration;
class TypeInfoDeclaration;
class TupleDeclaration;
class TypedefDeclaration;
class AliasDeclaration;
class AggregateDeclaration;
class EnumDeclaration;
class ClassDeclaration;
class InterfaceDeclaration;
class StructDeclaration;
class UnionDeclaration;
class FuncDeclaration;
class FuncAliasDeclaration;
class FuncLiteralDeclaration;
class CtorDeclaration;
class PostBlitDeclaration;
class DtorDeclaration;
class StaticCtorDeclaration;
class StaticDtorDeclaration;
class SharedStaticCtorDeclaration;
class SharedStaticDtorDeclaration;
class InvariantDeclaration;
class UnitTestDeclaration;
class NewDeclaration;
class VarDeclaration;
class AttribDeclaration;
struct Symbol;
class Package;
class Module;
class Import;
class Type;
class TypeTuple;
class WithStatement;
class LabelDsymbol;
class ScopeDsymbol;
class TemplateDeclaration;
class TemplateInstance;
class TemplateMixin;
class EnumMember;
class WithScopeSymbol;
class ArrayScopeSymbol;
class SymbolDeclaration;
class Expression;
class DeleteDeclaration;
struct HdrGenState;
class OverloadSet;
struct AA;
#ifdef IN_GCC
typedef union tree_node TYPE;
#else
struct TYPE;
#endif

// Back end
struct Classsym;

enum PROT
{
    PROTundefined,
    PROTnone,           // no access
    PROTprivate,
    PROTpackage,
    PROTprotected,
    PROTpublic,
    PROTexport,
};

// this is used for printing the protection in json, traits, docs, etc.
extern const char* Pprotectionnames[];

/* State of symbol in winding its way through the passes of the compiler
 */
enum PASS
{
    PASSinit,           // initial state
    PASSsemantic,       // semantic() started
    PASSsemanticdone,   // semantic() done
    PASSsemantic2,      // semantic2() started
    PASSsemantic2done,  // semantic2() done
    PASSsemantic3,      // semantic3() started
    PASSsemantic3done,  // semantic3() done
    PASSinline,         // inline started
    PASSinlinedone,     // inline done
    PASSobj,            // toObjFile() run
};

/* Flags for symbol search
 */
enum
{
    IgnoreNone              = 0x00, // default
    IgnorePrivateMembers    = 0x01, // don't find private members
    IgnoreErrors            = 0x02, // don't give error messages
    IgnoreAmbiguous         = 0x04, // return NULL if ambiguous
};

typedef int (*Dsymbol_apply_ft_t)(Dsymbol *, void *);

class Dsymbol : public RootObject
{
public:
    Identifier *ident;
    Dsymbol *parent;
    Symbol *csym;               // symbol for code generator
    Symbol *isym;               // import version of csym
    const utf8_t *comment;     // documentation comment for this Dsymbol
    Loc loc;                    // where defined
    Scope *scope;               // !=NULL means context to use for semantic()
    bool errors;                // this symbol failed to pass semantic()
    PASS semanticRun;
    char *depmsg;               // customized deprecation message
    Expressions *userAttributes;        // user defined attributes from UserAttributeDeclaration
    UnitTestDeclaration *ddocUnittest; // !=NULL means there's a ddoc unittest associated with this symbol (only use this with ddoc)

    Dsymbol();
    Dsymbol(Identifier *);
    static Dsymbol *create(Identifier *);
    char *toChars();
    Loc& getLoc();
    char *locToChars();
    bool equals(RootObject *o);
    bool isAnonymous();
    void error(Loc loc, const char *format, ...);
    void error(const char *format, ...);
    void deprecation(Loc loc, const char *format, ...);
    void deprecation(const char *format, ...);
    void checkDeprecated(Loc loc, Scope *sc);
    Module *getModule();
    Module *getAccessModule();
    Dsymbol *pastMixin();
    Dsymbol *toParent();
    Dsymbol *toParent2();
    TemplateInstance *isInstantiated();
    TemplateInstance *isSpeculative();
    Ungag ungagSpeculative();

    int dyncast() { return DYNCAST_DSYMBOL; }   // kludge for template.isSymbol()

    static Dsymbols *arraySyntaxCopy(Dsymbols *a);

    virtual Identifier *getIdent();
    virtual const char *toPrettyChars();
    virtual const char *kind();
    virtual Dsymbol *toAlias();                 // resolve real symbol
    virtual int apply(Dsymbol_apply_ft_t fp, void *param);
    virtual int addMember(Scope *sc, ScopeDsymbol *s, int memnum);
    virtual void setScope(Scope *sc);
    virtual void importAll(Scope *sc);
    virtual void semantic(Scope *sc);
    virtual void semantic2(Scope *sc);
    virtual void semantic3(Scope *sc);
    virtual void inlineScan();
    virtual Dsymbol *search(Loc loc, Identifier *ident, int flags = IgnoreNone);
    Dsymbol *search_correct(Identifier *id);
    Dsymbol *searchX(Loc loc, Scope *sc, RootObject *id);
    virtual bool overloadInsert(Dsymbol *s);
    virtual void toHBuffer(OutBuffer *buf, HdrGenState *hgs);
    virtual void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    virtual void toDocBuffer(OutBuffer *buf, Scope *sc);
    virtual unsigned size(Loc loc);
    virtual bool isforwardRef();
    virtual void defineRef(Dsymbol *s);
    virtual AggregateDeclaration *isThis();     // is a 'this' required to access the member
    AggregateDeclaration *isAggregateMember();  // are we a member of an aggregate?
    AggregateDeclaration *isAggregateMember2(); // are we a member of an aggregate?
    ClassDeclaration *isClassMember();          // are we a member of a class?
    virtual bool isExport();                    // is Dsymbol exported?
    virtual bool isImportedSymbol();            // is Dsymbol imported?
    virtual bool isDeprecated();                // is Dsymbol deprecated?
    virtual bool isOverloadable();
    virtual bool hasOverloads();
    virtual LabelDsymbol *isLabel();            // is this a LabelDsymbol?
    virtual AggregateDeclaration *isMember();   // is this symbol a member of an AggregateDeclaration?
    virtual Type *getType();                    // is this a type?
    virtual const char *mangle(bool isv = false);
    virtual bool needThis();                    // need a 'this' pointer?
    virtual PROT prot();
    virtual Dsymbol *syntaxCopy(Dsymbol *s);    // copy only syntax trees
    virtual bool oneMember(Dsymbol **ps, Identifier *ident);
    static bool oneMembers(Dsymbols *members, Dsymbol **ps, Identifier *ident);
    virtual void setFieldOffset(AggregateDeclaration *ad, unsigned *poffset, bool isunion);
    virtual bool hasPointers();
    virtual bool hasStaticCtorOrDtor();
    virtual void addLocalClass(ClassDeclarations *) { }
#if DMD_OBJC
    virtual void addObjcSymbols(ClassDeclarations *classes, ClassDeclarations *categories) { }
#endif
    
    virtual void checkCtorConstInit() { }

    virtual void addComment(const utf8_t *comment);
    virtual void emitComment(Scope *sc);
    void emitDitto(Scope *sc);

    // Backend

    virtual Symbol *toSymbol();                 // to backend symbol
    virtual void toObjFile(int multiobj);                       // compile to .obj file
    virtual int cvMember(unsigned char *p);     // emit cv debug info for member

    Symbol *toImport();                         // to backend import symbol
    static Symbol *toImport(Symbol *s);         // to backend import symbol

    Symbol *toSymbolX(const char *prefix, int sclass, TYPE *t, const char *suffix);     // helper

    // Eliminate need for dynamic_cast
    virtual Package *isPackage() { return NULL; }
    virtual Module *isModule() { return NULL; }
    virtual EnumMember *isEnumMember() { return NULL; }
    virtual TemplateDeclaration *isTemplateDeclaration() { return NULL; }
    virtual TemplateInstance *isTemplateInstance() { return NULL; }
    virtual TemplateMixin *isTemplateMixin() { return NULL; }
    virtual Declaration *isDeclaration() { return NULL; }
    virtual ThisDeclaration *isThisDeclaration() { return NULL; }
    virtual TypeInfoDeclaration *isTypeInfoDeclaration() { return NULL; }
    virtual TupleDeclaration *isTupleDeclaration() { return NULL; }
    virtual TypedefDeclaration *isTypedefDeclaration() { return NULL; }
    virtual AliasDeclaration *isAliasDeclaration() { return NULL; }
    virtual AggregateDeclaration *isAggregateDeclaration() { return NULL; }
    virtual FuncDeclaration *isFuncDeclaration() { return NULL; }
    virtual FuncAliasDeclaration *isFuncAliasDeclaration() { return NULL; }
    virtual FuncLiteralDeclaration *isFuncLiteralDeclaration() { return NULL; }
    virtual CtorDeclaration *isCtorDeclaration() { return NULL; }
    virtual PostBlitDeclaration *isPostBlitDeclaration() { return NULL; }
    virtual DtorDeclaration *isDtorDeclaration() { return NULL; }
    virtual StaticCtorDeclaration *isStaticCtorDeclaration() { return NULL; }
    virtual StaticDtorDeclaration *isStaticDtorDeclaration() { return NULL; }
    virtual SharedStaticCtorDeclaration *isSharedStaticCtorDeclaration() { return NULL; }
    virtual SharedStaticDtorDeclaration *isSharedStaticDtorDeclaration() { return NULL; }
    virtual InvariantDeclaration *isInvariantDeclaration() { return NULL; }
    virtual UnitTestDeclaration *isUnitTestDeclaration() { return NULL; }
    virtual NewDeclaration *isNewDeclaration() { return NULL; }
    virtual VarDeclaration *isVarDeclaration() { return NULL; }
    virtual ClassDeclaration *isClassDeclaration() { return NULL; }
    virtual StructDeclaration *isStructDeclaration() { return NULL; }
    virtual UnionDeclaration *isUnionDeclaration() { return NULL; }
    virtual InterfaceDeclaration *isInterfaceDeclaration() { return NULL; }
    virtual ScopeDsymbol *isScopeDsymbol() { return NULL; }
    virtual WithScopeSymbol *isWithScopeSymbol() { return NULL; }
    virtual ArrayScopeSymbol *isArrayScopeSymbol() { return NULL; }
    virtual Import *isImport() { return NULL; }
    virtual EnumDeclaration *isEnumDeclaration() { return NULL; }
    virtual DeleteDeclaration *isDeleteDeclaration() { return NULL; }
    virtual SymbolDeclaration *isSymbolDeclaration() { return NULL; }
    virtual AttribDeclaration *isAttribDeclaration() { return NULL; }
    virtual OverloadSet *isOverloadSet() { return NULL; }
    virtual void accept(Visitor *v) { v->visit(this); }
};

// Dsymbol that generates a scope

class ScopeDsymbol : public Dsymbol
{
public:
    Dsymbols *members;          // all Dsymbol's in this scope
    DsymbolTable *symtab;       // members[] sorted into table

    Dsymbols *imports;          // imported Dsymbol's
    PROT *prots;                // array of PROT, one for each import

    ScopeDsymbol();
    ScopeDsymbol(Identifier *id);
    Dsymbol *syntaxCopy(Dsymbol *s);
    Dsymbol *search(Loc loc, Identifier *ident, int flags = IgnoreNone);
    void importScope(Dsymbol *s, PROT protection);
    bool isforwardRef();
    void defineRef(Dsymbol *s);
    static void multiplyDefined(Loc loc, Dsymbol *s1, Dsymbol *s2);
    Dsymbol *nameCollision(Dsymbol *s);
    const char *kind();
    FuncDeclaration *findGetMembers();
    virtual Dsymbol *symtabInsert(Dsymbol *s);
    bool hasStaticCtorOrDtor();

    void emitMemberComments(Scope *sc);

    static size_t dim(Dsymbols *members);
    static Dsymbol *getNth(Dsymbols *members, size_t nth, size_t *pn = NULL);

    typedef int (*ForeachDg)(void *ctx, size_t idx, Dsymbol *s);
    static int foreach(Scope *sc, Dsymbols *members, ForeachDg dg, void *ctx, size_t *pn=NULL);

    ScopeDsymbol *isScopeDsymbol() { return this; }
    void accept(Visitor *v) { v->visit(this); }
};

// With statement scope

class WithScopeSymbol : public ScopeDsymbol
{
public:
    WithStatement *withstate;

    WithScopeSymbol(WithStatement *withstate);
    Dsymbol *search(Loc loc, Identifier *ident, int flags = IgnoreNone);

    WithScopeSymbol *isWithScopeSymbol() { return this; }
    void accept(Visitor *v) { v->visit(this); }
};

// Array Index/Slice scope

class ArrayScopeSymbol : public ScopeDsymbol
{
public:
    Expression *exp;    // IndexExp or SliceExp
    TypeTuple *type;    // for tuple[length]
    TupleDeclaration *td;       // for tuples of objects
    Scope *sc;

    ArrayScopeSymbol(Scope *sc, Expression *e);
    ArrayScopeSymbol(Scope *sc, TypeTuple *t);
    ArrayScopeSymbol(Scope *sc, TupleDeclaration *td);
    Dsymbol *search(Loc loc, Identifier *ident, int flags = IgnoreNone);

    ArrayScopeSymbol *isArrayScopeSymbol() { return this; }
    void accept(Visitor *v) { v->visit(this); }
};

// Overload Sets

class OverloadSet : public Dsymbol
{
public:
    Dsymbols a;         // array of Dsymbols

    OverloadSet(Identifier *ident);
    void push(Dsymbol *s);
    OverloadSet *isOverloadSet() { return this; }
    const char *kind();
    void accept(Visitor *v) { v->visit(this); }
};

// Table of Dsymbol's

class DsymbolTable : public RootObject
{
public:
    AA *tab;

    DsymbolTable();

    // Look up Identifier. Return Dsymbol if found, NULL if not.
    Dsymbol *lookup(Identifier *ident);

    // Insert Dsymbol in table. Return NULL if already there.
    Dsymbol *insert(Dsymbol *s);

    // Look for Dsymbol in table. If there, return it. If not, insert s and return that.
    Dsymbol *update(Dsymbol *s);
    Dsymbol *insert(Identifier *ident, Dsymbol *s);     // when ident and s are not the same
};

#endif /* DMD_DSYMBOL_H */
