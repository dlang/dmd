
// Compiler implementation of the D programming language
// Copyright (c) 1999-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

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

int AttribDeclaration::apply(Dsymbol_apply_ft_t fp, void *param)
{
    Dsymbols *d = include(scope, NULL);

    if (d)
    {
        for (size_t i = 0; i < d->dim; i++)
        {   Dsymbol *s = (*d)[i];
            if (s)
            {
                if (s->apply(fp, param))
                    return 1;
            }
        }
    }
    return 0;
}

int AttribDeclaration::addMember(Scope *sc, ScopeDsymbol *sd, int memnum)
{
    int m = 0;
    Dsymbols *d = include(sc, sd);

    if (d)
    {
        for (size_t i = 0; i < d->dim; i++)
        {   Dsymbol *s = (*d)[i];
            //printf("\taddMember %s to %s\n", s->toChars(), sd->toChars());
            m |= s->addMember(sc, sd, m | memnum);
        }
    }
    return m;
}

void AttribDeclaration::setScopeNewSc(Scope *sc,
        StorageClass stc, enum LINK linkage, enum PROT protection, int explicitProtection,
        structalign_t structalign)
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
        for (size_t i = 0; i < decl->dim; i++)
        {   Dsymbol *s = (*decl)[i];

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
        structalign_t structalign)
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
        for (size_t i = 0; i < decl->dim; i++)
        {   Dsymbol *s = (*decl)[i];

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
        for (size_t i = 0; i < d->dim; i++)
        {
            Dsymbol *s = (*d)[i];

            s->semantic(sc);
        }
    }
}

void AttribDeclaration::semantic2(Scope *sc)
{
    Dsymbols *d = include(sc, NULL);

    if (d)
    {
        for (size_t i = 0; i < d->dim; i++)
        {   Dsymbol *s = (*d)[i];
            s->semantic2(sc);
        }
    }
}

void AttribDeclaration::semantic3(Scope *sc)
{
    Dsymbols *d = include(sc, NULL);

    if (d)
    {
        for (size_t i = 0; i < d->dim; i++)
        {   Dsymbol *s = (*d)[i];
            s->semantic3(sc);
        }
    }
}

void AttribDeclaration::inlineScan()
{
    Dsymbols *d = include(NULL, NULL);

    if (d)
    {
        for (size_t i = 0; i < d->dim; i++)
        {   Dsymbol *s = (*d)[i];
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
            for (size_t i = 0; i < d->dim; i++)
            {   Dsymbol *s = (*d)[i];
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
        for (size_t i = 0; i < d->dim; i++)
        {   Dsymbol *s = (*d)[i];
            //printf("AttribDeclaration::emitComment %s\n", s->toChars());
            s->emitComment(sc);
        }
    }
}

void AttribDeclaration::setFieldOffset(AggregateDeclaration *ad, unsigned *poffset, bool isunion)
{
    Dsymbols *d = include(NULL, NULL);

    if (d)
    {
        for (size_t i = 0; i < d->dim; i++)
        {   Dsymbol *s = (*d)[i];
            s->setFieldOffset(ad, poffset, isunion);
        }
    }
}

int AttribDeclaration::hasPointers()
{
    Dsymbols *d = include(NULL, NULL);

    if (d)
    {
        for (size_t i = 0; i < d->dim; i++)
        {
            Dsymbol *s = (*d)[i];
            if (s->hasPointers())
                return 1;
        }
    }
    return 0;
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
                return TRUE;
        }
    }
    return FALSE;
}

const char *AttribDeclaration::kind()
{
    return "attribute";
}

int AttribDeclaration::oneMember(Dsymbol **ps, Identifier *ident)
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
        {   Dsymbol *s = (*d)[i];
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
        {   Dsymbol *s = (*d)[i];
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
            ((*decl)[0])->toCBuffer(buf, hgs);
        else
        {
            buf->writenl();
            buf->writeByte('{');
            buf->writenl();
            buf->level++;
            for (size_t i = 0; i < decl->dim; i++)
            {
                Dsymbol *s = (*decl)[i];
                s->toCBuffer(buf, hgs);
            }
            buf->level--;
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

int StorageClassDeclaration::oneMember(Dsymbol **ps, Identifier *ident)
{

    int t = Dsymbol::oneMembers(decl, ps, ident);
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
        //printf("scstc = x%llx\n", scstc);

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
        { STCtls },
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
        StorageClass tbl = table[i].stc;
        assert(tbl & STCStorageClass);
        if (stc & tbl)
        {
            stc &= ~tbl;
            if (tbl == STCtls)  // TOKtls was removed
                return "__thread";

            enum TOK tok = table[i].tok;
#if DMDV2
            if (tok == TOKat)
            {
                tmp[0] = '@';
                strcpy(tmp + 1, table[i].id->toChars());
                return tmp;
            }
            else
#endif
                return Token::toChars(tok);
        }
    }
    //printf("stc = %llx\n", (unsigned long long)stc);
    return NULL;
}

void StorageClassDeclaration::stcToCBuffer(OutBuffer *buf, StorageClass stc)
{
    while (stc)
    {   char tmp[20];
        const char *p = stcToChars(tmp, stc);
        if (!p)
            break;
        assert(strlen(p) < sizeof(tmp) / sizeof(tmp[0]));
        buf->writestring(p);
        buf->writeByte(' ');
    }
}

void StorageClassDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    stcToCBuffer(buf, stc);
    AttribDeclaration::toCBuffer(buf, hgs);
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
    StringExp *se = msg->toString();
    if (se)
        depmsg = (char *)se->string;
    else
        msg->error("string expected, not '%s'", msg->toChars());

    Scope *scx = sc->push();
    scx->depmsg = depmsg;
    StorageClassDeclaration::setScope(scx);
    scx->pop();
}

void DeprecatedDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("deprecated(");
    msg->toCBuffer(buf, hgs);
    buf->writestring(") ");
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
        for (size_t i = 0; i < decl->dim; i++)
        {
            Dsymbol *s = (*decl)[i];

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

    p = Pprotectionnames[protection];

    assert(p);

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
    if (salign == STRUCTALIGN_DEFAULT)
        buf->printf("align");
    else
        buf->printf("align (%d)", salign);
    AttribDeclaration::toCBuffer(buf, hgs);
}

/********************************* AnonDeclaration ****************************/

AnonDeclaration::AnonDeclaration(Loc loc, int isunion, Dsymbols *decl)
        : AttribDeclaration(decl)
{
    this->loc = loc;
    this->alignment = 0;
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
        sc->offset = 0;
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

        // 0 sized structs are set to 1 byte
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


void AnonDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->printf(isunion ? "union" : "struct");
    buf->writenl();
    buf->writestring("{");
    buf->writenl();
    buf->level++;
    if (decl)
    {
        for (size_t i = 0; i < decl->dim; i++)
        {
            Dsymbol *s = (*decl)[i];
            s->toCBuffer(buf, hgs);
        }
    }
    buf->level--;
    buf->writestring("}");
    buf->writenl();
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
                Expression *e = (*args)[i];

                e = e->semantic(sc);
                e = resolveProperties(sc, e);
                if (e->op != TOKerror && e->op != TOKtype)
                    e = e->ctfeInterpret();
                if (e->op == TOKerror)
                {   errorSupplemental(loc, "while evaluating pragma(msg, %s)", (*args)[i]->toChars());
                    return;
                }
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
            Expression *e = (*args)[0];

            e = e->semantic(sc);
            e = resolveProperties(sc, e);
            e = e->ctfeInterpret();
            (*args)[0] = e;
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
#if DMDV2
    else if (ident == Id::startaddress)
    {
        if (!args || args->dim != 1)
            error("function name expected for start address");
        else
        {
            Expression *e = (*args)[0];
            e = e->semantic(sc);
            e = resolveProperties(sc, e);
            e = e->ctfeInterpret();
            (*args)[0] = e;
            Dsymbol *sa = getDsymbol(e);
            if (!sa || !sa->isFuncDeclaration())
                error("function name expected for start address, not '%s'", e->toChars());
        }
        goto Lnodecl;
    }
#endif
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
                    Expression *e = (*args)[i];
                    e = e->semantic(sc);
                    e = resolveProperties(sc, e);
                    e = e->ctfeInterpret();
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

Ldecl:
    if (decl)
    {
        for (size_t i = 0; i < decl->dim; i++)
        {
            Dsymbol *s = (*decl)[i];

            s->semantic(sc);
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

int PragmaDeclaration::oneMember(Dsymbol **ps, Identifier *ident)
{
    *ps = NULL;
    return TRUE;
}

const char *PragmaDeclaration::kind()
{
    return "pragma";
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


int ConditionalDeclaration::oneMember(Dsymbol **ps, Identifier *ident)
{
    //printf("ConditionalDeclaration::oneMember(), inc = %d\n", condition->inc);
    if (condition->inc)
    {
        Dsymbols *d = condition->include(NULL, NULL) ? decl : elsedecl;
        return Dsymbol::oneMembers(d, ps, ident);
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
        for (size_t i = 0; i < d->dim; i++)
        {   Dsymbol *s = (*d)[i];
            s->emitComment(sc);
        }
    }
}

// Decide if 'then' or 'else' code should be included

Dsymbols *ConditionalDeclaration::include(Scope *sc, ScopeDsymbol *sd)
{
    //printf("ConditionalDeclaration::include(sc = %p) scope = %p\n", sc, scope);
    assert(condition);
    return condition->include(scope ? scope : sc, sd) ? decl : elsedecl;
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

void ConditionalDeclaration::importAll(Scope *sc)
{
    Dsymbols *d = include(sc, NULL);

    //printf("\tConditionalDeclaration::importAll '%s', d = %p\n",toChars(), d);
    if (d)
    {
       for (size_t i = 0; i < d->dim; i++)
       {
           Dsymbol *s = (*d)[i];

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
                for (size_t i = 0; i < d->dim; i++)
                {   Dsymbol *s = (*d)[i];
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
        buf->level++;
        if (decl)
        {
            for (size_t i = 0; i < decl->dim; i++)
            {
                Dsymbol *s = (*decl)[i];
                s->toCBuffer(buf, hgs);
            }
        }
        buf->level--;
        buf->writeByte('}');
        if (elsedecl)
        {
            buf->writenl();
            buf->writestring("else");
            buf->writenl();
            buf->writeByte('{');
            buf->writenl();
            buf->level++;
            for (size_t i = 0; i < elsedecl->dim; i++)
            {
                Dsymbol *s = (*elsedecl)[i];
                s->toCBuffer(buf, hgs);
            }
            buf->level--;
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

Dsymbols *StaticIfDeclaration::include(Scope *sc, ScopeDsymbol *sd)
{
    //printf("StaticIfDeclaration::include(sc = %p) scope = %p\n", sc, scope);

    if (condition->inc == 0)
    {
        Dsymbols *d = ConditionalDeclaration::include(sc, sd);

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
        return ConditionalDeclaration::include(sc, sd);
    }
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

    // But do set the scope, in case we need it for forward referencing
    Dsymbol::setScope(sc);
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
    exp = exp->ctfeInterpret();
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
    Expressions *atts = Expression::arraySyntaxCopy(this->atts);
    return new UserAttributeDeclaration(atts, Dsymbol::arraySyntaxCopy(decl));
}

void UserAttributeDeclaration::semantic(Scope *sc)
{
    //printf("UserAttributeDeclaration::semantic() %p\n", this);
    atts = arrayExpressionSemantic(atts, sc);

    if (decl)
    {
        Scope *newsc = sc;
#if 1
        if (atts && atts->dim)
        {
            // create new one for changes
            newsc = new Scope(*sc);
            newsc->flags &= ~SCOPEfree;

            // Create new uda that is the concatenation of the previous
            newsc->userAttributes = concat(newsc->userAttributes, atts);
        }
#endif
        for (size_t i = 0; i < decl->dim; i++)
        {   Dsymbol *s = (*decl)[i];

            s->semantic(newsc);
        }
        if (newsc != sc)
        {
            sc->offset = newsc->offset;
            newsc->pop();
        }
    }
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
        udas->push(new TupleExp(0, udas1));
        udas->push(new TupleExp(0, udas2));
    }
    return udas;
}

void UserAttributeDeclaration::setScope(Scope *sc)
{
    //printf("UserAttributeDeclaration::setScope() %p\n", this);
    if (decl)
    {
        Scope *newsc = sc;
#if 1
        if (atts && atts->dim)
        {
            // create new one for changes
            newsc = new Scope(*sc);
            newsc->flags &= ~SCOPEfree;

            // Append new atts to old one
            if (!newsc->userAttributes || newsc->userAttributes->dim == 0)
                newsc->userAttributes = atts;
            else
            {
                // Create a tuple that combines them
                Expressions *exps = new Expressions();
                exps->push(new TupleExp(0, newsc->userAttributes));
                exps->push(new TupleExp(0, atts));
                newsc->userAttributes = exps;
            }
        }
#endif
        for (size_t i = 0; i < decl->dim; i++)
        {   Dsymbol *s = (*decl)[i];

            s->setScope(newsc); // yes, the only difference from semantic()
        }
        if (newsc != sc)
        {
            sc->offset = newsc->offset;
            newsc->pop();
        }
    }
}

void UserAttributeDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("@(");
    argsToCBuffer(buf, atts, hgs);
    buf->writeByte(')');
    AttribDeclaration::toCBuffer(buf, hgs);
}

const char *UserAttributeDeclaration::kind()
{
    return "UserAttribute";
}


