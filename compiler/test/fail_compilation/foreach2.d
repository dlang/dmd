/*
TEST_OUTPUT:
---
fail_compilation/foreach2.d(25): Error: argument type mismatch, `int` to `ref immutable(int)`
    foreach (immutable ref x; arr) {}
    ^
fail_compilation/foreach2.d(26): Error: argument type mismatch, `int` to `ref immutable(int)`
    foreach (immutable ref int x; arr) {}
    ^
fail_compilation/foreach2.d(29): Error: argument type mismatch, `int` to `ref double`
    foreach (          ref double x; arr) {}
    ^
fail_compilation/foreach2.d(30): Error: argument type mismatch, `int` to `ref const(double)`
    foreach (    const ref double x; arr) {}
    ^
fail_compilation/foreach2.d(31): Error: argument type mismatch, `int` to `ref immutable(double)`
    foreach (immutable ref double x; arr) {}
    ^
---
*/
void test4090 ()
{
    // From https://issues.dlang.org/show_bug.cgi?id=4090
    int[] arr = [1,2,3];
    foreach (immutable ref x; arr) {}
    foreach (immutable ref int x; arr) {}

    // convertible type + qualifier + ref
    foreach (          ref double x; arr) {}
    foreach (    const ref double x; arr) {}
    foreach (immutable ref double x; arr) {}
}
