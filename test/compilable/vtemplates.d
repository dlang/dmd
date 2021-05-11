/* REQUIRED_ARGS: -vtemplates=list-instances
TEST_OUTPUT:
---
compilable/vtemplates.d(52): TI
 compilable/vtemplates.d(41): TD

compilable/vtemplates.d(53): TI
 compilable/vtemplates.d(41): TD

compilable/vtemplates.d(54): TI
 compilable/vtemplates.d(41): TD

compilable/vtemplates.d(43): TI
 compilable/vtemplates.d(42): TD

compilable/vtemplates.d(56): TI
 compilable/vtemplates.d(42): TD

compilable/vtemplates.d(57): TI
 compilable/vtemplates.d(42): TD

compilable/vtemplates.d(58): TI
 compilable/vtemplates.d(42): TD

compilable/vtemplates.d(47): TI
 compilable/vtemplates.d(40): TD

compilable/vtemplates.d(48): TI
 compilable/vtemplates.d(40): TD

compilable/vtemplates.d(49): TI
 compilable/vtemplates.d(40): TD

compilable/vtemplates.d(50): TI
 compilable/vtemplates.d(40): TD
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
