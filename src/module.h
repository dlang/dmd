
// Copyright (c) 1999-2004 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef DMD_MODULE_H
#define DMD_MODULE_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

#include "root.h"
#include "dsymbol.h"

struct ModuleInfoDeclaration;
struct ClassDeclaration;
struct ModuleDeclaration;

// Back end
struct elem;

struct Package : ScopeDsymbol
{
    Package(Identifier *ident);
    char *kind();

    static DsymbolTable *resolve(Array *packages, Dsymbol **pparent, Package **ppkg);

    Package *isPackage() { return this; }

    virtual void semantic(Scope *sc) { }
};

struct Module : Package
{
    static DsymbolTable *modules;	// All modules
    static Array deferred;	// deferred Dsymbol's needing semantic() run on them
    static void init();

    static ClassDeclaration *moduleinfo;


    const char *arg;	// original argument name
    ModuleDeclaration *md; // if !NULL, the contents of the ModuleDeclaration declaration
    File *srcfile;	// input source file
    File *objfile;	// output .obj file
    File *symfile;	// output symbol file
    unsigned errors;	// if any errors in file
    int isHtml;		// if it is an HTML file
    int needmoduleinfo;
    int insearch;
    int semanticdone;		// has semantic() been done?
    Module *importedFrom;	// module from command line we're imported from,
				// i.e. a module that will be taken all the
				// way to an object file

    Array *decldefs;		// top level declarations for this Module

    Array aimports;		// all imported modules

    ModuleInfoDeclaration *vmoduleinfo;

    unsigned debuglevel;	// debug level
    Array *debugids;		// debug identifiers

    unsigned versionlevel;	// version level
    Array *versionids;		// version identifiers


    Module(char *arg, Identifier *ident);
    ~Module();

    static Module *load(Loc loc, Array *packages, Identifier *ident);

    char *kind();
    void read();	// read file
    void parse();	// syntactic parse
    void semantic();	// semantic analysis
    void semantic2();	// pass 2 semantic analysis
    void semantic3();	// pass 3 semantic analysis
    void inlineScan();	// scan for functions to inline
    void genobjfile();
    void gensymfile();
    int needModuleInfo();
    Dsymbol *search(Identifier *ident, int flags);
    void deleteObjFile();
    void addDeferredSemantic(Dsymbol *s);
    void runDeferredSemantic();

    // Back end

    Symbol *sctor;		// module constructor
    Symbol *sdtor;		// module destructor
    Symbol *stest;		// module unit test

    Symbol *sfilename;		// symbol for filename

    Symbol *massert;		// module assert function
    Symbol *toModuleAssert();	// get module assert function

    Symbol *marray;		// module array bounds function
    Symbol *toModuleArray();	// get module array bounds function


    static Symbol *gencritsec();
    elem *toEfilename();

    Symbol *toSymbol();
    void genmoduleinfo();

    Module *isModule() { return this; }
};


struct ModuleDeclaration
{
    Identifier *id;
    Array *packages;		// array of Identifier's representing packages

    ModuleDeclaration(Array *packages, Identifier *id);

    char *toChars();
};

#endif /* DMD_MODULE_H */
