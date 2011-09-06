
// Copyright (c) 1999-2011 by Digital Mars
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
    isdeprecated = 0;
    isdone = 0;
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
    return ed;
}

void EnumDeclaration::semantic0(Scope *sc)
{
    /* This function is a hack to get around a significant problem.
     * The members of anonymous enums, like:
     *  enum { A, B, C }
     * don't get installed into the symbol table until after they are
     * semantically analyzed, yet they're supposed to go into the enclosing
     * scope's table. Hence, when forward referenced, they come out as
     * 'undefined'. The real fix is to add them in at addSymbol() time.
     * But to get code to compile, we'll just do this quick hack at the moment
     * to compile it if it doesn't depend on anything else.
     */

    if (isdone || !scope)
        return;
    if (!isAnonymous() || memtype)
        return;
    for (size_t i = 0; i < members->dim; i++)
    {
        EnumMember *em = (*members)[i]->isEnumMember();
        if (em && (em->type || em->value))
            return;
    }

    // Can do it
    semantic(sc);
}

void EnumDeclaration::semantic(Scope *sc)
{
    Type *t;
    Scope *sce;

    //printf("EnumDeclaration::semantic(sd = %p, '%s') %s\n", sc->scopesym, sc->scopesym->toChars(), toChars());
    //printf("EnumDeclaration::semantic() %s\n", toChars());
    if (!members)               // enum ident;
        return;

    if (!memtype && !isAnonymous())
    {   // Set memtype if we can to reduce fwd reference errors
        memtype = Type::tint32; // case 1)  enum ident { ... }
    }

    if (symtab)                 // if already done
    {   if (isdone || !scope)
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
        isdeprecated = 1;

    parent = sc->parent;

    /* The separate, and distinct, cases are:
     *  1. enum { ... }
     *  2. enum : memtype { ... }
     *  3. enum ident { ... }
     *  4. enum ident : memtype { ... }
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
#if 0   // Decided to abandon this restriction for D 2.0
        if (!memtype->isintegral())
        {   error("base type must be of integral type, not %s", memtype->toChars());
            memtype = Type::tint32;
        }
#endif
    }

    isdone = 1;
    Module::dprogress++;

    type = type->semantic(loc, sc);
    if (isAnonymous())
        sce = sc;
    else
    {   sce = sc->push(this);
        sce->parent = this;
    }
    if (members->dim == 0)
        error("enum %s must have at least one member", toChars());
    int first = 1;
    Expression *elast = NULL;
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
            e = e->optimize(WANTvalue | WANTinterpret);
            if (memtype)
            {
                e = e->implicitCastTo(sce, memtype);
                e = e->optimize(WANTvalue | WANTinterpret);
                if (!isAnonymous())
                    e = e->castTo(sce, type);
                t = memtype;
            }
            else if (em->type)
            {
                e = e->implicitCastTo(sce, em->type);
                e = e->optimize(WANTvalue | WANTinterpret);
                assert(isAnonymous());
                t = e->type;
            }
            else
                t = e->type;
        }
        else if (first)
        {
            if (memtype)
                t = memtype;
            else if (em->type)
                t = em->type;
            else
                t = Type::tint32;
            e = new IntegerExp(em->loc, 0, Type::tint32);
            e = e->implicitCastTo(sce, t);
            e = e->optimize(WANTvalue | WANTinterpret);
            if (!isAnonymous())
                e = e->castTo(sce, type);
        }
        else
        {
            // Set value to (elast + 1).
            // But first check that (elast != t.max)
            assert(elast);
            e = new EqualExp(TOKequal, em->loc, elast, t->getProperty(0, Id::max));
            e = e->semantic(sce);
            e = e->optimize(WANTvalue | WANTinterpret);
            if (e->toInteger())
                error("overflow of enum value %s", elast->toChars());

            // Now set e to (elast + 1)
            e = new AddExp(em->loc, elast, new IntegerExp(em->loc, 1, Type::tint32));
            e = e->semantic(sce);
            e = e->castTo(sce, elast->type);
            e = e->optimize(WANTvalue | WANTinterpret);
        }
        elast = e;
        em->value = e;

        // Add to symbol table only after evaluating 'value'
        if (isAnonymous())
        {
            /* Anonymous enum members get added to enclosing scope.
             */
            for (Scope *sct = sce; sct; sct = sct->enclosing)
            {
                if (sct->scopesym)
                {
                    if (!sct->scopesym->symtab)
                        sct->scopesym->symtab = new DsymbolTable();
                    em->addMember(sce, sct->scopesym, 1);
                    break;
                }
            }
        }
        else
            em->addMember(sc, this, 1);

        /* Compute .min, .max and .default values.
         * If enum doesn't have a name, we can never identify the enum type,
         * so there is no purpose for a .min, .max or .default
         */
        if (!isAnonymous())
        {
            if (first)
            {   defaultval = e;
                minval = e;
                maxval = e;
            }
            else
            {   Expression *ec;

                /* In order to work successfully with UDTs,
                 * build expressions to do the comparisons,
                 * and let the semantic analyzer and constant
                 * folder give us the result.
                 */

                // Compute if(e < minval)
                ec = new CmpExp(TOKlt, em->loc, e, minval);
                ec = ec->semantic(sce);
                ec = ec->optimize(WANTvalue | WANTinterpret);
                if (ec->toInteger())
                    minval = e;

                ec = new CmpExp(TOKgt, em->loc, e, maxval);
                ec = ec->semantic(sce);
                ec = ec->optimize(WANTvalue | WANTinterpret);
                if (ec->toInteger())
                    maxval = e;
            }
        }
        first = 0;
    }
    //printf("defaultval = %lld\n", defaultval);

    //if (defaultval) printf("defaultval: %s %s\n", defaultval->toChars(), defaultval->type->toChars());
    if (sc != sce)
        sce->pop();
    //members->print();
}

int EnumDeclaration::oneMember(Dsymbol **ps)
{
    if (isAnonymous())
        return Dsymbol::oneMembers(members, ps);
    return Dsymbol::oneMember(ps);
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
    for (size_t i = 0; i < members->dim; i++)
    {
        EnumMember *em = (*members)[i]->isEnumMember();
        if (!em)
            continue;
        //buf->writestring("    ");
        em->toCBuffer(buf, hgs);
        buf->writeByte(',');
        buf->writenl();
    }
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

int EnumDeclaration::isDeprecated()
{
    return isdeprecated;
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
    this->value = value;
    this->type = type;
    this->loc = loc;
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


