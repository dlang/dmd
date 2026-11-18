/*
REQUIRED_ARGS: -vcolumns
TEST_OUTPUT:
---
fail_compilation/aa_init.d(15,18): Error: invalid associative array initializer `[]`, use `null` instead
fail_compilation/aa_init.d(16,24): Error: missing key for value `4` in initializer
fail_compilation/aa_init.d(17,9): Error: cannot implicitly convert expression `[]` of type `void[]` to `int[int]`
fail_compilation/aa_init.d(18,19): Error: missing key for value `1` in initializer
fail_compilation/aa_init.d(19,30): Error: cannot implicitly convert expression `true ? [] : cast(void[])null` of type `void[]` to `int[int]`
---
*/

void main()
{
    int[int] a = [];
    int[int] b = [2:3, 4];
    a = [];
    int[int] c = [1, 2];
    static int[int] d = true ? [] : null;
}
