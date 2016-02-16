/*
TEST_OUTPUT:
---
fail_compilation/test314.d(15): Error: undefined identifier 'core'
fail_compilation/test314.d(16): Error: undefined identifier 'io'
---
*/

module test314;

import imports.a314;

void main()
{
    core.stdc.stdio.printf("This should not work.\n");
    io.printf("This should not work.\n");
    printf("This should not work.\n");
}
