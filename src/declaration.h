
// Copyright (c) 1999-2005 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
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
    STCforeach      = 0x2000,		// variable for foreach loop
    STCcomdat       = 0x4000,		// should go into COMDAT record
    STCvariadic     = 0x8000,		// variadic function argument
    STCctorinit     = 0x10000,		// can only be set inside constructor
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

/**************************************************************/

struct Declaration : Dsymbol
{
    Type *type;
    unsigned storage_class;
    enum PROT protection;
    enum LINK linkage;

    Declaration(Identifier *id);
    void semantic(Scope *sc);
    char *kind();
    unsigned size(Loc loc);

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
    int isAuto()         { return storage_class & STCauto; }
    int isSynchronized() { return storage_class & STCsynchronized; }
    int isParameter()    { return storage_class & STCparameter; }
    int isDeprecated()   { return storage_class & STCdeprecated; }
    int isOverride()     { return storage_class & STCoverride; }

    int isIn()    { return storage_class & STCin; }
    int isOut()   { return storage_class & STCout; }
    int isInOut() { return (storage_class & (STCin | STCout)) == (STCin | STCout); }

    enum PROT prot();

    Declaration *isDeclaration() { return this; }
};

struct TypedefDeclaration : Declaration
{
    Type *basetype;
    Initializer *init;
    int sem;			// 0: semantic() has not been run
				// 1: semantic() is in progress
				// 2: semantic() has been run
				// 3: semantic2() has been run

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

    void toObjFile();			// compile to .obj file
    void toDebug();
    int cvMember(unsigned char *p);

    TypedefDeclaration *isTypedefDeclaration() { return this; }
};

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

struct VarDeclaration : Declaration
{
    Initializer *init;
    unsigned offset;
    int noauto;			// no auto semantics
    int nestedref;		// referenced by a lexically nested function
    int inuse;
    int ctorinit;		// it has been initialized in a ctor

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
    Expression *callAutoDtor();
    ExpInitializer *getExpInitializer();
    void checkCtorConstInit();

    Symbol *toSymbol();
    void toObjFile();			// compile to .obj file
    int cvMember(unsigned char *p);

    // Eliminate need for dynamic_cast
    VarDeclaration *isVarDeclaration() { return (VarDeclaration *)this; }
};

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
    void toObjFile();			// compile to .obj file
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
    VarDeclaration *vthis;		// 'this' parameter
    VarDeclaration *v_arguments;	// '_arguments' parameter
#if IN_GCC
    VarDeclaration *v_argptr;	        // '_argptr' variable
#endif
    Array *parameters;			// Array of Argument's for parameters
    DsymbolTable *labtab;		// statement label symbol table
    Declaration *overnext;		// next in overload list
    Loc endloc;				// location of closing curly bracket
    int vtblIndex;			// for member functions, index into vtbl[]
    int naked;				// !=0 if naked
    int inlineAsm;			// !=0 if has inline assembler
    ILS inlineStatus;
    int inlineNest;			// !=0 if nested inline
    int semanticRun;			// !=0 if semantic3() had been run
    int nestedFrameRef;			// !=0 if nested variables referenced frame ptr
    ForeachStatement *fes;		// if foreach body, this is the foreach
    int introducing;			// !=0 if 'introducing' function
    Type *tintro;			// if !=NULL, then this is the type
					// of the 'introducing' function
					// this one is overriding
    int inferRetType;			// !=0 if return type is to be inferred

    // Things that should really go into Scope
    int hasReturnExp;			// 1 if there's a return exp; statement
					// 2 if there's a throw statement
					// 4 if there's an assert(0)
					// 8 if there's inline asm

    FuncDeclaration(Loc loc, Loc endloc, Identifier *id, enum STC storage_class, Type *type);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);
    void semantic3(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    void bodyToCBuffer(OutBuffer *buf, HdrGenState *hgs);
    int overrides(FuncDeclaration *fd);
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
    void inlineScan();
    int canInline(int hasthis, int hdrscan = 0);
    Expression *doInline(InlineScanState *iss, Expression *ethis, Array *arguments);
    char *kind();

    static FuncDeclaration *genCfunc(Type *treturn, char *name);

    Symbol *toSymbol();
    Symbol *toThunkSymbol(int offset);	// thunk version
    void toObjFile();			// compile to .obj file
    int cvMember(unsigned char *p);

    FuncDeclaration *isFuncDeclaration() { return this; }
};

struct FuncAliasDeclaration : FuncDeclaration
{
    FuncDeclaration *funcalias;

    FuncAliasDeclaration(FuncDeclaration *funcalias);

    FuncAliasDeclaration *isFuncAliasDeclaration() { return this; }
    char *kind();
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
{   Array *arguments;
    int varargs;

    CtorDeclaration(Loc loc, Loc endloc, Array *arguments, int varargs);
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
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
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
{   Array *arguments;
    int varargs;

    NewDeclaration(Loc loc, Loc endloc, Array *arguments, int varargs);
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
{   Array *arguments;

    DeleteDeclaration(Loc loc, Loc endloc, Array *arguments);
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
