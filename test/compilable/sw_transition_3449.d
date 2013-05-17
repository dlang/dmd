// PERMUTE_ARGS:
// REQUIRED_ARGS: -c -transition=3449
/*
TEST_OUTPUT:
---
compilable/sw_transition_3449.d(15): sw_transition_3449.S1.ix is immutable field
compilable/sw_transition_3449.d(16): sw_transition_3449.S1.cx is const field
compilable/sw_transition_3449.d(21): sw_transition_3449.S2!(immutable(int)).S2.f is immutable field
compilable/sw_transition_3449.d(21): sw_transition_3449.S2!(const(int)).S2.f is const field
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
