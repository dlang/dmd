
// Copyright (c) 1999-2010 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <assert.h>
#include <string.h>                     // strlen()

#include "root.h"
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
#include "lexer.h"

Scope *Scope::freelist = NULL;

void *Scope::operator new(size_t size)
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

    void *p = ::operator new(size);
    //printf("new %p\n", p);
    return p;
}

Scope::Scope()
{   // Create root scope

    //printf("Scope::Scope() %p\n", this);
    this->module = NULL;
    this->instantiatingModule = NULL;
    this->scopesym = NULL;
    this->sd = NULL;
    this->enclosing = NULL;
    this->parent = NULL;
    this->sw = NULL;
    this->tf = NULL;
    this->tinst = NULL;
    this->sbreak = NULL;
    this->scontinue = NULL;
    this->fes = NULL;
    this->callsc = NULL;
    this->structalign = STRUCTALIGN_DEFAULT;
    this->func = NULL;
    this->slabel = NULL;
    this->linkage = LINKd;
    this->protection = PROTpublic;
    this->explicitProtection = 0;
    this->stc = 0;
    this->depmsg = NULL;
    this->offset = 0;
    this->inunion = 0;
    this->nofree = 0;
    this->noctor = 0;
    this->intypeof = 0;
    this->speculative = 0;
    this->lastVar = NULL;
    this->callSuper = 0;
    this->fieldinit = NULL;
    this->fieldinit_dim = 0;
    this->flags = 0;
    this->lastdc = NULL;
    this->lastoffset = 0;
    this->docbuf = NULL;
    this->userAttributes = NULL;
}

Scope::Scope(Scope *enclosing)
{
    //printf("Scope::Scope(enclosing = %p) %p\n", enclosing, this);
    assert(!(enclosing->flags & SCOPEfree));
    this->module = enclosing->module;
    this->instantiatingModule = enclosing->instantiatingModule;
    this->func   = enclosing->func;
    this->parent = enclosing->parent;
    this->scopesym = NULL;
    this->sd = NULL;
    this->sw = enclosing->sw;
    this->tf = enclosing->tf;
    this->tinst = enclosing->tinst;
    this->sbreak = enclosing->sbreak;
    this->scontinue = enclosing->scontinue;
    this->fes = enclosing->fes;
    this->callsc = enclosing->callsc;
    this->structalign = enclosing->structalign;
    this->enclosing = enclosing;
#ifdef DEBUG
    if (enclosing->enclosing)
        assert(!(enclosing->enclosing->flags & SCOPEfree));
    if (this == enclosing->enclosing)
    {
        printf("this = %p, enclosing = %p, enclosing->enclosing = %p\n", this, enclosing, enclosing->enclosing);
    }
    assert(this != enclosing->enclosing);
#endif
    this->slabel = NULL;
    this->linkage = enclosing->linkage;
    this->protection = enclosing->protection;
    this->explicitProtection = enclosing->explicitProtection;
    this->depmsg = enclosing->depmsg;
    this->stc = enclosing->stc;
    this->offset = 0;
    this->inunion = enclosing->inunion;
    this->nofree = 0;
    this->noctor = enclosing->noctor;
    this->intypeof = enclosing->intypeof;
    this->speculative = enclosing->speculative;
    this->lastVar = enclosing->lastVar;
    this->callSuper = enclosing->callSuper;
    this->fieldinit = enclosing->saveFieldInit();
    this->fieldinit_dim = enclosing->fieldinit_dim;
    this->flags = (enclosing->flags & (SCOPEcontract | SCOPEdebug | SCOPEctfe | SCOPEcompile));
    this->lastdc = NULL;
    this->lastoffset = 0;
    this->docbuf = enclosing->docbuf;
    this->userAttributes = enclosing->userAttributes;
    assert(this != enclosing);
}

Scope *Scope::createGlobal(Module *module)
{
    Scope *sc;

    sc = new Scope();
    sc->module = module;
    sc->scopesym = new ScopeDsymbol();
    sc->scopesym->symtab = new DsymbolTable();

    // Add top level package as member of this global scope
    Dsymbol *m = module;
    while (m->parent)
        m = m->parent;
    m->addMember(NULL, sc->scopesym, 1);
    m->parent = NULL;                   // got changed by addMember()

    // Create the module scope underneath the global scope
    sc = sc->push(module);
    sc->parent = module;
    return sc;
}

Scope *Scope::push()
{
    //printf("Scope::push()\n");
    Scope *s = new Scope(this);
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
            size_t dim = fieldinit_dim;
            for (size_t i = 0; i < dim; i++)
                enclosing->fieldinit[i] |= fieldinit[i];
            /* Workaround regression @@@BUG11777@@@.
            Probably this memory is used in future.
            mem.free(fieldinit);
            */
            fieldinit = NULL;
        }
    }

    if (!nofree)
    {   enclosing = freelist;
        freelist = this;
        flags |= SCOPEfree;
    }

    return enc;
}

Scope *Scope::startCTFE()
{
    Scope *sc = this->push();
    sc->flags = this->flags | SCOPEctfe;
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
    {   // Have ALL branches called a constructor?
        int aAll = (cs        & (CSXthis_ctor | CSXsuper_ctor)) != 0;
        int bAll = (callSuper & (CSXthis_ctor | CSXsuper_ctor)) != 0;

        // Have ANY branches called a constructor?
        bool aAny = (cs        & CSXany_ctor) != 0;
        bool bAny = (callSuper & CSXany_ctor) != 0;

        // Have any branches returned?
        bool aRet = (cs        & CSXreturn) != 0;
        bool bRet = (callSuper & CSXreturn) != 0;

        bool ok = true;

        // If one has returned without a constructor call, there must be never
        // have been ctor calls in the other.
        if ( (aRet && !aAny && bAny) ||
             (bRet && !bAny && aAny))
        {   ok = false;
        }
        // If one branch has called a ctor and then exited, anything the
        // other branch has done is OK (except returning without a
        // ctor call, but we already checked that).
        else if (aRet && aAll)
        {
            callSuper |= cs & (CSXany_ctor | CSXlabel);
        }
        else if (bRet && bAll)
        {
            callSuper = cs | (callSuper & (CSXany_ctor | CSXlabel));
        }
        else
        {   // Both branches must have called ctors, or both not.
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
        fi = (unsigned *)mem.malloc(sizeof(unsigned) * dim);
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

        bool ok;

        if (aRet)
        {
            ok = !mustInit || (fi & CSXthis_ctor);
            fieldInit = fieldInit;
        }
        else if (bRet)
        {
            ok = !mustInit || (fieldInit & CSXthis_ctor);
            fieldInit = fi;
        }
        else
        {
            ok = !mustInit || !((fieldInit ^ fi) & CSXthis_ctor);
            fieldInit |= fi;
        }

        return ok;
    }
#if 0
    // This does a primitive flow analysis to support the restrictions
    // regarding when and how constructors can appear.
    // It merges the results of two paths.
    // The two paths are fieldInit and fi; the result is merged into fieldInit.

    if (fi != fieldInit)
    {   // Have ALL branches called a constructor?
        int aAll = (fi        & CSXthis_ctor) != 0;
        int bAll = (fieldInit & CSXthis_ctor) != 0;

        // Have ANY branches called a constructor?
        bool aAny = (fi        & CSXany_ctor) != 0;
        bool bAny = (fieldInit & CSXany_ctor) != 0;

        // Have any branches returned?
        bool aRet = (fi        & CSXreturn) != 0;
        bool bRet = (fieldInit & CSXreturn) != 0;

        bool ok = true;

printf("L%d fieldInit = x%x, fi = x%x\n", __LINE__, fieldInit, fi);

        // If one has returned without a constructor call, there must be never
        // have been ctor calls in the other.
        if ( (aRet && !aAny && bAny) ||
             (bRet && !bAny && aAny))
        {   ok = false;
printf("L%d\n", __LINE__);
        }
        // If one branch has called a ctor and then exited, anything the
        // other branch has done is OK (except returning without a
        // ctor call, but we already checked that).
        else if (aRet && aAll)
        {
            //fieldInit |= fi & (CSXany_ctor | CSXlabel);
printf("L%d -> fieldInit = x%x\n", __LINE__, fieldInit);
        }
        else if (bRet && bAll)
        {
            fieldInit = fi;// | (fieldInit & (CSXany_ctor | CSXlabel));
printf("L%d -> fieldInit = x%x\n", __LINE__, fieldInit);
        }
        else
        {   // Both branches must have called ctors, or both not.
            ok = (aAll == bAll);
            // If one returned without a ctor, we must remember that
            // (Don't bother if we've already found an error)
            if (ok && aRet && !aAny)
                fieldInit |= CSXreturn;
            fieldInit |= fi & (CSXany_ctor | CSXlabel);
printf("L%d ok = %d, fieldInit = x%x, fi = x%x\n", __LINE__, ok, fieldInit, fi);
        }
        return ok;
    }
#endif
    return true;
}

void Scope::mergeFieldInit(Loc loc, unsigned *fies)
{
    if (fieldinit && fies)
    {
        FuncDeclaration *f = func;
        if (fes) f = fes->func;
        AggregateDeclaration *ad = f->isAggregateMember2();
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

Dsymbol *Scope::search(Loc loc, Identifier *ident, Dsymbol **pscopesym)
{   Dsymbol *s;
    Scope *sc;

    //printf("Scope::search(%p, '%s')\n", this, ident->toChars());
    if (ident == Id::empty)
    {
        // Look for module scope
        for (sc = this; sc; sc = sc->enclosing)
        {
            assert(sc != sc->enclosing);
            if (sc->scopesym)
            {
                s = sc->scopesym->isModule();
                if (s)
                {
                    //printf("\tfound %s.%s\n", s->parent ? s->parent->toChars() : "", s->toChars());
                    if (pscopesym)
                        *pscopesym = sc->scopesym;
                    return s;
                }
            }
        }
        return NULL;
    }

    for (sc = this; sc; sc = sc->enclosing)
    {
        assert(sc != sc->enclosing);
        if (sc->scopesym)
        {
            //printf("\tlooking in scopesym '%s', kind = '%s'\n", sc->scopesym->toChars(), sc->scopesym->kind());
            s = sc->scopesym->search(loc, ident);
            if (s)
            {
                if (ident == Id::length &&
                    sc->scopesym->isArrayScopeSymbol() &&
                    sc->enclosing &&
                    sc->enclosing->search(loc, ident, NULL))
                {
                    warning(s->loc, "array 'length' hides other 'length' name in outer scope");
                }

                //printf("\tfound %s.%s, kind = '%s'\n", s->parent ? s->parent->toChars() : "", s->toChars(), s->kind());
                if (pscopesym)
                    *pscopesym = sc->scopesym;
                return s;
            }
        }
    }

    return NULL;
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
{   Scope *sc;

    for (sc = this; sc; sc = sc->enclosing)
    {
        ClassDeclaration *cd;

        if (sc->scopesym)
        {
            cd = sc->scopesym->isClassDeclaration();
            if (cd)
                return cd;
        }
    }
    return NULL;
}

/********************************************
 * Search enclosing scopes for ClassDeclaration.
 */

AggregateDeclaration *Scope::getStructClassScope()
{   Scope *sc;

    for (sc = this; sc; sc = sc->enclosing)
    {
        AggregateDeclaration *ad;

        if (sc->scopesym)
        {
            ad = sc->scopesym->isClassDeclaration();
            if (ad)
                return ad;
            else
            {   ad = sc->scopesym->isStructDeclaration();
                if (ad)
                    return ad;
            }
        }
    }
    return NULL;
}

/*******************************************
 * For TemplateDeclarations, we need to remember the Scope
 * where it was declared. So mark the Scope as not
 * to be free'd.
 */

void Scope::setNoFree()
{   Scope *sc;
    //int i = 0;

    //printf("Scope::setNoFree(this = %p)\n", this);
    for (sc = this; sc; sc = sc->enclosing)
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


/************************************************
 * Given the failed search attempt, try to find
 * one with a close spelling.
 */

void *scope_search_fp(void *arg, const char *seed)
{
    //printf("scope_search_fp('%s')\n", seed);

    /* If not in the lexer's string table, it certainly isn't in the symbol table.
     * Doing this first is a lot faster.
     */
    size_t len = strlen(seed);
    if (!len)
        return NULL;
    StringValue *sv = Lexer::stringtable.lookup(seed, len);
    if (!sv)
        return NULL;
    Identifier *id = (Identifier *)sv->ptrvalue;
    assert(id);

    Scope *sc = (Scope *)arg;
    Dsymbol *s = sc->search(Loc(), id, NULL);
    return (void*)s;
}

Dsymbol *Scope::search_correct(Identifier *ident)
{
    if (global.gag)
        return NULL;            // don't do it for speculative compiles; too time consuming

    return (Dsymbol *)speller(ident->toChars(), &scope_search_fp, this, idchars);
}
