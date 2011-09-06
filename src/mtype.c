
// Compiler implementation of the D programming language
// Copyright (c) 1999-2011 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// http://www.digitalmars.com
// http://www.dsource.org/projects/dmd/browser/trunk/src/mtype.c
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
void ObjectNotFound(Identifier *id);


#define LOGDOTEXP       0       // log ::dotExp()
#define LOGDEFAULTINIT  0       // log ::defaultInit()

// Allow implicit conversion of T[] to T*
#define IMPLICIT_ARRAY_TO_PTR   global.params.useDeprecated

/* These have default values for 32 bit code, they get
 * adjusted for 64 bit code.
 */

int PTRSIZE = 4;

/* REALSIZE = size a real consumes in memory
 * REALPAD = 'padding' added to the CPU real size to bring it up to REALSIZE
 * REALALIGNSIZE = alignment for reals
 */
#if TARGET_OSX
int REALSIZE = 16;
int REALPAD = 6;
int REALALIGNSIZE = 16;
#elif TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
int REALSIZE = 12;
int REALPAD = 2;
int REALALIGNSIZE = 4;
#elif TARGET_WINDOS
int REALSIZE = 10;
int REALPAD = 0;
int REALALIGNSIZE = 2;
#else
#error "fix this"
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
ClassDeclaration *Type::typeinfoconst;
ClassDeclaration *Type::typeinfoinvariant;
ClassDeclaration *Type::typeinfoshared;
ClassDeclaration *Type::typeinfowild;

TemplateDeclaration *Type::associativearray;

Type *Type::tvoidptr;
Type *Type::tstring;
Type *Type::basic[TMAX];
unsigned char Type::mangleChar[TMAX];
unsigned char Type::sizeTy[TMAX];
StringTable Type::stringtable;


Type::Type(TY ty)
{
    this->ty = ty;
    this->mod = 0;
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
    Lexer::initKeywords();

    for (size_t i = 0; i < TMAX; i++)
        sizeTy[i] = sizeof(TypeBasic);
    sizeTy[Tsarray] = sizeof(TypeSArray);
    sizeTy[Tarray] = sizeof(TypeDArray);
    sizeTy[Taarray] = sizeof(TypeAArray);
    sizeTy[Tpointer] = sizeof(TypePointer);
    sizeTy[Treference] = sizeof(TypeReference);
    sizeTy[Tfunction] = sizeof(TypeFunction);
    sizeTy[Tdelegate] = sizeof(TypeDelegate);
    sizeTy[Tident] = sizeof(TypeIdentifier);
    sizeTy[Tinstance] = sizeof(TypeInstance);
    sizeTy[Ttypeof] = sizeof(TypeTypeof);
    sizeTy[Tenum] = sizeof(TypeEnum);
    sizeTy[Ttypedef] = sizeof(TypeTypedef);
    sizeTy[Tstruct] = sizeof(TypeStruct);
    sizeTy[Tclass] = sizeof(TypeClass);
    sizeTy[Ttuple] = sizeof(TypeTuple);
    sizeTy[Tslice] = sizeof(TypeSlice);
    sizeTy[Treturn] = sizeof(TypeReturn);

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
    {   Type *t = new TypeBasic(basetab[i]);
        t = t->merge();
        basic[basetab[i]] = t;
    }
    basic[Terror] = new TypeError();

    tvoidptr = tvoid->pointerTo();
    tstring = tchar->invariantOf()->arrayOf();

    if (global.params.is64bit)
    {
        PTRSIZE = 8;
        if (global.params.isLinux || global.params.isFreeBSD || global.params.isSolaris)
        {
            REALSIZE = 16;
            REALPAD = 6;
            REALALIGNSIZE = 16;
        }
        Tsize_t = Tuns64;
        Tptrdiff_t = Tint64;
    }
    else
    {
        PTRSIZE = 4;
#if TARGET_OSX
        REALSIZE = 16;
        REALPAD = 6;
#elif TARGET_LINUX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
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
    return merge();
}

Type *Type::trySemantic(Loc loc, Scope *sc)
{
    //printf("+trySemantic(%s) %d\n", toChars(), global.errors);
    unsigned errors = global.errors;
    global.gag++;                       // suppress printing of error messages
    Type *t = semantic(loc, sc);
    global.gag--;
    if (errors != global.errors)        // if any errors happened
    {
        global.errors = errors;
        t = NULL;
    }
    //printf("-trySemantic(%s) %d\n", toChars(), global.errors);
    return t;
}

/*******************************
 * Determine if converting 'this' to 'to' is an identity operation,
 * a conversion to const operation, or the types aren't the same.
 * Returns:
 *      MATCHexact      'this' == 'to'
 *      MATCHconst      'to' is const
 *      MATCHnomatch    conversion to mutable or invariant
 */

MATCH Type::constConv(Type *to)
{
    if (equals(to))
        return MATCHexact;
    if (ty == to->ty && MODimplicitConv(mod, to->mod))
        return MATCHconst;
    return MATCHnomatch;
}

/********************************
 * Convert to 'const'.
 */

Type *Type::constOf()
{
    //printf("Type::constOf() %p %s\n", this, toChars());
    if (mod == MODconst)
        return this;
    if (cto)
    {   assert(cto->mod == MODconst);
        return cto;
    }
    Type *t = makeConst();
    t = t->merge();
    t->fixTo(this);
    //printf("-Type::constOf() %p %s\n", t, toChars());
    return t;
}

/********************************
 * Convert to 'immutable'.
 */

Type *Type::invariantOf()
{
    //printf("Type::invariantOf() %p %s\n", this, toChars());
    if (isImmutable())
    {
        return this;
    }
    if (ito)
    {
        assert(ito->isImmutable());
        return ito;
    }
    Type *t = makeInvariant();
    t = t->merge();
    t->fixTo(this);
    //printf("\t%p\n", t);
    return t;
}

/********************************
 * Make type mutable.
 */

Type *Type::mutableOf()
{
    //printf("Type::mutableOf() %p, %s\n", this, toChars());
    Type *t = this;
    if (isConst())
    {   if (isShared())
            t = sto;            // shared const => shared
        else
            t = cto;            // const => naked
        assert(!t || t->isMutable());
    }
    else if (isImmutable())
    {   t = ito;                // immutable => naked
        assert(!t || (t->isMutable() && !t->isShared()));
    }
    else if (isWild())
    {
        if (isShared())
            t = sto;            // shared wild => shared
        else
            t = wto;            // wild => naked
        assert(!t || t->isMutable());
    }
    if (!t)
    {
        t = makeMutable();
        t = t->merge();
        t->fixTo(this);
    }
    assert(t->isMutable());
    return t;
}

Type *Type::sharedOf()
{
    //printf("Type::sharedOf() %p, %s\n", this, toChars());
    if (mod == MODshared)
    {
        return this;
    }
    if (sto)
    {
        assert(sto->isShared());
        return sto;
    }
    Type *t = makeShared();
    t = t->merge();
    t->fixTo(this);
    //printf("\t%p\n", t);
    return t;
}

Type *Type::sharedConstOf()
{
    //printf("Type::sharedConstOf() %p, %s\n", this, toChars());
    if (mod == (MODshared | MODconst))
    {
        return this;
    }
    if (scto)
    {
        assert(scto->mod == (MODshared | MODconst));
        return scto;
    }
    Type *t = makeSharedConst();
    t = t->merge();
    t->fixTo(this);
    //printf("\t%p\n", t);
    return t;
}


/********************************
 * Make type unshared.
 *      0            => 0
 *      const        => const
 *      immutable    => immutable
 *      shared       => 0
 *      shared const => const
 *      wild         => wild
 *      shared wild  => wild
 */

Type *Type::unSharedOf()
{
    //printf("Type::unSharedOf() %p, %s\n", this, toChars());
    Type *t = this;

    if (isShared())
    {
        if (isConst())
            t = cto;    // shared const => const
        else if (isWild())
            t = wto;    // shared wild => wild
        else
            t = sto;
        assert(!t || !t->isShared());
    }

    if (!t)
    {
        unsigned sz = sizeTy[ty];
        t = (Type *)mem.malloc(sz);
        memcpy(t, this, sz);
        t->mod = mod & ~MODshared;
        t->deco = NULL;
        t->arrayof = NULL;
        t->pto = NULL;
        t->rto = NULL;
        t->cto = NULL;
        t->ito = NULL;
        t->sto = NULL;
        t->scto = NULL;
        t->wto = NULL;
        t->swto = NULL;
        t->vtinfo = NULL;
        t = t->merge();

        t->fixTo(this);
    }
    assert(!t->isShared());
    return t;
}

/********************************
 * Convert to 'wild'.
 */

Type *Type::wildOf()
{
    //printf("Type::wildOf() %p %s\n", this, toChars());
    if (mod == MODwild)
    {
        return this;
    }
    if (wto)
    {
        assert(wto->isWild());
        return wto;
    }
    Type *t = makeWild();
    t = t->merge();
    t->fixTo(this);
    //printf("\t%p %s\n", t, t->toChars());
    return t;
}

Type *Type::sharedWildOf()
{
    //printf("Type::sharedWildOf() %p, %s\n", this, toChars());
    if (mod == (MODshared | MODwild))
    {
        return this;
    }
    if (swto)
    {
        assert(swto->mod == (MODshared | MODwild));
        return swto;
    }
    Type *t = makeSharedWild();
    t = t->merge();
    t->fixTo(this);
    //printf("\t%p\n", t);
    return t;
}

/**********************************
 * For our new type 'this', which is type-constructed from t,
 * fill in the cto, ito, sto, scto, wto shortcuts.
 */

void Type::fixTo(Type *t)
{
    ito = t->ito;
#if 0
    /* Cannot do these because these are not fully transitive:
     * there can be a shared ptr to immutable, for example.
     * Immutable subtypes are always immutable, though.
     */
    cto = t->cto;
    sto = t->sto;
    scto = t->scto;
#endif

    assert(mod != t->mod);
#define X(m, n) (((m) << 4) | (n))
    switch (X(mod, t->mod))
    {
        case X(0, MODconst):
            cto = t;
            break;

        case X(0, MODimmutable):
            ito = t;
            break;

        case X(0, MODshared):
            sto = t;
            break;

        case X(0, MODshared | MODconst):
            scto = t;
            break;

        case X(0, MODwild):
            wto = t;
            break;

        case X(0, MODshared | MODwild):
            swto = t;
            break;


        case X(MODconst, 0):
            cto = NULL;
            goto L2;

        case X(MODconst, MODimmutable):
            ito = t;
            goto L2;

        case X(MODconst, MODshared):
            sto = t;
            goto L2;

        case X(MODconst, MODshared | MODconst):
            scto = t;
            goto L2;

        case X(MODconst, MODwild):
            wto = t;
            goto L2;

        case X(MODconst, MODshared | MODwild):
            swto = t;
        L2:
            t->cto = this;
            break;


        case X(MODimmutable, 0):
            ito = NULL;
            goto L3;

        case X(MODimmutable, MODconst):
            cto = t;
            goto L3;

        case X(MODimmutable, MODshared):
            sto = t;
            goto L3;

        case X(MODimmutable, MODshared | MODconst):
            scto = t;
            goto L3;

        case X(MODimmutable, MODwild):
            wto = t;
            goto L3;

        case X(MODimmutable, MODshared | MODwild):
            swto = t;
        L3:
            t->ito = this;
            if (t->cto) t->cto->ito = this;
            if (t->sto) t->sto->ito = this;
            if (t->scto) t->scto->ito = this;
            if (t->wto) t->wto->ito = this;
            if (t->swto) t->swto->ito = this;
            break;


        case X(MODshared, 0):
            sto = NULL;
            goto L4;

        case X(MODshared, MODconst):
            cto = t;
            goto L4;

        case X(MODshared, MODimmutable):
            ito = t;
            goto L4;

        case X(MODshared, MODshared | MODconst):
            scto = t;
            goto L4;

        case X(MODshared, MODwild):
            wto = t;
            goto L4;

        case X(MODshared, MODshared | MODwild):
            swto = t;
        L4:
            t->sto = this;
            break;


        case X(MODshared | MODconst, 0):
            scto = NULL;
            goto L5;

        case X(MODshared | MODconst, MODconst):
            cto = t;
            goto L5;

        case X(MODshared | MODconst, MODimmutable):
            ito = t;
            goto L5;

        case X(MODshared | MODconst, MODwild):
            wto = t;
            goto L5;

        case X(MODshared | MODconst, MODshared):
            sto = t;
            goto L5;

        case X(MODshared | MODconst, MODshared | MODwild):
            swto = t;
        L5:
            t->scto = this;
            break;


        case X(MODwild, 0):
            wto = NULL;
            goto L6;

        case X(MODwild, MODconst):
            cto = t;
            goto L6;

        case X(MODwild, MODimmutable):
            ito = t;
            goto L6;

        case X(MODwild, MODshared):
            sto = t;
            goto L6;

        case X(MODwild, MODshared | MODconst):
            scto = t;
            goto L6;

        case X(MODwild, MODshared | MODwild):
            swto = t;
        L6:
            t->wto = this;
            break;


        case X(MODshared | MODwild, 0):
            swto = NULL;
            goto L7;

        case X(MODshared | MODwild, MODconst):
            cto = t;
            goto L7;

        case X(MODshared | MODwild, MODimmutable):
            ito = t;
            goto L7;

        case X(MODshared | MODwild, MODshared):
            sto = t;
            goto L7;

        case X(MODshared | MODwild, MODshared | MODconst):
            scto = t;
            goto L7;

        case X(MODshared | MODwild, MODwild):
            wto = t;
        L7:
            t->swto = this;
            break;


        default:
            assert(0);
    }
#undef X

    check();
    t->check();
    //printf("fixTo: %s, %s\n", toChars(), t->toChars());
}

/***************************
 * Look for bugs in constructing types.
 */

void Type::check()
{
    switch (mod)
    {
        case 0:
            if (cto) assert(cto->mod == MODconst);
            if (ito) assert(ito->mod == MODimmutable);
            if (sto) assert(sto->mod == MODshared);
            if (scto) assert(scto->mod == (MODshared | MODconst));
            if (wto) assert(wto->mod == MODwild);
            if (swto) assert(swto->mod == (MODshared | MODwild));
            break;

        case MODconst:
            if (cto) assert(cto->mod == 0);
            if (ito) assert(ito->mod == MODimmutable);
            if (sto) assert(sto->mod == MODshared);
            if (scto) assert(scto->mod == (MODshared | MODconst));
            if (wto) assert(wto->mod == MODwild);
            if (swto) assert(swto->mod == (MODshared | MODwild));
            break;

        case MODimmutable:
            if (cto) assert(cto->mod == MODconst);
            if (ito) assert(ito->mod == 0);
            if (sto) assert(sto->mod == MODshared);
            if (scto) assert(scto->mod == (MODshared | MODconst));
            if (wto) assert(wto->mod == MODwild);
            if (swto) assert(swto->mod == (MODshared | MODwild));
            break;

        case MODshared:
            if (cto) assert(cto->mod == MODconst);
            if (ito) assert(ito->mod == MODimmutable);
            if (sto) assert(sto->mod == 0);
            if (scto) assert(scto->mod == (MODshared | MODconst));
            if (wto) assert(wto->mod == MODwild);
            if (swto) assert(swto->mod == (MODshared | MODwild));
            break;

        case MODshared | MODconst:
            if (cto) assert(cto->mod == MODconst);
            if (ito) assert(ito->mod == MODimmutable);
            if (sto) assert(sto->mod == MODshared);
            if (scto) assert(scto->mod == 0);
            if (wto) assert(wto->mod == MODwild);
            if (swto) assert(swto->mod == (MODshared | MODwild));
            break;

        case MODwild:
            if (cto) assert(cto->mod == MODconst);
            if (ito) assert(ito->mod == MODimmutable);
            if (sto) assert(sto->mod == MODshared);
            if (scto) assert(scto->mod == (MODshared | MODconst));
            if (wto) assert(wto->mod == 0);
            if (swto) assert(swto->mod == (MODshared | MODwild));
            break;

        case MODshared | MODwild:
            if (cto) assert(cto->mod == MODconst);
            if (ito) assert(ito->mod == MODimmutable);
            if (sto) assert(sto->mod == MODshared);
            if (scto) assert(scto->mod == (MODshared | MODconst));
            if (wto) assert(wto->mod == MODwild);
            if (swto) assert(swto->mod == 0);
            break;

        default:
            assert(0);
    }

    Type *tn = nextOf();
    if (tn && ty != Tfunction && tn->ty != Tfunction)
    {   // Verify transitivity
        switch (mod)
        {
            case 0:
                break;

            case MODconst:
                assert(tn->mod & MODimmutable || tn->mod & MODconst);
                break;

            case MODimmutable:
                assert(tn->mod == MODimmutable);
                break;

            case MODshared:
                assert(tn->mod & MODimmutable || tn->mod & MODshared);
                break;

            case MODshared | MODconst:
                assert(tn->mod & MODimmutable || tn->mod & (MODshared | MODconst));
                break;

            case MODwild:
                assert(tn->mod);
                break;

            case MODshared | MODwild:
                assert(tn->mod == MODimmutable || tn->mod == (MODshared | MODconst) || tn->mod == (MODshared | MODwild));
                break;

            default:
                assert(0);
        }
        tn->check();
    }
}

Type *Type::makeConst()
{
    //printf("Type::makeConst() %p, %s\n", this, toChars());
    if (cto)
        return cto;
    unsigned sz = sizeTy[ty];
    Type *t = (Type *)mem.malloc(sz);
    memcpy(t, this, sz);
    t->mod = MODconst;
    t->deco = NULL;
    t->arrayof = NULL;
    t->pto = NULL;
    t->rto = NULL;
    t->cto = NULL;
    t->ito = NULL;
    t->sto = NULL;
    t->scto = NULL;
    t->wto = NULL;
    t->swto = NULL;
    t->vtinfo = NULL;
    //printf("-Type::makeConst() %p, %s\n", t, toChars());
    return t;
}

Type *Type::makeInvariant()
{
    if (ito)
        return ito;
    unsigned sz = sizeTy[ty];
    Type *t = (Type *)mem.malloc(sz);
    memcpy(t, this, sz);
    t->mod = MODimmutable;
    t->deco = NULL;
    t->arrayof = NULL;
    t->pto = NULL;
    t->rto = NULL;
    t->cto = NULL;
    t->ito = NULL;
    t->sto = NULL;
    t->scto = NULL;
    t->wto = NULL;
    t->swto = NULL;
    t->vtinfo = NULL;
    return t;
}

Type *Type::makeShared()
{
    if (sto)
        return sto;
    unsigned sz = sizeTy[ty];
    Type *t = (Type *)mem.malloc(sz);
    memcpy(t, this, sz);
    t->mod = MODshared;
    t->deco = NULL;
    t->arrayof = NULL;
    t->pto = NULL;
    t->rto = NULL;
    t->cto = NULL;
    t->ito = NULL;
    t->sto = NULL;
    t->scto = NULL;
    t->wto = NULL;
    t->swto = NULL;
    t->vtinfo = NULL;
    return t;
}

Type *Type::makeSharedConst()
{
    if (scto)
        return scto;
    unsigned sz = sizeTy[ty];
    Type *t = (Type *)mem.malloc(sz);
    memcpy(t, this, sz);
    t->mod = MODshared | MODconst;
    t->deco = NULL;
    t->arrayof = NULL;
    t->pto = NULL;
    t->rto = NULL;
    t->cto = NULL;
    t->ito = NULL;
    t->sto = NULL;
    t->scto = NULL;
    t->wto = NULL;
    t->swto = NULL;
    t->vtinfo = NULL;
    return t;
}

Type *Type::makeWild()
{
    if (wto)
        return wto;
    unsigned sz = sizeTy[ty];
    Type *t = (Type *)mem.malloc(sz);
    memcpy(t, this, sz);
    t->mod = MODwild;
    t->deco = NULL;
    t->arrayof = NULL;
    t->pto = NULL;
    t->rto = NULL;
    t->cto = NULL;
    t->ito = NULL;
    t->sto = NULL;
    t->scto = NULL;
    t->wto = NULL;
    t->swto = NULL;
    t->vtinfo = NULL;
    return t;
}

Type *Type::makeSharedWild()
{
    if (swto)
        return swto;
    unsigned sz = sizeTy[ty];
    Type *t = (Type *)mem.malloc(sz);
    memcpy(t, this, sz);
    t->mod = MODshared | MODwild;
    t->deco = NULL;
    t->arrayof = NULL;
    t->pto = NULL;
    t->rto = NULL;
    t->cto = NULL;
    t->ito = NULL;
    t->sto = NULL;
    t->scto = NULL;
    t->wto = NULL;
    t->swto = NULL;
    t->vtinfo = NULL;
    return t;
}

Type *Type::makeMutable()
{
    unsigned sz = sizeTy[ty];
    Type *t = (Type *)mem.malloc(sz);
    memcpy(t, this, sz);
    t->mod =  mod & MODshared;
    t->deco = NULL;
    t->arrayof = NULL;
    t->pto = NULL;
    t->rto = NULL;
    t->cto = NULL;
    t->ito = NULL;
    t->sto = NULL;
    t->scto = NULL;
    t->wto = NULL;
    t->swto = NULL;
    t->vtinfo = NULL;
    return t;
}

/************************************
 * Apply MODxxxx bits to existing type.
 */

Type *Type::castMod(unsigned mod)
{   Type *t;

    switch (mod)
    {
        case 0:
            t = unSharedOf()->mutableOf();
            break;

        case MODconst:
            t = unSharedOf()->constOf();
            break;

        case MODimmutable:
            t = invariantOf();
            break;

        case MODshared:
            t = mutableOf()->sharedOf();
            break;

        case MODshared | MODconst:
            t = sharedConstOf();
            break;

        case MODwild:
            t = unSharedOf()->wildOf();
            break;

        case MODshared | MODwild:
            t = sharedWildOf();
            break;

        default:
            assert(0);
    }
    return t;
}

/************************************
 * Add MODxxxx bits to existing type.
 * We're adding, not replacing, so adding const to
 * a shared type => "shared const"
 */

Type *Type::addMod(unsigned mod)
{   Type *t = this;

    /* Add anything to immutable, and it remains immutable
     */
    if (!t->isImmutable())
    {
        //printf("addMod(%x) %s\n", mod, toChars());
        switch (mod)
        {
            case 0:
                break;

            case MODconst:
                if (isShared())
                    t = sharedConstOf();
                else
                    t = constOf();
                break;

            case MODimmutable:
                t = invariantOf();
                break;

            case MODshared:
                if (isConst())
                    t = sharedConstOf();
                else if (isWild())
                    t = sharedWildOf();
                else
                    t = sharedOf();
                break;

            case MODshared | MODconst:
                t = sharedConstOf();
                break;

            case MODwild:
                if (isConst())
                    ;
                else if (isShared())
                    t = sharedWildOf();
                else
                    t = wildOf();
                break;

            case MODshared | MODwild:
                t = sharedWildOf();
                break;

            default:
                assert(0);
        }
    }
    return t;
}

/************************************
 * Add storage class modifiers to type.
 */

Type *Type::addStorageClass(StorageClass stc)
{
    /* Just translate to MOD bits and let addMod() do the work
     */
    unsigned mod = 0;

    if (stc & STCimmutable)
        mod = MODimmutable;
    else
    {   if (stc & (STCconst | STCin))
            mod = MODconst;
        else if (stc & STCwild)         // const takes precedence over wild
            mod |= MODwild;
        if (stc & STCshared)
            mod |= MODshared;
    }
    return addMod(mod);
}

/**************************
 * Return type with the top level of it being mutable.
 */
Type *Type::toHeadMutable()
{
    if (!mod)
        return this;
    return mutableOf();
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

/***************************
 * Return !=0 if modfrom can be implicitly converted to modto
 */
int MODimplicitConv(unsigned char modfrom, unsigned char modto)
{
    if (modfrom == modto)
        return 1;

    //printf("MODimplicitConv(from = %x, to = %x)\n", modfrom, modto);
    #define X(m, n) (((m) << 4) | (n))
    switch (X(modfrom, modto))
    {
        case X(0,            MODconst):
        case X(MODimmutable, MODconst):
        case X(MODwild,      MODconst):
        case X(MODimmutable, MODconst | MODshared):
        case X(MODshared,    MODconst | MODshared):
        case X(MODwild | MODshared,    MODconst | MODshared):
            return 1;

        default:
            return 0;
    }
    #undef X
}

/***************************
 * Merge mod bits to form common mod.
 */
int MODmerge(unsigned char mod1, unsigned char mod2)
{
    if (mod1 == mod2)
        return mod1;

    //printf("MODmerge(1 = %x, 2 = %x)\n", modfrom, modto);
    #define X(m, n) (((m) << 4) | (n))
    // cases are commutative
    #define Y(m, n) X(m, n): case X(n, m)
    switch (X(mod1, mod2))
    {
#if 0
        case X(0, 0):
        case X(MODconst, MODconst):
        case X(MODimmutable, MODimmutable):
        case X(MODshared, MODshared):
        case X(MODshared | MODconst, MODshared | MODconst):
        case X(MODwild, MODwild):
        case X(MODshared | MODwild, MODshared | MODwild):
#endif

        case Y(0, MODconst):
        case Y(0, MODimmutable):
        case Y(MODconst, MODimmutable):
        case Y(MODconst, MODwild):
        case Y(0, MODwild):
        case Y(MODimmutable, MODwild):
            return MODconst;

        case Y(0, MODshared):
            return MODshared;

        case Y(0, MODshared | MODconst):
        case Y(MODconst, MODshared):
        case Y(MODconst, MODshared | MODconst):
        case Y(MODimmutable, MODshared):
        case Y(MODimmutable, MODshared | MODconst):
        case Y(MODshared, MODshared | MODconst):
        case Y(0, MODshared | MODwild):
        case Y(MODconst, MODshared | MODwild):
        case Y(MODimmutable, MODshared | MODwild):
        case Y(MODshared, MODwild):
        case Y(MODshared, MODshared | MODwild):
        case Y(MODshared | MODconst, MODwild):
        case Y(MODshared | MODconst, MODshared | MODwild):
            return MODshared | MODconst;

        case Y(MODwild, MODshared | MODwild):
            return MODshared | MODwild;

        default:
            assert(0);
    }
    #undef Y
    #undef X
    assert(0);
    return 0;
}

/*********************************
 * Mangling for mod.
 */
void MODtoDecoBuffer(OutBuffer *buf, unsigned char mod)
{
    switch (mod)
    {   case 0:
            break;
        case MODconst:
            buf->writeByte('x');
            break;
        case MODimmutable:
            buf->writeByte('y');
            break;
        case MODshared:
            buf->writeByte('O');
            break;
        case MODshared | MODconst:
            buf->writestring("Ox");
            break;
        case MODwild:
            buf->writestring("Ng");
            break;
        case MODshared | MODwild:
            buf->writestring("ONg");
            break;
        default:
            assert(0);
    }
}

/*********************************
 * Name for mod.
 */
void MODtoBuffer(OutBuffer *buf, unsigned char mod)
{
    switch (mod)
    {   case 0:
            break;

        case MODimmutable:
            buf->writestring(Token::tochars[TOKimmutable]);
            break;

        case MODshared:
            buf->writestring(Token::tochars[TOKshared]);
            break;

        case MODshared | MODconst:
            buf->writestring(Token::tochars[TOKshared]);
            buf->writeByte(' ');
        case MODconst:
            buf->writestring(Token::tochars[TOKconst]);
            break;

        case MODshared | MODwild:
            buf->writestring(Token::tochars[TOKshared]);
            buf->writeByte(' ');
        case MODwild:
            buf->writestring(Token::tochars[TOKwild]);
            break;
        default:
            assert(0);
    }
}

/********************************
 * Name mangling.
 * Input:
 *      flag    0x100   do not do const/invariant
 */

void Type::toDecoBuffer(OutBuffer *buf, int flag)
{
    if (flag != mod && flag != 0x100)
    {
        MODtoDecoBuffer(buf, mod);
    }
    buf->writeByte(mangleChar[ty]);
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
    {
        if (this->mod & MODshared)
        {
            MODtoBuffer(buf, this->mod & MODshared);
            buf->writeByte('(');
        }
        if (this->mod & ~MODshared)
        {
            MODtoBuffer(buf, this->mod & ~MODshared);
            buf->writeByte('(');
            toCBuffer2(buf, hgs, this->mod);
            buf->writeByte(')');
        }
        else
            toCBuffer2(buf, hgs, this->mod);
        if (this->mod & MODshared)
        {
            buf->writeByte(')');
        }
    }
}

void Type::modToBuffer(OutBuffer *buf)
{
    if (mod)
    {
        buf->writeByte(' ');
        MODtoBuffer(buf, mod);
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

        //if (next)
            //next = next->merge();
        toDecoBuffer(&buf);
        sv = stringtable.update((char *)buf.data, buf.offset);
        if (sv->ptrvalue)
        {   t = (Type *) sv->ptrvalue;
#ifdef DEBUG
            if (!t->deco)
                printf("t = %s\n", t->toChars());
#endif
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

/**************************
 * Given:
 *      T a, b;
 * Can we assign:
 *      a = b;
 * ?
 */
int Type::isAssignable()
{
    return TRUE;
}

int Type::checkBoolean()
{
    return isscalar();
}

/********************************
 * TRUE if when type goes out of scope, it needs a destructor applied.
 * Only applies to value types, not ref types.
 */
int Type::needsDestruction()
{
    return FALSE;
}

/*********************************
 * Check type to see if it is based on a deprecated symbol.
 */

void Type::checkDeprecated(Loc loc, Scope *sc)
{
    Dsymbol *s = toDsymbol(sc);

    if (s)
        s->checkDeprecated(loc, sc);
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
 *      MATCHnomatch, MATCHconvert, MATCHconst, MATCHexact
 */

MATCH Type::implicitConvTo(Type *to)
{
    //printf("Type::implicitConvTo(this=%p, to=%p)\n", this, to);
    //printf("from: %s\n", toChars());
    //printf("to  : %s\n", to->toChars());
    if (this == to)
        return MATCHexact;
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
        e = new ErrorExp();
    }
    else if (ident == Id::__xalignof)
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
        if (ty == Tfunction)
            error(loc, "function does not have an initializer");
        e = defaultInitLiteral(loc);
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
                    if (e->op == TOKassign || e->op == TOKconstruct || e->op == TOKblit)
                    {
                        e = ((AssignExp *)e)->e2;

                        /* Take care of case where we used a 0
                         * to initialize the struct.
                         */
                        if (e->type == Type::tint32 &&
                            e->isBool(0) &&
                            v->type->toBasetype()->ty == Tstruct)
                        {
                            e = v->type->defaultInit(e->loc);
                        }
                    }
                    e = e->optimize(WANTvalue | WANTinterpret);
//                  if (!e->isConst())
//                      error(loc, ".init cannot be evaluated at compile time");
                }
                goto Lreturn;
            }
#endif
            e = defaultInitLiteral(e->loc);
            goto Lreturn;
        }
    }
    if (ident == Id::typeinfo)
    {
        if (!global.params.useDeprecated)
            error(e->loc, ".typeinfo deprecated, use typeid(type)");
        e = getTypeInfo(sc);
    }
    else if (ident == Id::stringof)
    {   /* Bugzilla 3796: this should demangle e->type->deco rather than
         * pretty-printing the type.
         */
        char *s = e->toChars();
        e = new StringExp(e->loc, s, strlen(s), 'c');
    }
    else
        e = getProperty(e->loc, ident);

Lreturn:
    e = e->semantic(sc);
    return e;
}

/***************************************
 * Figures out what to do with an undefined member reference
 * for classes and structs.
 */
Expression *Type::noMember(Scope *sc, Expression *e, Identifier *ident)
{
    assert(ty == Tstruct || ty == Tclass);
    AggregateDeclaration *sym = toDsymbol(sc)->isAggregateDeclaration();
    assert(sym);

    if (ident != Id::__sizeof &&
        ident != Id::__xalignof &&
        ident != Id::init &&
        ident != Id::mangleof &&
        ident != Id::stringof &&
        ident != Id::offsetof)
    {
        /* Look for overloaded opDot() to see if we should forward request
         * to it.
         */
        Dsymbol *fd = search_function(sym, Id::opDot);
        if (fd)
        {   /* Rewrite e.ident as:
             *  e.opDot().ident
             */
            e = build_overload(e->loc, sc, e, NULL, fd);
            e = new DotIdExp(e->loc, e, ident);
            return e->semantic(sc);
        }

        /* Look for overloaded opDispatch to see if we should forward request
         * to it.
         */
        fd = search_function(sym, Id::opDispatch);
        if (fd)
        {
            /* Rewrite e.ident as:
             *  e.opDispatch!("ident")
             */
            TemplateDeclaration *td = fd->isTemplateDeclaration();
            if (!td)
            {
                fd->error("must be a template opDispatch(string s), not a %s", fd->kind());
                return new ErrorExp();
            }
            StringExp *se = new StringExp(e->loc, ident->toChars());
            Objects *tiargs = new Objects();
            tiargs->push(se);
            e = new DotTemplateInstanceExp(e->loc, e, Id::opDispatch, tiargs);
            ((DotTemplateInstanceExp *)e)->ti->tempdecl = td;
            return e;
            //return e->semantic(sc);
        }

        /* See if we should forward to the alias this.
         */
        if (sym->aliasthis)
        {   /* Rewrite e.ident as:
             *  e.aliasthis.ident
             */
            e = new DotIdExp(e->loc, e, sym->aliasthis->ident);
            e = new DotIdExp(e->loc, e, ident);
            return e->semantic(sc);
        }
    }

    return Type::dotExp(sc, e, ident);
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
    sprintf(name, "D%dTypeInfo_%s6__initZ", 9 + len, buf.data);
#else
    sprintf(name, "_D%dTypeInfo_%s6__initZ", 9 + len, buf.data);
#endif
    if (global.params.isWindows)
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
    return NULL;
}

/***************************************
 * Return !=0 if the type or any of its subtypes is wild.
 */

int Type::hasWild()
{
    return mod & MODwild;
}

/***************************************
 * Return MOD bits matching argument type (targ) to wild parameter type (this).
 */

unsigned Type::wildMatch(Type *targ)
{
    return 0;
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
    //printf("Type::hasPointers() %s, %d\n", toChars(), ty);
    return FALSE;
}

/*************************************
 * If this is a type of something, return that something.
 */

Type *Type::nextOf()
{
    return NULL;
}

/****************************************
 * Return the mask that an integral type will
 * fit into.
 */
uinteger_t Type::sizemask()
{   uinteger_t m;

    switch (toBasetype()->ty)
    {
        case Tbool:     m = 1;                          break;
        case Tchar:
        case Tint8:
        case Tuns8:     m = 0xFF;                       break;
        case Twchar:
        case Tint16:
        case Tuns16:    m = 0xFFFFUL;                   break;
        case Tdchar:
        case Tint32:
        case Tuns32:    m = 0xFFFFFFFFUL;               break;
        case Tint64:
        case Tuns64:    m = 0xFFFFFFFFFFFFFFFFULL;      break;
        default:
                assert(0);
    }
    return m;
}

/* ============================= TypeError =========================== */

TypeError::TypeError()
        : Type(Terror)
{
}

void TypeError::toCBuffer(OutBuffer *buf, Identifier *ident, HdrGenState *hgs)
{
    buf->writestring("_error_");
}

d_uns64 TypeError::size(Loc loc) { return 1; }
Expression *TypeError::getProperty(Loc loc, Identifier *ident) { return new ErrorExp(); }
Expression *TypeError::dotExp(Scope *sc, Expression *e, Identifier *ident) { return new ErrorExp(); }
Expression *TypeError::defaultInit(Loc loc) { return new ErrorExp(); }
Expression *TypeError::defaultInitLiteral(Loc loc) { return new ErrorExp(); }

/* ============================= TypeNext =========================== */

TypeNext::TypeNext(TY ty, Type *next)
        : Type(ty)
{
    this->next = next;
}

void TypeNext::toDecoBuffer(OutBuffer *buf, int flag)
{
    Type::toDecoBuffer(buf, flag);
    assert(next != this);
    //printf("this = %p, ty = %d, next = %p, ty = %d\n", this, this->ty, next, next->ty);
    next->toDecoBuffer(buf, (flag & 0x100) ? 0 : mod);
}

void TypeNext::checkDeprecated(Loc loc, Scope *sc)
{
    Type::checkDeprecated(loc, sc);
    if (next)   // next can be NULL if TypeFunction and auto return type
        next->checkDeprecated(loc, sc);
}


Type *TypeNext::reliesOnTident()
{
    return next->reliesOnTident();
}

int TypeNext::hasWild()
{
    return mod == MODwild || next->hasWild();
}

/***************************************
 * Return MOD bits matching argument type (targ) to wild parameter type (this).
 */

unsigned TypeNext::wildMatch(Type *targ)
{   unsigned mod;

    Type *tb = targ->nextOf();
    if (!tb)
        return 0;
    tb = tb->toBasetype();
    if (tb->isMutable())
        mod = MODmutable;
    else if (tb->isConst() || tb->isWild())
        return MODconst;
    else if (tb->isImmutable())
        mod = MODimmutable;
    else
        assert(0);
    mod |= next->wildMatch(tb);
    return mod;
}


/*******************************
 * For TypeFunction, nextOf() can return NULL if the function return
 * type is meant to be inferred, and semantic() hasn't yet ben run
 * on the function. After semantic(), it must no longer be NULL.
 */

Type *TypeNext::nextOf()
{
    return next;
}

Type *TypeNext::makeConst()
{
    //printf("TypeNext::makeConst() %p, %s\n", this, toChars());
    if (cto)
    {   assert(cto->mod == MODconst);
        return cto;
    }
    TypeNext *t = (TypeNext *)Type::makeConst();
    if (ty != Tfunction && next->ty != Tfunction &&
        //(next->deco || next->ty == Tfunction) &&
        !next->isImmutable() && !next->isConst())
    {   if (next->isShared())
            t->next = next->sharedConstOf();
        else
            t->next = next->constOf();
    }
    if (ty == Taarray)
    {
        ((TypeAArray *)t)->impl = NULL;         // lazily recompute it
    }
    //printf("TypeNext::makeConst() returns %p, %s\n", t, t->toChars());
    return t;
}

Type *TypeNext::makeInvariant()
{
    //printf("TypeNext::makeInvariant() %s\n", toChars());
    if (ito)
    {   assert(ito->isImmutable());
        return ito;
    }
    TypeNext *t = (TypeNext *)Type::makeInvariant();
    if (ty != Tfunction && next->ty != Tfunction &&
        //(next->deco || next->ty == Tfunction) &&
        !next->isImmutable())
    {   t->next = next->invariantOf();
    }
    if (ty == Taarray)
    {
        ((TypeAArray *)t)->impl = NULL;         // lazily recompute it
    }
    return t;
}

Type *TypeNext::makeShared()
{
    //printf("TypeNext::makeShared() %s\n", toChars());
    if (sto)
    {   assert(sto->mod == MODshared);
        return sto;
    }
    TypeNext *t = (TypeNext *)Type::makeShared();
    if (ty != Tfunction && next->ty != Tfunction &&
        //(next->deco || next->ty == Tfunction) &&
        !next->isImmutable() && !next->isShared())
    {
        if (next->isConst() || next->isWild())
            t->next = next->sharedConstOf();
        else
            t->next = next->sharedOf();
    }
    if (ty == Taarray)
    {
        ((TypeAArray *)t)->impl = NULL;         // lazily recompute it
    }
    //printf("TypeNext::makeShared() returns %p, %s\n", t, t->toChars());
    return t;
}

Type *TypeNext::makeSharedConst()
{
    //printf("TypeNext::makeSharedConst() %s\n", toChars());
    if (scto)
    {   assert(scto->mod == (MODshared | MODconst));
        return scto;
    }
    TypeNext *t = (TypeNext *)Type::makeSharedConst();
    if (ty != Tfunction && next->ty != Tfunction &&
        //(next->deco || next->ty == Tfunction) &&
        !next->isImmutable() && !next->isSharedConst())
    {
        t->next = next->sharedConstOf();
    }
    if (ty == Taarray)
    {
        ((TypeAArray *)t)->impl = NULL;         // lazily recompute it
    }
    //printf("TypeNext::makeSharedConst() returns %p, %s\n", t, t->toChars());
    return t;
}

Type *TypeNext::makeWild()
{
    //printf("TypeNext::makeWild() %s\n", toChars());
    if (wto)
    {   assert(wto->mod == MODwild);
        return wto;
    }
    TypeNext *t = (TypeNext *)Type::makeWild();
    if (ty != Tfunction && next->ty != Tfunction &&
        //(next->deco || next->ty == Tfunction) &&
        !next->isImmutable() && !next->isConst() && !next->isWild())
    {
        if (next->isShared())
            t->next = next->sharedWildOf();
        else
            t->next = next->wildOf();
    }
    if (ty == Taarray)
    {
        ((TypeAArray *)t)->impl = NULL;         // lazily recompute it
    }
    //printf("TypeNext::makeWild() returns %p, %s\n", t, t->toChars());
    return t;
}

Type *TypeNext::makeSharedWild()
{
    //printf("TypeNext::makeSharedWild() %s\n", toChars());
    if (swto)
    {   assert(swto->isSharedWild());
        return swto;
    }
    TypeNext *t = (TypeNext *)Type::makeSharedWild();
    if (ty != Tfunction && next->ty != Tfunction &&
        //(next->deco || next->ty == Tfunction) &&
        !next->isImmutable() && !next->isSharedConst())
    {
        t->next = next->sharedWildOf();
    }
    if (ty == Taarray)
    {
        ((TypeAArray *)t)->impl = NULL;         // lazily recompute it
    }
    //printf("TypeNext::makeSharedWild() returns %p, %s\n", t, t->toChars());
    return t;
}

Type *TypeNext::makeMutable()
{
    //printf("TypeNext::makeMutable() %p, %s\n", this, toChars());
    TypeNext *t = (TypeNext *)Type::makeMutable();
    if ((ty != Tfunction && next->ty != Tfunction &&
        //(next->deco || next->ty == Tfunction) &&
        next->isWild()) || ty == Tsarray)
    {
        t->next = next->mutableOf();
    }
    if (ty == Taarray)
    {
        ((TypeAArray *)t)->impl = NULL;         // lazily recompute it
    }
    //printf("TypeNext::makeMutable() returns %p, %s\n", t, t->toChars());
    return t;
}

MATCH TypeNext::constConv(Type *to)
{   MATCH m = Type::constConv(to);

    if (m == MATCHconst &&
        next->constConv(((TypeNext *)to)->next) == MATCHnomatch)
        m = MATCHnomatch;
    return m;
}


void TypeNext::transitive()
{
    /* Invoke transitivity of type attributes
     */
    next = next->addMod(mod);
}

/* ============================= TypeBasic =========================== */

TypeBasic::TypeBasic(TY ty)
        : Type(ty)
{   const char *d;
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
                        break;

        case Tint8:     d = Token::toChars(TOKint8);
                        flags |= TFLAGSintegral;
                        break;

        case Tuns8:     d = Token::toChars(TOKuns8);
                        flags |= TFLAGSintegral | TFLAGSunsigned;
                        break;

        case Tint16:    d = Token::toChars(TOKint16);
                        flags |= TFLAGSintegral;
                        break;

        case Tuns16:    d = Token::toChars(TOKuns16);
                        flags |= TFLAGSintegral | TFLAGSunsigned;
                        break;

        case Tint32:    d = Token::toChars(TOKint32);
                        flags |= TFLAGSintegral;
                        break;

        case Tuns32:    d = Token::toChars(TOKuns32);
                        flags |= TFLAGSintegral | TFLAGSunsigned;
                        break;

        case Tfloat32:  d = Token::toChars(TOKfloat32);
                        flags |= TFLAGSfloating | TFLAGSreal;
                        break;

        case Tint64:    d = Token::toChars(TOKint64);
                        flags |= TFLAGSintegral;
                        break;

        case Tuns64:    d = Token::toChars(TOKuns64);
                        flags |= TFLAGSintegral | TFLAGSunsigned;
                        break;

        case Tfloat64:  d = Token::toChars(TOKfloat64);
                        flags |= TFLAGSfloating | TFLAGSreal;
                        break;

        case Tfloat80:  d = Token::toChars(TOKfloat80);
                        flags |= TFLAGSfloating | TFLAGSreal;
                        break;

        case Timaginary32: d = Token::toChars(TOKimaginary32);
                        flags |= TFLAGSfloating | TFLAGSimaginary;
                        break;

        case Timaginary64: d = Token::toChars(TOKimaginary64);
                        flags |= TFLAGSfloating | TFLAGSimaginary;
                        break;

        case Timaginary80: d = Token::toChars(TOKimaginary80);
                        flags |= TFLAGSfloating | TFLAGSimaginary;
                        break;

        case Tcomplex32: d = Token::toChars(TOKcomplex32);
                        flags |= TFLAGSfloating | TFLAGScomplex;
                        break;

        case Tcomplex64: d = Token::toChars(TOKcomplex64);
                        flags |= TFLAGSfloating | TFLAGScomplex;
                        break;

        case Tcomplex80: d = Token::toChars(TOKcomplex80);
                        flags |= TFLAGSfloating | TFLAGScomplex;
                        break;

        case Tbool:     d = "bool";
                        flags |= TFLAGSintegral | TFLAGSunsigned;
                        break;

        case Tascii:    d = Token::toChars(TOKchar);
                        flags |= TFLAGSintegral | TFLAGSunsigned;
                        break;

        case Twchar:    d = Token::toChars(TOKwchar);
                        flags |= TFLAGSintegral | TFLAGSunsigned;
                        break;

        case Tdchar:    d = Token::toChars(TOKdchar);
                        flags |= TFLAGSintegral | TFLAGSunsigned;
                        break;

        default:        assert(0);
    }
    this->dstring = d;
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
    return Type::toChars();
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
                        size = REALSIZE;        break;
        case Tcomplex32:
                        size = 8;               break;
        case Tcomplex64:
                        size = 16;              break;
        case Tcomplex80:
                        size = REALSIZE * 2;    break;

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
            sz = REALALIGNSIZE;
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
            case Tfloat32:
            case Tcomplex64:
            case Timaginary64:
            case Tfloat64:
            case Tcomplex80:
            case Timaginary80:
            case Tfloat80:
                                // For backwards compatibility - eventually, deprecate
                                goto Lmin_normal;
        }
    }
    else if (ident == Id::min_normal)
    {
      Lmin_normal:
        switch (ty)
        {
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
                e = new RealExp(0, 0.0, t);
                break;

            default:
                e = Type::getProperty(e->loc, ident);
                break;
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
                e = e->copy();
                e->type = t;
                break;

            case Tfloat32:
            case Tfloat64:
            case Tfloat80:
                e = new RealExp(0, 0.0, this);
                break;

            default:
                e = Type::getProperty(e->loc, ident);
                break;
        }
    }
    else
    {
        return Type::dotExp(sc, e, ident);
    }
    e = e->semantic(sc);
    return e;
}

Expression *TypeBasic::defaultInit(Loc loc)
{   dinteger_t value = 0;

#if SNAN_DEFAULT_INIT
    /*
     * Use a payload which is different from the machine NaN,
     * so that uninitialised variables can be
     * detected even if exceptions are disabled.
     */
    union
    {   unsigned short us[8];
        long double    ld;
    } snan = {{ 0, 0, 0, 0xA000, 0x7FFF }};
    /*
     * Although long doubles are 10 bytes long, some
     * C ABIs pad them out to 12 or even 16 bytes, so
     * leave enough space in the snan array.
     */
    assert(REALSIZE <= sizeof(snan));
    d_float80 fvalue = snan.ld;
#endif

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
#if SNAN_DEFAULT_INIT
            return new RealExp(loc, fvalue, this);
#else
            return getProperty(loc, Id::nan);
#endif

        case Tcomplex32:
        case Tcomplex64:
        case Tcomplex80:
#if SNAN_DEFAULT_INIT
        {   // Can't use fvalue + I*fvalue (the im part becomes a quiet NaN).
            complex_t cvalue;
            ((real_t *)&cvalue)[0] = fvalue;
            ((real_t *)&cvalue)[1] = fvalue;
            return new ComplexExp(loc, cvalue, this);
        }
#else
            return getProperty(loc, Id::nan);
#endif

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
    }
    return 1;                   // yes
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
    : TypeNext(ty, next)
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
    else if (ident == Id::reverse || ident == Id::dup || ident == Id::idup)
    {
        Expression *ec;
        FuncDeclaration *fd;
        Expressions *arguments;
        int size = next->size(e->loc);
        int dup;

        assert(size);
        dup = (ident == Id::dup || ident == Id::idup);
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
        if (ident == Id::idup)
        {   Type *einv = next->invariantOf();
            if (next->implicitConvTo(einv) < MATCHconst)
                error(e->loc, "cannot implicitly convert element type %s to immutable", next->toChars());
            e->type = einv->arrayOf();
        }
        else
            e->type = next->mutableOf()->arrayOf();
    }
    else if (ident == Id::sort)
    {
        Expression *ec;
        FuncDeclaration *fd;
        Expressions *arguments;

        fd = FuncDeclaration::genCfunc(tint32->arrayOf(), "_adSort");
        ec = new VarExp(0, fd);
        e = e->castTo(sc, n->arrayOf());        // convert to dynamic array
        arguments = new Expressions();
        arguments->push(e);
        arguments->push(n->ty == Tsarray
                    ? n->getTypeInfo(sc)        // don't convert to dynamic array
                    : n->getInternalTypeInfo(sc));
        e = new CallExp(e->loc, ec, arguments);
        e->type = next->arrayOf();
    }
    else
    {
        e = Type::dotExp(sc, e, ident);
    }
    e = e->semantic(sc);
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
    t->mod = mod;
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
    {   ScopeDsymbol *sym = new ArrayScopeSymbol(sc, (TypeTuple *)t);
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
    ScopeDsymbol *sym = new ArrayScopeSymbol(sc, s);
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
        Expression *e = new IndexExp(loc, *pe, dim);
        *pe = e;
    }
    else if (*ps)
    {   Dsymbol *s = *ps;
        TupleDeclaration *td = s->isTupleDeclaration();
        if (td)
        {
            ScopeDsymbol *sym = new ArrayScopeSymbol(sc, td);
            sym->parent = sc->scopesym;
            sc = sc->push(sym);

            dim = dim->semantic(sc);
            dim = dim->optimize(WANTvalue | WANTinterpret);
            uinteger_t d = dim->toUInteger();

            sc = sc->pop();

            if (d >= td->objects->dim)
            {   error(loc, "tuple index %ju exceeds length %u", d, td->objects->dim);
                goto Ldefault;
            }
            Object *o = td->objects->tdata()[(size_t)d];
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
            objects->tdata()[0] = o;

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
        dim = dim->optimize(WANTvalue | WANTinterpret);
        uinteger_t d = dim->toUInteger();

        if (d >= sd->objects->dim)
        {   error(loc, "tuple index %ju exceeds %u", d, sd->objects->dim);
            return Type::terror;
        }
        Object *o = sd->objects->tdata()[(size_t)d];
        if (o->dyncast() != DYNCAST_TYPE)
        {   error(loc, "%s is not a type", toChars());
            return Type::terror;
        }
        t = (Type *)o;
        return t;
    }

    next = next->semantic(loc,sc);
    transitive();

    Type *tbn = next->toBasetype();

    if (dim)
    {   dinteger_t n, n2;

        dim = semanticLength(sc, tbn, dim);

        dim = dim->optimize(WANTvalue);
        if (sc && sc->parameterSpecialization && dim->op == TOKvar &&
            ((VarExp *)dim)->var->storage_class & STCtemplateparameter)
        {
            /* It could be a template parameter N which has no value yet:
             *   template Foo(T : T[N], size_t N);
             */
            return this;
        }
        dim = dim->optimize(WANTvalue | WANTinterpret);
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
        case Tstruct:
        {   TypeStruct *ts = (TypeStruct *)tbn;
            if (0 && ts->sym->isnested)
            {   error(loc, "cannot have static array of inner struct %s", ts->toChars());
                goto Lerror;
            }
            break;
        }
        case Tfunction:
        case Tnone:
            error(loc, "can't have array of %s", tbn->toChars());
            goto Lerror;
    }
    if (tbn->isscope())
    {   error(loc, "cannot have array of scope %s", tbn->toChars());
        goto Lerror;
    }

    /* Ensure things like const(immutable(T)[3]) become immutable(T[3])
     * and const(T)[3] become const(T[3])
     */
    t = addMod(next->mod);

    return t->merge();

Lerror:
    return Type::terror;
}

void TypeSArray::toDecoBuffer(OutBuffer *buf, int flag)
{
    Type::toDecoBuffer(buf, flag);
    if (dim)
        buf->printf("%ju", dim->toInteger());
    if (next)
        /* Note that static arrays are value types, so
         * for a parameter, propagate the 0x100 to the next
         * level, since for T[4][3], any const should apply to the T,
         * not the [4].
         */
        next->toDecoBuffer(buf,  (flag & 0x100) ? flag : mod);
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
    e = e->semantic(sc);
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

MATCH TypeSArray::constConv(Type *to)
{
    if (to->ty == Tsarray)
    {
        TypeSArray *tsa = (TypeSArray *)to;
        if (!dim->equals(tsa->dim))
            return MATCHnomatch;
    }
    return TypeNext::constConv(to);
}

MATCH TypeSArray::implicitConvTo(Type *to)
{
    //printf("TypeSArray::implicitConvTo(to = %s) this = %s\n", to->toChars(), toChars());

    // Allow implicit conversion of static array to pointer or dynamic array
    if (IMPLICIT_ARRAY_TO_PTR && to->ty == Tpointer)
    {
        TypePointer *tp = (TypePointer *)to;

        if (!MODimplicitConv(next->mod, tp->next->mod))
            return MATCHnomatch;

        if (tp->next->ty == Tvoid || next->constConv(tp->next) != MATCHnomatch)
        {
            return MATCHconvert;
        }
        return MATCHnomatch;
    }
    if (to->ty == Tarray)
    {   int offset = 0;
        TypeDArray *ta = (TypeDArray *)to;

        if (!MODimplicitConv(next->mod, ta->next->mod))
            return MATCHnomatch;

        if (next->equals(ta->next) ||
//          next->implicitConvTo(ta->next) >= MATCHconst ||
            next->constConv(ta->next) != MATCHnomatch ||
            (ta->next->isBaseOf(next, &offset) && offset == 0) ||
            ta->next->ty == Tvoid)
            return MATCHconvert;
        return MATCHnomatch;
    }
    if (to->ty == Tsarray)
    {
        if (this == to)
            return MATCHexact;

        TypeSArray *tsa = (TypeSArray *)to;

        if (dim->equals(tsa->dim))
        {
            /* Since static arrays are value types, allow
             * conversions from const elements to non-const
             * ones, just like we allow conversion from const int
             * to int.
             */
            MATCH m = next->implicitConvTo(tsa->next);
            if (m >= MATCHconst)
            {
                if (mod != to->mod)
                    m = MATCHconst;
                return m;
            }
        }
    }
    return MATCHnomatch;
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

int TypeSArray::needsDestruction()
{
    return next->needsDestruction();
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
        elements->tdata()[i] = elementinit;
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
    {   t = new TypeDArray(t);
        t->mod = mod;
    }
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
        case Tstruct:
        {   TypeStruct *ts = (TypeStruct *)tbn;
            if (0 && ts->sym->isnested)
                error(loc, "cannot have dynamic array of inner struct %s", ts->toChars());
            break;
        }
    }
    if (tn->isscope())
        error(loc, "cannot have array of scope %s", tn->toChars());

    next = tn;
    transitive();
    return merge();
}

void TypeDArray::toDecoBuffer(OutBuffer *buf, int flag)
{
    Type::toDecoBuffer(buf, flag);
    if (next)
        next->toDecoBuffer(buf, (flag & 0x100) ? 0 : mod);
}

void TypeDArray::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    if (mod != this->mod)
    {   toCBuffer3(buf, hgs, mod);
        return;
    }
    if (equals(tstring))
        buf->writestring("string");
    else
    {   next->toCBuffer2(buf, hgs, this->mod);
        buf->writestring("[]");
    }
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
    //printf("TypeDArray::implicitConvTo(to = %s) this = %s\n", to->toChars(), toChars());
    if (equals(to))
        return MATCHexact;

    // Allow implicit conversion of array to pointer
    if (IMPLICIT_ARRAY_TO_PTR && to->ty == Tpointer)
    {
        TypePointer *tp = (TypePointer *)to;

        /* Allow conversion to void*
         */
        if (tp->next->ty == Tvoid &&
            MODimplicitConv(next->mod, tp->next->mod))
        {
            return MATCHconvert;
        }

        return next->constConv(to);
    }

    if (to->ty == Tarray)
    {   int offset = 0;
        TypeDArray *ta = (TypeDArray *)to;

        if (!MODimplicitConv(next->mod, ta->next->mod))
            return MATCHnomatch;        // not const-compatible

        /* Allow conversion to void[]
         */
        if (next->ty != Tvoid && ta->next->ty == Tvoid)
        {
            return MATCHconvert;
        }

        MATCH m = next->constConv(ta->next);
        if (m != MATCHnomatch)
        {
            if (m == MATCHexact && mod != to->mod)
                m = MATCHconst;
            return m;
        }

#if 0
        /* Allow conversions of T[][] to const(T)[][]
         */
        if (mod == ta->mod && next->ty == Tarray && ta->next->ty == Tarray)
        {
            m = next->implicitConvTo(ta->next);
            if (m == MATCHconst)
                return m;
        }
#endif

        /* Conversion of array of derived to array of base
         */
        if (ta->next->isBaseOf(next, &offset) && offset == 0)
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
    this->impl = NULL;
    this->loc = 0;
    this->sc = NULL;
}

Type *TypeAArray::syntaxCopy()
{
    Type *t = next->syntaxCopy();
    Type *ti = index->syntaxCopy();
    if (t == next && ti == index)
        t = this;
    else
    {   t = new TypeAArray(t, ti);
        t->mod = mod;
    }
    return t;
}

d_uns64 TypeAArray::size(Loc loc)
{
    return PTRSIZE /* * 2*/;
}


Type *TypeAArray::semantic(Loc loc, Scope *sc)
{
    //printf("TypeAArray::semantic() %s index->ty = %d\n", toChars(), index->ty);
    this->loc = loc;
    this->sc = sc;
    if (sc)
        sc->setNoFree();

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
        {   index->error(loc, "index is not a type or an expression");
            return Type::terror;
        }
    }
    else
        index = index->semantic(loc,sc);

    if (index->nextOf() && !index->nextOf()->isImmutable())
    {
        index = index->constOf()->mutableOf();
#if 0
printf("index is %p %s\n", index, index->toChars());
index->check();
printf("index->mod = x%x\n", index->mod);
printf("index->ito = x%x\n", index->ito);
if (index->ito) {
printf("index->ito->mod = x%x\n", index->ito->mod);
printf("index->ito->ito = x%x\n", index->ito->ito);
}
#endif
    }

    switch (index->toBasetype()->ty)
    {
        case Tfunction:
        case Tvoid:
        case Tnone:
        case Ttuple:
            error(loc, "can't have associative array key of %s", index->toBasetype()->toChars());
            return Type::terror;
    }
    next = next->semantic(loc,sc);
    transitive();

    switch (next->toBasetype()->ty)
    {
        case Tfunction:
        case Tvoid:
        case Tnone:
            error(loc, "can't have associative array of %s", next->toChars());
            return Type::terror;
    }
    if (next->isscope())
    {   error(loc, "cannot have array of scope %s", next->toChars());
        return Type::terror;
    }
    return merge();
}

StructDeclaration *TypeAArray::getImpl()
{
    // Do it lazily
    if (!impl)
    {
        Type *index = this->index;
        Type *next = this->next;
        if (index->reliesOnTident() || next->reliesOnTident())
        {
            error(loc, "cannot create associative array %s", toChars());
            index = terror;
            next = terror;

            // Head off future failures
            StructDeclaration *s = new StructDeclaration(0, NULL);
            s->type = terror;
            impl = s;
            return impl;
        }
        /* This is really a proxy for the template instance AssocArray!(index, next)
         * But the instantiation can fail if it is a template specialization field
         * which has Tident's instead of real types.
         */
        Objects *tiargs = new Objects();
        tiargs->push(index);
        tiargs->push(next);

        // Create AssociativeArray!(index, next)
#if 1
        if (! Type::associativearray)
        {
            ObjectNotFound(Id::AssociativeArray);
        }
        TemplateInstance *ti = new TemplateInstance(loc, Type::associativearray, tiargs);
#else
        //Expression *e = new IdentifierExp(loc, Id::object);
        Expression *e = new IdentifierExp(loc, Id::empty);
        //e = new DotIdExp(loc, e, Id::object);
        DotTemplateInstanceExp *dti = new DotTemplateInstanceExp(loc,
                    e,
                    Id::AssociativeArray,
                    tiargs);
        dti->semantic(sc);
        TemplateInstance *ti = dti->ti;
#endif
        ti->semantic(sc);
        ti->semantic2(sc);
        ti->semantic3(sc);
        impl = ti->toAlias()->isStructDeclaration();
#ifdef DEBUG
        if (!impl)
        {   Dsymbol *s = ti->toAlias();
            printf("%s %s\n", s->kind(), s->toChars());
        }
#endif
        assert(impl);
    }
    return impl;
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
#if 0
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
        e->type = ((TypeFunction *)fd->type)->next;
    }
    else
    if (ident == Id::keys)
    {
        Expression *ec;
        FuncDeclaration *fd;
        Expressions *arguments;
        int size = index->size(e->loc);

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
        size_t keysize = index->size(e->loc);
        keysize = (keysize + PTRSIZE - 1) & ~(PTRSIZE - 1);
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
        arguments->push(index->getInternalTypeInfo(sc));
        e = new CallExp(e->loc, ec, arguments);
        e->type = this;
    }
    else
#endif
    if (ident != Id::__sizeof &&
        ident != Id::__xalignof &&
        ident != Id::init &&
        ident != Id::mangleof &&
        ident != Id::stringof &&
        ident != Id::offsetof)
    {
        e->type = getImpl()->type;
        e = e->type->dotExp(sc, e, ident);
    }
    else
        e = Type::dotExp(sc, e, ident);
    return e;
}

void TypeAArray::toDecoBuffer(OutBuffer *buf, int flag)
{
    Type::toDecoBuffer(buf, flag);
    index->toDecoBuffer(buf);
    next->toDecoBuffer(buf, (flag & 0x100) ? 0 : mod);
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

int TypeAArray::hasPointers()
{
    return TRUE;
}

MATCH TypeAArray::implicitConvTo(Type *to)
{
    //printf("TypeAArray::implicitConvTo(to = %s) this = %s\n", to->toChars(), toChars());
    if (equals(to))
        return MATCHexact;

    if (to->ty == Taarray)
    {   TypeAArray *ta = (TypeAArray *)to;

        if (!MODimplicitConv(next->mod, ta->next->mod))
            return MATCHnomatch;        // not const-compatible

        if (!MODimplicitConv(index->mod, ta->index->mod))
            return MATCHnomatch;        // not const-compatible

        MATCH m = next->constConv(ta->next);
        MATCH mi = index->constConv(ta->index);
        if (m != MATCHnomatch && mi != MATCHnomatch)
        {
            if (m == MATCHexact && mod != to->mod)
                m = MATCHconst;
            if (mi < m)
                m = mi;
            return m;
        }
    }
    return Type::implicitConvTo(to);
}

MATCH TypeAArray::constConv(Type *to)
{
    if (to->ty == Taarray)
    {
        TypeAArray *taa = (TypeAArray *)to;
        MATCH mindex = index->constConv(taa->index);
        MATCH mkey = next->constConv(taa->next);
        // Pick the worst match
        return mkey < mindex ? mkey : mindex;
    }
    else
        return Type::constConv(to);
}

/***************************** TypePointer *****************************/

TypePointer::TypePointer(Type *t)
    : TypeNext(Tpointer, t)
{
}

Type *TypePointer::syntaxCopy()
{
    Type *t = next->syntaxCopy();
    if (t == next)
        t = this;
    else
    {   t = new TypePointer(t);
        t->mod = mod;
    }
    return t;
}

Type *TypePointer::semantic(Loc loc, Scope *sc)
{
    //printf("TypePointer::semantic()\n");
    if (deco)
        return this;
    Type *n = next->semantic(loc, sc);
    switch (n->toBasetype()->ty)
    {
        case Ttuple:
            error(loc, "can't have pointer to %s", n->toChars());
            n = tint32;
            break;
    }
    if (n != next)
    {
        deco = NULL;
    }
    next = n;
    transitive();
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
    {   toCBuffer3(buf, hgs, mod);
        return;
    }
    next->toCBuffer2(buf, hgs, this->mod);
    if (next->ty != Tfunction)
        buf->writeByte('*');
}

MATCH TypePointer::implicitConvTo(Type *to)
{
    //printf("TypePointer::implicitConvTo(to = %s) %s\n", to->toChars(), toChars());

    if (equals(to))
        return MATCHexact;
    if (next->ty == Tfunction)
    {
        if (to->ty == Tpointer)
        {
            TypePointer *tp = (TypePointer*)to;
            if (tp->next->ty == Tfunction)
            {
                if (next->equals(tp->next))
                    return MATCHconst;

                if (next->covariant(tp->next) == 1)
                    return MATCHconvert;
            }
            else if (tp->next->ty == Tvoid)
            {
                // Allow conversions to void*
                return MATCHconvert;
            }
        }
        return MATCHnomatch;
    }
    else if (to->ty == Tpointer)
    {   TypePointer *tp = (TypePointer *)to;
        assert(tp->next);

        if (!MODimplicitConv(next->mod, tp->next->mod))
            return MATCHnomatch;        // not const-compatible

        /* Alloc conversion to void*
         */
        if (next->ty != Tvoid && tp->next->ty == Tvoid)
        {
            return MATCHconvert;
        }

        MATCH m = next->constConv(tp->next);
        if (m != MATCHnomatch)
        {
            if (m == MATCHexact && mod != to->mod)
                m = MATCHconst;
            return m;
        }

        /* Conversion of ptr to derived to ptr to base
         */
        int offset = 0;
        if (tp->next->isBaseOf(next, &offset) && offset == 0)
            return MATCHconvert;
    }
    return MATCHnomatch;
}

MATCH TypePointer::constConv(Type *to)
{
    if (next->ty == Tfunction)
    {
        if (to->nextOf() && next->equals(((TypeNext*)to)->next))
            return Type::constConv(to);
        else
            return MATCHnomatch;
    }
    return TypeNext::constConv(to);
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
    : TypeNext(Treference, t)
{
    // BUG: what about references to static arrays?
}

Type *TypeReference::syntaxCopy()
{
    Type *t = next->syntaxCopy();
    if (t == next)
        t = this;
    else
    {   t = new TypeReference(t);
        t->mod = mod;
    }
    return t;
}

Type *TypeReference::semantic(Loc loc, Scope *sc)
{
    //printf("TypeReference::semantic()\n");
    Type *n = next->semantic(loc, sc);
    if (n != next)
        deco = NULL;
    next = n;
    transitive();
    return merge();
}


d_uns64 TypeReference::size(Loc loc)
{
    return PTRSIZE;
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

TypeFunction::TypeFunction(Parameters *parameters, Type *treturn, int varargs, enum LINK linkage, StorageClass stc)
    : TypeNext(Tfunction, treturn)
{
//if (!treturn) *(char*)0=0;
//    assert(treturn);
    assert(0 <= varargs && varargs <= 2);
    this->parameters = parameters;
    this->varargs = varargs;
    this->linkage = linkage;
    this->inuse = 0;
    this->isnothrow = false;
    this->purity = PUREimpure;
    this->isproperty = false;
    this->isref = false;
    this->fargs = NULL;

    if (stc & STCpure)
        this->purity = PUREfwdref;
    if (stc & STCnothrow)
        this->isnothrow = true;
    if (stc & STCproperty)
        this->isproperty = true;

    this->trust = TRUSTdefault;
    if (stc & STCsafe)
        this->trust = TRUSTsafe;
    if (stc & STCsystem)
        this->trust = TRUSTsystem;
    if (stc & STCtrusted)
        this->trust = TRUSTtrusted;
}

Type *TypeFunction::syntaxCopy()
{
    Type *treturn = next ? next->syntaxCopy() : NULL;
    Parameters *params = Parameter::arraySyntaxCopy(parameters);
    TypeFunction *t = new TypeFunction(params, treturn, varargs, linkage);
    t->mod = mod;
    t->isnothrow = isnothrow;
    t->purity = purity;
    t->isproperty = isproperty;
    t->isref = isref;
    t->trust = trust;
    t->fargs = fargs;
    return t;
}

/*******************************
 * Covariant means that 'this' can substitute for 't',
 * i.e. a pure function is a match for an impure type.
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
//    printf("ty = %d\n", next->ty);
    printf("mod = %x, %x\n", mod, t->mod);
#endif

    int inoutmismatch = 0;

    TypeFunction *t1;
    TypeFunction *t2;

    if (equals(t))
        return 1;                       // covariant

    if (ty != Tfunction || t->ty != Tfunction)
        goto Ldistinct;

    t1 = (TypeFunction *)this;
    t2 = (TypeFunction *)t;

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
            {
#if 0 // turn on this for contravariant argument types, see bugzilla 3075
                // BUG: cannot convert ref to const to ref to immutable
                // We can add const, but not subtract it
                if (arg2->type->implicitConvTo(arg1->type) < MATCHconst)
#endif
                    goto Ldistinct;
            }
            const StorageClass sc = STCref | STCin | STCout | STClazy;
            if ((arg1->storageClass & sc) != (arg2->storageClass & sc))
                inoutmismatch = 1;
            // We can add scope, but not subtract it
            if (!(arg1->storageClass & STCscope) && (arg2->storageClass & STCscope))
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

  {
            // Return types
    Type *t1n = t1->next;
    Type *t2n = t2->next;

    if (!t1n || !t2n)           // happens with return type inference
        goto Lnotcovariant;

    if (t1n->equals(t2n))
        goto Lcovariant;
    if (t1n->ty == Tclass && t2n->ty == Tclass)
    {
        /* If same class type, but t2n is const, then it's
         * covariant. Do this test first because it can work on
         * forward references.
         */
        if (((TypeClass *)t1n)->sym == ((TypeClass *)t2n)->sym &&
            MODimplicitConv(t1n->mod, t2n->mod))
            goto Lcovariant;

        // If t1n is forward referenced:
        ClassDeclaration *cd = ((TypeClass *)t1n)->sym;
#if 0
        if (!cd->baseClass && cd->baseclasses->dim && !cd->isInterfaceDeclaration())
#else
        if (!cd->isBaseInfoComplete())
#endif
        {
            return 3;   // forward references
        }
    }
    if (t1n->implicitConvTo(t2n))
        goto Lcovariant;
  }
    goto Lnotcovariant;

Lcovariant:
    /* Can convert mutable to const
     */
    if (!MODimplicitConv(t2->mod, t1->mod))
        goto Lnotcovariant;
#if 0
    if (t1->mod != t2->mod)
    {
        if (!(t1->mod & MODconst) && (t2->mod & MODconst))
            goto Lnotcovariant;
        if (!(t1->mod & MODshared) && (t2->mod & MODshared))
            goto Lnotcovariant;
    }
#endif

    /* Can convert pure to impure, and nothrow to throw
     */
    if (!t1->purity && t2->purity)
        goto Lnotcovariant;

    if (!t1->isnothrow && t2->isnothrow)
        goto Lnotcovariant;

    if (t1->isref != t2->isref)
        goto Lnotcovariant;

    /* Can convert safe/trusted to system
     */
    if (t1->trust <= TRUSTsystem && t2->trust >= TRUSTtrusted)
        goto Lnotcovariant;

    //printf("\tcovaraint: 1\n");
    return 1;

Ldistinct:
    //printf("\tcovaraint: 0\n");
    return 0;

Lnotcovariant:
    //printf("\tcovaraint: 2\n");
    return 2;
}

void TypeFunction::toDecoBuffer(OutBuffer *buf, int flag)
{   unsigned char mc;

    //printf("TypeFunction::toDecoBuffer() this = %p %s\n", this, toChars());
    //static int nest; if (++nest == 50) *(char*)0=0;
    if (inuse)
    {   inuse = 2;              // flag error to caller
        return;
    }
    inuse++;
    MODtoDecoBuffer(buf, mod);
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
    if (purity || isnothrow || isproperty || isref || trust)
    {
        if (purity)
            buf->writestring("Na");
        if (isnothrow)
            buf->writestring("Nb");
        if (isref)
            buf->writestring("Nc");
        if (isproperty)
            buf->writestring("Nd");
        switch (trust)
        {
            case TRUSTtrusted:
                buf->writestring("Ne");
                break;
            case TRUSTsafe:
                buf->writestring("Nf");
                break;
        }
    }
    // Write argument types
    Parameter::argsToDecoBuffer(buf, parameters);
    //if (buf->data[buf->offset - 1] == '@') halt();
    buf->writeByte('Z' - varargs);      // mark end of arg list
    assert(next);
    next->toDecoBuffer(buf);
    inuse--;
}

void TypeFunction::toCBuffer(OutBuffer *buf, Identifier *ident, HdrGenState *hgs)
{
    toCBufferWithAttributes(buf, ident, hgs, this, NULL);
}

void TypeFunction::toCBufferWithAttributes(OutBuffer *buf, Identifier *ident, HdrGenState* hgs, TypeFunction *attrs, TemplateDeclaration *td)
{
    //printf("TypeFunction::toCBuffer() this = %p\n", this);
    const char *p = NULL;

    if (inuse)
    {   inuse = 2;              // flag error to caller
        return;
    }
    inuse++;

    /* Use 'storage class' style for attributes
     */
    if (attrs->mod)
    {
        MODtoBuffer(buf, attrs->mod);
        buf->writeByte(' ');
    }

    if (attrs->purity)
        buf->writestring("pure ");
    if (attrs->isnothrow)
        buf->writestring("nothrow ");
    if (attrs->isproperty)
        buf->writestring("@property ");
    if (attrs->isref)
        buf->writestring("ref ");

    switch (attrs->trust)
    {
        case TRUSTsystem:
            buf->writestring("@system ");
            break;

        case TRUSTtrusted:
            buf->writestring("@trusted ");
            break;

        case TRUSTsafe:
            buf->writestring("@safe ");
            break;
    }

    if (next && (!ident || ident->toHChars2() == ident->toChars()))
        next->toCBuffer2(buf, hgs, 0);
    else if (hgs->ddoc && !next)
        buf->writestring("auto");
    if (hgs->ddoc != 1)
    {
        switch (attrs->linkage)
        {
            case LINKd:         p = NULL;       break;
            case LINKc:         p = "C ";       break;
            case LINKwindows:   p = "Windows "; break;
            case LINKpascal:    p = "Pascal ";  break;
            case LINKcpp:       p = "C++ ";     break;
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

void TypeFunction::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    //printf("TypeFunction::toCBuffer2() this = %p, ref = %d\n", this, isref);
    const char *p = NULL;

    if (inuse)
    {   inuse = 2;              // flag error to caller
        return;
    }
    inuse++;
    if (next)
        next->toCBuffer2(buf, hgs, 0);
    if (hgs->ddoc != 1)
    {
        switch (linkage)
        {
            case LINKd:         p = NULL;       break;
            case LINKc:         p = " C";       break;
            case LINKwindows:   p = " Windows"; break;
            case LINKpascal:    p = " Pascal";  break;
            case LINKcpp:       p = " C++";     break;
            default:
                assert(0);
        }
    }

    if (!hgs->hdrgen && p)
        buf->writestring(p);
    buf->writestring(" function");
    Parameter::argsToCBuffer(buf, hgs, parameters, varargs);
    attributesToCBuffer(buf, mod);
    inuse--;
}

void TypeFunction::attributesToCBuffer(OutBuffer *buf, int mod)
{
    /* Use postfix style for attributes
     */
    if (mod != this->mod)
    {
        modToBuffer(buf);
    }
    if (purity)
        buf->writestring(" pure");
    if (isnothrow)
        buf->writestring(" nothrow");
    if (isproperty)
        buf->writestring(" @property");
    if (isref)
        buf->writestring(" ref");

    switch (trust)
    {
        case TRUSTsystem:
            buf->writestring(" @system");
            break;

        case TRUSTtrusted:
            buf->writestring(" @trusted");
            break;

        case TRUSTsafe:
            buf->writestring(" @safe");
            break;
    }
}

Type *TypeFunction::semantic(Loc loc, Scope *sc)
{
    if (deco)                   // if semantic() already run
    {
        //printf("already done\n");
        return this;
    }
    //printf("TypeFunction::semantic() this = %p\n", this);
    //printf("TypeFunction::semantic() %s, sc->stc = %llx, fargs = %p\n", toChars(), sc->stc, fargs);

    /* Copy in order to not mess up original.
     * This can produce redundant copies if inferring return type,
     * as semantic() will get called again on this.
     */
    TypeFunction *tf = (TypeFunction *)mem.malloc(sizeof(TypeFunction));
    memcpy(tf, this, sizeof(TypeFunction));
    if (parameters)
    {   tf->parameters = (Parameters *)parameters->copy();
        for (size_t i = 0; i < parameters->dim; i++)
        {   Parameter *arg = parameters->tdata()[i];
            Parameter *cpy = (Parameter *)mem.malloc(sizeof(Parameter));
            memcpy(cpy, arg, sizeof(Parameter));
            tf->parameters->tdata()[i] = cpy;
        }
    }

    if (sc->stc & STCpure)
        tf->purity = PUREfwdref;
    if (sc->stc & STCnothrow)
        tf->isnothrow = TRUE;
    if (sc->stc & STCref)
        tf->isref = TRUE;
    if (sc->stc & STCsafe)
        tf->trust = TRUSTsafe;
    if (sc->stc & STCtrusted)
        tf->trust = TRUSTtrusted;
    if (sc->stc & STCproperty)
        tf->isproperty = TRUE;

    tf->linkage = sc->linkage;

    /* If the parent is @safe, then this function defaults to safe
     * too.
     */
    if (tf->trust == TRUSTdefault)
        for (Dsymbol *p = sc->func; p; p = p->toParent2())
        {   FuncDeclaration *fd = p->isFuncDeclaration();
            if (fd)
            {
                if (fd->isSafe())
                    tf->trust = TRUSTsafe;              // default to @safe
                break;
            }
        }

    bool wildreturn = FALSE;
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
        if (tf->next->toBasetype()->ty == Tvoid)
            tf->isref = FALSE;                  // rewrite "ref void" as just "void"
        if (tf->next->isWild())
            wildreturn = TRUE;
    }

    bool wildparams = FALSE;
    bool wildsubparams = FALSE;
    if (tf->parameters)
    {
        /* Create a scope for evaluating the default arguments for the parameters
         */
        Scope *argsc = sc->push();
        argsc->stc = 0;                 // don't inherit storage class
        argsc->protection = PROTpublic;

        size_t dim = Parameter::dim(tf->parameters);
        for (size_t i = 0; i < dim; i++)
        {   Parameter *fparam = Parameter::getNth(tf->parameters, i);

            tf->inuse++;
            fparam->type = fparam->type->semantic(loc, argsc);
            if (tf->inuse == 1) tf->inuse--;

            fparam->type = fparam->type->addStorageClass(fparam->storageClass);

            if (fparam->storageClass & (STCauto | STCalias | STCstatic))
            {
                if (!fparam->type)
                    continue;
            }

            Type *t = fparam->type->toBasetype();

            if (fparam->storageClass & (STCout | STCref | STClazy))
            {
                //if (t->ty == Tsarray)
                    //error(loc, "cannot have out or ref parameter of type %s", t->toChars());
                if (fparam->storageClass & STCout && fparam->type->mod & (STCconst | STCimmutable))
                    error(loc, "cannot have const or immutable out parameter of type %s", t->toChars());
            }
            if (!(fparam->storageClass & STClazy) && t->ty == Tvoid)
                error(loc, "cannot have parameter of type %s", fparam->type->toChars());

            if (t->isWild())
            {
                wildparams = TRUE;
                if (tf->next && !wildreturn)
                    error(loc, "inout on parameter means inout must be on return type as well (if from D1 code, replace with 'ref')");
            }
            else if (!wildsubparams && t->hasWild())
                wildsubparams = TRUE;

            if (fparam->defaultArg)
            {
                fparam->defaultArg = fparam->defaultArg->semantic(argsc);
                fparam->defaultArg = resolveProperties(argsc, fparam->defaultArg);
                fparam->defaultArg = fparam->defaultArg->implicitCastTo(argsc, fparam->type);
            }

            /* If fparam turns out to be a tuple, the number of parameters may
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
                    {   Parameter *narg = tt->arguments->tdata()[j];
                        narg->storageClass |= fparam->storageClass;
                    }
                    fparam->storageClass = 0;
                }

                /* Reset number of parameters, and back up one to do this fparam again,
                 * now that it is the first element of a tuple
                 */
                dim = Parameter::dim(tf->parameters);
                i--;
                continue;
            }

            /* Resolve "auto ref" storage class to be either ref or value,
             * based on the argument matching the parameter
             */
            if (fparam->storageClass & STCauto)
            {
                if (fargs && i < fargs->dim)
                {   Expression *farg = fargs->tdata()[i];
                    if (farg->isLvalue())
                        ;                               // ref parameter
                    else
                        fparam->storageClass &= ~STCref;        // value parameter
                }
                else
                    error(loc, "auto can only be used for template function parameters");
            }
        }
        argsc->pop();
    }
    if (wildreturn && !wildparams)
        error(loc, "inout on return means inout must be on a parameter as well for %s", toChars());
    if (wildsubparams && wildparams)
        error(loc, "inout must be all or none on top level for %s", toChars());

    if (tf->next)
        tf->deco = tf->merge()->deco;

    if (tf->inuse)
    {   error(loc, "recursive type");
        tf->inuse = 0;
        return terror;
    }

    if (tf->isproperty && (tf->varargs || Parameter::dim(tf->parameters) > 1))
        error(loc, "properties can only have zero or one parameter");

    if (tf->varargs == 1 && tf->linkage != LINKd && Parameter::dim(tf->parameters) == 0)
        error(loc, "variadic functions with non-D linkage must have at least one parameter");

    /* Don't return merge(), because arg identifiers and default args
     * can be different
     * even though the types match
     */
    return tf;
}


/********************************************
 * Do this lazily, as the parameter types might be forward referenced.
 */
void TypeFunction::purityLevel()
{
    TypeFunction *tf = this;
    if (tf->purity == PUREfwdref)
    {   /* Evaluate what kind of purity based on the modifiers for the parameters
         */
        tf->purity = PUREstrong;        // assume strong until something weakens it
        if (tf->parameters)
        {
            size_t dim = Parameter::dim(tf->parameters);
            for (size_t i = 0; i < dim; i++)
            {   Parameter *fparam = Parameter::getNth(tf->parameters, i);
                if (fparam->storageClass & STClazy)
                {
                    tf->purity = PUREweak;
                    break;
                }
                if (fparam->storageClass & STCout)
                {
                    tf->purity = PUREweak;
                    break;
                }
                if (!fparam->type)
                    continue;
                if (fparam->storageClass & STCref)
                {
                    if (!(fparam->type->mod & (MODconst | MODimmutable | MODwild)))
                    {   tf->purity = PUREweak;
                        break;
                    }
                    if (fparam->type->mod & MODconst)
                    {   tf->purity = PUREconst;
                        continue;
                    }
                }
                Type *t = fparam->type->toBasetype();
                if (!t->hasPointers())
                    continue;
                if (t->mod & (MODimmutable | MODwild))
                    continue;
                /* The rest of this is too strict; fix later.
                 * For example, the only pointer members of a struct may be immutable,
                 * which would maintain strong purity.
                 */
                if (t->mod & MODconst)
                {   tf->purity = PUREconst;
                    continue;
                }
                Type *tn = t->nextOf();
                if (tn)
                {   tn = tn->toBasetype();
                    if (tn->ty == Tpointer || tn->ty == Tarray)
                    {   /* Accept immutable(T)* and immutable(T)[] as being strongly pure
                         */
                        if (tn->mod & (MODimmutable | MODwild))
                            continue;
                        if (tn->mod & MODconst)
                        {   tf->purity = PUREconst;
                            continue;
                        }
                    }
                }
                /* Should catch delegates and function pointers, and fold in their purity
                 */
                tf->purity = PUREweak;          // err on the side of too strict
                break;
            }
        }
    }
}


/********************************
 * 'args' are being matched to function 'this'
 * Determine match level.
 * Input:
 *      flag    1       performing a partial ordering match
 * Returns:
 *      MATCHxxxx
 */

int TypeFunction::callMatch(Expression *ethis, Expressions *args, int flag)
{
    //printf("TypeFunction::callMatch() %s\n", toChars());
    MATCH match = MATCHexact;           // assume exact match
    bool exactwildmatch = FALSE;
    bool wildmatch = FALSE;

    if (ethis)
    {   Type *t = ethis->type;
        if (t->toBasetype()->ty == Tpointer)
            t = t->toBasetype()->nextOf();      // change struct* to struct
        if (t->mod != mod)
        {
            if (MODimplicitConv(t->mod, mod))
                match = MATCHconst;
            else
                return MATCHnomatch;
        }
    }

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
    {   MATCH m;
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
        arg = args->tdata()[u];
        assert(arg);
        //printf("arg: %s, type: %s\n", arg->toChars(), arg->type->toChars());

        // Non-lvalues do not match ref or out parameters
        if (p->storageClass & (STCref | STCout))
        {   if (!arg->isLvalue())
                goto Nomatch;
        }

        if (p->storageClass & STCref)
        {
            /* Don't allow static arrays to be passed to mutable references
             * to static arrays if the argument cannot be modified.
             */
            Type *targb = arg->type->toBasetype();
            Type *tparb = p->type->toBasetype();
            //printf("%s\n", targb->toChars());
            //printf("%s\n", tparb->toChars());
            if (targb->nextOf() && tparb->ty == Tsarray &&
                !MODimplicitConv(targb->nextOf()->mod, tparb->nextOf()->mod))
                goto Nomatch;
        }

        if (p->storageClass & STClazy && p->type->ty == Tvoid &&
                arg->type->ty != Tvoid)
            m = MATCHconvert;
        else
        {
            //printf("%s of type %s implicitConvTo %s\n", arg->toChars(), arg->type->toChars(), p->type->toChars());
            if (flag)
                // for partial ordering, value is an irrelevant mockup, just look at the type
                m = arg->type->implicitConvTo(p->type);
            else
                m = arg->implicitConvTo(p->type);
            //printf("match %d\n", m);
            if (p->type->isWild())
            {
                if (m == MATCHnomatch)
                {
                    m = arg->implicitConvTo(p->type->constOf());
                    if (m == MATCHnomatch)
                        m = arg->implicitConvTo(p->type->sharedConstOf());
                    if (m != MATCHnomatch)
                        wildmatch = TRUE;       // mod matched to wild
                }
                else
                    exactwildmatch = TRUE;      // wild matched to wild

                /* If both are allowed, then there could be more than one
                 * binding of mod to wild, leaving a gaping type hole.
                 */
                if (wildmatch && exactwildmatch)
                    m = MATCHnomatch;
            }
        }

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
                    {   TypeArray *ta = (TypeArray *)tb;
                        for (; u < nargs; u++)
                        {
                            arg = args->tdata()[u];
                            assert(arg);
#if 1
                            /* If lazy array of delegates,
                             * convert arg(s) to delegate(s)
                             */
                            Type *tret = p->isLazyArray();
                            if (tret)
                            {
                                if (ta->next->equals(arg->type))
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
                                m = arg->implicitConvTo(ta->next);
#else
                            m = arg->implicitConvTo(ta->next);
#endif
                            if (m == MATCHnomatch)
                                goto Nomatch;
                            if (m < match)
                                match = m;
                        }
                        goto Ldone;
                    }
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
    size_t dim = Parameter::dim(parameters);
    for (size_t i = 0; i < dim; i++)
    {   Parameter *fparam = Parameter::getNth(parameters, i);
        Type *t = fparam->type->reliesOnTident();
        if (t)
            return t;
    }
    return next ? next->reliesOnTident() : NULL;
}

/********************************************
 * Return TRUE if there are lazy parameters.
 */
bool TypeFunction::hasLazyParameters()
{
    size_t dim = Parameter::dim(parameters);
    for (size_t i = 0; i < dim; i++)
    {   Parameter *fparam = Parameter::getNth(parameters, i);
        if (fparam->storageClass & STClazy)
            return TRUE;
    }
    return FALSE;
}

/***************************
 * Examine function signature for parameter p and see if
 * p can 'escape' the scope of the function.
 */

bool TypeFunction::parameterEscapes(Parameter *p)
{

    /* Scope parameters do not escape.
     * Allow 'lazy' to imply 'scope' -
     * lazy parameters can be passed along
     * as lazy parameters to the next function, but that isn't
     * escaping.
     */
    if (p->storageClass & (STCscope | STClazy))
        return FALSE;

    if (purity)
    {   /* With pure functions, we need only be concerned if p escapes
         * via any return statement.
         */
        Type* tret = nextOf()->toBasetype();
        if (!isref && !tret->hasPointers())
        {   /* The result has no references, so p could not be escaping
             * that way.
             */
            return FALSE;
        }
    }

    /* Assume it escapes in the absence of better information.
     */
    return TRUE;
}

Expression *TypeFunction::defaultInit(Loc loc)
{
    error(loc, "function does not have a default initializer");
    return new ErrorExp();
}

/***************************** TypeDelegate *****************************/

TypeDelegate::TypeDelegate(Type *t)
    : TypeNext(Tfunction, t)
{
    ty = Tdelegate;
}

Type *TypeDelegate::syntaxCopy()
{
    Type *t = next->syntaxCopy();
    if (t == next)
        t = this;
    else
    {   t = new TypeDelegate(t);
        t->mod = mod;
    }
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
    /* In order to deal with Bugzilla 4028, perhaps default arguments should
     * be removed from next before the merge.
     */

    /* Don't return merge(), because arg identifiers and default args
     * can be different
     * even though the types match
     */
    //deco = merge()->deco;
    //return this;
    return merge();
}

d_uns64 TypeDelegate::size(Loc loc)
{
    return PTRSIZE * 2;
}

unsigned TypeDelegate::alignsize()
{
#if DMDV1
    // See Bugzilla 942 for discussion
    if (!global.params.is64bit)
        return PTRSIZE * 2;
#endif
    return PTRSIZE;
}

MATCH TypeDelegate::implicitConvTo(Type *to)
{
    //printf("TypeDelegate::implicitConvTo(this=%p, to=%p)\n", this, to);
    //printf("from: %s\n", toChars());
    //printf("to  : %s\n", to->toChars());
    if (this == to)
        return MATCHexact;
#if 1 // not allowing covariant conversions because it interferes with overriding
    if (to->ty == Tdelegate && this->nextOf()->covariant(to->nextOf()) == 1)
        return MATCHconvert;
#endif
    return MATCHnomatch;
}

void TypeDelegate::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    if (mod != this->mod)
    {   toCBuffer3(buf, hgs, mod);
        return;
    }
    TypeFunction *tf = (TypeFunction *)next;

    tf->next->toCBuffer2(buf, hgs, 0);
    buf->writestring(" delegate");
    Parameter::argsToCBuffer(buf, hgs, tf->parameters, tf->varargs);
    tf->attributesToCBuffer(buf, mod);
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
    : Type(ty)
{
    this->loc = loc;
}

void TypeQualified::syntaxCopyHelper(TypeQualified *t)
{
    //printf("TypeQualified::syntaxCopyHelper(%s) %s\n", t->toChars(), toChars());
    idents.setDim(t->idents.dim);
    for (size_t i = 0; i < idents.dim; i++)
    {
        Identifier *id = t->idents.tdata()[i];
        if (id->dyncast() == DYNCAST_DSYMBOL)
        {
            TemplateInstance *ti = (TemplateInstance *)id;

            ti = (TemplateInstance *)ti->syntaxCopy(NULL);
            id = (Identifier *)ti;
        }
        idents.tdata()[i] = id;
    }
}


void TypeQualified::addIdent(Identifier *ident)
{
    idents.push(ident);
}

void TypeQualified::toCBuffer2Helper(OutBuffer *buf, HdrGenState *hgs)
{
    for (size_t i = 0; i < idents.dim; i++)
    {   Identifier *id = idents.tdata()[i];

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
 *      if expression, *pe is set
 *      if type, *pt is set
 */

void TypeQualified::resolveHelper(Loc loc, Scope *sc,
        Dsymbol *s, Dsymbol *scopesym,
        Expression **pe, Type **pt, Dsymbol **ps)
{
    VarDeclaration *v;
    EnumMember *em;
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
            Identifier *id = idents.tdata()[i];
            Dsymbol *sm = s->searchX(loc, sc, id);
            //printf("\t3: s = '%s' %p, kind = '%s'\n",s->toChars(), s, s->kind());
            //printf("\tgetType = '%s'\n", s->getType()->toChars());
            if (!sm)
            {   Type *t;

                v = s->isVarDeclaration();
                if (v && id == Id::length)
                {
                    e = v->getConstInitializer();
                    if (!e)
                        e = new VarExp(loc, v);
                    t = e->type;
                    if (!t)
                        goto Lerror;
                    goto L3;
                }
                else if (v && (id == Id::stringof || id == Id::offsetof))
                {
                    e = new DsymbolExp(loc, s, 0);
                    do
                    {
                        id = idents.tdata()[i];
                        e = new DotIdExp(loc, e, id);
                    } while (++i < idents.dim);
                    e = e->semantic(sc);
                    *pe = e;
                    return;
                }

                t = s->getType();
                if (!t && s->isDeclaration())
                    t = s->isDeclaration()->type;
                if (t)
                {
                    sm = t->toDsymbol(sc);
                    if (sm)
                    {   sm = sm->search(loc, id, 0);
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
                        id = idents.tdata()[i];
                        //printf("e: '%s', id: '%s', type = %p\n", e->toChars(), id->toChars(), e->type);
                        if (id == Id::offsetof || !e->type)
                        {   e = new DotIdExp(e->loc, e, id);
                            e = e->semantic(sc);
                        }
                        else
                            e = e->type->dotExp(sc, e, id);
                    }
                    *pe = e;
                }
                else
                {
                  Lerror:
                    error(loc, "identifier '%s' of '%s' is not defined", id->toChars(), toChars());
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
            *pe = new VarExp(loc, v);
            return;
        }
#if 0
        fd = s->isFuncDeclaration();
        if (fd)
        {
            *pe = new DsymbolExp(loc, fd, 1);
            return;
        }
#endif
        em = s->isEnumMember();
        if (em)
        {
            // It's not a type, it's an expression
            *pe = em->value->copy();
            return;
        }

L1:
        Type *t = s->getType();
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
    t->mod = mod;
    return t;
}

void TypeIdentifier::toDecoBuffer(OutBuffer *buf, int flag)
{   unsigned len;
    char *name;

    Type::toDecoBuffer(buf, flag);
    name = ident->toChars();
    len = strlen(name);
    buf->printf("%d%s", len, name);
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
{
    Dsymbol *scopesym;

    //printf("TypeIdentifier::resolve(sc = %p, idents = '%s')\n", sc, toChars());

    if ((ident->equals(Id::super) || ident->equals(Id::This)) && !hasThis(sc))
    {
        AggregateDeclaration *ad = sc->getStructClassScope();
        if (ad)
        {
            ClassDeclaration *cd = ad->isClassDeclaration();
            if (cd)
            {
                if (ident->equals(Id::This))
                    ident = cd->ident;
                else if (cd->baseClass && ident->equals(Id::super))
                    ident = cd->baseClass->ident;
            }
            else
            {
                StructDeclaration *sd = ad->isStructDeclaration();
                if (sd && ident->equals(Id::This))
                    ident = sd->ident;
            }
        }
    }

    Dsymbol *s = sc->search(loc, ident, &scopesym);
    resolveHelper(loc, sc, s, scopesym, pe, pt, ps);
    if (*pt)
        (*pt) = (*pt)->addMod(mod);
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
            Identifier *id = idents.tdata()[i];
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
        t = t->addMod(mod);
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
            //halt();
        }
        else
            error(loc, "%s is used as a type", toChars());
        t = terror;
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
        Identifier *id = idents.tdata()[i];
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
    t->mod = mod;
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
    if (*pt)
        *pt = (*pt)->addMod(mod);
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
        unsigned errors = global.errors;
        global.gag++;

        resolve(loc, sc, &e, &t, &s);

        global.gag--;
        if (errors != global.errors)
        {   if (global.gag == 0)
                global.errors = errors;
            return NULL;
        }
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
    t->mod = mod;
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

Type *TypeTypeof::semantic(Loc loc, Scope *sc)
{
    Type *t;

    //printf("TypeTypeof::semantic() %s\n", toChars());

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
        exp = exp->semantic(sc2);
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

        /* typeof should reflect the true type,
         * not what 'auto' would have gotten us.
         */
        //t = t->toHeadMutable();
    }
    if (idents.dim)
    {
        Dsymbol *s = t->toDsymbol(sc);
        for (size_t i = 0; i < idents.dim; i++)
        {
            if (!s)
                break;
            Identifier *id = idents.tdata()[i];
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



/***************************** TypeReturn *****************************/

TypeReturn::TypeReturn(Loc loc)
        : TypeQualified(Treturn, loc)
{
}

Type *TypeReturn::syntaxCopy()
{
    TypeReturn *t = new TypeReturn(loc);
    t->syntaxCopyHelper(this);
    t->mod = mod;
    return t;
}

Dsymbol *TypeReturn::toDsymbol(Scope *sc)
{
    Type *t = semantic(0, sc);
    if (t == this)
        return NULL;
    return t->toDsymbol(sc);
}

Type *TypeReturn::semantic(Loc loc, Scope *sc)
{
    Type *t;
    if (!sc->func)
    {   error(loc, "typeof(return) must be inside function");
        goto Lerr;
    }
    t = sc->func->type->nextOf();
    if (!t)
    {
        error(loc, "cannot use typeof(return) inside function %s with inferred return type", sc->func->toChars());
        goto Lerr;
    }
    t = t->addMod(mod);

    if (idents.dim)
    {
        Dsymbol *s = t->toDsymbol(sc);
        for (size_t i = 0; i < idents.dim; i++)
        {
            if (!s)
                break;
            Identifier *id = idents.tdata()[i];
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
    return t;

Lerr:
    return terror;
}

void TypeReturn::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    if (mod != this->mod)
    {   toCBuffer3(buf, hgs, mod);
        return;
    }
    buf->writestring("typeof(return)");
    toCBuffer2Helper(buf, hgs);
}


/***************************** TypeEnum *****************************/

TypeEnum::TypeEnum(EnumDeclaration *sym)
        : Type(Tenum)
{
    this->sym = sym;
}

char *TypeEnum::toChars()
{
    if (mod)
        return Type::toChars();
    return sym->toChars();
}

Type *TypeEnum::syntaxCopy()
{
    return this;
}

Type *TypeEnum::semantic(Loc loc, Scope *sc)
{
    //printf("TypeEnum::semantic() %s\n", toChars());
    //sym->semantic(sc);
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
        return tint32;
    }
    return sym->memtype->toBasetype();
}

void TypeEnum::toDecoBuffer(OutBuffer *buf, int flag)
{
    const char *name = sym->mangle();
    Type::toDecoBuffer(buf, flag);
    buf->printf("%s", name);
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
#if LOGDOTEXP
    printf("TypeEnum::dotExp(e = '%s', ident = '%s') '%s'\n", e->toChars(), ident->toChars(), toChars());
#endif
    Dsymbol *s = sym->search(e->loc, ident, 0);
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
    EnumMember *m = s->isEnumMember();
    Expression *em = m->value->copy();
    em->loc = e->loc;
    return em;
}

Expression *TypeEnum::getProperty(Loc loc, Identifier *ident)
{   Expression *e;

    if (ident == Id::max)
    {
        if (!sym->maxval)
            goto Lfwd;
        e = sym->maxval;
    }
    else if (ident == Id::min)
    {
        if (!sym->minval)
            goto Lfwd;
        e = sym->minval;
    }
    else if (ident == Id::init)
    {
        e = defaultInitLiteral(loc);
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
        e = toBasetype()->getProperty(loc, ident);
    }
    return e;

Lfwd:
    error(loc, "forward reference of %s.%s", toChars(), ident->toChars());
    return new ErrorExp();
}

int TypeEnum::isintegral()
{
    return sym->memtype->isintegral();
}

int TypeEnum::isfloating()
{
    return sym->memtype->isfloating();
}

int TypeEnum::isreal()
{
    return sym->memtype->isreal();
}

int TypeEnum::isimaginary()
{
    return sym->memtype->isimaginary();
}

int TypeEnum::iscomplex()
{
    return sym->memtype->iscomplex();
}

int TypeEnum::isunsigned()
{
    return sym->memtype->isunsigned();
}

int TypeEnum::isscalar()
{
    return sym->memtype->isscalar();
}

int TypeEnum::isAssignable()
{
    return sym->memtype->isAssignable();
}

int TypeEnum::checkBoolean()
{
    return sym->memtype->checkBoolean();
}

int TypeEnum::needsDestruction()
{
    return sym->memtype->needsDestruction();
}

MATCH TypeEnum::implicitConvTo(Type *to)
{   MATCH m;

    //printf("TypeEnum::implicitConvTo()\n");
    if (ty == to->ty && sym == ((TypeEnum *)to)->sym)
        m = (mod == to->mod) ? MATCHexact : MATCHconst;
    else if (sym->memtype->implicitConvTo(to))
        m = MATCHconvert;       // match with conversions
    else
        m = MATCHnomatch;       // no match
    return m;
}

MATCH TypeEnum::constConv(Type *to)
{
    if (equals(to))
        return MATCHexact;
    if (ty == to->ty && sym == ((TypeEnum *)to)->sym &&
        MODimplicitConv(mod, to->mod))
        return MATCHconst;
    return MATCHnomatch;
}


Expression *TypeEnum::defaultInit(Loc loc)
{
#if LOGDEFAULTINIT
    printf("TypeEnum::defaultInit() '%s'\n", toChars());
#endif
    // Initialize to first member of enum
    //printf("%s\n", sym->defaultval->type->toChars());
    if (!sym->defaultval)
    {
        error(loc, "forward reference of %s.init", toChars());
        return new ErrorExp();
    }
    return sym->defaultval;
}

int TypeEnum::isZeroInit(Loc loc)
{
    if (!sym->defaultval && sym->scope)
    {   // Enum is forward referenced. We need to resolve the whole thing.
        sym->semantic(NULL);
    }
    if (!sym->defaultval)
    {
#ifdef DEBUG
        printf("3: ");
#endif
        error(loc, "enum %s is forward referenced", sym->toChars());
        return 0;
    }
    return sym->defaultval->isBool(FALSE);
}

int TypeEnum::hasPointers()
{
    return toBasetype()->hasPointers();
}

/***************************** TypeTypedef *****************************/

TypeTypedef::TypeTypedef(TypedefDeclaration *sym)
        : Type(Ttypedef)
{
    this->sym = sym;
}

Type *TypeTypedef::syntaxCopy()
{
    return this;
}

char *TypeTypedef::toChars()
{
    return Type::toChars();
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

Type *TypeTypedef::toHeadMutable()
{
    if (!mod)
        return this;

    Type *tb = toBasetype();
    Type *t = tb->toHeadMutable();
    if (t->equals(tb))
        return this;
    else
        return mutableOf();
}

void TypeTypedef::toDecoBuffer(OutBuffer *buf, int flag)
{
    Type::toDecoBuffer(buf, flag);
    const char *name = sym->mangle();
    buf->printf("%s", name);
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
#if LOGDOTEXP
    printf("TypeTypedef::getProperty(ident = '%s') '%s'\n", ident->toChars(), toChars());
#endif
    if (ident == Id::init)
    {
        return Type::getProperty(loc, ident);
    }
    return sym->basetype->getProperty(loc, ident);
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

int TypeTypedef::isAssignable()
{
    return sym->basetype->isAssignable();
}

int TypeTypedef::checkBoolean()
{
    return sym->basetype->checkBoolean();
}

int TypeTypedef::needsDestruction()
{
    return sym->basetype->needsDestruction();
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
    t = t->addMod(mod);
    return t;
}

MATCH TypeTypedef::implicitConvTo(Type *to)
{   MATCH m;

    //printf("TypeTypedef::implicitConvTo(to = %s) %s\n", to->toChars(), toChars());
    if (equals(to))
        m = MATCHexact;         // exact match
    else if (sym->basetype->implicitConvTo(to))
        m = MATCHconvert;       // match with conversions
    else if (ty == to->ty && sym == ((TypeTypedef *)to)->sym)
    {
        m = constConv(to);
    }
    else
        m = MATCHnomatch;       // no match
    return m;
}

MATCH TypeTypedef::constConv(Type *to)
{
    if (equals(to))
        return MATCHexact;
    if (ty == to->ty && sym == ((TypeTypedef *)to)->sym)
        return sym->basetype->implicitConvTo(((TypeTypedef *)to)->sym->basetype);
    return MATCHnomatch;
}


Expression *TypeTypedef::defaultInit(Loc loc)
{
#if LOGDEFAULTINIT
    printf("TypeTypedef::defaultInit() '%s'\n", toChars());
#endif
    if (sym->init)
    {
        //sym->init->toExpression()->print();
        return sym->init->toExpression();
    }
    Type *bt = sym->basetype;
    Expression *e = bt->defaultInit(loc);
    e->type = this;
    while (bt->ty == Tsarray)
    {   TypeSArray *tsa = (TypeSArray *)bt;
        e->type = tsa->next;
        bt = tsa->next->toBasetype();
    }
    return e;
}

Expression *TypeTypedef::defaultInitLiteral(Loc loc)
{
#if LOGDEFAULTINIT
    printf("TypeTypedef::defaultInitLiteral() '%s'\n", toChars());
#endif
    if (sym->init)
    {
        //sym->init->toExpression()->print();
        return sym->init->toExpression();
    }
    Type *bt = sym->basetype;
    Expression *e = bt->defaultInitLiteral(loc);
    e->type = this;
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

int TypeTypedef::hasWild()
{
    return mod & MODwild || toBasetype()->hasWild();
}

/***************************** TypeStruct *****************************/

TypeStruct::TypeStruct(StructDeclaration *sym)
        : Type(Tstruct)
{
    this->sym = sym;
}

char *TypeStruct::toChars()
{
    //printf("sym.parent: %s, deco = %s\n", sym->parent->toChars(), deco);
    if (mod)
        return Type::toChars();
    TemplateInstance *ti = sym->parent->isTemplateInstance();
    if (ti && ti->toAlias() == sym)
    {
        return ti->toChars();
    }
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
    if (sz > sym->structalign)
        sz = sym->structalign;
    return sz;
}

Dsymbol *TypeStruct::toDsymbol(Scope *sc)
{
    return sym;
}

void TypeStruct::toDecoBuffer(OutBuffer *buf, int flag)
{
    const char *name = sym->mangle();
    //printf("TypeStruct::toDecoBuffer('%s') = '%s'\n", toChars(), name);
    Type::toDecoBuffer(buf, flag);
    buf->printf("%s", name);
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
        Expressions *exps = new Expressions;
        exps->reserve(sym->fields.dim);
        for (size_t i = 0; i < sym->fields.dim; i++)
        {   VarDeclaration *v = sym->fields.tdata()[i];
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
            assert(0);  // cannot find a case where this happens; leave
                        // assert in until we do
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
        return noMember(sc, e, ident);
    }
    if (!s->isFuncDeclaration())        // because of overloading
        s->checkDeprecated(e->loc, sc);
    s = s->toAlias();

    v = s->isVarDeclaration();
    if (v && !v->isDataseg())
    {
        Expression *ei = v->getConstInitializer();
        if (ei)
        {   e = ei->copy();     // need to copy it if it's a StringExp
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

    Import *timp = s->isImport();
    if (timp)
    {
        e = new DsymbolExp(e->loc, s, 0);
        e = e->semantic(sc);
        return e;
    }

    OverloadSet *o = s->isOverloadSet();
    if (o)
    {
        OverExp *oe = new OverExp(o);
        if (e->op == TOKtype)
            return oe;
        return new DotExp(e->loc, e, oe);
    }

    d = s->isDeclaration();
#ifdef DEBUG
    if (!d)
        printf("d = %s '%s'\n", s->kind(), s->toChars());
#endif
    assert(d);

    if (e->op == TOKtype)
    {   FuncDeclaration *fd = sc->func;

        if (d->isTupleDeclaration())
        {
            e = new TupleExp(e->loc, d->isTupleDeclaration());
            e = e->semantic(sc);
            return e;
        }
        if (d->needThis() && fd && fd->vthis)
        {
            e = new DotVarExp(e->loc, new ThisExp(e->loc), d);
            e = e->semantic(sc);
            return e;
        }
        return new VarExp(e->loc, d, 1);
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
#if 0
        Expression *b = new AddrExp(e->loc, e);
        b->type = e->type->pointerTo();
        b = new AddExp(e->loc, b, new IntegerExp(e->loc, v->offset, Type::tint32));
        b->type = v->type->pointerTo();
        b = new PtrExp(e->loc, b);
        b->type = v->type->addMod(e->type->mod);
        return b;
#endif
    }

    de = new DotVarExp(e->loc, e, d);
    return de->semantic(sc);
}

unsigned TypeStruct::memalign(unsigned salign)
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
    if (sym->isNested())
        return defaultInit(loc);
    Expressions *structelems = new Expressions();
    structelems->setDim(sym->fields.dim);
    for (size_t j = 0; j < structelems->dim; j++)
    {
        VarDeclaration *vd = sym->fields.tdata()[j];
        Expression *e;
        if (vd->init)
        {   if (vd->init->isVoidInitializer())
                e = NULL;
            else
                e = vd->init->toExpression();
        }
        else
            e = vd->type->defaultInitLiteral();
        structelems->tdata()[j] = e;
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

int TypeStruct::needsDestruction()
{
    return sym->dtor != NULL;
}

int TypeStruct::isAssignable()
{
    int assignable = TRUE;
    unsigned offset;

    /* If any of the fields are const or invariant,
     * then one cannot assign this struct.
     */
    for (size_t i = 0; i < sym->fields.dim; i++)
    {   VarDeclaration *v = sym->fields.tdata()[i];
        //printf("%s [%d] v = (%s) %s, v->offset = %d, v->parent = %s", sym->toChars(), i, v->kind(), v->toChars(), v->offset, v->parent->kind());
        if (i == 0)
            ;
        else if (v->offset == offset)
        {
            /* If any fields of anonymous union are assignable,
             * then regard union as assignable.
             * This is to support unsafe things like Rebindable templates.
             */
            if (assignable)
                continue;
        }
        else
        {
            if (!assignable)
                return FALSE;
        }
        assignable = v->type->isMutable() && v->type->isAssignable();
        offset = v->offset;
        //printf(" -> assignable = %d\n", assignable);
    }

    return assignable;
}

int TypeStruct::hasPointers()
{
    // Probably should cache this information in sym rather than recompute
    StructDeclaration *s = sym;

    sym->size(0);               // give error for forward references
    for (size_t i = 0; i < s->fields.dim; i++)
    {
        Dsymbol *sm = s->fields.tdata()[i];
        Declaration *d = sm->isDeclaration();
        if (d->storage_class & STCref || d->hasPointers())
            return TRUE;
    }
    return FALSE;
}

static MATCH aliasthisConvTo(AggregateDeclaration *ad, Type *from, Type *to)
{
    assert(ad->aliasthis);
    Declaration *d = ad->aliasthis->isDeclaration();
    if (d)
    {   assert(d->type);
        Type *t = d->type;
        if (d->isVarDeclaration() && d->needThis())
        {
            t = t->addMod(from->mod);
        }
        else if (d->isFuncDeclaration())
        {
            FuncDeclaration *fd = (FuncDeclaration *)d;
            Expression *ethis = from->defaultInit(0);
            fd = fd->overloadResolve(0, ethis, NULL);
            if (fd)
            {
                t = ((TypeFunction *)fd->type)->next;
            }
        }
        MATCH m = t->implicitConvTo(to);
        return m;
    }
    return MATCHnomatch;
}

MATCH TypeStruct::implicitConvTo(Type *to)
{   MATCH m;

    //printf("TypeStruct::implicitConvTo(%s => %s)\n", toChars(), to->toChars());
    if (to->ty == Taarray)
    {
        /* If there is an error instantiating AssociativeArray!(), it shouldn't
         * be reported -- it just means implicit conversion is impossible.
         */
        ++global.gag;
        int errs = global.errors;
        to = ((TypeAArray*)to)->getImpl()->type;
        --global.gag;
        if (errs != global.errors)
        {
            global.errors = errs;
            return MATCHnomatch;
        }
    }

    if (ty == to->ty && sym == ((TypeStruct *)to)->sym)
    {   m = MATCHexact;         // exact match
        if (mod != to->mod)
        {
            if (MODimplicitConv(mod, to->mod))
                m = MATCHconst;
            else
            {   /* Check all the fields. If they can all be converted,
                 * allow the conversion.
                 */
                for (size_t i = 0; i < sym->fields.dim; i++)
                {   Dsymbol *s = sym->fields.tdata()[i];
                    VarDeclaration *v = s->isVarDeclaration();
                    assert(v && v->storage_class & STCfield);

                    // 'from' type
                    Type *tvf = v->type->addMod(mod);

                    // 'to' type
                    Type *tv = v->type->castMod(to->mod);

                    //printf("\t%s => %s, match = %d\n", v->type->toChars(), tv->toChars(), tvf->implicitConvTo(tv));
                    if (tvf->implicitConvTo(tv) < MATCHconst)
                        return MATCHnomatch;
                }
                m = MATCHconst;
            }
        }
    }
    else if (sym->aliasthis)
        m = aliasthisConvTo(sym, this, to);
    else
        m = MATCHnomatch;       // no match
    return m;
}

Type *TypeStruct::toHeadMutable()
{
    return this;
}

MATCH TypeStruct::constConv(Type *to)
{
    if (equals(to))
        return MATCHexact;
    if (ty == to->ty && sym == ((TypeStruct *)to)->sym &&
        MODimplicitConv(mod, to->mod))
        return MATCHconst;
    return MATCHnomatch;
}


/***************************** TypeClass *****************************/

TypeClass::TypeClass(ClassDeclaration *sym)
        : Type(Tclass)
{
    this->sym = sym;
}

char *TypeClass::toChars()
{
    if (mod)
        return Type::toChars();
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
    return PTRSIZE;
}

Dsymbol *TypeClass::toDsymbol(Scope *sc)
{
    return sym;
}

void TypeClass::toDecoBuffer(OutBuffer *buf, int flag)
{
    const char *name = sym->mangle();
    //printf("TypeClass::toDecoBuffer('%s' flag=%d mod=%x) = '%s'\n", toChars(), flag, mod, name);
    Type::toDecoBuffer(buf, flag);
    buf->printf("%s", name);
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
        Expressions *exps = new Expressions;
        exps->reserve(sym->fields.dim);
        for (size_t i = 0; i < sym->fields.dim; i++)
        {   VarDeclaration *v = sym->fields.tdata()[i];
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
            assert(ClassDeclaration::classinfo);
            Type *t = ClassDeclaration::classinfo->type;
            if (e->op == TOKtype || e->op == TOKdottype)
            {
                /* For type.classinfo, we know the classinfo
                 * at compile time.
                 */
                if (!sym->vclassinfo)
                    sym->vclassinfo = new TypeInfoClassDeclaration(sym->type);
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
                    if (sym->isCPPinterface())
                    {   /* C++ interface vtbl[]s are different in that the
                         * first entry is always pointer to the first virtual
                         * function, not classinfo.
                         * We can't get a .classinfo for it.
                         */
                        error(e->loc, "no .classinfo for C++ interface objects");
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
             * *cast(invariant(void*)**)e
             */
            e = e->castTo(sc, tvoidptr->invariantOf()->pointerTo()->pointerTo());
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
            return noMember(sc, e, ident);
        }
    }
    if (!s->isFuncDeclaration())        // because of overloading
        s->checkDeprecated(e->loc, sc);
    s = s->toAlias();
    v = s->isVarDeclaration();
    if (v && !v->isDataseg())
    {   Expression *ei = v->getConstInitializer();

        if (ei)
        {   e = ei->copy();     // need to copy it if it's a StringExp
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

    OverloadSet *o = s->isOverloadSet();
    if (o)
    {
        OverExp *oe = new OverExp(o);
        if (e->op == TOKtype)
            return oe;
        return new DotExp(e->loc, e, oe);
    }

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
            VarExp *ve = new VarExp(e->loc, d, 1);
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
        e->type = d->type;
        return e;
    }

    if (d->parent && d->toParent()->isModule())
    {
        // (e, d)

        VarExp *ve = new VarExp(e->loc, d, 1);
        e = new CommaExp(e->loc, e, ve);
        e->type = d->type;
        return e;
    }

    DotVarExp *de = new DotVarExp(e->loc, e, d);
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
    //printf("TypeClass::implicitConvTo(to = '%s') %s\n", to->toChars(), toChars());
    MATCH m = constConv(to);
    if (m != MATCHnomatch)
        return m;

    ClassDeclaration *cdto = to->isClassHandle();
    if (cdto && cdto->isBaseOf(sym, NULL))
    {   //printf("'to' is base\n");
        return MATCHconvert;
    }

    if (global.params.Dversion == 1)
    {
        // Allow conversion to (void *)
        if (to->ty == Tpointer && ((TypePointer *)to)->next->ty == Tvoid)
            return MATCHconvert;
    }

    m = MATCHnomatch;
    if (sym->aliasthis)
        m = aliasthisConvTo(sym, this, to);

    return m;
}

MATCH TypeClass::constConv(Type *to)
{
    if (equals(to))
        return MATCHexact;
    if (ty == to->ty && sym == ((TypeClass *)to)->sym &&
        MODimplicitConv(mod, to->mod))
        return MATCHconst;
    return MATCHnomatch;
}

Type *TypeClass::toHeadMutable()
{
    return this;
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
    : Type(Ttuple)
{
    //printf("TypeTuple(this = %p)\n", this);
    this->arguments = arguments;
    //printf("TypeTuple() %p, %s\n", this, toChars());
#ifdef DEBUG
    if (arguments)
    {
        for (size_t i = 0; i < arguments->dim; i++)
        {
            Parameter *arg = arguments->tdata()[i];
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
    : Type(Ttuple)
{
    Parameters *arguments = new Parameters;
    if (exps)
    {
        arguments->setDim(exps->dim);
        for (size_t i = 0; i < exps->dim; i++)
        {   Expression *e = exps->tdata()[i];
            if (e->type->ty == Ttuple)
                e->error("cannot form tuple of tuples");
            Parameter *arg = new Parameter(STCundefined, e->type, NULL, NULL);
            arguments->tdata()[i] = arg;
        }
    }
    this->arguments = arguments;
    //printf("TypeTuple() %p, %s\n", this, toChars());
}

/*******************************************
 * Type tuple with 0, 1 or 2 types in it.
 */
TypeTuple::TypeTuple()
    : Type(Ttuple)
{
    arguments = new Parameters();
}

TypeTuple::TypeTuple(Type *t1)
    : Type(Ttuple)
{
    arguments = new Parameters();
    arguments->push(new Parameter(0, t1, NULL, NULL));
}

TypeTuple::TypeTuple(Type *t1, Type *t2)
    : Type(Ttuple)
{
    arguments = new Parameters();
    arguments->push(new Parameter(0, t1, NULL, NULL));
    arguments->push(new Parameter(0, t2, NULL, NULL));
}

Type *TypeTuple::syntaxCopy()
{
    Parameters *args = Parameter::arraySyntaxCopy(arguments);
    Type *t = new TypeTuple(args);
    t->mod = mod;
    return t;
}

Type *TypeTuple::semantic(Loc loc, Scope *sc)
{
    //printf("TypeTuple::semantic(this = %p)\n", this);
    //printf("TypeTuple::semantic() %p, %s\n", this, toChars());
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
            {   Parameter *arg1 = arguments->tdata()[i];
                Parameter *arg2 = tt->arguments->tdata()[i];

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
            Parameter *arg = arguments->tdata()[i];
            Type *t = arg->type->reliesOnTident();
            if (t)
                return t;
        }
    }
    return NULL;
}

#if 0
Type *TypeTuple::makeConst()
{
    //printf("TypeTuple::makeConst() %s\n", toChars());
    if (cto)
        return cto;
    TypeTuple *t = (TypeTuple *)Type::makeConst();
    t->arguments = new Parameters();
    t->arguments->setDim(arguments->dim);
    for (size_t i = 0; i < arguments->dim; i++)
    {   Parameter *arg = arguments->tdata()[i];
        Parameter *narg = new Parameter(arg->storageClass, arg->type->constOf(), arg->ident, arg->defaultArg);
        t->arguments->tdata()[i] = (Parameter *)narg;
    }
    return t;
}
#endif

void TypeTuple::toCBuffer2(OutBuffer *buf, HdrGenState *hgs, int mod)
{
    Parameter::argsToCBuffer(buf, hgs, arguments, 0);
}

void TypeTuple::toDecoBuffer(OutBuffer *buf, int flag)
{
    //printf("TypeTuple::toDecoBuffer() this = %p, %s\n", this, toChars());
    Type::toDecoBuffer(buf, flag);
    OutBuffer buf2;
    Parameter::argsToDecoBuffer(&buf2, arguments);
    unsigned len = buf2.offset;
    buf->printf("%d%.*s", len, len, (char *)buf2.extractData());
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
        e = new ErrorExp();
    }
    return e;
}

/***************************** TypeSlice *****************************/

/* This is so we can slice a TypeTuple */

TypeSlice::TypeSlice(Type *next, Expression *lwr, Expression *upr)
    : TypeNext(Tslice, next)
{
    //printf("TypeSlice[%s .. %s]\n", lwr->toChars(), upr->toChars());
    this->lwr = lwr;
    this->upr = upr;
}

Type *TypeSlice::syntaxCopy()
{
    Type *t = new TypeSlice(next->syntaxCopy(), lwr->syntaxCopy(), upr->syntaxCopy());
    t->mod = mod;
    return t;
}

Type *TypeSlice::semantic(Loc loc, Scope *sc)
{
    //printf("TypeSlice::semantic() %s\n", toChars());
    next = next->semantic(loc, sc);
    transitive();
    //printf("next: %s\n", next->toChars());

    Type *tbn = next->toBasetype();
    if (tbn->ty != Ttuple)
    {   error(loc, "can only slice tuple types, not %s", tbn->toChars());
        return Type::terror;
    }
    TypeTuple *tt = (TypeTuple *)tbn;

    lwr = semanticLength(sc, tbn, lwr);
    lwr = lwr->optimize(WANTvalue | WANTinterpret);
    uinteger_t i1 = lwr->toUInteger();

    upr = semanticLength(sc, tbn, upr);
    upr = upr->optimize(WANTvalue | WANTinterpret);
    uinteger_t i2 = upr->toUInteger();

    if (!(i1 <= i2 && i2 <= tt->arguments->dim))
    {   error(loc, "slice [%ju..%ju] is out of range of [0..%u]", i1, i2, tt->arguments->dim);
        return Type::terror;
    }

    Parameters *args = new Parameters;
    args->reserve(i2 - i1);
    for (size_t i = i1; i < i2; i++)
    {   Parameter *arg = tt->arguments->tdata()[i];
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
            ScopeDsymbol *sym = new ArrayScopeSymbol(sc, td);
            sym->parent = sc->scopesym;
            sc = sc->push(sym);

            lwr = lwr->semantic(sc);
            lwr = lwr->optimize(WANTvalue | WANTinterpret);
            uinteger_t i1 = lwr->toUInteger();

            upr = upr->semantic(sc);
            upr = upr->optimize(WANTvalue | WANTinterpret);
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
                objects->tdata()[i] = td->objects->tdata()[(size_t)i1 + i];
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
        {   Parameter *arg = args->tdata()[i];

            arg = arg->syntaxCopy();
            a->tdata()[i] = arg;
        }
    }
    return a;
}

char *Parameter::argsTypesToChars(Parameters *args, int varargs)
{
    OutBuffer *buf = new OutBuffer();

#if 1
    HdrGenState hgs;
    argsToCBuffer(buf, &hgs, args, varargs);
#else
    buf->writeByte('(');
    if (args)
    {   OutBuffer argbuf;
        HdrGenState hgs;

        for (size_t i = 0; i < args->dim; i++)
        {   if (i)
                buf->writeByte(',');
            Parameter *arg = args->tdata()[i];
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
#endif
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
            Parameter *arg = arguments->tdata()[i];

            if (arg->storageClass & STCauto)
                buf->writestring("auto ");

            if (arg->storageClass & STCout)
                buf->writestring("out ");
            else if (arg->storageClass & STCref)
                buf->writestring((global.params.Dversion == 1)
                        ? "inout " : "ref ");
            else if (arg->storageClass & STCin)
                buf->writestring("in ");
            else if (arg->storageClass & STClazy)
                buf->writestring("lazy ");
            else if (arg->storageClass & STCalias)
                buf->writestring("alias ");

            StorageClass stc = arg->storageClass;
            if (arg->type && arg->type->mod & MODshared)
                stc &= ~STCshared;

            StorageClassDeclaration::stcToCBuffer(buf,
                stc & (STCconst | STCimmutable | STCshared | STCscope));

            argbuf.reset();
            if (arg->storageClass & STCalias)
            {   if (arg->ident)
                    argbuf.writestring(arg->ident->toChars());
            }
            else
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
                buf->writeByte(',');
            buf->writestring("...");
        }
    }
    buf->writeByte(')');
}


void Parameter::argsToDecoBuffer(OutBuffer *buf, Parameters *arguments)
{
    //printf("Parameter::argsToDecoBuffer()\n");

    // Write argument types
    if (arguments)
    {
        size_t dim = Parameter::dim(arguments);
        for (size_t i = 0; i < dim; i++)
        {
            Parameter *arg = Parameter::getNth(arguments, i);
            arg->toDecoBuffer(buf);
        }
    }
}


/****************************************
 * Determine if parameter list is really a template parameter list
 * (i.e. it has auto or alias parameters)
 */

int Parameter::isTPL(Parameters *arguments)
{
    //printf("Parameter::isTPL()\n");

    if (arguments)
    {
        size_t dim = Parameter::dim(arguments);
        for (size_t i = 0; i < dim; i++)
        {
            Parameter *arg = Parameter::getNth(arguments, i);
            if (arg->storageClass & (STCalias | STCauto | STCstatic))
                return 1;
        }
    }
    return 0;
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
            Type *tel = ((TypeArray *)tb)->next->toBasetype();
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
    if (storageClass & STCscope)
        buf->writeByte('M');
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
#if 0
    int mod = 0x100;
    if (type->toBasetype()->ty == Tclass)
        mod = 0;
    type->toDecoBuffer(buf, mod);
#else
    //type->toHeadMutable()->toDecoBuffer(buf, 0);
    type->toDecoBuffer(buf, 0);
#endif
}

/***************************************
 * Determine number of arguments, folding in tuples.
 */

size_t Parameter::dim(Parameters *args)
{
    size_t n = 0;
    if (args)
    {
        for (size_t i = 0; i < args->dim; i++)
        {   Parameter *arg = args->tdata()[i];
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
 * Get nth Parameter, folding in tuples.
 * Returns:
 *      Parameter*      nth Parameter
 *      NULL            not found, *pn gets incremented by the number
 *                      of Parameters
 */

Parameter *Parameter::getNth(Parameters *args, size_t nth, size_t *pn)
{
    if (!args)
        return NULL;

    size_t n = 0;
    for (size_t i = 0; i < args->dim; i++)
    {   Parameter *arg = args->tdata()[i];
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
