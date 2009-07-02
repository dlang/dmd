
// Copyright (c) 1999-2004 by Digital Mars
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

struct Expression;
struct Statement;
struct LabelDsymbol;
struct Initializer;
struct Module;
struct InlineScanState;
struct ForeachStatement;
struct FuncDeclaration;
struct ExpInitializer;

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
};

struct Match
{
    int count;			// number of matches found
    MATCH last;			// match level of lastf
    FuncDeclaration *lastf;	// last matching function we found
    FuncDeclaration *nextf;	// current matching function
    FuncDeclaration *anyf;	// pick a func, any func, to use for error recovery
};

void overloadResolveX(Match *m, FuncDeclaration *f, Array *arguments);

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
    unsigned size();

    char *mangle();
    int isStatic() { return storage_class & STCstatic; }
    virtual int isStaticConstructor();
    virtual int isStaticDestructor();
    virtual int isDelete();
    virtual int isDataseg();
    virtual int isCodeseg();
    int isFinal() { return storage_class & STCfinal; }
    int isAbstract() { return storage_class & STCabstract; }
    int isConst() { return storage_class & STCconst; }
    int isAuto() { return storage_class & STCauto; }
    int isSynchronized() { return storage_class & STCsynchronized; }
    int isParameter() { return storage_class & STCparameter; }
    int isDeprecated() { return storage_class & STCdeprecated; }
    int isOverride() { return storage_class & STCoverride; }

    int isIn() { return storage_class & STCin; }
    int isOut() { return storage_class & STCout; }
    int isInOut() { return (storage_class & (STCin | STCout)) == (STCin | STCout); }

    enum PROT prot();

    Declaration *isDeclaration() { return this; }
};

struct TypedefDeclaration : Declaration
{
    Type *basetype;
    Initializer *init;
    int sem;			// !=0 if semantic() has been run

    TypedefDeclaration(Identifier *ident, Type *basetype, Initializer *init);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);
    void semantic2(Scope *sc);
    char *mangle();
    char *kind();
    Type *getType();
    void toCBuffer(OutBuffer *buf);

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
    void toCBuffer(OutBuffer *buf);

    AliasDeclaration *isAliasDeclaration() { return this; }
};

struct VarDeclaration : Declaration
{
    Initializer *init;
    unsigned offset;
    int noauto;			// no auto semantics
    int nestedref;		// referenced by a lexically nested function

    VarDeclaration(Loc loc, Type *t, Identifier *id, Initializer *init);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);
    void semantic2(Scope *sc);
    char *kind();
    void toCBuffer(OutBuffer *buf);
    int needThis();
    int isImportedSymbol();
    int isDataseg();
    Expression *callAutoDtor();
    ExpInitializer *getExpInitializer();

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

    SymbolDeclaration(Loc loc, Symbol *s);

    Symbol *toSymbol();
};

struct ClassInfoDeclaration : VarDeclaration
{
    ClassDeclaration *cd;

    ClassInfoDeclaration(ClassDeclaration *cd);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);

    Symbol *toSymbol();
};

struct ModuleInfoDeclaration : VarDeclaration
{
    Module *mod;

    ModuleInfoDeclaration(Module *mod);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);

    Symbol *toSymbol();
};

struct TypeInfoDeclaration : VarDeclaration
{
    Type *tinfo;

    TypeInfoDeclaration(Type *tinfo, int internal);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);

    Symbol *toSymbol();
    void toObjFile();			// compile to .obj file
    virtual void toDt(dt_t **pdt);
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
    Array *fthrows;			// Array of Type's of exceptions
    Statement *frequire;
    Identifier *outId;			// identifier for out statement
    VarDeclaration *vresult;		// variable corresponding to outId
    LabelDsymbol *returnLabel;		// where the return goes
    Statement *fensure;
    Statement *fbody;

    DsymbolTable *localsymtab;		// used to prevent symbols in different
					// scopes from having the same name
    VarDeclaration *vthis;		// 'this' parameter
    VarDeclaration *v_arguments;	// '_arguments' parameter
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
    int introducing;			// !=0 if 'introducing' function
    ForeachStatement *fes;		// if foreach body, this is the foreach

    // Things that should really go into Scope
    int hasReturnExp;			// if there's a return exp; statement

    FuncDeclaration(Loc loc, Loc endloc, Identifier *id, enum STC storage_class, Type *type);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);
    void semantic3(Scope *sc);
    void toHBuffer(OutBuffer *buf);
    void toCBuffer(OutBuffer *buf);
    int overrides(FuncDeclaration *fd);
    int overloadInsert(Dsymbol *s);
    FuncDeclaration *overloadExactMatch(Type *t);
    FuncDeclaration *overloadResolve(Loc loc, Array *arguments);
    LabelDsymbol *searchLabel(Identifier *ident);
    AggregateDeclaration *isThis();
    AggregateDeclaration *isMember2();
    int getLevel(FuncDeclaration *fd);	// lexical nesting level difference
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
    int canInline();
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
};

struct FuncLiteralDeclaration : FuncDeclaration
{
    enum TOK tok;			// TOKfunction or TOKdelegate

    FuncLiteralDeclaration(Loc loc, Loc endloc, Type *type, enum TOK tok,
	ForeachStatement *fes);
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
    char *kind();
    char *toChars();
    int isVirtual();
    int addPreInvariant();
    int addPostInvariant();

    CtorDeclaration *isCtorDeclaration() { return this; }
};

struct DtorDeclaration : FuncDeclaration
{
    DtorDeclaration(Loc loc, Loc endloc);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);
    int addPreInvariant();
    int addPostInvariant();
    int overloadInsert(Dsymbol *s);

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
};

struct InvariantDeclaration : FuncDeclaration
{
    InvariantDeclaration(Loc loc, Loc endloc);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);
    int isVirtual();
    int addPreInvariant();
    int addPostInvariant();

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

    UnitTestDeclaration *isUnitTestDeclaration() { return this; }
};

struct NewDeclaration : FuncDeclaration
{   Array *arguments;
    int varargs;

    NewDeclaration(Loc loc, Loc endloc, Array *arguments, int varargs);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);
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
    char *kind();
    int isDelete();
    int isVirtual();
    int addPreInvariant();
    int addPostInvariant();
};

#endif /* DMD_DECLARATION_H */
