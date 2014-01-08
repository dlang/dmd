/*
TEST_OUTPUT:
---
fail_compilation/fail325.d(12): Error: cannot cast template fun(T = int)(int w, int z) to type void function(int, int)
---
*/

void fun(T = int)(int w, int z) {}

void main()
{
    auto x = cast(void function(int, int))fun;
}
