
// Compiler implementation of the D programming language
// Copyright (c) 1999-2012 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// http://www.dsource.org/projects/dmd/browser/branches/dmd-1.x/src/mtype.c
// License for redistribution is by either the Artistic License
// in artistic.txt, or the GNU General Public License in gnu.txt.
// See the included readme.txt for details.

#define __C99FEATURES__ 1       // Needed on Solaris for NaN and more
#define __USE_ISOC99 1          // so signbit() gets defined

#if (defined (__SVR4) && defined (__sun))
#include <alloca.h>
#endif

#include <math.h>

#include <stdio.h>
#include <assert.h>
#include <float.h>

#if _MSC_VER
#include <malloc.h>
#include <complex>
#include <limits>
#elif __DMC__
#include <complex.h>
#elif __MINGW32__
#include <malloc.h>
#endif

#include "rmem.h"
#include "port.h"
#include "target.h"

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
#include "module.h"

FuncDeclaration *hasThis(Scope *sc);


#define LOGDOTEXP       0       // log ::dotExp()
#define LOGDEFAULTINIT  0       // log ::defaultInit()

// Allow implicit conversion of T[] to T*
#define IMPLICIT_ARRAY_TO_PTR   global.params.useDeprecated

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
Type *Type::tstring;
Type *Type::basic[TMAX];
unsigned char Type::mangleChar[TMAX];
StringTable Type::stringtable;


Type::Type(TY ty, Type *next)
{
    this->ty = ty;
    this->mod = 0;
    this->next = next;
    this->deco = NULL;
#if DMDV2
    this->cto = NULL;
    this->ito = NULL;
    this->sto = NULL;
    this->scto = NULL;
    this->wto = NULL;
    this->swto = NULL;
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
        (t && deco == t->deco) &&               // deco strings are unique
         deco != NULL)                          // and semantic() has been run
    {
        //printf("deco = '%s', t->deco = '%s'\n", deco, t->deco);
        return 1;
    }
    //if (deco && t && t->deco) printf("deco = '%s', t->deco = '%s'\n", deco, t->deco);
    return 0;
}

char Type::needThisPrefix()
{
    return 'M';         // name mangling prefix for functions needing 'this'
}

void Type::init()
{
    stringtable._init(1543);
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

    // '@' shouldn't appear anywhere in the deco'd names
    mangleChar[Tbit] = '@';
    mangleChar[Tinstance] = '@';
    mangleChar[Terror] = '@';
    mangleChar[Ttypeof] = '@';
    mangleChar[Ttuple] = 'B';
    mangleChar[Tslice] = '@';
    mangleChar[Treturn] = '@';

    for (size_t i = 0; i < TMAX; i++)
    {   if (!mangleChar[i])
            fprintf(stdmsg, "ty = %zd\n", i);
        assert(mangleChar[i]);
    }

    // Set basic types
    static TY basetab[] =
        { Tvoid, Tint8, Tuns8, Tint16, Tuns16, Tint32, Tuns32, Tint64, Tuns64,
          Tfloat32, Tfloat64, Tfloat80,
          Timaginary32, Timaginary64, Timaginary80,
          Tcomplex32, Tcomplex64, Tcomplex80,
          Tbool,
          Tascii, Twchar, Tdchar };

    for (size_t i = 0; i < sizeof(basetab) / sizeof(basetab[0]); i++)
        basic[basetab[i]] = new TypeBasic(basetab[i]);
    basic[Terror] = new TypeError();

    tvoidptr = tvoid->pointerTo();
    tstring = tchar->arrayOf();

    if (global.params.is64bit)
    {
        Tsize_t = Tuns64;
        Tptrdiff_t = Tint64;
    }
    else
    {
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
    return SIZE_INVALID;
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

Type *Type::trySemantic(Loc loc, Scope *sc)
{
    //printf("+trySemantic(%s) %d\n", toChars(), global.errors);
    unsigned errors = global.startGagging();
    Type *t = semantic(loc, sc);
    if (global.endGagging(errors))        // if any errors happened
    {
        t = NULL;
    }
    //printf("-trySemantic(%s) %d\n", toChars(), global.errors);
    return t;
}
Type *Type::pointerTo()
{
    if (ty == Terror)
        return this;
    if (!pto)
    {   Type *t;

        t = new TypePointer(this);
        pto = t->merge();
    }
    return pto;
}

Type *Type::referenceTo()
{
    if (ty == Terror)
        return this;
    if (!rto)
    {   Type *t;

        t = new TypeReference(this);
        rto = t->merge();
    }
    return rto;
}

Type *Type::arrayOf()
{
    if (ty == Terror)
        return this;
    if (!arrayof)
    {   Type *t;

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
    {   buf->writeByte(' ');
        buf->writestring(ident->toChars());
    }
}

void Type::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    if (mod != this->mod)
    {   toCBuffer3(buf, hgs, mod);
        return;
    }
    buf->writestring(toChars());
}

void Type::toCBuffer3(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    if (mod != this->mod)
    {   const char *p;

        switch (this->mod)
        {
            case 0:
                toCBuffer2(buf, hgs, this->mod);
                break;
            case MODconst:
                p = "const(";
                goto L1;
            case MODimmutable:
                p = "invariant(";
            L1: buf->writestring(p);
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
{
    if (ty == Terror) return this;
    //printf("merge(%s)\n", toChars());
    Type *t = this;
    assert(t);
    if (!deco)
    {
        if (next)
            next = next->merge();

        OutBuffer buf;
        toDecoBuffer(&buf);
        StringValue *sv = stringtable.update((char *)buf.data, buf.offset);
        if (sv->ptrvalue)
        {   t = (Type *) sv->ptrvalue;
            assert(t->deco);
            //printf("old value, deco = '%s' %p\n", t->deco, t->deco);
        }
        else
        {
            sv->ptrvalue = this;
            deco = (char *)sv->toDchars();
            //printf("new value, deco = '%s' %p\n", t->deco, t->deco);
        }
    }
    return t;
}

/*************************************
 * This version does a merge even if the deco is already computed.
 * Necessary for types that have a deco, but are not merged.
 */
Type *Type::merge2()
{
    //printf("merge2(%s)\n", toChars());
    Type *t = this;
    assert(t);
    if (!t->deco)
        return t->merge();

    StringValue *sv = stringtable.lookup((char *)t->deco, strlen(t->deco));
    if (sv && sv->ptrvalue)
    {   t = (Type *) sv->ptrvalue;
        assert(t->deco);
    }
    else
        assert(0);
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

int Type::isscope()
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
    for (Type *t = this; t; t = t->next)
    {
        Dsymbol *s = t->toDsymbol(sc);
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

/***************************************
 * Use when we prefer the default initializer to be a literal,
 * rather than a global immutable variable.
 */
Expression *Type::defaultInitLiteral(Loc loc)
{
#if LOGDEFAULTINIT
    printf("Type::defaultInitLiteral() '%s'\n", toChars());
#endif
    return defaultInit(loc);
}

int Type::isZeroInit(Loc loc)
{
    return 0;           // assume not
}

int Type::isBaseOf(Type *t, int *poffset)
{
    return 0;           // assume not
}

/********************************
 * Determine if 'this' can be implicitly converted
 * to type 'to'.
 * Returns:
 *      0       can't convert
 *      1       can convert using implicit conversions
 *      2       this and to are the same type
 */

MATCH Type::implicitConvTo(Type *to)
{
    //printf("Type::implicitConvTo(this=%p, to=%p)\n", this, to);
    //printf("\tthis->next=%p, to->next=%p\n", this->next, to->next);
    if (this == to)
        return MATCHexact;
//    if (to->ty == Tvoid)
//      return 1;
    return MATCHnomatch;
}

Expression *Type::getProperty(Loc loc, Identifier *ident)
{   Expression *e;

#if LOGDOTEXP
    printf("Type::getProperty(type = '%s', ident = '%s')\n", toChars(), ident->toChars());
#endif
    if (ident == Id::__sizeof)
    {
        d_uns64 sz = size(loc);
        if (sz == SIZE_INVALID)
            return new ErrorExp();
        e = new IntegerExp(loc, sz, Type::tsize_t);
    }
    else if (ident == Id::size)
    {
        error(loc, ".size property should be replaced with .sizeof");
        e = new ErrorExp();
    }
    else if (ident == Id::__xalignof)
    {
        e = new IntegerExp(loc, alignsize(), Type::tsize_t);
    }
    else if (ident == Id::typeinfo)
    {
        deprecation(loc, ".typeinfo deprecated, use typeid(type)");
        e = getTypeInfo(NULL);
    }
    else if (ident == Id::init)
    {
        e = defaultInit(loc);
    }
    else if (ident == Id::mangleof)
    {   const char *s;
        if (!deco)
        {   s = toChars();
            error(loc, "forward reference of type %s.mangleof", s);
        }
        else
            s = deco;
        e = new StringExp(loc, (char *)s, strlen(s), 'c');
        Scope sc;
        e = e->semantic(&sc);
    }
    else if (ident == Id::stringof)
    {   char *s = toChars();
        e = new StringExp(loc, s, strlen(s), 'c');
        Scope sc;
        e = e->semantic(&sc);
    }
    else
    {
        Dsymbol *s = NULL;
        if (ty == Tstruct || ty == Tclass || ty == Tenum || ty == Ttypedef)
            s = toDsymbol(NULL);
        if (s)
            s = s->search_correct(ident);
        if (this != Type::terror)
        {
            if (s)
                error(loc, "no property '%s' for type '%s', did you mean '%s'?", ident->toChars(), toChars(), s->toChars());
            else
                error(loc, "no property '%s' for type '%s'", ident->toChars(), toChars());
        }
        e = new ErrorExp();
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
            deprecation(e->loc, ".offset deprecated, use .offsetof");
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
                    e = e->ctfeInterpret();
//                  if (!e->isConst())
//                      error(loc, ".init cannot be evaluated at compile time");
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
        deprecation(e->loc, ".typeinfo deprecated, use typeid(type)");
        e = getTypeInfo(sc);
        return e;
    }
    if (ident == Id::stringof)
    {   char *s = e->toChars();
        e = new StringExp(e->loc, s, strlen(s), 'c');
        Scope sc;
        e = e->semantic(&sc);
        return e;
    }
    return getProperty(e->loc, ident);
}

structalign_t Type::memalign(structalign_t salign)
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

void Type::warning(Loc loc, const char *format, ...)
{
    va_list ap;
    va_start(ap, format);
    ::vwarning(loc, format, ap);
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
    {   buf.writeByte(mangleChar[ty]);
        if (ty == Tarray)
            buf.writeByte(mangleChar[((TypeArray *)this)->next->ty]);
    }
    else
        toDecoBuffer(&buf);
    len = buf.offset;
    name = (char *)alloca(19 + sizeof(len) * 3 + len + 1);
    buf.writeByte(0);
#if TARGET_OSX
    // The LINKc will prepend the _
    sprintf(name, "D%lluTypeInfo_%s6__initZ", (unsigned long long) 9 + len, buf.data);
#else
    sprintf(name, "_D%lluTypeInfo_%s6__initZ", (unsigned long long) 9 + len, buf.data);
#endif
    if (global.params.isWindows && !global.params.is64bit)
        name++;                 // C mangling will add it back in
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
    //printf("Type::resolve() %s, %d\n", toChars(), ty);
    Type *t = semantic(loc, sc);
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

/* ============================= TypeError =========================== */

TypeError::TypeError()
        : Type(Terror, NULL)
{
}

void TypeError::toCBuffer(OutBuffer *buf, Identifier *ident, HdrGenState *hgs)
{
    buf->writestring("_error_");
}

d_uns64 TypeError::size(Loc loc) { return SIZE_INVALID; }
Expression *TypeError::getProperty(Loc loc, Identifier *ident) { return new ErrorExp(); }
Expression *TypeError::dotExp(Scope *sc, Expression *e, Identifier *ident) { return new ErrorExp(); }
Expression *TypeError::defaultInit(Loc loc) { return new ErrorExp(); }
Expression *TypeError::defaultInitLiteral(Loc loc) { return new ErrorExp(); }

/* ============================= TypeBasic =========================== */

TypeBasic::TypeBasic(TY ty)
        : Type(ty, NULL)
{   const char *c;
    const char *d;
    unsigned flags;

#define TFLAGSintegral  1
#define TFLAGSfloating  2
#define TFLAGSunsigned  4
#define TFLAGSreal      8
#define TFLAGSimaginary 0x10
#define TFLAGScomplex   0x20

    flags = 0;
    switch (ty)
    {
        case Tvoid:     d = Token::toChars(TOKvoid);
                        c = "void";
                        break;

        case Tint8:     d = Token::toChars(TOKint8);
                        c = "byte";
                        flags |= TFLAGSintegral;
                        break;

        case Tuns8:     d = Token::toChars(TOKuns8);
                        c = "ubyte";
                        flags |= TFLAGSintegral | TFLAGSunsigned;
                        break;

        case Tint16:    d = Token::toChars(TOKint16);
                        c = "short";
                        flags |= TFLAGSintegral;
                        break;

        case Tuns16:    d = Token::toChars(TOKuns16);
                        c = "ushort";
                        flags |= TFLAGSintegral | TFLAGSunsigned;
                        break;

        case Tint32:    d = Token::toChars(TOKint32);
                        c = "int";
                        flags |= TFLAGSintegral;
                        break;

        case Tuns32:    d = Token::toChars(TOKuns32);
                        c = "uint";
                        flags |= TFLAGSintegral | TFLAGSunsigned;
                        break;

        case Tfloat32:  d = Token::toChars(TOKfloat32);
                        c = "float";
                        flags |= TFLAGSfloating | TFLAGSreal;
                        break;

        case Tint64:    d = Token::toChars(TOKint64);
                        c = "long";
                        flags |= TFLAGSintegral;
                        break;

        case Tuns64:    d = Token::toChars(TOKuns64);
                        c = "ulong";
                        flags |= TFLAGSintegral | TFLAGSunsigned;
                        break;

        case Tfloat64:  d = Token::toChars(TOKfloat64);
                        c = "double";
                        flags |= TFLAGSfloating | TFLAGSreal;
                        break;

        case Tfloat80:  d = Token::toChars(TOKfloat80);
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


        case Tbool:     d = "bool";
                        c = d;
                        flags |= TFLAGSintegral | TFLAGSunsigned;
                        break;

        case Tascii:    d = Token::toChars(TOKchar);
                        c = "char";
                        flags |= TFLAGSintegral | TFLAGSunsigned;
                        break;

        case Twchar:    d = Token::toChars(TOKwchar);
                        c = "wchar";
                        flags |= TFLAGSintegral | TFLAGSunsigned;
                        break;

        case Tdchar:    d = Token::toChars(TOKdchar);
                        c = "dchar";
                        flags |= TFLAGSintegral | TFLAGSunsigned;
                        break;

        default:        assert(0);
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
    return (char *)dstring;
}

void TypeBasic::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    //printf("TypeBasic::toCBuffer2(mod = %d, this->mod = %d)\n", mod, this->mod);
    if (mod != this->mod)
    {   toCBuffer3(buf, hgs, mod);
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
        case Tuns8:     size = 1;       break;
        case Tint16:
        case Tuns16:    size = 2;       break;
        case Tint32:
        case Tuns32:
        case Tfloat32:
        case Timaginary32:
                        size = 4;       break;
        case Tint64:
        case Tuns64:
        case Tfloat64:
        case Timaginary64:
                        size = 8;       break;
        case Tfloat80:
        case Timaginary80:
                        size = Target::realsize; break;
        case Tcomplex32:
                        size = 8;               break;
        case Tcomplex64:
                        size = 16;              break;
        case Tcomplex80:
                        size = Target::realsize * 2; break;

        case Tvoid:
            //size = Type::size();      // error message
            size = 1;
            break;

        case Tbool:     size = 1;               break;
        case Tascii:    size = 1;               break;
        case Twchar:    size = 2;               break;
        case Tdchar:    size = 4;               break;

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
            sz = Target::realalignsize;
            break;

#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
        case Tint64:
        case Tuns64:
            sz = global.params.is64bit ? 8 : 4;
            break;

        case Tfloat64:
        case Timaginary64:
            sz = global.params.is64bit ? 8 : 4;
            break;

        case Tcomplex32:
            sz = 4;
            break;

        case Tcomplex64:
            sz = global.params.is64bit ? 8 : 4;
            break;
#endif

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
            case Tint8:         ivalue = 0x7F;          goto Livalue;
            case Tuns8:         ivalue = 0xFF;          goto Livalue;
            case Tint16:        ivalue = 0x7FFFUL;      goto Livalue;
            case Tuns16:        ivalue = 0xFFFFUL;      goto Livalue;
            case Tint32:        ivalue = 0x7FFFFFFFUL;  goto Livalue;
            case Tuns32:        ivalue = 0xFFFFFFFFUL;  goto Livalue;
            case Tint64:        ivalue = 0x7FFFFFFFFFFFFFFFLL;  goto Livalue;
            case Tuns64:        ivalue = 0xFFFFFFFFFFFFFFFFULL; goto Livalue;
            case Tbool:         ivalue = 1;             goto Livalue;
            case Tchar:         ivalue = 0xFF;          goto Livalue;
            case Twchar:        ivalue = 0xFFFFUL;      goto Livalue;
            case Tdchar:        ivalue = 0x10FFFFUL;    goto Livalue;

            case Tcomplex32:
            case Timaginary32:
            case Tfloat32:      fvalue = FLT_MAX;       goto Lfvalue;
            case Tcomplex64:
            case Timaginary64:
            case Tfloat64:      fvalue = DBL_MAX;       goto Lfvalue;
            case Tcomplex80:
            case Timaginary80:
            case Tfloat80:      fvalue = Port::ldbl_max; goto Lfvalue;
        }
    }
    else if (ident == Id::min)
    {
        switch (ty)
        {
            case Tint8:         ivalue = -128;          goto Livalue;
            case Tuns8:         ivalue = 0;             goto Livalue;
            case Tint16:        ivalue = -32768;        goto Livalue;
            case Tuns16:        ivalue = 0;             goto Livalue;
            case Tint32:        ivalue = -2147483647L - 1;      goto Livalue;
            case Tuns32:        ivalue = 0;                     goto Livalue;
            case Tint64:        ivalue = (-9223372036854775807LL-1LL);  goto Livalue;
            case Tuns64:        ivalue = 0;             goto Livalue;
            case Tbool:         ivalue = 0;             goto Livalue;
            case Tchar:         ivalue = 0;             goto Livalue;
            case Twchar:        ivalue = 0;             goto Livalue;
            case Tdchar:        ivalue = 0;             goto Livalue;

            case Tcomplex32:
            case Timaginary32:
            case Tfloat32:      fvalue = FLT_MIN;       goto Lfvalue;
            case Tcomplex64:
            case Timaginary64:
            case Tfloat64:      fvalue = DBL_MIN;       goto Lfvalue;
            case Tcomplex80:
            case Timaginary80:
            case Tfloat80:      fvalue = LDBL_MIN;      goto Lfvalue;
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
                fvalue = Port::nan;
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
                fvalue = Port::infinity;
                goto Lfvalue;
        }
    }
    else if (ident == Id::dig)
    {
        switch (ty)
        {
            case Tcomplex32:
            case Timaginary32:
            case Tfloat32:      ivalue = FLT_DIG;       goto Lint;
            case Tcomplex64:
            case Timaginary64:
            case Tfloat64:      ivalue = DBL_DIG;       goto Lint;
            case Tcomplex80:
            case Timaginary80:
            case Tfloat80:      ivalue = LDBL_DIG;      goto Lint;
        }
    }
    else if (ident == Id::epsilon)
    {
        switch (ty)
        {
            case Tcomplex32:
            case Timaginary32:
            case Tfloat32:      fvalue = FLT_EPSILON;   goto Lfvalue;
            case Tcomplex64:
            case Timaginary64:
            case Tfloat64:      fvalue = DBL_EPSILON;   goto Lfvalue;
            case Tcomplex80:
            case Timaginary80:
            case Tfloat80:      fvalue = LDBL_EPSILON;  goto Lfvalue;
        }
    }
    else if (ident == Id::mant_dig)
    {
        switch (ty)
        {
            case Tcomplex32:
            case Timaginary32:
            case Tfloat32:      ivalue = FLT_MANT_DIG;  goto Lint;
            case Tcomplex64:
            case Timaginary64:
            case Tfloat64:      ivalue = DBL_MANT_DIG;  goto Lint;
            case Tcomplex80:
            case Timaginary80:
            case Tfloat80:      ivalue = LDBL_MANT_DIG; goto Lint;
        }
    }
    else if (ident == Id::max_10_exp)
    {
        switch (ty)
        {
            case Tcomplex32:
            case Timaginary32:
            case Tfloat32:      ivalue = FLT_MAX_10_EXP;        goto Lint;
            case Tcomplex64:
            case Timaginary64:
            case Tfloat64:      ivalue = DBL_MAX_10_EXP;        goto Lint;
            case Tcomplex80:
            case Timaginary80:
            case Tfloat80:      ivalue = LDBL_MAX_10_EXP;       goto Lint;
        }
    }
    else if (ident == Id::max_exp)
    {
        switch (ty)
        {
            case Tcomplex32:
            case Timaginary32:
            case Tfloat32:      ivalue = FLT_MAX_EXP;   goto Lint;
            case Tcomplex64:
            case Timaginary64:
            case Tfloat64:      ivalue = DBL_MAX_EXP;   goto Lint;
            case Tcomplex80:
            case Timaginary80:
            case Tfloat80:      ivalue = LDBL_MAX_EXP;  goto Lint;
        }
    }
    else if (ident == Id::min_10_exp)
    {
        switch (ty)
        {
            case Tcomplex32:
            case Timaginary32:
            case Tfloat32:      ivalue = FLT_MIN_10_EXP;        goto Lint;
            case Tcomplex64:
            case Timaginary64:
            case Tfloat64:      ivalue = DBL_MIN_10_EXP;        goto Lint;
            case Tcomplex80:
            case Timaginary80:
            case Tfloat80:      ivalue = LDBL_MIN_10_EXP;       goto Lint;
        }
    }
    else if (ident == Id::min_exp)
    {
        switch (ty)
        {
            case Tcomplex32:
            case Timaginary32:
            case Tfloat32:      ivalue = FLT_MIN_EXP;   goto Lint;
            case Tcomplex64:
            case Timaginary64:
            case Tfloat64:      ivalue = DBL_MIN_EXP;   goto Lint;
            case Tcomplex80:
            case Timaginary80:
            case Tfloat80:      ivalue = LDBL_MIN_EXP;  goto Lint;
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
        //for (size_t i = 0; i < 20; i++)
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
            case Tcomplex32:    t = tfloat32;           goto L1;
            case Tcomplex64:    t = tfloat64;           goto L1;
            case Tcomplex80:    t = tfloat80;           goto L1;
            L1:
                e = e->castTo(sc, t);
                break;

            case Tfloat32:
            case Tfloat64:
            case Tfloat80:
                break;

            case Timaginary32:  t = tfloat32;           goto L2;
            case Timaginary64:  t = tfloat64;           goto L2;
            case Timaginary80:  t = tfloat80;           goto L2;
            L2:
                e = new RealExp(e->loc, 0.0, t);
                break;

            default:
                return Type::getProperty(e->loc, ident);
        }
    }
    else if (ident == Id::im)
    {   Type *t2;

        switch (ty)
        {
            case Tcomplex32:    t = timaginary32;       t2 = tfloat32;  goto L3;
            case Tcomplex64:    t = timaginary64;       t2 = tfloat64;  goto L3;
            case Tcomplex80:    t = timaginary80;       t2 = tfloat80;  goto L3;
            L3:
                e = e->castTo(sc, t);
                e->type = t2;
                break;

            case Timaginary32:  t = tfloat32;   goto L4;
            case Timaginary64:  t = tfloat64;   goto L4;
            case Timaginary80:  t = tfloat80;   goto L4;
            L4:
                e->type = t;
                break;

            case Tfloat32:
            case Tfloat64:
            case Tfloat80:
                e = new RealExp(e->loc, 0.0, this);
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
{   dinteger_t value = 0;

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

        case Tvoid:
            error(loc, "void does not have a default initializer");
            return new ErrorExp();
    }
    return new IntegerExp(loc, value, this);
}

int TypeBasic::isZeroInit(Loc loc)
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
            return 0;           // no
        default:
            return 1;           // yes
    }
}

int TypeBasic::isbit()
{
    return 0;
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

#if DMDV2
    if (ty == to->ty)
    {
        return (mod == to->mod) ? MATCHexact : MATCHconst;
    }
#endif

    if (ty == Tvoid || to->ty == Tvoid)
        return MATCHnomatch;
    if (to->ty == Tbool)
        return MATCHnomatch;
    if (!to->isTypeBasic())
        return MATCHnomatch;

    TypeBasic *tob = (TypeBasic *)to;
    if (flags & TFLAGSintegral)
    {
        // Disallow implicit conversion of integers to imaginary or complex
        if (tob->flags & (TFLAGSimaginary | TFLAGScomplex))
            return MATCHnomatch;

#if DMDV2
        // If converting from integral to integral
        if (1 && tob->flags & TFLAGSintegral)
        {   d_uns64 sz = size(0);
            d_uns64 tosz = tob->size(0);

            /* Can't convert to smaller size
             */
            if (sz > tosz)
                return MATCHnomatch;

            /* Can't change sign if same size
             */
            /*if (sz == tosz && (flags ^ tob->flags) & TFLAGSunsigned)
                return MATCHnomatch;*/
        }
#endif
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
    Type *n = this->next->toBasetype();         // uncover any typedef's

#if LOGDOTEXP
    printf("TypeArray::dotExp(e = '%s', ident = '%s')\n", e->toChars(), ident->toChars());
#endif
    if (ident == Id::reverse && (n->ty == Tchar || n->ty == Twchar))
    {
        Expression *ec;
        FuncDeclaration *fd;
        Expressions *arguments;
        const char *nm;
        static const char *name[2] = { "_adReverseChar", "_adReverseWchar" };

        nm = name[n->ty == Twchar];
        fd = FuncDeclaration::genCfunc(Type::tindex, nm);
        ec = new VarExp(0, fd);
        e = e->castTo(sc, n->arrayOf());        // convert to dynamic array
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
        const char *nm;
        static const char *name[2] = { "_adSortChar", "_adSortWchar" };

        nm = name[n->ty == Twchar];
        fd = FuncDeclaration::genCfunc(Type::tindex, nm);
        ec = new VarExp(0, fd);
        e = e->castTo(sc, n->arrayOf());        // convert to dynamic array
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
        e = e->castTo(sc, n->arrayOf());        // convert to dynamic array
        arguments = new Expressions();
        if (dup)
            arguments->push(getTypeInfo(sc));
        arguments->push(e);
        if (!dup)
            arguments->push(new IntegerExp(0, size, Type::tsize_t));
        e = new CallExp(e->loc, ec, arguments);
        e->type = next->arrayOf();
    }
    else if (ident == Id::sort)
    {
        Expression *ec;
        FuncDeclaration *fd;
        Expressions *arguments;

        fd = FuncDeclaration::genCfunc(tint32->arrayOf(),
                (char*)"_adSort");
        ec = new VarExp(0, fd);
        e = e->castTo(sc, n->arrayOf());        // convert to dynamic array
        arguments = new Expressions();
        arguments->push(e);
        arguments->push(n->ty == Tsarray
                    ? n->getTypeInfo(sc)    // don't convert to dynamic array
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
{   dinteger_t sz;

    if (!dim)
        return Type::size(loc);
    sz = dim->toInteger();
    {   dinteger_t n, n2;

        n = next->size();
        n2 = n * sz;
        if (n && (n2 / n) != sz)
            goto Loverflow;
        sz = n2;
    }
    return sz;

Loverflow:
    error(loc, "index %jd overflow for static array", sz);
    return SIZE_INVALID;
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
    {   ScopeDsymbol *sym = new ArrayScopeSymbol((TypeTuple *)t);
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
    {   // It's really an index expression
        Expression *e;
        e = new IndexExp(loc, *pe, dim);
        *pe = e;
    }
    else if (*ps)
    {   Dsymbol *s = *ps;
        TupleDeclaration *td = s->isTupleDeclaration();
        if (td)
        {
            ScopeDsymbol *sym = new ArrayScopeSymbol(td);
            sym->parent = sc->scopesym;
            sc = sc->push(sym);

            dim = dim->semantic(sc);
            dim = dim->ctfeInterpret();
            uinteger_t d = dim->toUInteger();

            sc = sc->pop();

            if (d >= td->objects->dim)
            {   error(loc, "tuple index %ju exceeds length %u", d, td->objects->dim);
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
            if (o->dyncast() == DYNCAST_TYPE)
            {
                *ps = NULL;
                *pt = (Type *)o;
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
    {   TupleDeclaration *sd = s->isTupleDeclaration();

        dim = semanticLength(sc, sd, dim);
        dim = dim->ctfeInterpret();
        uinteger_t d = dim->toUInteger();

        if (d >= sd->objects->dim)
        {   error(loc, "tuple index %ju exceeds %u", d, sd->objects->dim);
            return Type::terror;
        }
        Object *o = (*sd->objects)[(size_t)d];
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
    {   dinteger_t n, n2;

        int errors = global.errors;
        dim = semanticLength(sc, tbn, dim);
        if (errors != global.errors)
            goto Lerror;

        dim = dim->ctfeInterpret();
        if (sc && sc->parameterSpecialization && dim->op == TOKvar &&
            ((VarExp *)dim)->var->storage_class & STCtemplateparameter)
        {
            /* It could be a template parameter N which has no value yet:
             *   template Foo(T : T[N], size_t N);
             */
            return this;
        }
        dinteger_t d1 = dim->toInteger();
        dim = dim->implicitCastTo(sc, tsize_t);
        dim = dim->optimize(WANTvalue);
        dinteger_t d2 = dim->toInteger();

        if (dim->op == TOKerror)
            goto Lerror;

        if (d1 != d2)
            goto Loverflow;

        if (tbn->isintegral() ||
                 tbn->isfloating() ||
                 tbn->ty == Tpointer ||
                 tbn->ty == Tarray ||
                 tbn->ty == Tsarray ||
                 tbn->ty == Taarray ||
                 (tbn->ty == Tstruct && (((TypeStruct *)tbn)->sym->sizeok == SIZEOKdone)) ||
                 tbn->ty == Tclass)
        {
            /* Only do this for types that don't need to have semantic()
             * run on them for the size, since they may be forward referenced.
             */
            n = tbn->size(loc);
            n2 = n * d2;
            if ((int)n2 < 0)
                goto Loverflow;
            if (n2 >= 0x1000000)        // put a 'reasonable' limit on it
                goto Loverflow;
            if (n && n2 / n != d2)
            {
              Loverflow:
                error(loc, "index %jd overflow for static array", d1);
                goto Lerror;
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
            {   error(loc, "tuple index %ju exceeds %u", d, tt->arguments->dim);
                goto Lerror;
            }
            Parameter *arg = tt->arguments->tdata()[(size_t)d];
            return arg->type;
        }
        case Tfunction:
        case Tnone:
            error(loc, "can't have array of %s", tbn->toChars());
            goto Lerror;
        default:
            break;
    }
    if (tbn->isscope())
    {   error(loc, "cannot have array of auto %s", tbn->toChars());
        goto Lerror;
    }
    return merge();

Lerror:
    return Type::terror;
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
    {   toCBuffer3(buf, hgs, mod);
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

structalign_t TypeSArray::memalign(structalign_t salign)
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
    {   int offset = 0;

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

int TypeSArray::isZeroInit(Loc loc)
{
    return next->isZeroInit(loc);
}

Expression *TypeSArray::defaultInitLiteral(Loc loc)
{
#if LOGDEFAULTINIT
    printf("TypeSArray::defaultInitLiteral() '%s'\n", toChars());
#endif
    size_t d = dim->toInteger();
    Expression *elementinit = next->defaultInitLiteral(loc);
    Expressions *elements = new Expressions();
    elements->setDim(d);
    for (size_t i = 0; i < d; i++)
        elements->data[i] = elementinit;
    ArrayLiteralExp *ae = new ArrayLiteralExp(0, elements);
    ae->type = this;
    return ae;
}

Expression *TypeSArray::toExpression()
{
    Expression *e = next->toExpression();
    if (e)
    {   Expressions *arguments = new Expressions();
        arguments->push(dim);
        e = new ArrayExp(dim->loc, e, arguments);
    }
    return e;
}

int TypeSArray::hasPointers()
{
    /* Don't want to do this, because:
     *    struct S { T* array[0]; }
     * may be a variable length struct.
     */
    //if (dim->toInteger() == 0)
        //return FALSE;

    if (next->ty == Tvoid)
        // Arrays of void contain arbitrary data, which may include pointers
        return TRUE;
    else
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
    return Target::ptrsize * 2;
}

unsigned TypeDArray::alignsize()
{
    // A DArray consists of two ptr-sized values, so align it on pointer size
    // boundary
    return Target::ptrsize;
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
        case Terror:
            return Type::terror;
        default:
            break;
    }
    if (tn->isscope())
        error(loc, "cannot have array of scope %s", tn->toChars());
    if (next != tn)
        //deco = NULL;                  // redo
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
    {   toCBuffer3(buf, hgs, mod);
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
        if (e->op == TOKnull)
            return new IntegerExp(e->loc, 0, Type::tindex);
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
    {   int offset = 0;

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
    return new NullExp(loc, this);
}

int TypeDArray::isZeroInit(Loc loc)
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
    return Target::ptrsize /* * 2*/;
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
        case Tbool:
        case Tfunction:
        case Tvoid:
        case Tnone:
        case Ttuple:
            error(loc, "can't have associative array key of %s", key->toChars());
            break;
    }
    next = next->semantic(loc,sc);
    switch (next->toBasetype()->ty)
    {
        case Tfunction:
        case Tvoid:
        case Tnone:
            error(loc, "can't have associative array of %s", next->toChars());
            break;
    }
    if (next->isscope())
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
        if (global.params.is64bit)
            keysize = (keysize + 15) & ~15;
        else
            keysize = (keysize + Target::ptrsize - 1) & ~(Target::ptrsize - 1);
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
    {   toCBuffer3(buf, hgs, mod);
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
    return new NullExp(loc, this);
}

int TypeAArray::isZeroInit(Loc loc)
{
    return TRUE;
}

int TypeAArray::checkBoolean()
{
    return TRUE;
}

Expression *TypeAArray::toExpression()
{
    Expression *e = next->toExpression();
    if (e)
    {
        Expression *ei = index->toExpression();
        if (ei)
        {
            Expressions *arguments = new Expressions();
            arguments->push(ei);
            return new ArrayExp(0, e, arguments);
        }
    }
    return NULL;
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
    if (deco)
        return this;

    //printf("TypePointer::semantic()\n");
    Type *n = next->semantic(loc, sc);
    switch (n->toBasetype()->ty)
    {
        case Ttuple:
            error(loc, "can't have pointer to %s", n->toChars());
       case Terror:
            return Type::terror;
        default:
            break;
    }
    if (n != next)
        deco = NULL;
    next = n;
    return merge();
}


d_uns64 TypePointer::size(Loc loc)
{
    return Target::ptrsize;
}

void TypePointer::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    //printf("TypePointer::toCBuffer2() next = %d\n", next->ty);
    if (mod != this->mod)
    {   toCBuffer3(buf, hgs, mod);
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
//      return MATCHconvert;
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
    return new NullExp(loc, this);
}

int TypePointer::isZeroInit(Loc loc)
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
    return Target::ptrsize;
}

void TypeReference::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    if (mod != this->mod)
    {   toCBuffer3(buf, hgs, mod);
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
    return new NullExp(loc, this);
}

int TypeReference::isZeroInit(Loc loc)
{
    return 1;
}


/***************************** TypeFunction *****************************/

TypeFunction::TypeFunction(Parameters *parameters, Type *treturn, int varargs, enum LINK linkage)
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
    Parameters *params = Parameter::arraySyntaxCopy(parameters);
    Type *t = new TypeFunction(params, treturn, varargs, linkage);
    return t;
}

/*******************************
 * Returns:
 *      0       types are distinct
 *      1       this is covariant with t
 *      2       arguments match as far as overloading goes,
 *              but types are not covariant
 *      3       cannot determine covariance because of forward references
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
        size_t dim = Parameter::dim(t1->parameters);
        if (dim != Parameter::dim(t2->parameters))
            goto Ldistinct;

        for (size_t i = 0; i < dim; i++)
        {   Parameter *arg1 = Parameter::getNth(t1->parameters, i);
            Parameter *arg2 = Parameter::getNth(t2->parameters, i);

            if (!arg1->type->equals(arg2->type))
                goto Ldistinct;
            if (arg1->storageClass != arg2->storageClass)
                inoutmismatch = 1;
        }
    }
    else if (t1->parameters != t2->parameters)
    {
        size_t dim1 = !t1->parameters ? 0 : t1->parameters->dim;
        size_t dim2 = !t2->parameters ? 0 : t2->parameters->dim;
        if (dim1 || dim2)
            goto Ldistinct;
    }

    // The argument lists match
    if (inoutmismatch)
        goto Lnotcovariant;
    if (t1->linkage != t2->linkage)
        goto Lnotcovariant;

            // Return types
    Type *t1n = t1->next;
    Type *t2n = t2->next;

    if (!t1n || !t2n)           // happens with return type inference
        goto Lnotcovariant;

    if (t1n->equals(t2n))
        goto Lcovariant;
    if (t1n->ty == Tclass && t2n->ty == Tclass)
    {
        ClassDeclaration *cd = ((TypeClass *)t1n)->sym;
        ClassDeclaration *cd2 = ((TypeClass *)t2n)->sym;
        if (cd == cd2)
            goto Lcovariant;

        // If t1n is forward referenced:
#if 0
        if (!cd->baseClass && cd->baseclasses->dim && !cd->isInterfaceDeclaration())
#else
        if (!cd->isBaseInfoComplete())
#endif
        {
            return 3;   // forward references
        }
    }
    if (t1n->ty == t2n->ty && t1n->implicitConvTo(t2n))
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
    {   inuse = 2;              // flag error to caller
        return;
    }
    inuse++;
    switch (linkage)
    {
        case LINKd:             mc = 'F';       break;
        case LINKc:             mc = 'U';       break;
        case LINKwindows:       mc = 'W';       break;
        case LINKpascal:        mc = 'V';       break;
        case LINKcpp:           mc = 'R';       break;
        default:
            assert(0);
    }
    buf->writeByte(mc);
    // Write argument types
    Parameter::argsToDecoBuffer(buf, parameters);
    //if (buf->data[buf->offset - 1] == '@') halt();
    buf->writeByte('Z' - varargs);      // mark end of arg list
    if (next != NULL)
        next->toDecoBuffer(buf);
    inuse--;
}

void TypeFunction::toCBuffer(OutBuffer *buf, Identifier *ident, HdrGenState *hgs)
{
    toCBufferWithAttributes(buf, ident, hgs, this, NULL);
}

void TypeFunction::toCBufferWithAttributes(OutBuffer *buf, Identifier *ident, HdrGenState* hgs, TypeFunction *attrs, TemplateDeclaration *td)
{
    const char *p = NULL;

    if (inuse)
    {   inuse = 2;              // flag error to caller
        return;
    }
    inuse++;
    if (hgs->ddoc != 1)
    {
        switch (linkage)
        {
            case LINKd:         p = NULL;       break;
            case LINKc:         p = "C ";       break;
            case LINKwindows:   p = "Windows "; break;
            case LINKpascal:    p = "Pascal ";  break;
            case LINKcpp:       p = "C++ ";     break;
            default:
                assert(0);
        }
        if (!hgs->hdrgen && p)
        {
            buf->writestring("extern (");
            buf->writestring(p);
            buf->writestring(") ");
        }
    }
    if (next && (!ident || ident->toHChars2() == ident->toChars()))
    {    next->toCBuffer2(buf, hgs, 0);
    }

    if (ident)
    {   buf->writeByte(' ');
        buf->writestring(ident->toHChars2());
    }
    if (td)
    {   buf->writeByte('(');
        for (size_t i = 0; i < td->origParameters->dim; i++)
        {
            TemplateParameter *tp = td->origParameters->tdata()[i];
            if (i)
                buf->writestring(", ");
            tp->toCBuffer(buf, hgs);
        }
        buf->writeByte(')');
    }
    Parameter::argsToCBuffer(buf, hgs, parameters, varargs);
    inuse--;
}

// kind is inserted before the argument list and will usually be "function" or "delegate".
void functionToCBuffer2(TypeFunction *t, OutBuffer *buf, HdrGenState *hgs, int mod, const char *kind)
{
    if (hgs->ddoc != 1)
    {
        const char *p = NULL;
        switch (t->linkage)
        {
            case LINKd:         p = NULL;      break;
            case LINKc:         p = "C";       break;
            case LINKwindows:   p = "Windows"; break;
            case LINKpascal:    p = "Pascal";  break;
            case LINKcpp:       p = "C++";     break;
            default:
                assert(0);
        }
        if (!hgs->hdrgen && p)
        {
            buf->writestring("extern (");
            buf->writestring(p);
            buf->writestring(") ");
        }
    }
    if (t->next)
    {
        t->next->toCBuffer2(buf, hgs, 0);
        buf->writeByte(' ');
    }
    buf->writestring(kind);
    Parameter::argsToCBuffer(buf, hgs, t->parameters, t->varargs);
}

void TypeFunction::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    //printf("TypeFunction::toCBuffer2() this = %p, ref = %d\n", this, isref);
    if (inuse)
    {   inuse = 2;              // flag error to caller
        return;
    }
    inuse++;

    functionToCBuffer2(this, buf, hgs, mod, "function");

    inuse--;
}

Type *TypeFunction::semantic(Loc loc, Scope *sc)
{
    if (deco)                   // if semantic() already run
    {
        //printf("already done\n");
        return this;
    }
    //printf("TypeFunction::semantic() this = %p\n", this);
    //printf("TypeFunction::semantic() %s, sc->stc = %x\n", toChars(), sc->stc);

    /* Copy in order to not mess up original.
     * This can produce redundant copies if inferring return type,
     * as semantic() will get called again on this.
     */
    TypeFunction *tf = (TypeFunction *)mem.malloc(sizeof(TypeFunction));
    memcpy(tf, this, sizeof(TypeFunction));
    if (parameters)
    {   tf->parameters = (Parameters *)parameters->copy();
        for (size_t i = 0; i < parameters->dim; i++)
        {   Parameter *arg = (*parameters)[i];
            Parameter *cpy = (Parameter *)mem.malloc(sizeof(Parameter));
            memcpy((void*)cpy, (void*)arg, sizeof(Parameter));
            (*tf->parameters)[i] = cpy;
        }
    }

    tf->linkage = sc->linkage;
    if (tf->next)
    {
        tf->next = tf->next->semantic(loc,sc);
#if !SARRAYVALUE
        if (tf->next->toBasetype()->ty == Tsarray)
        {   error(loc, "functions cannot return static array %s", tf->next->toChars());
            tf->next = Type::terror;
        }
#endif
        if (tf->next->toBasetype()->ty == Tfunction)
        {   error(loc, "functions cannot return a function");
            tf->next = Type::terror;
        }
        if (tf->next->toBasetype()->ty == Ttuple)
        {   error(loc, "functions cannot return a tuple");
            tf->next = Type::terror;
        }
        if (tf->next->isscope() && !(sc->flags & SCOPEctor))
            error(loc, "functions cannot return scope %s", tf->next->toChars());
    }

    if (tf->parameters)
    {
        /* Create a scope for evaluating the default arguments for the parameters
         */
        Scope *argsc = sc->push();
        argsc->stc = 0;                 // don't inherit storage class
        argsc->protection = PROTpublic;
        argsc->func = NULL;

        size_t dim = Parameter::dim(tf->parameters);
        for (size_t i = 0; i < dim; i++)
        {   Parameter *fparam = Parameter::getNth(tf->parameters, i);

            tf->inuse++;
            fparam->type = fparam->type->semantic(loc, argsc);
            if (tf->inuse == 1) tf->inuse--;

            Type *t = fparam->type->toBasetype();

            bool d2_compatibility_ref_cleared = false;

            if (fparam->storageClass & (STCout | STCref | STClazy))
            {
                if (t->ty == Tsarray)
                {
                    if (tf->linkage != LINKc)
                    {
                        error(loc, "cannot have out or ref parameter of type %s", t->toChars());
                    }
                    else
                    {
                        // ignore ref storage class for extern(C) static arrays
                        // to have a D1<->D2 compatible syntax for those that
                        // does not lose type safety
                        // see https://issues.dlang.org/show_bug.cgi?id=8887
                        fparam->storageClass &= ~STCref;
                        d2_compatibility_ref_cleared = true;
                    }
                }
            }
            if (!(fparam->storageClass & STClazy) && t->ty == Tvoid)
                error(loc, "cannot have parameter of type %s", fparam->type->toChars());

            if (fparam->defaultArg)
            {   Expression *e = fparam->defaultArg;
                e = e->semantic(argsc);
                e = resolveProperties(argsc, e);
                if (e->op == TOKfunction)               // see Bugzilla 4820
                {   FuncExp *fe = (FuncExp *)e;
                    if (fe->fd)
                    {   // Replace function literal with a function symbol,
                        // since default arg expression must be copied when used
                        // and copying the literal itself is wrong.
                        e = new VarExp(e->loc, fe->fd);
                        e = new AddrExp(e->loc, e);
                        e = e->semantic(argsc);
                    }
                }
                e = e->implicitCastTo(argsc, fparam->type);
                fparam->defaultArg = e;
            }

            /* If fparam after semantic() turns out to be a tuple, the number of parameters may
             * change.
             */
            if (t->ty == Ttuple)
            {
                // Propagate storage class from tuple parameters to their element-parameters.
                TypeTuple *tt = (TypeTuple *)t;
                if (tt->arguments)
                {
                    size_t tdim = tt->arguments->dim;
                    for (size_t j = 0; j < tdim; j++)
                    {   Parameter *narg = (Parameter *)tt->arguments->data[j];
                        narg->storageClass = fparam->storageClass;
                    }
                }

                /* Reset number of parameters, and back up one to do this arg again,
                 * now that it is the first element of a tuple
                 */
                dim = Parameter::dim(tf->parameters);
                i--;
                continue;
            }

            if ((global.params.enabledV2hints & V2MODEstaticarr) && sc->module && sc->module->isRoot() &&
                t->ty == Tsarray)
            {
                // ignore ref storage class for extern(C) static arrays
                // to have a D1<->D2 compatible syntax for those that
                // does not lose type safety
                // see https://issues.dlang.org/show_bug.cgi?id=8887

                if ((tf->linkage != LINKc) || !d2_compatibility_ref_cleared)
                {
                    warning(loc, "D2 passes static arrays by value, "
                            "use %s[] instead [-v2=%s]", t->next->toChars(),
                            V2MODE_name(V2MODEstaticarr));
                }
            }
        }
        argsc->pop();
    }
    if (tf->next)
        tf->deco = tf->merge()->deco;

    if (tf->inuse)
    {   error(loc, "recursive type");
        tf->inuse = 0;
        return terror;
    }

    if (tf->varargs == 1 && tf->linkage != LINKd && Parameter::dim(tf->parameters) == 0)
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
 *      MATCHxxxx
 */

int TypeFunction::callMatch(Expressions *args)
{
    //printf("TypeFunction::callMatch()\n");
    int match = MATCHexact;             // assume exact match

    size_t nparams = Parameter::dim(parameters);
    size_t nargs = args ? args->dim : 0;
    if (nparams == nargs)
        ;
    else if (nargs > nparams)
    {
        if (varargs == 0)
            goto Nomatch;               // too many args; no match
        match = MATCHconvert;           // match ... with a "conversion" match level
    }

    for (size_t u = 0; u < nparams; u++)
    {   int m;
        Expression *arg;

        // BUG: what about out and ref?

        Parameter *p = Parameter::getNth(parameters, u);
        assert(p);
        if (u >= nargs)
        {
            if (p->defaultArg)
                continue;
            if (varargs == 2 && u + 1 == nparams)
                goto L1;
            goto Nomatch;               // not enough arguments
        }
        arg = (*args)[u];
        assert(arg);
        if (p->storageClass & STClazy && p->type->ty == Tvoid && arg->type->ty != Tvoid)
            m = MATCHconvert;
        else
            m = arg->implicitConvTo(p->type);
        /* prefer matching the element type rather than the array
         * type when more arguments are present with T[]...
         */
        if (varargs == 2 && u + 1 == nparams && nargs > nparams)
            goto L1;

        //printf("\tm = %d\n", m);
        if (m == MATCHnomatch)                  // if no match
        {
          L1:
            if (varargs == 2 && u + 1 == nparams)       // if last varargs param
            {   Type *tb = p->type->toBasetype();
                TypeSArray *tsa;
                dinteger_t sz;

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
                            arg = (*args)[u];
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
            match = m;                  // pick worst match
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
        {   Parameter *arg = (Parameter *)parameters->data[i];
            Type *t = arg->type->reliesOnTident();
            if (t)
                return t;
        }
    }
    return next->reliesOnTident();
}

Expression *TypeFunction::defaultInit(Loc loc)
{
    error(loc, "function does not have a default initializer");
    return new ErrorExp();
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
    if (deco)                   // if semantic() already run
    {
        //printf("already done\n");
        return this;
    }
    next = next->semantic(loc,sc);
    return merge();
}

d_uns64 TypeDelegate::size(Loc loc)
{
    return Target::ptrsize * 2;
}

unsigned TypeDelegate::alignsize()
{
#if DMDV1
    // See Bugzilla 942 for discussion
    if (!global.params.is64bit)
        return Target::ptrsize * 2;
#endif
    return Target::ptrsize;
}

void TypeDelegate::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    if (mod != this->mod)
    {   toCBuffer3(buf, hgs, mod);
        return;
    }

    functionToCBuffer2((TypeFunction *)next, buf, hgs, mod, "delegate");
}

Expression *TypeDelegate::defaultInit(Loc loc)
{
#if LOGDEFAULTINIT
    printf("TypeDelegate::defaultInit() '%s'\n", toChars());
#endif
    return new NullExp(loc, this);
}

int TypeDelegate::isZeroInit(Loc loc)
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
        if (!e->isLvalue())
        {
            Identifier *idtmp = Lexer::uniqueId("__dgtmp");
            VarDeclaration *tmp = new VarDeclaration(e->loc, this, idtmp, new ExpInitializer(0, e));
            tmp->storage_class |= STCctfe;
            e = new DeclarationExp(e->loc, tmp);
            e = new CommaExp(e->loc, e, new VarExp(e->loc, tmp));
            e = e->semantic(sc);
        }
        e = e->addressOf(sc);
        e->type = tvoidptr;
        e = new AddExp(e->loc, e, new IntegerExp(Target::ptrsize));
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
    for (size_t i = 0; i < idents.dim; i++)
    {
        Object *id = t->idents[i];
        if (id->dyncast() == DYNCAST_DSYMBOL)
        {
            TemplateInstance *ti = (TemplateInstance *)id;

            ti = (TemplateInstance *)ti->syntaxCopy(NULL);
            id = ti;
        }
        idents[i] = id;
    }
}


void TypeQualified::addIdent(Identifier *ident)
{
    idents.push(ident);
}

void TypeQualified::addInst(TemplateInstance *inst)
{
    idents.push(inst);
}

void TypeQualified::toCBuffer2Helper(OutBuffer *buf, HdrGenState *hgs)
{
    for (size_t i = 0; i < idents.dim; i++)
    {   Object *id = idents[i];

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
    return SIZE_INVALID;
}

/*************************************
 * Takes an array of Identifiers and figures out if
 * it represents a Type or an Expression.
 * Output:
 *      if expression, *pe is set
 *      if type, *pt is set
 */

void TypeQualified::resolveHelper(Loc loc, Scope *sc,
        Dsymbol *s, Dsymbol *scopesym,
        Expression **pe, Type **pt, Dsymbol **ps)
{
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
        s->checkDeprecated(loc, sc);            // check for deprecated aliases
        s = s->toAlias();
        //printf("\t2: s = '%s' %p, kind = '%s'\n",s->toChars(), s, s->kind());
        for (size_t i = 0; i < idents.dim; i++)
        {
            Object *id = idents[i];
            Dsymbol *sm = s->searchX(loc, sc, id);
            //printf("\t3: s = '%s' %p, kind = '%s'\n",s->toChars(), s, s->kind());
            //printf("getType = '%s'\n", s->getType()->toChars());
            if (!sm)
            {
                v = s->isVarDeclaration();
                if (v && id == Id::length)
                {
                    if (v->isConst() && v->getExpInitializer())
                    {   e = v->getExpInitializer()->exp;
                    }
                    else
                        e = new VarExp(loc, v);
                    t = e->type;
                    if (!t)
                        goto Lerror;
                    goto L3;
                }
                else if (v && (id == Id::stringof || id == Id::offsetof))
                {
                    e = new DsymbolExp(loc, s);
                    do
                    {
                        id = idents[i];
                        e = new DotIdExp(loc, e, (Identifier *)id);
                    } while (++i < idents.dim);
                    e = e->semantic(sc);
                    *pe = e;
                    return;
                }

                t = s->getType();
                if (!t && s->isDeclaration())
                {   t = s->isDeclaration()->type;
                    if (!t && s->isTupleDeclaration())
                    {
                        e = new TupleExp(loc, s->isTupleDeclaration());
                        e = e->semantic(sc);
                        t = e->type;
                    }
                }
                if (t)
                {
                    sm = t->toDsymbol(sc);
                    if (sm)
                    {   if (id->dyncast() != DYNCAST_IDENTIFIER)
                            error(loc, "'%s' is not an identifier", id->toChars());
                        sm = sm->search(loc, (Identifier *)id, 0);
                        if (sm)
                            goto L2;
                    }
                    //e = t->getProperty(loc, id);
                    e = new TypeExp(loc, t);
                    e = t->dotExp(sc, e, (Identifier *)id);
                    i++;
                L3:
                    for (; i < idents.dim; i++)
                    {
                        Object *id = idents[i];
                        //printf("e: '%s', id: '%s', type = %s\n", e->toChars(), id->toChars(), e->type->toChars());
                        if (id->dyncast() == DYNCAST_IDENTIFIER)
                        {
                            e = e->type->dotExp(sc, e, (Identifier *)id);
                        }
                        else
                            assert(0);
                    }
                    if (e->op == TOKtype)
                        *pt = e->type;
                    else
                        *pe = e;
                }
                else
                {
                  Lerror:
                    if (id->dyncast() == DYNCAST_DSYMBOL)
                    {   // searchX already handles errors for template instances
                        assert(global.errors);
                    }
                    else
                    {
                        assert(id->dyncast() == DYNCAST_IDENTIFIER);
                        sm = s->search_correct((Identifier *)id);
                        if (sm)
                            error(loc, "identifier '%s' of '%s' is not defined, did you mean '%s %s'?",
                                  id->toChars(), toChars(), sm->kind(), sm->toChars());
                        else
                            error(loc, "identifier '%s' of '%s' is not defined", id->toChars(), toChars());
                    }
                    *pe = new ErrorExp();
                }
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
                *pe = ei->exp->copy();  // make copy so we can change loc
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
                    //assert(0);        // BUG: should handle this
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
                if (s->scope)
                    t = t->semantic(loc, s->scope);
                else
                {
                    /* Attempt to find correct scope in which to evaluate t.
                     * Not sure if this is right or not, or if we should just
                     * give forward reference error if s->scope is not set.
                     */
                    for (Scope *scx = sc; 1; scx = scx->enclosing)
                    {
                        if (!scx)
                        {   error(loc, "forward reference to '%s'", t->toChars());
                            return;
                        }
                        if (scx->scopesym == scopesym)
                        {
                            t = t->semantic(loc, scx);
                            break;
                        }
                    }
                }
            }
        }
        if (t->ty == Ttuple)
            *pt = t;
        else if (t->ty == Ttypeof)
            *pt = t->semantic(loc, sc);
        else
            *pt = t->merge();
    }

    if (!s)
    {
        const char *p = toChars();
        const char *n = importHint(p);
        if (n)
            error(loc, "'%s' is not defined, perhaps you need to import %s; ?", p, n);
        else
        {
            Identifier *id = new Identifier(p, TOKidentifier);
            s = sc->search_correct(id);
            if (s)
                error(loc, "undefined identifier %s, did you mean %s %s?", p, s->kind(), s->toChars());
            else
                error(loc, "undefined identifier %s", p);
        }
        *pt = Type::terror;
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
    {   toCBuffer3(buf, hgs, mod);
        return;
    }
    buf->writestring(this->ident->toChars());
    toCBuffer2Helper(buf, hgs);
}

/*************************************
 * Takes an array of Identifiers and figures out if
 * it represents a Type or an Expression.
 * Output:
 *      if expression, *pe is set
 *      if type, *pt is set
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
        for (size_t i = 0; i < idents.dim; i++)
        {
            Object *id = idents[i];
            s = s->searchX(loc, sc, id);
            if (!s)                 // failed to find a symbol
            {   //printf("\tdidn't find a symbol\n");
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
    for (size_t i = 0; i < idents.dim; i++)
    {
        Object *id = idents[i];
        if (id->dyncast() == DYNCAST_IDENTIFIER)
        {
            e = new DotIdExp(loc, e, (Identifier *)id);
        }
        else
            assert(0);
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
    {   toCBuffer3(buf, hgs, mod);
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
        unsigned errors = global.startGagging();

        resolve(loc, sc, &e, &t, &s);

        if (global.endGagging(errors))
        {
            return this;
        }
    }
    else
        resolve(loc, sc, &e, &t, &s);

    if (!t)
    {
#if 0
        if (s) printf("s = %s\n", s->kind());
        printf("2: e:%p s:%p ", e, s);
#endif
        error(loc, "%s is used as a type", toChars());
        t = terror;
    }
    return t;
}

Dsymbol *TypeInstance::toDsymbol(Scope *sc)
{
    Type *t;
    Expression *e;
    Dsymbol *s;

    //printf("TypeInstance::semantic(%s)\n", toChars());

    if (sc->parameterSpecialization)
    {
        unsigned errors = global.startGagging();

        resolve(loc, sc, &e, &t, &s);

        if (global.endGagging(errors))
            return NULL;
    }
    else
        resolve(loc, sc, &e, &t, &s);

    return s;
}


/***************************** TypeTypeof *****************************/

TypeTypeof::TypeTypeof(Loc loc, Expression *exp)
        : TypeQualified(Ttypeof, loc)
{
    this->exp = exp;
    inuse = 0;
}

Type *TypeTypeof::syntaxCopy()
{
    //printf("TypeTypeof::syntaxCopy() %s\n", toChars());
    TypeTypeof *t;

    t = new TypeTypeof(loc, exp->syntaxCopy());
    t->syntaxCopyHelper(this);
    return t;
}

Dsymbol *TypeTypeof::toDsymbol(Scope *sc)
{
    Type *t;

    t = semantic(loc, sc);
    if (t == this)
        return NULL;
    return t->toDsymbol(sc);
}

void TypeTypeof::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    if (mod != this->mod)
    {   toCBuffer3(buf, hgs, mod);
        return;
    }
    buf->writestring("typeof(");
    exp->toCBuffer(buf, hgs);
    buf->writeByte(')');
    toCBuffer2Helper(buf, hgs);
}

void TypeTypeof::toDecoBuffer(OutBuffer *buf)
{
    assert(0);
}

Type *TypeTypeof::semantic(Loc loc, Scope *sc)
{   Expression *e;
    Type *t;

    //printf("TypeTypeof::semantic() %p\n", this);

    //static int nest; if (++nest == 50) *(char*)0=0;
    if (inuse)
    {
        inuse = 2;
        error(loc, "circular typeof definition");
        return Type::terror;
    }
    inuse++;

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
                    {   error(loc, "class %s has no 'super'", s->toChars());
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
        Scope *sc2 = sc->push();
        sc2->intypeof++;
        unsigned oldspecgag = global.speculativeGag;
        if (global.gag)
            global.speculativeGag = global.gag;
        exp = exp->semantic(sc2);
        global.speculativeGag = oldspecgag;
#if DMDV2
        if (exp->type && exp->type->ty == Tfunction &&
            ((TypeFunction *)exp->type)->isproperty)
            exp = resolveProperties(sc2, exp);
#endif
        sc2->pop();
        if (exp->op == TOKtype)
        {
            error(loc, "argument %s to typeof is not an expression", exp->toChars());
            goto Lerr;
        }
        t = exp->type;
        if (!t)
        {
            error(loc, "expression (%s) has no type", exp->toChars());
            goto Lerr;
        }
        if (t->ty == Ttypeof)
        {   error(loc, "forward reference to %s", toChars());
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
            {   error(loc, "%s is not a type", s->toChars());
                goto Lerr;
            }
        }
        else
        {   error(loc, "cannot resolve .property for %s", toChars());
            goto Lerr;
        }
    }
    inuse--;
    return t;

Lerr:
    inuse--;
    return terror;
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

Type *TypeEnum::syntaxCopy()
{
    return this;
}

Type *TypeEnum::semantic(Loc loc, Scope *sc)
{
    //sym->semantic(sc);
    return merge();
}

d_uns64 TypeEnum::size(Loc loc)
{
    if (!sym->memtype)
    {
        error(loc, "enum %s is forward referenced", sym->toChars());
        return SIZE_INVALID;
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
    if (sym->scope)
    {   // Enum is forward referenced. We don't need to resolve the whole thing,
        // just the base type
        if (sym->memtype)
        {   sym->memtype = sym->memtype->semantic(sym->loc, sym->scope);
        }
        else
        {   if (!sym->isAnonymous())
                sym->memtype = Type::tint32;
        }
    }
    if (!sym->memtype)
    {
#ifdef DEBUG
        printf("2: ");
#endif
        error(sym->loc, "enum %s is forward referenced", sym->toChars());
        return terror;
    }
    return sym->memtype->toBasetype();
}

void TypeEnum::toDecoBuffer(OutBuffer *buf)
{   char *name;

    name = sym->mangle();
//    if (name[0] == '_' && name[1] == 'D')
//      name += 2;
    buf->printf("%c%s", mangleChar[ty], name);
}

void TypeEnum::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    if (mod != this->mod)
    {   toCBuffer3(buf, hgs, mod);
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
        if (ident == Id::max ||
            ident == Id::min ||
            ident == Id::init ||
            ident == Id::mangleof ||
            !sym->memtype
           )
        {
            return getProperty(e->loc, ident);
        }
        return sym->memtype->dotExp(sc, e, ident);
    }
    m = s->isEnumMember();
    em = m->value->copy();
    em->loc = e->loc;
    return em;

Lfwd:
    error(e->loc, "forward reference of enum %s.%s", toChars(), ident->toChars());
    return new IntegerExp(0, 0, Type::terror);
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
    else if (ident == Id::stringof)
    {   char *s = toChars();
        e = new StringExp(loc, s, strlen(s), 'c');
        Scope sc;
        e = e->semantic(&sc);
    }
    else if (ident == Id::mangleof)
    {
        e = Type::getProperty(loc, ident);
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
        m = MATCHexact;         // exact match
    else if (sym->memtype->implicitConvTo(to))
        m = MATCHconvert;       // match with conversions
    else
        m = MATCHnomatch;       // no match
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

int TypeEnum::isZeroInit(Loc loc)
{
    //printf("TypeEnum::isZeroInit() '%s'\n", toChars());
    if (!sym->isdone && sym->scope)
    {   // Enum is forward referenced. We need to resolve the whole thing.
        sym->semantic(NULL);
    }
    if (!sym->isdone)
    {
#ifdef DEBUG
        printf("3: ");
#endif
        error(loc, "enum %s is forward referenced", sym->toChars());
        return 0;
    }
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
    int errors = global.errors;
    sym->semantic(sc);
    if (errors != global.errors)
        return terror;
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
//      name += 2;
    //len = strlen(name);
    //buf->printf("%c%d%s", mangleChar[ty], len, name);
    buf->printf("%c%s", mangleChar[ty], name);
}

void TypeTypedef::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    //printf("TypeTypedef::toCBuffer2() '%s'\n", sym->toChars());
    if (mod != this->mod)
    {   toCBuffer3(buf, hgs, mod);
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
        m = MATCHexact;         // exact match
    else if (sym->basetype->implicitConvTo(to))
        m = MATCHconvert;       // match with conversions
    else
        m = MATCHnomatch;       // no match
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

int TypeTypedef::isZeroInit(Loc loc)
{
    if (sym->init)
    {
        if (sym->init->isVoidInitializer())
            return 1;           // initialize voids to 0
        Expression *e = sym->init->toExpression();
        if (e && e->isBool(FALSE))
            return 1;
        return 0;               // assume not
    }
    if (sym->inuse)
    {
        sym->error("circular definition");
        sym->basetype = Type::terror;
    }
    sym->inuse = 1;
    int result = sym->basetype->isZeroInit(loc);
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

    sym->size(0);               // give error for forward references
    sz = sym->alignsize;
    if (sym->structalign == STRUCTALIGN_DEFAULT)
    {
        if (sz > 8)
            sz = 8;
    }
    else if (sz > sym->structalign)
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
//      name += 2;
    //len = strlen(name);
    //buf->printf("%c%d%s", mangleChar[ty], len, name);
    buf->printf("%c%s", mangleChar[ty], name);
}

void TypeStruct::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    if (mod != this->mod)
    {   toCBuffer3(buf, hgs, mod);
        return;
    }
    TemplateInstance *ti = sym->parent->isTemplateInstance();
    if (ti && ti->toAlias() == sym)
        buf->writestring(ti->toChars());
    else
        buf->writestring(sym->toChars());
}

Expression *TypeStruct::dotExp(Scope *sc, Expression *e, Identifier *ident)
{
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
        return new ErrorExp();
    }

    /* If e.tupleof
     */
    if (ident == Id::tupleof)
    {
        /* Create a TupleExp out of the fields of the struct e:
         * (e.field0, e.field1, e.field2, ...)
         */
        e = e->semantic(sc);    // do this before turning on noaccesscheck
        e->type->size();        // do semantic of type
        Expressions *exps = new Expressions;
        exps->reserve(sym->fields.dim);
        for (size_t i = 0; i < sym->fields.dim; i++)
        {   VarDeclaration *v = sym->fields[i];
            Expression *fe = new DotVarExp(e->loc, e, v);
            exps->push(fe);
        }
        e = new TupleExp(e->loc, exps);
        sc = sc->push();
        sc->noaccesscheck = 1;
        e = e->semantic(sc);
        sc->pop();
        return e;
    }

    if (e->op == TOKdotexp)
    {   DotExp *de = (DotExp *)e;

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
    if (!s->isFuncDeclaration())        // because of overloading
        s->checkDeprecated(e->loc, sc);
    s = s->toAlias();

    v = s->isVarDeclaration();
    if (v && v->isConst() && v->type && v->type->toBasetype()->ty != Tsarray)
    {   ExpInitializer *ei = v->getExpInitializer();

        if (ei)
        {   e = ei->exp->copy();        // need to copy it if it's a StringExp
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
    {
        Expression *de = new DotExp(e->loc, e, new ScopeExp(e->loc, tm));
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
    {   if (!ti->semanticRun)
        {
            if (global.errors)
                return new ErrorExp();  // TemplateInstance::semantic() will fail anyway
            ti->semantic(sc);
        }
        s = ti->inst->toAlias();
        if (!s->isTemplateInstance())
            goto L1;
        Expression *de = new DotExp(e->loc, e, new ScopeExp(e->loc, ti));
        de->type = e->type;
        return de;
    }

    if (s->isImport() || s->isModule() || s->isPackage())
    {
        e = new DsymbolExp(e->loc, s);
        e = e->semantic(sc);
        return e;
    }

    d = s->isDeclaration();
#ifdef DEBUG
    if (!d)
        printf("d = %s '%s'\n", s->kind(), s->toChars());
#endif
    assert(d);

    if (e->op == TOKtype)
    {   FuncDeclaration *fd = sc->func;

        if (d->needThis() && fd && fd->vthis &&
                 fd->toParent2()->isStructDeclaration() == sym)
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
        e = e->semantic(sc);
        return e;
    }

    if (v)
    {
        if (v->toParent() != sym)
            sym->error(e->loc, "'%s' is not a member", v->toChars());

        // *(&e + offset)
        accessCheck(e->loc, sc, e, d);
#if 0
        b = new AddrExp(e->loc, e);
        b->type = e->type->pointerTo();
        b = new AddExp(e->loc, b, new IntegerExp(e->loc, v->offset, Type::tint32));
        b->type = v->type->pointerTo();
        e = new PtrExp(e->loc, b);
        e->type = v->type;
        return e;
#endif
    }

    de = new DotVarExp(e->loc, e, d);
    return de->semantic(sc);
}

structalign_t TypeStruct::memalign(structalign_t salign)
{
    sym->size(0);               // give error for forward references
    return sym->structalign;
}

Expression *TypeStruct::defaultInit(Loc loc)
{
#if LOGDEFAULTINIT
    printf("TypeStruct::defaultInit() '%s'\n", toChars());
#endif
    Symbol *s = sym->toInitializer();
    Declaration *d = new SymbolDeclaration(sym->loc, s, sym);
    assert(d);
    d->type = this;
    return new VarExp(sym->loc, d);
}

/***************************************
 * Use when we prefer the default initializer to be a literal,
 * rather than a global immutable variable.
 */
Expression *TypeStruct::defaultInitLiteral(Loc loc)
{
#if LOGDEFAULTINIT
    printf("TypeStruct::defaultInitLiteral() '%s'\n", toChars());
#endif
    Expressions *structelems = new Expressions();
    structelems->setDim(sym->fields.dim);
    for (size_t j = 0; j < structelems->dim; j++)
    {
        VarDeclaration *vd = sym->fields[j];
        Expression *e;
        if (vd->init)
        {   if (vd->init->isVoidInitializer())
                e = NULL;
            else
                e = vd->init->toExpression();
        }
        else
            e = vd->type->defaultInitLiteral(loc);
        (*structelems)[j] = e;
    }
    StructLiteralExp *structinit = new StructLiteralExp(loc, (StructDeclaration *)sym, structelems);
    // Why doesn't the StructLiteralExp constructor do this, when
    // sym->type != NULL ?
    structinit->type = sym->type;
    return structinit;
}


int TypeStruct::isZeroInit(Loc loc)
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

    sym->size(0);               // give error for forward references
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
    return (char *)sym->toPrettyChars();
}

Type *TypeClass::syntaxCopy()
{
    return this;
}

Type *TypeClass::semantic(Loc loc, Scope *sc)
{
    //printf("TypeClass::semantic(%s)\n", sym->toChars());
    if (deco)
        return this;
    //printf("\t%s\n", merge()->deco);
    return merge();
}

d_uns64 TypeClass::size(Loc loc)
{
    return Target::ptrsize;
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
//      name += 2;
    //printf("TypeClass::toDecoBuffer('%s') = '%s'\n", toChars(), name);
    //len = strlen(name);
    //buf->printf("%c%d%s", mangleChar[ty], len, name);
    buf->printf("%c%s", mangleChar[ty], name);
}

void TypeClass::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    if (mod != this->mod)
    {   toCBuffer3(buf, hgs, mod);
        return;
    }
    buf->writestring(sym->toChars());
}

Expression *TypeClass::dotExp(Scope *sc, Expression *e, Identifier *ident)
{
    VarDeclaration *v;
    Dsymbol *s;
    DotVarExp *de;

#if LOGDOTEXP
    printf("TypeClass::dotExp(e='%s', ident='%s')\n", e->toChars(), ident->toChars());
#endif

    if (e->op == TOKdotexp)
    {   DotExp *de = (DotExp *)e;

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
        e = e->semantic(sc);    // do this before turning on noaccesscheck
        e->type->size();        // do semantic of type
        Expressions *exps = new Expressions;
        exps->reserve(sym->fields.dim);
        for (size_t i = 0; i < sym->fields.dim; i++)
        {   VarDeclaration *v = sym->fields[i];
            // Don't include hidden 'this' pointer
            if (v->isThisDeclaration())
                continue;
            Expression *fe = new DotVarExp(e->loc, e, v);
            exps->push(fe);
        }
        e = new TupleExp(e->loc, exps);
        sc = sc->push();
        sc->noaccesscheck = 1;
        e = e->semantic(sc);
        sc->pop();
        return e;
    }

    s = sym->search(e->loc, ident, 0);
L1:
    if (!s)
    {
        // See if it's a base class
        ClassDeclaration *cbase = sym->searchBase(e->loc, ident);
        if (cbase)
        {
            if (InterfaceDeclaration *ifbase = cbase->isInterfaceDeclaration())
            {
                e = new CastExp(0, e, ifbase->type);
                return e;
            }
            else
            {
                e = new DotTypeExp(0, e, cbase);
                return e;
            }
        }

        if (ident == Id::classinfo)
        {
            assert(ClassDeclaration::classinfo);
            Type *t = ClassDeclaration::classinfo->type;
            if (e->op == TOKtype || e->op == TOKdottype)
            {
                /* For type.classinfo, we know the classinfo
                 * at compile time.
                 */
                if (!sym->vclassinfo)
                    sym->vclassinfo = new ClassInfoDeclaration(sym);
                e = new VarExp(e->loc, sym->vclassinfo);
                e = e->addressOf(sc);
                e->type = t;    // do this so we don't get redundant dereference
            }
            else
            {   /* For class objects, the classinfo reference is the first
                 * entry in the vtbl[]
                 */
                e = new PtrExp(e->loc, e);
                e->type = t->pointerTo();
                if (sym->isInterfaceDeclaration())
                {
                    if (sym->isCOMinterface())
                    {   /* COM interface vtbl[]s are different in that the
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

        if (ident == Id::__vptr)
        {   /* The pointer to the vtbl[]
             * *cast(void***)e
             */
            e = e->castTo(sc, tvoidptr->pointerTo()->pointerTo());
            e = new PtrExp(e->loc, e);
            e = e->semantic(sc);
            return e;
        }

        if (ident == Id::__monitor)
        {   /* The handle to the monitor (call it a void*)
             * *(cast(void**)e + 1)
             */
            e = e->castTo(sc, tvoidptr->pointerTo());
            e = new AddExp(e->loc, e, new IntegerExp(1));
            e = new PtrExp(e->loc, e);
            e = e->semantic(sc);
            return e;
        }

        if (ident == Id::typeinfo)
        {
            deprecation(e->loc, ".typeinfo deprecated, use typeid(type)");
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
    if (!s->isFuncDeclaration())        // because of overloading
        s->checkDeprecated(e->loc, sc);
    s = s->toAlias();
    v = s->isVarDeclaration();
    if (v && v->isConst() && v->type->toBasetype()->ty != Tsarray)
    {   ExpInitializer *ei = v->getExpInitializer();

        if (ei)
        {   e = ei->exp->copy();        // need to copy it if it's a StringExp
            e = e->semantic(sc);
            return e;
        }
    }

    if (s->getType())
    {
//      if (e->op == TOKtype)
            return new TypeExp(e->loc, s->getType());
//      return new DotTypeExp(e->loc, e, s);
    }

    EnumMember *em = s->isEnumMember();
    if (em)
    {
        assert(em->value);
        return em->value->copy();
    }

    TemplateMixin *tm = s->isTemplateMixin();
    if (tm)
    {
        Expression *de = new DotExp(e->loc, e, new ScopeExp(e->loc, tm));
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
    {   if (!ti->semanticRun)
        {
            if (global.errors)
                return new ErrorExp();  // TemplateInstance::semantic() will fail anyway
            ti->semantic(sc);
        }
        s = ti->inst->toAlias();
        if (!s->isTemplateInstance())
            goto L1;
        Expression *de = new DotExp(e->loc, e, new ScopeExp(e->loc, ti));
        de->type = e->type;
        return de;
    }

#if 0 // shouldn't this be here?
    if (s->isImport() || s->isModule() || s->isPackage())
    {
        e = new DsymbolExp(e->loc, s, 0);
        e = e->semantic(sc);
        return e;
    }
#endif

    Declaration *d = s->isDeclaration();
    if (!d)
    {
        e->error("%s.%s is not a declaration", e->toChars(), ident->toChars());
        return new ErrorExp();
    }

    if (e->op == TOKtype)
    {
        /* It's:
         *    Class.d
         */
        if (d->isTupleDeclaration())
        {
            e = new TupleExp(e->loc, d->isTupleDeclaration());
            e = e->semantic(sc);
            return e;
        }
        else if (d->needThis() && (hasThis(sc) || !(sc->intypeof || d->isFuncDeclaration())))
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
                        DotVarExp *de = new DotVarExp(e->loc, e, d);
                        e = de->semantic(sc);
                        return e;
                    }
                    else if ((!cd || !cd->isBaseOf(thiscd, NULL)) &&
                             !d->isFuncDeclaration())
                        e->error("'this' is required, but %s is not a base class of %s", e->type->toChars(), thiscd->toChars());
                }
            }

            /* Rewrite as:
             *  this.d
             */
            DotVarExp *de = new DotVarExp(e->loc, new ThisExp(e->loc), d);
            e = de->semantic(sc);
            return e;
        }
        else
        {
            VarExp *ve = new VarExp(e->loc, d);
            return ve;
        }
    }

    if (d->isDataseg())
    {
        // (e, d)
        VarExp *ve;

        accessCheck(e->loc, sc, e, d);
        ve = new VarExp(e->loc, d);
        e = new CommaExp(e->loc, e, ve);
        e = e->semantic(sc);
        return e;
    }

    if (d->parent && d->toParent()->isModule())
    {
        // (e, d)
        VarExp *ve = new VarExp(e->loc, d);
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

int TypeClass::isscope()
{
    return sym->isscope;
}

int TypeClass::isBaseOf(Type *t, int *poffset)
{
    if (t && t->ty == Tclass)
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
    {   //printf("'to' is base\n");
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
    return new NullExp(loc, this);
}

int TypeClass::isZeroInit(Loc loc)
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

TypeTuple::TypeTuple(Parameters *arguments)
    : Type(Ttuple, NULL)
{
    //printf("TypeTuple(this = %p)\n", this);
    this->arguments = arguments;
    //printf("TypeTuple() %s\n", toChars());
#ifdef DEBUG
    if (arguments)
    {
        for (size_t i = 0; i < arguments->dim; i++)
        {
            Parameter *arg = (Parameter *)arguments->data[i];
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
    Parameters *arguments = new Parameters;
    if (exps)
    {
        arguments->setDim(exps->dim);
        for (size_t i = 0; i < exps->dim; i++)
        {   Expression *e = (Expression *)exps->data[i];
            if (e->type->ty == Ttuple)
                e->error("cannot form tuple of tuples");
            Parameter *arg = new Parameter(STCin, e->type, NULL, NULL);
            arguments->data[i] = (void *)arg;
        }
    }
    this->arguments = arguments;
}

/*******************************************
 * Type tuple with 0, 1 or 2 types in it.
 */
TypeTuple::TypeTuple()
    : Type(Ttuple, NULL)
{
    arguments = new Parameters();
}

TypeTuple::TypeTuple(Type *t1)
    : Type(Ttuple, NULL)
{
    arguments = new Parameters();
    arguments->push(new Parameter(0, t1, NULL, NULL));
}

TypeTuple::TypeTuple(Type *t1, Type *t2)
    : Type(Ttuple, NULL)
{
    arguments = new Parameters();
    arguments->push(new Parameter(0, t1, NULL, NULL));
    arguments->push(new Parameter(0, t2, NULL, NULL));
}
Type *TypeTuple::syntaxCopy()
{
    Parameters *args = Parameter::arraySyntaxCopy(arguments);
    Type *t = new TypeTuple(args);
    return t;
}

Type *TypeTuple::semantic(Loc loc, Scope *sc)
{
    //printf("TypeTuple::semantic(this = %p)\n", this);
    //printf("TypeTuple::semantic() %s\n", toChars());
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
    {   TypeTuple *tt = (TypeTuple *)t;

        if (arguments->dim == tt->arguments->dim)
        {
            for (size_t i = 0; i < tt->arguments->dim; i++)
            {   Parameter *arg1 = (Parameter *)arguments->data[i];
                Parameter *arg2 = (Parameter *)tt->arguments->data[i];

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
            Parameter *arg = (Parameter *)arguments->data[i];
            Type *t = arg->type->reliesOnTident();
            if (t)
                return t;
        }
    }
    return NULL;
}

void TypeTuple::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    Parameter::argsToCBuffer(buf, hgs, arguments, 0);
}

void TypeTuple::toDecoBuffer(OutBuffer *buf)
{
    //printf("TypeTuple::toDecoBuffer() this = %p\n", this);
    OutBuffer buf2;
    Parameter::argsToDecoBuffer(&buf2, arguments);
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
    {   error(loc, "can only slice tuple types, not %s", tbn->toChars());
        return Type::terror;
    }
    TypeTuple *tt = (TypeTuple *)tbn;

    lwr = semanticLength(sc, tbn, lwr);
    lwr = lwr->ctfeInterpret();
    uinteger_t i1 = lwr->toUInteger();

    upr = semanticLength(sc, tbn, upr);
    upr = upr->ctfeInterpret();
    uinteger_t i2 = upr->toUInteger();

    if (!(i1 <= i2 && i2 <= tt->arguments->dim))
    {   error(loc, "slice [%ju..%ju] is out of range of [0..%u]", i1, i2, tt->arguments->dim);
        return Type::terror;
    }

    Parameters *args = new Parameters;
    args->reserve(i2 - i1);
    for (size_t i = i1; i < i2; i++)
    {   Parameter *arg = (Parameter *)tt->arguments->data[i];
        args->push(arg);
    }

    Type *t = (new TypeTuple(args))->semantic(loc, sc);
    return t;
}

void TypeSlice::resolve(Loc loc, Scope *sc, Expression **pe, Type **pt, Dsymbol **ps)
{
    next->resolve(loc, sc, pe, pt, ps);
    if (*pe)
    {   // It's really a slice expression
        Expression *e;
        e = new SliceExp(loc, *pe, lwr, upr);
        *pe = e;
    }
    else if (*ps)
    {   Dsymbol *s = *ps;
        TupleDeclaration *td = s->isTupleDeclaration();
        if (td)
        {
            /* It's a slice of a TupleDeclaration
             */
            ScopeDsymbol *sym = new ArrayScopeSymbol(td);
            sym->parent = sc->scopesym;
            sc = sc->push(sym);

            lwr = lwr->semantic(sc);
            lwr = lwr->ctfeInterpret();
            uinteger_t i1 = lwr->toUInteger();

            upr = upr->semantic(sc);
            upr = upr->ctfeInterpret();
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
    {   toCBuffer3(buf, hgs, mod);
        return;
    }
    next->toCBuffer2(buf, hgs, this->mod);

    buf->printf("[%s .. ", lwr->toChars());
    buf->printf("%s]", upr->toChars());
}

/***************************** Parameter *****************************/

Parameter::Parameter(StorageClass storageClass, Type *type, Identifier *ident, Expression *defaultArg)
{
    this->type = type;
    this->ident = ident;
    this->storageClass = storageClass;
    this->defaultArg = defaultArg;
}

Parameter *Parameter::syntaxCopy()
{
    Parameter *a = new Parameter(storageClass,
                type ? type->syntaxCopy() : NULL,
                ident,
                defaultArg ? defaultArg->syntaxCopy() : NULL);
    return a;
}

Parameters *Parameter::arraySyntaxCopy(Parameters *args)
{   Parameters *a = NULL;

    if (args)
    {
        a = new Parameters();
        a->setDim(args->dim);
        for (size_t i = 0; i < a->dim; i++)
        {   Parameter *arg = (*args)[i];

            arg = arg->syntaxCopy();
            (*a)[i] = arg;
        }
    }
    return a;
}

char *Parameter::argsTypesToChars(Parameters *args, int varargs)
{
    OutBuffer *buf = new OutBuffer();

    HdrGenState hgs;
    argsToCBuffer(buf, &hgs, args, varargs);

    return buf->toChars();
}

void Parameter::argsToCBuffer(OutBuffer *buf, HdrGenState *hgs, Parameters *arguments, int varargs)
{
    buf->writeByte('(');
    if (arguments)
    {
        OutBuffer argbuf;

        for (size_t i = 0; i < arguments->dim; i++)
        {
            if (i)
                buf->writestring(", ");
            Parameter *arg = (Parameter *)arguments->data[i];
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
            if (arguments->dim && varargs == 1)
                buf->writestring(", ");
            buf->writestring("...");
        }
    }
    buf->writeByte(')');
}

static int argsToDecoBufferDg(void *ctx, size_t n, Parameter *arg)
{
    arg->toDecoBuffer((OutBuffer *)ctx);
    return 0;
}

void Parameter::argsToDecoBuffer(OutBuffer *buf, Parameters *arguments)
{
    //printf("Parameter::argsToDecoBuffer()\n");
    // Write argument types
    foreach(arguments, &argsToDecoBufferDg, buf);
}

/****************************************
 * Determine if parameter list is really a template parameter list
 * (i.e. it has auto or alias parameters)
 */

static int isTPLDg(void *ctx, size_t n, Parameter *arg)
{
    if (arg->storageClass & (STCalias | STCauto | STCstatic))
        return 1;
    return 0;
}

int Parameter::isTPL(Parameters *arguments)
{
    //printf("Parameter::isTPL()\n");
    return foreach(arguments, &isTPLDg, NULL);
}

/****************************************************
 * Determine if parameter is a lazy array of delegates.
 * If so, return the return type of those delegates.
 * If not, return NULL.
 */

Type *Parameter::isLazyArray()
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

                if (!tf->varargs && Parameter::dim(tf->parameters) == 0)
                {
                    return tf->next;    // return type of delegate
                }
            }
        }
    }
    return NULL;
}

void Parameter::toDecoBuffer(OutBuffer *buf)
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
            printf("storageClass = x%llx\n", storageClass & (STCin | STCout | STCref | STClazy));
            halt();
#endif
            assert(0);
    }
    type->toDecoBuffer(buf);
}

/***************************************
 * Determine number of arguments, folding in tuples.
 */

static int dimDg(void *ctx, size_t n, Parameter *)
{
    ++*(size_t *)ctx;
    return 0;
}

size_t Parameter::dim(Parameters *args)
{
    size_t n = 0;
    foreach(args, &dimDg, &n);
    return n;
}

/***************************************
 * Get nth Parameter, folding in tuples.
 * Returns:
 *      Parameter*      nth Parameter
 *      NULL            not found, *pn gets incremented by the number
 *                      of Parameters
 */

struct GetNthParamCtx
{
    size_t nth;
    Parameter *arg;
};

static int getNthParamDg(void *ctx, size_t n, Parameter *arg)
{
    GetNthParamCtx *p = (GetNthParamCtx *)ctx;
    if (n == p->nth)
    {   p->arg = arg;
        return 1;
    }
    return 0;
}

Parameter *Parameter::getNth(Parameters *args, size_t nth, size_t *pn)
{
    GetNthParamCtx ctx = { nth, NULL };
    int res = foreach(args, &getNthParamDg, &ctx);
    return res ? ctx.arg : NULL;
}

/***************************************
 * Expands tuples in args in depth first order. Calls
 * dg(void *ctx, size_t argidx, Parameter *arg) for each Parameter.
 * If dg returns !=0, stops and returns that value else returns 0.
 * Use this function to avoid the O(N + N^2/2) complexity of
 * calculating dim and calling N times getNth.
 */

int Parameter::foreach(Parameters *args, Parameter::ForeachDg dg, void *ctx, size_t *pn)
{
    assert(dg);
    if (!args)
        return 0;

    size_t n = pn ? *pn : 0; // take over index
    int result = 0;
    for (size_t i = 0; i < args->dim; i++)
    {   Parameter *arg = args->tdata()[i];
        Type *t = arg->type->toBasetype();

        if (t->ty == Ttuple)
        {   TypeTuple *tu = (TypeTuple *)t;
            result = foreach(tu->arguments, dg, ctx, &n);
        }
        else
            result = dg(ctx, n++, arg);

        if (result)
            break;
    }

    if (pn)
        *pn = n; // update index
    return result;
}
