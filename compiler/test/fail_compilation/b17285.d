/*
TEST_OUTPUT:
---
fail_compilation/b17285.d(20): Error: type `ONE` has no value
    foreach(key; [ONE, TWO, 1]) {}
                  ^
fail_compilation/b17285.d(20): Error: type `TWO` has no value
    foreach(key; [ONE, TWO, 1]) {}
                       ^
fail_compilation/b17285.d(20): Error: cannot implicitly convert expression `ONE` of type `b17285.ONE` to `int`
    foreach(key; [ONE, TWO, 1]) {}
                  ^
---
*/

class ONE {}
enum TWO;

void foo() {
    foreach(key; [ONE, TWO, 1]) {}
}
