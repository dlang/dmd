/* REQUIRED_ARGS: -de
 * PERMUTE_ARGS:
 * TEST_OUTPUT:
---
fail_compilation/fix19018.d(17): Deprecation: `0b` isn't a valid integer literal, use `0b0` instead
fail_compilation/fix19018.d(18): Deprecation: `0B` isn't a valid integer literal, use `0B0` instead
fail_compilation/fix19018.d(19): Deprecation: `0x` isn't a valid integer literal, use `0x0` instead
fail_compilation/fix19018.d(20): Deprecation: `0X` isn't a valid integer literal, use `0X0` instead
fail_compilation/fix19018.d(21): Deprecation: `0x_` isn't a valid integer literal, use `0x0` instead
---
 */

// https://issues.dlang.org/show_bug.cgi?id=19018

void foo()
{
    auto a = 0b;
    auto b = 0B;
    auto c = 0x;
    auto d = 0X;
    auto e = 0x_;
}
