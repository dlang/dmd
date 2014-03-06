/*
TEST_OUTPUT:
---
fail_compilation/fail109.d(12): Error: enum member fail109.Bool.Unknown initialization with (Bool.True + 1) causes overflow for type 'bool'
---
*/

enum Bool : bool
{
    False,
    True,
    Unknown
}
