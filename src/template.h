
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#ifndef DMD_TEMPLATE_H
#define DMD_TEMPLATE_H

#ifdef __DMC__
#pragma once
#endif /* __DMC__ */

#include "root.h"
#include "dsymbol.h"

struct OutBuffer;
struct Identifier;
struct TemplateInstance;
struct TemplateParameter;
struct Type;
struct Scope;
struct Expression;
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

    TemplateDeclaration *isTemplateDeclaration() { return this; }
};

struct TemplateParameter
{
    /* For type-parameter:
     *	template Foo(ident)		// specType is set to NULL
     *	template Foo(ident : specType)
     * For value-parameter:
     *	template Foo(valType ident)	// specValue is set to NULL
     *	template Foo(valType ident : specValue)
     */

    Identifier *ident;

    /* if valType!=NULL
     *	it's a value-parameter
     * else
     *	it's a type-parameter
     */

    Type *specType;	// type parameter: if !=NULL, this is the type specialization

    Type *valType;
    Expression *specValue;

    TemplateParameter(Identifier *ident, Type *specType, Type *valType, Expression *specValue);
};

struct TemplateInstance : ScopeDsymbol
{
    /* Given:
     *	instance foo.bar.abc(int, char, 10)
     */
    Array idents;		// Array of Identifiers [foo, bar, abc]
    Array tiargs;		// Array of Types/Expressions of template instance arguments [int, char, 10]

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
    char *mangle();

    void toObjFile();			// compile to .obj file

    TemplateInstance *isTemplateInstance() { return this; }
};

#endif /* DMD_TEMPLATE_H */
