/* TEST_OUTPUT:
---
fail_compilation/test16495.d(16): Error: undefined identifier `q`
    auto m = __traits(fullyQualifiedName, q);
             ^
fail_compilation/test16495.d(21): Error: expected 1 arguments for `fullyQualifiedName` but had 0
    auto n = __traits(fullyQualifiedName);
             ^
---
 */

// https://issues.dlang.org/show_bug.cgi?id=16495

void test1()
{
    auto m = __traits(fullyQualifiedName, q);
}

void test2()
{
    auto n = __traits(fullyQualifiedName);
}
