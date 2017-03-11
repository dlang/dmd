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

version (OSX)
    version = Darwin;
else version (iOS)
    version = Darwin;
else version (TVOS)
    version = Darwin;
else version (WatchOS)
    version = Darwin;

extern (C):
@system:

/* Placed outside @nogc in order to not constrain what the callback does.
 */
///
alias int function(scope const void*, scope const void*) _compare_fp_t;
///
inout(void)* bsearch(scope const void* key, scope inout(void)* base, size_t nmemb, size_t size, _compare_fp_t compar);
///
void    qsort(scope void* base, size_t nmemb, size_t size, _compare_fp_t compar);


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
else version(CRuntime_Glibc)  enum RAND_MAX = 0x7fffffff;
else version(Darwin)  enum RAND_MAX = 0x7fffffff;
else version(FreeBSD) enum RAND_MAX = 0x7fffffff;
else version(NetBSD)  enum RAND_MAX = 0x7fffffff;
else version(OpenBSD) enum RAND_MAX = 0x7fffffff;
else version(Solaris) enum RAND_MAX = 0x7fff;
else version(CRuntime_Bionic) enum RAND_MAX = 0x7fffffff;
else static assert( false, "Unsupported platform" );

///
double  atof(scope const char* nptr);
///
int     atoi(scope const char* nptr);
///
c_long  atol(scope const char* nptr);
///
long    atoll(scope const char* nptr);

///
double  strtod(scope inout(char)* nptr, scope inout(char)** endptr);
///
float   strtof(scope inout(char)* nptr, scope inout(char)** endptr);
///
c_long  strtol(scope inout(char)* nptr, scope inout(char)** endptr, int base);
///
long    strtoll(scope inout(char)* nptr, scope inout(char)** endptr, int base);
///
c_ulong strtoul(scope inout(char)* nptr, scope inout(char)** endptr, int base);
///
ulong   strtoull(scope inout(char)* nptr, scope inout(char)** endptr, int base);

version (CRuntime_Microsoft)
{
    // strtold exists starting from VS2013, so we give it D linkage to avoid link errors
    ///
    extern (D) real strtold(scope inout(char)* nptr, inout(char)** endptr)
    {   // Fake it 'till we make it
        return strtod(nptr, endptr);
    }
}
else version (MinGW)
{
    ///
    real __mingw_strtold(scope inout(char)* nptr, scope inout(char)** endptr);
    ///
    alias __mingw_strtold strtold;
}
else version (CRuntime_Bionic)
{
    ///
    real strtold(scope inout(char)* nptr, scope inout(char)** endptr)
    {   // Fake it again till we make it
        return strtod(nptr, endptr);
    }
}
else
{
    ///
    real strtold(scope inout(char)* nptr, scope inout(char)** endptr);
}

// No unsafe pointer manipulation.
@trusted
{
    version(CRuntime_Bionic)
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
void    abort() @safe;
///
void    exit(int status);
///
int     atexit(void function() func);
///
void    _Exit(int status);

///
char*   getenv(scope const char* name);
///
int     system(scope const char* string);

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
int     mblen(scope const char* s, size_t n);
///
int     mbtowc(scope wchar_t* pwc, scope const char* s, size_t n);
///
int     wctomb(scope char* s, wchar_t wc);
///
size_t  mbstowcs(scope wchar_t* pwcs, scope const char* s, size_t n);
///
size_t  wcstombs(scope char* s, scope const wchar_t* pwcs, size_t n);

///
version( DigitalMars )
{
    // See malloc comment about @trusted.
    void* alloca(size_t size) pure; // non-standard
}
else version( GNU )
{
    void* alloca(size_t size) pure; // compiler intrinsic
}

version( CRuntime_Microsoft )
{
    ///
    ulong  _strtoui64(scope inout(char)*, scope inout(char)**,int);
    ///
    ulong  _wcstoui64(scope inout(wchar)*, scope inout(wchar)**,int);

    ///
    long  _strtoi64(scope inout(char)*, scope inout(char)**,int);
    ///
    long  _wcstoi64(scope inout(wchar)*, scope inout(wchar)**,int);
}
