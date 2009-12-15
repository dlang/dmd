
// Compiler implementation of the D programming language
// Copyright (c) 1999-2009 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

// Handle template implementation

#include <stdio.h>
#include <assert.h>

#include "root.h"
#include "rmem.h"
#include "stringtable.h"

#include "mtype.h"
#include "template.h"
#include "init.h"
#include "expression.h"
#include "scope.h"
#include "module.h"
#include "aggregate.h"
#include "declaration.h"
#include "dsymbol.h"
#include "mars.h"
#include "dsymbol.h"
#include "identifier.h"
#include "hdrgen.h"

#if WINDOWS_SEH
#include <windows.h>
long __cdecl __ehfilter(LPEXCEPTION_POINTERS ep);
#endif

#define LOG	0

/********************************************
 * These functions substitute for dynamic_cast. dynamic_cast does not work
 * on earlier versions of gcc.
 */

Expression *isExpression(Object *o)
{
    //return dynamic_cast<Expression *>(o);
    if (!o || o->dyncast() != DYNCAST_EXPRESSION)
	return NULL;
    return (Expression *)o;
}

Dsymbol *isDsymbol(Object *o)
{
    //return dynamic_cast<Dsymbol *>(o);
    if (!o || o->dyncast() != DYNCAST_DSYMBOL)
	return NULL;
    return (Dsymbol *)o;
}

Type *isType(Object *o)
{
    //return dynamic_cast<Type *>(o);
    if (!o || o->dyncast() != DYNCAST_TYPE)
	return NULL;
    return (Type *)o;
}

Tuple *isTuple(Object *o)
{
    //return dynamic_cast<Tuple *>(o);
    if (!o || o->dyncast() != DYNCAST_TUPLE)
	return NULL;
    return (Tuple *)o;
}


/***********************
 * Try to get arg as a type.
 */

Type *getType(Object *o)
{
    Type *t = isType(o);
    if (!t)
    {   Expression *e = isExpression(o);
	if (e)
	    t = e->type;
    }
    return t;
}

Dsymbol *getDsymbol(Object *oarg)
{
    Dsymbol *sa;
    Expression *ea = isExpression(oarg);
    if (ea)
    {   // Try to convert Expression to symbol
	if (ea->op == TOKvar)
	    sa = ((VarExp *)ea)->var;
	else if (ea->op == TOKfunction)
	    sa = ((FuncExp *)ea)->fd;
	else
	    sa = NULL;
    }
    else
    {   // Try to convert Type to symbol
	Type *ta = isType(oarg);
	if (ta)
	    sa = ta->toDsymbol(NULL);
	else
	    sa = isDsymbol(oarg);	// if already a symbol
    }
    return sa;
}

/******************************
 * If o1 matches o2, return 1.
 * Else, return 0.
 */

int match(Object *o1, Object *o2, TemplateDeclaration *tempdecl, Scope *sc)
{
    Type *t1 = isType(o1);
    Type *t2 = isType(o2);
    Expression *e1 = isExpression(o1);
    Expression *e2 = isExpression(o2);
    Dsymbol *s1 = isDsymbol(o1);
    Dsymbol *s2 = isDsymbol(o2);
    Tuple *v1 = isTuple(o1);
    Tuple *v2 = isTuple(o2);

    //printf("\t match t1 %p t2 %p, e1 %p e2 %p, s1 %p s2 %p, v1 %p v2 %p\n", t1,t2,e1,e2,s1,s2,v1,v2);

    /* A proper implementation of the various equals() overrides
     * should make it possible to just do o1->equals(o2), but
     * we'll do that another day.
     */

    if (t1)
    {
	/* if t1 is an instance of ti, then give error
	 * about recursive expansions.
	 */
	Dsymbol *s = t1->toDsymbol(sc);
	if (s && s->parent)
	{   TemplateInstance *ti1 = s->parent->isTemplateInstance();
	    if (ti1 && ti1->tempdecl == tempdecl)
	    {
		for (Scope *sc1 = sc; sc1; sc1 = sc1->enclosing)
		{
		    if (sc1->scopesym == ti1)
		    {
			error("recursive template expansion for template argument %s", t1->toChars());
			return 1;	// fake a match
		    }
		}
	    }
	}

	//printf("t1 = %s\n", t1->toChars());
	//printf("t2 = %s\n", t2->toChars());
	if (!t2 || !t1->equals(t2))
	    goto Lnomatch;
    }
    else if (e1)
    {
#if 0
	if (e1 && e2)
	{
	    printf("match %d\n", e1->equals(e2));
	    e1->print();
	    e2->print();
	    e1->type->print();
	    e2->type->print();
	}
#endif
	if (!e2)
	    goto Lnomatch;
	if (!e1->equals(e2))
	    goto Lnomatch;
    }
    else if (s1)
    {
	//printf("%p %s, %p %s\n", s1, s1->toChars(), s2, s2->toChars());
	if (!s2 || !s1->equals(s2) || s1->parent != s2->parent)
	{
	    goto Lnomatch;
	}
#if DMDV2
	VarDeclaration *v1 = s1->isVarDeclaration();
	VarDeclaration *v2 = s2->isVarDeclaration();
	if (v1 && v2 && v1->storage_class & v2->storage_class & STCmanifest)
	{   ExpInitializer *ei1 = v1->init->isExpInitializer();
	    ExpInitializer *ei2 = v2->init->isExpInitializer();
	    if (ei1 && ei2 && !ei1->exp->equals(ei2->exp))
		goto Lnomatch;
	}
#endif
    }
    else if (v1)
    {
	if (!v2)
	    goto Lnomatch;
	if (v1->objects.dim != v2->objects.dim)
	    goto Lnomatch;
	for (size_t i = 0; i < v1->objects.dim; i++)
	{
	    if (!match((Object *)v1->objects.data[i],
		       (Object *)v2->objects.data[i],
		       tempdecl, sc))
		goto Lnomatch;
	}
    }
    //printf("match\n");
    return 1;	// match
Lnomatch:
    //printf("nomatch\n");
    return 0;	// nomatch;
}

/****************************************
 */

void ObjectToCBuffer(OutBuffer *buf, HdrGenState *hgs, Object *oarg)
{
    //printf("ObjectToCBuffer()\n");
    Type *t = isType(oarg);
    Expression *e = isExpression(oarg);
    Dsymbol *s = isDsymbol(oarg);
    Tuple *v = isTuple(oarg);
    if (t)
    {	//printf("\tt: %s ty = %d\n", t->toChars(), t->ty);
	t->toCBuffer(buf, NULL, hgs);
    }
    else if (e)
	e->toCBuffer(buf, hgs);
    else if (s)
    {
	char *p = s->ident ? s->ident->toChars() : s->toChars();
	buf->writestring(p);
    }
    else if (v)
    {
	Objects *args = &v->objects;
	for (size_t i = 0; i < args->dim; i++)
	{
	    if (i)
		buf->writeByte(',');
	    Object *o = (Object *)args->data[i];
	    ObjectToCBuffer(buf, hgs, o);
	}
    }
    else if (!oarg)
    {
	buf->writestring("NULL");
    }
    else
    {
#ifdef DEBUG
	printf("bad Object = %p\n", oarg);
#endif
	assert(0);
    }
}

#if DMDV2
Object *objectSyntaxCopy(Object *o)
{
    if (!o)
	return NULL;
    Type *t = isType(o);
    if (t)
	return t->syntaxCopy();
    Expression *e = isExpression(o);
    if (e)
	return e->syntaxCopy();
    return o;
}
#endif


/* ======================== TemplateDeclaration ============================= */

TemplateDeclaration::TemplateDeclaration(Loc loc, Identifier *id,
	TemplateParameters *parameters, Expression *constraint, Array *decldefs)
    : ScopeDsymbol(id)
{
#if LOG
    printf("TemplateDeclaration(this = %p, id = '%s')\n", this, id->toChars());
#endif
#if 0
    if (parameters)
	for (int i = 0; i < parameters->dim; i++)
	{   TemplateParameter *tp = (TemplateParameter *)parameters->data[i];
	    //printf("\tparameter[%d] = %p\n", i, tp);
	    TemplateTypeParameter *ttp = tp->isTemplateTypeParameter();

	    if (ttp)
	    {
		printf("\tparameter[%d] = %s : %s\n", i, tp->ident->toChars(), ttp->specType ? ttp->specType->toChars() : "");
	    }
	}
#endif
    this->loc = loc;
    this->parameters = parameters;
    this->origParameters = parameters;
    this->constraint = constraint;
    this->members = decldefs;
    this->overnext = NULL;
    this->overroot = NULL;
    this->semanticRun = 0;
    this->onemember = NULL;
    this->literal = 0;
}

Dsymbol *TemplateDeclaration::syntaxCopy(Dsymbol *)
{
    //printf("TemplateDeclaration::syntaxCopy()\n");
    TemplateDeclaration *td;
    TemplateParameters *p;
    Array *d;

    p = NULL;
    if (parameters)
    {
	p = new TemplateParameters();
	p->setDim(parameters->dim);
	for (int i = 0; i < p->dim; i++)
	{   TemplateParameter *tp = (TemplateParameter *)parameters->data[i];
	    p->data[i] = (void *)tp->syntaxCopy();
	}
    }
    Expression *e = NULL;
    if (constraint)
	e = constraint->syntaxCopy();
    d = Dsymbol::arraySyntaxCopy(members);
    td = new TemplateDeclaration(loc, ident, p, e, d);
    return td;
}

void TemplateDeclaration::semantic(Scope *sc)
{
#if LOG
    printf("TemplateDeclaration::semantic(this = %p, id = '%s')\n", this, ident->toChars());
#endif
    if (semanticRun)
	return;		// semantic() already run
    semanticRun = 1;

    if (sc->func)
    {
#if DMDV1
	error("cannot declare template at function scope %s", sc->func->toChars());
#endif
    }

    if (/*global.params.useArrayBounds &&*/ sc->module)
    {
	// Generate this function as it may be used
	// when template is instantiated in other modules
	sc->module->toModuleArray();
    }

    if (/*global.params.useAssert &&*/ sc->module)
    {
	// Generate this function as it may be used
	// when template is instantiated in other modules
	sc->module->toModuleAssert();
    }

    /* Remember Scope for later instantiations, but make
     * a copy since attributes can change.
     */
    this->scope = new Scope(*sc);
    this->scope->setNoFree();

    // Set up scope for parameters
    ScopeDsymbol *paramsym = new ScopeDsymbol();
    paramsym->parent = sc->parent;
    Scope *paramscope = sc->push(paramsym);
    paramscope->parameterSpecialization = 1;
    paramscope->stc = 0;

    if (!parent)
	parent = sc->parent;

    if (global.params.doDocComments)
    {
	origParameters = new TemplateParameters();
	origParameters->setDim(parameters->dim);
	for (int i = 0; i < parameters->dim; i++)
	{
	    TemplateParameter *tp = (TemplateParameter *)parameters->data[i];
	    origParameters->data[i] = (void *)tp->syntaxCopy();
	}
    }

    for (int i = 0; i < parameters->dim; i++)
    {
	TemplateParameter *tp = (TemplateParameter *)parameters->data[i];

	tp->declareParameter(paramscope);
    }

    for (int i = 0; i < parameters->dim; i++)
    {
	TemplateParameter *tp = (TemplateParameter *)parameters->data[i];

	tp->semantic(paramscope);
	if (i + 1 != parameters->dim && tp->isTemplateTupleParameter())
	    error("template tuple parameter must be last one");
    }

    paramscope->pop();

    if (members)
    {
	Dsymbol *s;
	if (Dsymbol::oneMembers(members, &s))
	{
	    if (s && s->ident && s->ident->equals(ident))
	    {
		onemember = s;
		s->parent = this;
	    }
	}
    }

    /* BUG: should check:
     *	o no virtual functions or non-static data members of classes
     */
}

const char *TemplateDeclaration::kind()
{
    return (onemember && onemember->isAggregateDeclaration())
		? onemember->kind()
		: (char *)"template";
}

/**********************************
 * Overload existing TemplateDeclaration 'this' with the new one 's'.
 * Return !=0 if successful; i.e. no conflict.
 */

int TemplateDeclaration::overloadInsert(Dsymbol *s)
{
    TemplateDeclaration **pf;
    TemplateDeclaration *f;

#if LOG
    printf("TemplateDeclaration::overloadInsert('%s')\n", s->toChars());
#endif
    f = s->isTemplateDeclaration();
    if (!f)
	return FALSE;
    TemplateDeclaration *pthis = this;
    for (pf = &pthis; *pf; pf = &(*pf)->overnext)
    {
#if 0
	// Conflict if TemplateParameter's match
	// Will get caught anyway later with TemplateInstance, but
	// should check it now.
	TemplateDeclaration *f2 = *pf;

	if (f->parameters->dim != f2->parameters->dim)
	    goto Lcontinue;

	for (int i = 0; i < f->parameters->dim; i++)
	{   TemplateParameter *p1 = (TemplateParameter *)f->parameters->data[i];
	    TemplateParameter *p2 = (TemplateParameter *)f2->parameters->data[i];

	    if (!p1->overloadMatch(p2))
		goto Lcontinue;
	}

#if LOG
	printf("\tfalse: conflict\n");
#endif
	return FALSE;

     Lcontinue:
	;
#endif
    }

    f->overroot = this;
    *pf = f;
#if LOG
    printf("\ttrue: no conflict\n");
#endif
    return TRUE;
}

/****************************
 * Declare all the function parameters as variables
 * and add them to the scope
 */
void TemplateDeclaration::makeParamNamesVisibleInConstraint(Scope *paramscope)
{
    /* We do this ONLY if there is only one function in the template.
     */	 
    FuncDeclaration *fd = onemember && onemember->toAlias() ?
	onemember->toAlias()->isFuncDeclaration() : NULL;
    if (fd)
    {
	paramscope->parent = fd;
	Parameters *fparameters;		// function parameter list
	int fvarargs;				// function varargs
	if (fd->type)
	{
	    assert(fd->type->ty == Tfunction);
	    TypeFunction *fdtype = (TypeFunction *)fd->type;
	    fparameters = fdtype->parameters;
	    fvarargs = fdtype->varargs;
	}
	else // Constructors don't have type's
	{   CtorDeclaration *fctor = fd->isCtorDeclaration();
	    assert(fctor);
	    fparameters = fctor->arguments;
	    fvarargs = fctor->varargs;
	}
	size_t nfparams = Parameter::dim(fparameters); // Num function parameters
	for (int i = 0; i < nfparams; i++)
	{
	    Parameter *fparam = Parameter::getNth(fparameters, i)->syntaxCopy();
	    if (!fparam->ident)
		continue;			// don't add it, if it has no name
	    Type *vtype = fparam->type->syntaxCopy();
	    // isPure will segfault if called on a ctor, because fd->type is null.
	    if (fd->type && fd->isPure())
		vtype = vtype->addMod(MODconst);
	    VarDeclaration *v = new VarDeclaration(loc, vtype, fparam->ident, NULL);
	    v->storage_class |= STCparameter;
	    // Not sure if this condition is correct/necessary.
	    //   It's from func.c
	    if (//fd->type && fd->type->ty == Tfunction &&
	     fvarargs == 2 && i + 1 == nfparams)
		v->storage_class |= STCvariadic;
		
	    v->storage_class |= fparam->storageClass & (STCin | STCout | STCref | STClazy | STCfinal | STC_TYPECTOR | STCnodtor);
	    v->semantic(paramscope);
	    if (!paramscope->insert(v))
		error("parameter %s.%s is already defined", toChars(), v->toChars());
	    else
		v->parent = this;
	}
    }
}

/***************************************
 * Given that ti is an instance of this TemplateDeclaration,
 * deduce the types of the parameters to this, and store
 * those deduced types in dedtypes[].
 * Input:
 *	flag	1: don't do semantic() because of dummy types
 *		2: don't change types in matchArg()
 * Output:
 *	dedtypes	deduced arguments
 * Return match level.
 */

MATCH TemplateDeclaration::matchWithInstance(TemplateInstance *ti,
	Objects *dedtypes, int flag)
{   MATCH m;
    int dedtypes_dim = dedtypes->dim;

#define LOGM 0
#if LOGM
    printf("\n+TemplateDeclaration::matchWithInstance(this = %s, ti = %s, flag = %d)\n", toChars(), ti->toChars(), flag);
#endif

#if 0
    printf("dedtypes->dim = %d, parameters->dim = %d\n", dedtypes_dim, parameters->dim);
    if (ti->tiargs->dim)
	printf("ti->tiargs->dim = %d, [0] = %p\n",
	    ti->tiargs->dim,
	    ti->tiargs->data[0]);
#endif
    dedtypes->zero();

    int parameters_dim = parameters->dim;
    int variadic = isVariadic() != NULL;

    // If more arguments than parameters, no match
    if (ti->tiargs->dim > parameters_dim && !variadic)
    {
#if LOGM
	printf(" no match: more arguments than parameters\n");
#endif
	return MATCHnomatch;
    }

    assert(dedtypes_dim == parameters_dim);
    assert(dedtypes_dim >= ti->tiargs->dim || variadic);

    // Set up scope for parameters
    assert((size_t)scope > 0x10000);
    ScopeDsymbol *paramsym = new ScopeDsymbol();
    paramsym->parent = scope->parent;
    Scope *paramscope = scope->push(paramsym);
    paramscope->stc = 0;

    // Attempt type deduction
    m = MATCHexact;
    for (int i = 0; i < dedtypes_dim; i++)
    {	MATCH m2;
	TemplateParameter *tp = (TemplateParameter *)parameters->data[i];
	Declaration *sparam;

	//printf("\targument [%d]\n", i);
#if LOGM
	//printf("\targument [%d] is %s\n", i, oarg ? oarg->toChars() : "null");
	TemplateTypeParameter *ttp = tp->isTemplateTypeParameter();
	if (ttp)
	    printf("\tparameter[%d] is %s : %s\n", i, tp->ident->toChars(), ttp->specType ? ttp->specType->toChars() : "");
#endif

#if DMDV1
	m2 = tp->matchArg(paramscope, ti->tiargs, i, parameters, dedtypes, &sparam);
#else
	m2 = tp->matchArg(paramscope, ti->tiargs, i, parameters, dedtypes, &sparam, (flag & 2) ? 1 : 0);

#endif
	//printf("\tm2 = %d\n", m2);

	if (m2 == MATCHnomatch)
	{
#if 0
	    printf("\tmatchArg() for parameter %i failed\n", i);
#endif
	    goto Lnomatch;
	}

	if (m2 < m)
	    m = m2;

	if (!flag)
	    sparam->semantic(paramscope);
	if (!paramscope->insert(sparam))
	    goto Lnomatch;
    }

    if (!flag)
    {
	/* Any parameter left without a type gets the type of
	 * its corresponding arg
	 */
	for (int i = 0; i < dedtypes_dim; i++)
	{
	    if (!dedtypes->data[i])
	    {   assert(i < ti->tiargs->dim);
		dedtypes->data[i] = ti->tiargs->data[i];
	    }
	}
    }

#if DMDV2
    if (m && constraint && !(flag & 1))
    {	/* Check to see if constraint is satisfied.
	 */
	makeParamNamesVisibleInConstraint(paramscope);
	Expression *e = constraint->syntaxCopy();
	paramscope->flags |= SCOPEstaticif;
	e = e->semantic(paramscope);
	e = e->optimize(WANTvalue | WANTinterpret);
        if (e->isBool(TRUE))
            ;
        else if (e->isBool(FALSE))
            goto Lnomatch;
        else
        {
            e->error("constraint %s is not constant or does not evaluate to a bool", e->toChars());
        }
    }
#endif

#if LOGM
    // Print out the results
    printf("--------------------------\n");
    printf("template %s\n", toChars());
    printf("instance %s\n", ti->toChars());
    if (m)
    {
	for (int i = 0; i < dedtypes_dim; i++)
	{
	    TemplateParameter *tp = (TemplateParameter *)parameters->data[i];
	    Object *oarg;

	    printf(" [%d]", i);

	    if (i < ti->tiargs->dim)
		oarg = (Object *)ti->tiargs->data[i];
	    else
		oarg = NULL;
	    tp->print(oarg, (Object *)dedtypes->data[i]);
	}
    }
    else
	goto Lnomatch;
#endif

#if LOGM
    printf(" match = %d\n", m);
#endif
    goto Lret;

Lnomatch:
#if LOGM
    printf(" no match\n");
#endif
    m = MATCHnomatch;

Lret:
    paramscope->pop();
#if LOGM
    printf("-TemplateDeclaration::matchWithInstance(this = %p, ti = %p) = %d\n", this, ti, m);
#endif
    return m;
}

/********************************************
 * Determine partial specialization order of 'this' vs td2.
 * Returns:
 *	match	this is at least as specialized as td2
 *	0	td2 is more specialized than this
 */

MATCH TemplateDeclaration::leastAsSpecialized(TemplateDeclaration *td2)
{
    /* This works by taking the template parameters to this template
     * declaration and feeding them to td2 as if it were a template
     * instance.
     * If it works, then this template is at least as specialized
     * as td2.
     */

    TemplateInstance ti(0, ident);	// create dummy template instance
    Objects dedtypes;

#define LOG_LEASTAS	0

#if LOG_LEASTAS
    printf("%s.leastAsSpecialized(%s)\n", toChars(), td2->toChars());
#endif

    // Set type arguments to dummy template instance to be types
    // generated from the parameters to this template declaration
    ti.tiargs = new Objects();
    ti.tiargs->setDim(parameters->dim);
    for (int i = 0; i < ti.tiargs->dim; i++)
    {
	TemplateParameter *tp = (TemplateParameter *)parameters->data[i];

	void *p = tp->dummyArg();
	if (p)
	    ti.tiargs->data[i] = p;
	else
	    ti.tiargs->setDim(i);
    }

    // Temporary Array to hold deduced types
    //dedtypes.setDim(parameters->dim);
    dedtypes.setDim(td2->parameters->dim);

    // Attempt a type deduction
    MATCH m = td2->matchWithInstance(&ti, &dedtypes, 1);
    if (m)
    {
	/* A non-variadic template is more specialized than a
	 * variadic one.
	 */
	if (isVariadic() && !td2->isVariadic())
	    goto L1;

#if LOG_LEASTAS
	printf("  matches %d, so is least as specialized\n", m);
#endif
	return m;
    }
  L1:
#if LOG_LEASTAS
    printf("  doesn't match, so is not as specialized\n");
#endif
    return MATCHnomatch;
}


/*************************************************
 * Match function arguments against a specific template function.
 * Input:
 *	loc		instantiation location
 *	targsi		Expression/Type initial list of template arguments
 *	ethis		'this' argument if !NULL
 *	fargs		arguments to function
 * Output:
 *	dedargs		Expression/Type deduced template arguments
 * Returns:
 *	match level
 */

MATCH TemplateDeclaration::deduceFunctionTemplateMatch(Loc loc, Objects *targsi,
	Expression *ethis, Expressions *fargs,
	Objects *dedargs)
{
    size_t i;
    size_t nfparams;
    size_t nfargs;
    size_t nargsi;		// array size of targsi
    int fptupindex = -1;
    int tuple_dim = 0;
    MATCH match = MATCHexact;
    FuncDeclaration *fd = onemember->toAlias()->isFuncDeclaration();
    Parameters *fparameters;		// function parameter list
    int fvarargs;			// function varargs
    Objects dedtypes;	// for T:T*, the dedargs is the T*, dedtypes is the T

#if 0
    printf("\nTemplateDeclaration::deduceFunctionTemplateMatch() %s\n", toChars());
    for (i = 0; i < fargs->dim; i++)
    {	Expression *e = (Expression *)fargs->data[i];
	printf("\tfarg[%d] is %s, type is %s\n", i, e->toChars(), e->type->toChars());
    }
    printf("fd = %s\n", fd->toChars());
    printf("fd->type = %p\n", fd->type);
#endif

    assert((size_t)scope > 0x10000);

    dedargs->setDim(parameters->dim);
    dedargs->zero();

    dedtypes.setDim(parameters->dim);
    dedtypes.zero();

    // Set up scope for parameters
    ScopeDsymbol *paramsym = new ScopeDsymbol();
    paramsym->parent = scope->parent;
    Scope *paramscope = scope->push(paramsym);

    TemplateTupleParameter *tp = isVariadic();
    int tp_is_declared = 0;

#if 0
    for (i = 0; i < dedargs->dim; i++)
    {
	printf("\tdedarg[%d] = ", i);
	Object *oarg = (Object *)dedargs->data[i];
	if (oarg) printf("%s", oarg->toChars());
	printf("\n");
    }
#endif


    nargsi = 0;
    if (targsi)
    {	// Set initial template arguments

	nargsi = targsi->dim;
	size_t n = parameters->dim;
	if (tp)
	    n--;
	if (nargsi > n)
	{   if (!tp)
		goto Lnomatch;

	    /* The extra initial template arguments
	     * now form the tuple argument.
	     */
	    Tuple *t = new Tuple();
	    assert(parameters->dim);
	    dedargs->data[parameters->dim - 1] = (void *)t;

	    tuple_dim = nargsi - n;
	    t->objects.setDim(tuple_dim);
	    for (size_t i = 0; i < tuple_dim; i++)
	    {
		t->objects.data[i] = (void *)targsi->data[n + i];
	    }
	    declareParameter(paramscope, tp, t);
	    tp_is_declared = 1;
	}
	else
	    n = nargsi;

	memcpy(dedargs->data, targsi->data, n * sizeof(*dedargs->data));

	for (size_t i = 0; i < n; i++)
	{   assert(i < parameters->dim);
	    TemplateParameter *tp = (TemplateParameter *)parameters->data[i];
	    MATCH m;
	    Declaration *sparam = NULL;

	    m = tp->matchArg(paramscope, dedargs, i, parameters, &dedtypes, &sparam);
	    //printf("\tdeduceType m = %d\n", m);
	    if (m == MATCHnomatch)
		goto Lnomatch;
	    if (m < match)
		match = m;

	    sparam->semantic(paramscope);
	    if (!paramscope->insert(sparam))
		goto Lnomatch;
	}
    }
#if 0
    for (i = 0; i < dedargs->dim; i++)
    {
	printf("\tdedarg[%d] = ", i);
	Object *oarg = (Object *)dedargs->data[i];
	if (oarg) printf("%s", oarg->toChars());
	printf("\n");
    }
#endif

    if (fd->type)
    {
	assert(fd->type->ty == Tfunction);
	TypeFunction *fdtype = (TypeFunction *)fd->type;
	fparameters = fdtype->parameters;
	fvarargs = fdtype->varargs;
    }
    else
    {	CtorDeclaration *fctor = fd->isCtorDeclaration();
	assert(fctor);
	fparameters = fctor->arguments;
	fvarargs = fctor->varargs;
    }

    nfparams = Parameter::dim(fparameters);	// number of function parameters
    nfargs = fargs ? fargs->dim : 0;		// number of function arguments

    /* Check for match of function arguments with variadic template
     * parameter, such as:
     *
     * template Foo(T, A...) { void Foo(T t, A a); }
     * void main() { Foo(1,2,3); }
     */
    if (tp)				// if variadic
    {
	if (nfparams == 0 && nfargs != 0)		// if no function parameters
	{
	    if (tp_is_declared)
		goto L2;
	    Tuple *t = new Tuple();
	    //printf("t = %p\n", t);
	    dedargs->data[parameters->dim - 1] = (void *)t;
	    declareParameter(paramscope, tp, t);
	    goto L2;
	}
	else if (nfargs < nfparams - 1)
	    goto L1;
	else
	{
	    /* Figure out which of the function parameters matches
	     * the tuple template parameter. Do this by matching
	     * type identifiers.
	     * Set the index of this function parameter to fptupindex.
	     */
	    for (fptupindex = 0; fptupindex < nfparams; fptupindex++)
	    {
		Parameter *fparam = (Parameter *)fparameters->data[fptupindex];
		if (fparam->type->ty != Tident)
		    continue;
		TypeIdentifier *tid = (TypeIdentifier *)fparam->type;
		if (!tp->ident->equals(tid->ident) || tid->idents.dim)
		    continue;

		if (fvarargs)		// variadic function doesn't
		    goto Lnomatch;	// go with variadic template

		if (tp_is_declared)
		    goto L2;

		/* The types of the function arguments
		 * now form the tuple argument.
		 */
		Tuple *t = new Tuple();
		dedargs->data[parameters->dim - 1] = (void *)t;

		tuple_dim = nfargs - (nfparams - 1);
		t->objects.setDim(tuple_dim);
		for (i = 0; i < tuple_dim; i++)
		{   Expression *farg = (Expression *)fargs->data[fptupindex + i];
		    t->objects.data[i] = (void *)farg->type;
		}
		declareParameter(paramscope, tp, t);
		goto L2;
	    }
	    fptupindex = -1;
	}
    }

L1:
    if (nfparams == nfargs)
	;
    else if (nfargs > nfparams)
    {
	if (fvarargs == 0)
	    goto Lnomatch;		// too many args, no match
	match = MATCHconvert;		// match ... with a conversion
    }

L2:
#if DMDV2
    // Match 'ethis' to any TemplateThisParameter's
    if (ethis)
    {
	for (size_t i = 0; i < parameters->dim; i++)
	{   TemplateParameter *tp = (TemplateParameter *)parameters->data[i];
	    TemplateThisParameter *ttp = tp->isTemplateThisParameter();
	    if (ttp)
	    {	MATCH m;

		Type *t = new TypeIdentifier(0, ttp->ident);
		m = ethis->type->deduceType(paramscope, t, parameters, &dedtypes);
		if (!m)
		    goto Lnomatch;
		if (m < match)
		    match = m;		// pick worst match
	    }
	}
    }
#endif

    // Loop through the function parameters
    for (i = 0; i < nfparams; i++)
    {
	/* Skip over function parameters which wound up
	 * as part of a template tuple parameter.
	 */
	if (i == fptupindex)
	{   if (fptupindex == nfparams - 1)
		break;
	    i += tuple_dim - 1;
	    continue;
	}

	Parameter *fparam = Parameter::getNth(fparameters, i);

	if (i >= nfargs)		// if not enough arguments
	{
	    if (fparam->defaultArg)
	    {	/* Default arguments do not participate in template argument
		 * deduction.
		 */
		goto Lmatch;
	    }
	}
	else
	{   Expression *farg = (Expression *)fargs->data[i];
#if 0
	    printf("\tfarg->type   = %s\n", farg->type->toChars());
	    printf("\tfparam->type = %s\n", fparam->type->toChars());
#endif
	    Type *argtype = farg->type;

#if DMDV2
	    /* Allow string literals which are type [] to match with [dim]
	     */
	    if (farg->op == TOKstring)
	    {	StringExp *se = (StringExp *)farg;
		if (!se->committed && argtype->ty == Tarray &&
		    fparam->type->toBasetype()->ty == Tsarray)
		{
		    argtype = new TypeSArray(argtype->nextOf(), new IntegerExp(se->loc, se->len, Type::tindex));
		    argtype = argtype->semantic(se->loc, NULL);
		    argtype = argtype->invariantOf();
		}
	    }
#endif

	    MATCH m;
	    m = argtype->deduceType(paramscope, fparam->type, parameters, &dedtypes);
	    //printf("\tdeduceType m = %d\n", m);

	    /* If no match, see if there's a conversion to a delegate
	     */
	    if (!m && fparam->type->toBasetype()->ty == Tdelegate)
	    {
		TypeDelegate *td = (TypeDelegate *)fparam->type->toBasetype();
		TypeFunction *tf = (TypeFunction *)td->next;

		if (!tf->varargs && Parameter::dim(tf->parameters) == 0)
		{
		    m = farg->type->deduceType(paramscope, tf->next, parameters, &dedtypes);
		    if (!m && tf->next->toBasetype()->ty == Tvoid)
			m = MATCHconvert;
		}
		//printf("\tm2 = %d\n", m);
	    }

	    if (m)
	    {	if (m < match)
		    match = m;		// pick worst match
		continue;
	    }
	}

	/* The following code for variadic arguments closely
	 * matches TypeFunction::callMatch()
	 */
	if (!(fvarargs == 2 && i + 1 == nfparams))
	    goto Lnomatch;

	/* Check for match with function parameter T...
	 */
	Type *tb = fparam->type->toBasetype();
	switch (tb->ty)
	{
	    // Perhaps we can do better with this, see TypeFunction::callMatch()
	    case Tsarray:
	    {	TypeSArray *tsa = (TypeSArray *)tb;
		dinteger_t sz = tsa->dim->toInteger();
		if (sz != nfargs - i)
		    goto Lnomatch;
	    }
	    case Tarray:
	    {   TypeArray *ta = (TypeArray *)tb;
		for (; i < nfargs; i++)
		{
		    Expression *arg = (Expression *)fargs->data[i];
		    assert(arg);
		    MATCH m;
		    /* If lazy array of delegates,
		     * convert arg(s) to delegate(s)
		     */
		    Type *tret = fparam->isLazyArray();
		    if (tret)
		    {
			if (ta->next->equals(arg->type))
			{   m = MATCHexact;
			}
			else
			{
			    m = arg->implicitConvTo(tret);
			    if (m == MATCHnomatch)
			    {
				if (tret->toBasetype()->ty == Tvoid)
				    m = MATCHconvert;
			    }
			}
		    }
		    else
		    {
			m = arg->type->deduceType(paramscope, ta->next, parameters, &dedtypes);
			//m = arg->implicitConvTo(ta->next);
		    }
		    if (m == MATCHnomatch)
			goto Lnomatch;
		    if (m < match)
			match = m;
		}
		goto Lmatch;
	    }
	    case Tclass:
	    case Tident:
		goto Lmatch;

	    default:
		goto Lnomatch;
	}
    }

Lmatch:

    /* Fill in any missing arguments with their defaults.
     */
    for (i = nargsi; i < dedargs->dim; i++)
    {
	TemplateParameter *tp = (TemplateParameter *)parameters->data[i];
	//printf("tp[%d] = %s\n", i, tp->ident->toChars());
	/* For T:T*, the dedargs is the T*, dedtypes is the T
	 * But for function templates, we really need them to match
	 */
	Object *oarg = (Object *)dedargs->data[i];
	Object *oded = (Object *)dedtypes.data[i];
	//printf("1dedargs[%d] = %p, dedtypes[%d] = %p\n", i, oarg, i, oded);
	//if (oarg) printf("oarg: %s\n", oarg->toChars());
	//if (oded) printf("oded: %s\n", oded->toChars());
	if (!oarg)
	{
	    if (oded)
	    {
		if (tp->specialization())
		{   /* The specialization can work as long as afterwards
		     * the oded == oarg
		     */
		    Declaration *sparam;
		    dedargs->data[i] = (void *)oded;
		    MATCH m2 = tp->matchArg(paramscope, dedargs, i, parameters, &dedtypes, &sparam, 0);
		    //printf("m2 = %d\n", m2);
		    if (!m2)
			goto Lnomatch;
		    if (m2 < match)
			match = m2;		// pick worst match
		    if (dedtypes.data[i] != oded)
			error("specialization not allowed for deduced parameter %s", tp->ident->toChars());
		}
	    }
	    else
	    {	oded = tp->defaultArg(loc, paramscope);
		if (!oded)
		    goto Lnomatch;
	    }
	    declareParameter(paramscope, tp, oded);
	    dedargs->data[i] = (void *)oded;
	}
    }

#if DMDV2
    if (constraint)
    {	/* Check to see if constraint is satisfied.
	 */
	makeParamNamesVisibleInConstraint(paramscope);
	Expression *e = constraint->syntaxCopy();
	paramscope->flags |= SCOPEstaticif;
	e = e->semantic(paramscope);
	e = e->optimize(WANTvalue | WANTinterpret);
        if (e->isBool(TRUE))
            ;
        else if (e->isBool(FALSE))
            goto Lnomatch;
        else
        {
            e->error("constraint %s is not constant or does not evaluate to a bool", e->toChars());
        }
    }
#endif

#if 0
    for (i = 0; i < dedargs->dim; i++)
    {	Type *t = (Type *)dedargs->data[i];
	printf("\tdedargs[%d] = %d, %s\n", i, t->dyncast(), t->toChars());
    }
#endif

    paramscope->pop();
    //printf("\tmatch %d\n", match);
    return match;

Lnomatch:
    paramscope->pop();
    //printf("\tnomatch\n");
    return MATCHnomatch;
}

/**************************************************
 * Declare template parameter tp with value o, and install it in the scope sc.
 */

void TemplateDeclaration::declareParameter(Scope *sc, TemplateParameter *tp, Object *o)
{
    //printf("TemplateDeclaration::declareParameter('%s', o = %p)\n", tp->ident->toChars(), o);

    Type *targ = isType(o);
    Expression *ea = isExpression(o);
    Dsymbol *sa = isDsymbol(o);
    Tuple *va = isTuple(o);

    Dsymbol *s;

    // See if tp->ident already exists with a matching definition
    Dsymbol *scopesym;
    s = sc->search(loc, tp->ident, &scopesym);
    if (s && scopesym == sc->scopesym)
    {
	TupleDeclaration *td = s->isTupleDeclaration();
	if (va && td)
	{   Tuple tup;
	    tup.objects = *td->objects;
	    if (match(va, &tup, this, sc))
	    {
		return;
	    }
	}
    }

    if (targ)
    {
	//printf("type %s\n", targ->toChars());
	s = new AliasDeclaration(0, tp->ident, targ);
    }
    else if (sa)
    {
	//printf("Alias %s %s;\n", sa->ident->toChars(), tp->ident->toChars());
	s = new AliasDeclaration(0, tp->ident, sa);
    }
    else if (ea)
    {
	// tdtypes.data[i] always matches ea here
	Initializer *init = new ExpInitializer(loc, ea);
	TemplateValueParameter *tvp = tp->isTemplateValueParameter();

	Type *t = tvp ? tvp->valType : NULL;

	VarDeclaration *v = new VarDeclaration(loc, t, tp->ident, init);
	v->storage_class = STCmanifest;
	s = v;
    }
    else if (va)
    {
	//printf("\ttuple\n");
	s = new TupleDeclaration(loc, tp->ident, &va->objects);
    }
    else
    {
#ifdef DEBUG
	o->print();
#endif
	assert(0);
    }
    if (!sc->insert(s))
	error("declaration %s is already defined", tp->ident->toChars());
    s->semantic(sc);
}

/**************************************
 * Determine if TemplateDeclaration is variadic.
 */

TemplateTupleParameter *isVariadic(TemplateParameters *parameters)
{   size_t dim = parameters->dim;
    TemplateTupleParameter *tp = NULL;

    if (dim)
	tp = ((TemplateParameter *)parameters->data[dim - 1])->isTemplateTupleParameter();
    return tp;
}

TemplateTupleParameter *TemplateDeclaration::isVariadic()
{
    return ::isVariadic(parameters);
}

/***********************************
 * We can overload templates.
 */

int TemplateDeclaration::isOverloadable()
{
    return 1;
}

/*************************************************
 * Given function arguments, figure out which template function
 * to expand, and return that function.
 * If no match, give error message and return NULL.
 * Input:
 *	sc		instantiation scope
 *	loc		instantiation location
 *	targsi		initial list of template arguments
 *	ethis		if !NULL, the 'this' pointer argument
 *	fargs		arguments to function
 *	flags		1: do not issue error message on no match, just return NULL
 */

FuncDeclaration *TemplateDeclaration::deduceFunctionTemplate(Scope *sc, Loc loc,
	Objects *targsi, Expression *ethis, Expressions *fargs, int flags)
{
    MATCH m_best = MATCHnomatch;
    TemplateDeclaration *td_ambig = NULL;
    TemplateDeclaration *td_best = NULL;
    Objects *tdargs = new Objects();
    TemplateInstance *ti;
    FuncDeclaration *fd;

#if 0
    printf("TemplateDeclaration::deduceFunctionTemplate() %s\n", toChars());
    printf("    targsi:\n");
    if (targsi)
    {	for (int i = 0; i < targsi->dim; i++)
	{   Object *arg = (Object *)targsi->data[i];
	    printf("\t%s\n", arg->toChars());
	}
    }
    printf("    fargs:\n");
    for (int i = 0; i < fargs->dim; i++)
    {	Expression *arg = (Expression *)fargs->data[i];
	printf("\t%s %s\n", arg->type->toChars(), arg->toChars());
	//printf("\tty = %d\n", arg->type->ty);
    }
#endif

    for (TemplateDeclaration *td = this; td; td = td->overnext)
    {
	if (!td->semanticRun)
	{
	    error("forward reference to template %s", td->toChars());
	    goto Lerror;
	}
	if (!td->onemember || !td->onemember->toAlias()->isFuncDeclaration())
	{
	    error("is not a function template");
	    goto Lerror;
	}

	MATCH m;
	Objects dedargs;

	m = td->deduceFunctionTemplateMatch(loc, targsi, ethis, fargs, &dedargs);
	//printf("deduceFunctionTemplateMatch = %d\n", m);
	if (!m)			// if no match
	    continue;

	if (m < m_best)
	    goto Ltd_best;
	if (m > m_best)
	    goto Ltd;

	{
	// Disambiguate by picking the most specialized TemplateDeclaration
	MATCH c1 = td->leastAsSpecialized(td_best);
	MATCH c2 = td_best->leastAsSpecialized(td);
	//printf("c1 = %d, c2 = %d\n", c1, c2);

	if (c1 > c2)
	    goto Ltd;
	else if (c1 < c2)
	    goto Ltd_best;
	else
	    goto Lambig;
	}

      Lambig:		// td_best and td are ambiguous
	td_ambig = td;
	continue;

      Ltd_best:		// td_best is the best match so far
	td_ambig = NULL;
	continue;

      Ltd:		// td is the new best match
	td_ambig = NULL;
	assert((size_t)td->scope > 0x10000);
	td_best = td;
	m_best = m;
	tdargs->setDim(dedargs.dim);
	memcpy(tdargs->data, dedargs.data, tdargs->dim * sizeof(void *));
	continue;
    }
    if (!td_best)
    {
	if (!(flags & 1))
	    error(loc, "does not match any function template declaration");
	goto Lerror;
    }
    if (td_ambig)
    {
	error(loc, "matches more than one function template declaration:\n  %s\nand:\n  %s",
		td_best->toChars(), td_ambig->toChars());
    }

    /* The best match is td_best with arguments tdargs.
     * Now instantiate the template.
     */
    assert((size_t)td_best->scope > 0x10000);
    ti = new TemplateInstance(loc, td_best, tdargs);
    ti->semantic(sc);
    fd = ti->toAlias()->isFuncDeclaration();
    if (!fd)
	goto Lerror;
    return fd;

  Lerror:
#if DMDV2
    if (!(flags & 1))
#endif
    {
	HdrGenState hgs;

	OutBuffer bufa;
	Objects *args = targsi;
	if (args)
	{   for (int i = 0; i < args->dim; i++)
	    {
		if (i)
		    bufa.writeByte(',');
		Object *oarg = (Object *)args->data[i];
		ObjectToCBuffer(&bufa, &hgs, oarg);
	    }
	}

	OutBuffer buf;
	argExpTypesToCBuffer(&buf, fargs, &hgs);
	error(loc, "cannot deduce template function from argument types !(%s)(%s)",
		bufa.toChars(), buf.toChars());
    }
    return NULL;
}

void TemplateDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
#if 0 // Should handle template functions
    if (onemember && onemember->isFuncDeclaration())
	buf->writestring("foo ");
#endif
    buf->writestring(kind());
    buf->writeByte(' ');
    buf->writestring(ident->toChars());
    buf->writeByte('(');
    for (int i = 0; i < parameters->dim; i++)
    {
	TemplateParameter *tp = (TemplateParameter *)parameters->data[i];
	if (hgs->ddoc)
	    tp = (TemplateParameter *)origParameters->data[i];
	if (i)
	    buf->writeByte(',');
	tp->toCBuffer(buf, hgs);
    }
    buf->writeByte(')');
#if DMDV2
    if (constraint)
    {	buf->writestring(" if (");
	constraint->toCBuffer(buf, hgs);
	buf->writeByte(')');
    }
#endif

    if (hgs->hdrgen)
    {
	hgs->tpltMember++;
	buf->writenl();
	buf->writebyte('{');
	buf->writenl();
	for (int i = 0; i < members->dim; i++)
	{
	    Dsymbol *s = (Dsymbol *)members->data[i];
	    s->toCBuffer(buf, hgs);
	}
	buf->writebyte('}');
	buf->writenl();
	hgs->tpltMember--;
    }
}


char *TemplateDeclaration::toChars()
{   OutBuffer buf;
    HdrGenState hgs;

    memset(&hgs, 0, sizeof(hgs));
    buf.writestring(ident->toChars());
    buf.writeByte('(');
    for (int i = 0; i < parameters->dim; i++)
    {
	TemplateParameter *tp = (TemplateParameter *)parameters->data[i];
	if (i)
	    buf.writeByte(',');
	tp->toCBuffer(&buf, &hgs);
    }
    buf.writeByte(')');
#if DMDV2
    if (constraint)
    {	buf.writestring(" if (");
	constraint->toCBuffer(&buf, &hgs);
	buf.writeByte(')');
    }
#endif
    buf.writeByte(0);
    return (char *)buf.extractData();
}

/* ======================== Type ============================================ */

/****
 * Given an identifier, figure out which TemplateParameter it is.
 * Return -1 if not found.
 */

int templateIdentifierLookup(Identifier *id, TemplateParameters *parameters)
{
    for (size_t i = 0; i < parameters->dim; i++)
    {   TemplateParameter *tp = (TemplateParameter *)parameters->data[i];

	if (tp->ident->equals(id))
	    return i;
    }
    return -1;
}

int templateParameterLookup(Type *tparam, TemplateParameters *parameters)
{
    assert(tparam->ty == Tident);
    TypeIdentifier *tident = (TypeIdentifier *)tparam;
    //printf("\ttident = '%s'\n", tident->toChars());
    if (tident->idents.dim == 0)
    {
	return templateIdentifierLookup(tident->ident, parameters);
    }
    return -1;
}

/* These form the heart of template argument deduction.
 * Given 'this' being the type argument to the template instance,
 * it is matched against the template declaration parameter specialization
 * 'tparam' to determine the type to be used for the parameter.
 * Example:
 *	template Foo(T:T*)	// template declaration
 *	Foo!(int*)		// template instantiation
 * Input:
 *	this = int*
 *	tparam = T
 *	parameters = [ T:T* ]	// Array of TemplateParameter's
 * Output:
 *	dedtypes = [ int ]	// Array of Expression/Type's
 */

MATCH Type::deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters,
	Objects *dedtypes)
{
#if 0
    printf("Type::deduceType()\n");
    printf("\tthis   = %d, ", ty); print();
    printf("\ttparam = %d, ", tparam->ty); tparam->print();
#endif
    if (!tparam)
	goto Lnomatch;

    if (this == tparam)
	goto Lexact;

    if (tparam->ty == Tident)
    {
	// Determine which parameter tparam is
	int i = templateParameterLookup(tparam, parameters);
	if (i == -1)
	{
	    if (!sc)
		goto Lnomatch;

	    /* Need a loc to go with the semantic routine.
	     */
	    Loc loc;
	    if (parameters->dim)
	    {
		TemplateParameter *tp = (TemplateParameter *)parameters->data[0];
		loc = tp->loc;
	    }

	    /* BUG: what if tparam is a template instance, that
	     * has as an argument another Tident?
	     */
	    tparam = tparam->semantic(loc, sc);
	    assert(tparam->ty != Tident);
	    return deduceType(sc, tparam, parameters, dedtypes);
	}

	TemplateParameter *tp = (TemplateParameter *)parameters->data[i];

	// Found the corresponding parameter tp
	if (!tp->isTemplateTypeParameter())
	    goto Lnomatch;
	Type *tt = this;
	Type *at = (Type *)dedtypes->data[i];

	// 5*5 == 25 cases

	#define X(U,T)	((U) << 3) | (T)
	switch (X(tparam->mod, mod))
	{
	    case X(0, 0):
	    case X(0, MODconst):
	    case X(0, MODinvariant):
	    case X(0, MODshared):
	    case X(0, MODconst | MODshared):
		// foo(U:U) T                              => T
		// foo(U:U) const(T)                       => const(T)
		// foo(U:U) immutable(T)                   => immutable(T)
		// foo(U:U) shared(T)                      => shared(T)
		// foo(U:U) const(shared(T))               => const(shared(T))
		if (!at)
		{   dedtypes->data[i] = (void *)tt;
		    goto Lexact;
		}
		break;

	    case X(MODconst, MODconst):
	    case X(MODinvariant, MODinvariant):
	    case X(MODshared, MODshared):
	    case X(MODconst | MODshared, MODconst | MODshared):
		// foo(U:const(U))        const(T)         => T
		// foo(U:immutable(U))    immutable(T)     => T
		// foo(U:shared(U))       shared(T)        => T
		// foo(U:const(shared(U)) const(shared(T)) => T
		tt = mutableOf()->unSharedOf();
		if (!at)
		{   dedtypes->data[i] = (void *)tt;
		    goto Lexact;
		}
		break;

	    case X(MODconst, 0):
	    case X(MODconst, MODimmutable):
	    case X(MODconst, MODconst | MODshared):
	    case X(MODconst | MODshared, MODimmutable):
		// foo(U:const(U)) T                       => T
		// foo(U:const(U)) immutable(T)            => T
		// foo(U:const(U)) const(shared(T))        => shared(T)
		// foo(U:const(shared(U)) immutable(T)     => T
		tt = mutableOf();
		if (!at)
		{   dedtypes->data[i] = (void *)tt;
		    goto Lconst;
		}
		break;

	    case X(MODshared, MODconst | MODshared):
	    case X(MODconst | MODshared, MODshared):
		// foo(U:shared(U)) const(shared(T))       => const(T)
		// foo(U:const(shared(U)) shared(T)        => T
		tt = unSharedOf();
		if (!at)
		{   dedtypes->data[i] = (void *)tt;
		    goto Lconst;
		}
		break;

	    case X(MODimmutable,         0):
	    case X(MODimmutable,         MODconst):
	    case X(MODimmutable,         MODshared):
	    case X(MODimmutable,         MODconst | MODshared):
	    case X(MODconst,             MODshared):
	    case X(MODshared,            0):
	    case X(MODshared,            MODconst):
	    case X(MODshared,            MODimmutable):
	    case X(MODconst | MODshared, 0):
	    case X(MODconst | MODshared, MODconst):
		// foo(U:immutable(U)) T                   => nomatch
		// foo(U:immutable(U)) const(T)            => nomatch
		// foo(U:immutable(U)) shared(T)           => nomatch
		// foo(U:immutable(U)) const(shared(T))    => nomatch
		// foo(U:const(U)) shared(T)               => nomatch
		// foo(U:shared(U)) T                      => nomatch
		// foo(U:shared(U)) const(T)               => nomatch
		// foo(U:shared(U)) immutable(T)           => nomatch
		// foo(U:const(shared(U)) T                => nomatch
		// foo(U:const(shared(U)) const(T)         => nomatch
		//if (!at)
		    goto Lnomatch;
		break;

	    default:
		assert(0);
	}
	#undef X

	if (tt->equals(at))
	    goto Lexact;
	else if (tt->ty == Tclass && at->ty == Tclass)
	{
	    return tt->implicitConvTo(at);
	}
	else if (tt->ty == Tsarray && at->ty == Tarray &&
	    tt->nextOf()->implicitConvTo(at->nextOf()) >= MATCHconst)
	{
	    goto Lexact;
	}
	else
	    goto Lnomatch;
    }

    if (ty != tparam->ty)
	return implicitConvTo(tparam);
//	goto Lnomatch;

    if (nextOf())
	return nextOf()->deduceType(sc, tparam->nextOf(), parameters, dedtypes);

Lexact:
    return MATCHexact;

Lnomatch:
    return MATCHnomatch;

#if DMDV2
Lconst:
    return MATCHconst;
#endif
}

#if DMDV2
MATCH TypeDArray::deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters,
	Objects *dedtypes)
{
#if 0
    printf("TypeDArray::deduceType()\n");
    printf("\tthis   = %d, ", ty); print();
    printf("\ttparam = %d, ", tparam->ty); tparam->print();
#endif
    return Type::deduceType(sc, tparam, parameters, dedtypes);

  Lnomatch:
    return MATCHnomatch;
}
#endif

MATCH TypeSArray::deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters,
	Objects *dedtypes)
{
#if 0
    printf("TypeSArray::deduceType()\n");
    printf("\tthis   = %d, ", ty); print();
    printf("\ttparam = %d, ", tparam->ty); tparam->print();
#endif

    // Extra check that array dimensions must match
    if (tparam)
    {
	if (tparam->ty == Tsarray)
	{
	    TypeSArray *tp = (TypeSArray *)tparam;

	    if (tp->dim->op == TOKvar &&
		((VarExp *)tp->dim)->var->storage_class & STCtemplateparameter)
	    {	int i = templateIdentifierLookup(((VarExp *)tp->dim)->var->ident, parameters);
		// This code matches code in TypeInstance::deduceType()
		if (i == -1)
		    goto Lnomatch;
		TemplateParameter *tp = (TemplateParameter *)parameters->data[i];
		TemplateValueParameter *tvp = tp->isTemplateValueParameter();
		if (!tvp)
		    goto Lnomatch;
		Expression *e = (Expression *)dedtypes->data[i];
		if (e)
		{
		    if (!dim->equals(e))
			goto Lnomatch;
		}
		else
		{   Type *vt = tvp->valType->semantic(0, sc);
		    MATCH m = (MATCH)dim->implicitConvTo(vt);
		    if (!m)
			goto Lnomatch;
		    dedtypes->data[i] = dim;
		}
	    }
	    else if (dim->toInteger() != tp->dim->toInteger())
		return MATCHnomatch;
	}
	else if (tparam->ty == Taarray)
	{
	    TypeAArray *tp = (TypeAArray *)tparam;
	    if (tp->index->ty == Tident)
	    {	TypeIdentifier *tident = (TypeIdentifier *)tp->index;

		if (tident->idents.dim == 0)
		{   Identifier *id = tident->ident;

		    for (size_t i = 0; i < parameters->dim; i++)
		    {
			TemplateParameter *tp = (TemplateParameter *)parameters->data[i];

			if (tp->ident->equals(id))
			{   // Found the corresponding template parameter
			    TemplateValueParameter *tvp = tp->isTemplateValueParameter();
			    if (!tvp || !tvp->valType->isintegral())
				goto Lnomatch;

			    if (dedtypes->data[i])
			    {
				if (!dim->equals((Object *)dedtypes->data[i]))
				    goto Lnomatch;
			    }
			    else
			    {	dedtypes->data[i] = (void *)dim;
			    }
			    return next->deduceType(sc, tparam->nextOf(), parameters, dedtypes);
			}
		    }
		}
	    }
	}
	else if (tparam->ty == Tarray)
	{   MATCH m;

	    m = next->deduceType(sc, tparam->nextOf(), parameters, dedtypes);
	    if (m == MATCHexact)
		m = MATCHconvert;
	    return m;
	}
    }
    return Type::deduceType(sc, tparam, parameters, dedtypes);

  Lnomatch:
    return MATCHnomatch;
}

MATCH TypeAArray::deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes)
{
#if 0
    printf("TypeAArray::deduceType()\n");
    printf("\tthis   = %d, ", ty); print();
    printf("\ttparam = %d, ", tparam->ty); tparam->print();
#endif

    // Extra check that index type must match
    if (tparam && tparam->ty == Taarray)
    {
	TypeAArray *tp = (TypeAArray *)tparam;
	if (!index->deduceType(sc, tp->index, parameters, dedtypes))
	{
	    return MATCHnomatch;
	}
    }
    return Type::deduceType(sc, tparam, parameters, dedtypes);
}

MATCH TypeFunction::deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes)
{
    //printf("TypeFunction::deduceType()\n");
    //printf("\tthis   = %d, ", ty); print();
    //printf("\ttparam = %d, ", tparam->ty); tparam->print();

    // Extra check that function characteristics must match
    if (tparam && tparam->ty == Tfunction)
    {
	TypeFunction *tp = (TypeFunction *)tparam;
	if (varargs != tp->varargs ||
	    linkage != tp->linkage)
	    return MATCHnomatch;

	size_t nfargs = Parameter::dim(this->parameters);
	size_t nfparams = Parameter::dim(tp->parameters);

	/* See if tuple match
	 */
	if (nfparams > 0 && nfargs >= nfparams - 1)
	{
	    /* See if 'A' of the template parameter matches 'A'
	     * of the type of the last function parameter.
	     */
	    Parameter *fparam = Parameter::getNth(tp->parameters, nfparams - 1);
	    assert(fparam);
	    assert(fparam->type);
	    if (fparam->type->ty != Tident)
		goto L1;
	    TypeIdentifier *tid = (TypeIdentifier *)fparam->type;
	    if (tid->idents.dim)
		goto L1;

	    /* Look through parameters to find tuple matching tid->ident
	     */
	    size_t tupi = 0;
	    for (; 1; tupi++)
	    {	if (tupi == parameters->dim)
		    goto L1;
		TemplateParameter *t = (TemplateParameter *)parameters->data[tupi];
		TemplateTupleParameter *tup = t->isTemplateTupleParameter();
		if (tup && tup->ident->equals(tid->ident))
		    break;
	    }

	    /* The types of the function arguments [nfparams - 1 .. nfargs]
	     * now form the tuple argument.
	     */
	    int tuple_dim = nfargs - (nfparams - 1);

	    /* See if existing tuple, and whether it matches or not
	     */
	    Object *o = (Object *)dedtypes->data[tupi];
	    if (o)
	    {	// Existing deduced argument must be a tuple, and must match
		Tuple *t = isTuple(o);
		if (!t || t->objects.dim != tuple_dim)
		    return MATCHnomatch;
		for (size_t i = 0; i < tuple_dim; i++)
		{   Parameter *arg = Parameter::getNth(this->parameters, nfparams - 1 + i);
		    if (!arg->type->equals((Object *)t->objects.data[i]))
			return MATCHnomatch;
		}
	    }
	    else
	    {	// Create new tuple
		Tuple *t = new Tuple();
		t->objects.setDim(tuple_dim);
		for (size_t i = 0; i < tuple_dim; i++)
		{   Parameter *arg = Parameter::getNth(this->parameters, nfparams - 1 + i);
		    t->objects.data[i] = (void *)arg->type;
		}
		dedtypes->data[tupi] = (void *)t;
	    }
	    nfparams--;	// don't consider the last parameter for type deduction
	    goto L2;
	}

    L1:
	if (nfargs != nfparams)
	    return MATCHnomatch;
    L2:
	for (size_t i = 0; i < nfparams; i++)
	{
	    Parameter *a = Parameter::getNth(this->parameters, i);
	    Parameter *ap = Parameter::getNth(tp->parameters, i);
	    if (a->storageClass != ap->storageClass ||
		!a->type->deduceType(sc, ap->type, parameters, dedtypes))
		return MATCHnomatch;
	}
    }
    return Type::deduceType(sc, tparam, parameters, dedtypes);
}

MATCH TypeIdentifier::deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes)
{
    // Extra check
    if (tparam && tparam->ty == Tident)
    {
	TypeIdentifier *tp = (TypeIdentifier *)tparam;

	for (int i = 0; i < idents.dim; i++)
	{
	    Identifier *id1 = (Identifier *)idents.data[i];
	    Identifier *id2 = (Identifier *)tp->idents.data[i];

	    if (!id1->equals(id2))
		return MATCHnomatch;
	}
    }
    return Type::deduceType(sc, tparam, parameters, dedtypes);
}

MATCH TypeInstance::deduceType(Scope *sc,
	Type *tparam, TemplateParameters *parameters,
	Objects *dedtypes)
{
#if 0
    printf("TypeInstance::deduceType()\n");
    printf("\tthis   = %d, ", ty); print();
    printf("\ttparam = %d, ", tparam->ty); tparam->print();
#endif

    // Extra check
    if (tparam && tparam->ty == Tinstance)
    {
	TypeInstance *tp = (TypeInstance *)tparam;

	//printf("tempinst->tempdecl = %p\n", tempinst->tempdecl);
	//printf("tp->tempinst->tempdecl = %p\n", tp->tempinst->tempdecl);
	if (!tp->tempinst->tempdecl)
	{   //printf("tp->tempinst->name = '%s'\n", tp->tempinst->name->toChars());
	    if (!tp->tempinst->name->equals(tempinst->name))
	    {
		/* Handle case of:
		 *  template Foo(T : sa!(T), alias sa)
		 */
		int i = templateIdentifierLookup(tp->tempinst->name, parameters);
		if (i == -1)
		{   /* Didn't find it as a parameter identifier. Try looking
		     * it up and seeing if is an alias. See Bugzilla 1454
		     */
		    Dsymbol *s = tempinst->tempdecl->scope->search(0, tp->tempinst->name, NULL);
		    if (s)
		    {
			s = s->toAlias();
			TemplateDeclaration *td = s->isTemplateDeclaration();
			if (td && td == tempinst->tempdecl)
			    goto L2;
		    }
		    goto Lnomatch;
		}
		TemplateParameter *tpx = (TemplateParameter *)parameters->data[i];
		// This logic duplicates tpx->matchArg()
		TemplateAliasParameter *ta = tpx->isTemplateAliasParameter();
		if (!ta)
		    goto Lnomatch;
		Object *sa = tempinst->tempdecl;
		if (!sa)
		    goto Lnomatch;
		if (ta->specAlias && sa != ta->specAlias)
		    goto Lnomatch;
		if (dedtypes->data[i])
		{   // Must match already deduced symbol
		    Object *s = (Object *)dedtypes->data[i];

		    if (s != sa)
			goto Lnomatch;
		}
		dedtypes->data[i] = sa;
	    }
	}
	else if (tempinst->tempdecl != tp->tempinst->tempdecl)
	    goto Lnomatch;

      L2:

	for (int i = 0; 1; i++)
	{
	    //printf("\ttest: tempinst->tiargs[%d]\n", i);
	    Object *o1;
	    if (i < tempinst->tiargs->dim)
		o1 = (Object *)tempinst->tiargs->data[i];
	    else if (i < tempinst->tdtypes.dim && i < tp->tempinst->tiargs->dim)
		// Pick up default arg
		o1 = (Object *)tempinst->tdtypes.data[i];
	    else
		break;

	    if (i >= tp->tempinst->tiargs->dim)
		goto Lnomatch;

	    Object *o2 = (Object *)tp->tempinst->tiargs->data[i];

	    Type *t1 = isType(o1);
	    Type *t2 = isType(o2);

	    Expression *e1 = isExpression(o1);
	    Expression *e2 = isExpression(o2);

	    Dsymbol *s1 = isDsymbol(o1);
	    Dsymbol *s2 = isDsymbol(o2);

	    Tuple *v1 = isTuple(o1);
	    Tuple *v2 = isTuple(o2);
#if 0
	    if (t1)	printf("t1 = %s\n", t1->toChars());
	    if (t2)	printf("t2 = %s\n", t2->toChars());
	    if (e1)	printf("e1 = %s\n", e1->toChars());
	    if (e2)	printf("e2 = %s\n", e2->toChars());
	    if (s1)	printf("s1 = %s\n", s1->toChars());
	    if (s2)	printf("s2 = %s\n", s2->toChars());
	    if (v1)	printf("v1 = %s\n", v1->toChars());
	    if (v2)	printf("v2 = %s\n", v2->toChars());
#endif

	    TemplateTupleParameter *ttp;
	    int j;
	    if (t2 &&
		t2->ty == Tident &&
		i == tp->tempinst->tiargs->dim - 1 &&
		i == tempinst->tempdecl->parameters->dim - 1 &&
		(ttp = tempinst->tempdecl->isVariadic()) != NULL)
	    {
		/* Given:
		 *  struct A(B...) {}
		 *  alias A!(int, float) X;
		 *  static if (!is(X Y == A!(Z), Z))
		 * deduce that Z is a tuple(int, float)
		 */

		j = templateParameterLookup(t2, parameters);
		if (j == -1)
		    goto Lnomatch;

		/* Create tuple from remaining args
		 */
		Tuple *vt = new Tuple();
		int vtdim = tempinst->tiargs->dim - i;
		vt->objects.setDim(vtdim);
		for (size_t k = 0; k < vtdim; k++)
		    vt->objects.data[k] = (void *)tempinst->tiargs->data[i + k];

		Tuple *v = (Tuple *)dedtypes->data[j];
		if (v)
		{
		    if (!match(v, vt, tempinst->tempdecl, sc))
			goto Lnomatch;
		}
		else
		    dedtypes->data[j] = vt;
		break; //return MATCHexact;
	    }

	    if (t1 && t2)
	    {
		if (!t1->deduceType(sc, t2, parameters, dedtypes))
		    goto Lnomatch;
	    }
	    else if (e1 && e2)
	    {
		if (!e1->equals(e2))
		{   if (e2->op == TOKvar)
		    {
			/*
			 * (T:Number!(e2), int e2)
			 */
			j = templateIdentifierLookup(((VarExp *)e2)->var->ident, parameters);
			goto L1;
		    }
		    goto Lnomatch;
		}
	    }
	    else if (e1 && t2 && t2->ty == Tident)
	    {
		j = templateParameterLookup(t2, parameters);
	    L1:
		if (j == -1)
		    goto Lnomatch;
		TemplateParameter *tp = (TemplateParameter *)parameters->data[j];
		// BUG: use tp->matchArg() instead of the following
		TemplateValueParameter *tv = tp->isTemplateValueParameter();
		if (!tv)
		    goto Lnomatch;
		Expression *e = (Expression *)dedtypes->data[j];
		if (e)
		{
		    if (!e1->equals(e))
			goto Lnomatch;
		}
		else
		{   Type *vt = tv->valType->semantic(0, sc);
		    MATCH m = (MATCH)e1->implicitConvTo(vt);
		    if (!m)
			goto Lnomatch;
		    dedtypes->data[j] = e1;
		}
	    }
	    else if (s1 && t2 && t2->ty == Tident)
	    {
		j = templateParameterLookup(t2, parameters);
		if (j == -1)
		    goto Lnomatch;
		TemplateParameter *tp = (TemplateParameter *)parameters->data[j];
		// BUG: use tp->matchArg() instead of the following
		TemplateAliasParameter *ta = tp->isTemplateAliasParameter();
		if (!ta)
		    goto Lnomatch;
		Dsymbol *s = (Dsymbol *)dedtypes->data[j];
		if (s)
		{
		    if (!s1->equals(s))
			goto Lnomatch;
		}
		else
		{
		    dedtypes->data[j] = s1;
		}
	    }
	    else if (s1 && s2)
	    {
		if (!s1->equals(s2))
		    goto Lnomatch;
	    }
	    // BUG: Need to handle tuple parameters
	    else
		goto Lnomatch;
	}
    }
    return Type::deduceType(sc, tparam, parameters, dedtypes);

Lnomatch:
    //printf("no match\n");
    return MATCHnomatch;
}

MATCH TypeStruct::deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes)
{
    //printf("TypeStruct::deduceType()\n");
    //printf("\tthis->parent   = %s, ", sym->parent->toChars()); print();
    //printf("\ttparam = %d, ", tparam->ty); tparam->print();

    /* If this struct is a template struct, and we're matching
     * it against a template instance, convert the struct type
     * to a template instance, too, and try again.
     */
    TemplateInstance *ti = sym->parent->isTemplateInstance();

    if (tparam && tparam->ty == Tinstance)
    {
	if (ti && ti->toAlias() == sym)
	{
	    TypeInstance *t = new TypeInstance(0, ti);
	    return t->deduceType(sc, tparam, parameters, dedtypes);
	}

	/* Match things like:
	 *  S!(T).foo
	 */
	TypeInstance *tpi = (TypeInstance *)tparam;
	if (tpi->idents.dim)
	{   Identifier *id = (Identifier *)tpi->idents.data[tpi->idents.dim - 1];
	    if (id->dyncast() == DYNCAST_IDENTIFIER && sym->ident->equals(id))
	    {
		Type *tparent = sym->parent->getType();
		if (tparent)
		{
		    /* Slice off the .foo in S!(T).foo
		     */
		    tpi->idents.dim--;
		    MATCH m = tparent->deduceType(sc, tpi, parameters, dedtypes);
		    tpi->idents.dim++;
		    return m;
		}
	    }
	}
    }

    // Extra check
    if (tparam && tparam->ty == Tstruct)
    {
	TypeStruct *tp = (TypeStruct *)tparam;

	if (sym != tp->sym)
	    return MATCHnomatch;
    }
    return Type::deduceType(sc, tparam, parameters, dedtypes);
}

MATCH TypeEnum::deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes)
{
    // Extra check
    if (tparam && tparam->ty == Tenum)
    {
	TypeEnum *tp = (TypeEnum *)tparam;

	if (sym != tp->sym)
	    return MATCHnomatch;
    }
    return Type::deduceType(sc, tparam, parameters, dedtypes);
}

MATCH TypeTypedef::deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes)
{
    // Extra check
    if (tparam && tparam->ty == Ttypedef)
    {
	TypeTypedef *tp = (TypeTypedef *)tparam;

	if (sym != tp->sym)
	    return MATCHnomatch;
    }
    return Type::deduceType(sc, tparam, parameters, dedtypes);
}

MATCH TypeClass::deduceType(Scope *sc, Type *tparam, TemplateParameters *parameters, Objects *dedtypes)
{
    //printf("TypeClass::deduceType(this = %s)\n", toChars());

    /* If this class is a template class, and we're matching
     * it against a template instance, convert the class type
     * to a template instance, too, and try again.
     */
    TemplateInstance *ti = sym->parent->isTemplateInstance();

    if (tparam && tparam->ty == Tinstance)
    {
	if (ti && ti->toAlias() == sym)
	{
	    TypeInstance *t = new TypeInstance(0, ti);
	    return t->deduceType(sc, tparam, parameters, dedtypes);
	}

	/* Match things like:
	 *  S!(T).foo
	 */
	TypeInstance *tpi = (TypeInstance *)tparam;
	if (tpi->idents.dim)
	{   Identifier *id = (Identifier *)tpi->idents.data[tpi->idents.dim - 1];
	    if (id->dyncast() == DYNCAST_IDENTIFIER && sym->ident->equals(id))
	    {
		Type *tparent = sym->parent->getType();
		if (tparent)
		{
		    /* Slice off the .foo in S!(T).foo
		     */
		    tpi->idents.dim--;
		    MATCH m = tparent->deduceType(sc, tpi, parameters, dedtypes);
		    tpi->idents.dim++;
		    return m;
		}
	    }
	}
    }

    // Extra check
    if (tparam && tparam->ty == Tclass)
    {
	TypeClass *tp = (TypeClass *)tparam;

	//printf("\t%d\n", (MATCH) implicitConvTo(tp));
	return implicitConvTo(tp);
    }
    return Type::deduceType(sc, tparam, parameters, dedtypes);
}

/* ======================== TemplateParameter =============================== */

TemplateParameter::TemplateParameter(Loc loc, Identifier *ident)
{
    this->loc = loc;
    this->ident = ident;
    this->sparam = NULL;
}

TemplateTypeParameter  *TemplateParameter::isTemplateTypeParameter()
{
    return NULL;
}

TemplateValueParameter *TemplateParameter::isTemplateValueParameter()
{
    return NULL;
}

TemplateAliasParameter *TemplateParameter::isTemplateAliasParameter()
{
    return NULL;
}

TemplateTupleParameter *TemplateParameter::isTemplateTupleParameter()
{
    return NULL;
}

#if DMDV2
TemplateThisParameter  *TemplateParameter::isTemplateThisParameter()
{
    return NULL;
}
#endif

/* ======================== TemplateTypeParameter =========================== */

// type-parameter

TemplateTypeParameter::TemplateTypeParameter(Loc loc, Identifier *ident, Type *specType,
	Type *defaultType)
    : TemplateParameter(loc, ident)
{
    this->ident = ident;
    this->specType = specType;
    this->defaultType = defaultType;
}

TemplateTypeParameter  *TemplateTypeParameter::isTemplateTypeParameter()
{
    return this;
}

TemplateParameter *TemplateTypeParameter::syntaxCopy()
{
    TemplateTypeParameter *tp = new TemplateTypeParameter(loc, ident, specType, defaultType);
    if (tp->specType)
	tp->specType = specType->syntaxCopy();
    if (defaultType)
	tp->defaultType = defaultType->syntaxCopy();
    return tp;
}

void TemplateTypeParameter::declareParameter(Scope *sc)
{
    //printf("TemplateTypeParameter::declareParameter('%s')\n", ident->toChars());
    TypeIdentifier *ti = new TypeIdentifier(loc, ident);
    sparam = new AliasDeclaration(loc, ident, ti);
    if (!sc->insert(sparam))
	error(loc, "parameter '%s' multiply defined", ident->toChars());
}

void TemplateTypeParameter::semantic(Scope *sc)
{
    //printf("TemplateTypeParameter::semantic('%s')\n", ident->toChars());
    if (specType)
    {
	specType = specType->semantic(loc, sc);
    }
#if 0 // Don't do semantic() until instantiation
    if (defaultType)
    {
	defaultType = defaultType->semantic(loc, sc);
    }
#endif
}

/****************************************
 * Determine if two TemplateParameters are the same
 * as far as TemplateDeclaration overloading goes.
 * Returns:
 *	1	match
 *	0	no match
 */

int TemplateTypeParameter::overloadMatch(TemplateParameter *tp)
{
    TemplateTypeParameter *ttp = tp->isTemplateTypeParameter();

    if (ttp)
    {
	if (specType != ttp->specType)
	    goto Lnomatch;

	if (specType && !specType->equals(ttp->specType))
	    goto Lnomatch;

	return 1;			// match
    }

Lnomatch:
    return 0;
}

/*******************************************
 * Match to a particular TemplateParameter.
 * Input:
 *	i		i'th argument
 *	tiargs[]	actual arguments to template instance
 *	parameters[]	template parameters
 *	dedtypes[]	deduced arguments to template instance
 *	*psparam	set to symbol declared and initialized to dedtypes[i]
 *	flags		1: don't do 'toHeadMutable()'
 */

MATCH TemplateTypeParameter::matchArg(Scope *sc, Objects *tiargs,
	int i, TemplateParameters *parameters, Objects *dedtypes,
	Declaration **psparam, int flags)
{
    //printf("TemplateTypeParameter::matchArg()\n");
    Type *t;
    Object *oarg;
    MATCH m = MATCHexact;
    Type *ta;

    if (i < tiargs->dim)
	oarg = (Object *)tiargs->data[i];
    else
    {	// Get default argument instead
	oarg = defaultArg(loc, sc);
	if (!oarg)
	{   assert(i < dedtypes->dim);
	    // It might have already been deduced
	    oarg = (Object *)dedtypes->data[i];
	    if (!oarg)
	    {
		goto Lnomatch;
	    }
	    flags |= 1;		// already deduced, so don't to toHeadMutable()
	}
    }

    ta = isType(oarg);
    if (!ta)
    {
	//printf("%s %p %p %p\n", oarg->toChars(), isExpression(oarg), isDsymbol(oarg), isTuple(oarg));
	goto Lnomatch;
    }
    //printf("ta is %s\n", ta->toChars());

    t = (Type *)dedtypes->data[i];

    if (specType)
    {
	//printf("\tcalling deduceType(): ta is %s, specType is %s\n", ta->toChars(), specType->toChars());
	MATCH m2 = ta->deduceType(sc, specType, parameters, dedtypes);
	if (m2 == MATCHnomatch)
	{   //printf("\tfailed deduceType\n");
	    goto Lnomatch;
	}

	if (m2 < m)
	    m = m2;
	t = (Type *)dedtypes->data[i];
    }
    else
    {
	// So that matches with specializations are better
	m = MATCHconvert;

	/* This is so that:
	 *   template Foo(T), Foo!(const int), => ta == int
	 */
//	if (!(flags & 1))
//	    ta = ta->toHeadMutable();

	if (t)
	{   // Must match already deduced type

	    m = MATCHexact;
	    if (!t->equals(ta))
	    {	//printf("t = %s ta = %s\n", t->toChars(), ta->toChars());
		goto Lnomatch;
	    }
	}
    }

    if (!t)
    {
	dedtypes->data[i] = ta;
	t = ta;
    }
    *psparam = new AliasDeclaration(loc, ident, t);
    //printf("\tm = %d\n", m);
    return m;

Lnomatch:
    *psparam = NULL;
    //printf("\tm = %d\n", MATCHnomatch);
    return MATCHnomatch;
}


void TemplateTypeParameter::print(Object *oarg, Object *oded)
{
    printf(" %s\n", ident->toChars());

    Type *t  = isType(oarg);
    Type *ta = isType(oded);

    assert(ta);

    if (specType)
	printf("\tSpecialization: %s\n", specType->toChars());
    if (defaultType)
	printf("\tDefault:        %s\n", defaultType->toChars());
    printf("\tParameter:       %s\n", t ? t->toChars() : "NULL");
    printf("\tDeduced Type:   %s\n", ta->toChars());
}


void TemplateTypeParameter::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring(ident->toChars());
    if (specType)
    {
	buf->writestring(" : ");
	specType->toCBuffer(buf, NULL, hgs);
    }
    if (defaultType)
    {
	buf->writestring(" = ");
	defaultType->toCBuffer(buf, NULL, hgs);
    }
}


void *TemplateTypeParameter::dummyArg()
{   Type *t;

    if (specType)
	t = specType;
    else
    {   // Use this for alias-parameter's too (?)
	t = new TypeIdentifier(loc, ident);
    }
    return (void *)t;
}


Object *TemplateTypeParameter::specialization()
{
    return specType;
}


Object *TemplateTypeParameter::defaultArg(Loc loc, Scope *sc)
{
    Type *t;

    t = defaultType;
    if (t)
    {
	t = t->syntaxCopy();
	t = t->semantic(loc, sc);
    }
    return t;
}

/* ======================== TemplateThisParameter =========================== */

#if DMDV2
// this-parameter

TemplateThisParameter::TemplateThisParameter(Loc loc, Identifier *ident,
	Type *specType,
	Type *defaultType)
    : TemplateTypeParameter(loc, ident, specType, defaultType)
{
}

TemplateThisParameter  *TemplateThisParameter::isTemplateThisParameter()
{
    return this;
}

TemplateParameter *TemplateThisParameter::syntaxCopy()
{
    TemplateThisParameter *tp = new TemplateThisParameter(loc, ident, specType, defaultType);
    if (tp->specType)
	tp->specType = specType->syntaxCopy();
    if (defaultType)
	tp->defaultType = defaultType->syntaxCopy();
    return tp;
}

void TemplateThisParameter::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("this ");
    TemplateTypeParameter::toCBuffer(buf, hgs);
}
#endif

/* ======================== TemplateAliasParameter ========================== */

// alias-parameter

Dsymbol *TemplateAliasParameter::sdummy = NULL;

TemplateAliasParameter::TemplateAliasParameter(Loc loc, Identifier *ident,
	Type *specType, Object *specAlias, Object *defaultAlias)
    : TemplateParameter(loc, ident)
{
    this->ident = ident;
    this->specType = specType;
    this->specAlias = specAlias;
    this->defaultAlias = defaultAlias;
}

TemplateAliasParameter *TemplateAliasParameter::isTemplateAliasParameter()
{
    return this;
}

TemplateParameter *TemplateAliasParameter::syntaxCopy()
{
    TemplateAliasParameter *tp = new TemplateAliasParameter(loc, ident, specType, specAlias, defaultAlias);
    if (tp->specType)
	tp->specType = specType->syntaxCopy();
    tp->specAlias = objectSyntaxCopy(specAlias);
    tp->defaultAlias = objectSyntaxCopy(defaultAlias);
    return tp;
}

void TemplateAliasParameter::declareParameter(Scope *sc)
{
    TypeIdentifier *ti = new TypeIdentifier(loc, ident);
    sparam = new AliasDeclaration(loc, ident, ti);
    if (!sc->insert(sparam))
	error(loc, "parameter '%s' multiply defined", ident->toChars());
}

Object *aliasParameterSemantic(Loc loc, Scope *sc, Object *o)
{
    if (o)
    {
	Expression *ea = isExpression(o);
	Type *ta = isType(o);
	if (ta)
	{   Dsymbol *s = ta->toDsymbol(sc);
	    if (s)
		o = s;
	    else
		o = ta->semantic(loc, sc);
	}
	else if (ea)
	{
	    ea = ea->semantic(sc);
	    o = ea->optimize(WANTvalue | WANTinterpret);
	}
    }
    return o;
}

void TemplateAliasParameter::semantic(Scope *sc)
{
    if (specType)
    {
	specType = specType->semantic(loc, sc);
    }
    specAlias = aliasParameterSemantic(loc, sc, specAlias);
#if 0 // Don't do semantic() until instantiation
    if (defaultAlias)
	defaultAlias = defaultAlias->semantic(loc, sc);
#endif
}

int TemplateAliasParameter::overloadMatch(TemplateParameter *tp)
{
    TemplateAliasParameter *tap = tp->isTemplateAliasParameter();

    if (tap)
    {
	if (specAlias != tap->specAlias)
	    goto Lnomatch;

	return 1;			// match
    }

Lnomatch:
    return 0;
}

MATCH TemplateAliasParameter::matchArg(Scope *sc,
	Objects *tiargs, int i, TemplateParameters *parameters,
	Objects *dedtypes,
	Declaration **psparam, int flags)
{
    Object *sa;
    Object *oarg;
    Expression *ea;
    Dsymbol *s;

    //printf("TemplateAliasParameter::matchArg()\n");

    if (i < tiargs->dim)
	oarg = (Object *)tiargs->data[i];
    else
    {	// Get default argument instead
	oarg = defaultArg(loc, sc);
	if (!oarg)
	{   assert(i < dedtypes->dim);
	    // It might have already been deduced
	    oarg = (Object *)dedtypes->data[i];
	    if (!oarg)
		goto Lnomatch;
	}
    }

    sa = getDsymbol(oarg);
    if (sa)
    {
	/* specType means the alias must be a declaration with a type
	 * that matches specType.
	 */
	if (specType)
	{   Declaration *d = ((Dsymbol *)sa)->isDeclaration();
	    if (!d)
		goto Lnomatch;
	    if (!d->type->equals(specType))
		goto Lnomatch;
	}
    }
    else
    {
	sa = oarg;
	ea = isExpression(oarg);
	if (ea)
	{   if (specType)
	    {
		if (!ea->type->equals(specType))
		    goto Lnomatch;
	    }
	}
	else
	    goto Lnomatch;
    }

    if (specAlias)
    {
	if (sa == sdummy)
	    goto Lnomatch;
	if (sa != specAlias)
	    goto Lnomatch;
    }
    else if (dedtypes->data[i])
    {   // Must match already deduced symbol
	Object *s = (Object *)dedtypes->data[i];

	if (!sa || s != sa)
	    goto Lnomatch;
    }
    dedtypes->data[i] = sa;

    s = isDsymbol(sa);
    if (s)
	*psparam = new AliasDeclaration(loc, ident, s);
    else
    {
	assert(ea);

        // Declare manifest constant
        Initializer *init = new ExpInitializer(loc, ea);
        VarDeclaration *v = new VarDeclaration(loc, NULL, ident, init);
        v->storage_class = STCmanifest;
        v->semantic(sc);
	*psparam = v;
    }
    return MATCHexact;

Lnomatch:
    *psparam = NULL;
    //printf("\tm = %d\n", MATCHnomatch);
    return MATCHnomatch;
}


void TemplateAliasParameter::print(Object *oarg, Object *oded)
{
    printf(" %s\n", ident->toChars());

    Dsymbol *sa = isDsymbol(oded);
    assert(sa);

    printf("\tParameter alias: %s\n", sa->toChars());
}

void TemplateAliasParameter::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("alias ");
    if (specType)
    {	HdrGenState hgs;
	specType->toCBuffer(buf, ident, &hgs);
    }
    else
	buf->writestring(ident->toChars());
    if (specAlias)
    {
	buf->writestring(" : ");
	ObjectToCBuffer(buf, hgs, specAlias);
    }
    if (defaultAlias)
    {
	buf->writestring(" = ");
	ObjectToCBuffer(buf, hgs, defaultAlias);
    }
}


void *TemplateAliasParameter::dummyArg()
{   Object *s;

    s = specAlias;
    if (!s)
    {
	if (!sdummy)
	    sdummy = new Dsymbol();
	s = sdummy;
    }
    return (void*)s;
}


Object *TemplateAliasParameter::specialization()
{
    return specAlias;
}


Object *TemplateAliasParameter::defaultArg(Loc loc, Scope *sc)
{
    Object *o = aliasParameterSemantic(loc, sc, defaultAlias);
    return o;
}

/* ======================== TemplateValueParameter ========================== */

// value-parameter

Expression *TemplateValueParameter::edummy = NULL;

TemplateValueParameter::TemplateValueParameter(Loc loc, Identifier *ident, Type *valType,
	Expression *specValue, Expression *defaultValue)
    : TemplateParameter(loc, ident)
{
    this->ident = ident;
    this->valType = valType;
    this->specValue = specValue;
    this->defaultValue = defaultValue;
}

TemplateValueParameter *TemplateValueParameter::isTemplateValueParameter()
{
    return this;
}

TemplateParameter *TemplateValueParameter::syntaxCopy()
{
    TemplateValueParameter *tp =
	new TemplateValueParameter(loc, ident, valType, specValue, defaultValue);
    tp->valType = valType->syntaxCopy();
    if (specValue)
	tp->specValue = specValue->syntaxCopy();
    if (defaultValue)
	tp->defaultValue = defaultValue->syntaxCopy();
    return tp;
}

void TemplateValueParameter::declareParameter(Scope *sc)
{
    VarDeclaration *v = new VarDeclaration(loc, valType, ident, NULL);
    v->storage_class = STCtemplateparameter;
    if (!sc->insert(v))
	error(loc, "parameter '%s' multiply defined", ident->toChars());
    sparam = v;
}

void TemplateValueParameter::semantic(Scope *sc)
{
    sparam->semantic(sc);
    valType = valType->semantic(loc, sc);
    if (!(valType->isintegral() || valType->isfloating() || valType->isString()) &&
	valType->ty != Tident)
	error(loc, "arithmetic/string type expected for value-parameter, not %s", valType->toChars());

    if (specValue)
    {   Expression *e = specValue;

	e = e->semantic(sc);
	e = e->implicitCastTo(sc, valType);
	e = e->optimize(WANTvalue | WANTinterpret);
	if (e->op == TOKint64 || e->op == TOKfloat64 ||
	    e->op == TOKcomplex80 || e->op == TOKnull || e->op == TOKstring)
	    specValue = e;
	//e->toInteger();
    }

#if 0	// defer semantic analysis to arg match
    if (defaultValue)
    {   Expression *e = defaultValue;

	e = e->semantic(sc);
	e = e->implicitCastTo(sc, valType);
	e = e->optimize(WANTvalue | WANTinterpret);
	if (e->op == TOKint64)
	    defaultValue = e;
	//e->toInteger();
    }
#endif
}

int TemplateValueParameter::overloadMatch(TemplateParameter *tp)
{
    TemplateValueParameter *tvp = tp->isTemplateValueParameter();

    if (tvp)
    {
	if (valType != tvp->valType)
	    goto Lnomatch;

	if (valType && !valType->equals(tvp->valType))
	    goto Lnomatch;

	if (specValue != tvp->specValue)
	    goto Lnomatch;

	return 1;			// match
    }

Lnomatch:
    return 0;
}


MATCH TemplateValueParameter::matchArg(Scope *sc,
	Objects *tiargs, int i, TemplateParameters *parameters, Objects *dedtypes,
	Declaration **psparam, int flags)
{
    //printf("TemplateValueParameter::matchArg()\n");

    Initializer *init;
    Declaration *sparam;
    MATCH m = MATCHexact;
    Expression *ei;
    Object *oarg;

    if (i < tiargs->dim)
	oarg = (Object *)tiargs->data[i];
    else
    {	// Get default argument instead
	oarg = defaultArg(loc, sc);
	if (!oarg)
	{   assert(i < dedtypes->dim);
	    // It might have already been deduced
	    oarg = (Object *)dedtypes->data[i];
	    if (!oarg)
		goto Lnomatch;
	}
    }

    ei = isExpression(oarg);
    Type *vt;

    if (!ei && oarg)
	goto Lnomatch;

    if (ei && ei->op == TOKvar)
    {	// Resolve const variables that we had skipped earlier
	ei = ei->optimize(WANTvalue | WANTinterpret);
    }

    if (specValue)
    {
	if (!ei || ei == edummy)
	    goto Lnomatch;

	Expression *e = specValue;

	e = e->semantic(sc);
	e = e->implicitCastTo(sc, valType);
	e = e->optimize(WANTvalue | WANTinterpret);
	//e->type = e->type->toHeadMutable();

	ei = ei->syntaxCopy();
	ei = ei->semantic(sc);
	ei = ei->optimize(WANTvalue | WANTinterpret);
	//ei->type = ei->type->toHeadMutable();
	//printf("\tei: %s, %s\n", ei->toChars(), ei->type->toChars());
	//printf("\te : %s, %s\n", e->toChars(), e->type->toChars());
	if (!ei->equals(e))
	    goto Lnomatch;
    }
    else if (dedtypes->data[i])
    {   // Must match already deduced value
	Expression *e = (Expression *)dedtypes->data[i];

	if (!ei || !ei->equals(e))
	    goto Lnomatch;
    }
Lmatch:
    //printf("\tvalType: %s, ty = %d\n", valType->toChars(), valType->ty);
    vt = valType->semantic(0, sc);
    //printf("ei: %s, ei->type: %s\n", ei->toChars(), ei->type->toChars());
    //printf("vt = %s\n", vt->toChars());
    if (ei->type)
    {
	m = (MATCH)ei->implicitConvTo(vt);
	//printf("m: %d\n", m);
	if (!m)
	    goto Lnomatch;
    }
    dedtypes->data[i] = ei;

    init = new ExpInitializer(loc, ei);
    sparam = new VarDeclaration(loc, vt, ident, init);
    sparam->storage_class = STCmanifest;
    *psparam = sparam;
    return m;

Lnomatch:
    //printf("\tno match\n");
    *psparam = NULL;
    return MATCHnomatch;
}


void TemplateValueParameter::print(Object *oarg, Object *oded)
{
    printf(" %s\n", ident->toChars());

    Expression *ea = isExpression(oded);

    if (specValue)
	printf("\tSpecialization: %s\n", specValue->toChars());
    printf("\tParameter Value: %s\n", ea ? ea->toChars() : "NULL");
}


void TemplateValueParameter::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    valType->toCBuffer(buf, ident, hgs);
    if (specValue)
    {
	buf->writestring(" : ");
	specValue->toCBuffer(buf, hgs);
    }
    if (defaultValue)
    {
	buf->writestring(" = ");
	defaultValue->toCBuffer(buf, hgs);
    }
}


void *TemplateValueParameter::dummyArg()
{   Expression *e;

    e = specValue;
    if (!e)
    {
	// Create a dummy value
	if (!edummy)
	    edummy = valType->defaultInit();
	e = edummy;
    }
    return (void *)e;
}


Object *TemplateValueParameter::specialization()
{
    return specValue;
}


Object *TemplateValueParameter::defaultArg(Loc loc, Scope *sc)
{
    Expression *e = defaultValue;
    if (e)
    {
	e = e->syntaxCopy();
	e = e->semantic(sc);
#if DMDV2
	e = e->resolveLoc(loc, sc);
#endif
    }
    return e;
}

/* ======================== TemplateTupleParameter ========================== */

// variadic-parameter

TemplateTupleParameter::TemplateTupleParameter(Loc loc, Identifier *ident)
    : TemplateParameter(loc, ident)
{
    this->ident = ident;
}

TemplateTupleParameter *TemplateTupleParameter::isTemplateTupleParameter()
{
    return this;
}

TemplateParameter *TemplateTupleParameter::syntaxCopy()
{
    TemplateTupleParameter *tp = new TemplateTupleParameter(loc, ident);
    return tp;
}

void TemplateTupleParameter::declareParameter(Scope *sc)
{
    TypeIdentifier *ti = new TypeIdentifier(loc, ident);
    sparam = new AliasDeclaration(loc, ident, ti);
    if (!sc->insert(sparam))
	error(loc, "parameter '%s' multiply defined", ident->toChars());
}

void TemplateTupleParameter::semantic(Scope *sc)
{
}

int TemplateTupleParameter::overloadMatch(TemplateParameter *tp)
{
    TemplateTupleParameter *tvp = tp->isTemplateTupleParameter();

    if (tvp)
    {
	return 1;			// match
    }

Lnomatch:
    return 0;
}

MATCH TemplateTupleParameter::matchArg(Scope *sc,
	Objects *tiargs, int i, TemplateParameters *parameters,
	Objects *dedtypes,
	Declaration **psparam, int flags)
{
    //printf("TemplateTupleParameter::matchArg()\n");

    /* The rest of the actual arguments (tiargs[]) form the match
     * for the variadic parameter.
     */
    assert(i + 1 == dedtypes->dim);	// must be the last one
    Tuple *ovar;
    if (i + 1 == tiargs->dim && isTuple((Object *)tiargs->data[i]))
	ovar = isTuple((Object *)tiargs->data[i]);
    else
    {
	ovar = new Tuple();
	//printf("ovar = %p\n", ovar);
	if (i < tiargs->dim)
	{
	    //printf("i = %d, tiargs->dim = %d\n", i, tiargs->dim);
	    ovar->objects.setDim(tiargs->dim - i);
	    for (size_t j = 0; j < ovar->objects.dim; j++)
		ovar->objects.data[j] = tiargs->data[i + j];
	}
    }
    *psparam = new TupleDeclaration(loc, ident, &ovar->objects);
    dedtypes->data[i] = (void *)ovar;
    return MATCHexact;
}


void TemplateTupleParameter::print(Object *oarg, Object *oded)
{
    printf(" %s... [", ident->toChars());
    Tuple *v = isTuple(oded);
    assert(v);

    //printf("|%d| ", v->objects.dim);
    for (int i = 0; i < v->objects.dim; i++)
    {
	if (i)
	    printf(", ");

	Object *o = (Object *)v->objects.data[i];

	Dsymbol *sa = isDsymbol(o);
	if (sa)
	    printf("alias: %s", sa->toChars());

	Type *ta = isType(o);
	if (ta)
	    printf("type: %s", ta->toChars());

	Expression *ea = isExpression(o);
	if (ea)
	    printf("exp: %s", ea->toChars());

	assert(!isTuple(o));		// no nested Tuple arguments
    }

    printf("]\n");
}

void TemplateTupleParameter::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring(ident->toChars());
    buf->writestring("...");
}


void *TemplateTupleParameter::dummyArg()
{
    return NULL;
}


Object *TemplateTupleParameter::specialization()
{
    return NULL;
}


Object *TemplateTupleParameter::defaultArg(Loc loc, Scope *sc)
{
    return NULL;
}

/* ======================== TemplateInstance ================================ */

TemplateInstance::TemplateInstance(Loc loc, Identifier *ident)
    : ScopeDsymbol(NULL)
{
#if LOG
    printf("TemplateInstance(this = %p, ident = '%s')\n", this, ident ? ident->toChars() : "null");
#endif
    this->loc = loc;
    this->name = ident;
    this->tiargs = NULL;
    this->tempdecl = NULL;
    this->inst = NULL;
    this->tinst = NULL;
    this->argsym = NULL;
    this->aliasdecl = NULL;
    this->semanticRun = 0;
    this->semantictiargsdone = 0;
    this->withsym = NULL;
    this->nest = 0;
    this->havetempdecl = 0;
    this->isnested = NULL;
    this->errors = 0;
}

/*****************
 * This constructor is only called when we figured out which function
 * template to instantiate.
 */

TemplateInstance::TemplateInstance(Loc loc, TemplateDeclaration *td, Objects *tiargs)
    : ScopeDsymbol(NULL)
{
#if LOG
    printf("TemplateInstance(this = %p, tempdecl = '%s')\n", this, td->toChars());
#endif
    this->loc = loc;
    this->name = td->ident;
    this->tiargs = tiargs;
    this->tempdecl = td;
    this->inst = NULL;
    this->tinst = NULL;
    this->argsym = NULL;
    this->aliasdecl = NULL;
    this->semanticRun = 0;
    this->semantictiargsdone = 1;
    this->withsym = NULL;
    this->nest = 0;
    this->havetempdecl = 1;
    this->isnested = NULL;
    this->errors = 0;

    assert((size_t)tempdecl->scope > 0x10000);
}


Objects *TemplateInstance::arraySyntaxCopy(Objects *objs)
{
    Objects *a = NULL;
    if (objs)
    {	a = new Objects();
	a->setDim(objs->dim);
	for (size_t i = 0; i < objs->dim; i++)
	{
	    a->data[i] = objectSyntaxCopy((Object *)objs->data[i]);
	}
    }
    return a;
}

Dsymbol *TemplateInstance::syntaxCopy(Dsymbol *s)
{
    TemplateInstance *ti;

    if (s)
	ti = (TemplateInstance *)s;
    else
	ti = new TemplateInstance(loc, name);

    ti->tiargs = arraySyntaxCopy(tiargs);

    ScopeDsymbol::syntaxCopy(ti);
    return ti;
}


void TemplateInstance::semantic(Scope *sc)
{
    if (global.errors)
    {
	if (!global.gag)
	{
	    /* Trying to soldier on rarely generates useful messages
	     * at this point.
	     */
	    fatal();
	}
	return;
    }
#if LOG
    printf("\n+TemplateInstance::semantic('%s', this=%p)\n", toChars(), this);
#endif
    if (inst)		// if semantic() was already run
    {
#if LOG
	printf("-TemplateInstance::semantic('%s', this=%p) already run\n", inst->toChars(), inst);
#endif
	return;
    }

    // get the enclosing template instance from the scope tinst
    tinst = sc->tinst;

    if (semanticRun != 0)
    {
	error(loc, "recursive template expansion");
//	inst = this;
	return;
    }
    semanticRun = 1;

#if LOG
    printf("\tdo semantic\n");
#endif
    if (havetempdecl)
    {
	assert((size_t)tempdecl->scope > 0x10000);
	// Deduce tdtypes
	tdtypes.setDim(tempdecl->parameters->dim);
	if (!tempdecl->matchWithInstance(this, &tdtypes, 2))
	{
	    error("incompatible arguments for template instantiation");
	    inst = this;
	    return;
	}
    }
    else
    {
	/* Run semantic on each argument, place results in tiargs[]
	 * (if we havetempdecl, then tiargs is already evaluated)
	 */
	semanticTiargs(sc);

	tempdecl = findTemplateDeclaration(sc);
	if (tempdecl)
	    tempdecl = findBestMatch(sc);
	if (!tempdecl || global.errors)
	{   inst = this;
	    //printf("error return %p, %d\n", tempdecl, global.errors);
	    return;		// error recovery
	}
    }

    hasNestedArgs(tiargs);

    /* See if there is an existing TemplateInstantiation that already
     * implements the typeargs. If so, just refer to that one instead.
     */

    for (size_t i = 0; i < tempdecl->instances.dim; i++)
    {
	TemplateInstance *ti = (TemplateInstance *)tempdecl->instances.data[i];
#if LOG
	printf("\t%s: checking for match with instance %d (%p): '%s'\n", toChars(), i, ti, ti->toChars());
#endif
	assert(tdtypes.dim == ti->tdtypes.dim);

	// Nesting must match
	if (isnested != ti->isnested)
	{
	    //printf("test2 isnested %s ti->isnested %s\n", isnested ? isnested->toChars() : "", ti->isnested ? ti->isnested->toChars() : "");
	    continue;
	}
#if 0
	if (isnested && sc->parent != ti->parent)
	    continue;
#endif
	for (size_t j = 0; j < tdtypes.dim; j++)
	{   Object *o1 = (Object *)tdtypes.data[j];
	    Object *o2 = (Object *)ti->tdtypes.data[j];
	    if (!match(o1, o2, tempdecl, sc))
	    {
		goto L1;
	    }
	}

	// It's a match
	inst = ti;
	parent = ti->parent;
#if LOG
	printf("\tit's a match with instance %p\n", inst);
#endif
	return;

     L1:
	;
    }

    /* So, we need to implement 'this' instance.
     */
#if LOG
    printf("\timplement template instance '%s'\n", toChars());
#endif
    unsigned errorsave = global.errors;
    inst = this;
    int tempdecl_instance_idx = tempdecl->instances.dim;
    tempdecl->instances.push(this);
    parent = tempdecl->parent;
    //printf("parent = '%s'\n", parent->kind());

    ident = genIdent();		// need an identifier for name mangling purposes.

#if 1
    if (isnested)
	parent = isnested;
#endif
    //printf("parent = '%s'\n", parent->kind());

    // Add 'this' to the enclosing scope's members[] so the semantic routines
    // will get called on the instance members
#if 1
    int dosemantic3 = 0;
    {	Array *a;

	Scope *scx = sc;
#if 0
	for (scx = sc; scx; scx = scx->enclosing)
	    if (scx->scopesym)
		break;
#endif

	//if (scx && scx->scopesym) printf("3: scx is %s %s\n", scx->scopesym->kind(), scx->scopesym->toChars());
	if (scx && scx->scopesym &&
	    scx->scopesym->members && !scx->scopesym->isTemplateMixin()
#if 0 // removed because it bloated compile times
	    /* The problem is if A imports B, and B imports A, and both A
	     * and B instantiate the same template, does the compilation of A
	     * or the compilation of B do the actual instantiation?
	     *
	     * see bugzilla 2500.
	     */
	    && !scx->module->selfImports()
#endif
	   )
	{
	    //printf("\t1: adding to %s %s\n", scx->scopesym->kind(), scx->scopesym->toChars());
	    a = scx->scopesym->members;
	}
	else
	{   Module *m = sc->module->importedFrom;
	    //printf("\t2: adding to module %s instead of module %s\n", m->toChars(), sc->module->toChars());
	    a = m->members;
	    if (m->semanticRun >= 3)
		dosemantic3 = 1;
	}
	for (int i = 0; 1; i++)
	{
	    if (i == a->dim)
	    {
		a->push(this);
		break;
	    }
	    if (this == (Dsymbol *)a->data[i])	// if already in Array
		break;
	}
    }
#endif

    // Copy the syntax trees from the TemplateDeclaration
    members = Dsymbol::arraySyntaxCopy(tempdecl->members);

    // Create our own scope for the template parameters
    Scope *scope = tempdecl->scope;
    if (!tempdecl->semanticRun)
    {
	error("template instantiation %s forward references template declaration %s\n", toChars(), tempdecl->toChars());
	return;
    }

#if LOG
    printf("\tcreate scope for template parameters '%s'\n", toChars());
#endif
    argsym = new ScopeDsymbol();
    argsym->parent = scope->parent;
    scope = scope->push(argsym);
//    scope->stc = 0;

    // Declare each template parameter as an alias for the argument type
    Scope *paramscope = scope->push();
    paramscope->stc = 0;
    declareParameters(paramscope);
    paramscope->pop();

    // Add members of template instance to template instance symbol table
//    parent = scope->scopesym;
    symtab = new DsymbolTable();
    int memnum = 0;
    for (int i = 0; i < members->dim; i++)
    {
	Dsymbol *s = (Dsymbol *)members->data[i];
#if LOG
	printf("\t[%d] adding member '%s' %p kind %s to '%s', memnum = %d\n", i, s->toChars(), s, s->kind(), this->toChars(), memnum);
#endif
	memnum |= s->addMember(scope, this, memnum);
    }
#if LOG
    printf("adding members done\n");
#endif

    /* See if there is only one member of template instance, and that
     * member has the same name as the template instance.
     * If so, this template instance becomes an alias for that member.
     */
    //printf("members->dim = %d\n", members->dim);
    if (members->dim)
    {
	Dsymbol *s;
	if (Dsymbol::oneMembers(members, &s) && s)
	{
	    //printf("s->kind = '%s'\n", s->kind());
	    //s->print();
	    //printf("'%s', '%s'\n", s->ident->toChars(), tempdecl->ident->toChars());
	    if (s->ident && s->ident->equals(tempdecl->ident))
	    {
		//printf("setting aliasdecl\n");
		aliasdecl = new AliasDeclaration(loc, s->ident, s);
	    }
	}
    }

    // Do semantic() analysis on template instance members
#if LOG
    printf("\tdo semantic() on template instance members '%s'\n", toChars());
#endif
    Scope *sc2;
    sc2 = scope->push(this);
    //printf("isnested = %d, sc->parent = %s\n", isnested, sc->parent->toChars());
    sc2->parent = /*isnested ? sc->parent :*/ this;
    sc2->tinst = this;

#if WINDOWS_SEH
  __try
  {
#endif
    static int nest;
    //printf("%d\n", nest);
    if (++nest > 500)
    {
	global.gag = 0;			// ensure error message gets printed
	error("recursive expansion");
	fatal();
    }
    for (int i = 0; i < members->dim; i++)
    {
	Dsymbol *s = (Dsymbol *)members->data[i];
	//printf("\t[%d] semantic on '%s' %p kind %s in '%s'\n", i, s->toChars(), s, s->kind(), this->toChars());
	//printf("test: isnested = %d, sc2->parent = %s\n", isnested, sc2->parent->toChars());
//	if (isnested)
//	    s->parent = sc->parent;
	//printf("test3: isnested = %d, s->parent = %s\n", isnested, s->parent->toChars());
	s->semantic(sc2);
	//printf("test4: isnested = %d, s->parent = %s\n", isnested, s->parent->toChars());
	sc2->module->runDeferredSemantic();
    }
    --nest;
#if WINDOWS_SEH
  }
  __except (__ehfilter(GetExceptionInformation()))
  {
    global.gag = 0;			// ensure error message gets printed
    error("recursive expansion");
    fatal();
  }
#endif

    /* If any of the instantiation members didn't get semantic() run
     * on them due to forward references, we cannot run semantic2()
     * or semantic3() yet.
     */
    for (size_t i = 0; i < Module::deferred.dim; i++)
    {	Dsymbol *sd = (Dsymbol *)Module::deferred.data[i];

	if (sd->parent == this)
	    goto Laftersemantic;
    }

    /* The problem is when to parse the initializer for a variable.
     * Perhaps VarDeclaration::semantic() should do it like it does
     * for initializers inside a function.
     */
//    if (sc->parent->isFuncDeclaration())

	/* BUG 782: this has problems if the classes this depends on
	 * are forward referenced. Find a way to defer semantic()
	 * on this template.
	 */
	semantic2(sc2);

    if (sc->func || dosemantic3)
    {
#if WINDOWS_SEH
	__try
	{
#endif
	    static int nest;
	    if (++nest > 300)
	    {
		global.gag = 0;            // ensure error message gets printed
		error("recursive expansion");
		fatal();
	    }
	    semantic3(sc2);
	    --nest;
#if WINDOWS_SEH
	}
	__except (__ehfilter(GetExceptionInformation()))
	{
	    global.gag = 0;            // ensure error message gets printed
	    error("recursive expansion");
	    fatal();
	}
#endif
    }

  Laftersemantic:
    sc2->pop();

    scope->pop();

    // Give additional context info if error occurred during instantiation
    if (global.errors != errorsave)
    {
	error("error instantiating");
	if (tinst)
	{   tinst->printInstantiationTrace();
	    fatal();
	}
	errors = 1;
	if (global.gag)
	    tempdecl->instances.remove(tempdecl_instance_idx);
    }

#if LOG
    printf("-TemplateInstance::semantic('%s', this=%p)\n", toChars(), this);
#endif
}


void TemplateInstance::semanticTiargs(Scope *sc)
{
    //printf("+TemplateInstance::semanticTiargs() %s\n", toChars());
    if (semantictiargsdone)
	return;
    semantictiargsdone = 1;
    semanticTiargs(loc, sc, tiargs, 0);
}

/**********************************
 * Input:
 *	flags	1: replace const variables with their initializers
 */

void TemplateInstance::semanticTiargs(Loc loc, Scope *sc, Objects *tiargs, int flags)
{
    // Run semantic on each argument, place results in tiargs[]
    //printf("+TemplateInstance::semanticTiargs() %s\n", toChars());
    if (!tiargs)
	return;
    for (size_t j = 0; j < tiargs->dim; j++)
    {
	Object *o = (Object *)tiargs->data[j];
	Type *ta = isType(o);
	Expression *ea = isExpression(o);
	Dsymbol *sa = isDsymbol(o);

	//printf("1: tiargs->data[%d] = %p, %p, %p, ea=%p, ta=%p\n", j, o, isDsymbol(o), isTuple(o), ea, ta);
	if (ta)
	{
	    //printf("type %s\n", ta->toChars());
	    // It might really be an Expression or an Alias
	    ta->resolve(loc, sc, &ea, &ta, &sa);
	    if (ea)
	    {
		ea = ea->semantic(sc);
		/* This test is to skip substituting a const var with
		 * its initializer. The problem is the initializer won't
		 * match with an 'alias' parameter. Instead, do the
		 * const substitution in TemplateValueParameter::matchArg().
		 */
		if (ea->op != TOKvar || flags & 1)
		    ea = ea->optimize(WANTvalue | WANTinterpret);
		tiargs->data[j] = ea;
	    }
	    else if (sa)
	    {	tiargs->data[j] = sa;
		TupleDeclaration *d = sa->toAlias()->isTupleDeclaration();
		if (d)
		{
		    size_t dim = d->objects->dim;
		    tiargs->remove(j);
		    tiargs->insert(j, d->objects);
		    j--;
		}
	    }
	    else if (ta)
	    {
	      Ltype:
		if (ta->ty == Ttuple)
		{   // Expand tuple
		    TypeTuple *tt = (TypeTuple *)ta;
		    size_t dim = tt->arguments->dim;
		    tiargs->remove(j);
		    if (dim)
		    {	tiargs->reserve(dim);
			for (size_t i = 0; i < dim; i++)
			{   Parameter *arg = (Parameter *)tt->arguments->data[i];
			    tiargs->insert(j + i, arg->type);
			}
		    }
		    j--;
		}
		else
		    tiargs->data[j] = ta;
	    }
	    else
	    {
		assert(global.errors);
		tiargs->data[j] = Type::terror;
	    }
	}
	else if (ea)
	{
	    if (!ea)
	    {	assert(global.errors);
		ea = new IntegerExp(0);
	    }
	    assert(ea);
	    ea = ea->semantic(sc);
	    if (ea->op != TOKvar || flags & 1)
		ea = ea->optimize(WANTvalue | WANTinterpret);
	    tiargs->data[j] = ea;
	    if (ea->op == TOKtype)
	    {	ta = ea->type;
		goto Ltype;
	    }
	    if (ea->op == TOKtuple)
	    {   // Expand tuple
		TupleExp *te = (TupleExp *)ea;
		size_t dim = te->exps->dim;
		tiargs->remove(j);
		if (dim)
		{   tiargs->reserve(dim);
		    for (size_t i = 0; i < dim; i++)
			tiargs->insert(j + i, te->exps->data[i]);
		}
		j--;
	    }
	}
	else if (sa)
	{
	    TemplateDeclaration *td = sa->isTemplateDeclaration();
	    if (td && !td->semanticRun && td->literal)
		td->semantic(sc);
	}
	else
	{
	    assert(0);
	}
	//printf("1: tiargs->data[%d] = %p\n", j, tiargs->data[j]);
    }
#if 0
    printf("-TemplateInstance::semanticTiargs('%s', this=%p)\n", toChars(), this);
    for (size_t j = 0; j < tiargs->dim; j++)
    {
	Object *o = (Object *)tiargs->data[j];
	Type *ta = isType(o);
	Expression *ea = isExpression(o);
	Dsymbol *sa = isDsymbol(o);
	Tuple *va = isTuple(o);

	printf("\ttiargs[%d] = ta %p, ea %p, sa %p, va %p\n", j, ta, ea, sa, va);
    }
#endif
}

/**********************************************
 * Find template declaration corresponding to template instance.
 */

TemplateDeclaration *TemplateInstance::findTemplateDeclaration(Scope *sc)
{
    //printf("TemplateInstance::findTemplateDeclaration() %s\n", toChars());
    if (!tempdecl)
    {
	/* Given:
	 *    foo!( ... )
	 * figure out which TemplateDeclaration foo refers to.
	 */
	Dsymbol *s;
	Dsymbol *scopesym;
	Identifier *id;
	int i;

	id = name;
	s = sc->search(loc, id, &scopesym);
	if (!s)
	{   error("template '%s' is not defined", id->toChars());
	    return NULL;
	}

	/* If an OverloadSet, look for a unique member that is a template declaration
	 */
	OverloadSet *os = s->isOverloadSet();
	if (os)
	{   s = NULL;
	    for (int i = 0; i < os->a.dim; i++)
	    {	Dsymbol *s2 = (Dsymbol *)os->a.data[i];
		if (s2->isTemplateDeclaration())
		{
		    if (s)
			error("ambiguous template declaration %s and %s", s->toPrettyChars(), s2->toPrettyChars());
		    s = s2;
		}
	    }
	    if (!s)
	    {   error("template '%s' is not defined", id->toChars());
		return NULL;
	    }
	}

#if LOG
	printf("It's an instance of '%s' kind '%s'\n", s->toChars(), s->kind());
	if (s->parent)
	    printf("s->parent = '%s'\n", s->parent->toChars());
#endif
	withsym = scopesym->isWithScopeSymbol();

	/* We might have found an alias within a template when
	 * we really want the template.
	 */
	TemplateInstance *ti;
	if (s->parent &&
	    (ti = s->parent->isTemplateInstance()) != NULL)
	{
	    if (
		(ti->name == id ||
		 ti->toAlias()->ident == id)
		&&
		ti->tempdecl)
	    {
		/* This is so that one can refer to the enclosing
		 * template, even if it has the same name as a member
		 * of the template, if it has a !(arguments)
		 */
		tempdecl = ti->tempdecl;
		if (tempdecl->overroot)		// if not start of overloaded list of TemplateDeclaration's
		    tempdecl = tempdecl->overroot; // then get the start
		s = tempdecl;
	    }
	}

	s = s->toAlias();

	/* It should be a TemplateDeclaration, not some other symbol
	 */
	tempdecl = s->isTemplateDeclaration();
	if (!tempdecl)
	{
	    if (!s->parent && global.errors)
		return NULL;
	    if (!s->parent && s->getType())
	    {	Dsymbol *s2 = s->getType()->toDsymbol(sc);
		if (!s2)
		{
		    error("%s is not a template declaration, it is a %s", id->toChars(), s->kind());
		    return NULL;
		}
		s = s2;
	    }
#ifdef DEBUG
	    //if (!s->parent) printf("s = %s %s\n", s->kind(), s->toChars());
#endif
	    //assert(s->parent);
	    TemplateInstance *ti = s->parent ? s->parent->isTemplateInstance() : NULL;
	    if (ti &&
		(ti->name == id ||
		 ti->toAlias()->ident == id)
		&&
		ti->tempdecl)
	    {
		/* This is so that one can refer to the enclosing
		 * template, even if it has the same name as a member
		 * of the template, if it has a !(arguments)
		 */
		tempdecl = ti->tempdecl;
		if (tempdecl->overroot)		// if not start of overloaded list of TemplateDeclaration's
		    tempdecl = tempdecl->overroot; // then get the start
	    }
	    else
	    {
		error("%s is not a template declaration, it is a %s", id->toChars(), s->kind());
		return NULL;
	    }
	}
    }
    else
	assert(tempdecl->isTemplateDeclaration());
    return tempdecl;
}

TemplateDeclaration *TemplateInstance::findBestMatch(Scope *sc)
{
    /* Since there can be multiple TemplateDeclaration's with the same
     * name, look for the best match.
     */
    TemplateDeclaration *td_ambig = NULL;
    TemplateDeclaration *td_best = NULL;
    MATCH m_best = MATCHnomatch;
    Objects dedtypes;

#if LOG
    printf("TemplateInstance::findBestMatch()\n");
#endif
    // First look for forward references
    for (TemplateDeclaration *td = tempdecl; td; td = td->overnext)
    {
	if (!td->semanticRun)
	{
	    if (td->scope)
	    {	// Try to fix forward reference
		td->semantic(td->scope);
	    }
	    if (!td->semanticRun)
	    {
		error("%s forward references template declaration %s\n", toChars(), td->toChars());
		return NULL;
	    }
	}
    }

    for (TemplateDeclaration *td = tempdecl; td; td = td->overnext)
    {
	MATCH m;

//if (tiargs->dim) printf("2: tiargs->dim = %d, data[0] = %p\n", tiargs->dim, tiargs->data[0]);

	// If more arguments than parameters,
	// then this is no match.
	if (td->parameters->dim < tiargs->dim)
	{
	    if (!td->isVariadic())
		continue;
	}

	dedtypes.setDim(td->parameters->dim);
	dedtypes.zero();
	assert(td->semanticRun);
	m = td->matchWithInstance(this, &dedtypes, 0);
	//printf("matchWithInstance = %d\n", m);
	if (!m)			// no match at all
	    continue;

	if (m < m_best)
	    goto Ltd_best;
	if (m > m_best)
	    goto Ltd;

	{
	// Disambiguate by picking the most specialized TemplateDeclaration
	MATCH c1 = td->leastAsSpecialized(td_best);
	MATCH c2 = td_best->leastAsSpecialized(td);
	//printf("c1 = %d, c2 = %d\n", c1, c2);

	if (c1 > c2)
	    goto Ltd;
	else if (c1 < c2)
	    goto Ltd_best;
	else
	    goto Lambig;
	}

      Lambig:		// td_best and td are ambiguous
	td_ambig = td;
	continue;

      Ltd_best:		// td_best is the best match so far
	td_ambig = NULL;
	continue;

      Ltd:		// td is the new best match
	td_ambig = NULL;
	td_best = td;
	m_best = m;
	tdtypes.setDim(dedtypes.dim);
	memcpy(tdtypes.data, dedtypes.data, tdtypes.dim * sizeof(void *));
	continue;
    }

    if (!td_best)
    {
	if (tempdecl && !tempdecl->overnext)
	    // Only one template, so we can give better error message
	    error("%s does not match template declaration %s", toChars(), tempdecl->toChars());
	else
	    error("%s does not match any template declaration", toChars());
	return NULL;
    }
    if (td_ambig)
    {
	error("%s matches more than one template declaration, %s and %s",
		toChars(), td_best->toChars(), td_ambig->toChars());
    }

    /* The best match is td_best
     */
    tempdecl = td_best;

#if 0
    /* Cast any value arguments to be same type as value parameter
     */
    for (size_t i = 0; i < tiargs->dim; i++)
    {	Object *o = (Object *)tiargs->data[i];
	Expression *ea = isExpression(o);	// value argument
	TemplateParameter *tp = (TemplateParameter *)tempdecl->parameters->data[i];
	assert(tp);
	TemplateValueParameter *tvp = tp->isTemplateValueParameter();
	if (tvp)
	{
	    assert(ea);
	    ea = ea->castTo(tvp->valType);
	    ea = ea->optimize(WANTvalue | WANTinterpret);
	    tiargs->data[i] = (Object *)ea;
	}
    }
#endif

#if LOG
    printf("\tIt's a match with template declaration '%s'\n", tempdecl->toChars());
#endif
    return tempdecl;
}


/*****************************************
 * Determines if a TemplateInstance will need a nested
 * generation of the TemplateDeclaration.
 */

int TemplateInstance::hasNestedArgs(Objects *args)
{   int nested = 0;
    //printf("TemplateInstance::hasNestedArgs('%s')\n", tempdecl->ident->toChars());

    /* A nested instance happens when an argument references a local
     * symbol that is on the stack.
     */
    for (size_t i = 0; i < args->dim; i++)
    {   Object *o = (Object *)args->data[i];
	Expression *ea = isExpression(o);
	Dsymbol *sa = isDsymbol(o);
	Tuple *va = isTuple(o);
	if (ea)
	{
	    if (ea->op == TOKvar)
	    {
		sa = ((VarExp *)ea)->var;
		goto Lsa;
	    }
	    if (ea->op == TOKfunction)
	    {
		sa = ((FuncExp *)ea)->fd;
		goto Lsa;
	    }
	}
	else if (sa)
	{
	  Lsa:
	    TemplateDeclaration *td = sa->isTemplateDeclaration();
	    Declaration *d = sa->isDeclaration();
	    if ((td && td->literal) ||
	        (d && !d->isDataseg() &&
#if DMDV2
		 !(d->storage_class & STCmanifest) &&
#endif
		 (!d->isFuncDeclaration() || d->isFuncDeclaration()->isNested()) &&
		 !isTemplateMixin()
		))
	    {
		// if module level template
		if (tempdecl->toParent()->isModule())
		{   Dsymbol *dparent = sa->toParent();
		    if (!isnested)
			isnested = dparent;
		    else if (isnested != dparent)
		    {
			/* Select the more deeply nested of the two.
			 * Error if one is not nested inside the other.
			 */
			for (Dsymbol *p = isnested; p; p = p->parent)
			{
			    if (p == dparent)
				goto L1;	// isnested is most nested
			}
			for (Dsymbol *p = dparent; p; p = p->parent)
			{
			    if (p == isnested)
			    {	isnested = dparent;
				goto L1;	// dparent is most nested
			    }
			}
			error("%s is nested in both %s and %s",
				toChars(), isnested->toChars(), dparent->toChars());
		    }
		  L1:
		    //printf("\tnested inside %s\n", isnested->toChars());
		    nested |= 1;
		}
		else
		    error("cannot use local '%s' as parameter to non-global template %s", sa->toChars(), tempdecl->toChars());
	    }
	}
	else if (va)
	{
	    nested |= hasNestedArgs(&va->objects);
	}
    }
    return nested;
}

/****************************************
 * This instance needs an identifier for name mangling purposes.
 * Create one by taking the template declaration name and adding
 * the type signature for it.
 */

Identifier *TemplateInstance::genIdent()
{   OutBuffer buf;

    //printf("TemplateInstance::genIdent('%s')\n", tempdecl->ident->toChars());
    char *id = tempdecl->ident->toChars();
    buf.printf("__T%zu%s", strlen(id), id);
    Objects *args = tiargs;
    for (int i = 0; i < args->dim; i++)
    {   Object *o = (Object *)args->data[i];
	Type *ta = isType(o);
	Expression *ea = isExpression(o);
	Dsymbol *sa = isDsymbol(o);
	Tuple *va = isTuple(o);
	//printf("\to [%d] %p ta %p ea %p sa %p va %p\n", i, o, ta, ea, sa, va);
	if (ta)
	{
	    buf.writeByte('T');
	    if (ta->deco)
		buf.writestring(ta->deco);
	    else
	    {
#ifdef DEBUG
		printf("ta = %d, %s\n", ta->ty, ta->toChars());
#endif
		assert(global.errors);
	    }
	}
	else if (ea)
	{
	  Lea:
	    sinteger_t v;
	    real_t r;

	    ea = ea->optimize(WANTvalue | WANTinterpret);
	    if (ea->op == TOKvar)
	    {
		sa = ((VarExp *)ea)->var;
		ea = NULL;
		goto Lsa;
	    }
	    if (ea->op == TOKfunction)
	    {
		sa = ((FuncExp *)ea)->fd;
		ea = NULL;
		goto Lsa;
	    }
	    buf.writeByte('V');
	    if (ea->op == TOKtuple)
	    {	ea->error("tuple is not a valid template value argument");
		continue;
	    }
#if 1
	    /* Use deco that matches what it would be for a function parameter
	     */
	    buf.writestring(ea->type->deco);
#else
	    // Use type of parameter, not type of argument
	    TemplateParameter *tp = (TemplateParameter *)tempdecl->parameters->data[i];
	    assert(tp);
	    TemplateValueParameter *tvp = tp->isTemplateValueParameter();
	    assert(tvp);
	    buf.writestring(tvp->valType->deco);
#endif
	    ea->toMangleBuffer(&buf);
	}
	else if (sa)
	{
	  Lsa:
	    buf.writeByte('S');
	    Declaration *d = sa->isDeclaration();
	    if (d && (!d->type || !d->type->deco))
	    {	error("forward reference of %s", d->toChars());
		continue;
	    }
#if 0
	    VarDeclaration *v = sa->isVarDeclaration();
	    if (v && v->storage_class & STCmanifest)
	    {	ExpInitializer *ei = v->init->isExpInitializer();
		if (ei)
		{
		    ea = ei->exp;
		    goto Lea;
		}
	    }
#endif
	    const char *p = sa->mangle();
	    buf.printf("%zu%s", strlen(p), p);
	}
	else if (va)
	{
	    assert(i + 1 == args->dim);		// must be last one
	    args = &va->objects;
	    i = -1;
	}
	else
	    assert(0);
    }
    buf.writeByte('Z');
    id = buf.toChars();
    buf.data = NULL;
    //printf("\tgenIdent = %s\n", id);
    return new Identifier(id, TOKidentifier);
}


/****************************************************
 * Declare parameters of template instance, initialize them with the
 * template instance arguments.
 */

void TemplateInstance::declareParameters(Scope *sc)
{
    //printf("TemplateInstance::declareParameters()\n");
    for (int i = 0; i < tdtypes.dim; i++)
    {
	TemplateParameter *tp = (TemplateParameter *)tempdecl->parameters->data[i];
	//Object *o = (Object *)tiargs->data[i];
	Object *o = (Object *)tdtypes.data[i];		// initializer for tp

	//printf("\ttdtypes[%d] = %p\n", i, o);
	tempdecl->declareParameter(sc, tp, o);
    }
}

/*****************************************************
 * Determine if template instance is really a template function,
 * and that template function needs to infer types from the function
 * arguments.
 */

int TemplateInstance::needsTypeInference(Scope *sc)
{
    //printf("TemplateInstance::needsTypeInference() %s\n", toChars());
    if (!tempdecl)
	tempdecl = findTemplateDeclaration(sc);
    for (TemplateDeclaration *td = tempdecl; td; td = td->overnext)
    {
	/* If any of the overloaded template declarations need inference,
	 * then return TRUE
	 */
	FuncDeclaration *fd;
	if (!td->onemember ||
	    (fd = td->onemember->toAlias()->isFuncDeclaration()) == NULL ||
	    fd->type->ty != Tfunction)
	{
	    /* Not a template function, therefore type inference is not possible.
	     */
	    //printf("false\n");
	    return FALSE;
	}

	/* Determine if the instance arguments, tiargs, are all that is necessary
	 * to instantiate the template.
	 */
	TemplateTupleParameter *tp = td->isVariadic();
	//printf("tp = %p, td->parameters->dim = %d, tiargs->dim = %d\n", tp, td->parameters->dim, tiargs->dim);
	TypeFunction *fdtype = (TypeFunction *)fd->type;
	if (Parameter::dim(fdtype->parameters) &&
	    (tp || tiargs->dim < td->parameters->dim))
	    return TRUE;
    }
    //printf("false\n");
    return FALSE;
}

void TemplateInstance::semantic2(Scope *sc)
{   int i;

    if (semanticRun >= 2)
	return;
    semanticRun = 2;
#if LOG
    printf("+TemplateInstance::semantic2('%s')\n", toChars());
#endif
    if (!errors && members)
    {
	sc = tempdecl->scope;
	assert(sc);
	sc = sc->push(argsym);
	sc = sc->push(this);
	sc->tinst = this;
	for (i = 0; i < members->dim; i++)
	{
	    Dsymbol *s = (Dsymbol *)members->data[i];
#if LOG
printf("\tmember '%s', kind = '%s'\n", s->toChars(), s->kind());
#endif
	    s->semantic2(sc);
	}
	sc = sc->pop();
	sc->pop();
    }
#if LOG
    printf("-TemplateInstance::semantic2('%s')\n", toChars());
#endif
}

void TemplateInstance::semantic3(Scope *sc)
{
#if LOG
    printf("TemplateInstance::semantic3('%s'), semanticRun = %d\n", toChars(), semanticRun);
#endif
//if (toChars()[0] == 'D') *(char*)0=0;
    if (semanticRun >= 3)
	return;
    semanticRun = 3;
    if (!errors && members)
    {
	sc = tempdecl->scope;
	sc = sc->push(argsym);
	sc = sc->push(this);
	sc->tinst = this;
	for (int i = 0; i < members->dim; i++)
	{
	    Dsymbol *s = (Dsymbol *)members->data[i];
	    s->semantic3(sc);
	}
	sc = sc->pop();
	sc->pop();
    }
}

/**************************************
 * Given an error instantiating the TemplateInstance,
 * give the nested TemplateInstance instantiations that got
 * us here. Those are a list threaded into the nested scopes.
 */
void TemplateInstance::printInstantiationTrace()
{
    if (global.gag)
	return;

    const int max_shown = 6;
    const char format[] = "%s:        instantiated from here: %s\n";

    // determine instantiation depth and number of recursive instantiations
    int n_instantiations = 1;
    int n_totalrecursions = 0;
    for (TemplateInstance *cur = this; cur; cur = cur->tinst)
    {
	++n_instantiations;
	// If two instantiations use the same declaration, they are recursive.
	// (this works even if they are instantiated from different places in the
	// same template).
	// In principle, we could also check for multiple-template recursion, but it's
	// probably not worthwhile.
	if (cur->tinst && cur->tempdecl && cur->tinst->tempdecl
	    && cur->tempdecl->loc.equals(cur->tinst->tempdecl->loc))
	    ++n_totalrecursions;
    }

    // show full trace only if it's short or verbose is on
    if (n_instantiations <= max_shown || global.params.verbose)
    {
	for (TemplateInstance *cur = this; cur; cur = cur->tinst)
	{
	    fprintf(stdmsg, format, cur->loc.toChars(), cur->toChars());
	}
    }
    else if (n_instantiations - n_totalrecursions <= max_shown)
    {
	// By collapsing recursive instantiations into a single line,
	// we can stay under the limit.
	int recursionDepth=0;
	for (TemplateInstance *cur = this; cur; cur = cur->tinst)
	{
	    if (cur->tinst && cur->tempdecl && cur->tinst->tempdecl
		    && cur->tempdecl->loc.equals(cur->tinst->tempdecl->loc))
	    {
		++recursionDepth;
	    }
	    else
	    {
		if (recursionDepth)
		    fprintf(stdmsg, "%s:        %d recursive instantiations from here: %s\n", cur->loc.toChars(), recursionDepth+2, cur->toChars());
		else 
		    fprintf(stdmsg,format, cur->loc.toChars(), cur->toChars());
		recursionDepth = 0;
	    }
	}
    }
    else
    {
	// Even after collapsing the recursions, the depth is too deep.
	// Just display the first few and last few instantiations.
	size_t i = 0;
	for (TemplateInstance *cur = this; cur; cur = cur->tinst)
	{
	    if (i == max_shown / 2)
		fprintf(stdmsg,"    ... (%d instantiations, -v to show) ...\n", n_instantiations - max_shown);

	    if (i < max_shown / 2 ||
		i >= n_instantiations - max_shown + max_shown / 2)
		fprintf(stdmsg, format, cur->loc.toChars(), cur->toChars());
	    ++i;
	}
    }
}

void TemplateInstance::toObjFile(int multiobj)
{
#if LOG
    printf("TemplateInstance::toObjFile('%s', this = %p)\n", toChars(), this);
#endif
    if (!errors && members)
    {
	if (multiobj)
	    // Append to list of object files to be written later
	    obj_append(this);
	else
	{
	    for (int i = 0; i < members->dim; i++)
	    {
		Dsymbol *s = (Dsymbol *)members->data[i];
		s->toObjFile(multiobj);
	    }
	}
    }
}

void TemplateInstance::inlineScan()
{
#if LOG
    printf("TemplateInstance::inlineScan('%s')\n", toChars());
#endif
    if (!errors && members)
    {
	for (int i = 0; i < members->dim; i++)
	{
	    Dsymbol *s = (Dsymbol *)members->data[i];
	    s->inlineScan();
	}
    }
}

void TemplateInstance::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    int i;

    Identifier *id = name;
    buf->writestring(id->toChars());
    buf->writestring("!(");
    if (nest)
	buf->writestring("...");
    else
    {
	nest++;
	Objects *args = tiargs;
	for (i = 0; i < args->dim; i++)
	{
	    if (i)
		buf->writeByte(',');
	    Object *oarg = (Object *)args->data[i];
	    ObjectToCBuffer(buf, hgs, oarg);
	}
	nest--;
    }
    buf->writeByte(')');
}


Dsymbol *TemplateInstance::toAlias()
{
#if LOG
    printf("TemplateInstance::toAlias()\n");
#endif
    if (!inst)
    {	error("cannot resolve forward reference");
	errors = 1;
	return this;
    }

    if (inst != this)
	return inst->toAlias();

    if (aliasdecl)
    {
	return aliasdecl->toAlias();
    }

    return inst;
}

AliasDeclaration *TemplateInstance::isAliasDeclaration()
{
    return aliasdecl;
}

const char *TemplateInstance::kind()
{
    return "template instance";
}

int TemplateInstance::oneMember(Dsymbol **ps)
{
    *ps = NULL;
    return TRUE;
}

char *TemplateInstance::toChars()
{
    OutBuffer buf;
    HdrGenState hgs;
    char *s;

    toCBuffer(&buf, &hgs);
    s = buf.toChars();
    buf.data = NULL;
    return s;
}

/* ======================== TemplateMixin ================================ */

TemplateMixin::TemplateMixin(Loc loc, Identifier *ident, Type *tqual,
	Array *idents, Objects *tiargs)
	: TemplateInstance(loc, (Identifier *)idents->data[idents->dim - 1])
{
    //printf("TemplateMixin(ident = '%s')\n", ident ? ident->toChars() : "");
    this->ident = ident;
    this->tqual = tqual;
    this->idents = idents;
    this->tiargs = tiargs ? tiargs : new Objects();
}

Dsymbol *TemplateMixin::syntaxCopy(Dsymbol *s)
{   TemplateMixin *tm;

    Array *ids = new Array();
    ids->setDim(idents->dim);
    for (int i = 0; i < idents->dim; i++)
    {	// Matches TypeQualified::syntaxCopyHelper()
        Identifier *id = (Identifier *)idents->data[i];
        if (id->dyncast() == DYNCAST_DSYMBOL)
        {
            TemplateInstance *ti = (TemplateInstance *)id;

            ti = (TemplateInstance *)ti->syntaxCopy(NULL);
            id = (Identifier *)ti;
        }
        ids->data[i] = id;
    }

    tm = new TemplateMixin(loc, ident,
		(Type *)(tqual ? tqual->syntaxCopy() : NULL),
		ids, tiargs);
    TemplateInstance::syntaxCopy(tm);
    return tm;
}

void TemplateMixin::semantic(Scope *sc)
{
#if LOG
    printf("+TemplateMixin::semantic('%s', this=%p)\n", toChars(), this);
    fflush(stdout);
#endif
    if (semanticRun)
    {
	// This for when a class/struct contains mixin members, and
	// is done over because of forward references
	if (parent && toParent()->isAggregateDeclaration())
	    semanticRun = 1;		// do over
	else
	{
#if LOG
	    printf("\tsemantic done\n");
#endif
	    return;
	}
    }
    if (!semanticRun)
	semanticRun = 1;
#if LOG
    printf("\tdo semantic\n");
#endif
    util_progress();

    Scope *scx = NULL;
    if (scope)
    {	sc = scope;
	scx = scope;		// save so we don't make redundant copies
	scope = NULL;
    }

    // Follow qualifications to find the TemplateDeclaration
    if (!tempdecl)
    {	Dsymbol *s;
	int i;
	Identifier *id;

	if (tqual)
	{   s = tqual->toDsymbol(sc);
	    i = 0;
	}
	else
	{
	    i = 1;
	    id = (Identifier *)idents->data[0];
	    switch (id->dyncast())
	    {
		case DYNCAST_IDENTIFIER:
		    s = sc->search(loc, id, NULL);
		    break;

		case DYNCAST_DSYMBOL:
		{
		    TemplateInstance *ti = (TemplateInstance *)id;
		    ti->semantic(sc);
		    s = ti;
		    break;
		}
		default:
		    assert(0);
	    }
	}

	for (; i < idents->dim; i++)
	{
	    if (!s)
		break;
	    id = (Identifier *)idents->data[i];
	    s = s->searchX(loc, sc, id);
	}
	if (!s)
	{
	    error("is not defined");
	    inst = this;
	    return;
	}
	tempdecl = s->toAlias()->isTemplateDeclaration();
	if (!tempdecl)
	{
	    error("%s isn't a template", s->toChars());
	    inst = this;
	    return;
	}
    }

    // Look for forward reference
    assert(tempdecl);
    for (TemplateDeclaration *td = tempdecl; td; td = td->overnext)
    {
	if (!td->semanticRun)
	{
	    /* Cannot handle forward references if mixin is a struct member,
	     * because addField must happen during struct's semantic, not
	     * during the mixin semantic.
	     * runDeferred will re-run mixin's semantic outside of the struct's
	     * semantic.
	     */
	    semanticRun = 0;
	    AggregateDeclaration *ad = toParent()->isAggregateDeclaration();
	    if (ad)
		ad->sizeok = 2;
	    else
	    {
		// Forward reference
		//printf("forward reference - deferring\n");
		scope = scx ? scx : new Scope(*sc);
		scope->setNoFree();
		scope->module->addDeferredSemantic(this);
	    }
	    return;
	}
    }

    // Run semantic on each argument, place results in tiargs[]
    semanticTiargs(sc);
    if (errors)
	return;

    tempdecl = findBestMatch(sc);
    if (!tempdecl)
    {	inst = this;
	return;		// error recovery
    }

    if (!ident)
	ident = genIdent();

    inst = this;
    parent = sc->parent;

    /* Detect recursive mixin instantiations.
     */
    for (Dsymbol *s = parent; s; s = s->parent)
    {
	//printf("\ts = '%s'\n", s->toChars());
	TemplateMixin *tm = s->isTemplateMixin();
	if (!tm || tempdecl != tm->tempdecl)
	    continue;

	/* Different argument list lengths happen with variadic args
	 */
	if (tiargs->dim != tm->tiargs->dim)
	    continue;

	for (int i = 0; i < tiargs->dim; i++)
	{   Object *o = (Object *)tiargs->data[i];
	    Type *ta = isType(o);
	    Expression *ea = isExpression(o);
	    Dsymbol *sa = isDsymbol(o);
	    Object *tmo = (Object *)tm->tiargs->data[i];
	    if (ta)
	    {
		Type *tmta = isType(tmo);
		if (!tmta)
		    goto Lcontinue;
		if (!ta->equals(tmta))
		    goto Lcontinue;
	    }
	    else if (ea)
	    {	Expression *tme = isExpression(tmo);
		if (!tme || !ea->equals(tme))
		    goto Lcontinue;
	    }
	    else if (sa)
	    {
		Dsymbol *tmsa = isDsymbol(tmo);
		if (sa != tmsa)
		    goto Lcontinue;
	    }
	    else
		assert(0);
	}
	error("recursive mixin instantiation");
	return;

    Lcontinue:
	continue;
    }

    // Copy the syntax trees from the TemplateDeclaration
    members = Dsymbol::arraySyntaxCopy(tempdecl->members);
    if (!members)
	return;

    symtab = new DsymbolTable();

    for (Scope *sce = sc; 1; sce = sce->enclosing)
    {
	ScopeDsymbol *sds = (ScopeDsymbol *)sce->scopesym;
	if (sds)
	{
	    sds->importScope(this, PROTpublic);
	    break;
	}
    }

#if LOG
    printf("\tcreate scope for template parameters '%s'\n", toChars());
#endif
    Scope *scy = sc;
    scy = sc->push(this);
    scy->parent = this;

    argsym = new ScopeDsymbol();
    argsym->parent = scy->parent;
    Scope *argscope = scy->push(argsym);

    unsigned errorsave = global.errors;

    // Declare each template parameter as an alias for the argument type
    declareParameters(argscope);

    // Add members to enclosing scope, as well as this scope
    for (unsigned i = 0; i < members->dim; i++)
    {   Dsymbol *s;

	s = (Dsymbol *)members->data[i];
	s->addMember(argscope, this, i);
	//sc->insert(s);
	//printf("sc->parent = %p, sc->scopesym = %p\n", sc->parent, sc->scopesym);
	//printf("s->parent = %s\n", s->parent->toChars());
    }

    // Do semantic() analysis on template instance members
#if LOG
    printf("\tdo semantic() on template instance members '%s'\n", toChars());
#endif
    Scope *sc2;
    sc2 = argscope->push(this);
    sc2->offset = sc->offset;

    static int nest;
    //printf("%d\n", nest);
    if (++nest > 500)
    {
	global.gag = 0;			// ensure error message gets printed
	error("recursive expansion");
	fatal();
    }

    for (int i = 0; i < members->dim; i++)
    {
	Dsymbol *s = (Dsymbol *)members->data[i];
	s->semantic(sc2);
    }

    nest--;

    sc->offset = sc2->offset;

    /* The problem is when to parse the initializer for a variable.
     * Perhaps VarDeclaration::semantic() should do it like it does
     * for initializers inside a function.
     */
//    if (sc->parent->isFuncDeclaration())

	semantic2(sc2);

    if (sc->func)
    {
	semantic3(sc2);
    }

    // Give additional context info if error occurred during instantiation
    if (global.errors != errorsave)
    {
	error("error instantiating");
    }

    sc2->pop();

    argscope->pop();

//    if (!isAnonymous())
    {
	scy->pop();
    }
#if LOG
    printf("-TemplateMixin::semantic('%s', this=%p)\n", toChars(), this);
#endif
}

void TemplateMixin::semantic2(Scope *sc)
{   int i;

    if (semanticRun >= 2)
	return;
    semanticRun = 2;
#if LOG
    printf("+TemplateMixin::semantic2('%s')\n", toChars());
#endif
    if (members)
    {
	assert(sc);
	sc = sc->push(argsym);
	sc = sc->push(this);
	for (i = 0; i < members->dim; i++)
	{
	    Dsymbol *s = (Dsymbol *)members->data[i];
#if LOG
	    printf("\tmember '%s', kind = '%s'\n", s->toChars(), s->kind());
#endif
	    s->semantic2(sc);
	}
	sc = sc->pop();
	sc->pop();
    }
#if LOG
    printf("-TemplateMixin::semantic2('%s')\n", toChars());
#endif
}

void TemplateMixin::semantic3(Scope *sc)
{   int i;

    if (semanticRun >= 3)
	return;
    semanticRun = 3;
#if LOG
    printf("TemplateMixin::semantic3('%s')\n", toChars());
#endif
    if (members)
    {
	sc = sc->push(argsym);
	sc = sc->push(this);
	for (i = 0; i < members->dim; i++)
	{
	    Dsymbol *s = (Dsymbol *)members->data[i];
	    s->semantic3(sc);
	}
	sc = sc->pop();
	sc->pop();
    }
}

void TemplateMixin::inlineScan()
{
    TemplateInstance::inlineScan();
}

const char *TemplateMixin::kind()
{
    return "mixin";
}

int TemplateMixin::oneMember(Dsymbol **ps)
{
    return Dsymbol::oneMember(ps);
}

int TemplateMixin::hasPointers()
{
    //printf("TemplateMixin::hasPointers() %s\n", toChars());
    for (size_t i = 0; i < members->dim; i++)
    {
	Dsymbol *s = (Dsymbol *)members->data[i];
	//printf(" s = %s %s\n", s->kind(), s->toChars());
	if (s->hasPointers())
	{
	    return 1;
	}
    }
    return 0;
}

char *TemplateMixin::toChars()
{
    OutBuffer buf;
    HdrGenState hgs;
    char *s;

    TemplateInstance::toCBuffer(&buf, &hgs);
    s = buf.toChars();
    buf.data = NULL;
    return s;
}

void TemplateMixin::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("mixin ");

    for (int i = 0; i < idents->dim; i++)
    {   Identifier *id = (Identifier *)idents->data[i];

    	if (i)
	    buf->writeByte('.');
	buf->writestring(id->toChars());
    }
    buf->writestring("!(");
    if (tiargs)
    {
        for (int i = 0; i < tiargs->dim; i++)
        {   if (i)
                buf->writebyte(',');
	    Object *oarg = (Object *)tiargs->data[i];
	    Type *t = isType(oarg);
	    Expression *e = isExpression(oarg);
	    Dsymbol *s = isDsymbol(oarg);
	    if (t)
		t->toCBuffer(buf, NULL, hgs);
	    else if (e)
		e->toCBuffer(buf, hgs);
	    else if (s)
	    {
		char *p = s->ident ? s->ident->toChars() : s->toChars();
		buf->writestring(p);
	    }
	    else if (!oarg)
	    {
		buf->writestring("NULL");
	    }
	    else
	    {
		assert(0);
	    }
        }
    }
    buf->writebyte(')');
    if (ident)
    {
	buf->writebyte(' ');
	buf->writestring(ident->toChars());
    }
    buf->writebyte(';');
    buf->writenl();
}


void TemplateMixin::toObjFile(int multiobj)
{
    //printf("TemplateMixin::toObjFile('%s')\n", toChars());
    TemplateInstance::toObjFile(multiobj);
}

