/* REQUIRED_ARGS: -de
 * PERMUTE_ARGS:
 * TEST_OUTPUT:
---
fail_compilation/fix19059.d(14): Deprecation: `08` isn't a valid integer literal
fail_compilation/fix19059.d(15): Deprecation: `09` isn't a valid integer literal
---
 */

// https://issues.dlang.org/show_bug.cgi?id=19059

void foo()
{
    auto a = 08;
    auto b = 09;
}
