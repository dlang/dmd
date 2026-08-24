/* REQUIRED_ARGS: -betterC
TEST_OUTPUT:
---
fail_compilation/betterc_new.d(105): Error: `new` expression `new S(1)` requires the GC which is not available with `-betterC`
fail_compilation/betterc_new.d(106): Error: `new` expression `new int(3)` requires the GC which is not available with `-betterC`
fail_compilation/betterc_new.d(107): Error: `new` expression `new int[int]` requires the GC which is not available with `-betterC`
---
*/

#line 100

struct S { int i; }

void test()
{
    S* p = new S(1);
    int* i = new int(3);
    auto aa = new int[int];
}
