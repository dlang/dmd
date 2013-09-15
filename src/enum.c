
// Copyright (c) 1999-2013 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <assert.h>

#include "root.h"
#include "enum.h"
#include "mtype.h"
#include "scope.h"
#include "id.h"
#include "expression.h"
#include "module.h"
#include "declaration.h"
#include "init.h"

/********************************* EnumDeclaration ****************************/

EnumDeclaration::EnumDeclaration(Loc loc, Identifier *id, Type *memtype)
    : ScopeDsymbol(id)
{
    this->loc = loc;
    type = new TypeEnum(this);
    this->memtype = memtype;
    maxval = NULL;
    minval = NULL;
    defaultval = NULL;
    sinit = NULL;
    isdeprecated = false;
    protection = PROTundefined;
    parent = NULL;
    sce = NULL;
}

Dsymbol *EnumDeclaration::syntaxCopy(Dsymbol *s)
{
    Type *t = NULL;
    if (memtype)
        t = memtype->syntaxCopy();

    EnumDeclaration *ed;
    if (s)
    {   ed = (EnumDeclaration *)s;
        ed->memtype = t;
    }
    else
        ed = new EnumDeclaration(loc, ident, t);
    ScopeDsymbol::syntaxCopy(ed);
    if (isAnonymous())
    {
        for (size_t i = 0; i < members->dim; i++)
        {
            EnumMember *em = (*members)[i]->isEnumMember();
            em->ed = ed;
        }
    }
    return ed;
}

void EnumDeclaration::setScope(Scope *sc)
{
    if (semanticRun > PASSinit)
        return;
    ScopeDsymbol::setScope(sc);
}

int EnumDeclaration::addMember(Scope *sc, ScopeDsymbol *sd, int memnum)
{
    if (isAnonymous())
    {
        /* Anonymous enum members get added to enclosing scope.
         */
        for (size_t i = 0; i < members->dim; i++)
        {
            EnumMember *em = (*members)[i]->isEnumMember();
            em->ed = this;
            //printf("add %s\n", em->toChars());
            em->addMember(sc, sd, 1);
        }
        return 1;
    }
    else
       return ScopeDsymbol::addMember(sc, sd, memnum);
}


void EnumDeclaration::semantic(Scope *sc)
{
    //printf("EnumDeclaration::semantic(sd = %p, '%s') %s\n", sc->scopesym, sc->scopesym->toChars(), toChars());
    //printf("EnumDeclaration::semantic() %s\n", toChars());
    if (!members && !memtype)               // enum ident;
        return;

    if (symtab)                 // if already done
    {   if (semanticRun > PASSinit || !scope)
            return;             // semantic() already completed
    }
    else
        symtab = new DsymbolTable();

    Scope *scx = NULL;
    if (scope)
    {   sc = scope;
        scx = scope;            // save so we don't make redundant copies
        scope = NULL;
    }

    unsigned dprogress_save = Module::dprogress;

    if (sc->stc & STCdeprecated)
        isdeprecated = true;
    userAttributes = sc->userAttributes;

    parent = sc->parent;
    protection = sc->protection;

    /* The separate, and distinct, cases are:
     *  1. enum { ... }
     *  2. enum : memtype { ... }
     *  3. enum ident { ... }
     *  4. enum ident : memtype { ... }
     *  5. enum ident : memtype;
     */

    if (memtype)
    {
        memtype = memtype->semantic(loc, sc);

        /* Check to see if memtype is forward referenced
         */
        if (memtype->ty == Tenum)
        {   EnumDeclaration *sym = (EnumDeclaration *)memtype->toDsymbol(sc);
            if (!sym->memtype || !sym->members || !sym->symtab || sym->scope)
            {   // memtype is forward referenced, so try again later
                scope = scx ? scx : new Scope(*sc);
                scope->setNoFree();
                scope->module->addDeferredSemantic(this);
                Module::dprogress = dprogress_save;
                //printf("\tdeferring %s\n", toChars());
                return;
            }
        }
        if (memtype->ty == Tvoid)
        {
            error("base type must not be void");
            memtype = Type::terror;
        }
        if (memtype->ty == Terror)
        {
            errors = true;
            if (members)
            {
                for (size_t i = 0; i < members->dim; i++)
                {
                    Dsymbol *s = (*members)[i];
                    s->errors = true;               // poison all the members
                }
            }
            semanticRun = PASSsemanticdone;
            return;
        }
    }

    semanticRun = PASSsemanticdone;

    if (!members)               // enum ident : memtype;
        return;

    if (members->dim == 0)
    {
        error("enum %s must have at least one member", toChars());
        errors = true;
        return;
    }

    Module::dprogress++;

    type = type->semantic(loc, sc);
    if (isAnonymous())
        sce = sc;
    else
    {   sce = sc->push(this);
        sce->parent = this;
    }
    sce = sce->startCTFE();
    sce->setNoFree();                   // needed for getMaxMinValue()

    /* Determine the scope that the enum members are evaluated in
     */
    ScopeDsymbol *scopesym;
    if (isAnonymous())
    {
        /* Anonymous enum members get added to enclosing scope.
         */
        for (Scope *sct = sce; sct; sct = sct->enclosing)
        {
            if (sct->scopesym)
            {
                scopesym = sct->scopesym;
                if (!sct->scopesym->symtab)
                    sct->scopesym->symtab = new DsymbolTable();
                break;
            }
        }
    }
    else
        scopesym = this;

    int first = 1;
    Expression *elast = NULL;
    Expression *emax = NULL;
    Type *t;
    for (size_t i = 0; i < members->dim; i++)
    {
        EnumMember *em = (*members)[i]->isEnumMember();
        Expression *e;

        if (!em)
            /* The e->semantic(sce) can insert other symbols, such as
             * template instances and function literals.
             */
            continue;

        //printf("  Enum member '%s'\n",em->toChars());
        if (em->type)
            em->type = em->type->semantic(em->loc, sce);
        e = em->value;
        if (e)
        {
            assert(e->dyncast() == DYNCAST_EXPRESSION);
            e = e->semantic(sce);
            e = resolveProperties(sc, e);
            e = e->ctfeInterpret();
            if (first && !memtype && !isAnonymous())
                memtype = e->type;
            if (memtype && !em->type)
            {
                e = e->implicitCastTo(sce, memtype);
                e = e->ctfeInterpret();
                if (!isAnonymous())
                    e = e->castTo(sce, type);
                t = memtype;
            }
            else if (em->type)
            {
                e = e->implicitCastTo(sce, em->type);
                e = e->ctfeInterpret();
                assert(isAnonymous());
                t = e->type;
            }
            else
                t = e->type;
            if (isAnonymous() && em->type)
            {
                e = e->implicitCastTo(sce, em->type);
                e = e->ctfeInterpret();
            }
        }
        else if (first)
        {
            if (memtype)
                t = memtype;
            else
            {
                t = Type::tint32;
                if (!isAnonymous())
                    memtype = t;
            }
            e = new IntegerExp(em->loc, 0, Type::tint32);
            e = e->implicitCastTo(sce, t);
            e = e->ctfeInterpret();
            if (!isAnonymous())
                e = e->castTo(sce, type);
        }
        else if (memtype && memtype == Type::terror)
        {
            e = new ErrorExp();
            minval = e;
            maxval = e;
            defaultval = e;
        }
        else
        {
            // Lazily evaluate enum.max
            if (!emax)
            {
                emax = t->getProperty(Loc(), Id::max, 0);
                emax = emax->semantic(sce);
                emax = emax->ctfeInterpret();
            }

            // Set value to (elast + 1).
            // But first check that (elast != t.max)
            assert(elast);
            e = new EqualExp(TOKequal, em->loc, elast, emax);
            e = e->semantic(sce);
            e = e->ctfeInterpret();
            if (e->toInteger())
            {
                error("overflow of enum value %s", elast->toChars());
                em->errors = true;
            }

            // Now set e to (elast + 1)
            e = new AddExp(em->loc, elast, new IntegerExp(em->loc, 1, Type::tint32));
            e = e->semantic(sce);
            e = e->castTo(sce, elast->type);
            e = e->ctfeInterpret();

            if (t->isfloating())
            {
                // Check that e != elast (not always true for floats)
                Expression *etest = new EqualExp(TOKequal, em->loc, e, elast);
                etest = etest->semantic(sce);
                etest = etest->ctfeInterpret();
                if (etest->toInteger())
                {
                    error("enum member %s has inexact value, due to loss of precision", em->toChars());
                    em->errors = true;
                }
            }
        }
        elast = e;
        em->value = e;

        // Add to symbol table only after evaluating 'value'
        if (isAnonymous() && !sc->func)
        {
            // already inserted to enclosing scope in addMember
            assert(em->ed);
        }
        else
        {
            em->ed = this;
            em->addMember(sc, scopesym, 1);
        }
        first = 0;
    }
    //printf("defaultval = %lld\n", defaultval);

    //if (defaultval) printf("defaultval: %s %s\n", defaultval->toChars(), defaultval->type->toChars());
    //members->print();
}

/******************************
 * Get the value of the .max/.min property as an Expression
 * Input:
 *      id      Id::max or Id::min
 */

Expression *EnumDeclaration::getMaxMinValue(Loc loc, Identifier *id)
{
    //printf("EnumDeclaration::getMaxValue()\n");
    bool first = true;

    Expression **pval = (id == Id::max) ? &maxval : &minval;

    if (*pval)
        return *pval;

    if (scope)
        semantic(scope);
    if (errors)
        goto Lerrors;
    if (semanticRun == PASSinit || !members)
    {
        error("is forward referenced");
        goto Lerrors;
    }
    if (!(memtype && memtype->isintegral()))
    {
        error(loc, "has no .%s property because base type %s is not an integral type",
                id->toChars(),
                memtype ? memtype->toChars() : "");
        goto Lerrors;
    }

    for (size_t i = 0; i < members->dim; i++)
    {
        EnumMember *em = (*members)[i]->isEnumMember();
        if (!em)
            continue;
        Expression *e = em->value;
        if (em->errors)
            goto Lerrors;
        if (first)
        {
            *pval = e;
            first = false;
        }
        else
        {
            /* In order to work successfully with UDTs,
             * build expressions to do the comparisons,
             * and let the semantic analyzer and constant
             * folder give us the result.
             */

            /* Compute:
             *   if (e > maxval)
             *      maxval = e;
             */
            Expression *ec = new CmpExp(id == Id::max ? TOKgt : TOKlt, em->loc, e, *pval);
            ec = ec->semantic(sce);
            ec = ec->ctfeInterpret();
            if (ec->toInteger())
                *pval = e;
        }
    }
    return *pval;

Lerrors:
    *pval = new ErrorExp();
    return *pval;
}

Expression *EnumDeclaration::getDefaultValue(Loc loc)
{
    //printf("EnumDeclaration::getDefaultValue()\n");
    if (defaultval)
        return defaultval;

    if (scope)
        semantic(scope);
    if (errors)
        goto Lerrors;
    if (semanticRun == PASSinit || !members)
    {
        error(loc, "forward reference of %s.init", toChars());
        goto Lerrors;
    }

    for (size_t i = 0; i < members->dim; i++)
    {
        EnumMember *em = (*members)[i]->isEnumMember();
        if (!em)
            continue;
        defaultval = em->value;
        return defaultval;
    }

Lerrors:
    defaultval = new ErrorExp();
    return defaultval;
}

Type *EnumDeclaration::getMemtype(Loc loc)
{
    if (loc.linnum == 0)
        loc = this->loc;
    if (scope)
    {   /* Enum is forward referenced. We don't need to resolve the whole thing,
         * just the base type
         */
        if (memtype)
            memtype = memtype->semantic(loc, scope);
        else
        {
            if (!isAnonymous())
                memtype = Type::tint32;
        }
    }
    if (!memtype)
    {
        error(loc, "is forward referenced");
        return Type::terror;
    }
    return memtype;
}

bool EnumDeclaration::oneMember(Dsymbol **ps, Identifier *ident)
{
    if (isAnonymous())
        return Dsymbol::oneMembers(members, ps, ident);
    return Dsymbol::oneMember(ps, ident);
}

void EnumDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("enum ");
    if (ident)
    {   buf->writestring(ident->toChars());
        buf->writeByte(' ');
    }
    if (memtype)
    {
        buf->writestring(": ");
        memtype->toCBuffer(buf, NULL, hgs);
    }
    if (!members)
    {
        buf->writeByte(';');
        buf->writenl();
        return;
    }
    buf->writenl();
    buf->writeByte('{');
    buf->writenl();
    buf->level++;
    for (size_t i = 0; i < members->dim; i++)
    {
        EnumMember *em = (*members)[i]->isEnumMember();
        if (!em)
            continue;
        em->toCBuffer(buf, hgs);
        buf->writeByte(',');
        buf->writenl();
    }
    buf->level--;
    buf->writeByte('}');
    buf->writenl();
}

Type *EnumDeclaration::getType()
{
    return type;
}

const char *EnumDeclaration::kind()
{
    return "enum";
}

bool EnumDeclaration::isDeprecated()
{
    return isdeprecated;
}

PROT EnumDeclaration::prot()
{
    return protection;
}

Dsymbol *EnumDeclaration::search(Loc loc, Identifier *ident, int flags)
{
    //printf("%s.EnumDeclaration::search('%s')\n", toChars(), ident->toChars());
    if (scope)
        // Try one last time to resolve this enum
        semantic(scope);

    if (!members || !symtab || scope)
    {   error("is forward referenced when looking for '%s'", ident->toChars());
        //*(char*)0=0;
        return NULL;
    }

    Dsymbol *s = ScopeDsymbol::search(loc, ident, flags);
    return s;
}

/********************************* EnumMember ****************************/

EnumMember::EnumMember(Loc loc, Identifier *id, Expression *value, Type *type)
    : Dsymbol(id)
{
    this->ed = NULL;
    this->value = value;
    this->type = type;
    this->loc = loc;
    this->vd = NULL;
}

Dsymbol *EnumMember::syntaxCopy(Dsymbol *s)
{
    Expression *e = NULL;
    if (value)
        e = value->syntaxCopy();

    Type *t = NULL;
    if (type)
        t = type->syntaxCopy();

    EnumMember *em;
    if (s)
    {   em = (EnumMember *)s;
        em->loc = loc;
        em->value = e;
        em->type = t;
    }
    else
        em = new EnumMember(loc, ident, e, t);
    return em;
}

void EnumMember::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    if (type)
        type->toCBuffer(buf, ident, hgs);
    else
        buf->writestring(ident->toChars());
    if (value)
    {
        buf->writestring(" = ");
        value->toCBuffer(buf, hgs);
    }
}

const char *EnumMember::kind()
{
    return "enum member";
}

void EnumMember::semantic(Scope *sc)
{
    assert(ed);
    if (this->vd)
        return;
    ed->semantic(sc);
    assert(value);
    vd = new VarDeclaration(loc, type, ident, new ExpInitializer(loc, value->copy()));

    vd->storage_class = STCmanifest;
    vd->semantic(sc);

    vd->protection = ed->isAnonymous() ? ed->protection : PROTpublic;
    vd->parent = ed->isAnonymous() ? ed->parent : ed;
    vd->userAttributes = ed->isAnonymous() ? ed->userAttributes : NULL;

    if (errors)
        vd->errors = true;
}

Expression *EnumMember::getVarExp(Loc loc, Scope *sc)
{
    semantic(sc);
    assert(vd);
    if (errors)
        return new ErrorExp();
    Expression *e = new VarExp(loc, vd);
    return e->semantic(sc);
}
