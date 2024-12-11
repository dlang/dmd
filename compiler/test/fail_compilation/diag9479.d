/*
TEST_OUTPUT:
---
fail_compilation/diag9479.d(12): Error: undefined identifier `something_undefined`
    return { return something_undefined; };
                    ^
---
*/

int delegate() bug9479()
{
    return { return something_undefined; };
}
