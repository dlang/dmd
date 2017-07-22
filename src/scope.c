
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/scope.c
 */

#include <stdio.h>
#include <assert.h>
#include <string.h>                     // strlen()

#include "root.h"
#include "rmem.h"
#include "speller.h"

#include "mars.h"
#include "init.h"
#include "identifier.h"
#include "scope.h"
#include "attrib.h"
#include "dsymbol.h"
#include "declaration.h"
#include "statement.h"
#include "aggregate.h"
#include "module.h"
#include "id.h"
#include "template.h"

Scope *Scope::freelist = NULL;

Scope *Scope::alloc()
{
    if (freelist)
    {
        Scope *s = freelist;
        freelist = s->enclosing;
        //printf("freelist %p\n", s);
        assert(s->flags & SCOPEfree);
        s->flags &= ~SCOPEfree;
        return s;
    }

    return new Scope();
}

Scope::Scope()
{
    // Create root scope

    //printf("Scope::Scope() %p\n", this);
    this->module = NULL;
    this->scopesym = NULL;
    this->sds = NULL;
    this->enclosing = NULL;
    this->parent = NULL;
    this->sw = NULL;
    this->tf = NULL;
    this->os = NULL;
    this->tinst = NULL;
    this->minst = NULL;
    this->sbreak = NULL;
    this->scontinue = NULL;
    this->fes = NULL;
    this->callsc = NULL;
    this->aligndecl = NULL;
    this->func = NULL;
    this->slabel = NULL;
    this->linkage = LINKd;
    this->cppmangle = CPPMANGLEdefault;
    this->inlining = PINLINEdefault;
    this->protection = Prot(PROTpublic);
    this->explicitProtection = 0;
    this->stc = 0;
    this->depdecl = NULL;
    this->inunion = 0;
    this->nofree = 0;
    this->noctor = 0;
    this->intypeof = 0;
    this->lastVar = NULL;
    this->callSuper = 0;
    this->fieldinit = NULL;
    this->fieldinit_dim = 0;
    this->flags = 0;
    this->lastdc = NULL;
    this->anchorCounts = NULL;
    this->prevAnchor = NULL;
    this->userAttribDecl = NULL;
}

Scope *Scope::copy()
{
    Scope *sc = Scope::alloc();
    memcpy(sc, this, sizeof(Scope));

    /* Bugzilla 11777: The copied scope should not inherit fieldinit.
     */
    sc->fieldinit = NULL;

    return sc;
}

Scope *Scope::createGlobal(Module *module)
{
    Scope *sc = Scope::alloc();
    memset(sc, 0, sizeof(Scope));

    sc->aligndecl = NULL;
    sc->linkage = LINKd;
    sc->inlining = PINLINEdefault;
    sc->protection = Prot(PROTpublic);

    sc->module = module;

    sc->tinst = NULL;
    sc->minst = module;

    sc->scopesym = new ScopeDsymbol();
    sc->scopesym->symtab = new DsymbolTable();

    // Add top level package as member of this global scope
    Dsymbol *m = module;
    while (m->parent)
        m = m->parent;
    m->addMember(NULL, sc->scopesym);
    m->parent = NULL;                   // got changed by addMember()

    // Create the module scope underneath the global scope
    sc = sc->push(module);
    sc->parent = module;
    return sc;
}

Scope *Scope::push()
{
    Scope *s = copy();

    //printf("Scope::push(this = %p) new = %p\n", this, s);
    assert(!(flags & SCOPEfree));
    s->scopesym = NULL;
    s->sds = NULL;
    s->enclosing = this;
#ifdef DEBUG
    if (enclosing)
        assert(!(enclosing->flags & SCOPEfree));
    if (s == enclosing)
    {
        printf("this = %p, enclosing = %p, enclosing->enclosing = %p\n", s, this, enclosing);
    }
    assert(s != enclosing);
#endif
    s->slabel = NULL;
    s->nofree = 0;
    s->fieldinit = saveFieldInit();
    s->flags = (flags & (SCOPEcontract | SCOPEdebug | SCOPEctfe | SCOPEcompile | SCOPEconstraint));
    s->lastdc = NULL;

    assert(this != s);
    return s;
}

Scope *Scope::push(ScopeDsymbol *ss)
{
    //printf("Scope::push(%s)\n", ss->toChars());
    Scope *s = push();
    s->scopesym = ss;
    return s;
}

Scope *Scope::pop()
{
    //printf("Scope::pop() %p nofree = %d\n", this, nofree);
    Scope *enc = enclosing;

    if (enclosing)
    {
        enclosing->callSuper |= callSuper;
        if (enclosing->fieldinit && fieldinit)
        {
            assert(fieldinit != enclosing->fieldinit);

            size_t dim = fieldinit_dim;
            for (size_t i = 0; i < dim; i++)
                enclosing->fieldinit[i] |= fieldinit[i];
            mem.xfree(fieldinit);
            fieldinit = NULL;
        }
    }

    if (!nofree)
    {
        enclosing = freelist;
        freelist = this;
        flags |= SCOPEfree;
    }

    return enc;
}

Scope *Scope::startCTFE()
{
    Scope *sc = this->push();
    sc->flags = this->flags | SCOPEctfe;
#if 0
    /* TODO: Currently this is not possible, because we need to
     * unspeculative some types and symbols if they are necessary for the
     * final executable. Consider:
     *
     * struct S(T) {
     *   string toString() const { return "instantiated"; }
     * }
     * enum x = S!int();
     * void main() {
     *   // To call x.toString in runtime, compiler should unspeculative S!int.
     *   assert(x.toString() == "instantiated");
     * }
     */

    // If a template is instantiated from CT evaluated expression,
    // compiler can elide its code generation.
    sc->tinst = NULL;
    sc->minst = NULL;
#endif
    return sc;
}

Scope *Scope::endCTFE()
{
    assert(flags & SCOPEctfe);
    return pop();
}

void Scope::mergeCallSuper(Loc loc, unsigned cs)
{
    // This does a primitive flow analysis to support the restrictions
    // regarding when and how constructors can appear.
    // It merges the results of two paths.
    // The two paths are callSuper and cs; the result is merged into callSuper.

    if (cs != callSuper)
    {
        // Have ALL branches called a constructor?
        int aAll = (cs        & (CSXthis_ctor | CSXsuper_ctor)) != 0;
        int bAll = (callSuper & (CSXthis_ctor | CSXsuper_ctor)) != 0;

        // Have ANY branches called a constructor?
        bool aAny = (cs        & CSXany_ctor) != 0;
        bool bAny = (callSuper & CSXany_ctor) != 0;

        // Have any branches returned?
        bool aRet = (cs        & CSXreturn) != 0;
        bool bRet = (callSuper & CSXreturn) != 0;

        // Have any branches halted?
        bool aHalt = (cs        & CSXhalt) != 0;
        bool bHalt = (callSuper & CSXhalt) != 0;

        bool ok = true;

        if (aHalt && bHalt)
        {
            callSuper = CSXhalt;
        }
        else if ((!aHalt && aRet && !aAny && bAny) ||
                 (!bHalt && bRet && !bAny && aAny))
        {
            // If one has returned without a constructor call, there must be never
            // have been ctor calls in the other.
            ok = false;
        }
        else if (aHalt || aRet && aAll)
        {
            // If one branch has called a ctor and then exited, anything the
            // other branch has done is OK (except returning without a
            // ctor call, but we already checked that).
            callSuper |= cs & (CSXany_ctor | CSXlabel);
        }
        else if (bHalt || bRet && bAll)
        {
            callSuper = cs | (callSuper & (CSXany_ctor | CSXlabel));
        }
        else
        {
            // Both branches must have called ctors, or both not.
            ok = (aAll == bAll);
            // If one returned without a ctor, we must remember that
            // (Don't bother if we've already found an error)
            if (ok && aRet && !aAny)
                callSuper |= CSXreturn;
            callSuper |= cs & (CSXany_ctor | CSXlabel);
        }
        if (!ok)
            error(loc, "one path skips constructor");
    }
}

unsigned *Scope::saveFieldInit()
{
    unsigned *fi = NULL;
    if (fieldinit)  // copy
    {
        size_t dim = fieldinit_dim;
        fi = (unsigned *)mem.xmalloc(sizeof(unsigned) * dim);
        for (size_t i = 0; i < dim; i++)
            fi[i] = fieldinit[i];
    }
    return fi;
}

bool mergeFieldInit(Loc loc, unsigned &fieldInit, unsigned fi, bool mustInit)
{
    if (fi != fieldInit)
    {
        // Have any branches returned?
        bool aRet = (fi        & CSXreturn) != 0;
        bool bRet = (fieldInit & CSXreturn) != 0;

        // Have any branches halted?
        bool aHalt = (fi        & CSXhalt) != 0;
        bool bHalt = (fieldInit & CSXhalt) != 0;

        bool ok;

        if (aHalt && bHalt)
        {
            ok = true;
            fieldInit = CSXhalt;
        }
        else if (!aHalt && aRet)
        {
            ok = !mustInit || (fi & CSXthis_ctor);
            fieldInit = fieldInit;
        }
        else if (!bHalt && bRet)
        {
            ok = !mustInit || (fieldInit & CSXthis_ctor);
            fieldInit = fi;
        }
        else if (aHalt)
        {
            ok = !mustInit || (fieldInit & CSXthis_ctor);
            fieldInit = fieldInit;
        }
        else if (bHalt)
        {
            ok = !mustInit || (fi & CSXthis_ctor);
            fieldInit = fi;
        }
        else
        {
            ok = !mustInit || !((fieldInit ^ fi) & CSXthis_ctor);
            fieldInit |= fi;
        }

        return ok;
    }
    return true;
}

void Scope::mergeFieldInit(Loc loc, unsigned *fies)
{
    if (fieldinit && fies)
    {
        FuncDeclaration *f = func;
        if (fes) f = fes->func;
        AggregateDeclaration *ad = f->isMember2();
        assert(ad);

        for (size_t i = 0; i < ad->fields.dim; i++)
        {
            VarDeclaration *v = ad->fields[i];
            bool mustInit = (v->storage_class & STCnodefaultctor ||
                             v->type->needsNested());

            if (!::mergeFieldInit(loc, fieldinit[i], fies[i], mustInit))
            {
                ::error(loc, "one path skips field %s", ad->fields[i]->toChars());
            }
        }
    }
}

Module *Scope::instantiatingModule()
{
    // TODO: in speculative context, returning 'module' is correct?
    return minst ? minst : module;
}

static Dsymbol *searchScopes(Scope *scope, Loc loc, Identifier *ident, Dsymbol **pscopesym, int flags)
{
    for (Scope *sc = scope; sc; sc = sc->enclosing)
    {
        assert(sc != sc->enclosing);
        if (!sc->scopesym)
            continue;
        //printf("\tlooking in scopesym '%s', kind = '%s', flags = x%x\n", sc->scopesym->toChars(), sc->scopesym->kind(), flags);

        if (sc->scopesym->isModule())
            flags |= SearchUnqualifiedModule;        // tell Module.search() that SearchLocalsOnly is to be obeyed

        if (Dsymbol *s = sc->scopesym->search(loc, ident, flags))
        {
            if (!(flags & (SearchImportsOnly | IgnoreErrors)) &&
                ident == Id::length && sc->scopesym->isArrayScopeSymbol() &&
                sc->enclosing && sc->enclosing->search(loc, ident, NULL, flags))
            {
                warning(s->loc, "array 'length' hides other 'length' name in outer scope");
            }
#ifdef LOGSEARCH
            printf("\tfound %s.%s, kind = '%s'\n", s->parent ? s->parent->toChars() : "", s->toChars(), s->kind());
#endif
            if (pscopesym)
                *pscopesym = sc->scopesym;
            return s;
        }
        // Stop when we hit a module, but keep going if that is not just under the global scope
        if (sc->scopesym->isModule() && !(sc->enclosing && !sc->enclosing->enclosing))
            break;
    }
    return NULL;
}

/************************************
 * Perform unqualified name lookup by following the chain of scopes up
 * until found.
 *
 * Params:
 *  loc = location to use for error messages
 *  ident = name to look up
 *  pscopesym = if supplied and name is found, set to scope that ident was found in
 *  flags = modify search based on flags
 *
 * Returns:
 *  symbol if found, null if not
 */
Dsymbol *Scope::search(Loc loc, Identifier *ident, Dsymbol **pscopesym, int flags)
{
#ifdef LOGSEARCH
    printf("Scope::search(%p, '%s' flags=x%x)\n", this, ident->toChars(), flags);
    // Print scope chain
    for (Scope *sc = this; sc; sc = sc->enclosing)
    {
        if (!sc->scopesym)
            continue;
        printf("\tscope %s\n", sc->scopesym->toChars());
    }
#endif

    // This function is called only for unqualified lookup
    assert(!(flags & (SearchLocalsOnly | SearchImportsOnly)));

    /* If ident is "start at module scope", only look at module scope
     */
    if (ident == Id::empty)
    {
        // Look for module scope
        for (Scope *sc = this; sc; sc = sc->enclosing)
        {
            assert(sc != sc->enclosing);
            if (!sc->scopesym)
                continue;

            if (Dsymbol *s = sc->scopesym->isModule())
            {
#ifdef LOGSEARCH
                printf("\tfound %s.%s, kind = '%s'\n", s->parent ? s->parent->toChars() : "", s->toChars(), s->kind());
#endif
                if (pscopesym)
                    *pscopesym = sc->scopesym;
                return s;
            }
        }
        return NULL;
    }

    Dsymbol *sold;
    if (global.params.bug10378 || global.params.check10378)
    {
        sold = searchScopes(this, loc, ident, pscopesym, flags | IgnoreSymbolVisibility);
        if (!global.params.check10378)
            return sold;

        if (ident == Id::dollar) // Bugzilla 15825
            return sold;

        // Search both ways
        flags |= SearchCheckImports;
    }

    // First look in local scopes
    Dsymbol *s = searchScopes(this, loc, ident, pscopesym, flags | SearchLocalsOnly);
#ifdef LOGSEARCH
    if (s)
        printf("\t-Scope::search() found local %s.%s, kind = '%s'\n",
               s->parent ? s->parent->toChars() : "", s->toChars(), s->kind());
#endif
    if (!s)
    {
        // Second look in imported modules
        s = searchScopes(this, loc, ident, pscopesym, flags | SearchImportsOnly);
#ifdef LOGSEARCH
        if (s)
            printf("\t-Scope::search() found import %s.%s, kind = '%s'\n",
                   s->parent ? s->parent->toChars() : "", s->toChars(), s->kind());
#endif

        /** Still find private symbols, so that symbols that weren't access
         * checked by the compiler remain usable.  Once the deprecation is over,
         * this should be moved to search_correct instead.
         */
        if (!s)
        {
            s = searchScopes(this, loc, ident, pscopesym, flags | SearchLocalsOnly | IgnoreSymbolVisibility);
            if (!s)
                s = searchScopes(this, loc, ident, pscopesym, flags | SearchImportsOnly | IgnoreSymbolVisibility);

            if (s && !(flags & IgnoreErrors))
                ::deprecation(loc, "%s is not visible from module %s", s->toPrettyChars(), module->toChars());
#ifdef LOGSEARCH
            if (s)
                printf("\t-Scope::search() found imported private symbol%s.%s, kind = '%s'\n",
                       s->parent ? s->parent->toChars() : "", s->toChars(), s->kind());
#endif
        }
    }

    if (global.params.check10378)
    {
        Dsymbol *snew = s;
        if (sold != snew)
        {
            deprecation(loc, "local import search method found %s %s instead of %s %s",
                        sold ? sold->kind() : "nothing", sold ? sold->toPrettyChars() : NULL,
                        snew ? snew->kind() : "nothing", snew ? snew->toPrettyChars() : NULL);
        }
        if (global.params.bug10378)
            s = sold;
    }
    return s;
}

Dsymbol *Scope::insert(Dsymbol *s)
{
    if (VarDeclaration *vd = s->isVarDeclaration())
    {
        if (lastVar)
            vd->lastVar = lastVar;
        lastVar = vd;
    }
    else if (WithScopeSymbol *ss = s->isWithScopeSymbol())
    {
        if (VarDeclaration *vd = ss->withstate->wthis)
        {
            if (lastVar)
                vd->lastVar = lastVar;
            lastVar = vd;
        }
        return NULL;
    }
    for (Scope *sc = this; sc; sc = sc->enclosing)
    {
        //printf("\tsc = %p\n", sc);
        if (sc->scopesym)
        {
            //printf("\t\tsc->scopesym = %p\n", sc->scopesym);
            if (!sc->scopesym->symtab)
                sc->scopesym->symtab = new DsymbolTable();
            return sc->scopesym->symtabInsert(s);
        }
    }
    assert(0);
    return NULL;
}

/********************************************
 * Search enclosing scopes for ClassDeclaration.
 */

ClassDeclaration *Scope::getClassScope()
{
    for (Scope *sc = this; sc; sc = sc->enclosing)
    {
        if (!sc->scopesym)
            continue;

        ClassDeclaration *cd = sc->scopesym->isClassDeclaration();
        if (cd)
            return cd;
    }
    return NULL;
}

/********************************************
 * Search enclosing scopes for ClassDeclaration.
 */

AggregateDeclaration *Scope::getStructClassScope()
{
    for (Scope *sc = this; sc; sc = sc->enclosing)
    {
        if (!sc->scopesym)
            continue;

        AggregateDeclaration *ad = sc->scopesym->isClassDeclaration();
        if (ad)
            return ad;
        ad = sc->scopesym->isStructDeclaration();
        if (ad)
            return ad;
    }
    return NULL;
}

/*******************************************
 * For TemplateDeclarations, we need to remember the Scope
 * where it was declared. So mark the Scope as not
 * to be free'd.
 */

void Scope::setNoFree()
{
    //int i = 0;

    //printf("Scope::setNoFree(this = %p)\n", this);
    for (Scope *sc = this; sc; sc = sc->enclosing)
    {
        //printf("\tsc = %p\n", sc);
        sc->nofree = 1;

        assert(!(flags & SCOPEfree));
        //assert(sc != sc->enclosing);
        //assert(!sc->enclosing || sc != sc->enclosing->enclosing);
        //if (++i == 10)
            //assert(0);
    }
}

structalign_t Scope::alignment()
{
    if (aligndecl)
        return aligndecl->getAlignment();
    else
        return STRUCTALIGN_DEFAULT;
}

/************************************************
 * Given the failed search attempt, try to find
 * one with a close spelling.
 */

void *scope_search_fp(void *arg, const char *seed, int* cost)
{
    //printf("scope_search_fp('%s')\n", seed);

    /* If not in the lexer's string table, it certainly isn't in the symbol table.
     * Doing this first is a lot faster.
     */
    size_t len = strlen(seed);
    if (!len)
        return NULL;
    Identifier *id = Identifier::lookup(seed, len);
    if (!id)
        return NULL;

    Scope *sc = (Scope *)arg;
    Module::clearCache();
    Dsymbol *scopesym = NULL;
    Dsymbol *s = sc->search(Loc(), id, &scopesym, IgnoreErrors);
    if (s)
    {
        for (*cost = 0; sc; sc = sc->enclosing, (*cost)++)
            if (sc->scopesym == scopesym)
                break;
        if (scopesym != s->parent)
        {
            (*cost)++; // got to the symbol through an import
            if (s->prot().kind == PROTprivate)
                return NULL;
        }
    }
    return (void*)s;
}

Dsymbol *Scope::search_correct(Identifier *ident)
{
    if (global.gag)
        return NULL;            // don't do it for speculative compiles; too time consuming

    return (Dsymbol *)speller(ident->toChars(), &scope_search_fp, this, idchars);
}
