/*
TEST_OUTPUT:
---
fail_compilation/diag10984.d(16): Error: `static` function `diag10984.f.n` cannot access variable `x` in frame of function `diag10984.f`
    static void n() { x++; }
                      ^
fail_compilation/diag10984.d(15):        `x` declared here
    int x;
        ^
---
*/

void f()
{
    int x;
    static void n() { x++; }
}

void main()
{
}
