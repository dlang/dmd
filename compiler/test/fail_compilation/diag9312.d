/*
TEST_OUTPUT:
---
fail_compilation/diag9312.d(12): Error: `with` expression types must be enums or aggregates or pointers to them, not `int`
    with (1)
    ^
---
*/

void main()
{
    with (1)
    {
    }
}
