/*
TEST_OUTPUT:
---
fail_compilation/fail50.d(16): Error: taking the address of non-static variable `a` requires an instance of `Marko`
    int* m = &a;
             ^
fail_compilation/fail50.d(16): Error: variable `a` cannot be read at compile time
    int* m = &a;
             ^
---
*/

struct Marko
{
    int a;
    int* m = &a;
}
