// PERMUTE_ARGS:
// REQUIRED_ARGS: -vfield
/*
TEST_OUTPUT:
---
compilable/sw_vfield.d(15): sw_vfield.S1.ix is immutable field
compilable/sw_vfield.d(16): sw_vfield.S1.cx is const field
compilable/sw_vfield.d(21): sw_vfield.S2!(immutable(int)).S2.f is immutable field
compilable/sw_vfield.d(21): sw_vfield.S2!(const(int)).S2.f is const field
---
*/

struct S1
{
    immutable int ix = 1;
    const int cx = 2;
}

struct S2(F)
{
    F f = F.init;
}

alias S2!(immutable int) S2I;
alias S2!(    const int) S2C;
