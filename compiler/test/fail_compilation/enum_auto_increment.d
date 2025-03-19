/*
TEST_OUTPUT:
---
fail_compilation/enum_auto_increment.d(13): Error: auto-increment for enum member `d` cannot be performed because the base type `A1` does not support auto increment.
---
*/

enum A1 : int
{
    a,
    b,
}

enum A2 : A1
{
    c, // First member, should initialize correctly
    d, // This should trigger the error due to auto-increment on an enum with an enum base type
}
