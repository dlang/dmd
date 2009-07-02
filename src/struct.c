
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include "root.h"
#include "aggregate.h"

/********************************* AggregateDeclaration ****************************/

AggregateDeclaration::AggregateDeclaration(Identifier *id)
    : ScopeDsymbol(id)
{
    type = NULL;
    handle = NULL;
    structsize = 0;		// size of struct
    alignsize = 0;		// size of struct for alignment purposes
    structalign = 0;		// struct member alignment in effect
    sizeok = 0;			// size not determined yet
    inv = NULL;
    aggNew = NULL;
    aggDelete = NULL;

    stag = NULL;
    sinit = NULL;
}

void AggregateDeclaration::semantic2(Scope *sc)
{   int i;

    //printf("AggregateDeclaration::semantic2(%s)\n", toChars());
    if (members)
    {
	sc = sc->push(this);
	for (i = 0; i < members->dim; i++)
	{
	    Dsymbol *s = (Dsymbol *)members->data[i];
	    s->semantic2(sc);
	}
	sc->pop();
    }
}

void AggregateDeclaration::semantic3(Scope *sc)
{   int i;

    //printf("AggregateDeclaration::semantic3(%s)\n", toChars());
    if (members)
    {
	sc = sc->push(this);
	for (i = 0; i < members->dim; i++)
	{
	    Dsymbol *s = (Dsymbol *)members->data[i];
	    s->semantic3(sc);
	}
	sc->pop();
    }
}

void AggregateDeclaration::inlineScan()
{   int i;

    //printf("AggregateDeclaration::inlineScan(%s)\n", toChars());
    if (members)
    {
	for (i = 0; i < members->dim; i++)
	{
	    Dsymbol *s = (Dsymbol *)members->data[i];
	    s->inlineScan();
	}
    }
}

unsigned AggregateDeclaration::size()
{
    //printf("AggregateDeclaration::size() = %d\n", structsize);
    if (!members)
	error("unknown size");
    if (!sizeok)
	error("no size yet for forward reference");
    return structsize;
}

Type *AggregateDeclaration::getType()
{
    return type;
}


/****************************
 * Do byte or word alignment as necessary.
 * Align sizes of 0, as we may not know array sizes yet.
 */

void AggregateDeclaration::alignmember(unsigned salign, unsigned size, unsigned *poffset)
{
    //printf("salign = %d, size = %d, offset = %d\n",salign,size,offset);
    if (salign > 1)
    {	int sa;

	switch (size)
	{   case 1:
		break;
	    case 2:
	    case_2:
		*poffset = (*poffset + 1) & ~1;	// align to word
		break;
	    case 3:
	    case 4:
		if (salign == 2)
		    goto case_2;
		*poffset = (*poffset + 3) & ~3;	// align to dword
		break;
	    default:
		*poffset = (*poffset + salign - 1) & ~(salign - 1);
		break;
	}
    }
    //printf("result = %d\n",offset);
}

/********************************* StructDeclaration ****************************/

StructDeclaration::StructDeclaration(Identifier *id)
    : AggregateDeclaration(id)
{
    // For forward references
    type = new TypeStruct(this);
}

Dsymbol *StructDeclaration::syntaxCopy(Dsymbol *s)
{
    StructDeclaration *sd;

    if (s)
	sd = (StructDeclaration *)s;
    else
	sd = new StructDeclaration(ident);
    ScopeDsymbol::syntaxCopy(sd);
    return sd;
}

void StructDeclaration::semantic(Scope *sc)
{   int i;
    Scope *sc2;

    //printf("+StructDeclaration::semantic(this=%p, '%s')\n", this, toChars());
    if (!type)
	type = new TypeStruct(this);
    if (!members)			// if forward reference
	return;
    if (!symtab)			// if not already done semantic()
    {
	parent = sc->parent;
	handle = type->pointerTo();
	symtab = new DsymbolTable();
	structalign = sc->structalign;
	if (!isAnonymous())
	{
	    for (i = 0; i < members->dim; i++)
	    {
		Dsymbol *s = (Dsymbol *)members->data[i];
//printf("adding member '%s' to '%s'\n", s->toChars(), this->toChars());
		s->addMember(this);
	    }
	}
	sc2 = sc->push(this);
	sc2->parent = this;
	if (isUnion())
	    sc2->inunion = 1;
	sc2->stc &= ~(STCauto | STCstatic);
	for (i = 0; i < members->dim; i++)
	{
	    Dsymbol *s = (Dsymbol *)members->data[i];
	    s->semantic(sc2);
	    if (isUnion())
		sc2->offset = 0;
	}
	sc2->pop();

	// 0 sized struct's are set to 1 byte
	if (structsize == 0)
	{
	    structsize = 1;
	    alignsize = 1;
	}
	sizeok = 1;
    }

    AggregateDeclaration *sd;

    if (isAnonymous() &&
	(sd = isMember()) != NULL)
    {	// Anonymous structures aren't independent, all their members are
	// added to the enclosing struct.
	unsigned offset;
	int isunionsave;
	int i;

	// Align size of enclosing struct
	sd->alignmember(structalign, alignsize, &sd->structsize);

	// Add members to enclosing struct
	for (i = 0; i < fields.dim; i++)
	{
	    Dsymbol *s = (Dsymbol *)fields.data[i];
	    VarDeclaration *vd = s->isVarDeclaration();
	    if (vd)
	    {
		vd->addMember(sd);
		vd->offset += sd->structsize;
		sd->fields.push(vd);
	    }
	    else
		error("only fields allowed in anonymous struct");
	}

	sd->structsize += structsize;
	sc->offset = sd->structsize;

	if (sd->alignsize < alignsize)
	    sd->alignsize = alignsize;
    }
    //printf("-StructDeclaration::semantic(this=%p, '%s')\n", this, toChars());

    if (sc->func)
    {
	semantic2(sc);
	semantic3(sc);
    }
}

void StructDeclaration::toCBuffer(OutBuffer *buf)
{   int i;

    buf->printf("%s %s", kind(), toChars());
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
	Dsymbol *s = (Dsymbol *)members->data[i];

	buf->writestring("    ");
	s->toCBuffer(buf);
    }
    buf->writeByte('}');
    buf->writenl();
}

int StructDeclaration::isUnion()
{
    return 0;
}

char *StructDeclaration::kind()
{
    return "struct";
}

/********************************* UnionDeclaration ****************************/

UnionDeclaration::UnionDeclaration(Identifier *id)
    : StructDeclaration(id)
{
}

Dsymbol *UnionDeclaration::syntaxCopy(Dsymbol *s)
{
    UnionDeclaration *ud;

    if (s)
	ud = (UnionDeclaration *)s;
    else
	ud = new UnionDeclaration(ident);
    StructDeclaration::syntaxCopy(ud);
    return ud;
}

int UnionDeclaration::isUnion()
{
    return 1;
}

char *UnionDeclaration::kind()
{
    return "union";
}


