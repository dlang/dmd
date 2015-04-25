/**
 * D header file for C99.
 *
 * $(C_HEADER_DESCRIPTION pubs.opengroup.org/onlinepubs/009695399/basedefs/_stdlib.h.html, _stdlib.h)
 *
 * Copyright: Copyright Sean Kelly 2005 - 2014.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Sean Kelly
 * Standards: ISO/IEC 9899:1999 (E)
 * Source: $(DRUNTIMESRC src/core/stdc/_stdlib.d)
 */

module core.stdc.stdlib;

private import core.stdc.config;
public import core.stdc.stddef; // for wchar_t

extern (C):
@system:

/* Placed outside @nogc in order to not constrain what the callback does.
 */
///
alias int function(in void*, in void*) _compare_fp_t;
///
void*   bsearch(in void* key, in void* base, size_t nmemb, size_t size, _compare_fp_t compar);
///
void    qsort(void* base, size_t nmemb, size_t size, _compare_fp_t compar);


nothrow:
@nogc:

///
struct div_t
{
    int quot,
        rem;
}

///
struct ldiv_t
{
    int quot,
        rem;
}

///
struct lldiv_t
{
    long quot,
         rem;
}

///
enum EXIT_SUCCESS = 0;
///
enum EXIT_FAILURE = 1;
///
enum MB_CUR_MAX   = 1;

///
version(Windows)      enum RAND_MAX = 0x7fff;
else version(linux)   enum RAND_MAX = 0x7fffffff;
else version(OSX)     enum RAND_MAX = 0x7fffffff;
else version(FreeBSD) enum RAND_MAX = 0x7fffffff;
else version(Solaris) enum RAND_MAX = 0x7fff;
else version(Android) enum RAND_MAX = 0x7fffffff;
else static assert( false, "Unsupported platform" );

///
double  atof(in char* nptr);
///
int     atoi(in char* nptr);
///
c_long  atol(in char* nptr);
///
long    atoll(in char* nptr);

///
double  strtod(in char* nptr, char** endptr);
///
float   strtof(in char* nptr, char** endptr);
///
c_long  strtol(in char* nptr, char** endptr, int base);
///
long    strtoll(in char* nptr, char** endptr, int base);
///
c_ulong strtoul(in char* nptr, char** endptr, int base);
///
ulong   strtoull(in char* nptr, char** endptr, int base);

version (CRuntime_Microsoft)
{
    // strtold exists starting from VS2013, so we make this a template to avoid link errors
    ///
    real strtold()(in char* nptr, char** endptr)
    {   // Fake it 'till we make it
        return strtod(nptr, endptr);
    }
}
else version (MinGW)
{
    ///
    real __mingw_strtold(in char* nptr, char** endptr);
    ///
    alias __mingw_strtold strtold;
}
else version (Android)
{
    ///
    real strtold(in char* nptr, char** endptr)
    {   // Fake it again till we make it
        return strtod(nptr, endptr);
    }
}
else
{
    ///
    real strtold(in char* nptr, char** endptr);
}

// No unsafe pointer manipulation.
@trusted
{
    version(Android)
    {
       import core.sys.posix.stdlib: lrand48, srand48;
       ///
       alias core.sys.posix.stdlib.lrand48 rand;
       ///
       alias core.sys.posix.stdlib.srand48 srand;
    }
    else
    {
        ///
       int     rand();
       ///
       void    srand(uint seed);
    }
}

// We don't mark these @trusted. Given that they return a void*, one has
// to do a pointer cast to do anything sensible with the result. Thus,
// functions using these already have to be @trusted, allowing them to
// call @system stuff anyway.
///
void*   malloc(size_t size);
///
void*   calloc(size_t nmemb, size_t size);
///
void*   realloc(void* ptr, size_t size);
///
void    free(void* ptr);

///
void    abort();
///
void    exit(int status);
///
int     atexit(void function() func);
///
void    _Exit(int status);

///
char*   getenv(in char* name);
///
int     system(in char* string);

// These only operate on integer values.
@trusted
{
    ///
    pure int     abs(int j);
    ///
    pure c_long  labs(c_long j);
    ///
    pure long    llabs(long j);

    ///
    div_t   div(int numer, int denom);
    ///
    ldiv_t  ldiv(c_long numer, c_long denom);
    ///
    lldiv_t lldiv(long numer, long denom);
}

///
int     mblen(in char* s, size_t n);
///
int     mbtowc(wchar_t* pwc, in char* s, size_t n);
///
int     wctomb(char*s, wchar_t wc);
///
size_t  mbstowcs(wchar_t* pwcs, in char* s, size_t n);
///
size_t  wcstombs(char* s, in wchar_t* pwcs, size_t n);

///
version( DigitalMars )
{
    // See malloc comment about @trusted.
    void* alloca(size_t size); // non-standard
}
else version( GNU )
{
    void* alloca(size_t size); // compiler intrinsic
}

version( CRuntime_Microsoft )
{
    ///
    ulong  _strtoui64(in char *,char **,int);
    ///
    ulong  _wcstoui64(in wchar *,wchar **,int);

    ///
    long  _strtoi64(in char *,char **,int);
    ///
    long  _wcstoi64(in wchar *,wchar **,int);
}

