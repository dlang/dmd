
// Compiler implementation of the D programming language
// Copyright (c) 1999-2011 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <string.h>
#include <assert.h>

#include "rmem.h"
#include "speller.h"
#include "aav.h"

#include "mars.h"
#include "dsymbol.h"
#include "aggregate.h"
#include "identifier.h"
#include "module.h"
#include "mtype.h"
#include "expression.h"
#include "statement.h"
#include "declaration.h"
#include "id.h"
#include "scope.h"
#include "init.h"
#include "import.h"
#include "template.h"
#include "attrib.h"

/****************************** Dsymbol ******************************/

Dsymbol::Dsymbol()
{
    //printf("Dsymbol::Dsymbol(%p)\n", this);
    this->ident = NULL;
    this->c_ident = NULL;
    this->parent = NULL;
    this->csym = NULL;
    this->isym = NULL;
    this->loc = 0;
    this->comment = NULL;
    this->scope = NULL;
}

Dsymbol::Dsymbol(Identifier *ident)
{
    //printf("Dsymbol::Dsymbol(%p, ident)\n", this);
    this->ident = ident;
    this->c_ident = NULL;
    this->parent = NULL;
    this->csym = NULL;
    this->isym = NULL;
    this->loc = 0;
    this->comment = NULL;
    this->scope = NULL;
}

int Dsymbol::equals(Object *o)
{   Dsymbol *s;

    if (this == o)
        return TRUE;
    s = (Dsymbol *)(o);
    // Overload sets don't have an ident
    if (s && ident && s->ident && ident->equals(s->ident))
        return TRUE;
    return FALSE;
}

/**************************************
 * Copy the syntax.
 * Used for template instantiations.
 * If s is NULL, allocate the new object, otherwise fill it in.
 */

Dsymbol *Dsymbol::syntaxCopy(Dsymbol *s)
{
    print();
    printf("%s %s\n", kind(), toChars());
    assert(0);
    return NULL;
}

/**************************************
 * Determine if this symbol is only one.
 * Returns:
 *      FALSE, *ps = NULL: There are 2 or more symbols
 *      TRUE,  *ps = NULL: There are zero symbols
 *      TRUE,  *ps = symbol: The one and only one symbol
 */

int Dsymbol::oneMember(Dsymbol **ps)
{
    //printf("Dsymbol::oneMember()\n");
    *ps = this;
    return TRUE;
}

/*****************************************
 * Same as Dsymbol::oneMember(), but look at an array of Dsymbols.
 */

int Dsymbol::oneMembers(Dsymbols *members, Dsymbol **ps)
{
    //printf("Dsymbol::oneMembers() %d\n", members ? members->dim : 0);
    Dsymbol *s = NULL;

    if (members)
    {
        for (size_t i = 0; i < members->dim; i++)
        {   Dsymbol *sx = (*members)[i];

            int x = sx->oneMember(ps);
            //printf("\t[%d] kind %s = %d, s = %p\n", i, sx->kind(), x, *ps);
            if (!x)
            {
                //printf("\tfalse 1\n");
                assert(*ps == NULL);
                return FALSE;
            }
            if (*ps)
            {
                if (s)                  // more than one symbol
                {   *ps = NULL;
                    //printf("\tfalse 2\n");
                    return FALSE;
                }
                s = *ps;
            }
        }
    }
    *ps = s;            // s is the one symbol, NULL if none
    //printf("\ttrue\n");
    return TRUE;
}

/*****************************************
 * Is Dsymbol a variable that contains pointers?
 */

int Dsymbol::hasPointers()
{
    //printf("Dsymbol::hasPointers() %s\n", toChars());
    return 0;
}

char *Dsymbol::toChars()
{
    return ident ? ident->toChars() : (char *)"__anonymous";
}

const char *Dsymbol::toPrettyChars()
{   Dsymbol *p;
    char *s;
    char *q;
    size_t len;

    //printf("Dsymbol::toPrettyChars() '%s'\n", toChars());
    if (!parent)
        return toChars();

    len = 0;
    for (p = this; p; p = p->parent)
        len += strlen(p->toChars()) + 1;

    s = (char *)mem.malloc(len);
    q = s + len - 1;
    *q = 0;
    for (p = this; p; p = p->parent)
    {
        char *t = p->toChars();
        len = strlen(t);
        q -= len;
        memcpy(q, t, len);
        if (q == s)
            break;
        q--;
#if TARGET_NET
    if (AggregateDeclaration* ad = p->isAggregateDeclaration())
    {
        if (ad->isNested() && p->parent && p->parent->isAggregateDeclaration())
        {
            *q = '/';
            continue;
        }
    }
#endif
        *q = '.';
    }
    return s;
}

char *Dsymbol::locToChars()
{
    OutBuffer buf;

    if (!loc.filename)  // avoid bug 5861.
    {
        Module *m = getModule();

        if (m && m->srcfile)
            loc.filename = m->srcfile->toChars();
    }
    return loc.toChars();
}

const char *Dsymbol::kind()
{
    return "symbol";
}

/*********************************
 * If this symbol is really an alias for another,
 * return that other.
 */

Dsymbol *Dsymbol::toAlias()
{
    return this;
}

Dsymbol *Dsymbol::toParent()
{
    return parent ? parent->pastMixin() : NULL;
}

Dsymbol *Dsymbol::pastMixin()
{
    Dsymbol *s = this;

    //printf("Dsymbol::pastMixin() %s\n", toChars());
    while (s && s->isTemplateMixin())
        s = s->parent;
    return s;
}

/**********************************
 * Use this instead of toParent() when looking for the
 * 'this' pointer of the enclosing function/class.
 */

Dsymbol *Dsymbol::toParent2()
{
    Dsymbol *s = parent;
    while (s && s->isTemplateInstance())
        s = s->parent;
    return s;
}

TemplateInstance *Dsymbol::inTemplateInstance()
{
    for (Dsymbol *parent = this->parent; parent; parent = parent->parent)
    {
        TemplateInstance *ti = parent->isTemplateInstance();
        if (ti)
            return ti;
    }
    return NULL;
}

int Dsymbol::isAnonymous()
{
    return ident ? 0 : 1;
}

/*************************************
 * Set scope for future semantic analysis so we can
 * deal better with forward references.
 */

void Dsymbol::setScope(Scope *sc)
{
    //printf("Dsymbol::setScope() %p %s\n", this, toChars());
    if (!sc->nofree)
        sc->setNoFree();                // may need it even after semantic() finishes
    scope = sc;
}

void Dsymbol::importAll(Scope *sc)
{
}

/*************************************
 * Does semantic analysis on the public face of declarations.
 */

void Dsymbol::semantic0(Scope *sc)
{
}

void Dsymbol::semantic(Scope *sc)
{
    error("%p has no semantic routine", this);
}

/*************************************
 * Does semantic analysis on initializers and members of aggregates.
 */

void Dsymbol::semantic2(Scope *sc)
{
    // Most Dsymbols have no further semantic analysis needed
}

/*************************************
 * Does semantic analysis on function bodies.
 */

void Dsymbol::semantic3(Scope *sc)
{
    // Most Dsymbols have no further semantic analysis needed
}

/*************************************
 * Look for function inlining possibilities.
 */

void Dsymbol::inlineScan()
{
    // Most Dsymbols aren't functions
}

/*********************************************
 * Search for ident as member of s.
 * Input:
 *      flags:  1       don't find private members
 *              2       don't give error messages
 *              4       return NULL if ambiguous
 * Returns:
 *      NULL if not found
 */

Dsymbol *Dsymbol::search(Loc loc, Identifier *ident, int flags)
{
    //printf("Dsymbol::search(this=%p,%s, ident='%s')\n", this, toChars(), ident->toChars());
    return NULL;
}

/***************************************************
 * Search for symbol with correct spelling.
 */

void *symbol_search_fp(void *arg, const char *seed)
{
    Dsymbol *s = (Dsymbol *)arg;
    Identifier id(seed, 0);
    Module::clearCache();
    s = s->search(0, &id, 4|2);
    return s;
}

Dsymbol *Dsymbol::search_correct(Identifier *ident)
{
    if (global.gag)
        return NULL;            // don't do it for speculative compiles; too time consuming

    return (Dsymbol *)speller(ident->toChars(), &symbol_search_fp, this, idchars);
}

/***************************************
 * Search for identifier id as a member of 'this'.
 * id may be a template instance.
 * Returns:
 *      symbol found, NULL if not
 */

Dsymbol *Dsymbol::searchX(Loc loc, Scope *sc, Identifier *id)
{
    //printf("Dsymbol::searchX(this=%p,%s, ident='%s')\n", this, toChars(), ident->toChars());
    Dsymbol *s = toAlias();
    Dsymbol *sm;

    switch (id->dyncast())
    {
        case DYNCAST_IDENTIFIER:
            sm = s->search(loc, id, 0);
            break;

        case DYNCAST_DSYMBOL:
        {   // It's a template instance
            //printf("\ttemplate instance id\n");
            Dsymbol *st = (Dsymbol *)id;
            TemplateInstance *ti = st->isTemplateInstance();
            id = ti->name;
            sm = s->search(loc, id, 0);
            if (!sm)
            {   error("template identifier %s is not a member of %s %s",
                    id->toChars(), s->kind(), s->toChars());
                return NULL;
            }
            sm = sm->toAlias();
            TemplateDeclaration *td = sm->isTemplateDeclaration();
            if (!td)
            {
                error("%s is not a template, it is a %s", id->toChars(), sm->kind());
                return NULL;
            }
            ti->tempdecl = td;
            if (!ti->semanticRun)
                ti->semantic(sc);
            sm = ti->toAlias();
            break;
        }

        default:
            assert(0);
    }
    return sm;
}

int Dsymbol::overloadInsert(Dsymbol *s)
{
    //printf("Dsymbol::overloadInsert('%s')\n", s->toChars());
    return FALSE;
}

void Dsymbol::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring(toChars());
}

unsigned Dsymbol::size(Loc loc)
{
    error("Dsymbol '%s' has no size\n", toChars());
    return 0;
}

int Dsymbol::isforwardRef()
{
    return FALSE;
}

AggregateDeclaration *Dsymbol::isThis()
{
    return NULL;
}

AggregateDeclaration *Dsymbol::isAggregateMember()      // are we a member of an aggregate?
{
    Dsymbol *parent = toParent();
    if (parent && parent->isAggregateDeclaration())
        return (AggregateDeclaration *)parent;
    return NULL;
}

ClassDeclaration *Dsymbol::isClassMember()      // are we a member of a class?
{
    AggregateDeclaration *ad = isAggregateMember();
    return ad ? ad->isClassDeclaration() : NULL;
}

void Dsymbol::defineRef(Dsymbol *s)
{
    assert(0);
}

int Dsymbol::isExport()
{
    return FALSE;
}

int Dsymbol::isImportedSymbol()
{
    return FALSE;
}

int Dsymbol::isDeprecated()
{
    return FALSE;
}

#if DMDV2
int Dsymbol::isOverloadable()
{
    return 0;
}
#endif

LabelDsymbol *Dsymbol::isLabel()                // is this a LabelDsymbol()?
{
    return NULL;
}

AggregateDeclaration *Dsymbol::isMember()       // is this a member of an AggregateDeclaration?
{
    //printf("Dsymbol::isMember() %s\n", toChars());
    Dsymbol *parent = toParent();
    //printf("parent is %s %s\n", parent->kind(), parent->toChars());
    return parent ? parent->isAggregateDeclaration() : NULL;
}

Type *Dsymbol::getType()
{
    return NULL;
}

int Dsymbol::needThis()
{
    return FALSE;
}

int Dsymbol::addMember(Scope *sc, ScopeDsymbol *sd, int memnum)
{
    //printf("Dsymbol::addMember('%s')\n", toChars());
    //printf("Dsymbol::addMember(this = %p, '%s' scopesym = '%s')\n", this, toChars(), sd->toChars());
    //printf("Dsymbol::addMember(this = %p, '%s' sd = %p, sd->symtab = %p)\n", this, toChars(), sd, sd->symtab);
    parent = sd;
    if (!isAnonymous())         // no name, so can't add it to symbol table
    {
        if (!sd->symtabInsert(this))    // if name is already defined
        {
            Dsymbol *s2;

            s2 = sd->symtab->lookup(ident);
            if (!s2->overloadInsert(this))
            {
                sd->multiplyDefined(0, this, s2);
            }
        }
        if (sd->isAggregateDeclaration() || sd->isEnumDeclaration())
        {
            if (ident == Id::__sizeof || ident == Id::__xalignof || ident == Id::mangleof)
                error(".%s property cannot be redefined", ident->toChars());
        }
        return 1;
    }
    return 0;
}

void Dsymbol::error(const char *format, ...)
{
    //printf("Dsymbol::error()\n");
    if (!global.gag)
    {
        char *p = locToChars();

        if (*p)
            fprintf(stdmsg, "%s: ", p);
        mem.free(p);

        fprintf(stdmsg, "Error: ");
        if (isAnonymous())
            fprintf(stdmsg, "%s ", kind());
        else
            fprintf(stdmsg, "%s %s ", kind(), toPrettyChars());

        va_list ap;
        va_start(ap, format);
        vfprintf(stdmsg, format, ap);
        va_end(ap);

        fprintf(stdmsg, "\n");
        fflush(stdmsg);
//halt();
    }
    global.errors++;

    //fatal();
}

void Dsymbol::error(Loc loc, const char *format, ...)
{
    if (!global.gag)
    {
        char *p = loc.toChars();
        if (!*p)
            p = locToChars();

        if (*p)
            fprintf(stdmsg, "%s: ", p);
        mem.free(p);

        fprintf(stdmsg, "Error: ");
        fprintf(stdmsg, "%s %s ", kind(), toPrettyChars());

        va_list ap;
        va_start(ap, format);
        vfprintf(stdmsg, format, ap);
        va_end(ap);

        fprintf(stdmsg, "\n");
        fflush(stdmsg);
//halt();
    }

    global.errors++;

    //fatal();
}

void Dsymbol::checkDeprecated(Loc loc, Scope *sc)
{
    if (!global.params.useDeprecated && isDeprecated())
    {
        // Don't complain if we're inside a deprecated symbol's scope
        for (Dsymbol *sp = sc->parent; sp; sp = sp->parent)
        {   if (sp->isDeprecated())
                goto L1;
        }

        for (Scope *sc2 = sc; sc2; sc2 = sc2->enclosing)
        {
            if (sc2->scopesym && sc2->scopesym->isDeprecated())
                goto L1;

            // If inside a StorageClassDeclaration that is deprecated
            if (sc2->stc & STCdeprecated)
                goto L1;
        }

        error(loc, "is deprecated");
    }

  L1:
    Declaration *d = isDeclaration();
    if (d && d->storage_class & STCdisable)
    {
        if (!(sc->func && sc->func->storage_class & STCdisable))
        {
            if (d->ident == Id::cpctor && d->toParent())
                d->toParent()->error(loc, "is not copyable because it is annotated with @disable");
            else
                error(loc, "is not callable because it is annotated with @disable");
        }
    }
}

/**********************************
 * Determine which Module a Dsymbol is in.
 */

Module *Dsymbol::getModule()
{
    Module *m;
    Dsymbol *s;

    //printf("Dsymbol::getModule()\n");
    TemplateDeclaration *td = getFuncTemplateDecl(this);
    if (td)
        return td->getModule();

    s = this;
    while (s)
    {
        //printf("\ts = '%s'\n", s->toChars());
        m = s->isModule();
        if (m)
            return m;
        s = s->parent;
    }
    return NULL;
}

/*************************************
 */

enum PROT Dsymbol::prot()
{
    return PROTpublic;
}

/*************************************
 * Do syntax copy of an array of Dsymbol's.
 */


Dsymbols *Dsymbol::arraySyntaxCopy(Dsymbols *a)
{

    Dsymbols *b = NULL;
    if (a)
    {
        b = (Dsymbols *)a->copy();
        for (size_t i = 0; i < b->dim; i++)
        {
            Dsymbol *s = (*b)[i];

            s = s->syntaxCopy(NULL);
            (*b)[i] = s;
        }
    }
    return b;
}


/****************************************
 * Add documentation comment to Dsymbol.
 * Ignore NULL comments.
 */

void Dsymbol::addComment(unsigned char *comment)
{
    //if (comment)
        //printf("adding comment '%s' to symbol %p '%s'\n", comment, this, toChars());

    if (!this->comment)
        this->comment = comment;
#if 1
    else if (comment && strcmp((char *)comment, (char *)this->comment))
    {   // Concatenate the two
        this->comment = Lexer::combineComments(this->comment, comment);
    }
#endif
}

/********************************* OverloadSet ****************************/

#if DMDV2
OverloadSet::OverloadSet()
    : Dsymbol()
{
}

void OverloadSet::push(Dsymbol *s)
{
    a.push(s);
}

const char *OverloadSet::kind()
{
    return "overloadset";
}
#endif


/********************************* ScopeDsymbol ****************************/

ScopeDsymbol::ScopeDsymbol()
    : Dsymbol()
{
    members = NULL;
    symtab = NULL;
    imports = NULL;
    prots = NULL;
}

ScopeDsymbol::ScopeDsymbol(Identifier *id)
    : Dsymbol(id)
{
    members = NULL;
    symtab = NULL;
    imports = NULL;
    prots = NULL;
}

Dsymbol *ScopeDsymbol::syntaxCopy(Dsymbol *s)
{
    //printf("ScopeDsymbol::syntaxCopy('%s')\n", toChars());

    ScopeDsymbol *sd;
    if (s)
        sd = (ScopeDsymbol *)s;
    else
        sd = new ScopeDsymbol(ident);
    sd->members = arraySyntaxCopy(members);
    return sd;
}

Dsymbol *ScopeDsymbol::search(Loc loc, Identifier *ident, int flags)
{
    //printf("%s->ScopeDsymbol::search(ident='%s', flags=x%x)\n", toChars(), ident->toChars(), flags);
    //if (strcmp(ident->toChars(),"c") == 0) *(char*)0=0;

    // Look in symbols declared in this module
    Dsymbol *s = symtab ? symtab->lookup(ident) : NULL;
    //printf("\ts = %p, imports = %p, %d\n", s, imports, imports ? imports->dim : 0);
    if (s)
    {
        //printf("\ts = '%s.%s'\n",toChars(),s->toChars());
    }
    else if (imports)
    {
        OverloadSet *a = NULL;

        // Look in imported modules
        for (size_t i = 0; i < imports->dim; i++)
        {   ScopeDsymbol *ss = (*imports)[i];
            Dsymbol *s2;

            // If private import, don't search it
            if (flags & 1 && prots[i] == PROTprivate)
                continue;

            //printf("\tscanning import '%s', prots = %d, isModule = %p, isImport = %p\n", ss->toChars(), prots[i], ss->isModule(), ss->isImport());
            /* Don't find private members if ss is a module
             */
            s2 = ss->search(loc, ident, ss->isModule() ? 1 : 0);
            if (!s)
                s = s2;
            else if (s2 && s != s2)
            {
                if (s->toAlias() == s2->toAlias())
                {
                    /* After following aliases, we found the same symbol,
                     * so it's not an ambiguity.
                     * But if one alias is deprecated, prefer the other.
                     */
                    if (s->isDeprecated())
                        s = s2;
                }
                else
                {
                    /* Two imports of the same module should be regarded as
                     * the same.
                     */
                    Import *i1 = s->isImport();
                    Import *i2 = s2->isImport();
                    if (!(i1 && i2 &&
                          (i1->mod == i2->mod ||
                           (!i1->parent->isImport() && !i2->parent->isImport() &&
                            i1->ident->equals(i2->ident))
                          )
                         )
                       )
                    {
                        /* If both s2 and s are overloadable (though we only
                         * need to check s once)
                         */
                        if (s2->isOverloadable() && (a || s->isOverloadable()))
                        {   if (!a)
                                a = new OverloadSet();
                            /* Don't add to a[] if s2 is alias of previous sym
                             */
                            for (size_t j = 0; j < a->a.dim; j++)
                            {   Dsymbol *s3 = a->a[j];
                                if (s2->toAlias() == s3->toAlias())
                                {
                                    if (s3->isDeprecated())
                                        a->a[j] = s2;
                                    goto Lcontinue;
                                }
                            }
                            a->push(s2);
                        Lcontinue:
                            continue;
                        }
                        if (flags & 4)          // if return NULL on ambiguity
                            return NULL;
                        if (!(flags & 2))
                            ss->multiplyDefined(loc, s, s2);
                        break;
                    }
                }
            }
        }

        /* Build special symbol if we had multiple finds
         */
        if (a)
        {   assert(s);
            a->push(s);
            s = a;
        }

        if (s)
        {
            Declaration *d = s->isDeclaration();
            if (d && d->protection == PROTprivate &&
                !d->parent->isTemplateMixin() &&
                !(flags & 2))
                error(loc, "%s is private", d->toPrettyChars());
        }
    }
    return s;
}

void ScopeDsymbol::importScope(ScopeDsymbol *s, enum PROT protection)
{
    //printf("%s->ScopeDsymbol::importScope(%s, %d)\n", toChars(), s->toChars(), protection);

    // No circular or redundant import's
    if (s != this)
    {
        if (!imports)
            imports = new ScopeDsymbols();
        else
        {
            for (size_t i = 0; i < imports->dim; i++)
            {   ScopeDsymbol *ss = (*imports)[i];
                if (ss == s)                    // if already imported
                {
                    if (protection > prots[i])
                        prots[i] = protection;  // upgrade access
                    return;
                }
            }
        }
        imports->push(s);
        prots = (unsigned char *)mem.realloc(prots, imports->dim * sizeof(prots[0]));
        prots[imports->dim - 1] = protection;
    }
}

int ScopeDsymbol::isforwardRef()
{
    return (members == NULL);
}

void ScopeDsymbol::defineRef(Dsymbol *s)
{
    ScopeDsymbol *ss;

    ss = s->isScopeDsymbol();
    members = ss->members;
    ss->members = NULL;
}

void ScopeDsymbol::multiplyDefined(Loc loc, Dsymbol *s1, Dsymbol *s2)
{
#if 0
    printf("ScopeDsymbol::multiplyDefined()\n");
    printf("s1 = %p, '%s' kind = '%s', parent = %s\n", s1, s1->toChars(), s1->kind(), s1->parent ? s1->parent->toChars() : "");
    printf("s2 = %p, '%s' kind = '%s', parent = %s\n", s2, s2->toChars(), s2->kind(), s2->parent ? s2->parent->toChars() : "");
#endif
    if (loc.filename)
    {   ::error(loc, "%s at %s conflicts with %s at %s",
            s1->toPrettyChars(),
            s1->locToChars(),
            s2->toPrettyChars(),
            s2->locToChars());
    }
    else
    {
        s1->error(loc, "conflicts with %s %s at %s",
            s2->kind(),
            s2->toPrettyChars(),
            s2->locToChars());
    }
}

Dsymbol *ScopeDsymbol::nameCollision(Dsymbol *s)
{
    Dsymbol *sprev;

    // Look to see if we are defining a forward referenced symbol

    sprev = symtab->lookup(s->ident);
    assert(sprev);
    if (s->equals(sprev))               // if the same symbol
    {
        if (s->isforwardRef())          // if second declaration is a forward reference
            return sprev;
        if (sprev->isforwardRef())
        {
            sprev->defineRef(s);        // copy data from s into sprev
            return sprev;
        }
    }
    multiplyDefined(0, s, sprev);
    return sprev;
}

const char *ScopeDsymbol::kind()
{
    return "ScopeDsymbol";
}

Dsymbol *ScopeDsymbol::symtabInsert(Dsymbol *s)
{
    return symtab->insert(s);
}

/***************************************
 * Determine number of Dsymbols, folding in AttribDeclaration members.
 */

#if DMDV2
size_t ScopeDsymbol::dim(Dsymbols *members)
{
    size_t n = 0;
    if (members)
    {
        for (size_t i = 0; i < members->dim; i++)
        {   Dsymbol *s = (*members)[i];
            AttribDeclaration *a = s->isAttribDeclaration();

            if (a)
            {
                n += dim(a->decl);
            }
            else
                n++;
        }
    }
    return n;
}
#endif

/***************************************
 * Get nth Dsymbol, folding in AttribDeclaration members.
 * Returns:
 *      Dsymbol*        nth Dsymbol
 *      NULL            not found, *pn gets incremented by the number
 *                      of Dsymbols
 */

#if DMDV2
Dsymbol *ScopeDsymbol::getNth(Dsymbols *members, size_t nth, size_t *pn)
{
    if (!members)
        return NULL;

    size_t n = 0;
    for (size_t i = 0; i < members->dim; i++)
    {   Dsymbol *s = (*members)[i];
        AttribDeclaration *a = s->isAttribDeclaration();
        TemplateMixin *tm = s->isTemplateMixin();
        TemplateInstance *ti = s->isTemplateInstance();

        if (a)
        {
            s = getNth(a->decl, nth - n, &n);
            if (s)
                return s;
        }
        else if (tm)
        {
            s = getNth(tm->members, nth - n, &n);
            if (s)
                return s;
        }
        else if (ti)
            ;
        else if (n == nth)
            return s;
        else
            n++;
    }

    if (pn)
        *pn += n;
    return NULL;
}
#endif

/*******************************************
 * Look for member of the form:
 *      const(MemberInfo)[] getMembers(string);
 * Returns NULL if not found
 */

#if DMDV2
FuncDeclaration *ScopeDsymbol::findGetMembers()
{
    Dsymbol *s = search_function(this, Id::getmembers);
    FuncDeclaration *fdx = s ? s->isFuncDeclaration() : NULL;

#if 0  // Finish
    static TypeFunction *tfgetmembers;

    if (!tfgetmembers)
    {
        Scope sc;
        Parameters *arguments = new Parameters;
        Parameters *arg = new Parameter(STCin, Type::tchar->constOf()->arrayOf(), NULL, NULL);
        arguments->push(arg);

        Type *tret = NULL;
        tfgetmembers = new TypeFunction(arguments, tret, 0, LINKd);
        tfgetmembers = (TypeFunction *)tfgetmembers->semantic(0, &sc);
    }
    if (fdx)
        fdx = fdx->overloadExactMatch(tfgetmembers);
#endif
    if (fdx && fdx->isVirtual())
        fdx = NULL;

    return fdx;
}
#endif


/****************************** WithScopeSymbol ******************************/

WithScopeSymbol::WithScopeSymbol(WithStatement *withstate)
    : ScopeDsymbol()
{
    this->withstate = withstate;
}

Dsymbol *WithScopeSymbol::search(Loc loc, Identifier *ident, int flags)
{
    // Acts as proxy to the with class declaration
    return withstate->exp->type->toDsymbol(NULL)->search(loc, ident, 0);
}

/****************************** ArrayScopeSymbol ******************************/

ArrayScopeSymbol::ArrayScopeSymbol(Scope *sc, Expression *e)
    : ScopeDsymbol()
{
    assert(e->op == TOKindex || e->op == TOKslice);
    exp = e;
    type = NULL;
    td = NULL;
    this->sc = sc;
}

ArrayScopeSymbol::ArrayScopeSymbol(Scope *sc, TypeTuple *t)
    : ScopeDsymbol()
{
    exp = NULL;
    type = t;
    td = NULL;
    this->sc = sc;
}

ArrayScopeSymbol::ArrayScopeSymbol(Scope *sc, TupleDeclaration *s)
    : ScopeDsymbol()
{
    exp = NULL;
    type = NULL;
    td = s;
    this->sc = sc;
}

Dsymbol *ArrayScopeSymbol::search(Loc loc, Identifier *ident, int flags)
{
    //printf("ArrayScopeSymbol::search('%s', flags = %d)\n", ident->toChars(), flags);
    if (ident == Id::length || ident == Id::dollar)
    {   VarDeclaration **pvar;
        Expression *ce;

        if (ident == Id::length && !global.params.useDeprecated)
            error("using 'length' inside [ ] is deprecated, use '$' instead");

    L1:

        if (td)
        {   /* $ gives the number of elements in the tuple
             */
            VarDeclaration *v = new VarDeclaration(loc, Type::tsize_t, Id::dollar, NULL);
            Expression *e = new IntegerExp(0, td->objects->dim, Type::tsize_t);
            v->init = new ExpInitializer(0, e);
            v->storage_class |= STCstatic | STCconst;
            v->semantic(sc);
            return v;
        }

        if (type)
        {   /* $ gives the number of type entries in the type tuple
             */
            VarDeclaration *v = new VarDeclaration(loc, Type::tsize_t, Id::dollar, NULL);
            Expression *e = new IntegerExp(0, type->arguments->dim, Type::tsize_t);
            v->init = new ExpInitializer(0, e);
            v->storage_class |= STCstatic | STCconst;
            v->semantic(sc);
            return v;
        }

        if (exp->op == TOKindex)
        {   /* array[index] where index is some function of $
             */
            IndexExp *ie = (IndexExp *)exp;

            pvar = &ie->lengthVar;
            ce = ie->e1;
        }
        else if (exp->op == TOKslice)
        {   /* array[lwr .. upr] where lwr or upr is some function of $
             */
            SliceExp *se = (SliceExp *)exp;

            pvar = &se->lengthVar;
            ce = se->e1;
        }
        else
            /* Didn't find $, look in enclosing scope(s).
             */
            return NULL;

        /* If we are indexing into an array that is really a type
         * tuple, rewrite this as an index into a type tuple and
         * try again.
         */
        if (ce->op == TOKtype)
        {
            Type *t = ((TypeExp *)ce)->type;
            if (t->ty == Ttuple)
            {   type = (TypeTuple *)t;
                goto L1;
            }
        }

        /* *pvar is lazily initialized, so if we refer to $
         * multiple times, it gets set only once.
         */
        if (!*pvar)             // if not already initialized
        {   /* Create variable v and set it to the value of $
             */
            VarDeclaration *v = new VarDeclaration(loc, Type::tsize_t, Id::dollar, NULL);
            if (ce->op == TOKtuple)
            {   /* It is for an expression tuple, so the
                 * length will be a const.
                 */
                Expression *e = new IntegerExp(0, ((TupleExp *)ce)->exps->dim, Type::tsize_t);
                v->init = new ExpInitializer(0, e);
                v->storage_class |= STCstatic | STCconst;
            }
            else
            {   /* For arrays, $ will either be a compile-time constant
                 * (in which case its value in set during constant-folding),
                 * or a variable (in which case an expression is created in
                 * toir.c).
                 */
                v->init = new VoidInitializer(0);
            }
            *pvar = v;
        }
        (*pvar)->semantic(sc);
        return (*pvar);
    }
    return NULL;
}


/****************************** DsymbolTable ******************************/

DsymbolTable::DsymbolTable()
{
#if STRINGTABLE
    tab = new StringTable;
#else
    tab = NULL;
#endif
}

DsymbolTable::~DsymbolTable()
{
#if STRINGTABLE
    delete tab;
#endif
}

Dsymbol *DsymbolTable::lookup(Identifier *ident)
{
#if STRINGTABLE
#ifdef DEBUG
    assert(ident);
    assert(tab);
#endif
    //printf("DsymbolTable::lookup(%s)\n", (char*)ident->string);
    StringValue *sv = tab->lookup((char*)ident->string, ident->len);
    return (Dsymbol *)(sv ? sv->ptrvalue : NULL);
#else
    //printf("DsymbolTable::lookup(%s)\n", (char*)ident->string);
    return (Dsymbol *)_aaGetRvalue(tab, ident);
#endif
}

Dsymbol *DsymbolTable::insert(Dsymbol *s)
{
    //printf("DsymbolTable::insert(this = %p, '%s')\n", this, s->ident->toChars());
    Identifier *ident = s->ident;
#if STRINGTABLE
#ifdef DEBUG
    assert(ident);
    assert(tab);
#endif
    StringValue *sv = tab->insert(ident->toChars(), ident->len);
    if (!sv)
        return NULL;            // already in table
    sv->ptrvalue = s;
    return s;
#else
    Dsymbol **ps = (Dsymbol **)_aaGet(&tab, ident);
    if (*ps)
        return NULL;            // already in table
    *ps = s;
    return s;
#endif
}

Dsymbol *DsymbolTable::insert(Identifier *ident, Dsymbol *s)
{
    //printf("DsymbolTable::insert()\n");
#if STRINGTABLE
    StringValue *sv = tab->insert(ident->toChars(), ident->len);
    if (!sv)
        return NULL;            // already in table
    sv->ptrvalue = s;
    return s;
#else
    Dsymbol **ps = (Dsymbol **)_aaGet(&tab, ident);
    if (*ps)
        return NULL;            // already in table
    *ps = s;
    return s;
#endif
}

Dsymbol *DsymbolTable::update(Dsymbol *s)
{
    Identifier *ident = s->ident;
#if STRINGTABLE
    StringValue *sv = tab->update(ident->toChars(), ident->len);
    sv->ptrvalue = s;
    return s;
#else
    Dsymbol **ps = (Dsymbol **)_aaGet(&tab, ident);
    *ps = s;
    return s;
#endif
}




