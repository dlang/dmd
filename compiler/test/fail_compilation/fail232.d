/*
TEST_OUTPUT:
---
fail_compilation/fail232.d(27): Error: shift by 33 is outside the range `0..31`
    i = i >> 33;
        ^
fail_compilation/fail232.d(27): Error: shift by 33 is outside the range `0..31`
    i = i >> 33;
        ^
fail_compilation/fail232.d(28): Error: shift by 33 is outside the range `0..31`
    i = i << 33;
        ^
fail_compilation/fail232.d(28): Error: shift by 33 is outside the range `0..31`
    i = i << 33;
        ^
fail_compilation/fail232.d(29): Error: shift by 33 is outside the range `0..31`
    i = i >>> 33;
        ^
fail_compilation/fail232.d(29): Error: shift by 33 is outside the range `0..31`
    i = i >>> 33;
        ^
---
*/
void bug1601() {
    int i;

    i = i >> 33;
    i = i << 33;
    i = i >>> 33;
}
