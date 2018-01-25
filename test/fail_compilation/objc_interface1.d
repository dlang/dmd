// EXTRA_OBJC_SOURCES
/*
TEST_OUTPUT:
---
fail_compilation/objc_interface1.d(11): Error: function `objc_interface1.A.oneTwo` must have Objective-C linkage to attach a selector
---
*/

interface A
{
    void oneTwo(int a, int b) @selector("one:two:"); // selector attached in non-Objective-C interface
}
