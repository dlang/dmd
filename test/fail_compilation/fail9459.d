/*
REQUIRED_ARGS: -o-
PERMUTE_ARGS:
TEST_OUTPUT:
---
fail_compilation/fail9459.d(32): Error: array operation -a[] without destination memory not allowed (possible missing [])
fail_compilation/fail9459.d(33): Error: array operation ~a[] without destination memory not allowed (possible missing [])
fail_compilation/fail9459.d(35): Error: array operation a[] + a[] without destination memory not allowed (possible missing [])
fail_compilation/fail9459.d(36): Error: array operation a[] - a[] without destination memory not allowed (possible missing [])
fail_compilation/fail9459.d(37): Error: array operation a[] * a[] without destination memory not allowed (possible missing [])
fail_compilation/fail9459.d(38): Error: array operation a[] / a[] without destination memory not allowed (possible missing [])
fail_compilation/fail9459.d(39): Error: array operation a[] % a[] without destination memory not allowed (possible missing [])
fail_compilation/fail9459.d(40): Error: array operation a[] ^ a[] without destination memory not allowed (possible missing [])
fail_compilation/fail9459.d(41): Error: array operation a[] & a[] without destination memory not allowed (possible missing [])
fail_compilation/fail9459.d(42): Error: array operation a[] | a[] without destination memory not allowed (possible missing [])
fail_compilation/fail9459.d(43): Error: array operation a[] ^^ a[] without destination memory not allowed (possible missing [])
fail_compilation/fail9459.d(45): Error: invalid array operation a += a[] (possible missing [])
fail_compilation/fail9459.d(46): Error: invalid array operation a -= a[] (possible missing [])
fail_compilation/fail9459.d(47): Error: invalid array operation a *= a[] (possible missing [])
fail_compilation/fail9459.d(48): Error: invalid array operation a /= a[] (possible missing [])
fail_compilation/fail9459.d(49): Error: invalid array operation a %= a[] (possible missing [])
fail_compilation/fail9459.d(50): Error: invalid array operation a ^= a[] (possible missing [])
fail_compilation/fail9459.d(51): Error: invalid array operation a &= a[] (possible missing [])
fail_compilation/fail9459.d(52): Error: invalid array operation a |= a[] (possible missing [])
fail_compilation/fail9459.d(53): Error: invalid array operation a ^^= a[] (possible missing [])
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
