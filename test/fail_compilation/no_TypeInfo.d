/* 
DFLAGS:
REQUIRED_ARGS: -c -I=fail_compilation/extra-files/minimal/
TEST_OUTPUT:
---
fail_compilation/no_TypeInfo.d(13): Error: `object.TypeInfo` could not be found, but is implicitly used
---
*/

void test()
{
    int i;
    auto ti = typeid(i);
}

