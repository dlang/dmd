
/* Compiler implementation of the D programming language
 * Copyright (c) 1999-2014 by Digital Mars
 * All Rights Reserved
 * written by Walter Bright
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/attrib.c
 */

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <string.h>                     // memcpy()

#include "rmem.h"

#include "init.h"
#include "declaration.h"
#include "attrib.h"
#include "cond.h"
#include "scope.h"
#include "id.h"
#include "expression.h"
#include "dsymbol.h"
#include "aggregate.h"
#include "module.h"
#include "parse.h"
#include "template.h"
#include "utf.h"


/********************************* AttribDeclaration ****************************/

AttribDeclaration::AttribDeclaration(Dsymbols *decl)
        : Dsymbol()
{
    this->decl = decl;
}

Dsymbols *AttribDeclaration::include(Scope *sc, ScopeDsymbol *sds)
{
    return decl;
}

int AttribDeclaration::apply(Dsymbol_apply_ft_t fp, void *param)
{
    Dsymbols *d = include(scope, NULL);

    if (d)
    {
        for (size_t i = 0; i < d->dim; i++)
        {
            Dsymbol *s = (*d)[i];
            if (s)
            {
                if (s->apply(fp, param))
                    return 1;
            }
        }
    }
    return 0;
}

/****************************************
 * Create a new scope if one or more given attributes
 * are different from the sc's.
 * If the returned scope != sc, the caller should pop
 * the scope after it used.
 */
Scope *AttribDeclaration::createNewScope(Scope *sc,
        StorageClass stc, LINK linkage, Prot protection, int explicitProtection,
        structalign_t structalign)
{
    Scope *sc2 = sc;
    if (stc != sc->stc ||
        linkage != sc->linkage ||
        !protection.isSubsetOf(sc->protection) ||
        explicitProtection != sc->explicitProtection ||
        structalign != sc->structalign)
    {
        // create new one for changes
        sc2 = sc->copy();
        sc2->stc = stc;
        sc2->linkage = linkage;
        sc2->protection = protection;
        sc2->explicitProtection = explicitProtection;
        sc2->structalign = structalign;
    }
    return sc2;
}

/****************************************
 * A hook point to supply scope for members.
 * addMember, setScope, importAll, semantic, semantic2 and semantic3 will use this.
 */
Scope *AttribDeclaration::newScope(Scope *sc)
{
    return sc;
}

int AttribDeclaration::addMember(Scope *sc, ScopeDsymbol *sds, int memnum)
{
    int m = 0;
    Dsymbols *d = include(sc, sds);

    if (d)
    {
        Scope *sc2 = newScope(sc);

        for (size_t i = 0; i < d->dim; i++)
        {
            Dsymbol *s = (*d)[i];
            //printf("\taddMember %s to %s\n", s->toChars(), sds->toChars());
            m |= s->addMember(sc2, sds, m | memnum);
        }

        if (sc2 != sc)
            sc2->pop();
    }
    return m;
}

void AttribDeclaration::setScope(Scope *sc)
{
    Dsymbols *d = include(sc, NULL);

    //printf("\tAttribDeclaration::setScope '%s', d = %p\n",toChars(), d);
    if (d)
    {
        Scope *sc2 = newScope(sc);

        for (size_t i = 0; i < d->dim; i++)
        {
            Dsymbol *s = (*d)[i];
            s->setScope(sc2);
        }

        if (sc2 != sc)
            sc2->pop();
    }
}

void AttribDeclaration::importAll(Scope *sc)
{
    Dsymbols *d = include(sc, NULL);

    //printf("\tAttribDeclaration::importAll '%s', d = %p\n", toChars(), d);
    if (d)
    {
        Scope *sc2 = newScope(sc);

        for (size_t i = 0; i < d->dim; i++)
        {
            Dsymbol *s = (*d)[i];
            s->importAll(sc2);
        }

        if (sc2 != sc)
            sc2->pop();
    }
}

void AttribDeclaration::semantic(Scope *sc)
{
    Dsymbols *d = include(sc, NULL);

    //printf("\tAttribDeclaration::semantic '%s', d = %p\n",toChars(), d);
    if (d)
    {
        Scope *sc2 = newScope(sc);

        for (size_t i = 0; i < d->dim; i++)
        {
            Dsymbol *s = (*d)[i];
            s->semantic(sc2);
        }

        if (sc2 != sc)
            sc2->pop();
    }
}

void AttribDeclaration::semantic2(Scope *sc)
{
    Dsymbols *d = include(sc, NULL);

    if (d)
    {
        Scope *sc2 = newScope(sc);

        for (size_t i = 0; i < d->dim; i++)
        {
            Dsymbol *s = (*d)[i];
            s->semantic2(sc2);
        }

        if (sc2 != sc)
            sc2->pop();
    }
}

void AttribDeclaration::semantic3(Scope *sc)
{
    Dsymbols *d = include(sc, NULL);

    if (d)
    {
        Scope *sc2 = newScope(sc);

        for (size_t i = 0; i < d->dim; i++)
        {
            Dsymbol *s = (*d)[i];
            s->semantic3(sc2);
        }

        if (sc2 != sc)
            sc2->pop();
    }
}

void AttribDeclaration::addComment(const utf8_t *comment)
{
    //printf("AttribDeclaration::addComment %s\n", comment);
    if (comment)
    {
        Dsymbols *d = include(NULL, NULL);

        if (d)
        {
            for (size_t i = 0; i < d->dim; i++)
            {
                Dsymbol *s = (*d)[i];
                //printf("AttribDeclaration::addComment %s\n", s->toChars());
                s->addComment(comment);
            }
        }
    }
}

void AttribDeclaration::setFieldOffset(AggregateDeclaration *ad, unsigned *poffset, bool isunion)
{
    Dsymbols *d = include(NULL, NULL);

    if (d)
    {
        for (size_t i = 0; i < d->dim; i++)
        {
            Dsymbol *s = (*d)[i];
            s->setFieldOffset(ad, poffset, isunion);
        }
    }
}

bool AttribDeclaration::hasPointers()
{
    Dsymbols *d = include(NULL, NULL);

    if (d)
    {
        for (size_t i = 0; i < d->dim; i++)
        {
            Dsymbol *s = (*d)[i];
            if (s->hasPointers())
                return true;
        }
    }
    return false;
}

bool AttribDeclaration::hasStaticCtorOrDtor()
{
    Dsymbols *d = include(NULL, NULL);

    if (d)
    {
        for (size_t i = 0; i < d->dim; i++)
        {
            Dsymbol *s = (*d)[i];
            if (s->hasStaticCtorOrDtor())
                return true;
        }
    }
    return false;
}

const char *AttribDeclaration::kind()
{
    return "attribute";
}

bool AttribDeclaration::oneMember(Dsymbol **ps, Identifier *ident)
{
    Dsymbols *d = include(NULL, NULL);

    return Dsymbol::oneMembers(d, ps, ident);
}

void AttribDeclaration::checkCtorConstInit()
{
    Dsymbols *d = include(NULL, NULL);

    if (d)
    {
        for (size_t i = 0; i < d->dim; i++)
        {
            Dsymbol *s = (*d)[i];
            s->checkCtorConstInit();
        }
    }
}

/****************************************
 */

void AttribDeclaration::addLocalClass(ClassDeclarations *aclasses)
{
    Dsymbols *d = include(NULL, NULL);

    if (d)
    {
        for (size_t i = 0; i < d->dim; i++)
        {
            Dsymbol *s = (*d)[i];
            s->addLocalClass(aclasses);
        }
    }
}

/************************* StorageClassDeclaration ****************************/

StorageClassDeclaration::StorageClassDeclaration(StorageClass stc, Dsymbols *decl)
        : AttribDeclaration(decl)
{
    this->stc = stc;
}

Dsymbol *StorageClassDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    return new StorageClassDeclaration(stc, Dsymbol::arraySyntaxCopy(decl));
}

bool StorageClassDeclaration::oneMember(Dsymbol **ps, Identifier *ident)
{
    bool t = Dsymbol::oneMembers(decl, ps, ident);
    if (t && *ps)
    {
        /* This is to deal with the following case:
         * struct Tick {
         *   template to(T) { const T to() { ... } }
         * }
         * For eponymous function templates, the 'const' needs to get attached to 'to'
         * before the semantic analysis of 'to', so that template overloading based on the
         * 'this' pointer can be successful.
         */

        FuncDeclaration *fd = (*ps)->isFuncDeclaration();
        if (fd)
        {
            /* Use storage_class2 instead of storage_class otherwise when we do .di generation
             * we'll wind up with 'const const' rather than 'const'.
             */
            /* Don't think we need to worry about mutually exclusive storage classes here
             */
            fd->storage_class2 |= stc;
        }
    }
    return t;
}

Scope *StorageClassDeclaration::newScope(Scope *sc)
{
    StorageClass scstc = sc->stc;

    /* These sets of storage classes are mutually exclusive,
     * so choose the innermost or most recent one.
     */
    if (stc & (STCauto | STCscope | STCstatic | STCextern | STCmanifest))
        scstc &= ~(STCauto | STCscope | STCstatic | STCextern | STCmanifest);
    if (stc & (STCauto | STCscope | STCstatic | STCtls | STCmanifest | STCgshared))
        scstc &= ~(STCauto | STCscope | STCstatic | STCtls | STCmanifest | STCgshared);
    if (stc & (STCconst | STCimmutable | STCmanifest))
        scstc &= ~(STCconst | STCimmutable | STCmanifest);
    if (stc & (STCgshared | STCshared | STCtls))
        scstc &= ~(STCgshared | STCshared | STCtls);
    if (stc & (STCsafe | STCtrusted | STCsystem))
        scstc &= ~(STCsafe | STCtrusted | STCsystem);
    scstc |= stc;
    //printf("scstc = x%llx\n", scstc);

    return createNewScope(sc, scstc, sc->linkage, sc->protection, sc->explicitProtection, sc->structalign);
}

/*************************************************
 * Pick off one of the storage classes from stc,
 * and return a pointer to a string representation of it.
 * stc is reduced by the one picked.
 * tmp[] is a buffer big enough to hold that string.
 */
const char *StorageClassDeclaration::stcToChars(char tmp[], StorageClass& stc)
{
    struct SCstring
    {
        StorageClass stc;
        TOK tok;
        const char *id;
    };

    static SCstring table[] =
    {
        { STCauto,         TOKauto },
        { STCscope,        TOKscope },
        { STCstatic,       TOKstatic },
        { STCextern,       TOKextern },
        { STCconst,        TOKconst },
        { STCfinal,        TOKfinal },
        { STCabstract,     TOKabstract },
        { STCsynchronized, TOKsynchronized },
        { STCdeprecated,   TOKdeprecated },
        { STCoverride,     TOKoverride },
        { STClazy,         TOKlazy },
        { STCalias,        TOKalias },
        { STCout,          TOKout },
        { STCin,           TOKin },
        { STCmanifest,     TOKenum },
        { STCimmutable,    TOKimmutable },
        { STCshared,       TOKshared },
        { STCnothrow,      TOKnothrow },
        { STCwild,         TOKwild },
        { STCpure,         TOKpure },
        { STCref,          TOKref },
        { STCtls },
        { STCgshared,      TOKgshared },
        { STCnogc,         TOKat,       "nogc" },
        { STCproperty,     TOKat,       "property" },
        { STCsafe,         TOKat,       "safe" },
        { STCtrusted,      TOKat,       "trusted" },
        { STCsystem,       TOKat,       "system" },
        { STCdisable,      TOKat,       "disable" },
        { 0,               TOKreserved }
    };

    for (int i = 0; table[i].stc; i++)
    {
        StorageClass tbl = table[i].stc;
        assert(tbl & STCStorageClass);
        if (stc & tbl)
        {
            stc &= ~tbl;
            if (tbl == STCtls)  // TOKtls was removed
                return "__thread";

            TOK tok = table[i].tok;
            if (tok == TOKat)
            {
                tmp[0] = '@';
                strcpy(tmp + 1, table[i].id);
                return tmp;
            }
            else
                return Token::toChars(tok);
        }
    }
    //printf("stc = %llx\n", (unsigned long long)stc);
    return NULL;
}

void StorageClassDeclaration::stcToCBuffer(OutBuffer *buf, StorageClass stc)
{
    while (stc)
    {
        const size_t BUFFER_LEN = 20;
        char tmp[BUFFER_LEN];
        const char *p = stcToChars(tmp, stc);
        if (!p)
            break;
        assert(strlen(p) < BUFFER_LEN);
        buf->writestring(p);
        buf->writeByte(' ');
    }
}

/********************************* DeprecatedDeclaration ****************************/

DeprecatedDeclaration::DeprecatedDeclaration(Expression *msg, Dsymbols *decl)
        : StorageClassDeclaration(STCdeprecated, decl)
{
    this->msg = msg;
}

Dsymbol *DeprecatedDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    return new DeprecatedDeclaration(msg->syntaxCopy(), Dsymbol::arraySyntaxCopy(decl));
}

void DeprecatedDeclaration::setScope(Scope *sc)
{
    assert(msg);
    char *depmsg = NULL;
    StringExp *se = msg->toStringExp();
    if (se)
        depmsg = (char *)se->string;
    else
        msg->error("string expected, not '%s'", msg->toChars());

    Scope *scx = sc->push();
    scx->depmsg = depmsg;
    StorageClassDeclaration::setScope(scx);
    scx->pop();
}

/********************************* LinkDeclaration ****************************/

LinkDeclaration::LinkDeclaration(LINK p, Dsymbols *decl)
        : AttribDeclaration(decl)
{
    //printf("LinkDeclaration(linkage = %d, decl = %p)\n", p, decl);
    linkage = p;
}

Dsymbol *LinkDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    return new LinkDeclaration(linkage, Dsymbol::arraySyntaxCopy(decl));
}

Scope *LinkDeclaration::newScope(Scope *sc)
{
    return createNewScope(sc, sc->stc, this->linkage, sc->protection, sc->explicitProtection, sc->structalign);
}

char *LinkDeclaration::toChars()
{
    return (char *)"extern ()";
}

/********************************* ProtDeclaration ****************************/

/**
 * Params:
 *  loc = source location of attribute token
 *  p = protection attribute data
 *  decl = declarations which are affected by this protection attribute
 */
ProtDeclaration::ProtDeclaration(Loc loc, Prot p, Dsymbols *decl)
        : AttribDeclaration(decl)
{
    this->loc = loc;
    this->protection = p;
    this->pkg_identifiers = NULL;
    //printf("decl = %p\n", decl);
}

/**
 * Params:
 *  loc = source location of attribute token
 *  pkg_identifiers = list of identifiers for a qualified package name
 *  decl = declarations which are affected by this protection attribute
 */
ProtDeclaration::ProtDeclaration(Loc loc, Identifiers* pkg_identifiers, Dsymbols *decl)
        : AttribDeclaration(decl)
{
    this->loc = loc;
    this->protection.kind = PROTpackage;
    this->protection.pkg  = NULL;
    this->pkg_identifiers = pkg_identifiers;
}

Dsymbol *ProtDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    if (protection.kind == PROTpackage)
        return new ProtDeclaration(this->loc, pkg_identifiers, Dsymbol::arraySyntaxCopy(decl));
    else
        return new ProtDeclaration(this->loc, protection, Dsymbol::arraySyntaxCopy(decl));
}

Scope *ProtDeclaration::newScope(Scope *sc)
{
    if (pkg_identifiers)
        semantic(sc);
    return createNewScope(sc, sc->stc, sc->linkage, this->protection, 1, sc->structalign);
}

int ProtDeclaration::addMember(Scope *sc, ScopeDsymbol *sds, int memnum)
{
    if (pkg_identifiers)
    {
        Dsymbol* tmp;
        Package::resolve(pkg_identifiers, &tmp, NULL);
        protection.pkg = tmp ? tmp->isPackage() : NULL;
        pkg_identifiers = NULL;
    }

    if (protection.kind == PROTpackage && protection.pkg && sc->module)
    {
        Module *m = sc->module;
        Package* pkg = m->parent ? m->parent->isPackage() : NULL;
        if (!pkg || !protection.pkg->isAncestorPackageOf(pkg))
            error("does not bind to one of ancestor packages of module '%s'",
               m->toPrettyChars(true));
    }

    return AttribDeclaration::addMember(sc, sds, memnum);
}

const char *ProtDeclaration::kind()
{
    return "protection attribute";
}

const char *ProtDeclaration::toPrettyChars(bool)
{
    assert(protection.kind > PROTundefined);

    OutBuffer buf;
    buf.writeByte('\'');
    protectionToBuffer(&buf, protection);
    buf.writeByte('\'');
    return buf.extractString();
}

/********************************* AlignDeclaration ****************************/

AlignDeclaration::AlignDeclaration(unsigned sa, Dsymbols *decl)
        : AttribDeclaration(decl)
{
    salign = sa;
}

Dsymbol *AlignDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    return new AlignDeclaration(salign, Dsymbol::arraySyntaxCopy(decl));
}

Scope *AlignDeclaration::newScope(Scope *sc)
{
    return createNewScope(sc, sc->stc, sc->linkage, sc->protection, sc->explicitProtection, this->salign);
}

/********************************* AnonDeclaration ****************************/

AnonDeclaration::AnonDeclaration(Loc loc, bool isunion, Dsymbols *decl)
        : AttribDeclaration(decl)
{
    this->loc = loc;
    this->alignment = 0;
    this->isunion = isunion;
    this->sem = 0;
}

Dsymbol *AnonDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    return new AnonDeclaration(loc, isunion, Dsymbol::arraySyntaxCopy(decl));
}

void AnonDeclaration::semantic(Scope *sc)
{
    //printf("\tAnonDeclaration::semantic %s %p\n", isunion ? "union" : "struct", this);

    assert(sc->parent);

    Dsymbol *parent = sc->parent->pastMixin();
    AggregateDeclaration *ad = parent->isAggregateDeclaration();

    if (!ad || (!ad->isStructDeclaration() && !ad->isClassDeclaration()))
    {
        error("can only be a part of an aggregate");
        return;
    }

    alignment = sc->structalign;
    if (decl)
    {
        sc = sc->push();
        sc->stc &= ~(STCauto | STCscope | STCstatic | STCtls | STCgshared);
        sc->inunion = isunion;
        sc->flags = 0;

        for (size_t i = 0; i < decl->dim; i++)
        {
            Dsymbol *s = (*decl)[i];
            s->semantic(sc);
        }
        sc = sc->pop();
    }
}

void AnonDeclaration::setFieldOffset(AggregateDeclaration *ad, unsigned *poffset, bool isunion)
{
    //printf("\tAnonDeclaration::setFieldOffset %s %p\n", isunion ? "union" : "struct", this);

    if (decl)
    {
        /* This works by treating an AnonDeclaration as an aggregate 'member',
         * so in order to place that member we need to compute the member's
         * size and alignment.
         */

        size_t fieldstart = ad->fields.dim;

        /* Hackishly hijack ad's structsize and alignsize fields
         * for use in our fake anon aggregate member.
         */
        unsigned savestructsize = ad->structsize;
        unsigned savealignsize  = ad->alignsize;
        ad->structsize = 0;
        ad->alignsize = 0;

        unsigned offset = 0;
        for (size_t i = 0; i < decl->dim; i++)
        {
            Dsymbol *s = (*decl)[i];
            s->setFieldOffset(ad, &offset, this->isunion);
            if (this->isunion)
                offset = 0;
        }

        unsigned anonstructsize = ad->structsize;
        unsigned anonalignsize  = ad->alignsize;
        ad->structsize = savestructsize;
        ad->alignsize  = savealignsize;

        if (fieldstart == ad->fields.dim)
        {
            /* Bugzilla 13613: If the fields in this->members had been already
             * added in ad->fields, just update *poffset for the subsequent
             * field offset calculation.
             */
            *poffset = ad->structsize;
            return;
        }

        // 0 sized structs are set to 1 byte
        // TODO: is this corect hebavior?
        if (anonstructsize == 0)
        {
            anonstructsize = 1;
            anonalignsize = 1;
        }

        /* Given the anon 'member's size and alignment,
         * go ahead and place it.
         */
        unsigned anonoffset = AggregateDeclaration::placeField(
                poffset,
                anonstructsize, anonalignsize, alignment,
                &ad->structsize, &ad->alignsize,
                isunion);

        // Add to the anon fields the base offset of this anonymous aggregate
        //printf("anon fields, anonoffset = %d\n", anonoffset);
        for (size_t i = fieldstart; i < ad->fields.dim; i++)
        {
            VarDeclaration *v = ad->fields[i];
            //printf("\t[%d] %s %d\n", i, v->toChars(), v->offset);
            v->offset += anonoffset;
        }
    }
}

const char *AnonDeclaration::kind()
{
    return (isunion ? "anonymous union" : "anonymous struct");
}

/********************************* PragmaDeclaration ****************************/

PragmaDeclaration::PragmaDeclaration(Loc loc, Identifier *ident, Expressions *args, Dsymbols *decl)
        : AttribDeclaration(decl)
{
    this->loc = loc;
    this->ident = ident;
    this->args = args;
}

Dsymbol *PragmaDeclaration::syntaxCopy(Dsymbol *s)
{
    //printf("PragmaDeclaration::syntaxCopy(%s)\n", toChars());
    assert(!s);
    return new PragmaDeclaration(loc, ident,
        Expression::arraySyntaxCopy(args),
        Dsymbol::arraySyntaxCopy(decl));
}

void PragmaDeclaration::setScope(Scope *sc)
{
}

static unsigned setMangleOverride(Dsymbol *s, char *sym)
{
    AttribDeclaration *ad = s->isAttribDeclaration();

    if (ad)
    {
        Dsymbols *decls = ad->include(NULL, NULL);
        unsigned nestedCount = 0;

        if (decls && decls->dim)
            for (size_t i = 0; i < decls->dim; ++i)
                nestedCount += setMangleOverride((*decls)[i], sym);

        return nestedCount;
    }
    else if (s->isFuncDeclaration() || s->isVarDeclaration())
    {
        s->isDeclaration()->mangleOverride = sym;
        return 1;
    }
    else
        return 0;
}

void PragmaDeclaration::semantic(Scope *sc)
{
    // Should be merged with PragmaStatement

    //printf("\tPragmaDeclaration::semantic '%s'\n",toChars());
    if (ident == Id::msg)
    {
        if (args)
        {
            for (size_t i = 0; i < args->dim; i++)
            {
                Expression *e = (*args)[i];

                sc = sc->startCTFE();
                e = e->semantic(sc);
                e = resolveProperties(sc, e);
                sc = sc->endCTFE();

                // pragma(msg) is allowed to contain types as well as expressions
                e = ctfeInterpretForPragmaMsg(e);
                if (e->op == TOKerror)
                {
                    errorSupplemental(loc, "while evaluating pragma(msg, %s)", (*args)[i]->toChars());
                    return;
                }
                StringExp *se = e->toStringExp();
                if (se)
                {
                    se = se->toUTF8(sc);
                    fprintf(stderr, "%.*s", (int)se->len, (char *)se->string);
                }
                else
                    fprintf(stderr, "%s", e->toChars());
            }
            fprintf(stderr, "\n");
        }
        goto Lnodecl;
    }
    else if (ident == Id::lib)
    {
        if (!args || args->dim != 1)
            error("string expected for library name");
        else
        {
            Expression *e = (*args)[0];

            sc = sc->startCTFE();
            e = e->semantic(sc);
            e = resolveProperties(sc, e);
            sc = sc->endCTFE();

            e = e->ctfeInterpret();
            (*args)[0] = e;
            if (e->op == TOKerror)
                goto Lnodecl;
            StringExp *se = e->toStringExp();
            if (!se)
                error("string expected for library name, not '%s'", e->toChars());
            else
            {
                char *name = (char *)mem.malloc(se->len + 1);
                memcpy(name, se->string, se->len);
                name[se->len] = 0;
                if (global.params.verbose)
                    fprintf(global.stdmsg, "library   %s\n", name);
                if (global.params.moduleDeps && !global.params.moduleDepsFile)
                {
                    OutBuffer *ob = global.params.moduleDeps;
                    Module *imod = sc->instantiatingModule();
                    ob->writestring("depsLib ");
                    ob->writestring(imod->toPrettyChars());
                    ob->writestring(" (");
                    escapePath(ob, imod->srcfile->toChars());
                    ob->writestring(") : ");
                    ob->writestring((char *) name);
                    ob->writenl();
                }
                mem.free(name);
            }
        }
        goto Lnodecl;
    }
    else if (ident == Id::startaddress)
    {
        if (!args || args->dim != 1)
            error("function name expected for start address");
        else
        {
            /* Bugzilla 11980:
             * resolveProperties and ctfeInterpret call are not necessary.
             */
            Expression *e = (*args)[0];

            sc = sc->startCTFE();
            e = e->semantic(sc);
            sc = sc->endCTFE();

            (*args)[0] = e;
            Dsymbol *sa = getDsymbol(e);
            if (!sa || !sa->isFuncDeclaration())
                error("function name expected for start address, not '%s'", e->toChars());
        }
        goto Lnodecl;
    }
    else if (ident == Id::mangle)
    {
        if (!args)
            args = new Expressions();
        if (args->dim != 1)
        {
            error("string expected for mangled name");
            args->setDim(1);
            (*args)[0] = new ErrorExp();    // error recovery
            goto Ldecl;
        }

        Expression *e = (*args)[0];
        e = e->semantic(sc);
        e = e->ctfeInterpret();
        (*args)[0] = e;
        if (e->op == TOKerror)
            goto Ldecl;

        StringExp *se = e->toStringExp();
        if (!se)
        {
            error("string expected for mangled name, not '%s'", e->toChars());
            goto Ldecl;
        }
        if (!se->len)
        {
            error("zero-length string not allowed for mangled name");
            goto Ldecl;
        }
        if (se->sz != 1)
        {
            error("mangled name characters can only be of type char");
            goto Ldecl;
        }

#if 1
        /* Note: D language specification should not have any assumption about backend
         * implementation. Ideally pragma(mangle) can accept a string of any content.
         *
         * Therefore, this validation is compiler implementation specific.
         */
        for (size_t i = 0; i < se->len; )
        {
            utf8_t *p = (utf8_t *)se->string;
            dchar_t c = p[i];
            if (c < 0x80)
            {
                if (c >= 'A' && c <= 'Z' ||
                    c >= 'a' && c <= 'z' ||
                    c >= '0' && c <= '9' ||
                    c != 0 && strchr("$%().:?@[]_", c))
                {
                    ++i;
                    continue;
                }
                else
                {
                    error("char 0x%02x not allowed in mangled name", c);
                    break;
                }
            }

            if (const char* msg = utf_decodeChar((utf8_t *)se->string, se->len, &i, &c))
            {
                error("%s", msg);
                break;
            }

            if (!isUniAlpha(c))
            {
                error("char 0x%04x not allowed in mangled name", c);
                break;
            }
        }
#endif
    }
    else if (global.params.ignoreUnsupportedPragmas)
    {
        if (global.params.verbose)
        {
            /* Print unrecognized pragmas
             */
            fprintf(global.stdmsg, "pragma    %s", ident->toChars());
            if (args)
            {
                for (size_t i = 0; i < args->dim; i++)
                {
                    Expression *e = (*args)[i];

                    sc = sc->startCTFE();
                    e = e->semantic(sc);
                    e = resolveProperties(sc, e);
                    sc = sc->endCTFE();

                    e = e->ctfeInterpret();
                    if (i == 0)
                        fprintf(global.stdmsg, " (");
                    else
                        fprintf(global.stdmsg, ",");
                    fprintf(global.stdmsg, "%s", e->toChars());
                }
                if (args->dim)
                    fprintf(global.stdmsg, ")");
            }
            fprintf(global.stdmsg, "\n");
        }
        goto Lnodecl;
    }
    else
        error("unrecognized pragma(%s)", ident->toChars());

Ldecl:
    if (decl)
    {
        for (size_t i = 0; i < decl->dim; i++)
        {
            Dsymbol *s = (*decl)[i];

            s->semantic(sc);

            if (ident == Id::mangle)
            {
                assert(args && args->dim == 1);
                if (StringExp *se = (*args)[0]->toStringExp())
                {
                    char *name = (char *)mem.malloc(se->len + 1);
                    memcpy(name, se->string, se->len);
                    name[se->len] = 0;

                    unsigned cnt = setMangleOverride(s, name);
                    if (cnt > 1)
                        error("can only apply to a single declaration");
                }
            }
        }
    }
    return;

Lnodecl:
    if (decl)
    {
        error("pragma is missing closing ';'");
        goto Ldecl; // do them anyway, to avoid segfaults.
    }
}

const char *PragmaDeclaration::kind()
{
    return "pragma";
}

/********************************* ConditionalDeclaration ****************************/

ConditionalDeclaration::ConditionalDeclaration(Condition *condition, Dsymbols *decl, Dsymbols *elsedecl)
        : AttribDeclaration(decl)
{
    //printf("ConditionalDeclaration::ConditionalDeclaration()\n");
    this->condition = condition;
    this->elsedecl = elsedecl;
}

Dsymbol *ConditionalDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    return new ConditionalDeclaration(condition->syntaxCopy(),
        Dsymbol::arraySyntaxCopy(decl),
        Dsymbol::arraySyntaxCopy(elsedecl));
}

bool ConditionalDeclaration::oneMember(Dsymbol **ps, Identifier *ident)
{
    //printf("ConditionalDeclaration::oneMember(), inc = %d\n", condition->inc);
    if (condition->inc)
    {
        Dsymbols *d = condition->include(NULL, NULL) ? decl : elsedecl;
        return Dsymbol::oneMembers(d, ps, ident);
    }
    else
    {
        bool res = (Dsymbol::oneMembers(    decl, ps, ident) && *ps == NULL &&
                    Dsymbol::oneMembers(elsedecl, ps, ident) && *ps == NULL);
        *ps = NULL;
        return res;
    }
}

// Decide if 'then' or 'else' code should be included

Dsymbols *ConditionalDeclaration::include(Scope *sc, ScopeDsymbol *sds)
{
    //printf("ConditionalDeclaration::include(sc = %p) scope = %p\n", sc, scope);
    assert(condition);
    return condition->include(scope ? scope : sc, sds) ? decl : elsedecl;
}

void ConditionalDeclaration::setScope(Scope *sc)
{
    Dsymbols *d = include(sc, NULL);

    //printf("\tConditionalDeclaration::setScope '%s', d = %p\n",toChars(), d);
    if (d)
    {
       for (size_t i = 0; i < d->dim; i++)
       {
           Dsymbol *s = (*d)[i];
           s->setScope(sc);
       }
    }
}

void ConditionalDeclaration::addComment(const utf8_t *comment)
{
    /* Because addComment is called by the parser, if we called
     * include() it would define a version before it was used.
     * But it's no problem to drill down to both decl and elsedecl,
     * so that's the workaround.
     */

    if (comment)
    {
        Dsymbols *d = decl;

        for (int j = 0; j < 2; j++)
        {
            if (d)
            {
                for (size_t i = 0; i < d->dim; i++)
                {
                    Dsymbol *s = (*d)[i];
                    //printf("ConditionalDeclaration::addComment %s\n", s->toChars());
                    s->addComment(comment);
                }
            }
            d = elsedecl;
        }
    }
}

/***************************** StaticIfDeclaration ****************************/

StaticIfDeclaration::StaticIfDeclaration(Condition *condition,
        Dsymbols *decl, Dsymbols *elsedecl)
        : ConditionalDeclaration(condition, decl, elsedecl)
{
    //printf("StaticIfDeclaration::StaticIfDeclaration()\n");
    sds = NULL;
    addisdone = 0;
}

Dsymbol *StaticIfDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    return new StaticIfDeclaration(condition->syntaxCopy(),
        Dsymbol::arraySyntaxCopy(decl),
        Dsymbol::arraySyntaxCopy(elsedecl));
}

Dsymbols *StaticIfDeclaration::include(Scope *sc, ScopeDsymbol *sds)
{
    //printf("StaticIfDeclaration::include(sc = %p) scope = %p\n", sc, scope);

    if (condition->inc == 0)
    {
        /* Bugzilla 10101: Condition evaluation may cause self-recursive
         * condition evaluation. To resolve it, temporarily save sc into scope.
         */
        bool x = !scope && sc;
        if (x) scope = sc;
        Dsymbols *d = ConditionalDeclaration::include(sc, sds);
        if (x) scope = NULL;

        // Set the scopes lazily.
        if (scope && d)
        {
           for (size_t i = 0; i < d->dim; i++)
           {
               Dsymbol *s = (*d)[i];

               s->setScope(scope);
           }
        }
        return d;
    }
    else
    {
        return ConditionalDeclaration::include(sc, sds);
    }
}

int StaticIfDeclaration::addMember(Scope *sc, ScopeDsymbol *sds, int memnum)
{
    //printf("StaticIfDeclaration::addMember() '%s'\n",toChars());
    /* This is deferred until semantic(), so that
     * expressions in the condition can refer to declarations
     * in the same scope, such as:
     *
     * template Foo(int i)
     * {
     *     const int j = i + 1;
     *     static if (j == 3)
     *         const int k;
     * }
     */
    this->sds = sds;
    int m = 0;

    if (0 && memnum == 0)
    {
        m = AttribDeclaration::addMember(sc, sds, memnum);
        addisdone = 1;
    }
    return m;
}

void StaticIfDeclaration::importAll(Scope *sc)
{
    // do not evaluate condition before semantic pass
}

void StaticIfDeclaration::setScope(Scope *sc)
{
    // do not evaluate condition before semantic pass

    // But do set the scope, in case we need it for forward referencing
    Dsymbol::setScope(sc);
}

void StaticIfDeclaration::semantic(Scope *sc)
{
    Dsymbols *d = include(sc, sds);

    //printf("\tStaticIfDeclaration::semantic '%s', d = %p\n",toChars(), d);
    if (d)
    {
        if (!addisdone)
        {
            AttribDeclaration::addMember(sc, sds, 1);
            addisdone = 1;
        }

        for (size_t i = 0; i < d->dim; i++)
        {
            Dsymbol *s = (*d)[i];
            s->semantic(sc);
        }
    }
}

const char *StaticIfDeclaration::kind()
{
    return "static if";
}

/***************************** CompileDeclaration *****************************/

// These are mixin declarations, like mixin("int x");

CompileDeclaration::CompileDeclaration(Loc loc, Expression *exp)
    : AttribDeclaration(NULL)
{
    //printf("CompileDeclaration(loc = %d)\n", loc.linnum);
    this->loc = loc;
    this->exp = exp;
    this->sds = NULL;
    this->compiled = 0;
}

Dsymbol *CompileDeclaration::syntaxCopy(Dsymbol *s)
{
    //printf("CompileDeclaration::syntaxCopy('%s')\n", toChars());
    return new CompileDeclaration(loc, exp->syntaxCopy());
}

int CompileDeclaration::addMember(Scope *sc, ScopeDsymbol *sds, int memnum)
{
    //printf("CompileDeclaration::addMember(sc = %p, sds = %p, memnum = %d)\n", sc, sds, memnum);
    if (compiled)
        return 1;

    this->sds = sds;
    if (memnum == 0)
    {
        /* No members yet, so parse the mixin now
         */
        compileIt(sc);
        memnum |= AttribDeclaration::addMember(sc, sds, memnum);
        compiled = 1;
    }
    return memnum;
}

void CompileDeclaration::setScope(Scope *sc)
{
    Dsymbol::setScope(sc);
}

void CompileDeclaration::compileIt(Scope *sc)
{
    //printf("CompileDeclaration::compileIt(loc = %d) %s\n", loc.linnum, exp->toChars());
    sc = sc->startCTFE();
    exp = exp->semantic(sc);
    exp = resolveProperties(sc, exp);
    sc = sc->endCTFE();

    if (exp->op != TOKerror)
    {
        Expression *e = exp->ctfeInterpret();
        StringExp *se = e->toStringExp();
        if (!se)
            exp->error("argument to mixin must be a string, not (%s) of type %s", exp->toChars(), exp->type->toChars());
        else
        {
            se = se->toUTF8(sc);
            unsigned errors = global.errors;
            Parser p(loc, sc->module, (utf8_t *)se->string, se->len, 0);
            p.nextToken();

            decl = p.parseDeclDefs(0);
            if (p.token.value != TOKeof)
                exp->error("incomplete mixin declaration (%s)", se->toChars());
            if (p.errors)
            {
                assert(global.errors != errors);
                decl = NULL;
            }
        }
    }
}

void CompileDeclaration::semantic(Scope *sc)
{
    //printf("CompileDeclaration::semantic()\n");

    if (!compiled)
    {
        compileIt(sc);
        AttribDeclaration::addMember(sc, sds, 0);
        compiled = 1;

        if (scope && decl)
        {
            for (size_t i = 0; i < decl->dim; i++)
            {
                Dsymbol *s = (*decl)[i];
                s->setScope(scope);
            }
        }
    }
    AttribDeclaration::semantic(sc);
}

const char *CompileDeclaration::kind()
{
    return "mixin";
}

/***************************** UserAttributeDeclaration *****************************/

UserAttributeDeclaration::UserAttributeDeclaration(Expressions *atts, Dsymbols *decl)
        : AttribDeclaration(decl)
{
    //printf("UserAttributeDeclaration()\n");
    this->atts = atts;
}

Dsymbol *UserAttributeDeclaration::syntaxCopy(Dsymbol *s)
{
    //printf("UserAttributeDeclaration::syntaxCopy('%s')\n", toChars());
    assert(!s);
    return new UserAttributeDeclaration(
        Expression::arraySyntaxCopy(this->atts),
        Dsymbol::arraySyntaxCopy(decl));
}

Scope *UserAttributeDeclaration::newScope(Scope *sc)
{
    Scope *sc2 = sc;
    if (atts && atts->dim)
    {
        // create new one for changes
        sc2 = sc->copy();
        sc2->userAttribDecl = this;
    }
    return sc2;
}

void UserAttributeDeclaration::setScope(Scope *sc)
{
    //printf("UserAttributeDeclaration::setScope() %p\n", this);
    if (decl)
        Dsymbol::setScope(sc);  // for forward reference of UDAs

    return AttribDeclaration::setScope(sc);
}

void UserAttributeDeclaration::semantic(Scope *sc)
{
    //printf("UserAttributeDeclaration::semantic() %p\n", this);
    if (decl && !scope)
        Dsymbol::setScope(sc);  // for function local symbols

    return AttribDeclaration::semantic(sc);
}

void UserAttributeDeclaration::semantic2(Scope *sc)
{
    if (decl && atts && atts->dim)
    {
        if (atts && atts->dim && scope)
        {
            scope = NULL;
            arrayExpressionSemantic(atts, sc);  // run semantic
        }
    }

    AttribDeclaration::semantic2(sc);
}

Expressions *UserAttributeDeclaration::concat(Expressions *udas1, Expressions *udas2)
{
    Expressions *udas;
    if (!udas1 || udas1->dim == 0)
        udas = udas2;
    else if (!udas2 || udas2->dim == 0)
        udas = udas1;
    else
    {
        /* Create a new tuple that combines them
         * (do not append to left operand, as this is a copy-on-write operation)
         */
        udas = new Expressions();
        udas->push(new TupleExp(Loc(), udas1));
        udas->push(new TupleExp(Loc(), udas2));
    }
    return udas;
}

Expressions *UserAttributeDeclaration::getAttributes()
{
    if (scope)
    {
        Scope *sc = scope;
        scope = NULL;
        arrayExpressionSemantic(atts, sc);
    }

    Expressions *exps = new Expressions();
    if (userAttribDecl)
        exps->push(new TupleExp(Loc(), userAttribDecl->getAttributes()));
    if (atts && atts->dim)
        exps->push(new TupleExp(Loc(), atts));

    return exps;
}

const char *UserAttributeDeclaration::kind()
{
    return "UserAttribute";
}
