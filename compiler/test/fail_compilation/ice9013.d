/*
TEST_OUTPUT:
---
fail_compilation/ice9013.d(11): Error: undefined identifier `missing`
    foreach (i; 0 .. missing)
                     ^
---
*/
void main()
{
    foreach (i; 0 .. missing)
        int[] foo = cast(int[])[i];
}
