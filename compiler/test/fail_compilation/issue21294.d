/*
REQUIRED_ARGS:
TEST_OUTPUT:
---
fail_compilation/issue21294.d(13): Error: parameter `a` assigned twice
---
*/

void fun(int a) {}
void fun(int a, int b) {}

void main()
{
    fun(a: 2, a: 4);
}
