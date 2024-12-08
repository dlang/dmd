/*
EXTRA_FILES: imports/a10169.d
TEST_OUTPUT:
---
fail_compilation/diag10169.d(17): Error: no property `x` for `B(0)` of type `imports.a10169.B`
    auto a = B.init.x;
                   ^
fail_compilation/imports/a10169.d(3):        struct `B` defined here
struct B
^
---
*/
import imports.a10169;

void main()
{
    auto a = B.init.x;
}
