/* TEST_OUTPUT:
---
fail_compilation/test11006.d(11): Error: cannot subtract pointers to different types: `void*` and `int*`.
fail_compilation/test11006.d(11):        while evaluating: `static assert(2L == 2L)`
fail_compilation/test11006.d(12): Error: cannot subtract pointers to different types: `int*` and `void*`.
fail_compilation/test11006.d(12):        while evaluating: `static assert(8L == 8L)`
fail_compilation/test11006.d(15): Error: cannot subtract pointers to different types: `ushort*` and `ubyte*`.
---
 */
static assert(cast(void*)8 - cast(int*) 0 == 2L);
static assert(cast(int*) 8 - cast(void*)0 == 8L);
void test()
{
    auto foo = (ushort*).init - (ubyte*).init;
}
