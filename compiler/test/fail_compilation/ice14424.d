// REQUIRED_ARGS: -o- -unittest
// EXTRA_FILES: imports/a14424.d
/*
TEST_OUTPUT:
---
fail_compilation/ice14424.d(15): Error: `AliasSeq!(__unittest_L3_C1)` has no effect
    __traits(getUnitTests, imports.a14424);
    ^
---
*/

void main()
{
    import imports.a14424;
    __traits(getUnitTests, imports.a14424);
}
