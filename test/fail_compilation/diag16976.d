/* TEST_OUTPUT:
---
fail_compilation/diag16976.d(14): Error: foreach: key cannot be of non-integral type `float`
fail_compilation/diag16976.d(15): Error: foreach: key cannot be of non-integral type `float`
fail_compilation/diag16976.d(16): Error: foreach: key cannot be of non-integral type `float`
fail_compilation/diag16976.d(17): Error: foreach: key cannot be of non-integral type `float`
---
*/

void main()
{
    int[]  dyn = [1,2,3,4,5];
    int[5] sta = [1,2,3,4,5];
    foreach(float f, i; dyn) {}
    foreach(float f, i; sta) {}
    foreach_reverse(float f, i; dyn) {}
    foreach_reverse(float f, i; sta) {}
}
