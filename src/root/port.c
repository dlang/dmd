
// Copyright (c) 1999-2002 by Digital Mars
// All Rights Reserved
// written by Walter Bright
// www.digitalmars.com

#include "port.h"

#if __DMC__
#include <math.h>
#include <float.h>
#include <fp.h>
#include <time.h>
#include <stdlib.h>

double Port::nan = NAN;
double Port::infinity = INFINITY;
double Port::dbl_max = DBL_MAX;
double Port::dbl_min = DBL_MIN;

int Port::isNan(double r)
{
    return ::isnan(r);
}

int Port::isFinite(double r)
{
    return ::isfinite(r);
}

int Port::isInfinity(double r)
{
    return (::fpclassify(r) == FP_INFINITE);
}

int Port::Signbit(double r)
{
    return ::signbit(r);
}

double Port::floor(double d)
{
    return ::floor(d);
}

double Port::pow(double x, double y)
{
    return ::pow(x, y);
}

unsigned long long Port::strtoull(const char *p, char **pend, int base)
{
    return ::strtoull(p, pend, base);
}

char *Port::ull_to_string(char *buffer, ulonglong ull)
{
    sprintf(buffer, "%llu", ull);
    return buffer;
}

wchar_t *Port::ull_to_string(wchar_t *buffer, ulonglong ull)
{
    swprintf(buffer, sizeof(ulonglong) * 3 + 1, L"%llu", ull);
    return buffer;
}

double Port::ull_to_double(ulonglong ull)
{
    return (double) ull;
}

char *Port::list_separator()
{
    // LOCALE_SLIST for Windows
    return ",";
}

wchar_t *Port::wlist_separator()
{
    // LOCALE_SLIST for Windows
    return L",";
}

#endif

#if _MSC_VER

// Disable useless warnings about unreferenced functions
#pragma warning (disable : 4514)

#include <math.h>
#include <float.h>
#include <time.h>
#include <errno.h>
#include <string.h>
#include <ctype.h>
#include <stdlib.h>

static unsigned long nanarray[2] = {0,0x7FF80000 };
double Port::nan = (*(double *)nanarray);

//static unsigned long infinityarray[2] = {0,0x7FF00000 };
static double zero = 0;
double Port::infinity = 1 / zero;

double Port::dbl_max = DBL_MAX;
double Port::dbl_min = DBL_MIN;

int Port::isNan(double r)
{
    return ::_isnan(r);
}

int Port::isFinite(double r)
{
    return ::_finite(r);
}

int Port::isInfinity(double r)
{
    return (::_fpclass(r) & (_FPCLASS_NINF | _FPCLASS_PINF));
}

int Port::Signbit(double r)
{
    return (long)(((long *)&(r))[1] & 0x80000000);
}

double Port::floor(double d)
{
    return ::floor(d);
}

double Port::pow(double x, double y)
{
    if (y == 0)
	return 1;		// even if x is NAN
    return ::pow(x, y);
}

unsigned _int64 Port::strtoull(const char *p, char **pend, int base)
{
    unsigned _int64 number = 0;
    int c;
    int error;
    #define ULLONG_MAX ((unsigned _int64)~0I64)

    while (isspace(*p))		/* skip leading white space	*/
	p++;
    if (*p == '+')
	p++;
    switch (base)
    {   case 0:
	    base = 10;		/* assume decimal base		*/
	    if (*p == '0')
	    {   base = 8;	/* could be octal		*/
		    p++;
		    switch (*p)
		    {   case 'x':
			case 'X':
			    base = 16;	/* hex			*/
			    p++;
			    break;
#if BINARY
			case 'b':
			case 'B':
			    base = 2;	/* binary		*/
			    p++;
			    break;
#endif
		    }
	    }
	    break;
	case 16:			/* skip over '0x' and '0X'	*/
	    if (*p == '0' && (p[1] == 'x' || p[1] == 'X'))
		    p += 2;
	    break;
#if BINARY
	case 2:			/* skip over '0b' and '0B'	*/
	    if (*p == '0' && (p[1] == 'b' || p[1] == 'B'))
		    p += 2;
	    break;
#endif
    }
    error = 0;
    for (;;)
    {   c = *p;
	if (isdigit(c))
		c -= '0';
	else if (isalpha(c))
		c = (c & ~0x20) - ('A' - 10);
	else			/* unrecognized character	*/
		break;
	if (c >= base)		/* not in number base		*/
		break;
	if ((ULLONG_MAX - c) / base < number)
		error = 1;
	number = number * base + c;
	p++;
    }
    if (pend)
	*pend = (char *)p;
    if (error)
    {   number = ULLONG_MAX;
	errno = ERANGE;
    }
    return number;
}

char *Port::ull_to_string(char *buffer, ulonglong ull)
{
    _ui64toa(ull, buffer, 10);
    return buffer;
}

wchar_t *Port::ull_to_string(wchar_t *buffer, ulonglong ull)
{
    _ui64tow(ull, buffer, 10);
    return buffer;
}

double Port::ull_to_double(ulonglong ull)
{   double d;

    if ((__int64) ull < 0)
    {
	// MSVC doesn't implement the conversion
	d = (double) (__int64)(ull -  0x8000000000000000i64);
	d += (double)(signed __int64)(0x7FFFFFFFFFFFFFFFi64) + 1.0;
    }
    else
	d = (double)(__int64)ull;
    return d;
}

char *Port::list_separator()
{
    // LOCALE_SLIST for Windows
    return ",";
}

wchar_t *Port::wlist_separator()
{
    // LOCALE_SLIST for Windows
    return L",";
}

#endif

#if linux || __APPLE__ || __FreeBSD__

#include <math.h>
#include <bits/nan.h>
#include <bits/mathdef.h>
#include <time.h>
#include <sys/time.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>

static double zero = 0;
double Port::nan = NAN;
double Port::infinity = 1 / zero;
double Port::dbl_max = 1.7976931348623157e308;
double Port::dbl_min = 5e-324;

#undef isnan
int Port::isNan(double r)
{
    return ::isnan(r);
}

#undef isfinite
int Port::isFinite(double r)
{
    return ::finite(r);
}

#undef isinf
int Port::isInfinity(double r)
{
    return ::isinf(r);
}

#undef signbit
int Port::Signbit(double r)
{
    return (long)(((long *)&r)[1] & 0x80000000);
}

double Port::floor(double d)
{
    return ::floor(d);
}

double Port::pow(double x, double y)
{
    return ::pow(x, y);
}

unsigned long long Port::strtoull(const char *p, char **pend, int base)
{
    return ::strtoull(p, pend, base);
}

char *Port::ull_to_string(char *buffer, ulonglong ull)
{
    sprintf(buffer, "%llu", ull);
    return buffer;
}

wchar_t *Port::ull_to_string(wchar_t *buffer, ulonglong ull)
{
    swprintf(buffer, L"%llu", ull);
    return buffer;
}

double Port::ull_to_double(ulonglong ull)
{
    return (double) ull;
}

char *Port::list_separator()
{
    return ",";
}

wchar_t *Port::wlist_separator()
{
    return L",";
}

#endif
