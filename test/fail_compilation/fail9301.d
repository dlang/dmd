/*
REQUIRED_ARGS: -m64 -o-
PERMUTE_ARGS:
TEST_OUTPUT:
---
fail_compilation/fail9301.d(12): Error: cannot implicitly convert expression `0` of type `int` to `__vector(void[16])`
---
*/

void main()
{
    __vector(void[16]) x = 0x0;
}
