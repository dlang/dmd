/*
TEST_OUTPUT:
---
fail_compilation/diag12380.d(14): Error: cannot implicitly convert expression `E.a` of type `E` to `void*`
    void* a = E.init;
              ^
---
*/

enum E { a, b, }

void main()
{
    void* a = E.init;
}
