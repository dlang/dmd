/*
TEST_OUTPUT:
---
fail_compilation/ice11086.d(11): Error: template instance foo!A template 'foo' is not defined
fail_compilation/ice11086.d(11): Error: foo!A had previous errors
---
*/

struct A
{
    foo!(A) l1,l2;
}
