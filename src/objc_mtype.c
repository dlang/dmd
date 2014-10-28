
/* Compiler implementation of the D programming language
 * Copyright (c) 2014 by Digital Mars
 * All Rights Reserved
 * written by Michel Fortin
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/objc_mtype.c
 */

#include "aggregate.h"
#include "declaration.h"
#include "expression.h"
#include "id.h"
#include "mtype.h"
#include "objc.h"
#include "scope.h"

// MARK: Type::init

void objc_Type_init(unsigned char sizeTy[TMAX])
{
    sizeTy[Tobjcselector] = sizeof(TypeObjcSelector);
}

// MARK: dotExp

void objc_Type_dotExp_TOKdotvar_setReceiver(ClassDeclaration *&receiver, DotVarExp *dv)
{
    Type* baseType = dv->e1->type->toBasetype();
    if (baseType && baseType->ty == Tclass)
        receiver = ((TypeClass*) baseType)->sym;
}

void objc_Type_dotExp_TOKvar_setReceiver(VarDeclaration *v, ClassDeclaration *&receiver)
{
    if (Dsymbol* parent = v->toParent())
        receiver = parent->isClassDeclaration();
}

void objc_Type_dotExp_offsetof(Type *self, Expression *e, ClassDeclaration *receiver)
{
    if (receiver && receiver->objc.objc)
        self->error(e->loc, ".offsetof (%s) is not available for members of Objective-C classes (%s)", e->toChars(), receiver->toChars());
}

void objc_TypeClass_dotExp_tupleof(TypeClass *self, Expression *e)
{
    if (self->sym->objc.objc)
        self->error(e->loc, ".tupleof (%s) is not available for Objective-C classes (%s)", e->toChars(), self->sym->toChars());
}

ControlFlow objc_TypeClass_dotExp_protocolof(Scope *sc, Expression *&e, Identifier *ident)
{
    if (ident == Id::protocolof)
    {
        e = new ObjcProtocolOfExp(e->loc, e);
        e = e->semantic(sc);
        return CFreturn;
    }

    return CFnone;
}

void objc_TypeClass_dotExp_TOKtype(TypeClass *self, Scope *sc, Expression *&e, Declaration *d)
{
    // Objective-C class methods uses the class object as 'this'
    DotVarExp *de = new DotVarExp(e->loc, new ObjcClassRefExp(e->loc, self->sym), d);
    e = de->semantic(sc);
}
