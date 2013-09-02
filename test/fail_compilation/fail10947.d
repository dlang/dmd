/*
TEST_OUTPUT:
---
fail_compilation/fail10947.d(18): Error: cannot have immutable out parameter of type immutable(S)
fail_compilation/fail10947.d(19): Error: cannot have immutable out parameter of type immutable(S)
fail_compilation/fail10947.d(21): Error: cannot have const out parameter of type const(S)
fail_compilation/fail10947.d(22): Error: cannot have const out parameter of type const(S)
fail_compilation/fail10947.d(24): Error: cannot have inout out parameter of type inout(S)
fail_compilation/fail10947.d(25): Error: cannot have inout out parameter of type inout(S)
---
*/

struct S {}
alias SI = immutable S;
alias SC = const S;
alias SW = inout S;

void fooi1(out SI) {}
void fooi2(out immutable(S)) {}

void fooc1(out SC) {}
void fooc2(out const(S)) {}

void foow1(out SW) {}
void foow2(out inout(S)) {}
