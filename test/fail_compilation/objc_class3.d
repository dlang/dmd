// EXTRA_OBJC_SOURCES
/*
TEST_OUTPUT:
---
fail_compilation/objc_class3.d(13): Error: function `objc_class3.A.test!int.test` template cannot have an Objective-C selector attached
fail_compilation/objc_class3.d(19): Error: template instance `objc_class3.A.test!int` error instantiating
---
*/

extern (Objective-C)
class A
{
    void test(T)(T a) @selector("test:"); // selector defined for template
}

void test()
{
    A a;
    a.test(3);
}
