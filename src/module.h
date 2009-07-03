
// Copyright (c) 1999-2005 by Digital Mars
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
struct Macro;
struct VarDeclaration;

// Back end
#if IN_GCC
union tree_node; typedef union tree_node elem;
#else
struct elem;
#endif

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
    static DsymbolTable *modules;	// symbol table of all modules
    static Array amodules;		// array of all modules
    static Array deferred;	// deferred Dsymbol's needing semantic() run on them
    static unsigned dprogress;	// progress resolving the deferred list
    static void init();

    static ClassDeclaration *moduleinfo;


    const char *arg;	// original argument name
    ModuleDeclaration *md; // if !NULL, the contents of the ModuleDeclaration declaration
    File *srcfile;	// input source file
    File *objfile;	// output .obj file
    File *hdrfile;	// 'header' file
    File *symfile;	// output symbol file
    File *docfile;	// output documentation file
    unsigned errors;	// if any errors in file
    unsigned numlines;	// number of lines in source file
    int isHtml;		// if it is an HTML file
    int isDocFile;	// if it is a documentation input file, not D source
    int needmoduleinfo;
#ifdef IN_GCC
    int strictlyneedmoduleinfo;
#endif

    int insearch;
    Identifier *searchCacheIdent;
    Dsymbol *searchCacheSymbol;	// cached value of search
    int searchCacheFlags;	// cached flags

    int semanticdone;		// has semantic() been done?
    Module *importedFrom;	// module from command line we're imported from,
				// i.e. a module that will be taken all the
				// way to an object file

    Array *decldefs;		// top level declarations for this Module

    Array aimports;		// all imported modules

    ModuleInfoDeclaration *vmoduleinfo;

    unsigned debuglevel;	// debug level
    Array *debugids;		// debug identifiers
    Array *debugidsNot;		// forward referenced debug identifiers

    unsigned versionlevel;	// version level
    Array *versionids;		// version identifiers
    Array *versionidsNot;	// forward referenced version identifiers

    Macro *macrotable;		// document comment macros

    Module(char *arg, Identifier *ident, int doDocComment, int doHdrGen);
    ~Module();

    static Module *load(Loc loc, Array *packages, Identifier *ident);

    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);
    char *kind();
    void setDocfile();	// set docfile member
    void read(Loc loc);	// read file
#if IN_GCC
    void parse(bool dump_source = false);	// syntactic parse
#else
    void parse();	// syntactic parse
#endif
    void semantic();	// semantic analysis
    void semantic2();	// pass 2 semantic analysis
    void semantic3();	// pass 3 semantic analysis
    void inlineScan();	// scan for functions to inline
    void setHdrfile();	// set hdrfile member
#ifdef _DH
    void genhdrfile();  // generate D import file
#endif
    void genobjfile();
    void gensymfile();
    void gendocfile();
    int needModuleInfo();
    Dsymbol *search(Identifier *ident, int flags);
    void deleteObjFile();
    void addDeferredSemantic(Dsymbol *s);
    void runDeferredSemantic();

    // Back end

    Symbol *cov;		// private uint[] __coverage;
    unsigned *covb;		// bit array of valid code line numbers

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
    elem *toEmodulename();

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
