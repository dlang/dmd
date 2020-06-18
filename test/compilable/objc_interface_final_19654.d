/*
EXTRA_OBJC_SOURCES:
TEST_OUTPUT:
---
compilable/objc_interface_final_19654.d(13): Deprecation: interface `objc_interface_final_19654.Bar` Objective-C interfaces have been deprecated
compilable/objc_interface_final_19654.d(13):        Representing an Objective-C class as a D interface has been deprecated. Please use `extern (Objective-C) extern class` instead
---
*/

import core.attribute : selector;

extern (Objective-C)
interface Bar
{
    final void foo() @selector("foo") {}
}
