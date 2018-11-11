/**
 * Compiler implementation of the
 * $(LINK2 http://www.dlang.org, D programming language).
 *
 * Copyright:   Copyright (C) 1985-1998 by Symantec
 *              Copyright (C) 2000-2018 by The D Language Foundation, All Rights Reserved
 * Authors:     $(LINK2 http://www.digitalmars.com, Walter Bright)
 * License:     $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Source:      $(LINK2 https://github.com/dlang/dmd/blob/master/src/dmd/backend/fp.c, backend/fp.c)
 */

#if !SPP

#include        <math.h>
#include        <float.h>

#if defined __OpenBSD__
    #include <sys/param.h>
    #if OpenBSD < 201111 // 5.0
        #define HAVE_FENV_H 0
    #else
        #define HAVE_FENV_H 1
    #endif
#elif _MSC_VER
    #define HAVE_FENV_H 0
#else
    #define HAVE_FENV_H 1
#endif

#if HAVE_FENV_H
#include        <fenv.h>
#endif

#if __DMC__
#include        <fp.h>
#endif

#if _MSC_VER
#include        "longdouble.h"
#else
typedef long double longdouble;
#endif

#if __DMC__
    #define HAVE_FLOAT_EXCEPT 1

    int statusFE() { return _status87(); }

    int testFE()
    {
        return _status87() & 0x3F;
    }

    void clearFE()
    {
        _clear87();
    }
#elif HAVE_FENV_H
    #define HAVE_FLOAT_EXCEPT 1

    int statusFE() { return 0; }

    int testFE()
    {
        return fetestexcept(FE_ALL_EXCEPT);
    }

    void clearFE()
    {
        feclearexcept(FE_ALL_EXCEPT);
    }
#elif defined _MSC_VER /*&& TX86*/
    #define HAVE_FLOAT_EXCEPT 1

    int statusFE() { return 0; }

    int testFE()
    {
        return (ld_statusfpu() | _statusfp()) & 0x3F;
    }

    void clearFE()
    {
        _clearfp();
        ld_clearfpu();
    }
#else
    #define HAVE_FLOAT_EXCEPT 0
    int statusFE() { return 0; }
    int  testFE() { return 1; }
    void clearFE() { }
#endif

bool have_float_except() { return HAVE_FLOAT_EXCEPT; }

/************************************
 * Helper to do % for long doubles.
 */

longdouble _modulo(longdouble x, longdouble y)
{
#if __DMC__
    short sw;

    __asm
    {
        fld     tbyte ptr y
        fld     tbyte ptr x             // ST = x, ST1 = y
FM1:    // We don't use fprem1 because for some inexplicable
        // reason we get -5 when we do _modulo(15, 10)
        fprem                           // ST = ST % ST1
        fstsw   word ptr sw
        fwait
        mov     AH,byte ptr sw+1        // get msb of status word in AH
        sahf                            // transfer to flags
        jp      FM1                     // continue till ST < ST1
        fstp    ST(1)                   // leave remainder on stack
    }
#elif __FreeBSD__ || __OpenBSD__ || __DragonFly__
    return fmod(x, y);
#else
    return fmodl(x, y);
#endif
}

#endif /* !SPP */
