/*
TEST_OUTPUT:
---
fail_compilation/issue20288.d(13): Error: no property `dtor` for `new C` of type `issue20288.test.C`
fail_compilation/issue20288.d(12):        class `C` defined here
---
*/

// https://github.com/dlang/dmd/issues/20288
void test()
{
    class C { ~this(){} }
    (new C).dtor();
}
