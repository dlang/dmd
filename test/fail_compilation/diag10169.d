/*
TEST_OUTPUT:
---
fail_compilation/diag10169.d(11): Error: no property `x` for type `imports.a10169.B`
---
*/
import imports.a10169;

void main()
{
    auto a = B.init.x;
}
