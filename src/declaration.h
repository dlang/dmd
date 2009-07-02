
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#pragma once

#include "dsymbol.h"

struct Expression;
struct Statement;
struct LabelDsymbol;
struct Initializer;
struct Module;
enum PROT;
enum LINK;

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
};

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
    virtual int isConstructor();
    virtual int isStaticConstructor();
    virtual int isStaticDestructor();
    virtual int isUnitTest();
    virtual int isNew();
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
};

struct TypedefDeclaration : Declaration
{
    Type *basetype;
    Initializer *init;
    int sem;			// !=0 if semantic() has been run

    TypedefDeclaration(Identifier *ident, Type *basetype, Initializer *init);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);
    char *kind();
    Type *getType();
    void toCBuffer(OutBuffer *buf);
};

struct AliasDeclaration : Declaration
{
    Dsymbol *aliassym;

    AliasDeclaration(Loc loc, Identifier *ident, Type *type);
    AliasDeclaration(Loc loc, Identifier *ident, Dsymbol *s);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);
    char *kind();
    Type *getType();
    Dsymbol *toAlias();
    void toCBuffer(OutBuffer *buf);
};

struct VarDeclaration : Declaration
{
    Initializer *init;
    unsigned offset;
    int noauto;			// no auto semantics

    VarDeclaration(Loc loc, Type *t, Identifier *id, Initializer *init);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);
    void semantic2(Scope *sc);
    char *kind();
    void toCBuffer(OutBuffer *buf);
    int needThis();
    int isImport();
    int isDataseg();
    Expression *callAutoDtor();

    Symbol *toSymbol();
    void toObjFile();			// compile to .obj file
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

    TypeInfoDeclaration(Type *tinfo);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);

    Symbol *toSymbol();
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

    DsymbolTable *symtab;
    VarDeclaration *vthis;		// 'this' parameter
    Array *parameters;			// Array of VarDeclaration's for parameters
    DsymbolTable *labtab;		// statement label symbol table
    FuncDeclaration *overnext;		// next in overload list
    Loc endloc;				// location of closing curly bracket
    int vtblIndex;			// for member functions, index into vtbl[]
    int naked;				// !=0 if naked
    ILS inlineStatus;
    int inlineNest;			// !=0 if nested inline
    int semanticRun;			// !=0 if semantic3() had been run

    // Things that should really go into Scope
    int hasReturnExp;			// if there's a return exp; statement

    FuncDeclaration(Loc loc, Loc endloc, Identifier *id, enum STC storage_class, Type *type);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);
    void semantic3(Scope *sc);
    void toHBuffer(OutBuffer *buf);
    void toCBuffer(OutBuffer *buf);
    Dsymbol *search(Identifier *ident);
    int overloadInsert(Dsymbol *s);
    FuncDeclaration *overloadResolve(Loc loc, Array *arguments);
    LabelDsymbol *searchLabel(Identifier *ident);
    AggregateDeclaration *isThis();
    void appendExp(Expression *e);
    void appendState(Statement *s);
    char *mangle();
    int isMain();
    int isWinMain();
    int isDllMain();
    int isExport();
    int isImport();
    int isAbstract();
    int isCodeseg();
    int needThis();
    virtual int isVirtual();
    virtual int addPreInvariant();
    virtual int addPostInvariant();
    void inlineScan();
    int canInline();
    Expression *doInline(Expression *ethis, Array *arguments);
    char *kind();

    static FuncDeclaration *genCfunc(Type *treturn, char *name);

    Symbol *toSymbol();
    Symbol *toThunkSymbol(int offset);	// thunk version
    void toObjFile();			// compile to .obj file
};

struct CtorDeclaration : FuncDeclaration
{   Array *arguments;
    int varargs;

    CtorDeclaration(Loc loc, Loc endloc, Array *arguments, int varargs);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);
    char *kind();
    char *toChars();
    int isConstructor();
    int isVirtual();
    int addPreInvariant();
    int addPostInvariant();
};

struct DtorDeclaration : FuncDeclaration
{
    DtorDeclaration(Loc loc, Loc endloc);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);
    int addPreInvariant();
    int addPostInvariant();
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
};


struct UnitTestDeclaration : FuncDeclaration
{
    UnitTestDeclaration(Loc loc, Loc endloc);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);
    AggregateDeclaration *isThis();
    int isUnitTest();
    int isVirtual();
    int addPreInvariant();
    int addPostInvariant();
};

struct NewDeclaration : FuncDeclaration
{   Array *arguments;
    int varargs;

    NewDeclaration(Loc loc, Loc endloc, Array *arguments, int varargs);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);
    char *kind();
    int isNew();
    int isVirtual();
    int addPreInvariant();
    int addPostInvariant();
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



