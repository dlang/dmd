
// Copyright (c) 1999-2004 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#include "declaration.h"
#include "init.h"
#include "attrib.h"
#include "debcond.h"
#include "scope.h"
#include "id.h"
#include "expression.h"
#include "dsymbol.h"


/********************************* AttribDeclaration ****************************/

AttribDeclaration::AttribDeclaration(Array *decl)
	: Dsymbol()
{
    this->decl = decl;
}

int AttribDeclaration::include()
{
    return TRUE;
}

void AttribDeclaration::addMember(ScopeDsymbol *sd)
{
    unsigned i;

    if (include() && decl)
    {
	for (i = 0; i < decl->dim; i++)
	{   Dsymbol *s;

	    s = (Dsymbol *)decl->data[i];
	    s->addMember(sd);
	}
    }
}

void AttribDeclaration::semantic2(Scope *sc)
{
    unsigned i;

    if (include() && decl)
    {
	for (i = 0; i < decl->dim; i++)
	{   Dsymbol *s;

	    s = (Dsymbol *)decl->data[i];
	    s->semantic2(sc);
	}
    }
}

void AttribDeclaration::semantic3(Scope *sc)
{
    unsigned i;

    if (include() && decl)
    {
	for (i = 0; i < decl->dim; i++)
	{   Dsymbol *s;

	    s = (Dsymbol *)decl->data[i];
	    s->semantic3(sc);
	}
    }
}

void AttribDeclaration::inlineScan()
{
    unsigned i;

    if (include() && decl)
    {
	for (i = 0; i < decl->dim; i++)
	{   Dsymbol *s;

	    s = (Dsymbol *)decl->data[i];
	    s->inlineScan();
	}
    }
}

void AttribDeclaration::toObjFile()
{
    unsigned i;

    if (include() && decl)
    {
	for (i = 0; i < decl->dim; i++)
	{   Dsymbol *s;

	    s = (Dsymbol *)decl->data[i];
	    s->toObjFile();
	}
    }
}

char *AttribDeclaration::kind()
{
    return "attribute";
}

Dsymbol *AttribDeclaration::oneMember()
{   Dsymbol *s;

    if (decl && decl->dim == 1)
    {	s = (Dsymbol *)decl->data[0];
	return s->oneMember();
    }
    return NULL;
}

void AttribDeclaration::toCBuffer(OutBuffer *buf)
{
    if (decl)
    {
	buf->writenl();
	buf->writeByte('{');
	buf->writenl();
	for (unsigned i = 0; i < decl->dim; i++)
	{
	    Dsymbol *s = (Dsymbol *)decl->data[i];

	    buf->writestring("    ");
	    s->toCBuffer(buf);
	}
	buf->writeByte('}');
    }
    else
	buf->writeByte(':');
    buf->writenl();
}

/********************************* StorageClassDeclaration ****************************/

StorageClassDeclaration::StorageClassDeclaration(unsigned stc, Array *decl)
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

void StorageClassDeclaration::semantic(Scope *sc)
{
    if (decl)
    {	unsigned stc_save = sc->stc;

	sc->stc = stc;
	for (unsigned i = 0; i < decl->dim; i++)
	{
	    Dsymbol *s = (Dsymbol *)decl->data[i];

	    s->semantic(sc);
	}
	sc->stc = stc_save;
    }
    else
	sc->stc = stc;
}

void StorageClassDeclaration::toCBuffer(OutBuffer *buf)
{
    buf->writestring("BUG: storage class goes here");	// BUG
    AttribDeclaration::toCBuffer(buf);
}

/********************************* LinkDeclaration ****************************/

LinkDeclaration::LinkDeclaration(enum LINK p, Array *decl)
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

void LinkDeclaration::semantic(Scope *sc)
{
    //printf("LinkDeclaration::semantic(linkage = %d, decl = %p)\n", linkage, decl);
    if (decl)
    {	enum LINK linkage_save = sc->linkage;

	sc->linkage = linkage;
	for (unsigned i = 0; i < decl->dim; i++)
	{
	    Dsymbol *s = (Dsymbol *)decl->data[i];

	    s->semantic(sc);
	}
	sc->linkage = linkage_save;
    }
    else
    {
	sc->linkage = linkage;
    }
}

void LinkDeclaration::semantic3(Scope *sc)
{
    //printf("LinkDeclaration::semantic3(linkage = %d, decl = %p)\n", linkage, decl);
    if (decl)
    {	enum LINK linkage_save = sc->linkage;

	sc->linkage = linkage;
	for (unsigned i = 0; i < decl->dim; i++)
	{
	    Dsymbol *s = (Dsymbol *)decl->data[i];

	    s->semantic3(sc);
	}
	sc->linkage = linkage_save;
    }
    else
    {
	sc->linkage = linkage;
    }
}

void LinkDeclaration::toCBuffer(OutBuffer *buf)
{   char *p;

    switch (linkage)
    {
	case LINKd:		p = "D";		break;
	case LINKc:		p = "C";		break;
	case LINKcpp:		p = "C++";		break;
	case LINKwindows:	p = "Windows";		break;
	case LINKpascal:	p = "Pascal";		break;
	default:
	    assert(0);
	    break;
    }
    buf->writestring("extern ");
    buf->writestring(p);
    AttribDeclaration::toCBuffer(buf);
}

char *LinkDeclaration::toChars()
{
    return "extern ()";
}

/********************************* ProtDeclaration ****************************/

ProtDeclaration::ProtDeclaration(enum PROT p, Array *decl)
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

void ProtDeclaration::semantic(Scope *sc)
{
    if (decl)
    {	enum PROT protection_save = sc->protection;

	sc->protection = protection;
	for (unsigned i = 0; i < decl->dim; i++)
	{
	    Dsymbol *s = (Dsymbol *)decl->data[i];

	    s->semantic(sc);
	}
	sc->protection = protection_save;
    }
    else
	sc->protection = protection;
}

void ProtDeclaration::toCBuffer(OutBuffer *buf)
{   char *p;

    switch (protection)
    {
	case PROTprivate:	p = "private";		break;
	case PROTprotected:	p = "protected";	break;
	case PROTpublic:	p = "public";		break;
	case PROTexport:	p = "export";		break;
	default:
	    assert(0);
	    break;
    }
    buf->writestring(p);
    AttribDeclaration::toCBuffer(buf);
}

/********************************* AlignDeclaration ****************************/

AlignDeclaration::AlignDeclaration(unsigned sa, Array *decl)
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

void AlignDeclaration::semantic(Scope *sc)
{
    //printf("\tAlignDeclaration::semantic '%s'\n",toChars());
    if (decl)
    {	unsigned salign_save = sc->structalign;

	sc->structalign = salign;
	for (unsigned i = 0; i < decl->dim; i++)
	{
	    Dsymbol *s = (Dsymbol *)decl->data[i];

	    s->semantic(sc);
	}
	sc->structalign = salign_save;
    }
    else
	sc->structalign = salign;
}


void AlignDeclaration::toCBuffer(OutBuffer *buf)
{
    buf->printf("align %d", salign);
    AttribDeclaration::toCBuffer(buf);
}

/********************************* PragmaDeclaration ****************************/

PragmaDeclaration::PragmaDeclaration(Identifier *ident, Array *args, Array *decl)
	: AttribDeclaration(decl)
{
    this->ident = ident;
    this->args = args;
}

Dsymbol *PragmaDeclaration::syntaxCopy(Dsymbol *s)
{
    PragmaDeclaration *pd;

    assert(!s);
    pd = new PragmaDeclaration(ident,
	Expression::arraySyntaxCopy(args), Dsymbol::arraySyntaxCopy(decl));
    return pd;
}

void PragmaDeclaration::semantic(Scope *sc)
{
    //printf("\tPragmaDeclaration::semantic '%s'\n",toChars());
    if (ident == Id::msg)
    {
	if (args)
	{
	    for (size_t i = 0; i < args->dim; i++)
	    {
		Expression *e = (Expression *)args->data[i];

		e = e->semantic(sc);
		if (e->op == TOKstring)
		{
		    StringExp *se = (StringExp *)e;
		    printf("%.*s", se->len, se->string);
		}
		else
		    error("string expected for pragma msg, not '%s'", e->toChars());
	    }
	    printf("\n");
	}
    }
    else
	error("unrecognized pragma(%s)", ident->toChars());

    if (decl)
    {
	for (unsigned i = 0; i < decl->dim; i++)
	{
	    Dsymbol *s = (Dsymbol *)decl->data[i];

	    s->semantic(sc);
	}
    }
}


void PragmaDeclaration::toCBuffer(OutBuffer *buf)
{
    buf->printf("pragma(%s", ident->toChars());
    if (args)
    {
	for (size_t i = 0; i < args->dim; i++)
	{
	    Expression *e = (Expression *)args->data[i];

	    buf->printf(", %s", e->toChars());
	}
    }
    buf->writestring(")");
    AttribDeclaration::toCBuffer(buf);
}


/********************************* DebugDeclaration ****************************/

DebugDeclaration::DebugDeclaration(Condition *condition, Array *decl, Array *elsedecl)
	: AttribDeclaration(decl)
{
    //printf("DebugDeclaration::DebugDeclaration()\n");
    this->condition = condition;
    this->elsedecl = elsedecl;
}

Dsymbol *DebugDeclaration::syntaxCopy(Dsymbol *s)
{
    DebugDeclaration *dd;

    assert(!s);
    dd = new DebugDeclaration(condition,
	Dsymbol::arraySyntaxCopy(decl),
	Dsymbol::arraySyntaxCopy(elsedecl));
    return dd;
}


// Decide if debug code should be included

int DebugDeclaration::include()
{
    assert(condition);
    return condition->include();
}

void DebugDeclaration::addMember(ScopeDsymbol *sd)
{
    unsigned i;
    Array *d = include() ? decl : elsedecl;

    if (d)
    {
	for (i = 0; i < d->dim; i++)
	{   Dsymbol *s;

	    s = (Dsymbol *)d->data[i];
	    s->addMember(sd);
	}
    }
}

void DebugDeclaration::semantic(Scope *sc)
{
    Array *d = include() ? decl : elsedecl;

    //printf("\tDebugDeclaration::semantic '%s'\n",toChars());
    if (d)
    {
	for (unsigned i = 0; i < d->dim; i++)
	{
	    Dsymbol *s = (Dsymbol *)d->data[i];

	    s->semantic(sc);
	}
    }
}


void DebugDeclaration::semantic2(Scope *sc)
{
    unsigned i;
    Array *d = include() ? decl : elsedecl;

    if (d)
    {
	for (i = 0; i < d->dim; i++)
	{   Dsymbol *s;

	    s = (Dsymbol *)d->data[i];
	    s->semantic2(sc);
	}
    }
}

void DebugDeclaration::semantic3(Scope *sc)
{
    unsigned i;
    Array *d = include() ? decl : elsedecl;

    if (d)
    {
	for (i = 0; i < d->dim; i++)
	{   Dsymbol *s;

	    s = (Dsymbol *)d->data[i];
	    s->semantic3(sc);
	}
    }
}

void DebugDeclaration::toObjFile()
{
    unsigned i;
    Array *d = include() ? decl : elsedecl;

    if (d)
    {
	for (i = 0; i < d->dim; i++)
	{   Dsymbol *s;

	    s = (Dsymbol *)d->data[i];
	    s->toObjFile();
	}
    }
}

void DebugDeclaration::toCBuffer(OutBuffer *buf)
{
    if (isVersionDeclaration())
	buf->writestring("version(");
    else
	buf->writestring("debug(");
    condition->toCBuffer(buf);
    buf->writeByte(')');
    if (decl || elsedecl)
    {
	buf->writenl();
	buf->writeByte('{');
	buf->writenl();
	if (decl)
	{
	    for (unsigned i = 0; i < decl->dim; i++)
	    {
		Dsymbol *s = (Dsymbol *)decl->data[i];

		buf->writestring("    ");
		s->toCBuffer(buf);
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
		Dsymbol *s = (Dsymbol *)elsedecl->data[i];

		buf->writestring("    ");
		s->toCBuffer(buf);
	    }
	    buf->writeByte('}');
	}
    }
    else
	buf->writeByte(':');
    buf->writenl();
}


/********************************* VersionDeclaration ****************************/

VersionDeclaration::VersionDeclaration(Condition *condition, Array *decl, Array *elsedecl)
	: DebugDeclaration(condition, decl, elsedecl)
{
    //printf("VersionDeclaration::VersionDeclaration()\n");
}

Dsymbol *VersionDeclaration::syntaxCopy(Dsymbol *s)
{
    VersionDeclaration *vd;

    assert(!s);
    vd = new VersionDeclaration(condition,
	Dsymbol::arraySyntaxCopy(decl),
	Dsymbol::arraySyntaxCopy(elsedecl));
    return vd;
}


