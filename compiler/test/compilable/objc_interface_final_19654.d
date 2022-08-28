// EXTRA_OBJC_SOURCES:

import core.attribute : selector;

extern (Objective-C)
interface Bar
{
    final void foo() @selector("foo") {}
}
