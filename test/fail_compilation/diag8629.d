/*
TEST_OUTPUT:
---
fail_compilation/diag8629.d(8): Error: undefined identifier 'undef'
---
*/

#line 1
struct S {}

@property grop(S s, int n) { return 14; }

void main()
{
    S s;
    undef(); // line 8
    assert((s.grop = 1) == 14);
}
