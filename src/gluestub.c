
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/gluestub.c
 */

#include "module.h"
#include "declaration.h"
#include "aggregate.h"
#include "enum.h"
#include "attrib.h"
#include "template.h"
#include "statement.h"
#include "init.h"
#include "ctfe.h"
#include "lib.h"
#include "nspace.h"

// tocsym

Symbol *toInitializer(AggregateDeclaration *ad)
{
    return NULL;
}

Symbol *toModuleAssert(Module *m)
{
    return NULL;
}

Symbol *toModuleUnittest(Module *m)
{
    return NULL;
}

Symbol *toModuleArray(Module *m)
{
    return NULL;
}

// glue

void obj_write_deferred(Library *library)
{
}

void obj_start(char *srcfile)
{
}

void obj_end(Library *library, File *objfile)
{
}

void genObjFile(Module *m, bool multiobj)
{
}

void genhelpers(Module *m, bool iscomdat)
{
    assert(0);
}

// msc

void backend_init()
{
}

void backend_term()
{
}

// typinf

Expression *getTypeInfo(Type *t, Scope *sc)
{
    Declaration *ti = new TypeInfoDeclaration(t, 1);
    Expression *e = new VarExp(Loc(), ti);
    e = e->addressOf();
    e->type = ti->type;
    return e;
}

// lib

Library *LibMSCoff_factory()
{
    assert(0);
    return NULL;
}

Library *LibOMF_factory()
{
    assert(0);
    return NULL;
}

Library *LibElf_factory()
{
    assert(0);
    return NULL;
}

Library *LibMach_factory()
{
    assert(0);
    return NULL;
}

Statement* asmSemantic(AsmStatement *s, Scope *sc)
{
    assert(0);
    return NULL;
}

// toir

RET retStyle(TypeFunction *tf)
{
    return RETregs;
}
