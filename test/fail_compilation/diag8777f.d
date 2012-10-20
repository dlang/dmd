/*
TEST_OUTPUT:
---
fail_compilation/diag8777f.d(5): Error: cannot remove key from const associative array hash
---
*/

#line 1
const(int[int]) hash;

void main()
{
    hash.remove(1);
}
