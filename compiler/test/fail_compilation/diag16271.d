/*
TEST_OUTPUT:
---
fail_compilation/diag16271.d(12): Error: found `x` when expecting function literal following `ref`
    auto fun = ref x;
                   ^
---
*/

void main()
{
    auto fun = ref x;
}
