/*
EXTRA_OBJC_SOURCES:
TEST_OUTPUT:
---
compilable/objc_interface_final_19654.d(11): Deprecation: interface `objc_interface_final_19654.Bar` Objective-C interfaces have been deprecated
compilable/objc_interface_final_19654.d(11):        Representing an Objective-C class as a D interface has been deprecated. Please use `extern (Objective-C) extern class` instead
---
*/

extern (Objective-C)
interface Bar
{
    final void foo() @selector("foo") {}
}
