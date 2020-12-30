// https://issues.dlang.org/show_bug.cgi?id=21515
// EXTRA_CPP_SOURCES: test21515.cpp
// DISABLED: win32 win64
extern(C) cfloat  ccomplexf();
extern(C) cdouble ccomplex();
extern(C) creal   ccomplexl();
extern(C) void    ccomplexf2(cfloat c);
extern(C) void    ccomplex2(cdouble c);
extern(C) void    ccomplexl2(creal c);

extern(C++) cfloat  cpcomplexf();
extern(C++) cdouble cpcomplex();
extern(C++) creal   cpcomplexl();
extern(C++) void    cpcomplexf(cfloat c);
extern(C++) void    cpcomplex(cdouble c);
extern(C++) void    cpcomplexl(creal c);

struct wrap_complexf { cfloat c; alias c this; };
struct wrap_complex  { cdouble c; alias c this; };
struct wrap_complexl { creal c; alias c this; };

extern(C++) wrap_complexf wcomplexf();
extern(C++) wrap_complex  wcomplex();
extern(C++) wrap_complexl wcomplexl();
extern(C++) void          wcomplexf(wrap_complexf c);
extern(C++) void          wcomplex(wrap_complex c);
extern(C++) void          wcomplexl(wrap_complexl c);

struct soft_complexf { float re; float im; };
struct soft_complex  { double re; double im; };
struct soft_complexl { real re; real im; };

extern(C++) soft_complexf scomplexf();
extern(C++) soft_complex  scomplex();
extern(C++) soft_complexl scomplexl();
extern(C++) void          scomplexf(soft_complexf c);
extern(C++) void          scomplex(soft_complex c);
extern(C++) void          scomplexl(soft_complexl c);

int main()
{
    auto a1 = ccomplexf();
    auto b1 = ccomplex();
    auto c1 = ccomplexl();
    assert(a1.re == 2 && a1.im == 1);
    assert(b1.re == 2 && b1.im == 1);
    assert(c1.re == 2 && c1.im == 1);
    ccomplexf2(a1);
    ccomplex2(b1);
    ccomplexl2(c1);

    auto a2 = cpcomplexf();
    auto b2 = cpcomplex();
    auto c2 = cpcomplexl();
    assert(a2.re == 2 && a2.im == 1);
    assert(b2.re == 2 && b2.im == 1);
    assert(c2.re == 2 && c2.im == 1);
    cpcomplexf(a2);
    cpcomplex(b2);
    cpcomplexl(c2);

    auto a3 = wcomplexf();
    auto b3 = wcomplex();
    auto c3 = wcomplexl();
    assert(a3.re == 2 && a3.im == 1);
    assert(b3.re == 2 && b3.im == 1);
    assert(c3.re == 2 && c3.im == 1);
    wcomplexf(a3);
    wcomplex(b3);
    wcomplexl(c3);

    auto a4 = scomplexf();
    auto b4 = scomplex();
    auto c4 = scomplexl();
    assert(a4.re == 2 && a4.im == 1);
    assert(b4.re == 2 && b4.im == 1);
    assert(c4.re == 2 && c4.im == 1);
    scomplexf(a4);
    scomplex(b4);
    scomplexl(c4);

    return 0;
}
