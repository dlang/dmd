
// Compiler implementation of the D programming language
// Copyright (c) 1999-2007 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <assert.h>

#include "init.h"
#include "declaration.h"
#include "attrib.h"
#include "mtype.h"
#include "template.h"
#include "scope.h"
#include "aggregate.h"
#include "module.h"
#include "id.h"
#include "expression.h"
#include "hdrgen.h"

/********************************* Declaration ****************************/

Declaration::Declaration(Identifier *id)
    : Dsymbol(id)
{
    type = NULL;
    originalType = NULL;
    storage_class = STCundefined;
    protection = PROTundefined;
    linkage = LINKdefault;
}

void Declaration::semantic(Scope *sc)
{
}

char *Declaration::kind()
{
    return "declaration";
}

unsigned Declaration::size(Loc loc)
{
    assert(type);
    return type->size();
}

int Declaration::isStaticConstructor()
{
    return FALSE;
}

int Declaration::isStaticDestructor()
{
    return FALSE;
}

int Declaration::isDelete()
{
    return FALSE;
}

int Declaration::isDataseg()
{
    return FALSE;
}

int Declaration::isCodeseg()
{
    return FALSE;
}

enum PROT Declaration::prot()
{
    return protection;
}

/********************************* TupleDeclaration ****************************/

TupleDeclaration::TupleDeclaration(Loc loc, Identifier *id, Objects *objects)
    : Declaration(id)
{
    this->type = NULL;
    this->objects = objects;
    this->isexp = 0;
    this->tupletype = NULL;
}

Dsymbol *TupleDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(0);
    return NULL;
}

char *TupleDeclaration::kind()
{
    return "tuple";
}

Type *TupleDeclaration::getType()
{
    /* If this tuple represents a type, return that type
     */

    //printf("TupleDeclaration::getType() %s\n", toChars());
    if (isexp)
	return NULL;
    if (!tupletype)
    {
	/* It's only a type tuple if all the Object's are types
	 */
	for (size_t i = 0; i < objects->dim; i++)
	{   Object *o = (Object *)objects->data[i];

	    if (o->dyncast() != DYNCAST_TYPE)
	    {
		//printf("\tnot[%d], %p, %d\n", i, o, o->dyncast());
		return NULL;
	    }
	}

	/* We know it's a type tuple, so build the TypeTuple
	 */
	Arguments *args = new Arguments();
	args->setDim(objects->dim);
	OutBuffer buf;
	for (size_t i = 0; i < objects->dim; i++)
	{   Type *t = (Type *)objects->data[i];

	    //printf("type = %s\n", t->toChars());
#if 0
	    buf.printf("_%s_%d", ident->toChars(), i);
	    char *name = (char *)buf.extractData();
	    Identifier *id = new Identifier(name, TOKidentifier);
	    Argument *arg = new Argument(STCin, t, id, NULL);
#else
	    Argument *arg = new Argument(STCin, t, NULL, NULL);
#endif
	    args->data[i] = (void *)arg;
	}

	tupletype = new TypeTuple(args);
    }

    return tupletype;
}

int TupleDeclaration::needThis()
{
    //printf("TupleDeclaration::needThis(%s)\n", toChars());
    for (size_t i = 0; i < objects->dim; i++)
    {   Object *o = (Object *)objects->data[i];
	if (o->dyncast() == DYNCAST_EXPRESSION)
	{   Expression *e = (Expression *)o;
	    if (e->op == TOKdsymbol)
	    {	DsymbolExp *ve = (DsymbolExp *)e;
		Declaration *d = ve->s->isDeclaration();
		if (d && d->needThis())
		{
		    return 1;
		}
	    }
	}
    }
    return 0;
}

/********************************* TypedefDeclaration ****************************/

TypedefDeclaration::TypedefDeclaration(Loc loc, Identifier *id, Type *basetype, Initializer *init)
    : Declaration(id)
{
    this->type = new TypeTypedef(this);
    this->basetype = basetype->toBasetype();
    this->init = init;
#ifdef _DH
    this->htype = NULL;
    this->hbasetype = NULL;
#endif
    this->sem = 0;
    this->inuse = 0;
    this->loc = loc;
    this->sinit = NULL;
}

Dsymbol *TypedefDeclaration::syntaxCopy(Dsymbol *s)
{
    Type *basetype = this->basetype->syntaxCopy();

    Initializer *init = NULL;
    if (this->init)
	init = this->init->syntaxCopy();

    assert(!s);
    TypedefDeclaration *st;
    st = new TypedefDeclaration(loc, ident, basetype, init);
#ifdef _DH
    // Syntax copy for header file
    if (!htype)      // Don't overwrite original
    {	if (type)    // Make copy for both old and new instances
	{   htype = type->syntaxCopy();
	    st->htype = type->syntaxCopy();
	}
    }
    else            // Make copy of original for new instance
        st->htype = htype->syntaxCopy();
    if (!hbasetype)
    {	if (basetype)
	{   hbasetype = basetype->syntaxCopy();
	    st->hbasetype = basetype->syntaxCopy();
	}
    }
    else
        st->hbasetype = hbasetype->syntaxCopy();
#endif
    return st;
}

void TypedefDeclaration::semantic(Scope *sc)
{
    //printf("TypedefDeclaration::semantic(%s) sem = %d\n", toChars(), sem);
    if (sem == 0)
    {	sem = 1;
	basetype = basetype->semantic(loc, sc);
	sem = 2;
	type = type->semantic(loc, sc);
	if (sc->parent->isFuncDeclaration() && init)
	    semantic2(sc);
    }
    else if (sem == 1)
    {
	error("circular definition");
    }
}

void TypedefDeclaration::semantic2(Scope *sc)
{
    //printf("TypedefDeclaration::semantic2(%s) sem = %d\n", toChars(), sem);
    if (sem == 2)
    {	sem = 3;
	if (init)
	{
	    init = init->semantic(sc, basetype);

	    ExpInitializer *ie = init->isExpInitializer();
	    if (ie)
	    {
		if (ie->exp->type == basetype)
		    ie->exp->type = type;
	    }
	}
    }
}

char *TypedefDeclaration::kind()
{
    return "typedef";
}

Type *TypedefDeclaration::getType()
{
    return type;
}

void TypedefDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("typedef ");
    basetype->toCBuffer(buf, ident, hgs);
    if (init)
    {
	buf->writestring(" = ");
	init->toCBuffer(buf, hgs);
    }
    buf->writeByte(';');
    buf->writenl();
}

/********************************* AliasDeclaration ****************************/

AliasDeclaration::AliasDeclaration(Loc loc, Identifier *id, Type *type)
    : Declaration(id)
{
    //printf("AliasDeclaration(id = '%s', type = %p)\n", id->toChars(), type);
    //printf("type = '%s'\n", type->toChars());
    this->loc = loc;
    this->type = type;
    this->aliassym = NULL;
#ifdef _DH
    this->htype = NULL;
    this->haliassym = NULL;
#endif
    this->overnext = NULL;
    this->inSemantic = 0;
    assert(type);
}

AliasDeclaration::AliasDeclaration(Loc loc, Identifier *id, Dsymbol *s)
    : Declaration(id)
{
    //printf("AliasDeclaration(id = '%s', s = %p)\n", id->toChars(), s);
    assert(s != this);
    this->loc = loc;
    this->type = NULL;
    this->aliassym = s;
#ifdef _DH
    this->htype = NULL;
    this->haliassym = NULL;
#endif
    this->overnext = NULL;
    this->inSemantic = 0;
    assert(s);
}

Dsymbol *AliasDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    AliasDeclaration *sa;
    if (type)
	sa = new AliasDeclaration(loc, ident, type->syntaxCopy());
    else
	sa = new AliasDeclaration(loc, ident, aliassym->syntaxCopy(NULL));
#ifdef _DH
    // Syntax copy for header file
    if (!htype)	    // Don't overwrite original
    {	if (type)	// Make copy for both old and new instances
	{   htype = type->syntaxCopy();
	    sa->htype = type->syntaxCopy();
	}
    }
    else			// Make copy of original for new instance
	sa->htype = htype->syntaxCopy();
    if (!haliassym)
    {	if (aliassym)
	{   haliassym = aliassym->syntaxCopy(s);
	    sa->haliassym = aliassym->syntaxCopy(s);
	}
    }
    else
	sa->haliassym = haliassym->syntaxCopy(s);
#endif
    return sa;
}

void AliasDeclaration::semantic(Scope *sc)
{
    //printf("AliasDeclaration::semantic() %s\n", toChars());
    if (aliassym)
    {
	if (aliassym->isTemplateInstance())
	    aliassym->semantic(sc);
	return;
    }
    this->inSemantic = 1;

    if (storage_class & STCconst)
	error("cannot be const");

    storage_class |= sc->stc & STCdeprecated;

    // Given:
    //	alias foo.bar.abc def;
    // it is not knowable from the syntax whether this is an alias
    // for a type or an alias for a symbol. It is up to the semantic()
    // pass to distinguish.
    // If it is a type, then type is set and getType() will return that
    // type. If it is a symbol, then aliassym is set and type is NULL -
    // toAlias() will return aliasssym.

    Dsymbol *s;
    Type *t;
    Expression *e;

    /* This section is needed because resolve() will:
     *   const x = 3;
     *   alias x y;
     * try to alias y to 3.
     */
    s = type->toDsymbol(sc);
    if (s)
	goto L2;			// it's a symbolic alias

    //printf("alias type is %s\n", type->toChars());
    type->resolve(loc, sc, &e, &t, &s);
    if (s)
    {
	goto L2;
    }
    else if (e)
    {
	// Try to convert Expression to Dsymbol
        if (e->op == TOKvar)
	{   s = ((VarExp *)e)->var;
	    goto L2;
	}
        else if (e->op == TOKfunction)
	{   s = ((FuncExp *)e)->fd;
	    goto L2;
	}
        else
	{   error("cannot alias an expression %s", e->toChars());
	    t = e->type;
	}
    }
    else if (t)
	type = t;
    if (overnext)
	ScopeDsymbol::multiplyDefined(0, this, overnext);
    this->inSemantic = 0;
    return;

  L2:
    //printf("alias is a symbol %s %s\n", s->kind(), s->toChars());
    type = NULL;
    VarDeclaration *v = s->isVarDeclaration();
    if (v && v->linkage == LINKdefault)
    {
	error("forward reference of %s", v->toChars());
	s = NULL;
    }
    else
    {
	FuncDeclaration *f = s->toAlias()->isFuncDeclaration();
	if (f)
	{
	    if (overnext)
	    {
		FuncAliasDeclaration *fa = new FuncAliasDeclaration(f);
		if (!fa->overloadInsert(overnext))
		    ScopeDsymbol::multiplyDefined(0, f, overnext);
		overnext = NULL;
		s = fa;
		s->parent = sc->parent;
	    }
	}
	if (overnext)
	    ScopeDsymbol::multiplyDefined(0, s, overnext);
	if (s == this)
	{
	    assert(global.errors);
	    s = NULL;
	}
    }
    aliassym = s;
    this->inSemantic = 0;
}

int AliasDeclaration::overloadInsert(Dsymbol *s)
{
    /* Don't know yet what the aliased symbol is, so assume it can
     * be overloaded and check later for correctness.
     */

    //printf("AliasDeclaration::overloadInsert('%s')\n", s->toChars());
    if (overnext == NULL)
    {	overnext = s;
	return TRUE;
    }
    else
    {
	return overnext->overloadInsert(s);
    }
}

char *AliasDeclaration::kind()
{
    return "alias";
}

Type *AliasDeclaration::getType()
{
    return type;
}

Dsymbol *AliasDeclaration::toAlias()
{
    //printf("AliasDeclaration::toAlias('%s', this = %p, aliassym = %p, kind = '%s')\n", toChars(), this, aliassym, aliassym ? aliassym->kind() : "");
    assert(this != aliassym);
    //static int count; if (++count == 10) *(char*)0=0;
    if (inSemantic)
    {	error("recursive alias declaration");
//	return this;
    }
    Dsymbol *s = aliassym ? aliassym->toAlias() : this;
    return s;
}

void AliasDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("alias ");
#if 0 && _DH
    if (hgs->hdrgen)
    {
	if (haliassym)
	{
	    haliassym->toCBuffer(buf, hgs);
	    buf->writeByte(' ');
	    buf->writestring(ident->toChars());
	}
	else
	    htype->toCBuffer(buf, ident, hgs);
    }
    else
#endif
    {
	if (aliassym)
	{
	    aliassym->toCBuffer(buf, hgs);
	    buf->writeByte(' ');
	    buf->writestring(ident->toChars());
	}
	else
	    type->toCBuffer(buf, ident, hgs);
    }
    buf->writeByte(';');
    buf->writenl();
}

/********************************* VarDeclaration ****************************/

VarDeclaration::VarDeclaration(Loc loc, Type *type, Identifier *id, Initializer *init)
    : Declaration(id)
{
    //printf("VarDeclaration('%s')\n", id->toChars());
#ifdef DEBUG
    if (!type && !init)
    {	printf("VarDeclaration('%s')\n", id->toChars());
	//*(char*)0=0;
    }
#endif
    assert(type || init);
    this->type = type;
    this->init = init;
#ifdef _DH
    this->htype = NULL;
    this->hinit = NULL;
#endif
    this->loc = loc;
    offset = 0;
    noauto = 0;
    nestedref = 0;
    inuse = 0;
    ctorinit = 0;
    aliassym = NULL;
    onstack = 0;
    canassign = 0;
    value = NULL;
}

Dsymbol *VarDeclaration::syntaxCopy(Dsymbol *s)
{
    //printf("VarDeclaration::syntaxCopy(%s)\n", toChars());

    VarDeclaration *sv;
    if (s)
    {	sv = (VarDeclaration *)s;
    }
    else
    {
	Initializer *init = NULL;
	if (this->init)
	{   init = this->init->syntaxCopy();
	    //init->isExpInitializer()->exp->print();
	    //init->isExpInitializer()->exp->dump(0);
	}

	sv = new VarDeclaration(loc, type ? type->syntaxCopy() : NULL, ident, init);
	sv->storage_class = storage_class;
    }
#ifdef _DH
    // Syntax copy for header file
    if (!htype)      // Don't overwrite original
    {	if (type)    // Make copy for both old and new instances
	{   htype = type->syntaxCopy();
	    sv->htype = type->syntaxCopy();
	}
    }
    else            // Make copy of original for new instance
        sv->htype = htype->syntaxCopy();
    if (!hinit)
    {	if (init)
	{   hinit = init->syntaxCopy();
	    sv->hinit = init->syntaxCopy();
	}
    }
    else
        sv->hinit = hinit->syntaxCopy();
#endif
    return sv;
}

void VarDeclaration::semantic(Scope *sc)
{
    //printf("VarDeclaration::semantic('%s', parent = '%s')\n", toChars(), sc->parent->toChars());
    //printf("type = %s\n", type->toChars());
    //printf("linkage = %d\n", sc->linkage);
    //if (strcmp(toChars(), "mul") == 0) halt();

    storage_class |= sc->stc;
    if (storage_class & STCextern && init)
	error("extern symbols cannot have initializers");

    /* If auto type inference, do the inference
     */
    int inferred = 0;
    if (!type)
    {	inuse++;
	type = init->inferType(sc);
	inuse--;
	inferred = 1;

	/* This is a kludge to support the existing syntax for RAII
	 * declarations.
	 */
	storage_class &= ~STCauto;
	originalType = type;
    }
    else
    {	if (!originalType)
	    originalType = type;
	type = type->semantic(loc, sc);
    }

    type->checkDeprecated(loc, sc);
    linkage = sc->linkage;
    this->parent = sc->parent;
    //printf("this = %p, parent = %p, '%s'\n", this, parent, parent->toChars());
    protection = sc->protection;
    //printf("sc->stc = %x\n", sc->stc);
    //printf("storage_class = %x\n", storage_class);

    Dsymbol *parent = toParent();
    FuncDeclaration *fd = parent->isFuncDeclaration();

    Type *tb = type->toBasetype();
    if (tb->ty == Tvoid && !(storage_class & STClazy))
    {	error("voids have no value");
	type = Type::terror;
	tb = type;
    }
    if (tb->ty == Tfunction)
    {	error("cannot be declared to be a function");
	type = Type::terror;
	tb = type;
    }
    if (tb->ty == Tstruct)
    {	TypeStruct *ts = (TypeStruct *)tb;

	if (!ts->sym->members)
	{
	    error("no definition of struct %s", ts->toChars());
	}
    }

    if (tb->ty == Ttuple)
    {   /* Instead, declare variables for each of the tuple elements
	 * and add those.
	 */
	TypeTuple *tt = (TypeTuple *)tb;
	size_t nelems = Argument::dim(tt->arguments);
	Objects *exps = new Objects();
	exps->setDim(nelems);
	Expression *ie = init ? init->toExpression() : NULL;

	for (size_t i = 0; i < nelems; i++)
	{   Argument *arg = Argument::getNth(tt->arguments, i);

	    OutBuffer buf;
	    buf.printf("_%s_field_%zu", ident->toChars(), i);
	    buf.writeByte(0);
	    char *name = (char *)buf.extractData();
	    Identifier *id = new Identifier(name, TOKidentifier);

	    Expression *einit = ie;
	    if (ie && ie->op == TOKtuple)
	    {	einit = (Expression *)((TupleExp *)ie)->exps->data[i];
	    }
	    Initializer *ti = init;
	    if (einit)
	    {	ti = new ExpInitializer(einit->loc, einit);
	    }

	    VarDeclaration *v = new VarDeclaration(loc, arg->type, id, ti);
	    //printf("declaring field %s of type %s\n", v->toChars(), v->type->toChars());
	    v->semantic(sc);

	    if (sc->scopesym)
	    {	//printf("adding %s to %s\n", v->toChars(), sc->scopesym->toChars());
		if (sc->scopesym->members)
		    sc->scopesym->members->push(v);
	    }

	    Expression *e = new DsymbolExp(loc, v);
	    exps->data[i] = e;
	}
	TupleDeclaration *v2 = new TupleDeclaration(loc, ident, exps);
	v2->isexp = 1;
	aliassym = v2;
	return;
    }

    if (storage_class & STCconst && !init && !fd)
	// Initialize by constructor only
	storage_class = (storage_class & ~STCconst) | STCctorinit;

    if (isConst())
    {
    }
    else if (isStatic())
    {
    }
    else if (isSynchronized())
    {
	error("variable %s cannot be synchronized", toChars());
    }
    else if (isOverride())
    {
	error("override cannot be applied to variable");
    }
    else if (isAbstract())
    {
	error("abstract cannot be applied to variable");
    }
    else if (storage_class & STCtemplateparameter)
    {
    }
    else
    {
	AggregateDeclaration *aad = sc->anonAgg;
	if (!aad)
	    aad = parent->isAggregateDeclaration();
	if (aad)
	{
	    aad->addField(sc, this);
	}

	InterfaceDeclaration *id = parent->isInterfaceDeclaration();
	if (id)
	{
	    error("field not allowed in interface");
	}

	TemplateInstance *ti = parent->isTemplateInstance();
	if (ti)
	{
	    // Take care of nested templates
	    while (1)
	    {
		TemplateInstance *ti2 = ti->tempdecl->parent->isTemplateInstance();
		if (!ti2)
		    break;
		ti = ti2;
	    }

	    // If it's a member template
	    AggregateDeclaration *ad = ti->tempdecl->isMember();
	    if (ad && storage_class != STCundefined)
	    {
		error("cannot use template to add field to aggregate '%s'", ad->toChars());
	    }
	}
    }

    if (type->isauto() && !noauto)
    {
	if (storage_class & (STCfield | STCout | STCref | STCstatic) || !fd)
	{
	    error("globals, statics, fields, ref and out parameters cannot be auto");
	}

	if (!(storage_class & (STCauto | STCscope)))
	{
	    if (!(storage_class & STCparameter) && ident != Id::withSym)
		error("reference to scope class must be scope");
	}
    }

    if (!init && !sc->inunion && !isStatic() && !isConst() && fd &&
	!(storage_class & (STCfield | STCin | STCforeach)) &&
	type->size() != 0)
    {
	// Provide a default initializer
	//printf("Providing default initializer for '%s'\n", toChars());
	if (type->ty == Tstruct &&
	    ((TypeStruct *)type)->sym->zeroInit == 1)
	{   /* If a struct is all zeros, as a special case
	     * set it's initializer to the integer 0.
	     * In AssignExp::toElem(), we check for this and issue
	     * a memset() to initialize the struct.
	     * Must do same check in interpreter.
	     */
	    Expression *e = new IntegerExp(loc, 0, Type::tint32);
	    Expression *e1;
	    e1 = new VarExp(loc, this);
	    e = new AssignExp(loc, e1, e);
	    e->type = e1->type;
	    init = new ExpInitializer(loc, e/*->type->defaultInit()*/);
	    return;
	}
	else if (type->ty == Ttypedef)
	{   TypeTypedef *td = (TypeTypedef *)type;
	    if (td->sym->init)
	    {	init = td->sym->init;
		ExpInitializer *ie = init->isExpInitializer();
		if (ie)
		    // Make copy so we can modify it
		    init = new ExpInitializer(ie->loc, ie->exp);
	    }
	    else
		init = getExpInitializer();
	}
	else
	{
	    init = getExpInitializer();
	}
    }

    if (init)
    {
	ArrayInitializer *ai = init->isArrayInitializer();
	if (ai && tb->ty == Taarray)
	{
	    init = ai->toAssocArrayInitializer();
	}

	StructInitializer *si = init->isStructInitializer();
	ExpInitializer *ei = init->isExpInitializer();

	// See if we can allocate on the stack
	if (ei && isScope() && ei->exp->op == TOKnew)
	{   NewExp *ne = (NewExp *)ei->exp;
	    if (!(ne->newargs && ne->newargs->dim))
	    {	ne->onstack = 1;
		onstack = 1;
		if (type->isBaseOf(ne->newtype->semantic(loc, sc), NULL))
		    onstack = 2;
	    }
	}

	// If inside function, there is no semantic3() call
	if (sc->func)
	{
	    // If local variable, use AssignExp to handle all the various
	    // possibilities.
	    if (fd && !isStatic() && !isConst() && !init->isVoidInitializer())
	    {
		Expression *e1;
		Type *t;
		int dim;

		//printf("fd = '%s', var = '%s'\n", fd->toChars(), toChars());
		if (!ei)
		{
		    Expression *e = init->toExpression();
		    if (!e)
		    {
			init = init->semantic(sc, type);
			e = init->toExpression();
			if (!e)
			{   error("is not a static and cannot have static initializer");
			    return;
			}
		    }
		    ei = new ExpInitializer(init->loc, e);
		    init = ei;
		}

		e1 = new VarExp(loc, this);

		t = type->toBasetype();
		if (t->ty == Tsarray)
		{
		    ei->exp = ei->exp->semantic(sc);
		    if (!ei->exp->implicitConvTo(type))
		    {
			dim = ((TypeSArray *)t)->dim->toInteger();
			// If multidimensional static array, treat as one large array
			while (1)
			{
			    t = t->nextOf()->toBasetype();
			    if (t->ty != Tsarray)
				break;
			    dim *= ((TypeSArray *)t)->dim->toInteger();
			    e1->type = new TypeSArray(t->nextOf(), new IntegerExp(0, dim, Type::tindex));
			}
		    }
		    e1 = new SliceExp(loc, e1, NULL, NULL);
		}
		else if (t->ty == Tstruct)
		{
		    ei->exp = ei->exp->semantic(sc);
		    if (!ei->exp->implicitConvTo(type))
			ei->exp = new CastExp(loc, ei->exp, type);
		}
		ei->exp = new AssignExp(loc, e1, ei->exp);
		ei->exp->op = TOKconstruct;
		canassign++;
		ei->exp = ei->exp->semantic(sc);
		canassign--;
		ei->exp->optimize(WANTvalue);
	    }
	    else
	    {
		init = init->semantic(sc, type);
		if (fd && isConst() && !isStatic())
		{   // Make it static
		    storage_class |= STCstatic;
		}
	    }
	}
	else if (isConst() || isFinal())
	{
	    /* Because we may need the results of a const declaration in a
	     * subsequent type, such as an array dimension, before semantic2()
	     * gets ordinarily run, try to run semantic2() now.
	     * Ignore failure.
	     */

	    if (!global.errors && !inferred)
	    {
		unsigned errors = global.errors;
		global.gag++;
		//printf("+gag\n");
		Expression *e;
		Initializer *i2 = init;
		inuse++;
		if (ei)
		{
		    e = ei->exp->syntaxCopy();
		    e = e->semantic(sc);
		    e = e->implicitCastTo(sc, type);
		}
		else if (si || ai)
		{   i2 = init->syntaxCopy();
		    i2 = i2->semantic(sc, type);
		}
		inuse--;
		global.gag--;
		//printf("-gag\n");
		if (errors != global.errors)	// if errors happened
		{
		    if (global.gag == 0)
			global.errors = errors;	// act as if nothing happened
		}
		else if (ei)
		{
		    e = e->optimize(WANTvalue | WANTinterpret);
		    if (e->op == TOKint64 || e->op == TOKstring)
		    {
			ei->exp = e;		// no errors, keep result
		    }
		}
		else
		    init = i2;		// no errors, keep result
	    }
	}
    }
}

ExpInitializer *VarDeclaration::getExpInitializer()
{
    ExpInitializer *ei;

    if (init)
	ei = init->isExpInitializer();
    else
    {
	Expression *e = type->defaultInit();
	if (e)
	    ei = new ExpInitializer(loc, e);
	else
	    ei = NULL;
    }
    return ei;
}

void VarDeclaration::semantic2(Scope *sc)
{
    //printf("VarDeclaration::semantic2('%s')\n", toChars());
    if (init && !toParent()->isFuncDeclaration())
    {	inuse++;
#if 0
	ExpInitializer *ei = init->isExpInitializer();
	if (ei)
	{
	    ei->exp->dump(0);
	    printf("type = %p\n", ei->exp->type);
	}
#endif
	init = init->semantic(sc, type);
	inuse--;
    }
}

char *VarDeclaration::kind()
{
    return "variable";
}

Dsymbol *VarDeclaration::toAlias()
{
    //printf("VarDeclaration::toAlias('%s', this = %p, aliassym = %p)\n", toChars(), this, aliassym);
    assert(this != aliassym);
    Dsymbol *s = aliassym ? aliassym->toAlias() : this;
    return s;
}

void VarDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    if (storage_class & STCconst)
	buf->writestring("const ");
    if (storage_class & STCstatic)
	buf->writestring("static ");
    if (type)
	type->toCBuffer(buf, ident, hgs);
    else
	buf->writestring(ident->toChars());
    if (init)
    {	buf->writestring(" = ");
	init->toCBuffer(buf, hgs);
    }
    buf->writeByte(';');
    buf->writenl();
}

int VarDeclaration::needThis()
{
    //printf("VarDeclaration::needThis(%s, x%x)\n", toChars(), storage_class);
    return storage_class & STCfield;
}

int VarDeclaration::isImportedSymbol()
{
    if (protection == PROTexport && !init && (isStatic() || isConst() || parent->isModule()))
	return TRUE;
    return FALSE;
}

void VarDeclaration::checkCtorConstInit()
{
    if (ctorinit == 0 && isCtorinit() && !(storage_class & STCfield))
	error("missing initializer in static constructor for const variable");
}

/************************************
 * Check to see if variable is a reference to an enclosing function
 * or not.
 */

void VarDeclaration::checkNestedReference(Scope *sc, Loc loc)
{
    if (parent && !isDataseg() && parent != sc->parent)
    {
	FuncDeclaration *fdv = toParent()->isFuncDeclaration();
	FuncDeclaration *fdthis = sc->parent->isFuncDeclaration();

	if (fdv && fdthis)
	{
	    if (loc.filename)
		fdthis->getLevel(loc, fdv);
	    nestedref = 1;
	    fdv->nestedFrameRef = 1;
	    //printf("var %s in function %s is nested ref\n", toChars(), fdv->toChars());
	}
    }
}

/*******************************
 * Does symbol go into data segment?
 */

int VarDeclaration::isDataseg()
{
#if 0
    printf("VarDeclaration::isDataseg(%p, '%s')\n", this, toChars());
    printf("%x, %p, %p\n", storage_class & (STCstatic | STCconst), parent->isModule(), parent->isTemplateInstance());
    printf("parent = '%s'\n", parent->toChars());
#endif
    Dsymbol *parent = this->toParent();
    if (!parent && !(storage_class & (STCstatic | STCconst)))
    {	error("forward referenced");
	type = Type::terror;
	return 0;
    }
    return (storage_class & (STCstatic | STCconst) ||
	   parent->isModule() ||
	   parent->isTemplateInstance());
}

int VarDeclaration::hasPointers()
{
    return (!isDataseg() && type->hasPointers());
}

/******************************************
 * If a variable has an auto destructor call, return call for it.
 * Otherwise, return NULL.
 */

Expression *VarDeclaration::callAutoDtor()
{   Expression *e = NULL;

    //printf("VarDeclaration::callAutoDtor() %s\n", toChars());
    if (storage_class & (STCauto | STCscope) && !noauto)
    {
	for (ClassDeclaration *cd = type->isClassHandle();
	     cd;
	     cd = cd->baseClass)
	{
	    /* We can do better if there's a way with onstack
	     * classes to determine if there's no way the monitor
	     * could be set.
	     */
	    //if (cd->isInterfaceDeclaration())
		//error("interface %s cannot be scope", cd->toChars());
	    if (1 || onstack || cd->dtors.dim)	// if any destructors
	    {
		// delete this;
		Expression *ec;

		ec = new VarExp(loc, this);
		e = new DeleteExp(loc, ec);
		e->type = Type::tvoid;
		break;
	    }
	}
    }
    return e;
}


/********************************* ClassInfoDeclaration ****************************/

ClassInfoDeclaration::ClassInfoDeclaration(ClassDeclaration *cd)
    : VarDeclaration(0, ClassDeclaration::classinfo->type, cd->ident, NULL)
{
    this->cd = cd;
    storage_class = STCstatic;
}

Dsymbol *ClassInfoDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(0);		// should never be produced by syntax
    return NULL;
}

void ClassInfoDeclaration::semantic(Scope *sc)
{
}

/********************************* ModuleInfoDeclaration ****************************/

ModuleInfoDeclaration::ModuleInfoDeclaration(Module *mod)
    : VarDeclaration(0, Module::moduleinfo->type, mod->ident, NULL)
{
    this->mod = mod;
    storage_class = STCstatic;
}

Dsymbol *ModuleInfoDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(0);		// should never be produced by syntax
    return NULL;
}

void ModuleInfoDeclaration::semantic(Scope *sc)
{
}

/********************************* TypeInfoDeclaration ****************************/

TypeInfoDeclaration::TypeInfoDeclaration(Type *tinfo, int internal)
    : VarDeclaration(0, Type::typeinfo->type, tinfo->getTypeInfoIdent(internal), NULL)
{
    this->tinfo = tinfo;
    storage_class = STCstatic;
    protection = PROTpublic;
    linkage = LINKc;
}

Dsymbol *TypeInfoDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(0);		// should never be produced by syntax
    return NULL;
}

void TypeInfoDeclaration::semantic(Scope *sc)
{
    assert(linkage == LINKc);
}

/***************************** TypeInfoConstDeclaration **********************/

#if V2
TypeInfoConstDeclaration::TypeInfoConstDeclaration(Type *tinfo)
    : TypeInfoDeclaration(tinfo, 0)
{
}
#endif

/***************************** TypeInfoInvariantDeclaration **********************/

#if V2
TypeInfoInvariantDeclaration::TypeInfoInvariantDeclaration(Type *tinfo)
    : TypeInfoDeclaration(tinfo, 0)
{
}
#endif

/***************************** TypeInfoStructDeclaration **********************/

TypeInfoStructDeclaration::TypeInfoStructDeclaration(Type *tinfo)
    : TypeInfoDeclaration(tinfo, 0)
{
}

/***************************** TypeInfoClassDeclaration ***********************/

TypeInfoClassDeclaration::TypeInfoClassDeclaration(Type *tinfo)
    : TypeInfoDeclaration(tinfo, 0)
{
}

/***************************** TypeInfoInterfaceDeclaration *******************/

TypeInfoInterfaceDeclaration::TypeInfoInterfaceDeclaration(Type *tinfo)
    : TypeInfoDeclaration(tinfo, 0)
{
}

/***************************** TypeInfoTypedefDeclaration *********************/

TypeInfoTypedefDeclaration::TypeInfoTypedefDeclaration(Type *tinfo)
    : TypeInfoDeclaration(tinfo, 0)
{
}

/***************************** TypeInfoPointerDeclaration *********************/

TypeInfoPointerDeclaration::TypeInfoPointerDeclaration(Type *tinfo)
    : TypeInfoDeclaration(tinfo, 0)
{
}

/***************************** TypeInfoArrayDeclaration ***********************/

TypeInfoArrayDeclaration::TypeInfoArrayDeclaration(Type *tinfo)
    : TypeInfoDeclaration(tinfo, 0)
{
}

/***************************** TypeInfoStaticArrayDeclaration *****************/

TypeInfoStaticArrayDeclaration::TypeInfoStaticArrayDeclaration(Type *tinfo)
    : TypeInfoDeclaration(tinfo, 0)
{
}

/***************************** TypeInfoAssociativeArrayDeclaration ************/

TypeInfoAssociativeArrayDeclaration::TypeInfoAssociativeArrayDeclaration(Type *tinfo)
    : TypeInfoDeclaration(tinfo, 0)
{
}

/***************************** TypeInfoEnumDeclaration ***********************/

TypeInfoEnumDeclaration::TypeInfoEnumDeclaration(Type *tinfo)
    : TypeInfoDeclaration(tinfo, 0)
{
}

/***************************** TypeInfoFunctionDeclaration ********************/

TypeInfoFunctionDeclaration::TypeInfoFunctionDeclaration(Type *tinfo)
    : TypeInfoDeclaration(tinfo, 0)
{
}

/***************************** TypeInfoDelegateDeclaration ********************/

TypeInfoDelegateDeclaration::TypeInfoDelegateDeclaration(Type *tinfo)
    : TypeInfoDeclaration(tinfo, 0)
{
}

/***************************** TypeInfoTupleDeclaration **********************/

TypeInfoTupleDeclaration::TypeInfoTupleDeclaration(Type *tinfo)
    : TypeInfoDeclaration(tinfo, 0)
{
}

/********************************* ThisDeclaration ****************************/

// For the "this" parameter to member functions

ThisDeclaration::ThisDeclaration(Type *t)
   : VarDeclaration(0, t, Id::This, NULL)
{
    noauto = 1;
}

Dsymbol *ThisDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(0);		// should never be produced by syntax
    return NULL;
}


