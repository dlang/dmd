/*
TEST_OUTPUT:
---
fail_compilation/diag8629.d(16): Error: not a property gunc
---
*/

struct S {}

auto gunc(S s, int n) { return 13; }
@property grop(S s, int n) { return 14; }

void main()
{
    S s;
    assert((s.gunc = 1) == 13);
    assert((s.grop = 1) == 14);
}
