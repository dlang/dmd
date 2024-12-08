/*
TEST_OUTPUT:
---
fail_compilation/fail221.d(13): Error: expression `cast(void)0` is `void` and has no value
    data ~= cast(void) 0;
            ^
---
*/

void main()
{
    void[] data;
    data ~= cast(void) 0;
}
