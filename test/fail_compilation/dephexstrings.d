// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/dephexstrings.d(8): Deprecation: Built-in hex string literals are deprecated, use `std.conv.hexString` instead.
---
*/
enum xstr = x"60";
