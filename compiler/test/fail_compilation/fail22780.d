// https://issues.dlang.org/show_bug.cgi?id=22780
/* TEST_OUTPUT:
---
fail_compilation/fail22780.d(14): Error: variable `fail22780.test10717.c` reference to `scope class` must be `scope`
    C10717 c;
           ^
---
*/

scope class C10717 { }

void test10717()
{
    C10717 c;
}
