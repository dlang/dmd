/*
TEST_OUTPUT:
---
fail_compilation/fail10947.d(39): Error: cannot have `immutable out` parameter of type `immutable(S)`
void fooi1(out SI) {}
     ^
fail_compilation/fail10947.d(40): Error: cannot have `immutable out` parameter of type `immutable(S)`
void fooi2(out immutable(S)) {}
     ^
fail_compilation/fail10947.d(41): Error: cannot have `immutable out` parameter of type `immutable(S)`
void fooi3(out immutable S) {}
     ^
fail_compilation/fail10947.d(43): Error: cannot have `const out` parameter of type `const(S)`
void fooc1(out SC) {}
     ^
fail_compilation/fail10947.d(44): Error: cannot have `const out` parameter of type `const(S)`
void fooc2(out const(S)) {}
     ^
fail_compilation/fail10947.d(45): Error: cannot have `const out` parameter of type `const(S)`
void fooc3(out const S) {}
     ^
fail_compilation/fail10947.d(47): Error: cannot have `inout out` parameter of type `inout(S)`
void foow1(out SW) {}
     ^
fail_compilation/fail10947.d(48): Error: cannot have `inout out` parameter of type `inout(S)`
void foow2(out inout(S)) {}
     ^
fail_compilation/fail10947.d(49): Error: cannot have `inout out` parameter of type `inout(S)`
void foow3(out inout S) {}
     ^
---
*/

struct S {}
alias SI = immutable S;
alias SC = const S;
alias SW = inout S;

void fooi1(out SI) {}
void fooi2(out immutable(S)) {}
void fooi3(out immutable S) {}

void fooc1(out SC) {}
void fooc2(out const(S)) {}
void fooc3(out const S) {}

void foow1(out SW) {}
void foow2(out inout(S)) {}
void foow3(out inout S) {}
