/*
TEST_OUTPUT:
---
fail_compilation/fail325.d(14): Error: template `fun(T = int)(int w, int z)` has no type
    auto x = cast(void function(int, int))fun;
                                          ^
---
*/

void fun(T = int)(int w, int z) {}

void main()
{
    auto x = cast(void function(int, int))fun;
}
