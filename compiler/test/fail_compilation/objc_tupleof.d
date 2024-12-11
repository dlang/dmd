// EXTRA_OBJC_SOURCES:
/* TEST_OUTPUT:
---
fail_compilation/objc_tupleof.d(18): Error: no property `tupleof` for type `objc_tupleof.Foo`
    auto a = foo.tupleof[0];
             ^
fail_compilation/objc_tupleof.d(18):        `tupleof` is not available for members of Objective-C classes. Please use the Objective-C runtime instead
---
*/
extern (Objective-C) class Foo
{
    int a;
}

void bar()
{
    Foo foo;
    auto a = foo.tupleof[0];
}
