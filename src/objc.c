
/* Compiler implementation of the D programming language
 * Copyright (c) 2015 by Digital Mars
 * All Rights Reserved
 * written by Michel Fortin
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/objc.c
 */

#include "aggregate.h"
#include "arraytypes.h"
#include "attrib.h"
#include "cond.h"
#include "declaration.h"
#include "id.h"
#include "init.h"
#include "mars.h"
#include "module.h"
#include "mtype.h"
#include "objc.h"
#include "outbuffer.h"
#include "scope.h"
#include "statement.h"
#include "visitor.h"

void mangleToBuffer(Type *t, OutBuffer *buf);
void objc_initSymbols();

// MARK: Objc_ClassDeclaration

bool Objc_ClassDeclaration::isInterface()
{
    return objc;
}

// MARK: semantic

void objc_ClassDeclaration_semantic_PASSinit_LINKobjc(ClassDeclaration *cd)
{
    cd->objc.objc = true;
}

void objc_InterfaceDeclaration_semantic_objcExtern(InterfaceDeclaration *id, Scope *sc)
{
    if (sc->linkage == LINKobjc)
        id->objc.objc = true;
}

// MARK: Objc_FuncDeclaration

Objc_FuncDeclaration::Objc_FuncDeclaration()
{
    this->fdecl = NULL;
    selector = NULL;
}

Objc_FuncDeclaration::Objc_FuncDeclaration(FuncDeclaration* fdecl)
{
    this->fdecl = fdecl;
    selector = NULL;
}

// MARK: semantic

void objc_FuncDeclaration_semantic_setSelector(FuncDeclaration *fd, Scope *sc)
{
    if (!fd->userAttribDecl)
        return;

    Expressions *udas = fd->userAttribDecl->getAttributes();
    arrayExpressionSemantic(udas, sc, true);

    for (size_t i = 0; i < udas->dim; i++)
    {
        Expression *uda = (*udas)[i];
        assert(uda->type);

        if (uda->type->ty != Ttuple)
            continue;

        Expressions *exps = ((TupleExp *)uda)->exps;

        for (size_t j = 0; j < exps->dim; j++)
        {
            Expression *e = (*exps)[j];
            assert(e->type);

            if (e->type->ty != Tstruct)
                continue;

            StructLiteralExp *literal = (StructLiteralExp *)e;
            assert(literal->sd);

            if (!objc_isUdaSelector(literal->sd))
                continue;

            if (fd->objc.selector)
            {
                fd->error("can only have one Objective-C selector per method");
                return;
            }

            assert(literal->elements->dim == 1);
            StringExp *se = (*literal->elements)[0]->toStringExp();
            assert(se);

            fd->objc.selector = ObjcSelector::lookup((const char *)se->toUTF8(sc)->string);
        }
    }
}

bool objc_isUdaSelector(StructDeclaration *sd)
{
    if (sd->ident != Id::udaSelector || !sd->parent)
        return false;

    Module* module = sd->parent->isModule();
    return module && module->isCoreModule(Id::attribute);
}

void objc_FuncDeclaration_semantic_validateSelector(FuncDeclaration *fd)
{
    if (!fd->objc.selector)
        return;

    TypeFunction *tf = (TypeFunction *)fd->type;

    if (fd->objc.selector->paramCount != tf->parameters->dim)
        fd->error("number of colons in Objective-C selector must match number of parameters");

    if (fd->parent && fd->parent->isTemplateInstance())
        fd->error("template cannot have an Objective-C selector attached");
}

void objc_FuncDeclaration_semantic_checkLinkage(FuncDeclaration *fd)
{
    if (fd->linkage != LINKobjc && fd->objc.selector)
        fd->error("must have Objective-C linkage to attach a selector");
}

// MARK: init

void objc_tryMain_dObjc()
{
    VersionCondition::addPredefinedGlobalIdent("D_ObjectiveC");
}

void objc_tryMain_init()
{
    objc_initSymbols();
    ObjcSelector::init();
}

// MARK: Selector

StringTable ObjcSelector::stringtable;
int ObjcSelector::incnum = 0;

void ObjcSelector::init()
{
    stringtable._init();
}

ObjcSelector::ObjcSelector(const char *sv, size_t len, size_t pcount)
{
    stringvalue = sv;
    stringlen = len;
    paramCount = pcount;
}

ObjcSelector *ObjcSelector::lookup(const char *s)
{
    size_t len = 0;
    size_t pcount = 0;
    const char *i = s;
    while (*i != 0)
    {
        ++len;
        if (*i == ':') ++pcount;
        ++i;
    }
    return lookup(s, len, pcount);
}

ObjcSelector *ObjcSelector::lookup(const char *s, size_t len, size_t pcount)
{
    StringValue *sv = stringtable.update(s, len);
    ObjcSelector *sel = (ObjcSelector *) sv->ptrvalue;
    if (!sel)
    {
        sel = new ObjcSelector(sv->toDchars(), len, pcount);
        sv->ptrvalue = (char *)sel;
    }
    return sel;
}

ObjcSelector *ObjcSelector::create(FuncDeclaration *fdecl)
{
    OutBuffer buf;
    size_t pcount = 0;
    TypeFunction *ftype = (TypeFunction *)fdecl->type;

    // Special case: property setter
    if (ftype->isproperty && ftype->parameters && ftype->parameters->dim == 1)
    {
        // rewrite "identifier" as "setIdentifier"
        char firstChar = fdecl->ident->string[0];
        if (firstChar >= 'a' && firstChar <= 'z')
            firstChar = (char)(firstChar - 'a' + 'A');

        buf.writestring("set");
        buf.writeByte(firstChar);
        buf.write(fdecl->ident->string+1, fdecl->ident->len-1);
        buf.writeByte(':');
        goto Lcomplete;
    }

    // write identifier in selector
    buf.write(fdecl->ident->string, fdecl->ident->len);

    // add mangled type and colon for each parameter
    if (ftype->parameters && ftype->parameters->dim)
    {
        buf.writeByte('_');
        Parameters *arguments = ftype->parameters;
        size_t dim = Parameter::dim(arguments);
        for (size_t i = 0; i < dim; i++)
        {
            Parameter *arg = Parameter::getNth(arguments, i);
            mangleToBuffer(arg->type, &buf);
            buf.writeByte(':');
        }
        pcount = dim;
    }
Lcomplete:
    buf.writeByte('\0');

    return lookup((const char *)buf.data, buf.size, pcount);
}
