/*
TEST_OUTPUT:
---
fail_compilation/fail318_b.d(10): Error: function `D main` must return `int`, `void` or `noreturn`, not `string`
auto main()
     ^
---
*/

auto main()
{
    return "";
}
