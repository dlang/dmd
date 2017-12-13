/*
TEST_OUTPUT:
---
fail_compilation/bug9631.d(20): Error: cannot implicitly convert expression `F()` of type `bug9631.T1!().F` to `bug9631.T2!().F`
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

/*
TEST_OUTPUT:
---
fail_compilation/bug9631.d(41): Error: incompatible types for ((x) == (y)): 'bug9631.S' and 'bug9631.tem!().S'
---
*/

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

/*
TEST_OUTPUT:
---
fail_compilation/bug9631.d(55): Error: cannot cast expression `x` of type `bug9631.S` to `bug9631.tem!().S` because of different sizes
fail_compilation/bug9631.d(58): Error: cannot cast expression `ta` of type `bug9631.tem!().S[1]` to `bug9631.S[1]` because of different sizes
fail_compilation/bug9631.d(59): Error: cannot cast expression `sa` of type `S[1]` to `S[]` since sizes don't line up
---
*/
void test3()
{
    S x;
    auto y = cast(tem!().S)x;

    tem!().S[1] ta;
    S[1] sa = cast(S[1])ta;
    auto t2 = cast(tem!().S[])sa;
}
