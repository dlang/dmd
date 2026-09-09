/*
TEST_OUTPUT:
---
fail_compilation/issue21294.d(18): Error: none of the overloads of `fun` are callable using argument types `(int, int)`
fail_compilation/issue21294.d(18):        parameter `a` assigned twice
fail_compilation/issue21294.d(13):        Candidates are: `issue21294.fun(int a)`
fail_compilation/issue21294.d(14):                        `issue21294.fun(int a, int b)`
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
