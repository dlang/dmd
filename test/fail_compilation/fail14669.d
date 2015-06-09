/*
TEST_OUTPUT:
---
fail_compilation/fail14669.d(11): Error: auto can only be used for template function parameters
fail_compilation/fail14669.d(16): Error: template instance fail14669.foo1!() error instantiating
fail_compilation/fail14669.d(12): Error: auto can only be used for template function parameters
fail_compilation/fail14669.d(17): Error: template fail14669.foo2 cannot deduce function from argument types !()(int), candidates are:
fail_compilation/fail14669.d(12):        fail14669.foo2()(auto int a)
---
*/
void foo1()(auto int a) {}
void foo2()(auto int a) {}

void test1()
{
    alias f1 = foo1!();
    foo2(1);
}
