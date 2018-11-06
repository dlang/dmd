/*
TEST_OUTPUT:
---
fail_compilation/fail17674.d(21): Error: overloads `pure nothrow @nogc @safe int(S2 other)` and `pure nothrow @nogc @safe int(S1 other)` both match argument list for `opBinary`
---
*/

// https://issues.dlang.org/show_bug.cgi?id=17674
struct S1
{
    int opBinary(string op)(S2 other) { return 3; }
}

struct S2
{
    int opBinaryRight(string op)(S1 other) { return 4; }
}

void main()
{
    auto x = S1.init + S2.init;
}
