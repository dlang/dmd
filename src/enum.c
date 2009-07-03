
// Copyright (c) 1999-2006 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <assert.h>

#include "root.h"
#include "enum.h"
#include "mtype.h"
#include "scope.h"

/********************************* EnumDeclaration ****************************/

EnumDeclaration::EnumDeclaration(Loc loc, Identifier *id, Type *memtype)
    : ScopeDsymbol(id)
{
    this->loc = loc;
    type = new TypeEnum(this);
    this->memtype = memtype;
    maxval = 0;
    minval = 0;
    defaultval = 0;
}

Dsymbol *EnumDeclaration::syntaxCopy(Dsymbol *s)
{
    Type *t = NULL;
    if (memtype)
	t = memtype->syntaxCopy();

    EnumDeclaration *ed;
    if (s)
    {	ed = (EnumDeclaration *)s;
	ed->memtype = t;
    }
    else
	ed = new EnumDeclaration(loc, ident, t);
    ScopeDsymbol::syntaxCopy(ed);
    return ed;
}

void EnumDeclaration::semantic(Scope *sc)
{   int i;
    uinteger_t number;
    Type *t;
    Scope *sce;

    //printf("EnumDeclaration::semantic(sd = %p, '%s')\n", sc->scopesym, sc->scopesym->toChars());
    if (symtab)			// if already done
	return;
    if (!memtype)
	memtype = Type::tint32;
    parent = sc->scopesym;
    memtype = memtype->semantic(loc, sc);

    /* Check to see if memtype is forward referenced
     */
    if (memtype->ty == Tenum)
    {	EnumDeclaration *sym = (EnumDeclaration *)memtype->toDsymbol(sc);
	if (!sym->memtype)
	{
	    error("base enum %s is forward referenced", sym->toChars());
	    memtype = Type::tint32;
	}
    }

    if (!memtype->isintegral())
	error("base type must be of integral type, not %s", memtype->toChars());

    t = isAnonymous() ? memtype : type;
    symtab = new DsymbolTable();
    sce = sc->push(this);
    sce->parent = this;
    number = 0;
    if (!members)		// enum ident;
	return;
    if (members->dim == 0)
	error("enum %s must have at least one member", toChars());
    int first = 1;
    for (i = 0; i < members->dim; i++)
    {
	EnumMember *em = ((Dsymbol *)members->data[i])->isEnumMember();
	Expression *e;

	if (!em)
	    /* The e->semantic(sce) can insert other symbols, such as
	     * template instances and function literals.
	     */
	    continue;

	//printf("Enum member '%s'\n",em->toChars());
	e = em->value;
	if (e)
	{
	    assert(e->dyncast() == DYNCAST_EXPRESSION);
	    e = e->semantic(sce);
	    e = e->implicitCastTo(memtype);
	    e = e->optimize(WANTvalue);
	    number = e->toInteger();
	    e->type = t;
	}
	else
	{   // Default is the previous number plus 1
	    e = new IntegerExp(em->loc, number, t);
	}
	em->value = e;

	// Add to symbol table only after evaluating 'value'
	if (isAnonymous())
	{
	    //sce->enclosing->insert(em);
	    for (Scope *scx = sce->enclosing; scx; scx = scx->enclosing)
	    {
		if (scx->scopesym)
		{
		    if (!scx->scopesym->symtab)
			scx->scopesym->symtab = new DsymbolTable();
		    em->addMember(sce, scx->scopesym, 1);
		    break;
		}
	    }
	}
	else
	    em->addMember(sc, this, 1);

	if (first)
	{   first = 0;
	    defaultval = number;
	    minval = number;
	    maxval = number;
	}
	else if (memtype->isunsigned())
	{
	    if (number < minval)
		minval = number;
	    if (number > maxval)
		maxval = number;
	}
	else
	{
	    if ((sinteger_t)number < (sinteger_t)minval)
		minval = number;
	    if ((sinteger_t)number > (sinteger_t)maxval)
		maxval = number;
	}

	number++;
    }
    //printf("defaultval = %lld\n", defaultval);

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
{   int i;

    buf->writestring("enum ");
    if (ident)
    {	buf->writestring(ident->toChars());
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
    for (i = 0; i < members->dim; i++)
    {
	EnumMember *em = ((Dsymbol *)members->data[i])->isEnumMember();
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

char *EnumDeclaration::kind()
{
    return "enum";
}

/********************************* EnumMember ****************************/

EnumMember::EnumMember(Loc loc, Identifier *id, Expression *value)
    : Dsymbol(id)
{
    this->value = value;
    this->loc = loc;
}

Dsymbol *EnumMember::syntaxCopy(Dsymbol *s)
{
    Expression *e = NULL;
    if (value)
	e = value->syntaxCopy();

    EnumMember *em;
    if (s)
    {	em = (EnumMember *)s;
	em->loc = loc;
	em->value = e;
    }
    else
	em = new EnumMember(loc, ident, e);
    return em;
}

void EnumMember::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring(ident->toChars());
    if (value)
    {
	buf->writestring(" = ");
	value->toCBuffer(buf, hgs);
    }
}

char *EnumMember::kind()
{
    return "enum member";
}


