
// Copyright (c) 1999-2005 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

// Handle template implementation

#include <stdio.h>
#include <assert.h>

#include "root.h"
#include "mem.h"
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

#define LOG	0

/********************************************
 * These functions substitute for dynamic_cast. dynamic_cast does not work
 * on earlier versions of gcc.
 */

static Expression *isExpression(Object *o)
{
    //return dynamic_cast<Expression *>(o);
    if (!o || o->dyncast() != DYNCAST_EXPRESSION)
	return NULL;
    return (Expression *)o;
}

static Dsymbol *isDsymbol(Object *o)
{
    //return dynamic_cast<Dsymbol *>(o);
    if (!o || o->dyncast() != DYNCAST_DSYMBOL)
	return NULL;
    return (Dsymbol *)o;
}

static Type *isType(Object *o)
{
    //return dynamic_cast<Type *>(o);
    if (!o || o->dyncast() != DYNCAST_TYPE)
	return NULL;
    return (Type *)o;
}

/* ======================== TemplateDeclaration ============================= */

TemplateDeclaration::TemplateDeclaration(Loc loc, Identifier *id, Array *parameters, Array *decldefs)
    : ScopeDsymbol(id)
{
#if LOG
    printf("TemplateDeclaration(this = %p, id = '%s')\n", this, id->toChars());
#endif
#if 0
    if (parameters)
	for (int i = 0; i < parameters->dim; i++)
	{   TemplateParameter *tp = (TemplateParameter *)parameters->data[i];
	    TemplateTypeParameter *ttp = tp->isTemplateTypeParameter();

	    if (ttp)
	    {
		printf("\tparameter[%d] = %s : %s\n", i, tp->ident->toChars(), ttp->specType ? ttp->specType->toChars() : "");
	    }
	}
#endif
    this->loc = loc;
    this->parameters = parameters;
    this->members = decldefs;
    this->overnext = NULL;
    this->scope = NULL;
}

Dsymbol *TemplateDeclaration::syntaxCopy(Dsymbol *)
{
    TemplateDeclaration *td;
    Array *p;
    Array *d;

    p = NULL;
    if (parameters)
    {
	p = new Array();
	p->setDim(parameters->dim);
	for (int i = 0; i < p->dim; i++)
	{   TemplateParameter *tp = (TemplateParameter *)parameters->data[i];
	    p->data[i] = (void *)tp->syntaxCopy();
	}
    }
    d = Dsymbol::arraySyntaxCopy(members);
    td = new TemplateDeclaration(loc, ident, p, d);
    return td;
}

void TemplateDeclaration::semantic(Scope *sc)
{
#if LOG
    printf("TemplateDeclaration::semantic(this = %p, id = '%s')\n", this, ident->toChars());
#endif
    if (scope)
	return;		// semantic() already run

    if (sc->func)
    {
	error("cannot declare template at function scope %s", sc->func->toChars());
    }

    if (global.params.useArrayBounds && sc->module)
    {
	// Generate this function as it may be used
	// when template is instantiated in other modules
	sc->module->toModuleArray();
    }

    if (global.params.useAssert && sc->module)
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

    for (int i = 0; i < parameters->dim; i++)
    {
	TemplateParameter *tp = (TemplateParameter *)parameters->data[i];

	tp->semantic(paramscope);
    }

    paramscope->pop();

    /* BUG: should check:
     *	o no virtual functions or non-static data members of classes
     */
}

char *TemplateDeclaration::kind()
{
    return "template";
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
    }


    *pf = f;
#if LOG
    printf("\ttrue: no conflict\n");
#endif
    return TRUE;
}

/***************************************
 * Given that ti is an instance of this TemplateDeclaration,
 * deduce the types of the parameters to this, and store
 * those deduced types in dedtypes[].
 * Input:
 *	flag	1: don't do semantic() because of dummy types
 * Return match level.
 */

MATCH TemplateDeclaration::matchWithInstance(TemplateInstance *ti,
	Array *dedtypes, int flag)
{   MATCH m;
    int dim = dedtypes->dim;

#if LOG
    printf("+TemplateDeclaration::matchWithInstance(this = %p, ti = %p)\n", this, ti);
#endif
    dedtypes->zero();


//printf("TemplateDeclaration::matchWithInstance(this = %p, ti = %p)\n", this, ti);
//printf("dim = %d, parameters->dim = %d\n", dim, parameters->dim);
//if (ti->tiargs->dim)
//printf("ti->tiargs->dim = %d, [0] = %p\n", ti->tiargs->dim, ti->tiargs->data[0]);

    assert(dim == parameters->dim);
    assert(dim >= ti->tiargs->dim);

    // Set up scope for parameters
    assert(scope);
    ScopeDsymbol *paramsym = new ScopeDsymbol();
    paramsym->parent = scope->parent;
    Scope *paramscope = scope->push(paramsym);

    // Attempt type deduction
    m = MATCHexact;
    for (int i = 0; i < dim; i++)
    {	MATCH m2;
	TemplateParameter *tp = (TemplateParameter *)parameters->data[i];
	Object *oarg;
	Declaration *sparam;

	if (i < ti->tiargs->dim)
	    oarg = (Object *)ti->tiargs->data[i];
	else
	{   // Look for default argument instead
	    oarg = tp->defaultArg(paramscope);
	    if (!oarg)
		goto Lnomatch;
	}
#if 0
	printf("\targument [%d] is %s\n", i, oarg ? oarg->toChars() : "null");
	TemplateTypeParameter *ttp = tp->isTemplateTypeParameter();
	if (ttp)
	    printf("\tparameter[%d] is %s : %s\n", i, tp->ident->toChars(), ttp->specType ? ttp->specType->toChars() : "");
#endif

	m2 = tp->matchArg(paramscope, oarg, i, parameters, dedtypes, &sparam);
	if (m2 == MATCHnomatch)
	{   //printf("\tmatchArg() for parameter %i failed\n", i);
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
	// Any parameter left without a type gets the type of its corresponding arg
	for (int i = 0; i < dim; i++)
	{
	    if (!dedtypes->data[i])
	    {   assert(i < ti->tiargs->dim);
		dedtypes->data[i] = ti->tiargs->data[i];
	    }
	}
    }

#if 0
    // Print out the results
    printf("--------------------------\n");
    printf("template %s\n", toChars());
    printf("instance %s\n", ti->toChars());
    if (m)
    {
	for (int i = 0; i < dim; i++)
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

#if LOG
    printf(" match = %d\n", m);
#endif
    goto Lret;

Lnomatch:
#if LOG
    printf(" no match\n");
#endif
    m = MATCHnomatch;

Lret:
    paramscope->pop();
#if LOG
    printf("-TemplateDeclaration::matchWithInstance(this = %p, ti = %p) = %d\n", this, ti, m);
#endif
    return m;
}

/********************************************
 * Determine partial specialization order of 'this' vs td2.
 * Returns:
 *	1	this is at least as specialized as td2
 *	0	td2 is more specialized than this
 */

int TemplateDeclaration::leastAsSpecialized(TemplateDeclaration *td2)
{
    /* This works by taking the template parameters to this template
     * declaration and feeding them to td2 as if it were a template
     * instance.
     * If it works, then this template is at least as specialized
     * as td2.
     */

    TemplateInstance ti(0, ident);		// create dummy template instance
    Array dedtypes;

#define LOG_LEASTAS	0

#if LOG_LEASTAS
    printf("%s.leastAsSpecialized(%s)\n", toChars(), td2->toChars());
#endif

    // Set type arguments to dummy template instance to be types
    // generated from the parameters to this template declaration
    ti.tiargs = new Array();
    ti.tiargs->setDim(parameters->dim);
    for (int i = 0; i < ti.tiargs->dim; i++)
    {
	TemplateParameter *tp = (TemplateParameter *)parameters->data[i];

	ti.tiargs->data[i] = tp->dummyArg();
    }

    // Temporary Array to hold deduced types
    dedtypes.setDim(parameters->dim);

    // Attempt a type deduction
    if (td2->matchWithInstance(&ti, &dedtypes, 1))
    {
#if LOG_LEASTAS
	printf("  matches, so is least as specialized\n");
#endif
	return 1;
    }
#if LOG_LEASTAS
    printf("  doesn't match, so is not as specialized\n");
#endif
    return 0;
}

void TemplateDeclaration::toCBuffer(OutBuffer *buf)
{
    int i;

    buf->writestring("template ");
    buf->writestring(ident->toChars());
    buf->writeByte('(');
    for (i = 0; i < parameters->dim; i++)
    {
	TemplateParameter *tp = (TemplateParameter *)parameters->data[i];
	if (i)
	    buf->writeByte(',');
	tp->toCBuffer(buf);
    }
    buf->writeByte(')');
}


char *TemplateDeclaration::toChars()
{
    OutBuffer buf;
    char *s;

    toCBuffer(&buf);
    s = buf.toChars();
    buf.data = NULL;
    return s + 9;	// kludge to skip over 'template '
}

/* ======================== Type ============================================ */

/* These form the heart of template argument deduction.
 * Given 'this' being the argument to the template instance,
 * it is matched against the template declaration parameter specialization
 * 'tparam' to determine the type to be used for the parameter.
 */

MATCH Type::deduceType(Type *tparam, Array *parameters, Array *dedtypes)
{
    //printf("Type::deduceType()\n");
    //printf("\tthis   = %d, ", ty); print();
    //printf("\ttparam = %d, ", tparam->ty); tparam->print();
    if (!tparam)
	goto Lnomatch;

    if (this == tparam)
	goto Lexact;

    if (tparam->ty == Tident)
    {
	TypeIdentifier *tident = (TypeIdentifier *)tparam;

	//printf("\ttident = '%s'\n", tident->toChars());
	if (tident->idents.dim > 0)
	    goto Lnomatch;

	// Determine which parameter tparam is
	Identifier *id = tident->ident;
	int i;
	for (i = 0; 1; i++)
	{
	    if (i == parameters->dim)
		goto Lnomatch;
	    TemplateParameter *tp = (TemplateParameter *)parameters->data[i];

	    if (tp->ident->equals(id))
	    {	// Found the corresponding parameter
		Type *at = (Type *)dedtypes->data[i];
		if (!at)
		{
		    dedtypes->data[i] = (void *)this;
		    goto Lexact;
		}
		if (equals(at))
		    goto Lexact;
		else
		    goto Lnomatch;
	    }
	}
    }

    if (ty != tparam->ty)
	goto Lnomatch;

    if (next)
	return next->deduceType(tparam->next, parameters, dedtypes);

Lexact:
    return MATCHexact;

Lnomatch:
    return MATCHnomatch;
}

MATCH TypeSArray::deduceType(Type *tparam, Array *parameters, Array *dedtypes)
{
    // Extra check that array dimensions must match
    if (tparam && tparam->ty == Tsarray)
    {
	TypeSArray *tp = (TypeSArray *)tparam;
	if (dim->toInteger() != tp->dim->toInteger())
	    return MATCHnomatch;
    }
    return Type::deduceType(tparam, parameters, dedtypes);
}

MATCH TypeAArray::deduceType(Type *tparam, Array *parameters, Array *dedtypes)
{
    // Extra check that index type must match
    if (tparam && tparam->ty == Taarray)
    {
	TypeAArray *tp = (TypeAArray *)tparam;
	if (!index->deduceType(tp->index, parameters, dedtypes))
	    return MATCHnomatch;
    }
    return Type::deduceType(tparam, parameters, dedtypes);
}

MATCH TypeFunction::deduceType(Type *tparam, Array *parameters, Array *dedtypes)
{
    // Extra check that function characteristics must match
    if (tparam && tparam->ty == Tfunction)
    {
	TypeFunction *tp = (TypeFunction *)tparam;
	if (varargs != tp->varargs ||
	    linkage != tp->linkage ||
	    arguments->dim != tp->arguments->dim)
	    return MATCHnomatch;
	for (int i = 0; i < arguments->dim; i++)
	{
	    Argument *a = (Argument *)arguments->data[i];
	    Argument *ap = (Argument *)tp->arguments->data[i];
	    if (a->inout != ap->inout ||
		!a->type->deduceType(ap->type, parameters, dedtypes))
		return MATCHnomatch;
	}
    }
    return Type::deduceType(tparam, parameters, dedtypes);
}

MATCH TypeIdentifier::deduceType(Type *tparam, Array *parameters, Array *dedtypes)
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
    return Type::deduceType(tparam, parameters, dedtypes);
}

MATCH TypeInstance::deduceType(Type *tparam, Array *parameters, Array *dedtypes)
{
    // Extra check
    if (tparam && tparam->ty == Tinstance)
    {
	TypeInstance *tp = (TypeInstance *)tparam;

	for (int i = 0; i < idents.dim; i++)
	{
	    Identifier *id1 = (Identifier *)idents.data[i];
	    Identifier *id2 = (Identifier *)tp->idents.data[i];

	    if (!id1->equals(id2))
		return MATCHnomatch;
	}

	for (int i = 0; i < tempinst->tiargs->dim; i++)
	{
	    Type *t1 = (Type *)tempinst->tiargs->data[i];
	    Type *t2 = (Type *)tp->tempinst->tiargs->data[i];

	    if (!t1->deduceType(t2, parameters, dedtypes))
		return MATCHnomatch;
	}
    }
    return Type::deduceType(tparam, parameters, dedtypes);
}

MATCH TypeStruct::deduceType(Type *tparam, Array *parameters, Array *dedtypes)
{
    // Extra check
    if (tparam && tparam->ty == Tstruct)
    {
	TypeStruct *tp = (TypeStruct *)tparam;

	if (sym != tp->sym)
	    return MATCHnomatch;
    }
    return Type::deduceType(tparam, parameters, dedtypes);
}

MATCH TypeEnum::deduceType(Type *tparam, Array *parameters, Array *dedtypes)
{
    // Extra check
    if (tparam && tparam->ty == Tenum)
    {
	TypeEnum *tp = (TypeEnum *)tparam;

	if (sym != tp->sym)
	    return MATCHnomatch;
    }
    return Type::deduceType(tparam, parameters, dedtypes);
}

MATCH TypeTypedef::deduceType(Type *tparam, Array *parameters, Array *dedtypes)
{
    // Extra check
    if (tparam && tparam->ty == Ttypedef)
    {
	TypeTypedef *tp = (TypeTypedef *)tparam;

	if (sym != tp->sym)
	    return MATCHnomatch;
    }
    return Type::deduceType(tparam, parameters, dedtypes);
}

MATCH TypeClass::deduceType(Type *tparam, Array *parameters, Array *dedtypes)
{
    //printf("TypeClass::deduceType()\n");

    // Extra check
    if (tparam && tparam->ty == Tclass)
    {
	TypeClass *tp = (TypeClass *)tparam;

#if 1
	//printf("\t%d\n", (MATCH) implicitConvTo(tp));
	return (MATCH) implicitConvTo(tp);
#else
	if (sym != tp->sym)
	    return MATCHnomatch;
#endif
    }
    return Type::deduceType(tparam, parameters, dedtypes);
}

/* ======================== TemplateParameter =============================== */

TemplateParameter::TemplateParameter(Loc loc, Identifier *ident)
{
    this->loc = loc;
    this->ident = ident;
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

void TemplateTypeParameter::semantic(Scope *sc)
{
    //printf("TemplateTypeParameter::semantic('%s')\n", ident->toChars());
    TypeIdentifier *ti = new TypeIdentifier(loc, ident);
    Declaration *sparam = new AliasDeclaration(loc, ident, ti);
    if (!sc->insert(sparam))
	error(loc, "parameter '%s' multiply defined", ident->toChars());

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


MATCH TemplateTypeParameter::matchArg(Scope *sc, Object *oarg,
	int i, Array *parameters, Array *dedtypes, Declaration **psparam)
{
    //printf("TemplateTypeParameter::matchArg()\n");

    Type *t;
    MATCH m = MATCHexact;
    Type *ta = isType(oarg);
    if (!ta)
	goto Lnomatch;

    t = (Type *)dedtypes->data[i];

    if (specType)
    {
	//printf("\tcalling deduceType(), specType is %s\n", specType->toChars());
	MATCH m2 = ta->deduceType(specType, parameters, dedtypes);
	if (m2 == MATCHnomatch)
	{   //printf("\tfailed deduceType\n");
	    goto Lnomatch;
	}

	if (m2 < m)
	    m = m2;
	t = (Type *)dedtypes->data[i];
    }
    else if (t)
    {   // Must match already deduced type

	if (!t->equals(ta))
	    goto Lnomatch;
    }

    if (!t)
    {
	dedtypes->data[i] = ta;
	t = ta;
    }
    *psparam = new AliasDeclaration(loc, ident, t);
    return m;

Lnomatch:
    *psparam = NULL;
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
    printf("\tArgument:       %s\n", t ? t->toChars() : "NULL");
    printf("\tDeduced Type:   %s\n", ta->toChars());
}


void TemplateTypeParameter::toCBuffer(OutBuffer *buf)
{
    buf->writestring(ident->toChars());
    if (specType)
    {
	buf->writestring(" : ");
	specType->toCBuffer(buf, NULL);
    }
    if (defaultType)
    {
	buf->writestring(" = ");
	defaultType->toCBuffer(buf, NULL);
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


Object *TemplateTypeParameter::defaultArg(Scope *sc)
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

/* ======================== TemplateAliasParameter ========================== */

// alias-parameter

Dsymbol *TemplateAliasParameter::sdummy = NULL;

TemplateAliasParameter::TemplateAliasParameter(Loc loc, Identifier *ident, Type *specAliasT, Type *defaultAlias)
    : TemplateParameter(loc, ident)
{
    this->ident = ident;
    this->specAliasT = specAliasT;
    this->defaultAlias = defaultAlias;

    this->specAlias = NULL;
}

TemplateAliasParameter *TemplateAliasParameter::isTemplateAliasParameter()
{
    return this;
}

TemplateParameter *TemplateAliasParameter::syntaxCopy()
{
    TemplateAliasParameter *tp = new TemplateAliasParameter(loc, ident, specAliasT, defaultAlias);
    if (tp->specAliasT)
	tp->specAliasT = specAliasT->syntaxCopy();
    if (defaultAlias)
	tp->defaultAlias = defaultAlias->syntaxCopy();
    return tp;
}

void TemplateAliasParameter::semantic(Scope *sc)
{
    TypeIdentifier *ti = new TypeIdentifier(loc, ident);
    Declaration *sparam = new AliasDeclaration(loc, ident, ti);
    if (!sc->insert(sparam))
	error(loc, "parameter '%s' multiply defined", ident->toChars());

    if (specAliasT)
    {
	specAlias = specAliasT->toDsymbol(sc);
	if (!specAlias)
	    error("%s is not a symbol", specAliasT->toChars());
    }
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
	Object *oarg, int i, Array *parameters, Array *dedtypes, Declaration **psparam)
{
    Dsymbol *sa;

    //printf("TemplateAliasParameter::matchArg()\n");
    Expression *ea = isExpression(oarg);
    if (ea)
    {   // Try to convert Expression to symbol
	if (ea->op == TOKvar)
	    sa = ((VarExp *)ea)->var;
	else if (ea->op == TOKfunction)
	    sa = ((FuncExp *)ea)->fd;
	else
	    goto Lnomatch;
    }
    else
    {   // Try to convert Type to symbol
	Type *ta = isType(oarg);
	if (ta)
	    sa = ta->toDsymbol(NULL);
	else
	    sa = isDsymbol(oarg);	// if already a symbol
    }

    if (!sa)
	goto Lnomatch;

    if (specAlias)
    {
	if (!sa || sa == sdummy)
	    goto Lnomatch;
	if (sa != specAlias)
	    goto Lnomatch;
    }
    else if (dedtypes->data[i])
    {   // Must match already deduced symbol
	Dsymbol *s = (Dsymbol *)dedtypes->data[i];

	if (!sa || s != sa)
	    goto Lnomatch;
    }
    dedtypes->data[i] = sa;

    *psparam = new AliasDeclaration(loc, ident, sa);
    return MATCHexact;

Lnomatch:
    *psparam = NULL;
    return MATCHnomatch;
}


void TemplateAliasParameter::print(Object *oarg, Object *oded)
{
    printf(" %s\n", ident->toChars());

    Dsymbol *sa = isDsymbol(oded);
    assert(sa);

    printf("\tArgument alias: %s\n", sa->toChars());
}

void TemplateAliasParameter::toCBuffer(OutBuffer *buf)
{
    buf->writestring("alias ");
    buf->writestring(ident->toChars());
    if (specAliasT)
    {
	buf->writestring(" : ");
	specAliasT->toCBuffer(buf, NULL);
    }
    if (defaultAlias)
    {
	buf->writestring(" = ");
	defaultAlias->toCBuffer(buf, NULL);
    }
}


void *TemplateAliasParameter::dummyArg()
{   Dsymbol *s;

    s = specAlias;
    if (!s)
    {
	if (!sdummy)
	    sdummy = new Dsymbol();
	s = sdummy;
    }
    return (void*)s;
}


Object *TemplateAliasParameter::defaultArg(Scope *sc)
{
    Dsymbol *s = NULL;

    if (defaultAlias)
    {
	s = defaultAlias->toDsymbol(sc);
	if (!s)
	    error("%s is not a symbol", defaultAlias->toChars());
    }
    return s;
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

void TemplateValueParameter::semantic(Scope *sc)
{
    Declaration *sparam = new VarDeclaration(loc, valType, ident, NULL);
    if (!sc->insert(sparam))
	error(loc, "parameter '%s' multiply defined", ident->toChars());

    sparam->semantic(sc);
    valType = valType->semantic(loc, sc);
    if (!valType->isintegral() && valType->ty != Tident)
	error(loc, "integral type expected for value-parameter, not %s", valType->toChars());

    if (specValue)
    {   Expression *e = specValue;

	e = e->semantic(sc);
	e = e->implicitCastTo(valType);
	e = e->constFold();
	if (e->op == TOKint64)
	    specValue = e;
	//e->toInteger();
    }

#if 0	// defer semantic analysis to arg match
    if (defaultValue)
    {   Expression *e = defaultValue;

	e = e->semantic(sc);
	e = e->implicitCastTo(valType);
	e = e->constFold();
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
	Object *oarg, int i, Array *parameters, Array *dedtypes, Declaration **psparam)
{
    Initializer *init;
    Declaration *sparam;
    Expression *ei = isExpression(oarg);
    if (!ei && oarg)
	goto Lnomatch;

    if (specValue)
    {
	if (!ei || ei == edummy)
	    goto Lnomatch;

	Expression *e = specValue;
	e = e->semantic(sc);
	e = e->implicitCastTo(valType);
	e = e->constFold();
	if (!ei->equals(e))
	    goto Lnomatch;
    }
    else if (dedtypes->data[i])
    {   // Must match already deduced value
	Expression *e = (Expression *)dedtypes->data[i];

	if (!ei || !ei->equals(e))
	    goto Lnomatch;
    }
    dedtypes->data[i] = ei;

    init = new ExpInitializer(loc, ei);
    sparam = new VarDeclaration(loc, valType, ident, init);
    sparam->storage_class = STCconst;
    *psparam = sparam;
    return MATCHexact;

Lnomatch:
    *psparam = NULL;
    return MATCHnomatch;
}


void TemplateValueParameter::print(Object *oarg, Object *oded)
{
    printf(" %s\n", ident->toChars());

    Expression *ea = isExpression(oded);

    if (specValue)
	printf("\tSpecialization: %s\n", specValue->toChars());
    printf("\tArgument Value: %s\n", ea ? ea->toChars() : "NULL");
}


void TemplateValueParameter::toCBuffer(OutBuffer *buf)
{
    valType->toCBuffer(buf, ident);
    if (specValue)
    {
	buf->writestring(" : ");
	specValue->toCBuffer(buf);
    }
    if (defaultValue)
    {
	buf->writestring(" = ");
	defaultValue->toCBuffer(buf);
    }
}


void *TemplateValueParameter::dummyArg()
{   Expression *e;

    e = specValue;
    if (!e)
    {
	// Create a dummy value
	if (!edummy)
	    edummy = new IntegerExp(0);
	e = edummy;
    }
    return (void *)e;
}


Object *TemplateValueParameter::defaultArg(Scope *sc)
{
    Expression *e;

    e = defaultValue;
    if (e)
    {
	e = e->syntaxCopy();
	e = e->semantic(sc);
    }
    return e;
}

/* ======================== TemplateInstance ================================ */

TemplateInstance::TemplateInstance(Loc loc, Identifier *ident)
    : ScopeDsymbol(NULL)
{
#if LOG
    printf("TemplateInstance(this = %p, ident = '%s')\n", this, ident ? ident->toChars() : "null");
#endif
    this->loc = loc;
    this->idents.push(ident);
    this->tiargs = NULL;
    this->tempdecl = NULL;
    this->inst = NULL;
    this->argsym = NULL;
    this->aliasdecl = NULL;
    this->semanticdone = 0;
}


Dsymbol *TemplateInstance::syntaxCopy(Dsymbol *s)
{
    TemplateInstance *ti;
    int i;

    if (s)
	ti = (TemplateInstance *)s;
    else
	ti = new TemplateInstance(loc, (Identifier *)idents.data[0]);

    ti->idents.setDim(idents.dim);
    for (i = 1; i < idents.dim; i++)
	ti->idents.data[i] = idents.data[i];

    ti->tiargs = new Array();
    ti->tiargs->setDim(tiargs->dim);
    for (i = 0; i < tiargs->dim; i++)
    {
	Type *ta = isType((Object *)tiargs->data[i]);
	if (ta)
	    ti->tiargs->data[i] = ta->syntaxCopy();
	else
	{
	    Expression *ea = isExpression((Object *)tiargs->data[i]);
	    assert(ea);
	    ti->tiargs->data[i] = ea->syntaxCopy();
	}
    }

    ScopeDsymbol::syntaxCopy(ti);
    return ti;
}


void TemplateInstance::addIdent(Identifier *ident)
{
    idents.push(ident);
}

void TemplateInstance::semantic(Scope *sc)
{
#if LOG
    printf("+TemplateInstance::semantic('%s', this=%p)\n", toChars(), this);
#endif
    if (inst)		// if semantic() was already run
    {
#if LOG
    printf("-TemplateInstance::semantic('%s', this=%p)\n", inst->toChars(), inst);
#endif
	return;
    }

    if (semanticdone != 0)
    {
	error(loc, "recursive template expansion");
//	inst = this;
	return;
    }
    semanticdone = 1;

#if LOG
    printf("\tdo semantic\n");
#endif
    // Run semantic on each argument, place results in tiargs[]
    semanticTiargs(sc);

    tempdecl = findTemplateDeclaration(sc);
    if (!tempdecl || global.errors)
    {	inst = this;
	return;		// error recovery
    }

    /* See if there is an existing TemplateInstantiation that already
     * implements the typeargs. If so, just refer to that one instead.
     */

    for (int i = 0; i < tempdecl->instances.dim; i++)
    {
	TemplateInstance *ti = (TemplateInstance *)tempdecl->instances.data[i];
#if LOG
	printf("\tchecking for match with instance %d (%p): '%s'\n", i, ti, ti->toChars());
#endif
	assert(tdtypes.dim == ti->tdtypes.dim);

	for (int j = 0; j < tdtypes.dim; j++)
	{   Object *o1 = (Object *)tdtypes.data[j];
	    Object *o2 = (Object *)ti->tdtypes.data[j];
	    Type *t1 = isType(o1);
	    Type *t2 = isType(o2);
	    Expression *e1 = isExpression(o1);
	    Expression *e2 = isExpression(o2);
	    Dsymbol *s1 = isDsymbol(o1);
	    Dsymbol *s2 = isDsymbol(o2);

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
				return;
			    }
			}
		    }
		}

		if (!t2 || !t1->equals(t2))
		    goto L1;
	    }
	    else if (e1)
	    {
		if (!e2 || !e1->equals(e2))
		    goto L1;
	    }
	    else if (s1)
	    {
		if (!s2 || !s1->equals(s2))
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
    tempdecl->instances.push(this);
    parent = tempdecl->parent;
    //printf("parent = '%s'\n", parent->kind());

    ident = genIdent();		// need an identifier for name mangling purposes.

    // Add 'this' to the enclosing scope's members[] so the semantic routines
    // will get called on the instance members
#if 1
    {	Array *a;
	int i;

	if (sc->scopesym && sc->scopesym->members && !sc->scopesym->isTemplateMixin())
	{
	    //printf("\t1: adding to %s %s\n", sc->scopesym->kind(), sc->scopesym->toChars());
	    a = sc->scopesym->members;
	}
	else
	{
	    //printf("\t2: adding to module %s\n", sc->module->importedFrom->toChars());
	    a = sc->module->importedFrom->members;
	}
	for (i = 0; 1; i++)
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
    if (!scope)
    {
	error("forward reference to template declaration %s\n", tempdecl->toChars());
	return;
    }

#if LOG
    printf("\tcreate scope for template parameters '%s'\n", toChars());
#endif
    argsym = new ScopeDsymbol();
    argsym->parent = scope->parent;
    scope = scope->push(argsym);

    // Declare each template parameter as an alias for the argument type
    declareParameters(scope);

    // Add members of template instance to template instance symbol table
//    parent = scope->scopesym;
    symtab = new DsymbolTable();
    for (int i = 0; i < members->dim; i++)
    {
	Dsymbol *s = (Dsymbol *)members->data[i];
#if LOG
	printf("\tadding member '%s' %p to '%s'\n", s->toChars(), s, this->toChars());
#endif
	s->addMember(scope, this);
    }

    /* See if there is only one member of template instance, and that
     * member has the same name as the template instance.
     * If so, this template instance becomes an alias for that member.
     */
    //printf("members->dim = %d\n", members->dim);
    if (members->dim)
    {
	Dsymbol *s = (Dsymbol *)members->data[0];
	s = s->oneMember();

	// Ignore any additional template instance symbols
	for (int j = 1; j < members->dim; j++)
	{   Dsymbol *sx = (Dsymbol *)members->data[j];
	    if (sx->isTemplateInstance())
		continue;
	    s = NULL;
	    break;
	}

	if (s)
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
    sc2->parent = this;
    for (int i = 0; i < members->dim; i++)
    {
	Dsymbol *s = (Dsymbol *)members->data[i];
	s->semantic(sc2);
	sc2->module->runDeferredSemantic();
    }

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

    sc2->pop();

    scope->pop();

    // Give additional context info if error occurred during instantiation
    if (global.errors != errorsave)
	error("error instantiating");

#if LOG
    printf("-TemplateInstance::semantic('%s', this=%p)\n", toChars(), this);
#endif
}


void TemplateInstance::semanticTiargs(Scope *sc)
{
    // Run semantic on each argument, place results in tiargs[]
    for (int j = 0; j < tiargs->dim; j++)
    {   Type *ta = isType((Object *)tiargs->data[j]);
	Expression *ea;
	Dsymbol *sa;

	if (ta)
	{
	    // It might really be an Expression or an Alias
	    ta->resolve(loc, sc, &ea, &ta, &sa);
	    if (ea)
		tiargs->data[j] = ea;
	    else if (sa)
		tiargs->data[j] = sa;
	    else if (ta)
		tiargs->data[j] = ta;
	    else
	    {
		assert(global.errors);
		tiargs->data[j] = Type::terror;
	    }
	}
	else
	{
	    ea = isExpression((Object *)tiargs->data[j]);
	    assert(ea);
	    ea = ea->semantic(sc);
	    ea = ea->constFold();
	    tiargs->data[j] = ea;
	}
	//printf("1: tiargs->data[%d] = %p\n", j, tiargs->data[j]);
    }
}

/**********************************************
 * Find template declaration corresponding to template instance.
 */

TemplateDeclaration *TemplateInstance::findTemplateDeclaration(Scope *sc)
{
    if (!tempdecl)
    {
	/* Given:
	 *    instance foo.bar.abc( ... )
	 * figure out which TemplateDeclaration foo.bar.abc refers to.
	 */
	Dsymbol *s;
	Dsymbol *scopesym;
	Identifier *id;
	int i;

	id = (Identifier *)idents.data[0];
	s = sc->search(id, &scopesym);
	if (s)
	{
#if LOG
	    printf("It's an instance of '%s'\n", s->toChars());
#endif
	    s = s->toAlias();
	    for (i = 1; i < idents.dim; i++)
	    {   Dsymbol *sm;

		id = (Identifier *)idents.data[i];
		sm = s->search(id, 0);
		if (!sm)
		{
		    s = NULL;
		    break;
		}
		s = sm->toAlias();
	    }
	}
	if (!s)
	{   error("identifier '%s' is not defined", id->toChars());
	    return NULL;
	}

	/* It should be a TemplateDeclaration, not some other symbol
	 */
	tempdecl = s->isTemplateDeclaration();
	if (!tempdecl)
	{
	    error("%s is not a template declaration, it is a %s", id->toChars(), s->kind());
	    return NULL;
	}
    }
    else
	assert(tempdecl->isTemplateDeclaration());

    /* Since there can be multiple TemplateDeclaration's with the same
     * name, look for the best match.
     */
    TemplateDeclaration *td_ambig = NULL;
    TemplateDeclaration *td_best = NULL;
    MATCH m_best = MATCHnomatch;
    Array dedtypes;

    for (TemplateDeclaration *td = tempdecl; td; td = td->overnext)
    {
	MATCH m;

//if (tiargs->dim) printf("2: tiargs->dim = %d, data[0] = %p\n", tiargs->dim, tiargs->data[0]);

	// If more arguments than parameters,
	// then this is no match.
	if (td->parameters->dim < tiargs->dim)
	    continue;

	dedtypes.setDim(td->parameters->dim);
	if (!td->scope)
	{
	    error("forward reference to template");
	    return NULL;
	}
	m = td->matchWithInstance(this, &dedtypes, 0);
	if (!m)			// no match at all
	    continue;

#if 0
	if (m < m_best)
	    goto Ltd_best;
	if (m > m_best)
	    goto Ltd;
#else
	if (!m_best)
	    goto Ltd;
#endif
	{
	// Disambiguate by picking the most specialized TemplateDeclaration
	int c1 = td->leastAsSpecialized(td_best);
	int c2 = td_best->leastAsSpecialized(td);
	//printf("c1 = %d, c2 = %d\n", c1, c2);

	if (c1 && !c2)
	    goto Ltd;
	else if (!c1 && c2)
	    goto Ltd_best;
	else
	    goto Lambig;
	}

      Lambig:		// td_best and td are ambiguous
	td_ambig = td;
	continue;

      Ltd_best:		// td_best is the best match so far
	continue;

      Ltd:		// td is the new best match
	td_best = td;
	m_best = m;
	tdtypes.setDim(dedtypes.dim);
	memcpy(tdtypes.data, dedtypes.data, tdtypes.dim * sizeof(void *));
	continue;
    }

    if (!td_best)
    {
	error("does not match any template declaration");
	return NULL;
    }
    if (td_ambig)
    {
	error("matches more than one template declaration");
    }

    /* The best match is td_best
     */
    tempdecl = td_best;
#if LOG
    printf("\tIt's a match with template declaration '%s'\n", tempdecl->toChars());
#endif
    return tempdecl;
}


/****************************************
 * This instance needs an identifier for name mangling purposes.
 * Create one by taking the template declaration name and adding
 * the type signature for it.
 */

Identifier *TemplateInstance::genIdent()
{   OutBuffer buf;
    char *id;

    //printf("TemplateInstance::genIdent('%s')\n", tempdecl->ident->toChars());
    buf.writestring(tempdecl->ident->toChars());
    buf.writeByte('_');
    for (int i = 0; i < tiargs->dim; i++)
    {   Object *o = (Object *)tiargs->data[i];
	//Object *o = (Object *)tdtypes.data[i];
	Type *ta = isType(o);
	Expression *ea = isExpression(o);
	Dsymbol *sa = isDsymbol(o);
	if (ta)
	{
	    if (ta->deco)
		buf.writestring(ta->deco);
	    else
		assert(global.errors);
	}
	else if (ea)
	{
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
	    buf.writeByte('_');
	    buf.printf("%u", ea->toInteger());
	}
	else if (sa)
	{
	  Lsa:
	    Declaration *d = sa->isDeclaration();
	    if (d && !d->isDataseg() && !d->isFuncDeclaration() && !isTemplateMixin())
	    {
		error("cannot use local '%s' as template parameter", d->toChars());
	    }
	    if (d && !d->type->deco)
		error("forward reference of %s", d->toChars());
	    else
	    {
		char *p = sa->mangle();
		buf.printf("__%u_%s", strlen(p) + 1, p);
	    }
	}
	else
	    assert(0);
    }
    id = buf.toChars();
    buf.data = NULL;
    return new Identifier(id, TOKidentifier);
}


/****************************************************
 * Declare parameters of template instance, initialize them with the
 * template instance arguments.
 */

void TemplateInstance::declareParameters(Scope *scope)
{
    //printf("TemplateInstance::declareParameters()\n");
    for (int i = 0; i < tdtypes.dim; i++)
    {
	TemplateParameter *tp = (TemplateParameter *)tempdecl->parameters->data[i];
	//Object *o = (Object *)tiargs->data[i];
	Object *o = (Object *)tdtypes.data[i];
	Type *targ = isType(o);
	Expression *ea = isExpression(o);
	Dsymbol *sa = isDsymbol(o);
	Dsymbol *s;

	if (targ)
	{
	    Type *tded = isType((Object *)tdtypes.data[i]);

	    assert(tded);
	    s = new AliasDeclaration(0, tp->ident, tded);
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
	    assert(tvp);

	    VarDeclaration *v = new VarDeclaration(0, tvp->valType, tp->ident, init);
	    v->storage_class = STCconst;
	    s = v;
	}
	else
	    assert(0);
	if (!scope->insert(s))
	    error("declaration %s is already defined", tp->ident->toChars());
	s->semantic(scope);
    }
}


void TemplateInstance::semantic2(Scope *sc)
{   int i;

    if (semanticdone >= 2)
	return;
    semanticdone = 2;
#if LOG
    printf("+TemplateInstance::semantic2('%s')\n", toChars());
#endif
    if (members)
    {
	sc = tempdecl->scope;
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
    printf("-TemplateInstance::semantic2('%s')\n", toChars());
#endif
}

void TemplateInstance::semantic3(Scope *sc)
{   int i;

    if (semanticdone >= 3)
	return;
    semanticdone = 3;
#if LOG
    printf("TemplateInstance::semantic3('%s')\n", toChars());
#endif
    if (members)
    {
	sc = tempdecl->scope;
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

void TemplateInstance::toObjFile()
{   int i;

#if LOG
    printf("TemplateInstance::toObjFile('%s', this = %p)\n", toChars(), this);
#endif
    if (members)
    {
	for (i = 0; i < members->dim; i++)
	{
	    Dsymbol *s = (Dsymbol *)members->data[i];
	    s->toObjFile();
	}
    }
}

void TemplateInstance::inlineScan()
{   int i;

#if LOG
    printf("TemplateInstance::inlineScan('%s')\n", toChars());
#endif
    if (members)
    {
	for (i = 0; i < members->dim; i++)
	{
	    Dsymbol *s = (Dsymbol *)members->data[i];
	    s->inlineScan();
	}
    }
}

void TemplateInstance::toCBuffer(OutBuffer *buf)
{
    int i;

    for (i = 0; i < idents.dim; i++)
    {   Identifier *id = (Identifier *)idents.data[i];

	if (i)
	    buf->writeByte('.');
	buf->writestring(id->toChars());
    }
    buf->writestring("!(");
    if (nest)
	buf->writestring("...");
    else
    {
	nest++;
	for (i = 0; i < tiargs->dim; i++)
	{
	    if (i)
		buf->writeByte(',');
	    Object *oarg = (Object *)tiargs->data[i];
	    Type *t = isType(oarg);
	    Expression *e = isExpression(oarg);
	    Dsymbol *s = isDsymbol(oarg);
	    if (t)
		t->toCBuffer(buf, NULL);
	    else if (e)
		e->toCBuffer(buf);
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
#ifdef DEBUG
		printf("tiargs[%d] = %p\n", i, oarg);
#endif
		assert(0);
	    }
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
	return this;
    }

    if (inst != this)
	return inst->toAlias();

    if (aliasdecl)
	return aliasdecl->toAlias();

    return inst;
}

AliasDeclaration *TemplateInstance::isAliasDeclaration()
{
    return aliasdecl;
}

char *TemplateInstance::kind()
{
    return "template instance";
}

char *TemplateInstance::toChars()
{
    OutBuffer buf;
    char *s;

    toCBuffer(&buf);
    s = buf.toChars();
    buf.data = NULL;
    return s;
    //return s + 9;	// kludge to skip over 'instance '
}

/* ======================== TemplateMixin ================================ */

TemplateMixin::TemplateMixin(Loc loc, Identifier *ident, TypeTypeof *tqual,
	Array *idents, Array *tiargs)
	: TemplateInstance(loc, (Identifier *)idents->data[idents->dim - 1])
{
    //printf("TemplateMixin(ident = '%s')\n", ident ? ident->toChars() : "");
    this->ident = ident;
    this->tqual = tqual;
    this->idents = idents;
    this->tiargs = tiargs ? tiargs : new Array();
}

Dsymbol *TemplateMixin::syntaxCopy(Dsymbol *s)
{   TemplateMixin *tm;

    Array *ids = new Array();
    ids->setDim(idents->dim);
    for (int i = 0; i < idents->dim; i++)
    {	// Matches TypeQualified::syntaxCopyHelper()
        Identifier *id = (Identifier *)idents->data[i];
        if (id->dyncast() != DYNCAST_IDENTIFIER)
        {
            TemplateInstance *ti = (TemplateInstance *)id;

            ti = (TemplateInstance *)ti->syntaxCopy(NULL);
            id = (Identifier *)ti;
        }
        ids->data[i] = id;
    }

    tm = new TemplateMixin(loc, ident,
		(TypeTypeof *)(tqual ? tqual->syntaxCopy() : NULL),
		ids, tiargs);
    TemplateInstance::syntaxCopy(tm);
    return tm;
}

void TemplateMixin::semantic(Scope *sc)
{
#if LOG
    printf("+TemplateMixin::semantic('%s', this=%p)\n", toChars(), this);
#endif
    if (semanticdone)
	return;
    semanticdone = 1;
#if LOG
    printf("\tdo semantic\n");
#endif

    // Run semantic on each argument, place results in tiargs[]
    semanticTiargs(sc);

    // Follow qualifications to find the TemplateDeclaration
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
	    if (id->dyncast() == DYNCAST_IDENTIFIER)
	    {
		s = sc->search(id, NULL);
	    }
	    else
	    {
		TemplateInstance *ti = (TemplateInstance *)id;
		ti->semantic(sc);
		s = ti;
	    }
	}

	for (; i < idents->dim; i++)
	{   Dsymbol *sm;

	    if (!s)
		break;
	    s = s->toAlias();
	    id = (Identifier *)idents->data[i];
	    if (id->dyncast() == DYNCAST_IDENTIFIER)
	    {
		sm = s->search(id, 0);
	    }
	    else
	    {
		// It's a template instance
		//printf("\ttemplate instance id\n");
		TemplateDeclaration *td;
		TemplateInstance *ti = (TemplateInstance *)id;
		id = (Identifier *)ti->idents.data[0];
		sm = s->search(id, 0);
		if (!sm)
		{   error("template identifier %s is not a member of %s", id->toChars(), s->toChars());
		    return;
		}
		sm = sm->toAlias();
		td = sm->isTemplateDeclaration();
		if (!td)
		{
		    error("%s is not a template", id->toChars());
		    inst = this;
		    return;
		}
		ti->tempdecl = td;
		ti->semantic(sc);
		sm = ti->toAlias();
	    }
	    s = sm;
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
	    error("%s is not a template", s->toChars());
	    inst = this;
	    return;
	}
    }

    tempdecl = findTemplateDeclaration(sc);
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

    {
	ScopeDsymbol *sds = (ScopeDsymbol *)sc->scopesym;
	sds->importScope(this, PROTpublic);
    }

#if LOG
    printf("\tcreate scope for template parameters '%s'\n", toChars());
#endif
    Scope *scx = sc;
    scx = sc->push(this);
    scx->parent = this;

    argsym = new ScopeDsymbol();
    argsym->parent = scx->parent;
    Scope *scope = scx->push(argsym);

    // Declare each template parameter as an alias for the argument type
    declareParameters(scope);

    // Add members to enclosing scope, as well as this scope
    for (unsigned i = 0; i < members->dim; i++)
    {   Dsymbol *s;

	s = (Dsymbol *)members->data[i];
	s->addMember(scope, this);
	//sc->insert(s);
	//printf("sc->parent = %p, sc->scopesym = %p\n", sc->parent, sc->scopesym);
	//printf("s->parent = %s\n", s->parent->toChars());
    }

    // Do semantic() analysis on template instance members
#if LOG
    printf("\tdo semantic() on template instance members '%s'\n", toChars());
#endif
    Scope *sc2;
    sc2 = scope->push(this);
    sc2->offset = sc->offset;
    for (int i = 0; i < members->dim; i++)
    {
	Dsymbol *s = (Dsymbol *)members->data[i];
	s->semantic(sc2);
    }
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

    sc2->pop();

    scope->pop();

//    if (!isAnonymous())
    {
	scx->pop();
    }
#if LOG
    printf("-TemplateMixin::semantic('%s', this=%p)\n", toChars(), this);
#endif
}

void TemplateMixin::semantic2(Scope *sc)
{   int i;

    if (semanticdone >= 2)
	return;
    semanticdone = 2;
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

    if (semanticdone >= 3)
	return;
    semanticdone = 3;
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

char *TemplateMixin::kind()
{
    return "mixin";
}

Dsymbol *TemplateMixin::oneMember()
{
    return Dsymbol::oneMember();
}

void TemplateMixin::toCBuffer(OutBuffer *buf)
{
    //buf->writestring("mixin ");
    if (tqual)
    {	tqual->toCBuffer(buf, NULL);
	buf->writeByte('.');
    }
    for (int i = 0; i + 1 < idents->dim; i++)
    {	Identifier *id = (Identifier *)idents->data[i];

	buf->writestring(id->toChars());
	buf->writeByte('.');
    }
    TemplateInstance::toCBuffer(buf);
    if (ident)
    {
	buf->writeByte(' ');
	buf->writestring(ident->toChars());
    }
}


void TemplateMixin::toObjFile()
{
    //printf("TemplateMixin::toObjFile('%s')\n", toChars());
    TemplateInstance::toObjFile();
}

