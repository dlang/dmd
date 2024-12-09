/*
DFLAGS:
REQUIRED_ARGS: -c
EXTRA_SOURCES: extra-files/minimal/object.d
TEST_OUTPUT:
---
fail_compilation/no_TypeInfo.d(16): Error: `object.TypeInfo` could not be found, but is implicitly used
    auto ti = typeid(i);
              ^
---
*/

void test()
{
    int i;
    auto ti = typeid(i);
}
