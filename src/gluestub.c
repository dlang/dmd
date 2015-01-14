
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

Symbol *Dsymbol::toSymbolX(const char *prefix, int sclass, TYPE *t, const char *suffix)
{
    assert(0);
    return NULL;
}

Symbol *Dsymbol::toImport()
{
    assert(0);
    return NULL;
}

Symbol *Dsymbol::toImport(Symbol *sym)
{
    assert(0);
    return NULL;
}

Symbol *FuncDeclaration::toThunkSymbol(int offset)
{
    assert(0);
    return NULL;
}

Symbol *ClassDeclaration::toVtblSymbol()
{
    assert(0);
    return NULL;
}

Symbol *AggregateDeclaration::toInitializer()
{
    return NULL;
}

Symbol *EnumDeclaration::toInitializer()
{
    return NULL;
}

Symbol *Module::toModuleAssert()
{
    return NULL;
}

Symbol *Module::toModuleUnittest()
{
    return NULL;
}

Symbol *Module::toModuleArray()
{
    return NULL;
}

Symbol *TypeAArray::aaGetSymbol(const char *func, int flags)
{
    assert(0);
    return NULL;
}

Symbol* StructLiteralExp::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol* ClassReferenceExp::toSymbol()
{
    assert(0);
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

void Module::genobjfile(bool multiobj)
{
}

void Module::genhelpers(bool iscomdat)
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

Expression *Type::getInternalTypeInfo(Scope *sc)
{
    assert(0);
    return NULL;
}

Expression *Type::getTypeInfo(Scope *sc)
{
    Declaration *ti = new TypeInfoDeclaration(this, 1);
    Expression *e = new VarExp(Loc(), ti);
    e = e->addressOf();
    e->type = ti->type;
    return e;
}

TypeInfoDeclaration *Type::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

TypeInfoDeclaration *TypePointer::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

TypeInfoDeclaration *TypeDArray::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

TypeInfoDeclaration *TypeSArray::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

TypeInfoDeclaration *TypeAArray::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

TypeInfoDeclaration *TypeStruct::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

TypeInfoDeclaration *TypeClass::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

TypeInfoDeclaration *TypeVector::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

TypeInfoDeclaration *TypeEnum::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

TypeInfoDeclaration *TypeFunction::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

TypeInfoDeclaration *TypeDelegate::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

TypeInfoDeclaration *TypeTuple::getTypeInfoDeclaration()
{
    assert(0);
    return NULL;
}

int Type::builtinTypeInfo()
{
    assert(0);
    return 0;
}

int TypeBasic::builtinTypeInfo()
{
    assert(0);
    return 0;
}

int TypeDArray::builtinTypeInfo()
{
    assert(0);
    return 0;
}

int TypeClass::builtinTypeInfo()
{
    assert(0);
    return 0;
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
