// EXTRA_OBJC_SOURCES
/*
TEST_OUTPUT:
---
fail_compilation/objc_class2.d(12): Error: function `objc_class2.A.test` number of colons in Objective-C selector must match number of parameters
---
*/

extern (Objective-C)
class A
{
    void test(int a, int b, int c) @selector("test:"); // non-matching number of colon
}
