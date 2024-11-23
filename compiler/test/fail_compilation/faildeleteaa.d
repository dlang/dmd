/*
TEST_OUTPUT:
---
fail_compilation/faildeleteaa.d(14): Error: the `delete` keyword is obsolete
    delete aa[1];
    ^
fail_compilation/faildeleteaa.d(14):        use `object.destroy()` (and `core.memory.GC.free()` if applicable) instead
---
*/

void main()
{
    int[int] aa = [1 : 2];
    delete aa[1];
}
