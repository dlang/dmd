
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#pragma once

#include "root.h"
#include "dsymbol.h"

struct Identifier;
struct Type;
struct TypeFunction;
struct Expression;
struct FuncDeclaration;
struct CtorDeclaration;
struct DtorDeclaration;
struct InvariantDeclaration;
struct NewDeclaration;
struct DeleteDeclaration;
struct InterfaceDeclaration;
struct ClassInfoDeclaration;
struct dt_t;


struct AggregateDeclaration : ScopeDsymbol
{
    Type *type;
    Type *handle;		// 'this' type
    unsigned structsize;	// size of struct
    unsigned alignsize;		// size of struct for alignment purposes
    unsigned structalign;	// struct member alignment in effect
    Array fields;		// VarDeclaration fields
    unsigned sizeok;		// set when structsize contains valid data

    // Special member functions
    InvariantDeclaration *inv;		// invariant
    NewDeclaration *aggNew;		// allocator
    DeleteDeclaration *aggDelete;	// deallocator


    AggregateDeclaration(Identifier *id);
    void semantic2(Scope *sc);
    void semantic3(Scope *sc);
    void inlineScan();
    unsigned size();
    static void alignmember(unsigned salign, unsigned size, unsigned *poffset);
    Type *getType();
    virtual int isInterface();

    // Back end
    Symbol *stag;		// tag symbol for debug data
    Symbol *sinit;
    Symbol *toInitializer();
};

struct StructDeclaration : AggregateDeclaration
{
    StructDeclaration(Identifier *id);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf);
    virtual int isUnion();
    char *mangle();
    char *kind();

    void toObjFile();			// compile to .obj file
    void toDt(dt_t **pdt);
};

struct UnionDeclaration : StructDeclaration
{
    UnionDeclaration(Identifier *id);
    Dsymbol *syntaxCopy(Dsymbol *s);
    int isUnion();
    char *kind();
};

struct BaseClass
{
    Type *type;				// (before semantic processing)
    ClassDeclaration *base;
    enum PROT protection;		// protection for the base interface
    int offset;				// 'this' pointer offset
    Array vtbl;				// for interfaces: Array of FuncDeclaration's
					// making up the vtbl[]

    BaseClass(Type *type, enum PROT protection)
    {
	this->type = type;
	this->protection = protection;
	base = NULL;
	offset = 0;
    }

    int fillVtbl(ClassDeclaration *cd, Array *vtbl, int newinstance);
};

#define CLASSINFO_SIZE 	0x3C		// value of ClassInfo.size

struct ClassDeclaration : AggregateDeclaration
{
    static ClassDeclaration *classinfo;

    ClassDeclaration *baseClass;	// NULL only if this is Object
    CtorDeclaration *ctor;
    DtorDeclaration *dtor;
    FuncDeclaration *staticCtor;
    FuncDeclaration *staticDtor;
    Array vtbl;				// Array of FuncDeclaration's making up the vtbl[]

    Array baseclasses;			// Array of BaseClass's; first is super,
					// rest are Interface's

    int interfaces_dim;
    BaseClass **interfaces;		// interfaces[interfaces_dim] for this class
					// (does not include baseClass)

    ClassInfoDeclaration *vclassinfo;	// the ClassInfo object for this ClassDeclaration
    int com;				// !=0 if this is a COM class
    int isauto;				// !=0 if this is an auto class

    ClassDeclaration(Identifier *id, Array *baseclasses);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf);
    virtual int isBaseOf(ClassDeclaration *cd, int *poffset);
    Dsymbol *search(Identifier *ident);
    FuncDeclaration *findFunc(Identifier *ident, TypeFunction *tf);
    void interfaceSemantic(Scope *sc);
    int isCOMclass();
    char *kind();
    char *mangle();

    PROT getAccess(Dsymbol *smember);	// determine access to smember
    int hasPrivateAccess(Dsymbol *smember);	// does smember have private access to members of this class?
    void accessCheck(Loc loc, Scope *sc, Dsymbol *smember);
    int isFriendOf(ClassDeclaration *cd);

    // Back end
    void toObjFile();			// compile to .obj file
    unsigned baseVtblOffset(BaseClass *bc);
    Symbol *toSymbol();
    Symbol *toVtblSymbol();
    void toDt(dt_t **pdt);
    void toDt2(dt_t **pdt, ClassDeclaration *cd);

    Symbol *vtblsym;
};

struct InterfaceDeclaration : ClassDeclaration
{
    InterfaceDeclaration(Identifier *id, Array *baseclasses);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void semantic(Scope *sc);
    int isBaseOf(ClassDeclaration *cd, int *poffset);
    int isInterface();
    char *kind();

    void toObjFile();			// compile to .obj file
    Symbol *toSymbol();
};
