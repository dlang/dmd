/*
TEST_OUTPUT:
---
fail_compilation/fail10285.d(17): Error: no identifier for declarator `int`
fail_compilation/fail10285.d(18): Error: expected `,` or `=` after identifier, not `y`
fail_compilation/fail10285.d(18): Error: initializer required after `x` when type is specified
fail_compilation/fail10285.d(19): Error: no identifier for declarator `int`
fail_compilation/fail10285.d(19): Error: found `bool` when expecting `,`
fail_compilation/fail10285.d(20): Error: no identifier for declarator `j`
fail_compilation/fail10285.d(20): Error: found `int` when expecting `,`
fail_compilation/fail10285.d(21): Error: basic type expected, not `for`
fail_compilation/fail10285.d(23): Error: initializer required after `z` when type is specified
---
*/
enum
{
    int = 5,
    int x y,
    int bool i = 3,
    j int k = 3,
    for,
    int z
}
