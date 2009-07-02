
// Copyright (c) 1999-2003 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

// Handle template implementation

#include "root.h"
#include "mem.h"

#include "template.h"
#include "mtype.h"
#include "init.h"
#include "expression.h"

#define LOG	0

/********************************************
 * These functions substitute for dynamic_cast.
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
    this->loc = loc;
    this->parameters = parameters;
    this->members = decldefs;
    this->overnext = NULL;
    this->scope = NULL;
}

Dsymbol *TemplateDeclaration::syntaxCopy(Dsymbol *)
{
    assert(0);
    return NULL;
}

void TemplateDeclaration::semantic(Scope *sc)
{
    if (sc->func)
	error("cannot declare template at function scope");

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

    // Remember Scope for later instantiations
    this->scope = sc;
    sc->setNoFree();

    // Set up scope for parameters
    ScopeDsymbol *paramsym = new ScopeDsymbol();
    paramsym->parent = sc->parent;
    Scope *paramscope = sc->push(paramsym);


    for (int i = 0; i < parameters->dim; i++)
    {
	TemplateParameter *tp = (TemplateParameter *)parameters->data[i];

	TypeIdentifier *ti = new TypeIdentifier(loc, tp->ident);
	AliasDeclaration *sparam = new AliasDeclaration(loc, tp->ident, ti);
	if (!paramscope->insert(sparam))
	    error("parameter '%s' multiply defined", tp->ident->toChars());

	if (tp->valType)
	{
	    tp->valType = tp->valType->semantic(loc, sc);
	    if (!tp->valType->isintegral())
		error("integral type expected for value-parameter, not %s", tp->valType->toChars());
	}

	if (tp->specValue)
	{   Expression *e = tp->specValue;

	    e = e->semantic(sc);
	    e = e->implicitCastTo(tp->valType);
	    e = e->constFold();
	    tp->specValue = e;
	    e->toInteger();
	}

	if (tp->specType)
	{
	    tp->specType = tp->specType->semantic(loc, paramscope);
	}
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

	    if (p1->ident != p2->ident)
		goto Lcontinue;

	    if (p1->specType != p2->specType)
		goto Lcontinue;

	    if (p1->valType != p2->valType)
	    {
		if (p1->valType && !p1->valType->equals(p2->valType))
		    goto Lcontinue;
	    }
	    if (p1->specValue != p2->specValue)
		goto Lcontinue;

	    if (p1->isalias != p2->isalias)
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
 * Return match level.
 */

MATCH TemplateDeclaration::matchWithInstance(TemplateInstance *ti,
	Array *dedtypes)
{   MATCH m;
    int dim = dedtypes->dim;

#if LOG
    printf("TemplateDeclaration::matchWithInstance(this = %p, ti = %p)\n", this, ti);
#endif
    dedtypes->zero();

    assert(dim == parameters->dim);
    assert(dim == ti->tiargs.dim);

    // Attempt type deduction
    m = MATCHexact;
    for (int i = 0; i < dim; i++)
    {	MATCH m2;
	TemplateParameter *tp = (TemplateParameter *)parameters->data[i];
	Object *oarg = (Object *)ti->tiargs.data[i];

	if (tp->valType)
	{
	    Expression *ei = isExpression(oarg);
	    if (!ei && oarg)
		goto Lnomatch;

	    if (tp->specValue)
	    {
		if (!ei || !ei->equals(tp->specValue))
		    goto Lnomatch;
	    }
	    else if (dedtypes->data[i])
	    {	// Must match already deduced value
		Expression *e = (Expression *)dedtypes->data[i];

		if (!ei || !ei->equals(e))
		    goto Lnomatch;
	    }
	    dedtypes->data[i] = ei;
	}
	else if (tp->isalias)
	{
	    Dsymbol *sa;

	    Expression *ea = isExpression(oarg);
	    if (ea)
	    {	// Try to convert Expression to symbol
		if (ea->op == TOKvar)
		    sa = ((VarExp *)ea)->var;
		else
		    goto Lnomatch;
	    }
	    else
	    {	// Try to convert Type to symbol
		Type *ta = isType(oarg);
		if (ta)
		    sa = ta->toDsymbol(NULL);
		else
		    sa = isDsymbol(oarg);	// if already a symbol
	    }

	    if (!sa)
		goto Lnomatch;

	    dedtypes->data[i] = sa;
	}
	else
	{
	    Type *ta = isType(oarg);
	    if (!ta)
		goto Lnomatch;

	    if (tp->specType)
	    {
		//printf("calling matchType()\n");
		m2 = matchType(ta, i, dedtypes);
		if (m2 == MATCHnomatch)
		    goto Lnomatch;

		if (m2 < m)
		    m = m2;
	    }
	    else if (dedtypes->data[i])
	    {   // Must match already deduced type
		Type *t = (Type *)dedtypes->data[i];

		if (!t->equals(tp->specType))
		    goto Lnomatch;
	    }
	    else
	    {
		dedtypes->data[i] = ta;
	    }
	}
    }

    // Any parameter left without a type gets the type of its corresponding arg
    for (int i = 0; i < dim; i++)
    {
	if (!dedtypes->data[i])
	    dedtypes->data[i] = ti->tiargs.data[i];
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

	    printf(" [%d] %s\n", i, tp->ident->toChars());
	    printf("\tSpecialization: ");
	    if (tp->valType)
	    {
		Expression *ea = (Expression *)dedtypes->data[i];

		if (tp->specValue)
		    printf("%s\n", tp->specValue->toChars());
		else
		    printf("\n");
		printf("\tArgument Value: %s\n", ea ? ea->toChars() : "NULL");
	    }
	    else if (tp->isalias)
	    {
		Dsymbol *sa = (Dsymbol *)dedtypes->data[i];

		printf("\tArgument alias: %s\n", sa->toChars());
	    }
	    else
	    {
		Type *t  = (Type *)ti->tiargs.data[i];
		Type *ta = (Type *)dedtypes->data[i];

		if (tp->specType)
		    printf("%s\n", tp->specType->toChars());
		else
		    printf("\n");
		printf("\tArgument:       %s\n", t->toChars());
		printf("\tDeduced Type:   %s\n", ta->toChars());
	    }
	}
    }
    else
	goto Lnomatch;
#endif

#if LOG
    printf(" match = %d\n", m);
#endif
    return m;

Lnomatch:
#if LOG
    printf(" no match\n");
#endif
    return MATCHnomatch;
}

/************************************************
 * Given template instance i'th argument tiarg,
 * match it against the i'th TemplateParameter.type to deduce
 * any types.
 * Fill in any deduced types in atype[].
 */

MATCH TemplateDeclaration::matchType(Type *tiarg, int i, Array *dedtypes)
{
    TemplateParameter *tp = (TemplateParameter *)parameters->data[i];
    MATCH m = MATCHnomatch;

    assert(!tp->valType);
    if (!tp->specType)
    {
	/* No specialization given for this TemplateParameter.
	 * Therefore, the i'th parameter type should just be the
	 * corresponding instance argument - tiarg.
	 */

	Type *at = (Type *)dedtypes->data[i];
	if (!at)
	{
	    dedtypes->data[i] = (void *)tiarg;
	    return MATCHexact;
	}
	if (tiarg->equals(at))
	    return MATCHexact;
	else
	    return MATCHnomatch;
    }

    //printf("tiarg: %d, ", tiarg->ty); tiarg->print();
    //printf("tp->specType: %d, ", tp->specType->ty); tp->specType->print();

#if 0
    // Allow a derived class as a conversion match from a base class.
    if (tiarg->ty == Tclass && tp->specType->ty == Tclass)
    {
	return (MATCH) tiarg->implicitConvTo(tp->specType);
    }
#endif

    m = tiarg->deduceType(tp->specType, parameters, dedtypes);

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

    TemplateInstance ti(ident);		// create dummy template instance
    Array dedtypes;

#define LOG_LEASTAS	0

#if LOG_LEASTAS
    printf("%s.leastAsSpecialized(%s)\n", toChars(), td2->toChars());
#endif

    // Set type arguments to dummy template instance to be types
    // generated from the parameters to this template declaration
    ti.tiargs.setDim(parameters->dim);
    for (int i = 0; i < ti.tiargs.dim; i++)
    {
	TemplateParameter *tp = (TemplateParameter *)parameters->data[i];

	if (tp->valType)
	{
	    if (tp->specValue)
		ti.tiargs.data[i] = (void *)tp->specValue;
	    else
	    {
		ti.tiargs.data[i] = NULL;
	    }
	}
	else if (tp->isalias)
	{
	    ti.tiargs.data[i] = NULL;	// not sure what to put here
	}
	else
	{
	    if (tp->specType)
		ti.tiargs.data[i] = (void *)tp->specType;
	    else
	    {	// Use this for alias-parameter's too
		TypeIdentifier *t = new TypeIdentifier(0, tp->ident);
		ti.tiargs.data[i] = (void *)t;
	    }
	}
    }

    // Temporary Array to hold deduced types
    dedtypes.setDim(parameters->dim);

    // Attempt a type deduction
    if (td2->matchWithInstance(&ti, &dedtypes))
    {
#if LOG_LEASTAS
	printf("  is least as specialized\n");
#endif
	return 1;
    }
#if LOG_LEASTAS
    printf("  is not as specialized\n");
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
	if (tp->valType)
	{
	    tp->valType->toCBuffer(buf, tp->ident);
	    if (tp->specValue)
	    {
		buf->writestring(" : ");
		tp->specValue->toCBuffer(buf);
	    }
	}
	else if (tp->isalias)
	{
	    buf->writestring("alias ");
	    buf->writestring(tp->ident->toChars());
	}
	else
	{
	    buf->writestring(tp->ident->toChars());
	    if (tp->specType)
	    {
		buf->writestring(" : ");
		tp->specType->toCBuffer(buf, NULL);
	    }
	}
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

	for (int i = 0; i < tempinst->tiargs.dim; i++)
	{
	    Type *t1 = (Type *)tempinst->tiargs.data[i];
	    Type *t2 = (Type *)tp->tempinst->tiargs.data[i];

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

TemplateParameter::TemplateParameter(Identifier *ident, Type *specType)
{
     this->ident = ident;
     this->specType = specType;
     this->valType = NULL;
     this->specValue = NULL;
     this->isalias = 0;
}

TemplateParameter::TemplateParameter(Identifier *ident)
{
     this->ident = ident;
     this->specType = NULL;
     this->valType = NULL;
     this->specValue = NULL;
     this->isalias = 1;
}

TemplateParameter::TemplateParameter(Identifier *ident, Type *valType, Expression *specValue)
{
     this->ident = ident;
     this->specType = NULL;
     this->valType = valType;
     this->specValue = specValue;
     this->isalias = 0;
}

/* ======================== TemplateInstance ================================ */

TemplateInstance::TemplateInstance(Identifier *ident)
    : ScopeDsymbol(NULL)
{
#if LOG
    printf("TemplateInstance(this = %p, ident = '%s')\n", this, ident ? ident->toChars() : "null");
#endif
    this->idents.push(ident);
    this->tempdecl = NULL;
    this->inst = NULL;
    this->argsym = NULL;
    this->aliasdecl = NULL;
}


Dsymbol *TemplateInstance::syntaxCopy(Dsymbol *s)
{
    TemplateInstance *ti;
    int i;

    assert(!s);
    ti = new TemplateInstance((Identifier *)idents.data[0]);

    ti->idents.setDim(idents.dim);
    for (i = 1; i < idents.dim; i++)
	ti->idents.data[i] = idents.data[i];

    ti->tiargs.setDim(tiargs.dim);
    for (i = 0; i < tiargs.dim; i++)
    {
	Type *ta = isType((Object *)tiargs.data[i]);
	if (ta)
	    ti->tiargs.data[i] = ta->syntaxCopy();
	else
	{
	    Expression *ea = isExpression((Object *)tiargs.data[i]);
	    assert(ea);
	    ti->tiargs.data[i] = ea->syntaxCopy();
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
    if (inst)		// if semantic() was already run
	return;

#if LOG
    printf("TemplateInstance::semantic('%s', this=%p)\n", toChars(), this);
#endif

    // Run semantic on each argument
    for (int j = 0; j < tiargs.dim; j++)
    {   Type *ta = isType((Object *)tiargs.data[j]);
	Expression *ea;
	Dsymbol *sa;

	if (ta)
	{
	    // It might really be an Expression or an Alias
	    ta->resolve(loc, sc, &ea, &ta, &sa);
	    if (ea)
		tiargs.data[j] = ea;
	    else if (sa)
		tiargs.data[j] = sa;
	    else
	    {	assert(ta);
		tiargs.data[j] = ta;
	    }
	}
	else
	{
	    ea = isExpression((Object *)tiargs.data[j]);
	    assert(ea);
	    ea = ea->semantic(sc);
	    ea = ea->constFold();
	    tiargs.data[j] = ea;
	}
    }

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
	    return;
	}

	/* It should be a TemplateDeclaration, not some other symbol
	 */
	tempdecl = s->isTemplateDeclaration();
	if (!tempdecl)
	{
	    error("%s is not a template declaration", id->toChars());
	    return;
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

    tdtypes.setDim(tiargs.dim);
    dedtypes.setDim(tiargs.dim);
    for (TemplateDeclaration *td = tempdecl; td; td = td->overnext)
    {
	MATCH m;

	// If number of arguments doesn't match number of parameters,
	// then this is no match.
	if (td->parameters->dim != tiargs.dim)
	    continue;

	m = td->matchWithInstance(this, &dedtypes);
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
	memcpy(tdtypes.data, dedtypes.data, tiargs.dim * sizeof(void *));
	continue;
    }

    if (!td_best)
    {
	error("does not match any template declaration");
	return;
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

    /* See if there is an existing TemplateInstantiation that already
     * implements the typeargs. If so, just refer to that one instead.
     */

    for (int i = 0; i < tempdecl->instances.dim; i++)
    {
	TemplateInstance *ti = (TemplateInstance *)tempdecl->instances.data[i];
#if LOG
	printf("\tchecking for match with instance %d: '%s'\n", i, ti->toChars());
#endif
	assert(tiargs.dim == ti->tiargs.dim);

	for (int j = 0; j < tiargs.dim; j++)
	{   Object *o1 = (Object *)tiargs.data[j];
	    Object *o2 = (Object *)ti->tiargs.data[j];
	    Type *t1 = isType(o1);
	    Type *t2 = isType(o2);
	    Expression *e1 = isExpression(o1);
	    Expression *e2 = isExpression(o2);
	    Dsymbol *s1 = isDsymbol(o1);
	    Dsymbol *s2 = isDsymbol(o1);

	    /* A proper implementation of the various equals() overrides
	     * should make it possible to just do o1->equals(o2), but
	     * we'll do that another day.
	     */

	    if (t1)
	    {
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
    inst = this;
    tempdecl->instances.push(this);

    // This instance needs an identifier for name mangling purposes.
    // Create one by taking the template declaration name and adding
    // the type signature for it.
    {	OutBuffer buf;
	char *id;

	buf.writestring(tempdecl->ident->toChars());
	buf.writeByte('_');
	for (int i = 0; i < tiargs.dim; i++)
	{   Object *o = (Object *)tiargs.data[i];
	    //Object *o = (Object *)tdtypes.data[i];
	    Type *ta = isType(o);
	    Expression *ea = isExpression(o);
	    Dsymbol *sa = isDsymbol(o);
	    if (ta)
	    {
		assert(ta->deco);
		buf.writestring(ta->deco);
	    }
	    else if (ea)
	    {
		buf.writeByte('_');
		//buf.printf("%u", ea->toInteger());
	    }
	    else if (sa)
	    {
		char *p = sa->mangle();
		buf.printf("__%u_%s", strlen(p) + 1, p);
	    }
	    else
		assert(0);
	}
	id = buf.toChars();
	buf.data = NULL;
	ident = new Identifier(id, TOKidentifier);
    }

    // Add 'this' to the enclosing scope's members[] so the semantic routines
    // will get called on the instance members
#if 1
    {	Array *a;
	int i;

	if (sc->scopesym->members)
	    a = sc->scopesym->members;
	else
	{
	    a = sc->module->members;
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
    }

#if LOG
    printf("\tcreate scope for template parameters '%s'\n", toChars());
#endif
    argsym = new ScopeDsymbol();
    argsym->parent = scope->parent;
    scope = scope->push(argsym);

    // Declare each template parameter as an alias for the argument type
    for (int i = 0; i < tiargs.dim; i++)
    {
	TemplateParameter *tp = (TemplateParameter *)tempdecl->parameters->data[i];
	//Object *o = (Object *)tiargs.data[i];
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
	    s = new AliasDeclaration(0, tp->ident, sa);
	}
	else if (ea)
	{
	    // tdtypes.data[i] always matches ea here
	    Initializer *init = new ExpInitializer(loc, ea);

	    VarDeclaration *v = new VarDeclaration(0, tp->valType, tp->ident, init);
	    v->storage_class = STCconst;
	    s = v;
	}
	else
	    assert(0);
	if (!scope->insert(s))
	    error("declaration %s is already defined", tp->ident->toChars());
	s->semantic(scope);
    }

    // Add members of template instance to template instance symbol table
    parent = scope->scopesym;
    symtab = new DsymbolTable();
    for (int i = 0; i < members->dim; i++)
    {
	Dsymbol *s = (Dsymbol *)members->data[i];
#if LOG
	printf("\tadding member '%s' %p to '%s'\n", s->toChars(), s, this->toChars());
#endif
	s->addMember(this);
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
    }

    if (sc->parent->isFuncDeclaration())
	semantic2(sc2);

    sc2->pop();

    scope->pop();

    /* See if there is only one member of template instance, and that
     * member has the same name as the template instance.
     * If so, this template instance becomes an alias for that member.
     */
    //printf("members->dim = %d\n", members->dim);
    if (members->dim == 1)
    {
	Dsymbol *s = (Dsymbol *)members->data[0];

	//s->print();
	//printf("'%s', '%s'\n", s->ident->toChars(), tempdecl->ident->toChars());
	if (s->ident && s->ident->equals(tempdecl->ident))
	{
	    //printf("setting aliasdecl\n");
	    aliasdecl = new AliasDeclaration(loc, s->ident, s);
	}
    }
}

void TemplateInstance::semantic2(Scope *sc)
{   int i;

#if LOG
    printf("TemplateInstance::semantic2('%s')\n", toChars());
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
	    s->semantic2(sc);
	}
	sc = sc->pop();
	sc->pop();
    }
}

void TemplateInstance::semantic3(Scope *sc)
{   int i;

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
    printf("TemplateInstance::toObjFile('%s')\n", toChars());
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
    {	Identifier *id = (Identifier *)idents.data[i];

	if (i)
	    buf->writeByte('.');
	buf->writestring(id->toChars());
    }
    buf->writestring("!(");
    for (i = 0; i < tiargs.dim; i++)
    {
	if (i)
	    buf->writeByte(',');
	Type *t = isType((Object *)tiargs.data[i]);
	Expression *e = isExpression((Object *)tiargs.data[i]);
	Dsymbol *s = isDsymbol((Object *)tiargs.data[i]);
	if (t)
	    t->toCBuffer(buf, NULL);
	else if (e)
	    e->toCBuffer(buf);
	else if (s)
	{
	    buf->writestring(s->ident->toChars());
	}
	else
	    assert(0);
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

