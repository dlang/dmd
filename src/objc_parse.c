
/* Compiler implementation of the D programming language
 * Copyright (c) 2014 by Digital Mars
 * All Rights Reserved
 * written by Michel Fortin
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/objc_parse.c
 */

#include "arraytypes.h"
#include "declaration.h"
#include "expression.h"
#include "mars.h"
#include "mtype.h"
#include "objc.h"
#include "parse.h"

void objc_Parser_parseCtor_selector(Parser *self, TemplateParameters *tpl, Parameters *parameters, CtorDeclaration *f)
{
    f->objc.selector = objc_parseSelector(self);
    if (f->objc.selector)
    {
        if (tpl)
            self->error("constructor template cannot have an Objective-C selector attached");
        if (f->objc.selector->paramCount != parameters->dim)
            self->error("number of colons in Objective-C selector must match the number of parameters");
    }
}

void objc_Parser_parseDtor(Parser *self, DtorDeclaration *f)
{
    f->objc.selector = objc_parseSelector(self);
}

void objc_Parser_parseBasicType2_selector(Type *&t, TypeFunction *tf)
{
    tf->linkage = LINKobjc; // force Objective-C linkage
    t = new TypeObjcSelector(tf);
}

void objc_Parser_parseDeclarations_Tobjcselector(Type *&t, LINK &link)
{
    if (t->ty == Tobjcselector)
        link = LINKobjc; // force Objective-C linkage
}

void objc_Parser_parseDeclarations_Tfunction(Parser *self, Type *t, TemplateParameters *tpl, FuncDeclaration *f)
{
    f->objc.selector = objc_parseSelector(self);
    if (f->objc.selector)
    {
        TypeFunction *tf = (TypeFunction *)t;
        if (tpl)
            self->error("function template cannot have an Objective-C selector attached");
        if (f->objc.selector->paramCount != tf->parameters->dim)
            self->error("number of colons in Objective-C selector must match number of parameters");
    }
}

/*****************************************
 * Parse Objective-C selector name enclosed in brackets. Such as:
 *   [setObject:forKey:otherArgs::]
 * Return NULL when no bracket found.
 */

ObjcSelector *objc_parseSelector(Parser *self)
{
    if (self->token.value != TOKlbracket)
        return NULL; // no selector

    ObjcSelectorBuilder selBuilder;
    self->nextToken();
    while (1)
    {
        switch (self->token.value)
        {
            case TOKidentifier:
            Lcaseident:
                selBuilder.addIdentifier(self->token.ident);
                break;
            case TOKcolon:
                selBuilder.addColon();
                break;
            case TOKrbracket:
                goto Lendloop;
            default:
                // special case to allow D keywords in Objective-C selector names
                if (self->token.ident)
                    goto Lcaseident;
                goto Lparseerror;
        }
        self->nextToken();
    }
Lendloop:
    self->nextToken();
    if (!selBuilder.isValid())
    {
        self->error("illegal Objective-C selector name");
        return NULL;

    }
    return ObjcSelector::lookup(&selBuilder);

Lparseerror:
    error("illegal Objective-C selector name");
    // exit bracket ignoring content
    while (self->token.value != TOKrbracket && self->token.value != TOKeof)
        self->nextToken();
    self->nextToken();
    return NULL;
}

ControlFlow objc_Parser_parsePostExp_TOKclass(Parser *self, Expression *&e, Loc loc)
{
    e = new ObjcDotClassExp(loc, e);
    self->nextToken();
    return CFcontinue;
}
