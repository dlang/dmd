/*
TEST_OUTPUT:
---
fail_compilation/fix19059.d(26): Error: octal digit expected, not `8`
    auto a = 08;
             ^
fail_compilation/fix19059.d(26): Error: octal literals larger than 7 are no longer supported
    auto a = 08;
             ^
fail_compilation/fix19059.d(27): Error: octal digit expected, not `9`
    auto b = 09;
             ^
fail_compilation/fix19059.d(27): Error: octal literals larger than 7 are no longer supported
    auto b = 09;
             ^
fail_compilation/fix19059.d(28): Error: octal literals `010` are no longer supported, use `std.conv.octal!"10"` instead
    auto c = 010;
             ^
---
 */

// https://issues.dlang.org/show_bug.cgi?id=19059

void foo()
{
    auto a = 08;
    auto b = 09;
    auto c = 010;
}
