
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

// MARK: Selector

StringTable ObjcSelector::stringtable;
int ObjcSelector::incnum = 0;

void ObjcSelector::_init()
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
    const char *id = fdecl->ident->toChars();
    size_t id_length = strlen(id);

    // Special case: property setter
    if (ftype->isproperty && ftype->parameters && ftype->parameters->dim == 1)
    {
        // rewrite "identifier" as "setIdentifier"
        char firstChar = id[0];
        if (firstChar >= 'a' && firstChar <= 'z')
            firstChar = (char)(firstChar - 'a' + 'A');

        buf.writestring("set");
        buf.writeByte(firstChar);
        buf.write(id + 1, id_length - 1);
        buf.writeByte(':');
        goto Lcomplete;
    }

    // write identifier in selector
    buf.write(id, id_length);

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

class UnsupportedObjc : public Objc
{
public:
    void setObjc(ClassDeclaration *cd)
    {
        cd->error("Objective-C classes not supported");
    }

    void setObjc(InterfaceDeclaration *id)
    {
        id->error("Objective-C interfaces not supported");
    }

    void setSelector(FuncDeclaration *, Scope *)
    {
        // noop
    }

    void validateSelector(FuncDeclaration *)
    {
        // noop
    }

    void checkLinkage(FuncDeclaration *)
    {
        // noop
    }
};

class SupportedObjc : public Objc
{
public:
    SupportedObjc()
    {
        VersionCondition::addPredefinedGlobalIdent("D_ObjectiveC");

        objc_initSymbols();
        ObjcSelector::_init();
    }

    void setObjc(ClassDeclaration *cd)
    {
        cd->isobjc = true;
    }

    void setObjc(InterfaceDeclaration *id)
    {
        id->isobjc = true;
    }

    void setSelector(FuncDeclaration *fd, Scope *sc)
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

                if (!isUdaSelector(literal->sd))
                    continue;

                if (fd->selector)
                {
                    fd->error("can only have one Objective-C selector per method");
                    return;
                }

                assert(literal->elements->dim == 1);
                StringExp *se = (*literal->elements)[0]->toStringExp();
                assert(se);

                fd->selector = ObjcSelector::lookup((const char *)se->toUTF8(sc)->string);
            }
        }
    }

    void validateSelector(FuncDeclaration *fd)
    {
        if (!fd->selector)
            return;

        TypeFunction *tf = (TypeFunction *)fd->type;

        if (fd->selector->paramCount != tf->parameters->dim)
            fd->error("number of colons in Objective-C selector must match number of parameters");

        if (fd->parent && fd->parent->isTemplateInstance())
            fd->error("template cannot have an Objective-C selector attached");
    }

    void checkLinkage(FuncDeclaration *fd)
    {
        if (fd->linkage != LINKobjc && fd->selector)
            fd->error("must have Objective-C linkage to attach a selector");
    }

private:
    bool isUdaSelector(StructDeclaration *sd)
    {
        if (sd->ident != Id::udaSelector || !sd->parent)
            return false;

        Module* module = sd->parent->isModule();
        return module && module->isCoreModule(Id::attribute);
    }
};

static Objc *_objc;

Objc *objc()
{
    return _objc;
}

void Objc::_init()
{
    if (global.params.isOSX && global.params.is64bit)
        _objc = new SupportedObjc();
    else
        _objc = new UnsupportedObjc();
}
