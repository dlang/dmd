/*
TEST_OUTPUT:
---
fail_compilation/diag5839.d(12): Error: undefined identifier fo
---
*/

import imports.diag5839;

void main()
{
    fo = 1;
}
