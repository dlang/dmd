
// Compiler implementation of the D programming language
// Copyright (c) 1999-2008 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#define __USE_ISOC99 1		// so signbit() gets defined
#include <math.h>

#include <stdio.h>
#include <assert.h>
#include <float.h>

#ifdef __DMC__
#include <fp.h>
#endif

#if _MSC_VER
#include <malloc.h>
#include <complex>
#include <limits>
#elif __DMC__
#include <complex.h>
#else
//#define signbit 56
#endif

#if __APPLE__
#include <math.h>
static double zero = 0;
#elif __GNUC__
#include <math.h>
#include <bits/nan.h>
#include <bits/mathdef.h>
static double zero = 0;
#endif

#include "mem.h"

#include "dsymbol.h"
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
#include "hdrgen.h"

FuncDeclaration *hasThis(Scope *sc);


#define LOGDOTEXP	0	// log ::dotExp()
#define LOGDEFAULTINIT	0	// log ::defaultInit()

// Allow implicit conversion of T[] to T*
#define IMPLICIT_ARRAY_TO_PTR	global.params.useDeprecated

/* These have default values for 32 bit code, they get
 * adjusted for 64 bit code.
 */

int PTRSIZE = 4;
#if TARGET_LINUX
int REALSIZE = 12;
int REALPAD = 2;
#else
int REALSIZE = 10;
int REALPAD = 0;
#endif
int Tsize_t = Tuns32;
int Tptrdiff_t = Tint32;

/***************************** Type *****************************/

ClassDeclaration *Type::typeinfo;
ClassDeclaration *Type::typeinfoclass;
ClassDeclaration *Type::typeinfointerface;
ClassDeclaration *Type::typeinfostruct;
ClassDeclaration *Type::typeinfotypedef;
ClassDeclaration *Type::typeinfopointer;
ClassDeclaration *Type::typeinfoarray;
ClassDeclaration *Type::typeinfostaticarray;
ClassDeclaration *Type::typeinfoassociativearray;
ClassDeclaration *Type::typeinfoenum;
ClassDeclaration *Type::typeinfofunction;
ClassDeclaration *Type::typeinfodelegate;
ClassDeclaration *Type::typeinfotypelist;

Type *Type::tvoidptr;
Type *Type::basic[TMAX];
unsigned char Type::mangleChar[TMAX];
StringTable Type::stringtable;


Type::Type(TY ty, Type *next)
{
    this->ty = ty;
    this->mod = 0;
    this->next = next;
    this->deco = NULL;
#if V2
    this->cto = NULL;
    this->ito = NULL;
#endif
    this->pto = NULL;
    this->rto = NULL;
    this->arrayof = NULL;
    this->vtinfo = NULL;
    this->ctype = NULL;
}

Type *Type::syntaxCopy()
{
    print();
    fprintf(stdmsg, "ty = %d\n", ty);
    assert(0);
    return this;
}

int Type::equals(Object *o)
{   Type *t;

    t = (Type *)o;
    //printf("Type::equals(%s, %s)\n", toChars(), t->toChars());
    if (this == o ||
	(t && deco == t->deco) &&		// deco strings are unique
	 deco != NULL)				// and semantic() has been run
    {
	//printf("deco = '%s', t->deco = '%s'\n", deco, t->deco);
	return 1;
    }
    //if (deco && t && t->deco) printf("deco = '%s', t->deco = '%s'\n", deco, t->deco);
    return 0;
}

char Type::needThisPrefix()
{
    return 'M';		// name mangling prefix for functions needing 'this'
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

    mangleChar[Tbool] = 'b';
    mangleChar[Tascii] = 'a';
    mangleChar[Twchar] = 'u';
    mangleChar[Tdchar] = 'w';

    mangleChar[Tbit] = '@';
    mangleChar[Tinstance] = '@';
    mangleChar[Terror] = '@';
    mangleChar[Ttypeof] = '@';
    mangleChar[Ttuple] = 'B';
    mangleChar[Tslice] = '@';

    for (i = 0; i < TMAX; i++)
    {	if (!mangleChar[i])
	    fprintf(stdmsg, "ty = %d\n", i);
	assert(mangleChar[i]);
    }

    // Set basic types
    static TY basetab[] =
	{ Tvoid, Tint8, Tuns8, Tint16, Tuns16, Tint32, Tuns32, Tint64, Tuns64,
	  Tfloat32, Tfloat64, Tfloat80,
	  Timaginary32, Timaginary64, Timaginary80,
	  Tcomplex32, Tcomplex64, Tcomplex80,
	  Tbit, Tbool,
	  Tascii, Twchar, Tdchar };

    for (i = 0; i < sizeof(basetab) / sizeof(basetab[0]); i++)
	basic[basetab[i]] = new TypeBasic(basetab[i]);
    basic[Terror] = basic[Tint32];

    tvoidptr = tvoid->pointerTo();

    if (global.params.isX86_64)
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
#if TARGET_LINUX
	REALSIZE = 12;
	REALPAD = 2;
#else
	REALSIZE = 10;
	REALPAD = 0;
#endif
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
    return 1;
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
 * For pretty-printing a type.
 */

char *Type::toChars()
{   OutBuffer *buf;
    HdrGenState hgs;

    buf = new OutBuffer();
    toCBuffer(buf, NULL, &hgs);
    return buf->toChars();
}

void Type::toCBuffer(OutBuffer *buf, Identifier *ident, HdrGenState *hgs)
{
    toCBuffer2(buf, hgs, 0);
    if (ident)
    {	buf->writeByte(' ');
	buf->writestring(ident->toChars());
    }
}

void Type::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    if (mod != this->mod)
    {	toCBuffer3(buf, hgs, mod);
	return;
    }
    buf->writestring(toChars());
}

void Type::toCBuffer3(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    if (mod != this->mod)
    {	char *p;

	switch (this->mod)
	{
	    case 0:
		toCBuffer2(buf, hgs, this->mod);
		break;
	    case MODconst:
		p = "const(";
		goto L1;
	    case MODinvariant:
		p = "invariant(";
	    L1:	buf->writestring(p);
		toCBuffer2(buf, hgs, this->mod);
		buf->writeByte(')');
		break;
	    default:
		assert(0);
	}
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

/*********************************
 * Check type to see if it is based on a deprecated symbol.
 */

void Type::checkDeprecated(Loc loc, Scope *sc)
{
    Type *t;
    Dsymbol *s;

    for (t = this; t; t = t->next)
    {
	s = t->toDsymbol(sc);
	if (s)
	    s->checkDeprecated(loc, sc);
    }
}


Expression *Type::defaultInit(Loc loc)
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

int Type::isBaseOf(Type *t, int *poffset)
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

MATCH Type::implicitConvTo(Type *to)
{
    //printf("Type::implicitConvTo(this=%p, to=%p)\n", this, to);
    //printf("\tthis->next=%p, to->next=%p\n", this->next, to->next);
    if (this == to)
	return MATCHexact;
//    if (to->ty == Tvoid)
//	return 1;
    return MATCHnomatch;
}

Expression *Type::getProperty(Loc loc, Identifier *ident)
{   Expression *e;

#if LOGDOTEXP
    printf("Type::getProperty(type = '%s', ident = '%s')\n", toChars(), ident->toChars());
#endif
    if (ident == Id::__sizeof)
    {
	e = new IntegerExp(loc, size(loc), Type::tsize_t);
    }
    else if (ident == Id::size)
    {
	error(loc, ".size property should be replaced with .sizeof");
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
	if (ty == Tvoid)
	    error(loc, "void does not have an initializer");
	e = defaultInit(loc);
    }
    else if (ident == Id::mangleof)
    {
	assert(deco);
	e = new StringExp(loc, deco, strlen(deco), 'c');
	Scope sc;
	e = e->semantic(&sc);
    }
    else if (ident == Id::stringof)
    {	char *s = toChars();
	e = new StringExp(loc, s, strlen(s), 'c');
	Scope sc;
	e = e->semantic(&sc);
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
		e = new IntegerExp(e->loc, v->offset, Type::tsize_t);
		return e;
	    }
	}
	else if (ident == Id::init)
	{
#if 0
	    if (v->init)
	    {
		if (v->init->isVoidInitializer())
		    error(e->loc, "%s.init is void", v->toChars());
		else
		{   Loc loc = e->loc;
		    e = v->init->toExpression();
		    if (e->op == TOKassign || e->op == TOKconstruct)
		    {
			e = ((AssignExp *)e)->e2;

			/* Take care of case where we used a 0
			 * to initialize the struct.
			 */
			if (e->type == Type::tint32 &&
			    e->isBool(0) &&
			    v->type->toBasetype()->ty == Tstruct)
			{
			    e = v->type->defaultInit(loc);
			}
		    }
		    e = e->optimize(WANTvalue | WANTinterpret);
//		    if (!e->isConst())
//			error(loc, ".init cannot be evaluated at compile time");
		}
		return e;
	    }
#endif
	    Expression *ex = defaultInit(e->loc);
	    return ex;
	}
    }
    if (ident == Id::typeinfo)
    {
	if (!global.params.useDeprecated)
	    error(e->loc, ".typeinfo deprecated, use typeid(type)");
	e = getTypeInfo(sc);
	return e;
    }
    if (ident == Id::stringof)
    {	char *s = e->toChars();
	e = new StringExp(e->loc, s, strlen(s), 'c');
	Scope sc;
	e = e->semantic(&sc);
	return e;
    }
    return getProperty(e->loc, ident);
}

unsigned Type::memalign(unsigned salign)
{
    return salign;
}

void Type::error(Loc loc, const char *format, ...)
{
    va_list ap;
    va_start(ap, format);
    ::verror(loc, format, ap);
    va_end( ap );
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
    len = buf.offset;
    name = (char *)alloca(19 + sizeof(len) * 3 + len + 1);
    buf.writeByte(0);
    sprintf(name, "_D%dTypeInfo_%s6__initZ", 9 + len, buf.data);
    if (global.params.isWindows)
	name++;			// C mangling will add it back in
    //printf("name = %s\n", name);
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

/*******************************
 * If one of the subtypes of this type is a TypeIdentifier,
 * i.e. it's an unresolved type, return that type.
 */

Type *Type::reliesOnTident()
{
    if (!next)
	return NULL;
    else
	return next->reliesOnTident();
}

/********************************
 * We've mistakenly parsed this as a type.
 * Redo it as an Expression.
 * NULL if cannot.
 */

Expression *Type::toExpression()
{
    return NULL;
}

/***************************************
 * Return !=0 if type has pointers that need to
 * be scanned by the GC during a collection cycle.
 */

int Type::hasPointers()
{
    return FALSE;
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

	case Tbool:	d = "bool";
			c = d;
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

void TypeBasic::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    //printf("TypeBasic::toCBuffer2(mod = %d, this->mod = %d)\n", mod, this->mod);
    if (mod != this->mod)
    {	toCBuffer3(buf, hgs, mod);
	return;
    }
    buf->writestring(dstring);
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
	case Tbool:	size = 1;		break;
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
#ifdef IN_GCC
    real_t    fvalue;
#else
    d_float80 fvalue;
#endif

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
	    case Tbool:		ivalue = 1;		goto Livalue;
	    case Tchar:		ivalue = 0xFF;		goto Livalue;
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
	    case Tbool:		ivalue = 0;		goto Livalue;
	    case Tchar:		ivalue = 0;		goto Livalue;
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
	    {
#if IN_GCC
		// mode doesn't matter, will be converted in RealExp anyway
		fvalue = real_t::getnan(real_t::LongDouble);
#elif __GNUC__
		// gcc nan's have the sign bit set by default, so turn it off
		// Need the volatile to prevent gcc from doing incorrect
		// constant folding.
		volatile d_float80 foo;
		foo = NAN;
		if (signbit(foo))	// signbit sometimes, not always, set
		    foo = -foo;		// turn off sign bit
		fvalue = foo;
#elif _MSC_VER
		unsigned long nan[2]= { 0xFFFFFFFF, 0x7FFFFFFF };
		fvalue = *(double*)nan;
#else
		fvalue = NAN;
#endif
		goto Lfvalue;
	    }
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
#if IN_GCC
		fvalue = real_t::getinfinity();
#elif __GNUC__
		fvalue = 1 / zero;
#elif _MSC_VER
		fvalue = std::numeric_limits<long double>::infinity();
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
    e = new IntegerExp(loc, ivalue, this);
    return e;

Lfvalue:
    if (isreal() || isimaginary())
	e = new RealExp(loc, fvalue, this);
    else
    {
	complex_t cvalue;

#if __DMC__
	//((real_t *)&cvalue)[0] = fvalue;
	//((real_t *)&cvalue)[1] = fvalue;
	cvalue = fvalue + fvalue * I;
#else
	cvalue.re = fvalue;
	cvalue.im = fvalue;
#endif
	//for (int i = 0; i < 20; i++)
	//    printf("%02x ", ((unsigned char *)&cvalue)[i]);
	//printf("\n");
	e = new ComplexExp(loc, cvalue, this);
    }
    return e;

Lint:
    e = new IntegerExp(loc, ivalue, Type::tint32);
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
		e = e->castTo(sc, t);
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
		e = e->castTo(sc, t);
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

Expression *TypeBasic::defaultInit(Loc loc)
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
	    return getProperty(loc, Id::nan);
    }
    return new IntegerExp(loc, value, this);
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

MATCH TypeBasic::implicitConvTo(Type *to)
{
    //printf("TypeBasic::implicitConvTo(%s) from %s\n", to->toChars(), toChars());
    if (this == to)
	return MATCHexact;

    if (ty == Tvoid || to->ty == Tvoid)
	return MATCHnomatch;
    if (1 || global.params.Dversion == 1)
    {
	if (to->ty == Tbool)
	    return MATCHnomatch;
    }
    else
    {
	if (ty == Tbool || to->ty == Tbool)
	    return MATCHnomatch;
    }
    if (!to->isTypeBasic())
	return MATCHnomatch;

    TypeBasic *tob = (TypeBasic *)to;
    if (flags & TFLAGSintegral)
    {
	// Disallow implicit conversion of integers to imaginary or complex
	if (tob->flags & (TFLAGSimaginary | TFLAGScomplex))
	    return MATCHnomatch;

	// If converting to integral
	if (0 && global.params.Dversion > 1 && tob->flags & TFLAGSintegral)
	{   d_uns64 sz = size(0);
	    d_uns64 tosz = tob->size(0);

	    /* Can't convert to smaller size or, if same size, change sign
	     */
	    if (sz > tosz)
		return MATCHnomatch;

	    /*if (sz == tosz && (flags ^ tob->flags) & TFLAGSunsigned)
		return MATCHnomatch;*/
	}
    }
    else if (flags & TFLAGSfloating)
    {
	// Disallow implicit conversion of floating point to integer
	if (tob->flags & TFLAGSintegral)
	    return MATCHnomatch;

	assert(tob->flags & TFLAGSfloating);

	// Disallow implicit conversion from complex to non-complex
	if (flags & TFLAGScomplex && !(tob->flags & TFLAGScomplex))
	    return MATCHnomatch;

	// Disallow implicit conversion of real or imaginary to complex
	if (flags & (TFLAGSreal | TFLAGSimaginary) &&
	    tob->flags & TFLAGScomplex)
	    return MATCHnomatch;

	// Disallow implicit conversion to-from real and imaginary
	if ((flags & (TFLAGSreal | TFLAGSimaginary)) !=
	    (tob->flags & (TFLAGSreal | TFLAGSimaginary)))
	    return MATCHnomatch;
    }
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
    if (ident == Id::reverse && (n->ty == Tchar || n->ty == Twchar))
    {
	Expression *ec;
	FuncDeclaration *fd;
	Expressions *arguments;
	char *nm;
	static char *name[2] = { "_adReverseChar", "_adReverseWchar" };

	nm = name[n->ty == Twchar];
	fd = FuncDeclaration::genCfunc(Type::tindex, nm);
	ec = new VarExp(0, fd);
	e = e->castTo(sc, n->arrayOf());	// convert to dynamic array
	arguments = new Expressions();
	arguments->push(e);
	e = new CallExp(e->loc, ec, arguments);
	e->type = next->arrayOf();
    }
    else if (ident == Id::sort && (n->ty == Tchar || n->ty == Twchar))
    {
	Expression *ec;
	FuncDeclaration *fd;
	Expressions *arguments;
	char *nm;
	static char *name[2] = { "_adSortChar", "_adSortWchar" };

	nm = name[n->ty == Twchar];
	fd = FuncDeclaration::genCfunc(Type::tindex, nm);
	ec = new VarExp(0, fd);
	e = e->castTo(sc, n->arrayOf());	// convert to dynamic array
	arguments = new Expressions();
	arguments->push(e);
	e = new CallExp(e->loc, ec, arguments);
	e->type = next->arrayOf();
    }
    else if (ident == Id::reverse || ident == Id::dup)
    {
	Expression *ec;
	FuncDeclaration *fd;
	Expressions *arguments;
	int size = next->size(e->loc);
	int dup;

	assert(size);
	dup = (ident == Id::dup);
	fd = FuncDeclaration::genCfunc(Type::tindex, dup ? Id::adDup : Id::adReverse);
	ec = new VarExp(0, fd);
	e = e->castTo(sc, n->arrayOf());	// convert to dynamic array
	arguments = new Expressions();
	if (dup)
	    arguments->push(getTypeInfo(sc));
	arguments->push(e);
	if (!dup)
	    arguments->push(new IntegerExp(0, size, Type::tint32));
	e = new CallExp(e->loc, ec, arguments);
	e->type = next->arrayOf();
    }
    else if (ident == Id::sort)
    {
	Expression *ec;
	FuncDeclaration *fd;
	Expressions *arguments;

	fd = FuncDeclaration::genCfunc(tint32->arrayOf(),
		(char*)(n->ty == Tbit ? "_adSortBit" : "_adSort"));
	ec = new VarExp(0, fd);
	e = e->castTo(sc, n->arrayOf());	// convert to dynamic array
	arguments = new Expressions();
	arguments->push(e);
	if (next->ty != Tbit)
	    arguments->push(n->ty == Tsarray
			? n->getTypeInfo(sc)	// don't convert to dynamic array
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
    error(loc, "index %jd overflow for static array", sz);
    return 1;
}

unsigned TypeSArray::alignsize()
{
    return next->alignsize();
}

/**************************
 * This evaluates exp while setting length to be the number
 * of elements in the tuple t.
 */
Expression *semanticLength(Scope *sc, Type *t, Expression *exp)
{
    if (t->ty == Ttuple)
    {	ScopeDsymbol *sym = new ArrayScopeSymbol((TypeTuple *)t);
	sym->parent = sc->scopesym;
	sc = sc->push(sym);

	exp = exp->semantic(sc);

	sc->pop();
    }
    else
	exp = exp->semantic(sc);
    return exp;
}

Expression *semanticLength(Scope *sc, TupleDeclaration *s, Expression *exp)
{
    ScopeDsymbol *sym = new ArrayScopeSymbol(s);
    sym->parent = sc->scopesym;
    sc = sc->push(sym);

    exp = exp->semantic(sc);

    sc->pop();
    return exp;
}

void TypeSArray::resolve(Loc loc, Scope *sc, Expression **pe, Type **pt, Dsymbol **ps)
{
    //printf("TypeSArray::resolve() %s\n", toChars());
    next->resolve(loc, sc, pe, pt, ps);
    //printf("s = %p, e = %p, t = %p\n", *ps, *pe, *pt);
    if (*pe)
    {	// It's really an index expression
	Expression *e;
	e = new IndexExp(loc, *pe, dim);
	*pe = e;
    }
    else if (*ps)
    {	Dsymbol *s = *ps;
	TupleDeclaration *td = s->isTupleDeclaration();
	if (td)
	{
	    ScopeDsymbol *sym = new ArrayScopeSymbol(td);
	    sym->parent = sc->scopesym;
	    sc = sc->push(sym);

	    dim = dim->semantic(sc);
	    dim = dim->optimize(WANTvalue | WANTinterpret);
	    uinteger_t d = dim->toUInteger();

	    sc = sc->pop();

	    if (d >= td->objects->dim)
	    {	error(loc, "tuple index %ju exceeds %u", d, td->objects->dim);
		goto Ldefault;
	    }
	    Object *o = (Object *)td->objects->data[(size_t)d];
	    if (o->dyncast() == DYNCAST_DSYMBOL)
	    {
		*ps = (Dsymbol *)o;
		return;
	    }
	    if (o->dyncast() == DYNCAST_EXPRESSION)
	    {
		*ps = NULL;
		*pe = (Expression *)o;
		return;
	    }

	    /* Create a new TupleDeclaration which
	     * is a slice [d..d+1] out of the old one.
	     * Do it this way because TemplateInstance::semanticTiargs()
	     * can handle unresolved Objects this way.
	     */
	    Objects *objects = new Objects;
	    objects->setDim(1);
	    objects->data[0] = o;

	    TupleDeclaration *tds = new TupleDeclaration(loc, td->ident, objects);
	    *ps = tds;
	}
	else
	    goto Ldefault;
    }
    else
    {
     Ldefault:
	Type::resolve(loc, sc, pe, pt, ps);
    }
}

Type *TypeSArray::semantic(Loc loc, Scope *sc)
{
    //printf("TypeSArray::semantic() %s\n", toChars());

    Type *t;
    Expression *e;
    Dsymbol *s;
    next->resolve(loc, sc, &e, &t, &s);
    if (dim && s && s->isTupleDeclaration())
    {	TupleDeclaration *sd = s->isTupleDeclaration();

	dim = semanticLength(sc, sd, dim);
	dim = dim->optimize(WANTvalue | WANTinterpret);
	uinteger_t d = dim->toUInteger();

	if (d >= sd->objects->dim)
	{   error(loc, "tuple index %ju exceeds %u", d, sd->objects->dim);
	    return Type::terror;
	}
	Object *o = (Object *)sd->objects->data[(size_t)d];
	if (o->dyncast() != DYNCAST_TYPE)
	{   error(loc, "%s is not a type", toChars());
	    return Type::terror;
	}
	t = (Type *)o;
	return t;
    }

    next = next->semantic(loc,sc);
    Type *tbn = next->toBasetype();

    if (dim)
    {	integer_t n, n2;

	dim = semanticLength(sc, tbn, dim);

	dim = dim->optimize(WANTvalue | WANTinterpret);
	if (sc->parameterSpecialization && dim->op == TOKvar &&
	    ((VarExp *)dim)->var->storage_class & STCtemplateparameter)
	{
	    /* It could be a template parameter N which has no value yet:
	     *   template Foo(T : T[N], size_t N);
	     */
	    return this;
	}
	integer_t d1 = dim->toInteger();
	dim = dim->castTo(sc, tsize_t);
	dim = dim->optimize(WANTvalue);
	integer_t d2 = dim->toInteger();

	if (d1 != d2)
	    goto Loverflow;

	if (tbn->isintegral() ||
		 tbn->isfloating() ||
		 tbn->ty == Tpointer ||
		 tbn->ty == Tarray ||
		 tbn->ty == Tsarray ||
		 tbn->ty == Taarray ||
		 tbn->ty == Tclass)
	{
	    /* Only do this for types that don't need to have semantic()
	     * run on them for the size, since they may be forward referenced.
	     */
	    n = tbn->size(loc);
	    n2 = n * d2;
	    if ((int)n2 < 0)
		goto Loverflow;
	    if (n2 >= 0x1000000)	// put a 'reasonable' limit on it
		goto Loverflow;
	    if (n && n2 / n != d2)
	    {
	      Loverflow:
		error(loc, "index %jd overflow for static array", d1);
		dim = new IntegerExp(0, 1, tsize_t);
	    }
	}
    }
    switch (tbn->ty)
    {
	case Ttuple:
	{   // Index the tuple to get the type
	    assert(dim);
	    TypeTuple *tt = (TypeTuple *)tbn;
	    uinteger_t d = dim->toUInteger();

	    if (d >= tt->arguments->dim)
	    {	error(loc, "tuple index %ju exceeds %u", d, tt->arguments->dim);
		return Type::terror;
	    }
	    Argument *arg = (Argument *)tt->arguments->data[(size_t)d];
	    return arg->type;
	}
	case Tfunction:
	case Tnone:
	    error(loc, "can't have array of %s", tbn->toChars());
	    tbn = next = tint32;
	    break;
    }
    if (tbn->isauto())
	error(loc, "cannot have array of auto %s", tbn->toChars());
    return merge();
}

void TypeSArray::toDecoBuffer(OutBuffer *buf)
{
    buf->writeByte(mangleChar[ty]);
    if (dim)
	buf->printf("%ju", dim->toInteger());
    if (next)
	next->toDecoBuffer(buf);
}

void TypeSArray::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    if (mod != this->mod)
    {	toCBuffer3(buf, hgs, mod);
	return;
    }
    next->toCBuffer2(buf, hgs, this->mod);
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
	e = e->castTo(sc, next->pointerTo());
    }
    else
    {
	e = TypeArray::dotExp(sc, e, ident);
    }
    return e;
}

int TypeSArray::isString()
{
    TY nty = next->toBasetype()->ty;
    return nty == Tchar || nty == Twchar || nty == Tdchar;
}

unsigned TypeSArray::memalign(unsigned salign)
{
    return next->memalign(salign);
}

MATCH TypeSArray::implicitConvTo(Type *to)
{
    //printf("TypeSArray::implicitConvTo()\n");

    // Allow implicit conversion of static array to pointer or dynamic array
    if ((IMPLICIT_ARRAY_TO_PTR && to->ty == Tpointer) &&
	(to->next->ty == Tvoid || next->equals(to->next)
	 /*|| to->next->isBaseOf(next)*/))
    {
	return MATCHconvert;
    }
    if (to->ty == Tarray)
    {	int offset = 0;

	if (next->equals(to->next) ||
	    (to->next->isBaseOf(next, &offset) && offset == 0) ||
	    to->next->ty == Tvoid)
	    return MATCHconvert;
    }
#if 0
    if (to->ty == Tsarray)
    {
	TypeSArray *tsa = (TypeSArray *)to;

	if (next->equals(tsa->next) && dim->equals(tsa->dim))
	{
	    return MATCHconvert;
	}
    }
#endif
    return Type::implicitConvTo(to);
}

Expression *TypeSArray::defaultInit(Loc loc)
{
#if LOGDEFAULTINIT
    printf("TypeSArray::defaultInit() '%s'\n", toChars());
#endif
    return next->defaultInit(loc);
}

int TypeSArray::isZeroInit()
{
    return next->isZeroInit();
}


Expression *TypeSArray::toExpression()
{
    Expression *e = next->toExpression();
    if (e)
    {	Expressions *arguments = new Expressions();
	arguments->push(dim);
	e = new ArrayExp(dim->loc, e, arguments);
    }
    return e;
}

int TypeSArray::hasPointers()
{
    return next->hasPointers();
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
    Type *tbn = tn->toBasetype();
    switch (tbn->ty)
    {
	case Tfunction:
	case Tnone:
	case Ttuple:
	    error(loc, "can't have array of %s", tbn->toChars());
	    tn = next = tint32;
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

void TypeDArray::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    if (mod != this->mod)
    {	toCBuffer3(buf, hgs, mod);
	return;
    }
    next->toCBuffer2(buf, hgs, this->mod);
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
	e = e->castTo(sc, next->pointerTo());
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
    TY nty = next->toBasetype()->ty;
    return nty == Tchar || nty == Twchar || nty == Tdchar;
}

MATCH TypeDArray::implicitConvTo(Type *to)
{
    //printf("TypeDArray::implicitConvTo()\n");

    // Allow implicit conversion of array to pointer
    if (IMPLICIT_ARRAY_TO_PTR &&
	to->ty == Tpointer &&
	(to->next->ty == Tvoid || next->equals(to->next) /*|| to->next->isBaseOf(next)*/))
    {
	return MATCHconvert;
    }

    if (to->ty == Tarray)
    {	int offset = 0;

	if ((to->next->isBaseOf(next, &offset) && offset == 0) ||
	    to->next->ty == Tvoid)
	    return MATCHconvert;
    }
    return Type::implicitConvTo(to);
}

Expression *TypeDArray::defaultInit(Loc loc)
{
#if LOGDEFAULTINIT
    printf("TypeDArray::defaultInit() '%s'\n", toChars());
#endif
    Expression *e;
    e = new NullExp(loc);
    e->type = this;
    return e;
}

int TypeDArray::isZeroInit()
{
    return 1;
}

int TypeDArray::checkBoolean()
{
    return TRUE;
}

int TypeDArray::hasPointers()
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
    return PTRSIZE /* * 2*/;
}


Type *TypeAArray::semantic(Loc loc, Scope *sc)
{
    //printf("TypeAArray::semantic() %s index->ty = %d\n", toChars(), index->ty);

    // Deal with the case where we thought the index was a type, but
    // in reality it was an expression.
    if (index->ty == Tident || index->ty == Tinstance || index->ty == Tsarray)
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
#endif
	    break;
	case Tbit:
	case Tbool:
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

void TypeAArray::resolve(Loc loc, Scope *sc, Expression **pe, Type **pt, Dsymbol **ps)
{
    //printf("TypeAArray::resolve() %s\n", toChars());

    // Deal with the case where we thought the index was a type, but
    // in reality it was an expression.
    if (index->ty == Tident || index->ty == Tinstance || index->ty == Tsarray)
    {
	Expression *e;
	Type *t;
	Dsymbol *s;

	index->resolve(loc, sc, &e, &t, &s);
	if (e)
	{   // It was an expression -
	    // Rewrite as a static array

	    TypeSArray *tsa = new TypeSArray(next, e);
	    return tsa->resolve(loc, sc, pe, pt, ps);
	}
	else if (t)
	    index = t;
	else
	    index->error(loc, "index is not a type or an expression");
    }
    Type::resolve(loc, sc, pe, pt, ps);
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
	Expressions *arguments;

	fd = FuncDeclaration::genCfunc(Type::tsize_t, Id::aaLen);
	ec = new VarExp(0, fd);
	arguments = new Expressions();
	arguments->push(e);
	e = new CallExp(e->loc, ec, arguments);
	e->type = fd->type->next;
    }
    else if (ident == Id::keys)
    {
	Expression *ec;
	FuncDeclaration *fd;
	Expressions *arguments;
	int size = key->size(e->loc);

	assert(size);
	fd = FuncDeclaration::genCfunc(Type::tindex, Id::aaKeys);
	ec = new VarExp(0, fd);
	arguments = new Expressions();
	arguments->push(e);
	arguments->push(new IntegerExp(0, size, Type::tsize_t));
	e = new CallExp(e->loc, ec, arguments);
	e->type = index->arrayOf();
    }
    else if (ident == Id::values)
    {
	Expression *ec;
	FuncDeclaration *fd;
	Expressions *arguments;

	fd = FuncDeclaration::genCfunc(Type::tindex, Id::aaValues);
	ec = new VarExp(0, fd);
	arguments = new Expressions();
	arguments->push(e);
	size_t keysize = key->size(e->loc);
	keysize = (keysize + 3) & ~3;	// BUG: 64 bit pointers?
	arguments->push(new IntegerExp(0, keysize, Type::tsize_t));
	arguments->push(new IntegerExp(0, next->size(e->loc), Type::tsize_t));
	e = new CallExp(e->loc, ec, arguments);
	e->type = next->arrayOf();
    }
    else if (ident == Id::rehash)
    {
	Expression *ec;
	FuncDeclaration *fd;
	Expressions *arguments;

	fd = FuncDeclaration::genCfunc(Type::tint64, Id::aaRehash);
	ec = new VarExp(0, fd);
	arguments = new Expressions();
	arguments->push(e->addressOf(sc));
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

void TypeAArray::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    if (mod != this->mod)
    {	toCBuffer3(buf, hgs, mod);
	return;
    }
    next->toCBuffer2(buf, hgs, this->mod);
    buf->writeByte('[');
    index->toCBuffer2(buf, hgs, 0);
    buf->writeByte(']');
}

Expression *TypeAArray::defaultInit(Loc loc)
{
#if LOGDEFAULTINIT
    printf("TypeAArray::defaultInit() '%s'\n", toChars());
#endif
    Expression *e;
    e = new NullExp(loc);
    e->type = this;
    return e;
}

int TypeAArray::checkBoolean()
{
    return TRUE;
}

int TypeAArray::hasPointers()
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
    Type *n = next->semantic(loc, sc);
    switch (n->toBasetype()->ty)
    {
	case Ttuple:
	    error(loc, "can't have pointer to %s", n->toChars());
	    n = tint32;
	    break;
    }
    if (n != next)
	deco = NULL;
    next = n;
    return merge();
}


d_uns64 TypePointer::size(Loc loc)
{
    return PTRSIZE;
}

void TypePointer::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    //printf("TypePointer::toCBuffer2() next = %d\n", next->ty);
    if (mod != this->mod)
    {	toCBuffer3(buf, hgs, mod);
	return;
    }
    next->toCBuffer2(buf, hgs, this->mod);
    if (next->ty != Tfunction)
	buf->writeByte('*');
}

MATCH TypePointer::implicitConvTo(Type *to)
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

Expression *TypePointer::defaultInit(Loc loc)
{
#if LOGDEFAULTINIT
    printf("TypePointer::defaultInit() '%s'\n", toChars());
#endif
    Expression *e;
    e = new NullExp(loc);
    e->type = this;
    return e;
}

int TypePointer::isZeroInit()
{
    return 1;
}

int TypePointer::hasPointers()
{
    return TRUE;
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

void TypeReference::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    if (mod != this->mod)
    {	toCBuffer3(buf, hgs, mod);
	return;
    }
    next->toCBuffer2(buf, hgs, this->mod);
    buf->writeByte('&');
}

Expression *TypeReference::dotExp(Scope *sc, Expression *e, Identifier *ident)
{
#if LOGDOTEXP
    printf("TypeReference::dotExp(e = '%s', ident = '%s')\n", e->toChars(), ident->toChars());
#endif

    // References just forward things along
    return next->dotExp(sc, e, ident);
}

Expression *TypeReference::defaultInit(Loc loc)
{
#if LOGDEFAULTINIT
    printf("TypeReference::defaultInit() '%s'\n", toChars());
#endif
    Expression *e;
    e = new NullExp(loc);
    e->type = this;
    return e;
}

int TypeReference::isZeroInit()
{
    return 1;
}


/***************************** TypeFunction *****************************/

TypeFunction::TypeFunction(Arguments *parameters, Type *treturn, int varargs, enum LINK linkage)
    : Type(Tfunction, treturn)
{
//if (!treturn) *(char*)0=0;
//    assert(treturn);
    this->parameters = parameters;
    this->varargs = varargs;
    this->linkage = linkage;
    this->inuse = 0;
}

Type *TypeFunction::syntaxCopy()
{
    Type *treturn = next ? next->syntaxCopy() : NULL;
    Arguments *params = Argument::arraySyntaxCopy(parameters);
    Type *t = new TypeFunction(params, treturn, varargs, linkage);
    return t;
}

/*******************************
 * Returns:
 *	0	types are distinct
 *	1	this is covariant with t
 *	2	arguments match as far as overloading goes,
 *		but types are not covariant
 *	3	cannot determine covariance because of forward references
 */

int Type::covariant(Type *t)
{
#if 0
    printf("Type::covariant(t = %s) %s\n", t->toChars(), toChars());
    printf("deco = %p, %p\n", deco, t->deco);
    printf("ty = %d\n", next->ty);
#endif

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

    if (t1->parameters && t2->parameters)
    {
	size_t dim = Argument::dim(t1->parameters);
	if (dim != Argument::dim(t2->parameters))
	    goto Ldistinct;

	for (size_t i = 0; i < dim; i++)
	{   Argument *arg1 = Argument::getNth(t1->parameters, i);
	    Argument *arg2 = Argument::getNth(t2->parameters, i);

	    if (!arg1->type->equals(arg2->type))
		goto Ldistinct;
	    if (arg1->storageClass != arg2->storageClass)
		inoutmismatch = 1;
	}
    }
    else if (t1->parameters != t2->parameters)
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

    // If t1n is forward referenced:
    ClassDeclaration *cd = ((TypeClass *)t1n)->sym;
    if (!cd->baseClass && cd->baseclasses.dim && !cd->isInterfaceDeclaration())
    {
	return 3;
    }

    if (t1n->implicitConvTo(t2n))
	goto Lcovariant;
    goto Lnotcovariant;
    }

Lcovariant:
    //printf("\tcovaraint: 1\n");
    return 1;

Ldistinct:
    //printf("\tcovaraint: 0\n");
    return 0;

Lnotcovariant:
    //printf("\tcovaraint: 2\n");
    return 2;
}

void TypeFunction::toDecoBuffer(OutBuffer *buf)
{   unsigned char mc;

    //printf("TypeFunction::toDecoBuffer() this = %p %s\n", this, toChars());
    //static int nest; if (++nest == 50) *(char*)0=0;
    if (inuse)
    {	inuse = 2;		// flag error to caller
	return;
    }
    inuse++;
    switch (linkage)
    {
	case LINKd:		mc = 'F';	break;
	case LINKc:		mc = 'U';	break;
	case LINKwindows:	mc = 'W';	break;
	case LINKpascal:	mc = 'V';	break;
	case LINKcpp:		mc = 'R';	break;
	default:
	    assert(0);
    }
    buf->writeByte(mc);
    // Write argument types
    Argument::argsToDecoBuffer(buf, parameters);
    //if (buf->data[buf->offset - 1] == '@') halt();
    buf->writeByte('Z' - varargs);	// mark end of arg list
    next->toDecoBuffer(buf);
    inuse--;
}

void TypeFunction::toCBuffer(OutBuffer *buf, Identifier *ident, HdrGenState *hgs)
{
    char *p = NULL;

    if (inuse)
    {	inuse = 2;		// flag error to caller
	return;
    }
    inuse++;
    if (next && (!ident || ident->toHChars2() == ident->toChars()))
	next->toCBuffer2(buf, hgs, 0);
    if (hgs->ddoc != 1)
    {
	switch (linkage)
	{
	    case LINKd:		p = NULL;	break;
	    case LINKc:		p = "C ";	break;
	    case LINKwindows:	p = "Windows ";	break;
	    case LINKpascal:	p = "Pascal ";	break;
	    case LINKcpp:	p = "C++ ";	break;
	    default:
		assert(0);
	}
    }

    if (!hgs->hdrgen && p)
	buf->writestring(p);
    if (ident)
    {   buf->writeByte(' ');
	buf->writestring(ident->toHChars2());
    }
    Argument::argsToCBuffer(buf, hgs, parameters, varargs);
    inuse--;
}

void TypeFunction::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    char *p = NULL;

    if (inuse)
    {	inuse = 2;		// flag error to caller
	return;
    }
    inuse++;
    if (next)
	next->toCBuffer2(buf, hgs, 0);
    if (hgs->ddoc != 1)
    {
	switch (linkage)
	{
	    case LINKd:		p = NULL;	break;
	    case LINKc:		p = "C ";	break;
	    case LINKwindows:	p = "Windows ";	break;
	    case LINKpascal:	p = "Pascal ";	break;
	    case LINKcpp:	p = "C++ ";	break;
	    default:
		assert(0);
	}
    }

    if (!hgs->hdrgen && p)
	buf->writestring(p);
    buf->writestring(" function");
    Argument::argsToCBuffer(buf, hgs, parameters, varargs);
    inuse--;
}

Type *TypeFunction::semantic(Loc loc, Scope *sc)
{
    if (deco)			// if semantic() already run
    {
	//printf("already done\n");
	return this;
    }
    //printf("TypeFunction::semantic() this = %p\n", this);

    TypeFunction *tf = (TypeFunction *)mem.malloc(sizeof(TypeFunction));
    memcpy(tf, this, sizeof(TypeFunction));
    if (parameters)
    {	tf->parameters = (Arguments *)parameters->copy();
	for (size_t i = 0; i < parameters->dim; i++)
	{   Argument *arg = (Argument *)parameters->data[i];
	    Argument *cpy = (Argument *)mem.malloc(sizeof(Argument));
	    memcpy(cpy, arg, sizeof(Argument));
	    tf->parameters->data[i] = (void *)cpy;
	}
    }

    tf->linkage = sc->linkage;
    if (!tf->next)
    {
	assert(global.errors);
	tf->next = tvoid;
    }
    tf->next = tf->next->semantic(loc,sc);
    if (tf->next->toBasetype()->ty == Tsarray)
    {	error(loc, "functions cannot return static array %s", tf->next->toChars());
	tf->next = Type::terror;
    }
    if (tf->next->toBasetype()->ty == Tfunction)
    {	error(loc, "functions cannot return a function");
	tf->next = Type::terror;
    }
    if (tf->next->toBasetype()->ty == Ttuple)
    {	error(loc, "functions cannot return a tuple");
	tf->next = Type::terror;
    }
    if (tf->next->isauto() && !(sc->flags & SCOPEctor))
	error(loc, "functions cannot return auto %s", tf->next->toChars());

    if (tf->parameters)
    {	size_t dim = Argument::dim(tf->parameters);

	for (size_t i = 0; i < dim; i++)
	{   Argument *arg = Argument::getNth(tf->parameters, i);
	    Type *t;

	    tf->inuse++;
	    arg->type = arg->type->semantic(loc,sc);
	    if (tf->inuse == 1) tf->inuse--;
	    t = arg->type->toBasetype();

	    if (arg->storageClass & (STCout | STCref | STClazy))
	    {
		if (t->ty == Tsarray)
		    error(loc, "cannot have out or ref parameter of type %s", t->toChars());
	    }
	    if (!(arg->storageClass & STClazy) && t->ty == Tvoid)
		error(loc, "cannot have parameter of type %s", arg->type->toChars());

	    if (arg->defaultArg)
	    {
		arg->defaultArg = arg->defaultArg->semantic(sc);
		arg->defaultArg = resolveProperties(sc, arg->defaultArg);
		arg->defaultArg = arg->defaultArg->implicitCastTo(sc, arg->type);
	    }

	    /* If arg turns out to be a tuple, the number of parameters may
	     * change.
	     */
	    if (t->ty == Ttuple)
	    {	dim = Argument::dim(tf->parameters);
		i--;
	    }
	}
    }
    tf->deco = tf->merge()->deco;

    if (tf->inuse)
    {	error(loc, "recursive type");
	tf->inuse = 0;
	return terror;
    }

    if (tf->varargs == 1 && tf->linkage != LINKd && Argument::dim(tf->parameters) == 0)
	error(loc, "variadic functions with non-D linkage must have at least one parameter");

    /* Don't return merge(), because arg identifiers and default args
     * can be different
     * even though the types match
     */
    return tf;
}

/********************************
 * 'args' are being matched to function 'this'
 * Determine match level.
 * Returns:
 *	MATCHxxxx
 */

int TypeFunction::callMatch(Expressions *args)
{
    //printf("TypeFunction::callMatch()\n");
    int match = MATCHexact;		// assume exact match

    size_t nparams = Argument::dim(parameters);
    size_t nargs = args ? args->dim : 0;
    if (nparams == nargs)
	;
    else if (nargs > nparams)
    {
	if (varargs == 0)
	    goto Nomatch;		// too many args; no match
	match = MATCHconvert;		// match ... with a "conversion" match level
    }

    for (size_t u = 0; u < nparams; u++)
    {	int m;
	Expression *arg;

	// BUG: what about out and ref?

	Argument *p = Argument::getNth(parameters, u);
	assert(p);
	if (u >= nargs)
	{
	    if (p->defaultArg)
		continue;
	    if (varargs == 2 && u + 1 == nparams)
		goto L1;
	    goto Nomatch;		// not enough arguments
	}
	arg = (Expression *)args->data[u];
	assert(arg);
	if (p->storageClass & STClazy && p->type->ty == Tvoid && arg->type->ty != Tvoid)
	    m = MATCHconvert;
	else
	    m = arg->implicitConvTo(p->type);
	//printf("\tm = %d\n", m);
	if (m == MATCHnomatch)			// if no match
	{
	  L1:
	    if (varargs == 2 && u + 1 == nparams)	// if last varargs param
	    {	Type *tb = p->type->toBasetype();
		TypeSArray *tsa;
		integer_t sz;

		switch (tb->ty)
		{
		    case Tsarray:
			tsa = (TypeSArray *)tb;
			sz = tsa->dim->toInteger();
			if (sz != nargs - u)
			    goto Nomatch;
		    case Tarray:
			for (; u < nargs; u++)
			{
			    arg = (Expression *)args->data[u];
			    assert(arg);
#if 1
			    /* If lazy array of delegates,
			     * convert arg(s) to delegate(s)
			     */
			    Type *tret = p->isLazyArray();
			    if (tret)
			    {
				if (tb->next->equals(arg->type))
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
				m = arg->implicitConvTo(tb->next);
#else
			    m = arg->implicitConvTo(tb->next);
#endif
			    if (m == 0)
				goto Nomatch;
			    if (m < match)
				match = m;
			}
			goto Ldone;

		    case Tclass:
			// Should see if there's a constructor match?
			// Or just leave it ambiguous?
			goto Ldone;

		    default:
			goto Nomatch;
		}
	    }
	    goto Nomatch;
	}
	if (m < match)
	    match = m;			// pick worst match
    }

Ldone:
    //printf("match = %d\n", match);
    return match;

Nomatch:
    //printf("no match\n");
    return MATCHnomatch;
}

Type *TypeFunction::reliesOnTident()
{
    if (parameters)
    {
	for (size_t i = 0; i < parameters->dim; i++)
	{   Argument *arg = (Argument *)parameters->data[i];
	    Type *t = arg->type->reliesOnTident();
	    if (t)
		return t;
	}
    }
    return next->reliesOnTident();
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

void TypeDelegate::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    if (mod != this->mod)
    {	toCBuffer3(buf, hgs, mod);
	return;
    }
    TypeFunction *tf = (TypeFunction *)next;

    tf->next->toCBuffer2(buf, hgs, 0);
    buf->writestring(" delegate");
    Argument::argsToCBuffer(buf, hgs, tf->parameters, tf->varargs);
}

Expression *TypeDelegate::defaultInit(Loc loc)
{
#if LOGDEFAULTINIT
    printf("TypeDelegate::defaultInit() '%s'\n", toChars());
#endif
    Expression *e;
    e = new NullExp(loc);
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

Expression *TypeDelegate::dotExp(Scope *sc, Expression *e, Identifier *ident)
{
#if LOGDOTEXP
    printf("TypeDelegate::dotExp(e = '%s', ident = '%s')\n", e->toChars(), ident->toChars());
#endif
    if (ident == Id::ptr)
    {
	e->type = tvoidptr;
	return e;
    }
    else if (ident == Id::funcptr)
    {
	e = e->addressOf(sc);
	e->type = tvoidptr;
	e = new AddExp(e->loc, e, new IntegerExp(PTRSIZE));
	e->type = tvoidptr;
	e = new PtrExp(e->loc, e);
	e->type = next->pointerTo();
	return e;
    }
    else
    {
	e = Type::dotExp(sc, e, ident);
    }
    return e;
}

int TypeDelegate::hasPointers()
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
    //printf("TypeQualified::syntaxCopyHelper(%s) %s\n", t->toChars(), toChars());
    idents.setDim(t->idents.dim);
    for (int i = 0; i < idents.dim; i++)
    {
	Identifier *id = (Identifier *)t->idents.data[i];
	if (id->dyncast() == DYNCAST_DSYMBOL)
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

void TypeQualified::toCBuffer2Helper(OutBuffer *buf, HdrGenState *hgs)
{
    int i;

    for (i = 0; i < idents.dim; i++)
    {	Identifier *id = (Identifier *)idents.data[i];

	buf->writeByte('.');

	if (id->dyncast() == DYNCAST_DSYMBOL)
	{
	    TemplateInstance *ti = (TemplateInstance *)id;
	    ti->toCBuffer(buf, hgs);
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
    TupleDeclaration *td;
    Type *t;
    Expression *e;

#if 0
    printf("TypeQualified::resolveHelper(sc = %p, idents = '%s')\n", sc, toChars());
    if (scopesym)
	printf("\tscopesym = '%s'\n", scopesym->toChars());
#endif
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
	    sm = s->searchX(loc, sc, id);
	    //printf("\t3: s = '%s' %p, kind = '%s'\n",s->toChars(), s, s->kind());
	    //printf("getType = '%s'\n", s->getType()->toChars());
	    if (!sm)
	    {
		v = s->isVarDeclaration();
		if (v && id == Id::length)
		{
		    if (v->isConst() && v->getExpInitializer())
		    {	e = v->getExpInitializer()->exp;
		    }
		    else
			e = new VarExp(loc, v);
		    t = e->type;
		    if (!t)
			goto Lerror;
		    goto L3;
		}
		t = s->getType();
		if (!t && s->isDeclaration())
		    t = s->isDeclaration()->type;
		if (t)
		{
		    sm = t->toDsymbol(sc);
		    if (sm)
		    {	sm = sm->search(loc, id, 0);
			if (sm)
			    goto L2;
		    }
		    //e = t->getProperty(loc, id);
		    e = new TypeExp(loc, t);
		    e = t->dotExp(sc, e, id);
		    i++;
		L3:
		    for (; i < idents.dim; i++)
		    {
			id = (Identifier *)idents.data[i];
			//printf("e: '%s', id: '%s', type = %p\n", e->toChars(), id->toChars(), e->type);
			e = e->type->dotExp(sc, e, id);
		    }
		    *pe = e;
		}
		else
	          Lerror:
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
#if 0
		WithScopeSymbol *withsym;
		if (scopesym && (withsym = scopesym->isWithScopeSymbol()) != NULL)
		{
		    // Same as wthis.ident
		    e = new VarExp(loc, withsym->withstate->wthis);
		    e = new DotIdExp(loc, e, ident);
		    //assert(0);	// BUG: should handle this
		}
		else
#endif
		    *pe = new VarExp(loc, v);
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
		s = si->search(loc, s->ident, 0);
		if (s && s != si)
		    goto L1;
		s = si;
	    }
	    *ps = s;
	    return;
	}
	if (t->ty == Tinstance && t != this && !t->deco)
	{   error(loc, "forward reference to '%s'", t->toChars());
	    return;
	}

	if (t != this)
	{
	    if (t->reliesOnTident())
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
		t = t->semantic(loc, scx);
		//((TypeIdentifier *)t)->resolve(loc, scx, pe, &t, ps);
	    }
	}
	if (t->ty == Ttuple)
	    *pt = t;
	else
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

void TypeIdentifier::toDecoBuffer(OutBuffer *buf)
{   unsigned len;
    char *name;

    name = ident->toChars();
    len = strlen(name);
    buf->printf("%c%d%s", mangleChar[ty], len, name);
    //buf->printf("%c%s", mangleChar[ty], name);
}

void TypeIdentifier::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    if (mod != this->mod)
    {	toCBuffer3(buf, hgs, mod);
	return;
    }
    buf->writestring(this->ident->toChars());
    toCBuffer2Helper(buf, hgs);
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
    s = sc->search(loc, ident, &scopesym);
    resolveHelper(loc, sc, s, scopesym, pe, pt, ps);
}

/*****************************************
 * See if type resolves to a symbol, if so,
 * return that symbol.
 */

Dsymbol *TypeIdentifier::toDsymbol(Scope *sc)
{
    //printf("TypeIdentifier::toDsymbol('%s')\n", toChars());
    if (!sc)
	return NULL;
    //printf("ident = '%s'\n", ident->toChars());

    Dsymbol *scopesym;
    Dsymbol *s = sc->search(loc, ident, &scopesym);
    if (s)
    {
	for (int i = 0; i < idents.dim; i++)
	{
	    Identifier *id = (Identifier *)idents.data[i];
	    s = s->searchX(loc, sc, id);
	    if (!s)                 // failed to find a symbol
	    {	//printf("\tdidn't find a symbol\n");
		break;
	    }
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
    if (t)
    {
	//printf("\tit's a type %d, %s, %s\n", t->ty, t->toChars(), t->deco);

	if (t->ty == Ttypedef)
	{   TypeTypedef *tt = (TypeTypedef *)t;

	    if (tt->sym->sem == 1)
		error(loc, "circular reference of typedef %s", tt->toChars());
	}
    }
    else
    {
#ifdef DEBUG
	if (!global.gag)
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

Type *TypeIdentifier::reliesOnTident()
{
    return this;
}

Expression *TypeIdentifier::toExpression()
{
    Expression *e = new IdentifierExp(loc, ident);
    for (int i = 0; i < idents.dim; i++)
    {
	Identifier *id = (Identifier *)idents.data[i];
	e = new DotIdExp(loc, e, id);
    }

    return e;
}

/***************************** TypeInstance *****************************/

TypeInstance::TypeInstance(Loc loc, TemplateInstance *tempinst)
    : TypeQualified(Tinstance, loc)
{
    this->tempinst = tempinst;
}

Type *TypeInstance::syntaxCopy()
{
    //printf("TypeInstance::syntaxCopy() %s, %d\n", toChars(), idents.dim);
    TypeInstance *t;

    t = new TypeInstance(loc, (TemplateInstance *)tempinst->syntaxCopy(NULL));
    t->syntaxCopyHelper(this);
    return t;
}


void TypeInstance::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    if (mod != this->mod)
    {	toCBuffer3(buf, hgs, mod);
	return;
    }
    tempinst->toCBuffer(buf, hgs);
    toCBuffer2Helper(buf, hgs);
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

    if (sc->parameterSpecialization)
    {
	unsigned errors = global.errors;
	global.gag++;

	resolve(loc, sc, &e, &t, &s);

	global.gag--;
	if (errors != global.errors)
	{   if (global.gag == 0)
		global.errors = errors;
	    return this;
	}
    }
    else
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
    if (t == this)
	return NULL;
    return t->toDsymbol(sc);
}

void TypeTypeof::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    if (mod != this->mod)
    {	toCBuffer3(buf, hgs, mod);
	return;
    }
    buf->writestring("typeof(");
    exp->toCBuffer(buf, hgs);
    buf->writeByte(')');
    toCBuffer2Helper(buf, hgs);
}

Type *TypeTypeof::semantic(Loc loc, Scope *sc)
{   Expression *e;
    Type *t;

    //printf("TypeTypeof::semantic() %p\n", this);

    //static int nest; if (++nest == 50) *(char*)0=0;

#if 0
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
#endif
    {
	sc->intypeof++;
	exp = exp->semantic(sc);
	sc->intypeof--;
	t = exp->type;
	if (!t)
	{
	    error(loc, "expression (%s) has no type", exp->toChars());
	    goto Lerr;
	}
    }

    if (idents.dim)
    {
	Dsymbol *s = t->toDsymbol(sc);
	for (size_t i = 0; i < idents.dim; i++)
	{
	    if (!s)
		break;
	    Identifier *id = (Identifier *)idents.data[i];
	    s = s->searchX(loc, sc, id);
	}
	if (s)
	{
	    t = s->getType();
	    if (!t)
	    {	error(loc, "%s is not a type", s->toChars());
		goto Lerr;
	    }
	}
	else
	{   error(loc, "cannot resolve .property for %s", toChars());
	    goto Lerr;
	}
    }
    return t;

Lerr:
    return tvoid;
}

d_uns64 TypeTypeof::size(Loc loc)
{
    if (exp->type)
	return exp->type->size(loc);
    else
	return TypeQualified::size(loc);
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
    if (!sym->memtype)
    {
#ifdef DEBUG
	printf("1: ");
#endif
	error(0, "enum %s is forward referenced", sym->toChars());
	return 4;
    }
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
#ifdef DEBUG
	printf("2: ");
#endif
	error(sym->loc, "enum %s is forward referenced", sym->toChars());
	return tint32;
    }
    return sym->memtype->toBasetype();
}

void TypeEnum::toDecoBuffer(OutBuffer *buf)
{   char *name;

    name = sym->mangle();
//    if (name[0] == '_' && name[1] == 'D')
//	name += 2;
    buf->printf("%c%s", mangleChar[ty], name);
}

void TypeEnum::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    if (mod != this->mod)
    {	toCBuffer3(buf, hgs, mod);
	return;
    }
    buf->writestring(sym->toChars());
}

Expression *TypeEnum::dotExp(Scope *sc, Expression *e, Identifier *ident)
{
    EnumMember *m;
    Dsymbol *s;
    Expression *em;

#if LOGDOTEXP
    printf("TypeEnum::dotExp(e = '%s', ident = '%s') '%s'\n", e->toChars(), ident->toChars(), toChars());
#endif
    if (!sym->symtab)
	goto Lfwd;
    s = sym->symtab->lookup(ident);
    if (!s)
    {
	return getProperty(e->loc, ident);
    }
    m = s->isEnumMember();
    em = m->value->copy();
    em->loc = e->loc;
    return em;

Lfwd:
    error(e->loc, "forward reference of %s.%s", toChars(), ident->toChars());
    return new IntegerExp(0, 0, this);
}

Expression *TypeEnum::getProperty(Loc loc, Identifier *ident)
{   Expression *e;

    if (ident == Id::max)
    {
	if (!sym->symtab)
	    goto Lfwd;
	e = new IntegerExp(0, sym->maxval, this);
    }
    else if (ident == Id::min)
    {
	if (!sym->symtab)
	    goto Lfwd;
	e = new IntegerExp(0, sym->minval, this);
    }
    else if (ident == Id::init)
    {
	if (!sym->symtab)
	    goto Lfwd;
	e = defaultInit(loc);
    }
    else
    {
	if (!sym->memtype)
	    goto Lfwd;
	e = sym->memtype->getProperty(loc, ident);
    }
    return e;

Lfwd:
    error(loc, "forward reference of %s.%s", toChars(), ident->toChars());
    return new IntegerExp(0, 0, this);
}

int TypeEnum::isintegral()
{
    return 1;
}

int TypeEnum::isfloating()
{
    return 0;
}

int TypeEnum::isunsigned()
{
    return sym->memtype->isunsigned();
}

int TypeEnum::isscalar()
{
    return 1;
    //return sym->memtype->isscalar();
}

MATCH TypeEnum::implicitConvTo(Type *to)
{   MATCH m;

    //printf("TypeEnum::implicitConvTo()\n");
    if (this->equals(to))
	m = MATCHexact;		// exact match
    else if (sym->memtype->implicitConvTo(to))
	m = MATCHconvert;	// match with conversions
    else
	m = MATCHnomatch;	// no match
    return m;
}

Expression *TypeEnum::defaultInit(Loc loc)
{
#if LOGDEFAULTINIT
    printf("TypeEnum::defaultInit() '%s'\n", toChars());
#endif
    // Initialize to first member of enum
    Expression *e;
    e = new IntegerExp(loc, sym->defaultval, this);
    return e;
}

int TypeEnum::isZeroInit()
{
    return (sym->defaultval == 0);
}

int TypeEnum::hasPointers()
{
    return toBasetype()->hasPointers();
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
    //printf("TypeTypedef::semantic(%s), sem = %d\n", toChars(), sym->sem);
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
//    if (name[0] == '_' && name[1] == 'D')
//	name += 2;
    //len = strlen(name);
    //buf->printf("%c%d%s", mangleChar[ty], len, name);
    buf->printf("%c%s", mangleChar[ty], name);
}

void TypeTypedef::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    //printf("TypeTypedef::toCBuffer2() '%s'\n", sym->toChars());
    if (mod != this->mod)
    {	toCBuffer3(buf, hgs, mod);
	return;
    }
    buf->writestring(sym->toChars());
}

Expression *TypeTypedef::dotExp(Scope *sc, Expression *e, Identifier *ident)
{
#if LOGDOTEXP
    printf("TypeTypedef::dotExp(e = '%s', ident = '%s') '%s'\n", e->toChars(), ident->toChars(), toChars());
#endif
    if (ident == Id::init)
    {
	return Type::dotExp(sc, e, ident);
    }
    return sym->basetype->dotExp(sc, e, ident);
}

Expression *TypeTypedef::getProperty(Loc loc, Identifier *ident)
{
    if (ident == Id::init)
    {
	return Type::getProperty(loc, ident);
    }
    return sym->basetype->getProperty(loc, ident);
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

int TypeTypedef::isreal()
{
    return sym->basetype->isreal();
}

int TypeTypedef::isimaginary()
{
    return sym->basetype->isimaginary();
}

int TypeTypedef::iscomplex()
{
    return sym->basetype->iscomplex();
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
    if (sym->inuse)
    {
	sym->error("circular definition");
	sym->basetype = Type::terror;
	return Type::terror;
    }
    sym->inuse = 1;
    Type *t = sym->basetype->toBasetype();
    sym->inuse = 0;
    return t;
}

MATCH TypeTypedef::implicitConvTo(Type *to)
{   MATCH m;

    //printf("TypeTypedef::implicitConvTo()\n");
    if (this->equals(to))
	m = MATCHexact;		// exact match
    else if (sym->basetype->implicitConvTo(to))
	m = MATCHconvert;	// match with conversions
    else
	m = MATCHnomatch;	// no match
    return m;
}

Expression *TypeTypedef::defaultInit(Loc loc)
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
    e = bt->defaultInit(loc);
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
    {
	if (sym->init->isVoidInitializer())
	    return 1;		// initialize voids to 0
	Expression *e = sym->init->toExpression();
	if (e && e->isBool(FALSE))
	    return 1;
	return 0;		// assume not
    }
    if (sym->inuse)
    {
	sym->error("circular definition");
	sym->basetype = Type::terror;
    }
    sym->inuse = 1;
    int result = sym->basetype->isZeroInit();
    sym->inuse = 0;
    return result;
}

int TypeTypedef::hasPointers()
{
    return toBasetype()->hasPointers();
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
    TemplateInstance *ti = sym->parent->isTemplateInstance();
    if (ti && ti->toAlias() == sym)
	return ti->toChars();
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
    //printf("TypeStruct::toDecoBuffer('%s') = '%s'\n", toChars(), name);
//    if (name[0] == '_' && name[1] == 'D')
//	name += 2;
    //len = strlen(name);
    //buf->printf("%c%d%s", mangleChar[ty], len, name);
    buf->printf("%c%s", mangleChar[ty], name);
}

void TypeStruct::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    if (mod != this->mod)
    {	toCBuffer3(buf, hgs, mod);
	return;
    }
    TemplateInstance *ti = sym->parent->isTemplateInstance();
    if (ti && ti->toAlias() == sym)
	buf->writestring(ti->toChars());
    else
	buf->writestring(sym->toChars());
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

    if (ident == Id::tupleof)
    {
	/* Create a TupleExp
	 */
	Expressions *exps = new Expressions;
	exps->reserve(sym->fields.dim);
	for (size_t i = 0; i < sym->fields.dim; i++)
	{   VarDeclaration *v = (VarDeclaration *)sym->fields.data[i];
	    Expression *fe = new DotVarExp(e->loc, e, v);
	    exps->push(fe);
	}
	e = new TupleExp(e->loc, exps);
	e = e->semantic(sc);
	return e;
    }

    if (e->op == TOKdotexp)
    {	DotExp *de = (DotExp *)e;

	if (de->e1->op == TOKimport)
	{
	    ScopeExp *se = (ScopeExp *)de->e1;

	    s = se->sds->search(e->loc, ident, 0);
	    e = de->e1;
	    goto L1;
	}
    }

    s = sym->search(e->loc, ident, 0);
L1:
    if (!s)
    {
	//return getProperty(e->loc, ident);
	return Type::dotExp(sc, e, ident);
    }
    s = s->toAlias();

    v = s->isVarDeclaration();
    if (v && v->isConst())
    {	ExpInitializer *ei = v->getExpInitializer();

	if (ei)
	{   e = ei->exp->copy();	// need to copy it if it's a StringExp
	    e = e->semantic(sc);
	    return e;
	}
    }

    if (s->getType())
    {
	//return new DotTypeExp(e->loc, e, s);
	return new TypeExp(e->loc, s->getType());
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

    TemplateDeclaration *td = s->isTemplateDeclaration();
    if (td)
    {
        e = new DotTemplateExp(e->loc, e, td);
        e->semantic(sc);
	return e;
    }

    TemplateInstance *ti = s->isTemplateInstance();
    if (ti)
    {	if (!ti->semanticdone)
	    ti->semantic(sc);
	s = ti->inst->toAlias();
	if (!s->isTemplateInstance())
	    goto L1;
	Expression *de = new DotExp(e->loc, e, new ScopeExp(e->loc, ti));
	de->type = e->type;
	return de;
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
	if (d->isTupleDeclaration())
	{
	    e = new TupleExp(e->loc, d->isTupleDeclaration());
	    e = e->semantic(sc);
	    return e;
	}
	return new VarExp(e->loc, d);
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

    if (v)
    {
	if (v->toParent() != sym)
	    sym->error(e->loc, "'%s' is not a member", v->toChars());

	// *(&e + offset)
	accessCheck(e->loc, sc, e, d);
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

Expression *TypeStruct::defaultInit(Loc loc)
{   Symbol *s;
    Declaration *d;

#if LOGDEFAULTINIT
    printf("TypeStruct::defaultInit() '%s'\n", toChars());
#endif
    s = sym->toInitializer();
    d = new SymbolDeclaration(sym->loc, s, sym);
    assert(d);
    d->type = this;
    return new VarExp(sym->loc, d);
}

int TypeStruct::isZeroInit()
{
    return sym->zeroInit;
}

int TypeStruct::checkBoolean()
{
    return FALSE;
}

int TypeStruct::hasPointers()
{
    StructDeclaration *s = sym;

    sym->size(0);		// give error for forward references
    if (s->members)
    {
	for (size_t i = 0; i < s->members->dim; i++)
	{
	    Dsymbol *sm = (Dsymbol *)s->members->data[i];
	    if (sm->hasPointers())
		return TRUE;
	}
    }
    return FALSE;
}


/***************************** TypeClass *****************************/

TypeClass::TypeClass(ClassDeclaration *sym)
	: Type(Tclass, NULL)
{
    this->sym = sym;
}

char *TypeClass::toChars()
{
    return sym->toPrettyChars();
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
//    if (name[0] == '_' && name[1] == 'D')
//	name += 2;
    //printf("TypeClass::toDecoBuffer('%s') = '%s'\n", toChars(), name);
    //len = strlen(name);
    //buf->printf("%c%d%s", mangleChar[ty], len, name);
    buf->printf("%c%s", mangleChar[ty], name);
}

void TypeClass::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    if (mod != this->mod)
    {	toCBuffer3(buf, hgs, mod);
	return;
    }
    buf->writestring(sym->toChars());
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

	    s = se->sds->search(e->loc, ident, 0);
	    e = de->e1;
	    goto L1;
	}
    }

    if (ident == Id::tupleof)
    {
	/* Create a TupleExp
	 */
	Expressions *exps = new Expressions;
	exps->reserve(sym->fields.dim);
	for (size_t i = 0; i < sym->fields.dim; i++)
	{   VarDeclaration *v = (VarDeclaration *)sym->fields.data[i];
	    Expression *fe = new DotVarExp(e->loc, e, v);
	    exps->push(fe);
	}
	e = new TupleExp(e->loc, exps);
	e = e->semantic(sc);
	return e;
    }

    s = sym->search(e->loc, ident, 0);
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
		/* For type.classinfo, we know the classinfo
		 * at compile time.
		 */
		if (!sym->vclassinfo)
		    sym->vclassinfo = new ClassInfoDeclaration(sym);
		e = new VarExp(e->loc, sym->vclassinfo);
		e = e->addressOf(sc);
		e->type = t;	// do this so we don't get redundant dereference
	    }
	    else
	    {	/* For class objects, the classinfo reference is the first
		 * entry in the vtbl[]
		 */
		e = new PtrExp(e->loc, e);
		e->type = t->pointerTo();
		if (sym->isInterfaceDeclaration())
		{
		    if (sym->isCOMinterface())
		    {	/* COM interface vtbl[]s are different in that the
			 * first entry is always pointer to QueryInterface().
			 * We can't get a .classinfo for it.
			 */
			error(e->loc, "no .classinfo for COM interface objects");
		    }
		    /* For an interface, the first entry in the vtbl[]
		     * is actually a pointer to an instance of struct Interface.
		     * The first member of Interface is the .classinfo,
		     * so add an extra pointer indirection.
		     */
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
	if (ident == Id::outer && sym->vthis)
	{
	    s = sym->vthis;
	}
	else
	{
	    //return getProperty(e->loc, ident);
	    return Type::dotExp(sc, e, ident);
	}
    }
    s = s->toAlias();
    v = s->isVarDeclaration();
    if (v && v->isConst())
    {	ExpInitializer *ei = v->getExpInitializer();

	if (ei)
	{   e = ei->exp->copy();	// need to copy it if it's a StringExp
	    e = e->semantic(sc);
	    return e;
	}
    }

    if (s->getType())
    {
//	if (e->op == TOKtype)
	    return new TypeExp(e->loc, s->getType());
//	return new DotTypeExp(e->loc, e, s);
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

    TemplateDeclaration *td = s->isTemplateDeclaration();
    if (td)
    {
        e = new DotTemplateExp(e->loc, e, td);
        e->semantic(sc);
	return e;
    }

    TemplateInstance *ti = s->isTemplateInstance();
    if (ti)
    {	if (!ti->semanticdone)
	    ti->semantic(sc);
	s = ti->inst->toAlias();
	if (!s->isTemplateInstance())
	    goto L1;
	Expression *de = new DotExp(e->loc, e, new ScopeExp(e->loc, ti));
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

	if (d->needThis() && (hasThis(sc) || !d->isFuncDeclaration()))
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
		    else if ((!cd || !cd->isBaseOf(thiscd, NULL)) &&
			     !d->isFuncDeclaration())
			e->error("'this' is required, but %s is not a base class of %s", e->type->toChars(), thiscd->toChars());
		}
	    }

	    de = new DotVarExp(e->loc, new ThisExp(e->loc), d);
	    e = de->semantic(sc);
	    return e;
	}
	else if (d->isTupleDeclaration())
	{
	    e = new TupleExp(e->loc, d->isTupleDeclaration());
	    e = e->semantic(sc);
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

int TypeClass::isBaseOf(Type *t, int *poffset)
{
    if (t->ty == Tclass)
    {   ClassDeclaration *cd;

	cd   = ((TypeClass *)t)->sym;
	if (sym->isBaseOf(cd, poffset))
	    return 1;
    }
    return 0;
}

MATCH TypeClass::implicitConvTo(Type *to)
{
    //printf("TypeClass::implicitConvTo('%s')\n", to->toChars());
    if (this == to)
	return MATCHexact;

    ClassDeclaration *cdto = to->isClassHandle();
    if (cdto && cdto->isBaseOf(sym, NULL))
    {	//printf("is base\n");
	return MATCHconvert;
    }

    if (global.params.Dversion == 1)
    {
	// Allow conversion to (void *)
	if (to->ty == Tpointer && to->next->ty == Tvoid)
	    return MATCHconvert;
    }

    return MATCHnomatch;
}

Expression *TypeClass::defaultInit(Loc loc)
{
#if LOGDEFAULTINIT
    printf("TypeClass::defaultInit() '%s'\n", toChars());
#endif
    Expression *e;
    e = new NullExp(loc);
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

int TypeClass::hasPointers()
{
    return TRUE;
}

/***************************** TypeTuple *****************************/

TypeTuple::TypeTuple(Arguments *arguments)
    : Type(Ttuple, NULL)
{
    //printf("TypeTuple(this = %p)\n", this);
    this->arguments = arguments;
#ifdef DEBUG
    if (arguments)
    {
	for (size_t i = 0; i < arguments->dim; i++)
	{
	    Argument *arg = (Argument *)arguments->data[i];
	    assert(arg && arg->type);
	}
    }
#endif
}

/****************
 * Form TypeTuple from the types of the expressions.
 * Assume exps[] is already tuple expanded.
 */

TypeTuple::TypeTuple(Expressions *exps)
    : Type(Ttuple, NULL)
{
    Arguments *arguments = new Arguments;
    if (exps)
    {
	arguments->setDim(exps->dim);
	for (size_t i = 0; i < exps->dim; i++)
	{   Expression *e = (Expression *)exps->data[i];
	    if (e->type->ty == Ttuple)
		e->error("cannot form tuple of tuples");
	    Argument *arg = new Argument(STCin, e->type, NULL, NULL);
	    arguments->data[i] = (void *)arg;
	}
    }
    this->arguments = arguments;
}

Type *TypeTuple::syntaxCopy()
{
    Arguments *args = Argument::arraySyntaxCopy(arguments);
    Type *t = new TypeTuple(args);
    return t;
}

Type *TypeTuple::semantic(Loc loc, Scope *sc)
{
    //printf("TypeTuple::semantic(this = %p)\n", this);
    if (!deco)
	deco = merge()->deco;

    /* Don't return merge(), because a tuple with one type has the
     * same deco as that type.
     */
    return this;
}

int TypeTuple::equals(Object *o)
{   Type *t;

    t = (Type *)o;
    //printf("TypeTuple::equals(%s, %s)\n", toChars(), t->toChars());
    if (this == t)
    {
	return 1;
    }
    if (t->ty == Ttuple)
    {	TypeTuple *tt = (TypeTuple *)t;

	if (arguments->dim == tt->arguments->dim)
	{
	    for (size_t i = 0; i < tt->arguments->dim; i++)
	    {   Argument *arg1 = (Argument *)arguments->data[i];
		Argument *arg2 = (Argument *)tt->arguments->data[i];

		if (!arg1->type->equals(arg2->type))
		    return 0;
	    }
	    return 1;
	}
    }
    return 0;
}

Type *TypeTuple::reliesOnTident()
{
    if (arguments)
    {
	for (size_t i = 0; i < arguments->dim; i++)
	{
	    Argument *arg = (Argument *)arguments->data[i];
	    Type *t = arg->type->reliesOnTident();
	    if (t)
		return t;
	}
    }
    return NULL;
}

void TypeTuple::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    Argument::argsToCBuffer(buf, hgs, arguments, 0);
}

void TypeTuple::toDecoBuffer(OutBuffer *buf)
{
    //printf("TypeTuple::toDecoBuffer() this = %p\n", this);
    OutBuffer buf2;
    Argument::argsToDecoBuffer(&buf2, arguments);
    unsigned len = buf2.offset;
    buf->printf("%c%d%.*s", mangleChar[ty], len, len, (char *)buf2.extractData());
}

Expression *TypeTuple::getProperty(Loc loc, Identifier *ident)
{   Expression *e;

#if LOGDOTEXP
    printf("TypeTuple::getProperty(type = '%s', ident = '%s')\n", toChars(), ident->toChars());
#endif
    if (ident == Id::length)
    {
	e = new IntegerExp(loc, arguments->dim, Type::tsize_t);
    }
    else
    {
	error(loc, "no property '%s' for tuple '%s'", ident->toChars(), toChars());
	e = new IntegerExp(loc, 1, Type::tint32);
    }
    return e;
}

/***************************** TypeSlice *****************************/

/* This is so we can slice a TypeTuple */

TypeSlice::TypeSlice(Type *next, Expression *lwr, Expression *upr)
    : Type(Tslice, next)
{
    //printf("TypeSlice[%s .. %s]\n", lwr->toChars(), upr->toChars());
    this->lwr = lwr;
    this->upr = upr;
}

Type *TypeSlice::syntaxCopy()
{
    Type *t = new TypeSlice(next->syntaxCopy(), lwr->syntaxCopy(), upr->syntaxCopy());
    return t;
}

Type *TypeSlice::semantic(Loc loc, Scope *sc)
{
    //printf("TypeSlice::semantic() %s\n", toChars());
    next = next->semantic(loc, sc);
    //printf("next: %s\n", next->toChars());

    Type *tbn = next->toBasetype();
    if (tbn->ty != Ttuple)
    {	error(loc, "can only slice tuple types, not %s", tbn->toChars());
	return Type::terror;
    }
    TypeTuple *tt = (TypeTuple *)tbn;

    lwr = semanticLength(sc, tbn, lwr);
    lwr = lwr->optimize(WANTvalue);
    uinteger_t i1 = lwr->toUInteger();

    upr = semanticLength(sc, tbn, upr);
    upr = upr->optimize(WANTvalue);
    uinteger_t i2 = upr->toUInteger();

    if (!(i1 <= i2 && i2 <= tt->arguments->dim))
    {	error(loc, "slice [%ju..%ju] is out of range of [0..%u]", i1, i2, tt->arguments->dim);
	return Type::terror;
    }

    Arguments *args = new Arguments;
    args->reserve(i2 - i1);
    for (size_t i = i1; i < i2; i++)
    {	Argument *arg = (Argument *)tt->arguments->data[i];
	args->push(arg);
    }

    return new TypeTuple(args);
}

void TypeSlice::resolve(Loc loc, Scope *sc, Expression **pe, Type **pt, Dsymbol **ps)
{
    next->resolve(loc, sc, pe, pt, ps);
    if (*pe)
    {	// It's really a slice expression
	Expression *e;
	e = new SliceExp(loc, *pe, lwr, upr);
	*pe = e;
    }
    else if (*ps)
    {	Dsymbol *s = *ps;
	TupleDeclaration *td = s->isTupleDeclaration();
	if (td)
	{
	    /* It's a slice of a TupleDeclaration
	     */
	    ScopeDsymbol *sym = new ArrayScopeSymbol(td);
	    sym->parent = sc->scopesym;
	    sc = sc->push(sym);

	    lwr = lwr->semantic(sc);
	    lwr = lwr->optimize(WANTvalue);
	    uinteger_t i1 = lwr->toUInteger();

	    upr = upr->semantic(sc);
	    upr = upr->optimize(WANTvalue);
	    uinteger_t i2 = upr->toUInteger();

	    sc = sc->pop();

	    if (!(i1 <= i2 && i2 <= td->objects->dim))
	    {   error(loc, "slice [%ju..%ju] is out of range of [0..%u]", i1, i2, td->objects->dim);
		goto Ldefault;
	    }

	    if (i1 == 0 && i2 == td->objects->dim)
	    {
		*ps = td;
		return;
	    }

	    /* Create a new TupleDeclaration which
	     * is a slice [i1..i2] out of the old one.
	     */
	    Objects *objects = new Objects;
	    objects->setDim(i2 - i1);
	    for (size_t i = 0; i < objects->dim; i++)
	    {
		objects->data[i] = td->objects->data[(size_t)i1 + i];
	    }

	    TupleDeclaration *tds = new TupleDeclaration(loc, td->ident, objects);
	    *ps = tds;
	}
	else
	    goto Ldefault;
    }
    else
    {
     Ldefault:
	Type::resolve(loc, sc, pe, pt, ps);
    }
}

void TypeSlice::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    if (mod != this->mod)
    {	toCBuffer3(buf, hgs, mod);
	return;
    }
    next->toCBuffer2(buf, hgs, this->mod);

    buf->printf("[%s .. ", lwr->toChars());
    buf->printf("%s]", upr->toChars());
}

/***************************** Argument *****************************/

Argument::Argument(unsigned storageClass, Type *type, Identifier *ident, Expression *defaultArg)
{
    this->type = type;
    this->ident = ident;
    this->storageClass = storageClass;
    this->defaultArg = defaultArg;
}

Argument *Argument::syntaxCopy()
{
    Argument *a = new Argument(storageClass,
		type ? type->syntaxCopy() : NULL,
		ident,
		defaultArg ? defaultArg->syntaxCopy() : NULL);
    return a;
}

Arguments *Argument::arraySyntaxCopy(Arguments *args)
{   Arguments *a = NULL;

    if (args)
    {
	a = new Arguments();
	a->setDim(args->dim);
	for (size_t i = 0; i < a->dim; i++)
	{   Argument *arg = (Argument *)args->data[i];

	    arg = arg->syntaxCopy();
	    a->data[i] = (void *)arg;
	}
    }
    return a;
}

char *Argument::argsTypesToChars(Arguments *args, int varargs)
{   OutBuffer *buf;

    buf = new OutBuffer();

    buf->writeByte('(');
    if (args)
    {	int i;
	OutBuffer argbuf;
	HdrGenState hgs;

	for (i = 0; i < args->dim; i++)
	{   Argument *arg;

	    if (i)
		buf->writeByte(',');
	    arg = (Argument *)args->data[i];
	    argbuf.reset();
	    arg->type->toCBuffer2(&argbuf, &hgs, 0);
	    buf->write(&argbuf);
	}
	if (varargs)
	{
	    if (i && varargs == 1)
		buf->writeByte(',');
	    buf->writestring("...");
	}
    }
    buf->writeByte(')');

    return buf->toChars();
}

void Argument::argsToCBuffer(OutBuffer *buf, HdrGenState *hgs, Arguments *arguments, int varargs)
{
    buf->writeByte('(');
    if (arguments)
    {	int i;
	OutBuffer argbuf;

	for (i = 0; i < arguments->dim; i++)
	{   Argument *arg;

	    if (i)
		buf->writestring(", ");
	    arg = (Argument *)arguments->data[i];
	    if (arg->storageClass & STCout)
		buf->writestring("out ");
	    else if (arg->storageClass & STCref)
		buf->writestring((global.params.Dversion == 1)
			? (char *)"inout " : (char *)"ref ");
	    else if (arg->storageClass & STClazy)
		buf->writestring("lazy ");
	    argbuf.reset();
	    arg->type->toCBuffer(&argbuf, arg->ident, hgs);
	    if (arg->defaultArg)
	    {
		argbuf.writestring(" = ");
		arg->defaultArg->toCBuffer(&argbuf, hgs);
	    }
	    buf->write(&argbuf);
	}
	if (varargs)
	{
	    if (i && varargs == 1)
		buf->writeByte(',');
	    buf->writestring("...");
	}
    }
    buf->writeByte(')');
}


void Argument::argsToDecoBuffer(OutBuffer *buf, Arguments *arguments)
{
    //printf("Argument::argsToDecoBuffer()\n");

    // Write argument types
    if (arguments)
    {
	size_t dim = Argument::dim(arguments);
	for (size_t i = 0; i < dim; i++)
	{
	    Argument *arg = Argument::getNth(arguments, i);
	    arg->toDecoBuffer(buf);
	}
    }
}

/****************************************************
 * Determine if parameter is a lazy array of delegates.
 * If so, return the return type of those delegates.
 * If not, return NULL.
 */

Type *Argument::isLazyArray()
{
//    if (inout == Lazy)
    {
	Type *tb = type->toBasetype();
	if (tb->ty == Tsarray || tb->ty == Tarray)
	{
	    Type *tel = tb->next->toBasetype();
	    if (tel->ty == Tdelegate)
	    {
		TypeDelegate *td = (TypeDelegate *)tel;
		TypeFunction *tf = (TypeFunction *)td->next;

		if (!tf->varargs && Argument::dim(tf->parameters) == 0)
		{
		    return tf->next;	// return type of delegate
		}
	    }
	}
    }
    return NULL;
}

void Argument::toDecoBuffer(OutBuffer *buf)
{
    switch (storageClass & (STCin | STCout | STCref | STClazy))
    {   case 0:
	case STCin:
	    break;
	case STCout:
	    buf->writeByte('J');
	    break;
	case STCref:
	    buf->writeByte('K');
	    break;
	case STClazy:
	    buf->writeByte('L');
	    break;
	default:
#ifdef DEBUG
	    halt();
#endif
	    assert(0);
    }
    type->toDecoBuffer(buf);
}

/***************************************
 * Determine number of arguments, folding in tuples.
 */

size_t Argument::dim(Arguments *args)
{
    size_t n = 0;
    if (args)
    {
	for (size_t i = 0; i < args->dim; i++)
	{   Argument *arg = (Argument *)args->data[i];
	    Type *t = arg->type->toBasetype();

	    if (t->ty == Ttuple)
	    {   TypeTuple *tu = (TypeTuple *)t;
		n += dim(tu->arguments);
	    }
	    else
		n++;
	}
    }
    return n;
}

/***************************************
 * Get nth Argument, folding in tuples.
 * Returns:
 *	Argument*	nth Argument
 *	NULL		not found, *pn gets incremented by the number
 *			of Arguments
 */

Argument *Argument::getNth(Arguments *args, size_t nth, size_t *pn)
{
    if (!args)
	return NULL;

    size_t n = 0;
    for (size_t i = 0; i < args->dim; i++)
    {   Argument *arg = (Argument *)args->data[i];
	Type *t = arg->type->toBasetype();

	if (t->ty == Ttuple)
	{   TypeTuple *tu = (TypeTuple *)t;
	    arg = getNth(tu->arguments, nth - n, &n);
	    if (arg)
		return arg;
	}
	else if (n == nth)
	    return arg;
	else
	    n++;
    }

    if (pn)
	*pn += n;
    return NULL;
}
