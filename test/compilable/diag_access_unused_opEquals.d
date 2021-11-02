// REQUIRED_ARGS: -wi -vcolumns -unittest -vunused

/*
TEST_OUTPUT:
---
compilable/diag_access_unused_opEquals.d(10,9): Warning: unused private struct `S`
---
*/

private struct S
{
    @disable this(this);      // no warning for compiler generated `__xpostblit`
}
