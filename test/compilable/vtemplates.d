/* REQUIRED_ARGS: -vtemplates=list-instances
TEST_OUTPUT:
---
compilable/vtemplates.d(29): vtemplate: 3/6/0 distinct/total/transitive instantiation(s) of template `goo1(int I)()` found, they are:
compilable/vtemplates.d(30): vtemplate: implicit instance `goo1!42`
compilable/vtemplates.d(30): vtemplate: of parenting instance `goo2!42`
compilable/vtemplates.d(40): vtemplate: explicit instance `goo1!1`
compilable/vtemplates.d(41): vtemplate: explicit instance `goo1!1`
compilable/vtemplates.d(42): vtemplate: explicit instance `goo1!2`
compilable/vtemplates.d(30): vtemplate: implicit instance `goo1!1`
compilable/vtemplates.d(30): vtemplate: of parenting instance `goo2!1`
compilable/vtemplates.d(30): vtemplate: implicit instance `goo1!2`
compilable/vtemplates.d(30): vtemplate: of parenting instance `goo2!2`
compilable/vtemplates.d(28): vtemplate: 3/4/0 distinct/total/transitive instantiation(s) of template `foo(int I)()` found, they are:
compilable/vtemplates.d(35): vtemplate: explicit instance `foo!1`
compilable/vtemplates.d(36): vtemplate: explicit instance `foo!1`
compilable/vtemplates.d(37): vtemplate: explicit instance `foo!2`
compilable/vtemplates.d(38): vtemplate: explicit instance `foo!3`
compilable/vtemplates.d(30): vtemplate: 3/4/3 distinct/total/transitive instantiation(s) of template `goo2(int I)()` found, they are:
compilable/vtemplates.d(31): vtemplate: explicit instance `goo2!42`
compilable/vtemplates.d(44): vtemplate: explicit instance `goo2!1`
compilable/vtemplates.d(45): vtemplate: explicit instance `goo2!2`
compilable/vtemplates.d(46): vtemplate: explicit instance `goo2!2`
---
*/

// #line 1
void foo(int I)() { }
void goo1(int I)() { }
void goo2(int I)() { goo1!(I); }
void hoo() { goo2!(42)(); }

void test()
{
    foo!(1)();
    foo!(1)();
    foo!(2)();
    foo!(3)();

    goo1!(1)();
    goo1!(1)();
    goo1!(2)();

    goo2!(1)();
    goo2!(2)();
    goo2!(2)();
}
