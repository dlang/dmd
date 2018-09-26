/*
DFLAGS:
REQUIRED_ARGS: -c -I=fail_compilation/extra-files/no_TypeInfo/
TEST_OUTPUT:
---
fail_compilation/no_TypeInfo.d(15): Error: `object.TypeInfo` could not be found, but is implicitly used
---
*/

nothrow:

void test()
{
    int i;
    auto ti = typeid(i);
}

