/*
TEST_OUTPUT:
---
fail_compilation/ice11086.d(12): Error: template instance `foo!A` template `foo` is not defined
    foo!(A) l1,l2;
    ^
---
*/

struct A
{
    foo!(A) l1,l2;
}
