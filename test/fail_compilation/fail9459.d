/*
REQUIRED_ARGS: -o-
PERMUTE_ARGS:
TEST_OUTPUT:
---
fail_compilation/fail9459.d(32): Error: invalid array operation a = -a[] (did you forget a [] ?)
fail_compilation/fail9459.d(33): Error: invalid array operation a = ~a[] (did you forget a [] ?)
fail_compilation/fail9459.d(35): Error: invalid array operation a = a[] + a[] (did you forget a [] ?)
fail_compilation/fail9459.d(36): Error: invalid array operation a = a[] - a[] (did you forget a [] ?)
fail_compilation/fail9459.d(37): Error: invalid array operation a = a[] * a[] (did you forget a [] ?)
fail_compilation/fail9459.d(38): Error: invalid array operation a = a[] / a[] (did you forget a [] ?)
fail_compilation/fail9459.d(39): Error: invalid array operation a = a[] % a[] (did you forget a [] ?)
fail_compilation/fail9459.d(40): Error: invalid array operation a = a[] ^ a[] (did you forget a [] ?)
fail_compilation/fail9459.d(41): Error: invalid array operation a = a[] & a[] (did you forget a [] ?)
fail_compilation/fail9459.d(42): Error: invalid array operation a = a[] | a[] (did you forget a [] ?)
fail_compilation/fail9459.d(43): Error: invalid array operation a = a[] ^^ a[] (did you forget a [] ?)
fail_compilation/fail9459.d(45): Error: invalid array operation a += a[] (did you forget a [] ?)
fail_compilation/fail9459.d(46): Error: invalid array operation a -= a[] (did you forget a [] ?)
fail_compilation/fail9459.d(47): Error: invalid array operation a *= a[] (did you forget a [] ?)
fail_compilation/fail9459.d(48): Error: invalid array operation a /= a[] (did you forget a [] ?)
fail_compilation/fail9459.d(49): Error: invalid array operation a %= a[] (did you forget a [] ?)
fail_compilation/fail9459.d(50): Error: invalid array operation a ^= a[] (did you forget a [] ?)
fail_compilation/fail9459.d(51): Error: invalid array operation a &= a[] (did you forget a [] ?)
fail_compilation/fail9459.d(52): Error: invalid array operation a |= a[] (did you forget a [] ?)
fail_compilation/fail9459.d(53): Error: invalid array operation a ^^= a[] (did you forget a [] ?)
---
*/

void main()
{
    int[] a = [1, 2, 3];
    a = -a[];
    a = ~a[];

    a = a[] + a[];
    a = a[] - a[];
    a = a[] * a[];
    a = a[] / a[];
    a = a[] % a[];
    a = a[] ^ a[];
    a = a[] & a[];
    a = a[] | a[];
    a = a[] ^^ a[];

    a += a[];
    a -= a[];
    a *= a[];
    a /= a[];
    a %= a[];
    a ^= a[];
    a &= a[];
    a |= a[];
    a ^^= a[];
}
