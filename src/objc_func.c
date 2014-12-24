
/* Compiler implementation of the D programming language
 * Copyright (c) 2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/objc_func.c
 */

#include "aggregate.h"
#include "attrib.h"
#include "declaration.h"
#include "id.h"
#include "objc.h"
#include "scope.h"

// MARK: Ojbc_FuncDeclaration

Ojbc_FuncDeclaration::Ojbc_FuncDeclaration(FuncDeclaration* fdecl)
{
    this->fdecl = fdecl;
    selector = NULL;
    vcmd = NULL;
}

void Ojbc_FuncDeclaration::createSelector()
{
    if (selector == NULL && fdecl->linkage == LINKobjc && fdecl->isVirtual() && fdecl->type)
    {
        TypeFunction *ftype = (TypeFunction *)fdecl->type;
        selector = ObjcSelector::create(fdecl);
    }
}

bool Ojbc_FuncDeclaration::isProperty()
{
    TypeFunction* t = (TypeFunction*)fdecl->type;

    return (fdecl->storage_class & STCproperty) &&
    t && t->parameters &&
    ((t->parameters->dim == 1 && t->next == Type::tvoid) ||
     (t->parameters->dim == 0 && t->next != Type::tvoid));
}

// MARK: semantic

void objc_FuncDeclaration_semantic_validateSelector (FuncDeclaration *self)
{
    if (!self->objc.selector)
        return;

    TypeFunction *tf = (TypeFunction *)self->type;

    if (self->objc.selector->paramCount != tf->parameters->dim)
        self->error("number of colons in Objective-C selector must match number of parameters");

    if (self->parent && self->parent->isTemplateInstance())
        self->error("template cannot have an Objective-C selector attached");
}

void objc_FuncDeclaration_semantic_checkAbstractStatic(FuncDeclaration *self)
{
    // Because static functions are virtual in Objective-C objects
    if (self->isAbstract() && self->isStatic() && self->linkage == LINKobjc)
        self->error("static functions cannot be abstract");
}

void objc_FuncDeclaration_semantic_parentForStaticMethod(FuncDeclaration *self, ClassDeclaration *&cd)
{
    // Handle Objective-C static member functions, which are virtual
    // functions of the metaclass, by changing the parent class
    // declaration to the metaclass.
    if (cd->objc.objc && self->isStatic())
    {
        if (!cd->objc.meta) // but check that it hasn't already been done
        {
            assert(cd->objc.metaclass);
            cd = cd->objc.metaclass;
        }
    }
}

void objc_FuncDeclaration_semantic_checkInheritedSelector(FuncDeclaration *self, ClassDeclaration *cd)
{
    if (cd->objc.objc)
    {
        // Check for Objective-C selector inherited form overriden functions
        for (size_t i = 0; i < self->foverrides.dim; ++i)
        {
            FuncDeclaration *foverride = (FuncDeclaration *)self->foverrides.data[i];
            if (foverride && foverride->objc.selector)
            {
                if (!self->objc.selector)
                    self->objc.selector = foverride->objc.selector; // inherit selector
                else if (self->objc.selector != foverride->objc.selector)
                    self->error("Objective-C selector %s must be the same as selector %s in overriden function.", self->objc.selector->stringvalue, foverride->objc.selector->stringvalue);
            }
        }
    }
}

void objc_FuncDeclaration_semantic_addClassMethodList(FuncDeclaration *self, ClassDeclaration *cd)
{
    if (cd->objc.objc)
    {
        // Add to class method lists
        self->objc.createSelector(); // create a selector if needed
        if (self->objc.selector && cd)
        {
            assert(self->isStatic() ? cd->objc.meta : !cd->objc.meta);

            cd->objc.methodList.push(self);
            if (cd->objc.methods == NULL)
            {
                cd->objc.methods = new StringTable;
                cd->objc.methods->_init();
            }
            StringValue *sv = cd->objc.methods->update(self->objc.selector->stringvalue, self->objc.selector->stringlen);

            if (sv->ptrvalue)
            {
                // check if the other function with the same selector is
                // overriden by this one
                FuncDeclaration *selowner = (FuncDeclaration *)sv->ptrvalue;
                if (selowner != self && !self->overrides(selowner))
                    self->error("Objcective-C selector '%s' already in use by function '%s'.", self->objc.selector->stringvalue, selowner->toChars());
            }
            else
                sv->ptrvalue = self;
        }
    }
}

void objc_FuncDeclaration_semantic_checkLinkage(FuncDeclaration *self)
{
    if (self->linkage != LINKobjc && self->objc.selector)
        self->error("function must have Objective-C linkage to attach a selector");
}

void objc_SynchronizedStatement_semantic_sync_enter(ClassDeclaration *cd, Parameters* args, FuncDeclaration *&fdenter)
{
    if (cd && cd->objc.objc) // replace with Objective-C's equivalent function
        fdenter = FuncDeclaration::genCfunc(args, Type::tvoid, Id::objc_sync_enter, STCnothrow);
}

void objc_SynchronizedStatement_semantic_sync_exit(ClassDeclaration *cd, Parameters* args, FuncDeclaration *&fdexit)
{
    if (cd && cd->objc.objc) // replace with Objective-C's equivalent function
        fdexit = FuncDeclaration::genCfunc(args, Type::tvoid, Id::objc_sync_exit, STCnothrow);
}

// MARK: FuncDeclaration

void objc_FuncDeclaration_declareThis(FuncDeclaration *self, Scope *sc, VarDeclaration** vobjccmd, VarDeclaration *v)
{
    if (vobjccmd && self->objc.selector)
    {
        VarDeclaration* varObjc = new VarDeclaration(self->loc, Type::tvoidptr, Id::_cmd, NULL);
        varObjc->storage_class |= STCparameter;
        varObjc->semantic(sc);
        if (!sc->insert(varObjc))
            assert(0);
        varObjc->parent = self;
        *vobjccmd = varObjc;

        assert(*vobjccmd != v);
    }
}

void objc_FuncDeclaration_isThis(FuncDeclaration *self, AggregateDeclaration *&ad)
{
    // Use Objective-C class object as 'this'
    ClassDeclaration *cd = self->isMember2()->isClassDeclaration();
    if (cd->objc.objc)
        if (!cd->objc.meta) // but check that it hasn't already been done
            ad = cd->objc.metaclass;
}

ControlFlow objc_FuncDeclaration_isVirtual(FuncDeclaration *self, Dsymbol *p, bool &result)
{
    if (self->linkage == LINKobjc)
    {
        // * final member functions are kept virtual with Objective-C linkage
        //   because the Objective-C runtime always use dynamic dispatch.
        // * static member functions are kept virtual too, as they represent
        //   methods of the metaclass.
        result = self->isMember() &&
        !(self->protection == PROTprivate || self->protection == PROTpackage) &&
        p->isClassDeclaration();

        return CFreturn;
    }

    return CFnone;
}

bool objc_FuncDeclaration_objcPreinitInvariant(FuncDeclaration *self)
{
    return self->ident != Id::_dobjc_preinit && self->ident != Id::_dobjc_invariant;
}
