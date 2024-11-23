/*
TEST_OUTPUT:
---
fail_compilation/fail9936.d(35): Error: `S().opBinary` isn't a template
    S() + S();
     ^
fail_compilation/fail9936.d(36): Error: `S().opBinaryRight` isn't a template
    100 + S();
           ^
fail_compilation/fail9936.d(37): Error: `S().opOpAssign` isn't a template
    S() += S();
        ^
fail_compilation/fail9936.d(39): Error: `S().opIndexUnary` isn't a template
    +S()[0];
    ^
fail_compilation/fail9936.d(40): Error: `S().opUnary` isn't a template
    +S();
    ^
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
void main()
{
    static assert(!is(typeof( S() + S() )));
    static assert(!is(typeof( 100 + S() )));
    static assert(!is(typeof( S() += S() )));
    S() + S();
    100 + S();
    S() += S();

    +S()[0];
    +S();
}
