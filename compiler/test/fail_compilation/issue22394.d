/*
TEST_OUTPUT:
---
fail_compilation/issue22394.d(11): Error: incompatible types for `(a) + (1)`: `string` and `int`
fail_compilation/issue22394.d(15):        instantiated from here: `lambda function`
---
*/

// https://issues.dlang.org/show_bug.cgi?id=22394

alias l = a => a + 1;

void f()
{
    l("");
}
