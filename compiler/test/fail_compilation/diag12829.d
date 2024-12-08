/*
TEST_OUTPUT:
---
fail_compilation/diag12829.d(31): Error: function `diag12829.test1` is `@nogc` yet allocates closure for `test1()` with the GC
auto test1() @nogc
     ^
fail_compilation/diag12829.d(34):        delegate `diag12829.test1.__lambda_L34_C33` closes over variable `x`
    void delegate() @nogc foo = () {
                                ^
fail_compilation/diag12829.d(33):        `x` declared here
    int x;
        ^
fail_compilation/diag12829.d(38):        function `diag12829.test1.bar` closes over variable `x`
    void bar()
         ^
fail_compilation/diag12829.d(33):        `x` declared here
    int x;
        ^
fail_compilation/diag12829.d(45): Error: function `diag12829.test2` is `@nogc` yet allocates closure for `test2()` with the GC
auto test2() @nogc
     ^
fail_compilation/diag12829.d(50):        function `diag12829.test2.S.foo` closes over variable `x`
        void foo()
             ^
fail_compilation/diag12829.d(47):        `x` declared here
    int x;
        ^
---
*/

auto test1() @nogc
{
    int x;
    void delegate() @nogc foo = () {
        int y = x;
    };

    void bar()
    {
        int y = x;
    }
    auto dg = &bar;
}

auto test2() @nogc
{
    int x;
    struct S
    {
        void foo()
        {
            int y = x;
        }
    }
    return S();
}
