/*
REQUIRED_ARGS: -de
TEST_OUTPUT
---
fail_compilation/test19202.d(13): Deprecation: variable `test19202.X!().X` is deprecated
---
*/

// https://issues.dlang.org/show_bug.cgi?id=19202

void main()
{
    auto b = X!();
}

template X()
{
    deprecated enum X = true;
}
