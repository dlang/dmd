/* REQUIRED_ARGS: -de
 * PERMUTE_ARGS:
 * TEST_OUTPUT:
---
fail_compilation/fix19246.d(16): Deprecation: `0b_` isn't a valid integer literal, use `0b0` instead
fail_compilation/fix19246.d(17): Deprecation: `0B_` isn't a valid integer literal, use `0B0` instead
fail_compilation/fix19246.d(18): Deprecation: `0b` isn't a valid integer literal, use `0b0` instead
fail_compilation/fix19246.d(19): Deprecation: `0B` isn't a valid integer literal, use `0B0` instead
---
 */

// https://issues.dlang.org/show_bug.cgi?id=19246

void foo()
{
    auto a = 0b_;
    auto b = 0B_;
    auto c = 0b;
    auto d = 0B;
}
