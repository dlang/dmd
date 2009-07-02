
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <fp.h>
#include <float.h>
#include <complex.h>

#include "mem.h"

#include "mtype.h"
#include "scope.h"
#include "init.h"
#include "expression.h"
#include "attrib.h"
#include "declaration.h"
#include "template.h"

#define LOGDOTEXP 0	// log ::dotExp()

/***************************** Type *****************************/

ClassDeclaration *Type::typeinfo;
Type *Type::basic[TMAX];
unsigned char Type::mangleChar[TMAX];
StringTable Type::stringtable;


Type::Type(TY ty, Type *next)
{
    this->ty = ty;
    this->next = next;
    this->deco = NULL;
    this->pto = NULL;
    this->rto = NULL;
    this->arrayof = NULL;
    this->vtinfo = NULL;
}

Type *Type::syntaxCopy()
{
    print();
    assert(0);
    return this;
}

int Type::equals(Object *o)
{   Type *t;

    if (this == o ||
	((t = dynamic_cast<Type *>(o)) != NULL &&
	 deco == t->deco) &&			// deco strings are unique
	 deco != NULL)				// and semantic() has been run
    {
	return 1;
    }
    //if (deco && t && t->deco) printf("deco = '%s', t->deco = '%s'\n", deco, t->deco);
    return 0;
}

void Type::init()
{   int i;
    int j;

    Lexer::initKeywords();

    mangleChar[Tarray] = 'A';
    mangleChar[Tsarray] = 'G';
    mangleChar[Taarray] = 'H';
    mangleChar[Tpointer] = 'P';
    mangleChar[Treference] = 'R';
    mangleChar[Tfunction] = 'F';
    mangleChar[Tident] = 'I';
    mangleChar[Tclass] = 'C';
    mangleChar[Tstruct] = 'S';
    mangleChar[Tenum] = 'E';
    mangleChar[Ttypedef] = 'T';
    mangleChar[Tdelegate] = 'D';

    mangleChar[Tnone] = 'n';
    mangleChar[Tvoid] = 'v';
    mangleChar[Tint8] = 'g';
    mangleChar[Tuns8] = 'h';
    mangleChar[Tint16] = 's';
    mangleChar[Tuns16] = 't';
    mangleChar[Tint32] = 'i';
    mangleChar[Tuns32] = 'k';
    mangleChar[Tint64] = 'l';
    mangleChar[Tuns64] = 'm';
    mangleChar[Tfloat32] = 'f';
    mangleChar[Tfloat64] = 'd';
    mangleChar[Tfloat80] = 'e';

    mangleChar[Timaginary32] = 'o';
    mangleChar[Timaginary64] = 'p';
    mangleChar[Timaginary80] = 'j';
    mangleChar[Tcomplex32] = 'q';
    mangleChar[Tcomplex64] = 'r';
    mangleChar[Tcomplex80] = 'c';

    mangleChar[Tbit] = 'b';
    mangleChar[Tascii] = 'a';
    mangleChar[Twchar] = 'u';

    mangleChar[Tinstance] = '@';
    mangleChar[Terror] = '@';

    for (i = 0; i < TMAX; i++)
    {	if (!mangleChar[i])
	    printf("ty = %d\n", i);
	assert(mangleChar[i]);
    }

    // Set basic types
    static TY basetab[] =
	{ Tvoid, Tint8, Tuns8, Tint16, Tuns16, Tint32, Tuns32, Tint64, Tuns64,
	  Tfloat32, Tfloat64, Tfloat80,
	  Timaginary32, Timaginary64, Timaginary80,
	  Tcomplex32, Tcomplex64, Tcomplex80,
	  Tbit,
	  Tascii, Twchar };

    for (i = 0; i < sizeof(basetab) / sizeof(basetab[0]); i++)
	basic[basetab[i]] = new TypeBasic(basetab[i]);
}

unsigned Type::size()
{
    Loc loc;

    error(loc, "no size for type %s", toChars());
    return 0;
}

unsigned Type::alignsize()
{
    return size();
}

Type *Type::semantic(Loc loc, Scope *sc)
{
    if (next)
	next = next->semantic(loc,sc);
    return merge();
}

Type *Type::pointerTo()
{
    if (!pto)
    {	Type *t;

	t = new TypePointer(this);
	pto = t->merge();
    }
    return pto;
}

Type *Type::referenceTo()
{
    if (!rto)
    {	Type *t;

	t = new TypeReference(this);
	rto = t->merge();
    }
    return rto;
}

Type *Type::arrayOf()
{
    if (!arrayof)
    {	Type *t;

	t = new TypeDArray(this);
	arrayof = t->merge();
    }
    return arrayof;
}

/*******************************
 * If this is a shell around another type,
 * get that other type.
 */

Type *Type::toBasetype()
{
    return this;
}

/********************************
 * Name mangling.
 */

void Type::toDecoBuffer(OutBuffer *buf)
{
    buf->writeByte(mangleChar[ty]);
    if (next)
	next->toDecoBuffer(buf);
}

/********************************
 * Name mangling.
 */

void Type::toTypeInfoBuffer(OutBuffer *buf)
{
    buf->writeByte(mangleChar[ty]);
}

/********************************
 * For pretty-printing a type.
 */

char *Type::toChars()
{   OutBuffer *buf;

    buf = new OutBuffer();
    toCBuffer2(buf, NULL);
    return buf->toChars();
}

void Type::toCBuffer(OutBuffer *buf, Identifier *ident)
{
    OutBuffer tbuf;

    toCBuffer2(&tbuf, ident);
    buf->write(&tbuf);
}

void Type::toCBuffer2(OutBuffer *buf, Identifier *ident)
{
//    buf->prependbyte(' ');
    buf->prependstring(toChars());
    if (ident)
    {	buf->writeByte(' ');
	buf->writestring(ident->toChars());
    }
}

/************************************
 */

Type *Type::merge()
{   Type *t;

    //printf("merge()\n");
    t = this;
    if (!deco)
    {
	OutBuffer buf;
	StringValue *sv;

	if (next)
	    next = next->merge();
	toDecoBuffer(&buf);
	sv = stringtable.update((char *)buf.data, buf.offset);
	if (sv->ptrvalue)
	{   t = (Type *) sv->ptrvalue;
	    assert(t->deco);
	    //printf("old value, deco = '%s' %p\n", t->deco, t->deco);
	}
	else
	{
	    sv->ptrvalue = this;
	    deco = sv->lstring.string;
	    //printf("new value, deco = '%s' %p\n", t->deco, t->deco);
	}
    }
    return t;
}

int Type::isbit()
{
    return FALSE;
}

int Type::isintegral()
{
    return FALSE;
}

int Type::isfloating()
{
    return FALSE;
}

int Type::isreal()
{
    return FALSE;
}

int Type::isimaginary()
{
    return FALSE;
}

int Type::iscomplex()
{
    return FALSE;
}

int Type::isscalar()
{
    return FALSE;
}

int Type::isunsigned()
{
    return FALSE;
}

ClassDeclaration *Type::isClassHandle()
{
    return NULL;
}

int Type::isauto()
{
    return FALSE;
}

int Type::isString()
{
    return FALSE;
}

int Type::checkBoolean()
{
    return isscalar();
}

Expression *Type::defaultInit()
{
    return NULL;
}

/********************************
 * Determine if 'this' can be implicitly converted
 * to type 'to'.
 * Returns:
 *	0	can't convert
 *	1	can convert using implicit conversions
 *	2	this and to are the same type
 */

int Type::implicitConvTo(Type *to)
{
    //printf("Type::implicitConvTo(this=%p, to=%p)\n", this, to);
    //printf("\tthis->next=%p, to->next=%p\n", this->next, to->next);
    return (this == to) ? 2 : 0;
}

Expression *Type::getProperty(Loc loc, Identifier *ident)
{   Expression *e;

    if (ident == Id::size)
    {
	e = new IntegerExp(loc, size(), Type::tint32);
    }
    else if (ident == Id::typeinfo)
    {
	if (!vtinfo)
	    vtinfo = new TypeInfoDeclaration(this);
	e = new VarExp(loc, vtinfo);
	e = e->addressOf();
	e->type = vtinfo->type;		// do this so we don't get redundant dereference
    }
    else if (ident == Id::init)
	return defaultInit();
    else
    {	error(loc, "no property '%s' for type '%s'", ident->toChars(), toChars());
	e = new IntegerExp(loc, 1, Type::tint32);
    }
    return e;
}

Expression *Type::dotExp(Scope *sc, Expression *e, Identifier *ident)
{   VarDeclaration *v = NULL;

#if LOGDOTEXP
    printf("Type::dotExp(e = '%s', ident = '%s')\n", e->toChars(), ident->toChars());
#endif
    if (e->op == TOKdotvar)
    {
	DotVarExp *dv = (DotVarExp *)e;
	v = dynamic_cast<VarDeclaration *>(dv->var);
    }
    else if (e->op == TOKvar)
    {
	VarExp *ve = (VarExp *)e;
	v = dynamic_cast<VarDeclaration *>(ve->var);
    }
    if (v)
    {
	if (ident == Id::offset)
	{
	    if (v->storage_class & STCfield)
	    {
		e = new IntegerExp(e->loc, v->offset, Type::tint32);
		return e;
	    }
	}
	else if (ident == Id::init)
	{
	    if (v->init)
	    {
		e = v->init->toExpression();
		return e;
	    }
	}
    }
    return getProperty(e->loc, ident);
}

unsigned Type::memalign(unsigned salign)
{
    return salign;
}

void Type::error(Loc loc, const char *format, ...)
{
    char *p = loc.toChars();
    if (*p)
	printf("%s: ", p);
    mem.free(p);

    va_list ap;
    va_start(ap, format);
    vprintf(format, ap);
    va_end(ap);

    printf("\n");
    fflush(stdout);

    global.errors++;
    fatal();
}

Identifier *Type::getTypeInfoIdent()
{
    // _init_TypeInfo_%s
    OutBuffer buf;
    Identifier *id;
    char *name;

    toTypeInfoBuffer(&buf);
    name = (char *)alloca(15 + buf.offset + 1);
    buf.writeByte(0);
    sprintf(name, "_init_TypeInfo_%s", buf.data);
    id = Lexer::idPool(name);
    return id;
}

/* ============================= TypeBasic =========================== */

TypeBasic::TypeBasic(TY ty)
	: Type(ty, NULL)
{   char *c;
    char *d;
    unsigned flags;

#define TFLAGSintegral	1
#define TFLAGSfloating	2
#define TFLAGSunsigned	4
#define TFLAGSreal	8
#define TFLAGSimaginary	0x10
#define TFLAGScomplex	0x20

    flags = 0;
    switch (ty)
    {
	case Tvoid:	d = Token::toChars(TOKvoid);
			c = "void";
			break;

	case Tint8:	d = Token::toChars(TOKint8);
			c = "byte";
			flags |= TFLAGSintegral;
			break;

	case Tuns8:	d = Token::toChars(TOKuns8);
			c = "ubyte";
			flags |= TFLAGSintegral | TFLAGSunsigned;
			break;

	case Tint16:	d = Token::toChars(TOKint16);
			c = "short";
			flags |= TFLAGSintegral;
			break;

	case Tuns16:	d = Token::toChars(TOKuns16);
			c = "ushort";
			flags |= TFLAGSintegral | TFLAGSunsigned;
			break;

	case Tint32:	d = Token::toChars(TOKint32);
			c = "int";
			flags |= TFLAGSintegral;
			break;

	case Tuns32:	d = Token::toChars(TOKuns32);
			c = "uint";
			flags |= TFLAGSintegral | TFLAGSunsigned;
			break;

	case Tfloat32:	d = Token::toChars(TOKfloat32);
			c = "float";
			flags |= TFLAGSfloating | TFLAGSreal;
			break;

	case Tint64:	d = Token::toChars(TOKint64);
			c = "long";
			flags |= TFLAGSintegral;
			break;

	case Tuns64:	d = Token::toChars(TOKuns64);
			c = "ulong";
			flags |= TFLAGSintegral | TFLAGSunsigned;
			break;

	case Tfloat64:	d = Token::toChars(TOKfloat64);
			c = "double";
			flags |= TFLAGSfloating | TFLAGSreal;
			break;

	case Tfloat80:	d = Token::toChars(TOKfloat80);
			c = "extended";
			flags |= TFLAGSfloating | TFLAGSreal;
			break;

	case Timaginary32: d = Token::toChars(TOKimaginary);
			c = "imaginary32";
			flags |= TFLAGSfloating | TFLAGSimaginary;
			break;

	case Timaginary64: d = Token::toChars(TOKimaginary);
			c = "imaginary64";
			flags |= TFLAGSfloating | TFLAGSimaginary;
			break;

	case Timaginary80: d = Token::toChars(TOKimaginary);
			c = "imaginary";
			flags |= TFLAGSfloating | TFLAGSimaginary;
			break;

	case Tcomplex32: d = Token::toChars(TOKcomplex);
			c = "complex32";
			flags |= TFLAGSfloating | TFLAGScomplex;
			break;

	case Tcomplex64: d = Token::toChars(TOKcomplex);
			c = "complex64";
			flags |= TFLAGSfloating | TFLAGScomplex;
			break;

	case Tcomplex80: d = Token::toChars(TOKcomplex);
			c = "complex";
			flags |= TFLAGSfloating | TFLAGScomplex;
			break;


	case Tbit:	d = Token::toChars(TOKbit);
			c = "bit";
			flags |= TFLAGSintegral | TFLAGSunsigned;
			break;

	case Tascii:	d = Token::toChars(TOKascii);
			c = "char";
			flags |= TFLAGSintegral | TFLAGSunsigned;
			break;

	case Twchar:	d = Token::toChars(TOKwchar);
			c = "wchar";
			flags |= TFLAGSintegral | TFLAGSunsigned;
			break;

	default:	assert(0);
    }
    this->dstring = d;
    this->cstring = c;
    this->flags = flags;
    merge();
}

Type *TypeBasic::syntaxCopy()
{
    // No semantic analysis done on basic types, no need to copy
    return this;
}


char *TypeBasic::toChars()
{
    return dstring;
}

void TypeBasic::toCBuffer2(OutBuffer *buf, Identifier *ident)
{
    //buf->prependbyte(' ');
    buf->prependstring(cstring);
    if (ident)
    {	buf->writeByte(' ');
	buf->writestring(ident->toChars());
    }
}

unsigned TypeBasic::size()
{   unsigned size;

    //printf("TypeBasic::size()\n");
    switch (ty)
    {
	case Tint8:
	case Tuns8:	size = 1;	break;
	case Tint16:
	case Tuns16:	size = 2;	break;
	case Tint32:
	case Tuns32:
	case Tfloat32:
	case Timaginary32:
			size = 4;	break;
	case Tint64:
	case Tuns64:
	case Tfloat64:
	case Timaginary64:
			size = 8;	break;
	case Tfloat80:
	case Timaginary80:
			size = 10;	break;
	case Tcomplex32:
			size = 8;	break;
	case Tcomplex64:
			size = 16;	break;
	case Tcomplex80:
			size = 20;	break;

	case Tvoid:
	    //size = Type::size();	// error message
	    size = 1;
	    break;

	case Tbit:	size = 1;		break;
	case Tascii:	size = 1;		break;
	case Twchar:	size = sizeof(d_wchar);	break;

	default:
	    assert(0);
	    break;
    }
    return size;
}

unsigned TypeBasic::alignsize()
{   unsigned sz;

    switch (ty)
    {
	case Tfloat80:
	case Timaginary80:
	case Tcomplex80:
	    sz = 2;
	    break;

	default:
	    sz = size();
	    break;
    }
    return sz;
}


Expression *TypeBasic::getProperty(Loc loc, Identifier *ident)
{
    Expression *e;
    d_int64 ivalue;
    d_float80 fvalue;

    //printf("TypeBasic::getProperty('%s')\n", ident->toChars());
    if (ident == Id::max)
    {
	switch (ty)
	{
	    case Tint8:		ivalue = 0x7F;		goto Livalue;
	    case Tuns8:		ivalue = 0xFF;		goto Livalue;
	    case Tint16:	ivalue = 0x7FFFUL;	goto Livalue;
	    case Tuns16:	ivalue = 0xFFFFUL;	goto Livalue;
	    case Tint32:	ivalue = 0x7FFFFFFFUL;	goto Livalue;
	    case Tuns32:	ivalue = 0xFFFFFFFFUL;	goto Livalue;
	    case Tint64:	ivalue = 0x7FFFFFFFFFFFFFFFLL;	goto Livalue;
	    case Tuns64:	ivalue = 0xFFFFFFFFFFFFFFFFULL;	goto Livalue;
	    case Tbit:		ivalue = 1;		goto Livalue;
	    case Tascii:	ivalue = 0xFF;		goto Livalue;
	    case Twchar:	ivalue = 0xFFFFUL;	goto Livalue;

	    case Tcomplex32:
	    case Timaginary32:
	    case Tfloat32:	fvalue = FLT_MAX;	goto Lfvalue;
	    case Tcomplex64:
	    case Timaginary64:
	    case Tfloat64:	fvalue = DBL_MAX;	goto Lfvalue;
	    case Tcomplex80:
	    case Timaginary80:
	    case Tfloat80:	fvalue = LDBL_MAX;	goto Lfvalue;
	}
    }
    else if (ident == Id::min)
    {
	switch (ty)
	{
	    case Tint8:		ivalue = -128;		goto Livalue;
	    case Tuns8:		ivalue = 0;		goto Livalue;
	    case Tint16:	ivalue = -32768;	goto Livalue;
	    case Tuns16:	ivalue = 0;		goto Livalue;
	    case Tint32:	ivalue = -2147483647L - 1;	goto Livalue;
	    case Tuns32:	ivalue = 0;			goto Livalue;
	    case Tint64:	ivalue = (-9223372036854775807LL-1LL);	goto Livalue;
	    case Tuns64:	ivalue = 0;		goto Livalue;
	    case Tbit:		ivalue = 0;		goto Livalue;
	    case Tascii:	ivalue = 0;		goto Livalue;
	    case Twchar:	ivalue = 0;		goto Livalue;

	    case Tcomplex32:
	    case Timaginary32:
	    case Tfloat32:	fvalue = FLT_MIN;	goto Lfvalue;
	    case Tcomplex64:
	    case Timaginary64:
	    case Tfloat64:	fvalue = DBL_MIN;	goto Lfvalue;
	    case Tcomplex80:
	    case Timaginary80:
	    case Tfloat80:	fvalue = LDBL_MIN;	goto Lfvalue;
	}
    }
    else if (ident == Id::nan)
    {
	switch (ty)
	{
	    case Tcomplex32:
	    case Tcomplex64:
	    case Tcomplex80:
	    case Timaginary32:
	    case Timaginary64:
	    case Timaginary80:
	    case Tfloat32:
	    case Tfloat64:
	    case Tfloat80:	fvalue = NAN;		goto Lfvalue;
	}
    }
    else if (ident == Id::infinity)
    {
	switch (ty)
	{
	    case Tcomplex32:
	    case Tcomplex64:
	    case Tcomplex80:
	    case Timaginary32:
	    case Timaginary64:
	    case Timaginary80:
	    case Tfloat32:
	    case Tfloat64:
	    case Tfloat80:	fvalue = INFINITY;	goto Lfvalue;
	}
    }
    else if (ident == Id::dig)
    {
	switch (ty)
	{
	    case Tcomplex32:
	    case Timaginary32:
	    case Tfloat32:	ivalue = FLT_DIG;	goto Lint;
	    case Tcomplex64:
	    case Timaginary64:
	    case Tfloat64:	ivalue = DBL_DIG;	goto Lint;
	    case Tcomplex80:
	    case Timaginary80:
	    case Tfloat80:	ivalue = LDBL_DIG;	goto Lint;
	}
    }
    else if (ident == Id::epsilon)
    {
	switch (ty)
	{
	    case Tcomplex32:
	    case Timaginary32:
	    case Tfloat32:	fvalue = FLT_EPSILON;	goto Lfvalue;
	    case Tcomplex64:
	    case Timaginary64:
	    case Tfloat64:	fvalue = DBL_EPSILON;	goto Lfvalue;
	    case Tcomplex80:
	    case Timaginary80:
	    case Tfloat80:	fvalue = LDBL_EPSILON;	goto Lfvalue;
	}
    }
    else if (ident == Id::mant_dig)
    {
	switch (ty)
	{
	    case Tcomplex32:
	    case Timaginary32:
	    case Tfloat32:	ivalue = FLT_MANT_DIG;	goto Lint;
	    case Tcomplex64:
	    case Timaginary64:
	    case Tfloat64:	ivalue = DBL_MANT_DIG;	goto Lint;
	    case Tcomplex80:
	    case Timaginary80:
	    case Tfloat80:	ivalue = LDBL_MANT_DIG; goto Lint;
	}
    }
    else if (ident == Id::max_10_exp)
    {
	switch (ty)
	{
	    case Tcomplex32:
	    case Timaginary32:
	    case Tfloat32:	ivalue = FLT_MAX_10_EXP;	goto Lint;
	    case Tcomplex64:
	    case Timaginary64:
	    case Tfloat64:	ivalue = DBL_MAX_10_EXP;	goto Lint;
	    case Tcomplex80:
	    case Timaginary80:
	    case Tfloat80:	ivalue = LDBL_MAX_10_EXP;	goto Lint;
	}
    }
    else if (ident == Id::max_exp)
    {
	switch (ty)
	{
	    case Tcomplex32:
	    case Timaginary32:
	    case Tfloat32:	ivalue = FLT_MAX_EXP;	goto Lint;
	    case Tcomplex64:
	    case Timaginary64:
	    case Tfloat64:	ivalue = DBL_MAX_EXP;	goto Lint;
	    case Tcomplex80:
	    case Timaginary80:
	    case Tfloat80:	ivalue = LDBL_MAX_EXP;	goto Lint;
	}
    }
    else if (ident == Id::min_10_exp)
    {
	switch (ty)
	{
	    case Tcomplex32:
	    case Timaginary32:
	    case Tfloat32:	ivalue = FLT_MIN_10_EXP;	goto Lint;
	    case Tcomplex64:
	    case Timaginary64:
	    case Tfloat64:	ivalue = DBL_MIN_10_EXP;	goto Lint;
	    case Tcomplex80:
	    case Timaginary80:
	    case Tfloat80:	ivalue = LDBL_MIN_10_EXP;	goto Lint;
	}
    }
    else if (ident == Id::min_exp)
    {
	switch (ty)
	{
	    case Tcomplex32:
	    case Timaginary32:
	    case Tfloat32:	ivalue = FLT_MIN_EXP;	goto Lint;
	    case Tcomplex64:
	    case Timaginary64:
	    case Tfloat64:	ivalue = DBL_MIN_EXP;	goto Lint;
	    case Tcomplex80:
	    case Timaginary80:
	    case Tfloat80:	ivalue = LDBL_MIN_EXP;	goto Lint;
	}
    }

Ldefault:
    return Type::getProperty(loc, ident);

Livalue:
    e = new IntegerExp(0, ivalue, this);
    return e;

Lfvalue:
    if (isreal())
	e = new RealExp(0, fvalue, this);
    else if (isimaginary())
	e = new ImaginaryExp(0, fvalue, this);
    else
	e = new ComplexExp(0, fvalue + fvalue * I, this);
    return e;

Lint:
    e = new IntegerExp(0, ivalue, Type::tint32);
    return e;
}

Expression *TypeBasic::dotExp(Scope *sc, Expression *e, Identifier *ident)
{
#if LOGDOTEXP
    printf("TypeBasic::dotExp(e = '%s', ident = '%s')\n", e->toChars(), ident->toChars());
#endif
    Type *t;

    if (ident == Id::re)
    {
	switch (ty)
	{
	    case Tcomplex32:	t = tfloat32;		goto L1;
	    case Tcomplex64:	t = tfloat64;		goto L1;
	    case Tcomplex80:	t = tfloat80;		goto L1;
	    L1:
		e = e->castTo(t);
		break;

	    case Tfloat32:
	    case Tfloat64:
	    case Tfloat80:
		break;

	    case Timaginary32:	t = tfloat32;		goto L2;
	    case Timaginary64:	t = tfloat64;		goto L2;
	    case Timaginary80:	t = tfloat80;		goto L2;
	    L2:
		e = new RealExp(0, 0.0, t);
		break;

	    default:
		return Type::getProperty(e->loc, ident);
	}
    }
    else if (ident == Id::im)
    {	Type *t2;

	switch (ty)
	{
	    case Tcomplex32:	t = timaginary32;	t2 = tfloat32;	goto L3;
	    case Tcomplex64:	t = timaginary64;	t2 = tfloat64;	goto L3;
	    case Tcomplex80:	t = timaginary80;	t2 = tfloat80;	goto L3;
	    L3:
		e = e->castTo(t);
		e->type = t2;
		break;

	    case Timaginary32:	t = tfloat32;	goto L4;
	    case Timaginary64:	t = tfloat64;	goto L4;
	    case Timaginary80:	t = tfloat80;	goto L4;
	    L4:
		e->type = t;
		break;

	    case Tfloat32:
	    case Tfloat64:
	    case Tfloat80:
		e = new RealExp(0, 0.0, this);
		break;

	    default:
		return Type::getProperty(e->loc, ident);
	}
    }
    else
    {
	return Type::dotExp(sc, e, ident);
    }
    return e;
}

Expression *TypeBasic::defaultInit()
{
    switch (ty)
    {
	case Timaginary32:
	case Timaginary64:
	case Timaginary80:
	case Tfloat32:
	case Tfloat64:
	case Tfloat80:
	case Tcomplex32:
	case Tcomplex64:
	case Tcomplex80:
	    return getProperty(0, Id::nan);
    }
    return new IntegerExp(0, 0, this);
}

int TypeBasic::isbit()
{
    return (ty == Tbit);
}

int TypeBasic::isintegral()
{
    //printf("TypeBasic::isintegral('%s') x%x\n", toChars(), flags);
    return flags & TFLAGSintegral;
}

int TypeBasic::isfloating()
{
    return flags & TFLAGSfloating;
}

int TypeBasic::isreal()
{
    return flags & TFLAGSreal;
}

int TypeBasic::isimaginary()
{
    return flags & TFLAGSimaginary;
}

int TypeBasic::iscomplex()
{
    return flags & TFLAGScomplex;
}

int TypeBasic::isunsigned()
{
    return flags & TFLAGSunsigned;
}

int TypeBasic::isscalar()
{
    return flags & (TFLAGSintegral | TFLAGSfloating);
}

int TypeBasic::implicitConvTo(Type *to)
{
    //printf("TypeBasic::implicitConvTo()\n");
    if (this == to)
	return MATCHexact;
    if (!dynamic_cast<TypeBasic *>(to))
	return MATCHnomatch;
    if (ty == Tvoid || to->ty == Tvoid)
	return MATCHnomatch;
    if (to->ty == Tbit)
	return MATCHnomatch;
    return MATCHconvert;
}

/***************************** TypeArray *****************************/

TypeArray::TypeArray(TY ty, Type *next)
    : Type(ty, next)
{
}

Expression *TypeArray::dotExp(Scope *sc, Expression *e, Identifier *ident)
{
    Type *n = this->next->toBasetype();		// uncover any typedef's

#if LOGDOTEXP
    printf("TypeArray::dotExp(e = '%s', ident = '%s')\n", e->toChars(), ident->toChars());
#endif
    if (ident == Id::reverse || ident == Id::dup)
    {
	Expression *ec;
	FuncDeclaration *fd;
	Array *arguments;
	int size = next->size();
	char *nm;
	static char *name[2][2] = { { "_adReverse", "_adDup" },
				    { "_adReverseBit", "_adDupBit" } };

	assert(size);
	nm = name[n->ty == Tbit][ident == Id::dup];
	fd = FuncDeclaration::genCfunc(Type::tindex, nm);
	ec = new VarExp(0, fd);
	e = e->castTo(n->arrayOf());		// convert to dynamic array
	arguments = new Array();
	arguments->push(e);
	if (next->ty != Tbit)
	    arguments->push(new IntegerExp(0, size, Type::tint32));
	e = new CallExp(e->loc, ec, arguments);
	e->type = next->arrayOf();
    }
    else if (ident == Id::sort && n->ty != Tbit)
    {
	Expression *ec;
	FuncDeclaration *fd;
	Array *arguments;

	fd = FuncDeclaration::genCfunc(tint32->arrayOf(), "_adSort");
	ec = new VarExp(0, fd);
	e = e->castTo(n->arrayOf());		// convert to dynamic array
	arguments = new Array();
	arguments->push(e);
	arguments->push(n->getProperty(e->loc, Id::typeinfo));
	e = new CallExp(e->loc, ec, arguments);
	e->type = next->arrayOf();
    }
    else
    {
	e = Type::dotExp(sc, e, ident);
    }
    return e;
}

void TypeArray::toCBuffer2(OutBuffer *buf, Identifier *ident)
{
#if 1
    // The D way
    Type *t;
    OutBuffer buf2;
    for (t = this; 1; t = t->next)
    {	TypeArray *ta;

	ta = dynamic_cast<TypeArray *>(t);
	if (!ta)
	    break;
	ta->toPrettyBracket(&buf2);
    }
    buf->prependstring(buf2.toChars());
    if (ident)
    {
	buf2.writestring(ident->toChars());
    }
    t->toCBuffer2(buf, NULL);
#else
    // The C way
    if (buf->offset)
    {	buf->bracket('(', ')');
	assert(!ident);
    }
    else if (ident)
	buf->writestring(ident->toChars());
    Type *t = this;
    do
    {	Expression *dim;
	buf->writeByte('[');
	dim = ((TypeSArray *)t)->dim;
	if (dim)
	    buf->printf("%d", dim->toInteger());
	buf->writeByte(']');
	t = t->next;
    } while (t->ty == Tsarray);
    t->toCBuffer2(buf, NULL);
#endif
}

/***************************** TypeSArray *****************************/

TypeSArray::TypeSArray(Type *t, Expression *dim)
    : TypeArray(Tsarray, t)
{
    this->dim = dim;
}

Type *TypeSArray::syntaxCopy()
{
    Type *t = next->syntaxCopy();
    Expression *e = dim->syntaxCopy();
    t = new TypeSArray(t, e);
    return t;
}

unsigned TypeSArray::size()
{   unsigned sz;

    if (!dim)
	return Type::size();
    sz = dim->toInteger();
    if (next->ty == Tbit)		// if array of bits
    {
	sz = (sz + 31) / 8;		// size in bytes, rounded up to dwords
    }
    else
	sz *= next->size();
    return sz;
}

unsigned TypeSArray::alignsize()
{
    return next->alignsize();
}

Type *TypeSArray::semantic(Loc loc, Scope *sc)
{
    if (dim)
    {	dim = dim->semantic(sc);
	dim = dim->constFold();
    }
    next = next->semantic(loc,sc);
    switch (next->ty)
    {
	case Tfunction:
	case Tnone:
	    error(loc, "can't have array of %s", next->toChars());
	    break;
    }
    if (next->isauto())
	error(loc, "cannot have array of auto %s", next->toChars());
    return merge();
}

void TypeSArray::toDecoBuffer(OutBuffer *buf)
{
    buf->writeByte(mangleChar[ty]);
    if (dim)
	buf->printf("%d", dim->toInteger());
    if (next)
	next->toDecoBuffer(buf);
}

void TypeSArray::toTypeInfoBuffer(OutBuffer *buf)
{
    buf->writeByte(mangleChar[Tarray]);
    if (next)
	next->toTypeInfoBuffer(buf);
}

void TypeSArray::toPrettyBracket(OutBuffer *buf)
{
    buf->printf("[%d]", dim->toInteger());
}

Expression *TypeSArray::dotExp(Scope *sc, Expression *e, Identifier *ident)
{
#if LOGDOTEXP
    printf("TypeSArray::dotExp(e = '%s', ident = '%s')\n", e->toChars(), ident->toChars());
#endif
    if (ident == Id::length)
    {
	e = dim;
    }
    else
    {
	e = TypeArray::dotExp(sc, e, ident);
    }
    return e;
}

int TypeSArray::isString()
{
    return next->ty == Tascii || next->ty == Twchar;
}

unsigned TypeSArray::memalign(unsigned salign)
{
    return next->memalign(salign);
}

int TypeSArray::implicitConvTo(Type *to)
{
    //printf("TypeSArray::implicitConvTo()\n");

    // Allow implicit conversion of static array to pointer or dynamic array
    if ((to->ty == Tpointer || to->ty == Tarray) &&
	(to->next->ty == Tvoid || next->equals(to->next)))
    {
	return 1;
    }
#if 0
    if (to->ty == Tsarray)
    {
	TypeSArray *tsa = (TypeSArray *)to;

	if (next->equals(tsa->next) && dim->equals(tsa->dim))
	{
	    return 1;
	}
    }
#endif
    return Type::implicitConvTo(to);
}

Expression *TypeSArray::defaultInit()
{
    return next->defaultInit();
}

/***************************** TypeDArray *****************************/

TypeDArray::TypeDArray(Type *t)
    : TypeArray(Tarray, t)
{
    //printf("TypeDArray(t = %p)\n", t);
}

Type *TypeDArray::syntaxCopy()
{
    Type *t = next->syntaxCopy();
    if (t == next)
	t = this;
    else
	t = new TypeDArray(t);
    return t;
}

unsigned TypeDArray::size()
{
    //printf("TypeDArray::size()\n");
    return 8;
}

unsigned TypeDArray::alignsize()
{
    // A DArray consists of two dwords, so align it on dword
    // boundary
    return 4;
}

Type *TypeDArray::semantic(Loc loc, Scope *sc)
{
    next = next->semantic(loc,sc);
    switch (next->ty)
    {
	case Tfunction:
	case Tnone:
	    error(loc, "can't have array of %s", next->toChars());
	    break;
    }
    if (next->isauto())
	error(loc, "cannot have array of auto %s", next->toChars());
    return merge();
}

void TypeDArray::toDecoBuffer(OutBuffer *buf)
{
    buf->writeByte(mangleChar[ty]);
    if (next)
	next->toDecoBuffer(buf);
}

void TypeDArray::toTypeInfoBuffer(OutBuffer *buf)
{
    buf->writeByte(mangleChar[ty]);
    if (next)
	next->toTypeInfoBuffer(buf);
}

void TypeDArray::toPrettyBracket(OutBuffer *buf)
{
    buf->writestring("[]");
}

Expression *TypeDArray::dotExp(Scope *sc, Expression *e, Identifier *ident)
{
#if LOGDOTEXP
    printf("TypeDArray::dotExp(e = '%s', ident = '%s')\n", e->toChars(), ident->toChars());
#endif
    if (ident == Id::length)
    {
	if (e->op == TOKstring)
	{   StringExp *se = (StringExp *)e;

	    return new IntegerExp(se->loc, se->len, Type::tindex);
	}
	e = new ArrayLengthExp(0, e);
	e->type = Type::tindex;
	return e;
    }
    else
    {
	e = TypeArray::dotExp(sc, e, ident);
    }
    return e;
}

int TypeDArray::isString()
{
    return next->ty == Tascii || next->ty == Twchar;
}

int TypeDArray::implicitConvTo(Type *to)
{
    //printf("TypeDArray::implicitConvTo()\n");

    // Allow implicit conversion of array to pointer
    if (to->ty == Tpointer && (to->next->ty == Tvoid || next->equals(to->next)))
    {
	return 1;
    }
    return Type::implicitConvTo(to);
}

Expression *TypeDArray::defaultInit()
{
    Expression *e;
    e = new NullExp(0);
    e->type = this;
    return e;
}

int TypeDArray::checkBoolean()
{
    return TRUE;
}

/***************************** TypeAArray *****************************/

TypeAArray::TypeAArray(Type *t, Type *index)
    : TypeArray(Taarray, t)
{
    this->index = index;
    this->key = NULL;
}

Type *TypeAArray::syntaxCopy()
{
    Type *t = next->syntaxCopy();
    Type *ti = index->syntaxCopy();
    if (t == next && ti == index)
	t = this;
    else
	t = new TypeAArray(t, ti);
    return t;
}

unsigned TypeAArray::size()
{
    return 8;
}


Type *TypeAArray::semantic(Loc loc, Scope *sc)
{
    // Deal with the case where we thought the index was a type, but
    // in reality it was an expression.
    if (index->ty == Tident)
    {
	TypeIdentifier *ti = (TypeIdentifier *)index;
	Expression *e;
	Type *t;

	ti->resolve(sc, &e, &t);
	if (e)
	{   // It was an expression -
	    // Rewrite as a static array
	    TypeSArray *tsa;

	    tsa = new TypeSArray(next, e);
	    return tsa->semantic(loc,sc);
	}
	assert(t);
	index = t;
    }
    else
	index = index->semantic(loc,sc);

    // Compute key type; the purpose of the key type is to
    // minimize the permutations of runtime library
    // routines as much as possible.
    key = index->toBasetype();
    switch (key->ty)
    {
	case Tsarray:
	    // Convert to Tarray
	    key = key->next->arrayOf();
	    break;

	case Tbit:
	case Tint8:
	case Tuns8:
	case Tint16:
	case Tuns16:
	    key = tint32;
	    break;

	case Tfunction:
	case Tvoid:
	case Tnone:
	    error(loc, "can't have associative array key of %s", key->toChars());
	    break;
    }
    next = next->semantic(loc,sc);
    switch (next->toBasetype()->ty)
    {
	case Tfunction:
	case Tnone:
	    error(loc, "can't have associative array of %s", next->toChars());
	    break;
    }
    if (next->isauto())
	error(loc, "cannot have array of auto %s", next->toChars());

    return merge();
}

Expression *TypeAArray::dotExp(Scope *sc, Expression *e, Identifier *ident)
{
#if LOGDOTEXP
    printf("TypeAArray::dotExp(e = '%s', ident = '%s')\n", e->toChars(), ident->toChars());
#endif
    if (ident == Id::length)
    {
	Expression *ec;
	FuncDeclaration *fd;
	Array *arguments;

	fd = FuncDeclaration::genCfunc(Type::tindex, "_aaLen");
	ec = new VarExp(0, fd);
	arguments = new Array();
	arguments->push(e);
	e = new CallExp(e->loc, ec, arguments);
	e->type = fd->type->next;
    }
    else if (ident == Id::keys)
    {
	Expression *ec;
	FuncDeclaration *fd;
	Array *arguments;
	char aakeys[7+3*sizeof(int)+1];
	int size = key->size();

	assert(size);
#if 0
	if (size == 1 || size == 2 || size == 4 || size == 8)
	{
	    sprintf(aakeys, "_aaKeys%d", size);
	    size = 0;
	}
	else
#endif
	    strcpy(aakeys, "_aaKeys");
	fd = FuncDeclaration::genCfunc(Type::tindex, aakeys);
	ec = new VarExp(0, fd);
	arguments = new Array();
	arguments->push(e);
	if (size)
	    arguments->push(new IntegerExp(0, size, Type::tint32));
	e = new CallExp(e->loc, ec, arguments);
	e->type = key->arrayOf();
    }
    else if (ident == Id::values)
    {
	Expression *ec;
	FuncDeclaration *fd;
	Array *arguments;

	fd = FuncDeclaration::genCfunc(Type::tindex, "_aaValues");
	ec = new VarExp(0, fd);
	arguments = new Array();
	arguments->push(e);
	arguments->push(new IntegerExp(0, key->size(), Type::tint32));
	arguments->push(new IntegerExp(0, next->size(), Type::tint32));
	e = new CallExp(e->loc, ec, arguments);
	e->type = next->arrayOf();
    }
    else if (ident == Id::rehash)
    {
	Expression *ec;
	FuncDeclaration *fd;
	Array *arguments;

	fd = FuncDeclaration::genCfunc(this, "_aaRehash");
	ec = new VarExp(0, fd);
	arguments = new Array();
	arguments->push(e->addressOf());
	arguments->push(key->getProperty(e->loc, Id::typeinfo));
	e = new CallExp(e->loc, ec, arguments);
	e->type = this;
    }
    else
    {
	e = Type::dotExp(sc, e, ident);
    }
    return e;
}

void TypeAArray::toDecoBuffer(OutBuffer *buf)
{
    buf->writeByte(mangleChar[ty]);
    index->toDecoBuffer(buf);
    next->toDecoBuffer(buf);
}

void TypeAArray::toPrettyBracket(OutBuffer *buf)
{
    buf->writeByte('[');
    {	OutBuffer ibuf;

	index->toCBuffer2(&ibuf, NULL);
	buf->write(&ibuf);
    }
    buf->writeByte(']');
}

Expression *TypeAArray::defaultInit()
{
    Expression *e;
    e = new NullExp(0);
    e->type = this;
    return e;
}

int TypeAArray::checkBoolean()
{
    return TRUE;
}

/***************************** TypePointer *****************************/

TypePointer::TypePointer(Type *t)
    : Type(Tpointer, t)
{
}

Type *TypePointer::syntaxCopy()
{
    Type *t = next->syntaxCopy();
    if (t == next)
	t = this;
    else
	t = new TypePointer(t);
    return t;
}

Type *TypePointer::semantic(Loc loc, Scope *sc)
{
    //printf("TypePointer::semantic()\n");
    next = next->semantic(loc,sc);
    return merge();
}


unsigned TypePointer::size()
{
    return 4;
}

void TypePointer::toCBuffer2(OutBuffer *buf, Identifier *ident)
{
    buf->prependstring("*");
    if (ident)
    {
	buf->writestring(ident->toChars());
    }
    next->toCBuffer2(buf, NULL);
}

int TypePointer::implicitConvTo(Type *to)
{
    //printf("TypePointer::implicitConvTo()\n");

    if (this == to)
	return 2;
    if (to->next)
    {
	if (to->next->ty == Tvoid)
	    return 1;
#if 0
	if (next->ty == Tclass && to->next->ty == Tclass)
	{   ClassDeclaration *cd;
	    ClassDeclaration *cdto;

	    cd   = dynamic_cast<TypeClass *>(next)->sym;
	    cdto = dynamic_cast<TypeClass *>(to->next)->sym;
	    if (cdto->isBaseOf(cd))
		return 1;
	}
#endif
	if (next->ty == Tfunction && to->next->ty == Tfunction)
	{   TypeFunction *tf;
	    TypeFunction *tfto;

	    tf   = dynamic_cast<TypeFunction *>(next);
	    tfto = dynamic_cast<TypeFunction *>(to->next);
	    return tfto->equals(tf) ? 2 : 0;
	}
    }
    return 0;
}

int TypePointer::isscalar()
{
    return TRUE;
}

Expression *TypePointer::defaultInit()
{
    Expression *e;
    e = new NullExp(0);
    e->type = this;
    return e;
}


/***************************** TypeReference *****************************/

TypeReference::TypeReference(Type *t)
    : Type(Treference, t)
{
    if (t->ty == Tbit)
	error(0,"cannot make reference to a bit");
    // BUG: what about references to static arrays?
}

Type *TypeReference::syntaxCopy()
{
    Type *t = next->syntaxCopy();
    if (t == next)
	t = this;
    else
	t = new TypeReference(t);
    return t;
}

unsigned TypeReference::size()
{
    return 4;
}

void TypeReference::toCBuffer2(OutBuffer *buf, Identifier *ident)
{
    buf->prependstring("&");
    if (ident)
    {
	buf->writestring(ident->toChars());
    }
    next->toCBuffer2(buf, NULL);
}

Expression *TypeReference::dotExp(Scope *sc, Expression *e, Identifier *ident)
{
#if LOGDOTEXP
    printf("TypeReference::dotExp(e = '%s', ident = '%s')\n", e->toChars(), ident->toChars());
#endif

    // References just forward things along
    return next->dotExp(sc, e, ident);
}

Expression *TypeReference::defaultInit()
{
    Expression *e;
    e = new NullExp(0);
    e->type = this;
    return e;
}


/***************************** TypeFunction *****************************/

TypeFunction::TypeFunction(Array *arguments, Type *treturn, int varargs, enum LINK linkage)
    : Type(Tfunction, treturn)
{
    this->arguments = arguments;
    this->varargs = varargs;
    this->linkage = linkage;
}

Type *TypeFunction::syntaxCopy()
{
    Type *treturn = next->syntaxCopy();
    Array *args = NULL;
    if (arguments)
    {
	args = new Array();
	args->setDim(arguments->dim);
	for (int i = 0; i < args->dim; i++)
	{   Argument *arg;
	    Argument *a;

	    arg = (Argument *)arguments->data[i];
	    a = new Argument(arg->type->syntaxCopy(), arg->ident, arg->inout);
	    args->data[i] = (void *)a;
	}
    }
    Type *t = new TypeFunction(args, treturn, varargs, linkage);
    return t;
}


void TypeFunction::toDecoBuffer(OutBuffer *buf)
{   unsigned char mc;

    switch (linkage)
    {
	case LINKd:		mc = 'F';	break;
	case LINKc:		mc = 'U';	break;
	case LINKwindows:	mc = 'W';	break;
	case LINKpascal:	mc = 'V';	break;
	case LINKcpp:		mc = 'T';	break;
	default:
	    assert(0);
    }
    buf->writeByte(mc);
    // Write arguments
    if (arguments)
    {	int i;

	for (i = 0; i < arguments->dim; i++)
	{   Argument *arg;

	    arg = (Argument *)arguments->data[i];
	    // BUG: what about out and inout parameters?
	    arg->type->toDecoBuffer(buf);
	}
    }
    buf->writeByte(varargs ? 'Y' : 'Z');		// mark end of arg list
    next->toDecoBuffer(buf);
}

void TypeFunction::toCBuffer2(OutBuffer *buf, Identifier *ident)
{
    char *p;

    switch (linkage)
    {
	case LINKd:		p = NULL;	break;
	case LINKc:		p = "C ";	break;
	case LINKwindows:	p = "Windows ";	break;
	case LINKpascal:	p = "Pascal ";	break;
	case LINKcpp:		p = "C++ ";	break;
	default:
	    assert(0);
    }

    if (buf->offset)
    {	if (p)
	    buf->prependstring(p);
	buf->bracket('(', ')');
	assert(!ident);
    }
    else
    {
	if (p)
	    buf->writestring(p);
	if (ident)
	{   buf->writeByte(' ');
	    buf->writestring(ident->toChars());
	}
    }
    buf->writeByte('(');
    if (arguments)
    {	int i;
	OutBuffer argbuf;

	for (i = 0; i < arguments->dim; i++)
	{   Argument *arg;

	    arg = (Argument *)arguments->data[i];
	    argbuf.reset();
	    if (arg->inout == Out)
		argbuf.writestring("out ");
	    else if (arg->inout == InOut)
		argbuf.writestring("inout ");
	    arg->type->toCBuffer2(&argbuf, arg->ident);
	    if (i)
		buf->writeByte(',');
	    buf->write(&argbuf);
	}
	if (varargs)
	{
	    if (i)
		buf->writeByte(',');
	    buf->writestring("...");
	}
    }
    buf->writeByte(')');
    next->toCBuffer2(buf, NULL);
}

Type *TypeFunction::semantic(Loc loc, Scope *sc)
{
    if (deco)			// if semantic() already run
    {
	//printf("already done\n");
	return this;
    }
    next = next->semantic(loc,sc);
    if (next->toBasetype()->ty == Tsarray)
	error(loc, "functions cannot return static array %s", next->toChars());
    if (next->isauto() && !(sc->flags & SCOPEctor))
	error(loc, "functions cannot return auto %s", next->toChars());

    if (arguments)
    {	int i;

	for (i = 0; i < arguments->dim; i++)
	{   Argument *arg;
	    Type *t;

	    arg = (Argument *)arguments->data[i];
	    arg->type = arg->type->semantic(loc,sc);
	    t = arg->type->toBasetype();
	    if (arg->inout != In)
	    {
		if (t->ty == Tbit || t->ty == Tsarray)
		    error(loc, "cannot have out parameter of type %s", t->toChars());
	    }
	    if (t->ty == Tvoid)
		error(loc, "cannot have parameter of type %s", arg->type->toChars());
	}
    }
    deco = merge()->deco;

    // Don't return merge(), because arg identifiers can be different
    // even though the types match
    return this;
}

/********************************
 * Assume 'toargs' are being matched to function 'this'
 * Determine match level.
 * Returns:
 *	0	no match
 *	1	match with conversions
 *	2	exact match
 */

int TypeFunction::callMatch(Array *toargs)
{
    unsigned u;
    unsigned nargsf;
    unsigned nargst;
    int match;

    //printf("TypeFunction::callMatch()\n");
    match = 2;				// assume exact match

    nargsf = arguments ? arguments->dim : 0;
    nargst = toargs ? toargs->dim : 0;
    if (nargsf == nargst)
	;
    else if (nargsf > nargst)
	goto Nomatch;			// not enough args; no match
    else
    {
	if (!varargs)
	    goto Nomatch;		// too many args; no match
	match = 1;			// match ... with a "conversion" match level
    }

    for (u = 0; u < nargsf; u++)
    {	int m;
	Argument *af;
	Expression *ae;

	// BUG: what about out and inout?
	af = (Argument *)arguments->data[u];
	assert(af);
	ae = (Expression *)toargs->data[u];
	assert(ae);
	m = ae->implicitConvTo(af->type);
	if (m == 0)
	    goto Nomatch;		// no match for this argument
	if (m < match)
	    match = m;			// pick worst match
    }

    return match;

Nomatch:
    //printf("no match\n");
    return 0;
}

/***************************** TypeDelegate *****************************/

TypeDelegate::TypeDelegate(Type *t)
    : Type(Tfunction, t)
{
    ty = Tdelegate;
}

Type *TypeDelegate::syntaxCopy()
{
    Type *t = next->syntaxCopy();
    if (t == next)
	t = this;
    else
	t = new TypeDelegate(t);
    return t;
}

Type *TypeDelegate::semantic(Loc loc, Scope *sc)
{
    if (deco)			// if semantic() already run
    {
	//printf("already done\n");
	return this;
    }
    next = next->semantic(loc,sc);
    return merge();
}

unsigned TypeDelegate::size()
{
    return 8;
}

void TypeDelegate::toCBuffer2(OutBuffer *buf, Identifier *ident)
{
    next->toCBuffer2(buf, Id::delegate);
    if (ident)
    {
	buf->writestring(ident->toChars());
    }
}

Expression *TypeDelegate::defaultInit()
{
    Expression *e;
    e = new NullExp(0);
    e->type = this;
    return e;
}

int TypeDelegate::checkBoolean()
{
    return TRUE;
}

/***************************** TypeIdentifier *****************************/

TypeIdentifier::TypeIdentifier(Loc loc, Identifier *ident)
    : Type(Tident, NULL)
{
    this->loc = loc;
    this->idents.push(ident);
}


Type *TypeIdentifier::syntaxCopy()
{
    TypeIdentifier *t;

    t = new TypeIdentifier(loc, (Identifier *)idents.data[0]);
    t->idents.setDim(idents.dim);
    for (int i = 0; i < idents.dim; i++)
	t->idents.data[i] = idents.data[i];
    return t;
}


void TypeIdentifier::addIdent(Identifier *ident)
{
    idents.push(ident);
}

void TypeIdentifier::toCBuffer2(OutBuffer *buf, Identifier *ident)
{
    int i;

    for (i = idents.dim; i--;)
    {	Identifier *id = (Identifier *)idents.data[i];

	buf->prependstring(id->toChars());
	if (i)
	    buf->prependbyte('.');
    }
    if (ident)
    {	buf->writeByte(' ');
	buf->writestring(ident->toChars());
    }
}

/*************************************
 * Takes an array of Identifiers and figures out if
 * it represents a Type or an Expression.
 * Output:
 *	if expression, *pe is set
 *	if type, *pt is set
 */

void TypeIdentifier::resolve(Scope *sc, Expression **pe, Type **pt)
{   Dsymbol *s;
    Dsymbol *scopesym;
    Identifier *id;
    int i;
    VarDeclaration *v;
    EnumMember *em;
    Type *t;
    Expression *e;

    id = (Identifier *)idents.data[0];
    //printf("TypeIdentifier::resolve(sc = %p, idents = '%s')\n", sc, toChars());
    *pe = NULL;
    *pt = NULL;
    s = sc->search(id, &scopesym);
    if (s)
    {
	//printf("\ts = '%s' %p\n",s->toChars(), s);

	assert(!dynamic_cast<WithScopeSymbol *>(scopesym));	// BUG: should handle this

	s = s->toAlias();
	for (i = 1; i < idents.dim; i++)
	{   Dsymbol *sm;

	    id = (Identifier *)idents.data[i];
	    sm = s->search(id);
	    if (!sm)
	    {
		t = s->getType();
		if (t)
		{
		    e = t->getProperty(0, id);
		    i++;
		    for (; i < idents.dim; i++)
		    {
			id = (Identifier *)idents.data[i];
			e = e->type->dotExp(sc, e, id);
		    }
		    *pe = e;
		}
		else
		    error(loc, "identifier '%s' of '%s' is not defined", id->toChars(), toChars());
		return;
	    }
	    s = sm->toAlias();
	}

	v = dynamic_cast<VarDeclaration *>(s);
	if (v)
	{
	    // It's not a type, it's an expression
	    if (v->isConst())
	    {
		ExpInitializer *ei = dynamic_cast<ExpInitializer *>(v->init);
		assert(ei);
		*pe = ei->exp->copy();	// make copy so we can change loc
		(*pe)->loc = loc;
	    }
	    else
		*pe = new VarExp(loc, v);
	    return;
	}
	em = dynamic_cast<EnumMember *>(s);
	if (em)
	{
	    // It's not a type, it's an expression
	    *pe = em->value->copy();
	    return;
	}

L1:
	t = s->getType();
	if (!t)
	{
	    // If the symbol is an import, try looking inside the import
	    Import *si;

	    si = dynamic_cast<Import *>(s);
	    if (si)
	    {
		s = si->search(id);
		if (s)
		    goto L1;
		s = si;
	    }
	    s->error("is used as a type");
	}
	if (t->ty == Tident && t != this)
	{
	    ((TypeIdentifier *)t)->resolve(sc, pe, &t);
	}
	*pt = t->merge();
    }
    if (!s)
	error(loc, "identifier '%s' is not defined", toChars());
}

Type *TypeIdentifier::semantic(Loc loc, Scope *sc)
{
    Type *t;
    Expression *e;
    Identifier *id;

    //printf("TypeIdentifier::semantic(%s)\n", toChars());
    resolve(sc, &e, &t);
    if (!t)
    {
	id = (Identifier *)idents.data[0];
	error(loc, "%s is used as a type", id->toChars());
	t = this->merge();
    }
    return t;
}

unsigned TypeIdentifier::size()
{
    error(loc, "size of type %s is not known", toChars());
    return 1;
}

/***************************** TypeInstance *****************************/

TypeInstance::TypeInstance(Loc loc, TemplateInstance *tempinst)
    : Type(Tinstance, NULL)
{
    this->loc = loc;
    this->tempinst = tempinst;
}

Type *TypeInstance::syntaxCopy()
{
    TypeInstance *t;

    t = new TypeInstance(loc, (TemplateInstance *)tempinst->syntaxCopy(NULL));
    t->idents.setDim(idents.dim);
    for (int i = 0; i < idents.dim; i++)
	t->idents.data[i] = idents.data[i];
    return t;
}


void TypeInstance::addIdent(Identifier *ident)
{
    idents.push(ident);
}

void TypeInstance::toCBuffer2(OutBuffer *buf, Identifier *ident)
{
    int i;

    tempinst->toCBuffer(buf);
    for (i = 0; i < idents.dim; i++)
    {	Identifier *id = (Identifier *)idents.data[i];

	buf->writeByte('.');
	buf->writestring(id->toChars());
    }
    if (ident)
    {	buf->writeByte(' ');
	buf->writestring(ident->toChars());
    }
}

void TypeInstance::resolve(Scope *sc, Expression **pe, Type **pt)
{
    // Note close similarity to TypeIdentifier::resolve()

    Dsymbol *s;
    Identifier *id;
    int i;
    VarDeclaration *v;
    EnumMember *em;
    Type *t;
    Expression *e;

    id = (Identifier *)idents.data[0];
    //printf("TypeInstance::resolve(sc = %p, idents = '%s')\n", sc, id->toChars());
    *pe = NULL;
    *pt = NULL;
    s = tempinst;
    if (s)
    {
	//printf("\ts = '%s' %p\n",s->toChars(), s);
	s->semantic(sc);
	s = s->toAlias();
	for (i = 0; i < idents.dim; i++)
	{   Dsymbol *sm;

	    id = (Identifier *)idents.data[i];
	    sm = s->search(id);
	    if (!sm)
	    {
		t = s->getType();
		if (t)
		{
		    e = t->getProperty(0, id);
		    i++;
		    for (; i < idents.dim; i++)
		    {
			id = (Identifier *)idents.data[i];
			e = e->type->dotExp(sc, e, id);
		    }
		    *pe = e;
		}
		else
		    error(loc, "identifier '%s' of '%s' is not defined", id->toChars(), toChars());
		return;
	    }
	    s = sm->toAlias();
	}

	v = dynamic_cast<VarDeclaration *>(s);
	if (v)
	{
	    // It's not a type, it's an expression
	    if (v->isConst())
	    {
		ExpInitializer *ei = dynamic_cast<ExpInitializer *>(v->init);
		assert(ei);
		*pe = ei->exp->copy();	// make copy so we can change loc
		(*pe)->loc = loc;
	    }
	    else
		*pe = new VarExp(loc, v);
	    return;
	}
	em = dynamic_cast<EnumMember *>(s);
	if (em)
	{
	    // It's not a type, it's an expression
	    *pe = em->value->copy();
	    return;
	}

L1:
	t = s->getType();
	if (!t)
	{
	    // If the symbol is an import, try looking inside the import
	    Import *si;

	    si = dynamic_cast<Import *>(s);
	    if (si)
	    {
		s = si->search(id);
		if (s)
		    goto L1;
		s = si;
	    }
	    s->error("is used as a type");
	}
	if (t->ty == Tident && t != this)
	{
	    ((TypeInstance *)t)->resolve(sc, pe, &t);
	}
	*pt = t->merge();
    }
    if (!s)
	error(loc, "identifier '%s' is not defined", toChars());
}

Type *TypeInstance::semantic(Loc loc, Scope *sc)
{
    Type *t;
    Expression *e;
    Identifier *id;

    //printf("TypeInstance::semantic(%s)\n", toChars());
    resolve(sc, &e, &t);
    if (!t)
    {
	id = (Identifier *)idents.data[0];
	error(loc, "%s is used as a type", id->toChars());
	t = tvoid;
    }
    return t;
}

unsigned TypeInstance::size()
{
    error(loc, "size of type %s is not known", toChars());
    return 1;
}

/***************************** TypeEnum *****************************/

TypeEnum::TypeEnum(EnumDeclaration *sym)
	: Type(Tenum, NULL)
{
    this->sym = sym;
}

char *TypeEnum::toChars()
{
    return sym->toChars();
}

Type *TypeEnum::semantic(Loc loc, Scope *sc)
{
    sym->semantic(sc);
    return merge();
}

unsigned TypeEnum::size()
{
    if (!sym->memtype)
    {
	error(0, "enum %s is forward referenced", sym->toChars());
	return 4;
    }
    return sym->memtype->size();
}

unsigned TypeEnum::alignsize()
{
    assert(sym->memtype);
    return sym->memtype->alignsize();
}

Type *TypeEnum::toBasetype()
{
    if (!sym->memtype)
    {
	error(0, "enum %s is forward referenced", sym->toChars());
	return tint32;
    }
    return sym->memtype->toBasetype();
}

void TypeEnum::toDecoBuffer(OutBuffer *buf)
{   unsigned len;
    char *name;

    name = sym->toChars();
    len = strlen(name);
    buf->printf("%c%d%s", mangleChar[ty], len, name);
}

void TypeEnum::toTypeInfoBuffer(OutBuffer *buf)
{
    toBasetype()->toTypeInfoBuffer(buf);
}

void TypeEnum::toCBuffer2(OutBuffer *buf, Identifier *ident)
{
    buf->prependbyte(' ');
    buf->prependstring(sym->toChars());
    if (ident)
	buf->writestring(ident->toChars());
}

Expression *TypeEnum::dotExp(Scope *sc, Expression *e, Identifier *ident)
{
    EnumMember *m;
    Dsymbol *s;
    Expression *em;

    s = sym->symtab->lookup(ident);
    if (!s)
    {
	return getProperty(e->loc, ident);
    }
    m = dynamic_cast<EnumMember *>(s);
    em = m->value->copy();
    em->loc = e->loc;
    return em;
}

Expression *TypeEnum::getProperty(Loc loc, Identifier *ident)
{   Expression *e;

    if (ident == Id::max)
    {
	e = new IntegerExp(0, sym->maxval, this);
    }
    else if (ident == Id::min)
    {
	e = new IntegerExp(0, sym->minval, this);
    }
    else
    {
	assert(sym->memtype);
	e = sym->memtype->getProperty(loc, ident);
    }
    return e;
}

int TypeEnum::isintegral()
{
    return sym->memtype->isintegral();
}

int TypeEnum::isfloating()
{
    return sym->memtype->isfloating();
}

int TypeEnum::isunsigned()
{
    return sym->memtype->isunsigned();
}

int TypeEnum::isscalar()
{
    return sym->memtype->isscalar();
}

int TypeEnum::implicitConvTo(Type *to)
{   int m;

    //printf("TypeEnum::implicitConvTo()\n");
    if (this->equals(to))
	m = 2;			// exact match
    else if (sym->memtype->implicitConvTo(to))
	m = 1;			// match with conversions
    else
	m = 0;			// no match
    return m;
}

Expression *TypeEnum::defaultInit()
{
    // Initialize to first member of enum
    Expression *e;
    e = new IntegerExp(0, sym->defaultval, this);
    return e;
}


/***************************** TypeTypedef *****************************/

TypeTypedef::TypeTypedef(TypedefDeclaration *sym)
	: Type(Ttypedef, NULL)
{
    this->sym = sym;
}

char *TypeTypedef::toChars()
{
    return sym->toChars();
}

Type *TypeTypedef::semantic(Loc loc, Scope *sc)
{
    sym->semantic(sc);
    return merge();
}

unsigned TypeTypedef::size()
{
    return sym->basetype->size();
}

unsigned TypeTypedef::alignsize()
{
    return sym->basetype->alignsize();
}

void TypeTypedef::toDecoBuffer(OutBuffer *buf)
{   unsigned len;
    char *name;

    name = sym->toChars();
    len = strlen(name);
    buf->printf("%c%d%s", mangleChar[ty], len, name);
}

void TypeTypedef::toTypeInfoBuffer(OutBuffer *buf)
{
    sym->basetype->toTypeInfoBuffer(buf);
}

void TypeTypedef::toCBuffer2(OutBuffer *buf, Identifier *ident)
{
    buf->prependbyte(' ');
    buf->prependstring(sym->toChars());
    if (ident)
	buf->writestring(ident->toChars());
}

Expression *TypeTypedef::dotExp(Scope *sc, Expression *e, Identifier *ident)
{
    if (ident == Id::init)
    {
	if (e->op == TOKvar)
	{
	    VarExp *ve = (VarExp *)e;
	    VarDeclaration *v = dynamic_cast<VarDeclaration *>(ve->var);

	    assert(v);
	    if (v->init)
		return v->init->toExpression();
	}
	return defaultInit();
    }
    return sym->basetype->dotExp(sc, e, ident);
}

int TypeTypedef::isbit()
{
    return sym->basetype->isbit();
}

int TypeTypedef::isintegral()
{
    //printf("TypeTypedef::isintegral()\n");
    //printf("sym = '%s'\n", sym->toChars());
    //printf("basetype = '%s'\n", sym->basetype->toChars());
    return sym->basetype->isintegral();
}

int TypeTypedef::isfloating()
{
    return sym->basetype->isfloating();
}

int TypeTypedef::isunsigned()
{
    return sym->basetype->isunsigned();
}

int TypeTypedef::isscalar()
{
    return sym->basetype->isscalar();
}

int TypeTypedef::checkBoolean()
{
    return sym->basetype->checkBoolean();
}

Type *TypeTypedef::toBasetype()
{
    return sym->basetype->toBasetype();
}

int TypeTypedef::implicitConvTo(Type *to)
{   int m;

    //printf("TypeTypedef::implicitConvTo()\n");
    if (this->equals(to))
	m = 2;			// exact match
    else if (sym->basetype->implicitConvTo(to))
	m = 1;			// match with conversions
    else
	m = 0;			// no match
    return m;
}

Expression *TypeTypedef::defaultInit()
{   Expression *e;
    Type *bt;

    if (sym->init)
	return sym->init->toExpression();
    bt = sym->basetype;
    e = bt->defaultInit();
    e->type = this;
    while (bt->ty == Tsarray)
    {
	e->type = bt->next;
	bt = bt->next->toBasetype();
    }
    return e;
}

/***************************** TypeStruct *****************************/

TypeStruct::TypeStruct(StructDeclaration *sym)
	: Type(Tstruct, NULL)
{
    this->sym = sym;
}

char *TypeStruct::toChars()
{
    return sym->toChars();
}

Type *TypeStruct::semantic(Loc loc, Scope *sc)
{
    //printf("TypeStruct::semantic('%s')\n", sym->toChars());
    sym->semantic(sc);
    return merge();
}

unsigned TypeStruct::size()
{
    return sym->size();
}

unsigned TypeStruct::alignsize()
{   unsigned sz;

    sym->size();		// give error for forward references
    sz = sym->alignsize;
    if (sz > sym->structalign)
	sz = sym->structalign;
    return sz;
}

void TypeStruct::toDecoBuffer(OutBuffer *buf)
{   unsigned len;
    OutBuffer buf2;
    Dsymbol *s;

    s = sym;
    do
    {
	if (buf2.offset)
	    buf2.prependstring("_");
	buf2.prependstring(s->toChars());
	s = s->parent;
    } while (s);
    len = buf2.offset;
    buf2.writeByte(0);
    buf->printf("%c%d%s", mangleChar[ty], len, buf2.data);
}

void TypeStruct::toTypeInfoBuffer(OutBuffer *buf)
{
    toDecoBuffer(buf);
}


void TypeStruct::toCBuffer2(OutBuffer *buf, Identifier *ident)
{
    buf->prependbyte(' ');
    buf->prependstring(sym->toChars());
    if (ident)
	buf->writestring(ident->toChars());
}

Expression *TypeStruct::dotExp(Scope *sc, Expression *e, Identifier *ident)
{   unsigned offset;

    Expression *b;
    VarDeclaration *v;
    Dsymbol *s;
    DotVarExp *de;
    Declaration *d;

#if LOGDOTEXP
    printf("TypeStruct::dotExp(e = '%s', ident = '%s')\n", e->toChars(), ident->toChars());
#endif
    s = sym->symtab->lookup(ident);
    if (!s)
    {
	return getProperty(e->loc, ident);
    }
    v = dynamic_cast<VarDeclaration *>(s);
    if (v && v->isConst())
    {	ExpInitializer *ei = dynamic_cast<ExpInitializer *>(v->init);

	if (ei)
	    return ei->exp;
    }

    if (s->getType())
    {
	return new DotTypeExp(e->loc, e, s);
    }

    EnumMember *em = dynamic_cast<EnumMember *>(s);
    if (em)
    {
	assert(em->value);
	return em->value->copy();
    }

    d = dynamic_cast<Declaration *>(s);
    assert(d);

    if (e->op == TOKtype)
    {	FuncDeclaration *fd = sc->func;

	if (d->needThis() && fd && fd->vthis)
	{
	    e = new DotVarExp(e->loc, new ThisExp(e->loc), d);
	    e = e->semantic(sc);
	    return e;
	}
	return new VarExp(e->loc, d);
    }

    if (d->isStatic())
    {
	// (e, d)
	b = new VarExp(e->loc, d);
	e = new CommaExp(e->loc, e, b);
	e->type = d->type;
	return e;
    }

    if (v)
    {
	// *(&e + offset)
	b = new AddrExp(e->loc, e);
	b->type = e->type->pointerTo();
	b = new AddExp(e->loc, b, new IntegerExp(e->loc, v->offset, Type::tint32));
	b->type = v->type->pointerTo();
	e = new PtrExp(e->loc, b);
	e->type = v->type;
	return e;
    }

    de = new DotVarExp(e->loc, e, d);
    return de->semantic(sc);
}

unsigned TypeStruct::memalign(unsigned salign)
{
    sym->size();		// give error for forward references
    return sym->structalign;
}

Expression *TypeStruct::defaultInit()
{   Symbol *s;
    Declaration *d;

    s = sym->toInitializer();
    d = new SymbolDeclaration(sym->loc, s);
    assert(d);
    d->type = this;
    return new VarExp(sym->loc, d);
}


/***************************** TypeClass *****************************/

TypeClass::TypeClass(ClassDeclaration *sym)
	: Type(Tclass, NULL)
{
    this->sym = sym;
}

char *TypeClass::toChars()
{
printf("sym->parent = '%s'\n", sym->parent->toChars());
    return sym->toChars();
}

Type *TypeClass::semantic(Loc loc, Scope *sc)
{
    return merge();
}

unsigned TypeClass::size()
{
    return 4;
}

void TypeClass::toDecoBuffer(OutBuffer *buf)
{   unsigned len;
    char *name;

    //name = sym->toChars();
    name = sym->mangle();
    len = strlen(name);
    buf->printf("%c%d%s", mangleChar[ty], len, name);
}

void TypeClass::toCBuffer2(OutBuffer *buf, Identifier *ident)
{
    buf->prependbyte(' ');
    buf->prependstring(sym->toChars());
    if (ident)
	buf->writestring(ident->toChars());
}

Expression *TypeClass::dotExp(Scope *sc, Expression *e, Identifier *ident)
{   unsigned offset;

    Expression *b;
    VarDeclaration *v;
    Dsymbol *s;
    DotVarExp *de;
    Declaration *d;

#if LOGDOTEXP
    printf("TypeClass::dotExp(e='%s', ident='%s')\n", e->toChars(), ident->toChars());
#endif
    s = sym->search(ident);
    if (!s)
    {
	// See if it's a base class
	ClassDeclaration *cbase;
	for (cbase = sym->baseClass; cbase; cbase = cbase->baseClass)
	{
	    if (cbase->ident->equals(ident))
	    {
		e = new DotTypeExp(NULL, e, cbase);
		return e;
	    }
	}

	if (ident == Id::classinfo)
	{
	    Type *t;

	    assert(ClassDeclaration::classinfo);
	    t = ClassDeclaration::classinfo->type;
	    if (e->op == TOKtype)
	    {
		if (!sym->vclassinfo)
		    sym->vclassinfo = new ClassInfoDeclaration(sym);
		e = new VarExp(e->loc, sym->vclassinfo);
		e = e->addressOf();
		e->type = t;		// do this so we don't get redundant dereference
	    }
	    else
	    {
		if (sym->isInterface())
		    error(e->loc, "no .classinfo for interface objects");
		e = new PtrExp(e->loc, e);
		e->type = t->pointerTo();
		e = new PtrExp(e->loc, e, t);
	    }
	    return e;
	}

	return getProperty(e->loc, ident);
    }
    v = dynamic_cast<VarDeclaration *>(s);
    if (v && v->isConst())
    {	ExpInitializer *ei = dynamic_cast<ExpInitializer *>(v->init);

	assert(ei);
	return ei->exp;
    }

    if (s->getType())
    {
	return new DotTypeExp(e->loc, e, s);
    }

    EnumMember *em = dynamic_cast<EnumMember *>(s);
    if (em)
    {
	assert(em->value);
	return em->value->copy();
    }

    d = dynamic_cast<Declaration *>(s);
    assert(d);

    if (e->op == TOKtype)
    {
	VarExp *ve;

	if (d->needThis())
	{
	    if (sc->func)
	    {
		ClassDeclaration *thiscd;
		thiscd = dynamic_cast<ClassDeclaration *>(sc->func->parent);

		if (thiscd)
		{
		    ClassDeclaration *cd = e->type->isClassHandle();
		    if (!cd || !cd->isBaseOf(thiscd, NULL))
			e->error("'this' is required, but %s is not a base class of %s", e->type->toChars(), thiscd->toChars());
		}
	    }

	    de = new DotVarExp(e->loc, new ThisExp(e->loc), d);
	    e = de->semantic(sc);
	    return e;
	}
	else
	    ve = new VarExp(e->loc, d);
	return ve;
    }

    if (d->isStatic())
    {
	// (e, d)
	VarExp *ve;

	accessCheck(e->loc, sc, e, d);
	ve = new VarExp(e->loc, d);
	e = new CommaExp(e->loc, e, ve);
	e->type = d->type;
	return e;
    }

    de = new DotVarExp(e->loc, e, d);
    return de->semantic(sc);
}

ClassDeclaration *TypeClass::isClassHandle()
{
    return sym;
}

int TypeClass::isauto()
{
    return sym->isauto;
}


int TypeClass::implicitConvTo(Type *to)
{
    //printf("TypeClass::implicitConvTo()\n");
    if (this == to)
	return 2;

    ClassDeclaration *cdto = to->isClassHandle();
    if (cdto && cdto->isBaseOf(sym, NULL))
	return 1;

    // Allow conversion to (void *)
    if (to->ty == Tpointer && to->next->ty == Tvoid)
	return 1;

    return 0;
}

Expression *TypeClass::defaultInit()
{
    //printf("TypeClass::defaultInit()\n");
    Expression *e;
    e = new NullExp(0);
    e->type = this;
    return e;
}

Expression *TypeClass::getProperty(Loc loc, Identifier *ident)
{   Expression *e;
    static TypeInfoDeclaration *tid;	// one TypeInfo for all class objects

    if (ident == Id::typeinfo)
    {
	if (!tid)
	    tid = new TypeInfoDeclaration(this);
	vtinfo = tid;
	e = new VarExp(0, vtinfo);
	e = e->addressOf();
	e->type = vtinfo->type;		// do this so we don't get redundant dereference
    }
    else
    {
	e = Type::getProperty(loc, ident);
    }
    return e;
}

int TypeClass::checkBoolean()
{
    return TRUE;
}



/***************************** Argument *****************************/

Argument::Argument(Type *type, Identifier *ident, enum InOut inout)
{
    this->type = type;
    this->ident = ident;
    this->inout = inout;
}
