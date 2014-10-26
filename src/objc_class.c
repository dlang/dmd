
/* Compiler implementation of the D programming language
 * Copyright (c) 2014 by Digital Mars
 * All Rights Reserved
 * written by Michel Fortin
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/objc_class.c
 */

// MARK: semantic

#include "aggregate.h"
#include "id.h"
#include "init.h"
#include "scope.h"
#include "statement.h"

void objc_ClassDeclaration_semantic_PASSinit_LINKobjc(ClassDeclaration *self)
{
#if DMD_OBJC
    self->objc.objc = true;
    self->objc.extern_ = true;
#else
    self->error("Objective-C classes not supported");
#endif
}

void objc_ClassDeclaration_semantic_SIZEOKnone(ClassDeclaration *self, Scope *sc)
{
    if (self->objc.objc && !self->objc.meta && !self->objc.metaclass)
    {
        if (!self->objc.ident)
            self->objc.ident = self->ident;

        if (self->objc.ident == Id::Protocol)
        {
            if (ObjcProtocolOfExp::protocolClassDecl == NULL)
                ObjcProtocolOfExp::protocolClassDecl = self;
            else if (ObjcProtocolOfExp::protocolClassDecl != self)
                self->error("duplicate definition of Objective-C class '%s'", Id::Protocol);
        }

        // Create meta class derived from all our base's metaclass
        BaseClasses *metabases = new BaseClasses();
        for (size_t i = 0; i < self->baseclasses->dim; ++i)
        {
            ClassDeclaration *basecd = ((BaseClass *)self->baseclasses->data[i])->base;
            assert(basecd);
            if (basecd->objc.objc)
            {
                assert(basecd->objc.metaclass);
                assert(basecd->objc.metaclass->objc.meta);
                assert(basecd->objc.metaclass->type->ty == Tclass);
                assert(((TypeClass *)basecd->objc.metaclass->type)->sym == basecd->objc.metaclass);
                BaseClass *metabase = new BaseClass(basecd->objc.metaclass->type, PROTpublic);
                metabase->base = basecd->objc.metaclass;
                metabases->push(metabase);
            }
            else
                self->error("base class and interfaces for an Objective-C class must be extern (Objective-C)");
        }
        self->objc.metaclass = new ClassDeclaration(self->loc, Id::Class, metabases);
        self->objc.metaclass->storage_class |= STCstatic;
        self->objc.metaclass->objc.objc = true;
        self->objc.metaclass->objc.meta = true;
        self->objc.metaclass->objc.extern_ = self->objc.extern_;
        self->objc.metaclass->objc.ident = self->objc.ident;
        self->members->push(self->objc.metaclass);
        self->objc.metaclass->addMember(sc, self, 1);
    }
}

void objc_ClassDeclaration_semantic_staticInitializers(ClassDeclaration *self, Scope *sc2, size_t members_dim)
{
    if (self->objc.objc && !self->objc.extern_ && !self->objc.meta)
    {
        // Look for static initializers to create initializing function if needed
        Expression *inite = NULL;
        for (size_t i = 0; i < members_dim; i++)
        {
            VarDeclaration *vd = ((Dsymbol *)self->members->data[i])->isVarDeclaration();
            if (vd && vd->toParent() == self &&
                ((vd->init && !vd->init->isVoidInitializer()) && (vd->init || !vd->getType()->isZeroInit())))
            {
                Expression *thise = new ThisExp(vd->loc);
                thise->type = self->type;
                Expression *ie = vd->init->toExpression();
                if (!ie)
                    ie = vd->type->defaultInit(self->loc);
                if (!ie)
                    continue; // skip
                Expression *ve = new DotVarExp(vd->loc, thise, vd);
                ve->type = vd->type;
                Expression *e = new AssignExp(vd->loc, ve, ie);
                e->op = TOKblit;
                e->type = ve->type;
                inite = inite ? new CommaExp(self->loc, inite, e) : e;
            }
        }

        TypeFunction *tf = new TypeFunction(new Parameters, self->type, 0, LINKd);
        FuncDeclaration *initfd = self->findFunc(Id::_dobjc_preinit, tf);

        if (inite)
        {
            // we have static initializers, need to create any '_dobjc_preinit' instance
            // method to handle them.
            FuncDeclaration *newinitfd = new FuncDeclaration(self->loc, self->loc, Id::_dobjc_preinit, STCundefined, tf);
            Expression *retvale;
            if (initfd)
            {
                // call _dobjc_preinit in superclass
                retvale = new CallExp(self->loc, new DotIdExp(self->loc, new SuperExp(self->loc), Id::_dobjc_preinit));
                retvale->type = self->type;
            }
            else
            {
                // no _dobjc_preinit to call in superclass, just return this
                retvale = new ThisExp(self->loc);
                retvale->type = self->type;
            }
            newinitfd->fbody = new ReturnStatement(self->loc, new CommaExp(self->loc, inite, retvale));
            self->members->push(newinitfd);
            newinitfd->addMember(sc2, self, 1);
            newinitfd->semantic(sc2);

            // replace initfd for next step
            initfd = newinitfd;
        }

        if (initfd)
        {
            // replace alloc functions with stubs ending with a call to _dobjc_preinit
            // this is done by the backend glue in objc.c, we just need to set a flag
            self->objc.hasPreinit = true;
        }
    }
}

void objc_ClassDeclaration_semantic_invariant(ClassDeclaration *self, Scope *sc2)
{
    if (self->objc.objc && !self->objc.extern_ && !self->objc.meta)
    {
        // invariant for Objective-C class is handled by adding a _dobjc_invariant
        // dynamic method calling the invariant function and then the parent's
        // _dobjc_invariant if applicable.
        if (self->invs.dim > 0)
        {
            Loc iloc = self->inv->loc;
            TypeFunction *invtf = new TypeFunction(new Parameters, Type::tvoid, 0, LINKobjc);
            FuncDeclaration *invfd = self->findFunc(Id::_dobjc_invariant, invtf);

            // create dynamic dispatch handler for invariant
            FuncDeclaration *newinvfd = new FuncDeclaration(iloc, iloc, Id::_dobjc_invariant, STCundefined, invtf);
            if (self->baseClass && self->baseClass->inv)
                newinvfd->storage_class |= STCoverride;

            Expression *e;
            e = new DsymbolExp(iloc, self->inv);
            e = new CallExp(iloc, e);
            if (invfd)
            {   // call super's _dobjc_invariant
                e = new CommaExp(iloc, e, new CallExp(iloc, new DotIdExp(iloc, new SuperExp(iloc), Id::_dobjc_invariant)));
            }
            newinvfd->fbody = new ExpStatement(iloc, e);
            self->members->push(newinvfd);
            newinvfd->addMember(sc2, self, 1);
            newinvfd->semantic(sc2);
        }
    }
}

void objc_InterfaceDeclaration_semantic_objcExtern(InterfaceDeclaration *self, Scope *sc)
{
    if (sc->linkage == LINKobjc)
    {
#if DMD_OBJC
        self->objc.objc = true;
        // In the abscense of a better solution, classes with Objective-C linkage
        // are only a declaration. A class that derives from one with Objective-C
        // linkage but which does not have Objective-C linkage itself will
        // generate a definition in the object file.
        self->objc.extern_ = true; // this one is only a declaration

        if (!self->objc.ident)
            self->objc.ident = self->ident;
#else
        self->error("Objective-C interfaces not supported");
#endif
    }
}

ControlFlow objc_InterfaceDeclaration_semantic_mixingObjc(InterfaceDeclaration *self, Scope *sc, size_t i, TypeClass *tc)
{
    // Check for mixin Objective-C and non-Objective-C interfaces
    if (!self->objc.objc && tc->sym->objc.objc)
    {
        if (i == 0)
        {
            // This is the first -- there's no non-Objective-C interface before this one.
            // Implicitly switch this interface to Objective-C.
            self->objc.objc = true;
        }
        else
            goto Lobjcmix; // same error as below
    }
    else if (self->objc.objc && !tc->sym->objc.objc)
    {
    Lobjcmix:
        self->error("cannot mix Objective-C and non-Objective-C interfaces");
        self->baseclasses->remove(i);
        return CFcontinue;
    }

    return CFnone;
}

void objc_InterfaceDeclaration_semantic_createMetaclass(InterfaceDeclaration *self, Scope *sc)
{
    if (self->objc.objc && !self->objc.meta && !self->objc.metaclass)
    {   // Create meta class derived from all our base's metaclass
        BaseClasses *metabases = new BaseClasses();
        for (size_t i = 0; i < self->baseclasses->dim; ++i)
        {
            ClassDeclaration *basecd = ((BaseClass *)self->baseclasses->data[i])->base;
            assert(basecd);
            InterfaceDeclaration *baseid = basecd->isInterfaceDeclaration();
            assert(baseid);
            if (baseid->objc.objc)
            {
                assert(baseid->objc.metaclass);
                assert(baseid->objc.metaclass->objc.meta);
                assert(baseid->objc.metaclass->type->ty == Tclass);
                assert(((TypeClass *)baseid->objc.metaclass->type)->sym == baseid->objc.metaclass);
                BaseClass *metabase = new BaseClass(baseid->objc.metaclass->type, PROTpublic);
                metabase->base = baseid->objc.metaclass;
                metabases->push(metabase);
            }
            else
                self->error("base interfaces for an Objective-C interface must be extern (Objective-C)");
        }
        self->objc.metaclass = new InterfaceDeclaration(self->loc, Id::Class, metabases);
        self->objc.metaclass->storage_class |= STCstatic;
        self->objc.metaclass->objc.objc = true;
        self->objc.metaclass->objc.meta = true;
        self->objc.metaclass->objc.extern_ = self->objc.extern_;
        self->objc.metaclass->objc.ident = self->objc.ident;
        self->


        members->push(self->objc.metaclass);
        self->objc.metaclass->addMember(sc, self, 1);
    }
}
