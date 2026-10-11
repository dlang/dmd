/*
TEST_OUTPUT:
---
fail_compilation/issue21294.d(15): Error: parameter `a` assigned twice
---
*/

// https://github.com/dlang/dmd/issues/21294

void fun(int a) {}
void fun(int a, int b) {}

void main()
{
    fun(
        a: 2,
        a: 4,
    );
}
