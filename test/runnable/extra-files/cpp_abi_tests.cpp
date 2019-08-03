#include <assert.h>
#include <complex.h>

#if !defined (__SSE__) && (defined (_M_X64) || (defined (_M_IX86_FP) && _M_IX86_FP >= 1))
#define __SSE__ 1
#endif

#ifdef __SSE__
#include <immintrin.h>
#endif

#ifdef _WIN32
struct cfloat_t  { float re, im; };
struct cdouble_t { double re, im; };
struct creal_t   { long double re, im; };
#else
typedef _Complex float cfloat_t;
typedef _Complex double cdouble_t;
typedef _Complex long double creal_t;
#endif

#ifdef __SSE__
typedef __m128 float4_t;
#else
struct float4_t { float v[4]; };
#endif

#ifdef __AVX2__
typedef __m256 float8_t;
#else
struct float8_t { float v[8]; };
#endif

struct S{
    float a;
};

struct S3 { signed char a, b, c; };
struct S4 { signed char a, b, c, d; };
struct S5 { signed char a, b, c, d, e; };
struct S8 { int a; float b; };
struct S16 { int a, b; float c, d; };

namespace std
{
    struct test19248_ {int a;}; // Remove when `extern(C++, ns)` is gone
    struct test19248  {int a;};
};

#ifdef __DMC__
// DMC doesn't support c++11
#elif defined (_MSC_VER) && _MSC_VER <= 1800
// MSVC2013 doesn't support char16_t/char32_t
#else
#define TEST_UNICODE
#endif

struct S18784
{
    int i;
    S18784(int n);
};

S18784::S18784(int n) : i(n) {}

struct S030
{
    int i;
private:
    int j;
};

struct S031
{
private:
    int i, j;
};

struct S032
{
    int i;
    S032(int);
};

S032::S032(int i) : i(i) {}

struct S0 { };
S0 passthrough(S0 s, int &i) { ++i; return s; }

bool               passthrough(bool                value)     { return value; }
signed char        passthrough(signed char         value)     { return value; }
unsigned char      passthrough(unsigned char       value)     { return value; }
char               passthrough(char                value)     { return value; }
#ifdef TEST_UNICODE
char16_t           passthrough(char16_t            value)     { return value; }
char32_t           passthrough(char32_t            value)     { return value; }
#endif
wchar_t            passthrough(wchar_t             value)     { return value; }
short              passthrough(short               value)     { return value; }
unsigned short     passthrough(unsigned short      value)     { return value; }
int                passthrough(int                 value)     { return value; }
unsigned int       passthrough(unsigned int        value)     { return value; }
long               passthrough(long                value)     { return value; }
unsigned long      passthrough(unsigned long       value)     { return value; }
long long          passthrough(long long           value)     { return value; }
unsigned long long passthrough(unsigned long long  value)     { return value; }
float              passthrough(float               value)     { return value; }
double             passthrough(double              value)     { return value; }
cfloat_t           passthrough(cfloat_t            value)     { return value; }
cdouble_t          passthrough(cdouble_t           value)     { return value; }
creal_t            passthrough(creal_t             value)     { return value; }
float4_t           passthrough(float4_t            value)     { return value; }
float8_t           passthrough(float8_t            value)     { return value; }
S                  passthrough(S                   value)     { return value; }
std::test19248     passthrough(const std::test19248 value)    { return value; }
std::test19248_    passthrough(const std::test19248_ value)   { return value; }
S3                 passthrough(S3                  value)     { return value; }
S4                 passthrough(S4                  value)     { return value; }
S5                 passthrough(S5                  value)     { return value; }
S8                 passthrough(S8                  value)     { return value; }
S16                passthrough(S16                 value)     { return value; }
S030               passthrough(S030                value)     { return value; }
S031               passthrough(S031                value)     { return value; }
S032               passthrough(S032                value)     { return value; }

bool               passthrough_ptr(bool               *value) { return *value; }
signed char        passthrough_ptr(signed char        *value) { return *value; }
unsigned char      passthrough_ptr(unsigned char      *value) { return *value; }
char               passthrough_ptr(char               *value) { return *value; }
#ifdef TEST_UNICODE
char16_t           passthrough_ptr(char16_t           *value) { return *value; }
char32_t           passthrough_ptr(char32_t           *value) { return *value; }
#endif
wchar_t            passthrough_ptr(wchar_t            *value) { return *value; }
short              passthrough_ptr(short              *value) { return *value; }
unsigned short     passthrough_ptr(unsigned short     *value) { return *value; }
int                passthrough_ptr(int                *value) { return *value; }
unsigned int       passthrough_ptr(unsigned int       *value) { return *value; }
long               passthrough_ptr(long               *value) { return *value; }
unsigned long      passthrough_ptr(unsigned long      *value) { return *value; }
long long          passthrough_ptr(long long          *value) { return *value; }
unsigned long long passthrough_ptr(unsigned long long *value) { return *value; }
float              passthrough_ptr(float              *value) { return *value; }
double             passthrough_ptr(double             *value) { return *value; }
cfloat_t           passthrough_ptr(cfloat_t           *value) { return *value; }
cdouble_t          passthrough_ptr(cdouble_t          *value) { return *value; }
creal_t            passthrough_ptr(creal_t            *value) { return *value; }
float4_t           passthrough_ptr(float4_t           *value) { return *value; }
float8_t           passthrough_ptr(float8_t           *value) { return *value; }
S                  passthrough_ptr(S                  *value) { return *value; }
std::test19248     passthrough_ptr(const std::test19248 *value) { return *value; }
std::test19248_    passthrough_ptr(const std::test19248_ *value) { return *value; }
S3                 passthrough_ptr(S3                 *value) { return *value; }
S4                 passthrough_ptr(S4                 *value) { return *value; }
S5                 passthrough_ptr(S5                 *value) { return *value; }
S8                 passthrough_ptr(S8                 *value) { return *value; }
S16                passthrough_ptr(S16                *value) { return *value; }
S030               passthrough_ptr(S030               *value) { return *value; }
S031               passthrough_ptr(S031               *value) { return *value; }
S032               passthrough_ptr(S032               *value) { return *value; }

bool               passthrough_ref(bool               &value) { return value; }
signed char        passthrough_ref(signed char        &value) { return value; }
unsigned char      passthrough_ref(unsigned char      &value) { return value; }
char               passthrough_ref(char               &value) { return value; }
#ifdef TEST_UNICODE
char16_t           passthrough_ref(char16_t           &value) { return value; }
char32_t           passthrough_ref(char32_t           &value) { return value; }
#endif
wchar_t            passthrough_ref(wchar_t            &value) { return value; }
short              passthrough_ref(short              &value) { return value; }
unsigned short     passthrough_ref(unsigned short     &value) { return value; }
int                passthrough_ref(int                &value) { return value; }
unsigned int       passthrough_ref(unsigned int       &value) { return value; }
long               passthrough_ref(long               &value) { return value; }
unsigned long      passthrough_ref(unsigned long      &value) { return value; }
long long          passthrough_ref(long long          &value) { return value; }
unsigned long long passthrough_ref(unsigned long long &value) { return value; }
float              passthrough_ref(float              &value) { return value; }
double             passthrough_ref(double             &value) { return value; }
cfloat_t           passthrough_ref(cfloat_t           &value) { return value; }
cdouble_t          passthrough_ref(cdouble_t          &value) { return value; }
creal_t            passthrough_ref(creal_t            &value) { return value; }
float4_t           passthrough_ref(float4_t           &value) { return value; }
float8_t           passthrough_ref(float8_t           &value) { return value; }
S                  passthrough_ref(S                  &value) { return value; }
std::test19248     passthrough_ref(const std::test19248 &value) { return value; }
std::test19248_    passthrough_ref(const std::test19248_ &value) { return value; }
S3                 passthrough_ref(S3                 &value) { return value; }
S4                 passthrough_ref(S4                 &value) { return value; }
S5                 passthrough_ref(S5                 &value) { return value; }
S8                 passthrough_ref(S8                 &value) { return value; }
S16                passthrough_ref(S16                &value) { return value; }
S030               passthrough_ref(S030               &value) { return value; }
S031               passthrough_ref(S031               &value) { return value; }
S032               passthrough_ref(S032               &value) { return value; }

namespace ns1
{
    // D: `char*, const(char)**`
    int constFunction1(const char*, const char**) { return 1; }
    // D: `const(char)*, const(char*)*`
    int constFunction2(const char*, const char* const*) { return 2; }
    // D: `const(char*), const(char**)*`
    int constFunction3(const char* const, const char* const* const*) { return 3; }
    // D: `const(char*), const(char***)`
    int constFunction4(const char* const, const char* const* const* const) { return 42; }
};

struct SmallStruct
{
    int i;
    SmallStruct(int); // implemented in D
    SmallStruct(const SmallStruct &);
};
SmallStruct::SmallStruct(const SmallStruct &rhs)
    : i(rhs.i + 10) {}
void smallStructCallBack(SmallStruct p);
void smallStructTest(SmallStruct p)
{
    assert(p.i == 52);

    smallStructCallBack(p);
    assert(p.i == 52);
}

// Uncomment when mangling is fixed
// typedef void(*fn0)();
// fn0            passthrough_fn0   (fn0 value) { return value; }
// typedef int (*fn1)(int);
// fn1            passthrough_fn1   (fn1 value) { return value; }
