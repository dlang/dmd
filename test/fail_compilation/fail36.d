/*
TEST_OUTPUT:
---
fail_compilation/fail36.d(13): Error: no property 'a' for type 'void'
fail_compilation/fail36.d(18): Error: mixin fail36.func.t!10 error instantiating
---
*/

template t(int L)
{
    int a;
    // void foo(int b = t!(L).a) {} // correct
    void foo(int b = t.a) {} // wrong
}

void func()
{
    mixin t!(10);
}
