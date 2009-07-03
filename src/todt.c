
// Copyright (c) 1999-2005 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

/* A dt_t is a simple structure representing data to be added
 * to the data segment of the output object file. As such,
 * it is a list of initialized bytes, 0 data, and offsets from
 * other symbols.
 * Each D symbol and type can be converted into a dt_t so it can
 * be written to the data segment.
 */

#include	<stdio.h>
#include	<string.h>
#include	<time.h>
#include	<assert.h>
#include	<complex.h>

#include	"lexer.h"
#include	"mtype.h"
#include	"expression.h"
#include	"init.h"
#include	"enum.h"
#include	"aggregate.h"
#include	"declaration.h"


// Back end
#include	"cc.h"
#include	"el.h"
#include	"oper.h"
#include	"global.h"
#include	"code.h"
#include	"type.h"
#include	"dt.h"

extern Symbol *static_sym();

/* ================================================================ */

dt_t *Initializer::toDt()
{
    assert(0);
    return NULL;
}


dt_t *VoidInitializer::toDt()
{   /* Void initializers are set to 0, just because we need something
     * to set them to in the static data segment.
     */
    dt_t *dt = NULL;

    dtnzeros(&dt, type->size());
    return dt;
}


dt_t *StructInitializer::toDt()
{
    Array dts;
    unsigned i;
    unsigned j;
    dt_t *dt;
    dt_t *d;
    dt_t **pdtend;
    unsigned offset;

    //printf("StructInitializer::toDt('%s')\n", toChars());
    dts.setDim(ad->fields.dim);
    dts.zero();

    for (i = 0; i < field.dim; i++)
    {
	VarDeclaration *v = (VarDeclaration *)field.data[i];
	Initializer *val = (Initializer *)value.data[i];

	//printf("field[%d] = %s\n", i, v->toChars());

	for (j = 0; 1; j++)
	{
	    assert(j < dts.dim);
	    //printf(" adfield[%d] = %s\n", j, ((VarDeclaration *)ad->fields.data[j])->toChars());
	    if ((VarDeclaration *)ad->fields.data[j] == v)
	    {
		if (dts.data[j])
		    error("field %s of %s already initialized", v->toChars(), ad->toChars());
		dts.data[j] = (void *)val->toDt();
		break;
	    }
	}
    }

    dt = NULL;
    pdtend = &dt;
    offset = 0;
    for (j = 0; j < dts.dim; j++)
    {
	VarDeclaration *v = (VarDeclaration *)ad->fields.data[j];

	d = (dt_t *)dts.data[j];
	if (!d)
	{   // An instance specific initializer was not provided.
	    // Look to see if there's a default initializer from the
	    // struct definition
	    VarDeclaration *v = (VarDeclaration *)ad->fields.data[j];

	    if (v->init)
	    {
		d = v->init->toDt();
	    }
	    else if (v->offset >= offset)
	    {
		unsigned k;
		unsigned offset2 = v->offset + v->type->size();
		// Make sure this field does not overlap any explicitly
		// initialized field.
		for (k = j + 1; 1; k++)
		{
		    if (k == dts.dim)		// didn't find any overlap
		    {	v->type->toDt(&d);	// provide default initializer
			break;
		    }
		    VarDeclaration *v2 = (VarDeclaration *)ad->fields.data[k];

		    if (v2->offset < offset2 && dts.data[k])
			break;			// overlap
		}
	    }
	}
	if (d)
	{
	    if (v->offset < offset)
		error("duplicate union initialization for %s", v->toChars());
	    else
	    {	unsigned sz = dt_size(d);

		if (offset < v->offset)
		    pdtend = dtnzeros(pdtend, v->offset - offset);
		pdtend = dtcat(pdtend, d);
		assert(sz <= v->type->size());
		offset = v->offset + sz;
	    }
	}
    }
    if (offset < ad->structsize)
	dtnzeros(pdtend, ad->structsize - offset);

    return dt;
}


dt_t *ArrayInitializer::toDt()
{
    //printf("ArrayInitializer::toDt('%s')\n", toChars());
    Type *tb = type->toBasetype();
    Type *tn = tb->next->toBasetype();

    if (tn->ty == Tbit)
	return toDtBit();

    Array dts;
    unsigned size;
    unsigned length;
    unsigned i;
    dt_t *dt;
    dt_t *d;
    dt_t **pdtend;

    //printf("\tdim = %d\n", dim);
    dts.setDim(dim);
    dts.zero();

    size = tn->size();

    length = 0;
    for (i = 0; i < index.dim; i++)
    {	Expression *idx;
	Initializer *val;

	idx = (Expression *)index.data[i];
	if (idx)
	    length = idx->toInteger();
	//printf("\tindex[%d] = %p, length = %u, dim = %u\n", i, idx, length, dim);

	assert(length < dim);
	val = (Initializer *)value.data[i];
	dt = val->toDt();
	if (dts.data[length])
	    error("duplicate initializations for index %d", length);
	dts.data[length] = (void *)dt;
	length++;
    }

    Expression *edefault = tb->next->defaultInit();

    unsigned n = 1;
    for (Type *tbn = tn; tbn->ty == Tsarray; tbn = tbn->next->toBasetype())
    {	TypeSArray *tsa = (TypeSArray *)tbn;

	n *= tsa->dim->toInteger();
    }

    d = NULL;
    pdtend = &d;
    for (i = 0; i < dim; i++)
    {
	dt = (dt_t *)dts.data[i];
	if (dt)
	    pdtend = dtcat(pdtend, dt);
	else
	{
	    for (int j = 0; j < n; j++)
		pdtend = edefault->toDt(pdtend);
	}
    }
    switch (tb->ty)
    {
	case Tsarray:
	{   unsigned tadim;
	    TypeSArray *ta = (TypeSArray *)tb;

	    tadim = ta->dim->toInteger();
	    if (dim < tadim)
	    {
		if (edefault->isBool(FALSE))
		    // pad out end of array
		    pdtend = dtnzeros(pdtend, size * (tadim - dim));
		else
		{
		    for (i = dim; i < tadim; i++)
		    {	for (int j = 0; j < n; j++)
			    pdtend = edefault->toDt(pdtend);
		    }
		}
	    }
	    else if (dim > tadim)
		error("too many initializers %d for array[%d]", dim, tadim);
	    break;
	}

	case Tpointer:
	case Tarray:
	    // Create symbol, and then refer to it
	    Symbol *s;
	    s = static_sym();
	    s->Sdt = d;
	    outdata(s);

	    d = NULL;
	    if (tb->ty == Tarray)
		dtdword(&d, dim);
	    dtxoff(&d, s, 0, TYnptr);
	    break;

	default:
	    assert(0);
    }
    return d;
}


dt_t *ArrayInitializer::toDtBit()
{
    unsigned size;
    unsigned length;
    unsigned i;
    unsigned tadim;
    dt_t *d;
    dt_t **pdtend;
    Type *tb = type->toBasetype();

    //printf("ArrayInitializer::toDtBit('%s')\n", toChars());

    Bits databits;
    Bits initbits;

    if (tb->ty == Tsarray)
    {
	/* The 'dim' for ArrayInitializer is only the maximum dimension
	 * seen in the initializer, not the type. So, for static arrays,
	 * use instead the dimension of the type in order
	 * to get the whole thing.
	 */
	integer_t value = ((TypeSArray*)tb)->dim->toInteger();
	tadim = value;
	assert(tadim == value);	 // truncation overflow should already be checked
	databits.resize(tadim);
	initbits.resize(tadim);
    }
    else
    {
	databits.resize(dim);
	initbits.resize(dim);
    }

    /* The default initializer may be something other than zero.
     */
    if (tb->next->defaultInit()->toInteger())
       databits.set();

    size = sizeof(databits.data[0]);

    length = 0;
    for (i = 0; i < index.dim; i++)
    {	Expression *idx;
	Initializer *val;
	Expression *eval;

	idx = (Expression *)index.data[i];
	if (idx)
	{   integer_t value;
	    value = idx->toInteger();
	    length = value;
	    if (length != value)
	    {	error("index overflow %llu", value);
		length = 0;
	    }
	}
	assert(length < dim);

	val = (Initializer *)value.data[i];
	eval = val->toExpression();
	if (initbits.test(length))
	    error("duplicate initializations for index %d", length);
	initbits.set(length);
	if (eval->toInteger())		// any non-zero value is boolean 'true'
	    databits.set(length);
	else
	    databits.clear(length);	// boolean 'false'
	length++;
    }

    d = NULL;
    pdtend = dtnbytes(&d, databits.allocdim * size, (char *)databits.data);
    switch (tb->ty)
    {
	case Tsarray:
	{
	    if (dim > tadim)
		error("too many initializers %d for array[%d]", dim, tadim);
	    else
	    {
		tadim = (tadim + 31) / 32;
		if (databits.allocdim < tadim)
		    pdtend = dtnzeros(pdtend, size * (tadim - databits.allocdim));	// pad out end of array
	    }
	    break;
	}

	case Tpointer:
	case Tarray:
	    // Create symbol, and then refer to it
	    Symbol *s;
	    s = static_sym();
	    s->Sdt = d;
	    outdata(s);

	    d = NULL;
	    if (tb->ty == Tarray)
		dtdword(&d, dim);
	    dtxoff(&d, s, 0, TYnptr);
	    break;

	default:
	    assert(0);
    }
    return d;
}


dt_t *ExpInitializer::toDt()
{
    dt_t *dt = NULL;

    exp = exp->optimize(WANTvalue);
    exp->toDt(&dt);
    return dt;
}

/* ================================================================ */

dt_t **Expression::toDt(dt_t **pdt)
{
#ifdef DEBUG
    printf("Expression::toDt() %d\n", op);
#endif
    error("non-constant expression %s", toChars());
    pdt = dtnzeros(pdt, 1);
    return pdt;
}

dt_t **IntegerExp::toDt(dt_t **pdt)
{   unsigned sz;

    //printf("IntegerExp::toDt() %d\n", op);
    sz = type->size();
    if (value == 0)
	pdt = dtnzeros(pdt, sz);
    else
	pdt = dtnbytes(pdt, sz, (char *)&value);
    return pdt;
}

static char zeropad[2];

dt_t **RealExp::toDt(dt_t **pdt)
{
    d_float32 fvalue;
    d_float64 dvalue;
    d_float80 evalue;

    //printf("RealExp::toDt(%Lg)\n", value);
    switch (type->toBasetype()->ty)
    {
	case Tfloat32:
	case Timaginary32:
	    fvalue = value;
	    pdt = dtnbytes(pdt,4,(char *)&fvalue);
	    break;

	case Tfloat64:
	case Timaginary64:
	    dvalue = value;
	    pdt = dtnbytes(pdt,8,(char *)&dvalue);
	    break;

	case Tfloat80:
	case Timaginary80:
	    evalue = value;
	    pdt = dtnbytes(pdt,REALSIZE - REALPAD,(char *)&evalue);
	    pdt = dtnbytes(pdt,REALPAD,zeropad);
	    break;

	default:
	    printf("%s\n", toChars());
	    type->print();
	    assert(0);
	    break;
    }
    return pdt;
}

dt_t **ComplexExp::toDt(dt_t **pdt)
{
    //printf("ComplexExp::toDt() '%s'\n", toChars());
    d_float32 fvalue;
    d_float64 dvalue;
    d_float80 evalue;

    switch (type->toBasetype()->ty)
    {
	case Tcomplex32:
	    fvalue = creall(value);
	    pdt = dtnbytes(pdt,4,(char *)&fvalue);
	    fvalue = cimagl(value);
	    pdt = dtnbytes(pdt,4,(char *)&fvalue);
	    break;

	case Tcomplex64:
	    dvalue = creall(value);
	    pdt = dtnbytes(pdt,8,(char *)&dvalue);
	    dvalue = cimagl(value);
	    pdt = dtnbytes(pdt,8,(char *)&dvalue);
	    break;

	case Tcomplex80:
	    evalue = creall(value);
	    pdt = dtnbytes(pdt,REALSIZE - REALPAD,(char *)&evalue);
	    pdt = dtnbytes(pdt,REALPAD,zeropad);
	    evalue = cimagl(value);
	    pdt = dtnbytes(pdt,REALSIZE - REALPAD,(char *)&evalue);
	    pdt = dtnbytes(pdt,REALPAD,zeropad);
	    break;

	default:
	    assert(0);
	    break;
    }
    return pdt;
}

dt_t **NullExp::toDt(dt_t **pdt)
{
    assert(type);
    return dtnzeros(pdt, type->size());
}

dt_t **StringExp::toDt(dt_t **pdt)
{
    Type *t = type->toBasetype();

    // BUG: should implement some form of static string pooling
    switch (t->ty)
    {
	case Tarray:
	    dtdword(pdt, len);
	    pdt = dtabytes(pdt, TYnptr, 0, (len + 1) * sz, (char *)string);
	    break;

	case Tsarray:
	{   TypeSArray *tsa = (TypeSArray *)type;
	    integer_t dim;

	    pdt = dtnbytes(pdt, len * sz, (char *)string);
	    if (tsa->dim)
	    {
		dim = tsa->dim->toInteger();
		if (len < dim)
		{
		    // Pad remainder with 0
		    pdt = dtnzeros(pdt, (dim - len) * tsa->next->size());
		}
	    }
	    break;
	}
	case Tpointer:
	    pdt = dtabytes(pdt, TYnptr, 0, (len + 1) * sz, (char *)string);
	    break;

	default:
	    printf("StringExp::toDt(type = %s)\n", type->toChars());
	    assert(0);
    }
    return pdt;
}

dt_t **SymOffExp::toDt(dt_t **pdt)
{
    Symbol *s;

    //printf("SymOffExp::toDt('%s')\n", var->toChars());
    assert(var);
    if (!(var->isDataseg() || var->isCodeseg()) || var->needThis())
    {
#ifdef DEBUG
	printf("SymOffExp::toDt()\n");
#endif
	error("non-constant expression %s", toChars());
	return pdt;
    }
    s = var->toSymbol();
    return dtxoff(pdt, s, offset, TYnptr);
}

dt_t **VarExp::toDt(dt_t **pdt)
{
    //printf("VarExp::toDt() %d\n", op);
    for (; *pdt; pdt = &((*pdt)->DTnext))
	;

    VarDeclaration *v = var->isVarDeclaration();
    if (v && v->isConst() && type->toBasetype()->ty != Tsarray && v->init)
    {
	*pdt = v->init->toDt();
	return pdt;
    }
    SymbolDeclaration *sd = var->isSymbolDeclaration();
    if (sd && sd->dsym)
    {
	sd->dsym->toDt(pdt);
	return pdt;
    }
#ifdef DEBUG
    printf("VarExp::toDt(), kind = %s\n", var->kind());
#endif
    error("non-constant expression %s", toChars());
    pdt = dtnzeros(pdt, 1);
    return pdt;
}

/* ================================================================= */

// Generate the data for the static initializer.

void ClassDeclaration::toDt(dt_t **pdt)
{
    //printf("ClassDeclaration::toDt(this = '%s')\n", toChars());

    // Put in first two members, the vtbl[] and the monitor
    dtxoff(pdt, toVtblSymbol(), 0, TYnptr);
    dtdword(pdt, 0);			// monitor

    // Put in the rest
    toDt2(pdt, this);

    //printf("-ClassDeclaration::toDt(this = '%s')\n", toChars());
}

void ClassDeclaration::toDt2(dt_t **pdt, ClassDeclaration *cd)
{
    unsigned offset;
    unsigned i;
    dt_t *dt;
    unsigned csymoffset;

#define LOG 0

#if LOG
    printf("ClassDeclaration::toDt2(this = '%s', cd = '%s')\n", toChars(), cd->toChars());
#endif
    if (baseClass)
    {
	baseClass->toDt2(pdt, cd);
	offset = baseClass->structsize;
    }
    else
    {
	offset = 8;
    }

    // Note equivalence of this loop to struct's
    for (i = 0; i < fields.dim; i++)
    {
	VarDeclaration *v = (VarDeclaration *)fields.data[i];
	Initializer *init;

	//printf("\t\tv = '%s' v->offset = %2d, offset = %2d\n", v->toChars(), v->offset, offset);
	dt = NULL;
	init = v->init;
	if (init)
	{   //printf("\t\t%s has initializer %s\n", v->toChars(), init->toChars());
	    dt = init->toDt();
	}
	else if (v->offset >= offset)
	{   //printf("\t\tdefault initializer\n");
	    v->type->toDt(&dt);
	}
	if (dt)
	{
	    if (v->offset < offset)
		error("2duplicate union initialization for %s", v->toChars());
	    else
	    {
		if (offset < v->offset)
		    dtnzeros(pdt, v->offset - offset);
		dtcat(pdt, dt);
		offset = v->offset + v->type->size();
	    }
	}
    }

    // Interface vptr initializations
    toSymbol();						// define csym

    for (i = 0; i < vtblInterfaces->dim; i++)
    {	BaseClass *b = (BaseClass *)vtblInterfaces->data[i];

#if 1 || INTERFACE_VIRTUAL
	for (ClassDeclaration *cd2 = cd; 1; cd2 = cd2->baseClass)
	{
	    assert(cd2);
	    csymoffset = cd2->baseVtblOffset(b);
	    if (csymoffset != ~0)
	    {
		if (offset < b->offset)
		    dtnzeros(pdt, b->offset - offset);
		dtxoff(pdt, cd2->toSymbol(), csymoffset, TYnptr);
		break;
	    }
	}
#else
	csymoffset = baseVtblOffset(b);
	assert(csymoffset != ~0);
	dtxoff(pdt, csym, csymoffset, TYnptr);
#endif
	offset = b->offset + 4;
    }

    if (offset < structsize)
	dtnzeros(pdt, structsize - offset);

#undef LOG
}

void StructDeclaration::toDt(dt_t **pdt)
{
    unsigned offset;
    unsigned i;
    dt_t *dt;

    //printf("StructDeclaration::toDt(), this='%s'\n", toChars());
    offset = 0;

    // Note equivalence of this loop to class's
    for (i = 0; i < fields.dim; i++)
    {
	VarDeclaration *v = (VarDeclaration *)fields.data[i];
	Initializer *init;

	//printf("\tfield '%s' voffset %d, offset = %d\n", v->toChars(), v->offset, offset);
	dt = NULL;
	init = v->init;
	if (init)
	{   //printf("\t\thas initializer %s\n", init->toChars());
	    dt = init->toDt();
	}
	else if (v->offset >= offset)
	    v->type->toDt(&dt);
	if (dt)
	{
	    if (v->offset < offset)
		error("overlapping initialization for struct %s.%s", toChars(), v->toChars());
	    else
	    {
		if (offset < v->offset)
		    dtnzeros(pdt, v->offset - offset);
		dtcat(pdt, dt);
		offset = v->offset + v->type->size();
	    }
	}
    }

    if (offset < structsize)
	dtnzeros(pdt, structsize - offset);

    dt_optimize(*pdt);
}

/* ================================================================= */

dt_t **Type::toDt(dt_t **pdt)
{
    //printf("Type::toDt()\n");
    Expression *e = defaultInit();
    return e->toDt(pdt);
}

dt_t **TypeSArray::toDt(dt_t **pdt)
{
    int i;
    unsigned len;

    //printf("TypeSArray::toDt()\n");
    len = dim->toInteger();
    if (len)
    {
	while (*pdt)
	    pdt = &((*pdt)->DTnext);
	Type *tnext = next;
	Type *tbn = tnext->toBasetype();
	while (tbn->ty == Tsarray)
	{   TypeSArray *tsa = (TypeSArray *)tbn;

	    len *= tsa->dim->toInteger();
	    tnext = tbn->next;
	    tbn = tnext->toBasetype();
	}
	Expression *e = tnext->defaultInit();
	if (tbn->ty == Tbit)
	{
	    Bits databits;

	    databits.resize(len);
	    if (e->toInteger())
		databits.set();
	    pdt = dtnbytes(pdt, databits.allocdim * sizeof(databits.data[0]),
		(char *)databits.data);
	}
	else
	{
	    if (tbn->ty == Tstruct)
		tnext->toDt(pdt);
	    else
		e->toDt(pdt);
	    dt_optimize(*pdt);
	    if ((*pdt)->dt == DT_azeros && !(*pdt)->DTnext)
	    {
		(*pdt)->DTazeros *= len;
		pdt = &((*pdt)->DTnext);
	    }
	    else if ((*pdt)->dt == DT_1byte && (*pdt)->DTonebyte == 0 && !(*pdt)->DTnext)
	    {
		(*pdt)->dt = DT_azeros;
		(*pdt)->DTazeros = len;
		pdt = &((*pdt)->DTnext);
	    }
	    else
	    {
		for (i = 1; i < len; i++)
		{
		    if (tbn->ty == Tstruct)
		    {	pdt = tnext->toDt(pdt);
			while (*pdt)
			    pdt = &((*pdt)->DTnext);
		    }
		    else
			pdt = e->toDt(pdt);
		}
	    }
	}
    }
    return pdt;
}

dt_t **TypeStruct::toDt(dt_t **pdt)
{
    sym->toDt(pdt);
    return pdt;
}

dt_t **TypeTypedef::toDt(dt_t **pdt)
{
    if (sym->init)
    {
	dt_t *dt = sym->init->toDt();

	while (*pdt)
	    pdt = &((*pdt)->DTnext);
	*pdt = dt;
	return pdt;
    }
    sym->basetype->toDt(pdt);
    return pdt;
}



