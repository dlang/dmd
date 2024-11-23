/*
TEST_OUTPUT:
---
fail_compilation/diag11840.d(16): Error: undefined identifier `i`
    data[i .. j] = 0;
         ^
fail_compilation/diag11840.d(16): Error: undefined identifier `j`
    data[i .. j] = 0;
              ^
---
*/

void main()
{
    int[10] data;
    data[i .. j] = 0;
}
