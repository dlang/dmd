
/* Compiler implementation of the D programming language
 * Copyright (c) 2014 by Digital Mars
 * All Rights Reserved
 * written by Michel Fortin
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/objc_attrib.c
 */

#include "aggregate.h"
#include "arraytypes.h"
#include "attrib.h"

// MARK: addObjcSymbols

void Objc_ClassDeclaration::addObjcSymbols(ClassDeclarations *classes, ClassDeclarations *categories)
{
    if (objc && !extern_ && !meta)
        classes->push(cdecl);
}

void objc_AttribDeclaration_addObjcSymbols(AttribDeclaration* self, ClassDeclarations *classes, ClassDeclarations *categories)
{
    Dsymbols *d = self->include(NULL, NULL);

    if (d)
    {
        for (unsigned i = 0; i < d->dim; i++)
        {
            Dsymbol *s = (Dsymbol *)d->data[i];
            s->addObjcSymbols(classes, categories);
        }
    }
}

// MARK: semantic

void objc_PragmaDeclaration_semantic_objcTakesStringLiteral(PragmaDeclaration* self, Scope *sc)
{
    // This should apply only to a very limited number of classes and
    // interfaces: ObjcObject, NSObject, and NSString.

    if (self->args && self->args->dim != 0)
        self->error("takes no argument");

    Dsymbols *currdecl = self->decl;
Lagain_takestringliteral:
    if (currdecl->dim > 1)
        self->error("can only apply to one declaration, not %u", currdecl->dim);
    else if (currdecl->dim == 1)
    {   Dsymbol *dsym = (Dsymbol *)currdecl->data[0];
        ClassDeclaration *cdecl = dsym->isClassDeclaration();
        if (cdecl)
            cdecl->objc.takesStringLiteral = true; // set specific name
        else
        {
            AttribDeclaration *adecl = dsym->isAttribDeclaration();
            if (adecl)
            {   // encountered attrib declaration, search for a class inside
                currdecl = ((AttribDeclaration *)dsym)->decl;
                goto Lagain_takestringliteral;
            }
            else
                self->error("can only apply to class or interface declarations, not %s", dsym->toChars());
        }
    }
}

void objc_PragmaDeclaration_semantic_objcSelectorTarget(PragmaDeclaration* self, Scope *sc)
{
    // This should apply only to a very limited number of struct types in
    // the Objective-C runtime bindings: objc_object, objc_class.

    if (self->args && self->args->dim != 0)
        self->error("takes no argument");

    Dsymbols *currdecl = self->decl;
Lagain_selectortarget:
    if (currdecl->dim > 1)
        self->error("can only apply to one declaration, not %u", currdecl->dim);
    else if (currdecl->dim == 1)
    {   Dsymbol *dsym = (Dsymbol *)currdecl->data[0];
        StructDeclaration *sdecl = dsym->isStructDeclaration();
        if (sdecl)
            sdecl->objc.selectorTarget = true; // set valid selector target
        else
        {
            AttribDeclaration *adecl = dsym->isAttribDeclaration();
            if (adecl)
            {   // encountered attrib declaration, search for a class inside
                currdecl = ((AttribDeclaration *)dsym)->decl;
                goto Lagain_selectortarget;
            }
            else
                self->error("can only apply to struct declarations, not %s", dsym->toChars());
        }
    }
}

void objc_PragmaDeclaration_semantic_objcSelector(PragmaDeclaration* self, Scope *sc)
{

    // This should apply only to a very limited number of struct types in
    // the Objective-C runtime bindings: objc_object, objc_class.

    if (self->args && self->args->dim != 0)
        self->error("takes no argument");

    Dsymbols *currdecl = self->decl;
Lagain_isselector:
    if (currdecl->dim > 1)
        self->error("can only apply to one declaration, not %u", currdecl->dim);
    else if (currdecl->dim == 1)
    {   Dsymbol *dsym = (Dsymbol *)currdecl->data[0];
        StructDeclaration *sdecl = dsym->isStructDeclaration();
        if (sdecl)
            sdecl->objc.isSelector = true; // represents a selector
        else
        {   AttribDeclaration *adecl = dsym->isAttribDeclaration();
            if (adecl)
            {   // encountered attrib declaration, search for a class inside
                currdecl = ((AttribDeclaration *)dsym)->decl;
                goto Lagain_isselector;
            }
            else
                self->error("can only apply to struct declarations, not %s", dsym->toChars());
        }
    }
}

void objc_PragmaDeclaration_semantic_objcNameOverride(PragmaDeclaration* self, Scope *sc)
{
    if (!self->args || self->args->dim != 1)
        self->error("string expected for name override");

    Expression *e = (Expression *)self->args->data[0];

    e = e->semantic(sc);
    e = e->optimize(WANTvalue);
    if (e->op == TOKstring)
    {
        StringExp *se = (StringExp *)e;
        const char *name = (const char *)se->string;

        Dsymbols *currdecl = self->decl;
    Lagain_nameoverride:
        if (currdecl->dim > 1)
            self->error("can only apply to one declaration, not %u", currdecl->dim);
        else if (currdecl->dim == 1)
        {
            Dsymbol *dsym = (Dsymbol *)currdecl->data[0];
            ClassDeclaration *cdecl = dsym->isClassDeclaration();
            if (cdecl)
                cdecl->objc.ident = Lexer::idPool(name); // set specific name
            else
            {   AttribDeclaration *adecl = dsym->isAttribDeclaration();
                if (adecl)
                {   // encountered attrib declaration, search for a class inside
                    currdecl = ((AttribDeclaration *)dsym)->decl;
                    goto Lagain_nameoverride;
                }
                else
                    self->error("can only apply to class or interface declarations, not %s", dsym->toChars());
            }
        }
    }
    else
        self->error("string expected for name override, not '%s'", e->toChars());
}
