/*
TEST_OUTPUT:
---
fail_compilation/fail317.d(12): Error: function `fail317.I.f` has no function body with return type inference
    auto f()
         ^
---
*/

interface I
{
    auto f()
    in {}
    out {}
}
