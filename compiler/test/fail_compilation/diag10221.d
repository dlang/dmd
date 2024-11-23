/*
TEST_OUTPUT:
---
fail_compilation/diag10221.d(12): Error: cannot implicitly convert expression `256` of type `int` to `ubyte`
    foreach(ref ubyte i; 0..256) {}
                            ^
---
*/

void main()
{
    foreach(ref ubyte i; 0..256) {}
}
