
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

// tocsym

Symbol *SymbolDeclaration::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol *Dsymbol::toSymbolX(const char *prefix, int sclass, TYPE *t, const char *suffix)
{
    assert(0);
    return NULL;
}

Symbol *Dsymbol::toSymbol()
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

Symbol *VarDeclaration::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol *ClassInfoDeclaration::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol *TypeInfoDeclaration::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol *TypeInfoClassDeclaration::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol *FuncAliasDeclaration::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol *FuncDeclaration::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol *FuncDeclaration::toThunkSymbol(int offset)
{
    assert(0);
    return NULL;
}

Symbol *ClassDeclaration::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol *InterfaceDeclaration::toSymbol()
{
    assert(0);
    return NULL;
}

Symbol *Module::toSymbol()
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

Symbol *TypedefDeclaration::toInitializer()
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

// toobj

void Module::genmoduleinfo()
{
    assert(0);
}

void Dsymbol::toObjFile(int multiobj)
{
    assert(0);
}

void ClassDeclaration::toObjFile(int multiobj)
{
    assert(0);
}

unsigned ClassDeclaration::baseVtblOffset(BaseClass *bc)
{
    assert(0);
    return 0;
}

void InterfaceDeclaration::toObjFile(int multiobj)
{
    assert(0);
}

void StructDeclaration::toObjFile(int multiobj)
{
    assert(0);
}

void VarDeclaration::toObjFile(int multiobj)
{
    assert(0);
}

void TypedefDeclaration::toObjFile(int multiobj)
{
    assert(0);
}

void EnumDeclaration::toObjFile(int multiobj)
{
    assert(0);
}

void TypeInfoDeclaration::toObjFile(int multiobj)
{
    assert(0);
}

void AttribDeclaration::toObjFile(int multiobj)
{
    assert(0);
}

void PragmaDeclaration::toObjFile(int multiobj)
{
    assert(0);
}

void TemplateInstance::toObjFile(int multiobj)
{
    assert(0);
}

void TemplateMixin::toObjFile(int multiobj)
{
    assert(0);
}

// glue

void obj_append(Dsymbol *s)
{
    assert(0);
}

void obj_write_deferred(Library *library)
{
}

void obj_start(char *srcfile)
{
}

void obj_end(Library *library, File *objfile)
{
}

bool obj_includelib(const char *name)
{
    assert(0);
    return false;
}

void obj_startaddress(Symbol *s)
{
    assert(0);
}

void Module::genobjfile(int multiobj)
{
}

void FuncDeclaration::toObjFile(int multiobj)
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

TypeInfoDeclaration *TypeTypedef::getTypeInfoDeclaration()
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

Statement *AsmStatement::semantic(Scope *)
{
    assert(0);
    return NULL;
}

int binary(const char *p, const char **tab, int n)
{
    for (int i = 0; i < n; ++i)
        if (!strcmp(p, tab[i]))
            return i;
    return -1;
}
