// REQUIRED_ARGS: -o- -unittest
/*
TEST_OUTPUT:
---
fail_compilation/ice14424.d(12): Error: `tuple(__unittest_imports_a14424_3_0)` has no effect
---
*/

void main()
{
    import imports.a14424;
    __traits(getUnitTests, imports.a14424);
}
