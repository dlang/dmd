
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#pragma once

#include "root.h"
#include "stringtable.h"

struct Identifier;
struct Scope;
struct DsymbolTable;
struct AggregateDeclaration;
struct ClassDeclaration;
struct StructDeclaration;
struct Symbol;
struct Module;
struct Type;
struct WithStatement;
struct LabelDsymbol;
struct ScopeDsymbol;

struct TYPE;

enum PROT
{
    PROTundefined,
    PROTnone,		// no access
    PROTprivate,
    PROTprotected,
    PROTpublic,
    PROTexport,
};


struct Dsymbol : Object
{
    Identifier *ident;
    Identifier *c_ident;
    Dsymbol *parent;
    Symbol *csym;		// symbol for code generator
    Symbol *isym;		// import version of csym
    Loc loc;			// where defined

    Dsymbol();
    Dsymbol(Identifier *);
    char *toChars();
    char *locToChars();
    int equals(Object *o);
    int isAnonymous();
    void error(Loc loc, const char *format, ...);
    void error(const char *format, ...);
    Module *getModule();

    static Array *arraySyntaxCopy(Array *a);

    virtual char *kind();
    virtual Dsymbol *toAlias();			// resolve real symbol
    virtual void addMember(ScopeDsymbol *s);
    virtual void semantic(Scope *sc);
    virtual void semantic2(Scope *sc);
    virtual void semantic3(Scope *sc);
    virtual void inlineScan();
    virtual Dsymbol *search(Identifier *ident);
    virtual int overloadInsert(Dsymbol *s);
    virtual void toCBuffer(OutBuffer *buf);
    virtual unsigned size();
    virtual int isforwardRef();
    virtual void defineRef(Dsymbol *s);
    virtual AggregateDeclaration *isThis();	// is a 'this' required to access the member
    virtual ClassDeclaration *isClassMember();	// are we a member of a class?
    virtual int isExport();			// is Dsymbol exported?
    virtual int isImport();			// is Dsymbol imported?
    virtual int isDeprecated();			// is Dsymbol deprecated?
    virtual LabelDsymbol *isLabel();		// is this a LabelDsymbol()?
    virtual Type *getType();			// is this a type?
    virtual char *mangle();
    virtual int needThis();			// need a 'this' pointer?
    virtual enum PROT prot();
    virtual Dsymbol *syntaxCopy(Dsymbol *s);	// copy only syntax trees

    // Backend

    virtual Symbol *toSymbol();			// to backend symbol
    virtual void toObjFile();			// compile to .obj file

    Symbol *toImport();				// to backend import symbol
    static Symbol *toImport(Symbol *s);		// to backend import symbol

    Symbol *toSymbolX(const char *prefix, int sclass, TYPE *t);	// helper
};

// Dsymbol that generates a scope

struct ScopeDsymbol : Dsymbol
{
    Array *members;		// all Dsymbol's in this scope
    DsymbolTable *symtab;	// members[] sorted into table
    Array *imports;		// imported ScopeDsymbol's

    ScopeDsymbol();
    ScopeDsymbol(Identifier *id);
    Dsymbol *syntaxCopy(Dsymbol *s);
    Dsymbol *search(Identifier *ident);
    void importScope(ScopeDsymbol *s);
    int isforwardRef();
    void defineRef(Dsymbol *s);
    void multiplyDefined(Dsymbol *s1, Dsymbol *s2);
    Dsymbol *nameCollision(Dsymbol *s);
    char *kind();
};

// With statement scope

struct WithScopeSymbol : ScopeDsymbol
{
    WithStatement *withstate;

    WithScopeSymbol(WithStatement *withstate);
    Dsymbol *search(Identifier *ident);
};

// Table of Dsymbol's

struct DsymbolTable : Object
{
    StringTable *tab;

    DsymbolTable();
    ~DsymbolTable();

    // Look up Identifier. Return Dsymbol if found, NULL if not.
    Dsymbol *lookup(Identifier *ident);

    // Insert Dsymbol in table. Return NULL if already there.
    Dsymbol *insert(Dsymbol *s);

    // Look for Dsymbol in table. If there, return it. If not, insert s and return that.
    Dsymbol *update(Dsymbol *s);
    Dsymbol *insert(Identifier *ident, Dsymbol *s);	// when ident and s are not the same
};

