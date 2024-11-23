// https://issues.dlang.org/show_bug.cgi?id=3290
/*
TEST_OUTPUT:
---
fail_compilation/fail3290.d(14): Error: argument type mismatch, `const(int)` to `ref int`
    foreach (ref int i; array) {
    ^
---
*/

void main()
{
    const(int)[] array;
    foreach (ref int i; array) {
        //i = 42;
    }
}
