/*
TEST_OUTPUT:
---
fail_compilation/dip1044.d(100): Error: `dip1044.foo` called with argument types `(void)` matches both:
fail_compilation/dip1044.d(51):     `dip1044.foo(A a)`
and:
fail_compilation/dip1044.d(52):     `dip1044.foo(B b)`
---
*/


enum A{ a, b, e }
#line 51
void foo(A a){}

enum B { b, c, }
#line 52
void foo(B b){}

int f()
{
#line 100
    foo($b);
}
