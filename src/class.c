
// Compiler implementation of the D programming language
// Copyright (c) 1999-2013 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>                     // mem{cpy|set}()

#include "root.h"
#include "rmem.h"
#include "target.h"

#include "enum.h"
#include "init.h"
#include "attrib.h"
#include "declaration.h"
#include "aggregate.h"
#include "id.h"
#include "mtype.h"
#include "scope.h"
#include "module.h"
#include "expression.h"
#include "statement.h"
#include "template.h"

/********************************* ClassDeclaration ****************************/

ClassDeclaration *ClassDeclaration::object;
ClassDeclaration *ClassDeclaration::throwable;
#if DMD_OBJC
ClassDeclaration *ClassDeclaration::objcthrowable;
#endif
ClassDeclaration *ClassDeclaration::exception;
ClassDeclaration *ClassDeclaration::errorException;

ClassDeclaration::ClassDeclaration(Loc loc, Identifier *id, BaseClasses *baseclasses, bool inObject)
    : AggregateDeclaration(loc, id)
{
    static const char msg[] = "only object.d can define this reserved class name";

    if (baseclasses)
        // Actually, this is a transfer
        this->baseclasses = baseclasses;
    else
        this->baseclasses = new BaseClasses();
    baseClass = NULL;

    interfaces_dim = 0;
    interfaces = NULL;

    vtblInterfaces = NULL;

    //printf("ClassDeclaration(%s), dim = %d\n", id->toChars(), this->baseclasses->dim);

    // For forward references
    type = new TypeClass(this);
    handle = type;

    staticCtor = NULL;
    staticDtor = NULL;

    vtblsym = NULL;
    vclassinfo = NULL;

#if DMD_OBJC
    objc = 0;
    objcmeta = 0;
    objcextern = 0;
    objctakestringliteral = 0;
    objcident = NULL;
    sobjccls = NULL;
    objcMethods = NULL;
    metaclass = NULL;
    objchaspreinit = 0;
#endif

    if (id)
    {   // Look for special class names

        if (id == Id::__sizeof || id == Id::__xalignof || id == Id::mangleof)
            error("illegal class name");

        // BUG: What if this is the wrong TypeInfo, i.e. it is nested?
        if (id->toChars()[0] == 'T')
        {
            if (id == Id::TypeInfo)
            {   if (!inObject)
                    error("%s", msg);
                Type::dtypeinfo = this;
            }

            if (id == Id::TypeInfo_Class)
            {   if (!inObject)
                    error("%s", msg);
                Type::typeinfoclass = this;
            }

            if (id == Id::TypeInfo_Interface)
            {   if (!inObject)
                    error("%s", msg);
                Type::typeinfointerface = this;
            }

            if (id == Id::TypeInfo_Struct)
            {   if (!inObject)
                    error("%s", msg);
                Type::typeinfostruct = this;
            }

            if (id == Id::TypeInfo_Typedef)
            {   if (!inObject)
                    error("%s", msg);
                Type::typeinfotypedef = this;
            }

            if (id == Id::TypeInfo_Pointer)
            {   if (!inObject)
                    error("%s", msg);
                Type::typeinfopointer = this;
            }

            if (id == Id::TypeInfo_Array)
            {   if (!inObject)
                    error("%s", msg);
                Type::typeinfoarray = this;
            }

            if (id == Id::TypeInfo_StaticArray)
            {   //if (!inObject)
                    //Type::typeinfostaticarray->error("%s", msg);
                Type::typeinfostaticarray = this;
            }

            if (id == Id::TypeInfo_AssociativeArray)
            {   if (!inObject)
                    error("%s", msg);
                Type::typeinfoassociativearray = this;
            }

            if (id == Id::TypeInfo_Enum)
            {   if (!inObject)
                    error("%s", msg);
                Type::typeinfoenum = this;
            }

            if (id == Id::TypeInfo_Function)
            {   if (!inObject)
                    error("%s", msg);
                Type::typeinfofunction = this;
            }

            if (id == Id::TypeInfo_Delegate)
            {   if (!inObject)
                    error("%s", msg);
                Type::typeinfodelegate = this;
            }

            if (id == Id::TypeInfo_Tuple)
            {   if (!inObject)
                    error("%s", msg);
                Type::typeinfotypelist = this;
            }

            if (id == Id::TypeInfo_Const)
            {   if (!inObject)
                    error("%s", msg);
                Type::typeinfoconst = this;
            }

            if (id == Id::TypeInfo_Invariant)
            {   if (!inObject)
                    error("%s", msg);
                Type::typeinfoinvariant = this;
            }

            if (id == Id::TypeInfo_Shared)
            {   if (!inObject)
                    error("%s", msg);
                Type::typeinfoshared = this;
            }

            if (id == Id::TypeInfo_Wild)
            {   if (!inObject)
                    error("%s", msg);
                Type::typeinfowild = this;
            }

            if (id == Id::TypeInfo_Vector)
            {   if (!inObject)
                    error("%s", msg);
                Type::typeinfovector = this;
            }
        }

        if (id == Id::Object)
        {   if (!inObject)
                error("%s", msg);
            object = this;
        }

        if (id == Id::Throwable)
        {   if (!inObject)
                error("%s", msg);
            throwable = this;
        }

#if DMD_OBJC
        if (id == Id::ObjcThrowable)
        {   if (objcthrowable)
                objcthrowable->error("%s", msg);
            objcthrowable = this;
        }
#endif

        if (id == Id::Exception)
        {   if (!inObject)
                error("%s", msg);
            exception = this;
        }

        if (id == Id::Error)
        {   if (!inObject)
                error("%s", msg);
            errorException = this;
        }
    }

    com = 0;
    cpp = 0;
    isscope = 0;
    isabstract = 0;
    inuse = 0;
    doAncestorsSemantic = SemanticStart;
}

Dsymbol *ClassDeclaration::syntaxCopy(Dsymbol *s)
{
    ClassDeclaration *cd;

    //printf("ClassDeclaration::syntaxCopy('%s')\n", toChars());
    if (s)
        cd = (ClassDeclaration *)s;
    else
        cd = new ClassDeclaration(loc, ident, NULL);

    cd->storage_class |= storage_class;

    cd->baseclasses->setDim(this->baseclasses->dim);
    for (size_t i = 0; i < cd->baseclasses->dim; i++)
    {
        BaseClass *b = (*this->baseclasses)[i];
        BaseClass *b2 = new BaseClass(b->type->syntaxCopy(), b->protection);
        (*cd->baseclasses)[i] = b2;
    }

    ScopeDsymbol::syntaxCopy(cd);
    return cd;
}

void ClassDeclaration::semantic(Scope *sc)
{
    //printf("ClassDeclaration::semantic(%s), type = %p, sizeok = %d, this = %p\n", toChars(), type, sizeok, this);
    //printf("\tparent = %p, '%s'\n", sc->parent, sc->parent ? sc->parent->toChars() : "");
    //printf("sc->stc = %x\n", sc->stc);

    //{ static int n;  if (++n == 20) *(char*)0=0; }

    if (!ident)         // if anonymous class
    {   const char *id = "__anonclass";

        ident = Identifier::generateId(id);
    }

    if (!sc)
        sc = scope;
    if (!parent && sc->parent && !sc->parent->isModule())
        parent = sc->parent;

    type = type->semantic(loc, sc);
    handle = type;

    if (!members)               // if opaque declaration
    {   //printf("\tclass '%s' is forward referenced\n", toChars());
        return;
    }
    if (symtab)
    {   if (sizeok == SIZEOKdone || !scope)
        {   //printf("\tsemantic for '%s' is already completed\n", toChars());
            return;             // semantic() already completed
        }
    }
    else
        symtab = new DsymbolTable();

    Scope *scx = NULL;
    if (scope)
    {
        sc = scope;
        scx = scope;            // save so we don't make redundant copies
        scope = NULL;
    }
    unsigned dprogress_save = Module::dprogress;
    int errors = global.errors;

    if (sc->stc & STCdeprecated)
    {
        isdeprecated = true;
    }
    userAttributes = sc->userAttributes;

    if (sc->linkage == LINKcpp)
        cpp = 1;
    if (sc->linkage == LINKobjc)
    {
#if DMD_OBJC
        objc = 1;
        objcextern = 1;
#else
        error("Objective-C classes not supported");
#endif
    }

    // Expand any tuples in baseclasses[]
    for (size_t i = 0; i < baseclasses->dim; )
    {
        // Ungag errors when not speculative
        Ungag ungag = ungagSpeculative();

        BaseClass *b = (*baseclasses)[i];
        b->type = b->type->semantic(loc, sc);

        Type *tb = b->type->toBasetype();
        if (tb->ty == Ttuple)
        {   TypeTuple *tup = (TypeTuple *)tb;
            PROT protection = b->protection;
            baseclasses->remove(i);
            size_t dim = Parameter::dim(tup->arguments);
            for (size_t j = 0; j < dim; j++)
            {   Parameter *arg = Parameter::getNth(tup->arguments, j);
                b = new BaseClass(arg->type, protection);
                baseclasses->insert(i + j, b);
            }
        }
        else
            i++;
    }

    // See if there's a base class as first in baseclasses[]
    if (baseclasses->dim)
    {
        // Ungag errors when not speculative
        Ungag ungag = ungagSpeculative();

        BaseClass *b = (*baseclasses)[0];
        //b->type = b->type->semantic(loc, sc);

        Type *tb = b->type->toBasetype();
        if (tb->ty != Tclass)
        {
            if (b->type != Type::terror)
                error("base type must be class or interface, not %s", b->type->toChars());
            baseclasses->remove(0);
        }
        else
        {
            TypeClass *tc = (TypeClass *)(tb);

            if (tc->sym->isDeprecated())
            {
                if (!isDeprecated())
                {
                    // Deriving from deprecated class makes this one deprecated too
                    isdeprecated = true;

                    tc->checkDeprecated(loc, sc);
                }
            }

            if (tc->sym->isInterfaceDeclaration())
                ;
            else
            {
                for (ClassDeclaration *cdb = tc->sym; cdb; cdb = cdb->baseClass)
                {
                    if (cdb == this)
                    {
                        error("circular inheritance");
                        baseclasses->remove(0);
                        goto L7;
                    }
                }
                if (tc->sym->scope)
                {
                    // Try to resolve forward reference
                    tc->sym->semantic(NULL);
                }

                if (tc->sym->symtab && tc->sym->scope == NULL)
                {
                    /* Bugzilla 11034: Essentailly, class inheritance hierarchy
                     * and instance size of each classes are orthogonal information.
                     * Therefore, even if tc->sym->sizeof == SIZEOKnone,
                     * we need to set baseClass field for class covariance check.
                     */
                    baseClass = tc->sym;
                    b->base = baseClass;
                }
                if (!tc->sym->symtab || tc->sym->scope || tc->sym->sizeok == SIZEOKnone)
                {
                    //printf("%s: forward reference of base class %s\n", toChars(), tc->sym->toChars());
                    //error("forward reference of base class %s", baseClass->toChars());
                    // Forward reference of base class, try again later
                    //printf("\ttry later, forward reference of base class %s\n", tc->sym->toChars());
                    scope = scx ? scx : new Scope(*sc);
                    scope->setNoFree();
                    if (tc->sym->scope)
                        tc->sym->scope->module->addDeferredSemantic(tc->sym);
                    scope->module->addDeferredSemantic(this);
                    return;
                }
             L7: ;
            }
        }
    }

    // Treat the remaining entries in baseclasses as interfaces
    // Check for errors, handle forward references
    for (size_t i = (baseClass ? 1 : 0); i < baseclasses->dim; )
    {
        // Ungag errors when not speculative
        Ungag ungag = ungagSpeculative();

        BaseClass *b = (*baseclasses)[i];
        b->type = b->type->semantic(loc, sc);

        Type *tb = b->type->toBasetype();
        TypeClass *tc = (tb->ty == Tclass) ? (TypeClass *)tb : NULL;
        if (!tc || !tc->sym->isInterfaceDeclaration())
        {
            if (b->type != Type::terror)
                error("base type must be interface, not %s", b->type->toChars());
            baseclasses->remove(i);
            continue;
        }
        else
        {
            if (tc->sym->isDeprecated())
            {
                if (!isDeprecated())
                {
                    // Deriving from deprecated class makes this one deprecated too
                    isdeprecated = true;

                    tc->checkDeprecated(loc, sc);
                }
            }

            // Check for duplicate interfaces
            for (size_t j = (baseClass ? 1 : 0); j < i; j++)
            {
                BaseClass *b2 = (*baseclasses)[j];
                if (b2->base == tc->sym)
                    error("inherits from duplicate interface %s", b2->base->toChars());
            }

            if (tc->sym->scope)
            {
                // Try to resolve forward reference
                tc->sym->semantic(NULL);
            }

            b->base = tc->sym;
            if (!b->base->symtab || b->base->scope)
            {
                //error("forward reference of base class %s", baseClass->toChars());
                // Forward reference of base, try again later
                //printf("\ttry later, forward reference of base %s\n", baseClass->toChars());
                scope = scx ? scx : new Scope(*sc);
                scope->setNoFree();
                if (tc->sym->scope)
                    tc->sym->scope->module->addDeferredSemantic(tc->sym);
                scope->module->addDeferredSemantic(this);
                return;
            }
        }
        i++;
    }
    if (doAncestorsSemantic == SemanticIn)
        doAncestorsSemantic = SemanticDone;


    if (sizeok == SIZEOKnone)
    {
#if DMD_OBJC
        if (objc || (baseClass && baseClass->objc))
            objc = 1; // Objective-C classes do not inherit from Object
        else
#endif
        // If no base class, and this is not an Object, use Object as base class
        if (!baseClass && ident != Id::Object && !cpp)
        {
            if (!object)
            {
                error("missing or corrupt object.d");
                fatal();
            }

            Type *t = object->type;
            t = t->semantic(loc, sc)->toBasetype();
            assert(t->ty == Tclass);
            TypeClass *tc = (TypeClass *)t;

            BaseClass *b = new BaseClass(tc, PROTpublic);
            baseclasses->shift(b);

            baseClass = tc->sym;
            assert(!baseClass->isInterfaceDeclaration());
            b->base = baseClass;
        }

        interfaces_dim = baseclasses->dim;
        interfaces = baseclasses->tdata();

#if DMD_OBJC
        if (objc && !objcmeta && !metaclass)
        {
            if (!objcident)
                objcident = ident;

            if (objcident == Id::Protocol)
            {   if (ObjcProtocolOfExp::protocolClassDecl == NULL)
                ObjcProtocolOfExp::protocolClassDecl = this;
            else if (ObjcProtocolOfExp::protocolClassDecl != this)
            {   error("duplicate definition of Objective-C class '%s'", Id::Protocol);
            }
            }

            // Create meta class derived from all our base's metaclass
            BaseClasses *metabases = new BaseClasses();
            for (size_t i = 0; i < baseclasses->dim; ++i)
            {   ClassDeclaration *basecd = ((BaseClass *)baseclasses->data[i])->base;
                assert(basecd);
                if (basecd->objc)
                {   assert(basecd->metaclass);
                    assert(basecd->metaclass->objcmeta);
                    assert(basecd->metaclass->type->ty == Tclass);
                    assert(((TypeClass *)basecd->metaclass->type)->sym == basecd->metaclass);
                    BaseClass *metabase = new BaseClass(basecd->metaclass->type, PROTpublic);
                    metabase->base = basecd->metaclass;
                    metabases->push(metabase);
                }
                else
                    error("base class and interfaces for an Objective-C class must be extern (Objective-C)");
            }
            metaclass = new ClassDeclaration(loc, Id::Class, metabases);
            metaclass->storage_class |= STCstatic;
            metaclass->objc = 1;
            metaclass->objcmeta = 1;
            metaclass->objcextern = objcextern;
            metaclass->objcident = objcident;
            members->push(metaclass);
            metaclass->addMember(sc, this, 1);
        }
#endif

        if (baseClass)
        {
            if (baseClass->storage_class & STCfinal)
                error("cannot inherit from final class %s", baseClass->toChars());

            interfaces_dim--;
            interfaces++;

            // Copy vtbl[] from base class
            vtbl.setDim(baseClass->vtbl.dim);
            memcpy(vtbl.tdata(), baseClass->vtbl.tdata(), sizeof(void *) * vtbl.dim);

            // Inherit properties from base class
            com = baseClass->isCOMclass();
            if (baseClass->isCPPclass())
                cpp = 1;
            isscope = baseClass->isscope;
            vthis = baseClass->vthis;
            enclosing = baseClass->enclosing;
            storage_class |= baseClass->storage_class & STC_TYPECTOR;
        }
        else
        {
            // No base class, so this is the root of the class hierarchy
            vtbl.setDim(0);
            if (vtblOffset())
                vtbl.push(this);            // leave room for classinfo as first member
        }

        protection = sc->protection;
        storage_class |= sc->stc;

        interfaceSemantic(sc);

        for (size_t i = 0; i < members->dim; i++)
        {
            Dsymbol *s = (*members)[i];
            s->addMember(sc, this, 1);
        }

        /* If this is a nested class, add the hidden 'this'
         * member which is a pointer to the enclosing scope.
         */
        if (vthis)              // if inheriting from nested class
        {
            // Use the base class's 'this' member
            if (storage_class & STCstatic)
                error("static class cannot inherit from nested class %s", baseClass->toChars());
            if (toParent2() != baseClass->toParent2() &&
                (!toParent2() ||
                 !baseClass->toParent2()->getType() ||
                 !baseClass->toParent2()->getType()->isBaseOf(toParent2()->getType(), NULL)))
            {
                if (toParent2())
                {
                    error("is nested within %s, but super class %s is nested within %s",
                        toParent2()->toChars(),
                        baseClass->toChars(),
                        baseClass->toParent2()->toChars());
                }
                else
                {
                    error("is not nested, but super class %s is nested within %s",
                        baseClass->toChars(),
                        baseClass->toParent2()->toChars());
                }
                enclosing = NULL;
            }
        }
        else
            makeNested();

        if (storage_class & STCauto)
            error("storage class 'auto' is invalid when declaring a class, did you mean to use 'scope'?");
        if (storage_class & STCscope)
            isscope = 1;
        if (storage_class & STCabstract)
            isabstract = 1;
    }

    sc = sc->push(this);
    //sc->stc &= ~(STCfinal | STCauto | STCscope | STCstatic | STCabstract | STCdeprecated | STC_TYPECTOR | STCtls | STCgshared);
    //sc->stc |= storage_class & STC_TYPECTOR;
    sc->stc &= STCsafe | STCtrusted | STCsystem;
    sc->parent = this;
    sc->inunion = 0;
    if (isCOMclass())
    {
        if (global.params.isWindows)
            sc->linkage = LINKwindows;
        else
            /* This enables us to use COM objects under Linux and
             * work with things like XPCOM
             */
            sc->linkage = LINKc;
    }
#if DMD_OBJC
    else if (objc)
    {
        sc->linkage = LINKobjc;
    }
#endif
    sc->protection = PROTpublic;
    sc->explicitProtection = 0;
    sc->structalign = STRUCTALIGN_DEFAULT;
    if (baseClass)
    {
        sc->offset = baseClass->structsize;
        alignsize = baseClass->alignsize;
        sc->offset = (sc->offset + alignsize - 1) & ~(alignsize - 1);
//      if (enclosing)
//          sc->offset += Target::ptrsize;      // room for uplevel context pointer
    }
#if DMD_OBJC
    else if (objc)
    {   sc->offset = 0; // no hidden member for an Objective-C class
    }
#endif
    else
    {
        if (cpp)
            sc->offset = Target::ptrsize;       // allow room for __vptr
        else
            sc->offset = Target::ptrsize * 2;   // allow room for __vptr and __monitor
        alignsize = Target::ptrsize;
    }
    sc->userAttributes = NULL;
    structsize = sc->offset;
    Scope scsave = *sc;
    size_t members_dim = members->dim;
    sizeok = SIZEOKnone;
#if DMD_OBJC
    if (metaclass)
        metaclass->members = new Dsymbols();
#endif

    /* Set scope so if there are forward references, we still might be able to
     * resolve individual members like enums.
     */
    for (size_t i = 0; i < members_dim; i++)
    {
        Dsymbol *s = (*members)[i];
        //printf("[%d] setScope %s %s, sc = %p\n", i, s->kind(), s->toChars(), sc);
        s->setScope(sc);
    }

    for (size_t i = 0; i < members_dim; i++)
    {
        Dsymbol *s = (*members)[i];

        // Ungag errors when not speculative
        Ungag ungag = ungagSpeculative();
        s->semantic(sc);
    }

    // Set the offsets of the fields and determine the size of the class

    unsigned offset = structsize;
    for (size_t i = 0; i < members->dim; i++)
    {
        Dsymbol *s = (*members)[i];
        s->setFieldOffset(this, &offset, false);
    }
    sc->offset = structsize;

    if (global.errors != errors)
    {
        // The type is no good.
        type = Type::terror;
    }

    if (sizeok == SIZEOKfwd)            // failed due to forward references
    {
        // semantic() failed due to forward references
        // Unwind what we did, and defer it for later
        for (size_t i = 0; i < fields.dim; i++)
        {
            VarDeclaration *v = fields[i];
            v->offset = 0;
        }
        fields.setDim(0);
        structsize = 0;
        alignsize = 0;
//        structalign = 0;
#if DMD_OBJC
        if (metaclass)
            metaclass->members = NULL;
#endif

        sc = sc->pop();

        scope = scx ? scx : new Scope(*sc);
        scope->setNoFree();
        scope->module->addDeferredSemantic(this);

        Module::dprogress = dprogress_save;

        //printf("\tsemantic('%s') failed due to forward references\n", toChars());
        return;
    }

    //printf("\tsemantic('%s') successful\n", toChars());

    //members->print();

#if DMD_OBJC
	if (objc && !objcextern && !objcmeta)
	{	// Look for static initializers to create initializing function if needed
		Expression *inite = NULL;
		for (size_t i = 0; i < members_dim; i++)
		{
			VarDeclaration *vd = ((Dsymbol *)members->data[i])->isVarDeclaration();
			if (vd && vd->toParent() == this &&
				((vd->init && !vd->init->isVoidInitializer()) && (vd->init || !vd->getType()->isZeroInit())))
			{
				Expression *thise = new ThisExp(vd->loc);
				thise->type = type;
				Expression *ie = vd->init->toExpression();
				if (!ie)
					ie = vd->type->defaultInit(loc);
				if (!ie)
					continue; // skip
				Expression *ve = new DotVarExp(vd->loc, thise, vd);
				ve->type = vd->type;
				Expression *e = new AssignExp(vd->loc, ve, ie);
				e->op = TOKblit;
				e->type = ve->type;
				inite = inite ? new CommaExp(loc, inite, e) : e;
			}
		}

		TypeFunction *tf = new TypeFunction(new Parameters, type, 0, LINKd);
		FuncDeclaration *initfd = findFunc(Id::_dobjc_preinit, tf);

		if (inite)
		{   // we have static initializers, need to create any '_dobjc_preinit' instance
			// method to handle them.
			FuncDeclaration *newinitfd = new FuncDeclaration(loc, loc, Id::_dobjc_preinit, STCundefined, tf);
			Expression *retvale;
			if (initfd)
			{	// call _dobjc_preinit in superclass
				retvale = new CallExp(loc, new DotIdExp(loc, new SuperExp(loc), Id::_dobjc_preinit));
				retvale->type = type;
			}
			else
			{	// no _dobjc_preinit to call in superclass, just return this
				retvale = new ThisExp(loc);
				retvale->type = type;
			}
			newinitfd->fbody = new ReturnStatement(loc, new CommaExp(loc, inite, retvale));
			members->push(newinitfd);
			newinitfd->addMember(sc, this, 1);
			newinitfd->semantic(sc);

			// replace initfd for next step
			initfd = newinitfd;
		}

		if (initfd)
		{	// replace alloc functions with stubs ending with a call to _dobjc_preinit
            // this is done by the backend glue in objc.c, we just need to set a flag
            objchaspreinit = 1;
		}

        // invariant for Objective-C class is handled by adding a _dobjc_invariant
        // dynamic method calling the invariant function and then the parent's
        // _dobjc_invariant if applicable.
        if (inv)
        {
            Loc iloc = inv->loc;
            TypeFunction *invtf = new TypeFunction(new Parameters, Type::tvoid, 0, LINKobjc);
            FuncDeclaration *invfd = findFunc(Id::_dobjc_invariant, invtf);

            // create dynamic dispatch handler for invariant
			FuncDeclaration *newinvfd = new FuncDeclaration(iloc, iloc, Id::_dobjc_invariant, STCundefined, invtf);

            Expression *e;
            e = new DsymbolExp(iloc, inv);
            e = new CallExp(iloc, e);
            if (invfd)
            {   // call super's _dobjc_invariant
                e = new CommaExp(iloc, e, new CallExp(iloc, new DotIdExp(iloc, new SuperExp(iloc), Id::_dobjc_invariant)));
            }
			newinvfd->fbody = new ExpStatement(iloc, e);
			members->push(newinvfd);
			newinvfd->addMember(sc, this, 1);
			newinvfd->semantic(sc);
        }
	}
#endif

    /* Look for special member functions.
     * They must be in this class, not in a base class.
     */
    searchCtor();
    if (ctor && (ctor->toParent() != this || !(ctor->isCtorDeclaration() || ctor->isTemplateDeclaration())))
        ctor = NULL;    // search() looks through ancestor classes
    if (!ctor && noDefaultCtor)
    {
        // A class object is always created by constructor, so this check is legitimate.
        for (size_t i = 0; i < fields.dim; i++)
        {
            VarDeclaration *v = fields[i];
            if (v->storage_class & STCnodefaultctor)
                ::error(v->loc, "field %s must be initialized in constructor", v->toChars());
        }
    }

    inv = buildInv(sc);

    // Can be in base class
    aggNew    =    (NewDeclaration *)search(Loc(), Id::classNew);
    aggDelete = (DeleteDeclaration *)search(Loc(), Id::classDelete);

    // If this class has no constructor, but base class has a default
    // ctor, create a constructor:
    //    this() { }
    if (!ctor && baseClass && baseClass->ctor)
    {
        if (FuncDeclaration *fd = resolveFuncCall(loc, sc, baseClass->ctor, NULL, NULL, NULL, 1))
        {
            //printf("Creating default this(){} for class %s\n", toChars());
            TypeFunction *btf = (TypeFunction *)fd->type;
            TypeFunction *tf = new TypeFunction(NULL, NULL, 0, LINKd, fd->storage_class);
            tf->purity = btf->purity;
            tf->isnothrow = btf->isnothrow;
            tf->trust = btf->trust;
            CtorDeclaration *ctor = new CtorDeclaration(loc, Loc(), 0, tf);
            ctor->fbody = new CompoundStatement(Loc(), new Statements());
            members->push(ctor);
            ctor->addMember(sc, this, 1);
            *sc = scsave;   // why? What about sc->nofree?
            ctor->semantic(sc);
            this->ctor = ctor;
            defaultCtor = ctor;
        }
        else
        {
            error("Cannot implicitly generate a default ctor when base class %s is missing a default ctor", baseClass->toPrettyChars());
        }
    }

#if 0
    if (baseClass)
    {   if (!aggDelete)
            aggDelete = baseClass->aggDelete;
        if (!aggNew)
            aggNew = baseClass->aggNew;
    }
#endif

    // Allocate instance of each new interface
    sc->offset = structsize;
    for (size_t i = 0; i < vtblInterfaces->dim; i++)
    {
        BaseClass *b = (*vtblInterfaces)[i];
        unsigned thissize = Target::ptrsize;

        alignmember(STRUCTALIGN_DEFAULT, thissize, &sc->offset);
        assert(b->offset == 0);
        b->offset = sc->offset;

        // Take care of single inheritance offsets
        while (b->baseInterfaces_dim)
        {
            b = &b->baseInterfaces[0];
            b->offset = sc->offset;
        }

        sc->offset += thissize;
        if (alignsize < thissize)
            alignsize = thissize;
    }
    structsize = sc->offset;
    sizeok = SIZEOKdone;
    Module::dprogress++;

    dtor = buildDtor(sc);
    if (FuncDeclaration *f = hasIdentityOpAssign(sc))
    {
        if (!(f->storage_class & STCdisable))
            error(f->loc, "identity assignment operator overload is illegal");
    }
#if DMD_OBJC
//    if (metaclass)
//        metaclass->semantic(sc);
#endif
    sc->pop();

#if 0 // Do not call until toObjfile() because of forward references
    // Fill in base class vtbl[]s
    for (i = 0; i < vtblInterfaces->dim; i++)
    {
        BaseClass *b = (*vtblInterfaces)[i];

        //b->fillVtbl(this, &b->vtbl, 1);
    }
#endif
    //printf("-ClassDeclaration::semantic(%s), type = %p\n", toChars(), type);

    if (deferred && !global.gag)
    {
        deferred->semantic2(sc);
        deferred->semantic3(sc);
    }

    if (type->ty == Tclass && ((TypeClass *)type)->sym != this)
    {
        error("failed semantic analysis");
        this->errors = true;
        type = Type::terror;
    }
}

void ClassDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    if (!isAnonymous())
    {
        buf->printf("%s ", kind());
        buf->writestring(toChars());
        if (baseclasses->dim)
            buf->writestring(" : ");
    }
    for (size_t i = 0; i < baseclasses->dim; i++)
    {
        BaseClass *b = (*baseclasses)[i];

        if (i)
            buf->writestring(", ");
        //buf->writestring(b->base->ident->toChars());
        b->type->toCBuffer(buf, NULL, hgs);
    }
    if (members)
    {
        buf->writenl();
        buf->writeByte('{');
        buf->writenl();
        buf->level++;
        for (size_t i = 0; i < members->dim; i++)
        {
            Dsymbol *s = (*members)[i];
            s->toCBuffer(buf, hgs);
        }
        buf->level--;
        buf->writestring("}");
    }
    else
        buf->writeByte(';');
    buf->writenl();
}

#if 0
void ClassDeclaration::defineRef(Dsymbol *s)
{
    ClassDeclaration *cd;

    AggregateDeclaration::defineRef(s);
    cd = s->isClassDeclaration();
    baseType = cd->baseType;
    cd->baseType = NULL;
}
#endif

/*********************************************
 * Determine if 'this' is a base class of cd.
 * This is used to detect circular inheritance only.
 */

int ClassDeclaration::isBaseOf2(ClassDeclaration *cd)
{
    if (!cd)
        return 0;
    //printf("ClassDeclaration::isBaseOf2(this = '%s', cd = '%s')\n", toChars(), cd->toChars());
    for (size_t i = 0; i < cd->baseclasses->dim; i++)
    {   BaseClass *b = (*cd->baseclasses)[i];

        if (b->base == this || isBaseOf2(b->base))
            return 1;
    }
    return 0;
}

/*******************************************
 * Determine if 'this' is a base class of cd.
 */

int ClassDeclaration::isBaseOf(ClassDeclaration *cd, int *poffset)
{
    //printf("ClassDeclaration::isBaseOf(this = '%s', cd = '%s')\n", toChars(), cd->toChars());
    if (poffset)
        *poffset = 0;
    while (cd)
    {
        /* cd->baseClass might not be set if cd is forward referenced.
         */
        if (!cd->baseClass && cd->scope && !cd->isInterfaceDeclaration())
        {
            cd->semantic(NULL);
            if (!cd->baseClass && cd->scope)
                cd->error("base class is forward referenced by %s", toChars());
        }

        if (this == cd->baseClass)
            return 1;

        cd = cd->baseClass;
    }
    return 0;
}

/*********************************************
 * Determine if 'this' has complete base class information.
 * This is used to detect forward references in covariant overloads.
 */

int ClassDeclaration::isBaseInfoComplete()
{
#if DMD_OBJC
    if (objc)
    {}  // skip !baseClass check for Objective-C objects
    else
#endif
    if (!baseClass)
        return ident == Id::Object;
    for (size_t i = 0; i < baseclasses->dim; i++)
    {   BaseClass *b = (*baseclasses)[i];
        if (!b->base || !b->base->isBaseInfoComplete())
            return 0;
    }
    return 1;
}

Dsymbol *ClassDeclaration::search(Loc loc, Identifier *ident, int flags)
{
    Dsymbol *s;
    //printf("%s.ClassDeclaration::search('%s')\n", toChars(), ident->toChars());

    //if (scope) printf("%s doAncestorsSemantic = %d\n", toChars(), doAncestorsSemantic);
    if (scope && doAncestorsSemantic == SemanticStart)
    {
        // must semantic on base class/interfaces
        doAncestorsSemantic = SemanticIn;
        semantic(scope);
        if (doAncestorsSemantic != SemanticDone)
            doAncestorsSemantic = SemanticStart;
    }

    if (!members || !symtab)    // opaque or semantic() is not yet called
    {
        error("is forward referenced when looking for '%s'", ident->toChars());
        //*(char*)0=0;
        return NULL;
    }

    s = ScopeDsymbol::search(loc, ident, flags);
    if (!s)
    {
        // Search bases classes in depth-first, left to right order

        for (size_t i = 0; i < baseclasses->dim; i++)
        {
            BaseClass *b = (*baseclasses)[i];

            if (b->base)
            {
                if (!b->base->symtab)
                    error("base %s is forward referenced", b->base->ident->toChars());
                else
                {
                    s = b->base->search(loc, ident, flags);
                    if (s == this)      // happens if s is nested in this and derives from this
                        s = NULL;
                    else if (s)
                        break;
                }
            }
        }
    }
    return s;
}

ClassDeclaration *ClassDeclaration::searchBase(Loc loc, Identifier *ident)
{
    // Search bases classes in depth-first, left to right order

    for (size_t i = 0; i < baseclasses->dim; i++)
    {
        BaseClass *b = (*baseclasses)[i];
        ClassDeclaration *cdb = b->type->isClassHandle();
        if (!cdb)   // Bugzilla 10616
            return NULL;
        if (cdb->ident->equals(ident))
            return cdb;
        cdb = cdb->searchBase(loc, ident);
        if (cdb)
            return cdb;
    }
    return NULL;
}

/**********************************************************
 * fd is in the vtbl[] for this class.
 * Return 1 if function is hidden (not findable through search).
 */

int isf(void *param, Dsymbol *s)
{
    FuncDeclaration *fd = s->isFuncDeclaration();
    if (!fd)
        return 0;
    //printf("param = %p, fd = %p %s\n", param, fd, fd->toChars());
    return (RootObject *)param == fd;
}

int ClassDeclaration::isFuncHidden(FuncDeclaration *fd)
{
    //printf("ClassDeclaration::isFuncHidden(class = %s, fd = %s)\n", toChars(), fd->toChars());
    Dsymbol *s = search(Loc(), fd->ident, IgnoreAmbiguous | IgnoreErrors);
    if (!s)
    {
        //printf("not found\n");
        /* Because, due to a hack, if there are multiple definitions
         * of fd->ident, NULL is returned.
         */
        return 0;
    }
    s = s->toAlias();
    OverloadSet *os = s->isOverloadSet();
    if (os)
    {
        for (size_t i = 0; i < os->a.dim; i++)
        {
            Dsymbol *s2 = os->a[i];
            FuncDeclaration *f2 = s2->isFuncDeclaration();
            if (f2 && overloadApply(f2, (void *)fd, &isf))
                return 0;
        }
        return 1;
    }
    else
    {
        FuncDeclaration *fdstart = s->isFuncDeclaration();
        //printf("%s fdstart = %p\n", s->kind(), fdstart);
        if (overloadApply(fdstart, (void *)fd, &isf))
            return 0;

        return !fd->parent->isTemplateMixin();
    }
}

/****************
 * Find virtual function matching identifier and type.
 * Used to build virtual function tables for interface implementations.
 */

FuncDeclaration *ClassDeclaration::findFunc(Identifier *ident, TypeFunction *tf)
{
    //printf("ClassDeclaration::findFunc(%s, %s) %s\n", ident->toChars(), tf->toChars(), toChars());
    FuncDeclaration *fdmatch = NULL;
    FuncDeclaration *fdambig = NULL;

    ClassDeclaration *cd = this;
    Dsymbols *vtbl = &cd->vtbl;
    while (1)
    {
        for (size_t i = 0; i < vtbl->dim; i++)
        {
            FuncDeclaration *fd = (*vtbl)[i]->isFuncDeclaration();
            if (!fd)
                continue;               // the first entry might be a ClassInfo

            //printf("\t[%d] = %s\n", i, fd->toChars());
            if (ident == fd->ident &&
                fd->type->covariant(tf) == 1)
            {   //printf("fd->parent->isClassDeclaration() = %p\n", fd->parent->isClassDeclaration());
                if (!fdmatch)
                    goto Lfd;
                if (fd == fdmatch)
                    goto Lfdmatch;

                {
                // Function type matcing: exact > covariant
                MATCH m1 = tf->equals(fd     ->type) ? MATCHexact : MATCHnomatch;
                MATCH m2 = tf->equals(fdmatch->type) ? MATCHexact : MATCHnomatch;
                if (m1 > m2)
                    goto Lfd;
                else if (m1 < m2)
                    goto Lfdmatch;
                }

                {
                MATCH m1 = (tf->mod == fd     ->type->mod) ? MATCHexact : MATCHnomatch;
                MATCH m2 = (tf->mod == fdmatch->type->mod) ? MATCHexact : MATCHnomatch;
                if (m1 > m2)
                    goto Lfd;
                else if (m1 < m2)
                    goto Lfdmatch;
                }

                {
                // The way of definition: non-mixin > mixin
                MATCH m1 = fd     ->parent->isClassDeclaration() ? MATCHexact : MATCHnomatch;
                MATCH m2 = fdmatch->parent->isClassDeclaration() ? MATCHexact : MATCHnomatch;
                if (m1 > m2)
                    goto Lfd;
                else if (m1 < m2)
                    goto Lfdmatch;
                }

            Lambig:
                fdambig = fd;
                //printf("Lambig fdambig = %s %s [%s]\n", fdambig->toChars(), fdambig->type->toChars(), fdambig->loc.toChars());
                continue;

            Lfd:
                fdmatch = fd, fdambig = NULL;
                //printf("Lfd fdmatch = %s %s [%s]\n", fdmatch->toChars(), fdmatch->type->toChars(), fdmatch->loc.toChars());
                continue;

            Lfdmatch:
                continue;
            }
            //else printf("\t\t%d\n", fd->type->covariant(tf));
        }
        if (!cd)
            break;
        vtbl = &cd->vtblFinal;
        cd = cd->baseClass;
    }

    if (fdambig)
        error("ambiguous virtual function %s", fdambig->toChars());
    return fdmatch;
}

void ClassDeclaration::interfaceSemantic(Scope *sc)
{
    InterfaceDeclaration *id = isInterfaceDeclaration();

    vtblInterfaces = new BaseClasses();
    vtblInterfaces->reserve(interfaces_dim);

    for (size_t i = 0; i < interfaces_dim; i++)
    {
        BaseClass *b = interfaces[i];

        // If this is an interface, and it derives from a COM interface,
        // then this is a COM interface too.
        if (b->base->isCOMinterface())
            com = 1;

#if 1
        if (b->base->isCPPinterface() && id)
            id->cpp = 1;
#else
        if (b->base->isCPPinterface())
            cpp = 1;
#endif
        vtblInterfaces->push(b);
        b->copyBaseInterfaces(vtblInterfaces);
    }
}

/****************************************
 */

int ClassDeclaration::isCOMclass()
{
    return com;
}

int ClassDeclaration::isCOMinterface()
{
    return 0;
}

int ClassDeclaration::isCPPclass()
{
    return cpp;
}

int ClassDeclaration::isCPPinterface()
{
    return 0;
}

#if DMD_OBJC
int ClassDeclaration::isObjCinterface()
{
    return objc;
}
#endif


/****************************************
 */

bool ClassDeclaration::isAbstract()
{
    if (isabstract)
        return true;
    for (size_t i = 1; i < vtbl.dim; i++)
    {
        FuncDeclaration *fd = vtbl[i]->isFuncDeclaration();

        //printf("\tvtbl[%d] = %p\n", i, fd);
        if (!fd || fd->isAbstract())
        {
            isabstract |= 1;
            return true;
        }
    }
    return false;
}


/****************************************
 * Determine if slot 0 of the vtbl[] is reserved for something else.
 * For class objects, yes, this is where the classinfo ptr goes.
 * For COM interfaces, no.
 * For non-COM interfaces, yes, this is where the Interface ptr goes.
 * Returns:
 *      0       vtbl[0] is first virtual function pointer
 *      1       vtbl[0] is classinfo/interfaceinfo pointer
 */

int ClassDeclaration::vtblOffset()
{
    return cpp ? 0 : 1;
}

/****************************************
 */

const char *ClassDeclaration::kind()
{
    return "class";
}

/****************************************
 */

void ClassDeclaration::addLocalClass(ClassDeclarations *aclasses)
{
#if DMD_OBJC
    if (objc)
        return;
#endif
    aclasses->push(this);
}

#if DMD_OBJC
void ClassDeclaration::addObjcSymbols(ClassDeclarations *classes, ClassDeclarations *categories)
{
    if (objc && !objcextern && !objcmeta)
        classes->push(this);
}
#endif


/********************************* InterfaceDeclaration ****************************/

InterfaceDeclaration::InterfaceDeclaration(Loc loc, Identifier *id, BaseClasses *baseclasses)
    : ClassDeclaration(loc, id, baseclasses)
{
    if (id == Id::IUnknown)     // IUnknown is the root of all COM interfaces
    {   com = 1;
        cpp = 1;                // IUnknown is also a C++ interface
    }
}

Dsymbol *InterfaceDeclaration::syntaxCopy(Dsymbol *s)
{
    InterfaceDeclaration *id;

    if (s)
        id = (InterfaceDeclaration *)s;
    else
        id = new InterfaceDeclaration(loc, ident, NULL);

    ClassDeclaration::syntaxCopy(id);
    return id;
}

void InterfaceDeclaration::semantic(Scope *sc)
{
    //printf("InterfaceDeclaration::semantic(%s), type = %p\n", toChars(), type);
    if (inuse)
        return;

    if (!sc)
        sc = scope;
    if (!parent && sc->parent && !sc->parent->isModule())
        parent = sc->parent;

    type = type->semantic(loc, sc);
    handle = type;

    if (!members)                       // if forward reference
    {   //printf("\tinterface '%s' is forward referenced\n", toChars());
        return;
    }
    if (symtab)                 // if already done
    {   if (!scope)
            return;
    }
    else
        symtab = new DsymbolTable();

    Scope *scx = NULL;
    if (scope)
    {
        sc = scope;
        scx = scope;            // save so we don't make redundant copies
        scope = NULL;
    }

    int errors = global.errors;

    if (sc->stc & STCdeprecated)
    {
        isdeprecated = true;
    }
    userAttributes = sc->userAttributes;

    // Expand any tuples in baseclasses[]
    for (size_t i = 0; i < baseclasses->dim; )
    {
        // Ungag errors when not speculative
        Ungag ungag = ungagSpeculative();

        BaseClass *b = (*baseclasses)[i];
        b->type = b->type->semantic(loc, sc);

        Type *tb = b->type->toBasetype();
        if (tb->ty == Ttuple)
        {   TypeTuple *tup = (TypeTuple *)tb;
            PROT protection = b->protection;
            baseclasses->remove(i);
            size_t dim = Parameter::dim(tup->arguments);
            for (size_t j = 0; j < dim; j++)
            {   Parameter *arg = Parameter::getNth(tup->arguments, j);
                b = new BaseClass(arg->type, protection);
                baseclasses->insert(i + j, b);
            }
        }
        else
            i++;
    }

    if (!baseclasses->dim && sc->linkage == LINKcpp)
        cpp = 1;
    if (sc->linkage == LINKobjc)
    {
#if DMD_OBJC
        objc = 1;
        // In the abscense of a better solution, classes with Objective-C linkage
        // are only a declaration. A class that derives from one with Objective-C
        // linkage but which does not have Objective-C linkage itself will
        // generate a definition in the object file.
        objcextern = 1; // this one is only a declaration

        if (!objcident)
            objcident = ident;
#else
        error("Objective-C interfaces not supported");
#endif
    }

    // Check for errors, handle forward references
    for (size_t i = 0; i < baseclasses->dim; )
    {
        // Ungag errors when not speculative
        Ungag ungag = ungagSpeculative();

        BaseClass *b = (*baseclasses)[i];
        b->type = b->type->semantic(loc, sc);

        Type *tb = b->type->toBasetype();
        TypeClass *tc = (tb->ty == Tclass) ? (TypeClass *)tb : NULL;
        if (!tc || !tc->sym->isInterfaceDeclaration())
        {
            if (b->type != Type::terror)
                error("base type must be interface, not %s", b->type->toChars());
            baseclasses->remove(i);
            continue;
        }
        else
        {
#if DMD_OBJC
            // Check for mixin Objective-C and non-Objective-C interfaces
            if (!objc && tc->sym->objc)
            {   if (i == 0)
                {   // This is the first -- there's no non-Objective-C interface before this one.
                    // Implicitly switch this interface to Objective-C.
                    objc = 1;
                }
                else
                    goto Lobjcmix; // same error as below
            }
            else if (objc && !tc->sym->objc)
            {
            Lobjcmix:
                error ("cannot mix Objective-C and non-Objective-C interfaces");
                baseclasses->remove(i);
                continue;
            }
#endif
            // Check for duplicate interfaces
            for (size_t j = 0; j < i; j++)
            {
                BaseClass *b2 = (*baseclasses)[j];
                if (b2->base == tc->sym)
                    error("inherits from duplicate interface %s", b2->base->toChars());
            }

            b->base = tc->sym;
            if (b->base == this || isBaseOf2(b->base))
            {
                error("circular inheritance of interface");
                baseclasses->remove(i);
                continue;
            }
            if (b->base->scope)
            {
                // Try to resolve forward reference
                b->base->semantic(NULL);
            }
            if (!b->base->symtab || b->base->scope || b->base->inuse)
            {
                //error("forward reference of base class %s", baseClass->toChars());
                // Forward reference of base, try again later
                //printf("\ttry later, forward reference of base %s\n", b->base->toChars());
                scope = scx ? scx : new Scope(*sc);
                scope->setNoFree();
                scope->module->addDeferredSemantic(this);
                return;
            }
        }
#if 0
        // Inherit const/invariant from base class
        storage_class |= b->base->storage_class & STC_TYPECTOR;
#endif
        i++;
    }
    if (doAncestorsSemantic == SemanticIn)
        doAncestorsSemantic = SemanticDone;

    interfaces_dim = baseclasses->dim;
    interfaces = baseclasses->tdata();

#if DMD_OBJC
    if (objc && !objcmeta && !metaclass)
    {   // Create meta class derived from all our base's metaclass
        BaseClasses *metabases = new BaseClasses();
        for (size_t i = 0; i < baseclasses->dim; ++i)
        {   ClassDeclaration *basecd = ((BaseClass *)baseclasses->data[i])->base;
            assert(basecd);
            InterfaceDeclaration *baseid = basecd->isInterfaceDeclaration();
            assert(baseid);
            if (baseid->objc)
            {   assert(baseid->metaclass);
                assert(baseid->metaclass->objcmeta);
                assert(baseid->metaclass->type->ty == Tclass);
                assert(((TypeClass *)baseid->metaclass->type)->sym == baseid->metaclass);
                BaseClass *metabase = new BaseClass(baseid->metaclass->type, PROTpublic);
                metabase->base = baseid->metaclass;
                metabases->push(metabase);
            }
            else
                error("base interfaces for an Objective-C interface must be extern (Objective-C)");
        }
        metaclass = new InterfaceDeclaration(loc, Id::Class, metabases);
        metaclass->storage_class |= STCstatic;
        metaclass->objc = 1;
        metaclass->objcmeta = 1;
        metaclass->objcextern = objcextern;
        metaclass->objcident = objcident;
        members->push(metaclass);
        metaclass->addMember(sc, this, 1);
    }
#endif

    interfaceSemantic(sc);

    if (vtblOffset())
        vtbl.push(this);                // leave room at vtbl[0] for classinfo

    // Cat together the vtbl[]'s from base interfaces
    for (size_t i = 0; i < interfaces_dim; i++)
    {   BaseClass *b = interfaces[i];

        // Skip if b has already appeared
        for (size_t k = 0; k < i; k++)
        {
            if (b == interfaces[k])
                goto Lcontinue;
        }

        // Copy vtbl[] from base class
        if (b->base->vtblOffset())
        {   size_t d = b->base->vtbl.dim;
            if (d > 1)
            {
                vtbl.reserve(d - 1);
                for (size_t j = 1; j < d; j++)
                    vtbl.push(b->base->vtbl[j]);
            }
        }
        else
        {
            vtbl.append(&b->base->vtbl);
        }

      Lcontinue:
        ;
    }

    protection = sc->protection;
    storage_class |= sc->stc & STC_TYPECTOR;

    for (size_t i = 0; i < members->dim; i++)
    {
        Dsymbol *s = (*members)[i];
        s->addMember(sc, this, 1);
    }

    sc = sc->push(this);
    sc->stc &= STCsafe | STCtrusted | STCsystem;
    sc->parent = this;
    if (com)
        sc->linkage = LINKwindows;
    else if (cpp)
        sc->linkage = LINKcpp;
#if DMD_OBJC
    else if (isObjCinterface())
        sc->linkage = LINKobjc;
#endif
    sc->structalign = STRUCTALIGN_DEFAULT;
    sc->protection = PROTpublic;
    sc->explicitProtection = 0;
//    structalign = sc->structalign;
    sc->offset = Target::ptrsize * 2;
    sc->userAttributes = NULL;
    structsize = sc->offset;
    inuse++;

#if DMD_OBJC
    if (metaclass)
        metaclass->members = new Dsymbols();
#endif

    /* Set scope so if there are forward references, we still might be able to
     * resolve individual members like enums.
     */
    for (size_t i = 0; i < members->dim; i++)
    {   Dsymbol *s = (*members)[i];
        /* There are problems doing this in the general case because
         * Scope keeps track of things like 'offset'
         */
        if (s->isEnumDeclaration() || (s->isAggregateDeclaration() && s->ident))
        {
            //printf("setScope %s %s\n", s->kind(), s->toChars());
            s->setScope(sc);
        }
    }

    for (size_t i = 0; i < members->dim; i++)
    {
        Dsymbol *s = (*members)[i];

        // Ungag errors when not speculative
        Ungag ungag = ungagSpeculative();
        s->semantic(sc);
    }

    if (global.errors != errors)
    {   // The type is no good.
        type = Type::terror;
    }

    inuse--;
    //members->print();
#if DMD_OBJC
//    if (metaclass)
//        metaclass->semantic(sc);
#endif
    sc->pop();
    //printf("-InterfaceDeclaration::semantic(%s), type = %p\n", toChars(), type);

    if (type->ty == Tclass && ((TypeClass *)type)->sym != this)
    {
        error("failed semantic analysis");
        this->errors = true;
        type = Type::terror;
    }
}


/*******************************************
 * Determine if 'this' is a base class of cd.
 * (Actually, if it is an interface supported by cd)
 * Output:
 *      *poffset        offset to start of class
 *                      OFFSET_RUNTIME  must determine offset at runtime
 * Returns:
 *      0       not a base
 *      1       is a base
 */

int InterfaceDeclaration::isBaseOf(ClassDeclaration *cd, int *poffset)
{
#if DMD_OBJC
    if (poffset && objc && cd->objc)
    {   // Objective-C interfaces inside Objective-C classes have no offset.
        // Set offset to zero then set poffset to null to avoid it being changed.
        *poffset = 0;
        poffset = NULL;
    }
#endif

    //printf("%s.InterfaceDeclaration::isBaseOf(cd = '%s')\n", toChars(), cd->toChars());
    assert(!baseClass);
    for (size_t j = 0; j < cd->interfaces_dim; j++)
    {
        BaseClass *b = cd->interfaces[j];

        //printf("\tbase %s\n", b->base->toChars());
        if (this == b->base)
        {
            //printf("\tfound at offset %d\n", b->offset);
            if (poffset)
            {   *poffset = b->offset;
                if (j && cd->isInterfaceDeclaration())
                    *poffset = OFFSET_RUNTIME;
            }
            return 1;
        }
        if (isBaseOf(b, poffset))
        {   if (j && poffset && cd->isInterfaceDeclaration())
                *poffset = OFFSET_RUNTIME;
            return 1;
        }
    }

    if (cd->baseClass && isBaseOf(cd->baseClass, poffset))
        return 1;

    if (poffset)
        *poffset = 0;
    return 0;
}


int InterfaceDeclaration::isBaseOf(BaseClass *bc, int *poffset)
{
    //printf("%s.InterfaceDeclaration::isBaseOf(bc = '%s')\n", toChars(), bc->base->toChars());
#if DMD_OBJC
    if (poffset && objc && bc->base && bc->base->objc)
    {   // Objective-C interfaces inside Objective-C classes have no offset.
        // Set offset to zero then set poffset to null to avoid it being changed.
        *poffset = 0;
        poffset = NULL;
    }
#endif
    for (size_t j = 0; j < bc->baseInterfaces_dim; j++)
    {
        BaseClass *b = &bc->baseInterfaces[j];

        if (this == b->base)
        {
            if (poffset)
            {   *poffset = b->offset;
                if (j && bc->base->isInterfaceDeclaration())
                    *poffset = OFFSET_RUNTIME;
            }
            return 1;
        }
        if (isBaseOf(b, poffset))
        {   if (j && poffset && bc->base->isInterfaceDeclaration())
                *poffset = OFFSET_RUNTIME;
            return 1;
        }
    }
    if (poffset)
        *poffset = 0;
    return 0;
}

/*********************************************
 * Determine if 'this' has clomplete base class information.
 * This is used to detect forward references in covariant overloads.
 */

int InterfaceDeclaration::isBaseInfoComplete()
{
    assert(!baseClass);
    for (size_t i = 0; i < baseclasses->dim; i++)
    {   BaseClass *b = (*baseclasses)[i];
        if (!b->base || !b->base->isBaseInfoComplete ())
            return 0;
    }
    return 1;
}

/****************************************
 * Determine if slot 0 of the vtbl[] is reserved for something else.
 * For class objects, yes, this is where the ClassInfo ptr goes.
 * For COM interfaces, no.
 * For non-COM interfaces, yes, this is where the Interface ptr goes.
 */

int InterfaceDeclaration::vtblOffset()
{
    if (isCOMinterface() || isCPPinterface())
        return 0;
    return 1;
}

int InterfaceDeclaration::isCOMinterface()
{
    return com;
}

int InterfaceDeclaration::isCPPinterface()
{
    return cpp;
}

#if DMD_OBJC
void InterfaceDeclaration::addObjcSymbols(ClassDeclarations *classes, ClassDeclarations *categories)
{
    // nothing to do
}
#endif

/*******************************************
 */

const char *InterfaceDeclaration::kind()
{
    return "interface";
}


/******************************** BaseClass *****************************/

BaseClass::BaseClass()
{
    memset(this, 0, sizeof(BaseClass));
}

BaseClass::BaseClass(Type *type, PROT protection)
{
    //printf("BaseClass(this = %p, '%s')\n", this, type->toChars());
    this->type = type;
    this->protection = protection;
    base = NULL;
    offset = 0;

    baseInterfaces_dim = 0;
    baseInterfaces = NULL;
}

/****************************************
 * Fill in vtbl[] for base class based on member functions of class cd.
 * Input:
 *      vtbl            if !=NULL, fill it in
 *      newinstance     !=0 means all entries must be filled in by members
 *                      of cd, not members of any base classes of cd.
 * Returns:
 *      !=0 if any entries were filled in by members of cd (not exclusively
 *      by base classes)
 */

int BaseClass::fillVtbl(ClassDeclaration *cd, FuncDeclarations *vtbl, int newinstance)
{
    int result = 0;

    //printf("BaseClass::fillVtbl(this='%s', cd='%s')\n", base->toChars(), cd->toChars());
    if (vtbl)
        vtbl->setDim(base->vtbl.dim);

    // first entry is ClassInfo reference
    for (size_t j = base->vtblOffset(); j < base->vtbl.dim; j++)
    {
        FuncDeclaration *ifd = base->vtbl[j]->isFuncDeclaration();
        FuncDeclaration *fd;
        TypeFunction *tf;

        //printf("        vtbl[%d] is '%s'\n", j, ifd ? ifd->toChars() : "null");

        assert(ifd);
        // Find corresponding function in this class
        tf = (ifd->type->ty == Tfunction) ? (TypeFunction *)(ifd->type) : NULL;
        assert(tf);  // should always be non-null
        fd = cd->findFunc(ifd->ident, tf);
        if (fd && !fd->isAbstract())
        {
            //printf("            found\n");
            // Check that calling conventions match
            if (fd->linkage != ifd->linkage)
                fd->error("linkage doesn't match interface function");

            // Check that it is current
            if (newinstance &&
                fd->toParent() != cd &&
                ifd->toParent() == base)
                cd->error("interface function '%s' is not implemented", ifd->toFullSignature());

            if (fd->toParent() == cd)
                result = 1;
        }
        else
        {
            //printf("            not found\n");
            // BUG: should mark this class as abstract?
            if (!cd->isAbstract())
                cd->error("interface function '%s' is not implemented", ifd->toFullSignature());

            fd = NULL;
        }
        if (vtbl)
            (*vtbl)[j] = fd;
    }

    return result;
}

void BaseClass::copyBaseInterfaces(BaseClasses *vtblInterfaces)
{
    //printf("+copyBaseInterfaces(), %s\n", base->toChars());
//    if (baseInterfaces_dim)
//      return;

    baseInterfaces_dim = base->interfaces_dim;
    baseInterfaces = (BaseClass *)mem.calloc(baseInterfaces_dim, sizeof(BaseClass));

    //printf("%s.copyBaseInterfaces()\n", base->toChars());
    for (size_t i = 0; i < baseInterfaces_dim; i++)
    {
        BaseClass *b = &baseInterfaces[i];
        BaseClass *b2 = base->interfaces[i];

        assert(b2->vtbl.dim == 0);      // should not be filled yet
        memcpy(b, b2, sizeof(BaseClass));

        if (i)                          // single inheritance is i==0
            vtblInterfaces->push(b);    // only need for M.I.
        b->copyBaseInterfaces(vtblInterfaces);
    }
    //printf("-copyBaseInterfaces\n");
}
