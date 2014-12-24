
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
#include "target.h"

// MARK: TypeObjcSelector

TypeObjcSelector::TypeObjcSelector(Type *t)
: TypeNext(Tobjcselector, t)
{
    assert(((TypeFunction *)t)->linkage == LINKobjc);
}

Type *TypeObjcSelector::syntaxCopy()
{
    Type *t = next->syntaxCopy();
    if (t == next)
        t = this;
    else
    {   t = new TypeObjcSelector(t);
        t->mod = mod;
    }
    return t;
}

Type *TypeObjcSelector::semantic(Loc loc, Scope *sc)
{
    if (deco)                   // if semantic() already run
    {
        //printf("already done\n");
        return this;
    }
    Scope* newScope = new Scope(*sc);
    newScope->linkage = LINKobjc;
    next = next->semantic(loc,newScope);

    return merge();
}

d_uns64 TypeObjcSelector::size(Loc loc)
{
    return Target::ptrsize;
}

unsigned TypeObjcSelector::alignsize()
{
    return Target::ptrsize;
}

MATCH TypeObjcSelector::implicitConvTo(Type *to)
{
    //printf("TypeDelegate::implicitConvTo(this=%p, to=%p)\n", this, to);
    //printf("from: %s\n", toChars());
    //printf("to  : %s\n", to->toChars());
    if (this == to)
        return MATCHexact;
#if 0 // not allowing covariant conversions because it interferes with overriding
    if (to->ty == Tdelegate && this->nextOf()->covariant(to->nextOf()) == 1)
        return MATCHconvert;
#endif
    return MATCHnomatch;
}

Expression *TypeObjcSelector::defaultInit(Loc loc)
{
#if LOGDEFAULTINIT
    printf("TypeObjcSelector::defaultInit() '%s'\n", toChars());
#endif
    return new NullExp(loc, this);
}

bool TypeObjcSelector::isZeroInit(Loc loc)
{
    return true;
}

bool TypeObjcSelector::checkBoolean()
{
    return true;
}

Expression *TypeObjcSelector::dotExp(Scope *sc, Expression *e, Identifier *ident, int flag)
{
#if LOGDOTEXP
    printf("TypeDelegate::dotExp(e = '%s', ident = '%s')\n", e->toChars(), ident->toChars());
#endif
    /*    if (ident == Id::ptr)
     {
     e->type = tvoidptr;
     return e;
     }
     else if (ident == Id::funcptr)
     {
     e = e->addressOf(sc);
     e->type = tvoidptr;
     e = new AddExp(e->loc, e, new IntegerExp(PTRSIZE));
     e->type = tvoidptr;
     e = new PtrExp(e->loc, e);
     e->type = next->pointerTo();
     return e;
     }
     else*/
    {
        e = Type::dotExp(sc, e, ident, flag);
    }
    return e;
}

int TypeObjcSelector::hasPointers()
{
    return false; // not in GC memory
}

TypeInfoDeclaration *TypeObjcSelector::getTypeInfoDeclaration()
{
    return TypeInfoObjcSelectorDeclaration::create(this);
}

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
