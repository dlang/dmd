/*
REQUIRED_ARGS: -D
TEST_OUTPUT:
---
fail_compilation/ddocunittest.d(29): Error: Documented unittest found following undocumented symbol `foo`
fail_compilation/ddocunittest.d(26):        `foo` declared here
fail_compilation/ddocunittest.d(40): Error: Documented unittest found following undocumented symbol `__unittest_L24_C1`
fail_compilation/ddocunittest.d(34):        `__unittest_L24_C1` declared here
---
*/
/// document foo
void foo(int) {}

///
unittest
{
    foo(1);
}

// ignore
unittest
{
    noo(1);
}

void foo(string) {}

///
unittest
{
    foo(1);
}

unittest
{
    noo(1);
}

///
unittest
{
    foo(1);
}
