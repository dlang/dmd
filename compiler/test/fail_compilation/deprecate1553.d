/*
TEST_OUTPUT:
---
fail_compilation/deprecate1553.d(18): Error: cannot use `foreach_reverse` with a delegate
    foreach_reverse(a; &s.dg) {}
    ^
---
*/

struct S
{
    int dg(int delegate(ref int a)) { return 0; }
}

void main()
{
    S s;
    foreach_reverse(a; &s.dg) {}
}
