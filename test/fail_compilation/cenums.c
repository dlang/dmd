/* TEST_OUTPUT:
---
fail_compilation/cenums.c(202): Error: `enum E2` is incomplete without members
fail_compilation/cenums.c(303): Error: redeclaring `union E3` as `enum E3`
fail_compilation/cenums.c(502): Error: enum member `cenums.test5.F.a` conflicts with enum member `cenums.test5.F.a` at fail_compilation/cenums.c(502)
fail_compilation/cenums.c(502): Error: enum member `cenums.test5.F.a` conflicts with enum member `cenums.test5.F.a` at fail_compilation/cenums.c(502)
---
*/

#line 100
enum E1 { a };
void test1()
{
    enum E1 e1;
}

#line 200
void test2()
{
    enum E2 e2;
}

#line 300
union E3;
void test3()
{
    enum E3 e3;
}

#line 400
void test4()
{
    enum E4 { a, b, c = 3, d };
    _Static_assert(sizeof(enum E4) == 4, "in");
    _Static_assert(a == 0, "in");
    _Static_assert(b == 1, "in");
    _Static_assert(c == 3, "in");
    _Static_assert(d == 4, "in");
}

#line 500
void test5()
{
    enum F { a, a };
}

#line 600
enum E6 { a6, b6 } c6;
_Static_assert(a6 == 0, "in");
_Static_assert(b6 == 1, "in");

#line 700
void test()
{
    enum E { a, b } c;
    _Static_assert(a == 0, "in");
    _Static_assert(b == 1, "in");
}

