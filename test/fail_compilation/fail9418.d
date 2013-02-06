/*
TEST_OUTPUT:
---
fail_compilation/fail9418.d(20): Error: Array operation -a[] not implemented
fail_compilation/fail9418.d(21): Error: Array operation ~a[] not implemented
fail_compilation/fail9418.d(23): Error: Array operation a[] + a[] not implemented
fail_compilation/fail9418.d(24): Error: Array operation a[] - a[] not implemented
fail_compilation/fail9418.d(25): Error: Array operation a[] * a[] not implemented
fail_compilation/fail9418.d(26): Error: Array operation a[] / a[] not implemented
fail_compilation/fail9418.d(27): Error: Array operation a[] % a[] not implemented
fail_compilation/fail9418.d(28): Error: Array operation a[] ^ a[] not implemented
fail_compilation/fail9418.d(29): Error: Array operation a[] & a[] not implemented
fail_compilation/fail9418.d(30): Error: Array operation a[] | a[] not implemented
fail_compilation/fail9418.d(31): Error: Array operation a[] ^^ a[] not implemented
---
*/
void main()
{
    int[] a = [1, 2, 3];
    a = -a[];
    a = ~a[];   // 9418

    a = a[] + a[];
    a = a[] - a[];
    a = a[] * a[];
    a = a[] / a[];
    a = a[] % a[];  // 9458
    a = a[] ^ a[];
    a = a[] & a[];
    a = a[] | a[];
    a = a[] ^^ a[];
}
