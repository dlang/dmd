/*
TEST_OUTPUT:
---
fail_compilation/diag6949.d(4): Error: Expression 'i' of unsigned type 'uint' can never be less than zero
fail_compilation/diag6949.d(5): Error: Zero can never be greater than expression 'i' of unsigned type 'uint'
---
*/

#line 1
void main()
{
    uint i = 0;
    if (i < 0) { }
    if (0 > i) { }
}
