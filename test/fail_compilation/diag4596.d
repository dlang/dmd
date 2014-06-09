/*
TEST_OUTPUT:
---
fail_compilation/diag4596.d(15): Error: cannot modify 'this' reference
fail_compilation/diag4596.d(16): Error: cannot modify 'this' reference
fail_compilation/diag4596.d(18): Error: cannot modify 'super' reference
fail_compilation/diag4596.d(19): Error: cannot modify 'super' reference
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
