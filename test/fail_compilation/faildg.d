/*
TEST_OUTPUT:
---
fail_compilation/faildg.d(20): Error: dg.ptr is not an lvalue
fail_compilation/faildg.d(21): Error: dg.funcptr is not an lvalue
---
*/

/********************************************************/

class Foo11 {
    int x = 7;
    int func() { return x; }
}

void test11()
{
    int delegate() dg;
    Foo11 f = new Foo11;
    dg.ptr = cast(void*)f;
    dg.funcptr = &Foo11.func;
    assert(dg() == 7);
}
