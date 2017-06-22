/*
TEST_OUTPUT:
---
fail_compilation/fail136.d(11): Deprecation: built-in hex string literals are deprecated, use `std.conv.hexString` instead
fail_compilation/fail136.d(11): Error: `string` has no effect in expression `"\xef\xbb\xbf"`
---
*/

void main()
{
    x"EF BB BF";
}
