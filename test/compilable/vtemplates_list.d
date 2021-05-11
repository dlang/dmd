/* REQUIRED_ARGS: -vtemplates=list-instances
TEST_OUTPUT:
---
compilable/vtemplates_list.d(6): vtemplate: 3/4/0 distinct/total/transitive instantiation(s) of template `foo(int I)()` found, they are:
compilable/vtemplates_list.d(20): here
compilable/vtemplates_list.d(20): vtemplate: explicit instance `foo!1`
compilable/vtemplates_list.d(21): here
compilable/vtemplates_list.d(21): vtemplate: explicit instance `foo!1`
compilable/vtemplates_list.d(22): here
compilable/vtemplates_list.d(22): vtemplate: explicit instance `foo!2`
compilable/vtemplates_list.d(23): here
compilable/vtemplates_list.d(23): vtemplate: explicit instance `foo!3`
compilable/vtemplates_list.d(1): vtemplate: 1/3/0 distinct/total/transitive instantiation(s) of template `goo1(int I)()` found, they are:
compilable/vtemplates_list.d(10): here
compilable/vtemplates_list.d(10): vtemplate: explicit instance `goo1!1`
compilable/vtemplates_list.d(11): here
compilable/vtemplates_list.d(11): vtemplate: explicit instance `goo1!1`
compilable/vtemplates_list.d(2): here
compilable/vtemplates_list.d(2): vtemplate: implicit instance `goo1!1`
compilable/vtemplates_list.d(2): vtemplate: of parenting instance `goo2!1`
compilable/vtemplates_list.d(2): vtemplate: 1/3/1 distinct/total/transitive instantiation(s) of template `goo2(int I)()` found, they are:
compilable/vtemplates_list.d(13): here
compilable/vtemplates_list.d(13): vtemplate: explicit instance `goo2!1`
compilable/vtemplates_list.d(14): here
compilable/vtemplates_list.d(14): vtemplate: explicit instance `goo2!1`
compilable/vtemplates_list.d(3): here
compilable/vtemplates_list.d(3): vtemplate: implicit instance `goo2!1`
compilable/vtemplates_list.d(3): vtemplate: of parenting instance `goo3!1`
compilable/vtemplates_list.d(3): vtemplate: 1/3/1 distinct/total/transitive instantiation(s) of template `goo3(int I)()` found, they are:
compilable/vtemplates_list.d(16): here
compilable/vtemplates_list.d(16): vtemplate: explicit instance `goo3!1`
compilable/vtemplates_list.d(4): here
compilable/vtemplates_list.d(4): vtemplate: implicit instance `goo3!1`
compilable/vtemplates_list.d(4): vtemplate: of parenting instance `goo4!1`
compilable/vtemplates_list.d(4): here
compilable/vtemplates_list.d(4): vtemplate: implicit instance `goo3!1`
compilable/vtemplates_list.d(4): vtemplate: of parenting instance `goo4!1`
compilable/vtemplates_list.d(4): vtemplate: 1/3/2 distinct/total/transitive instantiation(s) of template `goo4(int I)()` found, they are:
compilable/vtemplates_list.d(17): here
compilable/vtemplates_list.d(17): vtemplate: explicit instance `goo4!1`
compilable/vtemplates_list.d(5): here
compilable/vtemplates_list.d(5): vtemplate: implicit instance `goo4!1`
compilable/vtemplates_list.d(5): vtemplate: of parenting instance `goo5!1`
compilable/vtemplates_list.d(5): here
compilable/vtemplates_list.d(5): vtemplate: implicit instance `goo4!1`
compilable/vtemplates_list.d(5): vtemplate: of parenting instance `goo5!1`
compilable/vtemplates_list.d(5): vtemplate: 1/1/2 distinct/total/transitive instantiation(s) of template `goo5(int I)()` found, they are:
compilable/vtemplates_list.d(18): here
compilable/vtemplates_list.d(18): vtemplate: explicit instance `goo5!1`
compilable/vtemplates_list.d(52): vtemplate: 1/1/0 distinct/total/transitive instantiation(s) of template `A()` found, they are:
compilable/vtemplates_list.d-mixin-53(53): here
compilable/vtemplates_list.d-mixin-53(53): vtemplate: explicit instance `A!()`
---
*/

#line 1
void goo1(int I)() { }
void goo2(int I)() { goo1!(I); }
void goo3(int I)() { goo2!(I); }
void goo4(int I)() { goo3!(I); goo3!(I); }
void goo5(int I)() { goo4!(I); goo4!(I); }
void foo(int I)() { }

void test()
{
    goo1!(1)();
    goo1!(1)();

    goo2!(1)();
    goo2!(1)();

    goo3!(1)();
    goo4!(1)();
    goo5!(1)();

    foo!(1)();
    foo!(1)();
    foo!(2)();
    foo!(3)();
}

// https://issues.dlang.org/show_bug.cgi?id=21489
#line 50
void test2()
{
    template A() {}
    alias ta = mixin("A!()");
}
