/*
TEST_OUTPUT:
---
fail_compilation/fail136.d(11): Deprecation: Built-in hex string literals are deprecated, use `std.conv.hexString` instead.
fail_compilation/fail136.d(11): Error: `"\xef\xbb\xbf"` has no effect
---
*/

void main()
{
    x"EF BB BF";
}
