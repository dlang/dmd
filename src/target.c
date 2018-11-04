
/* Compiler implementation of the D programming language
 * Copyright (C) 2013-2018 by The D Language Foundation, All Rights Reserved
 * All Rights Reserved
 * written by Iain Buclaw
 * http://www.digitalmars.com
 * Distributed under the Boost Software License, Version 1.0.
 * http://www.boost.org/LICENSE_1_0.txt
 * https://github.com/D-Programming-Language/dmd/blob/master/src/target.c
 */

#include "root/dsystem.h"

#if defined(__GNUC__) || defined(__clang__)
#include <limits> // for std::numeric_limits
#else
#include <math.h>
#include <float.h>
#endif

#include "target.h"
#include "aggregate.h"
#include "mars.h"
#include "mtype.h"
#include "root/outbuffer.h"

const char *toCppMangleItanium(Dsymbol *);
const char *cppTypeInfoMangleItanium(Dsymbol *);
const char *toCppMangleMSVC(Dsymbol *);
const char *cppTypeInfoMangleMSVC(Dsymbol *);

int Target::ptrsize;
int Target::realsize;
int Target::realpad;
int Target::realalignsize;
bool Target::reverseCppOverloads;
bool Target::cppExceptions;
int Target::c_longsize;
int Target::c_long_doublesize;
int Target::classinfosize;
unsigned long long Target::maxStaticDataSize;

/* Floating point constants for for .max, .min, and other properties.  */
template <typename T> real_t Target::FPTypeProperties<T>::max;
template <typename T> real_t Target::FPTypeProperties<T>::min_normal;
template <typename T> real_t Target::FPTypeProperties<T>::nan;
template <typename T> real_t Target::FPTypeProperties<T>::snan;
template <typename T> real_t Target::FPTypeProperties<T>::infinity;
template <typename T> real_t Target::FPTypeProperties<T>::epsilon;
template <typename T> d_int64 Target::FPTypeProperties<T>::dig;
template <typename T> d_int64 Target::FPTypeProperties<T>::mant_dig;
template <typename T> d_int64 Target::FPTypeProperties<T>::max_exp;
template <typename T> d_int64 Target::FPTypeProperties<T>::min_exp;
template <typename T> d_int64 Target::FPTypeProperties<T>::max_10_exp;
template <typename T> d_int64 Target::FPTypeProperties<T>::min_10_exp;

/* Initialize the floating point constants for TYPE.  */

template <typename T, typename V>
static void initFloatConstants()
{
#if defined(__GNUC__) || defined(__clang__)
    T::max = std::numeric_limits<V>::max();
    T::min_normal = std::numeric_limits<V>::min();

    assert(std::numeric_limits<V>::has_quiet_NaN);
    T::nan = std::numeric_limits<V>::quiet_NaN();

    assert(std::numeric_limits<V>::has_signaling_NaN);
    T::snan = std::numeric_limits<V>::signaling_NaN();

    assert(std::numeric_limits<V>::has_infinity);
    T::infinity = std::numeric_limits<V>::infinity();

    T::epsilon = std::numeric_limits<V>::epsilon();
    T::dig = std::numeric_limits<V>::digits10;
    T::mant_dig = std::numeric_limits<V>::digits;
    T::max_exp = std::numeric_limits<V>::max_exponent;
    T::min_exp = std::numeric_limits<V>::min_exponent;
    T::max_10_exp = std::numeric_limits<V>::max_exponent10;
    T::min_10_exp = std::numeric_limits<V>::min_exponent10;
#else
    union
    {   unsigned int ui[4];
        real_t ld;
    } snan = {{ 0, 0xA0000000, 0x7FFF, 0 }};

    if (sizeof(V) == sizeof(float))
    {
        T::max = FLT_MAX;
        T::min_normal = FLT_MIN;

        T::nan = NAN;
        T::snan = snan.ld;
        T::infinity = INFINITY;

        T::epsilon = FLT_EPSILON;
        T::dig = FLT_DIG;
        T::mant_dig = FLT_MANT_DIG;
        T::max_exp = FLT_MAX_EXP;
        T::min_exp = FLT_MIN_EXP;
        T::max_10_exp = FLT_MAX_10_EXP;
        T::min_10_exp = FLT_MIN_10_EXP;
    }
    else if (sizeof(V) == sizeof(double))
    {
        T::max = DBL_MAX;
        T::min_normal = DBL_MIN;

        T::nan = NAN;
        T::snan = snan.ld;
        T::infinity = INFINITY;

        T::epsilon = DBL_EPSILON;
        T::dig = DBL_DIG;
        T::mant_dig = DBL_MANT_DIG;
        T::max_exp = DBL_MAX_EXP;
        T::min_exp = DBL_MIN_EXP;
        T::max_10_exp = DBL_MAX_10_EXP;
        T::min_10_exp = DBL_MIN_10_EXP;
    }
    else
    {
        T::max = LDBL_MAX;
        T::min_normal = LDBL_MIN;

        T::nan = NAN;
        T::snan = snan.ld;
        T::infinity = INFINITY;

        T::epsilon = LDBL_EPSILON;
        T::dig = LDBL_DIG;
        T::mant_dig = LDBL_MANT_DIG;
        T::max_exp = LDBL_MAX_EXP;
        T::min_exp = LDBL_MIN_EXP;
        T::max_10_exp = LDBL_MAX_10_EXP;
        T::min_10_exp = LDBL_MIN_10_EXP;
    }
#endif
}

void Target::_init()
{
    // These have default values for 32 bit code, they get
    // adjusted for 64 bit code.
    ptrsize = 4;
    classinfosize = 0x4C;   // 76

    /* gcc uses int.max for 32 bit compilations, and long.max for 64 bit ones.
     * Set to int.max for both, because the rest of the compiler cannot handle
     * 2^64-1 without some pervasive rework. The trouble is that much of the
     * front and back end uses 32 bit ints for sizes and offsets. Since C++
     * silently truncates 64 bit ints to 32, finding all these dependencies will be a problem.
     */
    maxStaticDataSize = 0x7FFFFFFF;

    if (global.params.isLP64)
    {
        ptrsize = 8;
        classinfosize = 0x98;   // 152
    }

    if (global.params.isLinux || global.params.isFreeBSD
        || global.params.isOpenBSD || global.params.isSolaris)
    {
        realsize = 12;
        realpad = 2;
        realalignsize = 4;
        c_longsize = 4;
    }
    else if (global.params.isOSX)
    {
        realsize = 16;
        realpad = 6;
        realalignsize = 16;
        c_longsize = 4;
    }
    else if (global.params.isWindows)
    {
        realsize = 10;
        realpad = 0;
        realalignsize = 2;
        reverseCppOverloads = !global.params.is64bit;
        c_longsize = 4;
        if (ptrsize == 4)
        {
            /* Optlink cannot deal with individual data chunks
             * larger than 16Mb
             */
            maxStaticDataSize = 0x1000000;  // 16Mb
        }
    }
    else
        assert(0);

    if (global.params.is64bit)
    {
        if (global.params.isLinux || global.params.isFreeBSD || global.params.isSolaris)
        {
            realsize = 16;
            realpad = 6;
            realalignsize = 16;
            c_longsize = 8;
        }
        else if (global.params.isOSX)
        {
            c_longsize = 8;
        }
    }

    c_long_doublesize = realsize;
    if (global.params.is64bit && global.params.isWindows)
        c_long_doublesize = 8;

    cppExceptions = global.params.isLinux || global.params.isFreeBSD ||
        global.params.isOSX;

    initFloatConstants<Target::FloatProperties, float>();
    initFloatConstants<Target::DoubleProperties, double>();
    initFloatConstants<Target::RealProperties, real_t>();

}

/******************************
 * Return memory alignment size of type.
 */

unsigned Target::alignsize(Type* type)
{
    assert (type->isTypeBasic());

    switch (type->ty)
    {
        case Tfloat80:
        case Timaginary80:
        case Tcomplex80:
            return Target::realalignsize;

        case Tcomplex32:
            if (global.params.isLinux || global.params.isOSX || global.params.isFreeBSD
                || global.params.isOpenBSD || global.params.isSolaris)
                return 4;
            break;

        case Tint64:
        case Tuns64:
        case Tfloat64:
        case Timaginary64:
        case Tcomplex64:
            if (global.params.isLinux || global.params.isOSX || global.params.isFreeBSD
                || global.params.isOpenBSD || global.params.isSolaris)
                return global.params.is64bit ? 8 : 4;
            break;

        default:
            break;
    }
    return (unsigned)type->size(Loc());
}

/******************************
 * Return field alignment size of type.
 */

unsigned Target::fieldalign(Type* type)
{
    return type->alignsize();
}

/***********************************
 * Return size of OS critical section.
 * NOTE: can't use the sizeof() calls directly since cross compiling is
 * supported and would end up using the host sizes rather than the target
 * sizes.
 */
unsigned Target::critsecsize()
{
    if (global.params.isWindows)
    {
        // sizeof(CRITICAL_SECTION) for Windows.
        return global.params.isLP64 ? 40 : 24;
    }
    else if (global.params.isLinux)
    {
        // sizeof(pthread_mutex_t) for Linux.
        if (global.params.is64bit)
            return global.params.isLP64 ? 40 : 32;
        else
            return global.params.isLP64 ? 40 : 24;
    }
    else if (global.params.isFreeBSD)
    {
        // sizeof(pthread_mutex_t) for FreeBSD.
        return global.params.isLP64 ? 8 : 4;
    }
    else if (global.params.isOpenBSD)
    {
        // sizeof(pthread_mutex_t) for OpenBSD.
        return global.params.isLP64 ? 8 : 4;
    }
    else if (global.params.isOSX)
    {
        // sizeof(pthread_mutex_t) for OSX.
        return global.params.isLP64 ? 64 : 44;
    }
    else if (global.params.isSolaris)
    {
        // sizeof(pthread_mutex_t) for Solaris.
        return 24;
    }
    assert(0);
    return 0;
}

/***********************************
 * Returns a Type for the va_list type of the target.
 * NOTE: For Posix/x86_64 this returns the type which will really
 * be used for passing an argument of type va_list.
 */
Type *Target::va_listType()
{
    if (global.params.isWindows)
    {
        return Type::tchar->pointerTo();
    }
    else if (global.params.isLinux ||
             global.params.isFreeBSD ||
             global.params.isOpenBSD ||
             global.params.isSolaris ||
             global.params.isOSX)
    {
        if (global.params.is64bit)
        {
            return (new TypeIdentifier(Loc(), Identifier::idPool("__va_list_tag")))->pointerTo();
        }
        else
        {
            return Type::tchar->pointerTo();
        }
    }
    else
    {
        assert(0);
        return NULL;
    }
}

/**
 * Checks whether the target supports a vector type with total size `sz`
 * (in bytes) and element type `type`.
 *
 * Returns: 0 if the type is supported, or else: 1 if vector types are not
 *     supported on the target at all, 2 if the element type isn't, or 3 if
 *     the given size isn't.
 */

int Target::isVectorTypeSupported(int sz, Type *type)
{
    if (!global.params.is64bit && !global.params.isOSX)
        return 1; // not supported

    switch (type->ty)
    {
        case Tvoid:
        case Tint8:
        case Tuns8:
        case Tint16:
        case Tuns16:
        case Tint32:
        case Tuns32:
        case Tfloat32:
        case Tint64:
        case Tuns64:
        case Tfloat64:
            break;
        default:
            return 2; // wrong base type
    }

    if (sz != 16 && sz != 32)
        return 3; // wrong size

    return 0;
}

/**
 * Checks whether the target supports operation `op` for vectors of type `type`.
 * For binary ops `t2` is the type of the 2nd operand.
 *
 * Returns:
 *      true if the operation is supported or type is not a vector
 */
bool Target::isVectorOpSupported(Type *type, TOK op, Type *)
{
    if (type->ty != Tvector)
        return true; // not a vector op
    TypeVector *tvec = (TypeVector*)type;

    bool supported;
    switch (op)
    {
        case TOKneg: case TOKuadd:
            supported = tvec->isscalar();
            break;

        case TOKlt: case TOKgt: case TOKle: case TOKge: case TOKequal: case TOKnotequal: case TOKidentity: case TOKnotidentity:
            supported = false;
            break;

        case TOKunord: case TOKlg: case TOKleg: case TOKule: case TOKul: case TOKuge: case TOKug: case TOKue:
            supported = false;
            break;

        case TOKshl: case TOKshlass: case TOKshr: case TOKshrass: case TOKushr: case TOKushrass:
            supported = false;
            break;

        case TOKadd: case TOKaddass: case TOKmin: case TOKminass:
            supported = tvec->isscalar();
            break;

        case TOKmul: case TOKmulass:
            // only floats and short[8]/ushort[8] (PMULLW)
            if (tvec->isfloating() || tvec->elementType()->size(Loc()) == 2)
                supported = true;
            else
                supported = false;
            break;

        case TOKdiv: case TOKdivass:
            supported = tvec->isfloating();
            break;

        case TOKmod: case TOKmodass:
            supported = false;
            break;

        case TOKand: case TOKandass: case TOKor: case TOKorass: case TOKxor: case TOKxorass:
            supported = tvec->isintegral();
            break;

        case TOKnot:
            supported = false;
            break;

        case TOKtilde:
            supported = tvec->isintegral();
            break;

        case TOKpow: case TOKpowass:
            supported = false;
            break;

        default:
            assert(0);
    }
    return supported;
}

const char *Target::toCppMangle(Dsymbol *s)
{
#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
    return toCppMangleItanium(s);
#elif TARGET_WINDOS
    return toCppMangleMSVC(s);
#else
#error "fix this"
#endif
}

const char *Target::cppTypeInfoMangle(ClassDeclaration *cd)
{
#if TARGET_LINUX || TARGET_OSX || TARGET_FREEBSD || TARGET_OPENBSD || TARGET_SOLARIS
    return cppTypeInfoMangleItanium(cd);
#elif TARGET_WINDOS
    return cppTypeInfoMangleMSVC(cd);
#else
#error "fix this"
#endif
}

/******************************
 * For a vendor-specific type, return a string containing the C++ mangling.
 * In all other cases, return null.
 */
const char* Target::cppTypeMangle(Type *)
{
    return NULL;
}

/**
 * Get the type that will really be used for passing the given argument
 * to an `extern(C++)` function.
 * Params:
 *      p = parameter to be passed.
 * Returns:
 *      `Type` to use for parameter `p`.
 */
Type *Target::cppParameterType(Parameter *p)
{
    Type *t = p->type->merge2();
    if (p->storageClass & (STCout | STCref))
        t = t->referenceTo();
    else if (p->storageClass & STClazy)
    {
        // Mangle as delegate
        Type *td = new TypeFunction(NULL, t, 0, LINKd);
        td = new TypeDelegate(td);
        t = t->merge();
    }
    return t;
}

/******************************
 * Return the default system linkage for the target.
 */
LINK Target::systemLinkage()
{
    return global.params.isWindows ? LINKwindows : LINKc;
}
