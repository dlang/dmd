
// Copyright (c) 1999-2006 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <stdlib.h>
#include <assert.h>

#if _WIN32 || IN_GCC
#include "mem.h"
#elif linux
#include "../root/mem.h"
#endif

#include "init.h"
#include "declaration.h"
#include "attrib.h"
#include "cond.h"
#include "scope.h"
#include "id.h"
#include "expression.h"
#include "dsymbol.h"
#include "aggregate.h"

extern void obj_includelib(char *name);


/********************************* AttribDeclaration ****************************/

AttribDeclaration::AttribDeclaration(Array *decl)
	: Dsymbol()
{
    this->decl = decl;
}

Array *AttribDeclaration::include(Scope *sc, ScopeDsymbol *sd)
{
    return decl;
}

int AttribDeclaration::addMember(Scope *sc, ScopeDsymbol *sd, int memnum)
{
    unsigned i;
    int m = 0;
    Array *d = include(sc, sd);

    if (d)
    {
	for (i = 0; i < d->dim; i++)
	{   Dsymbol *s;

	    s = (Dsymbol *)d->data[i];
	    m |= s->addMember(sc, sd, m | memnum);
	}
    }
    return m;
}

void AttribDeclaration::semantic(Scope *sc)
{
    Array *d = include(sc, NULL);

    //printf("\tAttribDeclaration::semantic '%s'\n",toChars());
    if (d)
    {
	for (unsigned i = 0; i < d->dim; i++)
	{
	    Dsymbol *s = (Dsymbol *)d->data[i];

	    s->semantic(sc);
	}
    }
}

void AttribDeclaration::semantic2(Scope *sc)
{
    unsigned i;
    Array *d = include(sc, NULL);

    if (d)
    {
	for (i = 0; i < d->dim; i++)
	{   Dsymbol *s;

	    s = (Dsymbol *)d->data[i];
	    s->semantic2(sc);
	}
    }
}

void AttribDeclaration::semantic3(Scope *sc)
{
    unsigned i;
    Array *d = include(sc, NULL);

    if (d)
    {
	for (i = 0; i < d->dim; i++)
	{   Dsymbol *s;

	    s = (Dsymbol *)d->data[i];
	    s->semantic3(sc);
	}
    }
}

void AttribDeclaration::inlineScan()
{
    unsigned i;
    Array *d = include(NULL, NULL);

    if (d)
    {
	for (i = 0; i < d->dim; i++)
	{   Dsymbol *s;

	    s = (Dsymbol *)d->data[i];
	    //printf("AttribDeclaration::inlineScan %s\n", s->toChars());
	    s->inlineScan();
	}
    }
}

void AttribDeclaration::addComment(unsigned char *comment)
{
    if (comment)
    {
	unsigned i;
	Array *d = include(NULL, NULL);

	if (d)
	{
	    for (i = 0; i < d->dim; i++)
	    {   Dsymbol *s;

		s = (Dsymbol *)d->data[i];
		//printf("AttribDeclaration::addComment %s\n", s->toChars());
		s->addComment(comment);
	    }
	}
    }
}

void AttribDeclaration::emitComment(Scope *sc)
{
    //printf("AttribDeclaration::emitComment(sc = %p)\n", sc);

    /* If generating doc comment, skip this because if we're inside
     * a template, then include(NULL, NULL) will fail.
     */
//    if (sc->docbuf)
//	return;

    unsigned i;
    Array *d = include(NULL, NULL);

    if (d)
    {
	for (i = 0; i < d->dim; i++)
	{   Dsymbol *s;

	    s = (Dsymbol *)d->data[i];
	    //printf("AttribDeclaration::emitComment %s\n", s->toChars());
	    s->emitComment(sc);
	}
    }
}

void AttribDeclaration::toObjFile()
{
    unsigned i;
    Array *d = include(NULL, NULL);

    if (d)
    {
	for (i = 0; i < d->dim; i++)
	{   Dsymbol *s;

	    s = (Dsymbol *)d->data[i];
	    s->toObjFile();
	}
    }
}

int AttribDeclaration::cvMember(unsigned char *p)
{
    unsigned i;
    int nwritten = 0;
    int n;
    Array *d = include(NULL, NULL);

    if (d)
    {
	for (i = 0; i < d->dim; i++)
	{   Dsymbol *s;

	    s = (Dsymbol *)d->data[i];
	    n = s->cvMember(p);
	    if (p)
		p += n;
	    nwritten += n;
	}
    }
    return nwritten;
}

char *AttribDeclaration::kind()
{
    return "attribute";
}

int AttribDeclaration::oneMember(Dsymbol **ps)
{
    Array *d = include(NULL, NULL);

    return Dsymbol::oneMembers(d, ps);
}

void AttribDeclaration::checkCtorConstInit()
{
    unsigned i;
    Array *d = include(NULL, NULL);

    if (d)
    {
	for (i = 0; i < d->dim; i++)
	{   Dsymbol *s;

	    s = (Dsymbol *)d->data[i];
	    s->checkCtorConstInit();
	}
    }
}

/****************************************
 */

void AttribDeclaration::addLocalClass(ClassDeclarations *aclasses)
{   unsigned i;
    Array *d = include(NULL, NULL);

    if (d)
    {
	for (i = 0; i < d->dim; i++)
	{   Dsymbol *s;

	    s = (Dsymbol *)d->data[i];
	    s->addLocalClass(aclasses);
	}
    }
}


void AttribDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
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
	    s->toCBuffer(buf, hgs);
	}
	buf->writeByte('}');
    }
    else
	buf->writeByte(':');
    buf->writenl();
}

/************************* StorageClassDeclaration ****************************/

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

	if (stc & (STCauto | STCstatic | STCextern))
	    sc->stc &= ~(STCauto | STCstatic | STCextern);
	sc->stc |= stc;
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

void StorageClassDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    struct SCstring
    {
	int stc;
	enum TOK tok;
    };

    static SCstring table[] =
    {
	{ STCauto,         TOKauto },
	{ STCstatic,       TOKstatic },
	{ STCextern,       TOKextern },
	{ STCconst,        TOKconst },
	{ STCfinal,        TOKfinal },
	{ STCabstract,     TOKabstract },
	{ STCsynchronized, TOKsynchronized },
	{ STCdeprecated,   TOKdeprecated },
	{ STCoverride,     TOKoverride },
    };

    int written = 0;
    for (int i = 0; i < sizeof(table)/sizeof(table[0]); i++)
    {
	if (stc & table[i].stc)
	{
	    if (written)
		buf->writeByte(' ');
	    written = 1;
	    buf->writestring(Token::toChars(table[i].tok));
	}
    }

    AttribDeclaration::toCBuffer(buf, hgs);
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

void LinkDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
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
    buf->writestring("extern (");
    buf->writestring(p);
    buf->writestring(") ");
    AttribDeclaration::toCBuffer(buf, hgs);
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

void ProtDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{   char *p;

    switch (protection)
    {
	case PROTprivate:	p = "private";		break;
	case PROTpackage:	p = "package";		break;
	case PROTprotected:	p = "protected";	break;
	case PROTpublic:	p = "public";		break;
	case PROTexport:	p = "export";		break;
	default:
	    assert(0);
	    break;
    }
    buf->writestring(p);
    AttribDeclaration::toCBuffer(buf, hgs);
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


void AlignDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->printf("align (%d)", salign);
    AttribDeclaration::toCBuffer(buf, hgs);
}

/********************************* AnonDeclaration ****************************/

AnonDeclaration::AnonDeclaration(Loc loc, int isunion, Array *decl)
	: AttribDeclaration(decl)
{
    this->loc = loc;
    this->isunion = isunion;
    this->scope = NULL;
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

    Scope *scx = NULL;
    if (scope)
    {   sc = scope;
	scx = scope;
	scope = NULL;
    }

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

//	printf("\tsc->anonAgg = %p\n", sc->anonAgg);
//	printf("\tad  = %p\n", ad);
//	printf("\taad = %p\n", &aad);

	sc = sc->push();
	sc->anonAgg = &aad;
	sc->stc &= ~(STCauto | STCstatic);
	sc->inunion = isunion;
	sc->offset = 0;
	sc->flags = 0;
	aad.structalign = sc->structalign;
	aad.parent = ad;

	for (unsigned i = 0; i < decl->dim; i++)
	{
	    Dsymbol *s = (Dsymbol *)decl->data[i];

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
	    VarDeclaration *v = (VarDeclaration *)aad.fields.data[i];

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
	    Dsymbol *s = (Dsymbol *)decl->data[i];

	    //buf->writestring("    ");
	    s->toCBuffer(buf, hgs);
	}
    }
    buf->writestring("}\n");
}

char *AnonDeclaration::kind()
{
    return (char *)(isunion ? "anonymous union" : "anonymous struct");
}

/********************************* PragmaDeclaration ****************************/

PragmaDeclaration::PragmaDeclaration(Loc loc, Identifier *ident, Expressions *args, Array *decl)
	: AttribDeclaration(decl)
{
    this->loc = loc;
    this->ident = ident;
    this->args = args;
}

Dsymbol *PragmaDeclaration::syntaxCopy(Dsymbol *s)
{
    PragmaDeclaration *pd;

    assert(!s);
    pd = new PragmaDeclaration(loc, ident,
	Expression::arraySyntaxCopy(args), Dsymbol::arraySyntaxCopy(decl));
    return pd;
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
		Expression *e = (Expression *)args->data[i];

		e = e->semantic(sc);
		if (e->op == TOKstring)
		{
		    StringExp *se = (StringExp *)e;
		    fprintf(stdmsg, "%.*s", se->len, se->string);
		}
		else
		    error("string expected for message, not '%s'", e->toChars());
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
	    Expression *e = (Expression *)args->data[0];

	    e = e->semantic(sc);
	    args->data[0] = (void *)e;
	    if (e->op != TOKstring)
		error("string expected for library name, not '%s'", e->toChars());
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

	    e = (Expression *)args->data[0];
	    e = e->semantic(sc);
	    if (e->op == TOKvar)
	    {
		d = ((VarExp *)e)->var;
		if (! d->isFuncDeclaration() && ! d->isVarDeclaration())
		    d = NULL;
	    }
	    if (!d)
		error("first argument of GNU_asm must be a function or variable declaration");

	    e = (Expression *)args->data[1];
	    e = e->semantic(sc);
	    e = e->optimize(WANTvalue);
	    if (e->op == TOKstring && ((StringExp *)e)->sz == 1)
		s = ((StringExp *)e);
	    else
		error("second argument of GNU_asm must be a char string");

	    if (d && s)
		d->c_ident = Lexer::idPool((char*) s->string);
	}
	goto Lnodecl;
    }
#endif
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

char *PragmaDeclaration::kind()
{
    return "pragma";
}

void PragmaDeclaration::toObjFile()
{
    if (ident == Id::lib)
    {
	assert(args && args->dim == 1);

	Expression *e = (Expression *)args->data[0];

	assert(e->op == TOKstring);

	StringExp *se = (StringExp *)e;
	char *name = (char *)mem.malloc(se->len + 1);
	memcpy(name, se->string, se->len);
	name[se->len] = 0;
	obj_includelib(name);
    }
    AttribDeclaration::toObjFile();
}

void PragmaDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->printf("pragma(%s", ident->toChars());
    if (args)
    {
	for (size_t i = 0; i < args->dim; i++)
	{
	    Expression *e = (Expression *)args->data[i];

	    buf->writestring(", ");
	    e->toCBuffer(buf, hgs);
	}
    }
    buf->writestring(")");
    AttribDeclaration::toCBuffer(buf, hgs);
}


/********************************* ConditionalDeclaration ****************************/

ConditionalDeclaration::ConditionalDeclaration(Condition *condition, Array *decl, Array *elsedecl)
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
	Array *d = condition->include(NULL, NULL) ? decl : elsedecl;
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
}

// Decide if 'then' or 'else' code should be included

Array *ConditionalDeclaration::include(Scope *sc, ScopeDsymbol *sd)
{
    //printf("ConditionalDeclaration::include()\n");
    assert(condition);
    return condition->include(sc, sd) ? decl : elsedecl;
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
	Array *d = decl;

	for (int j = 0; j < 2; j++)
	{
	    if (d)
	    {
		for (unsigned i = 0; i < d->dim; i++)
		{   Dsymbol *s;

		    s = (Dsymbol *)d->data[i];
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
		Dsymbol *s = (Dsymbol *)decl->data[i];

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
		Dsymbol *s = (Dsymbol *)elsedecl->data[i];

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
	Array *decl, Array *elsedecl)
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
    {	m = AttribDeclaration::addMember(sc, sd, memnum);
	addisdone = 1;
    }
    return m;
}


void StaticIfDeclaration::semantic(Scope *sc)
{
    Array *d = include(sc, sd);

    //printf("\tStaticIfDeclaration::semantic '%s'\n",toChars());
    if (d)
    {
	if (!addisdone)
	{   AttribDeclaration::addMember(sc, sd, 1);
	    addisdone = 1;
	}

	for (unsigned i = 0; i < d->dim; i++)
	{
	    Dsymbol *s = (Dsymbol *)d->data[i];

	    s->semantic(sc);
	}
    }
}

char *StaticIfDeclaration::kind()
{
    return "static if";
}


