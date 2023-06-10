/*
TEST_OUTPUT:
---
fail_compilation/b17285.d(14): Error: type `ONE` has no value
fail_compilation/b17285.d(14): Error: type `TWO` has no value
---
*/


class ONE {}
enum TWO;

void foo() {
    foreach(key; [ONE, TWO, 1]) {}
}
