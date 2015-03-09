/*
TEST_OUTPUT:
---
compilable/diag4596.d(15): Deprecation: this is not an lvalue
compilable/diag4596.d(16): Deprecation: 1 ? this : this is not an lvalue
compilable/diag4596.d(18): Deprecation: super is not an lvalue
compilable/diag4596.d(19): Deprecation: 1 ? super : super is not an lvalue
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
