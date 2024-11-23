/*
TEST_OUTPUT:
---
fail_compilation/fail163.d(34): Error: cannot implicitly convert expression `q` of type `const(char)[]` to `char[]`
    p = q;
        ^
fail_compilation/fail163.d(41): Error: cannot implicitly convert expression `p` of type `const(int***)` to `const(int)***`
    cp = p;
         ^
fail_compilation/fail163.d(48): Error: cannot modify `const` expression `p`
    p = cp;
    ^
fail_compilation/fail163.d(55): Error: cannot implicitly convert expression `cp` of type `const(int)***[]` to `const(uint***)[]`
    p = cp;
        ^
fail_compilation/fail163.d(62): Error: cannot modify `const` expression `*p`
    *p = 3;
    ^
fail_compilation/fail163.d(68): Error: cannot implicitly convert expression `& x` of type `int*` to `immutable(int)*`
    immutable(int)* p = &x;
                        ^
fail_compilation/fail163.d(69): Error: cannot modify `immutable` expression `*p`
    *p = 3;
    ^
fail_compilation/fail163.d(75): Error: cannot implicitly convert expression `& x` of type `const(int)*` to `int*`
    int* p = &x;
             ^
---
*/
void test1()
{
    char[] p;
    const(char)[] q;
    p = q;
}

void test2()
{
    const int*** p;
    const(int)*** cp;
    cp = p;
}

void test3()
{
    const(uint***) p;
    const(int)*** cp;
    p = cp;
}

void test4()
{
    const(uint***)[] p;
    const(int)***[] cp;
    p = cp;
}

void test5()
{
    int x;
    const(int)* p = &x;
    *p = 3;
}

void test6()
{
    int x;
    immutable(int)* p = &x;
    *p = 3;
}

void test7()
{
    const(int) x = 3;
    int* p = &x;
}
