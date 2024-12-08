/*
TEST_OUTPUT:
---
fail_compilation/fail3990.d(16): Error: using `*` on an array is no longer supported; use `*(arr1).ptr` instead
    assert(*arr1 == 1);
           ^
fail_compilation/fail3990.d(18): Error: using `*` on an array is no longer supported; use `*(arr2).ptr` instead
    assert(*arr2 == 1);
           ^
---
*/

void main()
{
    int[] arr1 = [1, 2, 3];
    assert(*arr1 == 1);
    int[3] arr2 = [1, 2, 3];
    assert(*arr2 == 1);
}
