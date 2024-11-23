// EXTRA_OBJC_SOURCES:
/* TEST_OUTPUT:
---
fail_compilation/objc_offsetof.d(15): Error: no property `offsetof` for member `a` of type `int`
enum o = Foo.a.offsetof;
         ^
fail_compilation/objc_offsetof.d(15):        `offsetof` is not available for members of Objective-C classes. Please use the Objective-C runtime instead
---
*/
extern (Objective-C) class Foo
{
    int a;
}

enum o = Foo.a.offsetof;
