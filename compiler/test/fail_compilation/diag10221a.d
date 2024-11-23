/*
TEST_OUTPUT:
---
fail_compilation/diag10221a.d(12): Error: cannot implicitly convert expression `257` of type `int` to `ubyte`
    foreach(ubyte i; 0..257) {}
                        ^
---
*/

void main()
{
    foreach(ubyte i; 0..257) {}
}
