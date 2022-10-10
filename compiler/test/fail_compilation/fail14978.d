// https://issues.dlang.org/show_bug.cgi?id=14978

/*
TEST_OUTPUT:
---
fail_compilation/fail14978.d(12): Error: an expression is expected between `()`, not a type
---
*/

void main()
{
    (const(char)*)[string] aa;
}
