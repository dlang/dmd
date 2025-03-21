/*
TEST_OUTPUT:
---
fail_compilation/enum_auto_increment.d(18): Error: cannot automatically assign value to enum member `enum_auto_increment.A2.d` because base type `A1` is an enum; please provide an explicit value
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
