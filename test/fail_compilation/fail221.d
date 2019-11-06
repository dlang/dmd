/*
TEST_OUTPUT:
---
fail_compilation/fail221.d(12): Error: variable `fail221.main.__ceatmp$n$` variables cannot be of type `void`
fail_compilation/fail221.d(12): Error: expression `cast(void)0` is `void` and has no value
---
*/

void main()
{
    void[] data;
    data ~= cast(void) 0;
}
