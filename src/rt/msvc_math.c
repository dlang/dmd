/**
* This module provides alternate implementations of single-precision math
* functions missing in at least some 32-bit x86 MS VC runtimes
*
* Copyright: Copyright Digital Mars 2015.
* License: Distributed under the
*      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
*    (See accompanying file LICENSE)
* Source:    $(DRUNTIMESRC rt/_msvc_math.c)
* Authors:   Martin Kinkelin
*/

#if defined _M_IX86

// Forward-declare double-precision version and implement single-precision
// wrapper.
#define ALT_IMPL(baseName) \
    double baseName(double x); \
    float _msvc_ ## baseName ## f(float x) { return (float)baseName(x); }
#define ALT_IMPL2(baseName) \
    double baseName(double x, double y); \
    float _msvc_ ## baseName ## f(float x, float y) { return (float)baseName(x, y); }

ALT_IMPL(acos);
ALT_IMPL(asin);
ALT_IMPL(atan);
ALT_IMPL2(atan2);
ALT_IMPL(cos);
ALT_IMPL(sin);
ALT_IMPL(tan);
ALT_IMPL(cosh);
ALT_IMPL(sinh);
ALT_IMPL(tanh);
ALT_IMPL(exp);
ALT_IMPL(log);
ALT_IMPL(log10);
ALT_IMPL2(pow);
ALT_IMPL(sqrt);
ALT_IMPL(ceil);
ALT_IMPL(floor);
ALT_IMPL2(fmod);

double modf(double value, double *iptr);
float _msvc_modff(float value, float *iptr)
{
    double di;
    float result = (float)modf(value, &di);
    *iptr = (float)di;
    return result;
}

#endif // _M_IX86
