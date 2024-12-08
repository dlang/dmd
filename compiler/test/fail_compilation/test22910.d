/* REQUIRED_ARGS: -preview=dip1000
TEST_OUTPUT:
---
fail_compilation/test22910.d(21): Error: returning `&this.val` escapes a reference to parameter `this`
        return &this.val;
               ^
fail_compilation/test22910.d(19):        perhaps change the `return scope` into `scope return`
    int* retScope() return scope
         ^
---
*/
@safe:

struct S
{
    int  val;
    int* ptr;

    int* retScope() return scope
    {
        return &this.val;
    }
}
