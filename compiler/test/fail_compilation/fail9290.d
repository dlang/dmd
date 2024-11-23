/*
TEST_OUTPUT:
---
fail_compilation/fail9290.d(19): Error: slice `s1[]` is not mutable, struct `S` has immutable members
    s1 = S(3);
       ^
fail_compilation/fail9290.d(20): Error: array `s1` is not mutable, struct `S` has immutable members
    s1 = s2;
       ^
---
*/

struct S { immutable int i; }

void main()
{
    S[1] s1 = S(1);
    S[1] s2 = S(2);
    s1 = S(3);
    s1 = s2;
}
