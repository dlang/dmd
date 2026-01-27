/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/test9701b.d(22): Deprecation: enum member `test9701b.Enum.e0` is deprecated
fail_compilation/test9701b.d(16):        `e0` is declared here
fail_compilation/test9701b.d(23): Deprecation: enum member `test9701b.Enum.e1` is deprecated - message
fail_compilation/test9701b.d(17):        `e1` is declared here
---
*/

// https://issues.dlang.org/show_bug.cgi?id=9701

enum Enum
{
    deprecated e0,
    deprecated("message") e1,
}

void main()
{
    auto value = Enum.e0;
    auto value2 = Enum.e1;
}
