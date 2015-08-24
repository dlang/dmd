
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/typinf.c
 */

#include <stdio.h>
#include <string.h>
#include <assert.h>

#include "mars.h"
#include "module.h"
#include "mtype.h"
#include "scope.h"
#include "init.h"
#include "expression.h"
#include "attrib.h"
#include "declaration.h"
#include "template.h"
#include "id.h"
#include "enum.h"
#include "import.h"
#include "aggregate.h"

void toObjFile(Dsymbol *ds, bool multiobj);
TypeInfoDeclaration *getTypeInfoDeclaration(Type *t);
static bool builtinTypeInfo(Type *t);

/****************************************************
 * Get the exact TypeInfo.
 */

void genTypeInfo(Type *torig, Scope *sc)
{
    //printf("Type::genTypeInfo() %p, %s\n", this, toChars());
    if (!Type::dtypeinfo)
    {
        torig->error(Loc(), "TypeInfo not found. object.d may be incorrectly installed or corrupt, compile with -v switch");
        fatal();
    }

    Type *t = torig->merge2(); // do this since not all Type's are merge'd
    if (!t->vtinfo)
    {
        if (t->isShared())      // does both 'shared' and 'shared const'
            t->vtinfo = TypeInfoSharedDeclaration::create(t);
        else if (t->isConst())
            t->vtinfo = TypeInfoConstDeclaration::create(t);
        else if (t->isImmutable())
            t->vtinfo = TypeInfoInvariantDeclaration::create(t);
        else if (t->isWild())
            t->vtinfo = TypeInfoWildDeclaration::create(t);
        else
            t->vtinfo = getTypeInfoDeclaration(t);
        assert(t->vtinfo);

        /* If this has a custom implementation in std/typeinfo, then
         * do not generate a COMDAT for it.
         */
        if (!builtinTypeInfo(t))
        {
            // Generate COMDAT
            if (sc)                     // if in semantic() pass
            {
                if (sc->func && sc->func->inNonRoot())
                {
                    // Bugzilla 13043: Avoid linking TypeInfo if it's not
                    // necessary for root module compilation
                }
                else
                {
                    // Find module that will go all the way to an object file
                    Module *m = sc->module->importedFrom;
                    m->members->push(t->vtinfo);

                    semanticTypeInfo(sc, t);
                }
            }
            else                        // if in obj generation pass
            {
                toObjFile(t->vtinfo, global.params.multiobj);
            }
        }
    }
    if (!torig->vtinfo)
        torig->vtinfo = t->vtinfo;     // Types aren't merged, but we can share the vtinfo's
    assert(torig->vtinfo);
}

Type *getTypeInfoType(Type *t, Scope *sc)
{
    assert(t->ty != Terror);
    genTypeInfo(t, sc);
    return t->vtinfo->type;
}

TypeInfoDeclaration *getTypeInfoDeclaration(Type *t)
{
    //printf("Type::getTypeInfoDeclaration() %s\n", t->toChars());
    switch(t->ty)
    {
    case Tpointer:  return TypeInfoPointerDeclaration::create(t);
    case Tarray:    return TypeInfoArrayDeclaration::create(t);
    case Tsarray:   return TypeInfoStaticArrayDeclaration::create(t);
    case Taarray:   return TypeInfoAssociativeArrayDeclaration::create(t);
    case Tstruct:   return TypeInfoStructDeclaration::create(t);
    case Tvector:   return TypeInfoVectorDeclaration::create(t);
    case Tenum:     return TypeInfoEnumDeclaration::create(t);
    case Tfunction: return TypeInfoFunctionDeclaration::create(t);
    case Tdelegate: return TypeInfoDelegateDeclaration::create(t);
    case Ttuple:    return TypeInfoTupleDeclaration::create(t);
    case Tclass:
        if (((TypeClass *)t)->sym->isInterfaceDeclaration())
            return TypeInfoInterfaceDeclaration::create(t);
        else
            return TypeInfoClassDeclaration::create(t);
    default:
        return TypeInfoDeclaration::create(t, 0);
    }
}

/* ========================================================================= */

/* These decide if there's an instance for them already in std.typeinfo,
 * because then the compiler doesn't need to build one.
 */

static bool builtinTypeInfo(Type *t)
{
    if (t->isTypeBasic() || t->ty == Tclass)
        return !t->mod;
    if (t->ty == Tarray)
    {
        Type *next = t->nextOf();
        return !t->mod && (next->isTypeBasic() != NULL && !next->mod ||
            // strings are so common, make them builtin
            next->ty == Tchar && next->mod == MODimmutable ||
            next->ty == Tchar && next->mod == MODconst);
    }
    return false;
}
