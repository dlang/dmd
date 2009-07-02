
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

struct OutBuffer;
struct Identifier;
struct TemplateInstance;
struct TemplateParameter;
struct Type;
struct Scope;
enum MATCH;

struct TemplateDeclaration : ScopeDsymbol
{
    Array *parameters;		// array of TemplateParameter's
    Array instances;		// array of TemplateInstance's

    TemplateDeclaration *overnext;	// next overloaded TemplateDeclaration
    Scope *scope;

    TemplateDeclaration(Loc loc, Identifier *id, Array *parameters, Array *decldefs);
    Dsymbol *syntaxCopy(Dsymbol *);
    void semantic(Scope *sc);
    int overloadInsert(Dsymbol *s);
    void toCBuffer(OutBuffer *buf);
    char *kind();
    char *toChars();

    MATCH matchWithInstance(TemplateInstance *ti, Array *atypes);
    MATCH matchType(Type *tiarg, int i, Array *atypes);
    int leastAsSpecialized(TemplateDeclaration *td2);
};

struct TemplateParameter
{
    Identifier *ident;
    Type *type;

    TemplateParameter(Identifier *ident, Type *type);
};

struct TemplateInstance : ScopeDsymbol
{
    /* Given:
     *	instance foo.bar.abc(int, char)
     */
    Array idents;		// Array of Identifiers [foo, bar, abc]
    Array tiargs;		// Array of Types of template instance arguments [int, char]

    TemplateDeclaration *tempdecl;	// referenced by foo.bar.abc
    TemplateInstance *inst;		// refer to existing instance
    Array tdtypes;		// types corresponding to TemplateDeclaration.parameters
    ScopeDsymbol *argsym;	// argument symbol table

    TemplateInstance(Identifier *temp_id);
    Dsymbol *syntaxCopy(Dsymbol *);
    void addIdent(Identifier *ident);
    void semantic(Scope *sc);
    void semantic2(Scope *sc);
    void semantic3(Scope *sc);
    void inlineScan();
    void toCBuffer(OutBuffer *buf);
    Dsymbol *toAlias();			// resolve real symbol
    char *kind();
    char *toChars();

    void toObjFile();			// compile to .obj file
};

