/*
REQUIRED_ARGS: -D
TEST_OUTPUT:
---
fail_compilation/ddocunittest.d(14): Error: Documented unittest found following undocumented symbol `foo`
fail_compilation/ddocunittest.d(11):        `foo` declared here
fail_compilation/ddocunittest.d(27): Error: Documented unittest found following undocumented symbol `bar`
fail_compilation/ddocunittest.d(19):        `bar` declared here
---
*/
void foo(string) {}

///
unittest
{
    foo(1);
}

void bar() {}

unittest
{
    noo(1);
}

///
unittest
{
    foo(1);
}
