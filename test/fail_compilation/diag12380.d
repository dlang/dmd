/*
TEST_OUTPUT:
---
fail_compilation/diag12380.d(16): Error: cannot implicitly convert expression `cast(E)0` of type `E` to `void*`
fail_compilation/diag12380.d(17): Error: cannot implicitly convert expression `1024.00F` of type `float` to `int`
---
*/

enum E { a, b, }
struct vec2 { float x, y; }

enum winSize = vec2(1024, 768);

void main()
{
    void* a = E.init;
    int x = winSize.x;
}
