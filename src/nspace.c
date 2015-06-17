
// Compiler implementation of the D programming language
// Copyright: Copyright (c) 2014 by Digital Mars, All Rights Reserved
// Authors: Walter Bright, http://www.digitalmars.com
// License: http://boost.org/LICENSE_1_0.txt
// Source: https://github.com/D-Programming-Language/dmd/blob/master/src/nspace.c


#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#include "mars.h"
#include "dsymbol.h"
#include "nspace.h"
#include "identifier.h"
#include "scope.h"

/* This implements namespaces.
 */

Nspace::Nspace(Loc loc, Identifier *ident, Dsymbols *members)
    : ScopeDsymbol(ident)
{
    //printf("Nspace::Nspace(ident = %s)\n", ident->toChars());
    this->loc = loc;
    this->members = members;
}

Dsymbol *Nspace::syntaxCopy(Dsymbol *s)
{
    Nspace *ns = new Nspace(loc, ident, NULL);
    return ScopeDsymbol::syntaxCopy(ns);
}

void Nspace::semantic(Scope *sc)
{
    if (semanticRun >= PASSsemantic)
        return;
    semanticRun = PASSsemantic;
#if LOG
    printf("+Nspace::semantic('%s')\n", toChars());
#endif
    if (scope)
    {
        sc = scope;
        scope = NULL;
    }
    parent = sc->parent;
    if (members)
    {
        if (!symtab)
            symtab = new DsymbolTable();

        // The namespace becomes 'imported' into the enclosing scope
        for (Scope *sce = sc; 1; sce = sce->enclosing)
        {
            ScopeDsymbol *sds = (ScopeDsymbol *)sce->scopesym;
            if (sds)
            {
                sds->importScope(this, Prot(PROTpublic));
                break;
            }
        }

        assert(sc);
        sc = sc->push(this);
        sc->linkage = LINKcpp;          // note that namespaces imply C++ linkage
        sc->parent = this;

        for (size_t i = 0; i < members->dim; i++)
        {
            Dsymbol *s = (*members)[i];
            //printf("add %s to scope %s\n", s->toChars(), toChars());
            s->addMember(sc, this);
        }

        for (size_t i = 0; i < members->dim; i++)
        {
            Dsymbol *s = (*members)[i];
            s->setScope(sc);
        }

        for (size_t i = 0; i < members->dim; i++)
        {
            Dsymbol *s = (*members)[i];
            s->importAll(sc);
        }

        for (size_t i = 0; i < members->dim; i++)
        {
            Dsymbol *s = (*members)[i];
#if LOG
            printf("\tmember '%s', kind = '%s'\n", s->toChars(), s->kind());
#endif
            s->semantic(sc);
        }
        sc->pop();
    }
#if LOG
    printf("-Nspace::semantic('%s')\n", toChars());
#endif
}

void Nspace::semantic2(Scope *sc)
{
    if (semanticRun >= PASSsemantic2)
        return;
    semanticRun = PASSsemantic2;
#if LOG
    printf("+Nspace::semantic2('%s')\n", toChars());
#endif
    if (members)
    {
        assert(sc);
        sc = sc->push(this);
        sc->linkage = LINKcpp;
        for (size_t i = 0; i < members->dim; i++)
        {
            Dsymbol *s = (*members)[i];
#if LOG
            printf("\tmember '%s', kind = '%s'\n", s->toChars(), s->kind());
#endif
            s->semantic2(sc);
        }
        sc->pop();
    }
#if LOG
    printf("-Nspace::semantic2('%s')\n", toChars());
#endif
}

void Nspace::semantic3(Scope *sc)
{
    if (semanticRun >= PASSsemantic3)
        return;
    semanticRun = PASSsemantic3;
#if LOG
    printf("Nspace::semantic3('%s')\n", toChars());
#endif
    if (members)
    {
        sc = sc->push(this);
        sc->linkage = LINKcpp;
        for (size_t i = 0; i < members->dim; i++)
        {
            Dsymbol *s = (*members)[i];
            s->semantic3(sc);
        }
        sc->pop();
    }
}

const char *Nspace::kind()
{
    return "namespace";
}

bool Nspace::oneMember(Dsymbol **ps, Identifier *ident)
{
    return Dsymbol::oneMember(ps, ident);
}

int Nspace::apply(Dsymbol_apply_ft_t fp, void *param)
{
    if (members)
    {
        for (size_t i = 0; i < members->dim; i++)
        {
            Dsymbol *s = (*members)[i];
            if (s)
            {
                if (s->apply(fp, param))
                    return 1;
            }
        }
    }
    return 0;
}

bool Nspace::hasPointers()
{
    //printf("Nspace::hasPointers() %s\n", toChars());

    if (members)
    {
        for (size_t i = 0; i < members->dim; i++)
        {
            Dsymbol *s = (*members)[i];
            //printf(" s = %s %s\n", s->kind(), s->toChars());
            if (s->hasPointers())
            {
                return true;
            }
        }
    }
    return false;
}

void Nspace::setFieldOffset(AggregateDeclaration *ad, unsigned *poffset, bool isunion)
{
    //printf("Nspace::setFieldOffset() %s\n", toChars());
    if (scope)                  // if fwd reference
        semantic(NULL);         // try to resolve it
    if (members)
    {
        for (size_t i = 0; i < members->dim; i++)
        {
            Dsymbol *s = (*members)[i];
            //printf("\t%s\n", s->toChars());
            s->setFieldOffset(ad, poffset, isunion);
        }
    }
}
