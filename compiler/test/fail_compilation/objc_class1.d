// EXTRA_OBJC_SOURCES:
/*
TEST_OUTPUT:
---
fail_compilation/objc_class1.d(13): Error: function `objc_class1.A.oneTwo` must have Objective-C linkage to attach a selector
---
*/

import core.attribute : selector;

class A
{
    void oneTwo(int a, int b) @selector("one:two:"); // selector attached in non-Objective-C interface
}
