/*
REQUIRED_ARGS: -vcolumns
TEST_OUTPUT:
---
fail_compilation/aa_init.d(19,18): Error: invalid associative array initializer `[]`, use `null` instead
    int[int] a = [];
                 ^
fail_compilation/aa_init.d(20,24): Error: missing key for value `4` in initializer
    int[int] b = [2:3, 4];
                       ^
fail_compilation/aa_init.d(21,9): Error: cannot implicitly convert expression `[]` of type `void[]` to `int[int]`
    a = [];
        ^
---
*/

void main()
{
    int[int] a = [];
    int[int] b = [2:3, 4];
    a = [];
}
