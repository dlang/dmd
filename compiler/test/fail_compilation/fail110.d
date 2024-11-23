/*
TEST_OUTPUT:
---
fail_compilation/fail110.d(31): Error: variable `i` is shadowing variable `fail110.main.i`
    foreach (i; a) {}
    ^
fail_compilation/fail110.d(29):        declared here
    int i;
        ^
fail_compilation/fail110.d(32): Error: variable `i` is shadowing variable `fail110.main.i`
    foreach (size_t i, n; a) {}
    ^
fail_compilation/fail110.d(29):        declared here
    int i;
        ^
fail_compilation/fail110.d(33): Error: variable `i` is shadowing variable `fail110.main.i`
    for (int i;;) {}
         ^
fail_compilation/fail110.d(29):        declared here
    int i;
        ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=297
// Shadowing declarations allowed in foreach type lists
void main()
{
    int i;
    int[] a;
    foreach (i; a) {}
    foreach (size_t i, n; a) {}
    for (int i;;) {}
}
