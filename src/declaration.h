
// Compiler implementation of the D programming language
// Copyright (c) 1999-2008 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef DMD_DECLARATION_H
#define DMD_DECLARATION_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

#include "dsymbol.h"
#include "lexer.h"
#include "mtype.h"

struct Expression;
struct Statement;
struct LabelDsymbol;
struct Initializer;
struct Module;
struct InlineScanState;
struct ForeachStatement;
struct FuncDeclaration;
struct ExpInitializer;
struct StructDeclaration;
struct TupleType;
struct InterState;
struct IRState;

enum PROT;
enum LINK;
enum TOK;
enum MATCH;

enum STC
{
    STCundefined    = 0,
    STCstatic	    = 1,
    STCextern	    = 2,
    STCconst	    = 4,
    STCfinal	    = 8,
    STCabstract     = 0x10,
    STCparameter    = 0x20,
    STCfield	    = 0x40,
    STCoverride	    = 0x80,
    STCauto         = 0x100,
    STCsynchronized = 0x200,
    STCdeprecated   = 0x400,
    STCin           = 0x800,		// in parameter
    STCout          = 0x1000,		// out parameter
    STClazy	    = 0x2000,		// lazy parameter
    STCforeach      = 0x4000,		// variable for foreach loop
    STCcomdat       = 0x8000,		// should go into COMDAT record
    STCvariadic     = 0x10000,		// variadic function argument
    STCctorinit     = 0x20000,		// can only be set inside constructor
    STCtemplateparameter = 0x40000,	// template parameter
    STCscope	    = 0x80000,		// template parameter
    STCinvariant    = 0x100000,
    STCref	    = 0x200000,
    STCinit	    = 0x400000,		// has explicit initializer
    STCmanifest	    = 0x800000,		// manifest constant
    STCnodtor	    = 0x1000000,	// don't run destructor
    STCnothrow	    = 0x2000000,	// never throws exceptions
    STCpure	    = 0x4000000,	// pure function
    STCtls	    = 0x8000000,	// thread local
};

struct Match
{
    int count;			// number of matches found
    MATCH last;			// match level of lastf
    FuncDeclaration *lastf;	// last matching function we found
    FuncDeclaration *nextf;	// current matching function
    FuncDeclaration *anyf;	// pick a func, any func, to use for error recovery
};

void overloadResolveX(Match *m, FuncDeclaration *f, Expressions *arguments);
int overloadApply(FuncDeclaration *fstart,
	int (*fp)(void *, FuncDeclaration *),
	void *param);

/**************************************************************/

struct Declaration : Dsymbol
{
    Type *type;
    Type *originalType;		// before semantic analysis
    unsigned storage_class;
    enum PROT protection;
    enum LINK linkage;

    Declaration(Identifier *id);
    void semantic(Scope *sc);
    char *kind();
    unsigned size(Loc loc);
    void checkModify(Loc loc, Scope *sc, Type *t);

    void emitComment(Scope *sc);
    void toDocBuffer(OutBuffer *buf);

    char *mangle();
    int isStatic() { return storage_class & STCstatic; }
    virtual int isStaticConstructor();
    virtual int isStaticDestructor();
    virtual int isDelete();
    virtual int isDataseg();
    virtual int isCodeseg();
    int isCtorinit()     { return storage_class & STCctorinit; }
    int isFinal()        { return storage_class & STCfinal; }
    int isAbstract()     { return storage_class & STCabstract; }
    int isConst()        { return storage_class & STCconst; }
    int isInvariant()    { return 0; }
    int isAuto()         { return storage_class & STCauto; }
    int isScope()        { return storage_class & (STCscope | STCauto); }
    int isSynchronized() { return storage_class & STCsynchronized; }
    int isParameter()    { return storage_class & STCparameter; }
    int isDeprecated()   { return storage_class & STCdeprecated; }
    int isOverride()     { return storage_class & STCoverride; }

    int isIn()    { return storage_class & STCin; }
    int isOut()   { return storage_class & STCout; }
    int isRef()   { return storage_class & STCref; }

    enum PROT prot();

    Declaration *isDeclaration() { return this; }
};

/**************************************************************/

struct TupleDeclaration : Declaration
{
    Objects *objects;
    int isexp;			// 1: expression tuple

    TypeTuple *tupletype;	// !=NULL if this is a type tuple

    TupleDeclaration(Loc loc, Identifier *ident, Objects *objects);
    Dsymbol *syntaxCopy(Dsymbol *);
    char *kind();
    Type *getType();
    int needThis();

    TupleDeclaration *isTupleDeclaration() { return this; }
};

/**************************************************************/

struct TypedefDeclaration : Declaration
{
    Type *basetype;
    Initializer *init;
    int sem;			// 0: semantic() has not been run
				// 1: semantic() is in progress
				// 2: semantic() has been run
				// 3: semantic2() has been run
    int inuse;			// used to detect typedef cycles

    TypedefDeclaration(Loc loc, Identifier *ident, Type *basetype, Initializer *init);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);
    void semantic2(Scope *sc);
    char *mangle();
    char *kind();
    Type *getType();
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
#ifdef _DH
    Type *htype;
    Type *hbasetype;
#endif

    void toDocBuffer(OutBuffer *buf);

    void toObjFile(int multiobj);			// compile to .obj file
    void toDebug();
    int cvMember(unsigned char *p);

    TypedefDeclaration *isTypedefDeclaration() { return this; }

    Symbol *sinit;
    Symbol *toInitializer();
};

/**************************************************************/

struct AliasDeclaration : Declaration
{
    Dsymbol *aliassym;
    Dsymbol *overnext;		// next in overload list
    int inSemantic;

    AliasDeclaration(Loc loc, Identifier *ident, Type *type);
    AliasDeclaration(Loc loc, Identifier *ident, Dsymbol *s);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);
    int overloadInsert(Dsymbol *s);
    char *kind();
    Type *getType();
    Dsymbol *toAlias();
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
#ifdef _DH
    Type *htype;
    Dsymbol *haliassym;
#endif

    void toDocBuffer(OutBuffer *buf);

    AliasDeclaration *isAliasDeclaration() { return this; }
};

/**************************************************************/

struct VarDeclaration : Declaration
{
    Initializer *init;
    unsigned offset;
    int noauto;			// no auto semantics
    int nestedref;		// referenced by a lexically nested function
    int inuse;
    int ctorinit;		// it has been initialized in a ctor
    int onstack;		// 1: it has been allocated on the stack
				// 2: on stack, run destructor anyway
    int canassign;		// it can be assigned to
    Dsymbol *aliassym;		// if redone as alias to another symbol
    Expression *value;		// when interpreting, this is the value
				// (NULL if value not determinable)

    VarDeclaration(Loc loc, Type *t, Identifier *id, Initializer *init);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);
    void semantic2(Scope *sc);
    char *kind();
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
#ifdef _DH
    Type *htype;
    Initializer *hinit;
#endif
    int needThis();
    int isImportedSymbol();
    int isDataseg();
    int hasPointers();
    Expression *callAutoDtor();
    ExpInitializer *getExpInitializer();
    void checkCtorConstInit();
    void checkNestedReference(Scope *sc, Loc loc);
    Dsymbol *toAlias();

    Symbol *toSymbol();
    void toObjFile(int multiobj);			// compile to .obj file
    int cvMember(unsigned char *p);

    // Eliminate need for dynamic_cast
    VarDeclaration *isVarDeclaration() { return (VarDeclaration *)this; }
};

/**************************************************************/

// This is a shell around a back end symbol

struct SymbolDeclaration : Declaration
{
    Symbol *sym;
    StructDeclaration *dsym;

    SymbolDeclaration(Loc loc, Symbol *s, StructDeclaration *dsym);

    Symbol *toSymbol();

    // Eliminate need for dynamic_cast
    SymbolDeclaration *isSymbolDeclaration() { return (SymbolDeclaration *)this; }
};

struct ClassInfoDeclaration : VarDeclaration
{
    ClassDeclaration *cd;

    ClassInfoDeclaration(ClassDeclaration *cd);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);

    void emitComment(Scope *sc);

    Symbol *toSymbol();
};

struct ModuleInfoDeclaration : VarDeclaration
{
    Module *mod;

    ModuleInfoDeclaration(Module *mod);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);

    void emitComment(Scope *sc);

    Symbol *toSymbol();
};

struct TypeInfoDeclaration : VarDeclaration
{
    Type *tinfo;

    TypeInfoDeclaration(Type *tinfo, int internal);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);

    void emitComment(Scope *sc);

    Symbol *toSymbol();
    void toObjFile(int multiobj);			// compile to .obj file
    virtual void toDt(dt_t **pdt);
};

struct TypeInfoStructDeclaration : TypeInfoDeclaration
{
    TypeInfoStructDeclaration(Type *tinfo);

    void toDt(dt_t **pdt);
};

struct TypeInfoClassDeclaration : TypeInfoDeclaration
{
    TypeInfoClassDeclaration(Type *tinfo);

    void toDt(dt_t **pdt);
};

struct TypeInfoInterfaceDeclaration : TypeInfoDeclaration
{
    TypeInfoInterfaceDeclaration(Type *tinfo);

    void toDt(dt_t **pdt);
};

struct TypeInfoTypedefDeclaration : TypeInfoDeclaration
{
    TypeInfoTypedefDeclaration(Type *tinfo);

    void toDt(dt_t **pdt);
};

struct TypeInfoPointerDeclaration : TypeInfoDeclaration
{
    TypeInfoPointerDeclaration(Type *tinfo);

    void toDt(dt_t **pdt);
};

struct TypeInfoArrayDeclaration : TypeInfoDeclaration
{
    TypeInfoArrayDeclaration(Type *tinfo);

    void toDt(dt_t **pdt);
};

struct TypeInfoStaticArrayDeclaration : TypeInfoDeclaration
{
    TypeInfoStaticArrayDeclaration(Type *tinfo);

    void toDt(dt_t **pdt);
};

struct TypeInfoAssociativeArrayDeclaration : TypeInfoDeclaration
{
    TypeInfoAssociativeArrayDeclaration(Type *tinfo);

    void toDt(dt_t **pdt);
};

struct TypeInfoEnumDeclaration : TypeInfoDeclaration
{
    TypeInfoEnumDeclaration(Type *tinfo);

    void toDt(dt_t **pdt);
};

struct TypeInfoFunctionDeclaration : TypeInfoDeclaration
{
    TypeInfoFunctionDeclaration(Type *tinfo);

    void toDt(dt_t **pdt);
};

struct TypeInfoDelegateDeclaration : TypeInfoDeclaration
{
    TypeInfoDelegateDeclaration(Type *tinfo);

    void toDt(dt_t **pdt);
};

struct TypeInfoTupleDeclaration : TypeInfoDeclaration
{
    TypeInfoTupleDeclaration(Type *tinfo);

    void toDt(dt_t **pdt);
};

#if V2
struct TypeInfoConstDeclaration : TypeInfoDeclaration
{
    TypeInfoConstDeclaration(Type *tinfo);

    void toDt(dt_t **pdt);
};

struct TypeInfoInvariantDeclaration : TypeInfoDeclaration
{
    TypeInfoInvariantDeclaration(Type *tinfo);

    void toDt(dt_t **pdt);
};
#endif

/**************************************************************/

struct ThisDeclaration : VarDeclaration
{
    ThisDeclaration(Type *t);
    Dsymbol *syntaxCopy(Dsymbol *);
};

enum ILS
{
    ILSuninitialized,	// not computed yet
    ILSno,		// cannot inline
    ILSyes,		// can inline
};

/**************************************************************/
#if V2

enum BUILTIN
{
    BUILTINunknown = -1,	// not known if this is a builtin
    BUILTINnot,			// this is not a builtin
    BUILTINsin,			// std.math.sin
    BUILTINcos,			// std.math.cos
    BUILTINtan,			// std.math.tan
    BUILTINsqrt,		// std.math.sqrt
    BUILTINfabs,		// std.math.fabs
};

Expression *eval_builtin(enum BUILTIN builtin, Expressions *arguments);

#endif

struct FuncDeclaration : Declaration
{
    Array *fthrows;			// Array of Type's of exceptions (not used)
    Statement *frequire;
    Statement *fensure;
    Statement *fbody;

    Identifier *outId;			// identifier for out statement
    VarDeclaration *vresult;		// variable corresponding to outId
    LabelDsymbol *returnLabel;		// where the return goes

    DsymbolTable *localsymtab;		// used to prevent symbols in different
					// scopes from having the same name
    VarDeclaration *vthis;		// 'this' parameter (member and nested)
    VarDeclaration *v_arguments;	// '_arguments' parameter
#if IN_GCC
    VarDeclaration *v_argptr;	        // '_argptr' variable
#endif
    Dsymbols *parameters;		// Array of VarDeclaration's for parameters
    DsymbolTable *labtab;		// statement label symbol table
    Declaration *overnext;		// next in overload list
    Loc endloc;				// location of closing curly bracket
    int vtblIndex;			// for member functions, index into vtbl[]
    int naked;				// !=0 if naked
    int inlineAsm;			// !=0 if has inline assembler
    ILS inlineStatus;
    int inlineNest;			// !=0 if nested inline
    int cantInterpret;			// !=0 if cannot interpret function
    int semanticRun;			// !=0 if semantic3() had been run
					// this function's frame ptr
    ForeachStatement *fes;		// if foreach body, this is the foreach
    int introducing;			// !=0 if 'introducing' function
    Type *tintro;			// if !=NULL, then this is the type
					// of the 'introducing' function
					// this one is overriding
    int inferRetType;			// !=0 if return type is to be inferred
    Scope *scope;			// !=NULL means context to use

    // Things that should really go into Scope
    int hasReturnExp;			// 1 if there's a return exp; statement
					// 2 if there's a throw statement
					// 4 if there's an assert(0)
					// 8 if there's inline asm

    // Support for NRVO (named return value optimization)
    int nrvo_can;			// !=0 means we can do it
    VarDeclaration *nrvo_var;		// variable to replace with shidden
    Symbol *shidden;			// hidden pointer passed to function

#if V2
    enum BUILTIN builtin;		// set if this is a known, builtin
					// function we can evaluate at compile
					// time

    int tookAddressOf;			// set if someone took the address of
					// this function
    Dsymbols closureVars;		// local variables in this function
					// which are referenced by nested
					// functions
#else
    int nestedFrameRef;			// !=0 if nested variables referenced
#endif

    FuncDeclaration(Loc loc, Loc endloc, Identifier *id, enum STC storage_class, Type *type);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);
    void semantic2(Scope *sc);
    void semantic3(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    void bodyToCBuffer(OutBuffer *buf, HdrGenState *hgs);
    int overrides(FuncDeclaration *fd);
    int findVtblIndex(Array *vtbl, int dim);
    int overloadInsert(Dsymbol *s);
    FuncDeclaration *overloadExactMatch(Type *t);
    FuncDeclaration *overloadResolve(Loc loc, Expressions *arguments);
    LabelDsymbol *searchLabel(Identifier *ident);
    AggregateDeclaration *isThis();
    AggregateDeclaration *isMember2();
    int getLevel(Loc loc, FuncDeclaration *fd);	// lexical nesting level difference
    void appendExp(Expression *e);
    void appendState(Statement *s);
    char *mangle();
    int isMain();
    int isWinMain();
    int isDllMain();
    int isExport();
    int isImportedSymbol();
    int isAbstract();
    int isCodeseg();
    virtual int isNested();
    int needThis();
    virtual int isVirtual();
    virtual int addPreInvariant();
    virtual int addPostInvariant();
    Expression *interpret(InterState *istate, Expressions *arguments);
    void inlineScan();
    int canInline(int hasthis, int hdrscan = 0);
    Expression *doInline(InlineScanState *iss, Expression *ethis, Array *arguments);
    char *kind();
    void toDocBuffer(OutBuffer *buf);

    static FuncDeclaration *genCfunc(Type *treturn, char *name);
    static FuncDeclaration *genCfunc(Type *treturn, Identifier *id);

    Symbol *toSymbol();
    Symbol *toThunkSymbol(int offset);	// thunk version
    void toObjFile(int multiobj);			// compile to .obj file
    int cvMember(unsigned char *p);

    FuncDeclaration *isFuncDeclaration() { return this; }
};

struct FuncAliasDeclaration : FuncDeclaration
{
    FuncDeclaration *funcalias;

    FuncAliasDeclaration(FuncDeclaration *funcalias);

    FuncAliasDeclaration *isFuncAliasDeclaration() { return this; }
    char *kind();
    Symbol *toSymbol();
};

struct FuncLiteralDeclaration : FuncDeclaration
{
    enum TOK tok;			// TOKfunction or TOKdelegate

    FuncLiteralDeclaration(Loc loc, Loc endloc, Type *type, enum TOK tok,
	ForeachStatement *fes);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    Dsymbol *syntaxCopy(Dsymbol *);
    int isNested();

    FuncLiteralDeclaration *isFuncLiteralDeclaration() { return this; }
    char *kind();
};

struct CtorDeclaration : FuncDeclaration
{   Arguments *arguments;
    int varargs;

    CtorDeclaration(Loc loc, Loc endloc, Arguments *arguments, int varargs);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    char *kind();
    char *toChars();
    int isVirtual();
    int addPreInvariant();
    int addPostInvariant();
    void toDocBuffer(OutBuffer *buf);

    CtorDeclaration *isCtorDeclaration() { return this; }
};

struct DtorDeclaration : FuncDeclaration
{
    DtorDeclaration(Loc loc, Loc endloc);
    DtorDeclaration(Loc loc, Loc endloc, Identifier *id);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    int isVirtual();
    int addPreInvariant();
    int addPostInvariant();
    int overloadInsert(Dsymbol *s);
    void emitComment(Scope *sc);

    DtorDeclaration *isDtorDeclaration() { return this; }
};

struct StaticCtorDeclaration : FuncDeclaration
{
    StaticCtorDeclaration(Loc loc, Loc endloc);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);
    AggregateDeclaration *isThis();
    int isStaticConstructor();
    int isVirtual();
    int addPreInvariant();
    int addPostInvariant();
    void emitComment(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);

    StaticCtorDeclaration *isStaticCtorDeclaration() { return this; }
};

struct StaticDtorDeclaration : FuncDeclaration
{
    StaticDtorDeclaration(Loc loc, Loc endloc);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);
    AggregateDeclaration *isThis();
    int isStaticDestructor();
    int isVirtual();
    int addPreInvariant();
    int addPostInvariant();
    void emitComment(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);

    StaticDtorDeclaration *isStaticDtorDeclaration() { return this; }
};

struct InvariantDeclaration : FuncDeclaration
{
    InvariantDeclaration(Loc loc, Loc endloc);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);
    int isVirtual();
    int addPreInvariant();
    int addPostInvariant();
    void emitComment(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);

    InvariantDeclaration *isInvariantDeclaration() { return this; }
};


struct UnitTestDeclaration : FuncDeclaration
{
    UnitTestDeclaration(Loc loc, Loc endloc);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);
    AggregateDeclaration *isThis();
    int isVirtual();
    int addPreInvariant();
    int addPostInvariant();
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);

    UnitTestDeclaration *isUnitTestDeclaration() { return this; }
};

struct NewDeclaration : FuncDeclaration
{   Arguments *arguments;
    int varargs;

    NewDeclaration(Loc loc, Loc endloc, Arguments *arguments, int varargs);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    char *kind();
    int isVirtual();
    int addPreInvariant();
    int addPostInvariant();

    NewDeclaration *isNewDeclaration() { return this; }
};


struct DeleteDeclaration : FuncDeclaration
{   Arguments *arguments;

    DeleteDeclaration(Loc loc, Loc endloc, Arguments *arguments);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    char *kind();
    int isDelete();
    int isVirtual();
    int addPreInvariant();
    int addPostInvariant();
#ifdef _DH
    DeleteDeclaration *isDeleteDeclaration() { return this; }
#endif
};

#endif /* DMD_DECLARATION_H */
