// EXTRA_OBJC_SOURCES
// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/deprecate_objc_interface.d(10): Deprecation: interface `deprecate_objc_interface.NSObject` Objective-C interfaces have been deprecated
fail_compilation/deprecate_objc_interface.d(10):        Representing an Objective-C class as a D interface has been deprecated. Please use `extern (Objective-C) extern class` instead
---
*/
extern (Objective-C) interface NSObject
{

}
