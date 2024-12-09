/*
TEST_OUTPUT:
---
fail_compilation/fail201.d(14): Error: shift by 33 is outside the range `0..31`
        c = c >>> 33;
            ^
fail_compilation/fail201.d(14): Error: shift by 33 is outside the range `0..31`
        c = c >>> 33;
            ^
---
*/
void main() {
        int c;
        c = c >>> 33;
}
