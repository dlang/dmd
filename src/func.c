
/* Compiler implementation of the D programming language
 * Copyright (C) 1999-2020 by The D Language Foundation, All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/func.c
 */

#include "root/dsystem.h"

#include "mars.h"
#include "init.h"
#include "declaration.h"
#include "attrib.h"
#include "expression.h"
#include "scope.h"
#include "mtype.h"
#include "aggregate.h"
#include "identifier.h"
#include "id.h"
#include "module.h"
#include "statement.h"
#include "statement_rewrite_walker.h"
#include "template.h"
#include "hdrgen.h"
#include "target.h"
#include "parse.h"
#include "root/rmem.h"
#include "visitor.h"
#include "objc.h"

bool checkNestedRef(Dsymbol *s, Dsymbol *p);
int blockExit(Statement *s, FuncDeclaration *func, bool mustNotThrow);
TypeIdentifier *getThrowable();

void MODtoBuffer(OutBuffer *buf, MOD mod);
bool MODimplicitConv(MOD modfrom, MOD modto);
MATCH MODmethodConv(MOD modfrom, MOD modto);
Objc *objc();

/***********************************************************
 * Tuple of result identifier (possibly null) and statement.
 * This is used to store out contracts: out(id){ ensure }
 */
Ensure::Ensure()
{
    this->id = NULL;
    this->ensure = NULL;
}

Ensure::Ensure(Identifier *id, Statement *ensure)
{
    this->id = id;
    this->ensure = ensure;
}

Ensure Ensure::syntaxCopy()
{
    return Ensure(id, ensure->syntaxCopy());
}

/*****************************************
 * Do syntax copy of an array of Ensure's.
 */
Ensures *Ensure::arraySyntaxCopy(Ensures *a)
{
    Ensures *b = NULL;
    if (a)
    {
        b = a->copy();
        for (size_t i = 0; i < a->length; i++)
            (*b)[i] = (*a)[i].syntaxCopy();
    }
    return b;
}

/********************************* FuncDeclaration ****************************/

FuncDeclaration::FuncDeclaration(Loc loc, Loc endloc, Identifier *id, StorageClass storage_class, Type *type)
    : Declaration(id)
{
    //printf("FuncDeclaration(id = '%s', type = %p)\n", id->toChars(), type);
    //printf("storage_class = x%x\n", storage_class);
    this->storage_class = storage_class;
    this->type = type;
    if (type)
    {
        // Normalize storage_class, because function-type related attributes
        // are already set in the 'type' in parsing phase.
        this->storage_class &= ~(STC_TYPECTOR | STC_FUNCATTR);
    }
    this->loc = loc;
    this->endloc = endloc;
    fthrows = NULL;
    frequire = NULL;
    fdrequire = NULL;
    fdensure = NULL;
    mangleString = NULL;
    vresult = NULL;
    returnLabel = NULL;
    fensure = NULL;
    frequires = NULL;
    fensures = NULL;
    fbody = NULL;
    localsymtab = NULL;
    vthis = NULL;
    v_arguments = NULL;
    v_argptr = NULL;
    parameters = NULL;
    labtab = NULL;
    overnext = NULL;
    overnext0 = NULL;
    vtblIndex = -1;
    hasReturnExp = 0;
    naked = false;
    generated = false;
    inlineStatusExp = ILSuninitialized;
    inlineStatusStmt = ILSuninitialized;
    inlining = PINLINEdefault;
    inlineNest = 0;
    ctfeCode = NULL;
    isArrayOp = 0;
    semantic3Errors = false;
    fes = NULL;
    interfaceVirtual = NULL;
    introducing = 0;
    tintro = NULL;
    /* The type given for "infer the return type" is a TypeFunction with
     * NULL for the return type.
     */
    inferRetType = (type && type->nextOf() == NULL);
    storage_class2 = 0;
    hasReturnExp = 0;
    nrvo_can = 1;
    nrvo_var = NULL;
    shidden = NULL;
    builtin = BUILTINunknown;
    tookAddressOf = 0;
    requiresClosure = false;
    inlinedNestedCallees = NULL;
    flags = 0;
    returns = NULL;
    gotos = NULL;
    selector = NULL;
}

FuncDeclaration *FuncDeclaration::create(Loc loc, Loc endloc, Identifier *id, StorageClass storage_class, Type *type)
{
    return new FuncDeclaration(loc, endloc, id, storage_class, type);
}

Dsymbol *FuncDeclaration::syntaxCopy(Dsymbol *s)
{
    //printf("FuncDeclaration::syntaxCopy('%s')\n", toChars());
    FuncDeclaration *f =
        s ? (FuncDeclaration *)s
          : new FuncDeclaration(loc, endloc, ident, storage_class, type->syntaxCopy());
    f->frequires = frequires ? Statement::arraySyntaxCopy(frequires) : NULL;
    f->fensures = fensures ? Ensure::arraySyntaxCopy(fensures) : NULL;
    f->fbody = fbody ? fbody->syntaxCopy() : NULL;
    assert(!fthrows); // deprecated
    return f;
}

/**********************************
 * Decide if attributes for this function can be inferred from examining
 * the function body.
 * Returns:
 *  true if can
 */
static bool canInferAttributes(FuncDeclaration *fd, Scope *sc)
{
    if (!fd->fbody)
        return false;

    if (fd->isVirtualMethod())
        return false;               // since they may be overridden

    if (sc->func &&
        /********** this is for backwards compatibility for the moment ********/
        (!fd->isMember() || (sc->func->isSafeBypassingInference() && !fd->isInstantiated())))
        return true;

    if (fd->isFuncLiteralDeclaration() ||               // externs are not possible with literals
        (fd->storage_class & STCinference) ||           // do attribute inference
        (fd->inferRetType && !fd->isCtorDeclaration()))
        return true;

    if (fd->isInstantiated())
    {
        TemplateInstance *ti = fd->parent->isTemplateInstance();
        if (ti == NULL || ti->isTemplateMixin() || ti->tempdecl->ident == fd->ident)
            return true;
    }

    return false;
}

/*****************************************
 * Initialize for inferring the attributes of this function.
 */
static void initInferAttributes(FuncDeclaration *fd)
{
    //printf("initInferAttributes() for %s\n", toPrettyChars());
    TypeFunction *tf = fd->type->toTypeFunction();
    if (tf->purity == PUREimpure) // purity not specified
        fd->flags |= FUNCFLAGpurityInprocess;

    if (tf->trust == TRUSTdefault)
        fd->flags |= FUNCFLAGsafetyInprocess;

    if (!tf->isnothrow)
        fd->flags |= FUNCFLAGnothrowInprocess;

    if (!tf->isnogc)
        fd->flags |= FUNCFLAGnogcInprocess;

    if (!fd->isVirtual() || fd->introducing)
        fd->flags |= FUNCFLAGreturnInprocess;

    // Initialize for inferring STCscope
    if (global.params.vsafe)
        fd->flags |= FUNCFLAGinferScope;
}

// Returns true if a contract can appear without a function body.
bool allowsContractWithoutBody(FuncDeclaration *funcdecl)
{
    assert(!funcdecl->fbody);

    /* Contracts can only appear without a body when they are virtual
     * interface functions or abstract.
     */
    Dsymbol *parent = funcdecl->toParent();
    InterfaceDeclaration *id = parent->isInterfaceDeclaration();

    if (!funcdecl->isAbstract() &&
        (funcdecl->fensures || funcdecl->frequires) &&
        !(id && funcdecl->isVirtual()))
    {
        ClassDeclaration *cd = parent->isClassDeclaration();
        if (!(cd && cd->isAbstract()))
            return false;
    }
    return true;
}

// Do the semantic analysis on the external interface to the function.

void FuncDeclaration::semantic(Scope *sc)
{
    TypeFunction *f;
    AggregateDeclaration *ad;
    InterfaceDeclaration *id;

    if (semanticRun != PASSinit && isFuncLiteralDeclaration())
    {
        /* Member functions that have return types that are
         * forward references can have semantic() run more than
         * once on them.
         * See test\interface2.d, test20
         */
        return;
    }

    if (semanticRun >= PASSsemanticdone)
        return;
    assert(semanticRun <= PASSsemantic);
    semanticRun = PASSsemantic;

    if (_scope)
    {
        sc = _scope;
        _scope = NULL;
    }

    if (!sc || errors)
        return;

    parent = sc->parent;
    Dsymbol *parent = toParent();

    foverrides.setDim(0);       // reset in case semantic() is being retried for this function

    storage_class |= sc->stc & ~STCref;
    ad = isThis();
    // Don't nest structs b/c of generated methods which should not access the outer scopes.
    // https://issues.dlang.org/show_bug.cgi?id=16627
    if (ad && !generated)
    {
        storage_class |= ad->storage_class & (STC_TYPECTOR | STCsynchronized);
        ad->makeNested();
    }
    if (sc->func)
        storage_class |= sc->func->storage_class & STCdisable;
    // Remove prefix storage classes silently.
    if ((storage_class & STC_TYPECTOR) && !(ad || isNested()))
        storage_class &= ~STC_TYPECTOR;

    //printf("function storage_class = x%llx, sc->stc = x%llx, %x\n", storage_class, sc->stc, Declaration::isFinal());

    FuncLiteralDeclaration *fld = isFuncLiteralDeclaration();
    if (fld && fld->treq)
    {
        Type *treq = fld->treq;
        assert(treq->nextOf()->ty == Tfunction);
        if (treq->ty == Tdelegate)
            fld->tok = TOKdelegate;
        else if (treq->ty == Tpointer && treq->nextOf()->ty == Tfunction)
            fld->tok = TOKfunction;
        else
            assert(0);
        linkage = treq->nextOf()->toTypeFunction()->linkage;
    }
    else
        linkage = sc->linkage;
    inlining = sc->inlining;
    protection = sc->protection;
    userAttribDecl = sc->userAttribDecl;

    if (!originalType)
        originalType = type->syntaxCopy();
    if (type->ty != Tfunction)
    {
        if (type->ty != Terror)
        {
            error("%s must be a function instead of %s", toChars(), type->toChars());
            type = Type::terror;
        }
        errors = true;
        return;
    }
    if (!type->deco)
    {
        sc = sc->push();
        sc->stc |= storage_class & (STCdisable | STCdeprecated);  // forward to function type
        TypeFunction *tf = type->toTypeFunction();

        if (sc->func)
        {
            /* If the nesting parent is pure without inference,
             * then this function defaults to pure too.
             *
             *  auto foo() pure {
             *    auto bar() {}     // become a weak purity funciton
             *    class C {         // nested class
             *      auto baz() {}   // become a weak purity funciton
             *    }
             *
             *    static auto boo() {}   // typed as impure
             *    // Even though, boo cannot call any impure functions.
             *    // See also Expression::checkPurity().
             *  }
             */
            if (tf->purity == PUREimpure && (isNested() || isThis()))
            {
                FuncDeclaration *fd = NULL;
                for (Dsymbol *p = toParent2(); p; p = p->toParent2())
                {
                    if (AggregateDeclaration *adx = p->isAggregateDeclaration())
                    {
                        if (adx->isNested())
                            continue;
                        break;
                    }
                    if ((fd = p->isFuncDeclaration()) != NULL)
                        break;
                }

                /* If the parent's purity is inferred, then this function's purity needs
                 * to be inferred first.
                 */
                if (fd && fd->isPureBypassingInference() >= PUREweak &&
                    !isInstantiated())
                {
                    tf->purity = PUREfwdref;            // default to pure
                }
            }
        }

        if (tf->isref)      sc->stc |= STCref;
        if (tf->isscope)    sc->stc |= STCscope;
        if (tf->isnothrow)  sc->stc |= STCnothrow;
        if (tf->isnogc)     sc->stc |= STCnogc;
        if (tf->isproperty) sc->stc |= STCproperty;
        if (tf->purity == PUREfwdref)   sc->stc |= STCpure;
        if (tf->trust != TRUSTdefault)
            sc->stc &= ~(STCsafe | STCsystem | STCtrusted);
        if (tf->trust == TRUSTsafe)     sc->stc |= STCsafe;
        if (tf->trust == TRUSTsystem)   sc->stc |= STCsystem;
        if (tf->trust == TRUSTtrusted)  sc->stc |= STCtrusted;

        if (isCtorDeclaration())
        {
            sc->flags |= SCOPEctor;

            Type *tret = ad->handleType();
            assert(tret);
            tret = tret->addStorageClass(storage_class | sc->stc);
            tret = tret->addMod(type->mod);
            tf->next = tret;

            if (ad->isStructDeclaration())
                sc->stc |= STCref;
        }

        // 'return' on a non-static class member function implies 'scope' as well
        if (ad && ad->isClassDeclaration() && (tf->isreturn || sc->stc & STCreturn) && !(sc->stc & STCstatic))
            sc->stc |= STCscope;

        // If 'this' has no pointers, remove 'scope' as it has no meaning
        if (sc->stc & STCscope && ad && ad->isStructDeclaration() && !ad->type->hasPointers())
        {
            sc->stc &= ~STCscope;
            tf->isscope = false;
        }

        sc->linkage = linkage;

        if (!tf->isNaked() && !(isThis() || isNested()))
        {
            OutBuffer buf;
            MODtoBuffer(&buf, tf->mod);
            error("without 'this' cannot be %s", buf.peekChars());
            tf->mod = 0;    // remove qualifiers
        }

        /* Apply const, immutable, wild and shared storage class
         * to the function type. Do this before type semantic.
         */
        StorageClass stc = storage_class;
        if (type->isImmutable())
            stc |= STCimmutable;
        if (type->isConst())
            stc |= STCconst;
        if (type->isShared() || storage_class & STCsynchronized)
            stc |= STCshared;
        if (type->isWild())
            stc |= STCwild;
        switch (stc & STC_TYPECTOR)
        {
            case STCimmutable:
            case STCimmutable | STCconst:
            case STCimmutable | STCwild:
            case STCimmutable | STCwild | STCconst:
            case STCimmutable | STCshared:
            case STCimmutable | STCshared | STCconst:
            case STCimmutable | STCshared | STCwild:
            case STCimmutable | STCshared | STCwild | STCconst:
                // Don't use immutableOf(), as that will do a merge()
                type = type->makeImmutable();
                break;

            case STCconst:
                type = type->makeConst();
                break;

            case STCwild:
                type = type->makeWild();
                break;

            case STCwild | STCconst:
                type = type->makeWildConst();
                break;

            case STCshared:
                type = type->makeShared();
                break;

            case STCshared | STCconst:
                type = type->makeSharedConst();
                break;

            case STCshared | STCwild:
                type = type->makeSharedWild();
                break;

            case STCshared | STCwild | STCconst:
                type = type->makeSharedWildConst();
                break;

            case 0:
                break;

            default:
                assert(0);
        }

        type = typeSemantic(type, loc, sc);
        sc = sc->pop();
    }
    if (type->ty != Tfunction)
    {
        if (type->ty != Terror)
        {
            error("%s must be a function instead of %s", toChars(), type->toChars());
            type = Type::terror;
        }
        errors = true;
        return;
    }
    else
    {
        // Merge back function attributes into 'originalType'.
        // It's used for mangling, ddoc, and json output.
        TypeFunction *tfo = originalType->toTypeFunction();
        TypeFunction *tfx = type->toTypeFunction();
        tfo->mod        = tfx->mod;
        tfo->isscope    = tfx->isscope;
        tfo->isscopeinferred = tfx->isscopeinferred;
        tfo->isref      = tfx->isref;
        tfo->isnothrow  = tfx->isnothrow;
        tfo->isnogc     = tfx->isnogc;
        tfo->isproperty = tfx->isproperty;
        tfo->purity     = tfx->purity;
        tfo->trust      = tfx->trust;

        storage_class &= ~(STC_TYPECTOR | STC_FUNCATTR);
    }

    f = (TypeFunction *)type;

    if ((storage_class & STCauto) && !f->isref && !inferRetType)
        error("storage class 'auto' has no effect if return type is not inferred");
    /* Functions can only be 'scope' if they have a 'this'
     */
    if (f->isscope && !isNested() && !ad)
    {
        error("functions cannot be scope");
    }

    if (f->isreturn && !needThis() && !isNested())
    {
        /* Non-static nested functions have a hidden 'this' pointer to which
         * the 'return' applies
         */
        error("static member has no 'this' to which 'return' can apply");
    }

    if (isAbstract() && !isVirtual())
    {
        const char *sfunc;
        if (isStatic())
            sfunc = "static";
        else if (protection.kind == Prot::private_ || protection.kind == Prot::package_)
            sfunc = protectionToChars(protection.kind);
        else
            sfunc = "non-virtual";
        error("%s functions cannot be abstract", sfunc);
    }

    if (isOverride() && !isVirtual())
    {
        Prot::Kind kind = prot().kind;
        if ((kind == Prot::private_ || kind == Prot::package_) && isMember())
            error("%s method is not virtual and cannot override", protectionToChars(kind));
        else
            error("cannot override a non-virtual function");
    }

    if (isAbstract() && isFinalFunc())
        error("cannot be both final and abstract");

    id = parent->isInterfaceDeclaration();
    if (id)
    {
        storage_class |= STCabstract;

        if (isCtorDeclaration() ||
            isPostBlitDeclaration() ||
            isDtorDeclaration() ||
            isInvariantDeclaration() ||
            isNewDeclaration() || isDelete())
            error("constructors, destructors, postblits, invariants, new and delete functions are not allowed in interface %s", id->toChars());
        if (fbody && isVirtual())
            error("function body only allowed in final functions in interface %s", id->toChars());
    }

    if (UnionDeclaration *ud = parent->isUnionDeclaration())
    {
        if (isPostBlitDeclaration() ||
            isDtorDeclaration() ||
            isInvariantDeclaration())
            error("destructors, postblits and invariants are not allowed in union %s", ud->toChars());
    }

    if (parent->isStructDeclaration())
    {
        if (isCtorDeclaration())
        {
            goto Ldone;
        }
    }

    if (ClassDeclaration *cd = parent->isClassDeclaration())
    {
        if (isCtorDeclaration())
        {
            goto Ldone;
        }

        if (storage_class & STCabstract)
            cd->isabstract = ABSyes;

        // if static function, do not put in vtbl[]
        if (!isVirtual())
        {
            //printf("\tnot virtual\n");
            goto Ldone;
        }
        // Suppress further errors if the return type is an error
        if (type->nextOf() == Type::terror)
            goto Ldone;

        bool may_override = false;
        for (size_t i = 0; i < cd->baseclasses->length; i++)
        {
            BaseClass *b = (*cd->baseclasses)[i];
            ClassDeclaration *cbd = b->type->toBasetype()->isClassHandle();
            if (!cbd)
                continue;
            for (size_t j = 0; j < cbd->vtbl.length; j++)
            {
                FuncDeclaration *f2 = cbd->vtbl[j]->isFuncDeclaration();
                if (!f2 || f2->ident != ident)
                    continue;
                if (cbd->parent && cbd->parent->isTemplateInstance())
                {
                    if (!f2->functionSemantic())
                        goto Ldone;
                }
                may_override = true;
            }
        }
        if (may_override && type->nextOf() == NULL)
        {
            /* If same name function exists in base class but 'this' is auto return,
             * cannot find index of base class's vtbl[] to override.
             */
            error("return type inference is not supported if may override base class function");
        }

        /* Find index of existing function in base class's vtbl[] to override
         * (the index will be the same as in cd's current vtbl[])
         */
        int vi = cd->baseClass ? findVtblIndex((Dsymbols*)&cd->baseClass->vtbl, (int)cd->baseClass->vtbl.length)
                               : -1;

        bool doesoverride = false;
        switch (vi)
        {
            case -1:
        Lintro:
                /* Didn't find one, so
                 * This is an 'introducing' function which gets a new
                 * slot in the vtbl[].
                 */

                // Verify this doesn't override previous final function
                if (cd->baseClass)
                {
                    Dsymbol *s = cd->baseClass->search(loc, ident);
                    if (s)
                    {
                        FuncDeclaration *f2 = s->isFuncDeclaration();
                        if (f2)
                        {
                            f2 = f2->overloadExactMatch(type);
                            if (f2 && f2->isFinalFunc() && f2->prot().kind != Prot::private_)
                                error("cannot override final function %s", f2->toPrettyChars());
                        }
                    }
                }

                /* These quirky conditions mimic what VC++ appears to do
                 */
                if (global.params.mscoff && cd->isCPPclass() &&
                    cd->baseClass && cd->baseClass->vtbl.length)
                {
                    /* if overriding an interface function, then this is not
                     * introducing and don't put it in the class vtbl[]
                     */
                    interfaceVirtual = overrideInterface();
                    if (interfaceVirtual)
                    {
                        //printf("\tinterface function %s\n", toChars());
                        cd->vtblFinal.push(this);
                        goto Linterfaces;
                    }
                }

                if (isFinalFunc())
                {
                    // Don't check here, as it may override an interface function
                    //if (isOverride())
                        //error("is marked as override, but does not override any function");
                    cd->vtblFinal.push(this);
                }
                else
                {
                    //printf("\tintroducing function %s\n", toChars());
                    introducing = 1;
                    if (cd->isCPPclass() && target.cpp.reverseOverloads)
                    {
                        // with dmc, overloaded functions are grouped and in reverse order
                        vtblIndex = (int)cd->vtbl.length;
                        for (int i = 0; i < (int)cd->vtbl.length; i++)
                        {
                            if (cd->vtbl[i]->ident == ident && cd->vtbl[i]->parent == parent)
                            {
                                vtblIndex = (int)i;
                                break;
                            }
                        }
                        // shift all existing functions back
                        for (int i = (int)cd->vtbl.length; i > vtblIndex; i--)
                        {
                            FuncDeclaration *fd = cd->vtbl[i-1]->isFuncDeclaration();
                            assert(fd);
                            fd->vtblIndex++;
                        }
                        cd->vtbl.insert(vtblIndex, this);
                    }
                    else
                    {
                        // Append to end of vtbl[]
                        vi = (int)cd->vtbl.length;
                        cd->vtbl.push(this);
                        vtblIndex = vi;
                    }
                }
                break;

            case -2:
                // can't determine because of forward references
                errors = true;
                return;

            default:
            {
                FuncDeclaration *fdv = cd->baseClass->vtbl[vi]->isFuncDeclaration();
                FuncDeclaration *fdc = cd->vtbl[vi]->isFuncDeclaration();
                // This function is covariant with fdv

                if (fdc == this)
                {
                    doesoverride = true;
                    break;
                }

                if (fdc->toParent() == parent)
                {
                    //printf("vi = %d,\tthis = %p %s %s @ [%s]\n\tfdc  = %p %s %s @ [%s]\n\tfdv  = %p %s %s @ [%s]\n",
                    //        vi, this, this->toChars(), this->type->toChars(), this->loc.toChars(),
                    //            fdc,  fdc ->toChars(), fdc ->type->toChars(), fdc ->loc.toChars(),
                    //            fdv,  fdv ->toChars(), fdv ->type->toChars(), fdv ->loc.toChars());

                    // fdc overrides fdv exactly, then this introduces new function.
                    if (fdc->type->mod == fdv->type->mod && this->type->mod != fdv->type->mod)
                        goto Lintro;
                }

                // This function overrides fdv
                if (fdv->isFinalFunc())
                    error("cannot override final function %s", fdv->toPrettyChars());

                if (!isOverride())
                {
                    if (fdv->isFuture())
                    {
                        ::deprecation(loc, "@__future base class method %s is being overridden by %s; rename the latter",
                            fdv->toPrettyChars(), toPrettyChars());
                        // Treat 'this' as an introducing function, giving it a separate hierarchy in the vtbl[]
                        goto Lintro;
                    }
                    else
                    {
                        int vi2 = findVtblIndex(&cd->baseClass->vtbl, (int)cd->baseClass->vtbl.length, false);
                        if (vi2 < 0)
                            // https://issues.dlang.org/show_bug.cgi?id=17349
                            ::deprecation(loc, "cannot implicitly override base class method `%s` with `%s`; add `override` attribute",
                                fdv->toPrettyChars(), toPrettyChars());
                        else
                            ::error(loc, "implicitly overriding base class method %s with %s deprecated; add 'override' attribute",
                                fdv->toPrettyChars(), toPrettyChars());
                    }
                }

                doesoverride = true;
                if (fdc->toParent() == parent)
                {
                    // If both are mixins, or both are not, then error.
                    // If either is not, the one that is not overrides the other.
                    bool thismixin = this->parent->isClassDeclaration() != NULL;
                    bool fdcmixin = fdc->parent->isClassDeclaration() != NULL;
                    if (thismixin == fdcmixin)
                    {
                        error("multiple overrides of same function");
                    }
                    else if (!thismixin)    // fdc overrides fdv
                    {
                        // this doesn't override any function
                        break;
                    }
                }
                cd->vtbl[vi] = this;
                vtblIndex = vi;

                /* Remember which functions this overrides
                 */
                foverrides.push(fdv);

                /* This works by whenever this function is called,
                 * it actually returns tintro, which gets dynamically
                 * cast to type. But we know that tintro is a base
                 * of type, so we could optimize it by not doing a
                 * dynamic cast, but just subtracting the isBaseOf()
                 * offset if the value is != null.
                 */

                if (fdv->tintro)
                    tintro = fdv->tintro;
                else if (!type->equals(fdv->type))
                {
                    /* Only need to have a tintro if the vptr
                     * offsets differ
                     */
                    int offset;
                    if (fdv->type->nextOf()->isBaseOf(type->nextOf(), &offset))
                    {
                        tintro = fdv->type;
                    }
                }
                break;
            }
        }

        /* Go through all the interface bases.
         * If this function is covariant with any members of those interface
         * functions, set the tintro.
         */
    Linterfaces:
        for (size_t i = 0; i < cd->interfaces.length; i++)
        {
            BaseClass *b = cd->interfaces.ptr[i];
            vi = findVtblIndex((Dsymbols *)&b->sym->vtbl, (int)b->sym->vtbl.length);
            switch (vi)
            {
                case -1:
                    break;

                case -2:
                    // can't determine because of forward references
                    errors = true;
                    return;

                default:
                {
                    FuncDeclaration *fdv = (FuncDeclaration *)b->sym->vtbl[vi];
                    Type *ti = NULL;

                    /* Remember which functions this overrides
                     */
                    foverrides.push(fdv);

                    /* Should we really require 'override' when implementing
                     * an interface function?
                     */
                    //if (!isOverride())
                        //warning(loc, "overrides base class function %s, but is not marked with 'override'", fdv->toPrettyChars());

                    if (fdv->tintro)
                        ti = fdv->tintro;
                    else if (!type->equals(fdv->type))
                    {
                        /* Only need to have a tintro if the vptr
                         * offsets differ
                         */
                        int offset;
                        if (fdv->type->nextOf()->isBaseOf(type->nextOf(), &offset))
                        {
                            ti = fdv->type;
                        }
                    }
                    if (ti)
                    {
                        if (tintro)
                        {
                            if (!tintro->nextOf()->equals(ti->nextOf()) &&
                                !tintro->nextOf()->isBaseOf(ti->nextOf(), NULL) &&
                                !ti->nextOf()->isBaseOf(tintro->nextOf(), NULL))
                            {
                                error("incompatible covariant types %s and %s", tintro->toChars(), ti->toChars());
                            }
                        }
                        tintro = ti;
                    }
                    goto L2;
                }
            }
        }

        if (!doesoverride && isOverride() && (type->nextOf() || !may_override))
        {
            BaseClass *bc = NULL;
            Dsymbol *s = NULL;
            for (size_t i = 0; i < cd->baseclasses->length; i++)
            {
                bc = (*cd->baseclasses)[i];
                s = bc->sym->search_correct(ident);
                if (s) break;
            }

            if (s)
                error("does not override any function, did you mean to override '%s%s'?",
                    bc->sym->isCPPclass() ? "extern (C++) " : "", s->toPrettyChars());
            else
                error("does not override any function");
        }

    L2: ;

        /* Go through all the interface bases.
         * Disallow overriding any final functions in the interface(s).
         */
        for (size_t i = 0; i < cd->interfaces.length; i++)
        {
            BaseClass *b = cd->interfaces.ptr[i];
            if (b->sym)
            {
                Dsymbol *s = search_function(b->sym, ident);
                if (s)
                {
                    FuncDeclaration *f2 = s->isFuncDeclaration();
                    if (f2)
                    {
                        f2 = f2->overloadExactMatch(type);
                        if (f2 && f2->isFinalFunc() && f2->prot().kind != Prot::private_)
                            error("cannot override final function %s.%s", b->sym->toChars(), f2->toPrettyChars());
                    }
                }
            }
        }

        if (isOverride())
        {
            if (storage_class & STCdisable)
                deprecation("overridden functions cannot be annotated @disable");
            if (isDeprecated())
                deprecation("deprecated functions cannot be annotated @disable");
        }
    }
    else if (isOverride() && !parent->isTemplateInstance())
        error("override only applies to class member functions");

    // Reflect this->type to f because it could be changed by findVtblIndex
    f = type->toTypeFunction();

Ldone:
    /* Contracts can only appear without a body when they are virtual interface functions
     */
    if (!fbody && !allowsContractWithoutBody(this))
        error("in and out contracts can only appear without a body when they are virtual interface functions or abstract");

    /* Do not allow template instances to add virtual functions
     * to a class.
     */
    if (isVirtual())
    {
        TemplateInstance *ti = parent->isTemplateInstance();
        if (ti)
        {
            // Take care of nested templates
            while (1)
            {
                TemplateInstance *ti2 = ti->tempdecl->parent->isTemplateInstance();
                if (!ti2)
                    break;
                ti = ti2;
            }

            // If it's a member template
            ClassDeclaration *cd = ti->tempdecl->isClassMember();
            if (cd)
            {
                error("cannot use template to add virtual function to class '%s'", cd->toChars());
            }
        }
    }

    if (isMain())
        checkDmain();       // Check main() parameters and return type

    /* Purity and safety can be inferred for some functions by examining
     * the function body.
     */
    if (canInferAttributes(this, sc))
        initInferAttributes(this);

    Module::dprogress++;
    semanticRun = PASSsemanticdone;

    /* Save scope for possible later use (if we need the
     * function internals)
     */
    _scope = sc->copy();
    _scope->setNoFree();

    static bool printedMain = false;  // semantic might run more than once
    if (global.params.verbose && !printedMain)
    {
        const char *type = isMain() ? "main" : isWinMain() ? "winmain" : isDllMain() ? "dllmain" : (const char *)NULL;
        Module *mod = sc->_module;

        if (type && mod)
        {
            printedMain = true;
            const char *name = mod->srcfile->toChars();
            const char *path = FileName::searchPath(global.path, name, true);
            message("entry     %-10s\t%s", type, path ? path : name);
        }
    }

    if (fbody && isMain() && sc->_module->isRoot())
        Compiler::genCmain(sc);

    assert(type->ty != Terror || errors);

    // semantic for parameters' UDAs
    const size_t nparams = f->parameterList.length();
    for (size_t i = 0; i < nparams; i++)
    {
        Parameter *param = f->parameterList[i];
        if (param && param->userAttribDecl)
            param->userAttribDecl->semantic(sc);
    }
}

void FuncDeclaration::semantic2(Scope *sc)
{
    if (semanticRun >= PASSsemantic2done)
        return;
    assert(semanticRun <= PASSsemantic2);
    semanticRun = PASSsemantic2;

    objc()->setSelector(this, sc);
    objc()->validateSelector(this);

    if (parent->isClassDeclaration())
    {
        objc()->checkLinkage(this);
    }
    if (!type || type->ty != Tfunction)
        return;
    TypeFunction *f = type->toTypeFunction();
    const size_t nparams = f->parameterList.length();
    // semantic for parameters' UDAs
    for (size_t i = 0; i < nparams; i++)
    {
        Parameter *param = f->parameterList[i];
        if (param && param->userAttribDecl)
            param->userAttribDecl->semantic2(sc);
    }
}

/****************************************************
 * Determine whether an 'out' contract is declared inside
 * the given function or any of its overrides.
 * Params:
 *      fd = the function to search
 * Returns:
 *      true    found an 'out' contract
 *      false   didn't find one
 */
bool FuncDeclaration::needsFensure(FuncDeclaration *fd)
{
    if (fd->fensures)
        return true;

    for (size_t i = 0; i < fd->foverrides.length; i++)
    {
        FuncDeclaration *fdv = fd->foverrides[i];

        if (fdv->fensure)
            return true;

        if (needsFensure(fdv))
            return true;
    }
    return false;
}

/****************************************************
 * Check whether result variable can be built.
 * Returns:
 *     `true` if the function has a return type that
 *     is different from `void`.
 */
static bool canBuildResultVar(FuncDeclaration *fd)
{
    TypeFunction *f = (TypeFunction *)fd->type;
    return f && f->nextOf() && f->nextOf()->toBasetype()->ty != Tvoid;
}

/****************************************************
 * Rewrite contracts as statements.
 */
void FuncDeclaration::buildEnsureRequire()
{
    if (frequires)
    {
        /*   in { statements1... }
         *   in { statements2... }
         *   ...
         * becomes:
         *   in { { statements1... } { statements2... } ... }
         */
        assert(frequires->length);
        Loc loc = (*frequires)[0]->loc;
        Statements *s = new Statements;
        for (size_t i = 0; i < frequires->length; i++)
        {
            Statement *r = (*frequires)[i];
            s->push(new ScopeStatement(r->loc, r, r->loc));
        }
        frequire = new CompoundStatement(loc, s);
    }

    if (fensures)
    {
        /*   out(id1) { statements1... }
         *   out(id2) { statements2... }
         *   ...
         * becomes:
         *   out(__result) { { ref id1 = __result; { statements1... } }
         *                   { ref id2 = __result; { statements2... } } ... }
         */
        assert(fensures->length);
        Loc loc = (*fensures)[0].ensure->loc;
        Statements *s = new Statements;
        for (size_t i = 0; i < fensures->length; i++)
        {
            Ensure r = (*fensures)[i];
            if (r.id && canBuildResultVar(this))
            {
                Loc rloc = r.ensure->loc;
                IdentifierExp *resultId = new IdentifierExp(rloc, Id::result);
                ExpInitializer *init = new ExpInitializer(rloc, resultId);
                StorageClass stc = STCref | STCtemp | STCresult;
                VarDeclaration *decl = new VarDeclaration(rloc, NULL, r.id, init);
                decl->storage_class = stc;
                ExpStatement *sdecl = new ExpStatement(rloc, decl);
                s->push(new ScopeStatement(rloc, new CompoundStatement(rloc, sdecl, r.ensure), rloc));
            }
            else
            {
                s->push(r.ensure);
            }
        }
        fensure = new CompoundStatement(loc, s);
    }

    if (!isVirtual())
        return;

    /* Rewrite contracts as nested functions, then call them. Doing it as nested
     * functions means that overriding functions can call them.
     */
    TypeFunction *f = (TypeFunction *)type;

    if (frequire)
    {
        /*   in { ... }
         * becomes:
         *   void __require() { ... }
         *   __require();
         */
        Loc loc = frequire->loc;
        TypeFunction *tf = new TypeFunction(ParameterList(), Type::tvoid, LINKd);
        tf->isnothrow = f->isnothrow;
        tf->isnogc = f->isnogc;
        tf->purity = f->purity;
        tf->trust = f->trust;
        FuncDeclaration *fd = new FuncDeclaration(loc, loc,
                                                  Id::require, STCundefined, tf);
        fd->fbody = frequire;
        Statement *s1 = new ExpStatement(loc, fd);
        Expression *e = new CallExp(loc, new VarExp(loc, fd, false), (Expressions *)NULL);
        Statement *s2 = new ExpStatement(loc, e);
        frequire = new CompoundStatement(loc, s1, s2);
        fdrequire = fd;
    }

    if (fensure)
    {
        /*   out (result) { ... }
         * becomes:
         *   void __ensure(ref tret result) { ... }
         *   __ensure(result);
         */
        Loc loc = fensure->loc;
        Parameters *fparams = new Parameters();
        Parameter *p = NULL;
        if (canBuildResultVar(this))
        {
            p = new Parameter(STCref | STCconst, f->nextOf(), Id::result, NULL, NULL);
            fparams->push(p);
        }
        TypeFunction *tf = new TypeFunction(ParameterList(fparams), Type::tvoid, LINKd);
        tf->isnothrow = f->isnothrow;
        tf->isnogc = f->isnogc;
        tf->purity = f->purity;
        tf->trust = f->trust;
        FuncDeclaration *fd = new FuncDeclaration(loc, loc,
                                                  Id::ensure, STCundefined, tf);
        fd->fbody = fensure;
        Statement *s1 = new ExpStatement(loc, fd);
        Expression *eresult = NULL;
        if (canBuildResultVar(this))
            eresult = new IdentifierExp(loc, Id::result);
        Expression *e = new CallExp(loc, new VarExp(loc, fd, false), eresult);
        Statement *s2 = new ExpStatement(loc, e);
        fensure = new CompoundStatement(loc, s1, s2);
        fdensure = fd;
    }
}

/****************************************************
 * Resolve forward reference of function signature -
 * parameter types, return type, and attributes.
 * Returns false if any errors exist in the signature.
 */
bool FuncDeclaration::functionSemantic()
{
    if (!_scope)
        return !errors;

    if (!originalType)      // semantic not yet run
    {
        TemplateInstance *spec = isSpeculative();
        unsigned olderrs = global.errors;
        unsigned oldgag = global.gag;
        if (global.gag && !spec)
            global.gag = 0;
        semantic(_scope);
        global.gag = oldgag;
        if (spec && global.errors != olderrs)
            spec->errors = (global.errors - olderrs != 0);
        if (olderrs != global.errors)   // if errors compiling this function
            return false;
    }

    // if inferring return type, sematic3 needs to be run
    // - When the function body contains any errors, we cannot assume
    //   the inferred return type is valid.
    //   So, the body errors should become the function signature error.
    if (inferRetType && type && !type->nextOf())
        return functionSemantic3();

    TemplateInstance *ti;
    if (isInstantiated() && !isVirtualMethod() &&
        ((ti = parent->isTemplateInstance()) == NULL || ti->isTemplateMixin() || ti->tempdecl->ident == ident))
    {
        AggregateDeclaration *ad = isMember2();
        if (ad && ad->sizeok != SIZEOKdone)
        {
            /* Currently dmd cannot resolve forward references per methods,
             * then setting SIZOKfwd is too conservative and would break existing code.
             * So, just stop method attributes inference until ad->semantic() done.
             */
            //ad->sizeok = SIZEOKfwd;
        }
        else
            return functionSemantic3() || !errors;
    }

    if (storage_class & STCinference)
        return functionSemantic3() || !errors;

    return !errors;
}

/****************************************************
 * Resolve forward reference of function body.
 * Returns false if any errors exist in the body.
 */
bool FuncDeclaration::functionSemantic3()
{
    if (semanticRun < PASSsemantic3 && _scope)
    {
        /* Forward reference - we need to run semantic3 on this function.
         * If errors are gagged, and it's not part of a template instance,
         * we need to temporarily ungag errors.
         */
        TemplateInstance *spec = isSpeculative();
        unsigned olderrs = global.errors;
        unsigned oldgag = global.gag;
        if (global.gag && !spec)
            global.gag = 0;
        semantic3(this, _scope);
        global.gag = oldgag;

        // If it is a speculatively-instantiated template, and errors occur,
        // we need to mark the template as having errors.
        if (spec && global.errors != olderrs)
            spec->errors = (global.errors - olderrs != 0);
        if (olderrs != global.errors)   // if errors compiling this function
            return false;
    }

    return !errors && !semantic3Errors;
}

/****************************************************
 * Check that this function type is properly resolved.
 * If not, report "forward reference error" and return true.
 */
bool FuncDeclaration::checkForwardRef(Loc loc)
{
    if (!functionSemantic())
        return true;

    /* No deco means the functionSemantic() call could not resolve
     * forward referenes in the type of this function.
     */
    if (!type->deco)
    {
        bool inSemantic3 = (inferRetType && semanticRun >= PASSsemantic3);
        ::error(loc, "forward reference to %s'%s'",
            (inSemantic3 ? "inferred return type of function " : ""),
            toChars());
        return true;
    }
    return false;
}

VarDeclaration *FuncDeclaration::declareThis(Scope *sc, AggregateDeclaration *ad)
{
    if (ad)
    {
        VarDeclaration *v;
        {
            //printf("declareThis() %s\n", toChars());
            Type *thandle = ad->handleType();
            assert(thandle);
            thandle = thandle->addMod(type->mod);
            thandle = thandle->addStorageClass(storage_class);
            v = new ThisDeclaration(loc, thandle);
            v->storage_class |= STCparameter;
            if (thandle->ty == Tstruct)
            {
                v->storage_class |= STCref;

                // if member function is marked 'inout', then 'this' is 'return ref'
                if (type->ty == Tfunction && ((TypeFunction *)type)->iswild & 2)
                    v->storage_class |= STCreturn;
            }
            if (type->ty == Tfunction)
            {
                TypeFunction *tf = (TypeFunction *)type;
                if (tf->isreturn)
                    v->storage_class |= STCreturn;
                if (tf->isscope)
                    v->storage_class |= STCscope;
            }
            if (flags & FUNCFLAGinferScope && !(v->storage_class & STCscope))
                v->storage_class |= STCmaybescope;

            v->semantic(sc);
            if (!sc->insert(v))
                assert(0);
            v->parent = this;
            return v;
        }
    }
    else if (isNested())
    {
        /* The 'this' for a nested function is the link to the
         * enclosing function's stack frame.
         * Note that nested functions and member functions are disjoint.
         */
        VarDeclaration *v = new ThisDeclaration(loc, Type::tvoid->pointerTo());
        v->storage_class |= STCparameter;
        if (type->ty == Tfunction)
        {
            TypeFunction *tf = (TypeFunction *)type;
            if (tf->isreturn)
                v->storage_class |= STCreturn;
            if (tf->isscope)
                v->storage_class |= STCscope;
        }
        if (flags & FUNCFLAGinferScope && !(v->storage_class & STCscope))
            v->storage_class |= STCmaybescope;

        v->semantic(sc);
        if (!sc->insert(v))
            assert(0);
        v->parent = this;
        return v;
    }

    return NULL;
}

bool FuncDeclaration::equals(RootObject *o)
{
    if (this == o)
        return true;

    Dsymbol *s = isDsymbol(o);
    if (s)
    {
        FuncDeclaration *fd1 = this;
        FuncDeclaration *fd2 = s->isFuncDeclaration();
        if (!fd2)
            return false;

        FuncAliasDeclaration *fa1 = fd1->isFuncAliasDeclaration();
        FuncAliasDeclaration *fa2 = fd2->isFuncAliasDeclaration();
        if (fa1 && fa2)
        {
            return fa1->toAliasFunc()->equals(fa2->toAliasFunc()) &&
                   fa1->hasOverloads == fa2->hasOverloads;
        }

        if (fa1 && (fd1 = fa1->toAliasFunc())->isUnique() && !fa1->hasOverloads)
            fa1 = NULL;
        if (fa2 && (fd2 = fa2->toAliasFunc())->isUnique() && !fa2->hasOverloads)
            fa2 = NULL;
        if ((fa1 != NULL) != (fa2 != NULL))
            return false;

        return fd1->toParent()->equals(fd2->toParent()) &&
            fd1->ident->equals(fd2->ident) && fd1->type->equals(fd2->type);
    }
    return false;
}

/****************************************************
 * Declare result variable lazily.
 */

void FuncDeclaration::buildResultVar(Scope *sc, Type *tret)
{
    if (!vresult)
    {
        Loc loc = fensure ? fensure->loc : this->loc;

        /* If inferRetType is true, tret may not be a correct return type yet.
         * So, in here it may be a temporary type for vresult, and after
         * fbody->semantic() running, vresult->type might be modified.
         */
        vresult = new VarDeclaration(loc, tret, Id::result, NULL);
        vresult->storage_class |= STCnodtor | STCtemp;
        if (!isVirtual())
            vresult->storage_class |= STCconst;
        vresult->storage_class |= STCresult;

        // set before the semantic() for checkNestedReference()
        vresult->parent = this;
    }

    if (sc && vresult->semanticRun == PASSinit)
    {
        TypeFunction *tf = type->toTypeFunction();
        if (tf->isref)
            vresult->storage_class |= STCref;
        vresult->type = tret;

        vresult->semantic(sc);

        if (!sc->insert(vresult))
            error("out result %s is already defined", vresult->toChars());
        assert(vresult->parent == this);
    }
}

/****************************************************
 * Merge into this function the 'in' contracts of all it overrides.
 * 'in's are OR'd together, i.e. only one of them needs to pass.
 */

Statement *FuncDeclaration::mergeFrequire(Statement *sf)
{
    /* If a base function and its override both have an IN contract, then
     * only one of them needs to succeed. This is done by generating:
     *
     * void derived.in() {
     *  try {
     *    base.in();
     *  }
     *  catch () {
     *    ... body of derived.in() ...
     *  }
     * }
     *
     * So if base.in() doesn't throw, derived.in() need not be executed, and the contract is valid.
     * If base.in() throws, then derived.in()'s body is executed.
     */

    /* Implementing this is done by having the overriding function call
     * nested functions (the fdrequire functions) nested inside the overridden
     * function. This requires that the stack layout of the calling function's
     * parameters and 'this' pointer be in the same place (as the nested
     * function refers to them).
     * This is easy for the parameters, as they are all on the stack in the same
     * place by definition, since it's an overriding function. The problem is
     * getting the 'this' pointer in the same place, since it is a local variable.
     * We did some hacks in the code generator to make this happen:
     *  1. always generate exception handler frame, or at least leave space for it
     *     in the frame (Windows 32 SEH only)
     *  2. always generate an EBP style frame
     *  3. since 'this' is passed in a register that is subsequently copied into
     *     a stack local, allocate that local immediately following the exception
     *     handler block, so it is always at the same offset from EBP.
     */
    for (size_t i = 0; i < foverrides.length; i++)
    {
        FuncDeclaration *fdv = foverrides[i];

        /* The semantic pass on the contracts of the overridden functions must
         * be completed before code generation occurs.
         * https://issues.dlang.org/show_bug.cgi?id=3602
         */
        if (fdv->frequires && fdv->semanticRun != PASSsemantic3done)
        {
            assert(fdv->_scope);
            Scope *sc = fdv->_scope->push();
            sc->stc &= ~STCoverride;
            semantic3(fdv, sc);
            sc->pop();
        }

        sf = fdv->mergeFrequire(sf);
        if (sf && fdv->fdrequire)
        {
            //printf("fdv->frequire: %s\n", fdv->frequire->toChars());
            /* Make the call:
             *   try { __require(); }
             *   catch (Throwable) { frequire; }
             */
            Expression *eresult = NULL;
            Expression *e = new CallExp(loc, new VarExp(loc, fdv->fdrequire, false), eresult);
            Statement *s2 = new ExpStatement(loc, e);

            Catch *c = new Catch(loc, getThrowable(), NULL, sf);
            c->internalCatch = true;
            Catches *catches = new Catches();
            catches->push(c);
            sf = new TryCatchStatement(loc, s2, catches);
        }
        else
            return NULL;
    }
    return sf;
}

/****************************************************
 * Merge into this function the 'out' contracts of all it overrides.
 * 'out's are AND'd together, i.e. all of them need to pass.
 */

Statement *FuncDeclaration::mergeFensure(Statement *sf, Identifier *oid)
{
    /* Same comments as for mergeFrequire(), except that we take care
     * of generating a consistent reference to the 'result' local by
     * explicitly passing 'result' to the nested function as a reference
     * argument.
     * This won't work for the 'this' parameter as it would require changing
     * the semantic code for the nested function so that it looks on the parameter
     * list for the 'this' pointer, something that would need an unknown amount
     * of tweaking of various parts of the compiler that I'd rather leave alone.
     */
    for (size_t i = 0; i < foverrides.length; i++)
    {
        FuncDeclaration *fdv = foverrides[i];

        /* The semantic pass on the contracts of the overridden functions must
         * be completed before code generation occurs.
         * https://issues.dlang.org/show_bug.cgi?id=3602 and
         * https://issues.dlang.org/show_bug.cgi?id=5230
         */
        if (needsFensure(fdv) && fdv->semanticRun != PASSsemantic3done)
        {
            assert(fdv->_scope);
            Scope *sc = fdv->_scope->push();
            sc->stc &= ~STCoverride;
            semantic3(fdv, sc);
            sc->pop();
        }

        sf = fdv->mergeFensure(sf, oid);
        if (fdv->fdensure)
        {
            //printf("fdv->fensure: %s\n", fdv->fensure->toChars());
            // Make the call: __ensure(result)
            Expression *eresult = NULL;
            if (canBuildResultVar(this))
            {
                eresult = new IdentifierExp(loc, oid);

                Type *t1 = fdv->type->nextOf()->toBasetype();
                Type *t2 = this->type->nextOf()->toBasetype();
                if (t1->isBaseOf(t2, NULL))
                {
                    /* Making temporary reference variable is necessary
                     * in covariant return.
                     * See bugzilla 5204 and 10479.
                     */
                    ExpInitializer *ei = new ExpInitializer(Loc(), eresult);
                    VarDeclaration *v = new VarDeclaration(Loc(), t1, Identifier::generateId("__covres"), ei);
                    v->storage_class |= STCtemp;
                    DeclarationExp *de = new DeclarationExp(Loc(), v);
                    VarExp *ve = new VarExp(Loc(), v);
                    eresult = new CommaExp(Loc(), de, ve);
                }
            }
            Expression *e = new CallExp(loc, new VarExp(loc, fdv->fdensure, false), eresult);
            Statement *s2 = new ExpStatement(loc, e);

            if (sf)
            {
                sf = new CompoundStatement(sf->loc, s2, sf);
            }
            else
                sf = s2;
        }
    }
    return sf;
}

/****************************************************
 * Determine if 'this' overrides fd.
 * Return !=0 if it does.
 */

int FuncDeclaration::overrides(FuncDeclaration *fd)
{   int result = 0;

    if (fd->ident == ident)
    {
        int cov = type->covariant(fd->type);
        if (cov)
        {   ClassDeclaration *cd1 = toParent()->isClassDeclaration();
            ClassDeclaration *cd2 = fd->toParent()->isClassDeclaration();

            if (cd1 && cd2 && cd2->isBaseOf(cd1, NULL))
                result = 1;
        }
    }
    return result;
}

/*************************************************
 * Find index of function in vtbl[0..length] that
 * this function overrides.
 * Prefer an exact match to a covariant one.
 * Params:
 *      fix17349 = enable fix https://issues.dlang.org/show_bug.cgi?id=17349
 * Returns:
 *      -1      didn't find one
 *      -2      can't determine because of forward references
 */

int FuncDeclaration::findVtblIndex(Dsymbols *vtbl, int dim, bool fix17349)
{
    //printf("findVtblIndex() %s\n", toChars());
    FuncDeclaration *mismatch = NULL;
    StorageClass mismatchstc = 0;
    int mismatchvi = -1;
    int exactvi = -1;
    int bestvi = -1;
    for (int vi = 0; vi < dim; vi++)
    {
        FuncDeclaration *fdv = (*vtbl)[vi]->isFuncDeclaration();
        if (fdv && fdv->ident == ident)
        {
            if (type->equals(fdv->type))        // if exact match
            {
                if (fdv->parent->isClassDeclaration())
                {
                    if (fdv->isFuture())
                    {
                        bestvi = vi;
                        continue;           // keep looking
                    }
                    return vi;                  // no need to look further
                }

                if (exactvi >= 0)
                {
                    error("cannot determine overridden function");
                    return exactvi;
                }
                exactvi = vi;

                bestvi = vi;
                continue;
            }

            StorageClass stc = 0;
            int cov = type->covariant(fdv->type, &stc, fix17349);
            //printf("\tbaseclass cov = %d\n", cov);
            switch (cov)
            {
                case 0:         // types are distinct
                    break;

                case 1:
                    bestvi = vi;        // covariant, but not identical
                    break;              // keep looking for an exact match

                case 2:
                    mismatchvi = vi;
                    mismatchstc = stc;
                    mismatch = fdv;     // overrides, but is not covariant
                    break;              // keep looking for an exact match

                case 3:
                    return -2;  // forward references

                default:
                    assert(0);
            }
        }
    }
    if (bestvi == -1 && mismatch)
    {
        //type->print();
        //mismatch->type->print();
        //printf("%s %s\n", type->deco, mismatch->type->deco);
        //printf("stc = %llx\n", mismatchstc);
        if (mismatchstc)
        {   // Fix it by modifying the type to add the storage classes
            type = type->addStorageClass(mismatchstc);
            bestvi = mismatchvi;
        }
    }
    return bestvi;
}

/*********************************
 * If function a function in a base class,
 * return that base class.
 * Params:
 *  cd = class that function is in
 * Returns:
 *  base class if overriding, NULL if not
 */
BaseClass *FuncDeclaration::overrideInterface()
{
    ClassDeclaration *cd = parent->isClassDeclaration();
    for (size_t i = 0; i < cd->interfaces.length; i++)
    {
        BaseClass *b = cd->interfaces.ptr[i];
        int v = findVtblIndex((Dsymbols *)&b->sym->vtbl, (int)b->sym->vtbl.length);
        if (v >= 0)
            return b;
    }
    return NULL;
}

/****************************************************
 * Overload this FuncDeclaration with the new one f.
 * Return true if successful; i.e. no conflict.
 */

bool FuncDeclaration::overloadInsert(Dsymbol *s)
{
    //printf("FuncDeclaration::overloadInsert(s = %s) this = %s\n", s->toChars(), toChars());
    assert(s != this);

    AliasDeclaration *ad = s->isAliasDeclaration();
    if (ad)
    {
        if (overnext)
            return overnext->overloadInsert(ad);
        if (!ad->aliassym && ad->type->ty != Tident && ad->type->ty != Tinstance)
        {
            //printf("\tad = '%s'\n", ad->type->toChars());
            return false;
        }
        overnext = ad;
        //printf("\ttrue: no conflict\n");
        return true;
    }
    TemplateDeclaration *td = s->isTemplateDeclaration();
    if (td)
    {
        if (!td->funcroot)
            td->funcroot = this;
        if (overnext)
            return overnext->overloadInsert(td);
        overnext = td;
        return true;
    }
    FuncDeclaration *fd = s->isFuncDeclaration();
    if (!fd)
        return false;

    if (overnext)
    {
        td = overnext->isTemplateDeclaration();
        if (td)
            fd->overloadInsert(td);
        else
            return overnext->overloadInsert(fd);
    }
    overnext = fd;
    //printf("\ttrue: no conflict\n");
    return true;
}

/***************************************************
 * Visit each overloaded function/template in turn, and call
 * (*fp)(param, s) on it.
 * Exit when no more, or (*fp)(param, f) returns nonzero.
 * Returns:
 *      ==0     continue
 *      !=0     done
 */

int overloadApply(Dsymbol *fstart, void *param, int (*fp)(void *, Dsymbol *))
{
    Dsymbol *d;
    Dsymbol *next;
    for (d = fstart; d; d = next)
    {
        if (OverDeclaration *od = d->isOverDeclaration())
        {
            if (od->hasOverloads)
            {
                if (int r = overloadApply(od->aliassym, param, fp))
                    return r;
            }
            else
            {
                if (int r = (*fp)(param, od->aliassym))
                    return r;
            }
            next = od->overnext;
        }
        else if (FuncAliasDeclaration *fa = d->isFuncAliasDeclaration())
        {
            if (fa->hasOverloads)
            {
                if (int r = overloadApply(fa->funcalias, param, fp))
                    return r;
            }
            else
            {
                FuncDeclaration *fd = fa->toAliasFunc();
                if (!fd)
                {
                    d->error("is aliased to a function");
                    break;
                }
                if (int r = (*fp)(param, fd))
                    return r;
            }
            next = fa->overnext;
        }
        else if (AliasDeclaration *ad = d->isAliasDeclaration())
        {
            next = ad->toAlias();
            if (next == ad)
                break;
            if (next == fstart)
                break;
        }
        else if (TemplateDeclaration *td = d->isTemplateDeclaration())
        {
            if (int r = (*fp)(param, td))
                return r;
            next = td->overnext;
        }
        else
        {
            FuncDeclaration *fd = d->isFuncDeclaration();
            if (!fd)
            {
                d->error("is aliased to a function");
                break;              // BUG: should print error message?
            }
            if (int r = (*fp)(param, fd))
                return r;
            next = fd->overnext;
        }
    }
    return 0;
}

/********************************************
 * If there are no overloads of function f, return that function,
 * otherwise return NULL.
 */

FuncDeclaration *FuncDeclaration::isUnique()
{
  struct ParamUnique
  {
    static int fp(void *param, Dsymbol *s)
    {
        FuncDeclaration *f = s->isFuncDeclaration();
        if (!f)
            return 0;
        FuncDeclaration **pf = (FuncDeclaration **)param;

        if (*pf)
        {
            *pf = NULL;
            return 1;               // ambiguous, done
        }
        else
        {
            *pf = f;
            return 0;
        }
    }
  };
    FuncDeclaration *result = NULL;
    overloadApply(this, &result, &ParamUnique::fp);
    return result;
}

/********************************************
 * Find function in overload list that exactly matches t.
 */

FuncDeclaration *FuncDeclaration::overloadExactMatch(Type *t)
{
  struct ParamExact
  {
    Type *t;            // type to match
    FuncDeclaration *f; // return value

    static int fp(void *param, Dsymbol *s)
    {
        FuncDeclaration *f = s->isFuncDeclaration();
        if (!f)
            return 0;
        ParamExact *p = (ParamExact *)param;
        Type *t = p->t;

        if (t->equals(f->type))
        {
            p->f = f;
            return 1;
        }

        /* Allow covariant matches, as long as the return type
         * is just a const conversion.
         * This allows things like pure functions to match with an impure function type.
         */
        if (t->ty == Tfunction)
        {   TypeFunction *tf = (TypeFunction *)f->type;
            if (tf->covariant(t) == 1 &&
                tf->nextOf()->implicitConvTo(t->nextOf()) >= MATCHconst)
            {
                p->f = f;
                return 1;
            }
        }
        return 0;
    }
  };
    ParamExact p;
    p.t = t;
    p.f = NULL;
    overloadApply(this, &p, &ParamExact::fp);
    return p.f;
}

void MODMatchToBuffer(OutBuffer *buf, unsigned char lhsMod, unsigned char rhsMod)
{
    bool bothMutable = ((lhsMod & rhsMod) == 0);
    bool sharedMismatch = ((lhsMod ^ rhsMod) & MODshared) != 0;
    bool sharedMismatchOnly = ((lhsMod ^ rhsMod) == MODshared);

    if (lhsMod & MODshared)
        buf->writestring("shared ");
    else if (sharedMismatch && !(lhsMod & MODimmutable))
        buf->writestring("non-shared ");

    if (bothMutable && sharedMismatchOnly)
    { }
    else if (lhsMod & MODimmutable)
        buf->writestring("immutable ");
    else if (lhsMod & MODconst)
        buf->writestring("const ");
    else if (lhsMod & MODwild)
        buf->writestring("inout ");
    else
        buf->writestring("mutable ");
}

/********************************************
 * Find function in overload list that matches to the 'this' modifier.
 * There's four result types.
 *
 * 1. If the 'tthis' matches only one candidate, it's an "exact match".
 *    Returns the function and 'hasOverloads' is set to false.
 *      eg. If 'tthis" is mutable and there's only one mutable method.
 * 2. If there's two or more match candidates, but a candidate function will be
 *    a "better match".
 *    Returns the better match function but 'hasOverloads' is set to true.
 *      eg. If 'tthis' is mutable, and there's both mutable and const methods,
 *          the mutable method will be a better match.
 * 3. If there's two or more match candidates, but there's no better match,
 *    Returns NULL and 'hasOverloads' is set to true to represent "ambiguous match".
 *      eg. If 'tthis' is mutable, and there's two or more mutable methods.
 * 4. If there's no candidates, it's "no match" and returns NULL with error report.
 *      e.g. If 'tthis' is const but there's no const methods.
 */
FuncDeclaration *FuncDeclaration::overloadModMatch(Loc loc, Type *tthis, bool &hasOverloads)
{
    //printf("FuncDeclaration::overloadModMatch('%s')\n", toChars());
    Match m;
    memset(&m, 0, sizeof(m));
    m.last = MATCHnomatch;

  struct ParamMod
  {
    Match *m;
    Type *tthis;

    static int fp(void *param, Dsymbol *s)
    {
        if (FuncDeclaration *fd = s->isFuncDeclaration())
            return ((ParamMod *)param)->fp(fd);
        return 0;
    }
    int fp(FuncDeclaration *f)
    {
        if (f == m->lastf)          // skip duplicates
            return 0;

        m->anyf = f;
        TypeFunction *tf = f->type->toTypeFunction();
        //printf("tf = %s\n", tf->toChars());

        MATCH match;
        if (tthis)   // non-static functions are preferred than static ones
        {
            if (f->needThis())
                match = f->isCtorDeclaration() ? MATCHexact : MODmethodConv(tthis->mod, tf->mod);
            else
                match = MATCHconst; // keep static funciton in overload candidates
        }
        else            // static functions are preferred than non-static ones
        {
            if (f->needThis())
                match = MATCHconvert;
            else
                match = MATCHexact;
        }
        if (match != MATCHnomatch)
        {
            if (match > m->last) goto LfIsBetter;
            if (match < m->last) goto LlastIsBetter;

            /* See if one of the matches overrides the other.
             */
            if (m->lastf->overrides(f)) goto LlastIsBetter;
            if (f->overrides(m->lastf)) goto LfIsBetter;

            //printf("\tambiguous\n");
            m->nextf = f;
            m->count++;
            return 0;

        LlastIsBetter:
            //printf("\tlastbetter\n");
            m->count++; // count up
            return 0;

        LfIsBetter:
            //printf("\tisbetter\n");
            if (m->last <= MATCHconvert)
            {
                // clear last secondary matching
                m->nextf = NULL;
                m->count = 0;
            }
            m->last = match;
            m->lastf = f;
            m->count++;     // count up
            return 0;
        }
        return 0;
    }
  };
    ParamMod p;
    p.m = &m;
    p.tthis = tthis;
    overloadApply(this, &p, &ParamMod::fp);

    if (m.count == 1)       // exact match
    {
        hasOverloads = false;
    }
    else if (m.count > 1)   // better or ambiguous match
    {
        hasOverloads = true;
    }
    else                    // no match
    {
        hasOverloads = true;
        TypeFunction *tf = this->type->toTypeFunction();
        assert(tthis);
        assert(!MODimplicitConv(tthis->mod, tf->mod));  // modifier mismatch
        {
            OutBuffer thisBuf, funcBuf;
            MODMatchToBuffer(&thisBuf, tthis->mod, tf->mod);
            MODMatchToBuffer(&funcBuf, tf->mod, tthis->mod);
            ::error(loc, "%smethod %s is not callable using a %sobject",
                funcBuf.peekChars(), this->toPrettyChars(), thisBuf.peekChars());
        }
    }

    return m.lastf;
}

/********************************************
 * Returns true if function was declared
 * directly or indirectly in a unittest block
 */
bool FuncDeclaration::inUnittest()
{
    Dsymbol *f = this;
    do
    {
        if (f->isUnitTestDeclaration())
            return true;
        f = f->toParent();
    } while (f);

    return false;
}

/********************************************
 * find function template root in overload list
 */

TemplateDeclaration *FuncDeclaration::findTemplateDeclRoot()
{
    FuncDeclaration *f = this;
    while (f && f->overnext)
    {
        //printf("f->overnext = %p %s\n", f->overnext, f->overnext->toChars());
        TemplateDeclaration *td = f->overnext->isTemplateDeclaration();
        if (td)
            return td;
        f = f->overnext->isFuncDeclaration();
    }
    return NULL;
}

/*************************************
 * Determine partial specialization order of 'this' vs g.
 * This is very similar to TemplateDeclaration::leastAsSpecialized().
 * Returns:
 *      match   'this' is at least as specialized as g
 *      0       g is more specialized than 'this'
 */

MATCH FuncDeclaration::leastAsSpecialized(FuncDeclaration *g)
{
    /* This works by calling g() with f()'s parameters, and
     * if that is possible, then f() is at least as specialized
     * as g() is.
     */

    TypeFunction *tf = type->toTypeFunction();
    TypeFunction *tg = g->type->toTypeFunction();
    size_t nfparams = tf->parameterList.length();

    /* If both functions have a 'this' pointer, and the mods are not
     * the same and g's is not const, then this is less specialized.
     */
    if (needThis() && g->needThis() && tf->mod != tg->mod)
    {
        if (isCtorDeclaration())
        {
            if (!MODimplicitConv(tg->mod, tf->mod))
                return MATCHnomatch;
        }
        else
        {
            if (!MODimplicitConv(tf->mod, tg->mod))
                return MATCHnomatch;
        }
    }

    /* Create a dummy array of arguments out of the parameters to f()
     */
    Expressions args;
    args.setDim(nfparams);
    for (size_t u = 0; u < nfparams; u++)
    {
        Parameter *p = tf->parameterList[u];
        Expression *e;
        if (p->storageClass & (STCref | STCout))
        {
            e = new IdentifierExp(Loc(), p->ident);
            e->type = p->type;
        }
        else
            e = p->type->defaultInitLiteral(Loc());
        args[u] = e;
    }

    MATCH m = (MATCH) tg->callMatch(NULL, &args, 1);
    if (m > MATCHnomatch)
    {
        /* A variadic parameter list is less specialized than a
         * non-variadic one.
         */
        if (tf->parameterList.varargs && !tg->parameterList.varargs)
            goto L1;    // less specialized

        return m;
    }
  L1:
    return MATCHnomatch;
}

/// Walk through candidate template overloads and print them in the diagnostics.
struct TemplateCandidateWalker
{
    Loc loc;
    int numToDisplay;  // max num of overloads to print (-v overrides this).

    /// Count template overloads.
    struct CountWalker
    {
        int numOverloads;

        static int fp(void *param, Dsymbol *)
        {
            CountWalker *p = (CountWalker *)param;
            ++(p->numOverloads);
            return 0;
        }
    };

    static int fp(void *param, Dsymbol *s)
    {
        TemplateDeclaration *t = s->isTemplateDeclaration();
        if (!t) return 0;

        TemplateCandidateWalker *p = (TemplateCandidateWalker *)param;

        ::errorSupplemental(t->loc, "%s", t->toPrettyChars());

        if (!global.params.verbose && --(p->numToDisplay) == 0 && t->overnext)
        {
            // Too many overloads to sensibly display.
            // Just show count of remaining overloads.
            CountWalker cw;
            cw.numOverloads = 0;
            overloadApply(t->overnext, &cw, &CountWalker::fp);

            if (cw.numOverloads > 0)
                ::errorSupplemental(p->loc, "... (%d more, -v to show) ...", cw.numOverloads);

            return 1;  // stop iterating
        }

        return 0;
    }
};

/// Walk through candidate template overloads and print them in the diagnostics.
struct FuncCandidateWalker
{
    Loc loc;
    int numToDisplay;  // max num of overloads to print (-v overrides this).

    /// Count function overloads.
    struct CountWalker
    {
        int numOverloads;

        static int fp(void *param, Dsymbol *)
        {
            CountWalker *p = (CountWalker *)param;
            ++(p->numOverloads);
            return 0;
        }
    };

    static int fp(void *param, Dsymbol *s)
    {
        FuncDeclaration *fd = s->isFuncDeclaration();
        TemplateDeclaration *td = s->isTemplateDeclaration();
        if (fd)
        {
            if (fd->errors || fd->type->ty == Terror)
                return 0;

            TypeFunction *tf = (TypeFunction *)fd->type;

            ::errorSupplemental(fd->loc, "%s%s", fd->toPrettyChars(),
                parametersTypeToChars(tf->parameterList));
        }
        else
        {
            ::errorSupplemental(td->loc, "%s", td->toPrettyChars());
        }

        FuncCandidateWalker *p = (FuncCandidateWalker *)param;
        if (global.params.verbose || --(p->numToDisplay) != 0 || !fd)
            return 0;

        // Too many overloads to sensibly display.
        CountWalker cw;
        cw.numOverloads = 0;
        overloadApply(fd->overnext, &cw, &CountWalker::fp);

        if (cw.numOverloads > 0)
            ::errorSupplemental(p->loc, "... (%d more, -v to show) ...", cw.numOverloads);

        return 1;  // stop iterating
    }
};

/*******************************************
 * Given a symbol that could be either a FuncDeclaration or
 * a function template, resolve it to a function symbol.
 *      loc             instantiation location
 *      sc              instantiation scope
 *      tiargs          initial list of template arguments
 *      tthis           if !NULL, the 'this' pointer argument
 *      fargs           arguments to function
 *      flags           1: do not issue error message on no match, just return NULL
 *                      2: overloadResolve only
 */

FuncDeclaration *resolveFuncCall(Loc loc, Scope *sc, Dsymbol *s,
        Objects *tiargs, Type *tthis, Expressions *fargs, int flags)
{
    if (!s)
        return NULL;                    // no match

    if ((tiargs && arrayObjectIsError(tiargs)) ||
        (fargs  && arrayObjectIsError((Objects *)fargs)))
    {
        return NULL;
    }

    Match m;
    memset(&m, 0, sizeof(m));
    m.last = MATCHnomatch;

    functionResolve(&m, s, loc, sc, tiargs, tthis, fargs);

    if (m.last > MATCHnomatch && m.lastf)
    {
        if (m.count == 1)   // exactly one match
        {
            if (!(flags & 1))
                m.lastf->functionSemantic();
            return m.lastf;
        }
        if ((flags & 2) && !tthis && m.lastf->needThis())
        {
            return m.lastf;
        }
    }

    /* Failed to find a best match.
     * Do nothing or print error.
     */
    if (m.last <= MATCHnomatch)
    {
        // error was caused on matched function
        if (m.count == 1)
            return m.lastf;

        // if do not print error messages
        if (flags & 1)
            return NULL;    // no match
    }

    FuncDeclaration *fd = s->isFuncDeclaration();
    OverDeclaration *od = s->isOverDeclaration();
    TemplateDeclaration *td = s->isTemplateDeclaration();
    if (td && td->funcroot)
        s = fd = td->funcroot;

    OutBuffer tiargsBuf;
    arrayObjectsToBuffer(&tiargsBuf, tiargs);

    OutBuffer fargsBuf;
    fargsBuf.writeByte('(');
    argExpTypesToCBuffer(&fargsBuf, fargs);
    fargsBuf.writeByte(')');
    if (tthis)
        tthis->modToBuffer(&fargsBuf);

    const int numOverloadsDisplay = 5; // sensible number to display

    if (!m.lastf && !(flags & 1))   // no match
    {
        if (td && !fd)  // all of overloads are templates
        {
            ::error(loc, "%s %s.%s cannot deduce function from argument types !(%s)%s, candidates are:",
                    td->kind(), td->parent->toPrettyChars(), td->ident->toChars(),
                    tiargsBuf.peekChars(), fargsBuf.peekChars());

            // Display candidate templates (even if there are no multiple overloads)
            TemplateCandidateWalker tcw;
            tcw.loc = loc;
            tcw.numToDisplay = numOverloadsDisplay;
            overloadApply(td, &tcw, &TemplateCandidateWalker::fp);
        }
        else if (od)
        {
            ::error(loc, "none of the overloads of '%s' are callable using argument types !(%s)%s",
                od->ident->toChars(), tiargsBuf.peekChars(), fargsBuf.peekChars());
        }
        else
        {
            assert(fd);

            bool hasOverloads = fd->overnext != NULL;
            TypeFunction *tf = fd->type->toTypeFunction();
            if (tthis && !MODimplicitConv(tthis->mod, tf->mod)) // modifier mismatch
            {
                OutBuffer thisBuf, funcBuf;
                MODMatchToBuffer(&thisBuf, tthis->mod, tf->mod);
                MODMatchToBuffer(&funcBuf, tf->mod, tthis->mod);
                if (hasOverloads)
                    ::error(loc, "none of the overloads of '%s' are callable using a %sobject, candidates are:",
                        fd->ident->toChars(), thisBuf.peekChars());
                else
                    ::error(loc, "%smethod %s is not callable using a %sobject",
                        funcBuf.peekChars(), fd->toPrettyChars(), thisBuf.peekChars());
            }
            else
            {
                //printf("tf = %s, args = %s\n", tf->deco, (*fargs)[0]->type->deco);
                if (hasOverloads)
                    ::error(loc, "none of the overloads of '%s' are callable using argument types %s, candidates are:",
                            fd->ident->toChars(), fargsBuf.peekChars());
                else
                    fd->error(loc, "%s%s is not callable using argument types %s",
                        parametersTypeToChars(tf->parameterList),
                        tf->modToChars(),
                        fargsBuf.peekChars());
            }

            // Display candidate functions
            if (hasOverloads)
            {
                FuncCandidateWalker fcw;
                fcw.loc = loc;
                fcw.numToDisplay = numOverloadsDisplay;
                overloadApply(fd, &fcw, &FuncCandidateWalker::fp);
            }
        }
    }
    else if (m.nextf)
    {
        TypeFunction *tf1 = m.lastf->type->toTypeFunction();
        TypeFunction *tf2 = m.nextf->type->toTypeFunction();
        const char *lastprms = parametersTypeToChars(tf1->parameterList);
        const char *nextprms = parametersTypeToChars(tf2->parameterList);
        ::error(loc, "%s.%s called with argument types %s matches both:\n"
                     "%s:     %s%s\nand:\n%s:     %s%s",
                s->parent->toPrettyChars(), s->ident->toChars(),
                fargsBuf.peekChars(),
                m.lastf->loc.toChars(), m.lastf->toPrettyChars(), lastprms,
                m.nextf->loc.toChars(), m.nextf->toPrettyChars(), nextprms);
    }
    return NULL;
}

/********************************
 * Labels are in a separate scope, one per function.
 */

LabelDsymbol *FuncDeclaration::searchLabel(Identifier *ident)
{   Dsymbol *s;

    if (!labtab)
        labtab = new DsymbolTable();    // guess we need one

    s = labtab->lookup(ident);
    if (!s)
    {
        s = new LabelDsymbol(ident);
        labtab->insert(s);
    }
    return (LabelDsymbol *)s;
}

/*****************************************
 * Determine lexical level difference from 'this' to nested function 'fd'.
 * Error if this cannot call fd.
 * Returns:
 *      0       same level
 *      >0      decrease nesting by number
 *      -1      increase nesting by 1 (fd is nested within 'this')
 *      -2      error
 */

int FuncDeclaration::getLevel(Loc loc, Scope *sc, FuncDeclaration *fd)
{
    int level;
    Dsymbol *s;
    Dsymbol *fdparent;

    //printf("FuncDeclaration::getLevel(fd = '%s')\n", fd->toChars());
    fdparent = fd->toParent2();
    if (fdparent == this)
        return -1;
    s = this;
    level = 0;
    while (fd != s && fdparent != s->toParent2())
    {
        //printf("\ts = %s, '%s'\n", s->kind(), s->toChars());
        FuncDeclaration *thisfd = s->isFuncDeclaration();
        if (thisfd)
        {
            if (!thisfd->isNested() && !thisfd->vthis && !sc->intypeof)
                goto Lerr;
        }
        else
        {
            AggregateDeclaration *thiscd = s->isAggregateDeclaration();
            if (thiscd)
            {
                /* AggregateDeclaration::isNested returns true only when
                 * it has a hidden pointer.
                 * But, calling the function belongs unrelated lexical scope
                 * is still allowed inside typeof.
                 *
                 * struct Map(alias fun) {
                 *   typeof({ return fun(); }) RetType;
                 *   // No member function makes Map struct 'not nested'.
                 * }
                 */
                if (!thiscd->isNested() && !sc->intypeof)
                    goto Lerr;
            }
            else
                goto Lerr;
        }

        s = s->toParent2();
        assert(s);
        level++;
    }
    return level;

Lerr:
    // Don't give error if in template constraint
    if (!(sc->flags & SCOPEconstraint))
    {
        const char *xstatic = isStatic() ? "static " : "";
        // better diagnostics for static functions
        ::error(loc, "%s%s %s cannot access frame of function %s",
            xstatic, kind(), toPrettyChars(), fd->toPrettyChars());
        return -2;
    }
    return 1;
}

const char *FuncDeclaration::toPrettyChars(bool QualifyTypes)
{
    if (isMain())
        return "D main";
    else
        return Dsymbol::toPrettyChars(QualifyTypes);
}

/** for diagnostics, e.g. 'int foo(int x, int y) pure' */
const char *FuncDeclaration::toFullSignature()
{
    OutBuffer buf;
    functionToBufferWithIdent(type->toTypeFunction(), &buf, toChars());
    return buf.extractChars();
}

bool FuncDeclaration::isMain()
{
    return ident == Id::main &&
        linkage != LINKc && !isMember() && !isNested();
}

bool FuncDeclaration::isCMain()
{
    return ident == Id::main &&
        linkage == LINKc && !isMember() && !isNested();
}

bool FuncDeclaration::isWinMain()
{
    //printf("FuncDeclaration::isWinMain() %s\n", toChars());
    return ident == Id::WinMain &&
        linkage != LINKc && !isMember();
}

bool FuncDeclaration::isDllMain()
{
    return ident == Id::DllMain &&
        linkage != LINKc && !isMember();
}

bool FuncDeclaration::isExport() const
{
    return protection.kind == Prot::export_;
}

bool FuncDeclaration::isImportedSymbol() const
{
    //printf("isImportedSymbol()\n");
    //printf("protection = %d\n", protection);
    return (protection.kind == Prot::export_) && !fbody;
}

// Determine if function goes into virtual function pointer table

bool FuncDeclaration::isVirtual()
{
    if (toAliasFunc() != this)
        return toAliasFunc()->isVirtual();

    Dsymbol *p = toParent();
    return isMember() &&
        !(isStatic() || protection.kind == Prot::private_ || protection.kind == Prot::package_) &&
        p->isClassDeclaration() &&
        !(p->isInterfaceDeclaration() && isFinalFunc());
}

// Determine if a function is pedantically virtual

bool FuncDeclaration::isVirtualMethod()
{
    if (toAliasFunc() != this)
        return toAliasFunc()->isVirtualMethod();

    //printf("FuncDeclaration::isVirtualMethod() %s\n", toChars());
    if (!isVirtual())
        return false;
    // If it's a final method, and does not override anything, then it is not virtual
    if (isFinalFunc() && foverrides.length == 0)
    {
        return false;
    }
    return true;
}

bool FuncDeclaration::isFinalFunc()
{
    if (toAliasFunc() != this)
        return toAliasFunc()->isFinalFunc();

    ClassDeclaration *cd;
    return isMember() &&
        (Declaration::isFinal() ||
         ((cd = toParent()->isClassDeclaration()) != NULL && cd->storage_class & STCfinal));
}

bool FuncDeclaration::isCodeseg() const
{
    return true;                // functions are always in the code segment
}

bool FuncDeclaration::isOverloadable()
{
    return true;                // functions can be overloaded
}

PURE FuncDeclaration::isPure()
{
    //printf("FuncDeclaration::isPure() '%s'\n", toChars());
    TypeFunction *tf = type->toTypeFunction();
    if (flags & FUNCFLAGpurityInprocess)
        setImpure();
    if (tf->purity == PUREfwdref)
        tf->purityLevel();
    PURE purity = tf->purity;
    if (purity > PUREweak && isNested())
        purity = PUREweak;
    if (purity > PUREweak && needThis())
    {
        // The attribute of the 'this' reference affects purity strength
        if (type->mod & MODimmutable)
            ;
        else if (type->mod & (MODconst | MODwild) && purity >= PUREconst)
            purity = PUREconst;
        else
            purity = PUREweak;
    }
    tf->purity = purity;
    // ^ This rely on the current situation that every FuncDeclaration has a
    //   unique TypeFunction.
    return purity;
}

PURE FuncDeclaration::isPureBypassingInference()
{
    if (flags & FUNCFLAGpurityInprocess)
        return PUREfwdref;
    else
        return isPure();
}

/**************************************
 * The function is doing something impure,
 * so mark it as impure.
 * If there's a purity error, return true.
 */
bool FuncDeclaration::setImpure()
{
    if (flags & FUNCFLAGpurityInprocess)
    {
        flags &= ~FUNCFLAGpurityInprocess;
        if (fes)
            fes->func->setImpure();
    }
    else if (isPure())
        return true;
    return false;
}

bool FuncDeclaration::isSafe()
{
    if (flags & FUNCFLAGsafetyInprocess)
        setUnsafe();
    return type->toTypeFunction()->trust == TRUSTsafe;
}

bool FuncDeclaration::isSafeBypassingInference()
{
    return !(flags & FUNCFLAGsafetyInprocess) && isSafe();
}

bool FuncDeclaration::isTrusted()
{
    if (flags & FUNCFLAGsafetyInprocess)
        setUnsafe();
    return type->toTypeFunction()->trust == TRUSTtrusted;
}

/**************************************
 * The function is doing something unsave,
 * so mark it as unsafe.
 * If there's a safe error, return true.
 */
bool FuncDeclaration::setUnsafe()
{
    if (flags & FUNCFLAGsafetyInprocess)
    {
        flags &= ~FUNCFLAGsafetyInprocess;
        type->toTypeFunction()->trust = TRUSTsystem;
        if (fes)
            fes->func->setUnsafe();
    }
    else if (isSafe())
        return true;
    return false;
}

bool FuncDeclaration::isNogc()
{
    if (flags & FUNCFLAGnogcInprocess)
        setGC();
    return type->toTypeFunction()->isnogc;
}

bool FuncDeclaration::isNogcBypassingInference()
{
    return !(flags & FUNCFLAGnogcInprocess) && isNogc();
}

/**************************************
 * The function is doing something that may allocate with the GC,
 * so mark it as not nogc (not no-how).
 * Returns:
 *      true if function is marked as @nogc, meaning a user error occurred
 */
bool FuncDeclaration::setGC()
{
    if (flags & FUNCFLAGnogcInprocess)
    {
        flags &= ~FUNCFLAGnogcInprocess;
        type->toTypeFunction()->isnogc = false;
        if (fes)
            fes->func->setGC();
    }
    else if (isNogc())
        return true;
    return false;
}

/**************************************
 * Returns an indirect type one step from t.
 */

Type *getIndirection(Type *t)
{
    t = t->baseElemOf();
    if (t->ty == Tarray || t->ty == Tpointer)
        return t->nextOf()->toBasetype();
    if (t->ty == Taarray || t->ty == Tclass)
        return t;
    if (t->ty == Tstruct)
        return t->hasPointers() ? t : NULL; // TODO

    // should consider TypeDelegate?
    return NULL;
}

/**************************************
 * Returns true if memory reachable through a reference B to a value of type tb,
 * which has been constructed with a reference A to a value of type ta
 * available, can alias memory reachable from A based on the types involved
 * (either directly or via any number of indirections).
 *
 * Note that this relation is not symmetric in the two arguments. For example,
 * a const(int) reference can point to a pre-existing int, but not the other
 * way round.
 */
bool traverseIndirections(Type *ta, Type *tb, void *p = NULL, bool reversePass = false)
{
    Type *source = ta;
    Type *target = tb;
    if (reversePass)
    {
        source = tb;
        target = ta;
    }

    if (source->constConv(target))
        return true;
    else if (target->ty == Tvoid && MODimplicitConv(source->mod, target->mod))
        return true;

    // No direct match, so try breaking up one of the types (starting with tb).
    Type *tbb = tb->toBasetype()->baseElemOf();
    if (tbb != tb)
        return traverseIndirections(ta, tbb, p, reversePass);

    // context date to detect circular look up
    struct Ctxt
    {
        Ctxt *prev;
        Type *type;
    };
    Ctxt *ctxt = (Ctxt *)p;

    if (tb->ty == Tclass || tb->ty == Tstruct)
    {
        for (Ctxt *c = ctxt; c; c = c->prev)
            if (tb == c->type) return false;
        Ctxt c;
        c.prev = ctxt;
        c.type = tb;

        AggregateDeclaration *sym = tb->toDsymbol(NULL)->isAggregateDeclaration();
        for (size_t i = 0; i < sym->fields.length; i++)
        {
            VarDeclaration *v = sym->fields[i];
            Type *tprmi = v->type->addMod(tb->mod);
            //printf("\ttb = %s, tprmi = %s\n", tb->toChars(), tprmi->toChars());
            if (traverseIndirections(ta, tprmi, &c, reversePass))
                return true;
        }
    }
    else if (tb->ty == Tarray || tb->ty == Taarray || tb->ty == Tpointer)
    {
        Type *tind = tb->nextOf();
        if (traverseIndirections(ta, tind, ctxt, reversePass))
            return true;
    }
    else if (tb->hasPointers())
    {
        // FIXME: function pointer/delegate types should be considered.
        return true;
    }

    // Still no match, so try breaking up ta if we have note done so yet.
    if (!reversePass)
        return traverseIndirections(tb, ta, ctxt, true);

    return false;
}

/********************************************
 * Returns true if the function return value has no indirection
 * which comes from the parameters.
 */

bool FuncDeclaration::isolateReturn()
{
    TypeFunction *tf = type->toTypeFunction();
    assert(tf->next);

    Type *treti = tf->next;
    treti = tf->isref ? treti : getIndirection(treti);
    if (!treti)
        return true;    // target has no mutable indirection
    return parametersIntersect(treti);
}

/********************************************
 * Returns true if an object typed t can have indirections
 * which come from the parameters.
 */

bool FuncDeclaration::parametersIntersect(Type *t)
{
    assert(t);
    if (!isPureBypassingInference() || isNested())
        return false;

    TypeFunction *tf = type->toTypeFunction();

    //printf("parametersIntersect(%s) t = %s\n", tf->toChars(), t->toChars());

    size_t dim = tf->parameterList.length();
    for (size_t i = 0; i < dim; i++)
    {
        Parameter *fparam = tf->parameterList[i];
        if (!fparam->type)
            continue;
        Type *tprmi = (fparam->storageClass & (STClazy | STCout | STCref))
                ? fparam->type : getIndirection(fparam->type);
        if (!tprmi)
            continue;   // there is no mutable indirection

        //printf("\t[%d] tprmi = %d %s\n", i, tprmi->ty, tprmi->toChars());
        if (traverseIndirections(tprmi, t))
            return false;
    }
    if (AggregateDeclaration *ad = isCtorDeclaration() ? NULL : isThis())
    {
        Type *tthis = ad->getType()->addMod(tf->mod);
        //printf("\ttthis = %s\n", tthis->toChars());
        if (traverseIndirections(tthis, t))
            return false;
    }

    return true;
}

/****************************************
 * Determine if function needs a static frame pointer.
 * Returns:
 *  `true` if function is really nested within other function.
 * Contracts:
 *  If isNested() returns true, isThis() should return false.
 */
bool FuncDeclaration::isNested()
{
    FuncDeclaration *f = toAliasFunc();
    //printf("\ttoParent2() = '%s'\n", f->toParent2()->toChars());
    return ((f->storage_class & STCstatic) == 0) &&
           (f->linkage == LINKd) &&
           (f->toParent2()->isFuncDeclaration() != NULL);
}

/****************************************
 * Determine if function is a non-static member function
 * that has an implicit 'this' expression.
 * Returns:
 *  The aggregate it is a member of, or null.
 * Contracts:
 *  If isThis() returns true, isNested() should return false.
 */
AggregateDeclaration *FuncDeclaration::isThis()
{
    //printf("+FuncDeclaration::isThis() '%s'\n", toChars());
    AggregateDeclaration *ad = (storage_class & STCstatic) ? NULL : isMember2();
    //printf("-FuncDeclaration::isThis() %p\n", ad);
    return ad;
}

bool FuncDeclaration::needThis()
{
    //printf("FuncDeclaration::needThis() '%s'\n", toChars());
    return toAliasFunc()->isThis() != NULL;
}

bool FuncDeclaration::addPreInvariant()
{
    AggregateDeclaration *ad = isThis();
    ClassDeclaration *cd = ad ? ad->isClassDeclaration() : NULL;
    return (ad && !(cd && cd->isCPPclass()) &&
            global.params.useInvariants == CHECKENABLEon &&
            (protection.kind == Prot::protected_ || protection.kind == Prot::public_ || protection.kind == Prot::export_) &&
            !naked);
}

bool FuncDeclaration::addPostInvariant()
{
    AggregateDeclaration *ad = isThis();
    ClassDeclaration *cd = ad ? ad->isClassDeclaration() : NULL;
    return (ad && !(cd && cd->isCPPclass()) &&
            ad->inv &&
            global.params.useInvariants == CHECKENABLEon &&
            (protection.kind == Prot::protected_ || protection.kind == Prot::public_ || protection.kind == Prot::export_) &&
            !naked);
}

/**********************************
 * Generate a FuncDeclaration for a runtime library function.
 */

FuncDeclaration *FuncDeclaration::genCfunc(Parameters *fparams, Type *treturn, const char *name, StorageClass stc)
{
    return genCfunc(fparams, treturn, Identifier::idPool(name), stc);
}

FuncDeclaration *FuncDeclaration::genCfunc(Parameters *fparams, Type *treturn, Identifier *id, StorageClass stc)
{
    FuncDeclaration *fd;
    TypeFunction *tf;
    Dsymbol *s;
    static DsymbolTable *st = NULL;

    //printf("genCfunc(name = '%s')\n", id->toChars());
    //printf("treturn\n\t"); treturn->print();

    // See if already in table
    if (!st)
        st = new DsymbolTable();
    s = st->lookup(id);
    if (s)
    {
        fd = s->isFuncDeclaration();
        assert(fd);
        assert(fd->type->nextOf()->equals(treturn));
    }
    else
    {
        tf = new TypeFunction(ParameterList(fparams), treturn, LINKc, stc);
        fd = new FuncDeclaration(Loc(), Loc(), id, STCstatic, tf);
        fd->protection = Prot(Prot::public_);
        fd->linkage = LINKc;

        st->insert(fd);
    }
    return fd;
}

/******************
 * Check parameters and return type of D main() function.
 * Issue error messages.
 */
void FuncDeclaration::checkDmain()
{
    TypeFunction *tf = type->toTypeFunction();
    const size_t nparams = tf->parameterList.length();
    bool argerr = false;
    if (nparams == 1)
    {
        Parameter *fparam0 = tf->parameterList[0];
        Type *t = fparam0->type->toBasetype();
        if (t->ty != Tarray ||
            t->nextOf()->ty != Tarray ||
            t->nextOf()->nextOf()->ty != Tchar ||
            fparam0->storageClass & (STCout | STCref | STClazy))
        {
            argerr = true;
        }
    }

    if (!tf->nextOf())
        error("must return int or void");
    else if (tf->nextOf()->ty != Tint32 && tf->nextOf()->ty != Tvoid)
        error("must return int or void, not %s", tf->nextOf()->toChars());
    else if (tf->parameterList.varargs || nparams >= 2 || argerr)
        error("parameters must be main() or main(string[] args)");
}

/***********************************************
 * Check all return statements for a function to verify that returning
 * using NRVO is possible.
 *
 * Returns:
 *      `false` if the result cannot be returned by hidden reference.
 */
bool FuncDeclaration::checkNRVO()
{
    if (!nrvo_can || returns == NULL)
        return false;

    TypeFunction *tf = type->toTypeFunction();
    if (tf->isref)
        return false;

    for (size_t i = 0; i < returns->length; i++)
    {
        ReturnStatement *rs = (*returns)[i];

        if (VarExp *ve = rs->exp->isVarExp())
        {
            VarDeclaration *v = ve->var->isVarDeclaration();
            if (!v || v->isOut() || v->isRef())
                return false;
            else if (nrvo_var == NULL)
            {
                // Variables in the data segment (e.g. globals, TLS or not),
                // parameters and closure variables cannot be NRVOed.
                if (v->isDataseg() || v->isParameter() || v->toParent2() != this)
                    return false;
                //printf("Setting nrvo to %s\n", v->toChars());
                nrvo_var = v;
            }
            else if (nrvo_var != v)
                return false;
        }
        else //if (!exp->isLvalue())    // keep NRVO-ability
            return false;
    }
    return true;
}

const char *FuncDeclaration::kind() const
{
    return generated ? "generated function" : "function";
}

/*********************************************
 * In the current function, we are calling 'this' function.
 * 1. Check to see if the current function can call 'this' function, issue error if not.
 * 2. If the current function is not the parent of 'this' function, then add
 *    the current function to the list of siblings of 'this' function.
 * 3. If the current function is a literal, and it's accessing an uplevel scope,
 *    then mark it as a delegate.
 * Returns true if error occurs.
 */
bool FuncDeclaration::checkNestedReference(Scope *sc, Loc loc)
{
    //printf("FuncDeclaration::checkNestedReference() %s\n", toPrettyChars());

    if (FuncLiteralDeclaration *fld = this->isFuncLiteralDeclaration())
    {
        if (fld->tok == TOKreserved)
        {
            fld->tok = TOKfunction;
            fld->vthis = NULL;
        }
    }

    if (!parent || parent == sc->parent)
        return false;
    if (ident == Id::require || ident == Id::ensure)
        return false;
    if (!isThis() && !isNested())
        return false;

    // The current function
    FuncDeclaration *fdthis = sc->parent->isFuncDeclaration();
    if (!fdthis)
        return false;   // out of function scope

    Dsymbol *p = toParent2();

    // Function literals from fdthis to p must be delegates
    checkNestedRef(fdthis, p);

    if (isNested())
    {
        // The function that this function is in
        FuncDeclaration *fdv = p->isFuncDeclaration();
        if (!fdv)
            return false;
        if (fdv == fdthis)
            return false;

        //printf("this = %s in [%s]\n", this->toChars(), this->loc.toChars());
        //printf("fdv = %s in [%s]\n", fdv->toChars(), fdv->loc.toChars());
        //printf("fdthis = %s in [%s]\n", fdthis->toChars(), fdthis->loc.toChars());

        // Add this function to the list of those which called us
        if (fdthis != this)
        {
            bool found = false;
            for (size_t i = 0; i < siblingCallers.length; ++i)
            {
                if (siblingCallers[i] == fdthis)
                    found = true;
            }
            if (!found)
            {
                //printf("\tadding sibling %s\n", fdthis->toPrettyChars());
                if (!sc->intypeof && !(sc->flags & SCOPEcompile))
                    siblingCallers.push(fdthis);
            }
        }

        int lv = fdthis->getLevel(loc, sc, fdv);
        if (lv == -2)
            return true;    // error
        if (lv == -1)
            return false;   // downlevel call
        if (lv == 0)
            return false;   // same level call
        // Uplevel call
    }
    return false;
}

/* For all functions between outerFunc and f, mark them as needing
 * a closure.
 */
void markAsNeedingClosure(Dsymbol *f, FuncDeclaration *outerFunc)
{
    for (Dsymbol *sx = f; sx && sx != outerFunc; sx = sx->parent)
    {
        FuncDeclaration *fy = sx->isFuncDeclaration();
        if (fy && fy->closureVars.length)
        {
            /* fy needs a closure if it has closureVars[],
             * because the frame pointer in the closure will be accessed.
             */
            fy->requiresClosure = true;
        }
    }
}


/* Given a nested function f inside a function outerFunc, check
 * if any sibling callers of f have escaped. If so, mark
 * all the enclosing functions as needing closures.
 * Return true if any closures were detected.
 * This is recursive: we need to check the callers of our siblings.
 * Note that nested functions can only call lexically earlier nested
 * functions, so loops are impossible.
 */
bool checkEscapingSiblings(FuncDeclaration *f, FuncDeclaration *outerFunc, void *p = NULL)
{
    struct PrevSibling
    {
        PrevSibling *p;
        FuncDeclaration *f;
    };

    PrevSibling ps;
    ps.p = (PrevSibling *)p;
    ps.f = f;

    //printf("checkEscapingSiblings(f = %s, outerfunc = %s)\n", f->toChars(), outerFunc->toChars());
    bool bAnyClosures = false;
    for (size_t i = 0; i < f->siblingCallers.length; ++i)
    {
        FuncDeclaration *g = f->siblingCallers[i];
        if (g->isThis() || g->tookAddressOf)
        {
            markAsNeedingClosure(g, outerFunc);
            bAnyClosures = true;
        }

        PrevSibling *prev = (PrevSibling *)p;
        while (1)
        {
            if (!prev)
            {
                bAnyClosures |= checkEscapingSiblings(g, outerFunc, &ps);
                break;
            }
            if (prev->f == g)
                break;
            prev = prev->p;
        }
    }
    //printf("\t%d\n", bAnyClosures);
    return bAnyClosures;
}


/*******************************
 * Look at all the variables in this function that are referenced
 * by nested functions, and determine if a closure needs to be
 * created for them.
 */

bool FuncDeclaration::needsClosure()
{
    /* Need a closure for all the closureVars[] if any of the
     * closureVars[] are accessed by a
     * function that escapes the scope of this function.
     * We take the conservative approach and decide that a function needs
     * a closure if it:
     * 1) is a virtual function
     * 2) has its address taken
     * 3) has a parent that escapes
     * 4) calls another nested function that needs a closure
     *
     * Note that since a non-virtual function can be called by
     * a virtual one, if that non-virtual function accesses a closure
     * var, the closure still has to be taken. Hence, we check for isThis()
     * instead of isVirtual(). (thanks to David Friedman)
     *
     * When the function returns a local struct or class, `requiresClosure`
     * is already set to `true` upon entering this function when the
     * struct/class refers to a local variable and a closure is needed.
     */

    //printf("FuncDeclaration::needsClosure() %s\n", toChars());

    if (requiresClosure)
        goto Lyes;

    for (size_t i = 0; i < closureVars.length; i++)
    {
        VarDeclaration *v = closureVars[i];
        //printf("\tv = %s\n", v->toChars());

        for (size_t j = 0; j < v->nestedrefs.length; j++)
        {
            FuncDeclaration *f = v->nestedrefs[j];
            assert(f != this);

            //printf("\t\tf = %s, isVirtual=%d, isThis=%p, tookAddressOf=%d\n", f->toChars(), f->isVirtual(), f->isThis(), f->tookAddressOf);

            /* Look to see if f escapes. We consider all parents of f within
             * this, and also all siblings which call f; if any of them escape,
             * so does f.
             * Mark all affected functions as requiring closures.
             */
            for (Dsymbol *s = f; s && s != this; s = s->parent)
            {
                FuncDeclaration *fx = s->isFuncDeclaration();
                if (!fx)
                    continue;
                if (fx->isThis() || fx->tookAddressOf)
                {
                    //printf("\t\tfx = %s, isVirtual=%d, isThis=%p, tookAddressOf=%d\n", fx->toChars(), fx->isVirtual(), fx->isThis(), fx->tookAddressOf);

                    /* Mark as needing closure any functions between this and f
                     */
                    markAsNeedingClosure( (fx == f) ? fx->parent : fx, this);

                    requiresClosure = true;
                }

                /* We also need to check if any sibling functions that
                 * called us, have escaped. This is recursive: we need
                 * to check the callers of our siblings.
                 */
                if (checkEscapingSiblings(fx, this))
                    requiresClosure = true;

                /* Bugzilla 12406: Iterate all closureVars to mark all descendant
                 * nested functions that access to the closing context of this funciton.
                 */
            }
        }
    }
    if (requiresClosure)
        goto Lyes;

    return false;

Lyes:
    //printf("\tneeds closure\n");
    return true;
}

/***********************************************
 * Check that the function contains any closure.
 * If it's @nogc, report suitable errors.
 * This is mostly consistent with FuncDeclaration::needsClosure().
 *
 * Returns:
 *      true if any errors occur.
 */
bool FuncDeclaration::checkClosure()
{
    if (!needsClosure())
        return false;

    if (setGC())
    {
        error("is @nogc yet allocates closures with the GC");
        if (global.gag)     // need not report supplemental errors
            return true;
    }
    else
    {
        printGCUsage(loc, "using closure causes GC allocation");
        return false;
    }

    FuncDeclarations a;
    for (size_t i = 0; i < closureVars.length; i++)
    {
        VarDeclaration *v = closureVars[i];

        for (size_t j = 0; j < v->nestedrefs.length; j++)
        {
            FuncDeclaration *f = v->nestedrefs[j];
            assert(f != this);

            for (Dsymbol *s = f; s && s != this; s = s->parent)
            {
                FuncDeclaration *fx = s->isFuncDeclaration();
                if (!fx)
                    continue;
                if (fx->isThis() || fx->tookAddressOf)
                    goto Lfound;
                if (checkEscapingSiblings(fx, this))
                    goto Lfound;
            }
            continue;

        Lfound:
            for (size_t k = 0; ; k++)
            {
                if (k == a.length)
                {
                    a.push(f);
                    ::errorSupplemental(f->loc, "%s closes over variable %s at %s",
                        f->toPrettyChars(), v->toChars(), v->loc.toChars());
                    break;
                }
                if (a[k] == f)
                    break;
            }
            continue;
        }
    }

    return true;
}

/***********************************************
 * Determine if function's variables are referenced by a function
 * nested within it.
 */

bool FuncDeclaration::hasNestedFrameRefs()
{
    if (closureVars.length)
        return true;

    /* If a virtual function has contracts, assume its variables are referenced
     * by those contracts, even if they aren't. Because they might be referenced
     * by the overridden or overriding function's contracts.
     * This can happen because frequire and fensure are implemented as nested functions,
     * and they can be called directly by an overriding function and the overriding function's
     * context had better match, or Bugzilla 7335 will bite.
     */
    if (fdrequire || fdensure)
        return true;

    if (foverrides.length && isVirtualMethod())
    {
        for (size_t i = 0; i < foverrides.length; i++)
        {
            FuncDeclaration *fdv = foverrides[i];
            if (fdv->hasNestedFrameRefs())
                return true;
        }
    }

    return false;
}

/*********************************************
 * Return the function's parameter list, and whether
 * it is variadic or not.
 */

ParameterList FuncDeclaration::getParameterList()
{
    if (type)
    {
        TypeFunction *fdtype = type->toTypeFunction();
        return fdtype->parameterList;
    }

    return ParameterList();
}


/****************************** FuncAliasDeclaration ************************/

// Used as a way to import a set of functions from another scope into this one.

FuncAliasDeclaration::FuncAliasDeclaration(Identifier *ident, FuncDeclaration *funcalias, bool hasOverloads)
    : FuncDeclaration(funcalias->loc, funcalias->endloc, ident,
        funcalias->storage_class, funcalias->type)
{
    assert(funcalias != this);
    this->funcalias = funcalias;

    this->hasOverloads = hasOverloads;
    if (hasOverloads)
    {
        if (FuncAliasDeclaration *fad = funcalias->isFuncAliasDeclaration())
            this->hasOverloads = fad->hasOverloads;
    }
    else
    {   // for internal use
        assert(!funcalias->isFuncAliasDeclaration());
        this->hasOverloads = false;
    }
    userAttribDecl = funcalias->userAttribDecl;
}

const char *FuncAliasDeclaration::kind() const
{
    return "function alias";
}

FuncDeclaration *FuncAliasDeclaration::toAliasFunc()
{
    return funcalias->toAliasFunc();
}


/****************************** FuncLiteralDeclaration ************************/

FuncLiteralDeclaration::FuncLiteralDeclaration(Loc loc, Loc endloc, Type *type,
        TOK tok, ForeachStatement *fes, Identifier *id)
    : FuncDeclaration(loc, endloc, NULL, STCundefined, type)
{
    this->ident = id ? id : Id::empty;
    this->tok = tok;
    this->fes = fes;
    this->treq = NULL;
    this->deferToObj = false;
    //printf("FuncLiteralDeclaration() id = '%s', type = '%s'\n", this->ident->toChars(), type->toChars());
}

Dsymbol *FuncLiteralDeclaration::syntaxCopy(Dsymbol *s)
{
    //printf("FuncLiteralDeclaration::syntaxCopy('%s')\n", toChars());
    assert(!s);
    FuncLiteralDeclaration *f = new FuncLiteralDeclaration(loc, endloc,
        type->syntaxCopy(), tok, fes, ident);
    f->treq = treq;     // don't need to copy
    return FuncDeclaration::syntaxCopy(f);
}

bool FuncLiteralDeclaration::isNested()
{
    //printf("FuncLiteralDeclaration::isNested() '%s'\n", toChars());
    return (tok != TOKfunction) && !isThis();
}

AggregateDeclaration *FuncLiteralDeclaration::isThis()
{
    //printf("FuncLiteralDeclaration::isThis() '%s'\n", toChars());
    return tok == TOKdelegate ? FuncDeclaration::isThis() : NULL;
}

bool FuncLiteralDeclaration::isVirtual()
{
    return false;
}

bool FuncLiteralDeclaration::addPreInvariant()
{
    return false;
}

bool FuncLiteralDeclaration::addPostInvariant()
{
    return false;
}

/*******************************
 * Modify all expression type of return statements to tret.
 *
 * On function literals, return type may be modified based on the context type
 * after its semantic3 is done, in FuncExp::implicitCastTo.
 *
 *  A function() dg = (){ return new B(); } // OK if is(B : A) == true
 *
 * If B to A conversion is convariant that requires offseet adjusting,
 * all return statements should be adjusted to return expressions typed A.
 */
void FuncLiteralDeclaration::modifyReturns(Scope *sc, Type *tret)
{
    class RetWalker : public StatementRewriteWalker
    {
    public:
        Scope *sc;
        Type *tret;
        FuncLiteralDeclaration *fld;

        void visit(ReturnStatement *s)
        {
            Expression *exp = s->exp;
            if (exp && !exp->type->equals(tret))
            {
                s->exp = exp->castTo(sc, tret);
            }
        }
    };

    if (semanticRun < PASSsemantic3done)
        return;

    if (fes)
        return;

    RetWalker w;
    w.sc = sc;
    w.tret = tret;
    w.fld = this;
    fbody->accept(&w);

    // Also update the inferred function type to match the new return type.
    // This is required so the code generator does not try to cast the
    // modified returns back to the original type.
    if (inferRetType && type->nextOf() != tret)
        type->toTypeFunction()->next = tret;
}

const char *FuncLiteralDeclaration::kind() const
{
    return (tok != TOKfunction) ? "delegate" : "function";
}

const char *FuncLiteralDeclaration::toPrettyChars(bool QualifyTypes)
{
    if (parent)
    {
        TemplateInstance *ti = parent->isTemplateInstance();
        if (ti)
            return ti->tempdecl->toPrettyChars(QualifyTypes);
    }
    return Dsymbol::toPrettyChars(QualifyTypes);
}

/********************************* CtorDeclaration ****************************/

CtorDeclaration::CtorDeclaration(Loc loc, Loc endloc, StorageClass stc, Type *type)
    : FuncDeclaration(loc, endloc, Id::ctor, stc, type)
{
    //printf("CtorDeclaration(loc = %s) %s\n", loc.toChars(), toChars());
}

Dsymbol *CtorDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    CtorDeclaration *f = new CtorDeclaration(loc, endloc, storage_class, type->syntaxCopy());
    return FuncDeclaration::syntaxCopy(f);
}

void CtorDeclaration::semantic(Scope *sc)
{
    //printf("CtorDeclaration::semantic() %s\n", toChars());
    if (semanticRun >= PASSsemanticdone)
        return;
    if (_scope)
    {
        sc = _scope;
        _scope = NULL;
    }

    parent = sc->parent;
    Dsymbol *p = toParent2();
    AggregateDeclaration *ad = p->isAggregateDeclaration();
    if (!ad)
    {
        ::error(loc, "constructor can only be a member of aggregate, not %s %s",
            p->kind(), p->toChars());
        type = Type::terror;
        errors = true;
        return;
    }

    sc = sc->push();
    sc->stc &= ~STCstatic;              // not a static constructor
    sc->flags |= SCOPEctor;

    FuncDeclaration::semantic(sc);

    sc->pop();

    if (errors)
        return;

    TypeFunction *tf = type->toTypeFunction();

    /* See if it's the default constructor
     * But, template constructor should not become a default constructor.
     */
    if (ad && (!parent->isTemplateInstance() || parent->isTemplateMixin()))
    {
        const size_t dim = tf->parameterList.length();

        if (StructDeclaration *sd = ad->isStructDeclaration())
        {
            if (dim == 0 && tf->parameterList.varargs == VARARGnone) // empty default ctor w/o any varargs
            {
                if (fbody || !(storage_class & STCdisable) || dim)
                {
                    error("default constructor for structs only allowed "
                        "with @disable, no body, and no parameters");
                    storage_class |= STCdisable;
                    fbody = NULL;
                }
                sd->noDefaultCtor = true;
            }
            else if (dim == 0 && tf->parameterList.varargs) // allow varargs only ctor
            {
            }
            else if (dim && tf->parameterList[0]->defaultArg)
            {
                // if the first parameter has a default argument, then the rest does as well
                if (storage_class & STCdisable)
                {
                    deprecation("@disable'd constructor cannot have default "
                                "arguments for all parameters.");
                    deprecationSupplemental(loc, "Use @disable this(); if you want to disable default initialization.");
                }
                else
                    deprecation("all parameters have default arguments, "
                                "but structs cannot have default constructors.");
            }

        }
        else if (dim == 0 && tf->parameterList.varargs == VARARGnone)
        {
            ad->defaultCtor = this;
        }
    }
}

const char *CtorDeclaration::kind() const
{
    return "constructor";
}

const char *CtorDeclaration::toChars()
{
    return "this";
}

bool CtorDeclaration::isVirtual()
{
    return false;
}

bool CtorDeclaration::addPreInvariant()
{
    return false;
}

bool CtorDeclaration::addPostInvariant()
{
    return (isThis() && vthis && global.params.useInvariants == CHECKENABLEon);
}


/********************************* PostBlitDeclaration ****************************/

PostBlitDeclaration::PostBlitDeclaration(Loc loc, Loc endloc, StorageClass stc, Identifier *id)
    : FuncDeclaration(loc, endloc, id, stc, NULL)
{
}

Dsymbol *PostBlitDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    PostBlitDeclaration *dd = new PostBlitDeclaration(loc, endloc, storage_class, ident);
    return FuncDeclaration::syntaxCopy(dd);
}

void PostBlitDeclaration::semantic(Scope *sc)
{
    //printf("PostBlitDeclaration::semantic() %s\n", toChars());
    //printf("ident: %s, %s, %p, %p\n", ident->toChars(), Id::dtor->toChars(), ident, Id::dtor);
    //printf("stc = x%llx\n", sc->stc);
    if (semanticRun >= PASSsemanticdone)
        return;
    if (_scope)
    {
        sc = _scope;
        _scope = NULL;
    }

    parent = sc->parent;
    Dsymbol *p = toParent2();
    StructDeclaration *ad = p->isStructDeclaration();
    if (!ad)
    {
        ::error(loc, "postblit can only be a member of struct/union, not %s %s",
            p->kind(), p->toChars());
        type = Type::terror;
        errors = true;
        return;
    }
    if (ident == Id::postblit && semanticRun < PASSsemantic)
        ad->postblits.push(this);
    if (!type)
        type = new TypeFunction(ParameterList(), Type::tvoid, LINKd, storage_class);

    sc = sc->push();
    sc->stc &= ~STCstatic;              // not static
    sc->linkage = LINKd;

    FuncDeclaration::semantic(sc);

    sc->pop();
}

bool PostBlitDeclaration::overloadInsert(Dsymbol *)
{
    return false;       // cannot overload postblits
}

bool PostBlitDeclaration::addPreInvariant()
{
    return false;
}

bool PostBlitDeclaration::addPostInvariant()
{
    return (isThis() && vthis && global.params.useInvariants == CHECKENABLEon);
}

bool PostBlitDeclaration::isVirtual()
{
    return false;
}

/********************************* DtorDeclaration ****************************/

DtorDeclaration::DtorDeclaration(Loc loc, Loc endloc)
    : FuncDeclaration(loc, endloc, Id::dtor, STCundefined, NULL)
{
}

DtorDeclaration::DtorDeclaration(Loc loc, Loc endloc, StorageClass stc, Identifier *id)
    : FuncDeclaration(loc, endloc, id, stc, NULL)
{
}

Dsymbol *DtorDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    DtorDeclaration *dd = new DtorDeclaration(loc, endloc, storage_class, ident);
    return FuncDeclaration::syntaxCopy(dd);
}

void DtorDeclaration::semantic(Scope *sc)
{
    //printf("DtorDeclaration::semantic() %s\n", toChars());
    //printf("ident: %s, %s, %p, %p\n", ident->toChars(), Id::dtor->toChars(), ident, Id::dtor);
    if (semanticRun >= PASSsemanticdone)
        return;
    if (_scope)
    {
        sc = _scope;
        _scope = NULL;
    }

    parent = sc->parent;
    Dsymbol *p = toParent2();
    AggregateDeclaration *ad = p->isAggregateDeclaration();
    if (!ad)
    {
        ::error(loc, "destructor can only be a member of aggregate, not %s %s",
            p->kind(), p->toChars());
        type = Type::terror;
        errors = true;
        return;
    }
    if (ident == Id::dtor && semanticRun < PASSsemantic)
        ad->dtors.push(this);
    if (!type)
        type = new TypeFunction(ParameterList(), Type::tvoid, LINKd, storage_class);

    sc = sc->push();
    sc->stc &= ~STCstatic;              // not a static destructor
    if (sc->linkage != LINKcpp)
        sc->linkage = LINKd;

    FuncDeclaration::semantic(sc);

    sc->pop();
}

bool DtorDeclaration::overloadInsert(Dsymbol *)
{
    return false;       // cannot overload destructors
}

bool DtorDeclaration::addPreInvariant()
{
    return (isThis() && vthis && global.params.useInvariants == CHECKENABLEon);
}

bool DtorDeclaration::addPostInvariant()
{
    return false;
}

const char *DtorDeclaration::kind() const
{
    return "destructor";
}

const char *DtorDeclaration::toChars()
{
    return "~this";
}

bool DtorDeclaration::isVirtual()
{
    // false so that dtor's don't get put into the vtbl[]
    return false;
}

/********************************* StaticCtorDeclaration ****************************/

StaticCtorDeclaration::StaticCtorDeclaration(Loc loc, Loc endloc, StorageClass stc)
    : FuncDeclaration(loc, endloc,
      Identifier::generateId("_staticCtor"), STCstatic | stc, NULL)
{
}

StaticCtorDeclaration::StaticCtorDeclaration(Loc loc, Loc endloc, const char *name, StorageClass stc)
    : FuncDeclaration(loc, endloc,
      Identifier::generateId(name), STCstatic | stc, NULL)
{
}

Dsymbol *StaticCtorDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    StaticCtorDeclaration *scd = new StaticCtorDeclaration(loc, endloc, storage_class);
    return FuncDeclaration::syntaxCopy(scd);
}

void StaticCtorDeclaration::semantic(Scope *sc)
{
    //printf("StaticCtorDeclaration::semantic()\n");
    if (semanticRun >= PASSsemanticdone)
        return;
    if (_scope)
    {
        sc = _scope;
        _scope = NULL;
    }

    parent = sc->parent;
    Dsymbol *p = parent->pastMixin();
    if (!p->isScopeDsymbol())
    {
        const char *s = (isSharedStaticCtorDeclaration() ? "shared " : "");
        ::error(loc, "%sstatic constructor can only be member of module/aggregate/template, not %s %s",
            s, p->kind(), p->toChars());
        type = Type::terror;
        errors = true;
        return;
    }
    if (!type)
        type = new TypeFunction(ParameterList(), Type::tvoid, LINKd, storage_class);

    /* If the static ctor appears within a template instantiation,
     * it could get called multiple times by the module constructors
     * for different modules. Thus, protect it with a gate.
     */
    if (isInstantiated() && semanticRun < PASSsemantic)
    {
        /* Add this prefix to the function:
         *      static int gate;
         *      if (++gate != 1) return;
         * Note that this is not thread safe; should not have threads
         * during static construction.
         */
        VarDeclaration *v = new VarDeclaration(Loc(), Type::tint32, Id::gate, NULL);
        v->storage_class = STCtemp | (isSharedStaticCtorDeclaration() ? STCstatic : STCtls);
        Statements *sa = new Statements();
        Statement *s = new ExpStatement(Loc(), v);
        sa->push(s);
        Expression *e = new IdentifierExp(Loc(), v->ident);
        e = new AddAssignExp(Loc(), e, new IntegerExp(1));
        e = new EqualExp(TOKnotequal, Loc(), e, new IntegerExp(1));
        s = new IfStatement(Loc(), NULL, e, new ReturnStatement(Loc(), NULL), NULL, Loc());
        sa->push(s);
        if (fbody)
            sa->push(fbody);
        fbody = new CompoundStatement(Loc(), sa);
    }

    FuncDeclaration::semantic(sc);

    // We're going to need ModuleInfo
    Module *m = getModule();
    if (!m)
        m = sc->_module;
    if (m)
    {
        m->needmoduleinfo = 1;
        //printf("module1 %s needs moduleinfo\n", m->toChars());
    }
}

AggregateDeclaration *StaticCtorDeclaration::isThis()
{
    return NULL;
}

bool StaticCtorDeclaration::isVirtual()
{
    return false;
}

bool StaticCtorDeclaration::hasStaticCtorOrDtor()
{
    return true;
}

bool StaticCtorDeclaration::addPreInvariant()
{
    return false;
}

bool StaticCtorDeclaration::addPostInvariant()
{
    return false;
}

/********************************* SharedStaticCtorDeclaration ****************************/

SharedStaticCtorDeclaration::SharedStaticCtorDeclaration(Loc loc, Loc endloc, StorageClass stc)
    : StaticCtorDeclaration(loc, endloc, "_sharedStaticCtor", stc)
{
}

Dsymbol *SharedStaticCtorDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    SharedStaticCtorDeclaration *scd = new SharedStaticCtorDeclaration(loc, endloc, storage_class);
    return FuncDeclaration::syntaxCopy(scd);
}

/********************************* StaticDtorDeclaration ****************************/

StaticDtorDeclaration::StaticDtorDeclaration(Loc loc, Loc endloc, StorageClass stc)
    : FuncDeclaration(loc, endloc,
      Identifier::generateId("_staticDtor"), STCstatic | stc, NULL)
{
    vgate = NULL;
}

StaticDtorDeclaration::StaticDtorDeclaration(Loc loc, Loc endloc, const char *name, StorageClass stc)
    : FuncDeclaration(loc, endloc,
      Identifier::generateId(name), STCstatic | stc, NULL)
{
    vgate = NULL;
}

Dsymbol *StaticDtorDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    StaticDtorDeclaration *sdd = new StaticDtorDeclaration(loc, endloc, storage_class);
    return FuncDeclaration::syntaxCopy(sdd);
}

void StaticDtorDeclaration::semantic(Scope *sc)
{
    if (semanticRun >= PASSsemanticdone)
        return;
    if (_scope)
    {
        sc = _scope;
        _scope = NULL;
    }

    parent = sc->parent;
    Dsymbol *p = parent->pastMixin();
    if (!p->isScopeDsymbol())
    {
        const char *s = (isSharedStaticDtorDeclaration() ? "shared " : "");
        ::error(loc, "%sstatic destructor can only be member of module/aggregate/template, not %s %s",
            s, p->kind(), p->toChars());
        type = Type::terror;
        errors = true;
        return;
    }
    if (!type)
        type = new TypeFunction(ParameterList(), Type::tvoid, LINKd, storage_class);

    /* If the static ctor appears within a template instantiation,
     * it could get called multiple times by the module constructors
     * for different modules. Thus, protect it with a gate.
     */
    if (isInstantiated() && semanticRun < PASSsemantic)
    {
        /* Add this prefix to the function:
         *      static int gate;
         *      if (--gate != 0) return;
         * Increment gate during constructor execution.
         * Note that this is not thread safe; should not have threads
         * during static destruction.
         */
        VarDeclaration *v = new VarDeclaration(Loc(), Type::tint32, Id::gate, NULL);
        v->storage_class = STCtemp | (isSharedStaticDtorDeclaration() ? STCstatic : STCtls);
        Statements *sa = new Statements();
        Statement *s = new ExpStatement(Loc(), v);
        sa->push(s);
        Expression *e = new IdentifierExp(Loc(), v->ident);
        e = new AddAssignExp(Loc(), e, new IntegerExp(-1));
        e = new EqualExp(TOKnotequal, Loc(), e, new IntegerExp(0));
        s = new IfStatement(Loc(), NULL, e, new ReturnStatement(Loc(), NULL), NULL, Loc());
        sa->push(s);
        if (fbody)
            sa->push(fbody);
        fbody = new CompoundStatement(Loc(), sa);
        vgate = v;
    }

    FuncDeclaration::semantic(sc);

    // We're going to need ModuleInfo
    Module *m = getModule();
    if (!m)
        m = sc->_module;
    if (m)
    {
        m->needmoduleinfo = 1;
        //printf("module2 %s needs moduleinfo\n", m->toChars());
    }
}

AggregateDeclaration *StaticDtorDeclaration::isThis()
{
    return NULL;
}

bool StaticDtorDeclaration::isVirtual()
{
    return false;
}

bool StaticDtorDeclaration::hasStaticCtorOrDtor()
{
    return true;
}

bool StaticDtorDeclaration::addPreInvariant()
{
    return false;
}

bool StaticDtorDeclaration::addPostInvariant()
{
    return false;
}

/********************************* SharedStaticDtorDeclaration ****************************/

SharedStaticDtorDeclaration::SharedStaticDtorDeclaration(Loc loc, Loc endloc, StorageClass stc)
    : StaticDtorDeclaration(loc, endloc, "_sharedStaticDtor", stc)
{
}

Dsymbol *SharedStaticDtorDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    SharedStaticDtorDeclaration *sdd = new SharedStaticDtorDeclaration(loc, endloc, storage_class);
    return FuncDeclaration::syntaxCopy(sdd);
}

/********************************* InvariantDeclaration ****************************/

InvariantDeclaration::InvariantDeclaration(Loc loc, Loc endloc, StorageClass stc, Identifier *id)
    : FuncDeclaration(loc, endloc,
                      id ? id : Identifier::generateId("__invariant"),
                      stc, NULL)
{
}

Dsymbol *InvariantDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    InvariantDeclaration *id = new InvariantDeclaration(loc, endloc, storage_class);
    return FuncDeclaration::syntaxCopy(id);
}

void InvariantDeclaration::semantic(Scope *sc)
{
    if (semanticRun >= PASSsemanticdone)
        return;
    if (_scope)
    {
        sc = _scope;
        _scope = NULL;
    }

    parent = sc->parent;
    Dsymbol *p = parent->pastMixin();
    AggregateDeclaration *ad = p->isAggregateDeclaration();
    if (!ad)
    {
        ::error(loc, "invariant can only be a member of aggregate, not %s %s",
            p->kind(), p->toChars());
        type = Type::terror;
        errors = true;
        return;
    }
    if (ident != Id::classInvariant &&
        semanticRun < PASSsemantic &&
        !ad->isUnionDeclaration()           // users are on their own with union fields
       )
        ad->invs.push(this);
    if (!type)
        type = new TypeFunction(ParameterList(), Type::tvoid, LINKd, storage_class);

    sc = sc->push();
    sc->stc &= ~STCstatic;              // not a static invariant
    sc->stc |= STCconst;                // invariant() is always const
    sc->flags = (sc->flags & ~SCOPEcontract) | SCOPEinvariant;
    sc->linkage = LINKd;

    FuncDeclaration::semantic(sc);

    sc->pop();
}

bool InvariantDeclaration::isVirtual()
{
    return false;
}

bool InvariantDeclaration::addPreInvariant()
{
    return false;
}

bool InvariantDeclaration::addPostInvariant()
{
    return false;
}

/********************************* UnitTestDeclaration ****************************/

/*******************************
 * Generate unique unittest function Id so we can have multiple
 * instances per module.
 */

static Identifier *unitTestId(Loc loc)
{
    OutBuffer buf;
    buf.printf("__unittestL%u_", loc.linnum);
    return Identifier::generateId(buf.peekChars());
}

UnitTestDeclaration::UnitTestDeclaration(Loc loc, Loc endloc, StorageClass stc, char *codedoc)
    : FuncDeclaration(loc, endloc, unitTestId(loc), stc, NULL)
{
    this->codedoc = codedoc;
}

Dsymbol *UnitTestDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    UnitTestDeclaration *utd = new UnitTestDeclaration(loc, endloc, storage_class, codedoc);
    return FuncDeclaration::syntaxCopy(utd);
}

void UnitTestDeclaration::semantic(Scope *sc)
{
    if (semanticRun >= PASSsemanticdone)
        return;
    if (_scope)
    {
        sc = _scope;
        _scope = NULL;
    }

    protection = sc->protection;

    parent = sc->parent;
    Dsymbol *p = parent->pastMixin();
    if (!p->isScopeDsymbol())
    {
        ::error(loc, "unittest can only be a member of module/aggregate/template, not %s %s",
            p->kind(), p->toChars());
        type = Type::terror;
        errors = true;
        return;
    }

    if (global.params.useUnitTests)
    {
        if (!type)
            type = new TypeFunction(ParameterList(), Type::tvoid, LINKd, storage_class);
        Scope *sc2 = sc->push();
        sc2->linkage = LINKd;
        FuncDeclaration::semantic(sc2);
        sc2->pop();
    }
}

AggregateDeclaration *UnitTestDeclaration::isThis()
{
    return NULL;
}

bool UnitTestDeclaration::isVirtual()
{
    return false;
}

bool UnitTestDeclaration::addPreInvariant()
{
    return false;
}

bool UnitTestDeclaration::addPostInvariant()
{
    return false;
}

/********************************* NewDeclaration ****************************/

NewDeclaration::NewDeclaration(Loc loc, Loc endloc, StorageClass stc, Parameters *fparams, VarArg varargs)
    : FuncDeclaration(loc, endloc, Id::classNew, STCstatic | stc, NULL)
{
    this->parameters = fparams;
    this->varargs = varargs;
}

Dsymbol *NewDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    NewDeclaration *f = new NewDeclaration(loc, endloc,
        storage_class, Parameter::arraySyntaxCopy(parameters), varargs);
    return FuncDeclaration::syntaxCopy(f);
}

void NewDeclaration::semantic(Scope *sc)
{
    //printf("NewDeclaration::semantic()\n");
    if (semanticRun >= PASSsemanticdone)
        return;
    if (_scope)
    {
        sc = _scope;
        _scope = NULL;
    }

    parent = sc->parent;
    Dsymbol *p = parent->pastMixin();
    if (!p->isAggregateDeclaration())
    {
        ::error(loc, "allocator can only be a member of aggregate, not %s %s",
            p->kind(), p->toChars());
        type = Type::terror;
        errors = true;
        return;
    }
    Type *tret = Type::tvoid->pointerTo();
    if (!type)
        type = new TypeFunction(ParameterList(parameters, varargs), tret, LINKd, storage_class);

    type = typeSemantic(type, loc, sc);

    // Check that there is at least one argument of type size_t
    TypeFunction *tf = type->toTypeFunction();
    if (tf->parameterList.length() < 1)
    {
        error("at least one argument of type size_t expected");
    }
    else
    {
        Parameter *fparam = tf->parameterList[0];
        if (!fparam->type->equals(Type::tsize_t))
            error("first argument must be type size_t, not %s", fparam->type->toChars());
    }

    FuncDeclaration::semantic(sc);
}

const char *NewDeclaration::kind() const
{
    return "allocator";
}

bool NewDeclaration::isVirtual()
{
    return false;
}

bool NewDeclaration::addPreInvariant()
{
    return false;
}

bool NewDeclaration::addPostInvariant()
{
    return false;
}

/********************************* DeleteDeclaration ****************************/

DeleteDeclaration::DeleteDeclaration(Loc loc, Loc endloc, StorageClass stc, Parameters *fparams)
    : FuncDeclaration(loc, endloc, Id::classDelete, STCstatic | stc, NULL)
{
    this->parameters = fparams;
}

Dsymbol *DeleteDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    DeleteDeclaration *f = new DeleteDeclaration(loc, endloc,
            storage_class, Parameter::arraySyntaxCopy(parameters));
    return FuncDeclaration::syntaxCopy(f);
}

void DeleteDeclaration::semantic(Scope *sc)
{
    //printf("DeleteDeclaration::semantic()\n");
    if (semanticRun >= PASSsemanticdone)
        return;
    if (_scope)
    {
        sc = _scope;
        _scope = NULL;
    }

    parent = sc->parent;
    Dsymbol *p = parent->pastMixin();
    if (!p->isAggregateDeclaration())
    {
        ::error(loc, "deallocator can only be a member of aggregate, not %s %s",
            p->kind(), p->toChars());
        type = Type::terror;
        errors = true;
        return;
    }
    if (!type)
        type = new TypeFunction(ParameterList(parameters), Type::tvoid, LINKd, storage_class);

    type = typeSemantic(type, loc, sc);

    // Check that there is only one argument of type void*
    TypeFunction *tf = type->toTypeFunction();
    if (tf->parameterList.length() != 1)
    {
        error("one argument of type void* expected");
    }
    else
    {
        Parameter *fparam = tf->parameterList[0];
        if (!fparam->type->equals(Type::tvoid->pointerTo()))
            error("one argument of type void* expected, not %s", fparam->type->toChars());
    }

    FuncDeclaration::semantic(sc);
}

const char *DeleteDeclaration::kind() const
{
    return "deallocator";
}

bool DeleteDeclaration::isDelete()
{
    return true;
}

bool DeleteDeclaration::isVirtual()
{
    return false;
}

bool DeleteDeclaration::addPreInvariant()
{
    return false;
}

bool DeleteDeclaration::addPostInvariant()
{
    return false;
}
