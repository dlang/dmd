/*
REQUIRED_ARGS: -vcolumns
TEST_OUTPUT:
---
fail_compilation/fail21851.d(11,21): Error: cannot implicitly convert expression `42` of type `int` to `string`
---
*/

void main()
{
    string straße = 42;
}
