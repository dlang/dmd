/*
TEST_OUTPUT:
---
fail_compilation/fix19246.d(23): Error: `0b_` isn't a valid integer literal, use `0b0` instead
    auto a = 0b_;
             ^
fail_compilation/fix19246.d(24): Error: `0B_` isn't a valid integer literal, use `0B0` instead
    auto b = 0B_;
             ^
fail_compilation/fix19246.d(25): Error: `0b` isn't a valid integer literal, use `0b0` instead
    auto c = 0b;
             ^
fail_compilation/fix19246.d(26): Error: `0B` isn't a valid integer literal, use `0B0` instead
    auto d = 0B;
             ^
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
