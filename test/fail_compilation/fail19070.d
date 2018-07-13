/* REQUIRED_ARGS: -de
 * PERMUTE_ARGS:
 * TEST_OUTPUT:
---
fail_compilation/fail19070.d(20): Deprecation: octal literals `00` are no longer supported, use `std.conv.octal!0` instead
fail_compilation/fail19070.d(21): Deprecation: octal literals `01` are no longer supported, use `std.conv.octal!1` instead
fail_compilation/fail19070.d(22): Deprecation: octal literals `02` are no longer supported, use `std.conv.octal!2` instead
fail_compilation/fail19070.d(23): Deprecation: octal literals `03` are no longer supported, use `std.conv.octal!3` instead
fail_compilation/fail19070.d(24): Deprecation: octal literals `04` are no longer supported, use `std.conv.octal!4` instead
fail_compilation/fail19070.d(25): Deprecation: octal literals `05` are no longer supported, use `std.conv.octal!5` instead
fail_compilation/fail19070.d(26): Deprecation: octal literals `06` are no longer supported, use `std.conv.octal!6` instead
fail_compilation/fail19070.d(27): Deprecation: octal literals `07` are no longer supported, use `std.conv.octal!7` instead
---
 */

// https://issues.dlang.org/show_bug.cgi?id=19070

void foo()
{
    auto a = 00;
    auto b = 01;
    auto c = 02;
    auto d = 03;
    auto e = 04;
    auto f = 05;
    auto g = 06;
    auto h = 07;
}
