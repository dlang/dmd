
// Compiler implementation of the D programming language
// Copyright (c) 1999-2008 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <assert.h>

#include "root.h"
#include "aggregate.h"
#include "scope.h"
#include "mtype.h"
#include "declaration.h"
#include "module.h"
#include "id.h"
#include "expression.h"
#include "statement.h"
#include "init.h"


/*******************************************
 * We need an opAssign for the struct if
 * it has a destructor or a postblit.
 * We need to generate one if a user-specified one does not exist.
 */

int StructDeclaration::needOpAssign()
{
#define X 0
    if (X) printf("StructDeclaration::needOpAssign() %s\n", toChars());
    if (hasIdentityAssign)
	goto Ldontneed;

    if (dtor || postblit)
	goto Lneed;

    /* If any of the fields need an opAssign, then we
     * need it too.
     */
    for (size_t i = 0; i < fields.dim; i++)
    {
	Dsymbol *s = (Dsymbol *)fields.data[i];
	VarDeclaration *v = s->isVarDeclaration();
	assert(v && v->storage_class & STCfield);
	Type *tv = v->type->toBasetype();
	while (tv->ty == Tsarray)
	{   TypeSArray *ta = (TypeSArray *)tv;
	    tv = tv->nextOf()->toBasetype();
	}
	if (tv->ty == Tstruct)
	{   TypeStruct *ts = (TypeStruct *)tv;
	    StructDeclaration *sd = ts->sym;
	    if (sd->needOpAssign())
		goto Lneed;
	}
    }
Ldontneed:
    if (X) printf("\tdontneed\n");
    return 0;

Lneed:
    if (X) printf("\tneed\n");
    return 1;
#undef X
}

/******************************************
 * Build opAssign for struct.
 *	S* opAssign(S s) { ... }
 */

FuncDeclaration *StructDeclaration::buildOpAssign(Scope *sc)
{
    if (!needOpAssign())
	return NULL;

    //printf("StructDeclaration::buildOpAssign() %s\n", toChars());

    FuncDeclaration *fop = NULL;

    Argument *param = new Argument(STCnodtor, type, Id::p, NULL);
    Arguments *fparams = new Arguments;
    fparams->push(param);
    Type *ftype = new TypeFunction(fparams, handle, FALSE, LINKd);

    fop = new FuncDeclaration(0, 0, Id::assign, STCundefined, ftype);

    Expression *e = NULL;
    if (postblit)
    {	/* Swap:
	 *    tmp = *this; *this = s; tmp.dtor();
	 */
	//printf("\tswap copy\n");
	Identifier *idtmp = Lexer::uniqueId("__tmp");
	VarDeclaration *tmp;
	AssignExp *ec = NULL;
	if (dtor)
	{
	    tmp = new VarDeclaration(0, type, idtmp, new VoidInitializer(0));
	    tmp->noauto = 1;
	    e = new DeclarationExp(0, tmp);
	    ec = new AssignExp(0,
		new VarExp(0, tmp),
		new PtrExp(0, new ThisExp(0)));
	    ec->op = TOKblit;
	    e = Expression::combine(e, ec);
	}
	ec = new AssignExp(0,
		new PtrExp(0, new ThisExp(0)),
		new IdentifierExp(0, Id::p));
	ec->op = TOKblit;
	e = Expression::combine(e, ec);
	if (dtor)
	{
	    /* Instead of running the destructor on s, run it
	     * on tmp. This avoids needing to copy tmp back in to s.
	     */
	    Expression *ec = new DotVarExp(0, new VarExp(0, tmp), dtor, 0);
	    ec = new CallExp(0, ec);
	    e = Expression::combine(e, ec);
	}
    }
    else
    {	/* Do memberwise copy
	 */
	//printf("\tmemberwise copy\n");
	for (size_t i = 0; i < fields.dim; i++)
	{
	    Dsymbol *s = (Dsymbol *)fields.data[i];
	    VarDeclaration *v = s->isVarDeclaration();
	    assert(v && v->storage_class & STCfield);
	    // this.v = s.v;
	    AssignExp *ec = new AssignExp(0,
		new DotVarExp(0, new ThisExp(0), v, 0),
		new DotVarExp(0, new IdentifierExp(0, Id::p), v, 0));
	    ec->op = TOKblit;
	    e = Expression::combine(e, ec);
	}
    }
    Statement *s1 = new ExpStatement(0, e);

    /* Add:
     *   return this;
     */
    e = new ThisExp(0);
    Statement *s2 = new ReturnStatement(0, e);

    fop->fbody = new CompoundStatement(0, s1, s2);

    members->push(fop);
    fop->addMember(sc, this, 1);

    sc = sc->push();
    sc->stc = 0;
    sc->linkage = LINKd;

    fop->semantic(sc);

    sc->pop();

    //printf("-StructDeclaration::buildOpAssign() %s\n", toChars());

    return fop;
}

/*******************************************
 * Build copy constructor for struct.
 * Copy constructors are compiler generated only, and are only
 * callable from the compiler. They are not user accessible.
 * A copy constructor is:
 *    void cpctpr(ref S s)
 *    {
 *	*this = s;
 *	this.postBlit();
 *    }
 * This is done so:
 *	- postBlit() never sees uninitialized data
 *	- memcpy can be much more efficient than memberwise copy
 *	- no fields are overlooked
 */

FuncDeclaration *StructDeclaration::buildCpCtor(Scope *sc)
{
    //printf("StructDeclaration::buildCpCtor() %s\n", toChars());
    FuncDeclaration *fcp = NULL;

    /* Copy constructor is only necessary if there is a postblit function,
     * otherwise the code generator will just do a bit copy.
     */
    if (postblit)
    {
	//printf("generating cpctor\n");

	Argument *param = new Argument(STCref, type, Id::p, NULL);
	Arguments *fparams = new Arguments;
	fparams->push(param);
	Type *ftype = new TypeFunction(fparams, Type::tvoid, FALSE, LINKd);

	fcp = new FuncDeclaration(0, 0, Id::cpctor, STCundefined, ftype);

	// Build *this = p;
	Expression *e = new ThisExp(0);
	e = new PtrExp(0, e);
	AssignExp *ea = new AssignExp(0, e, new IdentifierExp(0, Id::p));
	ea->op = TOKblit;
	Statement *s = new ExpStatement(0, ea);

	// Build postBlit();
	e = new VarExp(0, postblit, 0);
	e = new CallExp(0, e);

	s = new CompoundStatement(0, s, new ExpStatement(0, e));
	fcp->fbody = s;

	members->push(fcp);

	sc = sc->push();
	sc->stc = 0;
	sc->linkage = LINKd;

	fcp->semantic(sc);

	sc->pop();
    }

    return fcp;
}

/*****************************************
 * Create inclusive postblit for struct by aggregating
 * all the postblits in postblits[] with the postblits for
 * all the members.
 * Note the close similarity with AggregateDeclaration::buildDtor(),
 * and the ordering changes (runs forward instead of backwards).
 */

#if V2
FuncDeclaration *StructDeclaration::buildPostBlit(Scope *sc)
{
    //printf("StructDeclaration::buildPostBlit() %s\n", toChars());
    Expression *e = NULL;

    for (size_t i = 0; i < fields.dim; i++)
    {
	Dsymbol *s = (Dsymbol *)fields.data[i];
	VarDeclaration *v = s->isVarDeclaration();
	assert(v && v->storage_class & STCfield);
	Type *tv = v->type->toBasetype();
	size_t dim = 1;
	while (tv->ty == Tsarray)
	{   TypeSArray *ta = (TypeSArray *)tv;
	    dim *= ((TypeSArray *)tv)->dim->toInteger();
	    tv = tv->nextOf()->toBasetype();
	}
	if (tv->ty == Tstruct)
	{   TypeStruct *ts = (TypeStruct *)tv;
	    StructDeclaration *sd = ts->sym;
	    if (sd->postblit)
	    {	Expression *ex;

		// this.v
		ex = new ThisExp(0);
		ex = new DotVarExp(0, ex, v, 0);

		if (dim == 1)
		{   // this.v.dtor()
		    ex = new DotVarExp(0, ex, sd->postblit, 0);
		    ex = new CallExp(0, ex);
		}
		else
		{
		    // Typeinfo.postblit(cast(void*)&this.v);
		    Expression *ea = new AddrExp(0, ex);
		    ea = new CastExp(0, ea, Type::tvoid->pointerTo());

		    Expression *et = v->type->getTypeInfo(sc);
		    et = new DotIdExp(0, et, Id::postblit);

		    ex = new CallExp(0, et, ea);
		}
		e = Expression::combine(e, ex);	// combine in forward order
	    }
	}
    }

    /* Build our own "postblit" which executes e
     */
    if (e)
    {	//printf("Building __fieldPostBlit()\n");
	PostBlitDeclaration *dd = new PostBlitDeclaration(0, 0, Lexer::idPool("__fieldPostBlit"));
	dd->fbody = new ExpStatement(0, e);
	dtors.push(dd);
	members->push(dd);
	dd->semantic(sc);
    }

    switch (postblits.dim)
    {
	case 0:
	    return NULL;

	case 1:
	    return (FuncDeclaration *)postblits.data[0];

	default:
	    e = NULL;
	    for (size_t i = 0; i < postblits.dim; i++)
	    {	FuncDeclaration *fd = (FuncDeclaration *)postblits.data[i];
		Expression *ex = new ThisExp(0);
		ex = new DotVarExp(0, ex, fd, 0);
		ex = new CallExp(0, ex);
		e = Expression::combine(e, ex);
	    }
	    PostBlitDeclaration *dd = new PostBlitDeclaration(0, 0, Lexer::idPool("__aggrPostBlit"));
	    dd->fbody = new ExpStatement(0, e);
	    members->push(dd);
	    dd->semantic(sc);
	    return dd;
    }
}

#endif

/*****************************************
 * Create inclusive destructor for struct/class by aggregating
 * all the destructors in dtors[] with the destructors for
 * all the members.
 * Note the close similarity with StructDeclaration::buildPostBlit(),
 * and the ordering changes (runs backward instead of forwards).
 */

FuncDeclaration *AggregateDeclaration::buildDtor(Scope *sc)
{
    //printf("AggregateDeclaration::buildDtor() %s\n", toChars());
    Expression *e = NULL;

#if V2
    for (size_t i = 0; i < fields.dim; i++)
    {
	Dsymbol *s = (Dsymbol *)fields.data[i];
	VarDeclaration *v = s->isVarDeclaration();
	assert(v && v->storage_class & STCfield);
	Type *tv = v->type->toBasetype();
	size_t dim = 1;
	while (tv->ty == Tsarray)
	{   TypeSArray *ta = (TypeSArray *)tv;
	    dim *= ((TypeSArray *)tv)->dim->toInteger();
	    tv = tv->nextOf()->toBasetype();
	}
	if (tv->ty == Tstruct)
	{   TypeStruct *ts = (TypeStruct *)tv;
	    StructDeclaration *sd = ts->sym;
	    if (sd->dtor)
	    {	Expression *ex;

		// this.v
		ex = new ThisExp(0);
		ex = new DotVarExp(0, ex, v, 0);

		if (dim == 1)
		{   // this.v.dtor()
		    ex = new DotVarExp(0, ex, sd->dtor, 0);
		    ex = new CallExp(0, ex);
		}
		else
		{
		    // Typeinfo.destroy(cast(void*)&this.v);
		    Expression *ea = new AddrExp(0, ex);
		    ea = new CastExp(0, ea, Type::tvoid->pointerTo());

		    Expression *et = v->type->getTypeInfo(sc);
		    et = new DotIdExp(0, et, Id::destroy);

		    ex = new CallExp(0, et, ea);
		}
		e = Expression::combine(ex, e);	// combine in reverse order
	    }
	}
    }

    /* Build our own "destructor" which executes e
     */
    if (e)
    {	//printf("Building __fieldDtor()\n");
	DtorDeclaration *dd = new DtorDeclaration(0, 0, Lexer::idPool("__fieldDtor"));
	dd->fbody = new ExpStatement(0, e);
	dtors.shift(dd);
	members->push(dd);
	dd->semantic(sc);
    }
#endif

    switch (dtors.dim)
    {
	case 0:
	    return NULL;

	case 1:
	    return (FuncDeclaration *)dtors.data[0];

	default:
	    e = NULL;
	    for (size_t i = 0; i < dtors.dim; i++)
	    {	FuncDeclaration *fd = (FuncDeclaration *)dtors.data[i];
		Expression *ex = new ThisExp(0);
		ex = new DotVarExp(0, ex, fd, 0);
		ex = new CallExp(0, ex);
		e = Expression::combine(ex, e);
	    }
	    DtorDeclaration *dd = new DtorDeclaration(0, 0, Lexer::idPool("__aggrDtor"));
	    dd->fbody = new ExpStatement(0, e);
	    members->push(dd);
	    dd->semantic(sc);
	    return dd;
    }
}


