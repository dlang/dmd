// REQUIRED_ARGS: -o- -unittest
/*
TEST_OUTPUT:
---
fail_compilation/ice14424.d(12): Error: `tuple(__unittest_fail_compilation_imports_a14424_d_3_0)` has no effect
---
*/

void main()
{
    import imports.a14424;
    __traits(getUnitTests, imports.a14424);
}
