// PERMUTE_ARGS:
// REQUIRED_ARGS: -unittest -verrors=0

/*
TEST_OUTPUT:
---
compilable/sw_transition_complex.d(126): Deprecation: use of complex type `creal` is deprecated, use `std.complex.Complex!(real)` instead
creal c80value;
      ^
compilable/sw_transition_complex.d(127): Deprecation: use of complex type `cdouble` is deprecated, use `std.complex.Complex!(double)` instead
cdouble c64value;
        ^
compilable/sw_transition_complex.d(128): Deprecation: use of complex type `cfloat` is deprecated, use `std.complex.Complex!(float)` instead
cfloat c32value;
       ^
compilable/sw_transition_complex.d(130): Deprecation: use of imaginary type `ireal` is deprecated, use `real` instead
ireal i80value;
      ^
compilable/sw_transition_complex.d(131): Deprecation: use of imaginary type `idouble` is deprecated, use `double` instead
idouble i64value;
        ^
compilable/sw_transition_complex.d(132): Deprecation: use of imaginary type `ifloat` is deprecated, use `float` instead
ifloat i32value;
       ^
compilable/sw_transition_complex.d(134): Deprecation: use of complex type `creal*` is deprecated, use `std.complex.Complex!(real)` instead
creal* c80pointer;
       ^
compilable/sw_transition_complex.d(135): Deprecation: use of complex type `cdouble*` is deprecated, use `std.complex.Complex!(double)` instead
cdouble* c64pointer;
         ^
compilable/sw_transition_complex.d(136): Deprecation: use of complex type `cfloat*` is deprecated, use `std.complex.Complex!(float)` instead
cfloat* c32pointer;
        ^
compilable/sw_transition_complex.d(138): Deprecation: use of imaginary type `ireal*` is deprecated, use `real` instead
ireal* i80pointer;
       ^
compilable/sw_transition_complex.d(139): Deprecation: use of imaginary type `idouble*` is deprecated, use `double` instead
idouble* i64pointer;
         ^
compilable/sw_transition_complex.d(140): Deprecation: use of imaginary type `ifloat*` is deprecated, use `float` instead
ifloat* i32pointer;
        ^
compilable/sw_transition_complex.d(142): Deprecation: use of complex type `creal[]*` is deprecated, use `std.complex.Complex!(real)` instead
creal[]* c80arrayp;
         ^
compilable/sw_transition_complex.d(143): Deprecation: use of complex type `cdouble[]*` is deprecated, use `std.complex.Complex!(double)` instead
cdouble[]* d64arrayp;
           ^
compilable/sw_transition_complex.d(144): Deprecation: use of complex type `cfloat[]*` is deprecated, use `std.complex.Complex!(float)` instead
cfloat[]* c32arrayp;
          ^
compilable/sw_transition_complex.d(146): Deprecation: use of imaginary type `ireal[]*` is deprecated, use `real` instead
ireal[]* i80arrayp;
         ^
compilable/sw_transition_complex.d(147): Deprecation: use of imaginary type `idouble[]*` is deprecated, use `double` instead
idouble[]* i64arrayp;
           ^
compilable/sw_transition_complex.d(148): Deprecation: use of imaginary type `ifloat[]*` is deprecated, use `float` instead
ifloat[]* i32arrayp;
          ^
compilable/sw_transition_complex.d(150): Deprecation: use of complex type `creal[4][]*` is deprecated, use `std.complex.Complex!(real)` instead
creal[4][]* c80sarrayp;
            ^
compilable/sw_transition_complex.d(151): Deprecation: use of complex type `cdouble[4][]*` is deprecated, use `std.complex.Complex!(double)` instead
cdouble[4][]* c64sarrayp;
              ^
compilable/sw_transition_complex.d(152): Deprecation: use of complex type `cfloat[4][]*` is deprecated, use `std.complex.Complex!(float)` instead
cfloat[4][]* c32sarrayp;
             ^
compilable/sw_transition_complex.d(154): Deprecation: use of imaginary type `ireal[4][]*` is deprecated, use `real` instead
ireal[4][]* i80sarrayp;
            ^
compilable/sw_transition_complex.d(155): Deprecation: use of imaginary type `idouble[4][]*` is deprecated, use `double` instead
idouble[4][]* i64sarrayp;
              ^
compilable/sw_transition_complex.d(156): Deprecation: use of imaginary type `ifloat[4][]*` is deprecated, use `float` instead
ifloat[4][]* i32sarrayp;
             ^
compilable/sw_transition_complex.d(161): Deprecation: use of complex type `creal` is deprecated, use `std.complex.Complex!(real)` instead
C14488 calias1;
       ^
compilable/sw_transition_complex.d(162): Deprecation: use of complex type `creal*` is deprecated, use `std.complex.Complex!(real)` instead
C14488* calias2;
        ^
compilable/sw_transition_complex.d(163): Deprecation: use of complex type `creal[]` is deprecated, use `std.complex.Complex!(real)` instead
C14488[] calias3;
         ^
compilable/sw_transition_complex.d(164): Deprecation: use of complex type `creal[4]` is deprecated, use `std.complex.Complex!(real)` instead
C14488[4] calias4;
          ^
compilable/sw_transition_complex.d(166): Deprecation: use of imaginary type `ireal` is deprecated, use `real` instead
I14488 ialias1;
       ^
compilable/sw_transition_complex.d(167): Deprecation: use of imaginary type `ireal*` is deprecated, use `real` instead
I14488* ialias2;
        ^
compilable/sw_transition_complex.d(168): Deprecation: use of imaginary type `ireal[]` is deprecated, use `real` instead
I14488[] ialias3;
         ^
compilable/sw_transition_complex.d(169): Deprecation: use of imaginary type `ireal[4]` is deprecated, use `real` instead
I14488[4] ialias4;
          ^
compilable/sw_transition_complex.d(171): Deprecation: use of complex type `cdouble` is deprecated, use `std.complex.Complex!(double)` instead
auto cauto = 1 + 0i;
     ^
compilable/sw_transition_complex.d(172): Deprecation: use of imaginary type `idouble` is deprecated, use `double` instead
auto iauto = 1i;
     ^
compilable/sw_transition_complex.d(173): Deprecation: use of complex type `cdouble` is deprecated, use `std.complex.Complex!(double)` instead
size_t c64sizeof = (cdouble).sizeof;
                   ^
compilable/sw_transition_complex.d(174): Deprecation: use of complex type `cdouble[]` is deprecated, use `std.complex.Complex!(double)` instead
TypeInfo c64ti = typeid(cdouble[]);
                 ^
compilable/sw_transition_complex.d(176): Deprecation: use of complex type `creal*` is deprecated, use `std.complex.Complex!(real)` instead
void test14488a(creal *p, real r, ireal i)
                      ^
compilable/sw_transition_complex.d(176): Deprecation: use of imaginary type `ireal` is deprecated, use `real` instead
void test14488a(creal *p, real r, ireal i)
                                        ^
compilable/sw_transition_complex.d(180): Deprecation: use of complex type `creal` is deprecated, use `std.complex.Complex!(real)` instead
creal test14488b()
      ^
---
*/
creal c80value;
cdouble c64value;
cfloat c32value;

ireal i80value;
idouble i64value;
ifloat i32value;

creal* c80pointer;
cdouble* c64pointer;
cfloat* c32pointer;

ireal* i80pointer;
idouble* i64pointer;
ifloat* i32pointer;

creal[]* c80arrayp;
cdouble[]* d64arrayp;
cfloat[]* c32arrayp;

ireal[]* i80arrayp;
idouble[]* i64arrayp;
ifloat[]* i32arrayp;

creal[4][]* c80sarrayp;
cdouble[4][]* c64sarrayp;
cfloat[4][]* c32sarrayp;

ireal[4][]* i80sarrayp;
idouble[4][]* i64sarrayp;
ifloat[4][]* i32sarrayp;

alias C14488 = creal;
alias I14488 = ireal;

C14488 calias1;
C14488* calias2;
C14488[] calias3;
C14488[4] calias4;

I14488 ialias1;
I14488* ialias2;
I14488[] ialias3;
I14488[4] ialias4;

auto cauto = 1 + 0i;
auto iauto = 1i;
size_t c64sizeof = (cdouble).sizeof;
TypeInfo c64ti = typeid(cdouble[]);

void test14488a(creal *p, real r, ireal i)
{
}

creal test14488b()
{
    return 1 + 0i;
}

// Forward referenced types shouldn't cause errors during test for complex or imaginary.
enum E;
struct S;

void test14488c(E *e, S *s)
{
}

// https://issues.dlang.org/show_bug.cgi?id=18212
// Usage of cfloat,cdouble,cfloat,ifloat,idouble,ireal shouldn't trigger an error in deprecated code
deprecated void test18212(creal c){}
deprecated unittest
{
    ireal a = 2i;
    creal b = 2 + 3i;
}
deprecated struct Foo
{
    ifloat a = 2i;
    cfloat b = 2f + 2i;
}

// https://issues.dlang.org/show_bug.cgi?id=18218
static assert(__traits(isDeprecated, cfloat));
static assert(__traits(isDeprecated, cdouble));
static assert(__traits(isDeprecated, creal));
static assert(__traits(isDeprecated, ifloat));
static assert(__traits(isDeprecated, idouble));
static assert(__traits(isDeprecated, ireal));
static assert(!__traits(isDeprecated, float));
static assert(!__traits(isDeprecated, double));
static assert(!__traits(isDeprecated, real));
static assert(!__traits(isDeprecated, int));
static assert(!__traits(isDeprecated, long));
static assert(!__traits(isDeprecated, ubyte));
static assert(!__traits(isDeprecated, char));
static assert(!__traits(isDeprecated, bool));
static assert(!__traits(isDeprecated, S));
