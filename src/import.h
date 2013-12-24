
// Compiler implementation of the D programming language
// Copyright (c) 1999-2013 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef DMD_IMPORT_H
#define DMD_IMPORT_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

#include "dsymbol.h"


class Identifier;
struct Scope;
struct OutBuffer;
class Module;
class Package;
class AliasDeclaration;
struct HdrGenState;

class Import : public Dsymbol
{
public:
    /* static import aliasId = pkg1.pkg2.id : alias1 = name1, alias2 = name2;
     */

    Identifiers *packages;      // array of Identifier's representing packages
    Identifier *id;             // module Identifier
    Identifier *aliasId;
    int isstatic;               // !=0 if static import
    PROT protection;

    // Pairs of alias=name to bind into current namespace
    Identifiers names;
    Identifiers aliases;

    Import(Loc loc, Identifiers *packages, Identifier *id, Identifier *aliasId,
        int isstatic);
    void addAlias(Identifier *name, Identifier *alias);

    AliasDeclarations aliasdecls; // corresponding AliasDeclarations for alias=name pairs

    Module *mod;
    Package *pkg;               // leftmost package/module

    const char *kind();
    PROT prot();
    Dsymbol *syntaxCopy(Dsymbol *s);    // copy only syntax trees
    void load(Scope *sc);
    void importAll(Scope *sc);
    void semantic(Scope *sc);
    void semantic2(Scope *sc);
    Dsymbol *toAlias();
    int addMember(Scope *sc, ScopeDsymbol *s, int memnum);
    Dsymbol *search(Loc loc, Identifier *ident, int flags = IgnoreNone);
    bool overloadInsert(Dsymbol *s);
    void toCBuffer(OutBuffer *buf, HdrGenState *hgs);

    Import *isImport() { return this; }
    void accept(Visitor *v) { v->visit(this); }
};

#endif /* DMD_IMPORT_H */
