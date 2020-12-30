// https://issues.dlang.org/show_bug.cgi?id=21515
// DISABLED: win32 win64
extern(D) cfloat  dcomplexf() { return 2.0f+1.0i; }
extern(D) cdouble dcomplex()  { return 2.0+1.0i; }
extern(D) creal   dcomplexl() { return 2.0L+1.0Li; }

extern(D) void dcomplexf(cfloat c) { assert(c.re == 2 && c.im == 1); }
extern(D) void dcomplex(cdouble c) { assert(c.re == 2 && c.im == 1); }
extern(D) void dcomplexl(creal c)  { assert(c.re == 2 && c.im == 1); }

extern(C) cfloat  ccomplexf() { return 2.0f+1.0fi; }
extern(C) cdouble ccomplex()  { return 2.0+1.0i; }
extern(C) creal   ccomplexl() { return 2.0L+1.0Li; }

extern(C) void ccomplexf2(cfloat c) { assert(c.re == 2 && c.im == 1); }
extern(C) void ccomplex2(cdouble c) { assert(c.re == 2 && c.im == 1); }
extern(C) void ccomplexl2(creal c)  { assert(c.re == 2 && c.im == 1); }

extern(C++) cfloat  cpcomplexf() { return 2.0f+1.0fi; }
extern(C++) cdouble cpcomplex()  { return 2.0+1.0i; }
extern(C++) creal   cpcomplexl() { return 2.0L+1.0Li; }

extern(C++) void cpcomplexf(cfloat c) { assert(c.re == 2 && c.im == 1); }
extern(C++) void cpcomplex(cdouble c) { assert(c.re == 2 && c.im == 1); }
extern(C++) void cpcomplexl(creal c)  { assert(c.re == 2 && c.im == 1); }

int main()
{
    auto a1 = dcomplexf();
    auto b1 = dcomplex();
    auto c1 = dcomplexl();
    assert(a1.re == 2 && a1.im == 1);
    assert(b1.re == 2 && b1.im == 1);
    assert(c1.re == 2 && c1.im == 1);
    dcomplexf(a1);
    dcomplex(b1);
    dcomplexl(c1);

    auto a2 = ccomplexf();
    auto b2 = ccomplex();
    auto c2 = ccomplexl();
    assert(a2.re == 2 && a2.im == 1);
    assert(b2.re == 2 && b2.im == 1);
    assert(c2.re == 2 && c2.im == 1);
    ccomplexf2(a2);
    ccomplex2(b2);
    ccomplexl2(c2);

    auto a3 = cpcomplexf();
    auto b3 = cpcomplex();
    auto c3 = cpcomplexl();
    assert(a3.re == 2 && a3.im == 1);
    assert(b3.re == 2 && b3.im == 1);
    assert(c3.re == 2 && c3.im == 1);
    cpcomplexf(a3);
    cpcomplex(b3);
    cpcomplexl(c3);

    return 0;
}
