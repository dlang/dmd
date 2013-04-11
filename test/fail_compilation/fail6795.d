// 6795
/*
TEST_OUTPUT:
---
fail_compilation/fail6795.d(11): Error: constant 0 is not an lvalue
fail_compilation/fail6795.d(11): Error: constant 0 is not an lvalue
---
*/

void main() {
    enum int[] array = [0];
    array[0]++;
    array[0] += 3;
}



