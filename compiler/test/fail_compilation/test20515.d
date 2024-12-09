// REQUIRED_ARGS: -verror-style=gnu
/*
TEST_OUTPUT:
---
fail_compilation/test20515.d:20: Deprecation: function `test20515.foo` is deprecated
    foo;
    ^
fail_compilation/test20515.d:21: Error: undefined identifier `bar`
    bar;
    ^
---
*/

module test20515;

deprecated void foo() { }

void test()
{
    foo;
    bar;
}
