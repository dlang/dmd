// REQUIRED_ARGS: -property
/*
TEST_OUTPUT:
---
fail_compilation/diag8629.d(9): Error: not a property s.gunc
---
*/

#line 1
struct S {}

auto gunc(S s, int n) { return 13; }
@property grop(S s, int n) { return 14; }

void main()
{
    S s;
    assert((s.gunc = 1) == 13);     // line 9
    assert((s.grop = 1) == 14);     // line 10
}
