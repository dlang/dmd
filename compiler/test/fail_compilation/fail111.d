/*
TEST_OUTPUT:
---
fail_compilation/fail111.d(14): Error: cannot have array of `int(int)`
ft[] x;  // is allowed
     ^
---
*/

// https://issues.dlang.org/show_bug.cgi?id=289
// Compiler allows (and crashes on) dynamic arrays of typedefs of "immediate"-function types
alias int ft(int);

ft[] x;  // is allowed

void test()
{
    x.length = 2;  // crashes DMD
}
