/*
TEST_OUTPUT:
---
fail_compilation/fail9936.d(25): Error: `S().opBinary` isn't a template
fail_compilation/fail9936.d(26): Error: `S().opBinaryRight` isn't a template
fail_compilation/fail9936.d(27): Error: `s.opOpAssign` isn't a template
fail_compilation/fail9936.d(29): Error: `S().opIndexUnary` isn't a template
fail_compilation/fail9936.d(30): Error: `S().opUnary` isn't a template
---
*/
struct S
{
    auto opBinary(S s) { return 1; }
    auto opBinaryRight(int n) { return 1; }
    auto opOpAssign(S s) { return 1; }

    auto opIndexUnary(S s) { return 1; }
    auto opUnary(S s) { return 1; }
}
void f(S s)
{
    static assert(!is(typeof( S() + S() )));
    static assert(!is(typeof( 100 + S() )));
    static assert(!is(typeof( s += S() )));
    S() + S();
    100 + S();
    s += S();

    +S()[0];
    +S();
}
