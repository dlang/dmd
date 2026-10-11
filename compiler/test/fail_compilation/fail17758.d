/*
TEST_OUTPUT:
---
fail_compilation/fail17758.d(15): Error: incompatible types for `("hello") ~ (s)`: both operands are of type `const(char)*`
fail_compilation/fail17758.d(15):        `~` concatenates arrays, not pointers; convert the pointer to an array first, e.g. with `std.string.fromStringz`
---
*/

// https://github.com/dlang/dmd/issues/17758
// Concatenating two pointers (a common mistake with C strings) should
// hint that `~` is for arrays, not just report a generic type mismatch.
void test17758()
{
    const(char)* s = "some literal";
    auto ss = "hello" ~ s;
}
