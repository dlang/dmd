
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

// Routines to perform function inlining

#define LOG 0

#include "init.h"

/* ========== Compute cost of inlining =============== */

/* Walk trees to determine if inlining can be done, and if so,
 * if it is too complex to be worth inlining or not.
 */

struct InlineCostState
{
    int nested;
};

const int COST_MAX = 250;

int Statement::inlineCost(InlineCostState *ics)
{
    return COST_MAX;		// default is we can't inline it
}

int ExpStatement::inlineCost(InlineCostState *ics)
{
    return exp ? exp->inlineCost(ics) : 0;
}

int CompoundStatement::inlineCost(InlineCostState *ics)
{   int cost = 0;

    for (int i = 0; i < statements->dim; i++)
    {	Statement *s;

	s = (Statement *) statements->data[i];
	if (s)
	{
	    cost += s->inlineCost(ics);
	    if (cost >= COST_MAX)
		break;
	}
    }
    return cost;
}

int IfStatement::inlineCost(InlineCostState *ics)
{
    int cost;

    cost = condition->inlineCost(ics);

    /* Specifically allow:
     *	if (condition)
     *	    return exp1;
     *	else
     *	    return exp2;
     * Otherwise, we can't handle return statements nested in if's.
     */

    if (elsebody &&
	dynamic_cast<ReturnStatement *>(ifbody) &&
	dynamic_cast<ReturnStatement *>(elsebody))
    {
	cost += ifbody->inlineCost(ics);
	cost += elsebody->inlineCost(ics);
printf("cost = %d\n", cost);
    }
    else
    {
	ics->nested += 1;
	cost += ifbody->inlineCost(ics);
	if (elsebody)
	    cost += elsebody->inlineCost(ics);
	ics->nested -= 1;
    }
    return cost;
}

int ReturnStatement::inlineCost(InlineCostState *ics)
{
    // Can't handle return statements nested in if's
    if (ics->nested)
	return COST_MAX;
    return exp ? exp->inlineCost(ics) : 0;
}

/* -------------------------- */

int Expression::inlineCost(InlineCostState *ics)
{
    return 1;
}

int DeclarationExp::inlineCost(InlineCostState *ics)
{   int cost = 0;
    VarDeclaration *vd;

    vd = dynamic_cast<VarDeclaration *>(declaration);
    if (vd)
    {
	if (vd->isStatic())
	    return COST_MAX;
	cost += 1;		// should scan initializer (vd->init)
    }
    return cost;
}

int UnaExp::inlineCost(InlineCostState *ics)
{
    return 1 + e1->inlineCost(ics);
}

int BinExp::inlineCost(InlineCostState *ics)
{
    return 1 + e1->inlineCost(ics) + e2->inlineCost(ics);
}

int CallExp::inlineCost(InlineCostState *ics)
{   int cost;

    cost = 1 + e1->inlineCost(ics);
    if (arguments)
    {
	for (int i = 0; i < arguments->dim; i++)
	{
	    Expression *e = (Expression *)arguments->data[i];

	    cost += e->inlineCost(ics);
	}
    }
    return cost;
}


int ArrayRangeExp::inlineCost(InlineCostState *ics)
{   int cost;

    cost = 1 + e1->inlineCost(ics);
    if (lwr)
	cost += lwr->inlineCost(ics);
    if (upr)
	cost += upr->inlineCost(ics);
    return cost;
}


int CondExp::inlineCost(InlineCostState *ics)
{
    return 1 +
	 e1->inlineCost(ics) +
	 e2->inlineCost(ics) +
	 econd->inlineCost(ics);
}


/* ======================== Perform the inlining ============================== */

/* Inlining is done by:
 * o	Converting to an Expression
 * o	Copying the trees of the function to be inlined
 * o	Renaming the variables
 */

struct InlineDoState
{
    VarDeclaration *vthis;
    Array from;		// old Dsymbols
    Array to;		// parallel array of new Dsymbols
};

Expression *Statement::doInline(InlineDoState *ids)
{
    assert(0);
    return NULL;		// default is we can't inline it
}

Expression *ExpStatement::doInline(InlineDoState *ids)
{
    return exp ? exp->doInline(ids) : NULL;
}

Expression *CompoundStatement::doInline(InlineDoState *ids)
{
    Expression *e = NULL;

    for (int i = 0; i < statements->dim; i++)
    {	Statement *s;
	Expression *e2;

	s = (Statement *) statements->data[i];
	if (s)
	{
	    e2 = s->doInline(ids);
	    e = Expression::combine(e, e2);
	    if (dynamic_cast<ReturnStatement *>(s))
		break;
	}
    }
    return e;
}

Expression *IfStatement::doInline(InlineDoState *ids)
{
    Expression *econd;
    Expression *e1;
    Expression *e2;
    Expression *e;

    econd = condition->doInline(ids);
    assert(econd);
    e1 = ifbody->doInline(ids);
    if (elsebody)
	e2 = elsebody->doInline(ids);
    else
	e2 = NULL;
    if (e1 && e2)
    {
	e = new CondExp(econd->loc, econd, e1, e2);
	e->type = e1->type;
    }
    else if (e1)
    {
	e = new AndAndExp(econd->loc, econd, e1);
	e->type = Type::tvoid;
    }
    else
    {
	e = new OrOrExp(econd->loc, econd, e1);
	e->type = Type::tvoid;
    }
    return e;
}

Expression *ReturnStatement::doInline(InlineDoState *ids)
{
    return exp ? exp->doInline(ids) : 0;
}

/* -------------------------- */

Expression *Expression::doInline(InlineDoState *ids)
{
    return copy();
}

Expression *VarExp::doInline(InlineDoState *ids)
{
    int i;

    for (i = 0; i < ids->from.dim; i++)
    {
	if (var == (Declaration *)ids->from.data[i])
	{
	    VarExp *ve = (VarExp *)copy();

	    ve->var = (Declaration *)ids->to.data[i];
	    return ve;
	}
    }
    return this;
}

Expression *ThisExp::doInline(InlineDoState *ids)
{
    assert(ids->vthis);

    VarExp *ve = new VarExp(loc, ids->vthis);
    ve->type = type;
    return ve;
}

Expression *SuperExp::doInline(InlineDoState *ids)
{
    assert(ids->vthis);

    VarExp *ve = new VarExp(loc, ids->vthis);
    ve->type = type;
    return ve;
}

Expression *DeclarationExp::doInline(InlineDoState *ids)
{   DeclarationExp *de = (DeclarationExp *)copy();
    VarDeclaration *vd;

    vd = dynamic_cast<VarDeclaration *>(declaration);
    if (vd)
    {
	if (vd->isStatic() || vd->isConst())
	    ;
	else
	{
	    ExpInitializer *ie;
	    ExpInitializer *ieto;
	    VarDeclaration *vto;

	    vto = new VarDeclaration(vd->loc, vd->type, vd->ident, vd->init);
	    *vto = *vd;
	    vto->csym = NULL;
	    vto->isym = NULL;

	    ids->from.push(vd);
	    ids->to.push(vto);

	    ie = dynamic_cast<ExpInitializer *>(vd->init);
	    assert(ie);
	    ieto = new ExpInitializer(ie->loc, ie->exp->doInline(ids));
	    vto->init = ieto;

	    de->declaration = (void *)vto;
	}
    }
    return de;
}

Expression *UnaExp::doInline(InlineDoState *ids)
{
    UnaExp *ue = (UnaExp *)copy();

    ue->e1 = e1->doInline(ids);
    return ue;
}

Expression *BinExp::doInline(InlineDoState *ids)
{
    BinExp *be = (BinExp *)copy();

    be->e1 = e1->doInline(ids);
    be->e2 = e2->doInline(ids);
    return be;
}

Expression *CallExp::doInline(InlineDoState *ids)
{
    CallExp *ce;

    ce = (CallExp *)copy();
    ce->e1 = e1->doInline(ids);
    if (arguments)
    {
	ce->arguments = new Array();
	ce->arguments->setDim(arguments->dim);

	for (int i = 0; i < arguments->dim; i++)
	{
	    Expression *e = (Expression *)arguments->data[i];

	    e = e->doInline(ids);
	    ce->arguments->data[i] = (void *)e;
	}
    }
    return ce;
}


Expression *ArrayRangeExp::doInline(InlineDoState *ids)
{
    ArrayRangeExp *are = (ArrayRangeExp *)copy();

    are->e1 = e1->doInline(ids);
    if (lwr)
	are->lwr = lwr->doInline(ids);
    if (upr)
	are->upr = upr->doInline(ids);
    return are;
}


Expression *CondExp::doInline(InlineDoState *ids)
{
    CondExp *ce = (CondExp *)copy();

    ce->econd = econd->doInline(ids);
    ce->e1 = e1->doInline(ids);
    ce->e2 = e2->doInline(ids);
    return ce;
}


/* ========== Walk the parse trees, and inline expand functions =============== */

/* Walk the trees, looking for functions to inline.
 * Inline any that can be.
 */

struct InlineScanState
{
    FuncDeclaration *fd;	// function being scanned
};

Statement *Statement::inlineScan(InlineScanState *iss)
{
    return this;
}

Statement *ExpStatement::inlineScan(InlineScanState *iss)
{
    if (exp)
	exp = exp->inlineScan(iss);
    return this;
}

Statement *CompoundStatement::inlineScan(InlineScanState *iss)
{
    for (int i = 0; i < statements->dim; i++)
    {	Statement *s;

	s = (Statement *) statements->data[i];
	if (s)
	    statements->data[i] = (void *)s->inlineScan(iss);
    }
    return this;
}

Statement *WhileStatement::inlineScan(InlineScanState *iss)
{
    condition = condition->inlineScan(iss);
    body = body->inlineScan(iss);
    return this;
}


Statement *DoStatement::inlineScan(InlineScanState *iss)
{
    body = body->inlineScan(iss);
    condition = condition->inlineScan(iss);
    return this;
}


Statement *ForStatement::inlineScan(InlineScanState *iss)
{
    if (init)
	init = init->inlineScan(iss);
    if (condition)
	condition = condition->inlineScan(iss);
    if (increment)
	increment = increment->inlineScan(iss);
    body = body->inlineScan(iss);
    return this;
}


Statement *IfStatement::inlineScan(InlineScanState *iss)
{
    condition = condition->inlineScan(iss);
    ifbody = ifbody->inlineScan(iss);
    if (elsebody)
	elsebody = elsebody->inlineScan(iss);
    return this;
}


Statement *SwitchStatement::inlineScan(InlineScanState *iss)
{
    condition = condition->inlineScan(iss);
    body = body->inlineScan(iss);
    if (sdefault)
	sdefault = (DefaultStatement *)sdefault->inlineScan(iss);
    if (cases)
    {
	for (int i = 0; i < cases->dim; i++)
	{   Statement *s;

	    s = (Statement *) cases->data[i];
	    cases->data[i] = (void *)s->inlineScan(iss);
	}
    }
    return this;
}


Statement *CaseStatement::inlineScan(InlineScanState *iss)
{
    exp = exp->inlineScan(iss);
    if (statement)
	statement = statement->inlineScan(iss);
    return this;
}


Statement *DefaultStatement::inlineScan(InlineScanState *iss)
{
    if (statement)
	statement = statement->inlineScan(iss);
    return this;
}


Statement *ReturnStatement::inlineScan(InlineScanState *iss)
{
    if (exp)
	exp = exp->inlineScan(iss);
    return this;
}


Statement *SynchronizedStatement::inlineScan(InlineScanState *iss)
{
    if (exp)
	exp = exp->inlineScan(iss);
    if (body)
	body = body->inlineScan(iss);
    return this;
}


Statement *WithStatement::inlineScan(InlineScanState *iss)
{
    if (exp)
	exp = exp->inlineScan(iss);
    if (body)
	body = body->inlineScan(iss);
    return this;
}


Statement *TryCatchStatement::inlineScan(InlineScanState *iss)
{
    if (body)
	body = body->inlineScan(iss);
    if (catches)
    {
	for (int i = 0; i < catches->dim; i++)
	{   Catch *c = (Catch *)catches->data[i];

	    c->handler = c->handler->inlineScan(iss);
	}
    }
    return this;
}


Statement *TryFinallyStatement::inlineScan(InlineScanState *iss)
{
    if (body)
	body = body->inlineScan(iss);
    if (finalbody)
	finalbody = finalbody->inlineScan(iss);
    return this;
}


Statement *ThrowStatement::inlineScan(InlineScanState *iss)
{
    if (exp)
	exp = exp->inlineScan(iss);
    return this;
}


Statement *VolatileStatement::inlineScan(InlineScanState *iss)
{
    if (statement)
	statement = statement->inlineScan(iss);
    return this;
}


Statement *LabelStatement::inlineScan(InlineScanState *iss)
{
    if (statement)
	statement = statement->inlineScan(iss);
    return this;
}

/* -------------------------- */

Expression *Expression::inlineScan(InlineScanState *iss)
{
    return this;
}

Expression *DeclarationExp::inlineScan(InlineScanState *iss)
{
    // Should scan variable initializers
    return this;
}

Expression *UnaExp::inlineScan(InlineScanState *iss)
{
    e1 = e1->inlineScan(iss);
    return this;
}

Expression *BinExp::inlineScan(InlineScanState *iss)
{
    e1 = e1->inlineScan(iss);
    e2 = e2->inlineScan(iss);
    return this;
}


Expression *CallExp::inlineScan(InlineScanState *iss)
{   Expression *e = this;

    //printf("CallExp::inlineScan()\n");
    e1 = e1->inlineScan(iss);
    if (arguments)
    {
	for (int i = 0; i < arguments->dim; i++)
	{
	    Expression *e = (Expression *)arguments->data[i];

	    e = e->inlineScan(iss);
	    arguments->data[i] = (void *)e;
	}
    }

    if (e1->op == TOKvar)
    {
	VarExp *ve = (VarExp *)e1;
	FuncDeclaration *fd = dynamic_cast<FuncDeclaration *>(ve->var);

	if (fd && fd != iss->fd && fd->canInline())
	{
	    e = fd->doInline(NULL, arguments);
	}
    }
    else if (e1->op == TOKdotvar)
    {
	DotVarExp *dve = (DotVarExp *)e1;
	FuncDeclaration *fd = dynamic_cast<FuncDeclaration *>(dve->var);

	if (fd && fd != iss->fd && fd->canInline())
	{
	    e = fd->doInline(dve->e1, arguments);
	}
    }

    return e;
}


Expression *ArrayRangeExp::inlineScan(InlineScanState *iss)
{
    e1 = e1->inlineScan(iss);
    if (lwr)
	lwr = lwr->inlineScan(iss);
    if (upr)
	upr = upr->inlineScan(iss);
    return this;
}


Expression *CondExp::inlineScan(InlineScanState *iss)
{
    econd = econd->inlineScan(iss);
    e1 = e1->inlineScan(iss);
    e2 = e2->inlineScan(iss);
    return this;
}


/* ==========  =============== */

void FuncDeclaration::inlineScan()
{
    InlineScanState iss;

    memset(&iss, 0, sizeof(iss));
    iss.fd = this;
    if (fbody)
    {
	inlineNest++;
	fbody = fbody->inlineScan(&iss);
	inlineNest--;
    }
}

int FuncDeclaration::canInline()
{
    InlineCostState ics;
    int cost;

#if LOG
    printf("FuncDeclaration::canInline('%s')\n", toChars());
#endif

    if (inlineNest || !semanticRun)
	return 0;

    switch (inlineStatus)
    {
	case ILSyes:
	    return 1;

	case ILSno:
	    return 0;

	case ILSuninitialized:
	    break;

	default:
	    assert(0);
    }

    TypeFunction *tf = dynamic_cast<TypeFunction *>(type);
    assert(tf);

    if (
#if 0
	isConstructor() ||	// cannot because need to convert:
				//	return;
				// to:
				//	return this;
#endif
	isSynchronized() ||
	isImport() ||
	!fbody ||
	tf->varargs ||		// no variadic parameter lists
	(isVirtual() && !isFinal())
       )
	goto Lno;
    memset(&ics, 0, sizeof(ics));
    cost = fbody->inlineCost(&ics);
    //printf("cost = %d\n", cost);
    if (cost >= COST_MAX)
	goto Lno;

    inlineScan();

Lyes:
    inlineStatus = ILSyes;
#if LOG
    printf("\tyes\n");
#endif
    return 1;

Lno:
    inlineStatus = ILSno;
#if LOG
    printf("\tno\n");
#endif
    return 0;
}

Expression *FuncDeclaration::doInline(Expression *ethis, Array *arguments)
{
    InlineDoState ids;
    DeclarationExp *de;
    Expression *e = NULL;

#if LOG
    printf("FuncDeclaration::doInline('%s')\n", toChars());
#endif

    memset(&ids, 0, sizeof(ids));

    // Set up vthis
    if (ethis)
    {
	VarDeclaration *vthis;
	ExpInitializer *ei;
	VarExp *ve;

	if (ethis->type->ty != Tclass && ethis->type->ty != Tpointer)
	{
	    ethis = ethis->addressOf();
	}

	ei = new ExpInitializer(ethis->loc, ethis);

	vthis = new VarDeclaration(ethis->loc, ethis->type, Id::This, ei);
	vthis->storage_class = STCin;
	vthis->linkage = LINKd;

	ve = new VarExp(vthis->loc, vthis);
	ve->type = vthis->type;

	ei->exp = new AssignExp(vthis->loc, ve, ethis);
	ei->exp->type = ve->type;

	ids.vthis = vthis;
    }

    // Set up parameters
    if (ethis)
    {
	e = new DeclarationExp(0, ids.vthis);
	e->type = Type::tvoid;
    }

    if (arguments && arguments->dim)
    {
	assert(parameters->dim == arguments->dim);

	for (int i = 0; i < arguments->dim; i++)
	{
	    VarDeclaration *vfrom = (VarDeclaration *)parameters->data[i];
	    VarDeclaration *vto;
	    Expression *arg = (Expression *)arguments->data[i];
	    ExpInitializer *ei;
	    VarExp *ve;

	    ei = new ExpInitializer(arg->loc, arg);

	    vto = new VarDeclaration(vfrom->loc, vfrom->type, vfrom->ident, ei);
	    vto->storage_class |= vfrom->storage_class & (STCin | STCout);
	    vto->linkage = vfrom->linkage;

	    ve = new VarExp(vto->loc, vto);
	    ve->type = vto->type;

	    ei->exp = new AssignExp(vto->loc, ve, arg);
	    ei->exp->type = ve->type;

	    ids.from.push(vfrom);
	    ids.to.push(vto);

	    de = new DeclarationExp(0, vto);
	    de->type = Type::tvoid;

	    e = Expression::combine(e, de);
	}
    }

    inlineNest++;
    Expression *eb = fbody->doInline(&ids);
    inlineNest--;
    return Expression::combine(e, eb);
}



