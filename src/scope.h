
// Copyright (c) 1999-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef DMD_SCOPE_H
#define DMD_SCOPE_H

#ifdef __DMC__
#pragma once
#endif

struct Dsymbol;
struct ScopeDsymbol;
struct Identifier;
struct Module;
struct Statement;
struct SwitchStatement;
struct TryFinallyStatement;
struct LabelStatement;
struct ForeachStatement;
struct ClassDeclaration;
struct AggregateDeclaration;
struct AnonymousAggregateDeclaration;
struct FuncDeclaration;
struct DocComment;
struct TemplateInstance;

#if __GNUC__
// Requires a full definition for PROT and LINK
#include "dsymbol.h"    // PROT
#include "mars.h"       // LINK
#else
enum LINK;
enum PROT;
#endif

struct Scope
{
    Scope *enclosing;           // enclosing Scope

    Module *module;             // Root module
    ScopeDsymbol *scopesym;     // current symbol
    ScopeDsymbol *sd;           // if in static if, and declaring new symbols,
                                // sd gets the addMember()
    FuncDeclaration *func;      // function we are in
    Dsymbol *parent;            // parent to use
    LabelStatement *slabel;     // enclosing labelled statement
    SwitchStatement *sw;        // enclosing switch statement
    TryFinallyStatement *tf;    // enclosing try finally statement
    TemplateInstance *tinst;    // enclosing template instance
    Statement *sbreak;          // enclosing statement that supports "break"
    Statement *scontinue;       // enclosing statement that supports "continue"
    ForeachStatement *fes;      // if nested function for ForeachStatement, this is it
    unsigned offset;            // next offset to use in aggregate
                                // This really shouldn't be a part of Scope, because it requires
                                // semantic() to be done in the lexical field order. It should be
                                // set in a pass after semantic() on all fields so they can be
                                // semantic'd in any order.
    int inunion;                // we're processing members of a union
    int incontract;             // we're inside contract code
    int nofree;                 // set if shouldn't free it
    int noctor;                 // set if constructor calls aren't allowed
    int intypeof;               // in typeof(exp)
    int parameterSpecialization; // if in template parameter specialization
    int noaccesscheck;          // don't do access checks
    int mustsemantic;           // cannot defer semantic()

    unsigned callSuper;         // primitive flow analysis for constructors
#define CSXthis_ctor    1       // called this()
#define CSXsuper_ctor   2       // called super()
#define CSXthis         4       // referenced this
#define CSXsuper        8       // referenced super
#define CSXlabel        0x10    // seen a label
#define CSXreturn       0x20    // seen a return statement
#define CSXany_ctor     0x40    // either this() or super() was called

    structalign_t structalign;       // alignment for struct members
    enum LINK linkage;          // linkage for external functions

    enum PROT protection;       // protection for class members
    int explicitProtection;     // set if in an explicit protection attribute

    StorageClass stc;           // storage class
    char *depmsg;               // customized deprecation message

    unsigned flags;
#define SCOPEctor       1       // constructor type
#define SCOPEstaticif   2       // inside static if
#define SCOPEfree       4       // is on free list


    DocComment *lastdc;         // documentation comment for last symbol at this scope
    unsigned lastoffset;        // offset in docbuf of where to insert next dec
    OutBuffer *docbuf;          // buffer for documentation output

    static Scope *freelist;
    static void *operator new(size_t sz);
    static Scope *createGlobal(Module *module);

    Scope();
    Scope(Module *module);
    Scope(Scope *enclosing);

    Scope *push();
    Scope *push(ScopeDsymbol *ss);
    Scope *pop();

    void mergeCallSuper(Loc loc, unsigned cs);

    Dsymbol *search(Loc loc, Identifier *ident, Dsymbol **pscopesym);
    Dsymbol *search_correct(Identifier *ident);
    Dsymbol *insert(Dsymbol *s);

    ClassDeclaration *getClassScope();
    AggregateDeclaration *getStructClassScope();
    void setNoFree();
};

#endif /* DMD_SCOPE_H */
