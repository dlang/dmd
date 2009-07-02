
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include "root.h"
#include "enum.h"

/********************************* EnumDeclaration ****************************/

EnumDeclaration::EnumDeclaration(Identifier *id, Type *memtype)
    : ScopeDsymbol(id)
{
    type = new TypeEnum(this);
    this->memtype = memtype;
    maxval = 0;
    minval = 0x7FFFFFFF;		// BUG: long long max?
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
	ed = new EnumDeclaration(ident, t);
    ScopeDsymbol::syntaxCopy(ed);
    return ed;
}

void EnumDeclaration::addMember(ScopeDsymbol *sd)
{   int i;

    //printf("EnumDeclaration::addMember(sd = %p, '%s')\n", sd, sd->toChars());
    if (!isAnonymous())
	Dsymbol::addMember(sd);
}

void EnumDeclaration::semantic(Scope *sc)
{   int i;
    integer_t number;
    Type *t;

    //printf("EnumDeclaration::semantic(sd = %p, '%s')\n", sc->scopesym, sc->scopesym->toChars());
    if (symtab)			// if already done
	return;
    if (!memtype)
	memtype = Type::tint32;
    parent = sc->scopesym;
    memtype = memtype->semantic(loc, sc);
    t = isAnonymous() ? memtype : type;
    symtab = new DsymbolTable();
    sc = sc->push(this);
    sc->parent = this;
    number = 0;
    if (members->dim == 0)
	error("enum %s must have at least one member", toChars());
    for (i = 0; i < members->dim; i++)
    {
	EnumMember *em = (EnumMember *)members->data[i];
	Expression *e;

	//printf("Inserting '%s' into table\n",em->toChars());
	if (isAnonymous())
	    //em->addMember((ScopeDsymbol *)parent);
	    sc->enclosing->insert(em);
	else
	    em->addMember(this);
	e = em->value;
	if (e)
	{
	    e = e->semantic(sc);
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
	if (number < minval)
	    minval = number;
	if (number > maxval)
	    maxval = number;
	if (i == 0)
	    defaultval = number;

	number++;
    }
    //members->print();
    sc->pop();
}

void EnumDeclaration::toCBuffer(OutBuffer *buf)
{   int i;

    buf->writestring("enum ");
    if (ident)
    {	buf->writestring(ident->toChars());
	buf->writeByte(' ');
    }
    if (memtype)
    {
	buf->writestring(": ");
	memtype->toCBuffer(buf, NULL);
    }
    buf->writenl();
    buf->writeByte('{');
    buf->writenl();
    for (i = 0; i < members->dim; i++)
    {
	EnumMember *em = (EnumMember *)members->data[i];
	buf->writestring("    ");
	em->toCBuffer(buf);
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

void EnumMember::toCBuffer(OutBuffer *buf)
{
    buf->writestring(ident->toChars());
    if (value)
    {
	buf->writestring(" = ");
	value->toCBuffer(buf);
    }
}

char *EnumMember::kind()
{
    return "enum member";
}


