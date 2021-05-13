/* REQUIRED_ARGS: -vtemplates=list-instances
TEST_OUTPUT:
---
compilable/vtemplates_list.d(20): TI
 compilable/vtemplates_list.d(6): TD

compilable/vtemplates_list.d(21): TI
 compilable/vtemplates_list.d(6): TD

compilable/vtemplates_list.d(22): TI
 compilable/vtemplates_list.d(6): TD

compilable/vtemplates_list.d(23): TI
 compilable/vtemplates_list.d(6): TD

compilable/vtemplates_list.d(10): TI
 compilable/vtemplates_list.d(1): TD

compilable/vtemplates_list.d(11): TI
 compilable/vtemplates_list.d(1): TD

compilable/vtemplates_list.d(16): TI
 compilable/vtemplates_list.d(3): TD

compilable/vtemplates_list.d(13): TI
 compilable/vtemplates_list.d(2): TD

compilable/vtemplates_list.d(14): TI
 compilable/vtemplates_list.d(2): TD

compilable/vtemplates_list.d(17): TI
 compilable/vtemplates_list.d(4): TD

compilable/vtemplates_list.d(18): TI
 compilable/vtemplates_list.d(5): TD

compilable/vtemplates_list.d-mixin-53(53): TI
 compilable/vtemplates_list.d(52): TD
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
