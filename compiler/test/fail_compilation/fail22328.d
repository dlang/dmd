/*
TEST_OUTPUT:
---
fail_compilation/fail22328.d(14): Error: cannot modify the content of array literal `[1, 2, 3]`
fail_compilation/fail22328.d(14): Error: cannot modify the content of array literal `[1, 2, 3]`
fail_compilation/fail22328.d(15): Error: cannot modify the content of array literal `[10, 20]`
fail_compilation/fail22328.d(15): Error: cannot modify the content of array literal `[10, 20]`
fail_compilation/fail22328.d(17): Error: cannot modify the content of array literal `[1, 2, 3]`
---
*/

void main() {
    enum ARR = [1, 2, 3];
    ARR[2] = 4;
    [10, 20][0] = 30;

    ARR[0..2] = [4, 5];

    auto p = &ARR[0];
}
