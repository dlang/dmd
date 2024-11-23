/*
DFLAGS:
TEST_OUTPUT:
---
fail_compilation/fail19923.d(18): Error: `object.TypeInfo_Class` could not be found, but is implicitly used
    auto ti = o.classinfo;
              ^
---
*/

module object;

class Object {}

void test()
{
    Object o;
    auto ti = o.classinfo;
}
