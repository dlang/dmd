/*
TEST_OUTPUT:
---
fail_compilation/diag11088.d(11): Error: enum member diag11088.E.B initialization with (E.A + 1) causes overflow for type 'int'
fail_compilation/diag11088.d(17): Error: enum member diag11088.E1.B initialization with (E1.A + 1) causes overflow for type 'short'
---
*/
enum E
{
    A = int.max,
    B
}

enum E1 : short
{
    A = short.max,
    B
}
