/*
TEST_OUTPUT:
---
fail_compilation/test17596.d(24): Error: overloads `(S1 lhs)` and `(S1 lhs)` both match argument list for `opBinaryRight`
fail_compilation/test17596.d(18):        `test17596.S2.opBinaryRight!"+".opBinaryRight` is declared here
fail_compilation/test17596.d(19):        `test17596.S2.opBinaryRight!"+".opBinaryRight` is declared here
fail_compilation/test17596.d(24): Error: forward reference to template `opBinaryRight`
fail_compilation/test17596.d(24): Error: function `test17596.S2.opBinaryRight!"+".opBinaryRight(S1 lhs)` is not callable using argument types `(S1)`
fail_compilation/test17596.d(24): Error: forward reference to template `opBinaryRight`
---
*/

// https://github.com/dlang/dmd/issues/17596

struct S1 {}
struct S2
{
    int opBinaryRight(string op)(S1 lhs) if (op == "+") { return 1; }
    int opBinaryRight(string op)(S1 lhs) if (true) { return 2; }
}

void test17596()
{
    auto x = S1.init + S2.init;
}
