// REQUIRED_ARGS: -vcolumns

/*
TEST_OUTPUT:
---
fail_compilation/testCols.d(14,5): Error: undefined identifier `nonexistent`
    nonexistent();
    ^
---
*/

void test()
{
    nonexistent();
}
