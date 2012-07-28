/*
TEST_OUTPUT:
---
fail_compilation/fail7322.d(25): Deprecation: function fail7322.f1 is deprecated
fail_compilation/fail7322.d(26): Deprecation: function fail7322.f2 is deprecated
fail_compilation/fail7322.d(28): Deprecation: function fail7322.f1 is deprecated
fail_compilation/fail7322.d(29): Deprecation: function fail7322.f2 is deprecated
fail_compilation/fail7322.d(32): Deprecation: function fail7322.A1.f is deprecated
fail_compilation/fail7322.d(35): Deprecation: function fail7322.A2.f is deprecated
fail_compilation/fail7322.d(38): Deprecation: function fail7322.A1.f is deprecated
fail_compilation/fail7322.d(41): Deprecation: function fail7322.A2.f is deprecated
fail_compilation/fail7322.d(43): Deprecation: function fail7322.f7!(string).f7 is deprecated
fail_compilation/fail7322.d(44): Deprecation: function fail7322.f7!(string).f7 is deprecated
---
*/

#line 1
void f1(int a) {}
deprecated void f1(float a) {}
deprecated void f2() {}

class A1
{
    void f(int a) {}
    deprecated void f(float a) {}
}

class A2
{
    deprecated void f() {}
}

void f3(void function(float) fp) {}
void f4(void function() fp) {}
void f5(void delegate(float) dg) {}
void f6(void delegate() dg) {}

deprecated void f7(T)() {}

void main()
{
    void function(float) fp1 = &f1;
    void function() fp2 = &f2;

    f3(&f1);
    f4(&f2);

    auto a1 = new A1();
    void delegate(float) dg1 = &a1.f;

    auto a2 = new A2();
    void delegate() dg2 = &a2.f;

    auto a3 = new A1();
    f5(&a3.f);

    auto a4 = new A2();
    f6(&a4.f);

    auto fp3 = &f7!string;
    f4(&f7!string);
}
