
// Compiler implementation of the D programming language
// Copyright (c) 1999-2011 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

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
#if TARGET_NET
 #include "frontend.net/pragma.h"
#endif

extern void obj_includelib(const char *name);
void obj_startaddress(Symbol *s);


/********************************* AttribDeclaration ****************************/

AttribDeclaration::AttribDeclaration(Dsymbols *decl)
        : Dsymbol()
{
    this->decl = decl;
}

Dsymbols *AttribDeclaration::include(Scope *sc, ScopeDsymbol *sd)
{
    return decl;
}

int AttribDeclaration::addMember(Scope *sc, ScopeDsymbol *sd, int memnum)
{
    int m = 0;
    Dsymbols *d = include(sc, sd);

    if (d)
    {
        for (unsigned i = 0; i < d->dim; i++)
        {   Dsymbol *s = d->tdata()[i];
            //printf("\taddMember %s to %s\n", s->toChars(), sd->toChars());
            m |= s->addMember(sc, sd, m | memnum);
        }
    }
    return m;
}

void AttribDeclaration::setScopeNewSc(Scope *sc,
        StorageClass stc, enum LINK linkage, enum PROT protection, int explicitProtection,
        unsigned structalign)
{
    if (decl)
    {
        Scope *newsc = sc;
        if (stc != sc->stc ||
            linkage != sc->linkage ||
            protection != sc->protection ||
            explicitProtection != sc->explicitProtection ||
            structalign != sc->structalign)
        {
            // create new one for changes
            newsc = new Scope(*sc);
            newsc->flags &= ~SCOPEfree;
            newsc->stc = stc;
            newsc->linkage = linkage;
            newsc->protection = protection;
            newsc->explicitProtection = explicitProtection;
            newsc->structalign = structalign;
        }
        for (unsigned i = 0; i < decl->dim; i++)
        {   Dsymbol *s = decl->tdata()[i];

            s->setScope(newsc); // yes, the only difference from semanticNewSc()
        }
        if (newsc != sc)
        {
            sc->offset = newsc->offset;
            newsc->pop();
        }
    }
}

void AttribDeclaration::semanticNewSc(Scope *sc,
        StorageClass stc, enum LINK linkage, enum PROT protection, int explicitProtection,
        unsigned structalign)
{
    if (decl)
    {
        Scope *newsc = sc;
        if (stc != sc->stc ||
            linkage != sc->linkage ||
            protection != sc->protection ||
            explicitProtection != sc->explicitProtection ||
            structalign != sc->structalign)
        {
            // create new one for changes
            newsc = new Scope(*sc);
            newsc->flags &= ~SCOPEfree;
            newsc->stc = stc;
            newsc->linkage = linkage;
            newsc->protection = protection;
            newsc->explicitProtection = explicitProtection;
            newsc->structalign = structalign;
        }
        for (unsigned i = 0; i < decl->dim; i++)
        {   Dsymbol *s = decl->tdata()[i];

            s->semantic(newsc);
        }
        if (newsc != sc)
        {
            sc->offset = newsc->offset;
            newsc->pop();
        }
    }
}

void AttribDeclaration::semantic(Scope *sc)
{
    Dsymbols *d = include(sc, NULL);

    //printf("\tAttribDeclaration::semantic '%s', d = %p\n",toChars(), d);
    if (d)
    {
        for (unsigned i = 0; i < d->dim; i++)
        {
            Dsymbol *s = d->tdata()[i];

            s->semantic(sc);
        }
    }
}

void AttribDeclaration::semantic2(Scope *sc)
{
    Dsymbols *d = include(sc, NULL);

    if (d)
    {
        for (unsigned i = 0; i < d->dim; i++)
        {   Dsymbol *s = d->tdata()[i];
            s->semantic2(sc);
        }
    }
}

void AttribDeclaration::semantic3(Scope *sc)
{
    Dsymbols *d = include(sc, NULL);

    if (d)
    {
        for (unsigned i = 0; i < d->dim; i++)
        {   Dsymbol *s = d->tdata()[i];
            s->semantic3(sc);
        }
    }
}

void AttribDeclaration::inlineScan()
{
    Dsymbols *d = include(NULL, NULL);

    if (d)
    {
        for (unsigned i = 0; i < d->dim; i++)
        {   Dsymbol *s = d->tdata()[i];
            //printf("AttribDeclaration::inlineScan %s\n", s->toChars());
            s->inlineScan();
        }
    }
}

void AttribDeclaration::addComment(unsigned char *comment)
{
    //printf("AttribDeclaration::addComment %s\n", comment);
    if (comment)
    {
        Dsymbols *d = include(NULL, NULL);

        if (d)
        {
            for (unsigned i = 0; i < d->dim; i++)
            {   Dsymbol *s = d->tdata()[i];
                //printf("AttribDeclaration::addComment %s\n", s->toChars());
                s->addComment(comment);
            }
        }
    }
}

void AttribDeclaration::emitComment(Scope *sc)
{
    //printf("AttribDeclaration::emitComment(sc = %p)\n", sc);

    /* A general problem with this, illustrated by BUGZILLA 2516,
     * is that attributes are not transmitted through to the underlying
     * member declarations for template bodies, because semantic analysis
     * is not done for template declaration bodies
     * (only template instantiations).
     * Hence, Ddoc omits attributes from template members.
     */

    Dsymbols *d = include(NULL, NULL);

    if (d)
    {
        for (unsigned i = 0; i < d->dim; i++)
        {   Dsymbol *s = d->tdata()[i];
            //printf("AttribDeclaration::emitComment %s\n", s->toChars());
            s->emitComment(sc);
        }
    }
}

void AttribDeclaration::toObjFile(int multiobj)
{
    Dsymbols *d = include(NULL, NULL);

    if (d)
    {
        for (unsigned i = 0; i < d->dim; i++)
        {   Dsymbol *s = d->tdata()[i];
            s->toObjFile(multiobj);
        }
    }
}

int AttribDeclaration::cvMember(unsigned char *p)
{
    int nwritten = 0;
    int n;
    Dsymbols *d = include(NULL, NULL);

    if (d)
    {
        for (unsigned i = 0; i < d->dim; i++)
        {   Dsymbol *s = d->tdata()[i];
            n = s->cvMember(p);
            if (p)
                p += n;
            nwritten += n;
        }
    }
    return nwritten;
}

int AttribDeclaration::hasPointers()
{
    Dsymbols *d = include(NULL, NULL);

    if (d)
    {
        for (size_t i = 0; i < d->dim; i++)
        {
            Dsymbol *s = d->tdata()[i];
            if (s->hasPointers())
                return 1;
        }
    }
    return 0;
}

const char *AttribDeclaration::kind()
{
    return "attribute";
}

int AttribDeclaration::oneMember(Dsymbol **ps)
{
    Dsymbols *d = include(NULL, NULL);

    return Dsymbol::oneMembers(d, ps);
}

void AttribDeclaration::checkCtorConstInit()
{
    Dsymbols *d = include(NULL, NULL);

    if (d)
    {
        for (unsigned i = 0; i < d->dim; i++)
        {   Dsymbol *s = d->tdata()[i];
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
        for (unsigned i = 0; i < d->dim; i++)
        {   Dsymbol *s = d->tdata()[i];
            s->addLocalClass(aclasses);
        }
    }
}


void AttribDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    if (decl)
    {
        if (decl->dim == 0)
            buf->writestring("{}");
        else if (decl->dim == 1)
            (decl->tdata()[0])->toCBuffer(buf, hgs);
        else
        {
            buf->writenl();
            buf->writeByte('{');
            buf->writenl();
            for (unsigned i = 0; i < decl->dim; i++)
            {
                Dsymbol *s = decl->tdata()[i];

                buf->writestring("    ");
                s->toCBuffer(buf, hgs);
            }
            buf->writeByte('}');
        }
    }
    else
        buf->writeByte(';');
    buf->writenl();
}

/************************* StorageClassDeclaration ****************************/

StorageClassDeclaration::StorageClassDeclaration(StorageClass stc, Dsymbols *decl)
        : AttribDeclaration(decl)
{
    this->stc = stc;
}

Dsymbol *StorageClassDeclaration::syntaxCopy(Dsymbol *s)
{
    StorageClassDeclaration *scd;

    assert(!s);
    scd = new StorageClassDeclaration(stc, Dsymbol::arraySyntaxCopy(decl));
    return scd;
}

void StorageClassDeclaration::setScope(Scope *sc)
{
    if (decl)
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

        setScopeNewSc(sc, scstc, sc->linkage, sc->protection, sc->explicitProtection, sc->structalign);
    }
}

void StorageClassDeclaration::semantic(Scope *sc)
{
    if (decl)
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

        semanticNewSc(sc, scstc, sc->linkage, sc->protection, sc->explicitProtection, sc->structalign);
    }
}

void StorageClassDeclaration::stcToCBuffer(OutBuffer *buf, StorageClass stc)
{
    struct SCstring
    {
        StorageClass stc;
        enum TOK tok;
        Identifier *id;
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
#if DMDV2
        { STCmanifest,     TOKenum },
        { STCimmutable,    TOKimmutable },
        { STCshared,       TOKshared },
        { STCnothrow,      TOKnothrow },
        { STCpure,         TOKpure },
        { STCref,          TOKref },
        { STCtls,          TOKtls },
        { STCgshared,      TOKgshared },
        { STCproperty,     TOKat,       Id::property },
        { STCsafe,         TOKat,       Id::safe },
        { STCtrusted,      TOKat,       Id::trusted },
        { STCsystem,       TOKat,       Id::system },
        { STCdisable,      TOKat,       Id::disable },
#endif
    };

    for (int i = 0; i < sizeof(table)/sizeof(table[0]); i++)
    {
        if (stc & table[i].stc)
        {
            enum TOK tok = table[i].tok;
#if DMDV2
            if (tok == TOKat)
            {
                buf->writeByte('@');
                buf->writestring(table[i].id->toChars());
            }
            else
#endif
                buf->writestring(Token::toChars(tok));
            buf->writeByte(' ');
        }
    }
}

void StorageClassDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    stcToCBuffer(buf, stc);
    AttribDeclaration::toCBuffer(buf, hgs);
}

/********************************* LinkDeclaration ****************************/

LinkDeclaration::LinkDeclaration(enum LINK p, Dsymbols *decl)
        : AttribDeclaration(decl)
{
    //printf("LinkDeclaration(linkage = %d, decl = %p)\n", p, decl);
    linkage = p;
}

Dsymbol *LinkDeclaration::syntaxCopy(Dsymbol *s)
{
    LinkDeclaration *ld;

    assert(!s);
    ld = new LinkDeclaration(linkage, Dsymbol::arraySyntaxCopy(decl));
    return ld;
}

void LinkDeclaration::setScope(Scope *sc)
{
    //printf("LinkDeclaration::setScope(linkage = %d, decl = %p)\n", linkage, decl);
    if (decl)
    {
        setScopeNewSc(sc, sc->stc, linkage, sc->protection, sc->explicitProtection, sc->structalign);
    }
}

void LinkDeclaration::semantic(Scope *sc)
{
    //printf("LinkDeclaration::semantic(linkage = %d, decl = %p)\n", linkage, decl);
    if (decl)
    {
        semanticNewSc(sc, sc->stc, linkage, sc->protection, sc->explicitProtection, sc->structalign);
    }
}

void LinkDeclaration::semantic3(Scope *sc)
{
    //printf("LinkDeclaration::semantic3(linkage = %d, decl = %p)\n", linkage, decl);
    if (decl)
    {   enum LINK linkage_save = sc->linkage;

        sc->linkage = linkage;
        for (unsigned i = 0; i < decl->dim; i++)
        {
            Dsymbol *s = decl->tdata()[i];

            s->semantic3(sc);
        }
        sc->linkage = linkage_save;
    }
    else
    {
        sc->linkage = linkage;
    }
}

void LinkDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{   const char *p;

    switch (linkage)
    {
        case LINKd:             p = "D";                break;
        case LINKc:             p = "C";                break;
        case LINKcpp:           p = "C++";              break;
        case LINKwindows:       p = "Windows";          break;
        case LINKpascal:        p = "Pascal";           break;
        default:
            assert(0);
            break;
    }
    buf->writestring("extern (");
    buf->writestring(p);
    buf->writestring(") ");
    AttribDeclaration::toCBuffer(buf, hgs);
}

char *LinkDeclaration::toChars()
{
    return (char *)"extern ()";
}

/********************************* ProtDeclaration ****************************/

ProtDeclaration::ProtDeclaration(enum PROT p, Dsymbols *decl)
        : AttribDeclaration(decl)
{
    protection = p;
    //printf("decl = %p\n", decl);
}

Dsymbol *ProtDeclaration::syntaxCopy(Dsymbol *s)
{
    ProtDeclaration *pd;

    assert(!s);
    pd = new ProtDeclaration(protection, Dsymbol::arraySyntaxCopy(decl));
    return pd;
}

void ProtDeclaration::setScope(Scope *sc)
{
    if (decl)
    {
        setScopeNewSc(sc, sc->stc, sc->linkage, protection, 1, sc->structalign);
    }
}

void ProtDeclaration::importAll(Scope *sc)
{
    Scope *newsc = sc;
    if (sc->protection != protection ||
       sc->explicitProtection != 1)
    {
       // create new one for changes
       newsc = new Scope(*sc);
       newsc->flags &= ~SCOPEfree;
       newsc->protection = protection;
       newsc->explicitProtection = 1;
    }

    for (size_t i = 0; i < decl->dim; i++)
    {
       Dsymbol *s = (*decl)[i];
       s->importAll(newsc);
    }

    if (newsc != sc)
       newsc->pop();
}

void ProtDeclaration::semantic(Scope *sc)
{
    if (decl)
    {
        semanticNewSc(sc, sc->stc, sc->linkage, protection, 1, sc->structalign);
    }
}

void ProtDeclaration::protectionToCBuffer(OutBuffer *buf, enum PROT protection)
{
    const char *p;

    switch (protection)
    {
        case PROTprivate:       p = "private";          break;
        case PROTpackage:       p = "package";          break;
        case PROTprotected:     p = "protected";        break;
        case PROTpublic:        p = "public";           break;
        case PROTexport:        p = "export";           break;
        default:
            assert(0);
            break;
    }
    buf->writestring(p);
    buf->writeByte(' ');
}

void ProtDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    protectionToCBuffer(buf, protection);
    AttribDeclaration::toCBuffer(buf, hgs);
}

/********************************* AlignDeclaration ****************************/

AlignDeclaration::AlignDeclaration(unsigned sa, Dsymbols *decl)
        : AttribDeclaration(decl)
{
    salign = sa;
}

Dsymbol *AlignDeclaration::syntaxCopy(Dsymbol *s)
{
    AlignDeclaration *ad;

    assert(!s);
    ad = new AlignDeclaration(salign, Dsymbol::arraySyntaxCopy(decl));
    return ad;
}

void AlignDeclaration::setScope(Scope *sc)
{
    //printf("\tAlignDeclaration::setScope '%s'\n",toChars());
    if (decl)
    {
        setScopeNewSc(sc, sc->stc, sc->linkage, sc->protection, sc->explicitProtection, salign);
    }
}

void AlignDeclaration::semantic(Scope *sc)
{
    //printf("\tAlignDeclaration::semantic '%s'\n",toChars());
    if (decl)
    {
        semanticNewSc(sc, sc->stc, sc->linkage, sc->protection, sc->explicitProtection, salign);
    }
}


void AlignDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->printf("align (%d)", salign);
    AttribDeclaration::toCBuffer(buf, hgs);
}

/********************************* AnonDeclaration ****************************/

AnonDeclaration::AnonDeclaration(Loc loc, int isunion, Dsymbols *decl)
        : AttribDeclaration(decl)
{
    this->loc = loc;
    this->isunion = isunion;
    this->sem = 0;
}

Dsymbol *AnonDeclaration::syntaxCopy(Dsymbol *s)
{
    AnonDeclaration *ad;

    assert(!s);
    ad = new AnonDeclaration(loc, isunion, Dsymbol::arraySyntaxCopy(decl));
    return ad;
}

void AnonDeclaration::semantic(Scope *sc)
{
    //printf("\tAnonDeclaration::semantic %s %p\n", isunion ? "union" : "struct", this);

    if (sem == 1)
    {   //printf("already completed\n");
        scope = NULL;
        return;             // semantic() already completed
    }

    Scope *scx = NULL;
    if (scope)
    {   sc = scope;
        scx = scope;
        scope = NULL;
    }

    unsigned dprogress_save = Module::dprogress;

    assert(sc->parent);

    Dsymbol *parent = sc->parent->pastMixin();
    AggregateDeclaration *ad = parent->isAggregateDeclaration();

    if (!ad || (!ad->isStructDeclaration() && !ad->isClassDeclaration()))
    {
        error("can only be a part of an aggregate");
        return;
    }

    if (decl)
    {
        AnonymousAggregateDeclaration aad;
        int adisunion;

        if (sc->anonAgg)
        {   ad = sc->anonAgg;
            adisunion = sc->inunion;
        }
        else
            adisunion = ad->isUnionDeclaration() != NULL;

//      printf("\tsc->anonAgg = %p\n", sc->anonAgg);
//      printf("\tad  = %p\n", ad);
//      printf("\taad = %p\n", &aad);

        sc = sc->push();
        sc->anonAgg = &aad;
        sc->stc &= ~(STCauto | STCscope | STCstatic | STCtls | STCgshared);
        sc->inunion = isunion;
        sc->offset = 0;
        sc->flags = 0;
        aad.structalign = sc->structalign;
        aad.parent = ad;

        for (unsigned i = 0; i < decl->dim; i++)
        {
            Dsymbol *s = decl->tdata()[i];

            s->semantic(sc);
            if (isunion)
                sc->offset = 0;
            if (aad.sizeok == 2)
            {
                break;
            }
        }
        sc = sc->pop();

        // If failed due to forward references, unwind and try again later
        if (aad.sizeok == 2)
        {
            ad->sizeok = 2;
            //printf("\tsetting ad->sizeok %p to 2\n", ad);
            if (!sc->anonAgg)
            {
                scope = scx ? scx : new Scope(*sc);
                scope->setNoFree();
                scope->module->addDeferredSemantic(this);
            }
            Module::dprogress = dprogress_save;
            //printf("\tforward reference %p\n", this);
            return;
        }
        if (sem == 0)
        {   Module::dprogress++;
            sem = 1;
            //printf("\tcompleted %p\n", this);
        }
        else
            ;//printf("\talready completed %p\n", this);

        // 0 sized structs are set to 1 byte
        if (aad.structsize == 0)
        {
            aad.structsize = 1;
            aad.alignsize = 1;
        }

        // Align size of anonymous aggregate
//printf("aad.structalign = %d, aad.alignsize = %d, sc->offset = %d\n", aad.structalign, aad.alignsize, sc->offset);
        ad->alignmember(aad.structalign, aad.alignsize, &sc->offset);
        //ad->structsize = sc->offset;
//printf("sc->offset = %d\n", sc->offset);

        // Add members of aad to ad
        //printf("\tadding members of aad to '%s'\n", ad->toChars());
        for (unsigned i = 0; i < aad.fields.dim; i++)
        {
            VarDeclaration *v = aad.fields.tdata()[i];

            v->offset += sc->offset;
            ad->fields.push(v);
        }

        // Add size of aad to ad
        if (adisunion)
        {
            if (aad.structsize > ad->structsize)
                ad->structsize = aad.structsize;
            sc->offset = 0;
        }
        else
        {
            ad->structsize = sc->offset + aad.structsize;
            sc->offset = ad->structsize;
        }

        if (ad->alignsize < aad.alignsize)
            ad->alignsize = aad.alignsize;
    }
}


void AnonDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->printf(isunion ? "union" : "struct");
    buf->writestring("\n{\n");
    if (decl)
    {
        for (unsigned i = 0; i < decl->dim; i++)
        {
            Dsymbol *s = decl->tdata()[i];

            //buf->writestring("    ");
            s->toCBuffer(buf, hgs);
        }
    }
    buf->writestring("}\n");
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
    PragmaDeclaration *pd;

    assert(!s);
    pd = new PragmaDeclaration(loc, ident,
        Expression::arraySyntaxCopy(args), Dsymbol::arraySyntaxCopy(decl));
    return pd;
}

void PragmaDeclaration::setScope(Scope *sc)
{
#if TARGET_NET
    if (ident == Lexer::idPool("assembly"))
    {
        if (!args || args->dim != 1)
        {
            error("pragma has invalid number of arguments");
        }
        else
        {
            Expression *e = args->tdata()[0];
            e = e->semantic(sc);
            e = e->optimize(WANTvalue | WANTinterpret);
            args->tdata()[0] = e;
            StringExp* se = e->toString();
            if (!se)
            {
                error("string expected, not '%s'", e->toChars());
            }
            PragmaScope* pragma = new PragmaScope(this, sc->parent, se);

            assert(sc);
            pragma->setScope(sc);

            //add to module members
            assert(sc->module);
            assert(sc->module->members);
            sc->module->members->push(pragma);
        }
    }
#endif // TARGET_NET
}

void PragmaDeclaration::semantic(Scope *sc)
{   // Should be merged with PragmaStatement

    //printf("\tPragmaDeclaration::semantic '%s'\n",toChars());
    if (ident == Id::msg)
    {
        if (args)
        {
            for (size_t i = 0; i < args->dim; i++)
            {
                Expression *e = args->tdata()[i];

                e = e->semantic(sc);
                e = e->optimize(WANTvalue | WANTinterpret);
                StringExp *se = e->toString();
                if (se)
                {
                    fprintf(stdmsg, "%.*s", (int)se->len, (char *)se->string);
                }
                else
                    fprintf(stdmsg, "%s", e->toChars());
            }
            fprintf(stdmsg, "\n");
        }
        goto Lnodecl;
    }
    else if (ident == Id::lib)
    {
        if (!args || args->dim != 1)
            error("string expected for library name");
        else
        {
            Expression *e = args->tdata()[0];

            e = e->semantic(sc);
            e = e->optimize(WANTvalue | WANTinterpret);
            args->tdata()[0] = e;
            if (e->op == TOKerror)
                goto Lnodecl;
            StringExp *se = e->toString();
            if (!se)
                error("string expected for library name, not '%s'", e->toChars());
            else if (global.params.verbose)
            {
                char *name = (char *)mem.malloc(se->len + 1);
                memcpy(name, se->string, se->len);
                name[se->len] = 0;
                printf("library   %s\n", name);
                mem.free(name);
            }
        }
        goto Lnodecl;
    }
#if IN_GCC
    else if (ident == Id::GNU_asm)
    {
        if (! args || args->dim != 2)
            error("identifier and string expected for asm name");
        else
        {
            Expression *e;
            Declaration *d = NULL;
            StringExp *s = NULL;

            e = args->tdata()[0];
            e = e->semantic(sc);
            if (e->op == TOKvar)
            {
                d = ((VarExp *)e)->var;
                if (! d->isFuncDeclaration() && ! d->isVarDeclaration())
                    d = NULL;
            }
            if (!d)
                error("first argument of GNU_asm must be a function or variable declaration");

            e = args->tdata()[1];
            e = e->semantic(sc);
            e = e->optimize(WANTvalue | WANTinterpret);
            e = e->toString();
            if (e && ((StringExp *)e)->sz == 1)
                s = ((StringExp *)e);
            else
                error("second argument of GNU_asm must be a char string");

            if (d && s)
                d->c_ident = Lexer::idPool((char*) s->string);
        }
        goto Lnodecl;
    }
#endif
#if DMDV2
    else if (ident == Id::startaddress)
    {
        if (!args || args->dim != 1)
            error("function name expected for start address");
        else
        {
            Expression *e = args->tdata()[0];
            e = e->semantic(sc);
            e = e->optimize(WANTvalue | WANTinterpret);
            args->tdata()[0] = e;
            Dsymbol *sa = getDsymbol(e);
            if (!sa || !sa->isFuncDeclaration())
                error("function name expected for start address, not '%s'", e->toChars());
        }
        goto Lnodecl;
    }
#endif
#if TARGET_NET
    else if (ident == Lexer::idPool("assembly"))
    {
    }
#endif // TARGET_NET
    else if (global.params.ignoreUnsupportedPragmas)
    {
        if (global.params.verbose)
        {
            /* Print unrecognized pragmas
             */
            printf("pragma    %s", ident->toChars());
            if (args)
            {
                for (size_t i = 0; i < args->dim; i++)
                {
                    Expression *e = args->tdata()[i];
                    e = e->semantic(sc);
                    e = e->optimize(WANTvalue | WANTinterpret);
                    if (i == 0)
                        printf(" (");
                    else
                        printf(",");
                    printf("%s", e->toChars());
                }
                if (args->dim)
                    printf(")");
            }
            printf("\n");
        }
        goto Lnodecl;
    }
    else
        error("unrecognized pragma(%s)", ident->toChars());

    if (decl)
    {
        for (unsigned i = 0; i < decl->dim; i++)
        {
            Dsymbol *s = decl->tdata()[i];

            s->semantic(sc);
        }
    }
    return;

Lnodecl:
    if (decl)
        error("pragma is missing closing ';'");
}

int PragmaDeclaration::oneMember(Dsymbol **ps)
{
    *ps = NULL;
    return TRUE;
}

const char *PragmaDeclaration::kind()
{
    return "pragma";
}

void PragmaDeclaration::toObjFile(int multiobj)
{
    if (ident == Id::lib)
    {
        assert(args && args->dim == 1);

        Expression *e = args->tdata()[0];

        assert(e->op == TOKstring);

        StringExp *se = (StringExp *)e;
        char *name = (char *)mem.malloc(se->len + 1);
        memcpy(name, se->string, se->len);
        name[se->len] = 0;
#if OMFOBJ
        /* The OMF format allows library names to be inserted
         * into the object file. The linker will then automatically
         * search that library, too.
         */
        obj_includelib(name);
#elif ELFOBJ || MACHOBJ
        /* The format does not allow embedded library names,
         * so instead append the library name to the list to be passed
         * to the linker.
         */
        global.params.libfiles->push(name);
#else
        error("pragma lib not supported");
#endif
    }
#if DMDV2
    else if (ident == Id::startaddress)
    {
        assert(args && args->dim == 1);
        Expression *e = args->tdata()[0];
        Dsymbol *sa = getDsymbol(e);
        FuncDeclaration *f = sa->isFuncDeclaration();
        assert(f);
        Symbol *s = f->toSymbol();
        obj_startaddress(s);
    }
#endif
    AttribDeclaration::toObjFile(multiobj);
}

void PragmaDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->printf("pragma (%s", ident->toChars());
    if (args && args->dim)
    {
        buf->writestring(", ");
        argsToCBuffer(buf, args, hgs);
    }
    buf->writeByte(')');
    AttribDeclaration::toCBuffer(buf, hgs);
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
    ConditionalDeclaration *dd;

    assert(!s);
    dd = new ConditionalDeclaration(condition->syntaxCopy(),
        Dsymbol::arraySyntaxCopy(decl),
        Dsymbol::arraySyntaxCopy(elsedecl));
    return dd;
}


int ConditionalDeclaration::oneMember(Dsymbol **ps)
{
    //printf("ConditionalDeclaration::oneMember(), inc = %d\n", condition->inc);
    if (condition->inc)
    {
        Dsymbols *d = condition->include(NULL, NULL) ? decl : elsedecl;
        return Dsymbol::oneMembers(d, ps);
    }
    *ps = NULL;
    return TRUE;
}

void ConditionalDeclaration::emitComment(Scope *sc)
{
    //printf("ConditionalDeclaration::emitComment(sc = %p)\n", sc);
    if (condition->inc)
    {
        AttribDeclaration::emitComment(sc);
    }
    else if (sc->docbuf)
    {
        /* If generating doc comment, be careful because if we're inside
         * a template, then include(NULL, NULL) will fail.
         */
        Dsymbols *d = decl ? decl : elsedecl;
        for (unsigned i = 0; i < d->dim; i++)
        {   Dsymbol *s = d->tdata()[i];
            s->emitComment(sc);
        }
    }
}

// Decide if 'then' or 'else' code should be included

Dsymbols *ConditionalDeclaration::include(Scope *sc, ScopeDsymbol *sd)
{
    //printf("ConditionalDeclaration::include()\n");
    assert(condition);
    return condition->include(sc, sd) ? decl : elsedecl;
}

void ConditionalDeclaration::setScope(Scope *sc)
{
    Dsymbols *d = include(sc, NULL);

    //printf("\tConditionalDeclaration::setScope '%s', d = %p\n",toChars(), d);
    if (d)
    {
       for (unsigned i = 0; i < d->dim; i++)
       {
           Dsymbol *s = d->tdata()[i];

           s->setScope(sc);
       }
    }
}

void ConditionalDeclaration::importAll(Scope *sc)
{
    Dsymbols *d = include(sc, NULL);

    //printf("\tConditionalDeclaration::importAll '%s', d = %p\n",toChars(), d);
    if (d)
    {
       for (unsigned i = 0; i < d->dim; i++)
       {
           Dsymbol *s = d->tdata()[i];

           s->importAll(sc);
       }
    }
}

void ConditionalDeclaration::addComment(unsigned char *comment)
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
                for (unsigned i = 0; i < d->dim; i++)
                {   Dsymbol *s;

                    s = d->tdata()[i];
                    //printf("ConditionalDeclaration::addComment %s\n", s->toChars());
                    s->addComment(comment);
                }
            }
            d = elsedecl;
        }
    }
}

void ConditionalDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    condition->toCBuffer(buf, hgs);
    if (decl || elsedecl)
    {
        buf->writenl();
        buf->writeByte('{');
        buf->writenl();
        if (decl)
        {
            for (unsigned i = 0; i < decl->dim; i++)
            {
                Dsymbol *s = decl->tdata()[i];

                buf->writestring("    ");
                s->toCBuffer(buf, hgs);
            }
        }
        buf->writeByte('}');
        if (elsedecl)
        {
            buf->writenl();
            buf->writestring("else");
            buf->writenl();
            buf->writeByte('{');
            buf->writenl();
            for (unsigned i = 0; i < elsedecl->dim; i++)
            {
                Dsymbol *s = elsedecl->tdata()[i];

                buf->writestring("    ");
                s->toCBuffer(buf, hgs);
            }
            buf->writeByte('}');
        }
    }
    else
        buf->writeByte(':');
    buf->writenl();
}

/***************************** StaticIfDeclaration ****************************/

StaticIfDeclaration::StaticIfDeclaration(Condition *condition,
        Dsymbols *decl, Dsymbols *elsedecl)
        : ConditionalDeclaration(condition, decl, elsedecl)
{
    //printf("StaticIfDeclaration::StaticIfDeclaration()\n");
    sd = NULL;
    addisdone = 0;
}


Dsymbol *StaticIfDeclaration::syntaxCopy(Dsymbol *s)
{
    StaticIfDeclaration *dd;

    assert(!s);
    dd = new StaticIfDeclaration(condition->syntaxCopy(),
        Dsymbol::arraySyntaxCopy(decl),
        Dsymbol::arraySyntaxCopy(elsedecl));
    return dd;
}


int StaticIfDeclaration::addMember(Scope *sc, ScopeDsymbol *sd, int memnum)
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
    this->sd = sd;
    int m = 0;

    if (memnum == 0)
    {   m = AttribDeclaration::addMember(sc, sd, memnum);
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
}

void StaticIfDeclaration::semantic(Scope *sc)
{
    Dsymbols *d = include(sc, sd);

    //printf("\tStaticIfDeclaration::semantic '%s', d = %p\n",toChars(), d);
    if (d)
    {
        if (!addisdone)
        {   AttribDeclaration::addMember(sc, sd, 1);
            addisdone = 1;
        }

        for (unsigned i = 0; i < d->dim; i++)
        {
            Dsymbol *s = d->tdata()[i];

            s->semantic(sc);
        }
    }
}

const char *StaticIfDeclaration::kind()
{
    return "static if";
}


/***************************** CompileDeclaration *****************************/

CompileDeclaration::CompileDeclaration(Loc loc, Expression *exp)
    : AttribDeclaration(NULL)
{
    //printf("CompileDeclaration(loc = %d)\n", loc.linnum);
    this->loc = loc;
    this->exp = exp;
    this->sd = NULL;
    this->compiled = 0;
}

Dsymbol *CompileDeclaration::syntaxCopy(Dsymbol *s)
{
    //printf("CompileDeclaration::syntaxCopy('%s')\n", toChars());
    CompileDeclaration *sc = new CompileDeclaration(loc, exp->syntaxCopy());
    return sc;
}

int CompileDeclaration::addMember(Scope *sc, ScopeDsymbol *sd, int memnum)
{
    //printf("CompileDeclaration::addMember(sc = %p, sd = %p, memnum = %d)\n", sc, sd, memnum);
    this->sd = sd;
    if (memnum == 0)
    {   /* No members yet, so parse the mixin now
         */
        compileIt(sc);
        memnum |= AttribDeclaration::addMember(sc, sd, memnum);
        compiled = 1;
    }
    return memnum;
}

void CompileDeclaration::compileIt(Scope *sc)
{
    //printf("CompileDeclaration::compileIt(loc = %d) %s\n", loc.linnum, exp->toChars());
    exp = exp->semantic(sc);
    exp = resolveProperties(sc, exp);
    exp = exp->optimize(WANTvalue | WANTinterpret);
    StringExp *se = exp->toString();
    if (!se)
    {   exp->error("argument to mixin must be a string, not (%s)", exp->toChars());
    }
    else
    {
        se = se->toUTF8(sc);
        Parser p(sc->module, (unsigned char *)se->string, se->len, 0);
        p.loc = loc;
        p.nextToken();
        decl = p.parseDeclDefs(0);
        if (p.token.value != TOKeof)
            exp->error("incomplete mixin declaration (%s)", se->toChars());
    }
}

void CompileDeclaration::semantic(Scope *sc)
{
    //printf("CompileDeclaration::semantic()\n");

    if (!compiled)
    {
        compileIt(sc);
        AttribDeclaration::addMember(sc, sd, 0);
        compiled = 1;
    }
    AttribDeclaration::semantic(sc);
}

void CompileDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("mixin(");
    exp->toCBuffer(buf, hgs);
    buf->writestring(");");
    buf->writenl();
}
