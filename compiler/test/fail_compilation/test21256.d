/**
TEST_OUTPUT:
---
fail_compilation/test21256.d(11): Error: cannot cast expression `x""` of type `string` to `ubyte`
---
*/

// https://github.com/dlang/dmd/issues/21256
void f21256()
{
    auto s = cast(ubyte[]) [x""];
}
