
// Copyright (c) 1999-2004 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#include <stdio.h>
#include <assert.h>

#ifdef __DMC__
#include <fp.h>
#endif

#include <float.h>
#include <complex.h>

#ifdef __APPLE__
#include <math.h>
static double zero = 0;
#elif __GNUC__
#include <math.h>
#include <bits/nan.h>
#include <bits/mathdef.h>
static double zero = 0;
#endif

#include "mem.h"

#include "mtype.h"
#include "scope.h"
#include "init.h"
#include "expression.h"
#include "attrib.h"
#include "declaration.h"
#include "template.h"
#include "id.h"
#include "enum.h"
#include "import.h"
#include "aggregate.h"


#define LOGDOTEXP	0	// log ::dotExp()
#define LOGDEFAULTINIT	0	// log ::defaultInit()

/* These have default values for 32 bit code, they get
 * adjusted for 64 bit code.
 */

int PTRSIZE = 4;
int REALSIZE = 10;
int Tsize_t = Tuns32;
int Tptrdiff_t = Tint32;

/***************************** Type *****************************/

ClassDeclaration *Type::typeinfo;
ClassDeclaration *Type::typeinfoclass;
ClassDeclaration *Type::typeinfostruct;
ClassDeclaration *Type::typeinfotypedef;

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
    this->ctype = NULL;
}

Type *Type::syntaxCopy()
{
    print();
    printf("ty = %d\n", ty);
    assert(0);
    return this;
}

int Type::equals(Object *o)
{   Type *t;

    t = (Type *)o;
    if (this == o ||
	(t && deco == t->deco) &&		// deco strings are unique
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
    mangleChar[Tdchar] = 'w';

    mangleChar[Tinstance] = '@';
    mangleChar[Terror] = '@';
    mangleChar[Ttypeof] = '@';

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
	  Tascii, Twchar, Tdchar };

    for (i = 0; i < sizeof(basetab) / sizeof(basetab[0]); i++)
	basic[basetab[i]] = new TypeBasic(basetab[i]);
    basic[Terror] = basic[Tint32];

    if (global.params.isAMD64)
    {
	PTRSIZE = 8;
	if (global.params.isLinux)
	    REALSIZE = 10;
	else
	    REALSIZE = 8;
	Tsize_t = Tuns64;
	Tptrdiff_t = Tint64;
    }
    else
    {
	PTRSIZE = 4;
	REALSIZE = 10;
	Tsize_t = Tuns32;
	Tptrdiff_t = Tint32;
    }
}

d_uns64 Type::size()
{
    return size(0);
}

d_uns64 Type::size(Loc loc)
{
    error(loc, "no size for type %s", toChars());
    return 0;
}

unsigned Type::alignsize()
{
    return size(0);
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

Dsymbol *Type::toDsymbol(Scope *sc)
{
    return NULL;
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
    {
	assert(next != this);
	//printf("this = %p, ty = %d, next = %p, ty = %d\n", this, this->ty, next, next->ty);
	next->toDecoBuffer(buf);
    }
}

/********************************
 * Name mangling.
 */

void Type::toTypeInfoBuffer(OutBuffer *buf)
{
    assert(0);
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

    //printf("merge(%s)\n", toChars());
    t = this;
    assert(t);
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
#if LOGDEFAULTINIT
    printf("Type::defaultInit() '%s'\n", toChars());
#endif
    return NULL;
}

int Type::isZeroInit()
{
    return 0;		// assume not
}

int Type::isBaseOf(Type *t)
{
    return 0;		// assume not
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
    if (this == to)
	return MATCHexact;
//    if (to->ty == Tvoid)
//	return 1;
    return 0;
}

Expression *Type::getProperty(Loc loc, Identifier *ident)
{   Expression *e;

    if (ident == Id::__sizeof)
    {
	e = new IntegerExp(loc, size(loc), Type::tsize_t);
    }
    else if (ident == Id::size)
    {
	if (!global.params.useDeprecated)
	    error(loc, ".size property is deprecated, use .sizeof");
	e = new IntegerExp(loc, size(loc), Type::tsize_t);
    }
    else if (ident == Id::alignof)
    {
	e = new IntegerExp(loc, alignsize(), Type::tsize_t);
    }
    else if (ident == Id::typeinfo)
    {
	if (!global.params.useDeprecated)
	    error(loc, ".typeinfo deprecated, use typeid(type)");
	e = getTypeInfo(NULL);
    }
    else if (ident == Id::init)
    {
	e = defaultInit();
	e->loc = loc;
    }
    else
    {
	error(loc, "no property '%s' for type '%s'", ident->toChars(), toChars());
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
	v = dv->var->isVarDeclaration();
    }
    else if (e->op == TOKvar)
    {
	VarExp *ve = (VarExp *)e;
	v = ve->var->isVarDeclaration();
    }
    if (v)
    {
	if (ident == Id::offset)
	{
	    if (!global.params.useDeprecated)
		error(e->loc, ".offset deprecated, use .offsetof");
	    goto Loffset;
	}
	else if (ident == Id::offsetof)
	{
	  Loffset:
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
    //fatal();
}

Identifier *Type::getTypeInfoIdent(int internal)
{
    // _init_10TypeInfo_%s
    OutBuffer buf;
    Identifier *id;
    char *name;
    int len;

    //toTypeInfoBuffer(&buf);
    if (internal)
    {	buf.writeByte(mangleChar[ty]);
	if (ty == Tarray)
	    buf.writeByte(mangleChar[next->ty]);
    }
    else
	toDecoBuffer(&buf);
    name = (char *)alloca(15 + sizeof(len) * 3 + buf.offset + 1);
    buf.writeByte(0);
    len = strlen((char *)buf.data);
    sprintf(name, "_init_%dTypeInfo_%s", 9 + len, buf.data);
    id = Lexer::idPool(name);
    return id;
}

TypeBasic *Type::isTypeBasic()
{
    return NULL;
}


void Type::resolve(Loc loc, Scope *sc, Expression **pe, Type **pt, Dsymbol **ps)
{
    Type *t;

    t = semantic(loc, sc);
    *pt = t;
    *pe = NULL;
    *ps = NULL;
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
			c = "real";
			flags |= TFLAGSfloating | TFLAGSreal;
			break;

	case Timaginary32: d = Token::toChars(TOKimaginary32);
			c = "ifloat";
			flags |= TFLAGSfloating | TFLAGSimaginary;
			break;

	case Timaginary64: d = Token::toChars(TOKimaginary64);
			c = "idouble";
			flags |= TFLAGSfloating | TFLAGSimaginary;
			break;

	case Timaginary80: d = Token::toChars(TOKimaginary80);
			c = "ireal";
			flags |= TFLAGSfloating | TFLAGSimaginary;
			break;

	case Tcomplex32: d = Token::toChars(TOKcomplex32);
			c = "cfloat";
			flags |= TFLAGSfloating | TFLAGScomplex;
			break;

	case Tcomplex64: d = Token::toChars(TOKcomplex64);
			c = "cdouble";
			flags |= TFLAGSfloating | TFLAGScomplex;
			break;

	case Tcomplex80: d = Token::toChars(TOKcomplex80);
			c = "creal";
			flags |= TFLAGSfloating | TFLAGScomplex;
			break;


	case Tbit:	d = Token::toChars(TOKbit);
			c = "bit";
			flags |= TFLAGSintegral | TFLAGSunsigned;
			break;

	case Tascii:	d = Token::toChars(TOKchar);
			c = "char";
			flags |= TFLAGSintegral | TFLAGSunsigned;
			break;

	case Twchar:	d = Token::toChars(TOKwchar);
			c = "wchar";
			flags |= TFLAGSintegral | TFLAGSunsigned;
			break;

	case Tdchar:	d = Token::toChars(TOKdchar);
			c = "dchar";
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
    buf->prependstring(cstring);
    if (ident)
    {	buf->writeByte(' ');
	buf->writestring(ident->toChars());
    }
}

d_uns64 TypeBasic::size(Loc loc)
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
			size = REALSIZE;	break;
	case Tcomplex32:
			size = 8;		break;
	case Tcomplex64:
			size = 16;		break;
	case Tcomplex80:
			size = REALSIZE * 2;	break;

	case Tvoid:
	    //size = Type::size();	// error message
	    size = 1;
	    break;

	case Tbit:	size = 1;		break;
	case Tascii:	size = 1;		break;
	case Twchar:	size = 2;		break;
	case Tdchar:	size = 4;		break;

	default:
	    assert(0);
	    break;
    }
    //printf("TypeBasic::size() = %d\n", size);
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
	    sz = size(0);
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
	    case Tdchar:	ivalue = 0x10FFFFUL;	goto Livalue;

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
	    case Tdchar:	ivalue = 0;		goto Livalue;

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
	    case Tfloat80:
#if __GNUC__
	    {	// gcc nan's have the sign bit set by default, so turn it off
		// Need the volatile to prevent gcc from doing incorrect
		// constant folding.
		volatile d_float80 foo;
		foo = NAN;
		foo = -foo;
		fvalue = foo;
	    }
#else
		fvalue = NAN;
#endif
		goto Lfvalue;
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
	    case Tfloat80:
#if __GNUC__
		fvalue = 1 / zero;
#else
		fvalue = INFINITY;
#endif
		goto Lfvalue;
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
    {
	complex_t cvalue;

#if __DMC__
	cvalue = fvalue + fvalue * I;
#else
	cvalue.re = fvalue;
	cvalue.im = fvalue;
#endif
	e = new ComplexExp(0, cvalue, this);
    }
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
{   integer_t value = 0;

#if LOGDEFAULTINIT
    printf("TypeBasic::defaultInit() '%s'\n", toChars());
#endif
    switch (ty)
    {
	case Tchar:
	    value = 0xFF;
	    break;

	case Twchar:
	case Tdchar:
	    value = 0xFFFF;
	    break;

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
    return new IntegerExp(0, value, this);
}

int TypeBasic::isZeroInit()
{
    switch (ty)
    {
	case Tchar:
	case Twchar:
	case Tdchar:
	case Timaginary32:
	case Timaginary64:
	case Timaginary80:
	case Tfloat32:
	case Tfloat64:
	case Tfloat80:
	case Tcomplex32:
	case Tcomplex64:
	case Tcomplex80:
	    return 0;		// no
    }
    return 1;			// yes
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
    //printf("TypeBasic::implicitConvTo(%s)\n", to->toChars());
    if (this == to)
	return MATCHexact;
    if (to->ty == Tvoid)
	return MATCHnomatch;
    if (!to->isTypeBasic())
	return MATCHnomatch;
    if (ty == Tvoid /*|| to->ty == Tvoid*/)
	return MATCHnomatch;
    if (to->ty == Tbit)
	return MATCHnomatch;
    // Disallow implicit conversion of floating point to integer
    if (flags & TFLAGSfloating && ((TypeBasic *)to)->flags & TFLAGSintegral)
	return MATCHnomatch;
    return MATCHconvert;
}

TypeBasic *TypeBasic::isTypeBasic()
{
    return (TypeBasic *)this;
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
	int size = next->size(e->loc);
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
	arguments->push(n->ty == Tsarray ? n->getTypeInfo(sc)	// don't convert to dynamic array
					 : n->getInternalTypeInfo(sc));
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
    OutBuffer buf2;
    toPrettyBracket(&buf2);
    buf->prependstring(buf2.toChars());
    if (ident)
    {
	buf->writestring(ident->toChars());
    }
    next->toCBuffer2(buf, NULL);
#elif 1
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
    //printf("TypeSArray(%s)\n", dim->toChars());
    this->dim = dim;
}

Type *TypeSArray::syntaxCopy()
{
    Type *t = next->syntaxCopy();
    Expression *e = dim->syntaxCopy();
    t = new TypeSArray(t, e);
    return t;
}

d_uns64 TypeSArray::size(Loc loc)
{   integer_t sz;

    if (!dim)
	return Type::size(loc);
    sz = dim->toInteger();
    if (next->toBasetype()->ty == Tbit)		// if array of bits
    {
	if (sz + 31 < sz)
	    goto Loverflow;
	sz = ((sz + 31) & ~31) / 8;	// size in bytes, rounded up to 32 bit dwords
    }
    else
    {	integer_t n, n2;

	n = next->size();
	n2 = n * sz;
	if (n && (n2 / n) != sz)
	    goto Loverflow;
	sz = n2;
    }
    return sz;

Loverflow:
    error(loc, "index %lld overflow for static array", sz);
    return 1;
}

unsigned TypeSArray::alignsize()
{
    return next->alignsize();
}

Type *TypeSArray::semantic(Loc loc, Scope *sc)
{
    //printf("TypeSArray::semantic() %s\n", toChars());
    next = next->semantic(loc,sc);
    if (dim)
    {	integer_t n, n2;

	dim = dim->semantic(sc);
	dim = dim->constFold();
	integer_t d1 = dim->toInteger();
	dim = dim->castTo(tsize_t);
	dim = dim->constFold();
	integer_t d2 = dim->toInteger();

	if (d1 != d2)
	    goto Loverflow;
	if (next->ty == Tbit && (d2 + 31) < d2)
	    goto Loverflow;
	else if (next->isintegral() ||
		 next->isfloating() ||
		 next->ty == Tpointer ||
		 next->ty == Tarray ||
		 next->ty == Tsarray ||
		 next->ty == Taarray ||
		 next->ty == Tclass)
	{
	    /* Only do this for types that don't need to have semantic()
	     * run on them for the size, since they may be forward referenced.
	     */
	    n = next->size(loc);
	    n2 = n * d2;
	    if ((int)n2 < 0)
		goto Loverflow;
	    if (n && n2 / n != d2)
	    {
	      Loverflow:
		error(loc, "index %lld overflow for static array", d1);
		dim = new IntegerExp(0, 1, tsize_t);
	    }
	}
    }
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
	buf->printf("%llu", dim->toInteger());
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
    buf->printf("[%s]", dim->toChars());
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
    else if (ident == Id::ptr)
    {
	e = e->castTo(next->pointerTo());
    }
    else
    {
	e = TypeArray::dotExp(sc, e, ident);
    }
    return e;
}

int TypeSArray::isString()
{
    return next->ty == Tascii || next->ty == Twchar || next->ty == Tdchar;
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
	(to->next->ty == Tvoid || next->equals(to->next)
	 /*|| to->next->isBaseOf(next)*/))
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
#if LOGDEFAULTINIT
    printf("TypeSArray::defaultInit() '%s'\n", toChars());
#endif
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

d_uns64 TypeDArray::size(Loc loc)
{
    //printf("TypeDArray::size()\n");
    return PTRSIZE * 2;
}

unsigned TypeDArray::alignsize()
{
    // A DArray consists of two ptr-sized values, so align it on pointer size
    // boundary
    return PTRSIZE;
}

Type *TypeDArray::semantic(Loc loc, Scope *sc)
{   Type *tn = next;

    tn = next->semantic(loc,sc);
    switch (tn->ty)
    {
	case Tfunction:
	case Tnone:
	    error(loc, "can't have array of %s", tn->toChars());
	    break;
    }
    if (tn->isauto())
	error(loc, "cannot have array of auto %s", tn->toChars());
    if (next != tn)
	//deco = NULL;			// redo
	return tn->arrayOf();
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
	e = new ArrayLengthExp(e->loc, e);
	e->type = Type::tsize_t;
	return e;
    }
    else if (ident == Id::ptr)
    {
	e = e->castTo(next->pointerTo());
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
    return next->ty == Tascii || next->ty == Twchar || next->ty == Tdchar;
}

int TypeDArray::implicitConvTo(Type *to)
{
    //printf("TypeDArray::implicitConvTo()\n");

    // Allow implicit conversion of array to pointer
    if (to->ty == Tpointer && (to->next->ty == Tvoid || next->equals(to->next) /*|| to->next->isBaseOf(next)*/))
    {
	return MATCHconvert;
    }
    if (to->ty == Tarray)
    {
	if (to->next->isBaseOf(next) || to->next->ty == Tvoid)
	    return MATCHconvert;
    }
    return Type::implicitConvTo(to);
}

Expression *TypeDArray::defaultInit()
{
#if LOGDEFAULTINIT
    printf("TypeDArray::defaultInit() '%s'\n", toChars());
#endif
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

d_uns64 TypeAArray::size(Loc loc)
{
    return PTRSIZE * 2;
}


Type *TypeAArray::semantic(Loc loc, Scope *sc)
{
    //printf("TypeAArray::semantic()\n");

    // Deal with the case where we thought the index was a type, but
    // in reality it was an expression.
    if (index->ty == Tident)
    {
	Expression *e;
	Type *t;
	Dsymbol *s;

	index->resolve(loc, sc, &e, &t, &s);
	if (e)
	{   // It was an expression -
	    // Rewrite as a static array
	    TypeSArray *tsa;

	    tsa = new TypeSArray(next, e);
	    return tsa->semantic(loc,sc);
	}
	else if (t)
	    index = t;
	else
	    index->error(loc, "index is not a type or an expression");
    }
    else
	index = index->semantic(loc,sc);

    // Compute key type; the purpose of the key type is to
    // minimize the permutations of runtime library
    // routines as much as possible.
    key = index->toBasetype();
    switch (key->ty)
    {
#if 0
	case Tint8:
	case Tuns8:
	case Tint16:
	case Tuns16:
	    key = tint32;
	    break;
#endif

	case Tsarray:
#if 0
	    // Convert to Tarray
	    key = key->next->arrayOf();
	    break;
#endif
	case Tbit:
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

	fd = FuncDeclaration::genCfunc(Type::tsize_t, "_aaLen");
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
	int size = key->size(e->loc);

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
	e->type = index->arrayOf();
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
	arguments->push(new IntegerExp(0, key->size(e->loc), Type::tint32));
	arguments->push(new IntegerExp(0, next->size(e->loc), Type::tint32));
	e = new CallExp(e->loc, ec, arguments);
	e->type = next->arrayOf();
    }
    else if (ident == Id::rehash)
    {
	Expression *ec;
	FuncDeclaration *fd;
	Array *arguments;

	fd = FuncDeclaration::genCfunc(Type::tint64, "_aaRehash");
	ec = new VarExp(0, fd);
	arguments = new Array();
	arguments->push(e->addressOf());
	arguments->push(key->getInternalTypeInfo(sc));
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
#if LOGDEFAULTINIT
    printf("TypeAArray::defaultInit() '%s'\n", toChars());
#endif
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


d_uns64 TypePointer::size(Loc loc)
{
    return PTRSIZE;
}

void TypePointer::toCBuffer2(OutBuffer *buf, Identifier *ident)
{
    //printf("TypePointer::toCBuffer2() next = %d\n", next->ty);
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
	return MATCHexact;
    if (to->ty == Tpointer && to->next)
    {
	if (to->next->ty == Tvoid)
	    return MATCHconvert;

#if 0
	if (to->next->isBaseOf(next))
	    return MATCHconvert;
#endif

	if (next->ty == Tfunction && to->next->ty == Tfunction)
	{   TypeFunction *tf;
	    TypeFunction *tfto;

	    tf   = (TypeFunction *)(next);
	    tfto = (TypeFunction *)(to->next);
	    return tfto->equals(tf) ? MATCHexact : MATCHnomatch;
	}
    }
//    if (to->ty == Tvoid)
//	return MATCHconvert;
    return MATCHnomatch;
}

int TypePointer::isscalar()
{
    return TRUE;
}

Expression *TypePointer::defaultInit()
{
#if LOGDEFAULTINIT
    printf("TypePointer::defaultInit() '%s'\n", toChars());
#endif
    Expression *e;
    e = new NullExp(0);
    e->type = this;
    return e;
}

int TypePointer::isZeroInit()
{
    return 1;
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

d_uns64 TypeReference::size(Loc loc)
{
    return PTRSIZE;
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
#if LOGDEFAULTINIT
    printf("TypeReference::defaultInit() '%s'\n", toChars());
#endif
    Expression *e;
    e = new NullExp(0);
    e->type = this;
    return e;
}

int TypeReference::isZeroInit()
{
    return 1;
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
    Array *args = Argument::arraySyntaxCopy(arguments);
    Type *t = new TypeFunction(args, treturn, varargs, linkage);
    return t;
}

/*******************************
 * Returns:
 *	0	types are distinct
 *	1	this is covariant with t
 *	2	arguments match as far as overloading goes,
 *		but types are not covariant
 */

int Type::covariant(Type *t)
{
    int inoutmismatch = 0;

    if (equals(t))
	goto Lcovariant;
    if (ty != Tfunction || t->ty != Tfunction)
	goto Ldistinct;

    {
    TypeFunction *t1 = (TypeFunction *)this;
    TypeFunction *t2 = (TypeFunction *)t;

    if (t1->varargs != t2->varargs)
	goto Ldistinct;

    if (t1->arguments && t2->arguments)
    {
	if (t1->arguments->dim != t2->arguments->dim)
	    goto Ldistinct;

	for (int i = 0; i < t1->arguments->dim; i++)
	{   Argument *arg1 = (Argument *)t1->arguments->data[i];
	    Argument *arg2 = (Argument *)t2->arguments->data[i];

	    if (!arg1->type->equals(arg2->type))
		goto Ldistinct;
	    if (arg1->inout != arg2->inout)
		inoutmismatch = 1;
	}
    }
    else if (t1->arguments != t2->arguments)
	goto Ldistinct;

    // The argument lists match
    if (inoutmismatch)
	goto Lnotcovariant;
    if (t1->linkage != t2->linkage)
	goto Lnotcovariant;

    Type *t1n = t1->next;
    Type *t2n = t2->next;

    if (t1n->equals(t2n))
	goto Lcovariant;
    if (t1n->ty != Tclass || t2n->ty != Tclass)
	goto Lnotcovariant;
    if (t1n->implicitConvTo(t2n))
	goto Lcovariant;
    goto Lnotcovariant;
    }

Lcovariant:
    return 1;

Ldistinct:
    return 0;

Lnotcovariant:
    return 2;
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
	    switch (arg->inout)
	    {	case In:
		    break;
		case Out:
		    buf->writeByte('J');
		    break;
		case InOut:
		    buf->writeByte('K');
		    break;
		default:
		    assert(0);
	    }
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
    {
	if (p)
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
    argsToCBuffer(buf);
    next->toCBuffer2(buf, NULL);
}

void TypeFunction::argsToCBuffer(OutBuffer *buf)
{
    buf->writeByte('(');
    if (arguments)
    {	int i;
	OutBuffer argbuf;

	for (i = 0; i < arguments->dim; i++)
	{   Argument *arg;

	    if (i)
		buf->writeByte(',');
	    arg = (Argument *)arguments->data[i];
	    if (arg->inout == Out)
		buf->writestring("out ");
	    else if (arg->inout == InOut)
		buf->writestring("inout ");
	    argbuf.reset();
	    arg->type->toCBuffer2(&argbuf, arg->ident);
	    if (arg->defaultArg)
	    {
		argbuf.writestring(" = ");
		arg->defaultArg->toCBuffer(&argbuf);
	    }
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
}

Type *TypeFunction::semantic(Loc loc, Scope *sc)
{
    if (deco)			// if semantic() already run
    {
	//printf("already done\n");
	return this;
    }
    linkage = sc->linkage;
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
		if (t->ty == Tsarray)
		    error(loc, "cannot have out or inout parameter of type %s", t->toChars());
	    }
	    if (t->ty == Tvoid)
		error(loc, "cannot have parameter of type %s", arg->type->toChars());

	    if (arg->defaultArg)
	    {
		arg->defaultArg = arg->defaultArg->semantic(sc);
		arg->defaultArg = resolveProperties(sc, arg->defaultArg);
		arg->defaultArg = arg->defaultArg->implicitCastTo(arg->type);
	    }
	}
    }
    deco = merge()->deco;

    if (varargs && linkage != LINKd && !(arguments && arguments->dim))
	error(loc, "variadic functions with non-C linkage must have at least one parameter");

    /* Don't return merge(), because arg identifiers and default args
     * can be different
     * even though the types match
     */
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
    else if (nargst > nargsf)
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
	if (u >= nargst)
	{
	    if (af->defaultArg)
		continue;
	    goto Nomatch;		// not enough arguments
	}
	ae = (Expression *)toargs->data[u];
	assert(ae);
	m = ae->implicitConvTo(af->type);
	//printf("\tm = %d\n", m);
	if (m == 0)
	    goto Nomatch;		// no match for this argument
	if (m < match)
	    match = m;			// pick worst match
    }

    //printf("match = %d\n", match);
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

d_uns64 TypeDelegate::size(Loc loc)
{
    return PTRSIZE * 2;
}

void TypeDelegate::toCBuffer2(OutBuffer *buf, Identifier *ident)
{
#if 1
    OutBuffer args;
    TypeFunction *tf = (TypeFunction *)next;

    tf->argsToCBuffer(&args);
    buf->prependstring(args.toChars());
    buf->prependstring(" delegate");
    if (ident)
    {
	buf->writestring(ident->toChars());
    }
    next->next->toCBuffer2(buf, NULL);
#else
    next->toCBuffer2(buf, Id::delegate);
    if (ident)
    {
	buf->writestring(ident->toChars());
    }
#endif
}

Expression *TypeDelegate::defaultInit()
{
#if LOGDEFAULTINIT
    printf("TypeDelegate::defaultInit() '%s'\n", toChars());
#endif
    Expression *e;
    e = new NullExp(0);
    e->type = this;
    return e;
}

int TypeDelegate::isZeroInit()
{
    return 1;
}

int TypeDelegate::checkBoolean()
{
    return TRUE;
}



/***************************** TypeQualified *****************************/

TypeQualified::TypeQualified(TY ty, Loc loc)
    : Type(ty, NULL)
{
    this->loc = loc;
}

void TypeQualified::syntaxCopyHelper(TypeQualified *t)
{
    idents.setDim(t->idents.dim);
    for (int i = 0; i < idents.dim; i++)
    {
	Identifier *id = (Identifier *)t->idents.data[i];
	if (id->dyncast() != DYNCAST_IDENTIFIER)
	{
	    TemplateInstance *ti = (TemplateInstance *)id;

	    ti = (TemplateInstance *)ti->syntaxCopy(NULL);
	    id = (Identifier *)ti;
	}
	idents.data[i] = id;
    }
}


void TypeQualified::addIdent(Identifier *ident)
{
    idents.push(ident);
}

void TypeQualified::toCBuffer2Helper(OutBuffer *buf, Identifier *ident)
{
    int i;

    for (i = 0; i < idents.dim; i++)
    {	Identifier *id = (Identifier *)idents.data[i];

	buf->writeByte('.');

	if (id->dyncast() != DYNCAST_IDENTIFIER)
	{
	    TemplateInstance *ti = (TemplateInstance *)id;
	    ti->toCBuffer(buf);
	}
	else
	    buf->writestring(id->toChars());
    }
}

d_uns64 TypeQualified::size(Loc loc)
{
    error(this->loc, "size of type %s is not known", toChars());
    return 1;
}

/*************************************
 * Takes an array of Identifiers and figures out if
 * it represents a Type or an Expression.
 * Output:
 *	if expression, *pe is set
 *	if type, *pt is set
 */

void TypeQualified::resolveHelper(Loc loc, Scope *sc,
	Dsymbol *s, Dsymbol *scopesym,
	Expression **pe, Type **pt, Dsymbol **ps)
{
    Identifier *id = NULL;
    int i;
    VarDeclaration *v;
    EnumMember *em;
    Type *t;
    Expression *e;

    //printf("TypeQualified::resolveHelper(sc = %p, idents = '%s')\n", sc, toChars());
    //printf("\tscopesym = '%s'\n", scopesym->toChars());
    *pe = NULL;
    *pt = NULL;
    *ps = NULL;
    if (s)
    {
	//printf("\t1: s = '%s' %p, kind = '%s'\n",s->toChars(), s, s->kind());
	s = s->toAlias();
	//printf("\t2: s = '%s' %p, kind = '%s'\n",s->toChars(), s, s->kind());
	for (i = 0; i < idents.dim; i++)
	{   Dsymbol *sm;

	    id = (Identifier *)idents.data[i];
	    if (id->dyncast() != DYNCAST_IDENTIFIER)
	    {
		// It's a template instance
		//printf("\ttemplate instance id\n");
		TemplateDeclaration *td;
		TemplateInstance *ti = (TemplateInstance *)id;
		id = (Identifier *)ti->idents.data[0];
		sm = s->search(id, 0);
		if (!sm)
		{   error(loc, "template identifier %s is not a member of %s", id->toChars(), s->toChars());
		    return;
		}
		sm = sm->toAlias();
		td = sm->isTemplateDeclaration();
		if (!td)
		{
		    error(loc, "%s is not a template", id->toChars());
		    return;
		}
		ti->tempdecl = td;
		ti->semantic(sc);
		sm = ti->toAlias();
	    }
	    else
		sm = s->search(id, 0);
//printf("s = '%s', kind = '%s'\n", s->toChars(), s->kind());
//printf("getType = '%s'\n", s->getType()->toChars());
	    if (!sm)
	    {
#if 0
		if (s->isAliasDeclaration() && this->ty == Tident)
		{
		    *pt = this;
		    return;
		}
#endif
		t = s->getType();
		if (!t && s->isDeclaration())
		    t = s->isDeclaration()->type;
		if (t)
		{
//<<>>
		    sm = t->toDsymbol(sc);
		    if (sm)
		    {	sm = sm->search(id, 0);
			if (sm)
			    goto L2;
		    }
		    e = t->getProperty(loc, id);
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
	L2:
	    s = sm->toAlias();
	}

	v = s->isVarDeclaration();
	if (v)
	{
	    // It's not a type, it's an expression
	    if (v->isConst() && v->getExpInitializer())
	    {
		ExpInitializer *ei = v->getExpInitializer();
		assert(ei);
		*pe = ei->exp->copy();	// make copy so we can change loc
		(*pe)->loc = loc;
	    }
	    else
	    {
		*pe = new VarExp(loc, v);
		assert(!scopesym || !scopesym->isWithScopeSymbol());	// BUG: should handle this
	    }
	    return;
	}
	em = s->isEnumMember();
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

	    si = s->isImport();
	    if (si)
	    {
		s = si->search(s->ident, 0);
		if (s)
		    goto L1;
		s = si;
	    }
	    *ps = s;
	    return;
	}
	if (t->ty == Tident && t != this)
	{
	    Scope *scx;

	    for (scx = sc; 1; scx = scx->enclosing)
	    {
		if (!scx)
		{   error(loc, "forward reference to '%s'", t->toChars());
		    return;
		}
		if (scx->scopesym == scopesym)
		    break;
	    }
	    ((TypeIdentifier *)t)->resolve(loc, scx, pe, &t, ps);
	}
	*pt = t->merge();
    }
    if (!s)
    {
	error(loc, "identifier '%s' is not defined", toChars());
    }
}

/***************************** TypeIdentifier *****************************/

TypeIdentifier::TypeIdentifier(Loc loc, Identifier *ident)
    : TypeQualified(Tident, loc)
{
    this->ident = ident;
}


Type *TypeIdentifier::syntaxCopy()
{
    TypeIdentifier *t;

    t = new TypeIdentifier(loc, ident);
    t->syntaxCopyHelper(this);
    return t;
}


void TypeIdentifier::toCBuffer2(OutBuffer *buf, Identifier *ident)
{
    OutBuffer tmp;

    tmp.writestring(this->ident->toChars());
    toCBuffer2Helper(&tmp, NULL);
    buf->prependstring(tmp.toChars());
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

void TypeIdentifier::resolve(Loc loc, Scope *sc, Expression **pe, Type **pt, Dsymbol **ps)
{   Dsymbol *s;
    Dsymbol *scopesym;

    //printf("TypeIdentifier::resolve(sc = %p, idents = '%s')\n", sc, toChars());
    s = sc->search(ident, &scopesym);
    resolveHelper(loc, sc, s, scopesym, pe, pt, ps);
}

/*****************************************
 * See if type resolves to a symbol, if so,
 * return that symbol.
 */

Dsymbol *TypeIdentifier::toDsymbol(Scope *sc)
{
    Dsymbol *s;
    Dsymbol *scopesym;

    if (!sc)
	return NULL;
    s = sc->search(ident, &scopesym);
    if (s)
    {
	s = s->toAlias();
	for (int i = 0; i < idents.dim; i++)
	{   Identifier *id;
	    Dsymbol *sm;

	    id = (Identifier *)idents.data[i];
	    if (id->dyncast() != DYNCAST_IDENTIFIER)
	    {
		// It's a template instance
		//printf("\ttemplate instance id\n");
		TemplateDeclaration *td;
		TemplateInstance *ti = (TemplateInstance *)id;
		id = (Identifier *)ti->idents.data[0];
		sm = s->search(id, 0);
		if (!sm)
		{   error(loc, "template identifier %s is not a member of %s", id->toChars(), s->toChars());
		    break;
		}
		sm = sm->toAlias();
		td = sm->isTemplateDeclaration();
		if (!td)
		{
		    error(loc, "%s is not a template", id->toChars());
		    break;
		}
		ti->tempdecl = td;
		ti->semantic(sc);
		sm = ti->toAlias();
	    }
	    else
		sm = s->search(id, 0);
	    s = sm;

	    if (!s)                 // failed to find a symbol
		break;
	    s = s->toAlias();
	}
    }
    return s;
}

Type *TypeIdentifier::semantic(Loc loc, Scope *sc)
{
    Type *t;
    Expression *e;
    Dsymbol *s;

    //printf("TypeIdentifier::semantic(%s)\n", toChars());
    resolve(loc, sc, &e, &t, &s);
    if (!t)
    {
#ifdef DEBUG
	printf("1: ");
#endif
	if (s)
	{
	    s->error(loc, "is used as a type");
	}
	else
	    error(loc, "%s is used as a type", toChars());
	t = tvoid;
    }
    //t->print();
    return t;
}

/***************************** TypeInstance *****************************/

TypeInstance::TypeInstance(Loc loc, TemplateInstance *tempinst)
    : TypeQualified(Tinstance, loc)
{
    this->tempinst = tempinst;
}

Type *TypeInstance::syntaxCopy()
{
    TypeInstance *t;

    t = new TypeInstance(loc, (TemplateInstance *)tempinst->syntaxCopy(NULL));
    t->syntaxCopyHelper(this);
    return t;
}


void TypeInstance::toCBuffer2(OutBuffer *buf, Identifier *ident)
{
    OutBuffer tmp;

    tempinst->toCBuffer(&tmp);
    toCBuffer2Helper(&tmp, NULL);
    buf->prependstring(tmp.toChars());
    if (ident)
    {	buf->writeByte(' ');
	buf->writestring(ident->toChars());
    }
}

void TypeInstance::resolve(Loc loc, Scope *sc, Expression **pe, Type **pt, Dsymbol **ps)
{
    // Note close similarity to TypeIdentifier::resolve()

    Dsymbol *s;

    *pe = NULL;
    *pt = NULL;
    *ps = NULL;

#if 0
    if (!idents.dim)
    {
	error(loc, "template instance '%s' has no identifier", toChars());
	return;
    }
#endif
    //id = (Identifier *)idents.data[0];
    //printf("TypeInstance::resolve(sc = %p, idents = '%s')\n", sc, id->toChars());
    s = tempinst;
    if (s)
	s->semantic(sc);
    resolveHelper(loc, sc, s, NULL, pe, pt, ps);
    //printf("pt = '%s'\n", (*pt)->toChars());
}

Type *TypeInstance::semantic(Loc loc, Scope *sc)
{
    Type *t;
    Expression *e;
    Dsymbol *s;

    //printf("TypeInstance::semantic(%s)\n", toChars());
    resolve(loc, sc, &e, &t, &s);
    if (!t)
    {
#ifdef DEBUG
	printf("2: ");
#endif
	error(loc, "%s is used as a type", toChars());
	t = tvoid;
    }
    return t;
}


/***************************** TypeTypeof *****************************/

TypeTypeof::TypeTypeof(Loc loc, Expression *exp)
	: TypeQualified(Ttypeof, loc)
{
    this->exp = exp;
}

Type *TypeTypeof::syntaxCopy()
{
    TypeTypeof *t;

    t = new TypeTypeof(loc, exp->syntaxCopy());
    t->syntaxCopyHelper(this);
    return t;
}

Dsymbol *TypeTypeof::toDsymbol(Scope *sc)
{
    Type *t;

    t = semantic(0, sc);
    return t->toDsymbol(sc);
}

void TypeTypeof::toCBuffer2(OutBuffer *buf, Identifier *ident)
{
    OutBuffer tmp;

    tmp.writestring("typeof(");
    exp->toCBuffer(&tmp);
    tmp.writeByte(')');
    toCBuffer2Helper(&tmp, NULL);
    buf->prependstring(tmp.toChars());
    if (ident)
    {	buf->writeByte(' ');
	buf->writestring(ident->toChars());
    }
}

Type *TypeTypeof::semantic(Loc loc, Scope *sc)
{   Expression *e;
    Type *t;

    //printf("TypeTypeof::semantic()\n");

    /* Special case for typeof(this) and typeof(super) since both
     * should work even if they are not inside a non-static member function
     */
    if (exp->op == TOKthis || exp->op == TOKsuper)
    {
	// Find enclosing struct or class
	for (Dsymbol *s = sc->parent; 1; s = s->parent)
	{
	    ClassDeclaration *cd;
	    StructDeclaration *sd;

	    if (!s)
	    {
		error(loc, "%s is not in a struct or class scope", exp->toChars());
		goto Lerr;
	    }
	    cd = s->isClassDeclaration();
	    if (cd)
	    {
		if (exp->op == TOKsuper)
		{
		    cd = cd->baseClass;
		    if (!cd)
		    {	error(loc, "class %s has no 'super'", s->toChars());
			goto Lerr;
		    }
		}
		t = cd->type;
		break;
	    }
	    sd = s->isStructDeclaration();
	    if (sd)
	    {
		if (exp->op == TOKsuper)
		{
		    error(loc, "struct %s has no 'super'", sd->toChars());
		    goto Lerr;
		}
		t = sd->type->pointerTo();
		break;
	    }
	}
    }
    else
    {

	exp = exp->semantic(sc);
	t = exp->type;
	if (!t)
	{
	    error(loc, "expression (%s) has no type", exp->toChars());
	    goto Lerr;
	}
    }

    if (idents.dim)
    {
	error(loc, ".property not implemented for typeof");
	goto Lerr;
    }
    return t;

Lerr:
    return tvoid;
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

d_uns64 TypeEnum::size(Loc loc)
{
    if (!sym->memtype)
    {
	error(loc, "enum %s is forward referenced", sym->toChars());
	return 4;
    }
    return sym->memtype->size(loc);
}

unsigned TypeEnum::alignsize()
{
    assert(sym->memtype);
    return sym->memtype->alignsize();
}

Dsymbol *TypeEnum::toDsymbol(Scope *sc)
{
    return sym;
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

#if LOGDOTEXP
    printf("TypeEnum::dotExp(e = '%s', ident = '%s') '%s'\n", e->toChars(), ident->toChars(), toChars());
#endif
    s = sym->symtab->lookup(ident);
    if (!s)
    {
	return getProperty(e->loc, ident);
    }
    m = s->isEnumMember();
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
#if LOGDEFAULTINIT
    printf("TypeEnum::defaultInit() '%s'\n", toChars());
#endif
    // Initialize to first member of enum
    Expression *e;
    e = new IntegerExp(0, sym->defaultval, this);
    return e;
}

int TypeEnum::isZeroInit()
{
    return (sym->defaultval == 0);
}


/***************************** TypeTypedef *****************************/

TypeTypedef::TypeTypedef(TypedefDeclaration *sym)
	: Type(Ttypedef, NULL)
{
    this->sym = sym;
}

Type *TypeTypedef::syntaxCopy()
{
    return this;
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

d_uns64 TypeTypedef::size(Loc loc)
{
    return sym->basetype->size(loc);
}

unsigned TypeTypedef::alignsize()
{
    return sym->basetype->alignsize();
}

Dsymbol *TypeTypedef::toDsymbol(Scope *sc)
{
    return sym;
}

void TypeTypedef::toDecoBuffer(OutBuffer *buf)
{   unsigned len;
    char *name;

    name = sym->mangle();
    //len = strlen(name);
    //buf->printf("%c%d%s", mangleChar[ty], len, name);
    buf->printf("%c%s", mangleChar[ty], name);
}

void TypeTypedef::toTypeInfoBuffer(OutBuffer *buf)
{
    sym->basetype->toTypeInfoBuffer(buf);
}

void TypeTypedef::toCBuffer2(OutBuffer *buf, Identifier *ident)
{
    //printf("TypeTypedef::toCBuffer2() '%s'\n", sym->toChars());
    buf->prependstring(sym->toChars());
    if (ident)
    {	buf->writeByte(' ');
	buf->writestring(ident->toChars());
    }
}

Expression *TypeTypedef::dotExp(Scope *sc, Expression *e, Identifier *ident)
{
#if LOGDOTEXP
    printf("TypeTypedef::dotExp(e = '%s', ident = '%s') '%s'\n", e->toChars(), ident->toChars(), toChars());
#endif
    if (ident == Id::init)
    {
	if (e->op == TOKvar)
	{
	    VarExp *ve = (VarExp *)e;
	    VarDeclaration *v = ve->var->isVarDeclaration();

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

#if LOGDEFAULTINIT
    printf("TypeTypedef::defaultInit() '%s'\n", toChars());
#endif
    if (sym->init)
    {
	//sym->init->toExpression()->print();
	return sym->init->toExpression();
    }
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

int TypeTypedef::isZeroInit()
{
    if (sym->init)
	return 0;		// assume not
    return sym->basetype->isZeroInit();
}

/***************************** TypeStruct *****************************/

TypeStruct::TypeStruct(StructDeclaration *sym)
	: Type(Tstruct, NULL)
{
    this->sym = sym;
}

char *TypeStruct::toChars()
{
    //printf("sym.parent: %s, deco = %s\n", sym->parent->toChars(), deco);
    return sym->toChars();
}

Type *TypeStruct::syntaxCopy()
{
    return this;
}

Type *TypeStruct::semantic(Loc loc, Scope *sc)
{
    //printf("TypeStruct::semantic('%s')\n", sym->toChars());

    /* Cannot do semantic for sym because scope chain may not
     * be right.
     */
    //sym->semantic(sc);

    return merge();
}

d_uns64 TypeStruct::size(Loc loc)
{
    return sym->size(loc);
}

unsigned TypeStruct::alignsize()
{   unsigned sz;

    sym->size(0);		// give error for forward references
    sz = sym->alignsize;
    if (sz > sym->structalign)
	sz = sym->structalign;
    return sz;
}

Dsymbol *TypeStruct::toDsymbol(Scope *sc)
{
    return sym;
}

void TypeStruct::toDecoBuffer(OutBuffer *buf)
{   unsigned len;
    char *name;

    name = sym->mangle();
    //len = strlen(name);
    //buf->printf("%c%d%s", mangleChar[ty], len, name);
    buf->printf("%c%s", mangleChar[ty], name);
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
    if (!sym->members)
    {
	error(e->loc, "struct %s is forward referenced", sym->toChars());
	return new IntegerExp(e->loc, 0, Type::tint32);
    }

    if (e->op == TOKdotexp)
    {	DotExp *de = (DotExp *)e;

	if (de->e1->op == TOKimport)
	{
	    ScopeExp *se = (ScopeExp *)de->e1;

	    s = se->sds->search(ident, 0);
	    e = de->e1;
	    goto L1;
	}
    }

    s = sym->search(ident, 0);
L1:
    if (!s)
    {
	return getProperty(e->loc, ident);
    }
    v = s->isVarDeclaration();
    if (v && v->isConst())
    {	ExpInitializer *ei = v->getExpInitializer();

	if (ei)
	    return ei->exp;
    }

    if (s->getType())
    {
	return new DotTypeExp(e->loc, e, s);
    }

    EnumMember *em = s->isEnumMember();
    if (em)
    {
	assert(em->value);
	return em->value->copy();
    }

    TemplateMixin *tm = s->isTemplateMixin();
    if (tm)
    {	Expression *de;

	de = new DotExp(e->loc, e, new ScopeExp(e->loc, tm));
	de->type = e->type;
	return de;
    }

    if (s->isTemplateDeclaration())
    {
	s->error("templates don't have properties");
	return e;
    }

    d = s->isDeclaration();
#ifdef DEBUG
    if (!d)
	printf("d = %s '%s'\n", s->kind(), s->toChars());
#endif
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
    sym->size(0);		// give error for forward references
    return sym->structalign;
}

Expression *TypeStruct::defaultInit()
{   Symbol *s;
    Declaration *d;

#if LOGDEFAULTINIT
    printf("TypeStruct::defaultInit() '%s'\n", toChars());
#endif
    s = sym->toInitializer();
    d = new SymbolDeclaration(sym->loc, s);
    assert(d);
    d->type = this;
    return new VarExp(sym->loc, d);
}

int TypeStruct::isZeroInit()
{
    return sym->zeroInit;
}


/***************************** TypeClass *****************************/

TypeClass::TypeClass(ClassDeclaration *sym)
	: Type(Tclass, NULL)
{
    this->sym = sym;
}

char *TypeClass::toChars()
{
    return sym->toChars();
}

Type *TypeClass::syntaxCopy()
{
    return this;
}

Type *TypeClass::semantic(Loc loc, Scope *sc)
{
    //printf("TypeClass::semantic(%s)\n", sym->toChars());
    if (sym->scope)
	sym->semantic(sym->scope);
    return merge();
}

d_uns64 TypeClass::size(Loc loc)
{
    return PTRSIZE;
}

Dsymbol *TypeClass::toDsymbol(Scope *sc)
{
    return sym;
}

void TypeClass::toDecoBuffer(OutBuffer *buf)
{   unsigned len;
    char *name;

    name = sym->mangle();
    //len = strlen(name);
    //buf->printf("%c%d%s", mangleChar[ty], len, name);
    buf->printf("%c%s", mangleChar[ty], name);
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

    if (e->op == TOKdotexp)
    {	DotExp *de = (DotExp *)e;

	if (de->e1->op == TOKimport)
	{
	    ScopeExp *se = (ScopeExp *)de->e1;

	    s = se->sds->search(ident, 0);
	    e = de->e1;
	    goto L1;
	}
    }

    s = sym->search(ident, 0);
L1:
    if (!s)
    {
	// See if it's a base class
	ClassDeclaration *cbase;
	for (cbase = sym->baseClass; cbase; cbase = cbase->baseClass)
	{
	    if (cbase->ident->equals(ident))
	    {
		e = new DotTypeExp(0, e, cbase);
		return e;
	    }
	}

	if (ident == Id::classinfo)
	{
	    Type *t;

	    assert(ClassDeclaration::classinfo);
	    t = ClassDeclaration::classinfo->type;
	    if (e->op == TOKtype || e->op == TOKdottype)
	    {
		if (!sym->vclassinfo)
		    sym->vclassinfo = new ClassInfoDeclaration(sym);
		e = new VarExp(e->loc, sym->vclassinfo);
		e = e->addressOf();
		e->type = t;	// do this so we don't get redundant dereference
	    }
	    else
	    {
		e = new PtrExp(e->loc, e);
		e->type = t->pointerTo();
		if (sym->isInterfaceDeclaration())
		{
		    if (sym->isCOMclass())
			error(e->loc, "no .classinfo for COM interface objects");
		    e->type = e->type->pointerTo();
		    e = new PtrExp(e->loc, e);
		    e->type = t->pointerTo();
		}
		e = new PtrExp(e->loc, e, t);
	    }
	    return e;
	}

	if (ident == Id::typeinfo)
	{
	    if (!global.params.useDeprecated)
		error(e->loc, ".typeinfo deprecated, use typeid(type)");
	    return getTypeInfo(sc);
	}
	return getProperty(e->loc, ident);
    }
    s = s->toAlias();
    v = s->isVarDeclaration();
    if (v && v->isConst())
    {	ExpInitializer *ei = v->getExpInitializer();

	if (ei)
	    return ei->exp;
    }

    if (s->getType())
    {
	if (e->op == TOKtype)
	    return new TypeExp(e->loc, s->getType());
	return new DotTypeExp(e->loc, e, s);
    }

    EnumMember *em = s->isEnumMember();
    if (em)
    {
	assert(em->value);
	return em->value->copy();
    }

    TemplateMixin *tm = s->isTemplateMixin();
    if (tm)
    {	Expression *de;

	de = new DotExp(e->loc, e, new ScopeExp(e->loc, tm));
	de->type = e->type;
	return de;
    }

    d = s->isDeclaration();
    if (!d)
    {
	e->error("%s.%s is not a declaration", e->toChars(), ident->toChars());
	return new IntegerExp(e->loc, 1, Type::tint32);
    }

    if (e->op == TOKtype)
    {
	VarExp *ve;

	if (d->needThis())
	{
	    if (sc->func)
	    {
		ClassDeclaration *thiscd;
		thiscd = sc->func->toParent()->isClassDeclaration();

		if (thiscd)
		{
		    ClassDeclaration *cd = e->type->isClassHandle();

		    if (cd == thiscd)
		    {
			e = new ThisExp(e->loc);
			e = new DotTypeExp(e->loc, e, cd);
			de = new DotVarExp(e->loc, e, d);
			e = de->semantic(sc);
			return e;
		    }
		    else if (!cd || !cd->isBaseOf(thiscd, NULL))
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

    if (d->isDataseg())
    {
	// (e, d)
	VarExp *ve;

	accessCheck(e->loc, sc, e, d);
	ve = new VarExp(e->loc, d);
	e = new CommaExp(e->loc, e, ve);
	e->type = d->type;
	return e;
    }

    if (d->parent && d->toParent()->isModule())
    {
	// (e, d)
	VarExp *ve;

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

int TypeClass::isBaseOf(Type *t)
{
    if (t->ty == Tclass)
    {   ClassDeclaration *cd;

	cd   = ((TypeClass *)t)->sym;
	if (sym->isBaseOf(cd, NULL))
	    return 1;
    }
    return 0;
}

int TypeClass::implicitConvTo(Type *to)
{
    //printf("TypeClass::implicitConvTo('%s')\n", to->toChars());
    if (this == to)
	return 2;

    ClassDeclaration *cdto = to->isClassHandle();
    if (cdto && cdto->isBaseOf(sym, NULL))
    {	//printf("is base\n");
	return 1;
    }

    // Allow conversion to (void *)
    if (to->ty == Tpointer && to->next->ty == Tvoid)
	return 1;

//    if (to->ty == Tvoid)
//	return MATCHconvert;
    return 0;
}

Expression *TypeClass::defaultInit()
{
#if LOGDEFAULTINIT
    printf("TypeClass::defaultInit() '%s'\n", toChars());
#endif
    Expression *e;
    e = new NullExp(0);
    e->type = this;
    return e;
}

int TypeClass::isZeroInit()
{
    return 1;
}

int TypeClass::checkBoolean()
{
    return TRUE;
}



/***************************** Argument *****************************/

Argument::Argument(enum InOut inout, Type *type, Identifier *ident, Expression *defaultArg)
{
    this->type = type;
    this->ident = ident;
    this->inout = inout;
    this->defaultArg = defaultArg;
}

Argument *Argument::syntaxCopy()
{
    Argument *a = new Argument(inout,
		type->syntaxCopy(),
		ident,
		defaultArg ? defaultArg->syntaxCopy() : NULL);
    return a;
}

Array *Argument::arraySyntaxCopy(Array *args)
{   Array *a = NULL;

    if (args)
    {
	a = new Array();
	a->setDim(args->dim);
	for (int i = 0; i < a->dim; i++)
	{   Argument *arg = (Argument *)args->data[i];

	    arg = arg->syntaxCopy();
	    a->data[i] = (void *)arg;
	}
    }
    return a;
}

