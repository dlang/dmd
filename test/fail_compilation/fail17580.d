// REQUIRED_ARGS: -de
/*
TEST_OUTPUT:
---
fail_compilation/fail17580.d(11): Deprecation: function `fail17580.S.fun` cannot be marked as `synchronized` because it is a member of the non-`synchronized` class `fail17580.S`. The `synchronized` attribute must be applied to the class declaration itself
---
*/

class S
{
    synchronized void fun() { }
}
