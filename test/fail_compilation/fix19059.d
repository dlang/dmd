/* REQUIRED_ARGS:
 * PERMUTE_ARGS:
 * TEST_OUTPUT:
---
fail_compilation/fix19059.d(16): Error: radix 8 digit expected, not `8`
fail_compilation/fix19059.d(16): Error: octal literals `010` are no longer supported, use `std.conv.octal!10` instead
fail_compilation/fix19059.d(17): Error: radix 8 digit expected, not `9`
fail_compilation/fix19059.d(17): Error: octal literals `011` are no longer supported, use `std.conv.octal!11` instead
---
 */

// https://issues.dlang.org/show_bug.cgi?id=19059

void foo()
{
    auto a = 08;
    auto b = 09;
}
