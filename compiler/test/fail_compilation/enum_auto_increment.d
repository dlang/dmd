/*
TEST_OUTPUT:
---
fail_compilation/enum_auto_increment.d(17): Error: auto-increment for enum member `d` cannot be performed because the base type `A1` does not support auto increment.
---
*/

enum A1 : int
{
    a,
    b,
}

enum A2 : A1
{
    c,
    d,
}
