/*
TEST_OUTPUT:
---
fail_compilation/diag8777e.d(5): Error: cannot remove key from immutable associative array hash
---
*/

#line 1
immutable(int[int]) hash;

void main()
{
    hash.remove(1);
}
