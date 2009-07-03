
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

#include "mars.h"
#include "init.h"
#include "declaration.h"
#include "attrib.h"
#include "expression.h"
#include "scope.h"
#include "mtype.h"
#include "aggregate.h"
#include "identifier.h"
#include "id.h"
#include "module.h"
#include "statement.h"
#include "template.h"
#include "hdrgen.h"

#ifdef IN_GCC
#include "d-dmd-gcc.h"
#endif

/********************************* FuncDeclaration ****************************/

FuncDeclaration::FuncDeclaration(Loc loc, Loc endloc, Identifier *id, enum STC storage_class, Type *type)
    : Declaration(id)
{
    //printf("FuncDeclaration(id = '%s', type = %p)\n", id->toChars(), type);
    this->storage_class = storage_class;
    this->type = type;
    this->loc = loc;
    this->endloc = endloc;
    fthrows = NULL;
    frequire = NULL;
    outId = NULL;
    vresult = NULL;
    returnLabel = NULL;
    fensure = NULL;
    fbody = NULL;
    localsymtab = NULL;
    vthis = NULL;
    v_arguments = NULL;
#if IN_GCC
    v_argptr = NULL;
#endif
    parameters = NULL;
    labtab = NULL;
    overnext = NULL;
    vtblIndex = -1;
    hasReturnExp = 0;
    naked = 0;
    inlineStatus = ILSuninitialized;
    inlineNest = 0;
    inlineAsm = 0;
    cantInterpret = 0;
    semanticRun = 0;
    nestedFrameRef = 0;
    fes = NULL;
    introducing = 0;
    tintro = NULL;
    inferRetType = (type && type->nextOf() == NULL);
    scope = NULL;
    hasReturnExp = 0;
    nrvo_can = 1;
    nrvo_var = NULL;
    shidden = NULL;
}

Dsymbol *FuncDeclaration::syntaxCopy(Dsymbol *s)
{
    FuncDeclaration *f;

    //printf("FuncDeclaration::syntaxCopy('%s')\n", toChars());
    if (s)
	f = (FuncDeclaration *)s;
    else
	f = new FuncDeclaration(loc, endloc, ident, (enum STC) storage_class, type->syntaxCopy());
    f->outId = outId;
    f->frequire = frequire ? frequire->syntaxCopy() : NULL;
    f->fensure  = fensure  ? fensure->syntaxCopy()  : NULL;
    f->fbody    = fbody    ? fbody->syntaxCopy()    : NULL;
    assert(!fthrows); // deprecated
    return f;
}


// Do the semantic analysis on the external interface to the function.

void FuncDeclaration::semantic(Scope *sc)
{   TypeFunction *f;
    StructDeclaration *sd;
    ClassDeclaration *cd;
    InterfaceDeclaration *id;

#if 0
    printf("FuncDeclaration::semantic(sc = %p, this = %p, '%s', linkage = %d)\n", sc, this, toPrettyChars(), sc->linkage);
    if (isFuncLiteralDeclaration())
	printf("\tFuncLiteralDeclaration()\n");
    printf("sc->parent = %s\n", sc->parent->toChars());
    printf("type: %s\n", type->toChars());
#endif

    if (type->nextOf())
	type = type->semantic(loc, sc);
    //type->print();
    if (type->ty != Tfunction)
    {
	error("%s must be a function", toChars());
	return;
    }
    f = (TypeFunction *)(type);
    size_t nparams = Argument::dim(f->parameters);

    linkage = sc->linkage;
//    if (!parent)
    {
	//parent = sc->scopesym;
	parent = sc->parent;
    }
    protection = sc->protection;
    storage_class |= sc->stc;
    //printf("function storage_class = x%x\n", storage_class);
    Dsymbol *parent = toParent();

    if (isConst() || isAuto() || isScope())
	error("functions cannot be const or auto");

    if (isAbstract() && !isVirtual())
	error("non-virtual functions cannot be abstract");

    if (isAbstract() && isFinal())
	error("cannot be both final and abstract");
#if 0
    if (isAbstract() && fbody)
	error("abstract functions cannot have bodies");
#endif

#if 0
    if (isStaticConstructor() || isStaticDestructor())
    {
	if (!isStatic() || type->nextOf()->ty != Tvoid)
	    error("static constructors / destructors must be static void");
	if (f->arguments && f->arguments->dim)
	    error("static constructors / destructors must have empty parameter list");
	// BUG: check for invalid storage classes
    }
#endif

#ifdef IN_GCC
    AggregateDeclaration *ad;

    ad = parent->isAggregateDeclaration();
    if (ad)
	ad->methods.push(this);
#endif
    sd = parent->isStructDeclaration();
    if (sd)
    {
	// Verify no constructors, destructors, etc.
	if (isCtorDeclaration() ||
	    isDtorDeclaration()
	    //|| isInvariantDeclaration()
	    //|| isUnitTestDeclaration()
	   )
	{
	    error("special member functions not allowed for %ss", sd->kind());
	}

#if 0
	if (!sd->inv)
	    sd->inv = isInvariantDeclaration();

	if (!sd->aggNew)
	    sd->aggNew = isNewDeclaration();

	if (isDelete())
	{
	    if (sd->aggDelete)
		error("multiple delete's for struct %s", sd->toChars());
	    sd->aggDelete = (DeleteDeclaration *)(this);
	}
#endif
    }

    id = parent->isInterfaceDeclaration();
    if (id)
    {
	storage_class |= STCabstract;

	if (isCtorDeclaration() ||
	    isDtorDeclaration() ||
	    isInvariantDeclaration() ||
	    isUnitTestDeclaration() || isNewDeclaration() || isDelete())
	    error("special function not allowed in interface %s", id->toChars());
	if (fbody)
	    error("function body is not abstract in interface %s", id->toChars());
    }

    cd = parent->isClassDeclaration();
    if (cd)
    {	int vi;
	CtorDeclaration *ctor;
	DtorDeclaration *dtor;
	InvariantDeclaration *inv;

	if (isCtorDeclaration())
	{
//	    ctor = (CtorDeclaration *)this;
//	    if (!cd->ctor)
//		cd->ctor = ctor;
	    return;
	}

#if 0
	dtor = isDtorDeclaration();
	if (dtor)
	{
	    if (cd->dtor)
		error("multiple destructors for class %s", cd->toChars());
	    cd->dtor = dtor;
	}

	inv = isInvariantDeclaration();
	if (inv)
	{
	    cd->inv = inv;
	}

	if (isNewDeclaration())
	{
	    if (!cd->aggNew)
		cd->aggNew = (NewDeclaration *)(this);
	}

	if (isDelete())
	{
	    if (cd->aggDelete)
		error("multiple delete's for class %s", cd->toChars());
	    cd->aggDelete = (DeleteDeclaration *)(this);
	}
#endif

	if (storage_class & STCabstract)
	    cd->isabstract = 1;

	// if static function, do not put in vtbl[]
	if (!isVirtual())
	{
	    //printf("\tnot virtual\n");
	    goto Ldone;
	}

	// Find index of existing function in vtbl[] to override
	vi = findVtblIndex(&cd->vtbl, cd->baseClass ? cd->baseClass->vtbl.dim : 0);
	switch (vi)
	{
	    case -1:	// didn't find one
		// This is an 'introducing' function.

		// Verify this doesn't override previous final function
		if (cd->baseClass)
		{   Dsymbol *s = cd->baseClass->search(loc, ident, 0);
		    if (s)
		    {
			FuncDeclaration *f = s->isFuncDeclaration();
			f = f->overloadExactMatch(type);
			if (f && f->isFinal() && f->prot() != PROTprivate)
			    error("cannot override final function %s", f->toPrettyChars());
		    }
		}

		if (isFinal())
		{
		    cd->vtblFinal.push(this);
		}
		else
		{
		    // Append to end of vtbl[]
		    //printf("\tintroducing function\n");
		    introducing = 1;
		    vi = cd->vtbl.dim;
		    cd->vtbl.push(this);
		    vtblIndex = vi;
		}
		break;

	    case -2:	// can't determine because of fwd refs
		cd->sizeok = 2;	// can't finish due to forward reference
		return;

	    default:
	    {   FuncDeclaration *fdv = (FuncDeclaration *)cd->vtbl.data[vi];
		// This function is covariant with fdv
		if (fdv->isFinal())
		    error("cannot override final function %s", fdv->toPrettyChars());

#if V2
		if (!isOverride() && global.params.warnings)
		    error("overrides base class function %s, but is not marked with 'override'", fdv->toPrettyChars());
#endif

		if (fdv->toParent() == parent)
		{
		    // If both are mixins, then error.
		    // If either is not, the one that is not overrides
		    // the other.
		    if (fdv->parent->isClassDeclaration())
			break;
		    if (!this->parent->isClassDeclaration()
#if !BREAKABI
			&& !isDtorDeclaration()
#endif
#if V2
			&& !isPostBlitDeclaration()
#endif
			)
			error("multiple overrides of same function");
		}
		cd->vtbl.data[vi] = (void *)this;
		vtblIndex = vi;

		/* This works by whenever this function is called,
		 * it actually returns tintro, which gets dynamically
		 * cast to type. But we know that tintro is a base
		 * of type, so we could optimize it by not doing a
		 * dynamic cast, but just subtracting the isBaseOf()
		 * offset if the value is != null.
		 */

		if (fdv->tintro)
		    tintro = fdv->tintro;
		else if (!type->equals(fdv->type))
		{
		    /* Only need to have a tintro if the vptr
		     * offsets differ
		     */
		    int offset;
		    if (fdv->type->nextOf()->isBaseOf(type->nextOf(), &offset))
		    {
			tintro = fdv->type;
		    }
		}
		break;
	    }
	}

	/* Go through all the interface bases.
	 * If this function is covariant with any members of those interface
	 * functions, set the tintro.
	 */
	for (int i = 0; i < cd->interfaces_dim; i++)
	{
#if 1
	    BaseClass *b = cd->interfaces[i];
	    vi = findVtblIndex(&b->base->vtbl, b->base->vtbl.dim);
	    switch (vi)
	    {
		case -1:
		    break;

		case -2:
		    cd->sizeok = 2;	// can't finish due to forward reference
		    return;

		default:
		{   FuncDeclaration *fdv = (FuncDeclaration *)b->base->vtbl.data[vi];
		    Type *ti = NULL;

		    if (fdv->tintro)
			ti = fdv->tintro;
		    else if (!type->equals(fdv->type))
		    {
			/* Only need to have a tintro if the vptr
			 * offsets differ
			 */
			int offset;
			if (fdv->type->nextOf()->isBaseOf(type->nextOf(), &offset))
			{
			    ti = fdv->type;
#if 0
			    if (offset)
				ti = fdv->type;
			    else if (type->nextOf()->ty == Tclass)
			    {   ClassDeclaration *cdn = ((TypeClass *)type->nextOf())->sym;
				if (cdn && cdn->sizeok != 1)
				    ti = fdv->type;
			    }
#endif
			}
		    }
		    if (ti)
		    {
			if (tintro && !tintro->equals(ti))
			{
			    error("incompatible covariant types %s and %s", tintro->toChars(), ti->toChars());
			}
			tintro = ti;
		    }
		    goto L2;
		}
	    }
#else
	    BaseClass *b = cd->interfaces[i];
	    for (vi = 0; vi < b->base->vtbl.dim; vi++)
	    {
		Dsymbol *s = (Dsymbol *)b->base->vtbl.data[vi];
		//printf("interface %d vtbl[%d] %p %s\n", i, vi, s, s->toChars());
		FuncDeclaration *fdv = s->isFuncDeclaration();
		if (fdv && fdv->ident == ident)
		{
		    int cov = type->covariant(fdv->type);
		    //printf("\tcov = %d\n", cov);
		    if (cov == 2)
		    {
			//type->print();
			//fdv->type->print();
			//printf("%s %s\n", type->deco, fdv->type->deco);
			error("of type %s overrides but is not covariant with %s of type %s",
			    type->toChars(), fdv->toPrettyChars(), fdv->type->toChars());
		    }
		    if (cov == 1)
		    {	Type *ti = NULL;

			if (fdv->tintro)
			    ti = fdv->tintro;
			else if (!type->equals(fdv->type))
			{
			    /* Only need to have a tintro if the vptr
			     * offsets differ
			     */
			    int offset;
			    if (fdv->type->nextOf()->isBaseOf(type->nextOf(), &offset))
			    {
				ti = fdv->type;
#if 0
				if (offset)
				    ti = fdv->type;
				else if (type->nextOf()->ty == Tclass)
				{   ClassDeclaration *cdn = ((TypeClass *)type->nextOf())->sym;
				    if (cdn && cdn->sizeok != 1)
					ti = fdv->type;
				}
#endif
			    }
			}
			if (ti)
			{
			    if (tintro && !tintro->equals(ti))
			    {
				error("incompatible covariant types %s and %s", tintro->toChars(), ti->toChars());
			    }
			    tintro = ti;
			}
			goto L2;
		    }
		    if (cov == 3)
		    {
			cd->sizeok = 2;	// can't finish due to forward reference
			return;
		    }
		}
	    }
#endif
	}

	if (introducing && isOverride())
	{
	    error("does not override any function");
	}

    L2: ;
    }
    else if (isOverride() && !parent->isTemplateInstance())
	error("override only applies to class member functions");

    /* Do not allow template instances to add virtual functions
     * to a class.
     */
    if (isVirtual())
    {
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
	    ClassDeclaration *cd = ti->tempdecl->isClassMember();
	    if (cd)
	    {
		error("cannot use template to add virtual function to class '%s'", cd->toChars());
	    }
	}
    }

    if (isMain())
    {
	// Check parameters to see if they are either () or (char[][] args)
	switch (nparams)
	{
	    case 0:
		break;

	    case 1:
	    {
		Argument *arg0 = Argument::getNth(f->parameters, 0);
		if (arg0->type->ty != Tarray ||
		    arg0->type->nextOf()->ty != Tarray ||
		    arg0->type->nextOf()->nextOf()->ty != Tchar ||
		    arg0->storageClass & (STCout | STCref | STClazy))
		    goto Lmainerr;
		break;
	    }

	    default:
		goto Lmainerr;
	}

	if (f->nextOf()->ty != Tint32 && f->nextOf()->ty != Tvoid)
	    error("must return int or void, not %s", f->nextOf()->toChars());
	if (f->varargs)
	{
	Lmainerr:
	    error("parameters must be main() or main(char[][] args)");
	}
    }

    if (ident == Id::assign && (sd || cd))
    {	// Disallow identity assignment operator.

	// opAssign(...)
	if (nparams == 0)
	{   if (f->varargs == 1)
		goto Lassignerr;
	}
	else
	{
	    Argument *arg0 = Argument::getNth(f->parameters, 0);
	    Type *t0 = arg0->type->toBasetype();
	    Type *tb = sd ? sd->type : cd->type;
	    if (arg0->type->implicitConvTo(tb) ||
		(sd && t0->ty == Tpointer && t0->nextOf()->implicitConvTo(tb))
	       )
	    {
		if (nparams == 1)
		    goto Lassignerr;
		Argument *arg1 = Argument::getNth(f->parameters, 1);
		if (arg1->defaultArg)
		    goto Lassignerr;
	    }
	}
    }

Ldone:
    /* Save scope for possible later use (if we need the
     * function internals)
     */
    scope = new Scope(*sc);
    scope->setNoFree();
    return;

Lassignerr:
    error("identity assignment operator overload is illegal");
}

void FuncDeclaration::semantic2(Scope *sc)
{
}

// Do the semantic analysis on the internals of the function.

void FuncDeclaration::semantic3(Scope *sc)
{   TypeFunction *f;
    AggregateDeclaration *ad;
    VarDeclaration *argptr = NULL;
    VarDeclaration *_arguments = NULL;

    if (!parent)
    {
	if (global.errors)
	    return;
	//printf("FuncDeclaration::semantic3(%s '%s', sc = %p)\n", kind(), toChars(), sc);
	assert(0);
    }
    //printf("FuncDeclaration::semantic3('%s.%s', sc = %p, loc = %s)\n", parent->toChars(), toChars(), sc, loc.toChars());
    //fflush(stdout);
    //{ static int x; if (++x == 2) *(char*)0=0; }
    //printf("\tlinkage = %d\n", sc->linkage);

    //printf(" sc->incontract = %d\n", sc->incontract);
    if (semanticRun)
	return;
    semanticRun = 1;

    if (!type || type->ty != Tfunction)
	return;
    f = (TypeFunction *)(type);
    size_t nparams = Argument::dim(f->parameters);

    // Check the 'throws' clause
    if (fthrows)
    {	int i;

	for (i = 0; i < fthrows->dim; i++)
	{
	    Type *t = (Type *)fthrows->data[i];

	    t = t->semantic(loc, sc);
	    if (!t->isClassHandle())
		error("can only throw classes, not %s", t->toChars());
	}
    }

    if (fbody || frequire)
    {
	/* Symbol table into which we place parameters and nested functions,
	 * solely to diagnose name collisions.
	 */
	localsymtab = new DsymbolTable();

	// Establish function scope
	ScopeDsymbol *ss = new ScopeDsymbol();
	ss->parent = sc->scopesym;
	Scope *sc2 = sc->push(ss);
	sc2->func = this;
	sc2->parent = this;
	sc2->callSuper = 0;
	sc2->sbreak = NULL;
	sc2->scontinue = NULL;
	sc2->sw = NULL;
	sc2->fes = fes;
	sc2->linkage = LINKd;
	sc2->stc &= ~(STCauto | STCscope | STCstatic | STCabstract | STCdeprecated | STCfinal);
	sc2->protection = PROTpublic;
	sc2->explicitProtection = 0;
	sc2->structalign = 8;
	sc2->incontract = 0;
	sc2->tf = NULL;
	sc2->noctor = 0;

	// Declare 'this'
	ad = isThis();
	if (ad)
	{   VarDeclaration *v;

	    if (isFuncLiteralDeclaration() && isNested())
	    {
		error("literals cannot be class members");
		return;
	    }
	    else
	    {
		assert(!isNested());	// can't be both member and nested
		assert(ad->handle);
		v = new ThisDeclaration(ad->handle);
		v->storage_class |= STCparameter | STCin;
		v->semantic(sc2);
		if (!sc2->insert(v))
		    assert(0);
		v->parent = this;
		vthis = v;
	    }
	}
	else if (isNested())
	{
	    VarDeclaration *v;

	    v = new ThisDeclaration(Type::tvoid->pointerTo());
	    v->storage_class |= STCparameter | STCin;
	    v->semantic(sc2);
	    if (!sc2->insert(v))
		assert(0);
	    v->parent = this;
	    vthis = v;
	}

	// Declare hidden variable _arguments[] and _argptr
	if (f->varargs == 1)
	{   Type *t;

	    if (f->linkage == LINKd)
	    {	// Declare _arguments[]
#if BREAKABI
		v_arguments = new VarDeclaration(0, Type::typeinfotypelist->type, Id::_arguments_typeinfo, NULL);
		v_arguments->storage_class = STCparameter | STCin;
		v_arguments->semantic(sc2);
		sc2->insert(v_arguments);
		v_arguments->parent = this;

		t = Type::typeinfo->type->arrayOf();
		_arguments = new VarDeclaration(0, t, Id::_arguments, NULL);
		_arguments->semantic(sc2);
		sc2->insert(_arguments);
		_arguments->parent = this;
#else
		t = Type::typeinfo->type->arrayOf();
		v_arguments = new VarDeclaration(0, t, Id::_arguments, NULL);
		v_arguments->storage_class = STCparameter | STCin;
		v_arguments->semantic(sc2);
		sc2->insert(v_arguments);
		v_arguments->parent = this;
#endif
	    }
	    if (f->linkage == LINKd || (parameters && parameters->dim))
	    {	// Declare _argptr
#if IN_GCC
		t = d_gcc_builtin_va_list_d_type;
#else
		t = Type::tvoid->pointerTo();
#endif
		argptr = new VarDeclaration(0, t, Id::_argptr, NULL);
		argptr->semantic(sc2);
		sc2->insert(argptr);
		argptr->parent = this;
	    }
	}

	// Propagate storage class from tuple parameters to their element-parameters.
	if (f->parameters)
	{
	    for (size_t i = 0; i < f->parameters->dim; i++)
	    {	Argument *arg = (Argument *)f->parameters->data[i];

		if (arg->type->ty == Ttuple)
		{   TypeTuple *t = (TypeTuple *)arg->type;
		    size_t dim = Argument::dim(t->arguments);
		    for (size_t j = 0; j < dim; j++)
		    {	Argument *narg = Argument::getNth(t->arguments, j);
			narg->storageClass = arg->storageClass;
		    }
		}
	    }
	}

	// Declare all the function parameters as variables
	if (nparams)
	{   /* parameters[] has all the tuples removed, as the back end
	     * doesn't know about tuples
	     */
	    parameters = new Dsymbols();
	    parameters->reserve(nparams);
	    for (size_t i = 0; i < nparams; i++)
	    {
		Argument *arg = Argument::getNth(f->parameters, i);
		Identifier *id = arg->ident;
		if (!id)
		{
		    /* Generate identifier for un-named parameter,
		     * because we need it later on.
		     */
		    OutBuffer buf;
		    buf.printf("_param_%zu", i);
		    char *name = (char *)buf.extractData();
		    id = new Identifier(name, TOKidentifier);
		    arg->ident = id;
		}
		VarDeclaration *v = new VarDeclaration(loc, arg->type, id, NULL);
		//printf("declaring parameter %s of type %s\n", v->toChars(), v->type->toChars());
		v->storage_class |= STCparameter;
		if (f->varargs == 2 && i + 1 == nparams)
		    v->storage_class |= STCvariadic;
		v->storage_class |= arg->storageClass & (STCin | STCout | STCref | STClazy);
		if (v->storage_class & STClazy)
		    v->storage_class |= STCin;
		v->semantic(sc2);
		if (!sc2->insert(v))
		    error("parameter %s.%s is already defined", toChars(), v->toChars());
		else
		    parameters->push(v);
		localsymtab->insert(v);
		v->parent = this;
	    }
	}

	// Declare the tuple symbols and put them in the symbol table,
	// but not in parameters[].
	if (f->parameters)
	{
	    for (size_t i = 0; i < f->parameters->dim; i++)
	    {	Argument *arg = (Argument *)f->parameters->data[i];

		if (!arg->ident)
		    continue;			// never used, so ignore
		if (arg->type->ty == Ttuple)
		{   TypeTuple *t = (TypeTuple *)arg->type;
		    size_t dim = Argument::dim(t->arguments);
		    Objects *exps = new Objects();
		    exps->setDim(dim);
		    for (size_t j = 0; j < dim; j++)
		    {	Argument *narg = Argument::getNth(t->arguments, j);
			assert(narg->ident);
			VarDeclaration *v = sc2->search(0, narg->ident, NULL)->isVarDeclaration();
			assert(v);
			Expression *e = new VarExp(0, v);
			exps->data[j] = (void *)e;
		    }
		    assert(arg->ident);
		    TupleDeclaration *v = new TupleDeclaration(0, arg->ident, exps);
		    //printf("declaring tuple %s\n", v->toChars());
		    v->isexp = 1;
		    if (!sc2->insert(v))
			error("parameter %s.%s is already defined", toChars(), v->toChars());
		    localsymtab->insert(v);
		    v->parent = this;
		}
	    }
	}

	/* Do the semantic analysis on the [in] preconditions and
	 * [out] postconditions.
	 */
	sc2->incontract++;

	if (frequire)
	{   /* frequire is composed of the [in] contracts
	     */
	    // BUG: need to error if accessing out parameters
	    // BUG: need to treat parameters as const
	    // BUG: need to disallow returns and throws
	    // BUG: verify that all in and ref parameters are read
	    frequire = frequire->semantic(sc2);
	    labtab = NULL;		// so body can't refer to labels
	}

	if (fensure || addPostInvariant())
	{   /* fensure is composed of the [out] contracts
	     */
	    ScopeDsymbol *sym = new ScopeDsymbol();
	    sym->parent = sc2->scopesym;
	    sc2 = sc2->push(sym);

	    assert(type->nextOf());
	    if (type->nextOf()->ty == Tvoid)
	    {
		if (outId)
		    error("void functions have no result");
	    }
	    else
	    {
		if (!outId)
		    outId = Id::result;		// provide a default
	    }

	    if (outId)
	    {	// Declare result variable
		VarDeclaration *v;
		Loc loc = this->loc;

		if (fensure)
		    loc = fensure->loc;

		v = new VarDeclaration(loc, type->nextOf(), outId, NULL);
		v->noauto = 1;
		sc2->incontract--;
		v->semantic(sc2);
		sc2->incontract++;
		if (!sc2->insert(v))
		    error("out result %s is already defined", v->toChars());
		v->parent = this;
		vresult = v;

		// vresult gets initialized with the function return value
		// in ReturnStatement::semantic()
	    }

	    // BUG: need to treat parameters as const
	    // BUG: need to disallow returns and throws
	    if (fensure)
	    {	fensure = fensure->semantic(sc2);
		labtab = NULL;		// so body can't refer to labels
	    }

	    if (!global.params.useOut)
	    {	fensure = NULL;		// discard
		vresult = NULL;
	    }

	    // Postcondition invariant
	    if (addPostInvariant())
	    {
		Expression *e = NULL;
		if (isCtorDeclaration())
		{
		    // Call invariant directly only if it exists
		    InvariantDeclaration *inv = ad->inv;
		    ClassDeclaration *cd = ad->isClassDeclaration();

		    while (!inv && cd)
		    {
			cd = cd->baseClass;
			if (!cd)
			    break;
			inv = cd->inv;
		    }
		    if (inv)
		    {
			e = new DsymbolExp(0, inv);
			e = new CallExp(0, e);
			e = e->semantic(sc2);
		    }
		}
		else
		{   // Call invariant virtually
		    ThisExp *v = new ThisExp(0);
		    v->type = vthis->type;
		    e = new AssertExp(0, v);
		}
		if (e)
		{
		    ExpStatement *s = new ExpStatement(0, e);
		    if (fensure)
			fensure = new CompoundStatement(0, s, fensure);
		    else
			fensure = s;
		}
	    }

	    if (fensure)
	    {	returnLabel = new LabelDsymbol(Id::returnLabel);
		LabelStatement *ls = new LabelStatement(0, Id::returnLabel, fensure);
		ls->isReturnLabel = 1;
		returnLabel->statement = ls;
	    }
	    sc2 = sc2->pop();
	}

	sc2->incontract--;

	if (fbody)
	{   ClassDeclaration *cd = isClassMember();

	    /* If this is a class constructor
	     */
	    if (isCtorDeclaration() && cd)
	    {
		for (int i = 0; i < cd->fields.dim; i++)
		{   VarDeclaration *v = (VarDeclaration *)cd->fields.data[i];

		    v->ctorinit = 0;
		}
	    }

	    if (inferRetType || f->retStyle() != RETstack)
		nrvo_can = 0;

	    fbody = fbody->semantic(sc2);

	    if (inferRetType)
	    {	// If no return type inferred yet, then infer a void
		if (!type->nextOf())
		{
		    ((TypeFunction *)type)->next = Type::tvoid;
		    type = type->semantic(loc, sc);
		}
		f = (TypeFunction *)type;
	    }

	    int offend = fbody ? fbody->fallOffEnd() : TRUE;

	    if (isStaticCtorDeclaration())
	    {	/* It's a static constructor. Ensure that all
		 * ctor consts were initialized.
		 */

		Dsymbol *p = toParent();
		ScopeDsymbol *ad = p->isScopeDsymbol();
		if (!ad)
		{
		    error("static constructor can only be member of struct/class/module, not %s %s", p->kind(), p->toChars());
		}
		else
		{
		    for (int i = 0; i < ad->members->dim; i++)
		    {   Dsymbol *s = (Dsymbol *)ad->members->data[i];

			s->checkCtorConstInit();
		    }
		}
	    }

	    if (isCtorDeclaration() && cd)
	    {
		//printf("callSuper = x%x\n", sc2->callSuper);

		// Verify that all the ctorinit fields got initialized
		if (!(sc2->callSuper & CSXthis_ctor))
		{
		    for (int i = 0; i < cd->fields.dim; i++)
		    {   VarDeclaration *v = (VarDeclaration *)cd->fields.data[i];

			if (v->ctorinit == 0 && v->isCtorinit())
			    error("missing initializer for const field %s", v->toChars());
		    }
		}

		if (!(sc2->callSuper & CSXany_ctor) &&
		    cd->baseClass && cd->baseClass->ctor)
		{
		    sc2->callSuper = 0;

		    // Insert implicit super() at start of fbody
		    Expression *e1 = new SuperExp(0);
		    Expression *e = new CallExp(0, e1);

		    unsigned errors = global.errors;
		    global.gag++;
		    e = e->semantic(sc2);
		    global.gag--;
		    if (errors != global.errors)
			error("no match for implicit super() call in constructor");

		    Statement *s = new ExpStatement(0, e);
		    fbody = new CompoundStatement(0, s, fbody);
		}
	    }
	    else if (fes)
	    {	// For foreach(){} body, append a return 0;
		Expression *e = new IntegerExp(0);
		Statement *s = new ReturnStatement(0, e);
		fbody = new CompoundStatement(0, fbody, s);
		assert(!returnLabel);
	    }
	    else if (!hasReturnExp && type->nextOf()->ty != Tvoid)
		error("expected to return a value of type %s", type->nextOf()->toChars());
	    else if (!inlineAsm)
	    {
		if (type->nextOf()->ty == Tvoid)
		{
		    if (offend && isMain())
		    {	// Add a return 0; statement
			Statement *s = new ReturnStatement(0, new IntegerExp(0));
			fbody = new CompoundStatement(0, fbody, s);
		    }
		}
		else
		{
		    if (offend)
		    {   Expression *e;

			if (global.params.warnings)
			{   fprintf(stdmsg, "warning - ");
			    error("no return at end of function");
			}

			if (global.params.useAssert &&
			    !global.params.useInline)
			{   /* Add an assert(0, msg); where the missing return
			     * should be.
			     */
			    e = new AssertExp(
				  endloc,
				  new IntegerExp(0),
				  new StringExp(loc, "missing return expression")
				);
			}
			else
			    e = new HaltExp(endloc);
			e = new CommaExp(0, e, type->nextOf()->defaultInit());
			e = e->semantic(sc2);
			Statement *s = new ExpStatement(0, e);
			fbody = new CompoundStatement(0, fbody, s);
		    }
		}
	    }
	}

	{
	    Statements *a = new Statements();

	    // Merge in initialization of 'out' parameters
	    if (parameters)
	    {	for (size_t i = 0; i < parameters->dim; i++)
		{
		    VarDeclaration *v = (VarDeclaration *)parameters->data[i];
		    if (v->storage_class & STCout)
		    {
			assert(v->init);
			ExpInitializer *ie = v->init->isExpInitializer();
			assert(ie);
			a->push(new ExpStatement(0, ie->exp));
		    }
		}
	    }

	    if (argptr)
	    {	// Initialize _argptr to point past non-variadic arg
#if IN_GCC
		// Handled in FuncDeclaration::toObjFile
		v_argptr = argptr;
		v_argptr->init = new VoidInitializer(loc);
#else
		Expression *e1;
		Expression *e;
		Type *t = argptr->type;
		VarDeclaration *p;
		unsigned offset;

		e1 = new VarExp(0, argptr);
		if (parameters && parameters->dim)
		    p = (VarDeclaration *)parameters->data[parameters->dim - 1];
		else
		    p = v_arguments;		// last parameter is _arguments[]
		offset = p->type->size();
		offset = (offset + 3) & ~3;	// assume stack aligns on 4
		e = new SymOffExp(0, p, offset);
		e = new AssignExp(0, e1, e);
		e->type = t;
		a->push(new ExpStatement(0, e));
#endif
	    }

	    if (_arguments)
	    {
		/* Advance to elements[] member of TypeInfo_Tuple with:
		 *  _arguments = v_arguments.elements;
		 */
		Expression *e = new VarExp(0, v_arguments);
		e = new DotIdExp(0, e, Id::elements);
		Expression *e1 = new VarExp(0, _arguments);
		e = new AssignExp(0, e1, e);
		e = e->semantic(sc);
		a->push(new ExpStatement(0, e));
	    }

	    // Merge contracts together with body into one compound statement

#ifdef _DH
	    if (frequire && global.params.useIn)
	    {	frequire->incontract = 1;
		a->push(frequire);
	    }
#else
	    if (frequire && global.params.useIn)
		a->push(frequire);
#endif

	    // Precondition invariant
	    if (addPreInvariant())
	    {
		Expression *e = NULL;
		if (isDtorDeclaration())
		{
		    // Call invariant directly only if it exists
		    InvariantDeclaration *inv = ad->inv;
		    ClassDeclaration *cd = ad->isClassDeclaration();

		    while (!inv && cd)
		    {
			cd = cd->baseClass;
			if (!cd)
			    break;
			inv = cd->inv;
		    }
		    if (inv)
		    {
			e = new DsymbolExp(0, inv);
			e = new CallExp(0, e);
			e = e->semantic(sc2);
		    }
		}
		else
		{   // Call invariant virtually
		    ThisExp *v = new ThisExp(0);
		    v->type = vthis->type;
		    Expression *se = new StringExp(0, "null this");
		    se = se->semantic(sc);
		    se->type = Type::tchar->arrayOf();
		    e = new AssertExp(loc, v, se);
		}
		if (e)
		{
		    ExpStatement *s = new ExpStatement(0, e);
		    a->push(s);
		}
	    }

	    if (fbody)
		a->push(fbody);

	    if (fensure)
	    {
		a->push(returnLabel->statement);

		if (type->nextOf()->ty != Tvoid)
		{
		    // Create: return vresult;
		    assert(vresult);
		    Expression *e = new VarExp(0, vresult);
		    if (tintro)
		    {	e = e->implicitCastTo(sc, tintro->nextOf());
			e = e->semantic(sc);
		    }
		    ReturnStatement *s = new ReturnStatement(0, e);
		    a->push(s);
		}
	    }

	    fbody = new CompoundStatement(0, a);
	}

	sc2->callSuper = 0;
	sc2->pop();
    }
    semanticRun = 2;
}

void FuncDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    //printf("FuncDeclaration::toCBuffer() '%s'\n", toChars());

    type->toCBuffer(buf, ident, hgs);
    bodyToCBuffer(buf, hgs);
}


void FuncDeclaration::bodyToCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    if (fbody &&
	(!hgs->hdrgen || hgs->tpltMember || canInline(1,1))
       )
    {	buf->writenl();

	// in{}
	if (frequire)
	{   buf->writestring("in");
	    buf->writenl();
	    frequire->toCBuffer(buf, hgs);
	}

	// out{}
	if (fensure)
	{   buf->writestring("out");
	    if (outId)
	    {   buf->writebyte('(');
		buf->writestring(outId->toChars());
		buf->writebyte(')');
	    }
	    buf->writenl();
	    fensure->toCBuffer(buf, hgs);
	}

        if (frequire || fensure)
	{   buf->writestring("body");
	    buf->writenl();
	}

	buf->writebyte('{');
	buf->writenl();
	fbody->toCBuffer(buf, hgs);
	buf->writebyte('}');
	buf->writenl();
    }
    else
    {	buf->writeByte(';');
	buf->writenl();
    }
}

/****************************************************
 * Determine if 'this' overrides fd.
 * Return !=0 if it does.
 */

int FuncDeclaration::overrides(FuncDeclaration *fd)
{   int result = 0;

    if (fd->ident == ident)
    {
	int cov = type->covariant(fd->type);
	if (cov)
	{   ClassDeclaration *cd1 = toParent()->isClassDeclaration();
	    ClassDeclaration *cd2 = fd->toParent()->isClassDeclaration();

	    if (cd1 && cd2 && cd2->isBaseOf(cd1, NULL))
		result = 1;
	}
    }
    return result;
}

/*************************************************
 * Find index of function in vtbl[0..dim] that
 * this function overrides.
 * Returns:
 *	-1	didn't find one
 *	-2	can't determine because of forward references
 */

int FuncDeclaration::findVtblIndex(Array *vtbl, int dim)
{
    for (int vi = 0; vi < dim; vi++)
    {
	FuncDeclaration *fdv = ((Dsymbol *)vtbl->data[vi])->isFuncDeclaration();
	if (fdv && fdv->ident == ident)
	{
	    int cov = type->covariant(fdv->type);
	    //printf("\tbaseclass cov = %d\n", cov);
	    switch (cov)
	    {
		case 0:		// types are distinct
		    break;

		case 1:
		    return vi;

		case 2:
		    //type->print();
		    //fdv->type->print();
		    //printf("%s %s\n", type->deco, fdv->type->deco);
		    error("of type %s overrides but is not covariant with %s of type %s",
			type->toChars(), fdv->toPrettyChars(), fdv->type->toChars());
		    break;

		case 3:
		    return -2;	// forward references

		default:
		    assert(0);
	    }
	}
    }
    return -1;
}

/****************************************************
 * Overload this FuncDeclaration with the new one f.
 * Return !=0 if successful; i.e. no conflict.
 */

int FuncDeclaration::overloadInsert(Dsymbol *s)
{
    FuncDeclaration *f;
    AliasDeclaration *a;

    //printf("FuncDeclaration::overloadInsert(%s)\n", s->toChars());
    a = s->isAliasDeclaration();
    if (a)
    {
	if (overnext)
	    return overnext->overloadInsert(a);
	if (!a->aliassym && a->type->ty != Tident && a->type->ty != Tinstance)
	{
	    //printf("\ta = '%s'\n", a->type->toChars());
	    return FALSE;
	}
	overnext = a;
	//printf("\ttrue: no conflict\n");
	return TRUE;
    }
    f = s->isFuncDeclaration();
    if (!f)
	return FALSE;

    if (type && f->type &&	// can be NULL for overloaded constructors
	f->type->covariant(type) &&
	!isFuncAliasDeclaration())
    {
	//printf("\tfalse: conflict %s\n", kind());
	return FALSE;
    }

    if (overnext)
	return overnext->overloadInsert(f);
    overnext = f;
    //printf("\ttrue: no conflict\n");
    return TRUE;
}

/********************************************
 * Find function in overload list that exactly matches t.
 */

/***************************************************
 * Visit each overloaded function in turn, and call
 * (*fp)(param, f) on it.
 * Exit when no more, or (*fp)(param, f) returns 1.
 * Returns:
 *	0	continue
 *	1	done
 */

int overloadApply(FuncDeclaration *fstart,
	int (*fp)(void *, FuncDeclaration *),
	void *param)
{
    FuncDeclaration *f;
    Declaration *d;
    Declaration *next;

    for (d = fstart; d; d = next)
    {	FuncAliasDeclaration *fa = d->isFuncAliasDeclaration();

	if (fa)
	{
	    if (overloadApply(fa->funcalias, fp, param))
		return 1;
	    next = fa->overnext;
	}
	else
	{
	    AliasDeclaration *a = d->isAliasDeclaration();

	    if (a)
	    {
		Dsymbol *s = a->toAlias();
		next = s->isDeclaration();
		if (next == a)
		    break;
		if (next == fstart)
		    break;
	    }
	    else
	    {
		f = d->isFuncDeclaration();
		if (!f)
		{   d->error("is aliased to a function");
		    break;		// BUG: should print error message?
		}
		if ((*fp)(param, f))
		    return 1;

		next = f->overnext;
	    }
	}
    }
    return 0;
}

/********************************************
 * Find function in overload list that exactly matches t.
 */

struct Param1
{
    Type *t;		// type to match
    FuncDeclaration *f;	// return value
};

int fp1(void *param, FuncDeclaration *f)
{   Param1 *p = (Param1 *)param;
    Type *t = p->t;

    if (t->equals(f->type))
    {	p->f = f;
	return 1;
    }

#if V2
    /* Allow covariant matches, if it's just a const conversion
     * of the return type
     */
    if (t->ty == Tfunction)
    {   TypeFunction *tf = (TypeFunction *)f->type;
	if (tf->covariant(t) == 1 &&
	    tf->nextOf()->implicitConvTo(t->nextOf()) >= MATCHconst)
	{
	    p->f = f;
	    return 1;
	}
    }
#endif
    return 0;
}

FuncDeclaration *FuncDeclaration::overloadExactMatch(Type *t)
{
    Param1 p;
    p.t = t;
    p.f = NULL;
    overloadApply(this, &fp1, &p);
    return p.f;
}

#if 0
FuncDeclaration *FuncDeclaration::overloadExactMatch(Type *t)
{
    FuncDeclaration *f;
    Declaration *d;
    Declaration *next;

    for (d = this; d; d = next)
    {	FuncAliasDeclaration *fa = d->isFuncAliasDeclaration();

	if (fa)
	{
	    FuncDeclaration *f2 = fa->funcalias->overloadExactMatch(t);
	    if (f2)
		return f2;
	    next = fa->overnext;
	}
	else
	{
	    AliasDeclaration *a = d->isAliasDeclaration();

	    if (a)
	    {
		Dsymbol *s = a->toAlias();
		next = s->isDeclaration();
		if (next == a)
		    break;
	    }
	    else
	    {
		f = d->isFuncDeclaration();
		if (!f)
		    break;		// BUG: should print error message?
		if (t->equals(d->type))
		    return f;
		next = f->overnext;
	    }
	}
    }
    return NULL;
}
#endif

/********************************************
 * Decide which function matches the arguments best.
 */

struct Param2
{
    Match *m;
    Expressions *arguments;
};

int fp2(void *param, FuncDeclaration *f)
{   Param2 *p = (Param2 *)param;
    Match *m = p->m;
    Expressions *arguments = p->arguments;
    MATCH match;

    if (f != m->lastf)		// skip duplicates
    {
	TypeFunction *tf;

	m->anyf = f;
	tf = (TypeFunction *)f->type;
	match = (MATCH) tf->callMatch(arguments);
	//printf("match = %d\n", match);
	if (match != MATCHnomatch)
	{
	    if (match > m->last)
		goto LfIsBetter;

	    if (match < m->last)
		goto LlastIsBetter;

	    /* See if one of the matches overrides the other.
	     */
	    if (m->lastf->overrides(f))
		goto LlastIsBetter;
	    else if (f->overrides(m->lastf))
		goto LfIsBetter;

	Lambiguous:
	    m->nextf = f;
	    m->count++;
	    return 0;

	LfIsBetter:
	    m->last = match;
	    m->lastf = f;
	    m->count = 1;
	    return 0;

	LlastIsBetter:
	    return 0;
	}
    }
    return 0;
}


void overloadResolveX(Match *m, FuncDeclaration *fstart, Expressions *arguments)
{
    Param2 p;
    p.m = m;
    p.arguments = arguments;
    overloadApply(fstart, &fp2, &p);
}

#if 0
// Recursive helper function

void overloadResolveX(Match *m, FuncDeclaration *fstart, Expressions *arguments)
{
    MATCH match;
    Declaration *d;
    Declaration *next;

    for (d = fstart; d; d = next)
    {
	FuncDeclaration *f;
	FuncAliasDeclaration *fa;
	AliasDeclaration *a;

	fa = d->isFuncAliasDeclaration();
	if (fa)
	{
	    overloadResolveX(m, fa->funcalias, arguments);
	    next = fa->overnext;
	}
	else if ((f = d->isFuncDeclaration()) != NULL)
	{
	    next = f->overnext;
	    if (f == m->lastf)
		continue;			// skip duplicates
	    else
	    {
		TypeFunction *tf;

		m->anyf = f;
		tf = (TypeFunction *)f->type;
		match = (MATCH) tf->callMatch(arguments);
		//printf("match = %d\n", match);
		if (match != MATCHnomatch)
		{
		    if (match > m->last)
			goto LfIsBetter;

		    if (match < m->last)
			goto LlastIsBetter;

		    /* See if one of the matches overrides the other.
		     */
		    if (m->lastf->overrides(f))
			goto LlastIsBetter;
		    else if (f->overrides(m->lastf))
			goto LfIsBetter;

		Lambiguous:
		    m->nextf = f;
		    m->count++;
		    continue;

		LfIsBetter:
		    m->last = match;
		    m->lastf = f;
		    m->count = 1;
		    continue;

		LlastIsBetter:
		    continue;
		}
	    }
	}
	else if ((a = d->isAliasDeclaration()) != NULL)
	{
	    Dsymbol *s = a->toAlias();
	    next = s->isDeclaration();
	    if (next == a)
		break;
	    if (next == fstart)
		break;
	}
	else
	{   d->error("is aliased to a function");
	    break;
	}
    }
}
#endif

FuncDeclaration *FuncDeclaration::overloadResolve(Loc loc, Expressions *arguments)
{
    TypeFunction *tf;
    Match m;

#if 0
printf("FuncDeclaration::overloadResolve('%s')\n", toChars());
if (arguments)
{   int i;

    for (i = 0; i < arguments->dim; i++)
    {   Expression *arg;

	arg = (Expression *)arguments->data[i];
	assert(arg->type);
	printf("\t%s: ", arg->toChars());
	arg->type->print();
    }
}
#endif

    memset(&m, 0, sizeof(m));
    m.last = MATCHnomatch;
    overloadResolveX(&m, this, arguments);

    if (m.count == 1)		// exactly one match
    {
	return m.lastf;
    }
    else
    {
	OutBuffer buf;

	if (arguments)
	{
	    HdrGenState hgs;

	    argExpTypesToCBuffer(&buf, arguments, &hgs);
	}

	if (m.last == MATCHnomatch)
	{
	    tf = (TypeFunction *)type;

	    //printf("tf = %s, args = %s\n", tf->deco, ((Expression *)arguments->data[0])->type->deco);
	    error(loc, "%s does not match parameter types (%s)",
		Argument::argsTypesToChars(tf->parameters, tf->varargs),
		buf.toChars());
	    return m.anyf;		// as long as it's not a FuncAliasDeclaration
	}
	else
	{
#if 1
	    TypeFunction *t1 = (TypeFunction *)m.lastf->type;
	    TypeFunction *t2 = (TypeFunction *)m.nextf->type;

	    error(loc, "called with argument types:\n\t(%s)\nmatches both:\n\t%s%s\nand:\n\t%s%s",
		    buf.toChars(),
		    m.lastf->toPrettyChars(), Argument::argsTypesToChars(t1->parameters, t1->varargs),
		    m.nextf->toPrettyChars(), Argument::argsTypesToChars(t2->parameters, t2->varargs));
#else
	    error(loc, "overloads %s and %s both match argument list for %s",
		    m.lastf->type->toChars(),
		    m.nextf->type->toChars(),
		    m.lastf->toChars());
#endif
	    return m.lastf;
	}
    }
}

/********************************
 * Labels are in a separate scope, one per function.
 */

LabelDsymbol *FuncDeclaration::searchLabel(Identifier *ident)
{   Dsymbol *s;

    if (!labtab)
	labtab = new DsymbolTable();	// guess we need one

    s = labtab->lookup(ident);
    if (!s)
    {
	s = new LabelDsymbol(ident);
	labtab->insert(s);
    }
    return (LabelDsymbol *)s;
}
/****************************************
 * If non-static member function that has a 'this' pointer,
 * return the aggregate it is a member of.
 * Otherwise, return NULL.
 */

AggregateDeclaration *FuncDeclaration::isThis()
{   AggregateDeclaration *ad;

    //printf("+FuncDeclaration::isThis() '%s'\n", toChars());
    ad = NULL;
    if ((storage_class & STCstatic) == 0)
    {
	ad = isMember2();
    }
    //printf("-FuncDeclaration::isThis() %p\n", ad);
    return ad;
}

AggregateDeclaration *FuncDeclaration::isMember2()
{   AggregateDeclaration *ad;

    //printf("+FuncDeclaration::isMember2() '%s'\n", toChars());
    ad = NULL;
    for (Dsymbol *s = this; s; s = s->parent)
    {
//printf("\ts = '%s', parent = '%s', kind = %s\n", s->toChars(), s->parent->toChars(), s->parent->kind());
	ad = s->isMember();
	if (ad)
{   //printf("test4\n");
	    break;
}
	if (!s->parent ||
	    (!s->parent->isTemplateInstance()))
{   //printf("test5\n");
	    break;
}
    }
    //printf("-FuncDeclaration::isMember2() %p\n", ad);
    return ad;
}

/*****************************************
 * Determine lexical level difference from 'this' to nested function 'fd'.
 * Error if this cannot call fd.
 * Returns:
 *	0	same level
 *	-1	increase nesting by 1 (fd is nested within 'this')
 *	>0	decrease nesting by number
 */

int FuncDeclaration::getLevel(Loc loc, FuncDeclaration *fd)
{   int level;
    Dsymbol *s;
    Dsymbol *fdparent;

    //printf("FuncDeclaration::getLevel(fd = '%s')\n", fd->toChars());
    fdparent = fd->toParent2();
    if (fdparent == this)
	return -1;
    s = this;
    level = 0;
    while (fd != s && fdparent != s->toParent2())
    {
	//printf("\ts = '%s'\n", s->toChars());
	FuncDeclaration *thisfd = s->isFuncDeclaration();
	if (thisfd)
	{   if (!thisfd->isNested() && !thisfd->vthis)
		goto Lerr;
	}
	else
	{
	    ClassDeclaration *thiscd = s->isClassDeclaration();
	    if (thiscd)
	    {	if (!thiscd->isNested())
		    goto Lerr;
	    }
	    else
		goto Lerr;
	}

	s = s->toParent2();
	assert(s);
	level++;
    }
    return level;

Lerr:
    error(loc, "cannot access frame of function %s", fd->toChars());
    return 1;
}

void FuncDeclaration::appendExp(Expression *e)
{   Statement *s;

    s = new ExpStatement(0, e);
    appendState(s);
}

void FuncDeclaration::appendState(Statement *s)
{   CompoundStatement *cs;

    if (!fbody)
    {	Statements *a;

	a = new Statements();
	fbody = new CompoundStatement(0, a);
    }
    cs = fbody->isCompoundStatement();
    cs->statements->push(s);
}


int FuncDeclaration::isMain()
{
    return ident == Id::main &&
	linkage != LINKc && !isMember() && !isNested();
}

int FuncDeclaration::isWinMain()
{
    return ident == Id::WinMain &&
	linkage != LINKc && !isMember();
}

int FuncDeclaration::isDllMain()
{
    return ident == Id::DllMain &&
	linkage != LINKc && !isMember();
}

int FuncDeclaration::isExport()
{
    return protection == PROTexport;
}

int FuncDeclaration::isImportedSymbol()
{
    //printf("isImportedSymbol()\n");
    //printf("protection = %d\n", protection);
    return (protection == PROTexport) && !fbody;
}

// Determine if function goes into virtual function pointer table

int FuncDeclaration::isVirtual()
{
#if 0
    printf("FuncDeclaration::isVirtual(%s)\n", toChars());
    printf("%p %d %d %d %d\n", isMember(), isStatic(), protection == PROTprivate, isCtorDeclaration(), linkage != LINKd);
    printf("result is %d\n",
	isMember() &&
	!(isStatic() || protection == PROTprivate || protection == PROTpackage) &&
	toParent()->isClassDeclaration());
#endif
    return isMember() &&
	!(isStatic() || protection == PROTprivate || protection == PROTpackage) &&
	toParent()->isClassDeclaration();
}

int FuncDeclaration::isAbstract()
{
    return storage_class & STCabstract;
}

int FuncDeclaration::isCodeseg()
{
    return TRUE;		// functions are always in the code segment
}

// Determine if function needs
// a static frame pointer to its lexically enclosing function

int FuncDeclaration::isNested()
{
    //if (!toParent())
	//printf("FuncDeclaration::isNested('%s') parent=%p\n", toChars(), parent);
    //printf("\ttoParent() = '%s'\n", toParent()->toChars());
    return ((storage_class & STCstatic) == 0) &&
	   (toParent2()->isFuncDeclaration() != NULL);
}

int FuncDeclaration::needThis()
{
    //printf("FuncDeclaration::needThis() '%s'\n", toChars());
    int i = isThis() != NULL;
    //printf("\t%d\n", i);
    if (!i && isFuncAliasDeclaration())
	i = ((FuncAliasDeclaration *)this)->funcalias->needThis();
    return i;
}

int FuncDeclaration::addPreInvariant()
{
    AggregateDeclaration *ad = isThis();
    return (ad &&
	    //ad->isClassDeclaration() &&
	    global.params.useInvariants &&
	    (protection == PROTpublic || protection == PROTexport) &&
	    !naked);
}

int FuncDeclaration::addPostInvariant()
{
    AggregateDeclaration *ad = isThis();
    return (ad &&
	    ad->inv &&
	    //ad->isClassDeclaration() &&
	    global.params.useInvariants &&
	    (protection == PROTpublic || protection == PROTexport) &&
	    !naked);
}

/**********************************
 * Generate a FuncDeclaration for a runtime library function.
 */

FuncDeclaration *FuncDeclaration::genCfunc(Type *treturn, char *name)
{
    return genCfunc(treturn, Lexer::idPool(name));
}

FuncDeclaration *FuncDeclaration::genCfunc(Type *treturn, Identifier *id)
{
    FuncDeclaration *fd;
    TypeFunction *tf;
    Dsymbol *s;
    static DsymbolTable *st = NULL;

    //printf("genCfunc(name = '%s')\n", id->toChars());
    //printf("treturn\n\t"); treturn->print();

    // See if already in table
    if (!st)
	st = new DsymbolTable();
    s = st->lookup(id);
    if (s)
    {
	fd = s->isFuncDeclaration();
	assert(fd);
	assert(fd->type->nextOf()->equals(treturn));
    }
    else
    {
	tf = new TypeFunction(NULL, treturn, 0, LINKc);
	fd = new FuncDeclaration(0, 0, id, STCstatic, tf);
	fd->protection = PROTpublic;
	fd->linkage = LINKc;

	st->insert(fd);
    }
    return fd;
}

char *FuncDeclaration::kind()
{
    return "function";
}
/*******************************
 * Look at all the variables in this function that are referenced
 * by nested functions, and determine if a closure needs to be
 * created for them.
 */

#if V2
int FuncDeclaration::needsClosure()
{
    /* Need a closure for all the closureVars[] if any of the
     * closureVars[] are accessed by a
     * function that escapes the scope of this function.
     * We take the conservative approach and decide that any function that:
     * 1) is a virtual function
     * 2) has its address taken
     * 3) has a parent that escapes
     * escapes.
     */

    //printf("FuncDeclaration::needsClosure() %s\n", toChars());
    for (int i = 0; i < closureVars.dim; i++)
    {	VarDeclaration *v = (VarDeclaration *)closureVars.data[i];
	assert(v->isVarDeclaration());
	//printf("\tv = %s\n", v->toChars());

	for (int j = 0; j < v->nestedrefs.dim; j++)
	{   FuncDeclaration *f = (FuncDeclaration *)v->nestedrefs.data[j];
	    assert(f != this);

	    //printf("\t\tf = %s, %d, %d\n", f->toChars(), f->isVirtual(), f->tookAddressOf);
	    if (f->isVirtual() || f->tookAddressOf)
		goto Lyes;	// assume f escapes this function's scope

	    // Look to see if any parents of f that are below this escape
	    for (Dsymbol *s = f->parent; s != this; s = s->parent)
	    {
		f = s->isFuncDeclaration();
		if (f && (f->isVirtual() || f->tookAddressOf))
		    goto Lyes;
	    }
	}
    }
    return 0;

Lyes:
    //printf("\tneeds closure\n");
    return 1;
}
#endif

/****************************** FuncAliasDeclaration ************************/

// Used as a way to import a set of functions from another scope into this one.

FuncAliasDeclaration::FuncAliasDeclaration(FuncDeclaration *funcalias)
    : FuncDeclaration(funcalias->loc, funcalias->endloc, funcalias->ident,
	(enum STC)funcalias->storage_class, funcalias->type)
{
    assert(funcalias != this);
    this->funcalias = funcalias;
}

char *FuncAliasDeclaration::kind()
{
    return "function alias";
}


/****************************** FuncLiteralDeclaration ************************/

FuncLiteralDeclaration::FuncLiteralDeclaration(Loc loc, Loc endloc, Type *type,
	enum TOK tok, ForeachStatement *fes)
    : FuncDeclaration(loc, endloc, NULL, STCundefined, type)
{
    char *id;

    if (fes)
	id = "__foreachbody";
    else if (tok == TOKdelegate)
	id = "__dgliteral";
    else
	id = "__funcliteral";
    this->ident = Identifier::generateId(id);
    this->tok = tok;
    this->fes = fes;
    //printf("FuncLiteralDeclaration() id = '%s', type = '%s'\n", this->ident->toChars(), type->toChars());
}

Dsymbol *FuncLiteralDeclaration::syntaxCopy(Dsymbol *s)
{
    FuncLiteralDeclaration *f;

    //printf("FuncLiteralDeclaration::syntaxCopy('%s')\n", toChars());
    if (s)
	f = (FuncLiteralDeclaration *)s;
    else
	f = new FuncLiteralDeclaration(loc, endloc, type->syntaxCopy(), tok, fes);
    FuncDeclaration::syntaxCopy(f);
    return f;
}

int FuncLiteralDeclaration::isNested()
{
    //printf("FuncLiteralDeclaration::isNested() '%s'\n", toChars());
    return (tok == TOKdelegate);
}

char *FuncLiteralDeclaration::kind()
{
    // GCC requires the (char*) casts
    return (tok == TOKdelegate) ? (char*)"delegate" : (char*)"function";
}

void FuncLiteralDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    static Identifier *idfunc;
    static Identifier *iddel;

    if (!idfunc)
	idfunc = new Identifier("function", 0);
    if (!iddel)
	iddel = new Identifier("delegate", 0);

    type->toCBuffer(buf, ((tok == TOKdelegate) ? iddel : idfunc), hgs);
    bodyToCBuffer(buf, hgs);
}


/********************************* CtorDeclaration ****************************/

CtorDeclaration::CtorDeclaration(Loc loc, Loc endloc, Arguments *arguments, int varargs)
    : FuncDeclaration(loc, endloc, Id::ctor, STCundefined, NULL)
{
    this->arguments = arguments;
    this->varargs = varargs;
    //printf("CtorDeclaration() %s\n", toChars());
}

Dsymbol *CtorDeclaration::syntaxCopy(Dsymbol *s)
{
    CtorDeclaration *f;

    f = new CtorDeclaration(loc, endloc, NULL, varargs);

    f->outId = outId;
    f->frequire = frequire ? frequire->syntaxCopy() : NULL;
    f->fensure  = fensure  ? fensure->syntaxCopy()  : NULL;
    f->fbody    = fbody    ? fbody->syntaxCopy()    : NULL;
    assert(!fthrows); // deprecated

    f->arguments = Argument::arraySyntaxCopy(arguments);
    return f;
}


void CtorDeclaration::semantic(Scope *sc)
{
    ClassDeclaration *cd;
    Type *tret;

    //printf("CtorDeclaration::semantic()\n");
    if (type)
	return;

    sc = sc->push();
    sc->stc &= ~STCstatic;		// not a static constructor

    parent = sc->parent;
    Dsymbol *parent = toParent();
    cd = parent->isClassDeclaration();
    if (!cd)
    {
	error("constructors are only for class definitions");
	tret = Type::tvoid;
    }
    else
	tret = cd->type; //->referenceTo();
    type = new TypeFunction(arguments, tret, varargs, LINKd);

    sc->flags |= SCOPEctor;
    type = type->semantic(loc, sc);
    sc->flags &= ~SCOPEctor;

    // Append:
    //	return this;
    // to the function body
    if (fbody)
    {	Expression *e;
	Statement *s;

	e = new ThisExp(0);
	s = new ReturnStatement(0, e);
	fbody = new CompoundStatement(0, fbody, s);
    }

    FuncDeclaration::semantic(sc);

    sc->pop();

    // See if it's the default constructor
    if (cd && varargs == 0 && Argument::dim(arguments) == 0)
	cd->defaultCtor = this;
}

char *CtorDeclaration::kind()
{
    return "constructor";
}

char *CtorDeclaration::toChars()
{
    return "this";
}

int CtorDeclaration::isVirtual()
{
    return FALSE;
}

int CtorDeclaration::addPreInvariant()
{
    return FALSE;
}

int CtorDeclaration::addPostInvariant()
{
    return (vthis && global.params.useInvariants);
}


void CtorDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("this");
    Argument::argsToCBuffer(buf, hgs, arguments, varargs);
    bodyToCBuffer(buf, hgs);
}

/********************************* DtorDeclaration ****************************/

DtorDeclaration::DtorDeclaration(Loc loc, Loc endloc)
    : FuncDeclaration(loc, endloc, Id::dtor, STCundefined, NULL)
{
}

DtorDeclaration::DtorDeclaration(Loc loc, Loc endloc, Identifier *id)
    : FuncDeclaration(loc, endloc, id, STCundefined, NULL)
{
}

Dsymbol *DtorDeclaration::syntaxCopy(Dsymbol *s)
{
    assert(!s);
    DtorDeclaration *dd = new DtorDeclaration(loc, endloc, ident);
    return FuncDeclaration::syntaxCopy(dd);
}


void DtorDeclaration::semantic(Scope *sc)
{
    ClassDeclaration *cd;

    parent = sc->parent;
    Dsymbol *parent = toParent();
    cd = parent->isClassDeclaration();
    if (!cd)
    {
	error("destructors only are for class definitions");
    }
    else
	cd->dtors.push(this);
    type = new TypeFunction(NULL, Type::tvoid, FALSE, LINKd);

    sc = sc->push();
    sc->stc &= ~STCstatic;		// not a static destructor
    sc->linkage = LINKd;

    FuncDeclaration::semantic(sc);

    sc->pop();
}

int DtorDeclaration::overloadInsert(Dsymbol *s)
{
    return FALSE;	// cannot overload destructors
}

int DtorDeclaration::addPreInvariant()
{
    return (vthis && global.params.useInvariants);
}

int DtorDeclaration::addPostInvariant()
{
    return FALSE;
}

int DtorDeclaration::isVirtual()
{
    /* This should be FALSE so that dtor's don't get put into the vtbl[],
     * but doing so will require recompiling everything.
     */
#if BREAKABI
    return FALSE;
#else
    return FuncDeclaration::isVirtual();
#endif
}

void DtorDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    if (hgs->hdrgen)
	return;
    buf->writestring("~this()");
    bodyToCBuffer(buf, hgs);
}

/********************************* StaticCtorDeclaration ****************************/

StaticCtorDeclaration::StaticCtorDeclaration(Loc loc, Loc endloc)
    : FuncDeclaration(loc, endloc,
      Identifier::generateId("_staticCtor"), STCstatic, NULL)
{
}

Dsymbol *StaticCtorDeclaration::syntaxCopy(Dsymbol *s)
{
    StaticCtorDeclaration *scd;

    assert(!s);
    scd = new StaticCtorDeclaration(loc, endloc);
    return FuncDeclaration::syntaxCopy(scd);
}


void StaticCtorDeclaration::semantic(Scope *sc)
{
    //printf("StaticCtorDeclaration::semantic()\n");

    type = new TypeFunction(NULL, Type::tvoid, FALSE, LINKd);

    FuncDeclaration::semantic(sc);

    // We're going to need ModuleInfo
    Module *m = getModule();
    if (!m)
	m = sc->module;
    if (m)
    {	m->needmoduleinfo = 1;
#ifdef IN_GCC
	m->strictlyneedmoduleinfo = 1;
#endif
    }
}

AggregateDeclaration *StaticCtorDeclaration::isThis()
{
    return NULL;
}

int StaticCtorDeclaration::isStaticConstructor()
{
    return TRUE;
}

int StaticCtorDeclaration::isVirtual()
{
    return FALSE;
}

int StaticCtorDeclaration::addPreInvariant()
{
    return FALSE;
}

int StaticCtorDeclaration::addPostInvariant()
{
    return FALSE;
}

void StaticCtorDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    if (hgs->hdrgen)
    {	buf->writestring("static this();\n");
	return;
    }
    buf->writestring("static this()");
    bodyToCBuffer(buf, hgs);
}

/********************************* StaticDtorDeclaration ****************************/

StaticDtorDeclaration::StaticDtorDeclaration(Loc loc, Loc endloc)
    : FuncDeclaration(loc, endloc,
      Identifier::generateId("_staticDtor"), STCstatic, NULL)
{
}

Dsymbol *StaticDtorDeclaration::syntaxCopy(Dsymbol *s)
{
    StaticDtorDeclaration *sdd;

    assert(!s);
    sdd = new StaticDtorDeclaration(loc, endloc);
    return FuncDeclaration::syntaxCopy(sdd);
}


void StaticDtorDeclaration::semantic(Scope *sc)
{
    ClassDeclaration *cd;
    Type *tret;

    cd = sc->scopesym->isClassDeclaration();
    if (!cd)
    {
    }
    type = new TypeFunction(NULL, Type::tvoid, FALSE, LINKd);

    FuncDeclaration::semantic(sc);

    // We're going to need ModuleInfo
    Module *m = getModule();
    if (!m)
	m = sc->module;
    if (m)
    {	m->needmoduleinfo = 1;
#ifdef IN_GCC
	m->strictlyneedmoduleinfo = 1;
#endif
    }
}

AggregateDeclaration *StaticDtorDeclaration::isThis()
{
    return NULL;
}

int StaticDtorDeclaration::isStaticDestructor()
{
    return TRUE;
}

int StaticDtorDeclaration::isVirtual()
{
    return FALSE;
}

int StaticDtorDeclaration::addPreInvariant()
{
    return FALSE;
}

int StaticDtorDeclaration::addPostInvariant()
{
    return FALSE;
}

void StaticDtorDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    if (hgs->hdrgen)
	return;
    buf->writestring("static ~this()");
    bodyToCBuffer(buf, hgs);
}

/********************************* InvariantDeclaration ****************************/

InvariantDeclaration::InvariantDeclaration(Loc loc, Loc endloc)
    : FuncDeclaration(loc, endloc, Id::classInvariant, STCundefined, NULL)
{
}

Dsymbol *InvariantDeclaration::syntaxCopy(Dsymbol *s)
{
    InvariantDeclaration *id;

    assert(!s);
    id = new InvariantDeclaration(loc, endloc);
    FuncDeclaration::syntaxCopy(id);
    return id;
}


void InvariantDeclaration::semantic(Scope *sc)
{
    AggregateDeclaration *ad;
    Type *tret;

    parent = sc->parent;
    Dsymbol *parent = toParent();
    ad = parent->isAggregateDeclaration();
    if (!ad)
    {
	error("invariants only are for struct/union/class definitions");
	return;
    }
    else if (ad->inv && ad->inv != this)
    {
	error("more than one invariant for %s", ad->toChars());
    }
    ad->inv = this;
    type = new TypeFunction(NULL, Type::tvoid, FALSE, LINKd);

    sc = sc->push();
    sc->stc &= ~STCstatic;		// not a static invariant
    sc->incontract++;
    sc->linkage = LINKd;

    FuncDeclaration::semantic(sc);

    sc->pop();
}

int InvariantDeclaration::isVirtual()
{
    return FALSE;
}

int InvariantDeclaration::addPreInvariant()
{
    return FALSE;
}

int InvariantDeclaration::addPostInvariant()
{
    return FALSE;
}

void InvariantDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    if (hgs->hdrgen)
	return;
    buf->writestring("invariant");
    bodyToCBuffer(buf, hgs);
}


/********************************* UnitTestDeclaration ****************************/

/*******************************
 * Generate unique unittest function Id so we can have multiple
 * instances per module.
 */

static Identifier *unitTestId()
{
    static int n;
    char buffer[10 + sizeof(n)*3 + 1];

    sprintf(buffer,"__unittest%d", n);
    n++;
    return Lexer::idPool(buffer);
}

UnitTestDeclaration::UnitTestDeclaration(Loc loc, Loc endloc)
    : FuncDeclaration(loc, endloc, unitTestId(), STCundefined, NULL)
{
}

Dsymbol *UnitTestDeclaration::syntaxCopy(Dsymbol *s)
{
    UnitTestDeclaration *utd;

    assert(!s);
    utd = new UnitTestDeclaration(loc, endloc);
    return FuncDeclaration::syntaxCopy(utd);
}


void UnitTestDeclaration::semantic(Scope *sc)
{
    if (global.params.useUnitTests)
    {
	Type *tret;

	type = new TypeFunction(NULL, Type::tvoid, FALSE, LINKd);
	FuncDeclaration::semantic(sc);
    }

    // We're going to need ModuleInfo even if the unit tests are not
    // compiled in, because other modules may import this module and refer
    // to this ModuleInfo.
    Module *m = getModule();
    if (!m)
	m = sc->module;
    if (m)
	m->needmoduleinfo = 1;
}

AggregateDeclaration *UnitTestDeclaration::isThis()
{
    return NULL;
}

int UnitTestDeclaration::isVirtual()
{
    return FALSE;
}

int UnitTestDeclaration::addPreInvariant()
{
    return FALSE;
}

int UnitTestDeclaration::addPostInvariant()
{
    return FALSE;
}

void UnitTestDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    if (hgs->hdrgen)
	return;
    buf->writestring("unittest");
    bodyToCBuffer(buf, hgs);
}

/********************************* NewDeclaration ****************************/

NewDeclaration::NewDeclaration(Loc loc, Loc endloc, Arguments *arguments, int varargs)
    : FuncDeclaration(loc, endloc, Id::classNew, STCstatic, NULL)
{
    this->arguments = arguments;
    this->varargs = varargs;
}

Dsymbol *NewDeclaration::syntaxCopy(Dsymbol *s)
{
    NewDeclaration *f;

    f = new NewDeclaration(loc, endloc, NULL, varargs);

    FuncDeclaration::syntaxCopy(f);

    f->arguments = Argument::arraySyntaxCopy(arguments);

    return f;
}


void NewDeclaration::semantic(Scope *sc)
{
    ClassDeclaration *cd;
    Type *tret;

    //printf("NewDeclaration::semantic()\n");

    parent = sc->parent;
    Dsymbol *parent = toParent();
    cd = parent->isClassDeclaration();
    if (!cd && !parent->isStructDeclaration())
    {
	error("new allocators only are for class or struct definitions");
    }
    tret = Type::tvoid->pointerTo();
    type = new TypeFunction(arguments, tret, varargs, LINKd);

    type = type->semantic(loc, sc);
    assert(type->ty == Tfunction);

    // Check that there is at least one argument of type uint
    TypeFunction *tf = (TypeFunction *)type;
    if (Argument::dim(tf->parameters) < 1)
    {
	error("at least one argument of type uint expected");
    }
    else
    {
	Argument *a = Argument::getNth(tf->parameters, 0);
	if (!a->type->equals(Type::tuns32))
	    error("first argument must be type uint, not %s", a->type->toChars());
    }

    FuncDeclaration::semantic(sc);
}

char *NewDeclaration::kind()
{
    return "allocator";
}

int NewDeclaration::isVirtual()
{
    return FALSE;
}

int NewDeclaration::addPreInvariant()
{
    return FALSE;
}

int NewDeclaration::addPostInvariant()
{
    return FALSE;
}

void NewDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("new");
    Argument::argsToCBuffer(buf, hgs, arguments, varargs);
    bodyToCBuffer(buf, hgs);
}


/********************************* DeleteDeclaration ****************************/

DeleteDeclaration::DeleteDeclaration(Loc loc, Loc endloc, Arguments *arguments)
    : FuncDeclaration(loc, endloc, Id::classDelete, STCstatic, NULL)
{
    this->arguments = arguments;
}

Dsymbol *DeleteDeclaration::syntaxCopy(Dsymbol *s)
{
    DeleteDeclaration *f;

    f = new DeleteDeclaration(loc, endloc, NULL);

    FuncDeclaration::syntaxCopy(f);

    f->arguments = Argument::arraySyntaxCopy(arguments);

    return f;
}


void DeleteDeclaration::semantic(Scope *sc)
{
    ClassDeclaration *cd;

    //printf("DeleteDeclaration::semantic()\n");

    parent = sc->parent;
    Dsymbol *parent = toParent();
    cd = parent->isClassDeclaration();
    if (!cd && !parent->isStructDeclaration())
    {
	error("new allocators only are for class or struct definitions");
    }
    type = new TypeFunction(arguments, Type::tvoid, 0, LINKd);

    type = type->semantic(loc, sc);
    assert(type->ty == Tfunction);

    // Check that there is only one argument of type void*
    TypeFunction *tf = (TypeFunction *)type;
    if (Argument::dim(tf->parameters) != 1)
    {
	error("one argument of type void* expected");
    }
    else
    {
	Argument *a = Argument::getNth(tf->parameters, 0);
	if (!a->type->equals(Type::tvoid->pointerTo()))
	    error("one argument of type void* expected, not %s", a->type->toChars());
    }

    FuncDeclaration::semantic(sc);
}

char *DeleteDeclaration::kind()
{
    return "deallocator";
}

int DeleteDeclaration::isDelete()
{
    return TRUE;
}

int DeleteDeclaration::isVirtual()
{
    return FALSE;
}

int DeleteDeclaration::addPreInvariant()
{
    return FALSE;
}

int DeleteDeclaration::addPostInvariant()
{
    return FALSE;
}

void DeleteDeclaration::toCBuffer(OutBuffer *buf, HdrGenState *hgs)
{
    buf->writestring("delete");
    Argument::argsToCBuffer(buf, hgs, arguments, 0);
    bodyToCBuffer(buf, hgs);
}




