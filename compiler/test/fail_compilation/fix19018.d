/*
TEST_OUTPUT:
---
fail_compilation/fix19018.d(26): Error: `0b` isn't a valid integer literal, use `0b0` instead
    auto a = 0b;
             ^
fail_compilation/fix19018.d(27): Error: `0B` isn't a valid integer literal, use `0B0` instead
    auto b = 0B;
             ^
fail_compilation/fix19018.d(28): Error: `0x` isn't a valid integer literal, use `0x0` instead
    auto c = 0x;
             ^
fail_compilation/fix19018.d(29): Error: `0X` isn't a valid integer literal, use `0X0` instead
    auto d = 0X;
             ^
fail_compilation/fix19018.d(30): Error: `0x_` isn't a valid integer literal, use `0x0` instead
    auto e = 0x_;
             ^
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
