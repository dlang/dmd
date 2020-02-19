// https://issues.dlang.org/show_bug.cgi?id=20583

// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/fail20583.d(17): Deprecation: `alias x this` is deprecated
---
*/

struct X
{
    int[1] x;
    deprecated alias x this;
}

auto y = X()[0];
