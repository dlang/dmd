// REQUIRED_ARGS: -o-
/*
TEST_OUTPUT:
---
fail_compilation/fail3903.d(24): Error: invalid array operation -a (possible missing [])
fail_compilation/fail3903.d(25): Error: invalid array operation ~a (possible missing [])
fail_compilation/fail3903.d(26): Error: invalid array operation a + a (possible missing [])
fail_compilation/fail3903.d(27): Error: invalid array operation a - a (possible missing [])
fail_compilation/fail3903.d(28): Error: invalid array operation a * a (possible missing [])
fail_compilation/fail3903.d(29): Error: invalid array operation a / a (possible missing [])
fail_compilation/fail3903.d(30): Error: invalid array operation a % a (possible missing [])
fail_compilation/fail3903.d(31): Error: invalid array operation a ^^ a (possible missing [])
fail_compilation/fail3903.d(32): Error: invalid array operation a & a (possible missing [])
fail_compilation/fail3903.d(33): Error: invalid array operation a | a (possible missing [])
fail_compilation/fail3903.d(34): Error: invalid array operation a ^ a (possible missing [])
---
*/

void test1()
{
    int[] a = [1, 2];
    int[] r;

    r = -a;
    r = ~a;
    r = a + a;
    r = a - a;
    r = a * a;
    r = a / a;
    r = a % a;
    r = a ^^ a;
    r = a & a;
    r = a | a;
    r = a ^ a;
}
