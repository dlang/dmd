/*
TEST_OUTPUT:
---
fail_compilation/diag9148.d(37): Error: `pure` function `diag9148.test9148a.foo` cannot access mutable static data `g`
        g++;
        ^
fail_compilation/diag9148.d(41): Error: `pure` function `diag9148.test9148a.bar` cannot access mutable static data `g`
        g++;
        ^
fail_compilation/diag9148.d(42): Error: `immutable` function `diag9148.test9148a.bar` cannot access mutable data `x`
        x++;
        ^
fail_compilation/diag9148.d(49): Error: `pure` function `diag9148.test9148a.S.foo` cannot access mutable static data `g`
            g++;
            ^
fail_compilation/diag9148.d(53): Error: `pure` function `diag9148.test9148a.S.bar` cannot access mutable static data `g`
            g++;
            ^
fail_compilation/diag9148.d(54): Error: `immutable` function `diag9148.test9148a.S.bar` cannot access mutable data `x`
            x++;
            ^
fail_compilation/diag9148.d(64): Error: `static` function `diag9148.test9148b.foo` cannot access variable `x` in frame of function `diag9148.test9148b`
        int y = x;
                ^
fail_compilation/diag9148.d(61):        `x` declared here
    int x;
        ^
---
*/
void test9148a() pure
{
    static int g;
    int x;

    void foo() /+pure+/
    {
        g++;
    }
    void bar() immutable /+pure+/
    {
        g++;
        x++;
    }

    struct S
    {
        void foo() /+pure+/
        {
            g++;
        }
        void bar() immutable /+pure+/
        {
            g++;
            x++;
        }
    }
}

void test9148b()
{
    int x;
    static void foo() pure
    {
        int y = x;
    }
}
