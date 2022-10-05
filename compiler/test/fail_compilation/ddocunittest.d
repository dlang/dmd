/*
REQUIRED_ARGS: -D
TEST_OUTPUT:
---
fail_compilation/ddocunittest.d(27): Error: Documented unittest found following undocumented symbol `foo`
fail_compilation/ddocunittest.d(24):        `foo` declared here
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

void foo(bool) {}

unittest
{
    noo(1);
}

/// FIXME not detected
unittest
{
    foo(1);
}
