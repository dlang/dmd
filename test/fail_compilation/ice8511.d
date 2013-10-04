/*
TEST_OUTPUT:
---
fail_compilation/ice8511.d(13): Error: type SQRTMAX has no value
fail_compilation/ice8511.d(13): Error: / has no effect in expression ((SQRTMAX) / 2)
fail_compilation/ice8511.d(10): Error: function ice8511.hypot has no return statement, but is expected to return a value of type real
---
*/

real hypot()
{
    enum SQRTMAX;
    SQRTMAX/2;
}
