// https://issues.dlang.org/show_bug.cgi?id=18623
// REQUIRED_ARGS: -D -unittest -de

/*
TEST_OUTPUT:
---
fail_compilation/test18623.d(16): Deprecation: `variable` `i` is `private` but is used in a public documented unittest
---
*/

private int i;

///
unittest
{
    i++;
}
