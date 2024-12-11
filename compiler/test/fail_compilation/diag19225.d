/*
TEST_OUTPUT:
---
fail_compilation/diag19225.d(18): Error: basic type expected, not `else`
    static else {}
           ^
fail_compilation/diag19225.d(18):        There's no `static else`, use `else` instead.
fail_compilation/diag19225.d(18): Error: found `else` without a corresponding `if`, `version` or `debug` statement
    static else {}
           ^
fail_compilation/diag19225.d(19): Error: unmatched closing brace
---
*/

void main()
{
    static if (true) {}
    static else {}
}
