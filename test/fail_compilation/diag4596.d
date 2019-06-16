/*
TEST_OUTPUT:
---
fail_compilation/diag4596.d(17): Error: `this` is not an lvalue and cannot be modified
fail_compilation/diag4596.d(18): Error: `this` is not an lvalue and cannot be modified
fail_compilation/diag4596.d(18): Error: `this` is not an lvalue and cannot be modified
fail_compilation/diag4596.d(20): Error: `super` is not an lvalue and cannot be modified
fail_compilation/diag4596.d(21): Error: `super` is not an lvalue and cannot be modified
fail_compilation/diag4596.d(21): Error: `super` is not an lvalue and cannot be modified
---
*/

class NoGo4596
{
    void fun()
    {
        this = new NoGo4596;
        (1?this:this) = new NoGo4596;

        super = new Object;
        (1?super:super) = new Object;
    }
}
