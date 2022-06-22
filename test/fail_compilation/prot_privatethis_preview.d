/*
TEST_OUTPUT:
---
fail_compilation/prot_privatethis_preview.d(10): Error: use `-preview=privateThis` to enable usage of `private(this)`
---
*/

class C
{
    private(this) int x;
}
