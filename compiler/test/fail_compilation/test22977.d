/* REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/test22977.d(107): Error: reference to stack allocated value returned by `fn()` assigned to non-scope `gPtr`
---
*/

// https://issues.dlang.org/show_bug.cgi?id=22977

#line 100

int* gPtr;

void test() @safe
{
    scope int* sPtr;
    int* fn() { return sPtr; }
    gPtr = fn();
}
