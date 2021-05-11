/* REQUIRED_ARGS: -vtemplates
TEST_OUTPUT:
---
compilable/vtemplates.d(11): vtemplate: 3/4/0 distinct/total/transitive instantiation(s) of template `foo(int I)()` found
compilable/vtemplates.d(12): vtemplate: 2/5/0 distinct/total/transitive instantiation(s) of template `goo1(int I)()` found
compilable/vtemplates.d(13): vtemplate: 2/3/2 distinct/total/transitive instantiation(s) of template `goo2(int I)()` found
---
*/

// #line 1
void foo(int I)() { }
void goo1(int I)() { }
void goo2(int I)() { goo1!(I); }

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
