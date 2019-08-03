// EXTRA_CPP_SOURCES: cpp_abi_tests.cpp
// CXXFLAGS(linux freebsd osx netbsd dragonflybsd): -std=c++11
// CXXFLAGS(win64): /arch:AVX2
// PERMUTE_ARGS: -mcpu=native

// N.B MSVC doesn't have a C++11 switch, but it defaults to the latest fully-supported standard
// N.B MSVC 2013 doesn't support char16_t/char32_t

import core.simd;
import core.stdc.config : c_long_double;

version (Posix) version (X86_64)
    version = Posix_x86_64;

version(Posix)
    enum __c_wchar_t : dchar;
else version(Windows)
    enum __c_wchar_t : wchar;
alias wchar_t = __c_wchar_t;

version (Windows)
{
    // MSVC doesn't have native complex types
    mixin template ComplexProperties(E)
    {
        static typeof(this) nan() @property { return typeof(this)(E.nan.re, E.nan.im); }
        static typeof(this) min_normal() @property { return typeof(this)(E.min_normal.re, E.min_normal.im); }
        static typeof(this) max() @property { return typeof(this)(E.max.re, E.max.im); }
    }
    struct cfloat_t  { float re, im; mixin ComplexProperties!float; }
    struct cdouble_t { double re, im; mixin ComplexProperties!double; }
    struct creal_t   { c_long_double re, im; mixin ComplexProperties!c_long_double; }

    T to(T : cfloat_t)(cfloat i)   { return T(i.re, i.im); }
    T to(T : cdouble_t)(cdouble i) { return T(i.re, i.im); }
    T to(T : creal_t)(creal i)     { return T(i.re, i.im); }
}
else
{
    alias cfloat_t = cfloat;
    alias cdouble_t = cdouble;
    alias creal_t = creal;
    T to(T)(T i) { return i; }
}

extern(C++) {

struct S
{
    float a = 1;
}

struct S3 { byte a, b, c; }
struct S4 { byte a, b, c, d; }
struct S5 { byte a, b, c, d, e; }
struct S8 { int a; float b; }
struct S16 { int a, b; float c, d; }

struct S18784
{
    int i;
    this(int);
}

extern(C++, std)
{
    struct test19248_ {int a = 42;}
}
extern(C++, `std`)
{
    struct test19248 {int a = 34;}
}

// Non C++03 POD structs
struct S030
{
    int i;
    private int j;
}

struct S031
{
    private int i, j;
}

struct S032
{
    int i;
    this(int);
}

struct S0 { }
S0 passthrough(S0, ref int);

bool   passthrough(bool   value);
byte   passthrough(byte   value);
ubyte  passthrough(ubyte  value);
char   passthrough(char   value);
wchar  passthrough(wchar  value);
dchar  passthrough(dchar  value);
wchar_t passthrough(wchar_t value);
short  passthrough(short  value);
ushort passthrough(ushort value);
int    passthrough(int    value);
uint   passthrough(uint   value);
long   passthrough(long   value);
ulong  passthrough(ulong  value);
float  passthrough(float  value);
double passthrough(double value);
cfloat_t passthrough(cfloat_t value);
cdouble_t passthrough(cdouble_t value);
creal_t passthrough(creal_t value);
version(D_SIMD) float4 passthrough(float4 value);
version(D_AVX2) float8 passthrough(float8 value);
S      passthrough(S      value);
test19248 passthrough(const(test19248) value);
std.test19248_ passthrough(const(std.test19248_) value);
S3     passthrough(S3     value);
S4     passthrough(S4     value);
S5     passthrough(S5     value);
S8     passthrough(S8     value);
S16    passthrough(S16    value);
S030   passthrough(S030   value);
S031   passthrough(S031   value);
S032   passthrough(S032   value);

bool   passthrough_ptr(bool   *value);
byte   passthrough_ptr(byte   *value);
ubyte  passthrough_ptr(ubyte  *value);
char   passthrough_ptr(char   *value);
wchar  passthrough_ptr(wchar  *value);
dchar  passthrough_ptr(dchar  *value);
wchar_t passthrough_ptr(wchar_t *value);
short  passthrough_ptr(short  *value);
ushort passthrough_ptr(ushort *value);
int    passthrough_ptr(int    *value);
uint   passthrough_ptr(uint   *value);
long   passthrough_ptr(long   *value);
ulong  passthrough_ptr(ulong  *value);
float  passthrough_ptr(float  *value);
double passthrough_ptr(double *value);
cfloat_t passthrough_ptr(cfloat_t *value);
cdouble_t passthrough_ptr(cdouble_t *value);
creal_t passthrough_ptr(creal_t *value);
version(D_SIMD) float4 passthrough_ptr(float4 *value);
version(D_AVX2) float8 passthrough_ptr(float8 *value);
S      passthrough_ptr(S      *value);
test19248 passthrough_ptr(const(test19248)* value);
std.test19248_ passthrough_ptr(const(std.test19248_)* value);
S3     passthrough_ptr(S3     *value);
S4     passthrough_ptr(S4     *value);
S5     passthrough_ptr(S5     *value);
S8     passthrough_ptr(S8     *value);
S16    passthrough_ptr(S16    *value);
S030   passthrough_ptr(S030   *value);
S031   passthrough_ptr(S031   *value);
S032   passthrough_ptr(S032   *value);

bool   passthrough_ref(ref bool   value);
byte   passthrough_ref(ref byte   value);
ubyte  passthrough_ref(ref ubyte  value);
char   passthrough_ref(ref char   value);
wchar  passthrough_ref(ref wchar  value);
dchar  passthrough_ref(ref dchar  value);
wchar_t passthrough_ref(ref wchar_t value);
short  passthrough_ref(ref short  value);
ushort passthrough_ref(ref ushort value);
int    passthrough_ref(ref int    value);
uint   passthrough_ref(ref uint   value);
long   passthrough_ref(ref long   value);
ulong  passthrough_ref(ref ulong  value);
float  passthrough_ref(ref float  value);
double passthrough_ref(ref double value);
cfloat_t passthrough_ref(ref cfloat_t value);
cdouble_t passthrough_ref(ref cdouble_t value);
creal_t passthrough_ref(ref creal_t value);
version(D_SIMD) float4 passthrough_ref(ref float4 value);
version(D_AVX2) float8 passthrough_ref(ref float8 value);
S      passthrough_ref(ref S      value);
test19248 passthrough_ref(ref const(test19248) value);
std.test19248_ passthrough_ref(ref const(std.test19248_) value);
S3     passthrough_ref(ref S3     value);
S4     passthrough_ref(ref S4     value);
S5     passthrough_ref(ref S5     value);
S8     passthrough_ref(ref S8     value);
S16    passthrough_ref(ref S16    value);
S030   passthrough_ref(ref S030   value);
S031   passthrough_ref(ref S031   value);
S032   passthrough_ref(ref S032   value);
}

template IsSigned(T)
{
    enum IsSigned = is(T==byte)  ||
                    is(T==short) ||
                    is(T==int)   ||
                    is(T==long);
}

template IsUnsigned(T)
{
    enum IsUnsigned = is(T==ubyte)  ||
                      is(T==ushort) ||
                      is(T==uint)   ||
                      is(T==ulong);
}

template IsIntegral(T)
{
    enum IsIntegral = IsSigned!T || IsUnsigned!T;
}

template IsFloatingPoint(T)
{
    enum IsFloatingPoint = is(T==float) || is(T==double) || is(T==real);
}

template IsComplex(T)
{
    enum IsComplex = is(T==cfloat_t) || is(T==cdouble_t) || is(T==creal_t);
}

template IsBoolean(T)
{
    enum IsBoolean = is(T==bool);
}

template IsSomeChar(T)
{
    enum IsSomeChar = is(T==char) || is(T==wchar) || is(T==dchar) || is(T==wchar_t);
}

void check(T)(T actual, T expected)
{
    static if (is(T == creal_t) && creal_t.sizeof > 20)
    {
        // this is a trick to zero out the padding
        actual = actual;
        expected = expected;
    }
    assert(actual is expected);
}

void check(T : __vector(V[N]), V, size_t N)(T actual, T expected)
{
    assert(actual.array == expected.array);
}

void check(T)(T value)
{
    check(passthrough(value), value);
    check(passthrough_ptr(&value), value);
    check(passthrough_ref(value), value);
}

T[] values(T)()
{
    T[] values;
    static if(IsBoolean!T)
    {
        values ~= true;
        values ~= false;
    }
    else static if(IsSomeChar!T)
    {
        values ~= T.init;
        values ~= T('a');
        values ~= T('z');
    }
    else
    {
        static if (IsComplex!T)
        {
            values ~= to!T(0+0i);
            values ~= to!T(1+1i);
        }
        else
        {
            values ~= T(0);
            values ~= T(1);
        }
        static if(IsIntegral!T)
        {
            static if(IsSigned!T) values ~= T.min;
            values ~= T.max;
        }
        else static if(IsFloatingPoint!T || IsComplex!T)
        {
            values ~= T.nan;
            values ~= T.min_normal;
            values ~= T.max;
        }
        else
        {
            assert(0);
        }
    }
    return values;
}

extern(C++, `ns1`)
 {
    // C++: `const char*, const char**`
    int constFunction1(const(char)*, const(char)**);
    // C++: `const char*, const char* const*`
    int constFunction2(const(char)*, const(char*)*);
    // C++: `const char* const, const char* const* const*`
    int constFunction3(const(char*), const(char**)*);
    // C++: `const char* const, const char* const* const* const`
    int constFunction4(const(char*), const(char***));
}

extern(C++)
{
    struct SmallStruct
    {
        int i;
        this(int i) { this.i = i; }
        this(ref const SmallStruct); // implemented in C++
    }
    void smallStructTest(SmallStruct p);
    void smallStructCallBack(SmallStruct p)
    {
        assert(p.i == 62);
    }
}

void main()
{
    foreach(bool val; values!bool())     check(val);
    foreach(byte val; values!byte())     check(val);
    foreach(ubyte val; values!ubyte())   check(val);
    foreach(char val; values!char())     check(val);
version(CppRuntime_DigitalMars){} else
version(CppRuntime_Microsoft)
{
// TODO: figure out how to detect VS2013 which doesn't support char16_t/char32_t
}
else
{
    foreach(wchar val; values!wchar())   check(val);
    foreach(dchar val; values!dchar())   check(val);
}
    foreach(wchar_t val; values!wchar_t()) check(val);
    foreach(short val; values!short())   check(val);
    foreach(ushort val; values!ushort()) check(val);
    foreach(int val; values!int())       check(val);
    foreach(uint val; values!uint())     check(val);
    foreach(long val; values!long())     check(val);
    foreach(ulong val; values!ulong())   check(val);
    foreach(float val; values!float())   check(val);
    foreach(double val; values!double()) check(val);
    foreach(cfloat_t val; values!cfloat_t()) check(val);
    foreach(cdouble_t val; values!cdouble_t()) check(val);
version (Posix_x86_64) {} else // still fails on POSIX x86_64
{
    foreach(creal_t val; values!creal_t()) check(val);
}
version(none) // Enable when the mangling is fixed
{
version(D_SIMD) foreach(float4 val; values!float4()) check(val);
version(D_AVX2) foreach(float8 val; values!float8()) check(val);
}
    check(S());
    check(test19248());
    check(std.test19248_());
    check(S3(1, 2, 3));
    check(S4(1, 2, 3, 4));
    check(S5(1, 2, 3, 4, 5));
    check(S8(1, 2));
    check(S16(1, 2, 3, 4));
    check(S030(1, 2));
    check(S031(1, 2));
    check(S032(1));

    assert(constFunction1(null, null) == 1);
    assert(constFunction2(null, null) == 2);
    assert(constFunction3(null, null) == 3);
    assert(constFunction4(null, null) == 42);

    auto ss = SmallStruct(42);
    smallStructTest(ss);
    assert(ss.i == 42);
    assert(S18784(1).i == 1);

version(Windows) // fails on Posix
{
    int i = 10;
    passthrough(S0(), i);
    assert(i == 11);
}
}
