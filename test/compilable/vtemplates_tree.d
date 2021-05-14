/* REQUIRED_ARGS: -vtemplates=list-instances
TEST_OUTPUT:
---
compilable/vtemplates_tree.d(26): vtemplate: 1/1/0 distinct/total/transitive instantiation(s) of template `h(int I)()` found, they are:
compilable/vtemplates_tree.d(23): vtemplate: implicit instance `h!42`
compilable/vtemplates_tree.d(23): vtemplate: of parenting instance `g!42`
compilable/vtemplates_tree.d(23): vtemplate: of parenting instance `f!42`
compilable/vtemplates_tree.d(21): vtemplate: 1/1/1 distinct/total/transitive instantiation(s) of template `g(int I)()` found, they are:
compilable/vtemplates_tree.d(18): vtemplate: implicit instance `g!42`
compilable/vtemplates_tree.d(18): vtemplate: of parenting instance `f!42`
compilable/vtemplates_tree.d(16): vtemplate: 1/1/2 distinct/total/transitive instantiation(s) of template `f(int I)()` found, they are:
compilable/vtemplates_tree.d(32): vtemplate: explicit instance `f!42`
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
