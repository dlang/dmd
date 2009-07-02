
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

/* ======================== TemplateDeclaration ============================= */

TemplateDeclaration::TemplateDeclaration(Loc loc, Identifier *id, Array *parameters, Array *decldefs)
    : ScopeDsymbol(id)
{
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

    // Remember Scope for later instantiations
    this->scope = sc;
    sc->setNoFree();

    for (int i = 0; i < parameters->dim; i++)
    {
	TemplateParameter *tp = (TemplateParameter *)parameters->data[i];

	// Check for duplicate parameters
	for (int j = i + 1; j < parameters->dim; j++)
	{
	    TemplateParameter *tp2 = (TemplateParameter *)parameters->data[j];
	    if (tp->ident->equals(tp2->ident))
		error("parameter '%s' multiply defined", tp->ident->toChars());
	}

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
    }

    /* BUG: should check:
     *	o no virtual functions or non-static data members of classes
     */
}

char *TemplateDeclaration::kind()
{
    return "template";
}

/**********************************
 * Overload this TemplateDeclaration with the new one td.
 * Return !=0 if successful; i.e. no conflict.
 */

int TemplateDeclaration::overloadInsert(Dsymbol *s)
{
    TemplateDeclaration **pf;
    TemplateDeclaration *f;

    //printf("TemplateDeclaration::overloadInsert(%s)\n", s->toChars());
    f = dynamic_cast<TemplateDeclaration *>(s);
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
		goto Lcontinue;

	    if (p1->specValue != p2->specValue)
		goto Lcontinue;
	}

	//printf("false: conflict\n");
	return FALSE;

     Lcontinue:
	;
    }


    *pf = f;
    //printf("true: no conflict\n");
    return TRUE;
}

/***************************************
 * Given that ti is an instance of this TemplateDeclaration,
 * deduce the types of the parameters to this, and store
 * those deduced types in dedtypes[].
 * Return match level.
 */

MATCH TemplateDeclaration::matchWithInstance(TemplateInstance *ti, Array *dedtypes)
{   MATCH m;
    int dim = dedtypes->dim;

    dedtypes->zero();

    assert(dim == parameters->dim);
    assert(dim == ti->tiargs.dim);

    // Attempt type deduction
    m = MATCHexact;
    for (int i = 0; i < dim; i++)
    {	MATCH m2;
	TemplateParameter *tp = (TemplateParameter *)parameters->data[i];

	if (tp->valType)
	{
	    Expression *ei = dynamic_cast<Expression *>((Object *)ti->tiargs.data[i]);
	    if (!ei && ti->tiargs.data[i])
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
	else
	{
	    Type *ta = dynamic_cast<Type *>((Object *)ti->tiargs.data[i]);
	    if (!ta)
		goto Lnomatch;

	    if (tp->specType)
	    {
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
	printf(" no match\n");
#endif

    return m;

Lnomatch:
    //printf(" no match\n");
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

    // Allow a derived class as a conversion match from a base class.
    if (tiarg->ty == Tclass && tp->specType->ty == Tclass)
    {
	return (MATCH) tiarg->implicitConvTo(tp->specType);
    }

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
	else
	{
	    if (tp->specType)
		ti.tiargs.data[i] = (void *)tp->specType;
	    else
	    {   TypeIdentifier *t = new TypeIdentifier(0, tp->ident);
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
    if (!tparam)
	goto Lnomatch;

    if (this == tparam)
	goto Lexact;

    if (tparam->ty == Tident)
    {
	TypeIdentifier *tident = (TypeIdentifier *)tparam;

	if (tident->idents.dim > 1)
	    goto Lnomatch;

	// Determine which parameter tparam is
	int i;
	for (i = 0; 1; i++)
	{
	    if (i == parameters->dim)
		goto Lnomatch;
	    TemplateParameter *tp = (TemplateParameter *)parameters->data[i];

	    if (tp->ident->equals((Identifier *)tident->idents.data[0]))
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
    // Extra check
    if (tparam && tparam->ty == Tclass)
    {
	TypeClass *tp = (TypeClass *)tparam;

	if (sym != tp->sym)
	    return MATCHnomatch;
    }
    return Type::deduceType(tparam, parameters, dedtypes);
}

/* ======================== TemplateParameter =============================== */

TemplateParameter::TemplateParameter(Identifier *ident, Type *specType, Type *valType, Expression *specValue)
{
     this->ident = ident;
     this->specType = specType;
     this->valType = valType;
     this->specValue = specValue;
}

/* ======================== TemplateInstance ================================ */

TemplateInstance::TemplateInstance(Identifier *ident)
    : ScopeDsymbol(NULL)
{
#if LOG
    printf("TemplateInstance(ident = '%s')\n", ident ? ident->toChars() : "null");
#endif
    this->idents.push(ident);
    this->tempdecl = NULL;
    this->inst = NULL;
    this->argsym = NULL;
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
	Type *ta = dynamic_cast<Type *>((Object *)tiargs.data[i]);
	if (ta)
	    ti->tiargs.data[i] = ta->syntaxCopy();
	else
	{
	    Expression *ea = dynamic_cast<Expression *>((Object *)tiargs.data[i]);
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
    Dsymbol *s;
    Dsymbol *scopesym;
    Identifier *id;
    int i;

    if (inst)		// if semantic() was already run
	return;

#if LOG
    printf("TemplateInstance::semantic('%s', this=%p)\n", toChars(), this);
#endif

    // Run semantic on each argument
    for (int j = 0; j < tiargs.dim; j++)
    {   Type *ta = dynamic_cast<Type *>((Object *)tiargs.data[j]);
	Expression *ea;

	if (ta)
	{
	    // If TypeIdentifier, it might really be an Expression
	    if (ta->ty == Tident)
	    {
		((TypeIdentifier *)ta)->resolve(sc, &ea, &ta);
		if (ea)
		    tiargs.data[j] = ea;
		else
		    tiargs.data[j] = ta;
	    }
	    else
	    {
		ta = ta->semantic(loc, sc);
		tiargs.data[j] = ta;
	    }
	}
	else
	{
	    ea = dynamic_cast<Expression *>((Object *)tiargs.data[j]);
	    assert(ea);
	    ea = ea->semantic(sc);
	    ea = ea->constFold();
	    tiargs.data[j] = ea;
	}
    }

    /* Given:
     *    instance foo.bar.abc( ... )
     * figure out which TemplateDeclaration foo.bar.abc refers to.
     */
    id = (Identifier *)idents.data[0];
    s = sc->search(id, &scopesym);
    if (s)
    {
	s = s->toAlias();
	for (i = 1; i < idents.dim; i++)
	{   Dsymbol *sm;

	    id = (Identifier *)idents.data[i];
	    sm = s->search(id);
	    if (!sm)
	    {
		s = NULL;
		break;
	    }
	    s = sm->toAlias();
	}
    }
    if (!s)
    {	error("identifier '%s' is not defined", id->toChars());
	return;
    }

    /* It should be a TemplateDeclaration, not some other symbol
     */
    tempdecl = dynamic_cast<TemplateDeclaration *>(s);
    if (!tempdecl)
    {
	error("%s is not a template declaration", id->toChars());
	return;
    }

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

	if (m < m_best)
	    goto Ltd_best;
	if (m == m_best)
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
	else
	    goto Ltd;

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

    /* See if there is an existing TemplateInstantiation that already
     * implements the typeargs. If so, just refer to that one instead.
     */

    for (int i = 0; i < tempdecl->instances.dim; i++)
    {
	TemplateInstance *ti = (TemplateInstance *)tempdecl->instances.data[i];
	//printf("instance %d: '%s'\n", i, ti->toChars());

	assert(tiargs.dim == ti->tiargs.dim);

	for (int j = 0; j < tiargs.dim; j++)
	{   Type *t1 = dynamic_cast<Type *>((Object *)tiargs.data[j]);
	    Type *t2 = dynamic_cast<Type *>((Object *)ti->tiargs.data[j]);

	    if (t1)
	    {
		if (!t1->equals(t2))
		    goto L1;
	    }
	    else
	    {
		Expression *e1 = dynamic_cast<Expression *>((Object *)tiargs.data[j]);
		Expression *e2 = dynamic_cast<Expression *>((Object *)ti->tiargs.data[j]);

		assert(e1);
		if (!e1->equals(e2))
		    goto L1;
	    }
	}

	// It's a match
	inst = ti;
#if LOG
	printf("it's a match with %p\n", inst);
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
	{
	    Type *ta = dynamic_cast<Type *>((Object *)tiargs.data[i]);
	    if (ta)
	    {
		assert(ta->deco);
		buf.writestring(ta->deco);
	    }
	    else
	    {
		Expression *ea = dynamic_cast<Expression *>((Object *)tiargs.data[i]);
		assert(ea);
		buf.writeByte('_');
		buf.printf("%u", ea->toInteger());
	    }
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
    argsym->parent = scope->scopesym;
    scope = scope->push(argsym);

    // Declare each template parameter as an alias for the argument type
    for (int i = 0; i < tiargs.dim; i++)
    {
	TemplateParameter *tp = (TemplateParameter *)tempdecl->parameters->data[i];
	Type *targ = dynamic_cast<Type *>((Object *)tiargs.data[i]);
	Dsymbol *s;

	if (targ)
	{
	    AliasDeclaration *sarg;

	    sarg = new AliasDeclaration(0, tp->ident, targ);
	    s = sarg;
	}
	else
	{   Expression *ea = dynamic_cast<Expression *>((Object *)tiargs.data[i]);
	    assert(ea);

	    Initializer *init = new ExpInitializer(loc, ea);
	    VarDeclaration *v = new VarDeclaration(0, tp->valType, tp->ident, init);
	    v->storage_class = STCconst;
	    s = v;
	}
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
	//printf("\tadding member '%s' %p to '%s'\n", s->toChars(), s, this->toChars());
	s->addMember(this);
    }

    // Do semantic() analysis on template instance members
#if LOG
    printf("\tdo semantic() on template instance members '%s'\n", toChars());
#endif
    Scope *sc2;
    sc2 = scope->push(this);
    for (int i = 0; i < members->dim; i++)
    {
	Dsymbol *s = (Dsymbol *)members->data[i];
	s->semantic(sc2);
    }
    sc2->pop();

    scope->pop();
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

    buf->writestring("instance ");
    for (i = 0; i < idents.dim; i++)
    {	Identifier *id = (Identifier *)idents.data[i];

	if (i)
	    buf->writeByte('.');
	buf->writestring(id->toChars());
    }
    buf->writeByte('(');
    for (i = 0; i < tiargs.dim; i++)
    {
	if (i)
	    buf->writeByte(',');
	Type *t = dynamic_cast<Type *>((Object *)tiargs.data[i]);
	if (t)
	    t->toCBuffer(buf, NULL);
	else
	{   Expression *e = dynamic_cast<Expression *>((Object *)tiargs.data[i]);
	    assert(e);
	    e->toCBuffer(buf);
	}
    }
    buf->writeByte(')');
}


Dsymbol *TemplateInstance::toAlias()
{
    return inst;
}

char *TemplateInstance::kind()
{
    return "instance";
}

char *TemplateInstance::toChars()
{
    OutBuffer buf;
    char *s;

    toCBuffer(&buf);
    s = buf.toChars();
    buf.data = NULL;
    return s + 9;	// kludge to skip over 'instance '
}

