/*
TEST_OUTPUT:
---
fail_compilation/fail12390.d(15): Error: `fun().i == 4` may not be discarded, since it is likely a mistake
fail_compilation/fail12390.d(15):        Note that `fun().i` may have a side effect
---
*/

struct S { int i; }

S fun() { return S(42); }

void main()
{
    fun().i == 4;
}
