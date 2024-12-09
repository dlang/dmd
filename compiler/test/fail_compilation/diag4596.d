/*
TEST_OUTPUT:
---
fail_compilation/diag4596.d(23): Error: cannot modify expression `this` because it is not an lvalue
        this = new NoGo4596;
        ^
fail_compilation/diag4596.d(24): Error: conditional expression `1 ? this : this` is not a modifiable lvalue
        (1?this:this) = new NoGo4596;
         ^
fail_compilation/diag4596.d(26): Error: cannot modify expression `super` because it is not an lvalue
        super = new Object;
        ^
fail_compilation/diag4596.d(27): Error: conditional expression `1 ? super : super` is not a modifiable lvalue
        (1?super:super) = new Object;
         ^
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
