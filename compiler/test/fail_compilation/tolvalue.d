/**
TEST_OUTPUT:
---
fail_compilation/tolvalue.d(52): Error: cannot take address of template `templateFunc(T)()`, perhaps instantiate it first
    auto x0 = &templateFunc;
               ^
fail_compilation/tolvalue.d(53): Error: cannot take address of type `int`
    auto x1 = &intAlias;
               ^
fail_compilation/tolvalue.d(54): Error: cannot take address of constant `3`
    auto x2 = &3;
               ^
fail_compilation/tolvalue.d(55): Error: cannot take address of operator `$`
    auto x3 = a[&$];
                 ^
fail_compilation/tolvalue.d(56): Error: cannot take address of compiler-generated variable `__ctfe`
    auto x4 = &__ctfe;
               ^
fail_compilation/tolvalue.d(57): Error: cannot take address of manifest constant `f`
    auto x6 = &E.f;
               ^
fail_compilation/tolvalue.d(62): Error: cannot create default argument for `ref` / `out` parameter from constant `3`
    void f0(ref int = 3) {}
                      ^
fail_compilation/tolvalue.d(63): Error: cannot create default argument for `ref` / `out` parameter from compiler-generated variable `__ctfe`
    void f1(ref bool = __ctfe) {}
                       ^
fail_compilation/tolvalue.d(64): Error: cannot create default argument for `ref` / `out` parameter from manifest constant `f`
    void f3(ref E = E.f) {}
                    ^
fail_compilation/tolvalue.d(69): Error: cannot modify constant `3`
    3++;
    ^
fail_compilation/tolvalue.d(70): Error: cannot modify compiler-generated variable `__ctfe`
    __ctfe++;
    ^
fail_compilation/tolvalue.d(71): Error: cannot modify manifest constant `f`
    E.f++;
    ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=24238

void templateFunc(T)() {}
alias intAlias = int;
enum E { f }

void addr()
{
    int[] a;
    auto x0 = &templateFunc;
    auto x1 = &intAlias;
    auto x2 = &3;
    auto x3 = a[&$];
    auto x4 = &__ctfe;
    auto x6 = &E.f;
}

void refArg()
{
    void f0(ref int = 3) {}
    void f1(ref bool = __ctfe) {}
    void f3(ref E = E.f) {}
}

void inc(int lz)
{
    3++;
    __ctfe++;
    E.f++;
}
