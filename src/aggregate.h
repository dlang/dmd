
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef DMD_AGGREGATE_H
#define DMD_AGGREGATE_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

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


    AggregateDeclaration(Loc loc, Identifier *id);
    void semantic2(Scope *sc);
    void semantic3(Scope *sc);
    void inlineScan();
    unsigned size();
    static void alignmember(unsigned salign, unsigned size, unsigned *poffset);
    Type *getType();

    // Back end
    Symbol *stag;		// tag symbol for debug data
    Symbol *sinit;
    Symbol *toInitializer();

    AggregateDeclaration *isAggregateDeclaration() { return this; }
};

struct StructDeclaration : AggregateDeclaration
{
    int zeroInit;		// !=0 if initialize with 0 fill

    StructDeclaration(Loc loc, Identifier *id);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf);
    char *mangle();
    char *kind();

    void toObjFile();			// compile to .obj file
    void toDt(dt_t **pdt);
    void toDebug();			// to symbolic debug info

    StructDeclaration *isStructDeclaration() { return this; }
};

struct UnionDeclaration : StructDeclaration
{
    UnionDeclaration(Loc loc, Identifier *id);
    Dsymbol *syntaxCopy(Dsymbol *s);
    char *kind();

    UnionDeclaration *isUnionDeclaration() { return this; }
};

struct BaseClass
{
    Type *type;				// (before semantic processing)
    enum PROT protection;		// protection for the base interface

    ClassDeclaration *base;
    int offset;				// 'this' pointer offset
    Array vtbl;				// for interfaces: Array of FuncDeclaration's
					// making up the vtbl[]

    int baseInterfaces_dim;
    BaseClass *baseInterfaces;		// if BaseClass is an interface, these
					// are a copy of the InterfaceDeclaration::interfaces

    BaseClass();
    BaseClass(Type *type, enum PROT protection);

    int fillVtbl(ClassDeclaration *cd, Array *vtbl, int newinstance);
    void copyBaseInterfaces(Array *);
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

    Array *vtblInterfaces;		// array of base interfaces that have
					// their own vtbl[]

    ClassInfoDeclaration *vclassinfo;	// the ClassInfo object for this ClassDeclaration
    int com;				// !=0 if this is a COM class
    int isauto;				// !=0 if this is an auto class
    Scope *scope;			// !=NULL means context to use

    ClassDeclaration(Loc loc, Identifier *id, Array *baseclasses);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void semantic(Scope *sc);
    void toCBuffer(OutBuffer *buf);

    #define OFFSET_RUNTIME 0x76543210
    virtual int isBaseOf(ClassDeclaration *cd, int *poffset);

    Dsymbol *search(Identifier *ident, int flags);
    FuncDeclaration *findFunc(Identifier *ident, TypeFunction *tf);
    void interfaceSemantic(Scope *sc);
    int isCOMclass();
    int isAbstract();
    virtual int vtblOffset();
    char *kind();
    char *mangle();

    PROT getAccess(Dsymbol *smember);	// determine access to smember
    int hasPrivateAccess(Dsymbol *smember);	// does smember have private access to members of this class?
    void accessCheck(Loc loc, Scope *sc, Dsymbol *smember);
    int isFriendOf(ClassDeclaration *cd);
    int hasPackageAccess(Scope *sc);

    // Back end
    void toObjFile();			// compile to .obj file
    void toDebug();
    unsigned baseVtblOffset(BaseClass *bc);
    Symbol *toSymbol();
    Symbol *toVtblSymbol();
    void toDt(dt_t **pdt);
    void toDt2(dt_t **pdt, ClassDeclaration *cd);

    Symbol *vtblsym;

    ClassDeclaration *isClassDeclaration() { return (ClassDeclaration *)this; }
};

struct InterfaceDeclaration : ClassDeclaration
{
    InterfaceDeclaration(Loc loc, Identifier *id, Array *baseclasses);
    Dsymbol *syntaxCopy(Dsymbol *s);
    void semantic(Scope *sc);
    int isBaseOf(ClassDeclaration *cd, int *poffset);
    int isBaseOf(BaseClass *bc, int *poffset);
    char *kind();
    int vtblOffset();

    void toObjFile();			// compile to .obj file
    Symbol *toSymbol();

    InterfaceDeclaration *isInterfaceDeclaration() { return this; }
};

#endif /* DMD_AGGREGATE_H */
