/*
REQUIRED_ARGS: -de
TEST_OUTPUT
---
fail_compilation/test9701b.d(13): Deprecation: enum member `test9701b.Enum.e0` is deprecated
---
*/

// https://issues.dlang.org/show_bug.cgi?id=9701

enum Enum
{
    deprecated e0,
}

void main()
{
    auto value = Enum.e0;
}
