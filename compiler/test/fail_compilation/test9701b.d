/*
REQUIRED_ARGS: -de
TEST_OUTPUT:
---
fail_compilation/test9701b.d(24): Deprecation: enum member `test9701b.Enum.e0` is deprecated
    auto value = Enum.e0;
                 ^
fail_compilation/test9701b.d(25): Deprecation: enum member `test9701b.Enum.e1` is deprecated - message
    auto value2 = Enum.e1;
                  ^
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
