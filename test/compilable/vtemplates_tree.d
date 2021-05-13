/* REQUIRED_ARGS: -vtemplates=list-instances
TEST_OUTPUT:
---
compilable/vtemplates_tree.d(25): TI
 compilable/vtemplates_tree.d(9): TD
---
*/

void f(int I)()
{
    g!I();
}

void g(int I)()
{
    h!I();
}

void h(int I)()
{
}

void test()
{
    f!(42)();
}
