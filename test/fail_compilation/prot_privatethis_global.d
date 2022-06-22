/*
REQUIRED_ARGS: -preview=privateThis
TEST_OUTPUT:
---
fail_compilation/prot_privatethis_global.d(11): Error: visibility attribute `private(this)` cannot be used in global scope
fail_compilation/prot_privatethis_global.d(13): Error: visibility attribute `private(this)` cannot be used in global scope
fail_compilation/prot_privatethis_global.d(16): Error: visibility attribute `private(this)` cannot be used in global scope
---
*/

private(this) int x;

private(this): int y;

private(this)
{
    int z;
}
