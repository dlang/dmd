// EXTRA_OBJC_SOURCES
/*
TEST_OUTPUT:
---
fail_compilation/objc_non_objc_base.d(12): Error: interface `objc_non_objc_base.A` base interface for an Objective-C interface must be `extern (Objective-C)`
---
*/

interface Base {}

extern (Objective-C)
interface A : Base {}
