
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2016 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/dlang/dmd/blob/master/src/import.h
 */

#ifndef DMD_IMPORT_H
#define DMD_IMPORT_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

#include "dsymbol.h"


class Identifier;
struct Scope;
class Module;
class Package;
class AliasDeclaration;

class Import : public Dsymbol
{
public:
    /* static import aliasId = pkg1.pkg2.id : alias1 = name1, alias2 = name2;
     */

    Identifiers *packages;      // array of Identifier's representing packages
    Identifier *id;             // module Identifier
    Identifier *aliasId;
    int isstatic;               // !=0 if static import
    Prot protection;

    // Pairs of alias=name to bind into current namespace
    Identifiers names;
    Identifiers aliases;

    Module *mod;
    Package *pkg;               // leftmost package/module

    AliasDeclarations aliasdecls; // corresponding AliasDeclarations for alias=name pairs

    void addAlias(Identifier *name, Identifier *alias);
    const char *kind();
    Prot prot();
    Dsymbol *syntaxCopy(Dsymbol *s);    // copy only syntax trees
    void load(Scope *sc);
    void importAll(Scope *sc);
    void semantic(Scope *sc);
    void semantic2(Scope *sc);
    Dsymbol *toAlias();
    void addMember(Scope *sc, ScopeDsymbol *sds);
    void setScope(Scope* sc);
    Dsymbol *search(Loc loc, Identifier *ident, int flags = SearchLocalsOnly);
    bool overloadInsert(Dsymbol *s);

    Import *isImport() { return this; }
    void accept(Visitor *v) { v->visit(this); }
};

#endif /* DMD_IMPORT_H */
