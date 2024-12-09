/*
TEST_OUTPUT:
---
fail_compilation/fail10285.d(28): Error: no identifier for declarator `int`
    int = 5,
        ^
fail_compilation/fail10285.d(29): Error: expected `,` or `=` after identifier, not `y`
    int x y,
          ^
fail_compilation/fail10285.d(29): Error: initializer required after `x` when type is specified
fail_compilation/fail10285.d(30): Error: no identifier for declarator `int`
    int bool i = 3,
        ^
fail_compilation/fail10285.d(30): Error: found `bool` when expecting `,`
    int bool i = 3,
        ^
fail_compilation/fail10285.d(31): Error: no identifier for declarator `j`
    j int k = 3,
      ^
fail_compilation/fail10285.d(31): Error: found `int` when expecting `,`
    j int k = 3,
      ^
fail_compilation/fail10285.d(33): Error: initializer required after `z` when type is specified
---
*/
enum
{
    int = 5,
    int x y,
    int bool i = 3,
    j int k = 3,
    int z
}
