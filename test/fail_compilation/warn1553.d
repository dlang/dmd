// REQUIRED_ARGS: -w
// PERMUTE_ARGS:

/*
TEST_OUTPUT:
---
fail_compilation/warn1553.d(19): Warning: cannot use foreach_reverse with a delegate
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
