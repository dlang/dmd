/*
TEST_OUTPUT:
---
fail_compilation/bug9631.d(68): Error: cannot implicitly convert expression `F()` of type `bug9631.T1!().F` to `bug9631.T2!().F`
    T2!().F x = T1!().F();
                       ^
fail_compilation/bug9631.d(82): Error: incompatible types for `(x) == (y)`: `bug9631.S` and `bug9631.tem!().S`
    bool b = x == y;
             ^
fail_compilation/bug9631.d(88): Error: cannot cast expression `x` of type `bug9631.S` to `bug9631.tem!().S` because of different sizes
    auto y = cast(tem!().S)x;
                           ^
fail_compilation/bug9631.d(91): Error: cannot cast expression `ta` of type `bug9631.tem!().S[1]` to `bug9631.S[1]` because of different sizes
    S[1] sa = cast(S[1])ta;
                        ^
fail_compilation/bug9631.d(92): Error: cannot cast expression `sa` of type `S[1]` to `S[]` since sizes don't line up
    auto t2 = cast(tem!().S[])sa;
                              ^
fail_compilation/bug9631.d(101): Error: function `f` is not callable using argument types `(int, S)`
    f(4, y);
     ^
fail_compilation/bug9631.d(101):        cannot pass argument `y` of type `bug9631.tem!().S` to parameter `bug9631.S s`
fail_compilation/bug9631.d(100):        `bug9631.arg.f(int i, S s)` declared here
    void f(int i, S s);
         ^
fail_compilation/bug9631.d(102): Error: function literal `__lambda_L102_C5(S s)` is not callable using argument types `(S)`
    (tem!().S s){}(x);
                  ^
fail_compilation/bug9631.d(102):        cannot pass argument `x` of type `bug9631.S` to parameter `bug9631.tem!().S s`
fail_compilation/bug9631.d(108): Error: constructor `bug9631.arg.A.this(S __param_0)` is not callable using argument types `(S)`
    A(tem!().S());
     ^
fail_compilation/bug9631.d(108):        cannot pass argument `S(0)` of type `bug9631.tem!().S` to parameter `bug9631.S __param_0`
fail_compilation/bug9631.d(117): Error: function `ft` is not callable using argument types `(S)`
    ft!()(x);
         ^
fail_compilation/bug9631.d(117):        cannot pass argument `x` of type `bug9631.S` to parameter `bug9631.tem!().S __param_0`
fail_compilation/bug9631.d(116):        `bug9631.targ.ft!().ft(S __param_0)` declared here
    void ft()(tem!().S){}
         ^
fail_compilation/bug9631.d(118): Error: template `ft` is not callable using argument types `!()(S)`
    ft(x);
      ^
fail_compilation/bug9631.d(116):        Candidate is: `ft()(tem!().S)`
    void ft()(tem!().S){}
         ^
fail_compilation/bug9631.d(120): Error: template `ft2` is not callable using argument types `!()(S, int)`
    ft2(y, 1);
       ^
fail_compilation/bug9631.d(119):        Candidate is: `ft2(T)(S, T)`
    void ft2(T)(S, T){}
         ^
---
*/

template T1()
{
    struct F { }
}

template T2()
{
    struct F { }
}

void main()
{
    T2!().F x = T1!().F();
}

struct S { char c; }

template tem()
{
    struct S { int i; }
}

void equal()
{
    S x;
    auto y = tem!().S();
    bool b = x == y;
}

void test3()
{
    S x;
    auto y = cast(tem!().S)x;

    tem!().S[1] ta;
    S[1] sa = cast(S[1])ta;
    auto t2 = cast(tem!().S[])sa;
}

void arg()
{
    S x;
    tem!().S y;

    void f(int i, S s);
    f(4, y);
    (tem!().S s){}(x);

    struct A
    {
        this(S){}
    }
    A(tem!().S());
}

void targ()
{
    S x;
    tem!().S y;

    void ft()(tem!().S){}
    ft!()(x);
    ft(x);
    void ft2(T)(S, T){}
    ft2(y, 1);
}
