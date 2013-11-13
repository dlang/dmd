/*
TEST_OUTPUT:
---
fail_compilation/fail8179b.d(10): Error: e2ir: cannot cast [1, 2] of type int[] to type int[2][1]
---
*/

void foo(int[2][1]) {}
void main() {
    foo(cast(int[2][1])[1, 2]);
}

