
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#pragma once

struct Dsymbol;
struct ScopeDsymbol;
struct Array;
struct Identifier;
struct Module;
struct SwitchStatement;
struct LabelStatement;
struct ClassDeclaration;
enum LINK;
enum PROT;

struct Scope
{
    Scope *enclosing;		// enclosing Scope

    Module *module;		// Root module
    ScopeDsymbol *scopesym;	// current symbol
    FuncDeclaration *func;	// function we are in
    LabelStatement *slabel;	// enclosing labelled statement
    SwitchStatement *sw;	// enclosing switch statement
    Statement *sbreak;		// enclosing statement that supports "break"
    Statement *scontinue;	// enclosing statement that supports "continue"
    unsigned offset;		// next offset to use in aggregate
    int inunion;		// we're processing members of a union
    int incontract;		// we're inside contract code
    int nofree;			// set if shouldn't free it
    int noctor;			// set if constructor calls aren't allowed
    unsigned callSuper;		// primitive flow analysis for constructors
#define	CSXthis_ctor	1	// called this()
#define CSXsuper_ctor	2	// called super()
#define CSXthis		4	// referenced this
#define CSXsuper	8	// referenced super
#define CSXlabel	0x10	// seen a label
#define CSXreturn	0x20	// seen a return statement
#define CSXany_ctor	0x40	// either this() or super() was called

    unsigned structalign;	// alignment for struct members
    enum LINK linkage;		// linkage for external functions
    enum PROT protection;	// protection for class members
    unsigned stc;		// storage class
    unsigned flags;
#define SCOPEctor	1	// constructor type

    static Scope *freelist;
    static void *operator new(size_t sz);

    Scope(Module *module);
    Scope(Scope *enclosing);

    Scope *push();
    Scope *push(ScopeDsymbol *ss);
    Scope *pop();

    void mergeCallSuper(Loc loc, unsigned cs);

    Dsymbol *search(Identifier *ident, Dsymbol **pscopesym);
    Dsymbol *insert(Dsymbol *s);

    ClassDeclaration *getClassScope();
    void setNoFree();
};
