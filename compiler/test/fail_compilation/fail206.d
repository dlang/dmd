/*
TEST_OUTPUT:
---
fail_compilation/fail206.d(11): Error: shift assign by 65 is outside the range `0..63`
        c >>>= 65;
          ^
---
*/
void main() {
        long c;
        c >>>= 65;
}
